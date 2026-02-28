use crate::models::BrowserConfig;
use std::collections::HashSet;
#[cfg(target_os = "macos")]
use std::path::{Path, PathBuf};

pub fn detect_installed_browsers(existing: &[BrowserConfig]) -> Vec<BrowserConfig> {
    let existing_identities: HashSet<String> =
        existing.iter().map(BrowserConfig::identity).collect();
    let mut discovered: Vec<BrowserConfig> = Vec::new();

    #[cfg(target_os = "linux")]
    {
        let mut seen: HashSet<String> = HashSet::new();
        detect_linux(&mut discovered, &mut seen);
    }

    #[cfg(target_os = "windows")]
    {
        let mut seen: HashSet<String> = HashSet::new();
        detect_windows(&mut discovered, &mut seen);
    }

    #[cfg(target_os = "macos")]
    {
        let mut seen: HashSet<String> = HashSet::new();
        detect_macos(&mut discovered, &mut seen);
    }

    discovered.retain(|browser| !existing_identities.contains(&browser.identity()));

    let mut used_shortcuts: HashSet<String> = existing
        .iter()
        .map(|browser| browser.shortcut_key.clone())
        .collect();
    for browser in &mut discovered {
        let next_key = next_available_shortcut(&used_shortcuts);
        browser.shortcut_key = next_key.clone();
        used_shortcuts.insert(next_key);
    }

    discovered.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    discovered
}

fn next_available_shortcut(used: &HashSet<String>) -> String {
    for index in 1..=9 {
        let key = index.to_string();
        if !used.contains(&key) {
            return key;
        }
    }
    "9".to_owned()
}

#[cfg(target_os = "macos")]
fn detect_macos(discovered: &mut Vec<BrowserConfig>, seen: &mut HashSet<String>) {
    const CANDIDATES: [(&str, &str, &str); 9] = [
        ("Safari", "com.apple.Safari", "Safari"),
        ("Google Chrome", "com.google.Chrome", "Google Chrome"),
        ("Brave", "com.brave.Browser", "Brave Browser"),
        ("Microsoft Edge", "com.microsoft.edgemac", "Microsoft Edge"),
        ("Firefox", "org.mozilla.firefox", "Firefox"),
        ("Vivaldi", "com.vivaldi.Vivaldi", "Vivaldi"),
        ("Arc", "company.thebrowser.Browser", "Arc"),
        ("Zen Browser", "app.zen-browser.zen", "Zen Browser"),
        ("Chromium", "org.chromium.Chromium", "Chromium"),
    ];

    for (name, app_id, app_name) in CANDIDATES {
        let Some(app_path) = macos_app_path(app_name) else {
            continue;
        };

        let identity = format!("{app_id}|");
        if seen.insert(identity) {
            discovered.push(BrowserConfig::new(
                name.to_owned(),
                app_id.to_owned(),
                "/usr/bin/open".to_owned(),
                "1".to_owned(),
                None,
                Some(format!("-a \"{}\" {{url}}", app_path.display())),
            ));
        }
    }
}

#[cfg(target_os = "macos")]
fn macos_app_path(app_name: &str) -> Option<PathBuf> {
    let local_app = std::env::var("HOME")
        .ok()
        .map(|home| format!("{home}/Applications/{app_name}.app"));
    let mut candidates = vec![
        format!("/Applications/{app_name}.app"),
        format!("/System/Applications/{app_name}.app"),
    ];
    if let Some(local_app) = local_app {
        candidates.push(local_app);
    }

    for candidate in candidates {
        let path = Path::new(&candidate);
        if path.exists() {
            return Some(path.to_path_buf());
        }
    }

    None
}

#[cfg(target_os = "linux")]
fn detect_linux(discovered: &mut Vec<BrowserConfig>, seen: &mut HashSet<String>) {
    const CANDIDATES: [(&str, &str, [&str; 2]); 7] = [
        ("Firefox", "org.mozilla.firefox", ["firefox", "firefox-bin"]),
        (
            "Google Chrome",
            "com.google.chrome",
            ["google-chrome", "google-chrome-stable"],
        ),
        ("Chromium", "org.chromium", ["chromium", "chromium-browser"]),
        ("Brave", "com.brave.browser", ["brave-browser", "brave"]),
        (
            "Microsoft Edge",
            "com.microsoft.edge",
            ["microsoft-edge", "msedge"],
        ),
        (
            "Vivaldi",
            "com.vivaldi.browser",
            ["vivaldi", "vivaldi-stable"],
        ),
        ("Opera", "com.opera.browser", ["opera", "opera-stable"]),
    ];

    for (name, app_id, executables) in CANDIDATES {
        if let Some(executable) = executables
            .into_iter()
            .find_map(|candidate| which::which(candidate).ok())
        {
            let identity = format!("{app_id}|");
            if seen.insert(identity) {
                discovered.push(BrowserConfig::new(
                    name.to_owned(),
                    app_id.to_owned(),
                    executable.to_string_lossy().to_string(),
                    "1".to_owned(),
                    None,
                    None,
                ));
            }
        }
    }
}

