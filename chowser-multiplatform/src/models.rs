use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use uuid::Uuid;

pub const APP_SCHEMA_VERSION: u32 = 1;
pub const DOMAIN_MAX_ENTRIES: usize = 100;
pub const DOMAIN_SUGGESTION_THRESHOLD: u32 = 30;
const SUPPORTED_SHORTCUTS: [&str; 9] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"];

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BrowserConfig {
    pub id: Uuid,
    pub name: String,
    pub app_id: String,
    pub executable: String,
    pub shortcut_key: String,
    pub profile: Option<String>,
    pub custom_arguments: Option<String>,
}

impl BrowserConfig {
    pub fn new(
        name: String,
        app_id: String,
        executable: String,
        shortcut_key: String,
        profile: Option<String>,
        custom_arguments: Option<String>,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            app_id,
            executable,
            shortcut_key,
            profile,
            custom_arguments,
        }
    }

    pub fn identity(&self) -> String {
        format!("{}|{}", self.app_id, self.profile.as_deref().unwrap_or(""))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BrowserRoutingRule {
    pub id: Uuid,
    pub name: String,
    pub host_pattern: String,
    pub path_prefix: Option<String>,
    pub browser_app_id: String,
    pub profile: Option<String>,
    #[serde(default = "default_true")]
    pub is_enabled: bool,
    pub source_app_id: Option<String>,
    #[serde(default)]
    pub use_private_mode: bool,
}

impl BrowserRoutingRule {
    #[allow(dead_code)]
    pub fn new(
        name: String,
        host_pattern: String,
        path_prefix: Option<String>,
        browser_app_id: String,
        profile: Option<String>,
        source_app_id: Option<String>,
        use_private_mode: bool,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            host_pattern,
            path_prefix,
            browser_app_id,
            profile,
            is_enabled: true,
            source_app_id,
            use_private_mode,
        }
    }
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PersistedState {
    #[serde(default = "default_schema_version")]
    pub version: u32,
    #[serde(default)]
    pub has_completed_onboarding: bool,
    #[serde(default)]
    pub configured_browsers: Vec<BrowserConfig>,
    #[serde(default)]
    pub routing_rules: Vec<BrowserRoutingRule>,
    #[serde(default)]
    pub hidden_app_ids: Vec<String>,
    #[serde(default)]
    pub domain_frequency: HashMap<String, HashMap<String, u32>>,
}

impl PersistedState {
    pub fn ensure_defaults(&mut self) {
        if self.version == 0 {
            self.version = APP_SCHEMA_VERSION;
        }
        if self.configured_browsers.is_empty() {
            self.configured_browsers = fresh_setup_browsers();
        }
    }

    pub fn next_available_shortcut(&self) -> String {
        let used: HashSet<&str> = self
            .configured_browsers
            .iter()
            .map(|browser| browser.shortcut_key.as_str())
            .collect();

        for key in SUPPORTED_SHORTCUTS {
            if !used.contains(key) {
                return key.to_owned();
            }
        }

        "9".to_owned()
    }

    pub fn add_browser(&mut self, mut browser: BrowserConfig) -> bool {
        if self
            .configured_browsers
            .iter()
            .any(|existing| existing.identity() == browser.identity())
        {
            return false;
        }

        let normalized_shortcut = normalize_shortcut(&browser.shortcut_key)
            .unwrap_or_else(|| self.next_available_shortcut());
        if self
            .configured_browsers
            .iter()
            .any(|existing| existing.shortcut_key == normalized_shortcut)
        {
            browser.shortcut_key = self.next_available_shortcut();
        } else {
            browser.shortcut_key = normalized_shortcut;
        }

        self.configured_browsers.push(browser);
        true
    }

    pub fn record_domain(&mut self, domain: &str, app_id: &str) {
        let normalized_domain = domain.trim().to_lowercase();
        let normalized_app_id = app_id.trim().to_owned();

        if normalized_domain.is_empty() || normalized_app_id.is_empty() {
            return;
        }

        let counts = self.domain_frequency.entry(normalized_domain).or_default();
        *counts.entry(normalized_app_id).or_insert(0) += 1;

        if self.domain_frequency.len() > DOMAIN_MAX_ENTRIES {
            let mut keys: Vec<String> = self.domain_frequency.keys().cloned().collect();
            keys.sort();
            if let Some(first_key) = keys.first() {
                self.domain_frequency.remove(first_key);
            }
        }
    }

    pub fn suggestions(&self, threshold: u32) -> Vec<DomainSuggestion> {
        let mut suggestions = Vec::new();

        for (domain, app_counts) in &self.domain_frequency {
            for (app_id, count) in app_counts {
                if *count >= threshold {
                    suggestions.push(DomainSuggestion {
                        domain: domain.clone(),
                        app_id: app_id.clone(),
                        count: *count,
                    });
                }
            }
        }

        suggestions.sort_by(|a, b| {
            b.count
                .cmp(&a.count)
                .then_with(|| a.domain.cmp(&b.domain))
                .then_with(|| a.app_id.cmp(&b.app_id))
        });
        suggestions
    }
}

fn default_schema_version() -> u32 {
    APP_SCHEMA_VERSION
}

pub fn normalize_shortcut(input: &str) -> Option<String> {
    let trimmed = input.trim();
    if SUPPORTED_SHORTCUTS.contains(&trimmed) {
        Some(trimmed.to_owned())
    } else {
        None
    }
}

pub fn fresh_setup_browsers() -> Vec<BrowserConfig> {
    #[cfg(target_os = "windows")]
    {
        vec![BrowserConfig::new(
            "Microsoft Edge".to_owned(),
            "com.microsoft.edge".to_owned(),
            "msedge.exe".to_owned(),
            "1".to_owned(),
            None,
            None,
        )]
    }

    #[cfg(target_os = "linux")]
    {
        vec![BrowserConfig::new(
            "Firefox".to_owned(),
            "org.mozilla.firefox".to_owned(),
            "firefox".to_owned(),
            "1".to_owned(),
            None,
            None,
        )]
    }

    #[cfg(target_os = "macos")]
    {
        vec![BrowserConfig::new(
            "Safari".to_owned(),
            "com.apple.Safari".to_owned(),
            "/usr/bin/open".to_owned(),
            "1".to_owned(),
            None,
            Some("-a /System/Applications/Safari.app {url}".to_owned()),
        )]
    }

    #[cfg(not(any(target_os = "windows", target_os = "linux", target_os = "macos")))]
    {
        vec![BrowserConfig::new(
            "Browser".to_owned(),
            "browser.default".to_owned(),
            "xdg-open".to_owned(),
            "1".to_owned(),
            None,
            None,
        )]
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DomainSuggestion {
    pub domain: String,
    pub app_id: String,
    pub count: u32,
}
