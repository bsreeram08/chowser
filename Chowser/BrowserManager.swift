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

struct BrowserRoutingRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var hostPattern: String
    var pathPrefix: String?
    var browserBundleId: String
    var isEnabled: Bool = true
}

@MainActor
@Observable final class BrowserManager {
    private enum Constants {
        static let defaultsKey = "configuredBrowsers"
        static let onboardingCompletedKey = "onboardingCompleted"
        static let routingRulesKey = "routingRules"
        static let supportedShortcutKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    }

    static let shared = BrowserManager(defaults: makeDefaultStore())

    var configuredBrowsers: [BrowserConfig] = [] {
        didSet {
            save()
            removeRoutingRulesWithMissingBrowsers()
        }
    }

    var routingRules: [BrowserRoutingRule] = [] {
        didSet {
            saveRoutingRules()
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
            clearPersistedRoutingRules()
        }

        load()
        loadRoutingRules()
        removeRoutingRulesWithMissingBrowsers()
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

    func loadRoutingRules() {
        if let data = defaults.data(forKey: Constants.routingRulesKey),
           let decoded = try? JSONDecoder().decode([BrowserRoutingRule].self, from: data) {
            routingRules = decoded
        } else {
            routingRules = []
        }
    }

    func saveRoutingRules() {
        if let encoded = try? JSONEncoder().encode(routingRules) {
            defaults.set(encoded, forKey: Constants.routingRulesKey)
        }
    }

    func resetToFreshSetup() {
        restoreDefaultBrowserList()
        restoreDefaultRoutingRules()
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

    func restoreDefaultRoutingRules() {
        clearPersistedRoutingRules()
        routingRules = []
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

    // MARK: - Routing Rules

    func addRoutingRule(name: String, hostPattern: String, pathPrefix: String?, browserBundleId: String) {
        guard configuredBrowsers.contains(where: { $0.bundleId == browserBundleId }) else { return }

        let normalizedHost = normalizedHostPattern(hostPattern)
        guard isValidHostPattern(normalizedHost) else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ruleName = trimmedName.isEmpty ? normalizedHost : trimmedName

        routingRules.append(
            BrowserRoutingRule(
                name: ruleName,
                hostPattern: normalizedHost,
                pathPrefix: normalizedPathPrefix(pathPrefix),
                browserBundleId: browserBundleId
            )
        )
    }

    func removeRoutingRule(id: UUID) {
        routingRules.removeAll { $0.id == id }
    }

    func removeRoutingRules(at offsets: IndexSet) {
        routingRules.remove(atOffsets: offsets)
    }

    func moveRoutingRules(from offsets: IndexSet, to destination: Int) {
        routingRules.move(fromOffsets: offsets, toOffset: destination)
    }

    func duplicateRoutingRule(id: UUID) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }

        let original = routingRules[index]
        let duplicate = BrowserRoutingRule(
            name: "\(original.name) Copy",
            hostPattern: original.hostPattern,
            pathPrefix: original.pathPrefix,
            browserBundleId: original.browserBundleId,
            isEnabled: original.isEnabled
        )
        routingRules.insert(duplicate, at: index + 1)
    }

    func routingRuleName(for id: UUID) -> String {
        routingRules.first(where: { $0.id == id })?.name ?? ""
    }

    func routingRuleHostPattern(for id: UUID) -> String {
        routingRules.first(where: { $0.id == id })?.hostPattern ?? ""
    }

    func routingRulePathPrefix(for id: UUID) -> String {
        routingRules.first(where: { $0.id == id })?.pathPrefix ?? ""
    }

    func routingRuleBrowserBundleID(for id: UUID) -> String {
        routingRules.first(where: { $0.id == id })?.browserBundleId ?? ""
    }

    func routingRuleIsEnabled(for id: UUID) -> Bool {
        routingRules.first(where: { $0.id == id })?.isEnabled ?? false
    }

    func updateRoutingRuleName(id: UUID, to name: String) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        routingRules[index].name = trimmedName.isEmpty ? routingRules[index].hostPattern : trimmedName
    }

    func updateRoutingRuleHostPattern(id: UUID, to hostPattern: String) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        let normalizedHost = normalizedHostPattern(hostPattern)
        guard !normalizedHost.isEmpty else { return }
        routingRules[index].hostPattern = normalizedHost

