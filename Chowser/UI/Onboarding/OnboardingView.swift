//
//  OnboardingView.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI

/// First launch is one screen: most people skip onboarding, so everything else
/// (browsers, profiles, App Store settings) is set up automatically and the rest is
/// taught in context. The only thing that needs the user is the default-browser switch.
struct OnboardingView: View {
    /// Called with whether to bring over the App Store version's settings.
    let onComplete: (_ importFromAppStore: Bool) -> Void

    @State private var isDefaultBrowser = BrowserManager.isDefaultBrowser()
    @State private var hasAppStoreInstall = BrowserManager.hasAppStoreInstallPreferences
    @State private var importFromAppStore = true
    @State private var detectedBrowserNames: [String] = []

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Every link, in the right browser")
                    .font(.system(size: 22, weight: .bold))
                Text("Chowser opens links in the browser and profile you choose. When it isn't sure, it asks with a quick picker.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                if !detectedBrowserNames.isEmpty {
                    Label(detectedBrowsersSummary, systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.multicolor)
                }
                if hasAppStoreInstall {
                    Toggle("Bring over browsers and rules from the App Store version", isOn: $importFromAppStore)
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("onboarding.importFromAppStore")
                }
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10, style: .continuous))

            VStack(spacing: 8) {
                if isDefaultBrowser {
                    Button("Done") { onComplete(importFromAppStore && hasAppStoreInstall) }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("onboarding.done")
                    Text("Chowser is already your default browser.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Button("Make Chowser my default browser") {
                        BrowserManager.setAsDefaultBrowser()
                        onComplete(importFromAppStore && hasAppStoreInstall)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboarding.setDefault")

                    Button("Not now") { onComplete(importFromAppStore && hasAppStoreInstall) }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("onboarding.notNow")
                }
            }

            Text("Everything here can be changed later in Settings.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            detectedBrowserNames = BrowserManager.getInstalledBrowsers().map(\.name)
        }
    }

    private var detectedBrowsersSummary: String {
        let names = detectedBrowserNames
        switch names.count {
        case 1: return "Found \(names[0]) on your Mac"
        case 2: return "Found \(names[0]) and \(names[1]) on your Mac"
        case 3: return "Found \(names[0]), \(names[1]) and \(names[2]) on your Mac"
        default: return "Found \(names[0]), \(names[1]) and \(names.count - 2) more on your Mac"
        }
    }
}

#Preview {
    OnboardingView(onComplete: { _ in })
}
