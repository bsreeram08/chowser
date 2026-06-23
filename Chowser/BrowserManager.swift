import Foundation
import AppKit
import SwiftUI
import ServiceManagement

struct BrowserConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var bundleId: String // e.g. "com.apple.Safari"
    var shortcutKey: String // "1", "2", etc
    var profile: String? // Optional profile argument for browsers that support it
    var customArguments: String? // Normal-launch arg template (e.g. "--profile-directory={profile}")
    var privateArguments: String? // Private/incognito-launch arg template (e.g. "--incognito --profile-directory={profile}")

    var identity: String { "\(bundleId)|\(profile ?? "")" }
}

struct BrowserRoutingRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var hostPattern: String
    var pathPrefix: String?
    var browserBundleId: String
    var profile: String?
    var isEnabled: Bool = true
    var sourceAppBundleId: String? = nil
    var usePrivateMode: Bool = false
    var useRegex: Bool = false
}

extension BrowserRoutingRule {
    private enum CodingKeys: String, CodingKey {
        case id, name, hostPattern, pathPrefix, browserBundleId, profile, isEnabled, sourceAppBundleId, usePrivateMode, useRegex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        hostPattern = try c.decode(String.self, forKey: .hostPattern)
        pathPrefix = try c.decodeIfPresent(String.self, forKey: .pathPrefix)
        browserBundleId = try c.decode(String.self, forKey: .browserBundleId)
        profile = try c.decodeIfPresent(String.self, forKey: .profile)
        isEnabled = (try c.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? true
        sourceAppBundleId = try c.decodeIfPresent(String.self, forKey: .sourceAppBundleId)
        usePrivateMode = (try c.decodeIfPresent(Bool.self, forKey: .usePrivateMode)) ?? false
        useRegex = (try c.decodeIfPresent(Bool.self, forKey: .useRegex)) ?? false
    }
}

@MainActor
@Observable final class BrowserManager {
    enum RoutingRuleValidationError: Error, Equatable {
        case browserNotFound(bundleId: String, profile: String?)
        case invalidHostPattern
        case invalidRegexPattern
        case invalidPathPrefix
        case invalidSourceAppBundleId
        case ruleNotFound

        var message: String {
            switch self {
            case .browserNotFound:
                return "Browser not found. Add the browser first."
            case .invalidHostPattern:
                return "Host pattern is invalid."
            case .invalidRegexPattern:
                return "Regex host pattern is invalid."
            case .invalidPathPrefix:
                return "Path prefix is invalid. Use a path such as /docs or docs."
            case .invalidSourceAppBundleId:
                return "Source app bundle ID is invalid."
            case .ruleNotFound:
                return "Rule not found."
            }
        }
    }

    private enum Constants {
        static let defaultsKey = "configuredBrowsers"
        static let routingRulesKey = "routingRules"
        static let hiddenBundleIDsKey = "hiddenBundleIDs"
        static let pickerIconSizeKey = "pickerIconSize"
        static let pickerShowLabelsKey = "pickerShowLabels"
        static let pickerLayoutModeKey = "pickerLayoutMode"
        static let pickerAppearanceModeKey = "pickerAppearanceMode"
        static let pickerTintHexKey = "pickerTintHex"
        static let pickerBackgroundOpacityKey = "pickerBackgroundOpacity"
        static let pickerCornerRadiusKey = "pickerCornerRadius"
        static let pickerAccentHexKey = "pickerAccentHex"
        static let pickerDimInactiveKey = "pickerDimInactive"
        static let pickerColorSchemeKey = "pickerColorScheme"
        static let showLinkPreviewKey = "showLinkPreview"
        static let autoNativeAppRoutingKey = "autoNativeAppRouting"
        static let densityPreferenceKey = "densityPreference"
        static let skipExistingImportedRulesKey = "skipExistingImportedRules"
        static let skipExistingImportedBrowsersKey = "skipExistingImportedBrowsers"
        static let supportedShortcutKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

        /// Apps that register as HTTP handlers but are not browsers.
        static let defaultHiddenBundleIDs: Set<String> = [
            "com.mxtech.mxplayerforios",
            "com.mxtech.videoplayer.pro",
            "com.mxplayer.mac",
            "com.rockysandstudio.MKPlayer",
            "io.mpv",
            "com.colliderli.iina",
            "org.videolan.vlc",
        ]
        static let recentURLsKey = "recentURLs"
    }

    static let shared = BrowserManager(defaults: makeDefaultStore(), immediateWrite: false)

    struct ImportSummary: Equatable {
        var added: Int = 0
        var updated: Int = 0
        var skipped: Int = 0
        var invalid: Int = 0

        var changedCount: Int { added + updated }
        var totalProcessed: Int { added + updated + skipped + invalid }
    }

    var configuredBrowsers: [BrowserConfig] = [] {
        didSet {
            scheduleSaveBrowsers()
        }
    }

    var routingRules: [BrowserRoutingRule] = [] {
        didSet {
            scheduleSaveRules()
        }
    }

    var launchAtLogin: Bool = false {
        didSet {
            guard launchAtLogin != oldValue else { return }
            updateLaunchAtLogin()
        }
    }
    var skipExistingImportedRules: Bool = true {
        didSet {
            defaults.set(skipExistingImportedRules, forKey: Constants.skipExistingImportedRulesKey)
        }
    }
    var skipExistingImportedBrowsers: Bool = true {
        didSet {
            defaults.set(skipExistingImportedBrowsers, forKey: Constants.skipExistingImportedBrowsersKey)
        }
    }

    var hasCompletedOnboarding: Bool {
        get { OnboardingManager.hasCompletedOnboarding(in: defaults) }
        set { OnboardingManager.setHasCompletedOnboarding(newValue, in: defaults) }
    }

    var currentURL: URL?
    var currentURLPrivateModeRequested = false
    var currentSourceAppBundleId: String? = nil
    var lastOpenedBrowserBundleIDForTesting: String?
    @ObservationIgnored private var pendingPrivateModeURL: URL?

    /// Picker icon size: "small", "medium" (default), "large"
    var pickerIconSize: String = "medium" {
        didSet {
            defaults.set(pickerIconSize, forKey: Constants.pickerIconSizeKey)
        }
    }

    /// Whether to show browser name labels below icons in the picker.
    var pickerShowLabels: Bool = true {
        didSet {
            defaults.set(pickerShowLabels, forKey: Constants.pickerShowLabelsKey)
        }
    }

    /// Picker layout mode: "icons" (horizontal icon bar) or "list" (vertical list with full names).
    var pickerLayoutMode: String = "icons" {
        didSet {
            defaults.set(pickerLayoutMode, forKey: Constants.pickerLayoutModeKey)
        }
    }