        if routingRules[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            routingRules[index].name = normalizedHost
        }
    }

    func updateRoutingRulePathPrefix(id: UUID, to pathPrefix: String) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        routingRules[index].pathPrefix = normalizedPathPrefix(pathPrefix)
    }

    func updateRoutingRuleBrowser(id: UUID, to browserBundleId: String) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        guard configuredBrowsers.contains(where: { $0.bundleId == browserBundleId }) else { return }
        routingRules[index].browserBundleId = browserBundleId
    }

    func updateRoutingRuleIsEnabled(id: UUID, to isEnabled: Bool) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        routingRules[index].isEnabled = isEnabled
    }

    func resolvedRoute(for url: URL) -> (rule: BrowserRoutingRule, browser: BrowserConfig)? {
        let host = (url.host ?? "").lowercased()
        guard !host.isEmpty else { return nil }

        let path = url.path.isEmpty ? "/" : url.path

        for rule in routingRules where rule.isEnabled {
            guard hostMatches(host, pattern: rule.hostPattern) else { continue }
            guard pathMatches(path, prefix: rule.pathPrefix) else { continue }
            guard let browser = configuredBrowsers.first(where: { $0.bundleId == rule.browserBundleId }) else { continue }

            return (rule, browser)
        }

        return nil
    }

    func resolvedBrowser(for url: URL) -> BrowserConfig? {
        resolvedRoute(for: url)?.browser
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

    func open(url: URL, withBrowserBundleID bundleId: String) {
        if AppEnvironment.shouldDisableExternalURLOpen {
            lastOpenedBrowserBundleIDForTesting = bundleId
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error {
                print("Failed to open URL: \(error)")
            }
        }
    }

    func isValidRoutingHostPattern(_ hostPattern: String) -> Bool {
        let normalizedPattern = normalizedHostPattern(hostPattern)
        return isValidHostPattern(normalizedPattern)
    }

    private func clearPersistedBrowserList() {
        defaults.removeObject(forKey: defaultsKey)
    }

    private func clearPersistedRoutingRules() {
        defaults.removeObject(forKey: Constants.routingRulesKey)
    }

    private func removeRoutingRulesWithMissingBrowsers() {
        let validBundleIDs = Set(configuredBrowsers.map(\.bundleId))
        let filteredRules = routingRules.filter { validBundleIDs.contains($0.browserBundleId) }

        if filteredRules.count != routingRules.count {
            routingRules = filteredRules
        }
    }

    private func normalizedShortcut(_ key: String) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Constants.supportedShortcutKeys.contains(trimmed) else {
            return nil
        }

        return trimmed
    }

    private func normalizedHostPattern(_ hostPattern: String) -> String {
        var normalized = hostPattern
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return "" }

        if let schemeRange = normalized.range(of: "://") {
            normalized = String(normalized[schemeRange.upperBound...])
        }

        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }

        if normalized.hasPrefix("*.") {
            var suffix = String(normalized.dropFirst(2))
            if let colonIndex = suffix.firstIndex(of: ":") {
                suffix = String(suffix[..<colonIndex])
            }
            while suffix.hasSuffix(".") {
                suffix.removeLast()
            }

            return suffix.isEmpty ? "" : "*.\(suffix)"
        }

        if let colonIndex = normalized.firstIndex(of: ":") {
            normalized = String(normalized[..<colonIndex])
        }

        while normalized.hasSuffix(".") {
            normalized.removeLast()
        }

        return normalized
    }

    private func isValidHostPattern(_ hostPattern: String) -> Bool {
        guard !hostPattern.isEmpty else { return false }
        guard !hostPattern.contains(" ") else { return false }
        guard !hostPattern.contains("/") else { return false }

        if hostPattern.hasPrefix("*.") {
            let suffix = String(hostPattern.dropFirst(2))
            return !suffix.isEmpty && !suffix.contains("*") && isValidHostName(suffix)
        }

        return !hostPattern.contains("*") && isValidHostName(hostPattern)
    }

    private func isValidHostName(_ host: String) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }

        for label in labels {
            guard !label.isEmpty else { return false }
            guard label.first != "-", label.last != "-" else { return false }
            guard label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else {
                return false
            }
        }

        return true
    }

    private func normalizedPathPrefix(_ pathPrefix: String?) -> String? {
        guard let pathPrefix else { return nil }

        let trimmed = pathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("/") {
            return trimmed
        }

        return "/\(trimmed)"
    }

    private func hostMatches(_ host: String, pattern: String) -> Bool {
        let normalizedPattern = normalizedHostPattern(pattern)
        guard !normalizedPattern.isEmpty else { return false }

        if normalizedPattern.hasPrefix("*.") {
            let suffix = String(normalizedPattern.dropFirst(2))
            guard !suffix.isEmpty else { return false }
            return host == suffix || host.hasSuffix(".\(suffix)")
        }

        return host == normalizedPattern
    }

    private func pathMatches(_ path: String, prefix: String?) -> Bool {
        guard let normalizedPrefix = normalizedPathPrefix(prefix) else {
            return true
        }

        return path.hasPrefix(normalizedPrefix)
    }
}
