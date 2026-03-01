#![allow(unexpected_cfgs)]

mod config_store;
mod discovery;
mod launcher;
#[cfg(target_os = "macos")]
mod macos_url_events;
mod models;
mod routing;

use anyhow::{anyhow, bail, Context, Result};
use config_store::{ConfigStore, ImportPayload};
#[cfg(target_os = "macos")]
use core_foundation::base::TCFType;
#[cfg(target_os = "macos")]
use core_foundation::string::{CFString, CFStringRef};
use discovery::detect_installed_browsers;
use launcher::open_url_with_browser;
use models::{
    normalize_shortcut, BrowserConfig, BrowserRoutingRule, DomainSuggestion, PersistedState,
    APP_SCHEMA_VERSION, DOMAIN_SUGGESTION_THRESHOLD,
};
use routing::resolved_route;
use serde::Serialize;
use std::collections::HashSet;
use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Mutex};
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{Manager, State, WebviewUrl, WebviewWindow, WebviewWindowBuilder};
use tauri_plugin_autostart::MacosLauncher;
use tauri_plugin_clipboard_manager::ClipboardExt;
use url::Url;
use uuid::Uuid;

const SETTINGS_WINDOW_LABEL: &str = "settings";
const PICKER_WINDOW_LABEL: &str = "picker";
const TRAY_ID: &str = "chowser-tray";
const TRAY_MENU_OPEN_SETTINGS: &str = "tray.open-settings";
const TRAY_MENU_OPEN_PICKER: &str = "tray.open-picker";
const TRAY_MENU_SET_DEFAULT: &str = "tray.set-default";
const TRAY_MENU_OPEN_CLIPBOARD_URL: &str = "tray.open-clipboard-url";
const TRAY_MENU_QUIT: &str = "tray.quit";

#[derive(Debug, Default)]
struct CliOptions {
    url: Option<Url>,
    source_app_id: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
struct CommandOutcome {
    ok: bool,
    message: String,
    added: Option<usize>,
}

#[derive(Debug, Serialize, Clone)]
struct DefaultBrowserStatus {
    supported: bool,
    app_bundle_id: String,
    http_handler: Option<String>,
    https_handler: Option<String>,
    is_default: bool,
    note: String,
}

#[derive(Debug, Serialize, Clone)]
struct AppSnapshot {
    config_path: String,
    has_completed_onboarding: bool,
    configured_browsers: Vec<BrowserConfig>,
    routing_rules: Vec<BrowserRoutingRule>,
    suggestions: Vec<DomainSuggestion>,
    pending_url: Option<String>,
    status_line: Option<String>,
    default_browser: DefaultBrowserStatus,
    suggested_browsers_path: String,
    suggested_rules_path: String,
    hidden_app_ids: Vec<String>,
}

struct AppRuntimeState {
    store: ConfigStore,
    state: Mutex<PersistedState>,
    pending_url: Mutex<Option<String>>,
    status_line: Mutex<Option<String>>,
    app_handle: Mutex<Option<tauri::AppHandle>>,
    app_bundle_id: String,
    suggested_browsers_path: String,
    suggested_rules_path: String,
}

impl AppRuntimeState {
    fn hidden_app_set(state: &PersistedState) -> HashSet<String> {
        state.hidden_app_ids.iter().cloned().collect()
    }

    fn new(store: ConfigStore, mut state: PersistedState) -> Self {
        state.ensure_defaults();
        let home = env::var("HOME").unwrap_or_else(|_| String::new());
        let suggested_browsers_path = if home.is_empty() {
            "ChowserBrowsers.json".to_owned()
        } else {
            format!("{home}/Documents/ChowserBrowsers.json")
        };
        let suggested_rules_path = if home.is_empty() {
            "ChowserRules.json".to_owned()
        } else {
            format!("{home}/Documents/ChowserRules.json")
        };

        Self {
            store,
            state: Mutex::new(state),
            pending_url: Mutex::new(None),
            status_line: Mutex::new(None),
            app_handle: Mutex::new(None),
            app_bundle_id: current_bundle_identifier(),
            suggested_browsers_path,
            suggested_rules_path,
        }
    }

    fn set_status(&self, status: impl Into<String>) {
        if let Ok(mut line) = self.status_line.lock() {
            *line = Some(status.into());
        }
    }

    fn set_app_handle(&self, app_handle: tauri::AppHandle) {
        if let Ok(mut handle) = self.app_handle.lock() {
            *handle = Some(app_handle);
        }
    }

    fn with_app_handle<F: FnOnce(&tauri::AppHandle)>(&self, f: F) {
        let app_handle = self
            .app_handle
            .lock()
            .ok()
            .and_then(|handle| handle.clone());
        if let Some(app) = app_handle {
            f(&app);
        }
    }

    fn reveal_picker_window(&self) {
        self.with_app_handle(|app| {
            let _ = show_picker_window(app);
        });
    }

    fn hide_picker_window(&self) {
        self.with_app_handle(|app| {
            if let Some(window) = app.get_webview_window(PICKER_WINDOW_LABEL) {
                let _ = window.hide();
            }
        });
    }

    fn persist_locked_state(&self, state: &PersistedState) {
        if let Err(error) = self.store.save(state) {
            self.set_status(format!("Failed to save config: {error}"));
        }
    }

    fn process_incoming_url(&self, url: Url, source_app: Option<&str>) {
        let route = {
            let guard = match self.state.lock() {
                Ok(guard) => guard,
                Err(_) => {
                    self.set_status("Failed to lock app state for URL routing");
                    return;
                }
            };

            let hidden_apps = Self::hidden_app_set(&guard);
            let visible_browsers: Vec<BrowserConfig> = guard
                .configured_browsers
                .iter()
                .filter(|browser| !hidden_apps.contains(&browser.app_id))
                .cloned()
                .collect();

            resolved_route(&url, &guard.routing_rules, &visible_browsers, source_app).map(|route| {
                (
                    route.browser.clone(),
                    route.rule.use_private_mode,
                    route.browser.app_id.clone(),
                )
            })
        };

        if let Some((browser, use_private_mode, browser_app_id)) = route {
            match open_url_with_browser(&url, &browser, use_private_mode) {
                Ok(()) => {
                    if let Some(host) = url.host_str() {
                        if let Ok(mut guard) = self.state.lock() {
                            guard.record_domain(host, &browser_app_id);
                            self.persist_locked_state(&guard);
                        }
                    }
                    self.set_status(format!("Auto-routed {} to {}", url, browser.name));
                    self.hide_picker_window();
                }
                Err(error) => {
                    self.set_status(format!(
                        "Failed to open {} in {}: {error}",
                        url, browser.name
                    ));
                }
            }
            return;
        }

        if let Ok(mut pending) = self.pending_url.lock() {
            *pending = Some(url.to_string());
        }
        self.set_status(format!("No rule matched {}. Picker is ready.", url));
        self.reveal_picker_window();
    }

