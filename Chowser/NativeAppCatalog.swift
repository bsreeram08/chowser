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
        .init(name: "Slack", bundleId: "com.tinyspeck.slackmacgap", domains: ["app.slack.com", "slack.com"]),
        .init(name: "Zoom", bundleId: "us.zoom.xos", domains: ["zoom.us"]),
        .init(name: "Figma", bundleId: "com.figma.Desktop", domains: ["figma.com"]),
        .init(name: "Notion", bundleId: "notion.id", domains: ["notion.so"]),
        .init(name: "Linear", bundleId: "com.linear", domains: ["linear.app"]),
        .init(name: "Spotify", bundleId: "com.spotify.client", domains: ["open.spotify.com"]),
        .init(name: "Discord", bundleId: "com.hnc.Discord", domains: ["discord.com"]),
        .init(name: "Telegram", bundleId: "ru.keepcoder.Telegram", domains: ["t.me"]),
        .init(name: "Microsoft Teams", bundleId: "com.microsoft.teams2", domains: ["teams.microsoft.com"]),
        .init(name: "WhatsApp", bundleId: "net.whatsapp.WhatsApp", domains: ["web.whatsapp.com", "wa.me"]),
        .init(name: "Spark", bundleId: "com.readdle.smartemail-Mac", domains: []),
        .init(name: "Tidal", bundleId: "com.tidal.desktop", domains: ["tidal.com"]),
    ]

    /// Catalog entries that are actually installed, minus ones already configured.
    static func installedSuggestions(excludingBundleIDs configured: Set<String>) -> [NativeAppSuggestion] {
        all.filter { $0.isInstalled && !configured.contains($0.bundleId.lowercased()) }
    }
}
