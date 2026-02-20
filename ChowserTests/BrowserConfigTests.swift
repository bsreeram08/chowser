import Testing
import Foundation
@testable import Chowser

// MARK: - BrowserConfig Model Tests

struct BrowserConfigTests {
    
    // MARK: - Initialization
    
    @Test("Default initialization creates valid config")
    func defaultInit() {
        let config = BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
        
        #expect(config.name == "Safari")
        #expect(config.bundleId == "com.apple.Safari")
        #expect(config.shortcutKey == "1")
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
        let original = BrowserConfig(name: "Chrome", bundleId: "com.google.Chrome", shortcutKey: "2")
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserConfig.self, from: data)
        
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.bundleId == original.bundleId)
        #expect(decoded.shortcutKey == original.shortcutKey)
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
}
