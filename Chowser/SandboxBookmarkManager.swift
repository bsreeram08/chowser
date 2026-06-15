import Foundation
import AppKit
import Darwin

/// Manages a security-scoped bookmark for ~/Library/Application Support
/// so the sandboxed App Store build can read browser profile data.
final class SandboxBookmarkManager {

    enum GrantStatus: Equatable {
        case missing
        case granted(URL)
        case stale(URL)
        case invalid

        var hasGrant: Bool {
            switch self {
            case .granted, .stale:
                return true
            case .missing, .invalid:
                return false
            }
        }

        var needsRecovery: Bool {
            switch self {
            case .missing, .stale, .invalid:
                return true
            case .granted:
                return false
            }
        }

        var hasStoredBookmark: Bool {
            switch self {
            case .granted, .stale, .invalid:
                return true
            case .missing:
                return false
            }
        }
    }

    enum BookmarkError: Error {
        case unableToCreateBookmark
    }

    static let shared = SandboxBookmarkManager()

    static let bookmarkKey = "securityScopedBookmark_AppSupport"

    private let defaults: UserDefaults
    private let startAccessHandler: (URL) -> Bool
    private let stopAccessHandler: (URL) -> Void
    private var accessedURL: URL?
    private var accessCount = 0

    init(
        defaults: UserDefaults = .standard,
        startAccessHandler: @escaping (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        stopAccessHandler: @escaping (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    ) {
        self.defaults = defaults
        self.startAccessHandler = startAccessHandler
        self.stopAccessHandler = stopAccessHandler
    }

    // MARK: - Grant Status

    var hasGrant: Bool {
        grantStatus.hasGrant
    }

    var grantStatus: GrantStatus {
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return .missing }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return .invalid
        }

        if let accessedURL, accessedURL == url {
            return isStale ? .stale(url) : .granted(url)
        }

        guard startAccessHandler(url) else { return .invalid }
        stopAccessHandler(url)

        return isStale ? .stale(url) : .granted(url)
    }

    func clearGrant() {
        while accessCount > 0 {
            stopAccessing()
        }
        defaults.removeObject(forKey: Self.bookmarkKey)
    }

    // MARK: - Grant Creation

    @MainActor
    func requestApplicationSupportAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Allow Browser Profile Access"
        panel.message = "Choose your Library/Application Support folder so Chowser can read browser profile names."
        panel.prompt = "Allow Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = defaultApplicationSupportDirectory()

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try storeGrant(for: url)
            return true
        } catch {
            print("Chowser: Failed to store Application Support bookmark: \(error.localizedDescription)")
            return false
        }
    }

    func storeGrant(for url: URL) throws {
        let bookmarkOptions: URL.BookmarkCreationOptions = [
            .withSecurityScope,
            .securityScopeAllowOnlyReadAccess,
        ]
        let data = try url.bookmarkData(
            options: bookmarkOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        guard !data.isEmpty else { throw BookmarkError.unableToCreateBookmark }

        while accessCount > 0 {
            stopAccessing()
        }
        defaults.set(data, forKey: Self.bookmarkKey)
    }

    // MARK: - Scoped Access

    /// Starts accessing the bookmarked directory. Returns the resolved URL, or nil if unavailable.
    /// Supports nested calls via reference counting.
    func startAccessing() -> URL? {
        if let url = accessedURL {
            accessCount += 1
            return url
        }

        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        guard startAccessHandler(url) else { return nil }

        if isStale {
            try? storeGrant(for: url)
        }

        accessedURL = url
        accessCount = 1
        return url
    }

    /// Stops accessing the bookmarked directory. Balances a prior `startAccessing()` call.
    func stopAccessing() {
        guard accessCount > 0 else { return }
        accessCount -= 1
        if accessCount == 0, let url = accessedURL {
            stopAccessHandler(url)
            accessedURL = nil
        }
    }

    func defaultApplicationSupportDirectory() -> URL {
        let homeDirectory = Self.realUserHomeDirectory() ?? FileManager.default.homeDirectoryForCurrentUser
        let library = homeDirectory.appendingPathComponent("Library", isDirectory: true)
        let appSupport = library.appendingPathComponent("Application Support", isDirectory: true)

        if FileManager.default.fileExists(atPath: appSupport.path) {
            return appSupport
        }

        if FileManager.default.fileExists(atPath: library.path) {
            return library
        }

        return homeDirectory
    }

    static func realUserHomeDirectory() -> URL? {
        guard let passwd = getpwuid(getuid()),
              let homePath = passwd.pointee.pw_dir else {
            return nil
        }

        let path = String(cString: homePath)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
