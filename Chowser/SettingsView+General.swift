import SwiftUI
import AppKit

extension SettingsView {
    var appsSection: some View {
        SettingsDetailScaffold(
            title: "Apps",
            subtitle: "Hide URL handlers that should not appear as browser choices.",
            systemImage: "app.badge",
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsGroup("Hidden Apps", subtitle: "Bundle IDs in this list are excluded from browser discovery.") {
                        if browserManager.hiddenBundleIDs.isEmpty {
                            SettingsRow(title: "No hidden apps", subtitle: "All discovered URL handlers are currently eligible.") {
                                EmptyView()
                            }
                        } else {
                            ForEach(Array(browserManager.hiddenBundleIDs.sorted()), id: \.self) { bundleId in
                                SettingsHiddenAppRow(bundleId: bundleId) {
                                    browserManager.removeHiddenBundleID(bundleId)
                                }
                                if bundleId != browserManager.hiddenBundleIDs.sorted().last {
                                    SettingsDivider()
                                }
                            }
                        }
                    }

                    SettingsGroup("Add Bundle ID", subtitle: "Use this when an app registers as a browser but should stay hidden.") {
                        HStack(spacing: 10) {
                            TextField("com.example.app", text: $newHiddenBundleId)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))

                            Button("Hide") {
                                addHiddenBundleIDFromField()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Reset Defaults") {
                                browserManager.resetHiddenBundleIDs()
                            }
                            .controlSize(.small)
                        }
                        .padding(14)
                    }
                }
            }
        )
    }

    var generalSection: some View {
        @Bindable var manager = browserManager

        return SettingsDetailScaffold(
            title: "General",
            subtitle: "Startup, imports, system integration, and maintenance.",
            systemImage: "gearshape",
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsGroup("Startup") {
                        SettingsRow(
                            title: "Launch Chowser at login",
                            subtitle: "Start automatically when you sign in."
                        ) {
                            Toggle("", isOn: $manager.launchAtLogin)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }

                    SettingsGroup("Import Behavior") {
                        SettingsRow(title: "Skip existing rules", subtitle: "Ignore imported rules that already exist.") {
                            Toggle("", isOn: $manager.skipExistingImportedRules)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityIdentifier("settings.importRulesSkipExisting")
                        }

                        SettingsDivider()

                        SettingsRow(title: "Skip existing browsers", subtitle: "Ignore imported browsers that already exist.") {
                            Toggle("", isOn: $manager.skipExistingImportedBrowsers)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityIdentifier("settings.importBrowsersSkipExisting")
                        }
                    }

                    SettingsGroup("System") {
                        SettingsRow(
                            title: "Default Browser",
                            subtitle: BrowserManager.isDefaultBrowser()
                                ? "Chowser is currently the default browser."
                                : "Set Chowser as the default handler for HTTP and HTTPS links."
                        ) {
                            Button("Set as Default") {
                                BrowserManager.setAsDefaultBrowser()
                            }
                            .disabled(BrowserManager.isDefaultBrowser())
                            .controlSize(.small)
                            .accessibilityLabel("Set Chowser as the default browser")
                        }

                        SettingsDivider()

                        MCPServerSettingsRow()
                    }

                    SettingsGroup("Maintenance") {
                        SettingsRow(
                            title: "Reset Setup",
                            subtitle: "Restore the first-launch state with Safari as option 1."
                        ) {
                            Button("Reset to Fresh Setup…", role: .destructive) {
                                showingResetConfirmation = true
                            }
                            .controlSize(.small)
                            .accessibilityIdentifier("settings.resetButton")
                        }

                        SettingsDivider()

                        SettingsRow(
                            title: "Replay Onboarding",
                            subtitle: "Open the Welcome and Setup flow again."
                        ) {
                            Button("Replay") {
                                OnboardingManager.shared.resetOnboarding()
                                OnboardingManager.shared.showOnboardingWindow {}
                            }
                            .controlSize(.small)
                        }
                    }

                    SettingsGroup("About") {
                        HStack(spacing: 12) {
                            Image(nsImage: BrowserManager.currentAppIcon())
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chowser")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("A browser chooser for macOS")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("Version \(appVersion)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                        .padding(14)
                    }
                }
            }
        )
    }

    var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    private func addHiddenBundleIDFromField() {
        let trimmed = newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        browserManager.addHiddenBundleID(trimmed)
        newHiddenBundleId = ""
    }
}

private struct SettingsHiddenAppRow: View {
    let bundleId: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(bundleId)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button("Show", systemImage: "eye") {
                onRemove()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Show this app in the browser list")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct MCPServerSettingsRow: View {
    @State private var tokenCopied = false

    private let server = MCPServer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Local API Server")
                        .font(.system(size: 13, weight: .medium))

                    Text(server.isRunning ? "Running on port \(server.port)" : "Stopped")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(server.isRunning ? "Stop" : "Start") {
                    if server.isRunning {
                        server.stop()
                    } else {
                        server.start()
                    }
                }
                .controlSize(.small)
            }

            if server.isRunning {
                HStack(spacing: 8) {
                    Text(server.authToken)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    Button(tokenCopied ? "Copied" : "Copy", systemImage: tokenCopied ? "checkmark" : "doc.on.clipboard") {
                        copyToken()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(tokenCopied ? .green : .secondary)
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Text("The server listens only on this Mac and requires the generated bearer token.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: server.isRunning)
    }

    private func copyToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.authToken, forType: .string)
        withAnimation { tokenCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { tokenCopied = false }
        }
    }
}
