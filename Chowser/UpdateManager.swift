import Foundation
import AppKit

/// Checks the App Store for a newer version of Chowser using the iTunes lookup API.
@MainActor
final class UpdateManager {
    static let shared = UpdateManager()

    private(set) var updateAvailable = false
    private(set) var latestVersion: String?
    private let bundleId = "in.sreerams.Chowser"
    private let appStoreURL = URL(string: "https://apps.apple.com/app/chowser/id6741527291")!

    private init() {}

    func checkForUpdates() async {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let storeVersion = first["version"] as? String else { return }

            latestVersion = storeVersion
            updateAvailable = isNewerVersion(storeVersion, than: currentVersion)
        } catch {
            // Silent failure — update check is best-effort
        }
    }

    func openAppStore() {
        NSWorkspace.shared.open(appStoreURL)
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private func isNewerVersion(_ store: String, than current: String) -> Bool {
        let storeParts = store.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(storeParts.count, currentParts.count)
        for i in 0..<maxLen {
            let s = i < storeParts.count ? storeParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if s > c { return true }
            if s < c { return false }
        }
        return false
    }
}