    /// Picker appearance mode: "auto" (native glass/material) or "custom" (user-tuned surface).
    var pickerAppearanceMode: String = "auto" {
        didSet {
            defaults.set(pickerAppearanceMode, forKey: Constants.pickerAppearanceModeKey)
        }
    }

    /// Hex tint washed over the picker panel in custom mode. Empty = no tint.
    var pickerTintHex: String = "" {
        didSet {
            defaults.set(pickerTintHex, forKey: Constants.pickerTintHexKey)
        }
    }

    /// Picker surface opacity in custom mode (0.2...1.0).
    var pickerBackgroundOpacity: Double = 0.85 {
        didSet {
            defaults.set(pickerBackgroundOpacity, forKey: Constants.pickerBackgroundOpacityKey)
        }
    }

    /// Picker panel corner radius (8...28). Applies in both modes.
    var pickerCornerRadius: Double = 16 {
        didSet {
            defaults.set(pickerCornerRadius, forKey: Constants.pickerCornerRadiusKey)
        }
    }

    /// Hex accent override for selection/shortcut highlights. Empty = system accent.
    var pickerAccentHex: String = "" {
        didSet {
            defaults.set(pickerAccentHex, forKey: Constants.pickerAccentHexKey)
        }
    }

    /// Dim browsers that aren't currently running in the picker.
    var pickerDimInactiveBrowsers: Bool = true {
        didSet {
            defaults.set(pickerDimInactiveBrowsers, forKey: Constants.pickerDimInactiveKey)
        }
    }

    /// Picker color scheme override: "system" (default), "light", or "dark".
    var pickerColorScheme: String = "system" {
        didSet {
            defaults.set(pickerColorScheme, forKey: Constants.pickerColorSchemeKey)
        }
    }

    /// Fetch + show a metadata preview (title/description/image) for the clicked link
    /// in the picker. Also resolves shortlinks via the fetch's redirect chain.
    var showLinkPreview: Bool = true {
        didSet {
            defaults.set(showLinkPreview, forKey: Constants.showLinkPreviewKey)
        }
    }

    /// Automatically route links whose domain belongs to a known installed app
    /// (Slack, Zoom, Figma…) straight to that app, without an explicit rule. Opt-in.
    var autoNativeAppRouting: Bool = false {
        didSet {
            defaults.set(autoNativeAppRouting, forKey: Constants.autoNativeAppRoutingKey)
        }
    }

    /// Settings UI density: "compact", "default", or "comfortable".
    var densityPreference: String = "default" {
        didSet {
            defaults.set(densityPreference, forKey: Constants.densityPreferenceKey)
        }
    }

    var hiddenBundleIDs: Set<String> = [] {
        didSet {
            defaults.set(Array(hiddenBundleIDs), forKey: Constants.hiddenBundleIDsKey)
        }
    }

    var recentURLs: [URL] = [] {
        didSet {
            scheduleSaveRecentURLs()
        }
    }

    struct TemporaryRoute {
        let browserBundleId: String
        let profile: String?
        let expiresAt: Date
    }

    var temporaryRoute: TemporaryRoute? {
        didSet {
            if temporaryRoute != nil {
                scheduleTemporaryRouteExpirationTimer()
            } else {
                temporaryRouteExpirationTimer?.invalidate()
                temporaryRouteExpirationTimer = nil
            }
        }
    }

    @ObservationIgnored private let defaultsKey: String
    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored private let immediateWrite: Bool
    @ObservationIgnored private var pendingBrowsersSave: DispatchWorkItem?
    @ObservationIgnored private var pendingRulesSave: DispatchWorkItem?
    @ObservationIgnored private var pendingRecentURLsSave: DispatchWorkItem?
    @ObservationIgnored private var temporaryRouteExpirationTimer: Timer?

    init(defaults: UserDefaults = AppEnvironment.makeDefaultStore(), defaultsKey: String = "configuredBrowsers", immediateWrite: Bool = true) {
        self.defaults = defaults
        self.defaultsKey = defaultsKey
        self.immediateWrite = immediateWrite

        if AppEnvironment.shouldClearDataOnLaunch {
            clearPersistedBrowserList()
            clearPersistedRoutingRules()
            clearPersistedRecentURLs()
        }

        load()
        loadRoutingRules()
        loadHiddenBundleIDs()
        loadRecentURLs()
        loadPickerPreferences()
        loadImportPreferences()
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
        AppEnvironment.makeDefaultStore()
    }

    func prepareClipboardPrivateModeRequest(for url: URL, usePrivateMode: Bool) {
        pendingPrivateModeURL = Self.supportsApplicationLaunchArgumentsInCurrentBuild && usePrivateMode ? url : nil
        currentURLPrivateModeRequested = false
    }

    func consumeClipboardPrivateModeRequest(for url: URL) -> Bool {
        guard Self.supportsApplicationLaunchArgumentsInCurrentBuild,
              pendingPrivateModeURL == url else {
            return false
        }

        pendingPrivateModeURL = nil
        return true
    }

