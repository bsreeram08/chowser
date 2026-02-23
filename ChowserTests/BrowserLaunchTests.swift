import Testing
import Foundation
@testable import Chowser

struct BrowserLaunchTests {
    
    @Test("Chromium-based browsers use --profile-directory")
    func chromiumArguments() {
        let url = URL(string: "https://example.com")!
        let browsers = [
            "com.google.Chrome",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.vivaldi.Vivaldi",
            "company.thebrowser.Browser", // Arc
            "org.chromium.Chromium",
            "com.operasoftware.Opera"
        ]
        
        for bundleID in browsers {
            let info = BrowserManager.launchInfo(forBundleID: bundleID, profile: "Profile 1", customArguments: nil, url: url)
            #expect(info != nil, "Should support \(bundleID)")
            #expect(info?.type == "chromium")
            #expect(info?.arguments.contains("--profile-directory=Profile 1") == true)
            #expect(info?.arguments.contains(url.absoluteString) == true)
        }
    }
    
    @Test("Firefox-based browsers use -P")
    func firefoxArguments() {
        let url = URL(string: "https://example.com")!
        let browsers = [
            "org.mozilla.firefox",
            "app.zen-browser.zen",
            "io.gitlab.librewolf-community.librewolf",
            "net.waterfox.waterfox"
        ]
        
        for bundleID in browsers {
            let info = BrowserManager.launchInfo(forBundleID: bundleID, profile: "Work", customArguments: nil, url: url)
            #expect(info != nil, "Should support \(bundleID)")
            #expect(info?.type == "firefox")
            #expect(info?.arguments.contains("-P") == true)
            #expect(info?.arguments.contains("Work") == true)
            #expect(info?.arguments.contains(url.absoluteString) == true)
        }
    }
    
    @Test("Custom arguments override defaults and support placeholders")
    func customArguments() {
        let url = URL(string: "https://example.com")!
        let bundleID = "com.custom.browser"
        
        // Test basic override
        let info1 = BrowserManager.launchInfo(
            forBundleID: bundleID, 
            profile: "MyProfile", 
            customArguments: "--flag --profile={profile}", 
            url: url
        )
        #expect(info1?.type == "custom")
        #expect(info1?.arguments == ["--flag", "--profile=MyProfile", url.absoluteString])
        
        // Test custom URL placeholder position
        let info2 = BrowserManager.launchInfo(
            forBundleID: bundleID, 
            profile: "MyProfile", 
            customArguments: "{url} --incognito", 
            url: url
        )
        #expect(info2?.arguments == [url.absoluteString, "--incognito"])
    }
    
    @Test("Safari and others return nil (no change to default launch)")
    func defaultArguments() {
        let url = URL(string: "https://example.com")!
        let browsers = [
            "com.apple.Safari",
            "com.apple.Safari.WebApp.some-id"
        ]
        
        for bundleID in browsers {
            let info = BrowserManager.launchInfo(forBundleID: bundleID, profile: "Work", customArguments: nil, url: url)
            #expect(info == nil)
        }
    }
}
