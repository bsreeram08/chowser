import CryptoKit
import Foundation
import Testing
@testable import Chowser

struct HostedCatalogTrustTests {
    private final class StubTransport: HostedCatalogTransport {
        var responses: [URL: Result<Data, Error>]

        init(responses: [URL: Result<Data, Error>]) {
            self.responses = responses
        }

        func data(from url: URL, maximumBytes: Int) async throws -> Data {
            guard let result = responses[url] else {
                throw HostedCatalogTransportError.invalidResponse
            }
            let data = try result.get()
            guard data.count <= maximumBytes else {
                throw HostedCatalogTransportError.responseTooLarge(maxBytes: maximumBytes)
            }
            return data
        }
    }

    private struct FixtureCatalog: HostedCatalogDocument, Equatable {
        static let expectedCatalogKind = "test-catalog"

        let schemaVersion: Int
        let catalogKind: String
        let catalogVersion: Int
        let publishedAt: String
        let items: [String]

        var itemCount: Int { items.count }
    }

    private struct FixtureSigner {
        let keyID: String
        let privateKey: Curve25519.Signing.PrivateKey

        init(keyID: String = "fixture-2026", privateKey: Curve25519.Signing.PrivateKey = .init()) {
            self.keyID = keyID
            self.privateKey = privateKey
        }

        var trustedKey: HostedCatalogKey {
            HostedCatalogKey(keyID: keyID, publicKey: privateKey.publicKey.rawRepresentation)
        }

        func artifact(
            version: Int = 1,
            items: [String] = ["one"],
            kind: String = FixtureCatalog.expectedCatalogKind,
            schemaVersion: Int = 1
        ) throws -> HostedCatalogArtifact {
            let catalog = FixtureCatalog(
                schemaVersion: schemaVersion,
                catalogKind: kind,
                catalogVersion: version,
                publishedAt: "2026-07-17T00:00:00Z",
                items: items
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let documentData = try encoder.encode(catalog)
            let digest = SHA256.hash(data: documentData).map { String(format: "%02x", $0) }.joined()
            let signature = try privateKey.signature(for: documentData).base64EncodedString()
            let metadata = HostedCatalogSignatureMetadata(
                schemaVersion: 1,
                catalogKind: kind,
                keyID: keyID,
                algorithm: "ed25519",
                sha256: digest,
                signature: signature
            )
            return HostedCatalogArtifact(
                documentData: documentData,
                signatureData: try encoder.encode(metadata)
            )
        }
    }

    @Test("A pinned Ed25519 key verifies the exact catalog bytes")
    func validSignature() throws {
        let signer = FixtureSigner()
        let trust = HostedCatalogTrust(keys: [signer.trustedKey])

        let verified = try trust.verify(try signer.artifact(), as: FixtureCatalog.self)

        #expect(verified.document.catalogVersion == 1)
        #expect(verified.provenance.catalogKind == FixtureCatalog.expectedCatalogKind)
        #expect(verified.provenance.keyID == signer.keyID)
        #expect(verified.provenance.sha256.count == 64)
    }

    @Test("Bundled keyring shape decodes only Base64 public keys")
    func keyringDecoding() throws {
        let signer = FixtureSigner()
        let keyring = HostedCatalogKeyring(
            schemaVersion: 1,
            keys: [
                .init(
                    keyID: signer.keyID,
                    publicKey: signer.privateKey.publicKey.rawRepresentation.base64EncodedString()
                )
            ]
        )

        #expect(try keyring.trustedKeys() == [signer.trustedKey])

        let invalid = HostedCatalogKeyring(
            schemaVersion: 1,
            keys: [.init(keyID: signer.keyID, publicKey: "not-base64")]
        )
        expectFailure(.invalidKeyring) {
            try invalid.trustedKeys()
        }
    }

