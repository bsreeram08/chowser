import Foundation

class DomainFrequencyTracker {
    static let shared = DomainFrequencyTracker()
    
    private let userDefaultsKey = "DomainFrequencyStats"
    private let maxEntries = 100
    private let suggestionThreshold = 30
    
    private init() {}
    
    /// Records a click for a domain and browser combination.
    func record(domain: String, browserBundleID: String) {
        var stats = getStats()
        
        var domainStats = stats[domain] ?? [:]
        let currentCount = domainStats[browserBundleID] ?? 0
        domainStats[browserBundleID] = currentCount + 1
        
        stats[domain] = domainStats
        
        // Maintain size limit
        if stats.count > maxEntries {
            // Remove the least recently updated entry or just any entry if we don't track recency
            // For simplicity, we'll just remove a random one or the one with lowest total counts
            if let leastFrequentDomain = stats.keys.first {
                stats.removeValue(forKey: leastFrequentDomain)
            }
        }
        
        saveStats(stats)
    }
    
    /// Returns a list of domains that have reached the threshold for a specific browser.
    func getSuggestions() -> [(domain: String, browserBundleID: String)] {
        let stats = getStats()
        var suggestions: [(String, String)] = []
        
        for (domain, browsers) in stats {
            for (bundleID, count) in browsers {
                if count >= suggestionThreshold {
                    suggestions.append((domain, bundleID))
                }
            }
        }
        
        return suggestions
    }
    
    private func getStats() -> [String: [String: Int]] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let stats = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else {
            return [:]
        }
        return stats
    }
    
    private func saveStats(_ stats: [String: [String: Int]]) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
