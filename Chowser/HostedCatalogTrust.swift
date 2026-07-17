import CryptoKit
import Foundation

/// Common signed-document contract for every remotely hosted Chowser catalog.
/// The catalog kind and version live inside the signed bytes, so neither can be
/// changed by replacing only the detached signature metadata.
protocol HostedCatalogDocument: Codable {
    static var expectedCatalogKind: String { get }

    var schemaVersion: Int { get }
    var catalogKind: String { get }
    var catalogVersion: Int { get }
    var publishedAt: String { get }
    var itemCount: Int { get }
}

struct HostedCatalogKey: Equatable {
    let keyID: String
    let publicKey: Data
}

struct HostedCatalogLimits: Equatable {
    static let standard = HostedCatalogLimits(
        maxDocumentBytes: 512 * 1_024,
        maxSignatureBytes: 4 * 1_024,
        maxItems: 1_000
    )

    let maxDocumentBytes: Int
    let maxSignatureBytes: Int
    let maxItems: Int
}

struct HostedCatalogSignatureMetadata: Codable, Equatable {
    let schemaVersion: Int
    let catalogKind: String
    let keyID: String
    let algorithm: String
    let sha256: String
    let signature: String
}

struct HostedCatalogArtifact: Equatable {
    var documentData: Data
    var signatureData: Data
}

enum HostedCatalogSource: String, Codable, Equatable {
    case remote
    case cache
}

struct HostedCatalogProvenance: Codable, Equatable {
    let catalogKind: String
    let catalogVersion: Int
    let keyID: String
    let sha256: String
    var source: HostedCatalogSource
}

struct VerifiedHostedCatalog<Document: HostedCatalogDocument> {
    let document: Document
    let artifact: HostedCatalogArtifact
    let provenance: HostedCatalogProvenance
}

enum HostedCatalogTrustError: Error, Equatable {
    case documentTooLarge(maxBytes: Int)
    case signatureTooLarge(maxBytes: Int)
    case malformedSignatureMetadata
    case unsupportedSignatureSchema(Int)
    case unsupportedAlgorithm(String)
    case unknownKey(String)
    case invalidPinnedKey(String)
    case digestMismatch
    case malformedSignature
    case invalidSignature
    case malformedCatalog
    case catalogKindMismatch(expected: String, actual: String)
    case unsupportedCatalogSchema(Int)
    case invalidCatalogVersion(Int)
    case tooManyItems(maxItems: Int)
    case rollback(highestAcceptedVersion: Int, receivedVersion: Int)
    case versionReuse(Int)
    case cacheCorrupt
    case cacheIO
}

/// Pure verifier for detached Ed25519 signatures over the exact catalog bytes.
/// It performs no network I/O and knows nothing about the catalog's feature domain.
struct HostedCatalogTrust {
    private let keysByID: [String: Data]
    let limits: HostedCatalogLimits

    init(keys: [HostedCatalogKey], limits: HostedCatalogLimits = .standard) {
        keysByID = keys.reduce(into: [:]) { result, key in
            result[key.keyID] = key.publicKey
        }
        self.limits = limits
    }