    fn drain_external_url_events(&self) {
        #[cfg(target_os = "macos")]
        {
            while let Some(event) = macos_url_events::take_pending_url_event() {
                let raw_url = event.url;
                let Ok(url) = Url::parse(&raw_url) else {
                    self.set_status(format!("Ignored malformed URL event: {raw_url}"));
                    continue;
                };

                if url.scheme() != "http" && url.scheme() != "https" {
                    self.set_status(format!("Ignored unsupported URL scheme: {url}"));
                    continue;
                }

                self.process_incoming_url(url, event.source_app_id.as_deref());
            }
        }
    }

    fn snapshot(&self) -> Result<AppSnapshot, String> {
        self.drain_external_url_events();

        let guard = self
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        let pending = self
            .pending_url
            .lock()
            .map_err(|_| "Failed to lock pending URL state".to_owned())?
            .clone();
        let status_line = self
            .status_line
            .lock()
            .map_err(|_| "Failed to lock status state".to_owned())?
            .clone();

        Ok(AppSnapshot {
            config_path: self.store.path().display().to_string(),
            has_completed_onboarding: guard.has_completed_onboarding,
            configured_browsers: guard.configured_browsers.clone(),
            routing_rules: guard.routing_rules.clone(),
            suggestions: guard.suggestions(DOMAIN_SUGGESTION_THRESHOLD),
            pending_url: pending,
            status_line,
            default_browser: self.default_browser_status(),
            suggested_browsers_path: self.suggested_browsers_path.clone(),
            suggested_rules_path: self.suggested_rules_path.clone(),
            hidden_app_ids: guard.hidden_app_ids.clone(),
        })
    }

    fn default_browser_status(&self) -> DefaultBrowserStatus {
        #[cfg(target_os = "macos")]
        {
            match read_default_browser_handlers() {
                Ok((http_handler, https_handler)) => {
                    let is_default = http_handler.as_deref() == Some(self.app_bundle_id.as_str())
                        && https_handler.as_deref() == Some(self.app_bundle_id.as_str());
                    DefaultBrowserStatus {
                        supported: true,
                        app_bundle_id: self.app_bundle_id.clone(),
                        http_handler,
                        https_handler,
                        is_default,
                        note: if is_default {
                            "Chowser Rust is currently the default browser for http and https."
                                .to_owned()
                        } else {
                            "Use 'Set as Default Browser' from onboarding to register Chowser Rust for http and https."
                                .to_owned()
                        },
                    }
                }
                Err(error) => DefaultBrowserStatus {
                    supported: true,
                    app_bundle_id: self.app_bundle_id.clone(),
                    http_handler: None,
                    https_handler: None,
                    is_default: false,
                    note: format!("Could not read default browser status: {error}"),
                },
            }
        }

        #[cfg(not(target_os = "macos"))]
        {
            DefaultBrowserStatus {
                supported: false,
                app_bundle_id: self.app_bundle_id.clone(),
                http_handler: None,
                https_handler: None,
                is_default: false,
                note: "Default-browser status checks are implemented for macOS in this build."
                    .to_owned(),
            }
        }
    }

