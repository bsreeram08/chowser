use crate::models::BrowserConfig;
use anyhow::{Context, Result};
use std::process::Command;
use url::Url;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum BrowserFamily {
    Chromium,
    Firefox,
    Other,
}

pub fn open_url_with_browser(
    url: &Url,
    browser: &BrowserConfig,
    use_private_mode: bool,
) -> Result<()> {
    let args = launch_arguments(browser, url, use_private_mode);
    let mut command = Command::new(&browser.executable);
    command.args(args);

    command
        .spawn()
        .with_context(|| format!("failed to launch {}", browser.name))?;
    Ok(())
}

pub fn launch_arguments(browser: &BrowserConfig, url: &Url, use_private_mode: bool) -> Vec<String> {
    if let Some(custom_arguments) = browser.custom_arguments.as_deref() {
        if !custom_arguments.trim().is_empty() {
            let mut args = split_custom_args(custom_arguments);
            for arg in &mut args {
                *arg = arg
                    .replace("{profile}", browser.profile.as_deref().unwrap_or(""))
                    .replace("{url}", url.as_str());
            }
            args.retain(|arg| !arg.is_empty());
            if !custom_arguments.contains("{url}") {
                args.push(url.as_str().to_owned());
            }
            return args;
        }
    }

    if let Some(args) = launch_args_for_macos_bundle_open(browser, url, use_private_mode) {
        return args;
    }

    let family = browser_family(browser);
    let profile = browser.profile.as_deref();

    if use_private_mode && profile.is_none() {
        return match family {
            BrowserFamily::Chromium => vec!["--incognito".to_owned(), url.as_str().to_owned()],
            BrowserFamily::Firefox => vec!["-private-window".to_owned(), url.as_str().to_owned()],
            BrowserFamily::Other => vec![url.as_str().to_owned()],
        };
    }

    if let Some(profile_name) = profile {
        return match family {
            BrowserFamily::Chromium => {
                let mut args = Vec::new();
                if use_private_mode {
                    args.push("--incognito".to_owned());
                }
                args.push(format!("--profile-directory={profile_name}"));
                args.push(url.as_str().to_owned());
                args
            }
            BrowserFamily::Firefox => {
                let mut args = Vec::new();
                if use_private_mode {
                    args.push("-private-window".to_owned());
                }
                args.push("-P".to_owned());
                args.push(profile_name.to_owned());
                args.push(url.as_str().to_owned());
                args
            }
            BrowserFamily::Other => vec![url.as_str().to_owned()],
        };
    }

    vec![url.as_str().to_owned()]
}

fn launch_args_for_macos_bundle_open(
    browser: &BrowserConfig,
    url: &Url,
    use_private_mode: bool,
) -> Option<Vec<String>> {
    #[cfg(target_os = "macos")]
    {
        if browser.executable != "/usr/bin/open" {
            return None;
        }

        let family = browser_family(browser);
        let profile = browser.profile.as_deref();

        let mut app_args = Vec::new();

        if use_private_mode {
            match family {
                BrowserFamily::Chromium => app_args.push("--incognito".to_owned()),
                BrowserFamily::Firefox => app_args.push("-private-window".to_owned()),
                BrowserFamily::Other => {}
            }
        }

        if let Some(profile_name) = profile {
            match family {
                BrowserFamily::Chromium => {
                    app_args.push(format!("--profile-directory={profile_name}"));
                }
                BrowserFamily::Firefox => {
                    app_args.push("-P".to_owned());
                    app_args.push(profile_name.to_owned());
                }
                BrowserFamily::Other => {}
            }
        }

        app_args.push(url.as_str().to_owned());

        let args = if browser.app_id.trim().is_empty() {
            vec!["--args".to_owned()]
        } else {
            vec!["-b".to_owned(), browser.app_id.clone(), "--args".to_owned()]
        };

        let mut full_args = args;
        full_args.extend(app_args);
        Some(full_args)
    }

    #[cfg(not(target_os = "macos"))]
    {
        let _ = (browser, url, use_private_mode);
        None
    }
}