    func verify<Document: HostedCatalogDocument>(
        _ artifact: HostedCatalogArtifact,
        as documentType: Document.Type,
        source: HostedCatalogSource = .remote
    ) throws -> VerifiedHostedCatalog<Document> {
        guard artifact.documentData.count <= limits.maxDocumentBytes else {
            throw HostedCatalogTrustError.documentTooLarge(maxBytes: limits.maxDocumentBytes)
        }
        guard artifact.signatureData.count <= limits.maxSignatureBytes else {
            throw HostedCatalogTrustError.signatureTooLarge(maxBytes: limits.maxSignatureBytes)
        }

        let metadata: HostedCatalogSignatureMetadata
        do {
            metadata = try JSONDecoder().decode(
                HostedCatalogSignatureMetadata.self,
                from: artifact.signatureData
            )
        } catch {
            throw HostedCatalogTrustError.malformedSignatureMetadata
        }

        guard metadata.schemaVersion == 1 else {
            throw HostedCatalogTrustError.unsupportedSignatureSchema(metadata.schemaVersion)
        }
        guard metadata.algorithm == "ed25519" else {
            throw HostedCatalogTrustError.unsupportedAlgorithm(metadata.algorithm)
        }
        guard let rawPublicKey = keysByID[metadata.keyID] else {
            throw HostedCatalogTrustError.unknownKey(metadata.keyID)
        }

        let calculatedDigest = Self.sha256Hex(artifact.documentData)
        guard metadata.sha256 == calculatedDigest else {
            throw HostedCatalogTrustError.digestMismatch
        }
        guard let signature = Data(base64Encoded: metadata.signature) else {
            throw HostedCatalogTrustError.malformedSignature
        }

        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: rawPublicKey)
        } catch {
            throw HostedCatalogTrustError.invalidPinnedKey(metadata.keyID)
        }
        guard publicKey.isValidSignature(signature, for: artifact.documentData) else {
            throw HostedCatalogTrustError.invalidSignature
        }

        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: artifact.documentData)
        } catch {
            throw HostedCatalogTrustError.malformedCatalog
        }

        guard document.catalogKind == Document.expectedCatalogKind else {
            throw HostedCatalogTrustError.catalogKindMismatch(
                expected: Document.expectedCatalogKind,
                actual: document.catalogKind
            )
        }
        guard metadata.catalogKind == document.catalogKind else {
            throw HostedCatalogTrustError.catalogKindMismatch(
                expected: document.catalogKind,
                actual: metadata.catalogKind
            )
        }
        guard document.schemaVersion == 1 else {
            throw HostedCatalogTrustError.unsupportedCatalogSchema(document.schemaVersion)
        }
        guard document.catalogVersion > 0 else {
            throw HostedCatalogTrustError.invalidCatalogVersion(document.catalogVersion)
        }
        guard document.itemCount <= limits.maxItems else {
            throw HostedCatalogTrustError.tooManyItems(maxItems: limits.maxItems)
        }

        return VerifiedHostedCatalog(
            document: document,
            artifact: artifact,
            provenance: HostedCatalogProvenance(
                catalogKind: document.catalogKind,
                catalogVersion: document.catalogVersion,
                keyID: metadata.keyID,
                sha256: calculatedDigest,
                source: source
            )
        )
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// File-backed storage for the exact last accepted artifact. The detached signature
/// is retained and re-verified whenever the cache is loaded.
struct HostedCatalogCache {
    struct State: Codable, Equatable {
        let catalogVersion: Int
        let sha256: String
        let keyID: String
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Chowser/Catalogs", isDirectory: true)
    }

    let directory: URL
    private let fileManager: FileManager

    init(directory: URL = Self.defaultDirectory, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func load(catalogKind: String) throws -> (HostedCatalogArtifact, State)? {
        let paths = paths(for: catalogKind)
        let existence = [paths.document, paths.signature, paths.state]
            .map { fileManager.fileExists(atPath: $0.path) }
        if existence.allSatisfy({ !$0 }) { return nil }
        guard existence.allSatisfy({ $0 }) else {
            throw HostedCatalogTrustError.cacheCorrupt
        }

        do {
            let artifact = HostedCatalogArtifact(
                documentData: try Data(contentsOf: paths.document),
                signatureData: try Data(contentsOf: paths.signature)
            )
            let state = try JSONDecoder().decode(State.self, from: Data(contentsOf: paths.state))
            return (artifact, state)
        } catch let error as HostedCatalogTrustError {
            throw error
        } catch {
            throw HostedCatalogTrustError.cacheCorrupt
        }
    }

    func save(
        artifact: HostedCatalogArtifact,
        provenance: HostedCatalogProvenance
    ) throws {
        let paths = paths(for: provenance.catalogKind)
        do {
            try fileManager.createDirectory(
                at: paths.directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try artifact.documentData.write(to: paths.document, options: .atomic)
            try artifact.signatureData.write(to: paths.signature, options: .atomic)
            let state = State(
                catalogVersion: provenance.catalogVersion,
                sha256: provenance.sha256,
                keyID: provenance.keyID
            )
            try JSONEncoder().encode(state).write(to: paths.state, options: .atomic)
            for file in [paths.document, paths.signature, paths.state] {
                try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            }
        } catch {
            throw HostedCatalogTrustError.cacheIO
        }
    }

    private func paths(for catalogKind: String) -> (
        directory: URL,
        document: URL,
        signature: URL,
        state: URL
    ) {
        let safeKind = catalogKind.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
                ? character
                : "_"
        }
        let catalogDirectory = directory.appendingPathComponent(String(safeKind), isDirectory: true)
        return (
            catalogDirectory,
            catalogDirectory.appendingPathComponent("catalog.json"),
            catalogDirectory.appendingPathComponent("catalog.sig.json"),
            catalogDirectory.appendingPathComponent("state.json")
        )
    }
}

/// Applies monotonic-version and same-version immutability rules before replacing
/// the last-known-good cache.
struct HostedCatalogRepository {
    let trust: HostedCatalogTrust
    let cache: HostedCatalogCache

