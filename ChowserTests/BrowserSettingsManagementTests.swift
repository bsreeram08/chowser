import Testing
import Foundation
@testable import Chowser

/// Covers the BrowserManager logic behind the Browsers settings page: multi-add with
/// shortcut assignment, undoable removal/restore, shortcut swaps, and rule usage counts.
struct BrowserSettingsManagementTests {

    private func makeManager() -> BrowserManager {
        let defaults = UserDefaults(suiteName: "com.chowser.tests.\(UUID().uuidString)")!
        return BrowserManager(defaults: defaults)
    }

    private func request(_ name: String, _ bundleId: String, profile: String? = nil) -> BrowserManager.BrowserAddRequest {
        BrowserManager.BrowserAddRequest(name: name, bundleId: bundleId, profile: profile)
    }

    // MARK: - Multi-add

    @Test("Adding several browsers at once assigns the next free shortcuts in order")
    @MainActor
    func multiAddAssignsNextFreeShortcuts() {
        let manager = makeManager()
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3"),
        ]

        let added = manager.addBrowsers([
            request("Chrome - Work", "com.google.Chrome", profile: "Profile 1"),
            request("Chrome - Personal", "com.google.Chrome", profile: "Default"),
            request("Arc", "company.thebrowser.Browser"),
        ])