    fn setup_default_browser_flow(&self) -> Result<CommandOutcome, String> {
        #[cfg(target_os = "macos")]
        {
            let mut notes = Vec::new();

            if let Some(bundle_path) = current_app_bundle_path() {
                let lsregister = Path::new(
                    "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                );
                if lsregister.exists() {
                    let status = Command::new(lsregister)
                        .arg("-f")
                        .arg(&bundle_path)
                        .status()
                        .map_err(|error| format!("Failed to run lsregister: {error}"))?;
                    if status.success() {
                        notes.push("Registered app with Launch Services".to_owned());
                    } else {
                        notes.push(
                            "Launch Services registration returned a non-zero status".to_owned(),
                        );
                    }
                } else {
                    notes.push("lsregister not found on this macOS installation".to_owned());
                }
            } else {
                notes.push("Could not locate .app bundle path from current executable".to_owned());
            }

            match set_default_browser_handlers(&self.app_bundle_id) {
                Ok(()) => notes.push("Set default handler for http and https".to_owned()),
                Err(error) => {
                    notes.push(format!("Could not set default handler directly: {error}"));
                }
            }

            let status = self.default_browser_status();
            let message = if status.is_default {
                "Chowser Rust is now set as the default browser."
            } else {
                "Default browser is still not set. Reopen onboarding and retry after relaunching the app from /Applications."
            };

            let full_message = format!("{} | {}", notes.join(". "), message);
            self.set_status(full_message.clone());

            Ok(CommandOutcome {
                ok: status.is_default,
                message: full_message,
                added: None,
            })
        }

        #[cfg(not(target_os = "macos"))]
        {
            let message = "Default browser setup workflow is implemented for macOS in this build.";
            self.set_status(message);
            Ok(CommandOutcome {
                ok: false,
                message: message.to_owned(),
                added: None,
            })
        }
    }
}

fn ensure_settings_window(app: &tauri::AppHandle) -> Result<WebviewWindow, String> {
    if let Some(window) = app.get_webview_window(SETTINGS_WINDOW_LABEL) {
        return Ok(window);
    }

    WebviewWindowBuilder::new(
        app,
        SETTINGS_WINDOW_LABEL,
        WebviewUrl::App("index.html?view=settings".into()),
    )
    .title("Chowser Rust Settings")
    .inner_size(1180.0, 820.0)
    .min_inner_size(900.0, 620.0)
    .resizable(true)
    .visible(true)
    .build()
    .map_err(|error| format!("Failed to create settings window: {error}"))
}

fn ensure_picker_window(app: &tauri::AppHandle) -> Result<WebviewWindow, String> {
    if let Some(window) = app.get_webview_window(PICKER_WINDOW_LABEL) {
        return Ok(window);
    }

    WebviewWindowBuilder::new(
        app,
        PICKER_WINDOW_LABEL,
        WebviewUrl::App("index.html?view=picker".into()),
    )
    .title("Choose Browser")
    .inner_size(760.0, 420.0)
    .min_inner_size(640.0, 320.0)
    .resizable(true)
    .always_on_top(true)
    .skip_taskbar(true)
    .visible(false)
    .build()
    .map_err(|error| format!("Failed to create picker window: {error}"))
}

fn show_settings_window(app: &tauri::AppHandle) -> Result<(), String> {
    let window = ensure_settings_window(app)?;
    window
        .show()
        .map_err(|error| format!("Failed to show settings window: {error}"))?;
    let _ = window.unminimize();
    let _ = window.set_focus();
    Ok(())
}

fn show_picker_window(app: &tauri::AppHandle) -> Result<(), String> {
    let window = ensure_picker_window(app)?;
    window
        .show()
        .map_err(|error| format!("Failed to show picker window: {error}"))?;
    let _ = window.unminimize();
    let _ = window.set_focus();
    Ok(())
}

fn queue_clipboard_url(
    app: &tauri::AppHandle,
    runtime_state: &AppRuntimeState,
) -> Result<(), String> {
    let clipboard = app
        .clipboard()
        .read_text()
        .map_err(|error| format!("Failed to read clipboard: {error}"))?;
    let trimmed = clipboard.trim();
    if trimmed.is_empty() {
        return Err("Clipboard is empty".to_owned());
    }
    let url = parse_http_url(trimmed)
        .map_err(|error| format!("Clipboard content is not a valid HTTP(S) URL: {error}"))?;
    runtime_state.process_incoming_url(url, None);
    Ok(())
}

fn setup_tray_icon(
    app: &tauri::AppHandle,
    runtime_state: Arc<AppRuntimeState>,
) -> Result<(), String> {
    let open_settings = MenuItem::with_id(
        app,
        TRAY_MENU_OPEN_SETTINGS,
        "Open Settings",
        true,
        None::<&str>,
    )
    .map_err(|error| format!("Failed to create tray menu item: {error}"))?;
    let open_picker = MenuItem::with_id(
        app,
        TRAY_MENU_OPEN_PICKER,
        "Open Picker",
        true,
        None::<&str>,
    )
    .map_err(|error| format!("Failed to create tray menu item: {error}"))?;
    let set_default = MenuItem::with_id(
        app,
        TRAY_MENU_SET_DEFAULT,
        "Set as Default Browser",
        true,
        None::<&str>,
    )
    .map_err(|error| format!("Failed to create tray menu item: {error}"))?;
    let open_clipboard_url = MenuItem::with_id(
        app,
        TRAY_MENU_OPEN_CLIPBOARD_URL,
        "Open URL from Clipboard",
        true,
        None::<&str>,
    )
    .map_err(|error| format!("Failed to create tray menu item: {error}"))?;
    let separator = PredefinedMenuItem::separator(app)
        .map_err(|error| format!("Failed to create tray separator: {error}"))?;
    let quit = MenuItem::with_id(app, TRAY_MENU_QUIT, "Quit", true, None::<&str>)
        .map_err(|error| format!("Failed to create tray menu item: {error}"))?;

    let tray_menu = Menu::with_items(
        app,
        &[
            &open_settings,
            &open_picker,
            &open_clipboard_url,
            &set_default,
            &separator,
            &quit,
        ],
    )
    .map_err(|error| format!("Failed to build tray menu: {error}"))?;

    let icon = tauri::image::Image::from_bytes(include_bytes!("../icons/icon.png"))
        .map_err(|error| format!("Failed to load tray icon: {error}"))?;

    TrayIconBuilder::with_id(TRAY_ID)
        .icon(icon)
        .icon_as_template(true)
        .menu(&tray_menu)
        .show_menu_on_left_click(true)
        .tooltip("Chowser Rust")
        .on_menu_event(move |app, event| {
            if event.id() == TRAY_MENU_OPEN_SETTINGS {
                let _ = show_settings_window(app);
            } else if event.id() == TRAY_MENU_OPEN_PICKER {
                let _ = show_picker_window(app);
            } else if event.id() == TRAY_MENU_SET_DEFAULT {
                let _ = runtime_state.setup_default_browser_flow();
                let _ = show_settings_window(app);
            } else if event.id() == TRAY_MENU_OPEN_CLIPBOARD_URL {
                match queue_clipboard_url(app, &runtime_state) {
                    Ok(()) => {}
                    Err(error) => runtime_state.set_status(error),
                }
            } else if event.id() == TRAY_MENU_QUIT {
                app.exit(0);
            }
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                let _ = show_settings_window(tray.app_handle());
            }
        })
        .build(app)
        .map_err(|error| format!("Failed to build tray icon: {error}"))?;

