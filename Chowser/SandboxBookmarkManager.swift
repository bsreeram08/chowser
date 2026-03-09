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

    // MARK: - Query

    /// Whether a stored bookmark exists and can be resolved.
    var hasBookmark: Bool {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return false }
        var isStale = false
        guard let _ = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return false }
        return true
    }

    // MARK: - Grant Access via NSOpenPanel

    /// Shows an NSOpenPanel for the user to grant access to Application Support.
    /// Returns `true` if the bookmark was successfully saved.
    @discardableResult
    func promptForAccess() -> Bool {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first

        let panel = NSOpenPanel()
        panel.title = "Grant Browser Profile Access"
        panel.message = "Select your Application Support folder so Chowser can detect browser profiles (Chrome, Firefox, etc.)."
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = appSupport
        panel.treatsFilePackagesAsDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return saveBookmark(for: url)
    }

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

        // Refresh stale bookmark
        if isStale {
            _ = saveBookmark(for: url)
        }

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

    // MARK: - Private

    private func saveBookmark(for url: URL) -> Bool {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return false }
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        return true
    }
}
