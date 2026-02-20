import Foundation
import AppKit
import Combine
import ServiceManagement

struct BrowserConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var bundleId: String // e.g. "com.apple.Safari"
    var shortcutKey: String // "1", "2", etc
}

class BrowserManager: ObservableObject {
    static let shared = BrowserManager()
    
    @Published var configuredBrowsers: [BrowserConfig] = [] {
        didSet {
            save()
        }
    }
    
    @Published var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin()
        }
    }
    
    @Published var currentURL: URL?
    
    let defaultsKey = "configuredBrowsers"
    let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    func load() {
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([BrowserConfig].self, from: data) {
            configuredBrowsers = decoded
        } else {
            // Default setup if nothing is saved
            configuredBrowsers = [
                BrowserConfig(name: "Safari", bundleId: "com.apple.Safari", shortcutKey: "1")
            ]
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(configuredBrowsers) {
            defaults.set(encoded, forKey: defaultsKey)
        }
    }
    
    // MARK: - Launch at Login
    
    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    
    // MARK: - Default Browser
    
    static func setAsDefaultBrowser() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        
        let workspace = NSWorkspace.shared
        // Use the modern API to prompt the user
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            workspace.setDefaultApplication(at: url, toOpenURLsWithScheme: "http") { error in
                if let error = error {
                    print("Failed to set default for http: \(error)")
                }
            }
            workspace.setDefaultApplication(at: url, toOpenURLsWithScheme: "https") { error in
                if let error = error {
                    print("Failed to set default for https: \(error)")
                }
            }
        }
    }
    
    static func isDefaultBrowser() -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let defaultHandler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!),
              let defaultBundle = Bundle(url: defaultHandler)?.bundleIdentifier else {
            return false
        }
        return defaultBundle == bundleId
    }
    
    // MARK: - Installed Browsers
    
    static func getInstalledBrowsers() -> [(name: String, bundleId: String, iconURL: URL?)] {
        guard let dummyURL = URL(string: "https://example.com") else { return [] }
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: dummyURL)
        
        var browsers: [(String, String, URL?)] = []
        for url in appURLs {
            if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                           (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                           url.deletingPathExtension().lastPathComponent
                browsers.append((name, bundleId, url))
            }
        }
        
        // Filter out Chowser itself
        let myBundleId = Bundle.main.bundleIdentifier ?? ""
        return browsers.filter { $0.1 != myBundleId && !$0.1.contains("apple.Safari.WebApp") }.sorted { $0.0 < $1.0 }
    }
}
