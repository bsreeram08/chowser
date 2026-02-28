use crate::models::{
    fresh_setup_browsers, normalize_shortcut, BrowserConfig, BrowserRoutingRule, PersistedState,
    APP_SCHEMA_VERSION,
};
use anyhow::{bail, Context, Result};
use directories::ProjectDirs;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

#[derive(Debug, Clone)]
pub enum ImportPayload {
    FullState(PersistedState),
    Browsers(Vec<BrowserConfig>),
    Rules(Vec<BrowserRoutingRule>),
}

#[derive(Debug, Clone, Deserialize)]
struct LegacyBrowserImport {
    #[serde(default)]
    id: Option<Uuid>,
    #[serde(default)]
    name: String,
    #[serde(rename = "bundleId")]
    bundle_id: String,
    #[serde(rename = "shortcutKey", default)]
    shortcut_key: String,
    #[serde(default)]
    profile: Option<String>,
    #[serde(rename = "customArguments", default)]
    custom_arguments: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
struct LegacyRuleImport {
    #[serde(default)]
    id: Option<Uuid>,
    #[serde(default)]
    name: String,
    #[serde(rename = "hostPattern")]
    host_pattern: String,
    #[serde(rename = "pathPrefix", default)]
    path_prefix: Option<String>,
    #[serde(rename = "browserBundleId")]
    browser_bundle_id: String,
    #[serde(default)]
    profile: Option<String>,
    #[serde(rename = "isEnabled", default = "default_true")]
    is_enabled: bool,
    #[serde(rename = "sourceAppBundleId", default)]
    source_app_bundle_id: Option<String>,
    #[serde(rename = "usePrivateMode", default)]
    use_private_mode: bool,
}

#[derive(Debug, Clone, Serialize)]
struct LegacyBrowserExport {
    id: Uuid,
    name: String,
    #[serde(rename = "bundleId")]
    bundle_id: String,
    #[serde(rename = "shortcutKey")]
    shortcut_key: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    profile: Option<String>,
    #[serde(rename = "customArguments", skip_serializing_if = "Option::is_none")]
    custom_arguments: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
struct LegacyRuleExport {
    id: Uuid,
    name: String,
    #[serde(rename = "hostPattern")]
    host_pattern: String,
    #[serde(rename = "pathPrefix", skip_serializing_if = "Option::is_none")]
    path_prefix: Option<String>,
    #[serde(rename = "browserBundleId")]
    browser_bundle_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    profile: Option<String>,
    #[serde(rename = "isEnabled")]
    is_enabled: bool,
    #[serde(rename = "sourceAppBundleId", skip_serializing_if = "Option::is_none")]
    source_app_bundle_id: Option<String>,
    #[serde(rename = "usePrivateMode")]
    use_private_mode: bool,
}

#[derive(Debug, Clone)]
pub struct ConfigStore {
    path: PathBuf,
}

impl ConfigStore {
    pub fn new() -> Self {
        let path = if let Some(project_dirs) =
            ProjectDirs::from("in", "sreerams", "chowser-multiplatform")
        {
            project_dirs.config_dir().join("config.json")
        } else {
            PathBuf::from(".chowser-multiplatform").join("config.json")
        };

        Self { path }
    }

    pub fn path(&self) -> &Path {
        self.path.as_path()
    }

    pub fn load_or_default(&self) -> Result<PersistedState> {
        if !self.path.exists() {
            return Ok(PersistedState {
                version: APP_SCHEMA_VERSION,
                configured_browsers: fresh_setup_browsers(),
                ..Default::default()
            });
        }

        let bytes = fs::read(&self.path)
            .with_context(|| format!("failed to read config file at {}", self.path.display()))?;
        let mut state: PersistedState = serde_json::from_slice(&bytes)
            .with_context(|| format!("failed to parse JSON config at {}", self.path.display()))?;
        state.ensure_defaults();
        Ok(state)
    }

    pub fn save(&self, state: &PersistedState) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent).with_context(|| {
                format!("failed to create config directory {}", parent.display())
            })?;
        }

