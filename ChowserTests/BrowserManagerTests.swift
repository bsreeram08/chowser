import Testing
import Foundation
@testable import Chowser

// MARK: - BrowserManager Tests

struct BrowserManagerTests {
    
    /// Creates an isolated UserDefaults suite for testing so we don't touch real preferences.
    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "com.chowser.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return defaults
    }
    
    /// Cleans up a test defaults suite.
    private func cleanupDefaults(_ defaults: UserDefaults, suiteName: String? = nil) {
        defaults.removePersistentDomain(forName: defaults.description)
    }
    
    // MARK: - App Mode

    @Test("App mode defaults to .app on a fresh install, hasBeenAskedAppMode defaults to false")
    @MainActor
    func appModeDefaultsToAppOnFreshInstall() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        #expect(manager.appMode == .app)
        #expect(manager.hasBeenAskedAppMode == false)
    }

    @Test("App mode and hasBeenAskedAppMode persist across manager instances")
    @MainActor
    func appModePersists() {
        let defaults = makeTestDefaults()
        let manager1 = BrowserManager(defaults: defaults)
        manager1.appMode = .menuBar
        manager1.hasBeenAskedAppMode = true

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.appMode == .menuBar)
        #expect(manager2.hasBeenAskedAppMode == true)
    }

    // MARK: - Default State

    @Test("Fresh manager loads default Safari browser")
    @MainActor
    func defaultBrowserOnFirstLaunch() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        #expect(manager.configuredBrowsers.count == 1)
        #expect(manager.configuredBrowsers[0].name == "Safari")
        #expect(manager.configuredBrowsers[0].bundleId == "com.apple.Safari")
        #expect(manager.configuredBrowsers[0].shortcutKey == "1")
        #expect(manager.hasCompletedOnboarding == false)
    }
    
    // MARK: - Persistence (Save & Load)
    
    @Test("Saved browsers persist across manager instances")
    @MainActor
    func saveAndLoad() {
        let defaults = makeTestDefaults()
        
        // Create manager and add browsers
        let manager1 = BrowserManager(defaults: defaults)
        manager1.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "2"),
        ]
        
        // Create new manager instance with same defaults — should load our saved data
        let manager2 = BrowserManager(defaults: defaults)
        
        #expect(manager2.configuredBrowsers.count == 2)
        #expect(manager2.configuredBrowsers[0].name == "Chrome")
        #expect(manager2.configuredBrowsers[1].name == "Firefox")
    }
    
    @Test("Empty browser list persists correctly")
    @MainActor
    func saveEmptyList() {
        let defaults = makeTestDefaults()
        
        let manager1 = BrowserManager(defaults: defaults)
        manager1.configuredBrowsers = []
        
        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.configuredBrowsers.isEmpty)
    }
    
    // MARK: - Add Browser
    
    @Test("Adding a browser appends to list and persists")
    @MainActor
    func addBrowser() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        let newBrowser = BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "2", profile: "Work")
        manager.configuredBrowsers.append(newBrowser)
        
        #expect(manager.configuredBrowsers.count == 2)
        #expect(manager.configuredBrowsers[1].name == "Arc")
        #expect(manager.configuredBrowsers[1].profile == "Work")
        
        // Verify persistence
        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.configuredBrowsers.count == 2)
        #expect(manager2.configuredBrowsers[1].bundleId == "company.thebrowser.Browser")
        #expect(manager2.configuredBrowsers[1].profile == "Work")
    }
    
    // MARK: - Remove Browser
    
    @Test("Removing a browser by ID works")
    @MainActor
    func removeBrowserById() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        let firefox = BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3")
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            chrome,
            firefox,
        ]
        
        // Remove Chrome
        manager.configuredBrowsers.removeAll { $0.id == chrome.id }
        
        #expect(manager.configuredBrowsers.count == 2)
        #expect(manager.configuredBrowsers[0].name == "Safari")
        #expect(manager.configuredBrowsers[1].name == "Firefox")
    }
    
    @Test("Removing by offset works (used by onDelete)")
    @MainActor
    func removeBrowserByOffset() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3"),
        ]
        
        manager.configuredBrowsers.remove(atOffsets: IndexSet(integer: 1))
        
        #expect(manager.configuredBrowsers.count == 2)
        #expect(manager.configuredBrowsers[0].name == "Safari")
        #expect(manager.configuredBrowsers[1].name == "Firefox")
    }
    
    // MARK: - Reorder
    
    @Test("Moving browsers reorders and persists")
    @MainActor
    func reorderBrowsers() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3"),
        ]
        
        // Move Firefox (index 2) to the front (before index 0)
        manager.configuredBrowsers.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        
        #expect(manager.configuredBrowsers[0].name == "Firefox")
        #expect(manager.configuredBrowsers[1].name == "Safari")
        #expect(manager.configuredBrowsers[2].name == "Chrome")
        
        // Verify persistence
        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.configuredBrowsers[0].name == "Firefox")
    }
    
    // MARK: - Shortcut Key Assignment
    
    @Test("Shortcut keys default incrementally when adding browsers")
    @MainActor
    func shortcutKeyAssignment() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        // Simulate the AddBrowserSheet logic
        for i in 1...9 {
            let key = String(min(manager.configuredBrowsers.count + 1, 9))
            let browser = BrowserConfig(
                name: "Browser \(i)",
                bundleId: "com.test.browser\(i)",
                shortcutKey: key
            )
            manager.configuredBrowsers.append(browser)
        }
        
        // First added browser (after default Safari) should get key "2"
        #expect(manager.configuredBrowsers[1].shortcutKey == "2")
        // Keys cap at "9"
        #expect(manager.configuredBrowsers.last!.shortcutKey == "9")
    }
    
    // MARK: - Editing Browser Name
    
    @Test("Editing browser name persists")
    @MainActor
    func editBrowserName() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        manager.configuredBrowsers[0].name = "Safari (Private)"
        
        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.configuredBrowsers[0].name == "Safari (Private)")
    }
    
    // MARK: - Corrupted Data
    
    @Test("Corrupted defaults data falls back to default Safari")
    @MainActor
    func corruptedDataFallback() {
        let defaults = makeTestDefaults()
        
        // Write garbage data
        defaults.set(Data("not valid json".utf8), forKey: "configuredBrowsers")
        
        let manager = BrowserManager(defaults: defaults)
        
        // Should fall back to default
        #expect(manager.configuredBrowsers.count == 1)
        #expect(manager.configuredBrowsers[0].name == "Safari")
    }

    // MARK: - Fresh Setup Reset

    @Test("Reset to fresh setup restores default Safari browser")
    @MainActor
    func resetToFreshSetupRestoresDefaults() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3"),
        ]
        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome"
        )
        manager.completeOnboarding()

        manager.resetToFreshSetup()

        #expect(manager.configuredBrowsers.count == 1)
        #expect(manager.configuredBrowsers[0].name == "Safari")
        #expect(manager.configuredBrowsers[0].bundleId == "com.apple.Safari")
        #expect(manager.configuredBrowsers[0].shortcutKey == "1")
        #expect(manager.routingRules.isEmpty)
        #expect(manager.hasCompletedOnboarding == false)
    }

    @Test("Completing onboarding persists across manager instances")
    @MainActor
    func completeOnboardingPersists() {
        let defaults = makeTestDefaults()
        let manager1 = BrowserManager(defaults: defaults)
        manager1.completeOnboarding()

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.hasCompletedOnboarding == true)
    }

    // MARK: - Shortcut Conflict Handling

    @Test("Updating a shortcut swaps conflicting assignments")
    @MainActor
    func shortcutSwapOnConflict() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        manager.configuredBrowsers = [safari, chrome]

        manager.updateShortcutKey(id: safari.id, to: "2")

        let updatedSafari = manager.configuredBrowsers.first { $0.id == safari.id }
        let updatedChrome = manager.configuredBrowsers.first { $0.id == chrome.id }

        #expect(updatedSafari?.shortcutKey == "2")
        #expect(updatedChrome?.shortcutKey == "1")
    }

    // MARK: - Routing Rules

    @Test("Routing rules match exact host and optional path prefix")
    @MainActor
    func routingRuleExactMatch() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "GitHub Orgs",
            hostPattern: "github.com",
            pathPrefix: "/orgs",
            browserBundleId: "company.thebrowser.Browser"
        )

        let matchingURL = URL(string: "https://github.com/orgs/anyaiapp")!
        let nonMatchingURL = URL(string: "https://github.com/settings")!

        #expect(manager.resolvedBrowser(for: matchingURL)?.bundleId == "company.thebrowser.Browser")
        #expect(manager.resolvedBrowser(for: nonMatchingURL) == nil)
    }

    @Test("Routing rules support wildcard host patterns")
    @MainActor
    func routingRuleWildcardHostMatch() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "Google Workspace",
            hostPattern: "*.google.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome"
        )

        let subdomainURL = URL(string: "https://mail.google.com/mail/u/0/#inbox")!
        let rootURL = URL(string: "https://google.com/search?q=swift")!
        let differentDomainURL = URL(string: "https://duckduckgo.com")!

        #expect(manager.resolvedBrowser(for: subdomainURL)?.bundleId == "com.google.Chrome")
        #expect(manager.resolvedBrowser(for: rootURL)?.bundleId == "com.google.Chrome")
        #expect(manager.resolvedBrowser(for: differentDomainURL) == nil)
    }

    @Test("Routing rules support global wildcard host pattern")
    @MainActor
    func routingRuleGlobalWildcardHostMatch() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "All Hosts",
            hostPattern: "*",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome"
        )

        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].hostPattern == "*")
        #expect(manager.resolvedBrowser(for: URL(string: "https://github.com")!)?.bundleId == "com.google.Chrome")
        #expect(manager.resolvedBrowser(for: URL(string: "https://anyaiapp.com/research")!)?.bundleId == "com.google.Chrome")
    }

    @Test("Global wildcard rules can be scoped by source app")
    @MainActor
    func routingRuleGlobalWildcardWithSourceApp() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "WhatsApp to Chrome",
            hostPattern: "*",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["net.whatsapp.WhatsApp"]
        )

        let url = URL(string: "https://news.ycombinator.com")!
        manager.currentSourceAppBundleId = "com.apple.Safari"
        #expect(manager.resolvedRoute(for: url) == nil)

        manager.currentSourceAppBundleId = "net.whatsapp.WhatsApp"
        #expect(manager.resolvedRoute(for: url)?.browser.bundleId == "com.google.Chrome")
        #expect(manager.resolvedRoute(for: url)?.rule?.sourceAppBundleIDs == ["net.whatsapp.WhatsApp"])
    }

    @Test("A rule with multiple source apps matches any of them (FR-010/012), zero means any (FR-011)")
    @MainActor
    func routingRuleMatchesAnyOfMultipleSourceApps() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
        ]

        manager.addRoutingRule(
            name: "Work Chat Apps",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["com.tinyspeck.slackmacgap", "com.apple.mail"]
        )

        let url = URL(string: "https://github.com/org/repo")!

        manager.currentSourceAppBundleId = "com.tinyspeck.slackmacgap"
        #expect(manager.resolvedRoute(for: url)?.browser.bundleId == "com.google.Chrome")

        manager.currentSourceAppBundleId = "com.apple.mail"
        #expect(manager.resolvedRoute(for: url)?.browser.bundleId == "com.google.Chrome")

        // Zero source apps in the incoming context, or a source not in the list: no match.
        manager.currentSourceAppBundleId = nil
        #expect(manager.resolvedRoute(for: url) == nil)

        manager.currentSourceAppBundleId = "com.tinyspeck.linear"
        #expect(manager.resolvedRoute(for: url) == nil)
    }

    @Test("Apple Event URL helper rejects invalid URL payloads")
    func appleEventURLRejectsInvalidPayloads() {
        #expect(AppDelegate.appleEventURL(from: nil) == nil)
        #expect(AppDelegate.appleEventURL(from: "") == nil)
        #expect(AppDelegate.appleEventURL(from: "github.com/path") == nil)
        #expect(AppDelegate.appleEventURL(from: "https://github.com/path")?.absoluteString == "https://github.com/path")
    }

    @Test("Source app helper resolves PID before sender bundle and frontmost fallback")
    func sourceAppResolutionPrefersPIDThenSenderThenFrontmost() {
        var senderPID = pid_t(4242)
        let senderPIDData = withUnsafeBytes(of: &senderPID) { Data($0) }

        let pidResolved = AppDelegate.sourceAppBundleIdentifier(
            senderPIDData: senderPIDData,
            senderBundleIdentifier: "com.sender.bundle",
            frontmostBundleIdentifier: "com.frontmost.bundle",
            ownBundleIdentifier: "in.sreerams.Chowser",
            runningApplicationBundleIdentifier: { pid in
                #expect(pid == 4242)
                return "com.pid.bundle"
            }
        )
        #expect(pidResolved == "com.pid.bundle")

        let senderResolved = AppDelegate.sourceAppBundleIdentifier(
            senderPIDData: nil,
            senderBundleIdentifier: "com.sender.bundle",
            frontmostBundleIdentifier: "com.frontmost.bundle",
            ownBundleIdentifier: "in.sreerams.Chowser",
            runningApplicationBundleIdentifier: { _ in nil }
        )
        #expect(senderResolved == "com.sender.bundle")

        let frontmostResolved = AppDelegate.sourceAppBundleIdentifier(
            senderPIDData: nil,
            senderBundleIdentifier: nil,
            frontmostBundleIdentifier: "com.frontmost.bundle",
            ownBundleIdentifier: "in.sreerams.Chowser",
            runningApplicationBundleIdentifier: { _ in nil }
        )
        #expect(frontmostResolved == "com.frontmost.bundle")

        let ownAppIgnored = AppDelegate.sourceAppBundleIdentifier(
            senderPIDData: nil,
            senderBundleIdentifier: nil,
            frontmostBundleIdentifier: "in.sreerams.Chowser",
            ownBundleIdentifier: "in.sreerams.Chowser",
            runningApplicationBundleIdentifier: { _ in nil }
        )
        #expect(ownAppIgnored == nil)
    }

    @Test("Incoming URL route uses source app and clears routing context")
    @MainActor
    func incomingURLRouteUsesSourceAppAndClearsContext() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]
        manager.addRoutingRule(
            name: "Slack GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        manager.currentSourceAppBundleId = "com.tinyspeck.slackmacgap"
        let route = AppDelegate.resolveIncomingURLRoute(
            for: URL(string: "https://github.com/org/repo")!,
            using: manager,
            forceShowPicker: false
        )

        #expect(route?.browser.bundleId == "com.google.Chrome")
        #expect(route?.rule?.sourceAppBundleIDs == ["com.tinyspeck.slackmacgap"])
        #expect(manager.currentSourceAppBundleId == nil)
    }

    @Test("Incoming URL route falls back to picker when source app does not match")
    @MainActor
    func incomingURLRouteFallsBackWhenSourceAppDoesNotMatch() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]
        manager.addRoutingRule(
            name: "Slack GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        manager.currentSourceAppBundleId = "com.apple.mail"
        let route = AppDelegate.resolveIncomingURLRoute(
            for: URL(string: "https://github.com/org/repo")!,
            using: manager,
            forceShowPicker: false
        )

        #expect(route == nil)
        #expect(manager.currentSourceAppBundleId == nil)
    }

    @Test("Incoming URL route uses the explicitly passed source app, not a since-overwritten ambient value (TOCTOU regression, found in Hound review)")
    @MainActor
    func incomingURLRouteUsesExplicitSourceAppNotAmbient() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]
        manager.addRoutingRule(
            name: "Slack GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        // Simulate the race: a second link's source app has already overwritten the ambient
        // property by the time this call runs (e.g. after an `await unshortenURL` gap), but the
        // caller (AppDelegate.application(_:open:)) captured the correct value up front and must
        // pass it explicitly — the production entry point does this, this test proves it matters.
        manager.currentSourceAppBundleId = "com.apple.mail"
        let route = AppDelegate.resolveIncomingURLRoute(
            for: URL(string: "https://github.com/org/repo")!,
            using: manager,
            forceShowPicker: false,
            sourceApp: "com.tinyspeck.slackmacgap"
        )

        #expect(route?.browser.bundleId == "com.google.Chrome")
        #expect(route?.rule?.sourceAppBundleIDs == ["com.tinyspeck.slackmacgap"])
    }

    @Test("Temporary focus route takes precedence over matching source app rule")
    @MainActor
    func temporaryFocusRoutePrecedesSourceAppRule() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "2"),
        ]
        manager.addRoutingRule(
            name: "Slack GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"]
        )
        manager.setTemporaryRoute(browserBundleId: "org.mozilla.firefox", profile: nil, duration: 60)
        manager.currentSourceAppBundleId = "com.tinyspeck.slackmacgap"

        let route = AppDelegate.resolveIncomingURLRoute(
            for: URL(string: "https://github.com/org/repo")!,
            using: manager,
            forceShowPicker: false
        )

        #expect(route?.rule == nil)
        #expect(route?.browser.bundleId == "org.mozilla.firefox")
        #expect(manager.currentSourceAppBundleId == nil)
    }

    @Test("Forced picker bypasses matching rules and clears source app context")
    @MainActor
    func forcedPickerBypassesMatchingRules() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]
        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome"
        )
        manager.currentSourceAppBundleId = "com.tinyspeck.slackmacgap"

        let route = AppDelegate.resolveIncomingURLRoute(
            for: URL(string: "https://github.com/org/repo")!,
            using: manager,
            forceShowPicker: true
        )

        #expect(route == nil)
        #expect(manager.currentSourceAppBundleId == nil)
    }

    @Test("Private clipboard action arms private mode for the next URL open")
    @MainActor
    func privateClipboardActionArmsPrivateModeForNextURLOpen() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        let url = URL(string: "https://example.com")!
        var openedURL: URL?

        AppDelegate.prepareClipboardURLOpen(url, using: manager, usePrivateMode: true) { url in
            openedURL = url
        }

        #expect(openedURL == url)
        #expect(manager.consumeClipboardPrivateModeRequest(for: url) == BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)
        #expect(manager.consumeClipboardPrivateModeRequest(for: url) == false)
    }

    @Test("Normal clipboard action clears private mode for the next URL open")
    @MainActor
    func normalClipboardActionClearsPrivateModeForNextURLOpen() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        let url = URL(string: "https://example.com")!
        manager.currentURLPrivateModeRequested = true

        AppDelegate.prepareClipboardURLOpen(url, using: manager, usePrivateMode: false) { _ in }

        #expect(manager.currentURLPrivateModeRequested == false)
        #expect(manager.consumeClipboardPrivateModeRequest(for: url) == false)
    }

    @Test("Private clipboard request only applies to the exact URL and is one-shot")
    @MainActor
    func privateClipboardRequestIsURLScopedAndOneShot() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        let privateURL = URL(string: "https://example.com/private")!
        let otherURL = URL(string: "https://example.com/other")!

        AppDelegate.prepareClipboardURLOpen(privateURL, using: manager, usePrivateMode: true) { _ in }

        #expect(manager.consumeClipboardPrivateModeRequest(for: otherURL) == false)
        #expect(manager.consumeClipboardPrivateModeRequest(for: privateURL) == BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)
        #expect(manager.consumeClipboardPrivateModeRequest(for: privateURL) == false)
    }

    @Test("Forced private clipboard request overrides non-private routing rule")
    @MainActor
    func forcedPrivateClipboardRequestOverridesNonPrivateRoutingRule() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        let rule = BrowserRoutingRule(
            name: "Example",
            hostPattern: "example.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            usePrivateMode: false
        )

        manager.currentURLPrivateModeRequested = true

        #expect(AppDelegate.requestedPrivateModeForIncomingURL(rule: rule, forcedPrivateMode: true) == BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)
    }

    @Test("Picker fallback private request state is explicit per consumed URL")
    @MainActor
    func pickerFallbackPrivateRequestStateIsExplicitPerConsumedURL() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        let url = URL(string: "https://example.com/picker")!

        AppDelegate.prepareClipboardURLOpen(url, using: manager, usePrivateMode: true) { _ in }
        let consumedPrivateMode = manager.consumeClipboardPrivateModeRequest(for: url)
        manager.currentURLPrivateModeRequested = BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild && consumedPrivateMode

        #expect(manager.currentURLPrivateModeRequested == BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)

        manager.currentURLPrivateModeRequested = false
        #expect(manager.currentURLPrivateModeRequested == false)
    }

    @Test("Routing rules persist across manager instances")
    @MainActor
    func routingRulesPersist() {
        let defaults = makeTestDefaults()
        let manager1 = BrowserManager(defaults: defaults)
        manager1.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "2"),
        ]

        manager1.addRoutingRule(
            name: "Mozilla",
            hostPattern: "mozilla.org",
            pathPrefix: "/en-US",
            browserBundleId: "org.mozilla.firefox"
        )

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.routingRules.count == 1)
        #expect(manager2.routingRules[0].name == "Mozilla")
        #expect(manager2.routingRules[0].hostPattern == "mozilla.org")
        #expect(manager2.routingRules[0].pathPrefix == "/en-US")
        #expect(manager2.routingRules[0].browserBundleId == "org.mozilla.firefox")
    }

    @Test("Removing a browser preserves rules targeting that browser")
    @MainActor
    func removingBrowserPreservesRules() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        manager.configuredBrowsers = [safari, chrome]

        manager.addRoutingRule(
            name: "Chrome Route",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome"
        )
        #expect(manager.routingRules.count == 1)

        manager.removeBrowser(id: chrome.id)

        #expect(manager.configuredBrowsers.count == 1)
        // Rules are preserved so the user can reassign them
        #expect(manager.routingRules.count == 1)
        // But resolvedRoute skips them since the target browser is gone
        let url = URL(string: "https://github.com")!
        #expect(manager.resolvedRoute(for: url) == nil)
    }

    @Test("resolvedRoute returns both matching rule and browser")
    @MainActor
    func resolvedRouteIncludesRuleAndBrowser() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "Test Rule",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.apple.Safari"
        )

        let url = URL(string: "https://github.com/anyaiapp")!
        let route = manager.resolvedRoute(for: url)
        #expect(route != nil)
        #expect(route?.rule?.name == "Test Rule")
        #expect(route?.browser.name == "Safari")
    }

    @Test("resolvedRoute takes an explicit source app so callers outside a live URL open (e.g. the Settings rule tester) can match source-app conditions")
    @MainActor
    func resolvedRouteAcceptsExplicitSourceApp() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]
        manager.addRoutingRule(
            name: "From Slack",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.apple.Safari",
            sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        let url = URL(string: "https://github.com/org/repo")!

        // The ambient property is nil here (as it is in the tester, since it's only set
        // during a live URL open and immediately defer-cleared) — without an explicit
        // parameter this rule could never match outside a real open.
        #expect(manager.currentSourceAppBundleId == nil)
        #expect(manager.resolvedRoute(for: url) == nil)

        // Passing the simulated source app explicitly must let the rule match.
        let matched = manager.resolvedRoute(for: url, sourceApp: "com.tinyspeck.slackmacgap")
        #expect(matched?.rule?.name == "From Slack")

        // A mismatched explicit source app must still fail to match.
        #expect(manager.resolvedRoute(for: url, sourceApp: "com.apple.mail") == nil)
    }

    @Test("Routing host normalization accepts pasted full URLs")
    @MainActor
    func routingRuleHostNormalizationFromURL() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "https://github.com/orgs/anyaiapp",
            pathPrefix: nil,
            browserBundleId: "company.thebrowser.Browser"
        )

        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].hostPattern == "github.com")
        #expect(manager.resolvedBrowser(for: URL(string: "https://github.com/anyaiapp")!)?.bundleId == "company.thebrowser.Browser")
    }

    @Test("Duplicating a routing rule inserts a copy below the source")
    @MainActor
    func duplicateRoutingRule() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: "/orgs",
            browserBundleId: "company.thebrowser.Browser"
        )

        guard let originalID = manager.routingRules.first?.id else {
            Issue.record("Expected a source rule to duplicate")
            return
        }

        manager.duplicateRoutingRule(id: originalID)

        #expect(manager.routingRules.count == 2)
        #expect(manager.routingRules[0].name == "GitHub")
        #expect(manager.routingRules[1].name == "GitHub Copy")
        #expect(manager.routingRules[1].hostPattern == "github.com")
        #expect(manager.routingRules[1].pathPrefix == "/orgs")
    }
    
    // MARK: - Installed Browsers Discovery
    
    @Test("getInstalledBrowsers returns at least Safari")
    func installedBrowsersIncludeSafari() {
        let browsers = BrowserManager.getInstalledBrowsers()
        
        // On any Mac, Safari should be installed
        let safari = browsers.first { $0.bundleId == "com.apple.Safari" }
        #expect(safari != nil)
        #expect(safari?.name == "Safari")
    }
    
    @Test("getInstalledBrowsers filters out Safari WebApps")
    func installedBrowsersExcludeWebApps() {
        let browsers = BrowserManager.getInstalledBrowsers()
        
        let webApps = browsers.filter { $0.bundleId.contains("apple.Safari.WebApp") }
        #expect(webApps.isEmpty)
    }
    
    @Test("getInstalledBrowsers filters out Chowser itself")
    func installedBrowsersExcludesSelf() {
        let browsers = BrowserManager.getInstalledBrowsers()
        let myBundleId = Bundle.main.bundleIdentifier ?? "in.sreerams.Chowser"
        
        let selfEntries = browsers.filter { $0.bundleId == myBundleId }
        #expect(selfEntries.isEmpty)
    }
    
    @Test("getInstalledBrowsers results are sorted alphabetically")
    func installedBrowsersSorted() {
        let browsers = BrowserManager.getInstalledBrowsers()
        
        let names = browsers.map(\.name)
        #expect(names == names.sorted())
    }
    
    // MARK: - Multiple Save Cycles
    
    @Test("Multiple rapid mutations all persist correctly")
    @MainActor
    func rapidMutations() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        // Rapid mutations
        manager.configuredBrowsers.append(
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        )
        manager.configuredBrowsers.append(
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3")
        )
        manager.configuredBrowsers.remove(at: 0) // Remove Safari
        manager.configuredBrowsers[0].name = "Google Chrome"
        
        // Verify final state
        #expect(manager.configuredBrowsers.count == 2)
        #expect(manager.configuredBrowsers[0].name == "Google Chrome")
        #expect(manager.configuredBrowsers[1].name == "Firefox")
        
        // Verify persistence
        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.configuredBrowsers.count == 2)
        #expect(manager2.configuredBrowsers[0].name == "Google Chrome")
    }
    
    // MARK: - Import / Export Rules
    
    @Test("Rules are exported and imported correctly")
    @MainActor
    func importExportRules() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "company.thebrowser.Browser"
        )
        
        // Export to temp URL
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("rules_export.json")
        try manager.exportRules(to: tempURL)
        
        // Setup new manager and clear its rules, then import
        let newManager = BrowserManager(defaults: makeTestDefaults())
        newManager.configuredBrowsers = manager.configuredBrowsers
        newManager.routingRules.removeAll()
        #expect(newManager.routingRules.isEmpty)
        
        try newManager.importRules(from: tempURL)
        
        #expect(newManager.routingRules.count == 1)
        #expect(newManager.routingRules[0].name == "GitHub")
        #expect(newManager.routingRules[0].hostPattern == "github.com")
        #expect(newManager.routingRules[0].browserBundleId == "company.thebrowser.Browser")
        
        try FileManager.default.removeItem(at: tempURL)
    }

    @Test("Legacy singular sourceAppBundleId decodes into a one-item sourceAppBundleIDs array (FR-013)")
    @MainActor
    func legacySingleSourceDecodesToArray() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
        ]

        let legacyJSON = """
        [{"id":"\(UUID().uuidString)","name":"Legacy","hostPattern":"github.com","browserBundleId":"com.google.Chrome","sourceAppBundleId":"com.tinyspeck.slackmacgap"}]
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("legacy_rules_\(UUID().uuidString).json")
        try legacyJSON.data(using: .utf8)!.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try manager.importRules(from: tempURL)

        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].sourceAppBundleIDs == ["com.tinyspeck.slackmacgap"])
    }

    @Test("Export emits the plural sourceAppBundleIDs field, not the legacy singular one")
    @MainActor
    func exportEmitsPluralSourceAppField() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
        ]
        manager.addRoutingRule(
            name: "Slack GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("export_shape_\(UUID().uuidString).json")
        try manager.exportRules(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let data = try Data(contentsOf: tempURL)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        #expect(decoded?.first?["sourceAppBundleIDs"] as? [String] == ["com.tinyspeck.slackmacgap"])
        #expect(decoded?.first?["sourceAppBundleId"] == nil)
    }

    @Test("Import skips a genuinely malformed element (missing required field) without failing the whole array (FR-014)")
    @MainActor
    func importSkipsMalformedElementWithoutFailingWholeArray() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        // Middle element is missing the required "hostPattern" key — a whole-array
        // `[BrowserRoutingRule].self` decode would throw and import nothing at all.
        let json = """
        [
            {"id":"\(UUID().uuidString)","name":"Good One","hostPattern":"a.example.com","browserBundleId":"com.apple.Safari"},
            {"id":"\(UUID().uuidString)","name":"Missing Host","browserBundleId":"com.apple.Safari"},
            {"id":"\(UUID().uuidString)","name":"Good Two","hostPattern":"b.example.com","browserBundleId":"com.apple.Safari"}
        ]
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("malformed_rules_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let summary = try manager.importRules(from: tempURL)

        #expect(summary.added == 2)
        #expect(summary.invalid == 1)
        #expect(manager.routingRules.count == 2)
        #expect(manager.routingRules.contains { $0.hostPattern == "a.example.com" })
        #expect(manager.routingRules.contains { $0.hostPattern == "b.example.com" })
    }

    @Test("Import skips non-object array elements (null/string/number) without failing the whole array")
    @MainActor
    func importSkipsNonObjectElementsWithoutFailingWholeArray() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        // A whole-array `as? [[String: Any]]` cast returns nil the moment any element
        // isn't an object — null, a bare string, or a bare number here — which used to
        // fall through to a whole-array decode that throws and aborts the entire import.
        let json = """
        [
            {"id":"\(UUID().uuidString)","name":"Good One","hostPattern":"a.example.com","browserBundleId":"com.apple.Safari"},
            null,
            "not an object",
            42,
            {"id":"\(UUID().uuidString)","name":"Good Two","hostPattern":"b.example.com","browserBundleId":"com.apple.Safari"}
        ]
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("non_object_elements_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let summary = try manager.importRules(from: tempURL)

        #expect(summary.added == 2)
        #expect(summary.invalid == 3)
        #expect(manager.routingRules.count == 2)
        #expect(manager.routingRules.contains { $0.hostPattern == "a.example.com" })
        #expect(manager.routingRules.contains { $0.hostPattern == "b.example.com" })
    }

    @Test("Importing non-array JSON still throws instead of silently succeeding")
    @MainActor
    func importThrowsOnNonArrayTopLevelJSON() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("not_an_array_\(UUID().uuidString).json")
        try #"{"not": "an array"}"#.data(using: .utf8)!.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            try manager.importRules(from: tempURL)
            Issue.record("Importing non-array JSON unexpectedly succeeded")
        } catch {
            // Expected: decode error propagated instead of silently treated as empty.
        }
    }

    // MARK: - Migration-Time Merge Assist

    @Test("Merge assist proposes merging consecutive same-destination single-source rules")
    @MainActor
    func mergeSuggestionProposesForSameDestination() {
        let ruleA = BrowserRoutingRule(name: "Slack", hostPattern: "github.com", browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"])
        let ruleB = BrowserRoutingRule(name: "Mail", hostPattern: "github.com", browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.apple.mail"])

        let suggestions = BrowserManager.computeMergeSuggestions(for: [ruleA, ruleB])

        #expect(suggestions.count == 1)
        #expect(Set(suggestions[0].mergedSourceAppBundleIDs) == ["com.tinyspeck.slackmacgap", "com.apple.mail"])
        #expect(suggestions[0].ruleIDs == [ruleA.id, ruleB.id])
    }

    @Test("Merge assist does not propose merging rules with different destinations")
    @MainActor
    func mergeSuggestionSkipsDifferentDestinations() {
        let ruleA = BrowserRoutingRule(name: "Slack", hostPattern: "github.com", browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"])
        let ruleB = BrowserRoutingRule(name: "Mail", hostPattern: "github.com", browserBundleId: "com.apple.Safari", sourceAppBundleIDs: ["com.apple.mail"])

        let suggestions = BrowserManager.computeMergeSuggestions(for: [ruleA, ruleB])

        #expect(suggestions.isEmpty)
    }

    @Test("Merge assist does not propose merging across an interleaved, differently-matching rule (order safety)")
    @MainActor
    func mergeSuggestionSkipsInterleavedDifferentRule() {
        let ruleA = BrowserRoutingRule(name: "Slack", hostPattern: "example.com", browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"])
        // Interleaved: same host, but no source restriction — a genuinely different match condition.
        let interleaved = BrowserRoutingRule(name: "Catch All", hostPattern: "example.com", browserBundleId: "org.mozilla.firefox")
        let ruleB = BrowserRoutingRule(name: "Mail", hostPattern: "example.com", browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.apple.mail"])

        let suggestions = BrowserManager.computeMergeSuggestions(for: [ruleA, interleaved, ruleB])

        #expect(suggestions.isEmpty)
    }

    @Test("Accepting a merge suggestion combines the rules and preserves routing behavior")
    @MainActor
    func acceptingMergeSuggestionCombinesRulesAndPreservesRouting() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
        ]
        manager.addRoutingRule(name: "Slack", hostPattern: "github.com", pathPrefix: nil, browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"])
        manager.addRoutingRule(name: "Mail", hostPattern: "github.com", pathPrefix: nil, browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.apple.mail"])

        let suggestions = BrowserManager.computeMergeSuggestions(for: manager.routingRules)
        #expect(suggestions.count == 1)

        #expect(manager.acceptRuleMergeSuggestion(suggestions[0]))
        #expect(manager.routingRules.count == 1)
        #expect(Set(manager.routingRules[0].sourceAppBundleIDs) == ["com.tinyspeck.slackmacgap", "com.apple.mail"])

        let url = URL(string: "https://github.com/org/repo")!
        manager.currentSourceAppBundleId = "com.tinyspeck.slackmacgap"
        #expect(manager.resolvedRoute(for: url)?.browser.bundleId == "com.google.Chrome")
        manager.currentSourceAppBundleId = "com.apple.mail"
        #expect(manager.resolvedRoute(for: url)?.browser.bundleId == "com.google.Chrome")
    }

    @Test("Rejecting a merge suggestion leaves rules unchanged")
    @MainActor
    func rejectingMergeSuggestionLeavesRulesUnchanged() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
        ]
        manager.addRoutingRule(name: "Slack", hostPattern: "github.com", pathPrefix: nil, browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"])
        manager.addRoutingRule(name: "Mail", hostPattern: "github.com", pathPrefix: nil, browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.apple.mail"])

        let suggestions = BrowserManager.computeMergeSuggestions(for: manager.routingRules)
        manager.pendingRuleMergeSuggestions = suggestions
        manager.rejectRuleMergeSuggestion(suggestions[0])

        #expect(manager.routingRules.count == 2)
        #expect(manager.pendingRuleMergeSuggestions.isEmpty)
    }

    @Test("Merge review suggestions are only computed once per install (hasSeenRuleMergeReview gate)")
    @MainActor
    func mergeReviewSuggestionsComputedOnce() {
        // Suggestions are computed once at launch from *persisted* rules (migration-time,
        // not a live recomputation on every edit) — seed persisted rules with one manager,
        // then load them fresh with another to simulate the next launch.
        let defaults = makeTestDefaults()
        let seedManager = BrowserManager(defaults: defaults)
        seedManager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
        ]
        seedManager.addRoutingRule(name: "Slack", hostPattern: "github.com", pathPrefix: nil, browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"])
        seedManager.addRoutingRule(name: "Mail", hostPattern: "github.com", pathPrefix: nil, browserBundleId: "com.google.Chrome", sourceAppBundleIDs: ["com.apple.mail"])

        let manager = BrowserManager(defaults: defaults)
        #expect(!manager.pendingRuleMergeSuggestions.isEmpty)
        manager.finishRuleMergeReview()
        #expect(manager.pendingRuleMergeSuggestions.isEmpty)
        #expect(manager.hasSeenRuleMergeReview)

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.pendingRuleMergeSuggestions.isEmpty)
    }

    // MARK: - Profile Support

    @Test("addBrowser with profile stores profile correctly")
    @MainActor
    func addBrowserWithProfile() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = []

        manager.addBrowser(name: "Brave - Work", bundleId: "com.brave.Browser", profile: "Profile 1")

        #expect(manager.configuredBrowsers.count == 1)
        #expect(manager.configuredBrowsers[0].profile == "Profile 1")
        #expect(manager.configuredBrowsers[0].name == "Brave - Work")
    }

    @Test("addBrowser prevents duplicate bundleId+profile combination")
    @MainActor
    func addBrowserDuplicateProfilePrevented() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = []

        manager.addBrowser(name: "Brave - Work", bundleId: "com.brave.Browser", profile: "Profile 1")
        manager.addBrowser(name: "Brave - Work", bundleId: "com.brave.Browser", profile: "Profile 1")

        #expect(manager.configuredBrowsers.count == 1)
    }

    @Test("addBrowser allows same bundleId with different profiles")
    @MainActor
    func addBrowserDifferentProfiles() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = []

        manager.addBrowser(name: "Brave - Work", bundleId: "com.brave.Browser", profile: "Profile 1")
        manager.addBrowser(name: "Brave - Personal", bundleId: "com.brave.Browser", profile: "Profile 2")

        #expect(manager.configuredBrowsers.count == 2)
        #expect(manager.configuredBrowsers[0].profile == "Profile 1")
        #expect(manager.configuredBrowsers[1].profile == "Profile 2")
    }

    @Test("BrowserConfig identity combines bundleId and profile")
    func browserConfigIdentity() {
        let withProfile = BrowserConfig(name: "Brave", bundleId: "com.brave.Browser", shortcutKey: "1", profile: "Profile 1")
        let withoutProfile = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "2")

        #expect(withProfile.identity == "com.brave.Browser|Profile 1")
        #expect(withoutProfile.identity == "com.apple.Safari|")
    }

    @Test("Profile persists across manager instances")
    @MainActor
    func profilePersistsAcrossInstances() {
        let defaults = makeTestDefaults()
        let manager1 = BrowserManager(defaults: defaults)
        manager1.configuredBrowsers = [
            BrowserConfig(name: "Brave - Work", bundleId: "com.brave.Browser", shortcutKey: "1", profile: "Profile 1"),
        ]

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.configuredBrowsers[0].profile == "Profile 1")
        #expect(manager2.configuredBrowsers[0].identity == "com.brave.Browser|Profile 1")
    }

    @Test("Routing rule with profile matches correct browser")
    @MainActor
    func routingRuleWithProfileMatchesCorrectBrowser() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Brave - Work", bundleId: "com.brave.Browser", shortcutKey: "1", profile: "Profile 1"),
            BrowserConfig(name: "Brave - Personal", bundleId: "com.brave.Browser", shortcutKey: "2", profile: "Profile 2"),
            BrowserConfig(name: "Google Chrome", bundleId: "com.google.Chrome", shortcutKey: "3", profile: "Work"),
        ]

        manager.addRoutingRule(
            name: "Google Services",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            profile: "Work"
        )

        let url = URL(string: "https://github.com/test")!
        let route = manager.resolvedRoute(for: url)
        #expect(route != nil)
        #expect(route?.rule?.name == "Google Services")
        #expect(route?.browser.name == "Google Chrome")
        #expect(route?.browser.profile == "Work")
    }

    @Test("Removing browser with profile preserves all rules")
    @MainActor
    func removingBrowserWithProfilePreservesRules() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        let work = BrowserConfig(name: "Brave - Work", bundleId: "com.brave.Browser", shortcutKey: "1", profile: "Profile 1")
        let personal = BrowserConfig(name: "Brave - Personal", bundleId: "com.brave.Browser", shortcutKey: "2", profile: "Profile 2")
        manager.configuredBrowsers = [work, personal]

        manager.addRoutingRule(
            name: "Work GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.brave.Browser",
            profile: "Profile 1"
        )
        manager.addRoutingRule(
            name: "Personal Reddit",
            hostPattern: "reddit.com",
            pathPrefix: nil,
            browserBundleId: "com.brave.Browser",
            profile: "Profile 2"
        )

        #expect(manager.routingRules.count == 2)

        manager.removeBrowser(id: work.id)

        #expect(manager.configuredBrowsers.count == 1)
        // Both rules are preserved — orphaned rules can be reassigned by the user
        #expect(manager.routingRules.count == 2)
        // Only the Personal Reddit rule resolves since its browser is still configured
        let redditURL = URL(string: "https://reddit.com")!
        let githubURL = URL(string: "https://github.com")!
        #expect(manager.resolvedRoute(for: redditURL)?.rule?.name == "Personal Reddit")
        #expect(manager.resolvedRoute(for: githubURL) == nil)
    }

    @Test("Import/export preserves profile in routing rules")
    @MainActor
    func importExportRulesWithProfile() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Brave - Work", bundleId: "com.brave.Browser", shortcutKey: "1", profile: "Profile 1"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.brave.Browser",
            profile: "Profile 1"
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("rules_profile_export.json")
        try manager.exportRules(to: tempURL)

        let newManager = BrowserManager(defaults: makeTestDefaults())
        newManager.configuredBrowsers = manager.configuredBrowsers
        newManager.routingRules.removeAll()

        try newManager.importRules(from: tempURL)

        #expect(newManager.routingRules.count == 1)
        #expect(newManager.routingRules[0].profile == "Profile 1")

        try FileManager.default.removeItem(at: tempURL)
    }

    @Test("Import skips rules with duplicate IDs")
    @MainActor
    func importSkipsDuplicateIDs() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.apple.Safari"
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("rules_dup_test.json")
        try manager.exportRules(to: tempURL)

        // Try importing the same rules — should not duplicate
        try manager.importRules(from: tempURL)

        #expect(manager.routingRules.count == 1)

        try FileManager.default.removeItem(at: tempURL)
    }

    @Test("Import updates existing rules with matching IDs")
    @MainActor
    func importUpdatesExistingRules() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.apple.Safari"
        )

        let ruleId = manager.routingRules[0].id
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("rules_update_test.json")
        try manager.exportRules(to: tempURL)

        // Modify the exported file to update the rule
        var exported = try JSONDecoder().decode([BrowserRoutingRule].self, from: Data(contentsOf: tempURL))
        exported[0].name = "GitHub Updated"
        exported[0].browserBundleId = "com.google.Chrome"
        try JSONEncoder().encode(exported).write(to: tempURL)

        // Import should update the existing rule, not add a new one
        try manager.importRules(from: tempURL)

        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].id == ruleId)
        #expect(manager.routingRules[0].name == "GitHub Updated")
        #expect(manager.routingRules[0].browserBundleId == "com.google.Chrome")

        try FileManager.default.removeItem(at: tempURL)
    }

    @Test("Import rules returns summary for merge behavior")
    @MainActor
    func importRulesSummaryReturnsMergeCounts() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.apple.Safari"
        )

        let existingId = manager.routingRules[0].id
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("rules_summary_test.json")

        let updated = [
            BrowserRoutingRule(
                id: existingId,
                name: "GitHub Updated",
                hostPattern: "github.com",
                pathPrefix: nil,
                browserBundleId: "com.apple.Safari"
            ),
            BrowserRoutingRule(
                name: "Google",
                hostPattern: "google.com",
                pathPrefix: nil,
                browserBundleId: "com.apple.Safari"
            )
        ]
        try JSONEncoder().encode(updated).write(to: tempURL)

        let summary = try manager.importRules(from: tempURL, skipExisting: false)

        #expect(summary.updated == 1)
        #expect(summary.added == 1)
        #expect(summary.skipped == 0)
        #expect(summary.changedCount == 2)
        #expect(summary.totalProcessed == 2)

        let summarySkip = try manager.importRules(from: tempURL, skipExisting: true)
        #expect(summarySkip.updated == 0)
        #expect(summarySkip.added == 0)
        #expect(summarySkip.skipped == 2)
    }

    @Test("Import rules summary reports invalid entries") @MainActor
    func importRulesSummaryCountsInvalidRules() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("rules_invalid_summary_test.json")

        let payload = [
            BrowserRoutingRule(
                name: "Invalid Host",
                hostPattern: "bad host",
                pathPrefix: nil,
                browserBundleId: "com.apple.Safari"
            ),
            BrowserRoutingRule(
                name: "Missing Browser",
                hostPattern: "example.com",
                pathPrefix: nil,
                browserBundleId: "com.example.missing"
            ),
        ]
        try JSONEncoder().encode(payload).write(to: tempURL)

        let summary = try manager.importRules(from: tempURL)

        #expect(summary.invalid == 2)
        #expect(summary.added == 0)
        #expect(summary.updated == 0)
        #expect(summary.skipped == 0)

        try FileManager.default.removeItem(at: tempURL)
    }

    @Test("Import updates existing browsers with matching identity")
    @MainActor
    func importUpdatesExistingBrowsers() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        let existingId = manager.configuredBrowsers[0].id
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("browsers_update_test.json")

        // Create an import file with the same identity but different name
        let updatedBrowsers = [
            BrowserConfig(name: "Safari (Updated)", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]
        try JSONEncoder().encode(updatedBrowsers).write(to: tempURL)

        try manager.importBrowsers(from: tempURL)

        #expect(manager.configuredBrowsers.count == 1)
        #expect(manager.configuredBrowsers[0].name == "Safari (Updated)")
        #expect(manager.configuredBrowsers[0].bundleId == "com.apple.Safari")
        #expect(manager.configuredBrowsers[0].id == existingId)

        try FileManager.default.removeItem(at: tempURL)
    }

    @Test("Import browsers returns summary for merge behavior")
    @MainActor
    func importBrowsersSummaryReturnsMergeCounts() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        let existingId = manager.configuredBrowsers[0].id
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("browsers_summary_test.json")
        let imported = [
            BrowserConfig(id: existingId, name: "Safari (Updated)", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "2"),
        ]
        try JSONEncoder().encode(imported).write(to: tempURL)

        let summary = try manager.importBrowsers(from: tempURL, skipExisting: false)
        #expect(summary.updated == 1)
        #expect(summary.added == 1)
        #expect(summary.skipped == 0)
        #expect(summary.totalProcessed == 2)
        #expect(manager.configuredBrowsers.count == 2)

        let summarySkip = try manager.importBrowsers(from: tempURL, skipExisting: true)
        #expect(summarySkip.updated == 0)
        #expect(summarySkip.added == 0)
        #expect(summarySkip.skipped == 2)

        try FileManager.default.removeItem(at: tempURL)
    }

    @Test("Import adds new rules alongside existing ones")
    @MainActor
    func importAddsNewRulesAlongsideExisting() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.apple.Safari"
        )

        // Create a new rule with a different ID
        let newRules = [
            BrowserRoutingRule(name: "Google", hostPattern: "google.com", browserBundleId: "com.apple.Safari"),
        ]
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("rules_add_test.json")
        try JSONEncoder().encode(newRules).write(to: tempURL)

        try manager.importRules(from: tempURL)

        #expect(manager.routingRules.count == 2)
        #expect(manager.routingRules[0].name == "GitHub")
        #expect(manager.routingRules[1].name == "Google")

        try FileManager.default.removeItem(at: tempURL)
    }

    @Test("Rule edits use validation and preserve existing rule on invalid update")
    @MainActor
    func invalidRuleEditPreservesExistingRule() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
        ]

        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: "orgs",
            browserBundleId: "com.apple.Safari"
        )

        let original = manager.routingRules[0]
        #expect(original.pathPrefix == "/orgs")

        var invalidHostUpdate = original
        invalidHostUpdate.hostPattern = "bad host pattern"
        let invalidHostResult = manager.updateRule(invalidHostUpdate)
        if case .failure(let error) = invalidHostResult {
            #expect(error == .invalidHostPattern)
        } else {
            Issue.record("Invalid host update unexpectedly succeeded")
        }
        #expect(manager.routingRules[0].hostPattern == "github.com")

        var invalidRegexUpdate = original
        invalidRegexUpdate.useRegex = true
        invalidRegexUpdate.hostPattern = "[invalid"
        let invalidRegexResult = manager.updateRule(invalidRegexUpdate)
        if case .failure(let error) = invalidRegexResult {
            #expect(error == .invalidRegexPattern)
        } else {
            Issue.record("Invalid regex update unexpectedly succeeded")
        }
        #expect(manager.routingRules[0].useRegex == false)
        #expect(manager.routingRules[0].hostPattern == "github.com")

        var missingBrowserUpdate = original
        missingBrowserUpdate.browserBundleId = "com.missing.Browser"
        let missingBrowserResult = manager.updateRule(missingBrowserUpdate)
        if case .failure(let error) = missingBrowserResult {
            #expect(error == .browserNotFound(bundleId: "com.missing.Browser", profile: nil))
        } else {
            Issue.record("Missing-browser update unexpectedly succeeded")
        }
        #expect(manager.routingRules[0].browserBundleId == "com.apple.Safari")

        var invalidPathUpdate = original
        invalidPathUpdate.pathPrefix = "https://github.com/orgs"
        let invalidPathResult = manager.updateRule(invalidPathUpdate)
        if case .failure(let error) = invalidPathResult {
            #expect(error == .invalidPathPrefix)
        } else {
            Issue.record("Invalid path update unexpectedly succeeded")
        }
        #expect(manager.routingRules[0].pathPrefix == "/orgs")
    }

    @Test("Rule validation normalizes paths and validates source app matching")
    @MainActor
    func ruleValidationNormalizesPathAndSourceApp() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
        ]

        let invalidSourceResult = manager.addRoutingRule(
            name: "Bad Source",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["not a bundle"]
        )
        if case .failure(let error) = invalidSourceResult {
            #expect(error == .invalidSourceAppBundleId)
        } else {
            Issue.record("Invalid source app bundle ID unexpectedly succeeded")
        }
        #expect(manager.routingRules.isEmpty)

        manager.addRoutingRule(
            name: "Slack GitHub",
            hostPattern: "github.com",
            pathPrefix: "orgs",
            browserBundleId: "com.google.Chrome",
            sourceAppBundleIDs: ["com.tinyspeck.slackmacgap"]
        )

        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].pathPrefix == "/orgs")
        #expect(manager.routingRules[0].sourceAppBundleIDs == ["com.tinyspeck.slackmacgap"])

        let matchingURL = URL(string: "https://github.com/orgs/chowser")!
        manager.currentSourceAppBundleId = nil
        #expect(manager.resolvedRoute(for: matchingURL) == nil)
        manager.currentSourceAppBundleId = "com.apple.mail"
        #expect(manager.resolvedRoute(for: matchingURL) == nil)
        manager.currentSourceAppBundleId = "com.tinyspeck.slackmacgap"
        #expect(manager.resolvedRoute(for: matchingURL)?.browser.bundleId == "com.google.Chrome")
    }

    @Test("Rule import skips invalid rules and keeps valid existing rules loadable")
    @MainActor
    func importSkipsInvalidRulesAndPreservesExistingRules() throws {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        manager.addRoutingRule(
            name: "Existing GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.apple.Safari"
        )

        let existingRule = manager.routingRules[0]
        let validImportedRule = BrowserRoutingRule(
            name: "Docs",
            hostPattern: "docs.example.com",
            pathPrefix: "guide",
            browserBundleId: "com.apple.Safari"
        )
        var invalidExistingUpdate = existingRule
        invalidExistingUpdate.hostPattern = "bad host"
        let missingBrowserRule = BrowserRoutingRule(
            name: "Missing Browser",
            hostPattern: "missing.example.com",
            browserBundleId: "com.missing.Browser"
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("rules_validation_import_\(UUID().uuidString).json")
        try JSONEncoder().encode([invalidExistingUpdate, validImportedRule, missingBrowserRule]).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try manager.importRules(from: tempURL)

        #expect(manager.routingRules.count == 2)
        #expect(manager.routingRules[0].id == existingRule.id)
        #expect(manager.routingRules[0].hostPattern == "github.com")
        #expect(manager.routingRules[1].hostPattern == "docs.example.com")
        #expect(manager.routingRules[1].pathPrefix == "/guide")
        #expect(manager.resolvedRoute(for: URL(string: "https://github.com")!)?.browser.bundleId == "com.apple.Safari")
        #expect(manager.resolvedRoute(for: URL(string: "https://docs.example.com/guide/setup")!)?.browser.bundleId == "com.apple.Safari")
    }

    @Test("Installed browsers list includes profile info when profiles exist")
    func installedBrowsersIncludeProfiles() {
        let browsers = BrowserManager.getInstalledBrowsers()
        let braveEntries = browsers.filter { $0.bundleId == "com.brave.Browser" }

        // If Brave is installed with profiles, there should be multiple entries
        if braveEntries.count > 1 {
            #expect(braveEntries.allSatisfy { $0.profile != nil })
            let profileIDs = braveEntries.compactMap(\.profile)
            #expect(Set(profileIDs).count == braveEntries.count) // All unique
        }
    }

    @Test("Browser blocklist persists and filters correctly")
    @MainActor
    func blocklistPersistence() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        let testID = "com.test.nonbrowser"
        manager.addHiddenBundleID(testID)
        #expect(manager.hiddenBundleIDs.contains(testID))
        
        let newManager = BrowserManager(defaults: defaults)
        #expect(newManager.hiddenBundleIDs.contains(testID))
        
        newManager.removeHiddenBundleID(testID)
        #expect(!newManager.hiddenBundleIDs.contains(testID))
    }

    @Test("getInstalledBrowsers respects blocklist parameter")
    @MainActor
    func blocklistFiltering() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)
        
        // com.mxplayer.mac is in default blocklist
        let browsers = BrowserManager.getInstalledBrowsers(includeHidden: false)
        #expect(!browsers.contains(where: { $0.bundleId == "com.mxplayer.mac" }))
        
        let allBrowsers = BrowserManager.getInstalledBrowsers(includeHidden: true)
        // Note: This test assumes MX Player is actually installed on the test machine 
        // to be truly useful, but we can verify the behavior if it exists.
    }

    // MARK: - Recent URLs

    @Test("Recent URLs are capped at 5 and persist")
    @MainActor
    func recentURLsTracking() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        for i in 1...6 {
            manager.addRecentURL(URL(string: "https://example\(i).com")!)
        }

        #expect(manager.recentURLs.count == 5)
        // Most recent should be at index 0 (example6)
        #expect(manager.recentURLs[0].absoluteString == "https://example6.com")
        // Overflows should push out the oldest, so example1 shouldn't be there.
        #expect(!manager.recentURLs.contains(where: { $0.absoluteString == "https://example1.com" }))

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.recentURLs.count == 5)
        #expect(manager2.recentURLs[0].absoluteString == "https://example6.com")
    }

    @Test("Adding a duplicate URL moves it to the top instead of adding twice")
    @MainActor
    func recentURLsDuplicates() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        manager.addRecentURL(URL(string: "https://example1.com")!)
        manager.addRecentURL(URL(string: "https://example2.com")!)
        
        #expect(manager.recentURLs[0].absoluteString == "https://example2.com")
        #expect(manager.recentURLs.count == 2)
        
        // Add example1 again
        manager.addRecentURL(URL(string: "https://example1.com")!)
        
        // Should move to top, count shouldn't increase
        #expect(manager.recentURLs[0].absoluteString == "https://example1.com")
        #expect(manager.recentURLs[1].absoluteString == "https://example2.com")
        #expect(manager.recentURLs.count == 2)
    }

    // MARK: - URL Cleaning

    @Test("cleanURL strips tracking parameters but keeps valid ones")
    func urlCleaningStripsTrackingParams() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        
        let urlWithTrackers = URL(string: "https://example.com/page?utm_source=twitter&valid=true&gclid=12345")!
        let cleanedURL = manager.cleanURL(urlWithTrackers)
        
        // Output should be exactly valid=true
        #expect(cleanedURL.absoluteString == "https://example.com/page?valid=true")
        
        let urlWithOnlyTrackers = URL(string: "https://example.com/page?utm_source=twitter")!
        let fullyCleaned = manager.cleanURL(urlWithOnlyTrackers)
        
        // The query string itself should be removed
        #expect(fullyCleaned.absoluteString == "https://example.com/page")
        
        let cleanURL = URL(string: "https://example.com/page?q=search")!
        let unchanged = manager.cleanURL(cleanURL)
        
        #expect(unchanged.absoluteString == "https://example.com/page?q=search")
    }

    // MARK: - Expanded Tracking Parameters

    @Test("cleanURL strips expanded tracking parameters")
    @MainActor
    func urlCleaningStripsExpandedTrackingParams() {
        let manager = BrowserManager(defaults: makeTestDefaults())

        // HubSpot
        let hsURL = URL(string: "https://example.com/page?_hsenc=abc&_hsmi=123&valid=true")!
        let hsClean = manager.cleanURL(hsURL)
        #expect(hsClean.absoluteString == "https://example.com/page?valid=true")

        // Google Ads expanded
        let gaURL = URL(string: "https://example.com/page?dclid=x&gbraid=y&wbraid=z&_ga=1&_gl=2&valid=ok")!
        let gaClean = manager.cleanURL(gaURL)
        #expect(gaClean.absoluteString == "https://example.com/page?valid=ok")

        // Yandex
        let yURL = URL(string: "https://example.com/page?yclid=abc&_openstat=xyz")!
        let yClean = manager.cleanURL(yURL)
        #expect(yClean.absoluteString == "https://example.com/page")

        // Marketo
        let mktURL = URL(string: "https://example.com/page?mkt_tok=abc&valid=1")!
        let mktClean = manager.cleanURL(mktURL)
        #expect(mktClean.absoluteString == "https://example.com/page?valid=1")
    }

    // MARK: - Regex Routing Rules

    @Test("Regex routing rule matches host pattern")
    @MainActor
    func regexRoutingRuleMatches() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager.configuredBrowsers = [chrome]

        // Add a regex rule matching any subdomain of company.com
        manager.addRoutingRule(
            name: "Company Internal",
            hostPattern: ".*\\.internal\\.company\\.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            useRegex: true
        )

        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].useRegex == true)

        // Should match
        let url1 = URL(string: "https://app.internal.company.com/dashboard")!
        let route1 = manager.resolvedRoute(for: url1)
        #expect(route1 != nil)
        #expect(route1?.browser.bundleId == "com.google.Chrome")

        // Should match deeper subdomain
        let url2 = URL(string: "https://dev.staging.internal.company.com/page")!
        let route2 = manager.resolvedRoute(for: url2)
        #expect(route2 != nil)

        // Should NOT match (no .internal. prefix)
        let url3 = URL(string: "https://company.com/page")!
        let route3 = manager.resolvedRoute(for: url3)
        #expect(route3 == nil)
    }

    @Test("Regex routing rule rejects invalid pattern")
    @MainActor
    func regexRoutingRuleRejectsInvalidPattern() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager.configuredBrowsers = [chrome]

        // Invalid regex — unmatched bracket
        manager.addRoutingRule(
            name: "Bad Regex",
            hostPattern: "[invalid",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            useRegex: true
        )

        // Should not have been added
        #expect(manager.routingRules.isEmpty)
    }

    @Test("isValidRoutingHostPattern validates regex patterns")
    @MainActor
    func regexPatternValidation() {
        let manager = BrowserManager(defaults: makeTestDefaults())

        #expect(manager.isValidRoutingHostPattern(".*\\.example\\.com", useRegex: true) == true)
        #expect(manager.isValidRoutingHostPattern("(dev|staging)\\.company\\.com", useRegex: true) == true)
        #expect(manager.isValidRoutingHostPattern("[invalid", useRegex: true) == false)
        #expect(manager.isValidRoutingHostPattern("", useRegex: true) == false)
    }

    @Test("Regex rule persists useRegex flag across manager instances")
    @MainActor
    func regexRulePersistence() {
        let defaults = makeTestDefaults()
        let manager1 = BrowserManager(defaults: defaults)

        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager1.configuredBrowsers = [chrome]
        manager1.addRoutingRule(
            name: "Regex Rule",
            hostPattern: ".*\\.test\\.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            useRegex: true
        )

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.routingRules.count == 1)
        #expect(manager2.routingRules[0].useRegex == true)
        #expect(manager2.routingRules[0].hostPattern == ".*\\.test\\.com")
    }

    @Test("Duplicating a regex rule preserves the useRegex flag")
    @MainActor
    func duplicateRegexRule() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager.configuredBrowsers = [chrome]
        manager.addRoutingRule(
            name: "Regex Original",
            hostPattern: ".*\\.dev\\.co",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            useRegex: true
        )

        manager.duplicateRoutingRule(id: manager.routingRules[0].id)
        #expect(manager.routingRules.count == 2)
        #expect(manager.routingRules[1].useRegex == true)
        #expect(manager.routingRules[1].hostPattern == ".*\\.dev\\.co")
        #expect(manager.routingRules[1].name == "Regex Original Copy")
    }

    @Test("Regex routing rule anchors match to full host string")
    @MainActor
    func regexRoutingRuleAnchorsMatch() {
        let defaults = makeTestDefaults()
        let manager = BrowserManager(defaults: defaults)

        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager.configuredBrowsers = [chrome]

        // Pattern "google\\.com" should only match exactly "google.com", NOT "not-google.com"
        manager.addRoutingRule(
            name: "Google Only",
            hostPattern: "google\\.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            useRegex: true
        )

        let exact = URL(string: "https://google.com/search")!
        #expect(manager.resolvedRoute(for: exact) != nil)

        let partial = URL(string: "https://not-google.com/search")!
        #expect(manager.resolvedRoute(for: partial) == nil)

        let suffix = URL(string: "https://google.com.evil.com/search")!
        #expect(manager.resolvedRoute(for: suffix) == nil)
    }

    // MARK: - Fallback Policy (Phase 1)

    @Test("Network privacy upgrade notice is only marked seen once, and stays seen (idempotent guard, not a UI-lifecycle flag)")
    @MainActor
    func networkPrivacyUpgradeNoticeMarkedSeenIsIdempotent() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        #expect(manager.hasSeenNetworkPrivacyUpgradeNotice == false)

        manager.markNetworkPrivacyUpgradeNoticeSeen()
        #expect(manager.hasSeenNetworkPrivacyUpgradeNotice == true)

        // Calling again (e.g. a second dismiss action) must not throw or misbehave — the
        // guard clause in markNetworkPrivacyUpgradeNoticeSeen() is what this test protects.
        // The actual regression this notice shipped with was in the UI layer (ContentView's
        // banner called this from `.onAppear` instead of only from the explicit dismiss
        // button, so the banner vanished before a user could read it — see PR #40 review).
        // That's not unit-testable without rendering the view; this test only guards the
        // state-layer contract the UI fix depends on: marking seen is a one-way,
        // explicit-action-only transition.
        manager.markNetworkPrivacyUpgradeNoticeSeen()
        #expect(manager.hasSeenNetworkPrivacyUpgradeNotice == true)
    }

    @Test("Fallback policy defaults to picker for fresh and existing installs")
    @MainActor
    func fallbackPolicyDefaultsToPicker() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        #expect(manager.fallbackPolicy.mode == .picker)
        #expect(manager.fallbackRoute() == nil)
    }

    @Test("Fallback policy persists across manager instances")
    @MainActor
    func fallbackPolicyPersists() {
        let defaults = makeTestDefaults()
        let manager1 = BrowserManager(defaults: defaults)
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager1.configuredBrowsers = [chrome]
        manager1.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: chrome.id, profile: nil)

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.fallbackPolicy.mode == .browser)
        #expect(manager2.fallbackPolicy.browserID == chrome.id)
    }

    @Test("Unmatched link opens the configured fallback browser")
    @MainActor
    func fallbackRouteOpensConfiguredBrowser() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager.configuredBrowsers = [chrome]
        manager.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: chrome.id)

        let route = AppDelegate.resolveIncomingURLRoute(
            for: URL(string: "https://example.com")!,
            using: manager,
            forceShowPicker: false
        )

        #expect(route?.rule == nil)
        #expect(route?.browser.bundleId == "com.google.Chrome")
    }

    @Test("Fallback falls back to picker when the configured browser was deleted")
    @MainActor
    func fallbackRouteMissingBrowserShowsPicker() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        manager.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: UUID())

        #expect(manager.fallbackRoute() == nil)
    }

    @Test("Fallback falls back to picker when the configured browser is hidden")
    @MainActor
    func fallbackRouteHiddenBrowserShowsPicker() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager.configuredBrowsers = [chrome]
        manager.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: chrome.id)
        manager.addHiddenBundleID("com.google.Chrome")

        #expect(manager.fallbackRoute() == nil)
    }

    @Test("Fallback falls back to picker when the configured browser is disabled (FR-003)")
    @MainActor
    func fallbackRouteDisabledBrowserShowsPicker() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        var chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        chrome.isEnabled = false
        manager.configuredBrowsers = [chrome]
        manager.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: chrome.id)

        #expect(manager.fallbackRoute() == nil)
    }

    @Test("Hold-Shift forces the picker even when fallback would open a browser")
    @MainActor
    func forcedPickerOverridesFallback() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
        manager.configuredBrowsers = [chrome]
        manager.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: chrome.id)

        let route = AppDelegate.resolveIncomingURLRoute(
            for: URL(string: "https://example.com")!,
            using: manager,
            forceShowPicker: true
        )

        #expect(route == nil)
    }

    @Test("A matching routing rule takes precedence over fallback")
    @MainActor
    func matchedRuleTakesPrecedenceOverFallback() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        manager.configuredBrowsers = [
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "2"),
        ]
        manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome"
        )
        manager.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: manager.configuredBrowsers[1].id)

        let route = AppDelegate.resolveIncomingURLRoute(
            for: URL(string: "https://github.com/org/repo")!,
            using: manager,
            forceShowPicker: false
        )

        #expect(route?.browser.bundleId == "com.google.Chrome")
    }

    // MARK: - Save-Time Regex Complexity Rejection (FR-028)

    @Test("Catastrophic-backtracking regex patterns are rejected at save time")
    @MainActor
    func catastrophicRegexPatternsRejectedAtSave() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        manager.configuredBrowsers = [BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")]

        for pattern in [
            "(a+)+", "(a*)*", "(a+)*", "(ab+)+",
            // Security review bypasses: interval quantifiers, outer and inner position.
            "(a+){10,}", "(a{2,})+",
            // Security review bypasses: overlapping/duplicate alternation branches.
            "(a|a)*", "(a|ab)*",
            // Security review bypass: directly-nested group under an outer quantifier.
            "((a+))+",
        ] {
            let result = manager.addRoutingRule(
                name: "Bad",
                hostPattern: pattern,
                pathPrefix: nil,
                browserBundleId: "com.google.Chrome",
                useRegex: true
            )
            if case .failure(let error) = result {
                #expect(error == .regexTooComplex, "Pattern \(pattern) should be rejected as too complex")
            } else {
                Issue.record("Pattern \(pattern) unexpectedly passed save-time validation")
            }
        }
        #expect(manager.routingRules.isEmpty)
        #expect(BrowserManager.isDangerouslyComplexRegex("(a+)+"))
        #expect(BrowserManager.isDangerouslyComplexRegex("(a+){10,}"))
        #expect(BrowserManager.isDangerouslyComplexRegex("(a{2,})+"))
        #expect(BrowserManager.isDangerouslyComplexRegex("(a|a)*"))
        #expect(BrowserManager.isDangerouslyComplexRegex("(a|ab)*"))
        #expect(BrowserManager.isDangerouslyComplexRegex("((a+))+"))
    }

    @Test("hostMatches caps regex input length as a runtime backstop, independent of the save-time heuristic's completeness")
    @MainActor
    func hostMatchesCapsRegexInputLength() {
        // A pathologically long host is rejected outright before it ever reaches the
        // regex engine, bounding worst-case backtracking regardless of pattern quality.
        let longHost = String(repeating: "a", count: BrowserManager.maxRegexHostLength + 1)
        #expect(!BrowserManager.hostMatches(longHost, pattern: ".*", useRegex: true))

        // A host right at the cap still matches normally.
        let boundaryHost = String(repeating: "a", count: BrowserManager.maxRegexHostLength)
        #expect(BrowserManager.hostMatches(boundaryHost, pattern: ".*", useRegex: true))
    }

    @Test("Legitimate regex patterns are still accepted at save time")
    @MainActor
    func legitimateRegexPatternsStillAccepted() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        manager.configuredBrowsers = [BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")]

        let result = manager.addRoutingRule(
            name: "Fine",
            hostPattern: ".*\\.example\\.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            useRegex: true
        )
        #expect(result.isSuccess)
        #expect(manager.isValidRoutingHostPattern("(dev|staging)\\.company\\.com", useRegex: true) == true)
        #expect(!BrowserManager.isDangerouslyComplexRegex(".*\\.example\\.com"))
    }

    @Test("Regression: already-persisted complex regex rules are not re-validated on load")
    @MainActor
    func persistedComplexRegexRuleNotRetroactivelyBroken() throws {
        let defaults = makeTestDefaults()
        // Simulate a rule saved before the FR-028 check existed by writing directly to
        // persistence, bypassing addRoutingRule's validation.
        let legacyRule = BrowserRoutingRule(
            id: UUID(),
            name: "Legacy",
            hostPattern: "(a+)+\\.example\\.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            profile: nil,
            useRegex: true
        )
        let encoded = try JSONEncoder().encode([legacyRule])
        defaults.set(encoded, forKey: "routingRules")

        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")]

        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].useRegex == true)
    }

    // MARK: - Network Lookups / Privacy Controls (Phase 1)

    @Test("Shortlink resolution defaults to off, including for existing-shaped installs")
    @MainActor
    func networkLookupsDefaultOff() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        #expect(manager.networkLookupsEnabled == false)
    }

    @Test("Disabled shortlink resolution makes no network request and returns the original URL")
    @MainActor
    func disabledShortlinkResolutionSkipsNetwork() async {
        let manager = BrowserManager(defaults: makeTestDefaults())
        manager.networkLookupsEnabled = false

        let shortlink = URL(string: "https://bit.ly/does-not-matter")!
        let start = ContinuousClock.now
        let result = await manager.unshortenURL(shortlink)
        let elapsed = start.duration(to: .now)

        #expect(result == shortlink)
        #expect(elapsed < .seconds(1), "Disabled resolution should return immediately without touching the network")
    }

    @Test("Shortlink allowlist covers built-in hosts and user-appended hosts only")
    @MainActor
    func shortlinkAllowlistCoversBuiltInAndUserHosts() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        #expect(manager.isAllowedShortenerHost("bit.ly"))
        #expect(manager.isAllowedShortenerHost("t.co"))
        #expect(!manager.isAllowedShortenerHost("not-a-shortener.example.com"))

        manager.addUserShortenerHost("short.example.com")
        #expect(manager.isAllowedShortenerHost("short.example.com"))
        #expect(manager.isAllowedShortenerHost("SHORT.example.com"))

        manager.removeUserShortenerHost("short.example.com")
        #expect(!manager.isAllowedShortenerHost("short.example.com"))
    }

    @Test("Tracking cleanup toggle gates parameter stripping")
    @MainActor
    func trackingCleanupToggleGatesStripping() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let url = URL(string: "https://example.com/page?utm_source=test&keep=1")!

        manager.trackingCleanupEnabled = true
        let cleaned = manager.cleanURL(url)
        #expect(cleaned.query?.contains("utm_source") == false)
        #expect(cleaned.query?.contains("keep=1") == true)

        manager.trackingCleanupEnabled = false
        let uncleaned = manager.cleanURL(url)
        #expect(uncleaned == url)
    }

    // MARK: - MCP Constant-Time Token Comparison

    @Test("Constant-time token comparison matches standard equality semantics")
    func constantTimeTokenComparisonMatchesEquality() {
        #expect(MCPServer.constantTimeEquals("abc123", "abc123"))
        #expect(!MCPServer.constantTimeEquals("abc123", "abc124"))
        #expect(!MCPServer.constantTimeEquals("abc123", "abc12"))
        #expect(!MCPServer.constantTimeEquals("", "abc123"))
        #expect(MCPServer.constantTimeEquals("", ""))
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
