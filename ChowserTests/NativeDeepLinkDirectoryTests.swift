import CryptoKit
import Foundation
import Testing
@testable import Chowser

struct NativeDeepLinkDirectoryTests {
    private final class NeverTransport: HostedCatalogTransport {
        func data(from url: URL, maximumBytes: Int) async throws -> Data {
            throw HostedCatalogTransportError.invalidResponse
        }
    }

    private final class StubSystemHandler: NativeAppSystemHandling {
        var handlerBundleIdentifier = "com.spotify.client"
        var openedURLs: [URL] = []

        func handlerBundleIdentifier(for nativeURL: URL) -> String? {
            handlerBundleIdentifier
        }

        func installedBundleIdentifier(for allowedBundleIdentifiers: [String]) -> String? {
            allowedBundleIdentifiers.first
        }

        func open(_ nativeURL: URL) -> Bool {
            openedURLs.append(nativeURL)
            return true
        }
    }

    private func pathCapture(
        _ name: String,
        characterSet: NativeCaptureCharacterSet = .urlUnreserved,
        maxLength: Int = 128
    ) -> NativeSourcePathSegment {
        .capture(NativeCapture(name: name, characterSet: characterSet, maxLength: maxLength))
    }

    private func spotifyEntry() -> NativeAppDirectoryEntry {
        NativeAppDirectoryEntry(
            id: "spotify",
            name: "Spotify",
            summary: "Open Spotify links in the installed native app.",
            bundleIdentifiers: ["com.spotify.client"],
            nativeSchemes: ["spotify"],
            rules: [
                NativeDeepLinkRule(
                    id: "album",
                    source: NativeDeepLinkSource(
                        hosts: ["open.spotify.com"],
                        path: [.literal("album"), pathCapture("id")],
                        query: []
                    ),
                    target: NativeDeepLinkTarget(
                        scheme: "spotify",
                        format: .opaqueColonPath,
                        host: "album",
                        path: [.capture("id")],
                        query: []
                    )
                ),
                NativeDeepLinkRule(
                    id: "track",
                    source: NativeDeepLinkSource(
                        hosts: ["open.spotify.com"],
                        path: [.literal("track"), pathCapture("id")],
                        query: []
                    ),
                    target: NativeDeepLinkTarget(
                        scheme: "spotify",
                        format: .opaqueColonPath,
                        host: "track",
                        path: [.capture("id")],
                        query: []
                    )
                )
            ]
        )
    }

    private func directory(_ apps: [NativeAppDirectoryEntry]) -> NativeAppDirectory {
        NativeAppDirectory(
            schemaVersion: 1,
            catalogKind: NativeAppDirectory.expectedCatalogKind,
            catalogVersion: 1,
            publishedAt: "2026-07-17T00:00:00Z",
            apps: apps
        )
    }

    private func verifySigned(
        _ directory: NativeAppDirectory
    ) throws -> VerifiedHostedCatalog<NativeAppDirectory> {
        let privateKey = Curve25519.Signing.PrivateKey()
        let keyID = "native-fixture"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let document = try encoder.encode(directory)
        let digest = HostedCatalogTrust.sha256Hex(document)
        let signature = HostedCatalogSignatureMetadata(
            schemaVersion: 1,
            catalogKind: NativeAppDirectory.expectedCatalogKind,
            keyID: keyID,
            algorithm: "ed25519",
            sha256: digest,
            signature: try privateKey.signature(for: document).base64EncodedString()
        )
        return try HostedCatalogTrust(keys: [
            HostedCatalogKey(keyID: keyID, publicKey: privateKey.publicKey.rawRepresentation)
        ]).verify(
            HostedCatalogArtifact(
                documentData: document,
                signatureData: try encoder.encode(signature)
            ),
            as: NativeAppDirectory.self
        )
    }

    @Test("Committed multi-app directory verifies with the public key bundled in Chowser")
    func committedDirectoryVerifies() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let keyringData = try Data(contentsOf: repository.appendingPathComponent("Chowser/HostedCatalogKeys.json"))
        let keyring = try JSONDecoder().decode(HostedCatalogKeyring.self, from: keyringData)
        let artifact = HostedCatalogArtifact(
            documentData: try Data(contentsOf: repository.appendingPathComponent("docs/public/native-app-directory.json")),
            signatureData: try Data(contentsOf: repository.appendingPathComponent("docs/public/native-app-directory.sig.json"))
        )