    static func freshSetupBrowsers() -> [BrowserConfig] {
        [BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")]
    }

    static var supportsApplicationLaunchArgumentsInCurrentBuild: Bool {
        #if APP_STORE
        false
        #else
        true
        #endif
    }

    /// Profiles & custom launch args can be ENTERED in every build (UI + local API) and
    /// are stored/portable. Auto-detection (reading the browser's Local State) only works
    /// in the direct build. They are APPLIED at launch reliably in the direct build; the
    /// App Store build attempts delivery via NSWorkspace, but macOS sandboxing may ignore
    /// launch arguments (developer.apple.com/forums/thread/657252).
    static var supportsBrowserProfilesInCurrentBuild: Bool { true }

    // Profiles & custom args are always STORED (so configs set via the local API /
    // import survive, and stay portable to the direct-download build). They are only
    // APPLIED at launch in the direct build — the App Store sandbox can't pass them.
    private static func normalizedProfileForCurrentBuild(_ profile: String?) -> String? {
        profile
    }

    private static func normalizedCustomArgumentsForCurrentBuild(_ customArguments: String?) -> String? {
        customArguments
    }

    private static func normalizedPrivateModeForCurrentBuild(_ usePrivateMode: Bool) -> Bool {
        supportsApplicationLaunchArgumentsInCurrentBuild ? usePrivateMode : false
    }

    func load() {
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([BrowserConfig].self, from: data) {
            configuredBrowsers = decoded.map { browser in
                var normalizedBrowser = browser
                normalizedBrowser.profile = Self.normalizedProfileForCurrentBuild(browser.profile)
                normalizedBrowser.customArguments = Self.normalizedCustomArgumentsForCurrentBuild(browser.customArguments)
                return normalizedBrowser
            }
        } else {
            configuredBrowsers = Self.freshSetupBrowsers()
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(configuredBrowsers) {
            defaults.set(encoded, forKey: defaultsKey)
        }
    }

    func saveRoutingRules() {
        if let encoded = try? JSONEncoder().encode(routingRules) {
            defaults.set(encoded, forKey: Constants.routingRulesKey)
        }
    }

    func saveRecentURLs() {
        if let encoded = try? JSONEncoder().encode(recentURLs) {
            defaults.set(encoded, forKey: Constants.recentURLsKey)
        }
    }

    private func scheduleSaveBrowsers() {
        guard !immediateWrite else { save(); return }
        pendingBrowsersSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.save() }
        }
        pendingBrowsersSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func scheduleSaveRules() {
        guard !immediateWrite else { saveRoutingRules(); return }
        pendingRulesSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.saveRoutingRules() }
        }
        pendingRulesSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func scheduleSaveRecentURLs() {
        guard !immediateWrite else { saveRecentURLs(); return }
        pendingRecentURLsSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.saveRecentURLs() }
        }
        pendingRecentURLsSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    func flushPendingSaves() {
        if pendingBrowsersSave != nil {
            pendingBrowsersSave?.cancel()
            pendingBrowsersSave = nil
            save()
        }
        if pendingRulesSave != nil {
            pendingRulesSave?.cancel()
            pendingRulesSave = nil
            saveRoutingRules()
        }
        if pendingRecentURLsSave != nil {
            pendingRecentURLsSave?.cancel()
            pendingRecentURLsSave = nil
            saveRecentURLs()
        }
    }

