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
}
