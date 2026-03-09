import Foundation
import AppKit

/// Manages a security-scoped bookmark for ~/Library/Application Support
/// so the sandboxed App Store build can read browser profile data.
final class SandboxBookmarkManager {

    static let shared = SandboxBookmarkManager()

    private let bookmarkKey = "securityScopedBookmark_AppSupport"
    private var accessedURL: URL?
    private var accessCount = 0

    private init() {}

    // MARK: - Scoped Access

    /// Starts accessing the bookmarked directory. Returns the resolved URL, or nil if unavailable.
    /// Supports nested calls via reference counting.
    func startAccessing() -> URL? {
        if let url = accessedURL {
            accessCount += 1
            return url
        }

        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        guard url.startAccessingSecurityScopedResource() else { return nil }
        accessedURL = url
        accessCount = 1
        return url
    }

    /// Stops accessing the bookmarked directory. Balances a prior `startAccessing()` call.
    func stopAccessing() {
        guard accessCount > 0 else { return }
        accessCount -= 1
        if accessCount == 0, let url = accessedURL {
            url.stopAccessingSecurityScopedResource()
            accessedURL = nil
        }
    }
}