    private func scheduleTemporaryRouteExpirationTimer() {
        temporaryRouteExpirationTimer?.invalidate()
        guard let expiresAt = temporaryRoute?.expiresAt else { return }
        
        // If already expired, clear immediately
        if Date() >= expiresAt {
            temporaryRoute = nil
            return
        }

        temporaryRouteExpirationTimer = Timer.scheduledTimer(withTimeInterval: expiresAt.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.temporaryRoute = nil
            }
        }
    }

    func setTemporaryRoute(browserBundleId: String, profile: String?, duration: TimeInterval = 3600) {
        let expirationDate = Date().addingTimeInterval(duration)
        temporaryRoute = TemporaryRoute(browserBundleId: browserBundleId, profile: profile, expiresAt: expirationDate)
    }

    func clearTemporaryRoute() {
        temporaryRoute = nil
    }

    func loadRoutingRules() {
        if let data = defaults.data(forKey: Constants.routingRulesKey),
           let decoded = try? JSONDecoder().decode([BrowserRoutingRule].self, from: data) {
            routingRules = decoded.map { rule in
                var normalizedRule = rule
                normalizedRule.profile = Self.normalizedProfileForCurrentBuild(rule.profile)
                normalizedRule.usePrivateMode = Self.normalizedPrivateModeForCurrentBuild(rule.usePrivateMode)
                return normalizedRule
            }
        } else {
            routingRules = []
        }
    }

    func loadRecentURLs() {
        if let data = defaults.data(forKey: Constants.recentURLsKey),
           let decoded = try? JSONDecoder().decode([URL].self, from: data) {
            recentURLs = decoded
        } else {
            recentURLs = []
        }
    }

    func resetToFreshSetup() {
        restoreDefaultBrowserList()
        restoreDefaultRoutingRules()
        clearPersistedRecentURLs()
        recentURLs = []
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

    func addBrowser(name: String, bundleId: String, shortcutKey: String? = nil, profile: String? = nil) {
        let launchProfile = Self.normalizedProfileForCurrentBuild(profile)
        guard !configuredBrowsers.contains(where: { $0.bundleId == bundleId && $0.profile == launchProfile }) else {
            return
        }

        let key = shortcutKey.flatMap { normalizedShortcut($0) } ?? nextAvailableShortcutKey()
        configuredBrowsers.append(BrowserConfig(name: name, bundleId: bundleId, shortcutKey: key, profile: launchProfile))
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

    func updateBrowserCustomArguments(id: UUID, to args: String) {
        guard Self.supportsBrowserProfilesInCurrentBuild else { return }
        guard let index = configuredBrowsers.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = args.isEmpty ? nil : args
        if configuredBrowsers[index].customArguments != trimmed {
            configuredBrowsers[index].customArguments = trimmed
        }
    }

    func updateBrowserPrivateArguments(id: UUID, to args: String) {
        guard Self.supportsBrowserProfilesInCurrentBuild else { return }
        guard let index = configuredBrowsers.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = args.isEmpty ? nil : args
        if configuredBrowsers[index].privateArguments != trimmed {
            configuredBrowsers[index].privateArguments = trimmed
        }
    }

    /// Sets a browser's profile-directory string. Sandbox can't always auto-detect
    /// profiles, so this allows manual entry (and the MCP agent) to set it directly.
    func updateBrowserProfile(id: UUID, to profile: String) {
        guard Self.supportsBrowserProfilesInCurrentBuild else { return }
        guard let index = configuredBrowsers.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty ? nil : trimmed
        if configuredBrowsers[index].profile != normalized {
            configuredBrowsers[index].profile = normalized
        }
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

    // MARK: - Import / Export Rules

    func exportRules(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(routingRules)
        try data.write(to: url)
    }

    func importRules(from url: URL, skipExisting: Bool = false) throws -> ImportSummary {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([BrowserRoutingRule].self, from: data)

        var summary = ImportSummary()
        var updatedRules = routingRules
        
        for rule in decoded {
            guard case .success(let normalizedRule) = validatedRoutingRule(rule) else {
                summary.invalid += 1
                continue
            }

            if let existingIndex = updatedRules.firstIndex(where: { $0.id == rule.id }) {
                if skipExisting {
                    summary.skipped += 1
                    continue
                }
                // Update existing rule in place
                updatedRules[existingIndex] = normalizedRule
                summary.updated += 1
            } else {
                // Append new rule
                updatedRules.append(normalizedRule)
                summary.added += 1
            }
        }
        
        routingRules = updatedRules
        return summary
    }

    func exportBrowsers(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configuredBrowsers)
        try data.write(to: url)
    }

    func importBrowsers(from url: URL, skipExisting: Bool = false) throws -> ImportSummary {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([BrowserConfig].self, from: data)

        var summary = ImportSummary()
        var updatedBrowsers = configuredBrowsers
        
        for var browser in decoded {
            browser.profile = Self.normalizedProfileForCurrentBuild(browser.profile)
            browser.customArguments = Self.normalizedCustomArgumentsForCurrentBuild(browser.customArguments)
            if let existingIndex = updatedBrowsers.firstIndex(where: { $0.identity == browser.identity }) {
                if skipExisting {
                    summary.skipped += 1
                    continue
                }
                // Update existing browser in place, preserving its id and shortcut key
                let existingId = updatedBrowsers[existingIndex].id
                let existingKey = updatedBrowsers[existingIndex].shortcutKey
                browser.id = existingId
                browser.shortcutKey = existingKey
                updatedBrowsers[existingIndex] = browser
                summary.updated += 1
            } else {
                // Ensure shortcuts don't conflict for new browsers
                if updatedBrowsers.contains(where: { $0.shortcutKey == browser.shortcutKey }) {
                    browser.shortcutKey = nextAvailableShortcutKey(excluding: updatedBrowsers)
                }
                updatedBrowsers.append(browser)
                summary.added += 1
            }
        }
        configuredBrowsers = updatedBrowsers
        return summary
    }

    private func nextAvailableShortcutKey(excluding: [BrowserConfig]) -> String {
        for key in Constants.supportedShortcutKeys where !excluding.contains(where: { $0.shortcutKey == key }) {
            return key
        }
        return Constants.supportedShortcutKeys.last ?? "9"
    }

    // MARK: - Routing Rules

    @discardableResult
    func addRoutingRule(name: String, hostPattern: String, pathPrefix: String?, browserBundleId: String, profile: String? = nil, sourceAppBundleId: String? = nil, usePrivateMode: Bool = false, useRegex: Bool = false) -> Result<BrowserRoutingRule, RoutingRuleValidationError> {
        let rule = BrowserRoutingRule(
            name: name,
            hostPattern: hostPattern,
            pathPrefix: pathPrefix,
            browserBundleId: browserBundleId,
            profile: profile,
            sourceAppBundleId: sourceAppBundleId,
            usePrivateMode: usePrivateMode,
            useRegex: useRegex
        )
        return addRoutingRule(rule)
    }

    @discardableResult
    func addRoutingRule(_ rule: BrowserRoutingRule) -> Result<BrowserRoutingRule, RoutingRuleValidationError> {
        let result = validatedRoutingRule(rule)
        if case .success(let normalizedRule) = result {
            routingRules.append(normalizedRule)
        }
        return result
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
            profile: original.profile,
            isEnabled: original.isEnabled,
            sourceAppBundleId: original.sourceAppBundleId,
            usePrivateMode: original.usePrivateMode,
            useRegex: original.useRegex
        )
        guard case .success(let normalizedDuplicate) = validatedRoutingRule(duplicate) else { return }
        routingRules.insert(normalizedDuplicate, at: index + 1)
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

    func routingRuleProfile(for id: UUID) -> String? {
        routingRules.first(where: { $0.id == id })?.profile
    }

    func routingRuleIsEnabled(for id: UUID) -> Bool {
        routingRules.first(where: { $0.id == id })?.isEnabled ?? false
    }

    func updateRoutingRuleName(id: UUID, to name: String) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        var updated = routingRules[index]
        updated.name = name
        updateRule(updated)
    }

    func updateRoutingRuleHostPattern(id: UUID, to hostPattern: String) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        var updated = routingRules[index]
        updated.hostPattern = hostPattern
        updateRule(updated)
    }

    func updateRoutingRulePathPrefix(id: UUID, to pathPrefix: String) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        var updated = routingRules[index]
        updated.pathPrefix = pathPrefix
        updateRule(updated)
    }

    func updateRoutingRuleBrowser(id: UUID, to browserBundleId: String, profile: String? = nil) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        var updated = routingRules[index]
        updated.browserBundleId = browserBundleId
        updated.profile = profile
        updateRule(updated)
    }

    func updateRoutingRuleIsEnabled(id: UUID, to isEnabled: Bool) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        var updated = routingRules[index]
        updated.isEnabled = isEnabled
        updateRule(updated)
    }

    func updateRoutingRuleSourceApp(id: UUID, to bundleId: String?) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        var updated = routingRules[index]
        updated.sourceAppBundleId = bundleId
        updateRule(updated)
    }

    func updateRoutingRuleUsePrivateMode(id: UUID, to usePrivateMode: Bool) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        var updated = routingRules[index]
        updated.usePrivateMode = usePrivateMode
        updateRule(updated)
    }

    @discardableResult
    func updateRule(_ updated: BrowserRoutingRule) -> Result<BrowserRoutingRule, RoutingRuleValidationError> {
        guard let index = routingRules.firstIndex(where: { $0.id == updated.id }) else {
            return .failure(.ruleNotFound)
        }
        let result = validatedRoutingRule(updated)
        if case .success(let normalizedRule) = result {
            routingRules[index] = normalizedRule
        }
        return result
    }

    func resolvedRoute(for url: URL) -> (rule: BrowserRoutingRule?, browser: BrowserConfig)? {
        let host = (url.host ?? "").lowercased()
        guard !host.isEmpty else { return nil }

        let path = url.path.isEmpty ? "/" : url.path

        // 1. Check Temporary Overrides first
        if let temp = temporaryRoute, Date() < temp.expiresAt {
            if let targetBrowser = configuredBrowsers.first(where: { $0.bundleId == temp.browserBundleId && $0.profile == temp.profile }) {
                return (nil, targetBrowser)
            }
        }

        // 2. Evaluate rules
        for rule in routingRules where rule.isEnabled {
            guard hostMatches(host, pattern: rule.hostPattern, useRegex: rule.useRegex) else { continue }
            guard pathMatches(path, prefix: rule.pathPrefix) else { continue }
            if let ruleSource = rule.sourceAppBundleId, !ruleSource.isEmpty {
                guard ruleSource == (currentSourceAppBundleId ?? "") else { continue }
            }
            // The target may be a configured browser, OR an app that only exists as a
            // routing target (e.g. Slack) — synthesize it so it never has to appear in
            // the picker's browser list.
            let browser = configuredBrowsers.first(where: { $0.bundleId == rule.browserBundleId && $0.profile == rule.profile })
                ?? BrowserConfig(name: rule.name, bundleId: rule.browserBundleId, shortcutKey: "", profile: rule.profile)

            return (rule, browser)
        }

        // 3. Auto app-based selection (opt-in): route known app domains to the
        // installed app, even if it isn't an explicitly configured target.
        if autoNativeAppRouting, let app = NativeAppCatalog.appMatching(host: host) {
            let target = configuredBrowsers.first(where: { $0.bundleId.lowercased() == app.bundleId.lowercased() })
                ?? BrowserConfig(name: app.name, bundleId: app.bundleId, shortcutKey: "")
            return (nil, target)
        }

        return nil
    }

    func resolvedBrowser(for url: URL) -> BrowserConfig? {
        resolvedRoute(for: url)?.browser
    }

    // MARK: - URL Cleaning & Unshortening

    private static let trackingParameters: Set<String> = [
        // Google Analytics / Ads
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_source_platform", "utm_creative_format", "utm_marketing_tactic",
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "_ga", "_gl",
        // Meta / Facebook / Instagram
        "fbclid", "igshid",
        // Microsoft / Bing
        "msclkid",
        // Twitter / X
        "twclid",
        // Mailchimp
        "mc_cid", "mc_eid",
        // HubSpot
        "_hsenc", "_hsmi", "hsa_cam", "hsa_grp", "hsa_mt", "hsa_src",
        "hsa_ad", "hsa_acc", "hsa_net", "hsa_ver", "hsa_la", "hsa_ol",
        "hsa_kw", "hsa_tgt",
        // Yandex
        "yclid", "_openstat",
        // Adobe / Marketo
        "mkt_tok",
        // Other common trackers
        "si", "ref_src", "ref_url", "zanpid", "vero_id",
        "sclid", "s_cid", "ss_source", "ss_campaign_name",
    ]

    func cleanURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        
        if let queryItems = components.queryItems {
            let cleanedItems = queryItems.filter { !Self.trackingParameters.contains($0.name.lowercased()) }
            components.queryItems = cleanedItems.isEmpty ? nil : cleanedItems
        }
        
        return components.url ?? url
    }

    private static let shortenerDomains: Set<String> = [
        "t.co", "bit.ly", "tinyurl.com", "is.gd", "buff.ly", "ow.ly", "goo.gl", "lnkd.in"
    ]

    func unshortenURL(_ url: URL) async -> URL {
        guard let host = url.host?.lowercased(), Self.shortenerDomains.contains(host) else {
            return url
        }

        var currentURL = url
        var hops = 0
        let maxHops = 5
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        while hops < maxHops {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "HEAD"
            
            let delegate = RedirectHandler()
            let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
            
            do {
                let (_, response) = try await session.data(for: request)
                session.invalidateAndCancel()
                
                if let redirectURL = delegate.redirectLocation {
                    currentURL = redirectURL
                    hops += 1
                    continue
                }
                
                if let httpResponse = response as? HTTPURLResponse, 
                   (300...399).contains(httpResponse.statusCode),
                   let locationString = httpResponse.value(forHTTPHeaderField: "Location"),
                   let redirectURL = URL(string: locationString) {
                    currentURL = redirectURL
                    hops += 1
                    continue
                }
                
                // No redirect found on this hop, we have reached the final destination
                break
            } catch {
                session.invalidateAndCancel()
                break
            }
        }
        
        return currentURL
    }

    enum UnshortenError: Error {
        case invalidResponse
        case noRedirectFound
    }

    func manualUnshortenURL(_ url: URL) async throws -> URL {
        var currentURL = url
        var hops = 0
        let maxHops = 8
        var hasRedirected = false
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        while hops < maxHops {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "HEAD"
            
            // Spoof some generic desktop headers to bypass basic bot-blocking scripts
            // that some trackers or aggressive shorteners might use.
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            
            let delegate = RedirectHandler()
            let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
            
            do {
                let (_, response) = try await session.data(for: request)
                session.invalidateAndCancel()
                
                if let redirectURL = delegate.redirectLocation {
                    currentURL = redirectURL
                    hasRedirected = true
                    hops += 1
                    continue
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if (300...399).contains(httpResponse.statusCode),
                       let locationString = httpResponse.value(forHTTPHeaderField: "Location"),
                       let redirectURL = URL(string: locationString) {
                        currentURL = redirectURL
                        hasRedirected = true
                        hops += 1
                        continue
                    }
                    
                    // No redirect, we've hit the final end of the chain.
                    break
                }
                
                // Invalid response type, just stop here
                break
                
            } catch let error as URLError {
                session.invalidateAndCancel()
                if !hasRedirected {
                    throw error
                }
                break // Stop on network error, keep whatever hops we resolved so far
            } catch {
                session.invalidateAndCancel()
                break
            }
        }
        
        if hasRedirected {
            return currentURL
        } else {
            throw UnshortenError.noRedirectFound
        }
    }

    // URLSessionTaskDelegate to capture the redirect location without actually fetching the content
    private class RedirectHandler: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var _redirectLocation: URL?
        
        var redirectLocation: URL? {
            lock.lock()
            defer { lock.unlock() }
            return _redirectLocation
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            lock.lock()
            self._redirectLocation = request.url
            lock.unlock()
            // Returning nil via completionHandler halts the redirect chain immediately
            completionHandler(nil)
        }
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

    static func getInstalledBrowsers(includeHidden: Bool = false) -> [(name: String, bundleId: String, profile: String?, iconURL: URL?)] {
        // Clear the profile cache so we always pick up the latest profiles on disk.
        // This is cheap — detectProfiles reads a single JSON file per browser.
        BrowserProfileDetector.clearCache()
        if AppEnvironment.shouldUseMockInstalledBrowsers {
            let mockEntries: [(String, String, String?)] = [
                ("Google Chrome", "com.google.Chrome", nil),
                ("Firefox", "org.mozilla.firefox", nil),
                ("Safari", "com.apple.Safari", nil),
                ("Zen Browser", "app.zen-browser.zen", nil),
            ]

            return mockEntries.map { name, bundleId, profile in
                let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
                return (name, bundleId, profile, url)
            }
        }

        guard let dummyURL = URL(string: "https://sreerams.in") else { return [] }
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: dummyURL)

        // Apps that register as HTTP handlers but aren't browsers.
        let blockedBundleIDs = shared.hiddenBundleIDs

        let myBundleId = Bundle.main.bundleIdentifier ?? ""

        var browsers: [(String, String, String?, URL?)] = []
        var seenIdentities: Set<String> = []

        for url in appURLs {
            guard let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier else { continue }

            // Skip Chowser, Safari WebApps, and known non-browsers.
            if bundleId == myBundleId { continue }
            if bundleId.contains("apple.Safari.WebApp") { continue }
            if !includeHidden && blockedBundleIDs.contains(bundleId) { continue }

            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                       (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                       url.deletingPathExtension().lastPathComponent

            let profiles = BrowserProfileDetector.detectProfiles(for: bundleId)
            if profiles.isEmpty {
                let identity = "\(bundleId)|"
                guard seenIdentities.insert(identity).inserted else { continue }
                browsers.append((name, bundleId, nil, url))
            } else if profiles.count == 1 {
                let identity = "\(bundleId)|\(profiles[0].id)"
                guard seenIdentities.insert(identity).inserted else { continue }
                browsers.append((name, bundleId, profiles[0].id, url))
            } else {
                for profile in profiles {
                    let identity = "\(bundleId)|\(profile.id)"
                    guard seenIdentities.insert(identity).inserted else { continue }
                    browsers.append(("\(name) - \(profile.name)", bundleId, profile.id, url))
                }
            }
        }

        return browsers.sorted { $0.0 < $1.0 }
    }

    static func icon(forBrowserBundleID bundleId: String, fallbackURL: URL? = nil) -> NSImage? {
        if let fallbackURL {
            return NSWorkspace.shared.icon(forFile: fallbackURL.path)
        }

        return AppMetadataCache.shared.icon(for: bundleId)
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

    private enum BrowserFamily {
        case chromium, firefox, other
    }

    /// Browsers that enforce a single-process model and reject `/usr/bin/open -n`.
    /// For these, we omit `-n` so macOS routes the args to the already-running instance
    /// via the single-instance socket — the existing process then handles --profile-directory.
    private static let singleInstanceBrowsers: Set<String> = [
        "company.thebrowser.dia",
        "app.zen-browser.zen",
        "company.thebrowser.browser",
    ]

    /// Human-readable rendering engine for UI badges: "Chromium", "Firefox", or nil.
    static func browserEngineLabel(forBundleID bundleId: String) -> String? {
        switch browserFamily(for: bundleId) {
        case .chromium: return "Chromium"
        case .firefox: return "Firefox"
        case .other: return nil
        }
    }

    private static func browserFamily(for bundleId: String) -> BrowserFamily {
        // Chromium-family browsers accept --profile-directory.
        let chromiumMarkers = [
            "Chrome", "Brave", "Edge", "Vivaldi", "Arc", "company.thebrowser", // Arc + Dia
            "Chromium", "Opera", "Comet", "perplexity",                        // Perplexity Comet
            "Thorium", "Helium", "Wavebox", "Sidekick", "naver.whale",         // Whale
            "SamsungInternet", "Yandex", "Ungoogled", "Maxthon", "Sleipnir",
        ]
        if chromiumMarkers.contains(where: { bundleId.localizedCaseInsensitiveContains($0) }) {
            return .chromium
        }
        // Firefox-family browsers accept -P <profile>.
        let firefoxMarkers = [
            "Firefox", "Zen", "LibreWolf", "Waterfox", "Floorp",
            "Mullvad", "Basilisk", "palemoon", "pale-moon", "torproject", "IceCat",
        ]
        if firefoxMarkers.contains(where: { bundleId.localizedCaseInsensitiveContains($0) }) {
            return .firefox
        }
        // Note: Orion (Kagi) and Safari are WebKit-based — no profile-arg support.
        return .other
    }

    enum BrowserLaunchMode: Equatable {
        case directDownload
        case appStoreSandbox
    }

    struct BrowserLaunchPlan: Equatable {
        let mode: BrowserLaunchMode
        let bundleId: String
        let appURL: URL
        let documentURLs: [URL]
        let requestedApplicationArguments: [String]
        let deliveredApplicationArguments: [String]
        let argumentType: String?
        let applicationArgumentsSupported: Bool
        let createsNewApplicationInstance: Bool

        var usesDirectOpenTool: Bool {
            mode == .directDownload && !deliveredApplicationArguments.isEmpty
        }

        var directOpenArguments: [String] {
            var arguments: [String] = []
            if createsNewApplicationInstance {
                arguments.append("-n")
            }
            arguments += ["-a", appURL.path]
            arguments += documentURLs.map(\.absoluteString)
            if !deliveredApplicationArguments.isEmpty {
                arguments.append("--args")
                arguments += deliveredApplicationArguments
            }
            return arguments
        }
    }

    func open(url: URL, withBrowserBundleID bundleId: String, profile: String? = nil, usePrivateMode: Bool = false) {
        if AppEnvironment.shouldDisableExternalURLOpen {
            lastOpenedBrowserBundleIDForTesting = bundleId
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            print("Chowser: App not found for bundle ID: \(bundleId)")
            return
        }

        let browser = configuredBrowsers.first(where: { $0.bundleId.lowercased() == bundleId.lowercased() && $0.profile == profile })
        let customArgs = browser?.customArguments
        let privateArgs = browser?.privateArguments

        #if APP_STORE
        let launchMode = BrowserLaunchMode.appStoreSandbox
        #else
        let launchMode = BrowserLaunchMode.directDownload
        #endif

        let plan = Self.launchPlan(
            forBundleID: bundleId,
            appURL: appURL,
            url: url,
            profile: profile,
            customArguments: customArgs,
            privateArguments: privateArgs,
            usePrivateMode: usePrivateMode,
            mode: launchMode
        )

        #if APP_STORE
        // Sandboxed: attempt to pass launch args via OpenConfiguration (macOS may ignore
        // them). Direct build below delivers them reliably via /usr/bin/open --args.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = plan.createsNewApplicationInstance
        configuration.arguments = plan.deliveredApplicationArguments
        NSWorkspace.shared.open(plan.documentURLs, withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error = error {
                print("Chowser: Failed to open URL (Sandboxed): \(error)")
            }
        }
        #else
        if plan.usesDirectOpenTool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = plan.directOpenArguments
            do {
                try process.run()
            } catch {
                print("Chowser: Failed to launch browser with profile/private arguments: \(error)")
            }
        } else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = plan.createsNewApplicationInstance
            NSWorkspace.shared.open(plan.documentURLs, withApplicationAt: appURL, configuration: configuration) { _, error in
                if let error = error {
                    print("Chowser: Failed to open URL: \(error)")
                }
            }
        }
        #endif

        // Record frequency for suggestions
        if let domain = url.host {
            DomainFrequencyTracker.shared.record(domain: domain.lowercased(), browserBundleID: bundleId)
        }
    }

    static func launchPlan(
        forBundleID bundleId: String,
        appURL: URL,
        url: URL,
        profile: String?,
        customArguments: String?,
        privateArguments: String? = nil,
        usePrivateMode: Bool = false,
        mode: BrowserLaunchMode
    ) -> BrowserLaunchPlan {
        let launchInfo = launchInfo(
            forBundleID: bundleId,
            profile: profile,
            customArguments: customArguments,
            privateArguments: privateArguments,
            url: url,
            usePrivateMode: usePrivateMode
        )
        let documentURLs = [url]
        let requestedArguments = launchInfo?.arguments ?? []
        let filteredArguments = requestedArguments.filter { argument in
            !documentURLs.contains { $0.absoluteString == argument }
        }
        // Both builds attempt argument delivery: the direct build via
        // `/usr/bin/open --args` (reliable), the App Store build via
        // NSWorkspace.OpenConfiguration.arguments (macOS may drop them when sandboxed).
        let appArgumentsSupported = true
        let deliveredArguments = appArgumentsSupported ? filteredArguments : []

        return BrowserLaunchPlan(
            mode: mode,
            bundleId: bundleId,
            appURL: appURL,
            documentURLs: documentURLs,
            requestedApplicationArguments: requestedArguments,
            deliveredApplicationArguments: deliveredArguments,
            argumentType: launchInfo?.type,
            applicationArgumentsSupported: appArgumentsSupported,
            createsNewApplicationInstance: !singleInstanceBrowsers.contains(bundleId.lowercased())
        )
    }

    /// Generates the appropriate application arguments for a browser launch.
    /// Supports {profile} and {url} placeholders. Per-browser templates
    /// (customArguments for normal, privateArguments for private) take precedence over
    /// the built-in Chromium/Firefox defaults, so AI-researched flags work for any browser.
    static func launchInfo(forBundleID bundleId: String, profile: String?, customArguments: String?, privateArguments: String? = nil, url: URL, usePrivateMode: Bool = false) -> (arguments: [String], type: String)? {
        func expand(_ template: String) -> [String] {
            tokenizeCustomArguments(template).map {
                $0.replacingOccurrences(of: "{profile}", with: profile ?? "")
                    .replacingOccurrences(of: "{url}", with: url.absoluteString)
            }
        }

        // Explicit per-browser private template wins for private launches.
        if usePrivateMode, let custom = privateArguments, !custom.isEmpty {
            return (arguments: expand(custom), type: "custom-private")
        }
        // Explicit per-browser normal template (also used for private if no private template).
        if let custom = customArguments, !custom.isEmpty {
            return (arguments: expand(custom), type: "custom")
        }

        let family = browserFamily(for: bundleId)

        if usePrivateMode && profile == nil {
            switch family {
            case .chromium:
                return (arguments: ["--incognito"], type: "chromium-private")
            case .firefox:
                return (arguments: ["-private"], type: "firefox-private")
            case .other:
                return nil
            }
        }

        guard let profile = profile else { return nil }

        switch family {
        case .chromium:
            let args = usePrivateMode
                ? ["--incognito", "--profile-directory=\(profile)"]
                : ["--profile-directory=\(profile)"]
            return (arguments: args, type: "chromium")
        case .firefox:
            let args = usePrivateMode
                ? ["-private", "-P", profile]
                : ["-P", profile]
            return (arguments: args, type: "firefox")
        case .other:
            return nil
        }
    }

    private static func tokenizeCustomArguments(_ arguments: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var isEscaping = false

        for character in arguments {
            if isEscaping {
                current.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            if character == "\"" || character == "'" {
                if quote == character {
                    quote = nil
                    continue
                }
                if quote == nil {
                    quote = character
                    continue
                }
            }

            if quote == nil && character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(character)
        }

        if isEscaping {
            current.append("\\")
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    func isValidRoutingHostPattern(_ hostPattern: String, useRegex: Bool = false) -> Bool {
        if useRegex {
            let trimmed = hostPattern.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 500 else { return false }
            return (try? NSRegularExpression(pattern: trimmed)) != nil
        }
        let normalizedPattern = normalizedHostPattern(hostPattern)
        return isValidHostPattern(normalizedPattern)
    }

    /// Public normalization helper for rule host patterns (used by view closures).
    func normalizedRoutingHostPattern(_ pattern: String) -> String {
        normalizedHostPattern(pattern)
    }

    /// Replaces an existing routing rule (matched by ID) with an updated value.
    @discardableResult
    func updateRoutingRule(_ rule: BrowserRoutingRule) -> Result<BrowserRoutingRule, RoutingRuleValidationError> {
        updateRule(rule)
    }

    private func clearPersistedBrowserList() {
        defaults.removeObject(forKey: defaultsKey)
    }

    private func clearPersistedRoutingRules() {
        defaults.removeObject(forKey: Constants.routingRulesKey)
    }

    private func clearPersistedRecentURLs() {
        defaults.removeObject(forKey: Constants.recentURLsKey)
    }

    func addRecentURL(_ url: URL) {
        var newURLs = recentURLs
        newURLs.removeAll { $0 == url }
        newURLs.insert(url, at: 0)
        if newURLs.count > 5 {
            newURLs = Array(newURLs.prefix(5))
        }
        recentURLs = newURLs
    }

    private func loadHiddenBundleIDs() {
        if let stored = defaults.array(forKey: Constants.hiddenBundleIDsKey) as? [String] {
            hiddenBundleIDs = Set(stored)
        } else {
            // First launch: seed with defaults
            hiddenBundleIDs = Constants.defaultHiddenBundleIDs
        }
    }

    func addHiddenBundleID(_ bundleId: String) {
        hiddenBundleIDs.insert(bundleId)
    }

    func removeHiddenBundleID(_ bundleId: String) {
        hiddenBundleIDs.remove(bundleId)
    }

    func resetHiddenBundleIDs() {
        hiddenBundleIDs = Constants.defaultHiddenBundleIDs
    }

    private func loadPickerPreferences() {
        if let size = defaults.string(forKey: Constants.pickerIconSizeKey) {
            pickerIconSize = size
        }
        if defaults.object(forKey: Constants.pickerShowLabelsKey) != nil {
            pickerShowLabels = defaults.bool(forKey: Constants.pickerShowLabelsKey)
        }
        if let mode = defaults.string(forKey: Constants.pickerLayoutModeKey) {
            // Only accept known layout modes; ignore unexpected values to avoid invalid picker state
            let allowedModes: Set<String> = ["icons", "list"]
            if allowedModes.contains(mode) {
                pickerLayoutMode = mode
            }
        }
        if let density = defaults.string(forKey: Constants.densityPreferenceKey) {
            let allowedDensities: Set<String> = ["compact", "default", "comfortable"]
            if allowedDensities.contains(density) {
                densityPreference = density
            }
        }
        if let mode = defaults.string(forKey: Constants.pickerAppearanceModeKey),
           ["auto", "custom"].contains(mode) {
            pickerAppearanceMode = mode
        }
        if let tint = defaults.string(forKey: Constants.pickerTintHexKey) {
            pickerTintHex = tint
        }
        if defaults.object(forKey: Constants.pickerBackgroundOpacityKey) != nil {
            pickerBackgroundOpacity = min(1.0, max(0.2, defaults.double(forKey: Constants.pickerBackgroundOpacityKey)))
        }
        if defaults.object(forKey: Constants.pickerCornerRadiusKey) != nil {
            pickerCornerRadius = min(28, max(8, defaults.double(forKey: Constants.pickerCornerRadiusKey)))
        }
        if let accent = defaults.string(forKey: Constants.pickerAccentHexKey) {
            pickerAccentHex = accent
        }
        if defaults.object(forKey: Constants.pickerDimInactiveKey) != nil {
            pickerDimInactiveBrowsers = defaults.bool(forKey: Constants.pickerDimInactiveKey)
        }
        if let scheme = defaults.string(forKey: Constants.pickerColorSchemeKey),
           ["system", "light", "dark"].contains(scheme) {
            pickerColorScheme = scheme
        }
        if defaults.object(forKey: Constants.showLinkPreviewKey) != nil {
            showLinkPreview = defaults.bool(forKey: Constants.showLinkPreviewKey)
        }
        if defaults.object(forKey: Constants.autoNativeAppRoutingKey) != nil {
            autoNativeAppRouting = defaults.bool(forKey: Constants.autoNativeAppRoutingKey)
        }
    }

    /// Bundle IDs of browsers currently running, lowercased — for picker running-state dimming.
    static func runningBrowserBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
    }

    private func loadImportPreferences() {
        skipExistingImportedRules = defaults.object(forKey: Constants.skipExistingImportedRulesKey) == nil
            ? true
            : defaults.bool(forKey: Constants.skipExistingImportedRulesKey)
        skipExistingImportedBrowsers = defaults.object(forKey: Constants.skipExistingImportedBrowsersKey) == nil
            ? true
            : defaults.bool(forKey: Constants.skipExistingImportedBrowsersKey)
    }

    private func normalizedShortcut(_ key: String) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Constants.supportedShortcutKeys.contains(trimmed) else {
            return nil
        }

        return trimmed
    }

    private func normalizedHostPatterns(_ patterns: String) -> [String] {
        return patterns.components(separatedBy: ",")
            .map { normalizedHostPattern(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func validatedRoutingRule(_ rule: BrowserRoutingRule) -> Result<BrowserRoutingRule, RoutingRuleValidationError> {
        let launchProfile = Self.normalizedProfileForCurrentBuild(rule.profile)
        let launchPrivateMode = Self.normalizedPrivateModeForCurrentBuild(rule.usePrivateMode)
        guard configuredBrowsers.contains(where: { $0.bundleId == rule.browserBundleId && $0.profile == launchProfile }) else {
            return .failure(.browserNotFound(bundleId: rule.browserBundleId, profile: launchProfile))
        }

        let normalizedSourceBundleId: String?
        switch normalizedSourceAppBundleId(rule.sourceAppBundleId) {
        case .success(let value):
            normalizedSourceBundleId = value
        case .failure(let error):
            return .failure(error)
        }

        let normalizedPathPrefix: String?
        switch normalizedPathPrefixForStorage(rule.pathPrefix) {
        case .success(let value):
            normalizedPathPrefix = value
        case .failure(let error):
            return .failure(error)
        }

        let normalizedHost: String
        if rule.useRegex {
            let trimmed = rule.hostPattern.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 500, (try? NSRegularExpression(pattern: trimmed)) != nil else {
                return .failure(.invalidRegexPattern)
            }
            normalizedHost = trimmed
        } else {
            let normalizedHosts = normalizedHostPatterns(rule.hostPattern)
            guard isValidHostPatterns(normalizedHosts, sourceAppBundleId: normalizedSourceBundleId) else {
                return .failure(.invalidHostPattern)
            }
            normalizedHost = normalizedHosts.joined(separator: ", ")
        }

        let trimmedName = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)

        var normalizedRule = rule
        normalizedRule.name = trimmedName.isEmpty ? normalizedHost : trimmedName
        normalizedRule.hostPattern = normalizedHost
        normalizedRule.pathPrefix = normalizedPathPrefix
        normalizedRule.profile = launchProfile
        normalizedRule.sourceAppBundleId = normalizedSourceBundleId
        normalizedRule.usePrivateMode = launchPrivateMode
        return .success(normalizedRule)
    }

    private func isValidHostPatterns(_ patterns: [String], sourceAppBundleId: String? = nil) -> Bool {
        guard !patterns.isEmpty else { return false }
        for pattern in patterns {
            if !isValidHostPattern(pattern) { return false }
        }
        return true
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

        if normalized == "*" {
            return "*"
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

        if hostPattern == "*" {
            return true
        }

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
        (try? normalizedPathPrefixForStorage(pathPrefix).get()) ?? nil
    }

    private func normalizedPathPrefixForStorage(_ pathPrefix: String?) -> Result<String?, RoutingRuleValidationError> {
        guard let pathPrefix else { return .success(nil) }

        let trimmed = pathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .success(nil) }

        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !trimmed.contains("://"),
              !trimmed.hasPrefix("//") else {
            return .failure(.invalidPathPrefix)
        }

        if trimmed.hasPrefix("/") {
            return .success(trimmed)
        }

        return .success("/\(trimmed)")
    }

    private func normalizedSourceAppBundleId(_ bundleId: String?) -> Result<String?, RoutingRuleValidationError> {
        guard let bundleId else { return .success(nil) }

        let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .success(nil) }
        guard isValidBundleId(trimmed) else { return .failure(.invalidSourceAppBundleId) }
        return .success(trimmed)
    }

    private func isValidBundleId(_ bundleId: String) -> Bool {
        let labels = bundleId.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }

        return labels.allSatisfy { label in
            !label.isEmpty && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }

    private func hostMatches(_ host: String, pattern: String, useRegex: Bool = false) -> Bool {
        if useRegex {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let fullRange = NSRange(host.startIndex..., in: host)
                // Verify match covers the entire host string (immune to group-escape attacks)
                guard let match = regex.firstMatch(in: host, options: [], range: fullRange),
                      match.range == fullRange else {
                    return false
                }
                return true
            } catch {
                return false
            }
        }

        let normalizedPattern = normalizedHostPattern(pattern)
        guard !normalizedPattern.isEmpty else { return false }

        if normalizedPattern == "*" {
            return true
        }

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

        return path.lowercased().hasPrefix(normalizedPrefix.lowercased())
    }
}
