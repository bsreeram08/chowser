import SwiftUI
import AppKit

struct OnboardingView: View {
    var browserManager = BrowserManager.shared
    let onOpenSettings: () -> Void
    let onFinish: () -> Void

    @State private var isDefaultBrowser = BrowserManager.isDefaultBrowser()

    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    private var isInstalledInApplications: Bool {
        let path = Bundle.main.bundleURL.path
        return path.hasPrefix("/Applications/") || path.contains("/Applications/")
    }

    private var isSetupReady: Bool {
        isDefaultBrowser && !browserManager.configuredBrowsers.isEmpty
    }

    private var completedStepCount: Int {
        var count = 0
        if isInstalledInApplications { count += 1 }
        if isDefaultBrowser { count += 1 }
        if !browserManager.configuredBrowsers.isEmpty { count += 1 }
        if browserManager.launchAtLogin { count += 1 }
        return count
    }

    var body: some View {
        HStack(spacing: 0) {
            heroPanel
            Divider()
                .opacity(0.35)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        progressCard
                        installationCard
                        defaultBrowserCard
                        browserConfigCard
                        startupCard
                    }
                    .padding(20)
                }

                Divider()
                    .opacity(0.35)
                footer
            }
        }
        .frame(width: 700, height: 520)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.98),
                    Color(nsColor: .underPageBackgroundColor).opacity(0.94),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            refreshDefaultBrowserStatus()
        }
        .accessibilityIdentifier("onboarding.root")
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(nsImage: BrowserManager.currentAppIcon())
                .resizable()
                .interpolation(.high)
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Chowser")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("Fast browser switching for every link.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Version \(appVersion)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 9) {
                Label("Set as your default browser", systemImage: "network")
                Label("Choose browsers and shortcuts", systemImage: "globe")
                Label("Enable startup behavior", systemImage: "power")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .frame(maxWidth: 230, maxHeight: .infinity, alignment: .topLeading)
        .background(heroBackground)
    }

    @ViewBuilder
    private var heroBackground: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle()
                .fill(.white.opacity(0.03))
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Setup Progress")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(completedStepCount)/4")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(completedStepCount), total: 4.0)
                .tint(isSetupReady ? .green : .accentColor)

            Text(isSetupReady ? "You are ready to go." : "Complete the steps below to finish setup.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .modifier(OnboardingCardModifier())
    }

    private var installationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Install in Applications", systemImage: "externaldrive.connected.to.line.below")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if isInstalledInApplications {
                    stepStatusBadge(title: "Done", color: .green)
                } else {
                    stepStatusBadge(title: "Needs Action", color: .orange)
                }
            }

            if isInstalledInApplications {
                Label("Installed in /Applications.", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Text("Move Chowser to /Applications and allow it in Privacy & Security for reliable startup.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Open Applications Folder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)

                    Button("Reveal Current App") {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)

                    Button("Open Privacy & Security") {
                        openPrivacyAndSecuritySettings()
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)
                }
            }
        }
        .modifier(OnboardingCardModifier())
    }

    private var defaultBrowserCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Default Browser", systemImage: "network")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if isDefaultBrowser {
                    stepStatusBadge(title: "Done", color: .green)
                } else {
                    stepStatusBadge(title: "Required", color: .orange)
                }
            }

            Text(isDefaultBrowser ? "Chowser is currently your default browser." : "Set Chowser as default to show the quick switcher on every link click.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if isDefaultBrowser {
                    Button("Default Browser Set") {}
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.small)
                        .disabled(true)
                } else {
                    Button("Set as Default Browser") {
                        BrowserManager.setAsDefaultBrowser()
                        refreshDefaultBrowserStatus()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .controlSize(.small)
                }

                if isDefaultBrowser {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .modifier(OnboardingCardModifier())
    }

    private var browserConfigCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Browser Configuration", systemImage: "globe")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                stepStatusBadge(title: browserManager.configuredBrowsers.isEmpty ? "Required" : "Done", color: browserManager.configuredBrowsers.isEmpty ? .orange : .green)
            }

            Text("Add, remove, and reorder browsers. In the picker, shortcuts are keys 1...9. You can also set Rules in Settings for automatic routing.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button("Open Browser Settings") {
                onOpenSettings()
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .controlSize(.small)
        }
        .modifier(OnboardingCardModifier())
    }

    private var startupCard: some View {
        @Bindable var manager = browserManager

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Startup", systemImage: "power")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                stepStatusBadge(title: manager.launchAtLogin ? "Enabled" : "Optional", color: manager.launchAtLogin ? .green : .secondary)
            }

            Toggle("Launch Chowser at login", isOn: $manager.launchAtLogin)
                .toggleStyle(.switch)
                .font(.system(size: 12))
        }
        .modifier(OnboardingCardModifier())
    }

    private var footer: some View {
        HStack {
            Button("Not Now") {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.regular)
            .accessibilityIdentifier("onboarding.notNowButton")

            Spacer()

            Button(isSetupReady ? "Finish Setup" : "Finish Anyway") {
                onFinish()
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .keyboardShortcut(.defaultAction)
            .controlSize(.regular)
            .accessibilityIdentifier("onboarding.finishButton")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func refreshDefaultBrowserStatus() {
        Task { @MainActor in
            isDefaultBrowser = BrowserManager.isDefaultBrowser()
            guard !isDefaultBrowser else { return }

            for _ in 0..<6 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                isDefaultBrowser = BrowserManager.isDefaultBrowser()
                if isDefaultBrowser {
                    break
                }
            }
        }
    }

    private func openPrivacyAndSecuritySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?General",
            "x-apple.systempreferences:com.apple.preference.security",
        ]

        for rawValue in urls {
            if let url = URL(string: rawValue), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func stepStatusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct OnboardingCardModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .padding(12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.8)
                )
        } else {
            content
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.06))
                        .stroke(.white.opacity(0.08), lineWidth: 0.8)
                )
        }
    }
}

#Preview {
    OnboardingView(onOpenSettings: {}, onFinish: {})
}
