import AppKit

/// Curated list of popular native apps that handle their own web links, so users can
/// one-click route those domains to the app instead of a browser. Launch uses the same
/// NSWorkspace path as browsers — it works for apps that handle their universal links.
struct NativeAppSuggestion: Identifiable {
    var id: String { bundleId }
    let name: String
    let bundleId: String
    /// Host patterns to route to this app (used to offer auto-rule creation).
    let domains: [String]

    /// Whether the app is installed on this Mac.
    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
}

enum NativeAppCatalog {
    static let all: [NativeAppSuggestion] = [
        // Chat / messaging
        .init(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", domains: ["app.slack.com", "slack.com"]),
        .init(name: "Discord", bundleId: "com.hnc.Discord", domains: ["discord.com", "discordapp.com"]),
        .init(name: "Telegram", bundleId: "ru.keepcoder.Telegram", domains: ["t.me", "telegram.me"]),
        .init(name: "WhatsApp", bundleId: "net.whatsapp.WhatsApp", domains: ["web.whatsapp.com", "wa.me", "chat.whatsapp.com"]),
        .init(name: "Microsoft Teams", bundleId: "com.microsoft.teams2", domains: ["teams.microsoft.com", "teams.live.com"]),
        .init(name: "Signal", bundleId: "org.whispersystems.signal-desktop", domains: ["signal.group", "signal.me"]),
        .init(name: "Messenger", bundleId: "com.facebook.archon", domains: ["messenger.com"]),
        // Meetings
        .init(name: "Zoom", bundleId: "us.zoom.xos", domains: ["zoom.us"]),
        .init(name: "Webex", bundleId: "com.webex.meetingmanager", domains: ["webex.com"]),
        // Productivity / work
        .init(name: "Figma", bundleId: "com.figma.Desktop", domains: ["figma.com"]),
        .init(name: "Notion", bundleId: "notion.id", domains: ["notion.so"]),
        .init(name: "Linear", bundleId: "com.linear", domains: ["linear.app"]),
        .init(name: "Asana", bundleId: "com.electron.asana", domains: ["app.asana.com"]),
        .init(name: "ClickUp", bundleId: "com.clickup.desktop-app", domains: ["app.clickup.com"]),
        .init(name: "Trello", bundleId: "com.atlassian.trello", domains: ["trello.com"]),
        .init(name: "Height", bundleId: "run.height.desktop", domains: ["height.app"]),
        .init(name: "Loom", bundleId: "com.loom.desktop", domains: ["loom.com"]),
        .init(name: "Obsidian", bundleId: "md.obsidian", domains: []),
        .init(name: "Notion Calendar", bundleId: "com.cron.electron", domains: ["calendar.notion.so", "cron.com"]),
        // Music / media
        .init(name: "Spotify", bundleId: "com.spotify.client", domains: ["open.spotify.com"]),
        .init(name: "Apple Music", bundleId: "com.apple.Music", domains: ["music.apple.com"]),
        .init(name: "Tidal", bundleId: "com.tidal.desktop", domains: ["tidal.com", "listen.tidal.com"]),
        // Mail
        .init(name: "Spark", bundleId: "com.readdle.smartemail-Mac", domains: []),
    ]

    /// Catalog entries that are actually installed, minus ones already configured.
    static func installedSuggestions(excludingBundleIDs configured: Set<String>) -> [NativeAppSuggestion] {
        all.filter { $0.isInstalled && !configured.contains($0.bundleId.lowercased()) }
    }

    /// The installed catalog app that owns `host` (exact or subdomain match), if any.
    /// Used for opt-in automatic app-based routing.
    static func appMatching(host: String) -> NativeAppSuggestion? {
        let host = host.lowercased()
        return all.first { app in
            app.isInstalled && app.domains.contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }
}
