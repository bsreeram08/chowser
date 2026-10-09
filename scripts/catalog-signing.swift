#!/usr/bin/env swift

import CryptoKit
import Darwin
import Foundation

private struct PrivateKeyFile: Codable {
    let schemaVersion: Int
    let keyID: String
    let privateKey: String
    let publicKey: String
}

private struct PublicKeyEntry: Codable {
    let keyID: String
    let publicKey: String
}

private struct PublicKeyRing: Codable {
    let schemaVersion: Int
    let keys: [PublicKeyEntry]
}

private struct CatalogHeader: Codable {
    let schemaVersion: Int
    let catalogKind: String
    let catalogVersion: Int
}

private struct SignatureMetadata: Codable {
    let schemaVersion: Int
    let catalogKind: String
    let keyID: String
    let algorithm: String
    let sha256: String
    let signature: String
}

private enum ToolError: Error, CustomStringConvertible {
    case usage(String)
    case invalidFile(String)
    case unsafeOutput(String)
    case verification(String)

    var description: String {
        switch self {
        case .usage(let message), .invalidFile(let message), .unsafeOutput(let message),
             .verification(let message):
            return message
        }
    }
}

private struct Arguments {
    let command: String
    let options: [String: String]

    init(_ raw: [String]) throws {
        guard let command = raw.first else {
            throw ToolError.usage(Self.help)
        }
        self.command = command

        var parsed: [String: String] = [:]
        var index = 1
        while index < raw.count {
            let name = raw[index]
            guard name.hasPrefix("--"), index + 1 < raw.count else {
                throw ToolError.usage("Invalid option near '\(name)'.\n\n\(Self.help)")
            }
            parsed[name] = raw[index + 1]
            index += 2
        }
        options = parsed
    }

    func require(_ name: String) throws -> String {
        guard let value = options[name], !value.isEmpty else {
            throw ToolError.usage("Missing required option \(name).\n\n\(Self.help)")
        }
        return value
    }

    static let help = """
    Usage:
      scripts/catalog-signing.swift generate-key --key-id <id> --private-key <outside-repo-path>
      scripts/catalog-signing.swift print-public-key --private-key <path>
      scripts/catalog-signing.swift sign --private-key <path> --catalog <json> --signature <sig-json>
      scripts/catalog-signing.swift verify --keyring <json> --catalog <json> --signature <sig-json>

    Catalog signatures are Ed25519 signatures over the exact catalog file bytes.
    Keep the generated private-key file offline and out of this repository.
    """
}

