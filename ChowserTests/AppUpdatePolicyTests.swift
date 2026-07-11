import Testing
import Foundation
@testable import Chowser

struct AppUpdatePolicyTests {
    @Test("Stable update policy does not allow prerelease channels")
    func stablePolicy() {
        let policy = AppUpdatePolicy(includesBetaReleases: false)

        #expect(policy.allowedChannels.isEmpty)
    }

    @Test("Beta opt-in allows only the beta channel")
    func betaPolicy() {
        let policy = AppUpdatePolicy(includesBetaReleases: true)

        #expect(policy.allowedChannels == ["beta"])
    }

    @Test("Beta preference persists in the provided defaults store")
    @MainActor
    func betaPreferencePersists() {
        let suiteName = "in.sreerams.Chowser.UpdateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let controller = AppUpdateController(defaults: defaults)
        controller.includesBetaReleases = true

        #expect(defaults.bool(forKey: AppUpdateController.includeBetaDefaultsKey))
        #expect(AppUpdateController(defaults: defaults).includesBetaReleases)
    }

    @Test("Updater fallbacks default to automatic checks without automatic downloads")
    @MainActor
    func updaterDefaults() {
        let controller = AppUpdateController()

        #expect(controller.automaticallyChecksForUpdates)
        #expect(!controller.automaticallyDownloadsUpdates)
    }
}