#[cfg(target_os = "windows")]
fn detect_windows(discovered: &mut Vec<BrowserConfig>, seen: &mut HashSet<String>) {
    detect_windows_registry(discovered, seen);
    detect_windows_path(discovered, seen);
}

#[cfg(target_os = "windows")]
fn detect_windows_path(discovered: &mut Vec<BrowserConfig>, seen: &mut HashSet<String>) {
    const CANDIDATES: [(&str, &str, [&str; 1]); 6] = [
        ("Microsoft Edge", "com.microsoft.edge", ["msedge.exe"]),
        ("Google Chrome", "com.google.chrome", ["chrome.exe"]),
        ("Firefox", "org.mozilla.firefox", ["firefox.exe"]),
        ("Brave", "com.brave.browser", ["brave.exe"]),
        ("Vivaldi", "com.vivaldi.browser", ["vivaldi.exe"]),
        ("Opera", "com.opera.browser", ["opera.exe"]),
    ];

    for (name, app_id, executables) in CANDIDATES {
        if let Some(executable) = executables
            .into_iter()
            .find_map(|candidate| which::which(candidate).ok())
        {
            let identity = format!("{app_id}|");
            if seen.insert(identity) {
                discovered.push(BrowserConfig::new(
                    name.to_owned(),
                    app_id.to_owned(),
                    executable.to_string_lossy().to_string(),
                    "1".to_owned(),
                    None,
                    None,
                ));
            }
        }
    }
}

#[cfg(target_os = "windows")]
fn detect_windows_registry(discovered: &mut Vec<BrowserConfig>, seen: &mut HashSet<String>) {
    use winreg::enums::{HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE};
    use winreg::RegKey;

    const ROOT: &str = r"SOFTWARE\Clients\StartMenuInternet";
    let hives = [
        RegKey::predef(HKEY_CURRENT_USER),
        RegKey::predef(HKEY_LOCAL_MACHINE),
    ];

    for hive in hives {
        let Ok(root) = hive.open_subkey(ROOT) else {
            continue;
        };

        for key_name in root.enum_keys().flatten() {
            let browser_key_path = format!(r"{ROOT}\{key_name}");
            let command_key_path = format!(r"{browser_key_path}\shell\open\command");

            let executable = hive
                .open_subkey(&command_key_path)
                .ok()
                .and_then(|key| key.get_value::<String, _>("").ok())
                .and_then(|command| extract_executable(&command));
            let Some(executable) = executable else {
                continue;
            };

            let display_name = hive
                .open_subkey(&browser_key_path)
                .ok()
                .and_then(|key| key.get_value::<String, _>("").ok())
                .filter(|value| !value.trim().is_empty())
                .unwrap_or_else(|| friendly_name(&key_name));
            let app_id = normalize_windows_app_id(&key_name);
            let identity = format!("{app_id}|");

            if seen.insert(identity) {
                discovered.push(BrowserConfig::new(
                    display_name,
                    app_id,
                    executable,
                    "1".to_owned(),
                    None,
                    None,
                ));
            }
        }
    }
}

#[cfg(target_os = "windows")]
fn extract_executable(command: &str) -> Option<String> {
    let trimmed = command.trim();
    if trimmed.is_empty() {
        return None;
    }

    if let Some(stripped) = trimmed.strip_prefix('"') {
        let end = stripped.find('"')?;
        return Some(stripped[..end].to_owned());
    }

    Some(
        trimmed
            .split_whitespace()
            .next()
            .unwrap_or(trimmed)
            .to_owned(),
    )
}

#[cfg(target_os = "windows")]
fn normalize_windows_app_id(raw: &str) -> String {
    raw.to_lowercase().replace(' ', ".")
}

#[cfg(target_os = "windows")]
fn friendly_name(raw: &str) -> String {
    raw.replace('_', " ")
}
