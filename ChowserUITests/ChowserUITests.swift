import XCTest
import AppKit

final class ChowserUITests: XCTestCase {
    private var app: XCUIApplication!
    private var logsDirectory: URL!
    private var defaultsSuiteName: String!
    private let chowserBundleIdentifier = "in.sreerams.Chowser"

    override func setUpWithError() throws {
        continueAfterFailure = false

        terminateRunningChowserApps()

        logsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chowser-ui-tests-\(UUID().uuidString)", isDirectory: true)
        launchTestApp(arguments: [
            "-UITesting",
            "-UITesting_ClearData",
            "-UITesting_MockInstalledBrowsers",
            "-UITesting_DisableExternalOpen",
            "-UITesting_DefaultURL",
            "-UITesting_OpenSettings",
        ])
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }

        terminateRunningChowserApps(timeout: 2)
        if let logsDirectory {
            try? FileManager.default.removeItem(at: logsDirectory)
        }
        if let defaultsSuiteName {
            UserDefaults(suiteName: defaultsSuiteName)?.removePersistentDomain(forName: defaultsSuiteName)
        }
        logsDirectory = nil
        defaultsSuiteName = nil
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

    private func launchTestApp(
        arguments: [String],
        suiteLabel: String = "default",
        mouseLocation: CGPoint? = nil
    ) {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        terminateRunningChowserApps()
        if let defaultsSuiteName {
            UserDefaults(suiteName: defaultsSuiteName)?.removePersistentDomain(forName: defaultsSuiteName)
        }

        defaultsSuiteName = "in.sreerams.Chowser.UITests.\(suiteLabel).\(UUID().uuidString)"
        app = XCUIApplication()
        app.launchEnvironment["CHOWSER_LOGS_DIRECTORY"] = logsDirectory.path
        app.launchEnvironment["CHOWSER_DEFAULTS_SUITE"] = defaultsSuiteName
        app.launchArguments = arguments
        if let mouseLocation {
            CGWarpMouseCursorPosition(mouseLocation)
        }
        app.launch()
    }

    private func launchClassicPickerFixture(suiteLabel: String) {
        launchTestApp(arguments: [
            "-UITesting",
            "-UITesting_ClearData",
            "-UITesting_IconsPickerFixture",
            "-UITesting_DisableExternalOpen",
            "-UITesting_DefaultURL",
            "-UITesting_OpenPicker",
            "-ApplePersistenceIgnoreState",
            "YES",
        ], suiteLabel: suiteLabel)
    }