    Ok(())
}

#[tauri::command]
fn refresh_snapshot(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
) -> Result<AppSnapshot, String> {
    state.snapshot()
}

#[tauri::command]
fn import_browsers_from_path(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    path: String,
) -> Result<CommandOutcome, String> {
    let path = if path.trim().is_empty() {
        PathBuf::from(state.suggested_browsers_path.clone())
    } else {
        PathBuf::from(path.trim())
    };

    let payload = state
        .store
        .import_payload_from(&path)
        .map_err(|error| format!("Import failed: {error}"))?;

    let added = {
        let mut guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;

        let added = match payload {
            ImportPayload::FullState(imported) => {
                merge_imported_browsers(&mut guard, imported.configured_browsers)
            }
            ImportPayload::Browsers(browsers) => merge_imported_browsers(&mut guard, browsers),
            ImportPayload::Rules(_) => {
                return Err(
                    "Selected file contains rules JSON. Use rules import instead.".to_owned(),
                )
            }
        };

        if added > 0 {
            state.persist_locked_state(&guard);
        }

        added
    };

    let message = format!("Imported {added} browser(s) from {}", path.display());
    state.set_status(message.clone());

    Ok(CommandOutcome {
        ok: true,
        message,
        added: Some(added),
    })
}

#[tauri::command]
fn import_rules_from_path(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    path: String,
) -> Result<CommandOutcome, String> {
    let path = if path.trim().is_empty() {
        PathBuf::from(state.suggested_rules_path.clone())
    } else {
        PathBuf::from(path.trim())
    };

    let payload = state
        .store
        .import_payload_from(&path)
        .map_err(|error| format!("Import failed: {error}"))?;

    let added = {
        let mut guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;

        let added = match payload {
            ImportPayload::FullState(imported) => {
                merge_imported_rules(&mut guard, imported.routing_rules)
            }
            ImportPayload::Rules(rules) => merge_imported_rules(&mut guard, rules),
            ImportPayload::Browsers(_) => {
                return Err(
                    "Selected file contains browsers JSON. Use browsers import instead.".to_owned(),
                )
            }
        };

        if added > 0 {
            state.persist_locked_state(&guard);
        }

        added
    };

    let message = format!("Imported {added} rule(s) from {}", path.display());
    state.set_status(message.clone());

    Ok(CommandOutcome {
        ok: true,
        message,
        added: Some(added),
    })
}

#[tauri::command]
fn export_browsers_to_path(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    path: String,
) -> Result<CommandOutcome, String> {
    let target_path = if path.trim().is_empty() {
        PathBuf::from(state.suggested_browsers_path.clone())
    } else {
        PathBuf::from(path.trim())
    };

    let browsers = {
        let guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        guard.configured_browsers.clone()
    };

    state
        .store
        .export_browsers_to(&target_path, &browsers)
        .map_err(|error| format!("Export failed: {error}"))?;

    let message = format!("Exported browsers to {}", target_path.display());
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn export_rules_to_path(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    path: String,
) -> Result<CommandOutcome, String> {
    let target_path = if path.trim().is_empty() {
        PathBuf::from(state.suggested_rules_path.clone())
    } else {
        PathBuf::from(path.trim())
    };

    let rules = {
        let guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        guard.routing_rules.clone()
    };

    state
        .store
        .export_rules_to(&target_path, &rules)
        .map_err(|error| format!("Export failed: {error}"))?;

    let message = format!("Exported rules to {}", target_path.display());
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn export_full_config_to_path(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    path: String,
) -> Result<CommandOutcome, String> {
    let target_path = if path.trim().is_empty() {
        let home = env::var("HOME").unwrap_or_else(|_| String::new());
        if home.is_empty() {
            PathBuf::from("chowser-multiplatform-config.json")
        } else {
            PathBuf::from(home)
                .join("Documents")
                .join("chowser-multiplatform-config.json")
        }
    } else {
        PathBuf::from(path.trim())
    };

    let persisted = {
        let guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        guard.clone()
    };

    state
        .store
        .export_to(&target_path, &persisted)
        .map_err(|error| format!("Export failed: {error}"))?;

    let message = format!("Exported full config to {}", target_path.display());
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn detect_browsers(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
) -> Result<CommandOutcome, String> {
    let discovered = {
        let guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        let hidden_apps = AppRuntimeState::hidden_app_set(&guard);
        detect_installed_browsers(&guard.configured_browsers)
            .into_iter()
            .filter(|browser| !hidden_apps.contains(&browser.app_id))
            .collect::<Vec<_>>()
    };

    let added = {
        let mut guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        let added = merge_imported_browsers(&mut guard, discovered);
        if added > 0 {
            state.persist_locked_state(&guard);
        }
        added
    };

    let message = if added == 0 {
        "No new browsers discovered".to_owned()
    } else {
        format!("Added {added} discovered browser(s)")
    };
    state.set_status(message.clone());

    Ok(CommandOutcome {
        ok: true,
        message,
        added: Some(added),
    })
}

#[tauri::command]
fn set_hidden_app(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    app_id: String,
    hidden: bool,
) -> Result<CommandOutcome, String> {
    let app_id = app_id.trim().to_owned();
    if app_id.is_empty() {
        return Err("App ID is required".to_owned());
    }

    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;

    if hidden {
        if !guard.hidden_app_ids.iter().any(|value| value == &app_id) {
            guard.hidden_app_ids.push(app_id.clone());
            guard.hidden_app_ids.sort();
        }
    } else {
        guard.hidden_app_ids.retain(|value| value != &app_id);
    }

    state.persist_locked_state(&guard);
    let message = if hidden {
        format!("Hidden app {app_id}")
    } else {
        format!("Unhid app {app_id}")
    };
    state.set_status(message.clone());

    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn choose_browser_for_pending_url(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    browser_id: String,
    private_mode: bool,
) -> Result<CommandOutcome, String> {
    let selected_id = Uuid::parse_str(browser_id.trim())
        .map_err(|error| format!("Invalid browser id: {error}"))?;

    let browser = {
        let guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        let selected = guard
            .configured_browsers
            .iter()
            .find(|browser| browser.id == selected_id)
            .cloned();
        if let Some(ref browser) = selected {
            if guard
                .hidden_app_ids
                .iter()
                .any(|value| value == &browser.app_id)
            {
                return Err("Selected browser is hidden".to_owned());
            }
        }
        selected
    }
    .ok_or_else(|| "Selected browser was not found".to_owned())?;

    let pending_url = {
        let mut pending = state
            .pending_url
            .lock()
            .map_err(|_| "Failed to lock pending URL state".to_owned())?;
        pending.take()
    }
    .ok_or_else(|| "No pending URL available for picker".to_owned())?;

    let url = Url::parse(&pending_url).map_err(|error| format!("Invalid pending URL: {error}"))?;

    if let Err(error) = open_url_with_browser(&url, &browser, private_mode) {
        if let Ok(mut pending) = state.pending_url.lock() {
            *pending = Some(url.to_string());
        }
        return Err(format!("Failed to open URL with {}: {error}", browser.name));
    }

    if let Some(host) = url.host_str() {
        if let Ok(mut guard) = state.state.lock() {
            guard.record_domain(host, &browser.app_id);
            state.persist_locked_state(&guard);
        }
    }

    let message = format!("Opened {} in {}", url, browser.name);
    state.set_status(message.clone());
    state.hide_picker_window();

    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn queue_test_url_for_picker(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    url: String,
) -> Result<CommandOutcome, String> {
    let normalized = parse_http_url(url.trim())
        .map_err(|error| format!("Invalid URL for picker test: {error}"))?
        .to_string();

    {
        let mut pending = state
            .pending_url
            .lock()
            .map_err(|_| "Failed to lock pending URL state".to_owned())?;
        *pending = Some(normalized.clone());
    }

    let message = format!("Queued test URL for picker: {normalized}");
    state.set_status(message.clone());
    state.reveal_picker_window();

    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn set_onboarding_completed(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    completed: bool,
) -> Result<CommandOutcome, String> {
    {
        let mut guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        guard.has_completed_onboarding = completed;
        state.persist_locked_state(&guard);
    }

    let message = if completed {
        "Onboarding completed".to_owned()
    } else {
        "Onboarding reopened".to_owned()
    };
    state.set_status(message.clone());

    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn setup_default_browser(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
) -> Result<CommandOutcome, String> {
    state.setup_default_browser_flow()
}

#[tauri::command]
fn add_browser(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    name: String,
    app_id: String,
    executable: String,
    shortcut_key: String,
    profile: Option<String>,
    custom_arguments: Option<String>,
) -> Result<CommandOutcome, String> {
    let name = name.trim().to_owned();
    let app_id = app_id.trim().to_owned();
    if name.is_empty() {
        return Err("Browser name is required".to_owned());
    }
    if app_id.is_empty() {
        return Err("Browser app ID is required".to_owned());
    }
    let executable = optional_trimmed(&executable).unwrap_or_else(default_executable_for_platform);
    let browser = BrowserConfig::new(
        name.clone(),
        app_id,
        executable,
        shortcut_key,
        profile.as_deref().and_then(optional_trimmed),
        custom_arguments.as_deref().and_then(optional_trimmed),
    );
    let added = {
        let mut guard = state
            .state
            .lock()
            .map_err(|_| "Failed to lock app state".to_owned())?;
        let result = guard.add_browser(browser);
        if result {
            state.persist_locked_state(&guard);
        }
        result
    };
    if !added {
        return Err("A browser with that app ID and profile already exists".to_owned());
    }
    let message = format!("Browser '{name}' added");
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: Some(1),
    })
}

#[tauri::command]
fn update_browser(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    id: String,
    name: String,
    app_id: String,
    executable: String,
    shortcut_key: String,
    profile: Option<String>,
    custom_arguments: Option<String>,
) -> Result<CommandOutcome, String> {
    let browser_id = Uuid::parse_str(id.trim()).map_err(|e| format!("Invalid browser id: {e}"))?;
    let name = name.trim().to_owned();
    let app_id = app_id.trim().to_owned();
    if name.is_empty() {
        return Err("Browser name is required".to_owned());
    }
    if app_id.is_empty() {
        return Err("Browser app ID is required".to_owned());
    }
    let executable = optional_trimmed(&executable).unwrap_or_else(default_executable_for_platform);

    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;

    if !guard.configured_browsers.iter().any(|b| b.id == browser_id) {
        return Err("Browser not found".to_owned());
    }

    // Guard against creating a duplicate identity on a different browser
    let new_identity = format!(
        "{}|{}",
        app_id,
        profile.as_deref().map(str::trim).unwrap_or("")
    );
    if guard
        .configured_browsers
        .iter()
        .any(|b| b.id != browser_id && b.identity() == new_identity)
    {
        return Err("A browser with that app ID and profile already exists".to_owned());
    }

    let resolved_shortcut = {
        match normalize_shortcut(&shortcut_key) {
            Some(s) => {
                let conflict = guard
                    .configured_browsers
                    .iter()
                    .any(|b| b.id != browser_id && b.shortcut_key == s);
                if conflict {
                    guard.next_available_shortcut()
                } else {
                    s
                }
            }
            None => guard.next_available_shortcut(),
        }
    };

    if let Some(browser) = guard
        .configured_browsers
        .iter_mut()
        .find(|b| b.id == browser_id)
    {
        browser.name = name.clone();
        browser.app_id = app_id;
        browser.executable = executable;
        browser.shortcut_key = resolved_shortcut;
        browser.profile = profile.as_deref().and_then(optional_trimmed);
        browser.custom_arguments = custom_arguments.as_deref().and_then(optional_trimmed);
    }

    state.persist_locked_state(&guard);
    let message = format!("Browser '{name}' updated");
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn delete_browser(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    id: String,
) -> Result<CommandOutcome, String> {
    let browser_id = Uuid::parse_str(id.trim()).map_err(|e| format!("Invalid browser id: {e}"))?;

    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;

    let len_before = guard.configured_browsers.len();
    guard.configured_browsers.retain(|b| b.id != browser_id);

    if guard.configured_browsers.len() == len_before {
        return Err("Browser not found".to_owned());
    }

    state.persist_locked_state(&guard);
    let message = "Browser deleted".to_owned();
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn reorder_browsers(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    ordered_ids: Vec<String>,
) -> Result<CommandOutcome, String> {
    let ids: Vec<Uuid> = ordered_ids
        .iter()
        .map(|id| Uuid::parse_str(id.trim()).map_err(|e| format!("Invalid browser id: {e}")))
        .collect::<Result<Vec<_>, _>>()?;

    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;

    let mut reordered: Vec<BrowserConfig> = Vec::with_capacity(guard.configured_browsers.len());
    for id in &ids {
        if let Some(browser) = guard.configured_browsers.iter().find(|b| b.id == *id) {
            reordered.push(browser.clone());
        }
    }
    for browser in &guard.configured_browsers {
        if !ids.contains(&browser.id) {
            reordered.push(browser.clone());
        }
    }
    guard.configured_browsers = reordered;
    state.persist_locked_state(&guard);

    let message = "Browsers reordered".to_owned();
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn add_rule(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    name: String,
    host_pattern: String,
    path_prefix: Option<String>,
    browser_app_id: String,
    profile: Option<String>,
    source_app_id: Option<String>,
    use_private_mode: bool,
    is_enabled: Option<bool>,
) -> Result<CommandOutcome, String> {
    let normalized_host = routing::normalized_host_pattern(&host_pattern);
    if !routing::is_valid_host_pattern(&normalized_host) {
        return Err(format!("Invalid host pattern: '{host_pattern}'"));
    }
    let browser_app_id = browser_app_id.trim().to_owned();
    if browser_app_id.is_empty() {
        return Err("Browser app ID is required".to_owned());
    }
    let rule_name = if name.trim().is_empty() {
        normalized_host.clone()
    } else {
        name.trim().to_owned()
    };
    let mut rule = BrowserRoutingRule::new(
        rule_name.clone(),
        normalized_host,
        routing::normalized_path_prefix(path_prefix.as_deref()),
        browser_app_id,
        profile.as_deref().and_then(optional_trimmed),
        source_app_id.as_deref().and_then(optional_trimmed),
        use_private_mode,
    );
    rule.is_enabled = is_enabled.unwrap_or(true);
    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;
    guard.routing_rules.push(rule);
    state.persist_locked_state(&guard);
    let message = format!("Rule '{rule_name}' added");
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: Some(1),
    })
}

#[tauri::command]
fn update_rule(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    id: String,
    name: String,
    host_pattern: String,
    path_prefix: Option<String>,
    browser_app_id: String,
    profile: Option<String>,
    source_app_id: Option<String>,
    use_private_mode: bool,
    is_enabled: bool,
) -> Result<CommandOutcome, String> {
    let rule_id = Uuid::parse_str(id.trim()).map_err(|e| format!("Invalid rule id: {e}"))?;
    let normalized_host = routing::normalized_host_pattern(&host_pattern);
    if !routing::is_valid_host_pattern(&normalized_host) {
        return Err(format!("Invalid host pattern: '{host_pattern}'"));
    }
    let browser_app_id = browser_app_id.trim().to_owned();
    if browser_app_id.is_empty() {
        return Err("Browser app ID is required".to_owned());
    }
    let rule_name = if name.trim().is_empty() {
        normalized_host.clone()
    } else {
        name.trim().to_owned()
    };
    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;
    let rule = guard
        .routing_rules
        .iter_mut()
        .find(|r| r.id == rule_id)
        .ok_or_else(|| "Rule not found".to_owned())?;
    rule.name = rule_name.clone();
    rule.host_pattern = normalized_host;
    rule.path_prefix = routing::normalized_path_prefix(path_prefix.as_deref());
    rule.browser_app_id = browser_app_id;
    rule.profile = profile.as_deref().and_then(optional_trimmed);
    rule.source_app_id = source_app_id.as_deref().and_then(optional_trimmed);
    rule.use_private_mode = use_private_mode;
    rule.is_enabled = is_enabled;
    state.persist_locked_state(&guard);
    let message = format!("Rule '{rule_name}' updated");
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn delete_rule(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    id: String,
) -> Result<CommandOutcome, String> {
    let rule_id = Uuid::parse_str(id.trim()).map_err(|e| format!("Invalid rule id: {e}"))?;

    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;

    let len_before = guard.routing_rules.len();
    guard.routing_rules.retain(|r| r.id != rule_id);

    if guard.routing_rules.len() == len_before {
        return Err("Rule not found".to_owned());
    }

    state.persist_locked_state(&guard);
    let message = "Rule deleted".to_owned();
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn toggle_rule(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    id: String,
    is_enabled: bool,
) -> Result<CommandOutcome, String> {
    let rule_id = Uuid::parse_str(id.trim()).map_err(|e| format!("Invalid rule id: {e}"))?;

    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;

    let rule = guard
        .routing_rules
        .iter_mut()
        .find(|r| r.id == rule_id)
        .ok_or_else(|| "Rule not found".to_owned())?;
    rule.is_enabled = is_enabled;

    state.persist_locked_state(&guard);
    let message = if is_enabled {
        "Rule enabled".to_owned()
    } else {
        "Rule disabled".to_owned()
    };
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn reorder_rules(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    ordered_ids: Vec<String>,
) -> Result<CommandOutcome, String> {
    let ids: Vec<Uuid> = ordered_ids
        .iter()
        .map(|id| Uuid::parse_str(id.trim()).map_err(|e| format!("Invalid rule id: {e}")))
        .collect::<Result<Vec<_>, _>>()?;

    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;

    let mut reordered: Vec<BrowserRoutingRule> = Vec::with_capacity(guard.routing_rules.len());
    for id in &ids {
        if let Some(rule) = guard.routing_rules.iter().find(|r| r.id == *id) {
            reordered.push(rule.clone());
        }
    }
    for rule in &guard.routing_rules {
        if !ids.contains(&rule.id) {
            reordered.push(rule.clone());
        }
    }
    guard.routing_rules = reordered;
    state.persist_locked_state(&guard);

    let message = "Rules reordered".to_owned();
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

#[tauri::command]
fn create_rule_for_pending_url(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    name: String,
    browser_app_id: String,
    profile: Option<String>,
    use_private_mode: bool,
) -> Result<CommandOutcome, String> {
    let pending_url = {
        let guard = state
            .pending_url
            .lock()
            .map_err(|_| "Failed to lock pending URL state".to_owned())?;
        guard
            .clone()
            .ok_or_else(|| "No pending URL to create rule for".to_owned())?
    };

    let url = Url::parse(&pending_url).map_err(|e| format!("Invalid pending URL: {e}"))?;
    let host = url.host_str().ok_or_else(|| "URL has no host".to_owned())?;
    let normalized_host = routing::normalized_host_pattern(host);
    if !routing::is_valid_host_pattern(&normalized_host) {
        return Err(format!("Cannot create rule for host: '{host}'"));
    }
    let browser_app_id = browser_app_id.trim().to_owned();
    if browser_app_id.is_empty() {
        return Err("Browser app ID is required".to_owned());
    }
    let rule_name = if name.trim().is_empty() {
        normalized_host.clone()
    } else {
        name.trim().to_owned()
    };
    let rule = BrowserRoutingRule::new(
        rule_name.clone(),
        normalized_host,
        None,
        browser_app_id,
        profile.as_deref().and_then(optional_trimmed),
        None,
        use_private_mode,
    );
    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;
    guard.routing_rules.push(rule);
    state.persist_locked_state(&guard);
    let message = format!("Rule '{rule_name}' created");
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: Some(1),
    })
}

#[tauri::command]
fn dismiss_suggestion(
    state: State<'_, std::sync::Arc<AppRuntimeState>>,
    domain: String,
    app_id: String,
) -> Result<CommandOutcome, String> {
    let domain = domain.trim().to_lowercase();
    let app_id = app_id.trim().to_owned();

    let mut guard = state
        .state
        .lock()
        .map_err(|_| "Failed to lock app state".to_owned())?;

    if let Some(counts) = guard.domain_frequency.get_mut(&domain) {
        counts.remove(&app_id);
        if counts.is_empty() {
            guard.domain_frequency.remove(&domain);
        }
    }

    state.persist_locked_state(&guard);
    let message = format!("Suggestion dismissed for {domain}");
    state.set_status(message.clone());
    Ok(CommandOutcome {
        ok: true,
        message,
        added: None,
    })
}

fn merge_imported_browsers(state: &mut PersistedState, browsers: Vec<BrowserConfig>) -> usize {
    let mut added = 0usize;

    for mut browser in browsers {
        if browser.name.trim().is_empty() || browser.app_id.trim().is_empty() {
            continue;
        }

        if browser.executable.trim().is_empty() {
            browser.executable = default_executable_for_platform();
        }

        browser.shortcut_key = normalize_shortcut(&browser.shortcut_key)
            .unwrap_or_else(|| state.next_available_shortcut());
        browser.name = browser.name.trim().to_owned();
        browser.app_id = browser.app_id.trim().to_owned();
        browser.profile = browser.profile.as_deref().and_then(optional_trimmed);
        browser.custom_arguments = browser
            .custom_arguments
            .as_deref()
            .and_then(optional_trimmed);

        if state.add_browser(browser) {
            added += 1;
        }
    }

    added
}

fn merge_imported_rules(state: &mut PersistedState, rules: Vec<BrowserRoutingRule>) -> usize {
    let mut added = 0usize;
    let mut existing_ids: std::collections::HashSet<Uuid> =
        state.routing_rules.iter().map(|rule| rule.id).collect();

    for mut rule in rules {
        let normalized_host = routing::normalized_host_pattern(&rule.host_pattern);
        if !routing::is_valid_host_pattern(&normalized_host) {
            continue;
        }

        if existing_ids.contains(&rule.id) {
            continue;
        }

        rule.host_pattern = normalized_host;
        rule.path_prefix = routing::normalized_path_prefix(rule.path_prefix.as_deref());
        rule.name = if rule.name.trim().is_empty() {
            rule.host_pattern.clone()
        } else {
            rule.name.trim().to_owned()
        };
        rule.browser_app_id = rule.browser_app_id.trim().to_owned();
        rule.profile = rule.profile.as_deref().and_then(optional_trimmed);
        rule.source_app_id = rule.source_app_id.as_deref().and_then(optional_trimmed);

        existing_ids.insert(rule.id);
        state.routing_rules.push(rule);
        added += 1;
    }

    added
}

fn optional_trimmed(input: &str) -> Option<String> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}

fn default_executable_for_platform() -> String {
    #[cfg(target_os = "macos")]
    {
        return "/usr/bin/open".to_owned();
    }
    #[cfg(target_os = "linux")]
    {
        return "xdg-open".to_owned();
    }
    #[cfg(target_os = "windows")]
    {
        return "msedge.exe".to_owned();
    }
    #[allow(unreachable_code)]
    "browser".to_owned()
}

fn parse_cli() -> Result<CliOptions> {
    let mut options = CliOptions::default();
    let mut args = env::args().skip(1);

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--help" | "-h" => {
                print_usage();
                std::process::exit(0);
            }
            "--url" => {
                let value = args.next().context("--url requires a value")?;
                options.url = Some(parse_http_url(&value)?);
            }
            "--source-app" => {
                let value = args
                    .next()
                    .context("--source-app requires an app identifier value")?;
                let trimmed = value.trim();
                if !trimmed.is_empty() {
                    options.source_app_id = Some(trimmed.to_owned());
                }
            }
            value if value.starts_with("http://") || value.starts_with("https://") => {
                options.url = Some(parse_http_url(value)?);
            }
            value if value.starts_with("-psn_") => {
                let _ = value;
            }
            _ => {}
        }
    }

    Ok(options)
}

fn parse_http_url(value: &str) -> Result<Url> {
    let url = Url::parse(value).with_context(|| format!("invalid URL: {value}"))?;
    if url.scheme() != "http" && url.scheme() != "https" {
        bail!("only http/https URLs are supported: {value}");
    }
    Ok(url)
}

fn print_usage() {
    println!(
        "chowser-multiplatform [--source-app <id>] [--url <http(s)://...>] [http(s)://...]\n\
         \n\
         Examples:\n\
         chowser-multiplatform --url https://example.com\n\
         chowser-multiplatform --source-app com.slack.Slack --url https://example.com"
    );
}

fn current_bundle_identifier() -> String {
    #[cfg(target_os = "macos")]
    {
        if let Some(bundle_id) = bundle_identifier_from_info_plist() {
            return bundle_id;
        }
    }

    "in.sreerams.chowser-test".to_owned()
}

#[cfg(target_os = "macos")]
fn current_app_bundle_path() -> Option<PathBuf> {
    let current_exe = env::current_exe().ok()?;
    current_exe
        .ancestors()
        .find(|path| {
            path.extension()
                .and_then(|ext| ext.to_str())
                .map(|ext| ext.eq_ignore_ascii_case("app"))
                .unwrap_or(false)
        })
        .map(Path::to_path_buf)
}

#[cfg(target_os = "macos")]
fn bundle_identifier_from_info_plist() -> Option<String> {
    let bundle_path = current_app_bundle_path()?;
    let info_plist = bundle_path.join("Contents").join("Info.plist");
    let plist = plist::Value::from_file(info_plist).ok()?;
    let dictionary = plist.as_dictionary()?;
    dictionary
        .get("CFBundleIdentifier")
        .and_then(plist::Value::as_string)
        .map(ToOwned::to_owned)
}

#[cfg(target_os = "macos")]
#[link(name = "CoreServices", kind = "framework")]
unsafe extern "C" {
    fn LSSetDefaultHandlerForURLScheme(
        in_url_scheme: CFStringRef,
        in_handler_bundle_id: CFStringRef,
    ) -> i32;
    fn LSCopyDefaultHandlerForURLScheme(in_url_scheme: CFStringRef) -> CFStringRef;
}

#[cfg(target_os = "macos")]
fn set_default_browser_handlers(bundle_id: &str) -> Result<()> {
    set_default_handler_for_url_scheme("http", bundle_id)?;
    set_default_handler_for_url_scheme("https", bundle_id)?;
    Ok(())
}

#[cfg(target_os = "macos")]
fn set_default_handler_for_url_scheme(scheme: &str, bundle_id: &str) -> Result<()> {
    let scheme_cf = CFString::new(scheme);
    let bundle_cf = CFString::new(bundle_id);

    let status = unsafe {
        LSSetDefaultHandlerForURLScheme(
            scheme_cf.as_concrete_TypeRef(),
            bundle_cf.as_concrete_TypeRef(),
        )
    };
    if status != 0 {
        bail!(
            "LaunchServices returned status {} while setting {} handler to {}",
            status,
            scheme,
            bundle_id
        );
    }

    Ok(())
}

#[cfg(target_os = "macos")]
fn copy_default_handler_for_url_scheme(scheme: &str) -> Result<Option<String>> {
    let scheme_cf = CFString::new(scheme);
    let handler_ref = unsafe { LSCopyDefaultHandlerForURLScheme(scheme_cf.as_concrete_TypeRef()) };

    if handler_ref.is_null() {
        return Ok(None);
    }

    let handler = unsafe { CFString::wrap_under_create_rule(handler_ref) };
    Ok(Some(handler.to_string()))
}

#[cfg(target_os = "macos")]
fn read_default_browser_handlers() -> Result<(Option<String>, Option<String>)> {
    let http_handler = copy_default_handler_for_url_scheme("http")?;
    let https_handler = copy_default_handler_for_url_scheme("https")?;
    if http_handler.is_some() || https_handler.is_some() {
        return Ok((http_handler, https_handler));
    }

    let home = env::var("HOME").context("HOME environment variable is missing")?;
    let plist_path = PathBuf::from(home)
        .join("Library")
        .join("Preferences")
        .join("com.apple.LaunchServices")
        .join("com.apple.launchservices.secure.plist");

    if !plist_path.exists() {
        return Ok((None, None));
    }

    let root = plist::Value::from_file(&plist_path)
        .with_context(|| format!("failed to parse {}", plist_path.display()))?;
    let handlers = root
        .as_dictionary()
        .and_then(|dict| dict.get("LSHandlers"))
        .and_then(plist::Value::as_array)
        .ok_or_else(|| anyhow!("LSHandlers array missing from LaunchServices plist"))?;

    let mut fallback_http_handler = None;
    let mut fallback_https_handler = None;

    for entry in handlers {
        let Some(handler) = entry.as_dictionary() else {
            continue;
        };

        let Some(scheme) = handler
            .get("LSHandlerURLScheme")
            .and_then(plist::Value::as_string)
        else {
            continue;
        };

        let role_handler = handler
            .get("LSHandlerRoleAll")
            .or_else(|| handler.get("LSHandlerRoleViewer"))
            .and_then(plist::Value::as_string)
            .map(ToOwned::to_owned);

        match scheme {
            "http" => fallback_http_handler = role_handler,
            "https" => fallback_https_handler = role_handler,
            _ => {}
        }
    }

    Ok((fallback_http_handler, fallback_https_handler))
}

fn main() -> Result<()> {
    #[cfg(target_os = "macos")]
    macos_url_events::install_url_event_handler()
        .context("failed to install macOS URL event handler")?;

    let cli = parse_cli()?;
    let store = ConfigStore::new();
    let mut state = store
        .load_or_default()
        .context("failed to load config state")?;
    state.version = APP_SCHEMA_VERSION;
    state.ensure_defaults();

    let runtime_state = Arc::new(AppRuntimeState::new(store, state));

    if let Some(url) = cli.url {
        runtime_state.process_incoming_url(url, cli.source_app_id.as_deref());
    }

    #[cfg(target_os = "macos")]
    {
        let worker_state = runtime_state.clone();
        std::thread::spawn(move || loop {
            worker_state.drain_external_url_events();
            std::thread::sleep(std::time::Duration::from_millis(320));
        });
    }

    tauri::Builder::default()
        .plugin(tauri_plugin_autostart::init(
            MacosLauncher::LaunchAgent,
            None::<Vec<&'static str>>,
        ))
        .plugin(tauri_plugin_clipboard_manager::init())
        .setup({
            let runtime_state = runtime_state.clone();
            move |app| {
                let app_handle = app.handle().clone();
                runtime_state.set_app_handle(app_handle.clone());

                if let Err(error) = ensure_settings_window(&app_handle) {
                    eprintln!("{error}");
                }
                if let Err(error) = ensure_picker_window(&app_handle) {
                    eprintln!("{error}");
                }
                if let Err(error) = setup_tray_icon(&app_handle, runtime_state.clone()) {
                    eprintln!("{error}");
                }
                if let Err(error) = show_settings_window(&app_handle) {
                    eprintln!("{error}");
                }

                let has_pending_url = runtime_state
                    .pending_url
                    .lock()
                    .ok()
                    .and_then(|pending| pending.clone())
                    .is_some();
                if has_pending_url {
                    if let Err(error) = show_picker_window(&app_handle) {
                        eprintln!("{error}");
                    }
                }

                Ok(())
            }
        })
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                let label = window.label();
                if label == SETTINGS_WINDOW_LABEL || label == PICKER_WINDOW_LABEL {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .enable_macos_default_menu(false)
        .manage(runtime_state.clone())
        .invoke_handler(tauri::generate_handler![
            refresh_snapshot,
            import_browsers_from_path,
            import_rules_from_path,
            export_browsers_to_path,
            export_rules_to_path,
            export_full_config_to_path,
            detect_browsers,
            set_hidden_app,
            choose_browser_for_pending_url,
            queue_test_url_for_picker,
            set_onboarding_completed,
            setup_default_browser,
            add_browser,
            update_browser,
            delete_browser,
            reorder_browsers,
            add_rule,
            update_rule,
            delete_rule,
            toggle_rule,
            reorder_rules,
            create_rule_for_pending_url,
            dismiss_suggestion,
        ])
        .run(tauri::generate_context!())
        .map_err(|error| anyhow!("failed to run Tauri application: {error}"))?;

    Ok(())
}