fn browser_family(browser: &BrowserConfig) -> BrowserFamily {
    let fingerprint = format!(
        "{} {} {}",
        browser.app_id.to_lowercase(),
        browser.executable.to_lowercase(),
        browser.name.to_lowercase()
    );

    const CHROMIUM_MARKERS: [&str; 8] = [
        "chrome", "chromium", "edge", "brave", "vivaldi", "opera", "arc", "dia",
    ];
    const FIREFOX_MARKERS: [&str; 5] = ["firefox", "waterfox", "librewolf", "zen", "floorp"];

    if CHROMIUM_MARKERS
        .iter()
        .any(|marker| fingerprint.contains(marker))
    {
        BrowserFamily::Chromium
    } else if FIREFOX_MARKERS
        .iter()
        .any(|marker| fingerprint.contains(marker))
    {
        BrowserFamily::Firefox
    } else {
        BrowserFamily::Other
    }
}

fn split_custom_args(args: &str) -> Vec<String> {
    if let Some(parts) = shlex::split(args) {
        return parts;
    }

    args.split_whitespace().map(ToOwned::to_owned).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn browser(
        app_id: &str,
        profile: Option<&str>,
        custom_arguments: Option<&str>,
    ) -> BrowserConfig {
        BrowserConfig::new(
            "Browser".to_owned(),
            app_id.to_owned(),
            "browser".to_owned(),
            "1".to_owned(),
            profile.map(ToOwned::to_owned),
            custom_arguments.map(ToOwned::to_owned),
        )
    }

    #[test]
    fn custom_args_replace_placeholders() {
        let b = browser(
            "com.google.chrome",
            Some("Profile 2"),
            Some("--profile-directory={profile} --app={url}"),
        );
        let url = Url::parse("https://example.com").expect("valid URL");
        let args = launch_arguments(&b, &url, false);
        assert_eq!(
            args,
            vec![
                "--profile-directory=Profile 2".to_owned(),
                "--app=https://example.com/".to_owned(),
            ]
        );
    }

    #[test]
    fn chromium_private_mode_without_profile_adds_incognito() {
        let b = browser("com.google.chrome", None, None);
        let url = Url::parse("https://example.com").expect("valid URL");
        let args = launch_arguments(&b, &url, true);
        assert_eq!(
            args,
            vec!["--incognito".to_owned(), "https://example.com/".to_owned()]
        );
    }

    #[test]
    fn firefox_profile_launch_adds_profile_switch() {
        let b = browser("org.mozilla.firefox", Some("Work"), None);
        let url = Url::parse("https://example.com").expect("valid URL");
        let args = launch_arguments(&b, &url, false);
        assert_eq!(
            args,
            vec![
                "-P".to_owned(),
                "Work".to_owned(),
                "https://example.com/".to_owned(),
            ]
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn mac_open_bundle_args_include_bundle_and_args() {
        let mut b = browser("com.apple.Safari", None, None);
        b.executable = "/usr/bin/open".to_owned();
        let url = Url::parse("https://example.com").expect("valid URL");
        let args = launch_arguments(&b, &url, false);
        assert_eq!(
            args,
            vec![
                "-b".to_owned(),
                "com.apple.Safari".to_owned(),
                "--args".to_owned(),
                "https://example.com/".to_owned(),
            ]
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn mac_open_bundle_with_chromium_profile_and_private_mode() {
        let mut b = browser("com.brave.Browser", Some("Profile 1"), None);
        b.executable = "/usr/bin/open".to_owned();
        let url = Url::parse("https://example.com").expect("valid URL");
        let args = launch_arguments(&b, &url, true);
        assert_eq!(
            args,
            vec![
                "-b".to_owned(),
                "com.brave.Browser".to_owned(),
                "--args".to_owned(),
                "--incognito".to_owned(),
                "--profile-directory=Profile 1".to_owned(),
                "https://example.com/".to_owned(),
            ]
        );
    }
}