    private func waitForOpenInvocationCount(_ expectedCount: Int, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let defaults = UserDefaults(suiteName: defaultsSuiteName)
            if defaults?.integer(forKey: "uiTestOpenInvocationCount") == expectedCount {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return false
    }

    private func performSystemDrag(from start: CGPoint, to end: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        for step in 1...12 {
            let progress = CGFloat(step) / 12
            let point = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left)?
                .post(tap: .cghidEventTap)
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }

    func testAppearancePreviewStaysVisibleWhileEditingLowerSettings() throws {
        let appearanceButton = app.buttons["settings.sidebar.appearance"]
        XCTAssertTrue(appearanceButton.waitForExistence(timeout: 5))
        appearanceButton.click()

        let previewTitle = app.staticTexts["Preview"]
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(previewTitle.isHittable)

        let accentLabel = app.staticTexts["Accent Color"]
        let scrollView = app.scrollViews["settings.appearance.controls"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        for _ in 0..<4 where !accentLabel.isHittable { scrollView.swipeUp() }
        XCTAssertTrue(accentLabel.isHittable, "Lower appearance controls should be reachable.")
        XCTAssertTrue(previewTitle.isHittable, "The live preview should remain visible while editing lower appearance controls.")
    }

    func testAppearancePreviewShowsLinkMetadataInClassicPicker() throws {
        let appearanceButton = app.buttons["settings.sidebar.appearance"]
        XCTAssertTrue(appearanceButton.waitForExistence(timeout: 5))
        appearanceButton.click()

        let linkPreview = app.staticTexts[
            "Page titles and descriptions appear here before you choose a browser."
        ]
        XCTAssertTrue(
            linkPreview.waitForExistence(timeout: 5),
            "The Appearance sample should demonstrate the enabled Link Preview in Icons mode."
        )
    }

    func testAppearanceUsesPinnedTopPreviewAtNarrowWidth() throws {
        launchTestApp(arguments: [
            "-UITesting",
            "-UITesting_ClearData",
            "-UITesting_MockInstalledBrowsers",
            "-UITesting_DisableExternalOpen",
            "-UITesting_DefaultURL",
            "-UITesting_OpenSettings",
            "-UITesting_NarrowSettings",
        ], suiteLabel: "narrow")

        let appearanceButton = app.buttons["settings.sidebar.appearance"]
        XCTAssertTrue(appearanceButton.waitForExistence(timeout: 5))
        appearanceButton.click()

        let preview = app.descendants(matching: .any).matching(identifier: "settings.appearance.preview").firstMatch
        let controls = app.scrollViews["settings.appearance.controls"]
        let layoutPicker = app.descendants(matching: .any).matching(identifier: "settings.appearance.layoutPicker").firstMatch

        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(controls.waitForExistence(timeout: 5))
        XCTAssertTrue(layoutPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.isHittable)
        XCTAssertTrue(layoutPicker.isHittable)
        XCTAssertLessThanOrEqual(preview.frame.maxY, controls.frame.minY + 2, "The compact preview should be pinned above the independently scrolling controls.")

        let accentLabel = app.staticTexts["Accent Color"]
        for _ in 0..<4 where !accentLabel.isHittable { controls.swipeUp() }
        XCTAssertTrue(accentLabel.isHittable, "Lower appearance controls should remain reachable in the narrow layout.")
        XCTAssertTrue(preview.isHittable, "The compact preview should remain visible while narrow controls scroll.")
    }

    func testFallbackBrowserPickerHasExplicitEmptySelection() throws {
        let behaviorButton = app.buttons["settings.sidebar.behavior"]
        XCTAssertTrue(behaviorButton.waitForExistence(timeout: 5))
        behaviorButton.click()

        let fallbackModePicker = app.descendants(matching: .any)
            .matching(identifier: "settings.behavior.fallbackModePicker")
            .firstMatch
        XCTAssertTrue(fallbackModePicker.waitForExistence(timeout: 5))
        fallbackModePicker.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).click()

        let browserPicker = app.descendants(matching: .any)
            .matching(identifier: "settings.behavior.fallbackBrowserPicker")
            .firstMatch
        XCTAssertTrue(browserPicker.waitForExistence(timeout: 5))
        XCTAssertEqual(browserPicker.value as? String, "Choose Browser")
    }

    func testRadialPickerUsesCursorAsCenterAndDirectionSelectsBrowser() throws {
        let screenFrame = NSScreen.main!.frame
        launchTestApp(arguments: [
            "-UITesting",
            "-UITesting_ClearData",
            "-UITesting_RadialPickerFixture",
            "-UITesting_DisableExternalOpen",
            "-UITesting_DefaultURL",
            "-UITesting_OpenPicker",
            "-ApplePersistenceIgnoreState",
            "YES",
        ], suiteLabel: "radial", mouseLocation: CGPoint(x: screenFrame.midX, y: screenFrame.midY))

        let radial = app.descendants(matching: .any).matching(identifier: "picker.radial").firstMatch
        XCTAssertTrue(radial.waitForExistence(timeout: 5), "Radial picker should be visible.")
        // Compare against the launch anchor, not the live pointer: XCTest can move the
        // pointer again while establishing its accessibility session after the picker is placed.
        let launchAnchor = CGPoint(x: screenFrame.midX, y: screenFrame.maxY - screenFrame.midY)
        XCTAssertEqual(radial.frame.midX, launchAnchor.x, accuracy: 3, "Cursor must be the radial picker's horizontal center.")
        XCTAssertEqual(radial.frame.midY, launchAnchor.y, accuracy: 3, "Cursor must be the radial picker's vertical center.")
        XCTAssertEqual(radial.frame.width, radial.frame.height, accuracy: 1, "The radial picker canvas must stay square.")
        XCTAssertLessThan(radial.frame.width, 300, "Two destinations should use the compact radial wheel, not the maximum canvas.")

        let safariButton = app.buttons["Open in Safari"]
        let chromeButton = app.buttons["Open in Chrome - Work"]
        XCTAssertTrue(safariButton.waitForExistence(timeout: 2))
        XCTAssertTrue(chromeButton.waitForExistence(timeout: 2))
        XCTAssertEqual(safariButton.value as? String, "not selected", "The cursor dead zone must start with no destination selected.")
        XCTAssertEqual(chromeButton.value as? String, "not selected", "The cursor dead zone must start with no destination selected.")

        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(radial.exists, "Return must not activate an invisible destination while the cursor is in the dead zone.")

        // With two destinations browser 1 is above center and browser 2 is below center.
        // Moving down from the original cursor anchor must select Chrome, not merely hover a button.
        radial.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).hover()
        let directionSelected = NSPredicate(format: "value == 'selected'")
        let selectionResult = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: directionSelected, object: chromeButton)],
            timeout: 2
        )
        XCTAssertEqual(selectionResult, .completed, "Pointer direction should visibly select Chrome before confirmation.")
        chromeButton.click()

        let pickerDismissed = NSPredicate(format: "exists == false")
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: pickerDismissed, object: radial)], timeout: 3)
        XCTAssertEqual(result, .completed, "Activating the direction-selected Chrome destination should dismiss the radial picker.")
        XCTAssertTrue(waitForOpenInvocationCount(1), "Radial pointer activation should launch exactly once.")
    }

    func testClassicPickerShowsPathAndUsesExplicitURLEditAction() throws {
        let layouts = [
            ("icons-destination", "-UITesting_IconsPickerFixture"),
            ("list-destination", "-UITesting_ListPickerFixture"),
        ]

        for (label, fixture) in layouts {
            launchTestApp(arguments: [
                "-UITesting",
                "-UITesting_ClearData",
                fixture,
                "-UITesting_DisableExternalOpen",
                "-UITesting_SensitiveURL",
                "-UITesting_OpenPicker",
                "-ApplePersistenceIgnoreState",
                "YES",
            ], suiteLabel: label)

            let path = app.staticTexts["picker.destinationPath"]
            XCTAssertTrue(path.waitForExistence(timeout: 5), "Expected destination path in \(label).")
            XCTAssertEqual(path.value as? String, "/account/reset password")
            XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "secret")).count, 0)

            let editButton = app.buttons["picker.urlEditTrigger"]
            XCTAssertTrue(editButton.waitForExistence(timeout: 2))
            editButton.click()

            let editField = app.textFields["picker.urlEditField"]
            XCTAssertTrue(editField.waitForExistence(timeout: 2))
            XCTAssertEqual(
                editField.value as? String,
                "https://example.com/account/reset%20password?token=secret#confirm"
            )
        }
    }

    func testPrivateModeIsVisibleAndAnnouncedInEveryPickerLayout() throws {
        let layouts = [
            ("icons", "-UITesting_IconsPickerFixture", "picker.urlDisplay"),
            ("list", "-UITesting_ListPickerFixture", "picker.urlDisplay"),
            ("radial-private", "-UITesting_RadialPickerFixture", "picker.radial"),
            ("minimal", "-UITesting_MinimalPickerFixture", "picker.minimal"),
        ]

        for (label, fixture, rootIdentifier) in layouts {
            launchTestApp(arguments: [
                "-UITesting",
                "-UITesting_ClearData",
                fixture,
                "-UITesting_PrivatePicker",
                "-UITesting_DisableExternalOpen",
                "-UITesting_DefaultURL",
                "-UITesting_OpenPicker",
                "-ApplePersistenceIgnoreState",
                "YES",
            ], suiteLabel: label)

            let root = app.descendants(matching: .any).matching(identifier: rootIdentifier).firstMatch
            XCTAssertTrue(root.waitForExistence(timeout: 5), "Expected \(label) picker.")

            let indicator = app.descendants(matching: .any).matching(identifier: "picker.privateModeIndicator").firstMatch
            XCTAssertTrue(indicator.waitForExistence(timeout: 2), "Expected visible private mode in \(label).")
            XCTAssertTrue(app.buttons["Open in Safari privately"].waitForExistence(timeout: 2), "Expected private launch announcement in \(label).")
        }

        for (label, fixture) in [
            ("radial-overflow-private", "-UITesting_RadialPickerFixture"),
            ("minimal-overflow-private", "-UITesting_MinimalPickerFixture"),
        ] {
            launchTestApp(arguments: [
                "-UITesting",
                "-UITesting_ClearData",
                fixture,
                "-UITesting_OverflowPickerFixture",
                "-UITesting_PrivatePicker",
                "-UITesting_DisableExternalOpen",
                "-UITesting_DefaultURL",
                "-UITesting_OpenPicker",
                "-ApplePersistenceIgnoreState",
                "YES",
            ], suiteLabel: label)

            let moreButton = app.buttons["More browsers and profiles"]
            XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Expected More in \(label).")
            moreButton.click()

            let overflow = app.descendants(matching: .any).matching(identifier: "picker.moreList").firstMatch
            XCTAssertTrue(overflow.waitForExistence(timeout: 2), "Expected overflow in \(label).")
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "picker.privateModeIndicator").firstMatch.waitForExistence(timeout: 2))
            XCTAssertTrue(app.buttons["Open in Zen privately"].waitForExistence(timeout: 2))
        }
    }

    func testQuickPickersSupportImmediateKeyboardSelectionAndLaunch() throws {
        for (label, fixture, arrowCount) in [
            ("radial-keyboard", "-UITesting_RadialPickerFixture", 2),
            ("minimal-keyboard", "-UITesting_MinimalPickerFixture", 1),
        ] {
            launchTestApp(arguments: [
                "-UITesting",
                "-UITesting_ClearData",
                fixture,
                "-UITesting_DisableExternalOpen",
                "-UITesting_DefaultURL",
                "-UITesting_OpenPicker",
                "-ApplePersistenceIgnoreState",
                "YES",
            ], suiteLabel: label)

            let chromeButton = app.buttons["Open in Chrome - Work"]
            XCTAssertTrue(chromeButton.waitForExistence(timeout: 5))
            for _ in 0..<arrowCount { app.typeKey(.rightArrow, modifierFlags: []) }
            XCTAssertEqual(chromeButton.value as? String, "selected", "Arrow selection should update immediately in \(label).")

            let picker = app.descendants(matching: .any)
                .matching(identifier: fixture.contains("Radial") ? "picker.radial" : "picker.minimal")
                .firstMatch
            app.typeKey(.return, modifierFlags: [])

            XCTAssertEqual(
                XCTWaiter.wait(
                    for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: picker)],
                    timeout: 5
                ),
                .completed,
                "Return should launch the selected browser and dismiss \(label)."
            )
            XCTAssertTrue(waitForOpenInvocationCount(1), "Return should launch exactly once in \(label).")
        }
    }

    func testMinimalPickerHoverTracksPointerAndLaunchesOnce() throws {
        launchTestApp(arguments: [
            "-UITesting",
            "-UITesting_ClearData",
            "-UITesting_MinimalPickerFixture",
            "-UITesting_DisableExternalOpen",
            "-UITesting_DefaultURL",
            "-UITesting_OpenPicker",
            "-ApplePersistenceIgnoreState",
            "YES",
        ], suiteLabel: "minimal-hover")

        let picker = app.descendants(matching: .any).matching(identifier: "picker.minimal").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), app.debugDescription)
        let chromeButton = app.buttons["Open in Chrome - Work"]
        XCTAssertTrue(chromeButton.waitForExistence(timeout: 5), app.debugDescription)
        chromeButton.hover()
        XCTAssertEqual(chromeButton.value as? String, "selected")
        chromeButton.click()
        XCTAssertTrue(waitForOpenInvocationCount(1), "Minimal pointer activation should launch exactly once.")
    }

    func testQuickPickerDragSelectionLaunchesOnce() throws {
        for (label, fixture, rootIdentifier) in [
            ("radial-drag", "-UITesting_RadialPickerFixture", "picker.radial"),
            ("minimal-drag", "-UITesting_MinimalPickerFixture", "picker.minimal"),
        ] {
            launchTestApp(arguments: [
                "-UITesting",
                "-UITesting_ClearData",
                fixture,
                "-UITesting_DisableExternalOpen",
                "-UITesting_DefaultURL",
                "-UITesting_OpenPicker",
                "-ApplePersistenceIgnoreState",
                "YES",
            ], suiteLabel: label)

            let picker = app.descendants(matching: .any).matching(identifier: rootIdentifier).firstMatch
            let safariButton = app.buttons["Open in Safari"]
            let chromeButton = app.buttons["Open in Chrome - Work"]
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            XCTAssertTrue(safariButton.waitForExistence(timeout: 2))
            XCTAssertTrue(chromeButton.waitForExistence(timeout: 2))

            let start = rootIdentifier == "picker.radial"
                ? CGPoint(x: picker.frame.midX, y: picker.frame.midY)
                : CGPoint(x: safariButton.frame.midX, y: safariButton.frame.midY)
            let end = CGPoint(x: chromeButton.frame.midX, y: chromeButton.frame.midY)
            performSystemDrag(from: start, to: end)

            XCTAssertTrue(waitForOpenInvocationCount(1), "Drag activation should launch exactly once in \(label).")
            XCTAssertFalse(picker.exists, "Drag activation should dismiss \(label).")
        }
    }

    func testEmptyPickerOffersDirectSettingsRecovery() throws {
        launchTestApp(arguments: [
            "-UITesting",
            "-UITesting_ClearData",
            "-UITesting_EmptyPickerFixture",
            "-UITesting_DisableExternalOpen",
            "-UITesting_DefaultURL",
            "-UITesting_OpenPicker",
            "-ApplePersistenceIgnoreState",
            "YES",
        ], suiteLabel: "empty-picker")

        let settingsButton = app.buttons["picker.openSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), app.debugDescription)
        settingsButton.click()

        XCTAssertTrue(app.buttons["settings.addBrowserButton"].waitForExistence(timeout: 5))
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
        launchClassicPickerFixture(suiteLabel: "picker-selection")
        let ui = ChowserAppDriver(app: app)
        ui.assertPickerVisible()
        XCTAssertTrue(ui.lastOpenedBrowserText.waitForExistence(timeout: 3), "Expected picker selection marker before choosing a browser.")

        XCTAssertTrue(ui.firstPickerBrowserRow.waitForExistence(timeout: 3), "Expected at least one picker browser row.")
        ui.firstPickerBrowserRow.click()

        ui.assertBrowserSelectionRecorded()
    }

    func testPickerNumberShortcutSelectsBrowser() throws {
        launchClassicPickerFixture(suiteLabel: "picker-number")
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

    func testOpenLinkShortcutSelectionWorks() throws {
        let ui = ChowserAppDriver(app: app)
        ui.openSettings()
        ui.assertSettingsVisible()

        let testURL = "https://example.com/chowser-shortcut-\(UUID().uuidString)"
        triggerOpenURLInChowser(testURL)

        ui.assertPickerVisible()
        XCTAssertTrue(ui.lastOpenedBrowserText.waitForExistence(timeout: 3), "Expected picker selection marker before using keyboard shortcut after URL open.")

        app.typeKey("1", modifierFlags: [])

        ui.assertBrowserSelectionRecorded()
    }

    func testSendToIPhoneActionMenu() throws {
        launchClassicPickerFixture(suiteLabel: "picker-phone")
        let ui = ChowserAppDriver(app: app)
        ui.assertPickerVisible()

        XCTAssertTrue(ui.sendToIPhoneButton.waitForExistence(timeout: 5), "Send to iPhone button should exist for a transferable URL.")
        ui.sendToIPhoneButton.click()

        XCTAssertTrue(ui.iphoneAirDropButton.waitForExistence(timeout: 5), "AirDrop action should appear in the Send to iPhone menu.")
        XCTAssertTrue(ui.iphoneShowQRCodeButton.waitForExistence(timeout: 5), "Show QR Code action should appear in the Send to iPhone menu.")
        XCTAssertTrue(ui.iphoneCopyURLButton.waitForExistence(timeout: 5), "Copy URL action should appear in the Send to iPhone menu.")
        XCTAssertTrue(ui.iphoneHandoffStatusText.waitForExistence(timeout: 5), "Handoff explanation text should appear in the Send to iPhone menu.")

        ui.iphoneShowQRCodeButton.click()

        XCTAssertTrue(ui.iphoneQRSheet.waitForExistence(timeout: 5), "QR sheet should be visible after choosing Show QR Code.")
        XCTAssertTrue(ui.iphoneQRImage.waitForExistence(timeout: 5), "QR image should be visible in the QR sheet.")
        XCTAssertTrue(ui.iphoneQRURLText.waitForExistence(timeout: 5), "URL text should be visible in the QR sheet.")
        XCTAssertTrue(ui.iphoneQRCloseButton.waitForExistence(timeout: 5), "Close button should be visible in the QR sheet.")

        ui.iphoneQRCloseButton.click()
    }

    // MARK: - Profile-Aware Tests

    func testAddBrowserSheetShowsProfileEntries() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.assertSettingsVisible()
        ui.openAddBrowserSheet()

        // The add-browser sheet should show browser options (mock or real).
        // Each option has the identifier "settings.addSheet.option".
        let options = app.descendants(matching: .any).matching(identifier: "settings.addSheet.option")
        XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 5), "Expected at least one browser option in add sheet.")
        XCTAssertGreaterThanOrEqual(options.count, 1, "Should have at least one browser option displayed.")
    }

    func testAddBrowserWithProfileAppearsInList() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.assertSettingsVisible()
        ui.openAddBrowserSheet()

        // Count browsers before adding
        let beforeCount = ui.browserDeleteButtons.count

        // Add the first available browser option
        ui.addFirstBrowserOption()

        // Browser list should grow by 1
        let afterCount = ui.browserDeleteButtons.count
        XCTAssertEqual(afterCount, beforeCount + 1, "Adding a browser should increase the browser list count.")
    }

    func testRulesMenuButtonExists() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.assertSettingsVisible()
        ui.openRulesSection()

        // The rules section should have a menu button for export/import
        let menuButton = app.descendants(matching: .any).matching(identifier: "settings.rulesMenuButton").firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Rules menu button should exist.")
    }

    func testRulesMenuShowsExportImportOptions() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.assertSettingsVisible()

        // Need at least one rule first
        ui.openRulesSection()
        ui.openAddRuleSheet()
        ui.addRule(hostPattern: "example.com")
        ui.assertRuleCreated()

        // Click the menu button to open the menu
        let menuButton = app.descendants(matching: .any).matching(identifier: "settings.rulesMenuButton").firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Rules menu button should exist.")
        menuButton.click()

        // Check that Export and Import items appear
        let exportItem = app.menuItems["Export Rules…"]
        let importItem = app.menuItems["Import Rules…"]
        XCTAssertTrue(exportItem.waitForExistence(timeout: 3), "Export Rules menu item should appear.")
        XCTAssertTrue(importItem.waitForExistence(timeout: 3), "Import Rules menu item should appear.")

        // Dismiss the menu by pressing Escape
        app.typeKey(.escape, modifierFlags: [])
    }

    func testAppModeRoundTripKeepsBothModesReachableAndRecordsDiagnostics() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.openGeneralSection()

        let appMode = app.buttons["settings.appMode.app"]
        let menuBarMode = app.buttons["settings.appMode.menuBar"]
        XCTAssertTrue(appMode.waitForExistence(timeout: 5))
        XCTAssertTrue(menuBarMode.waitForExistence(timeout: 5))

        menuBarMode.click()
        XCTAssertEqual(menuBarMode.value as? String, "selected")

        appMode.click()
        XCTAssertEqual(appMode.value as? String, "selected")

        menuBarMode.click()
        XCTAssertEqual(menuBarMode.value as? String, "selected")

        appMode.click()
        XCTAssertEqual(appMode.value as? String, "selected")

        let diagnosticsButton = app.buttons["settings.diagnosticsButton"]
        XCTAssertTrue(diagnosticsButton.waitForExistence(timeout: 5))
        diagnosticsButton.click()

        let events = app.descendants(matching: .any).matching(identifier: "diagnosticsRecentEvents").firstMatch
        XCTAssertTrue(events.waitForExistence(timeout: 5))
        let eventText = events.value as? String ?? ""
        XCTAssertTrue(eventText.contains("status-item-created"), "Diagnostics should record creation of the menu-bar item.")
        XCTAssertTrue(eventText.contains("status-item-removed"), "Diagnostics should record removal of the menu-bar item.")
        XCTAssertTrue(eventText.contains("activation-policy-transition-did-complete"), "Diagnostics should record completed transitions.")
    }

    func testAddRuleWithBrowserPickerSelection() throws {
        let ui = ChowserAppDriver(app: app)

        ui.openSettings()
        ui.assertSettingsVisible()

        // Ensure multiple browsers are configured
        if ui.browserDeleteButtons.count < 2 {
            ui.openAddBrowserSheet()
            ui.addFirstBrowserOption()
        }

        // Switch to rules and add a rule
        ui.openRulesSection()
        ui.openAddRuleSheet()

        // Verify the browser picker is present in the add-rule sheet
        let browserPicker = app.descendants(matching: .any).matching(identifier: "settings.addRule.browserPicker").firstMatch
        XCTAssertTrue(browserPicker.waitForExistence(timeout: 5), "Browser picker should be present in add-rule sheet.")

        // Fill the rule and submit
        ui.addRule(hostPattern: "test.example.com")
        ui.assertRuleCreated()

        // Verify the rule's browser picker in the rules list
        let ruleBrowserPicker = app.descendants(matching: .any).matching(identifier: "settings.rule.browserPicker").firstMatch
        XCTAssertTrue(ruleBrowserPicker.waitForExistence(timeout: 5), "Rule should have a browser picker.")
    }

    private func triggerOpenURLInChowser(_ urlString: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let appURL = NSRunningApplication.runningApplications(withBundleIdentifier: chowserBundleIdentifier).first?.bundleURL else {
            XCTFail("Could not locate running Chowser app to open URL.", file: file, line: line)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appURL.path, urlString]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            XCTFail("Failed to invoke open command for URL test: \(error.localizedDescription)", file: file, line: line)
            return
        }

        XCTAssertEqual(process.terminationStatus, 0, "open command should succeed when sending URL to Chowser.", file: file, line: line)
    }
}

