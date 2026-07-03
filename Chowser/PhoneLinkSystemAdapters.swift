import AppKit
import Foundation

enum PhoneLinkURLValidator {
    static func isHTTPOrHTTPS(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "http" || scheme == "https" else { return false }
        return url.host?.isEmpty == false
    }
}

enum PhoneLinkAirDropShareStatus: Equatable {
    case shared
    case unavailable
    case skippedForUITesting
}

@MainActor
protocol PhoneLinkAirDropSharing {
    func canShare(_ url: URL) -> Bool

    @discardableResult
    func share(_ url: URL) -> PhoneLinkAirDropShareStatus
}

@MainActor
final class PhoneLinkAirDropAdapter: PhoneLinkAirDropSharing {
    private let sharingServiceProvider: () -> NSSharingService?
    private let isExternalOpenDisabled: () -> Bool

    private(set) var lastShareStatusForTesting: PhoneLinkAirDropShareStatus?

    init(sharingServiceProvider: @escaping () -> NSSharingService? = { NSSharingService(named: .sendViaAirDrop) }) {
        self.sharingServiceProvider = sharingServiceProvider
        self.isExternalOpenDisabled = { AppEnvironment.shouldDisableExternalURLOpen }
    }

    init(
        sharingServiceProvider: @escaping () -> NSSharingService?,
        isExternalOpenDisabled: @escaping () -> Bool
    ) {
        self.sharingServiceProvider = sharingServiceProvider
        self.isExternalOpenDisabled = isExternalOpenDisabled
    }

    func canShare(_ url: URL) -> Bool {
        guard PhoneLinkURLValidator.isHTTPOrHTTPS(url) else { return false }
        guard let sharingService = sharingServiceProvider() else { return false }
        return sharingService.canPerform(withItems: [url as NSURL])
    }

    @discardableResult
    func share(_ url: URL) -> PhoneLinkAirDropShareStatus {
        guard PhoneLinkURLValidator.isHTTPOrHTTPS(url) else {
            lastShareStatusForTesting = .unavailable
            return .unavailable
        }
        guard !isExternalOpenDisabled() else {
            lastShareStatusForTesting = .skippedForUITesting
            return .skippedForUITesting
        }
        guard let sharingService = sharingServiceProvider(),
              sharingService.canPerform(withItems: [url as NSURL]) else {
            AppLogger.error("AirDrop", "AirDrop unavailable for \(url.host ?? url.absoluteString)")
            lastShareStatusForTesting = .unavailable
            return .unavailable
        }

        AppLogger.log("AirDrop", "Sharing \(url.host ?? url.absoluteString)")
        sharingService.perform(withItems: [url as NSURL])
        lastShareStatusForTesting = .shared
        return .shared
    }
}

@MainActor
protocol PhoneLinkPasteboardWriting {
    func copy(_ url: URL)
}

@MainActor
final class PhoneLinkPasteboardAdapter: PhoneLinkPasteboardWriting {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func copy(_ url: URL) {
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
    }
}

enum PhoneLinkHandoffEvent: Equatable {
    case started(URL)
    case updated(URL)
    case invalidated
}

@MainActor
protocol PhoneLinkHandoffManaging {
    func startOrUpdate(_ url: URL)
    func stop()
}

@MainActor
final class PhoneLinkHandoffAdapter: PhoneLinkHandoffManaging {
    /// The system web-browsing activity type: with no iOS Chowser app to receive a
    /// custom activity, this is what makes the receiving device offer its browser
    /// (Safari icon in the iPhone app switcher / dock) for the advertised URL.
    static let activityType = NSUserActivityTypeBrowsingWeb

    private var currentActivity: NSUserActivity?

    func startOrUpdate(_ url: URL) {
        guard PhoneLinkURLValidator.isHTTPOrHTTPS(url) else { return }

        let activity = currentActivity ?? NSUserActivity(activityType: Self.activityType)
        activity.title = "Open in Chowser"
        activity.webpageURL = url
        activity.isEligibleForHandoff = true
        activity.becomeCurrent()
        currentActivity = activity
        AppLogger.log("Handoff", "Advertising \(url.host ?? url.absoluteString)")
    }

    func stop() {
        guard currentActivity != nil else { return }
        currentActivity?.invalidate()
        currentActivity = nil
        AppLogger.log("Handoff", "Stopped advertising")
    }
}
