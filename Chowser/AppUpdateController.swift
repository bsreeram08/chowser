import Foundation
import Observation

#if DIRECT_DISTRIBUTION
import Sparkle

struct AppUpdatePolicy: Equatable, Sendable {
    static let betaChannel = "beta"

    var includesBetaReleases: Bool

    var allowedChannels: Set<String> {
        includesBetaReleases ? [Self.betaChannel] : []
    }
}

@MainActor
@Observable
final class AppUpdateController: NSObject, AppUpdateProviding {
    static let shared = AppUpdateController()

    static let includeBetaDefaultsKey = "updates.includeBetaReleases"
    private let defaults: UserDefaults
    private let bundle: Bundle
    private var hasStarted = false

    private(set) var canCheckForUpdates = false

    var includesBetaReleases: Bool {
        didSet {
            guard includesBetaReleases != oldValue else { return }
            defaults.set(includesBetaReleases, forKey: Self.includeBetaDefaultsKey)
            resetUpdateCycleAfterChannelChange()
        }
    }

    @ObservationIgnored
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    @ObservationIgnored
    private var canCheckObservation: NSKeyValueObservation?

    init(
        defaults: UserDefaults = AppEnvironment.makeDefaultStore(),
        bundle: Bundle = .main
    ) {
        self.defaults = defaults
        self.bundle = bundle
        includesBetaReleases = defaults.bool(forKey: Self.includeBetaDefaultsKey)
        super.init()
    }

    var isConfigured: Bool {
        guard let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
            return false
        }

        return !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !feedURL.contains("$(")
            && !publicKey.contains("$(")
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            isConfigured ? updaterController.updater.automaticallyChecksForUpdates : true
        }
        set {
            guard isConfigured else { return }
            updaterController.updater.automaticallyChecksForUpdates = newValue
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get {
            isConfigured ? updaterController.updater.automaticallyDownloadsUpdates : false
        }
        set {
            guard isConfigured else { return }
            updaterController.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    func start() {
        guard !hasStarted, isConfigured, !AppEnvironment.isUITesting else { return }
        updaterController.startUpdater()
        hasStarted = true
        observeCanCheckForUpdates()
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        updaterController.checkForUpdates(nil)
    }

    private func resetUpdateCycleAfterChannelChange() {
        guard hasStarted else { return }
        updaterController.updater.resetUpdateCycleAfterShortDelay()
    }

    private func observeCanCheckForUpdates() {
        let updater = updaterController.updater
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            DispatchQueue.main.async {
                self?.canCheckForUpdates = canCheck
            }
        }
    }
}

extension AppUpdateController: SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        AppUpdatePolicy(includesBetaReleases: includesBetaReleases).allowedChannels
    }
}
#endif
