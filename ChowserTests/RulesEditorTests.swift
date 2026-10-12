import Testing
import Foundation
@testable import Chowser

@MainActor
struct RulesEditorTests {
    private func makeManager() -> BrowserManager {
        let defaults = UserDefaults(suiteName: "com.chowser.tests.rules.\(UUID().uuidString)")!
        let manager = BrowserManager(defaults: defaults)
        manager.configuredBrowsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "2"),
        ]
        manager.routingRules = []
        return manager
    }

    @discardableResult
    private func addRule(_ manager: BrowserManager, _ host: String, browser: String = "com.apple.Safari") -> BrowserRoutingRule {
        guard case .success(let rule) = manager.addRoutingRule(name: "", hostPattern: host, pathPrefix: nil, browserBundleId: browser) else {
            Issue.record("Expected \(host) to be a valid rule")
            return BrowserRoutingRule(name: "", hostPattern: "", browserBundleId: "")
        }
        return rule
    }

    // MARK: - BrowserManager helpers

    @Test("validateRoutingRule reports errors without mutating the store")
    func validateDoesNotMutate() {
        let manager = makeManager()
        let invalid = BrowserRoutingRule(name: "", hostPattern: "git..hub", browserBundleId: "com.apple.Safari")
        #expect(manager.validateRoutingRule(invalid) == .failure(.invalidHostPattern))

        let valid = BrowserRoutingRule(name: "", hostPattern: "GitHub.com/", browserBundleId: "com.apple.Safari")
        guard case .success(let normalized) = manager.validateRoutingRule(valid) else {
            Issue.record("Expected success")
            return
        }
        #expect(normalized.hostPattern == "github.com")
        #expect(normalized.name == "github.com")
        #expect(manager.routingRules.isEmpty)

        let missingBrowser = BrowserRoutingRule(name: "", hostPattern: "a.com", browserBundleId: "com.example.gone")
        #expect(manager.validateRoutingRule(missingBrowser) == .failure(.browserNotFound(bundleId: "com.example.gone", profile: nil)))
    }

    @Test("Insertion index is after the given rule, or at the end")
    func insertionIndex() {
        let manager = makeManager()
        let a = addRule(manager, "a.com")
        let b = addRule(manager, "b.com")
        #expect(manager.routingRuleInsertionIndex(after: a.id) == 1)
        #expect(manager.routingRuleInsertionIndex(after: b.id) == 2)
        #expect(manager.routingRuleInsertionIndex(after: nil) == 2)
        #expect(manager.routingRuleInsertionIndex(after: UUID()) == 2)
    }

    @Test("insertRoutingRule validates and clamps the index")
    func insertRule() {
        let manager = makeManager()
        addRule(manager, "a.com")
        addRule(manager, "b.com")

        let invalid = BrowserRoutingRule(name: "", hostPattern: "", browserBundleId: "com.apple.Safari")
        #expect(manager.insertRoutingRule(invalid, at: 1) == .failure(.invalidHostPattern))
        #expect(manager.routingRules.count == 2)

        let middle = BrowserRoutingRule(name: "", hostPattern: "m.com", browserBundleId: "com.apple.Safari")
        #expect((try? manager.insertRoutingRule(middle, at: 1).get()) != nil)
        #expect(manager.routingRules.map(\.hostPattern) == ["a.com", "m.com", "b.com"])

        let far = BrowserRoutingRule(name: "", hostPattern: "z.com", browserBundleId: "com.apple.Safari")
        #expect((try? manager.insertRoutingRule(far, at: 99).get()) != nil)
        #expect(manager.routingRules.last?.hostPattern == "z.com")
    }

    @Test("Deleting a rule registers an undo that restores it at its original index, and redo deletes again")
    func deleteUndoRestoresIndex() {
        let manager = makeManager()
        addRule(manager, "a.com")
        let b = addRule(manager, "b.com")
        addRule(manager, "c.com")
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false

        undoManager.beginUndoGrouping()
        let index = manager.deleteRoutingRule(id: b.id, undoManager: undoManager)
        undoManager.endUndoGrouping()

        #expect(index == 1)
        #expect(manager.routingRules.map(\.hostPattern) == ["a.com", "c.com"])
        #expect(undoManager.canUndo)
        #expect(undoManager.undoActionName == "Delete Rule")

        undoManager.undo()
        #expect(manager.routingRules.map(\.hostPattern) == ["a.com", "b.com", "c.com"])
        #expect(manager.routingRules[1] == b)

        #expect(undoManager.canRedo)
        undoManager.redo()
        #expect(manager.routingRules.map(\.hostPattern) == ["a.com", "c.com"])
    }

    @Test("Restore clamps the index and never duplicates an existing rule")
    func restoreClampsAndDedupes() {
        let manager = makeManager()
        let a = addRule(manager, "a.com")
        manager.restoreRoutingRule(a, at: 0, undoManager: nil)
        #expect(manager.routingRules.count == 1)

        let gone = BrowserRoutingRule(name: "x", hostPattern: "x.com", browserBundleId: "com.apple.Safari")
        manager.restoreRoutingRule(gone, at: 50, undoManager: nil)
        #expect(manager.routingRules.map(\.hostPattern) == ["a.com", "x.com"])
    }

    @Test("routingRuleIssues lists enabled stored rules whose browser is missing")
    func ruleIssues() {
        let manager = makeManager()
        addRule(manager, "a.com", browser: "company.thebrowser.Browser")
        addRule(manager, "b.com")
        manager.configuredBrowsers.removeAll { $0.bundleId == "company.thebrowser.Browser" }
        let issues = manager.routingRuleIssues()
        #expect(issues.count == 1)
        #expect(issues.first?.index == 0)
        #expect(issues.first?.error == .browserNotFound(bundleId: "company.thebrowser.Browser", profile: nil))
    }

    // MARK: - RulesEditorModel

    @Test("Invalid edits stay as a draft and never reach the store; valid edits commit")
    func invalidEditsKeptAsDraft() {
        let manager = makeManager()
        let rule = addRule(manager, "github.com")
        let model = RulesEditorModel(manager: manager)
        model.selection = rule.id

        model.update(rule.id) { $0.hostPattern = "git..hub" }
        #expect(manager.routingRules[0].hostPattern == "github.com")
        #expect(model.editableRule(for: rule.id)?.hostPattern == "git..hub")
        #expect(model.rows.first?.issue == .invalidHostPattern)
        #expect(model.hasUnsavedInvalidEdits(rule.id))

        // Ending editing must not lose the invalid text.
        model.endEditing(rule.id)
        #expect(model.editableRule(for: rule.id)?.hostPattern == "git..hub")

        model.update(rule.id) { $0.hostPattern = "GitLab.com" }
        #expect(manager.routingRules[0].hostPattern == "gitlab.com")
        // The typed text is kept until editing ends, then shows the normalized value.
        #expect(model.editableRule(for: rule.id)?.hostPattern == "GitLab.com")
        model.endEditing(rule.id)
        #expect(model.editableRule(for: rule.id)?.hostPattern == "gitlab.com")
        #expect(!model.hasUnsavedInvalidEdits(rule.id))
    }

    @Test("An auto-derived name follows the pattern when the pattern changes")
    func autoNameFollowsPattern() {
        let manager = makeManager()
        let rule = addRule(manager, "github.com")
        #expect(rule.name == "github.com")
        let model = RulesEditorModel(manager: manager)
        #expect(model.editableRule(for: rule.id)?.name == "")
        model.update(rule.id) { $0.hostPattern = "gitlab.com" }
        #expect(manager.routingRules[0].name == "gitlab.com")
    }

    @Test("Revert discards an invalid draft")
    func revertDraft() {
        let manager = makeManager()
        let rule = addRule(manager, "github.com")
        let model = RulesEditorModel(manager: manager)
        model.update(rule.id) { $0.pathPrefix = "has space" }
        #expect(model.rows.first?.issue == .invalidPathPrefix)
        model.revert(rule.id)
        #expect(model.rows.first?.issue == nil)
        #expect(model.editableRule(for: rule.id)?.pathPrefix == nil)
    }

    @Test("A new rule is inserted after the selection as an unsaved draft, then saved once valid")
    func addRuleAfterSelection() {
        let manager = makeManager()
        let a = addRule(manager, "a.com")
        addRule(manager, "b.com")
        let model = RulesEditorModel(manager: manager)
        model.selection = a.id

        model.addRule()
        guard let newID = model.selection, newID != a.id else {
            Issue.record("New rule should be selected")
            return
        }
        #expect(model.focusPatternRequest == newID)
        #expect(manager.routingRules.count == 2)
        #expect(model.rows.map(\.id)[1] == newID)
        #expect(model.rows[1].isUnsaved)
        #expect(model.rows[1].issue == .invalidHostPattern)

        model.update(newID) { $0.hostPattern = "n" }
        model.update(newID) { $0.hostPattern = "new.com" }
        #expect(manager.routingRules.map(\.hostPattern) == ["a.com", "new.com", "b.com"])
        #expect(!model.isUnsaved(newID))
    }

    @Test("An untouched new rule is discarded when the selection moves away; one with typing is kept")
    func blankNewRuleDiscarded() {
        let manager = makeManager()
        let a = addRule(manager, "a.com")
        let model = RulesEditorModel(manager: manager)

        model.addRule()
        model.selection = a.id
        #expect(model.pendingNewRule == nil)
        #expect(model.rows.count == 1)

        model.addRule()
        let newID = model.selection!
        model.update(newID) { $0.hostPattern = "bad..host" }
        model.selection = a.id
        #expect(model.pendingNewRule?.rule.hostPattern == "bad..host")
        #expect(manager.routingRules.count == 1)

        // Adding again returns to the existing unsaved rule instead of losing it.
        model.addRule()
        #expect(model.selection == newID)
    }

    @Test("A prefilled valid host is saved immediately")
    func prefilledRuleSaved() {
        let manager = makeManager()
        let model = RulesEditorModel(manager: manager)
        model.addRule(prefillHost: "example.com", browserIdentity: "company.thebrowser.Browser|")
        #expect(manager.routingRules.count == 1)
        #expect(manager.routingRules[0].browserBundleId == "company.thebrowser.Browser")
        #expect(model.selection == manager.routingRules[0].id)
    }

    @Test("Delete selects the next row and undo restores the stored rule")
    func deleteViaModel() {
        let manager = makeManager()
        addRule(manager, "a.com")
        let b = addRule(manager, "b.com")
        let c = addRule(manager, "c.com")
        let model = RulesEditorModel(manager: manager)
        model.selection = b.id
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false

        undoManager.beginUndoGrouping()
        model.delete(b.id, undoManager: undoManager)
        undoManager.endUndoGrouping()
        #expect(model.selection == c.id)
        #expect(manager.routingRules.map(\.hostPattern) == ["a.com", "c.com"])

        undoManager.undo()
        #expect(manager.routingRules.map(\.hostPattern) == ["a.com", "b.com", "c.com"])
    }

    @Test("Moving by table position reorders the store")
    func moveRows() {
        let manager = makeManager()
        let a = addRule(manager, "a.com")
        addRule(manager, "b.com")
        addRule(manager, "c.com")
        let model = RulesEditorModel(manager: manager)
        model.move(ids: [a.id], toDisplayIndex: 3)
        #expect(manager.routingRules.map(\.hostPattern) == ["b.com", "c.com", "a.com"])
    }

    @Test("Tester reports the matching rule, the fallback, and skipped rules")
    func testerOutcome() {
        let manager = makeManager()
        addRule(manager, "github.com", browser: "company.thebrowser.Browser")
        addRule(manager, "*.example.com")
        let model = RulesEditorModel(manager: manager)

        #expect(model.testOutcome().kind == .empty)
        model.testURL = "not a link"
        #expect(model.testOutcome().kind == .invalidURL)

        model.testURL = "docs.example.com/path"
        guard case .matched(_, let browser, let position) = model.testOutcome().kind else {
            Issue.record("Expected a match")
            return
        }
        #expect(position == 2)
        #expect(browser.bundleId == "com.apple.Safari")

        manager.configuredBrowsers.removeAll { $0.bundleId == "company.thebrowser.Browser" }
        model.testURL = "github.com"
        let outcome = model.testOutcome()
        #expect(outcome.kind == .picker)
        #expect(outcome.skipped.count == 1)
    }

    @Test("Pattern messages explain what is wrong")
    func patternMessages() {
        #expect(RoutingRuleMessages.hostPatternMessage("") == "Enter a link to match, like github.com.")
        #expect(RoutingRuleMessages.hostPatternMessage("git..hub.com").contains("two dots"))
        #expect(RoutingRuleMessages.hostPatternMessage("git*hub.com").contains("Use * only at the start"))
        #expect(RoutingRuleMessages.hostPatternMessage("git hub.com").contains("spaces"))
        #expect(RoutingRuleMessages.ignoredPathInPattern("github.com/acme/*") == "/acme/")
        #expect(RoutingRuleMessages.ignoredPathInPattern("github.com") == nil)
    }
}
