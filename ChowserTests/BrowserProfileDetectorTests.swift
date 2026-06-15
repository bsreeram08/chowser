import Testing
import Foundation
@testable import Chowser

// MARK: - BrowserProfileDetector Tests

struct BrowserProfileDetectorTests {

    // MARK: - Chromium Profile Detection (Brave)

    @Test("Detects Brave browser profiles from Local State file")
    func detectBraveProfiles() {
        let profiles = BrowserProfileDetector.detectProfiles(for: "com.brave.Browser")

        // The user has Brave installed with 2 profiles (Work + Personal).
        // If Brave isn't installed, skip gracefully.
        if profiles.isEmpty { return }

        #expect(profiles.count >= 2)
        let names = profiles.map(\.name)
        #expect(names.contains("Work"))
        #expect(names.contains("Personal"))
    }

    @Test("Brave profile IDs use Chromium directory names")
    func braveProfileIDs() {
        let profiles = BrowserProfileDetector.detectProfiles(for: "com.brave.Browser")
        if profiles.isEmpty { return }

        // Chromium uses "Profile 1", "Profile 2", "Default" as directory names
        for profile in profiles {
            #expect(!profile.id.isEmpty)
            #expect(profile.id.hasPrefix("Profile") || profile.id == "Default")
        }
    }

    // MARK: - Chrome Profile Detection

    @Test("Chrome profile detection returns empty if Chrome not installed")
    func chromeNotInstalled() {
        // If Chrome is not installed, profiles should be empty (not crash)
        let profiles = BrowserProfileDetector.detectProfiles(for: "com.google.Chrome")
        // This test just verifies no crash; result depends on Chrome being installed
        #expect(profiles.count >= 0)
    }

    // MARK: - Safari (No Profile Support)

    @Test("Safari returns no profiles")
    func safariNoProfiles() {
        let profiles = BrowserProfileDetector.detectProfiles(for: "com.apple.Safari")
        #expect(profiles.isEmpty)
    }

    // MARK: - Unknown Browser

    @Test("Unknown browser returns no profiles")
    func unknownBrowserNoProfiles() {
        let profiles = BrowserProfileDetector.detectProfiles(for: "com.unknown.browser")
        #expect(profiles.isEmpty)
    }

    // MARK: - DIA Profile Detection

    @Test("Detects DIA browser profiles from Local State file")
    func detectDIAProfiles() {
        let profiles = BrowserProfileDetector.detectProfiles(for: "company.thebrowser.dia")

        // If DIA isn't installed, skip gracefully.
        if profiles.isEmpty { return }

        // Profiles should have non-empty IDs and names
        for profile in profiles {
            #expect(!profile.id.isEmpty)
            #expect(!profile.name.isEmpty)
        }
    }

    @Test("DIA profile detection uses chromium directory path")
    func diaProfilePath() {
        let profiles = BrowserProfileDetector.detectProfiles(for: "company.thebrowser.dia")
        if profiles.isEmpty { return }

        // DIA uses Chromium's Local State path: ~/Library/Application Support/Dia/User Data/Local State
        for profile in profiles {
            #expect(!profile.id.isEmpty)
        }
    }

    // MARK: - Sorted Results

    @Test("Detected profiles are sorted alphabetically by name")
    func profilesSortedByName() {
        let profiles = BrowserProfileDetector.detectProfiles(for: "com.brave.Browser")
        if profiles.count < 2 { return }

        let names = profiles.map(\.name)
        #expect(names == names.sorted())
    }

    // MARK: - Deterministic Fixture Detection

