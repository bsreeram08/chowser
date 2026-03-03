import Foundation

class DomainFrequencyTracker {
    static let shared = DomainFrequencyTracker()

    private let userDefaultsKey = "DomainFrequencyStats"
    private let maxEntries = 100
    private let suggestionThreshold = 30

    private var cachedStats: [String: [String: Int]] = [:]

    private init() {
        cachedStats = loadFromDefaults()
    }

    /// Records a click for a domain and browser combination.
    func record(domain: String, browserBundleID: String) {
        var domainStats = cachedStats[domain] ?? [:]
        domainStats[browserBundleID] = (domainStats[browserBundleID] ?? 0) + 1
        cachedStats[domain] = domainStats

        if cachedStats.count > maxEntries {
            if let firstKey = cachedStats.keys.first {
                cachedStats.removeValue(forKey: firstKey)
            }
        }

        let snapshot = cachedStats
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: self.userDefaultsKey)
            }
        }
    }

    /// Returns a list of domains that have reached the threshold for a specific browser.
    func getSuggestions() -> [(domain: String, browserBundleID: String)] {
        var suggestions: [(String, String)] = []

        for (domain, browsers) in cachedStats {
            for (bundleID, count) in browsers {
                if count >= suggestionThreshold {
                    suggestions.append((domain, bundleID))
                }
            }
        }

        return suggestions
    }

    /// Returns click counts per browser bundle ID for a given domain.
    func stats(for domain: String) -> [String: Int] {
        return cachedStats[domain.lowercased()] ?? [:]
    }

    private func loadFromDefaults() -> [String: [String: Int]] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let stats = try? JSONDecoder().decode([String: [String: Int]].self, from: data) else {
            return [:]
        }
        return stats
    }
}