        let verified = try HostedCatalogTrust(keys: keyring.trustedKeys())
            .verify(artifact, as: NativeAppDirectory.self)
        let spotify = try #require(verified.document.apps.first { $0.id == "spotify" })
        let resolution = NativeDeepLinkResolver.resolve(
            webURL: URL(string: "https://open.spotify.com/track/0hwPOwj3rojFt33NhaxNUy?si=ignored")!,
            in: verified.document,
            approvedBehaviorSHA256ByEntryID: [spotify.id: spotify.behaviorSHA256],
            handlerBundleIdentifier: { _ in "com.spotify.client" }
        )

        #expect(verified.document.apps.map(\.id) == ["spotify", "slack", "zoom"])
        #expect(resolution?.nativeURL.absoluteString == "spotify:track:0hwPOwj3rojFt33NhaxNUy")
    }

    @Test("Signed native directories with unsafe or ambiguous behavior fail validation")
    func invalidSignedDirectoryRejected() throws {
        var reservedTarget = spotifyEntry()
        reservedTarget.nativeSchemes = ["file"]
        reservedTarget.rules[0].target.scheme = "file"

        do {
            _ = try verifySigned(directory([reservedTarget]))
            Issue.record("Expected a reserved native target scheme to be rejected")
        } catch let error as HostedCatalogTrustError {
            #expect(error == .invalidCatalogContents)
        }

        var unknownCapture = spotifyEntry()
        var unknownRule = unknownCapture.rules[0]
        var unknownTarget = unknownRule.target
        unknownTarget = NativeDeepLinkTarget(
            scheme: unknownTarget.scheme,
            host: unknownTarget.host,
            path: [.capture("not-in-source")],
            query: unknownTarget.query
        )
        unknownRule.target = unknownTarget
        unknownCapture.rules[0] = unknownRule

        do {
            _ = try verifySigned(directory([unknownCapture]))
            Issue.record("Expected an undefined target capture to be rejected")
        } catch let error as HostedCatalogTrustError {
            #expect(error == .invalidCatalogContents)
        }

        let duplicate = spotifyEntry()
        do {
            _ = try verifySigned(directory([duplicate, duplicate]))
            Issue.record("Expected duplicate native app identifiers to be rejected")
        } catch let error as HostedCatalogTrustError {
            #expect(error == .invalidCatalogContents)
        }
    }

    @Test("Spotify album and track links resolve through declarative catalog rules")
    func spotifyFixtures() {
        let spotify = spotifyEntry()
        let approvals = [spotify.id: spotify.behaviorSHA256]

        let album = NativeDeepLinkResolver.resolve(
            webURL: URL(string: "https://open.spotify.com/album/2Ki8BsWPpqo2g7bUj6AGyV?si=ignored")!,
            in: directory([spotify]),
            approvedBehaviorSHA256ByEntryID: approvals,
            handlerBundleIdentifier: { _ in "com.spotify.client" }
        )
        let track = NativeDeepLinkResolver.resolve(
            webURL: URL(string: "https://open.spotify.com/track/0hwPOwj3rojFt33NhaxNUy?si=ignored")!,
            in: directory([spotify]),
            approvedBehaviorSHA256ByEntryID: approvals,
            handlerBundleIdentifier: { _ in "com.spotify.client" }
        )

        #expect(album?.nativeURL.absoluteString == "spotify:album:2Ki8BsWPpqo2g7bUj6AGyV")
        #expect(track?.nativeURL.absoluteString == "spotify:track:0hwPOwj3rojFt33NhaxNUy")
        #expect(album?.matchedRuleID == "album")
        #expect(spotify.rules[0].reviewDescription.contains("→ spotify:album:{id}"))
    }

    @Test("The same resolver supports an unrelated query-driven app without Swift mappings")
    func unrelatedAppFixture() {
        let entry = NativeAppDirectoryEntry(
            id: "meeting-app",
            name: "Meeting App",
            summary: "Fixture proving the resolver is app-agnostic.",
            bundleIdentifiers: ["com.example.meeting"],
            nativeSchemes: ["meet-example"],
            rules: [
                NativeDeepLinkRule(
                    id: "join",
                    source: NativeDeepLinkSource(
                        hosts: ["meet.example.test"],
                        path: [.literal("join")],
                        query: [
                            NativeSourceQueryCapture(
                                queryName: "code",
                                capture: NativeCapture(name: "meeting", characterSet: .digits, maxLength: 12),
                                required: true
                            )
                        ]
                    ),
                    target: NativeDeepLinkTarget(
                        scheme: "meet-example",
                        host: "join",
                        path: [],
                        query: [
                            NativeTargetQueryItem(name: "meeting", value: .capture("meeting"))
                        ]
                    )
                )
            ]
        )

        let resolution = NativeDeepLinkResolver.resolve(
            webURL: URL(string: "https://meet.example.test/join?code=123456")!,
            in: directory([entry]),
            approvedBehaviorSHA256ByEntryID: [entry.id: entry.behaviorSHA256],
            handlerBundleIdentifier: { _ in "com.example.meeting" }
        )

        #expect(resolution?.nativeURL.absoluteString == "meet-example://join?meeting=123456")
        #expect(resolution?.entryID == "meeting-app")
    }

    @Test("Native routing is disabled until the exact behavior digest is approved")
    func explicitConsentAndBehaviorChange() {
        let original = spotifyEntry()
        var changed = original
        changed.rules.append(NativeDeepLinkRule(
            id: "artist",
            source: NativeDeepLinkSource(
                hosts: ["open.spotify.com"],
                path: [.literal("artist"), pathCapture("id")],
                query: []
            ),
            target: NativeDeepLinkTarget(
                scheme: "spotify",
                host: "artist",
                path: [.capture("id")],
                query: []
            )
        ))

        #expect(original.behaviorSHA256 != changed.behaviorSHA256)
        var renamed = original
        renamed.name = "Spotify Music"
        #expect(original.behaviorSHA256 == renamed.behaviorSHA256)

        let url = URL(string: "https://open.spotify.com/album/abc123")!
        let handler: (URL) -> String? = { _ in "com.spotify.client" }
        #expect(NativeDeepLinkResolver.resolve(
            webURL: url,
            in: directory([original]),
            approvedBehaviorSHA256ByEntryID: [:],
            handlerBundleIdentifier: handler
        ) == nil)
        #expect(NativeDeepLinkResolver.resolve(
            webURL: url,
            in: directory([changed]),
            approvedBehaviorSHA256ByEntryID: [changed.id: original.behaviorSHA256],
            handlerBundleIdentifier: handler
        ) == nil)
    }

    @Test("Missing or mismatched native scheme handlers fail closed")
    func handlerVerification() {
        let spotify = spotifyEntry()
        let approvals = [spotify.id: spotify.behaviorSHA256]
        let url = URL(string: "https://open.spotify.com/album/abc123")!

        #expect(NativeDeepLinkResolver.resolve(
            webURL: url,
            in: directory([spotify]),
            approvedBehaviorSHA256ByEntryID: approvals,
            handlerBundleIdentifier: { _ in nil }
        ) == nil)
        #expect(NativeDeepLinkResolver.resolve(
            webURL: url,
            in: directory([spotify]),
            approvedBehaviorSHA256ByEntryID: approvals,
            handlerBundleIdentifier: { _ in "com.attacker.claimed-scheme" }
        ) == nil)
    }

    @Test("Launch rechecks the handler to close the resolution-to-open race")
    @MainActor
    func launchRechecksHandler() {
        let system = StubSystemHandler()
        let cache = HostedCatalogCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("native-open-\(UUID().uuidString)"))
        let client = HostedCatalogClient(
            repository: HostedCatalogRepository(
                trust: HostedCatalogTrust(keys: []),
                cache: cache
            ),
            transport: NeverTransport()
        )
        let service = NativeAppDirectoryService(client: client, systemHandler: system)
        let resolution = NativeDeepLinkResolution(
            entryID: "spotify",
            appName: "Spotify",
            matchedRuleID: "album",
            handlerBundleIdentifier: "com.spotify.client",
            nativeURL: URL(string: "spotify://album/abc")!
        )

        system.handlerBundleIdentifier = "com.attacker.claimed-scheme"
        #expect(!service.open(resolution))
        #expect(system.openedURLs.isEmpty)

        system.handlerBundleIdentifier = "com.spotify.client"
        #expect(service.open(resolution))
        #expect(system.openedURLs == [resolution.nativeURL])
    }

    @Test("Native app approval persists only for the exact behavior digest")
    @MainActor
    func approvalPersistence() {
        let suite = "in.sreerams.Chowser.NativeApproval.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = spotifyEntry()
        let firstManager = BrowserManager(defaults: defaults)
        firstManager.approveNativeApp(original)

        let restored = BrowserManager(defaults: defaults)
        #expect(restored.isNativeAppApproved(original))

        var changed = original
        changed.nativeSchemes = ["spotify-v2"]
        #expect(!restored.isNativeAppApproved(changed))

        restored.resetToFreshSetup()
        #expect(restored.nativeAppApprovals.isEmpty)
    }

    @Test("Reserved targets and hostile captures cannot produce native URLs")
    func unsafeTransformsRejected() {
        var reserved = spotifyEntry()
        reserved.nativeSchemes = ["file"]
        reserved.rules[0].target.scheme = "file"
        let reservedResolution = NativeDeepLinkResolver.resolve(
            webURL: URL(string: "https://open.spotify.com/album/abc123")!,
            in: directory([reserved]),
            approvedBehaviorSHA256ByEntryID: [reserved.id: reserved.behaviorSHA256],
            handlerBundleIdentifier: { _ in "com.spotify.client" }
        )
        #expect(reservedResolution == nil)

        let spotify = spotifyEntry()
        let approvals = [spotify.id: spotify.behaviorSHA256]
        let encodedSlash = NativeDeepLinkResolver.resolve(
            webURL: URL(string: "https://open.spotify.com/album/abc%2Fdef")!,
            in: directory([spotify]),
            approvedBehaviorSHA256ByEntryID: approvals,
            handlerBundleIdentifier: { _ in "com.spotify.client" }
        )
        let oversized = NativeDeepLinkResolver.resolve(
            webURL: URL(string: "https://open.spotify.com/album/\(String(repeating: "a", count: 129))")!,
            in: directory([spotify]),
            approvedBehaviorSHA256ByEntryID: approvals,
            handlerBundleIdentifier: { _ in "com.spotify.client" }
        )
        #expect(encodedSlash == nil)
        #expect(oversized == nil)
    }

    @Test("Explicit browser routes and Shift precede native routing; private mode bypasses it")
    @MainActor
    func incomingDestinationPrecedence() {
        let defaults = UserDefaults(suiteName: "in.sreerams.Chowser.NativePrecedence.\(UUID().uuidString)")!
        let manager = BrowserManager(defaults: defaults)
        let safari = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        manager.configuredBrowsers = [safari]
        manager.addRoutingRule(
            name: "Spotify in browser",
            hostPattern: "open.spotify.com",
            pathPrefix: nil,
            browserBundleId: safari.bundleId
        )
        let native = NativeDeepLinkResolution(
            entryID: "spotify",
            appName: "Spotify",
            matchedRuleID: "album",
            handlerBundleIdentifier: "com.spotify.client",
            nativeURL: URL(string: "spotify://album/abc")!
        )
        let url = URL(string: "https://open.spotify.com/album/abc")!

        let explicit = AppDelegate.resolveIncomingURLDestination(
            for: url,
            using: manager,
            forceShowPicker: false,
            privateModeRequested: false,
            nativeResolution: { native }
        )
        guard case .browser(let rule, _) = explicit else {
            Issue.record("Expected explicit browser rule")
            return
        }
        #expect(rule?.name == "Spotify in browser")

        manager.routingRules.removeAll()
        let nativeDestination = AppDelegate.resolveIncomingURLDestination(
            for: url,
            using: manager,
            forceShowPicker: false,
            privateModeRequested: false,
            nativeResolution: { native }
        )
        guard case .native(let resolution) = nativeDestination else {
            Issue.record("Expected approved native route")
            return
        }
        #expect(resolution.entryID == "spotify")

        let forcedPicker = AppDelegate.resolveIncomingURLDestination(
            for: url,
            using: manager,
            forceShowPicker: true,
            privateModeRequested: false,
            nativeResolution: { native }
        )
        guard case .picker = forcedPicker else {
            Issue.record("Expected Shift to force picker")
            return
        }

        manager.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: safari.id)
        let privateDestination = AppDelegate.resolveIncomingURLDestination(
            for: url,
            using: manager,
            forceShowPicker: false,
            privateModeRequested: true,
            nativeResolution: { native }
        )
        guard case .browser(let rule, let browser) = privateDestination else {
            Issue.record("Expected private request to bypass native app and use browser fallback")
            return
        }
        #expect(rule == nil)
        #expect(browser.id == safari.id)
    }

    @Test("Incoming modifier intent is captured before asynchronous URL processing")
    func incomingIntentSnapshot() {
        let intent = AppDelegate.captureIncomingURLIntent(
            privateModeRequested: false,
            modifierFlags: [.shift]
        )

        #expect(intent.forceShowPicker)
        #expect(!intent.privateModeRequested)
    }
}
