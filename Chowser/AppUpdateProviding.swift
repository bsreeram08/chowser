import Foundation

#if DIRECT_DISTRIBUTION
@MainActor
protocol AppUpdateProviding: AnyObject {
    var includesBetaReleases: Bool { get set }
    var isConfigured: Bool { get }
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }

    func start()
    func checkForUpdates()
}
#endif