    func accept<Document: HostedCatalogDocument>(
        _ artifact: HostedCatalogArtifact,
        as documentType: Document.Type
    ) throws -> VerifiedHostedCatalog<Document> {
        let verified = try trust.verify(artifact, as: documentType, source: .remote)
        if let (_, state) = try cache.load(catalogKind: Document.expectedCatalogKind) {
            if verified.provenance.catalogVersion < state.catalogVersion {
                throw HostedCatalogTrustError.rollback(
                    highestAcceptedVersion: state.catalogVersion,
                    receivedVersion: verified.provenance.catalogVersion
                )
            }
            if verified.provenance.catalogVersion == state.catalogVersion,
               verified.provenance.sha256 != state.sha256 {
                throw HostedCatalogTrustError.versionReuse(state.catalogVersion)
            }
        }
        try cache.save(artifact: verified.artifact, provenance: verified.provenance)
        return verified
    }

    func lastKnownGood<Document: HostedCatalogDocument>(
        as documentType: Document.Type
    ) throws -> VerifiedHostedCatalog<Document>? {
        guard let (artifact, state) = try cache.load(catalogKind: Document.expectedCatalogKind) else {
            return nil
        }
        let verified = try trust.verify(artifact, as: documentType, source: .cache)
        guard verified.provenance.catalogVersion == state.catalogVersion,
              verified.provenance.sha256 == state.sha256,
              verified.provenance.keyID == state.keyID else {
            throw HostedCatalogTrustError.cacheCorrupt
        }
        return verified
    }
}

struct HostedCatalogEndpoint: Equatable {
    let documentURL: URL
    let signatureURL: URL
}

enum HostedCatalogTransportError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case responseTooLarge(maxBytes: Int)
}

protocol HostedCatalogTransport {
    func data(from url: URL, maximumBytes: Int) async throws -> Data
}

/// Streams responses into a bounded buffer so a compromised host cannot make Chowser
/// retain an arbitrarily large catalog in memory before verification starts.
final class URLSessionHostedCatalogTransport: HostedCatalogTransport {
    static let shared = URLSessionHostedCatalogTransport()

    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func data(from url: URL, maximumBytes: Int) async throws -> Data {
        let (bytes, response) = try await session.bytes(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw HostedCatalogTransportError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw HostedCatalogTransportError.httpStatus(http.statusCode)
        }
        if response.expectedContentLength > Int64(maximumBytes) {
            throw HostedCatalogTransportError.responseTooLarge(maxBytes: maximumBytes)
        }

        var result = Data()
        if response.expectedContentLength > 0 {
            result.reserveCapacity(min(Int(response.expectedContentLength), maximumBytes))
        }
        for try await byte in bytes {
            guard result.count < maximumBytes else {
                throw HostedCatalogTransportError.responseTooLarge(maxBytes: maximumBytes)
            }
            result.append(byte)
        }
        return result
    }
}

struct HostedCatalogLoadResult<Document: HostedCatalogDocument> {
    let verified: VerifiedHostedCatalog<Document>
    let usedCachedFallback: Bool
}

/// Fetches the two fixed catalog artifacts, verifies them, and replaces the cache only
/// after all signature and monotonic-version checks pass. Any remote failure may fall
/// back only to the separately re-verified last-known-good artifact.
struct HostedCatalogClient {
    let repository: HostedCatalogRepository
    let transport: any HostedCatalogTransport

    func load<Document: HostedCatalogDocument>(
        endpoint: HostedCatalogEndpoint,
        as documentType: Document.Type
    ) async throws -> HostedCatalogLoadResult<Document> {
        do {
            let documentData = try await transport.data(
                from: endpoint.documentURL,
                maximumBytes: repository.trust.limits.maxDocumentBytes
            )
            let signatureData = try await transport.data(
                from: endpoint.signatureURL,
                maximumBytes: repository.trust.limits.maxSignatureBytes
            )
            let verified = try repository.accept(
                HostedCatalogArtifact(
                    documentData: documentData,
                    signatureData: signatureData
                ),
                as: documentType
            )
            return HostedCatalogLoadResult(verified: verified, usedCachedFallback: false)
        } catch {
            if let cached = try? repository.lastKnownGood(as: documentType) {
                return HostedCatalogLoadResult(verified: cached, usedCachedFallback: true)
            }
            throw error
        }
    }
}
