import Foundation
import AppKit
import SwiftUI
import ServiceManagement

struct BrowserConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var bundleId: String // e.g. "com.apple.Safari"
    var shortcutKey: String // "1", "2", etc
}

@MainActor
@Observable final class BrowserManager {
    private enum Constants {
        static let defaultsKey = "configuredBrowsers"
        static let onboardingCompletedKey = "onboardingCompleted"
        static let supportedShortcutKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    }

    static let shared = BrowserManager(defaults: makeDefaultStore())

    var configuredBrowsers: [BrowserConfig] = [] {
        didSet {
            save()
        }
    }

    var launchAtLogin: Bool = false {
        didSet {
            guard launchAtLogin != oldValue else { return }
            updateLaunchAtLogin()
        }
    }

    var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Constants.onboardingCompletedKey)
        }
    }

    var currentURL: URL?
    var lastOpenedBrowserBundleIDForTesting: String?

    @ObservationIgnored private let defaultsKey: String
    @ObservationIgnored let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, defaultsKey: String = "configuredBrowsers") {
        self.defaults = defaults
        self.defaultsKey = defaultsKey
        self.hasCompletedOnboarding = defaults.bool(forKey: Constants.onboardingCompletedKey)

        if AppEnvironment.shouldClearDataOnLaunch {
            clearPersistedBrowserList()
        }

        load()
        if AppEnvironment.shouldDisableSystemIntegration {
            launchAtLogin = false
        } else {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }

        if let defaultURL = AppEnvironment.defaultTestURL {
            currentURL = defaultURL
        }
    }

    static func makeDefaultStore() -> UserDefaults {
        guard let suiteName = AppEnvironment.defaultsSuiteName else {
            return .standard
        }

        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func freshSetupBrowsers() -> [BrowserConfig] {
        [BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")]
    }

    func load() {
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([BrowserConfig].self, from: data) {
            configuredBrowsers = decoded
        } else {
            configuredBrowsers = Self.freshSetupBrowsers()
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(configuredBrowsers) {
            defaults.set(encoded, forKey: defaultsKey)
        }
    }

    func resetToFreshSetup() {
        restoreDefaultBrowserList()
        currentURL = nil
        hasCompletedOnboarding = false

        if launchAtLogin {
            launchAtLogin = false
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func restoreDefaultBrowserList() {
        clearPersistedBrowserList()
        configuredBrowsers = Self.freshSetupBrowsers()
    }

    func addBrowser(name: String, bundleId: String, shortcutKey: String? = nil) {
        guard !configuredBrowsers.contains(where: { $0.bundleId == bundleId }) else {
            return
        }

        let key = shortcutKey.flatMap { normalizedShortcut($0) } ?? nextAvailableShortcutKey()
        configuredBrowsers.append(BrowserConfig(name: name, bundleId: bundleId, shortcutKey: key))
    }

    func removeBrowser(id: UUID) {
        configuredBrowsers.removeAll { $0.id == id }
    }

    func removeBrowsers(at offsets: IndexSet) {
        configuredBrowsers.remove(atOffsets: offsets)
    }

    func moveBrowsers(from offsets: IndexSet, to destination: Int) {
        configuredBrowsers.move(fromOffsets: offsets, toOffset: destination)
    }

    func updateBrowserName(id: UUID, to name: String) {
        guard let index = configuredBrowsers.firstIndex(where: { $0.id == id }) else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if configuredBrowsers[index].name != trimmedName {
            configuredBrowsers[index].name = trimmedName
        }
    }

    func browserName(for id: UUID) -> String {
        configuredBrowsers.first(where: { $0.id == id })?.name ?? ""
    }

    func shortcutKey(for id: UUID) -> String {
        configuredBrowsers.first(where: { $0.id == id })?.shortcutKey ?? "1"
    }

    func updateShortcutKey(id: UUID, to newShortcut: String) {
        guard let index = configuredBrowsers.firstIndex(where: { $0.id == id }) else { return }
        guard let normalized = normalizedShortcut(newShortcut) else { return }

        // Keep shortcuts unique by swapping the existing owner with the current browser.
        if let existingIndex = configuredBrowsers.firstIndex(where: {
            $0.shortcutKey == normalized && $0.id != id
        }) {
            configuredBrowsers[existingIndex].shortcutKey = configuredBrowsers[index].shortcutKey
        }

        configuredBrowsers[index].shortcutKey = normalized
    }

    func nextAvailableShortcutKey() -> String {
        for key in Constants.supportedShortcutKeys where !configuredBrowsers.contains(where: { $0.shortcutKey == key }) {
            return key
        }

        return Constants.supportedShortcutKeys.last ?? "9"
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin() {
        guard !AppEnvironment.shouldDisableSystemIntegration else { return }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    // MARK: - Default Browser

    static func setAsDefaultBrowser() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }

        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            workspace.setDefaultApplication(at: url, toOpenURLsWithScheme: "http") { error in
                if let error = error {
                    print("Failed to set default for http: \(error)")
                }
            }
            workspace.setDefaultApplication(at: url, toOpenURLsWithScheme: "https") { error in
                if let error = error {
                    print("Failed to set default for https: \(error)")
                }
            }
        }
    }

    static func isDefaultBrowser() -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let defaultHandler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!),
              let defaultBundle = Bundle(url: defaultHandler)?.bundleIdentifier else {
            return false
        }

        return defaultBundle == bundleId
    }

    // MARK: - Installed Browsers

    static func getInstalledBrowsers() -> [(name: String, bundleId: String, iconURL: URL?)] {
        if AppEnvironment.shouldUseMockInstalledBrowsers {
            let mockEntries = [
                ("Google Chrome", "com.google.Chrome"),
                ("Firefox", "org.mozilla.firefox"),
                ("Safari", "com.apple.Safari"),
                ("Zen Browser", "app.zen-browser.zen"),
            ]

            return mockEntries.map { name, bundleId in
                let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
                return (name, bundleId, url)
            }
        }

        guard let dummyURL = URL(string: "https://example.com") else { return [] }
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: dummyURL)

        var browsers: [(String, String, URL?)] = []
        for url in appURLs {
            if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                           (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                           url.deletingPathExtension().lastPathComponent
                browsers.append((name, bundleId, url))
            }
        }

        // Filter out Chowser itself.
        let myBundleId = Bundle.main.bundleIdentifier ?? ""
        return browsers
            .filter { $0.1 != myBundleId && !$0.1.contains("apple.Safari.WebApp") }
            .sorted { $0.0 < $1.0 }
    }

    static func icon(forBrowserBundleID bundleId: String, fallbackURL: URL? = nil) -> NSImage? {
        if let fallbackURL {
            return NSWorkspace.shared.icon(forFile: fallbackURL.path)
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    static func currentAppIcon() -> NSImage {
        if let icon = NSApplication.shared.applicationIconImage.copy() as? NSImage,
           icon.size.width > 0,
           icon.size.height > 0 {
            return icon
        }

        let bundleIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundleURL.path)
        if bundleIcon.size.width > 0, bundleIcon.size.height > 0 {
            return bundleIcon
        }

        if let fallback = NSImage(systemSymbolName: "app.badge", accessibilityDescription: "Chowser") {
            return fallback
        }

        return NSImage(size: NSSize(width: 64, height: 64))
    }

    private func clearPersistedBrowserList() {
        defaults.removeObject(forKey: defaultsKey)
    }

    private func normalizedShortcut(_ key: String) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Constants.supportedShortcutKeys.contains(trimmed) else {
            return nil
        }

        return trimmed
    }
}
