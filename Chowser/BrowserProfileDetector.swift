import Foundation

struct BrowserProfile {
    let id: String
    let name: String
}

enum BrowserProfileDetector {
    
    static func detectProfiles(for bundleId: String) -> [BrowserProfile] {
        if bundleId.contains("Chrome") || bundleId == "com.brave.Browser" || bundleId == "com.microsoft.edgemac" || bundleId == "com.vivaldi.Vivaldi" {
            return detectChromiumProfiles(bundleId: bundleId)
        } else if bundleId == "org.mozilla.firefox" || bundleId == "app.zen-browser.zen" {
            return detectFirefoxProfiles(bundleId: bundleId)
        }
        return []
    }
    
    private static func detectChromiumProfiles(bundleId: String) -> [BrowserProfile] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pathSuffix: String
        switch bundleId {
        case "com.google.Chrome": pathSuffix = "Google/Chrome/Local State"
        case "com.brave.Browser": pathSuffix = "BraveSoftware/Brave-Browser/Local State"
        case "com.microsoft.edgemac": pathSuffix = "Microsoft Edge/Local State"
        case "com.vivaldi.Vivaldi": pathSuffix = "Vivaldi/Local State"
        default: return []
        }
        
        let localStateURL = appSupport.appendingPathComponent(pathSuffix)
        guard let data = try? Data(contentsOf: localStateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: [String: Any]] else {
            return []
        }
        
        var profiles: [BrowserProfile] = []
        for (key, info) in infoCache {
            let name = info["name"] as? String ?? key
            profiles.append(BrowserProfile(id: key, name: name))
        }
        
        return profiles.sorted(by: { $0.name < $1.name })
    }
    
    private static func detectFirefoxProfiles(bundleId: String) -> [BrowserProfile] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pathSuffix = bundleId == "org.mozilla.firefox" ? "Firefox/profiles.ini" : "Zen/profiles.ini"
        let iniURL = appSupport.appendingPathComponent(pathSuffix)
        
        guard let content = try? String(contentsOf: iniURL) else { return [] }
        
        var profiles: [BrowserProfile] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentName: String?
        for line in lines {
            if line.hasPrefix("[Profile") {
                currentName = nil
            } else if line.hasPrefix("Name=") {
                currentName = String(line.dropFirst(5))
                if let name = currentName {
                    profiles.append(BrowserProfile(id: name, name: name))
                }
            }
        }
        
        return profiles.sorted(by: { $0.name < $1.name })
    }
}
