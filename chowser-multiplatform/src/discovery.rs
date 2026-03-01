use crate::models::BrowserConfig;
use std::collections::HashSet;
#[cfg(target_os = "macos")]
use std::path::{Path, PathBuf};
#[cfg(target_os = "macos")]
use std::{env, fs};

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
    const CANDIDATES: [(&str, &str, &str, Option<&str>, Option<&str>); 9] = [
        ("Safari", "com.apple.Safari", "Safari", None, None),
        (
            "Google Chrome",
            "com.google.Chrome",
            "Google Chrome",
            Some("Library/Application Support/Google/Chrome/Local State"),
            None,
        ),
        (
            "Brave",
            "com.brave.Browser",
            "Brave Browser",
            Some("Library/Application Support/BraveSoftware/Brave-Browser/Local State"),
            None,
        ),
        (
            "Microsoft Edge",
            "com.microsoft.edgemac",
            "Microsoft Edge",
            Some("Library/Application Support/Microsoft Edge/Local State"),
            None,
        ),
        (
            "Firefox",
            "org.mozilla.firefox",
            "Firefox",
            None,
            Some("Library/Application Support/Firefox/profiles.ini"),
        ),
        (
            "Vivaldi",
            "com.vivaldi.Vivaldi",
            "Vivaldi",
            Some("Library/Application Support/Vivaldi/Local State"),
            None,
        ),
        ("Arc", "company.thebrowser.Browser", "Arc", None, None),
        (
            "Zen Browser",
            "app.zen-browser.zen",
            "Zen Browser",
            None,
            None,
        ),
        (
            "Chromium",
            "org.chromium.Chromium",
            "Chromium",
            Some("Library/Application Support/Chromium/Local State"),
            None,
        ),
    ];

    for (name, app_id, app_name, chromium_state_path, firefox_profiles_path) in CANDIDATES {
        let Some(app_path) = macos_app_path(app_name) else {
            continue;
        };

        let profile_entries = if let Some(relative_path) = chromium_state_path {
            chromium_profiles_from_local_state(relative_path)
        } else if let Some(relative_path) = firefox_profiles_path {
            firefox_profiles_from_ini(relative_path)
        } else {
            Vec::new()
        };

        if profile_entries.is_empty() {
            push_macos_browser(discovered, seen, name, app_id, &app_path, None, None);
            continue;
        }

        for (profile_label, profile_value) in profile_entries {
            let display_name = format!("{name} ({profile_label})");
            push_macos_browser(
                discovered,
                seen,
                &display_name,
                app_id,
                &app_path,
                Some(profile_value),
                None,
            );
        }
    }
}

#[cfg(target_os = "macos")]
fn push_macos_browser(
    discovered: &mut Vec<BrowserConfig>,
    seen: &mut HashSet<String>,
    name: &str,
    app_id: &str,
    app_path: &Path,
    profile: Option<String>,
    custom_arguments: Option<String>,
) {
    let custom_arguments = if profile.is_some() {
        custom_arguments
    } else {
        custom_arguments.or_else(|| Some(format!("-a \"{}\" {{url}}", app_path.display())))
    };
    let identity = format!("{}|{}", app_id, profile.as_deref().unwrap_or(""));
    if seen.insert(identity) {
        discovered.push(BrowserConfig::new(
            name.to_owned(),
            app_id.to_owned(),
            "/usr/bin/open".to_owned(),
            "1".to_owned(),
            profile,
            custom_arguments,
        ));
    }
}

#[cfg(target_os = "macos")]
fn chromium_profiles_from_local_state(relative_state_path: &str) -> Vec<(String, String)> {
    let Some(path) = home_join(relative_state_path) else {
        return Vec::new();
    };
    let Ok(contents) = fs::read_to_string(path) else {
        return Vec::new();
    };
    parse_chromium_profiles_from_local_state(&contents)
}

fn parse_chromium_profiles_from_local_state(contents: &str) -> Vec<(String, String)> {
    let Ok(json) = serde_json::from_str::<serde_json::Value>(contents) else {
        return Vec::new();
    };
    let Some(info_cache) = json
        .get("profile")
        .and_then(|profile| profile.get("info_cache"))
        .and_then(serde_json::Value::as_object)
    else {
        return Vec::new();
    };

    let mut profiles: Vec<(String, String)> = info_cache
        .iter()
        .map(|(directory, meta)| {
            let label = meta
                .get("name")
                .and_then(serde_json::Value::as_str)
                .filter(|value| !value.trim().is_empty())
                .unwrap_or(directory);
            (label.to_owned(), directory.to_owned())
        })
        .collect();
    profiles.sort_by(|a, b| a.0.to_lowercase().cmp(&b.0.to_lowercase()));
    profiles
}

#[cfg(target_os = "macos")]
fn firefox_profiles_from_ini(relative_ini_path: &str) -> Vec<(String, String)> {
    let Some(path) = home_join(relative_ini_path) else {
        return Vec::new();
    };
    let Ok(contents) = fs::read_to_string(path) else {
        return Vec::new();
    };

    parse_firefox_profiles_ini(&contents)
}

fn parse_firefox_profiles_ini(contents: &str) -> Vec<(String, String)> {
    let mut results = Vec::new();
    let mut current_name: Option<String> = None;
    let mut in_profile_section = false;

    for raw_line in contents.lines() {
        let line = raw_line.trim();
        if line.starts_with('[') && line.ends_with(']') {
            if in_profile_section {
                if let Some(name) = current_name.take() {
                    results.push((name.clone(), name));
                }
            }
            in_profile_section = line
                .strip_prefix('[')
                .and_then(|value| value.strip_suffix(']'))
                .map(|value| value.starts_with("Profile"))
                .unwrap_or(false);
            current_name = None;
            continue;
        }
        if !in_profile_section {
            continue;
        }
        if let Some(name) = line.strip_prefix("Name=") {
            let trimmed = name.trim();
            if !trimmed.is_empty() {
                current_name = Some(trimmed.to_owned());
            }
        }
    }

    if in_profile_section {
        if let Some(name) = current_name.take() {
            results.push((name.clone(), name));
        }
    }

    results.sort_by(|a, b| a.0.to_lowercase().cmp(&b.0.to_lowercase()));
    results
}

#[cfg(target_os = "macos")]
fn home_join(relative_path: &str) -> Option<PathBuf> {
    env::var("HOME")
        .ok()
        .map(PathBuf::from)
        .map(|home| home.join(relative_path))
}

#[cfg(test)]
mod tests {
    use super::{parse_chromium_profiles_from_local_state, parse_firefox_profiles_ini};

    #[test]
    fn parses_chromium_profiles_from_local_state_json() {
        let json = r#"{
          "profile": {
            "info_cache": {
              "Default": { "name": "Personal" },
              "Profile 1": { "name": "Work" }
            }
          }
        }"#;
        let profiles = parse_chromium_profiles_from_local_state(json);
        assert_eq!(
            profiles,
            vec![
                ("Personal".to_owned(), "Default".to_owned()),
                ("Work".to_owned(), "Profile 1".to_owned())
            ]
        );
    }

    #[test]
    fn parses_firefox_profiles_ini_names() {
        let ini = r#"
[Profile0]
Name=default-release
IsRelative=1
Path=Profiles/abcd.default-release

[Profile1]
Name=work
IsRelative=1
Path=Profiles/efgh.work
"#;
        let profiles = parse_firefox_profiles_ini(ini);
        assert_eq!(
            profiles,
            vec![
                ("default-release".to_owned(), "default-release".to_owned()),
                ("work".to_owned(), "work".to_owned())
            ]
        );
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
