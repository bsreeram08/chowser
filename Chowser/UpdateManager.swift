#if !APP_STORE
import Foundation
import Combine
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    private var updaterController: SPUStandardUpdaterController!

    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    
    nonisolated let objectWillChange = ObservableObjectPublisher()

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var joinBetaProgram: Bool {
        get { UserDefaults.standard.bool(forKey: "ChowserJoinBetaProgram") }
        set {
            UserDefaults.standard.set(newValue, forKey: "ChowserJoinBetaProgram")
            // Force a re-check so beta/stable channel is picked up
            if newValue {
                checkForUpdates()
            }
        }
    }

    private override init() {
        super.init()
        
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheckDate)
    }

    func startUpdater() {
        updaterController.startUpdater()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        let isBeta = UserDefaults.standard.bool(forKey: "ChowserJoinBetaProgram")
        if isBeta {
            return Bundle.main.infoDictionary?["SUBetaFeedURL"] as? String
        }
        return Bundle.main.infoDictionary?["SUFeedURL"] as? String
    }

    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let isBeta = UserDefaults.standard.bool(forKey: "ChowserJoinBetaProgram")
        return isBeta ? ["beta"] : []
    }
}
#endif
