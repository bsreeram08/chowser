import AppKit
import XCTest

/// Automated screenshot generation for App Store submission.
/// Run this test to generate all required screenshots.
final class ChowserScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private let chowserBundleIdentifier = "in.sreerams.Chowser"
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        terminateRunningChowserApps()
        
        app = XCUIApplication()
        app.launchEnvironment["CHOWSER_DEFAULTS_SUITE"] = "in.sreerams.Chowser.Screenshots"
        app.launchArguments = [
            "-UITesting",
            "-UITesting_ClearData",
            "-UITesting_MockInstalledBrowsers",
            "-UITesting_DisableExternalOpen",
            "-UITesting_DefaultURL",
            "-UITesting_OpenSettings",
            "-Screenshot" // Custom flag to trigger demo data
        ]
        app.launch()
        
        // Give the app time to fully render
        Thread.sleep(forTimeInterval: 1.0)
    }
    
    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        terminateRunningChowserApps(timeout: 2)
        app = nil
    }
    
    // MARK: - Screenshot Tests
    
    func testScreenshot1_BrowserPicker() throws {
        // Set up: Open picker with a pending URL
        triggerOpenURLInChowser("https://github.com/apple/swift")
        
        // Wait for picker to be visible
        let pickerButton = app.buttons["picker.openSettingsButton"]
        XCTAssertTrue(pickerButton.waitForExistence(timeout: 5))
        
        // Give animation time to complete
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(named: "01-BrowserPicker")
    }
    
    func testScreenshot2_RoutingRules() throws {
        setupDemoRules()
        
        let ui = ChowserAppDriver(app: app)
        ui.openSettings()
        ui.openRulesSection()
        
        // Wait for rules to render
        Thread.sleep(forTimeInterval: 0.5)
        
        // Add a test URL to the rule tester
        let testField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'URL'")).firstMatch
        if testField.waitForExistence(timeout: 3) {
            testField.click()
            testField.typeText("github.com/apple/swift")
        }
        
        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(named: "02-RoutingRules")
    }
    
    func testScreenshot3_BrowserManagement() throws {
        let ui = ChowserAppDriver(app: app)
        ui.openSettings()
        ui.openBrowsersSection()
        
        // Ensure we have multiple browsers
        if ui.browserDeleteButtons.count < 3 {
            ui.openAddBrowserSheet()
            ui.addFirstBrowserOption()
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(named: "03-BrowserManagement")
    }
    
    func testScreenshot4_RuleTesterDetail() throws {
        setupDemoRules()
        
        let ui = ChowserAppDriver(app: app)
        ui.openSettings()
        ui.openRulesSection()
        
        // Focus on the rule tester
        let testField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'URL'")).firstMatch
        if testField.waitForExistence(timeout: 3) {
            testField.click()
            testField.typeText("github.com/swift-evolution")
        }
        
        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(named: "04-RuleTesterDetail")
    }
    
    func testScreenshot5_GeneralSettings() throws {
        let ui = ChowserAppDriver(app: app)
        ui.openSettings()
        ui.openGeneralSection()
        
        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(named: "05-GeneralSettings")
    }
    
    // MARK: - Helper Methods
    
    private func setupDemoRules() {
        let ui = ChowserAppDriver(app: app)
        ui.openSettings()
        
        // Ensure we have browsers
        if ui.browserDeleteButtons.count < 2 {
            ui.openAddBrowserSheet()
            ui.addFirstBrowserOption()
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        ui.openRulesSection()
        
        // Add multiple demo rules if needed
        let demoRules = [
            "github.com",
            "google.com",
            "apple.com",
            "stackoverflow.com"
        ]
        
        for (index, host) in demoRules.enumerated() {
            if ui.ruleHostFields.count >= demoRules.count {
                break
            }
            
            ui.openAddRuleSheet()
            
            let nameField = app.descendants(matching: .textField).matching(identifier: "settings.addRule.nameField").firstMatch
            if nameField.waitForExistence(timeout: 3) {
                nameField.click()
                nameField.typeText("Rule \(index + 1)")
            }
            
            let hostField = app.descendants(matching: .any).matching(identifier: "settings.addRule.hostField").firstMatch
            if hostField.waitForExistence(timeout: 3) {
                hostField.click()
                hostField.typeText(host)
            }
            
            app.typeKey(.return, modifierFlags: [])
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
    
    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        
        // Also save to Desktop for easy access
        if let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            let screenshotPath = desktopPath
                .appendingPathComponent("Chowser-Screenshots", isDirectory: true)
                .appendingPathComponent("\(name).png")
            
            try? FileManager.default.createDirectory(
                at: screenshotPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            if let data = screenshot.pngRepresentation {
                try? data.write(to: screenshotPath)
            }
        }
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
}

// Reuse the driver from ChowserUITests
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
    
    var addRuleButton: XCUIElement {
        app.buttons["settings.addRuleButton"]
    }
    
    var addRuleSheetRoot: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "settings.addRule.root").firstMatch
    }
    
    var ruleHostFields: XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "settings.rule.hostField")
    }
    
    func openSettings() {
        if settingsAddBrowserButton.waitForExistence(timeout: 5) {
            return
        }
        
        if pickerSettingsButton.waitForExistence(timeout: 5) {
            pickerSettingsButton.click()
            XCTAssertTrue(settingsAddBrowserButton.waitForExistence(timeout: 5))
            return
        }
        
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settingsAddBrowserButton.waitForExistence(timeout: 5))
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
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.click()
        XCTAssertTrue(addSheetRoot.waitForExistence(timeout: 5))
    }
    
    func addFirstBrowserOption() {
        let firstOption = app.descendants(matching: .any).matching(identifier: "settings.addSheet.option").firstMatch
        XCTAssertTrue(firstOption.waitForExistence(timeout: 5))
        firstOption.click()
        
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: addSheetRoot)
        _ = XCTWaiter.wait(for: [expectation], timeout: 5)
    }
    
    func openAddRuleSheet() {
        XCTAssertTrue(addRuleButton.waitForExistence(timeout: 5))
        addRuleButton.click()
        XCTAssertTrue(addRuleSheetRoot.waitForExistence(timeout: 5))
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
