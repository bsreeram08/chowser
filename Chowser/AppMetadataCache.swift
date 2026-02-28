import AppKit

/// Process-lifetime cache for app metadata (icons, display names, URLs).
/// Avoids hitting `NSWorkspace` / `Bundle` filesystem I/O on every SwiftUI render.
final class AppMetadataCache {
    static let shared = AppMetadataCache()

    private var icons: [String: NSImage] = [:]
    private var names: [String: String] = [:]
    private var urls: [String: URL] = [:]
    private var missing: Set<String> = []

    func appURL(for bundleId: String) -> URL? {
        if missing.contains(bundleId) { return nil }
        if let cached = urls[bundleId] { return cached }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            missing.insert(bundleId)
            return nil
        }
        urls[bundleId] = url
        return url
    }

    func icon(for bundleId: String) -> NSImage? {
        if let cached = icons[bundleId] { return cached }

        guard let url = appURL(for: bundleId) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleId] = image
        return image
    }

    func displayName(for bundleId: String) -> String? {
        if let cached = names[bundleId] { return cached }

        guard let url = appURL(for: bundleId) else { return nil }
        guard let bundle = Bundle(url: url) else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
        if let name {
            names[bundleId] = name
        }
        return name
    }
}