    @Test("Changing a signed catalog byte is rejected")
    func tamperedDocument() throws {
        let signer = FixtureSigner()
        let trust = HostedCatalogTrust(keys: [signer.trustedKey])
        var artifact = try signer.artifact()
        artifact.documentData.append(0x20)

        expectFailure(.digestMismatch) {
            try trust.verify(artifact, as: FixtureCatalog.self)
        }
    }

    @Test("Unknown key identifiers fail closed")
    func unknownKey() throws {
        let signer = FixtureSigner(keyID: "unknown")
        let trust = HostedCatalogTrust(keys: [])

        expectFailure(.unknownKey("unknown")) {
            try trust.verify(try signer.artifact(), as: FixtureCatalog.self)
        }
    }

    @Test("A signature from a different key is rejected")
    func wrongKey() throws {
        let signer = FixtureSigner(keyID: "current")
        let otherKey = Curve25519.Signing.PrivateKey()
        let trust = HostedCatalogTrust(keys: [
            HostedCatalogKey(keyID: "current", publicKey: otherKey.publicKey.rawRepresentation)
        ])

        expectFailure(.invalidSignature) {
            try trust.verify(try signer.artifact(), as: FixtureCatalog.self)
        }
    }

    @Test("Malformed signature metadata is rejected before decoding the catalog")
    func malformedSignatureMetadata() throws {
        let signer = FixtureSigner()
        let trust = HostedCatalogTrust(keys: [signer.trustedKey])
        let artifact = HostedCatalogArtifact(
            documentData: Data("not a catalog".utf8),
            signatureData: Data("{not-json".utf8)
        )

        expectFailure(.malformedSignatureMetadata) {
            try trust.verify(artifact, as: FixtureCatalog.self)
        }
    }

    @Test("Catalog kind and schema are part of the signed contract")
    func contractMetadata() throws {
        let signer = FixtureSigner()
        let trust = HostedCatalogTrust(keys: [signer.trustedKey])

        expectFailure(.catalogKindMismatch(expected: FixtureCatalog.expectedCatalogKind, actual: "other")) {
            try trust.verify(try signer.artifact(kind: "other"), as: FixtureCatalog.self)
        }
        expectFailure(.unsupportedCatalogSchema(2)) {
            try trust.verify(try signer.artifact(schemaVersion: 2), as: FixtureCatalog.self)
        }
    }

    @Test("Document byte and item limits reject oversized catalogs")
    func sizeLimits() throws {
        let signer = FixtureSigner()
        let byteLimitedTrust = HostedCatalogTrust(
            keys: [signer.trustedKey],
            limits: HostedCatalogLimits(maxDocumentBytes: 8, maxSignatureBytes: 4_096, maxItems: 10)
        )
        expectFailure(.documentTooLarge(maxBytes: 8)) {
            try byteLimitedTrust.verify(try signer.artifact(), as: FixtureCatalog.self)
        }

        let itemLimitedTrust = HostedCatalogTrust(
            keys: [signer.trustedKey],
            limits: HostedCatalogLimits(maxDocumentBytes: 64_000, maxSignatureBytes: 4_096, maxItems: 1)
        )
        expectFailure(.tooManyItems(maxItems: 1)) {
            try itemLimitedTrust.verify(try signer.artifact(items: ["one", "two"]), as: FixtureCatalog.self)
        }
    }

    @Test("Repository rejects rollback and same-version content replacement")
    func rollbackProtection() throws {
        let signer = FixtureSigner()
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = HostedCatalogRepository(
            trust: HostedCatalogTrust(keys: [signer.trustedKey]),
            cache: HostedCatalogCache(directory: directory)
        )

        _ = try repository.accept(try signer.artifact(version: 2), as: FixtureCatalog.self)

        expectFailure(.rollback(highestAcceptedVersion: 2, receivedVersion: 1)) {
            try repository.accept(try signer.artifact(version: 1), as: FixtureCatalog.self)
        }
        expectFailure(.versionReuse(2)) {
            try repository.accept(
                try signer.artifact(version: 2, items: ["different content"]),
                as: FixtureCatalog.self
            )
        }
    }