        #expect(added.map(\.name) == ["Chrome - Work", "Chrome - Personal", "Arc"])
        #expect(added.map(\.shortcutKey) == ["2", "4", "5"])
        #expect(manager.configuredBrowsers.count == 5)
        #expect(manager.configuredBrowsers.suffix(3).map(\.id) == added.map(\.id))
    }

    @Test("Multi-add skips already-configured and duplicate identities")
    @MainActor
    func multiAddSkipsDuplicates() {
        let manager = makeManager()
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
        ]

        let added = manager.addBrowsers([
            request("Safari again", "com.apple.Safari"),
            request("Chrome", "com.google.Chrome", profile: "Default"),
            request("Chrome dup", "com.google.Chrome", profile: "Default"),
            request("   ", "com.example.blank"),
        ])

        #expect(added.count == 1)
        #expect(added.first?.name == "Chrome")
        #expect(added.first?.shortcutKey == "2")
        #expect(manager.configuredBrowsers.count == 2)
    }

    @Test("Multi-add with nothing new leaves the list untouched")
    @MainActor
    func multiAddNoOp() {
        let manager = makeManager()
        let before = manager.configuredBrowsers

        let added = manager.addBrowsers([])

        #expect(added.isEmpty)
        #expect(manager.configuredBrowsers == before)
    }

    // MARK: - Remove / restore

    @Test("Removing then restoring puts the browser back at its index with its shortcut")
    @MainActor
    func removeAndRestoreKeepsIndexAndShortcut() {
        let manager = makeManager()
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "4", profile: "Default")
        let firefox = BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "2")
        manager.configuredBrowsers = [safari, chrome, firefox]

        let snapshot = manager.removeBrowser(id: chrome.id, undoManager: nil)

        #expect(snapshot?.index == 1)
        #expect(manager.configuredBrowsers.map(\.id) == [safari.id, firefox.id])

        let restored = snapshot.map { manager.restoreBrowser($0) } ?? false

        #expect(restored)
        #expect(manager.configuredBrowsers.map(\.id) == [safari.id, chrome.id, firefox.id])
        #expect(manager.configuredBrowsers[1] == chrome)
    }

    @Test("Undo restores a removed browser and redo removes it again")
    @MainActor
    func undoManagerRestoresAndRedoes() {
        let manager = makeManager()
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        let firefox = BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3")
        manager.configuredBrowsers = [safari, chrome, firefox]

        let undoManager = UndoManager()
        undoManager.groupsByEvent = false

        undoManager.beginUndoGrouping()
        manager.removeBrowser(id: safari.id, undoManager: undoManager)
        undoManager.endUndoGrouping()

        #expect(manager.configuredBrowsers.map(\.id) == [chrome.id, firefox.id])
        #expect(undoManager.canUndo)
        #expect(undoManager.undoActionName == "Remove Browser")

        undoManager.undo()
        #expect(manager.configuredBrowsers.map(\.id) == [safari.id, chrome.id, firefox.id])
        #expect(manager.configuredBrowsers[0].shortcutKey == "1")
        #expect(undoManager.canRedo)

        undoManager.redo()
        #expect(manager.configuredBrowsers.map(\.id) == [chrome.id, firefox.id])
    }

    @Test("Restoring after the list shrank clamps the index")
    @MainActor
    func restoreClampsIndex() {
        let manager = makeManager()
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        let firefox = BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3")
        manager.configuredBrowsers = [safari, chrome, firefox]

        let firefoxSnapshot = manager.removeBrowser(id: firefox.id, undoManager: nil)
        manager.removeBrowser(id: chrome.id, undoManager: nil)

        #expect(firefoxSnapshot.map { manager.restoreBrowser($0) } == true)
        #expect(manager.configuredBrowsers.map(\.id) == [safari.id, firefox.id])
    }

    @Test("Restore gives a new shortcut when the original was taken in the meantime")
    @MainActor
    func restoreResolvesShortcutConflict() {
        let manager = makeManager()
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        manager.configuredBrowsers = [safari, chrome]

        let snapshot = manager.removeBrowser(id: chrome.id, undoManager: nil)
        manager.updateShortcutKey(id: safari.id, to: "2")

        #expect(snapshot.map { manager.restoreBrowser($0) } == true)
        let restoredChrome = manager.configuredBrowsers.first { $0.id == chrome.id }
        #expect(restoredChrome?.shortcutKey == "1")
        #expect(Set(manager.configuredBrowsers.map(\.shortcutKey)).count == 2)
    }

    @Test("Restore is a no-op when the same browser was re-added")
    @MainActor
    func restoreSkipsReaddedBrowser() {
        let manager = makeManager()
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        manager.configuredBrowsers = [safari, chrome]

        let snapshot = manager.removeBrowser(id: chrome.id, undoManager: nil)
        manager.addBrowsers([request("Chrome", "com.google.Chrome")])

        #expect(snapshot.map { manager.restoreBrowser($0) } == false)
        #expect(manager.configuredBrowsers.count == 2)
    }

    @Test("Restoring a browser makes its routing rules resolve again")
    @MainActor
    func restoreRevivesRules() throws {
        let manager = makeManager()
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2", profile: "Default")
        manager.configuredBrowsers = [safari, chrome]
        manager.routingRules = []
        _ = manager.addRoutingRule(
            name: "GitHub",
            hostPattern: "github.com",
            pathPrefix: nil,
            browserBundleId: "com.google.Chrome",
            profile: "Default"
        )
        #expect(manager.routingRuleCount(forBrowser: chrome) == 1)
        #expect(manager.routingRuleCount(forBrowser: safari) == 0)

        let url = try #require(URL(string: "https://github.com/acme"))
        #expect(manager.resolvedRoute(for: url)?.browser.id == chrome.id)

        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        undoManager.beginUndoGrouping()
        manager.removeBrowser(id: chrome.id, undoManager: undoManager)
        undoManager.endUndoGrouping()
        #expect(manager.resolvedRoute(for: url)?.rule == nil)

        undoManager.undo()
        #expect(manager.resolvedRoute(for: url)?.browser.id == chrome.id)
        #expect(manager.resolvedRoute(for: url)?.rule?.name == "GitHub")
    }

    // MARK: - Shortcut swap

    @Test("Picking a shortcut another browser uses swaps and reports the other browser")
    @MainActor
    func shortcutSwapReportsPartner() {
        let manager = makeManager()
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        let firefox = BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3")
        manager.configuredBrowsers = [safari, chrome, firefox]

        let swapped = manager.updateShortcutKey(id: firefox.id, to: "1")

        #expect(swapped?.id == safari.id)
        #expect(swapped?.shortcutKey == "3")
        #expect(manager.configuredBrowsers.map(\.shortcutKey) == ["3", "2", "1"])
    }

    @Test("Picking a free or unchanged shortcut reports no swap")
    @MainActor
    func shortcutWithoutSwapReturnsNil() {
        let manager = makeManager()
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let chrome = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        manager.configuredBrowsers = [safari, chrome]

        #expect(manager.updateShortcutKey(id: chrome.id, to: "7") == nil)
        #expect(manager.updateShortcutKey(id: chrome.id, to: "7") == nil)
        #expect(manager.updateShortcutKey(id: chrome.id, to: "x") == nil)
        #expect(manager.configuredBrowsers.map(\.shortcutKey) == ["1", "7"])
    }

    // MARK: - Add sheet rows

    @Test("Add sheet keeps configured entries (shown as already added) in launch-argument builds")
    func sheetRowsKeepConfiguredEntries() {
        let source: [AddBrowserSheet.BrowserEntry] = [
            (name: "Google Chrome - Personal", bundleId: "com.google.Chrome", profile: "Default", iconURL: nil),
            (name: "Google Chrome - Work", bundleId: "com.google.Chrome", profile: "Profile 1", iconURL: nil),
            (name: "Safari", bundleId: "com.apple.Safari", profile: nil, iconURL: nil),
        ]

        let rows = AddBrowserSheet.sheetRows(
            for: source,
            configuredIdentities: ["com.apple.Safari|"],
            supportsLaunchArguments: true
        )
        let candidates = AddBrowserSheet.browserCandidates(
            for: source,
            configuredIdentities: ["com.apple.Safari|"],
            supportsLaunchArguments: true
        )

        #expect(rows.count == 3)
        #expect(candidates.map(\.name) == ["Google Chrome - Personal", "Google Chrome - Work"])
    }
}
