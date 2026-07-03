import Testing
import Foundation
@testable import Chowser

struct PhoneLinkSystemAdapterTests {
    private let url = URL(string: "https://example.com/path?q=1")!

    @Test("AirDrop fake receives exact URL for capability and share")
    @MainActor
    func airDropFakeReceivesExactURL() {
        let airDrop = FakePhoneLinkAirDropAdapter(canShareResult: true)

        let canShare = airDrop.canShare(url)
        let status = airDrop.share(url)

        #expect(canShare)
        #expect(status == .shared)
        #expect(airDrop.capabilityURLs == [url])
        #expect(airDrop.sharedURLs == [url])
    }

    @Test("AirDrop adapter skips system UI when external opens are disabled")
    @MainActor
    func airDropAdapterSkipsSystemUIWhenExternalOpenDisabled() {
        let airDrop = PhoneLinkAirDropAdapter(
            sharingServiceProvider: { nil },
            isExternalOpenDisabled: { true }
        )

        let status = airDrop.share(url)

        #expect(status == .skippedForUITesting)
        #expect(airDrop.lastShareStatusForTesting == .skippedForUITesting)
    }

    @Test("Pasteboard fake stores exact absolute URL string")
    @MainActor
    func pasteboardFakeStoresExactURLString() {
        let pasteboard = FakePhoneLinkPasteboardAdapter()

        pasteboard.copy(url)

        #expect(pasteboard.copiedStrings == ["https://example.com/path?q=1"])
    }

    @Test("Handoff fake records start update and invalidate")
    @MainActor
    func handoffFakeRecordsLifecycle() {
        let handoff = FakePhoneLinkHandoffAdapter()

        handoff.startOrUpdate(url)
        handoff.startOrUpdate(url)
        handoff.stop()

        #expect(handoff.events == [
            .started(url),
            .updated(url),
            .invalidated,
        ])
    }

    @Test("Handoff fake ignores non HTTP and HTTPS URLs")
    @MainActor
    func handoffIgnoresNonHTTPURLs() {
        let handoff = FakePhoneLinkHandoffAdapter()
        let ignoredURLs = [
            URL(string: "ftp://example.com/file")!,
            URL(string: "mailto:hello@example.com")!,
            URL(fileURLWithPath: "/tmp/example.html"),
        ]

        for ignoredURL in ignoredURLs {
            handoff.startOrUpdate(ignoredURL)
        }

        #expect(handoff.events.isEmpty)
    }
}


@MainActor
private final class FakePhoneLinkAirDropAdapter: PhoneLinkAirDropSharing {
    private let canShareResult: Bool
    private(set) var capabilityURLs: [URL] = []
    private(set) var sharedURLs: [URL] = []

    init(canShareResult: Bool) {
        self.canShareResult = canShareResult
    }

    func canShare(_ url: URL) -> Bool {
        capabilityURLs.append(url)
        return canShareResult
    }

    @discardableResult
    func share(_ url: URL) -> PhoneLinkAirDropShareStatus {
        sharedURLs.append(url)
        return canShareResult ? .shared : .unavailable
    }
}

@MainActor
private final class FakePhoneLinkPasteboardAdapter: PhoneLinkPasteboardWriting {
    private(set) var copiedStrings: [String] = []

    func copy(_ url: URL) {
        copiedStrings.append(url.absoluteString)
    }
}

@MainActor
private final class FakePhoneLinkHandoffAdapter: PhoneLinkHandoffManaging {
    private(set) var events: [PhoneLinkHandoffEvent] = []
    private var hasCurrentActivity = false

    func startOrUpdate(_ url: URL) {
        guard PhoneLinkURLValidator.isHTTPOrHTTPS(url) else { return }

        events.append(hasCurrentActivity ? .updated(url) : .started(url))
        hasCurrentActivity = true
    }

    func stop() {
        guard hasCurrentActivity else { return }

        events.append(.invalidated)
        hasCurrentActivity = false
    }
}
