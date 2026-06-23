import Testing
import Foundation
@testable import Chowser

struct BrowserLaunchTests {
    private let url = URL(string: "https://example.com/path?q=1")!
    private let appURL = URL(fileURLWithPath: "/Applications/Test Browser.app")

    @Test("Chromium-based browsers use --profile-directory without URL app argument")
    func chromiumProfileArguments() {
        let browsers = [
            "com.google.Chrome",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.vivaldi.Vivaldi",
            "company.thebrowser.Browser",
            "company.thebrowser.browser",
            "company.thebrowser.dia",
            "org.chromium.Chromium",
            "com.operasoftware.Opera"
        ]

        for bundleID in browsers {
            let info = BrowserManager.launchInfo(forBundleID: bundleID, profile: "Profile 1", customArguments: nil, url: url)
            #expect(info != nil, "Should support \(bundleID)")
            #expect(info?.type == "chromium")
            #expect(info?.arguments == ["--profile-directory=Profile 1"])
            #expect(info?.arguments.contains(url.absoluteString) == false)
        }
    }

    @Test("Chromium private arguments cover default profile and profile combinations")
    func chromiumPrivateArguments() {
        let privateInfo = BrowserManager.launchInfo(
            forBundleID: "com.google.Chrome",
            profile: nil,
            customArguments: nil,
            url: url,
            usePrivateMode: true
        )
        #expect(privateInfo?.type == "chromium-private")
        #expect(privateInfo?.arguments == ["--incognito"])

        let privateProfileInfo = BrowserManager.launchInfo(
            forBundleID: "com.google.Chrome",
            profile: "Profile 1",
            customArguments: nil,
            url: url,
            usePrivateMode: true
        )
        #expect(privateProfileInfo?.type == "chromium")
        #expect(privateProfileInfo?.arguments == ["--incognito", "--profile-directory=Profile 1"])
    }

