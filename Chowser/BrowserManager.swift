import Foundation
import AppKit
import SwiftUI
import ServiceManagement

/// Whether Chowser presents as a menu-bar-only utility (today's only behavior, no Dock
/// icon) or a regular app (Dock icon, appears in Cmd-Tab, no menu bar status item).
/// Existing installs are asked once on upgrade (`hasBeenAskedAppMode`), new installs are
/// asked during onboarding — see `AppModeStepView`.
enum ChowserAppMode: String, Codable {
    case menuBar
    case app
}

/// The four visual presentations available when an incoming URL needs a choice.
/// Raw values intentionally match the persisted/MCP API strings used by older builds.
enum PickerLayoutMode: String, Codable, CaseIterable, Hashable {
    case icons
    case list
    case radial
    case minimal
}

struct BrowserConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var bundleId: String // e.g. "com.apple.Safari"
    var shortcutKey: String // "1", "2", etc
    var profile: String? // Optional profile argument for browsers that support it
    var customArguments: String? // Normal-launch arg template (e.g. "--profile-directory={profile}")
    var privateArguments: String? // Private/incognito-launch arg template (e.g. "--incognito --profile-directory={profile}")
    var isEnabled: Bool = true // PRD FR-003: a disabled fallback browser must fall through to the picker

    var identity: String { "\(bundleId)|\(profile ?? "")" }
}

extension BrowserConfig {
    /// Custom `init(from:)`/`encode(to:)` (mirrors `BrowserRoutingRule` above) so that
    /// `isEnabled`, added after browsers were already being persisted, decodes to its
    /// default (`true`) for existing saved configs instead of throwing `keyNotFound` and
    /// silently wiping the browser list (see the `try?` decode at `BrowserManager.swift`'s
    /// `loadBrowsers`).
    private enum CodingKeys: String, CodingKey {
        case id, name, bundleId, shortcutKey, profile, customArguments, privateArguments, isEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        bundleId = try c.decode(String.self, forKey: .bundleId)
        shortcutKey = try c.decode(String.self, forKey: .shortcutKey)
        profile = try c.decodeIfPresent(String.self, forKey: .profile)
        customArguments = try c.decodeIfPresent(String.self, forKey: .customArguments)
        privateArguments = try c.decodeIfPresent(String.self, forKey: .privateArguments)
        isEnabled = (try c.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(bundleId, forKey: .bundleId)
        try c.encode(shortcutKey, forKey: .shortcutKey)
        try c.encodeIfPresent(profile, forKey: .profile)
        try c.encodeIfPresent(customArguments, forKey: .customArguments)
        try c.encodeIfPresent(privateArguments, forKey: .privateArguments)
        try c.encode(isEnabled, forKey: .isEnabled)
    }
}

struct BrowserRoutingRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var hostPattern: String
    var pathPrefix: String?
    var browserBundleId: String
    var profile: String?
    var isEnabled: Bool = true
    /// Zero source apps means "any source app" (FR-011). Matches when the incoming
    /// source app is present in this list (FR-012).
    var sourceAppBundleIDs: [String] = []
    var usePrivateMode: Bool = false
    var useRegex: Bool = false
}

extension BrowserRoutingRule {
    /// `legacySourceAppBundleId` decodes the old single-source shape (FR-014); it is
    /// never used for encoding, so exports always emit the plural `sourceAppBundleIDs`.
    private enum CodingKeys: String, CodingKey {
        case id, name, hostPattern, pathPrefix, browserBundleId, profile, isEnabled, sourceAppBundleIDs, usePrivateMode, useRegex
        case legacySourceAppBundleId = "sourceAppBundleId"
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
        if let ids = try c.decodeIfPresent([String].self, forKey: .sourceAppBundleIDs) {
            sourceAppBundleIDs = ids
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .legacySourceAppBundleId), !legacy.isEmpty {
            sourceAppBundleIDs = [legacy]
        } else {
            sourceAppBundleIDs = []
        }
        usePrivateMode = (try c.decodeIfPresent(Bool.self, forKey: .usePrivateMode)) ?? false
        useRegex = (try c.decodeIfPresent(Bool.self, forKey: .useRegex)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(hostPattern, forKey: .hostPattern)
        try c.encodeIfPresent(pathPrefix, forKey: .pathPrefix)
        try c.encode(browserBundleId, forKey: .browserBundleId)
        try c.encodeIfPresent(profile, forKey: .profile)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(sourceAppBundleIDs, forKey: .sourceAppBundleIDs)
        try c.encode(usePrivateMode, forKey: .usePrivateMode)
        try c.encode(useRegex, forKey: .useRegex)
    }
}

/// A migration-time suggestion (Phase 2) to merge two or more single-source routing
/// rules that share the same destination and match condition into one multi-source
/// rule. Computed once per install (gated by `hasSeenRuleMergeReview`) and only
/// applied on explicit user accept — never silently (see PRD "Migration-time merge assist").
struct RuleMergeSuggestion: Identifiable, Equatable {
    var id = UUID()
    var ruleIDs: [UUID]
    var mergedName: String
    var mergedSourceAppBundleIDs: [String]
    var browserBundleId: String
    var profile: String?
    var hostPattern: String
}

/// The global routing outcome for unmatched links: show the picker, or open a
/// specific configured browser/profile. See CONTEXT.md: "Fallback Policy".
struct BrowserFallbackPolicy: Codable, Equatable {
    enum Mode: String, Codable, Hashable {
        case picker
        case browser
    }

    var mode: Mode
    var browserID: UUID?
    var profile: String?

