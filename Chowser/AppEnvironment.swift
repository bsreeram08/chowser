import Foundation

/// Launch/runtime flags used to make the app deterministic for UI testing
/// without impacting normal user behavior.
enum AppEnvironment {
    private static let arguments = Set(ProcessInfo.processInfo.arguments)

    static let uiTestDefaultsSuiteName = "in.sreerams.Chowser.UITests"

    static var isUITesting: Bool {
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

    static var shouldUseMockInstalledBrowsers: Bool {
        arguments.contains("-UITesting_MockInstalledBrowsers")
    }

    static var shouldDisableExternalURLOpen: Bool {
        arguments.contains("-UITesting_DisableExternalOpen")
    }

    static var shouldDisableSystemIntegration: Bool {
        isUITesting || arguments.contains("-UITesting_DisableSystemIntegration")
    }

    static var defaultsSuiteName: String? {
        if let suite = ProcessInfo.processInfo.environment["CHOWSER_DEFAULTS_SUITE"], !suite.isEmpty {
            return suite
        }

        return isUITesting ? uiTestDefaultsSuiteName : nil
    }

    static var defaultTestURL: URL? {
        guard arguments.contains("-UITesting_DefaultURL") else { return nil }
        return URL(string: "https://example.com/ui-test")
    }
}
