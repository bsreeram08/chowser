import Foundation
import Observation

enum PhoneLinkTransferAction: CaseIterable, Equatable {
    case airDrop
    case showQRCode
    case copyURL
}

enum PhoneLinkHandoffStatus: Equatable {
    case availableWhenSupported
}

@MainActor
@Observable final class PhoneLinkTransferManager {
    struct Dependencies {
        var isTransferableURL: (URL?) -> Bool

        static let live = Dependencies { url in
            url.map(PhoneLinkURLValidator.isHTTPOrHTTPS) ?? false
        }
    }

    enum Strings {
        static let buttonLabel = "Send to Phone"
        static let handoffExplanation = "Also available via Handoff on nearby Apple devices when supported."
    }

    static let shared = PhoneLinkTransferManager()

    private let dependencies: Dependencies

    var handoffStatus: PhoneLinkHandoffStatus = .availableWhenSupported

    init(dependencies: Dependencies? = nil) {
        self.dependencies = dependencies ?? Dependencies.live
    }

    func availableActions(for url: URL?) -> [PhoneLinkTransferAction] {
        guard dependencies.isTransferableURL(url) else { return [] }
        return PhoneLinkTransferAction.allCases
    }
}
