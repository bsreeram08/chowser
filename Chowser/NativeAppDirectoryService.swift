import AppKit
import Foundation

struct VerifiedNativeAppDirectory: Identifiable {
    let verified: VerifiedHostedCatalog<NativeAppDirectory>

    init(_ verified: VerifiedHostedCatalog<NativeAppDirectory>) {
        self.verified = verified
    }

    var id: String { "\(directory.catalogVersion):\(provenance.sha256)" }
    var directory: NativeAppDirectory { verified.document }
    var provenance: HostedCatalogProvenance { verified.provenance }
}

@MainActor
protocol NativeAppSystemHandling: AnyObject {
    func handlerBundleIdentifier(for nativeURL: URL) -> String?
    func installedBundleIdentifier(for allowedBundleIdentifiers: [String]) -> String?
    @discardableResult func open(_ nativeURL: URL) -> Bool
}

@MainActor
final class WorkspaceNativeAppSystemHandler: NativeAppSystemHandling {
    static let shared = WorkspaceNativeAppSystemHandler()

    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func handlerBundleIdentifier(for nativeURL: URL) -> String? {
        guard let appURL = workspace.urlForApplication(toOpen: nativeURL) else { return nil }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    func installedBundleIdentifier(for allowedBundleIdentifiers: [String]) -> String? {
        allowedBundleIdentifiers.first { workspace.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    @discardableResult
    func open(_ nativeURL: URL) -> Bool {
        workspace.open(nativeURL)
    }
}

@MainActor
final class NativeAppDirectoryService {
    static let shared = NativeAppDirectoryService()

    static let directoryURL = URL(string: "https://chowser.sreerams.in/native-app-directory.json")!
    static let signatureURL = URL(string: "https://chowser.sreerams.in/native-app-directory.sig.json")!

    private let client: HostedCatalogClient
    private let systemHandler: any NativeAppSystemHandling
    private(set) var currentDirectory: VerifiedNativeAppDirectory?

    init(
        client: HostedCatalogClient? = nil,
        systemHandler: (any NativeAppSystemHandling)? = nil
    ) {
        self.client = client ?? Self.makeProductionClient()
        self.systemHandler = systemHandler ?? WorkspaceNativeAppSystemHandler.shared
    }

    private static func makeProductionClient() -> HostedCatalogClient {
        HostedCatalogClient(
            repository: HostedCatalogRepository(
                trust: HostedCatalogTrustConfiguration.production,
                cache: HostedCatalogCache()
            ),
            transport: URLSessionHostedCatalogTransport.shared
        )
    }

    @discardableResult
    func loadLastKnownGood() -> VerifiedNativeAppDirectory? {
        guard let verified = try? client.repository.lastKnownGood(as: NativeAppDirectory.self) else {
            return nil
        }
        let directory = VerifiedNativeAppDirectory(verified)
        currentDirectory = directory
        return directory
    }

    @discardableResult
    func refresh() async -> VerifiedNativeAppDirectory? {
        do {
            let result = try await client.load(
                endpoint: HostedCatalogEndpoint(
                    documentURL: Self.directoryURL,
                    signatureURL: Self.signatureURL
                ),
                as: NativeAppDirectory.self
            )
            let directory = VerifiedNativeAppDirectory(result.verified)
            currentDirectory = directory
            if result.usedCachedFallback {
                AppLogger.log("NativeApps", "Using the verified last-known-good native app directory")
            }
            return directory
        } catch {
            AppLogger.error(
                "NativeApps",
                "Directory fetch or verification failed (\(String(describing: type(of: error))))"
            )
            return nil
        }
    }

    func installedBundleIdentifier(for entry: NativeAppDirectoryEntry) -> String? {
        systemHandler.installedBundleIdentifier(for: entry.bundleIdentifiers)
    }

    func resolve(
        webURL: URL,
        approvals: [String: String]
    ) -> NativeDeepLinkResolution? {
        guard let directory = currentDirectory?.directory else { return nil }
        return NativeDeepLinkResolver.resolve(
            webURL: webURL,
            in: directory,
            approvedBehaviorSHA256ByEntryID: approvals,
            handlerBundleIdentifier: { [systemHandler] nativeURL in
                systemHandler.handlerBundleIdentifier(for: nativeURL)
            }
        )
    }

    @discardableResult
    func open(_ resolution: NativeDeepLinkResolution) -> Bool {
        guard systemHandler.handlerBundleIdentifier(for: resolution.nativeURL)?
            .caseInsensitiveCompare(resolution.handlerBundleIdentifier) == .orderedSame else {
            AppLogger.error("NativeApps", "Native URL handler changed before launch")
            return false
        }
        let opened = systemHandler.open(resolution.nativeURL)
        AppLogger.log(
            "NativeApps",
            opened
                ? "Opened approved native route '\(resolution.entryID)' in \(resolution.handlerBundleIdentifier)"
                : "Failed to open approved native route '\(resolution.entryID)'"
        )
        return opened
    }
}