    init(mode: Mode = .picker, browserID: UUID? = nil, profile: String? = nil) {
        self.mode = mode
        self.browserID = browserID
        self.profile = profile
    }
}

@MainActor
@Observable final class BrowserManager {
    enum RoutingRuleValidationError: Error, Equatable {
        case browserNotFound(bundleId: String, profile: String?)
        case invalidHostPattern
        case invalidRegexPattern
        case regexTooComplex
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
            case .regexTooComplex:
                return "This pattern could cause severe slowdowns — simplify it."
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
        static let qrCodeAccentHexKey = "qrCodeAccentHex"
        static let pickerDimInactiveKey = "pickerDimInactive"
        static let pickerColorSchemeKey = "pickerColorScheme"
        static let showLinkPreviewKey = "showLinkPreview"
        static let densityPreferenceKey = "densityPreference"
        static let skipExistingImportedRulesKey = "skipExistingImportedRules"
        static let skipExistingImportedBrowsersKey = "skipExistingImportedBrowsers"
        static let appModeKey = "appMode"
        static let hasBeenAskedAppModeKey = "hasBeenAskedAppMode"
        static let fallbackPolicyKey = "fallbackPolicy"
        static let networkLookupsEnabledKey = "networkLookupsEnabled"
        static let userShortenerHostsKey = "userShortenerHosts"
        static let shortlinkResolutionTimeoutKey = "shortlinkResolutionTimeout"
        static let trackingCleanupEnabledKey = "trackingCleanupEnabled"
        static let hasSeenNetworkPrivacyUpgradeNoticeKey = "hasSeenNetworkPrivacyUpgradeNotice"
        static let hasSeenRuleMergeReviewKey = "hasSeenRuleMergeReview"
        static let rewriteRulesKey = "rewriteRules"
        static let mcpAutoStartEnabledKey = "mcpAutoStartEnabled"
        static let lastSeenRewriteCatalogVersionKey = "lastSeenRewriteCatalogVersion"
        static let catalogAppliedRuleNamesKey = "catalogAppliedRuleNames"
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

    /// Typed URL rewrite rules (FR-020), applied in order before routing-rule matching.
    var rewriteRules: [URLRewriteRule] = [] {
        didSet {
            scheduleSaveRewrites()
        }
    }

    /// Last skip reason per rewrite rule (FR-024), keyed by rule ID. In-memory only —
    /// reflects the most recent real (or tested) pipeline run, not persisted state.
    var rewriteSkipReasons: [UUID: String] = [:]

    /// True while the pre-picker pipeline (rewrites → shortlink resolution → cleanup) is
    /// still running on an incoming link. Drives the picker's loading state so a shortlink
    /// lookup taking up to `shortlinkResolutionTimeout` doesn't read as an app hang.
    var isResolvingIncomingURL: Bool = false

    /// Trace of rewrite steps applied to the currently-displayed picker URL (Phase 3
    /// cherry-pick: shown inline in the picker's link-preview area). In-memory only.
    var currentRewriteTrace: [RewritePipeline.Step] = []