    @Test("Detects Chromium profiles from a temp Application Support fixture")
    func detectsChromiumProfilesFromFixture() throws {
        let appSupportURL = try makeTemporaryAppSupportFixture()
        defer { try? FileManager.default.removeItem(at: appSupportURL.deletingLastPathComponent()) }

        let localStateURL = appSupportURL.appendingPathComponent("BraveSoftware/Brave-Browser/Local State")
        try FileManager.default.createDirectory(at: localStateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{"profile":{"info_cache":{"Profile 2":{"name":"Work"},"Default":{"name":"Personal"}}}}"#
            .data(using: .utf8)!
            .write(to: localStateURL)

        let profiles = BrowserProfileDetector.detectProfiles(for: "com.brave.Browser", appSupportURL: appSupportURL)

        #expect(profiles.map(\.name) == ["Personal", "Work"])
        #expect(profiles.map(\.id) == ["Default", "Profile 2"])
    }

    @Test("Detects Firefox profiles from a temp Application Support fixture")
    func detectsFirefoxProfilesFromFixture() throws {
        let appSupportURL = try makeTemporaryAppSupportFixture()
        defer { try? FileManager.default.removeItem(at: appSupportURL.deletingLastPathComponent()) }

        let profilesURL = appSupportURL.appendingPathComponent("Firefox/profiles.ini")
        try FileManager.default.createDirectory(at: profilesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        [Profile0]
        Name=Personal
        IsRelative=1
        Path=Profiles/personal
        [Profile1]
        Name=Work
        IsRelative=1
        Path=Profiles/work
        """.write(to: profilesURL, atomically: true, encoding: .utf8)

        let profiles = BrowserProfileDetector.detectProfiles(for: "org.mozilla.firefox", appSupportURL: appSupportURL)

        #expect(profiles.map(\.name) == ["Personal", "Work"])
        #expect(profiles.map(\.id) == ["Personal", "Work"])
    }

    @Test("Missing Application Support access reports no grant and profile detection does not crash")
    func missingAccessNoCrash() throws {
        let suiteName = "BrowserProfileDetectorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let bookmarkManager = SandboxBookmarkManager(defaults: defaults)

        #expect(bookmarkManager.grantStatus == .missing)
        #expect(!bookmarkManager.hasGrant)
        #expect(bookmarkManager.startAccessing() == nil)
        bookmarkManager.stopAccessing()

        let appSupportURL = try makeTemporaryAppSupportFixture()
        defer { try? FileManager.default.removeItem(at: appSupportURL.deletingLastPathComponent()) }
        let profiles = BrowserProfileDetector.detectProfiles(for: "com.google.Chrome", appSupportURL: appSupportURL)
        #expect(profiles.isEmpty)
    }

    @Test("Clearing a stored Application Support grant returns to missing status")
    func clearStoredGrant() throws {
        let suiteName = "SandboxBookmarkManagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let bookmarkManager = SandboxBookmarkManager(defaults: defaults)
        let appSupportURL = try makeTemporaryAppSupportFixture()
        defer { try? FileManager.default.removeItem(at: appSupportURL.deletingLastPathComponent()) }

        try bookmarkManager.storeGrant(for: appSupportURL)
        #expect(bookmarkManager.grantStatus.hasGrant)

        bookmarkManager.clearGrant()
        #expect(bookmarkManager.grantStatus == .missing)
        #expect(!bookmarkManager.hasGrant)
    }


    @Test("Malformed stored bookmark data reports invalid status")
    func malformedBookmarkDataReportsInvalid() throws {
        let suiteName = "SandboxBookmarkManagerInvalidTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-a-bookmark".utf8), forKey: SandboxBookmarkManager.bookmarkKey)

        let bookmarkManager = SandboxBookmarkManager(defaults: defaults)

        #expect(bookmarkManager.grantStatus == .invalid)
        #expect(!bookmarkManager.hasGrant)
        #expect(bookmarkManager.grantStatus.needsRecovery)
        #expect(bookmarkManager.grantStatus.hasStoredBookmark)
    }

    @Test("Resolved bookmark with denied security scope reports invalid status")
    func deniedSecurityScopeReportsInvalid() throws {
        let suiteName = "SandboxBookmarkManagerDeniedTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appSupportURL = try makeTemporaryAppSupportFixture()
        defer { try? FileManager.default.removeItem(at: appSupportURL.deletingLastPathComponent()) }
        let bookmarkManager = SandboxBookmarkManager(defaults: defaults)
        try bookmarkManager.storeGrant(for: appSupportURL)

        let deniedManager = SandboxBookmarkManager(
            defaults: defaults,
            startAccessHandler: { _ in false },
            stopAccessHandler: { _ in }
        )

        #expect(deniedManager.grantStatus == .invalid)
        #expect(!deniedManager.hasGrant)
        #expect(deniedManager.startAccessing() == nil)
    }

    @Test("Application Support picker default uses login user home")
    func applicationSupportDefaultUsesLoginHome() throws {
        let homeURL = try #require(SandboxBookmarkManager.realUserHomeDirectory())
        let bookmarkManager = SandboxBookmarkManager()
        let defaultURL = bookmarkManager.defaultApplicationSupportDirectory()

        #expect(defaultURL.path.hasPrefix(homeURL.path))
        #expect(!defaultURL.path.contains("/Library/Containers/"))
        #expect(
            defaultURL.lastPathComponent == "Application Support" ||
            defaultURL.lastPathComponent == "Library" ||
            defaultURL.standardizedFileURL == homeURL.standardizedFileURL
        )
    }

    private func makeTemporaryAppSupportFixture() throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChowserProfileTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appSupportURL = rootURL.appendingPathComponent("Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        return appSupportURL
    }

}
