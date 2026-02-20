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
        
        let newBrowser = BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "2")
        manager.configuredBrowsers.append(newBrowser)
        
        #expect(manager.configuredBrowsers.count == 2)
        #expect(manager.configuredBrowsers[1].name == "Arc")
        
        // Verify persistence
        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.configuredBrowsers.count == 2)
        #expect(manager2.configuredBrowsers[1].bundleId == "company.thebrowser.Browser")
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

        let matchingURL = URL(string: "https://github.com/orgs/openai")!
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

    @Test("Removing a browser removes rules targeting that browser")
    @MainActor
    func removingBrowserPrunesRules() {
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
        #expect(manager.routingRules.isEmpty)
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
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "company.thebrowser.Browser"
        )

        let url = URL(string: "https://github.com/openai")!
        let route = manager.resolvedRoute(for: url)

        #expect(route?.rule.name == "GitHub")
        #expect(route?.browser.bundleId == "company.thebrowser.Browser")
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
            hostPattern: "https://github.com/orgs/openai",
            pathPrefix: nil,
            browserBundleId: "company.thebrowser.Browser"
        )

        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].hostPattern == "github.com")
        #expect(manager.resolvedBrowser(for: URL(string: "https://github.com/openai")!)?.bundleId == "company.thebrowser.Browser")
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
}
