import Foundation

struct BrowserProfile {
    let id: String
    let name: String
}

enum BrowserProfileDetector {

    private static var profileCache: [String: [BrowserProfile]] = [:]

    /// Clears the profile cache — call when the Settings window opens to pick up newly added profiles.
    static func clearCache() {
        profileCache = [:]
    }

    static func detectProfiles(for bundleId: String) -> [BrowserProfile] {
        if let cached = profileCache[bundleId] { return cached }
        let profiles = detectProfilesUncached(for: bundleId)
        profileCache[bundleId] = profiles
        return profiles
    }

    static func detectProfiles(for bundleId: String, appSupportURL: URL) -> [BrowserProfile] {
        detectProfilesUncached(for: bundleId, appSupportURL: appSupportURL)
    }

    private static func detectProfilesUncached(for bundleId: String) -> [BrowserProfile] {
        guard let appSupportURL = profileApplicationSupportURL() else { return [] }
        defer { SandboxBookmarkManager.shared.stopAccessing() }
        return detectProfilesUncached(for: bundleId, appSupportURL: appSupportURL)
    }

    private static func detectProfilesUncached(for bundleId: String, appSupportURL: URL) -> [BrowserProfile] {
        let id = bundleId.lowercased()
        if id.contains("chrome") || id == "com.brave.browser" || id == "com.microsoft.edgemac" || id == "com.vivaldi.vivaldi" || id == "company.thebrowser.browser" || id == "company.thebrowser.dia" {
            return detectChromiumProfiles(bundleId: id, appSupportURL: appSupportURL)
        } else if id == "org.mozilla.firefox" || id == "app.zen-browser.zen" {
            return detectFirefoxProfiles(bundleId: id, appSupportURL: appSupportURL)
        }
        return []
    }

    private static func profileApplicationSupportURL() -> URL? {
        if let bookmarkedURL = SandboxBookmarkManager.shared.startAccessing() {
            return bookmarkedURL
        }

        #if APP_STORE
        return nil
        #else
        return directApplicationSupportURL()
        #endif
    }

    private static func directApplicationSupportURL() -> URL {
        let home = NSHomeDirectory()
        if home.contains("/Containers/") {
            // Escape from ~/Library/Containers/bundle.id/Data to ~.
            let realHome = URL(fileURLWithPath: home)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            return realHome.appendingPathComponent("Library/Application Support")
        }

        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    private static func detectChromiumProfiles(bundleId: String, appSupportURL: URL) -> [BrowserProfile] {
        let pathSuffix: String
        switch bundleId.lowercased() {
        case "com.google.chrome": pathSuffix = "Google/Chrome/Local State"
        case "com.brave.browser": pathSuffix = "BraveSoftware/Brave-Browser/Local State"
        case "com.microsoft.edgemac": pathSuffix = "Microsoft Edge/Local State"
        case "com.vivaldi.vivaldi": pathSuffix = "Vivaldi/Local State"
        case "company.thebrowser.browser": pathSuffix = "Arc/User Data/Local State"
        case "company.thebrowser.dia": pathSuffix = "Dia/User Data/Local State"
        default: return []
        }

        var localStateURL = appSupportURL.appendingPathComponent(pathSuffix)

        // Fallback for Dia: Check if User Data is missing in the path.
        if bundleId.lowercased() == "company.thebrowser.dia" && !FileManager.default.fileExists(atPath: localStateURL.path) {
            let altURL = appSupportURL.appendingPathComponent("Dia/Local State")
            if FileManager.default.fileExists(atPath: altURL.path) {
                localStateURL = altURL
            }
        }
        guard let data = try? Data(contentsOf: localStateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: [String: Any]] else {
            return []
        }

        var profiles: [BrowserProfile] = []
        for (key, info) in infoCache {
            let name = info["name"] as? String ?? key
            profiles.append(BrowserProfile(id: key, name: name))
        }

        return profiles.sorted(by: { $0.name < $1.name })
    }

    private static func detectFirefoxProfiles(bundleId: String, appSupportURL: URL) -> [BrowserProfile] {
        let pathSuffix = bundleId == "org.mozilla.firefox" ? "Firefox/profiles.ini" : "Zen/profiles.ini"
        let iniURL = appSupportURL.appendingPathComponent(pathSuffix)

        guard let content = try? String(contentsOf: iniURL, encoding: .utf8) else { return [] }

        var profiles: [BrowserProfile] = []
        let lines = content.components(separatedBy: .newlines)

        var currentName: String?
        for line in lines {
            if line.hasPrefix("[Profile") {
                currentName = nil
            } else if line.hasPrefix("Name=") {
                currentName = String(line.dropFirst(5))
                if let name = currentName {
                    profiles.append(BrowserProfile(id: name, name: name))
                }
            }
        }

        return profiles.sorted(by: { $0.name < $1.name })
    }
}