private enum CatalogSigningTool {
    static func run() {
        do {
            let arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
            switch arguments.command {
            case "generate-key":
                try generateKey(arguments)
            case "print-public-key":
                try printPublicKey(arguments)
            case "sign":
                try sign(arguments)
            case "verify":
                try verify(arguments)
            case "help", "--help", "-h":
                print(Arguments.help)
            default:
                throw ToolError.usage("Unknown command '\(arguments.command)'.\n\n\(Arguments.help)")
            }
        } catch {
            FileHandle.standardError.write(Data("catalog-signing: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func generateKey(_ arguments: Arguments) throws {
        let keyID = try arguments.require("--key-id")
        try validateKeyID(keyID)
        let outputURL = URL(fileURLWithPath: try arguments.require("--private-key"))
            .standardizedFileURL
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw ToolError.unsafeOutput("Refusing to overwrite an existing private-key file")
        }
        guard !isInsideRepository(outputURL) else {
            throw ToolError.unsafeOutput("Private-key output must be outside the repository")
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        let file = PrivateKeyFile(
            schemaVersion: 1,
            keyID: keyID,
            privateKey: privateKey.rawRepresentation.base64EncodedString(),
            publicKey: privateKey.publicKey.rawRepresentation.base64EncodedString()
        )
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try encoded(file, pretty: true).write(to: outputURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: outputURL.path)

        print("Generated Ed25519 catalog key '\(keyID)'.")
        print("Public key: \(file.publicKey)")
        print("Back up the private-key file offline; it cannot be recovered from the public key.")
    }

    private static func printPublicKey(_ arguments: Arguments) throws {
        let file = try loadPrivateKey(at: try arguments.require("--private-key"))
        print("\(file.keyID) \(file.publicKey)")
    }

    private static func sign(_ arguments: Arguments) throws {
        let keyFile = try loadPrivateKey(at: try arguments.require("--private-key"))
        guard let rawPrivateKey = Data(base64Encoded: keyFile.privateKey),
              let declaredPublicKey = Data(base64Encoded: keyFile.publicKey) else {
            throw ToolError.invalidFile("Private-key file contains invalid Base64")
        }
        let privateKey: Curve25519.Signing.PrivateKey
        do {
            privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawPrivateKey)
        } catch {
            throw ToolError.invalidFile("Private-key file contains an invalid Ed25519 key")
        }
        guard privateKey.publicKey.rawRepresentation == declaredPublicKey else {
            throw ToolError.invalidFile("Private-key file public/private values do not match")
        }

        let catalogURL = URL(fileURLWithPath: try arguments.require("--catalog"))
        let signatureURL = URL(fileURLWithPath: try arguments.require("--signature"))
        let catalogData = try boundedData(at: catalogURL, maximumBytes: 512 * 1_024)
        let header = try decodeCatalogHeader(catalogData)
        let digest = sha256Hex(catalogData)
        let signature = try privateKey.signature(for: catalogData).base64EncodedString()
        let metadata = SignatureMetadata(
            schemaVersion: 1,
            catalogKind: header.catalogKind,
            keyID: keyFile.keyID,
            algorithm: "ed25519",
            sha256: digest,
            signature: signature
        )
        try FileManager.default.createDirectory(
            at: signatureURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoded(metadata, pretty: true).write(to: signatureURL, options: .atomic)
        print("Signed \(header.catalogKind) catalog v\(header.catalogVersion) with key '\(keyFile.keyID)'.")
        print("SHA-256: \(digest)")
    }

    private static func verify(_ arguments: Arguments) throws {
        let keyringURL = URL(fileURLWithPath: try arguments.require("--keyring"))
        let catalogURL = URL(fileURLWithPath: try arguments.require("--catalog"))
        let signatureURL = URL(fileURLWithPath: try arguments.require("--signature"))
        let keyring: PublicKeyRing = try decode(
            boundedData(at: keyringURL, maximumBytes: 32 * 1_024),
            description: "public keyring"
        )
        guard keyring.schemaVersion == 1 else {
            throw ToolError.verification("Unsupported public keyring schema")
        }
        let catalogData = try boundedData(at: catalogURL, maximumBytes: 512 * 1_024)
        let signatureData = try boundedData(at: signatureURL, maximumBytes: 4 * 1_024)
        let header = try decodeCatalogHeader(catalogData)
        let metadata: SignatureMetadata = try decode(signatureData, description: "signature metadata")

        guard metadata.schemaVersion == 1,
              metadata.algorithm == "ed25519",
              metadata.catalogKind == header.catalogKind else {
            throw ToolError.verification("Signature metadata does not match the catalog contract")
        }
        guard metadata.sha256 == sha256Hex(catalogData) else {
            throw ToolError.verification("Catalog SHA-256 does not match the signed digest")
        }
        guard let entry = keyring.keys.first(where: { $0.keyID == metadata.keyID }) else {
            throw ToolError.verification("Signature uses an unknown key identifier")
        }
        guard let rawPublicKey = Data(base64Encoded: entry.publicKey),
              let signature = Data(base64Encoded: metadata.signature) else {
            throw ToolError.verification("Signature or public key is not valid Base64")
        }
        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: rawPublicKey)
        } catch {
            throw ToolError.verification("Keyring contains an invalid Ed25519 public key")
        }
        guard publicKey.isValidSignature(signature, for: catalogData) else {
            throw ToolError.verification("Ed25519 signature verification failed")
        }
        print("Verified \(header.catalogKind) catalog v\(header.catalogVersion) with key '\(entry.keyID)'.")
        print("SHA-256: \(metadata.sha256)")
    }

    private static func loadPrivateKey(at path: String) throws -> PrivateKeyFile {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard !isInsideRepository(url) else {
            throw ToolError.invalidFile("Refusing to use a private key stored inside the repository")
        }
        let file: PrivateKeyFile = try decode(
            boundedData(at: url, maximumBytes: 4 * 1_024),
            description: "private-key file"
        )
        guard file.schemaVersion == 1 else {
            throw ToolError.invalidFile("Unsupported private-key file schema")
        }
        try validateKeyID(file.keyID)
        return file
    }

    private static func decodeCatalogHeader(_ data: Data) throws -> CatalogHeader {
        let header: CatalogHeader = try decode(data, description: "catalog")
        guard header.schemaVersion == 1,
              !header.catalogKind.isEmpty,
              header.catalogVersion > 0 else {
            throw ToolError.invalidFile("Catalog header is invalid")
        }
        return header
    }

    private static func validateKeyID(_ keyID: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard keyID.count <= 64,
              !keyID.isEmpty,
              keyID.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ToolError.invalidFile("Key identifier must use 1-64 ASCII letters, digits, '-' or '_'")
        }
    }

    private static func boundedData(at url: URL, maximumBytes: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let size = values.fileSize,
              size <= maximumBytes else {
            throw ToolError.invalidFile("Input file is missing, not regular, or exceeds \(maximumBytes) bytes")
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    private static func decode<Value: Decodable>(_ data: Data, description: String) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw ToolError.invalidFile("Could not decode \(description)")
        }
    }

    private static func encoded<Value: Encodable>(_ value: Value, pretty: Bool) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty
            ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func isInsideRepository(_ url: URL) -> Bool {
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath()
        return candidate.path == repository.path || candidate.path.hasPrefix(repository.path + "/")
    }
}

CatalogSigningTool.run()
