use crate::models::{BrowserConfig, BrowserRoutingRule};
use url::Url;

pub struct ResolvedRoute<'a> {
    pub rule: &'a BrowserRoutingRule,
    pub browser: &'a BrowserConfig,
}

pub fn resolved_route<'a>(
    url: &Url,
    rules: &'a [BrowserRoutingRule],
    browsers: &'a [BrowserConfig],
    current_source_app: Option<&str>,
) -> Option<ResolvedRoute<'a>> {
    let host = url.host_str()?.to_lowercase();
    let path = if url.path().is_empty() {
        "/"
    } else {
        url.path()
    };

    for rule in rules.iter().filter(|rule| rule.is_enabled) {
        if !host_matches(&host, &rule.host_pattern) {
            continue;
        }

        if !path_matches(path, rule.path_prefix.as_deref()) {
            continue;
        }

        if let Some(source_app_id) = rule.source_app_id.as_deref() {
            if source_app_id != current_source_app.unwrap_or_default() {
                continue;
            }
        }

        if let Some(browser) = browsers.iter().find(|browser| {
            browser.app_id == rule.browser_app_id && browser.profile == rule.profile
        }) {
            return Some(ResolvedRoute { rule, browser });
        }
    }

    None
}

pub fn normalized_host_pattern(pattern: &str) -> String {
    let mut normalized = pattern.trim().to_lowercase();
    if normalized.is_empty() {
        return String::new();
    }

    if let Some(scheme_idx) = normalized.find("://") {
        normalized = normalized[(scheme_idx + 3)..].to_owned();
    }

    if let Some(slash_idx) = normalized.find('/') {
        normalized = normalized[..slash_idx].to_owned();
    }

    if let Some(stripped) = normalized.strip_prefix("*.") {
        let mut suffix = stripped.to_owned();
        if let Some(colon_idx) = suffix.find(':') {
            suffix = suffix[..colon_idx].to_owned();
        }
        while suffix.ends_with('.') {
            suffix.pop();
        }
        return if suffix.is_empty() {
            String::new()
        } else {
            format!("*.{suffix}")
        };
    }

    if let Some(colon_idx) = normalized.find(':') {
        normalized = normalized[..colon_idx].to_owned();
    }

    while normalized.ends_with('.') {
        normalized.pop();
    }

    normalized
}

pub fn is_valid_host_pattern(pattern: &str) -> bool {
    if pattern.is_empty() || pattern.contains(' ') || pattern.contains('/') {
        return false;
    }

    if let Some(suffix) = pattern.strip_prefix("*.") {
        return !suffix.is_empty() && !suffix.contains('*') && is_valid_host_name(suffix);
    }

    !pattern.contains('*') && is_valid_host_name(pattern)
}

pub fn normalized_path_prefix(prefix: Option<&str>) -> Option<String> {
    let value = prefix?.trim();
    if value.is_empty() {
        return None;
    }

    if value.starts_with('/') {
        Some(value.to_owned())
    } else {
        Some(format!("/{value}"))
    }
}

pub fn host_matches(host: &str, pattern: &str) -> bool {
    let normalized_pattern = normalized_host_pattern(pattern);
    if normalized_pattern.is_empty() {
        return false;
    }

    if let Some(suffix) = normalized_pattern.strip_prefix("*.") {
        return host == suffix || host.ends_with(&format!(".{suffix}"));
    }

    host == normalized_pattern
}

pub fn path_matches(path: &str, prefix: Option<&str>) -> bool {
    let normalized_prefix = normalized_path_prefix(prefix);
    match normalized_prefix {
        Some(prefix) => path.to_lowercase().starts_with(&prefix.to_lowercase()),
        None => true,
    }
}

fn is_valid_host_name(host: &str) -> bool {
    let labels: Vec<&str> = host.split('.').collect();
    if labels.is_empty() {
        return false;
    }

    for label in labels {
        if label.is_empty() {
            return false;
        }
        if label.starts_with('-') || label.ends_with('-') {
            return false;
        }
        if !label
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || ch == '-')
        {
            return false;
        }
    }

    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{BrowserConfig, BrowserRoutingRule};
    use pretty_assertions::assert_eq;

    fn browser(app_id: &str, profile: Option<&str>) -> BrowserConfig {
        BrowserConfig::new(
            "Browser".to_owned(),
            app_id.to_owned(),
            "browser".to_owned(),
            "1".to_owned(),
            profile.map(ToOwned::to_owned),
            None,
        )
    }

    #[test]
    fn host_pattern_normalization_strips_scheme_and_port() {
        let actual = normalized_host_pattern("https://WWW.Example.com:443/path");
        assert_eq!(actual, "www.example.com");
    }

    #[test]
    fn wildcard_host_matching_supports_subdomains() {
        assert!(host_matches("docs.example.com", "*.example.com"));
        assert!(host_matches("example.com", "*.example.com"));
        assert!(!host_matches("example.org", "*.example.com"));
    }

    #[test]
    fn path_prefix_normalization_adds_leading_slash() {
        let actual = normalized_path_prefix(Some("docs/api"));
        assert_eq!(actual, Some("/docs/api".to_owned()));
    }

    #[test]
    fn resolved_route_matches_source_app_when_required() {
        let browsers = vec![browser("com.google.chrome", Some("Profile 1"))];
        let rules = vec![BrowserRoutingRule::new(
            "Docs".to_owned(),
            "*.example.com".to_owned(),
            Some("/docs".to_owned()),
            "com.google.chrome".to_owned(),
            Some("Profile 1".to_owned()),
            Some("com.slack.Slack".to_owned()),
            false,
        )];

        let url = Url::parse("https://example.com/docs/getting-started").expect("valid URL");
        let matched = resolved_route(&url, &rules, &browsers, Some("com.slack.Slack"));
        assert!(matched.is_some());

        let not_matched = resolved_route(&url, &rules, &browsers, Some("com.microsoft.teams"));
        assert!(not_matched.is_none());
    }
}
