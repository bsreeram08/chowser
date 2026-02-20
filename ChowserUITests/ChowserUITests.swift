import XCTest
import AppKit

final class ChowserUITests: XCTestCase {
    private var app: XCUIApplication!
    private let chowserBundleIdentifier = "in.sreerams.Chowser"

    override func setUpWithError() throws {
        continueAfterFailure = false

        terminateRunningChowserApps()

        app = XCUIApplication()
        app.launchEnvironment["CHOWSER_DEFAULTS_SUITE"] = "in.sreerams.Chowser.UITests.\(UUID().uuidString)"
        app.launchArguments = [
            "-UITesting",
            "-UITesting_ClearData",
            "-UITesting_MockInstalledBrowsers",
            "-UITesting_DisableExternalOpen",
            "-UITesting_DefaultURL",
            "-UITesting_OpenSettings",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }

        terminateRunningChowserApps(timeout: 2)
        app = nil
    }

    private func terminateRunningChowserApps(timeout: TimeInterval = 6) {
        let deadline = Date().addingTimeInterval(timeout)

        while true {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: chowserBundleIdentifier)
            guard !runningApps.isEmpty else { return }

            for runningApp in runningApps {
                if !runningApp.terminate() {
                    runningApp.forceTerminate()
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.15))

            if Date() >= deadline {
                for runningApp in runningApps where !runningApp.isTerminated {
                    runningApp.forceTerminate()
                }
                return
            }
        }
    }

    func testSettingsDeleteButtonDoesNotCloseSettingsWindow() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.assertSettingsVisible()

        if ui.browserDeleteButtons.count < 2 {
            ui.openAddBrowserSheet()
            ui.addFirstBrowserOption()
        }

        XCTAssertGreaterThanOrEqual(ui.browserDeleteButtons.count, 2, "Need at least two rows to verify deletion.")

        ui.browserDeleteButtons.element(boundBy: 1).click()
        ui.assertSettingsVisible()
    }

    func testResetToFreshSetupRestoresFirstLaunchState() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.assertSettingsVisible()

        ui.openAddBrowserSheet()
        ui.addFirstBrowserOption()
        XCTAssertGreaterThanOrEqual(ui.browserDeleteButtons.count, 2, "Add browser should increase browser list size.")

        ui.openGeneralSection()
        ui.resetToFreshSetup()
        ui.openBrowsersSection()

        XCTAssertEqual(ui.browserDeleteButtons.count, 1, "Fresh setup should restore one default browser.")
        XCTAssertTrue(ui.firstBrowserNameValue.localizedCaseInsensitiveContains("Safari"))
    }

    func testPickerSelectionClearsPendingURL() throws {
        let ui = ChowserAppDriver(app: app)
        ui.assertPickerVisible()
        XCTAssertTrue(ui.lastOpenedBrowserText.waitForExistence(timeout: 3), "Expected picker selection marker before choosing a browser.")

        XCTAssertTrue(ui.firstPickerBrowserRow.waitForExistence(timeout: 3), "Expected at least one picker browser row.")
        ui.firstPickerBrowserRow.click()

        ui.assertBrowserSelectionRecorded()
    }

    func testPickerNumberShortcutSelectsBrowser() throws {
        let ui = ChowserAppDriver(app: app)
        ui.assertPickerVisible()
        XCTAssertTrue(ui.lastOpenedBrowserText.waitForExistence(timeout: 3), "Expected picker selection marker before using keyboard shortcut.")

        app.typeKey("1", modifierFlags: [])

        ui.assertBrowserSelectionRecorded()
    }

    func testCanAddRoutingRule() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.assertSettingsVisible()
        ui.openRulesSection()
        ui.openAddRuleSheet()
        ui.addRule(hostPattern: "github.com")
        ui.assertRuleCreated()
    }
}

private struct ChowserAppDriver {
    let app: XCUIApplication

    var pickerSettingsButton: XCUIElement { app.buttons["picker.openSettingsButton"] }
    var settingsAddBrowserButton: XCUIElement { app.buttons["settings.addBrowserButton"] }

    var browserDeleteButtons: XCUIElementQuery {
        app.buttons.matching(identifier: "settings.browser.deleteButton")
    }

