import Foundation

/// Launch/runtime flags used to make the app deterministic for UI testing
/// without impacting normal user behavior.
enum AppEnvironment {
    nonisolated private static let arguments = Set(ProcessInfo.processInfo.arguments)

    nonisolated static let uiTestDefaultsSuiteName = "in.sreerams.Chowser.UITests"

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

    static var shouldBypassOnboardingForRequestedUITestSurface: Bool {
        isUITesting && (shouldOpenSettingsOnLaunch || shouldOpenPickerOnLaunch)
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

    nonisolated static var defaultsSuiteName: String? {
        if let suite = ProcessInfo.processInfo.environment["CHOWSER_DEFAULTS_SUITE"], !suite.isEmpty {
            return suite
        }

        return isUITesting ? uiTestDefaultsSuiteName : nil
    }

    nonisolated static func makeDefaultStore() -> UserDefaults {
        guard let suiteName = defaultsSuiteName else {
            return .standard
        }

        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    static var defaultTestURL: URL? {
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