private struct ChowserAppDriver {
    let app: XCUIApplication

    var pickerSettingsButton: XCUIElement { app.buttons["picker.openSettingsButton"] }
    var pickerRoot: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "picker.urlDisplay").firstMatch
    }
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

    var sendToIPhoneButton: XCUIElement { app.buttons["picker.sendToIPhoneButton"] }
    var iphoneAirDropButton: XCUIElement { app.buttons["iphoneAction.airDropButton"] }
    var iphoneShowQRCodeButton: XCUIElement { app.buttons["iphoneAction.showQRCodeButton"] }
    var iphoneCopyURLButton: XCUIElement { app.buttons["iphoneAction.copyURLButton"] }
    var iphoneHandoffStatusText: XCUIElement { app.staticTexts["iphoneAction.handoffStatusText"] }
    var iphoneQRCloseButton: XCUIElement { app.buttons["iphoneQR.closeButton"] }

    var iphoneQRSheet: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "iphoneQR.sheet").firstMatch
    }

    var iphoneQRImage: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "iphoneQR.image").firstMatch
    }

    var iphoneQRURLText: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "iphoneQR.urlText").firstMatch
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
        XCTAssertTrue(pickerRoot.waitForExistence(timeout: 5), "Picker UI should be visible.", file: file, line: line)
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
        // Fill the rule name field
        let nameField = app.descendants(matching: .textField).matching(identifier: "settings.addRule.nameField").firstMatch
        if nameField.waitForExistence(timeout: 3) {
            nameField.click()
            nameField.typeText("TestRule")
        }

        // Fill the host pattern field
        let hostField = resolvedAddRuleHostField()
        XCTAssertTrue(hostField.waitForExistence(timeout: 5), "Host pattern field not found.")
        hostField.click()
        hostField.typeText(hostPattern)

        // The "Add Rule" button has .keyboardShortcut(.defaultAction),
        // so pressing Return triggers it. XCUI can't reliably read isEnabled
        // on .defaultAction buttons, so we use the keyboard shortcut instead.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        app.typeKey(.return, modifierFlags: [])

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