    @Test("The last-known-good artifact survives a repository restart")
    func lastKnownGoodCache() throws {
        let signer = FixtureSigner()
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trust = HostedCatalogTrust(keys: [signer.trustedKey])
        let cache = HostedCatalogCache(directory: directory)

        _ = try HostedCatalogRepository(trust: trust, cache: cache)
            .accept(try signer.artifact(version: 7, items: ["cached"]), as: FixtureCatalog.self)

        let cached = try HostedCatalogRepository(trust: trust, cache: cache)
            .lastKnownGood(as: FixtureCatalog.self)

        #expect(cached?.document.catalogVersion == 7)
        #expect(cached?.document.items == ["cached"])
        #expect(cached?.provenance.source == .cache)
    }

    @Test("Client accepts a valid remote artifact, then falls back to its verified cache")
    @MainActor
    func remoteRefreshAndFallback() async throws {
        let signer = FixtureSigner()
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = HostedCatalogRepository(
            trust: HostedCatalogTrust(keys: [signer.trustedKey]),
            cache: HostedCatalogCache(directory: directory)
        )
        let endpoint = HostedCatalogEndpoint(
            documentURL: URL(string: "https://catalog.invalid/test.json")!,
            signatureURL: URL(string: "https://catalog.invalid/test.sig.json")!
        )
        let artifact = try signer.artifact(version: 4)
        let online = StubTransport(responses: [
            endpoint.documentURL: .success(artifact.documentData),
            endpoint.signatureURL: .success(artifact.signatureData)
        ])

        let refreshed = try await HostedCatalogClient(repository: repository, transport: online)
            .load(endpoint: endpoint, as: FixtureCatalog.self)
        #expect(refreshed.verified.provenance.source == .remote)
        #expect(!refreshed.usedCachedFallback)

        let offline = StubTransport(responses: [
            endpoint.documentURL: .failure(HostedCatalogTransportError.invalidResponse),
            endpoint.signatureURL: .failure(HostedCatalogTransportError.invalidResponse)
        ])
        let fallback = try await HostedCatalogClient(repository: repository, transport: offline)
            .load(endpoint: endpoint, as: FixtureCatalog.self)
        #expect(fallback.verified.document.catalogVersion == 4)
        #expect(fallback.verified.provenance.source == .cache)
        #expect(fallback.usedCachedFallback)
    }

    @Test("Client fails closed when the remote artifact is invalid and no cache exists")
    @MainActor
    func invalidRemoteWithoutCache() async throws {
        let signer = FixtureSigner()
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = HostedCatalogRepository(
            trust: HostedCatalogTrust(keys: [signer.trustedKey]),
            cache: HostedCatalogCache(directory: directory)
        )
        let endpoint = HostedCatalogEndpoint(
            documentURL: URL(string: "https://catalog.invalid/test.json")!,
            signatureURL: URL(string: "https://catalog.invalid/test.sig.json")!
        )
        var artifact = try signer.artifact()
        artifact.documentData.append(0x20)
        let transport = StubTransport(responses: [
            endpoint.documentURL: .success(artifact.documentData),
            endpoint.signatureURL: .success(artifact.signatureData)
        ])

        do {
            _ = try await HostedCatalogClient(repository: repository, transport: transport)
                .load(endpoint: endpoint, as: FixtureCatalog.self)
            Issue.record("Expected invalid remote catalog to fail")
        } catch let error as HostedCatalogTrustError {
            #expect(error == .digestMismatch)
        } catch {
            Issue.record("Expected digestMismatch, received \(error)")
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ChowserCatalogTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func expectFailure<T>(
        _ expected: HostedCatalogTrustError,
        operation: () throws -> T
    ) {
        do {
            _ = try operation()
            Issue.record("Expected \(expected), but verification succeeded")
        } catch let error as HostedCatalogTrustError {
            #expect(error == expected)
        } catch {
            Issue.record("Expected \(expected), received \(error)")
        }
    }
}