        let payload =
            serde_json::to_vec_pretty(state).context("failed to serialize config JSON")?;
        fs::write(&self.path, payload)
            .with_context(|| format!("failed to write config at {}", self.path.display()))?;
        Ok(())
    }

    pub fn import_payload_from(&self, source_path: &Path) -> Result<ImportPayload> {
        let bytes = fs::read(source_path)
            .with_context(|| format!("failed to read import file {}", source_path.display()))?;

        if let Ok(mut state) = serde_json::from_slice::<PersistedState>(&bytes) {
            state.ensure_defaults();
            return Ok(ImportPayload::FullState(state));
        }

        if let Ok(browsers) = serde_json::from_slice::<Vec<BrowserConfig>>(&bytes) {
            return Ok(ImportPayload::Browsers(browsers));
        }

        if let Ok(rules) = serde_json::from_slice::<Vec<BrowserRoutingRule>>(&bytes) {
            return Ok(ImportPayload::Rules(rules));
        }

        if let Ok(legacy_browsers) = serde_json::from_slice::<Vec<LegacyBrowserImport>>(&bytes) {
            let browsers = legacy_browsers
                .into_iter()
                .map(BrowserConfig::from_legacy)
                .collect();
            return Ok(ImportPayload::Browsers(browsers));
        }

        if let Ok(legacy_rules) = serde_json::from_slice::<Vec<LegacyRuleImport>>(&bytes) {
            let rules = legacy_rules
                .into_iter()
                .map(BrowserRoutingRule::from_legacy)
                .collect();
            return Ok(ImportPayload::Rules(rules));
        }

        bail!(
            "failed to parse JSON import from {}. Expected full config, browsers array, or rules array.",
            source_path.display()
        )
    }

    pub fn export_to(&self, target_path: &Path, state: &PersistedState) -> Result<()> {
        write_json_file(target_path, state, "failed to serialize JSON export")
    }

    pub fn export_browsers_to(&self, target_path: &Path, browsers: &[BrowserConfig]) -> Result<()> {
        let payload: Vec<LegacyBrowserExport> = browsers
            .iter()
            .map(LegacyBrowserExport::from_browser)
            .collect();
        write_json_file(
            target_path,
            &payload,
            "failed to serialize browser export JSON",
        )
    }

    pub fn export_rules_to(&self, target_path: &Path, rules: &[BrowserRoutingRule]) -> Result<()> {
        let payload: Vec<LegacyRuleExport> =
            rules.iter().map(LegacyRuleExport::from_rule).collect();
        write_json_file(
            target_path,
            &payload,
            "failed to serialize rules export JSON",
        )
    }
}

impl BrowserConfig {
    fn from_legacy(legacy: LegacyBrowserImport) -> Self {
        let normalized_name =
            normalize_non_empty(legacy.name).unwrap_or_else(|| "Browser".to_owned());
        let bundle_id = legacy.bundle_id.trim().to_owned();
        let profile = normalize_non_empty_option(legacy.profile);
        let shortcut = normalize_shortcut(&legacy.shortcut_key).unwrap_or_else(|| "1".to_owned());
        let executable = inferred_executable_for_bundle_id(&bundle_id);
        let custom_arguments = normalize_non_empty_option(legacy.custom_arguments)
            .map(|custom_args| wrap_legacy_custom_arguments_for_platform(&bundle_id, &custom_args));

        Self {
            id: legacy.id.unwrap_or_else(Uuid::new_v4),
            name: normalized_name,
            app_id: bundle_id,
            executable,
            shortcut_key: shortcut,
            profile,
            custom_arguments,
        }
    }
}

impl BrowserRoutingRule {
    fn from_legacy(legacy: LegacyRuleImport) -> Self {
        let host_pattern = legacy.host_pattern.trim().to_owned();
        let normalized_name =
            normalize_non_empty(legacy.name).unwrap_or_else(|| host_pattern.clone());

        Self {
            id: legacy.id.unwrap_or_else(Uuid::new_v4),
            name: normalized_name,
            host_pattern,
            path_prefix: normalize_non_empty_option(legacy.path_prefix),
            browser_app_id: legacy.browser_bundle_id.trim().to_owned(),
            profile: normalize_non_empty_option(legacy.profile),
            is_enabled: legacy.is_enabled,
            source_app_id: normalize_non_empty_option(legacy.source_app_bundle_id),
            use_private_mode: legacy.use_private_mode,
        }
    }
}

impl LegacyBrowserExport {
    fn from_browser(browser: &BrowserConfig) -> Self {
        Self {
            id: browser.id,
            name: browser.name.clone(),
            bundle_id: browser.app_id.clone(),
            shortcut_key: browser.shortcut_key.clone(),
            profile: browser.profile.clone(),
            custom_arguments: export_custom_arguments(
                &browser.app_id,
                browser.custom_arguments.clone(),
            ),
        }
    }
}

impl LegacyRuleExport {
    fn from_rule(rule: &BrowserRoutingRule) -> Self {
        Self {
            id: rule.id,
            name: rule.name.clone(),
            host_pattern: rule.host_pattern.clone(),
            path_prefix: rule.path_prefix.clone(),
            browser_bundle_id: rule.browser_app_id.clone(),
            profile: rule.profile.clone(),
            is_enabled: rule.is_enabled,
            source_app_bundle_id: rule.source_app_id.clone(),
            use_private_mode: rule.use_private_mode,
        }
    }
}

fn write_json_file<T: Serialize>(
    target_path: &Path,
    payload: &T,
    error_message: &str,
) -> Result<()> {
    if let Some(parent) = target_path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create export directory {}", parent.display()))?;
    }

    let bytes = serde_json::to_vec_pretty(payload).with_context(|| error_message.to_owned())?;
    fs::write(target_path, bytes)
        .with_context(|| format!("failed to write export file {}", target_path.display()))?;
    Ok(())
}

fn normalize_non_empty(value: String) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}

fn normalize_non_empty_option(value: Option<String>) -> Option<String> {
    value.and_then(normalize_non_empty)
}

