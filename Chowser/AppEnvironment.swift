import Foundation

/// Launch/runtime flags used to make the app deterministic for UI testing
/// without impacting normal user behavior.
enum AppEnvironment {
    nonisolated private static let arguments = Set(ProcessInfo.processInfo.arguments)

    nonisolated static let uiTestDefaultsSuiteName = "in.sreerams.Chowser.UITests"
    nonisolated static let uiTestOpenInvocationCountKey = "uiTestOpenInvocationCount"

    nonisolated static var isUITesting: Bool {
        arguments.contains("-UITesting")
    }

    static var shouldClearDataOnLaunch: Bool {
        arguments.contains("-UITesting_ClearData") || arguments.contains("-ResetToFreshSetup")
    }

    static var shouldOpenSettingsOnLaunch: Bool {
        arguments.contains("-UITesting_OpenSettings")
    }

    static var shouldOpenPickerOnLaunch: Bool {
        arguments.contains("-UITesting_OpenPicker")
    }

    static var shouldUseNarrowSettingsWindow: Bool {
        isUITesting && arguments.contains("-UITesting_NarrowSettings")
    }

    static var shouldBypassOnboardingForRequestedUITestSurface: Bool {
        isUITesting && (shouldOpenSettingsOnLaunch || shouldOpenPickerOnLaunch)
    }

    static var shouldUseMockInstalledBrowsers: Bool {
        arguments.contains("-UITesting_MockInstalledBrowsers")
    }

    struct PickerFixture {
        let mode: PickerLayoutMode
        let browsers: [BrowserConfig]
    }

    static var pickerFixture: PickerFixture? {
        guard isUITesting else { return nil }
        if arguments.contains("-UITesting_EmptyPickerFixture") {
            return PickerFixture(mode: .icons, browsers: [])
        }

        let mode: PickerLayoutMode
        if arguments.contains("-UITesting_RadialPickerFixture") { mode = .radial }
        else if arguments.contains("-UITesting_MinimalPickerFixture") { mode = .minimal }
        else if arguments.contains("-UITesting_ListPickerFixture") { mode = .list }
        else if arguments.contains("-UITesting_IconsPickerFixture") { mode = .icons }
        else { return nil }

        var browsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome - Work", bundleId: "com.google.Chrome", shortcutKey: "2", profile: "Work"),
        ]
        if arguments.contains("-UITesting_OverflowPickerFixture") {
            browsers += [
                BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3"),
                BrowserConfig(name: "Edge", bundleId: "com.microsoft.edgemac", shortcutKey: "4"),
                BrowserConfig(name: "Arc", bundleId: "company.thebrowser.Browser", shortcutKey: "5"),
                BrowserConfig(name: "Brave", bundleId: "com.brave.Browser", shortcutKey: "6"),
                BrowserConfig(name: "Orion", bundleId: "com.kagi.kagimacOS", shortcutKey: "7"),
                BrowserConfig(name: "Vivaldi", bundleId: "com.vivaldi.Vivaldi", shortcutKey: "8"),
                BrowserConfig(name: "Zen", bundleId: "app.zen-browser.zen", shortcutKey: "9"),
                BrowserConfig(name: "Firefox - Personal", bundleId: "org.mozilla.firefox", shortcutKey: "9", profile: "Personal"),
            ]
        }
        return PickerFixture(mode: mode, browsers: browsers)
    }

    static var shouldRequestPrivatePicker: Bool {
        isUITesting && arguments.contains("-UITesting_PrivatePicker")
    }

    static var shouldDisableExternalURLOpen: Bool {
        arguments.contains("-UITesting_DisableExternalOpen")
    }

    static var shouldDisableSystemIntegration: Bool {
        isUITesting || arguments.contains("-UITesting_DisableSystemIntegration")
    }

    nonisolated static var defaultsSuiteName: String? {
        if let suite = ProcessInfo.processInfo.environment["CHOWSER_DEFAULTS_SUITE"], !suite.isEmpty {
            return suite
        }

        return isUITesting ? uiTestDefaultsSuiteName : nil
    }

    nonisolated static var automatedTestLogsDirectory: URL? {
        let environment = ProcessInfo.processInfo.environment
        if isUITesting,
           let path = environment["CHOWSER_LOGS_DIRECTORY"],
           !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        if environment["XCTestConfigurationFilePath"] != nil {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("chowser-unit-tests-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        }
        return nil
    }

    nonisolated static func makeDefaultStore() -> UserDefaults {
        guard let suiteName = defaultsSuiteName else {
            return .standard
        }

        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    static var defaultTestURL: URL? {
        if arguments.contains("-UITesting_SensitiveURL") {
            return URL(string: "https://example.com/account/reset%20password?token=secret#confirm")
        }
        guard arguments.contains("-UITesting_DefaultURL") else { return nil }
        return URL(string: "https://example.com/ui-test")
    }

    /// Pins MCPServer's auth token to a known value under UI testing/automation,
    /// instead of a fresh UUID every launch — otherwise there's no sanctioned way
    /// for test automation to discover the token (it's UI-only, no accessibility
    /// identifier, never logged) and the MCP API can't be exercised end-to-end.
    static var fixedMCPAuthToken: String? {
        guard isUITesting else { return nil }
        return "ui-testing-fixed-mcp-token"
    }
}