    @Test("Firefox-based browsers use -P without URL app argument")
    func firefoxProfileArguments() {
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
            #expect(info?.arguments == ["-P", "Work"])
            #expect(info?.arguments.contains(url.absoluteString) == false)
        }
    }

    @Test("Firefox private arguments cover default profile and profile combinations")
    func firefoxPrivateArguments() {
        let privateInfo = BrowserManager.launchInfo(
            forBundleID: "org.mozilla.firefox",
            profile: nil,
            customArguments: nil,
            url: url,
            usePrivateMode: true
        )
        #expect(privateInfo?.type == "firefox-private")
        #expect(privateInfo?.arguments == ["-private"])

        let privateProfileInfo = BrowserManager.launchInfo(
            forBundleID: "org.mozilla.firefox",
            profile: "Work",
            customArguments: nil,
            url: url,
            usePrivateMode: true
        )
        #expect(privateProfileInfo?.type == "firefox")
        #expect(privateProfileInfo?.arguments == ["-private", "-P", "Work"])
    }

    @Test("Custom arguments preserve profile names with spaces")
    func customArgumentsPreserveProfileSpaces() {
        let info = BrowserManager.launchInfo(
            forBundleID: "com.custom.browser",
            profile: "Profile 1",
            customArguments: "--flag --profile-directory={profile}",
            url: url
        )

        #expect(info?.type == "custom")
        #expect(info?.arguments == ["--flag", "--profile-directory=Profile 1"])
    }

    @Test("Custom arguments support quoted values and URL placeholders")
    func customArgumentsSupportQuotedValuesAndURLPlaceholder() {
        let info = BrowserManager.launchInfo(
            forBundleID: "com.custom.browser",
            profile: "MyProfile",
            customArguments: "--name 'Work Profile' {url} --profile={profile}",
            url: url
        )

        #expect(info?.type == "custom")
        #expect(info?.arguments == ["--name", "Work Profile", url.absoluteString, "--profile=MyProfile"])
    }

    @Test("Safari and other browsers do not generate special app arguments")
    func defaultArguments() {
        let browsers = [
            "com.apple.Safari",
            "com.apple.Safari.WebApp.some-id"
        ]

        for bundleID in browsers {
            let info = BrowserManager.launchInfo(forBundleID: bundleID, profile: "Work", customArguments: nil, url: url)
            #expect(info == nil)
        }
    }

    @Test("Direct launch plan delivers URL once before args through /usr/bin/open")
    func directLaunchPlanLowersToOpenToolArguments() {
        let plan = BrowserManager.launchPlan(
            forBundleID: "com.google.Chrome",
            appURL: appURL,
            url: url,
            profile: "Profile 1",
            customArguments: nil,
            mode: .directDownload
        )

        #expect(plan.applicationArgumentsSupported)
        #expect(plan.usesDirectOpenTool)
        #expect(plan.documentURLs == [url])
        #expect(plan.requestedApplicationArguments == ["--profile-directory=Profile 1"])
        #expect(plan.deliveredApplicationArguments == ["--profile-directory=Profile 1"])
        #expect(plan.directOpenArguments == ["-n", "-a", appURL.path, url.absoluteString, "--args", "--profile-directory=Profile 1"])
    }

    @Test("Direct launch plan filters custom URL app arguments to avoid duplicate URL delivery")
    func directLaunchPlanFiltersCustomURLArgument() {
        let plan = BrowserManager.launchPlan(
            forBundleID: "com.custom.browser",
            appURL: appURL,
            url: url,
            profile: "Profile 1",
            customArguments: "{url} --profile-directory={profile}",
            mode: .directDownload
        )

        #expect(plan.requestedApplicationArguments == [url.absoluteString, "--profile-directory=Profile 1"])
        #expect(plan.deliveredApplicationArguments == ["--profile-directory=Profile 1"])
        #expect(plan.directOpenArguments == ["-n", "-a", appURL.path, url.absoluteString, "--args", "--profile-directory=Profile 1"])
    }

    @Test("App Store launch plan delivers profile arguments via NSWorkspace (not the direct-open tool)")
    func appStoreLaunchPlanDeliversProfileArguments() {
        let plan = BrowserManager.launchPlan(
            forBundleID: "com.google.Chrome",
            appURL: appURL,
            url: url,
            profile: "Profile 1",
            customArguments: nil,
            usePrivateMode: false, // private mode stays gated off in App Store builds
            mode: .appStoreSandbox
        )

        #expect(plan.applicationArgumentsSupported)
        #expect(!plan.usesDirectOpenTool) // sandbox never shells out to /usr/bin/open
        #expect(plan.documentURLs == [url])
        #expect(plan.deliveredApplicationArguments == ["--profile-directory=Profile 1"])
        #expect(plan.createsNewApplicationInstance)
    }

    @Test("Other browsers use reliable NSWorkspace document opening without special args")
    func otherBrowserLaunchPlanUsesDocumentOpenOnly() {
        let plan = BrowserManager.launchPlan(
            forBundleID: "com.apple.Safari",
            appURL: appURL,
            url: url,
            profile: nil,
            customArguments: nil,
            usePrivateMode: true,
            mode: .directDownload
        )

        #expect(plan.applicationArgumentsSupported)
        #expect(!plan.usesDirectOpenTool)
        #expect(plan.documentURLs == [url])
        #expect(plan.requestedApplicationArguments.isEmpty)
        #expect(plan.deliveredApplicationArguments.isEmpty)
    }

    @Test("Single-instance browsers do not request a new application instance")
    func singleInstanceBrowsersDisableNewInstance() {
        let singleInstanceBundleIDs = [
            "company.thebrowser.Browser",
            "company.thebrowser.browser",
            "company.thebrowser.dia",
            "app.zen-browser.zen"
        ]

        for bundleID in singleInstanceBundleIDs {
            let plan = BrowserManager.launchPlan(
                forBundleID: bundleID,
                appURL: appURL,
                url: url,
                profile: "Profile 1",
                customArguments: nil,
                mode: .directDownload
            )
            #expect(!plan.createsNewApplicationInstance, "Should not use -n for \(bundleID)")
            #expect(plan.directOpenArguments.first != "-n")
        }
    }
}