fn default_true() -> bool {
    true
}

fn inferred_executable_for_bundle_id(bundle_id: &str) -> String {
    #[cfg(target_os = "macos")]
    {
        let _ = bundle_id;
        "/usr/bin/open".to_owned()
    }

    #[cfg(target_os = "linux")]
    {
        let normalized = bundle_id.to_lowercase();
        if normalized.contains("chrome") {
            "google-chrome".to_owned()
        } else if normalized.contains("brave") {
            "brave-browser".to_owned()
        } else if normalized.contains("edge") {
            "microsoft-edge".to_owned()
        } else if normalized.contains("firefox") || normalized.contains("zen") {
            "firefox".to_owned()
        } else if normalized.contains("vivaldi") {
            "vivaldi".to_owned()
        } else if normalized.contains("opera") {
            "opera".to_owned()
        } else {
            "xdg-open".to_owned()
        }
    }

    #[cfg(target_os = "windows")]
    {
        let normalized = bundle_id.to_lowercase();
        if normalized.contains("chrome") {
            "chrome.exe".to_owned()
        } else if normalized.contains("brave") {
            "brave.exe".to_owned()
        } else if normalized.contains("edge") {
            "msedge.exe".to_owned()
        } else if normalized.contains("firefox") || normalized.contains("zen") {
            "firefox.exe".to_owned()
        } else if normalized.contains("vivaldi") {
            "vivaldi.exe".to_owned()
        } else if normalized.contains("opera") {
            "opera.exe".to_owned()
        } else {
            bundle_id.to_owned()
        }
    }

    #[cfg(not(any(target_os = "macos", target_os = "linux", target_os = "windows")))]
    {
        bundle_id.to_owned()
    }
}

fn wrap_legacy_custom_arguments_for_platform(bundle_id: &str, custom_args: &str) -> String {
    #[cfg(target_os = "macos")]
    {
        let mut args = custom_args.trim().to_owned();
        if !args.contains("{url}") {
            args.push_str(" {url}");
        }
        format!("-b {bundle_id} --args {args}")
    }

    #[cfg(not(target_os = "macos"))]
    {
        let _ = bundle_id;
        custom_args.to_owned()
    }
}

fn export_custom_arguments(_bundle_id: &str, custom_arguments: Option<String>) -> Option<String> {
    let custom_arguments = custom_arguments?;
    let trimmed = custom_arguments.trim().to_owned();
    if trimmed.is_empty() {
        return None;
    }

    #[cfg(target_os = "macos")]
    {
        let prefix = format!("-b {_bundle_id} --args ");
        if let Some(stripped) = trimmed.strip_prefix(&prefix) {
            return normalize_non_empty(stripped.to_owned());
        }
    }

    Some(trimmed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn write_temp_json(filename_prefix: &str, content: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time should be valid")
            .as_nanos();
        let path = std::env::temp_dir().join(format!("{filename_prefix}-{nanos}.json"));
        fs::write(&path, content).expect("temp JSON write should succeed");
        path
    }

    #[test]
    fn imports_legacy_browser_array() {
        let json = r#"
[
  {
    "id": "A386FF08-CC58-4351-91DA-7ED3668EFA20",
    "bundleId": "app.zen-browser.zen",
    "name": "Zen - Default (release)",
    "shortcutKey": "1",
    "profile": "Default (release)"
  }
]
"#;
        let path = write_temp_json("chowser-legacy-browsers", json);
        let store = ConfigStore::new();

        let result = store
            .import_payload_from(&path)
            .expect("legacy browser import should parse");
        let _ = fs::remove_file(&path);

        match result {
            ImportPayload::Browsers(browsers) => {
                assert_eq!(browsers.len(), 1);
                assert_eq!(browsers[0].app_id, "app.zen-browser.zen");
                assert_eq!(browsers[0].profile.as_deref(), Some("Default (release)"));
                assert!(!browsers[0].executable.is_empty());
            }
            _ => panic!("expected browsers payload"),
        }
    }

    #[test]
    fn imports_legacy_rules_array() {
        let json = r#"
[
  {
    "hostPattern": "github.com",
    "usePrivateMode": false,
    "browserBundleId": "company.thebrowser.dia",
    "name": "Github",
    "id": "905EE215-FDFD-4A57-B92B-C3C18FA502EF",
    "pathPrefix": "/bsreeram08",
    "isEnabled": true
  }
]
"#;
        let path = write_temp_json("chowser-legacy-rules", json);
        let store = ConfigStore::new();

        let result = store
            .import_payload_from(&path)
            .expect("legacy rules import should parse");
        let _ = fs::remove_file(&path);

        match result {
            ImportPayload::Rules(rules) => {
                assert_eq!(rules.len(), 1);
                assert_eq!(rules[0].browser_app_id, "company.thebrowser.dia");
                assert_eq!(rules[0].host_pattern, "github.com");
                assert_eq!(rules[0].path_prefix.as_deref(), Some("/bsreeram08"));
            }
            _ => panic!("expected rules payload"),
        }
    }
}