    var addSheetRoot: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "settings.addSheet.root").firstMatch
    }

    var lastOpenedBrowserText: XCUIElement {
        app.staticTexts["picker.lastOpenedBrowser"]
    }

    var browserNameFields: XCUIElementQuery {
        app.textFields.matching(identifier: "settings.browser.nameField")
    }

    var firstPickerBrowserRow: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "picker.browserRow").firstMatch
    }

    var addRuleButton: XCUIElement {
        app.buttons["settings.addRuleButton"]
    }

    var addRuleSheetRoot: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "settings.addRule.root").firstMatch
    }

    var addRuleConfirmButton: XCUIElement {
        app.buttons["settings.addRule.confirmButton"]
    }

    var addRuleQuickFillButton: XCUIElement {
        app.buttons["settings.addRule.fillTestHostButton"]
    }

    var ruleHostFields: XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "settings.rule.hostField")
    }

    var firstBrowserNameValue: String {
        guard browserNameFields.count > 0 else { return "" }
        return browserNameFields.element(boundBy: 0).value as? String ?? ""
    }

    func assertPickerVisible(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(pickerSettingsButton.waitForExistence(timeout: 5), "Picker UI should be visible.", file: file, line: line)
    }

    func assertBrowserSelectionRecorded(file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value != 'none'")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: lastOpenedBrowserText)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, "Picker should record selected browser in UI-test mode.", file: file, line: line)
    }

    func assertSettingsVisible(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(settingsAddBrowserButton.waitForExistence(timeout: 5), "Settings UI should remain visible.", file: file, line: line)
    }

    func openSettings() {
        if settingsAddBrowserButton.waitForExistence(timeout: 5) {
            return
        }

        if pickerSettingsButton.waitForExistence(timeout: 5) {
            pickerSettingsButton.click()
            XCTAssertTrue(settingsAddBrowserButton.waitForExistence(timeout: 5), "Settings did not open after tapping picker gear button.")
            return
        }

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settingsAddBrowserButton.waitForExistence(timeout: 5), "Settings UI did not appear.")
    }

    func openBrowsersSection() {
        clickSidebarItem(identifier: "settings.sidebar.browsers")
    }

    func openGeneralSection() {
        clickSidebarItem(identifier: "settings.sidebar.general")
    }

    func openRulesSection() {
        clickSidebarItem(identifier: "settings.sidebar.rules")
    }

    func openAddBrowserSheet() {
        let addButton = app.buttons["settings.addBrowserButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add browser button not found.")
        addButton.click()

        XCTAssertTrue(addSheetRoot.waitForExistence(timeout: 5), "Add browser sheet should open.")
    }

    func addFirstBrowserOption() {
        let firstOption = app.descendants(matching: .any).matching(identifier: "settings.addSheet.option").firstMatch
        XCTAssertTrue(firstOption.waitForExistence(timeout: 5), "No available browser option found.")
        firstOption.click()

        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: addSheetRoot)
        _ = XCTWaiter.wait(for: [expectation], timeout: 5)
    }

    func resetToFreshSetup() {
        let resetButton = app.buttons["settings.resetButton"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5), "Reset button not found in General section.")
        resetButton.click()

        let confirmButton = app.buttons["action-button-1"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Reset confirmation not shown.")
        confirmButton.click()
    }

    func openAddRuleSheet() {
        XCTAssertTrue(addRuleButton.waitForExistence(timeout: 5), "Add rule button not found.")
        addRuleButton.click()
        XCTAssertTrue(addRuleSheetRoot.waitForExistence(timeout: 5), "Add rule sheet should open.")
    }

    func addRule(hostPattern: String) {
        if addRuleQuickFillButton.waitForExistence(timeout: 1) {
            addRuleQuickFillButton.click()
        } else {
            let hostField = resolvedAddRuleHostField()
            XCTAssertTrue(hostField.waitForExistence(timeout: 5), "Host pattern field not found.")
            hostField.click()
            hostField.typeText(hostPattern)

            if !addRuleConfirmButton.isEnabled {
                app.typeKey("\t", modifierFlags: [])
                app.typeText(hostPattern)
            }
        }

        XCTAssertTrue(addRuleConfirmButton.waitForExistence(timeout: 5), "Add rule confirm button not found.")
        XCTAssertTrue(addRuleConfirmButton.isEnabled, "Add rule confirm button should be enabled.")
        addRuleConfirmButton.click()

        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: addRuleSheetRoot)
        _ = XCTWaiter.wait(for: [expectation], timeout: 5)
    }

    func assertRuleCreated(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(ruleHostFields.firstMatch.waitForExistence(timeout: 5), "Expected at least one routing rule row.", file: file, line: line)
    }

    private func clickSidebarItem(identifier: String) {
        let candidates: [XCUIElement] = [
            app.buttons[identifier],
            app.staticTexts[identifier],
            app.cells[identifier],
            app.otherElements[identifier],
        ]

        for candidate in candidates where candidate.waitForExistence(timeout: 1) {
            candidate.click()
            return
        }

        XCTFail("Sidebar item \(identifier) not found.")
    }

    private func resolvedAddRuleHostField() -> XCUIElement {
        let identifierMatch = app.descendants(matching: .any).matching(identifier: "settings.addRule.hostField").firstMatch
        if identifierMatch.waitForExistence(timeout: 1) {
            return identifierMatch
        }

        let textFields = addRuleSheetRoot.descendants(matching: .textField)
        let secondField = textFields.element(boundBy: 1)
        if secondField.waitForExistence(timeout: 1) {
            return secondField
        }

        return textFields.firstMatch
    }
}
