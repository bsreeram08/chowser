import Testing
import Foundation
@testable import Chowser

// MARK: - BrowserConfig Model Tests

struct BrowserConfigTests {
    
    // MARK: - Initialization
    
    @Test("Default initialization creates valid config")
    func defaultInit() {
        let config = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1", profile: "Work")
        
        #expect(config.name == "Safari")
        #expect(config.bundleId == "com.apple.Safari")
        #expect(config.shortcutKey == "1")
        #expect(config.profile == "Work")
        #expect(config.id != UUID()) // Has a unique ID
    }
    
    @Test("Each config gets a unique ID")
    func uniqueIds() {
        let a = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let b = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        
        #expect(a.id != b.id)
    }
    
    // MARK: - Codable
    
    @Test("Encodes and decodes correctly")
    func codableRoundTrip() throws {
        let original = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2", profile: "Default")
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserConfig.self, from: data)
        
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.bundleId == original.bundleId)
        #expect(decoded.shortcutKey == original.shortcutKey)
        #expect(decoded.profile == original.profile)
    }
    
    @Test("Array encodes and decodes correctly")
    func codableArrayRoundTrip() throws {
        let browsers = [
            BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1"),
            BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2"),
            BrowserConfig(name: "Firefox", bundleId: "org.mozilla.firefox", shortcutKey: "3"),
        ]
        
        let data = try JSONEncoder().encode(browsers)
        let decoded = try JSONDecoder().decode([BrowserConfig].self, from: data)
        
        #expect(decoded.count == 3)
        for (original, restored) in zip(browsers, decoded) {
            #expect(original.id == restored.id)
            #expect(original.name == restored.name)
            #expect(original.bundleId == restored.bundleId)
        }
    }
    
    // MARK: - Hashable
    
    @Test("Hashable conformance works for Set usage")
    func hashable() {
        let a = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        let b = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        
        var set = Set<BrowserConfig>()
        set.insert(a)
        set.insert(b)
        set.insert(a) // duplicate
        
        #expect(set.count == 2)
    }
    
    @Test("Equality based on all fields including id")
    func equality() {
        let a = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        var b = a // copy
        
        #expect(a == b)
        
        b.name = "Modified"
        #expect(a != b)
    }

    // MARK: - Add Browser Sheet Candidates

    @Test("Unsupported launch-argument builds collapse profile variants to plain browser apps")
    func unsupportedLaunchArgumentsCollapseProfileVariants() {
        let source: [AddBrowserSheet.BrowserEntry] = [
            (name: "Google Chrome - Personal", bundleId: "com.google.Chrome", profile: "Default", iconURL: nil),
            (name: "Google Chrome - Work", bundleId: "com.google.Chrome", profile: "Profile 1", iconURL: nil),
            (name: "Firefox", bundleId: "org.mozilla.firefox", profile: "default-release", iconURL: nil),
            (name: "Safari", bundleId: "com.apple.Safari", profile: nil, iconURL: nil),
        ]

        let candidates = AddBrowserSheet.browserCandidates(
            for: source,
            configuredIdentities: ["com.apple.Safari|"],
            supportsLaunchArguments: false
        )

        #expect(candidates.count == 2)
        #expect(candidates[0].name == "Google Chrome")
        #expect(candidates[0].bundleId == "com.google.Chrome")
        #expect(candidates[0].profile == nil)
        #expect(candidates[1].name == "Firefox")
        #expect(candidates[1].bundleId == "org.mozilla.firefox")
        #expect(candidates[1].profile == nil)
    }

    @Test("Launch-argument-capable builds keep profile variants selectable")
    func launchArgumentCapableBuildsKeepProfileVariants() {
        let source: [AddBrowserSheet.BrowserEntry] = [
            (name: "Google Chrome - Personal", bundleId: "com.google.Chrome", profile: "Default", iconURL: nil),
            (name: "Google Chrome - Work", bundleId: "com.google.Chrome", profile: "Profile 1", iconURL: nil),
        ]

        let candidates = AddBrowserSheet.browserCandidates(
            for: source,
            configuredIdentities: ["com.google.Chrome|Profile 1"],
            supportsLaunchArguments: true
        )

        #expect(candidates.count == 1)
        #expect(candidates[0].name == "Google Chrome - Personal")
        #expect(candidates[0].bundleId == "com.google.Chrome")
        #expect(candidates[0].profile == "Default")
    }
}