    var launchAtLogin: Bool = false {
        didSet {
            guard launchAtLogin != oldValue else { return }
            updateLaunchAtLogin()
        }
    }
    /// Menu-bar-only utility vs. regular Dock app. Defaults to `.app` for a brand-new
    /// install with no persisted value; existing installs are asked explicitly once
    /// (`hasBeenAskedAppMode`) rather than silently switched, so this default only takes
    /// effect if that one-time question is somehow skipped. AppDelegate applies the
    /// activation-policy side effect (NSApp.setActivationPolicy) — this property is just
    /// the persisted preference, mirroring how `launchAtLogin` separates state from the
    /// SMAppService side effect in `updateLaunchAtLogin()`.
    var appMode: ChowserAppMode = .app {
        didSet {
            guard appMode != oldValue else { return }
            defaults.set(appMode.rawValue, forKey: Constants.appModeKey)
        }
    }
    var hasBeenAskedAppMode: Bool = false {
        didSet {
            defaults.set(hasBeenAskedAppMode, forKey: Constants.hasBeenAskedAppModeKey)
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

    /// What happens when no routing rule matches: show the picker, or open a
    /// specific configured browser/profile. Defaults to picker for every install
    /// (fresh and upgraded) per FR-005.
    var fallbackPolicy: BrowserFallbackPolicy = BrowserFallbackPolicy() {
        didSet {
            if let encoded = try? JSONEncoder().encode(fallbackPolicy) {
                defaults.set(encoded, forKey: Constants.fallbackPolicyKey)
            }
        }
    }

    /// Gates every network call Chowser makes before routing/previewing a link
    /// (shortlink resolution, FR-030; link-preview fetch, FR-034). Off by default,
    /// including on upgrade for existing installs — docs/adr/0003.
    var networkLookupsEnabled: Bool = false {
        didSet {
            defaults.set(networkLookupsEnabled, forKey: Constants.networkLookupsEnabledKey)
        }
    }

    /// User-appended shortener hosts, on top of the fixed built-in list (FR-031).
    var userShortenerHosts: Set<String> = [] {
        didSet {
            defaults.set(Array(userShortenerHosts), forKey: Constants.userShortenerHostsKey)
        }
    }

    /// Per-request timeout for shortlink resolution (FR-032). Visible in Settings.
    var shortlinkResolutionTimeout: Double = 1.5 {
        didSet {
            defaults.set(shortlinkResolutionTimeout, forKey: Constants.shortlinkResolutionTimeoutKey)
        }
    }

    /// Built-in tracking-parameter stripping, on/off (docs/adr/0002). On by default —
    /// this is today's always-on behavior, not a new privacy-sensitive default.
    var trackingCleanupEnabled: Bool = true {
        didSet {
            defaults.set(trackingCleanupEnabled, forKey: Constants.trackingCleanupEnabledKey)
        }
    }

    /// Whether the one-time "shortlink resolution is now off by default" notice has been
    /// shown, on either surface (picker banner or Settings > Behavior). Shared flag so it
    /// only shows once total, whichever surface the user hits first.
    var hasSeenNetworkPrivacyUpgradeNotice: Bool = false {
        didSet {
            defaults.set(hasSeenNetworkPrivacyUpgradeNotice, forKey: Constants.hasSeenNetworkPrivacyUpgradeNoticeKey)
        }
    }

    func markNetworkPrivacyUpgradeNoticeSeen() {
        guard !hasSeenNetworkPrivacyUpgradeNotice else { return }
        hasSeenNetworkPrivacyUpgradeNotice = true
    }

    /// Off by default — the MCP server is opt-in. Settable from Settings, or from
    /// Terminal for support/debugging without opening the UI:
    /// `defaults write in.sreerams.Chowser mcpAutoStartEnabled -bool true`, matching
    /// the existing `defaults delete in.sreerams.Chowser hasCompletedOnboarding`
    /// support pattern. Applied by `AppDelegate.setupApplicationState()` on launch.
    var mcpAutoStartEnabled: Bool = false {
        didSet {
            defaults.set(mcpAutoStartEnabled, forKey: Constants.mcpAutoStartEnabledKey)
        }
    }

    /// Highest predefined rewrite-catalog version the user has been notified about or
    /// applied (`RewriteCatalogService`). 0 means never checked.
    var lastSeenRewriteCatalogVersion: Int = 0 {
        didSet {
            defaults.set(lastSeenRewriteCatalogVersion, forKey: Constants.lastSeenRewriteCatalogVersionKey)
        }
    }

    /// Names of rewrite rules added from the predefined catalog. Lets us detect when a
    /// catalog-sourced rule is deleted so `lastSeenRewriteCatalogVersion` can be reset and
    /// the catalog re-offered (see `removeRewriteRule`).
    var catalogAppliedRuleNames: Set<String> = [] {
        didSet {
            defaults.set(Array(catalogAppliedRuleNames), forKey: Constants.catalogAppliedRuleNamesKey)
        }
    }

    /// Whether the one-time rule-merge-assist review has been shown (accepted/rejected/
    /// dismissed). Gates `pendingRuleMergeSuggestions` computation so it only runs once
    /// per install, not on every launch.
    var hasSeenRuleMergeReview: Bool = false {
        didSet {
            defaults.set(hasSeenRuleMergeReview, forKey: Constants.hasSeenRuleMergeReviewKey)
        }
    }

    /// Migration-time merge suggestions awaiting explicit accept/reject (never applied
    /// silently — see PRD "Migration-time merge assist"). Empty once reviewed.
    var pendingRuleMergeSuggestions: [RuleMergeSuggestion] = []

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

    /// Picker layout. Stored by raw value for compatibility with existing preferences.
    var pickerLayoutMode: PickerLayoutMode = .icons {
        didSet {
            defaults.set(pickerLayoutMode.rawValue, forKey: Constants.pickerLayoutModeKey)
        }
    }

    /// Ephemeral geometry selected when a radial picker is presented. It is deliberately
    /// not persisted: the shape depends on the cursor's screen-edge position for this link.
    var radialPickerShape: RadialPickerShape = .circle

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

    /// Hex color for "Send to Phone" QR code modules. Empty = falls back to pickerAccentHex/system accent.
    var qrCodeAccentHex: String = "" {
        didSet {
            defaults.set(qrCodeAccentHex, forKey: Constants.qrCodeAccentHexKey)
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
    @ObservationIgnored private var pendingRewritesSave: DispatchWorkItem?
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
        loadRewriteRules()
        loadHiddenBundleIDs()
        loadRecentURLs()
        loadPickerPreferences()
        if AppEnvironment.shouldUseRadialPickerFixture {
            configuredBrowsers = [
                BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
                BrowserConfig(name: "Chrome - Work", bundleId: "com.google.Chrome", shortcutKey: "2", profile: "Work"),
            ]
            pickerLayoutMode = .radial
        }
        loadImportPreferences()
        appMode = ChowserAppMode(rawValue: defaults.string(forKey: Constants.appModeKey) ?? "") ?? .app
        hasBeenAskedAppMode = defaults.bool(forKey: Constants.hasBeenAskedAppModeKey)
        loadFallbackPolicy()
        loadNetworkPrivacyPreferences()
        mcpAutoStartEnabled = defaults.bool(forKey: Constants.mcpAutoStartEnabledKey)
        lastSeenRewriteCatalogVersion = defaults.integer(forKey: Constants.lastSeenRewriteCatalogVersionKey)
        catalogAppliedRuleNames = Set(defaults.array(forKey: Constants.catalogAppliedRuleNamesKey) as? [String] ?? [])
        hasSeenRuleMergeReview = defaults.bool(forKey: Constants.hasSeenRuleMergeReviewKey)
        if !hasSeenRuleMergeReview {
            pendingRuleMergeSuggestions = Self.computeMergeSuggestions(for: routingRules)
        }
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

    func saveRewriteRules() {
        if let encoded = try? JSONEncoder().encode(rewriteRules) {
            defaults.set(encoded, forKey: Constants.rewriteRulesKey)
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

    private func scheduleSaveRewrites() {
        guard !immediateWrite else { saveRewriteRules(); return }
        pendingRewritesSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.saveRewriteRules() }
        }
        pendingRewritesSave = item
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
        if pendingRewritesSave != nil {
            pendingRewritesSave?.cancel()
            pendingRewritesSave = nil
            saveRewriteRules()
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

    func loadRewriteRules() {
        if let data = defaults.data(forKey: Constants.rewriteRulesKey),
           let decoded = try? JSONDecoder().decode([URLRewriteRule].self, from: data) {
            rewriteRules = decoded
        } else {
            rewriteRules = []
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

    private func loadFallbackPolicy() {
        if let data = defaults.data(forKey: Constants.fallbackPolicyKey),
           let decoded = try? JSONDecoder().decode(BrowserFallbackPolicy.self, from: data) {
            fallbackPolicy = decoded
        } else {
            fallbackPolicy = BrowserFallbackPolicy()
        }
    }

    private func loadNetworkPrivacyPreferences() {
        networkLookupsEnabled = defaults.object(forKey: Constants.networkLookupsEnabledKey) != nil
            ? defaults.bool(forKey: Constants.networkLookupsEnabledKey)
            : false
        if let stored = defaults.array(forKey: Constants.userShortenerHostsKey) as? [String] {
            userShortenerHosts = Set(stored)
        }
        if defaults.object(forKey: Constants.shortlinkResolutionTimeoutKey) != nil {
            shortlinkResolutionTimeout = defaults.double(forKey: Constants.shortlinkResolutionTimeoutKey)
        }
        trackingCleanupEnabled = defaults.object(forKey: Constants.trackingCleanupEnabledKey) != nil
            ? defaults.bool(forKey: Constants.trackingCleanupEnabledKey)
            : true
        hasSeenNetworkPrivacyUpgradeNotice = defaults.bool(forKey: Constants.hasSeenNetworkPrivacyUpgradeNoticeKey)
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

    /// Decodes the file as loosely-typed JSON first, then attempts each element's
    /// `Decodable` decode individually — a malformed element is skipped and counted
    /// in `summary.invalid` instead of failing the entire import (see PRD Architecture
    /// Notes "Correction": a single-shot `[BrowserRoutingRule].self` decode has no
    /// per-item resilience, one bad element fails the whole array).
    func importRules(from url: URL, skipExisting: Bool = false) throws -> ImportSummary {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        // Cast to `[Any]`, not `[[String: Any]]` — the latter returns nil for the whole
        // array if even one element isn't an object (e.g. null/string/number), which
        // used to fall through to a whole-array decode that throws and aborts the entire
        // import. Casting loosely lets each element be judged (and skipped) individually.
        guard let rawItems = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            // Not an array at all — surface the same decode error callers relied on
            // before (e.g. importing a non-JSON or non-array file).
            _ = try decoder.decode([BrowserRoutingRule].self, from: data)
            return ImportSummary()
        }

        var summary = ImportSummary()
        var updatedRules = routingRules

        for rawItem in rawItems {
            guard let rawObject = rawItem as? [String: Any],
                  let itemData = try? JSONSerialization.data(withJSONObject: rawObject),
                  let rule = try? decoder.decode(BrowserRoutingRule.self, from: itemData) else {
                summary.invalid += 1
                continue
            }

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
    func addRoutingRule(name: String, hostPattern: String, pathPrefix: String?, browserBundleId: String, profile: String? = nil, sourceAppBundleIDs: [String] = [], usePrivateMode: Bool = false, useRegex: Bool = false) -> Result<BrowserRoutingRule, RoutingRuleValidationError> {
        let rule = BrowserRoutingRule(
            name: name,
            hostPattern: hostPattern,
            pathPrefix: pathPrefix,
            browserBundleId: browserBundleId,
            profile: profile,
            sourceAppBundleIDs: sourceAppBundleIDs,
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
            sourceAppBundleIDs: original.sourceAppBundleIDs,
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

    func updateRoutingRuleSourceApps(id: UUID, to bundleIds: [String]) {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else { return }
        var updated = routingRules[index]
        updated.sourceAppBundleIDs = bundleIds
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

    /// Source app is an explicit parameter (mirrors `RewritePipeline.apply`) rather than
    /// always reading the ambient `currentSourceAppBundleId`, which is only set during a
    /// live URL open and `defer`-cleared immediately after — a tester/preview call site
    /// invoking this outside that window would otherwise always see `nil` and could never
    /// match a source-app condition. Defaults to the ambient property so existing live-open
    /// call sites (AppDelegate, ContentView) keep working unchanged.
    func resolvedRoute(for url: URL, sourceApp: String? = nil) -> (rule: BrowserRoutingRule?, browser: BrowserConfig)? {
        let effectiveSourceApp = sourceApp ?? currentSourceAppBundleId
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
            guard Self.hostMatches(host, pattern: rule.hostPattern, useRegex: rule.useRegex) else { continue }
            guard Self.pathMatches(path, prefix: rule.pathPrefix) else { continue }
            if !rule.sourceAppBundleIDs.isEmpty {
                guard let currentSource = effectiveSourceApp, rule.sourceAppBundleIDs.contains(currentSource) else { continue }
            }
            guard let browser = configuredBrowsers.first(where: { $0.bundleId == rule.browserBundleId && $0.profile == rule.profile }) else { continue }

            return (rule, browser)
        }

        return nil
    }

    func resolvedBrowser(for url: URL) -> BrowserConfig? {
        resolvedRoute(for: url)?.browser
    }

    /// The fallback destination for a link that matched no routing rule (FR-001/002).
    /// Returns nil (show the picker) when the mode is picker, or when the configured
    /// fallback browser was deleted, disabled, or hidden since it was chosen (FR-003).
    func fallbackRoute() -> (rule: BrowserRoutingRule?, browser: BrowserConfig)? {
        guard fallbackPolicy.mode == .browser, let browserID = fallbackPolicy.browserID else {
            return nil
        }
        guard let browser = configuredBrowsers.first(where: { $0.id == browserID }),
              browser.isEnabled,
              !hiddenBundleIDs.contains(browser.bundleId) else {
            return nil
        }
        return (nil, browser)
    }

    // MARK: - URL Rewrites

    enum RewriteRuleValidationError: Error, Equatable {
        case invalidHostPattern
        case invalidRegexPattern
        case regexTooComplex
        case invalidPathPrefix
        case invalidSourceAppBundleId
        case noActions
        case ruleNotFound

        var message: String {
            switch self {
            case .invalidHostPattern:
                return "Host pattern is invalid."
            case .invalidRegexPattern:
                return "Regex host pattern is invalid."
            case .regexTooComplex:
                return "This pattern could cause severe slowdowns — simplify it."
            case .invalidPathPrefix:
                return "Path prefix is invalid. Use a path such as /docs or docs."
            case .invalidSourceAppBundleId:
                return "Source app bundle ID is invalid."
            case .noActions:
                return "Add at least one action."
            case .ruleNotFound:
                return "Rewrite rule not found."
            }
        }
    }

    /// Runs the rewrite pipeline (FR-021/022) against a real or tested URL. Source app is
    /// an explicit parameter (Eng Review: "Source-app context must be explicit") rather than
    /// read from `currentSourceAppBundleId`, which is cleared via `defer` before later
    /// picker interactions (the tester, a live trace) would otherwise see it. Records each
    /// skipped rule's reason (FR-024) and logs the outcome through the existing "Route"
    /// category (FR-025b) — the same entry point the tester (FR-025) calls into.
    @discardableResult
    func applyRewritePipeline(to url: URL, sourceApp: String?) -> RewritePipeline.Result {
        let result = RewritePipeline.apply(url: url, rules: rewriteRules, sourceApp: sourceApp)
        for step in result.steps where step.skipped {
            rewriteSkipReasons[step.ruleID] = step.skipReason
        }
        if !result.steps.isEmpty {
            let summary = result.steps.map { "\($0.ruleName)\($0.skipped ? " (skipped: \($0.skipReason ?? "invalid output"))" : "")" }
            AppLogger.log("Route", "Rewrite pipeline: \(summary.joined(separator: " → "))")
        }
        return result
    }

    @discardableResult
    func addRewriteRule(_ rule: URLRewriteRule) -> Result<URLRewriteRule, RewriteRuleValidationError> {
        let result = validatedRewriteRule(rule)
        if case .success(let normalizedRule) = result {
            rewriteRules.append(normalizedRule)
        }
        return result
    }

    @discardableResult
    func updateRewriteRule(_ rule: URLRewriteRule) -> Result<URLRewriteRule, RewriteRuleValidationError> {
        guard let index = rewriteRules.firstIndex(where: { $0.id == rule.id }) else {
            return .failure(.ruleNotFound)
        }
        let result = validatedRewriteRule(rule)
        if case .success(let normalizedRule) = result {
            rewriteRules[index] = normalizedRule
        }
        return result
    }

    func removeRewriteRule(id: UUID) {
        if let removed = rewriteRules.first(where: { $0.id == id }),
           catalogAppliedRuleNames.contains(removed.name) {
            catalogAppliedRuleNames.remove(removed.name)
            // Re-offer the catalog: with the version gate reset, "Check for Updates"
            // re-fires even if the same or newer catalog is still current.
            lastSeenRewriteCatalogVersion = 0
        }
        rewriteRules.removeAll { $0.id == id }
        rewriteSkipReasons.removeValue(forKey: id)
    }

    func duplicateRewriteRule(id: UUID) {
        guard let index = rewriteRules.firstIndex(where: { $0.id == id }) else { return }
        let original = rewriteRules[index]
        let duplicate = URLRewriteRule(name: "\(original.name) Copy", isEnabled: original.isEnabled, match: original.match, actions: original.actions)
        guard case .success(let normalizedDuplicate) = validatedRewriteRule(duplicate) else { return }
        rewriteRules.insert(normalizedDuplicate, at: index + 1)
    }

    /// Keyboard-accessible reordering (design review: drag-only has no accessible
    /// equivalent) — Up/Down buttons in the Rewrites list call this directly.
    func moveRewriteRule(id: UUID, offsetBy delta: Int) {
        guard let index = rewriteRules.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + delta
        guard rewriteRules.indices.contains(destination) else { return }
        rewriteRules.move(fromOffsets: IndexSet(integer: index), toOffset: delta > 0 ? destination + 1 : destination)
    }

    func exportRewrites(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(rewriteRules)
        try data.write(to: url)
    }

    /// Same per-item-resilient decode restructuring as `importRules` (PRD Architecture
    /// Notes "Correction" — a naive `[URLRewriteRule].self` decode has no per-item
    /// resilience; one malformed element must not fail the whole import).
    func importRewrites(from url: URL, skipExisting: Bool = false) throws -> ImportSummary {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        // See `importRules` above: `[Any]`, not `[[String: Any]]`, so a non-object
        // element (null/string/number) is counted invalid instead of failing the cast
        // for the whole array and aborting the import.
        guard let rawItems = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            _ = try decoder.decode([URLRewriteRule].self, from: data)
            return ImportSummary()
        }

        var summary = ImportSummary()
        var updatedRewrites = rewriteRules

        for rawItem in rawItems {
            guard let rawObject = rawItem as? [String: Any],
                  let itemData = try? JSONSerialization.data(withJSONObject: rawObject),
                  let rule = try? decoder.decode(URLRewriteRule.self, from: itemData) else {
                summary.invalid += 1
                continue
            }

            guard case .success(let normalizedRule) = validatedRewriteRule(rule) else {
                summary.invalid += 1
                continue
            }

            if let existingIndex = updatedRewrites.firstIndex(where: { $0.id == rule.id }) {
                if skipExisting {
                    summary.skipped += 1
                    continue
                }
                updatedRewrites[existingIndex] = normalizedRule
                summary.updated += 1
            } else {
                updatedRewrites.append(normalizedRule)
                summary.added += 1
            }
        }

        rewriteRules = updatedRewrites
        return summary
    }

    private func validatedRewriteRule(_ rule: URLRewriteRule) -> Result<URLRewriteRule, RewriteRuleValidationError> {
        let normalizedActions = Self.normalizedRewriteActions(rule.actions)
        guard !normalizedActions.isEmpty else { return .failure(.noActions) }

        switch normalizedSourceAppBundleIDs(rule.match.sourceAppBundleIDs) {
        case .success(let value):
            let normalizedPathPrefixResult = Self.normalizedPathPrefixForStorage(rule.match.pathPrefix)
            let normalizedPathPrefix: String?
            switch normalizedPathPrefixResult {
            case .success(let path):
                normalizedPathPrefix = path
            case .failure:
                return .failure(.invalidPathPrefix)
            }

            let normalizedHost: String
            if rule.match.useRegex {
                let trimmed = rule.match.hostPattern.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed.count <= 500, (try? NSRegularExpression(pattern: trimmed)) != nil else {
                    return .failure(.invalidRegexPattern)
                }
                guard !Self.isDangerouslyComplexRegex(trimmed) else {
                    return .failure(.regexTooComplex)
                }
                normalizedHost = trimmed
            } else {
                let normalizedHosts = normalizedHostPatterns(rule.match.hostPattern)
                guard isValidHostPatterns(normalizedHosts) else {
                    return .failure(.invalidHostPattern)
                }
                normalizedHost = normalizedHosts.joined(separator: ", ")
            }

            var normalizedRule = rule
            let trimmedName = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
            normalizedRule.name = trimmedName.isEmpty ? normalizedHost : trimmedName
            normalizedRule.match.hostPattern = normalizedHost
            normalizedRule.match.pathPrefix = normalizedPathPrefix
            normalizedRule.match.sourceAppBundleIDs = value
            normalizedRule.match.schemes = Self.normalizedSchemes(rule.match.schemes)
            normalizedRule.actions = normalizedActions
            return .success(normalizedRule)
        case .failure:
            return .failure(.invalidSourceAppBundleId)
        }
    }

    private static func normalizedSchemes(_ schemes: [String]) -> [String] {
        var normalized: [String] = []
        for raw in schemes {
            let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard lowered == "http" || lowered == "https", !normalized.contains(lowered) else { continue }
            normalized.append(lowered)
        }
        return normalized
    }

    private static func normalizedRewriteActions(_ actions: [URLRewriteAction]) -> [URLRewriteAction] {
        actions.compactMap { action in
            switch action {
            case .forceScheme(let scheme):
                let trimmed = scheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return trimmed.isEmpty ? nil : .forceScheme(trimmed)
            case .replaceHost(let host):
                let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return trimmed.isEmpty ? nil : .replaceHost(trimmed)
            case .stripQueryParameters(let names):
                let trimmed = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                return trimmed.isEmpty ? nil : .stripQueryParameters(trimmed)
            case .stripQueryParameterPrefixes(let prefixes):
                let trimmed = prefixes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                return trimmed.isEmpty ? nil : .stripQueryParameterPrefixes(trimmed)
            case .setQueryParameter(let name, let value):
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedName.isEmpty ? nil : .setQueryParameter(name: trimmedName, value: value)
            case .removeFragment:
                return .removeFragment
            }
        }
    }

    // MARK: - Migration-Time Merge Assist

    /// Groups *consecutive* rules (in current order) that share every field except a
    /// single source app into merge suggestions. Requiring consecutiveness is the
    /// order-safety guarantee: any interleaved rule with a different match condition
    /// blocks the merge outright rather than risk changing which rule wins for a URL.
    static func computeMergeSuggestions(for rules: [BrowserRoutingRule]) -> [RuleMergeSuggestion] {
        guard rules.count >= 2 else { return [] }

        var suggestions: [RuleMergeSuggestion] = []
        var index = 0
        while index < rules.count {
            var group = [rules[index]]
            var next = index + 1
            while next < rules.count, isMergeableSignature(rules[index], rules[next]) {
                group.append(rules[next])
                next += 1
            }

            if group.count >= 2 {
                var mergedSources: [String] = []
                for rule in group {
                    for source in rule.sourceAppBundleIDs where !mergedSources.contains(source) {
                        mergedSources.append(source)
                    }
                }
                suggestions.append(RuleMergeSuggestion(
                    ruleIDs: group.map(\.id),
                    mergedName: group[0].name,
                    mergedSourceAppBundleIDs: mergedSources,
                    browserBundleId: group[0].browserBundleId,
                    profile: group[0].profile,
                    hostPattern: group[0].hostPattern
                ))
            }

            index = next > index + 1 ? next : index + 1
        }
        return suggestions
    }

    private static func isMergeableSignature(_ a: BrowserRoutingRule, _ b: BrowserRoutingRule) -> Bool {
        a.sourceAppBundleIDs.count == 1 &&
        b.sourceAppBundleIDs.count == 1 &&
        a.sourceAppBundleIDs != b.sourceAppBundleIDs &&
        a.hostPattern == b.hostPattern &&
        a.pathPrefix == b.pathPrefix &&
        a.browserBundleId == b.browserBundleId &&
        a.profile == b.profile &&
        a.isEnabled == b.isEnabled &&
        a.usePrivateMode == b.usePrivateMode &&
        a.useRegex == b.useRegex
    }

    @discardableResult
    func acceptRuleMergeSuggestion(_ suggestion: RuleMergeSuggestion) -> Bool {
        guard applyRuleMerge(suggestion) else { return false }
        pendingRuleMergeSuggestions.removeAll { $0.id == suggestion.id }
        return true
    }

    func rejectRuleMergeSuggestion(_ suggestion: RuleMergeSuggestion) {
        pendingRuleMergeSuggestions.removeAll { $0.id == suggestion.id }
    }

    func acceptAllPendingRuleMergeSuggestions() {
        for suggestion in pendingRuleMergeSuggestions {
            applyRuleMerge(suggestion)
        }
        pendingRuleMergeSuggestions.removeAll()
    }

    /// Marks the one-time review as complete so suggestions are never recomputed again.
    func finishRuleMergeReview() {
        hasSeenRuleMergeReview = true
        pendingRuleMergeSuggestions = []
    }

    @discardableResult
    private func applyRuleMerge(_ suggestion: RuleMergeSuggestion) -> Bool {
        guard let firstIndex = routingRules.firstIndex(where: { $0.id == suggestion.ruleIDs.first }) else { return false }

        var merged = routingRules[firstIndex]
        merged.sourceAppBundleIDs = suggestion.mergedSourceAppBundleIDs
        guard case .success(let normalizedMerged) = validatedRoutingRule(merged) else { return false }

        let groupIDs = Set(suggestion.ruleIDs)
        var updatedRules = routingRules.filter { !groupIDs.contains($0.id) }
        updatedRules.insert(normalizedMerged, at: firstIndex)

        routingRules = updatedRules
        // One-time migration write: a single synchronous save, not debounced (PRD:
        // "Persistence And Compatibility") — this isn't an interactive drag/typing edit.
        saveRoutingRules()
        return true
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
        guard trackingCleanupEnabled else { return url }
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

    /// Fixed built-in list plus any user-appended hosts (FR-031). The built-in list itself
    /// cannot be edited — users can only add to it.
    func isAllowedShortenerHost(_ host: String) -> Bool {
        let lowered = host.lowercased()
        return Self.shortenerDomains.contains(lowered) || userShortenerHosts.contains(lowered)
    }

    func addUserShortenerHost(_ host: String) {
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        userShortenerHosts.insert(normalized)
    }

    func removeUserShortenerHost(_ host: String) {
        userShortenerHosts.remove(host)
    }

    func unshortenURL(_ url: URL) async -> URL {
        guard networkLookupsEnabled,
              let host = url.host?.lowercased(), isAllowedShortenerHost(host) else {
            return url
        }

        var currentURL = url
        var hops = 0
        let maxHops = 5
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = shortlinkResolutionTimeout
        sessionConfig.timeoutIntervalForResource = shortlinkResolutionTimeout

        while hops < maxHops {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "HEAD"
            request.timeoutInterval = shortlinkResolutionTimeout

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
            AppLogger.error("Launch", "App not found for bundle ID: \(bundleId)")
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

        // No hostname/URL recorded, private mode or not — only the destination browser.
        AppLogger.log("Launch", "Opening link in \(bundleId) profile=\(profile ?? "-")")

        #if APP_STORE
        // Sandboxed: attempt to pass launch args via OpenConfiguration (macOS may ignore
        // them). Direct build below delivers them reliably via /usr/bin/open --args.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = plan.createsNewApplicationInstance
        configuration.arguments = plan.deliveredApplicationArguments
        NSWorkspace.shared.open(plan.documentURLs, withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error = error {
                AppLogger.error("Launch", "Failed to open URL (sandboxed): \(error)")
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
                AppLogger.error("Launch", "Failed to launch browser with profile/private arguments: \(error)")
            }
        } else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = plan.createsNewApplicationInstance
            NSWorkspace.shared.open(plan.documentURLs, withApplicationAt: appURL, configuration: configuration) { _, error in
                if let error = error {
                    AppLogger.error("Launch", "Failed to open URL: \(error)")
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
            guard (try? NSRegularExpression(pattern: trimmed)) != nil else { return false }
            return !Self.isDangerouslyComplexRegex(trimmed)
        }
        let normalizedPattern = Self.normalizedHostPattern(hostPattern)
        return isValidHostPattern(normalizedPattern)
    }

    /// Save-time ReDoS heuristic (FR-028): flags nested-quantifier shapes like `(a+)+` or
    /// `(a*)*`, interval-quantifier variants like `(a+){10,}` and `(a{2,})+`, overlapping
    /// alternation like `(a|a)*`/`(a|ab)*`, and directly-nested groups like `((a+))+` that
    /// cause catastrophic backtracking. A heuristic, not a formal classifier — see the
    /// PRD's Risks section; `hostMatches` also caps host length as a runtime backstop for
    /// whatever this heuristic misses. Runs only when a pattern is saved/edited, never at
    /// match time, so already-persisted rules are never retroactively re-validated.
    static func isDangerouslyComplexRegex(_ pattern: String) -> Bool {
        let nsPattern = pattern as NSString
        let fullRange = NSRange(location: 0, length: nsPattern.length)
        let quantifierSuffix = "(?:[+*]|\\{[0-9]+,?[0-9]*\\})"

        // A parenthesized group (no nested parens) immediately followed by `+`, `*`, or an
        // interval like `{10,}`. Covers `(a+)+` / `(a*)*` as well as interval variants:
        // `(a+){10,}` (interval outer) and `(a{2,})+` (interval inner).
        if let quantifiedGroup = try? NSRegularExpression(pattern: "\\(([^()]*)\\)\(quantifierSuffix)") {
            for match in quantifiedGroup.matches(in: pattern, range: fullRange) where match.numberOfRanges > 1 {
                let content = nsPattern.substring(with: match.range(at: 1))

                if content.range(of: "[+*]|\\{[0-9]+,?[0-9]*\\}", options: .regularExpression) != nil {
                    return true
                }

                // Overlapping/duplicate alternation branches under a quantifier, e.g.
                // `(a|a)*` (identical branches) or `(a|ab)*` (one branch a prefix of another).
                if content.contains("|") {
                    let branches = content.components(separatedBy: "|")
                    for i in 0..<branches.count {
                        for j in (i + 1)..<branches.count {
                            let (a, b) = (branches[i], branches[j])
                            guard !a.isEmpty, !b.isEmpty else { continue }
                            if a == b || a.hasPrefix(b) || b.hasPrefix(a) { return true }
                        }
                    }
                }
            }
        }

        // A group directly nested inside another group with an inner quantifier, itself
        // under an outer quantifier, e.g. `((a+))+` — the check above can't see across the
        // inner group's own parens, so this needs its own pattern.
        if let nestedGroup = try? NSRegularExpression(pattern: "\\(\\([^()]*[+*][^()]*\\)\\)\(quantifierSuffix)"),
           nestedGroup.firstMatch(in: pattern, range: fullRange) != nil {
            return true
        }

        return false
    }

    /// Public normalization helper for rule host patterns (used by view closures).
    func normalizedRoutingHostPattern(_ pattern: String) -> String {
        Self.normalizedHostPattern(pattern)
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
        if let rawMode = defaults.string(forKey: Constants.pickerLayoutModeKey),
           let mode = PickerLayoutMode(rawValue: rawMode) {
            pickerLayoutMode = mode
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
        if let qrAccent = defaults.string(forKey: Constants.qrCodeAccentHexKey) {
            qrCodeAccentHex = qrAccent
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
            .map { Self.normalizedHostPattern(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func validatedRoutingRule(_ rule: BrowserRoutingRule) -> Result<BrowserRoutingRule, RoutingRuleValidationError> {
        let launchProfile = Self.normalizedProfileForCurrentBuild(rule.profile)
        let launchPrivateMode = Self.normalizedPrivateModeForCurrentBuild(rule.usePrivateMode)
        guard configuredBrowsers.contains(where: { $0.bundleId == rule.browserBundleId && $0.profile == launchProfile }) else {
            return .failure(.browserNotFound(bundleId: rule.browserBundleId, profile: launchProfile))
        }

        let normalizedSourceBundleIDs: [String]
        switch normalizedSourceAppBundleIDs(rule.sourceAppBundleIDs) {
        case .success(let value):
            normalizedSourceBundleIDs = value
        case .failure(let error):
            return .failure(error)
        }

        let normalizedPathPrefix: String?
        switch Self.normalizedPathPrefixForStorage(rule.pathPrefix) {
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
            guard !Self.isDangerouslyComplexRegex(trimmed) else {
                return .failure(.regexTooComplex)
            }
            normalizedHost = trimmed
        } else {
            let normalizedHosts = normalizedHostPatterns(rule.hostPattern)
            guard isValidHostPatterns(normalizedHosts) else {
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
        normalizedRule.sourceAppBundleIDs = normalizedSourceBundleIDs
        normalizedRule.usePrivateMode = launchPrivateMode
        return .success(normalizedRule)
    }

    private func isValidHostPatterns(_ patterns: [String]) -> Bool {
        guard !patterns.isEmpty else { return false }
        for pattern in patterns {
            if !isValidHostPattern(pattern) { return false }
        }
        return true
    }

    /// Static (not just private) so `RewritePipeline` — a separate pure type — can reuse
    /// the exact same host-matching logic routing rules use (Eng Review: rewrite engine
    /// must literally share code with routing, not just look similar).
    static func normalizedHostPattern(_ hostPattern: String) -> String {
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

    static func normalizedPathPrefix(_ pathPrefix: String?) -> String? {
        (try? normalizedPathPrefixForStorage(pathPrefix).get()) ?? nil
    }

    static func normalizedPathPrefixForStorage(_ pathPrefix: String?) -> Result<String?, RoutingRuleValidationError> {
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

    private func normalizedSourceAppBundleIDs(_ bundleIds: [String]) -> Result<[String], RoutingRuleValidationError> {
        var normalized: [String] = []
        for raw in bundleIds {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard isValidBundleId(trimmed) else { return .failure(.invalidSourceAppBundleId) }
            if !normalized.contains(trimmed) {
                normalized.append(trimmed)
            }
        }
        return .success(normalized)
    }

    private func isValidBundleId(_ bundleId: String) -> Bool {
        let labels = bundleId.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }

        return labels.allSatisfy { label in
            !label.isEmpty && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }

    /// Hard runtime backstop (Security Review, round 2): the save-time `isDangerouslyComplexRegex`
    /// heuristic can never catch every catastrophic-backtracking shape. A length cap only bounds
    /// anything if it's near the actual worst case, not an arbitrary "large" number — classic
    /// catastrophic regexes exhaust NSRegularExpression's backtracking budget around 30-60 input
    /// characters, so a 2000-char cap (the original value here) protected nothing: any hostname
    /// short enough to be real (DNS labels cap total hostname length at 253 chars, RFC 1035) would
    /// already trigger the hang before ever approaching that cap. 253 is both the real-world bound
    /// (nothing valid is longer) and small enough to actually matter for pathological patterns.
    static let maxRegexHostLength = 253

    static func hostMatches(_ host: String, pattern: String, useRegex: Bool = false) -> Bool {
        if useRegex {
            guard host.count <= maxRegexHostLength else { return false }
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

    static func pathMatches(_ path: String, prefix: String?) -> Bool {
        guard let normalizedPrefix = normalizedPathPrefix(prefix) else {
            return true
        }

        return path.lowercased().hasPrefix(normalizedPrefix.lowercased())
    }
}
