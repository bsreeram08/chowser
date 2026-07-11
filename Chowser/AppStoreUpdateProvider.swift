#if APP_STORE
import AppKit
import Observation

@MainActor
@Observable
final class AppStoreUpdateProvider {
    static let shared = AppStoreUpdateProvider()
    static let appStoreURL = URL(string: "https://apps.apple.com/in/app/chowser/id6760034779")!

    func openAppStore() {
        guard !AppEnvironment.shouldDisableExternalURLOpen else { return }
        NSWorkspace.shared.open(Self.appStoreURL)
    }
}
#endif
