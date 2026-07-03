import Testing
import Foundation
@testable import Chowser

struct PhoneLinkTransferServiceTests {
    @Test("HTTPS URLs expose exactly AirDrop, QR, and Copy URL actions")
    @MainActor
    func validHTTPSURLExposesExpectedActions() {
        let manager = PhoneLinkTransferManager()
        let url = URL(string: "https://example.com/path?q=1")!

        let actions = manager.availableActions(for: url)

        #expect(actions == [.airDrop, .showQRCode, .copyURL])
        #expect(PhoneLinkTransferAction.allCases == [.airDrop, .showQRCode, .copyURL])
    }

    @Test("Invalid URLs expose no phone transfer actions and do not crash")
    @MainActor
    func invalidURLsExposeNoActions() {
        let manager = PhoneLinkTransferManager()
        let cases: [URL?] = [
            nil,
            URL(string: "not a url"),
            URL(string: "ftp://example.com/file"),
            URL(string: "mailto:hello@example.com"),
            URL(fileURLWithPath: "/tmp/example.html"),
        ]

        for url in cases {
            #expect(manager.availableActions(for: url).isEmpty)
        }
    }

    @Test("HTTP URLs expose exactly AirDrop, QR, and Copy URL actions")
    @MainActor
    func validHTTPURLExposesExpectedActions() {
        let manager = PhoneLinkTransferManager()
        let url = URL(string: "http://example.com/path?q=1")!

        #expect(manager.availableActions(for: url) == [.airDrop, .showQRCode, .copyURL])
    }

    @Test("Phone link transfer copy uses approved labels")
    @MainActor
    func copyUsesApprovedLabels() {
        #expect(PhoneLinkTransferManager.Strings.buttonLabel == "Send to Phone")
        #expect(
            PhoneLinkTransferManager.Strings.handoffExplanation ==
                "Also available via Handoff on nearby Apple devices when supported."
        )
    }

    @Test("Handoff remains lifecycle status instead of selectable delivery action")
    @MainActor
    func handoffIsStatusNotSelectableAction() {
        let manager = PhoneLinkTransferManager()

        #expect(manager.handoffStatus == .availableWhenSupported)
        #expect(PhoneLinkTransferAction.allCases == [.airDrop, .showQRCode, .copyURL])
    }

    @Test("User-facing copy avoids unsupported device detection claims")
    @MainActor
    func stringsAvoidDeviceDetectionClaims() {
        let userFacingStrings = [
            PhoneLinkTransferManager.Strings.buttonLabel,
            PhoneLinkTransferManager.Strings.handoffExplanation,
        ]

        for string in userFacingStrings {
            #expect(!string.localizedCaseInsensitiveContains("detected iPhone"))
            #expect(!string.localizedCaseInsensitiveContains("paired iPhone"))
            #expect(!string.localizedCaseInsensitiveContains("same iCloud iPhone found"))
        }
    }
}
