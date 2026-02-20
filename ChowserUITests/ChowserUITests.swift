import XCTest
import AppKit

final class ChowserUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        for runningApp in NSRunningApplication.runningApplications(withBundleIdentifier: "in.sreerams.Chowser") {
            runningApp.forceTerminate()
        }

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
        app = nil
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
        if settingsAddBrowserButton.waitForExistence(timeout: 2) {
            return
        }

        XCTAssertTrue(pickerSettingsButton.waitForExistence(timeout: 5), "Settings button not found in picker.")
        pickerSettingsButton.click()
    }

    func openBrowsersSection() {
        clickSidebarItem(identifier: "settings.sidebar.browsers")
    }

    func openGeneralSection() {
        clickSidebarItem(identifier: "settings.sidebar.general")
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
}
