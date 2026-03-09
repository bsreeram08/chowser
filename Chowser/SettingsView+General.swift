import SwiftUI
import AppKit

extension SettingsView {

    var appsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apps")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("Apps registered as URL handlers that you don't want in the browser list.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if browserManager.hiddenBundleIDs.isEmpty {
                            Text("No hidden apps.")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(browserManager.hiddenBundleIDs.sorted()), id: \.self) { bundleId in
                                HStack {
                                    Text(bundleId)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Button {
                                        browserManager.removeHiddenBundleID(bundleId)
                                    } label: {
                                        Image(systemName: "eye")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Show this app in the browser list")
                                }
                            }
                        }

                        Divider()

                        HStack(spacing: 8) {
                            TextField("Bundle ID (e.g. com.example.app)", text: $newHiddenBundleId)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))

                            Button("Hide") {
                                let trimmed = newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                browserManager.addHiddenBundleID(trimmed)
                                newHiddenBundleId = ""
                            }
                            .disabled(newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        Button("Reset to Defaults") {
                            browserManager.resetHiddenBundleIDs()
                        }
                        .font(.system(size: 11))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Hidden Apps")
                }
            }
            .formStyle(.grouped)
        }
    }

    var generalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("General")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("App behavior and system integration.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            Form {
                @Bindable var manager = browserManager

                Section {
                    Toggle("Launch Chowser at login", isOn: $manager.launchAtLogin)
                        .accessibilityHint("When enabled, Chowser starts automatically when you log in")
                } header: {
                    Text("Startup")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Layout", selection: $manager.pickerLayoutMode) {
                            Text("Icons").tag("icons")
                            Text("List").tag("list")
                        }
                        .pickerStyle(.segmented)

                        if manager.pickerLayoutMode == "icons" {
                            Picker("Icon Size", selection: $manager.pickerIconSize) {
                                Text("Small").tag("small")
                                Text("Medium").tag("medium")
                                Text("Large").tag("large")
                            }
                            .pickerStyle(.segmented)

                            Toggle("Show browser name labels", isOn: $manager.pickerShowLabels)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Density", selection: $manager.densityPreference) {
                            Text("Compact").tag("compact")
                            Text("Default").tag("default")
                            Text("Comfortable").tag("comfortable")
                        }
                        .pickerStyle(.segmented)
                        
                        Text("Compact shows more items with less spacing. Comfortable adds extra space and larger text.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                } header: {
                    Text("Picker Appearance")
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Browser")
                                .font(.system(size: 13))

                            if BrowserManager.isDefaultBrowser() {
                                Text("Chowser is your default browser ✓")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.green)
                            } else {
                                Text("Another app is set as default")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Set as Default") {
                            BrowserManager.setAsDefaultBrowser()
                        }
                        .disabled(BrowserManager.isDefaultBrowser())
                        .accessibilityLabel("Set Chowser as the default browser")
                    }
                } header: {
                    Text("System")
                }



                Section {
                    MCPServerSettingsRow()
                } header: {
                    Text("API Server")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reset Chowser setup to a clean state.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Button("Reset to Fresh Setup…", role: .destructive) {
                            showingResetConfirmation = true
                        }
                        .accessibilityIdentifier("settings.resetButton")
                        
                        Divider()
                            .padding(.vertical, 4)
                            
                        Text("Replay the Welcome & Setup experience.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            
                        Button("Replay Onboarding") {
                            OnboardingManager.shared.resetOnboarding()
                            OnboardingManager.shared.showOnboardingWindow {}
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Maintenance")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(nsImage: BrowserManager.currentAppIcon())
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Chowser")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("A browser chooser for macOS")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("Version \(appVersion)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About")
                }
            }
            .formStyle(.grouped)
        }
    }

    var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }
}

// MARK: - MCP Server Settings Row

struct MCPServerSettingsRow: View {
    @State private var tokenCopied = false

    private let server = MCPServer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)

                if server.isRunning {
                    Text("Running on port \(server.port)")
                        .font(.system(size: 13))
                } else {
                    Text("Stopped")
                        .font(.system(size: 13))
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
                .font(.system(size: 11))
            }

            if server.isRunning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auth Token")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(server.authToken)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button(action: copyToken) {
                            Image(systemName: tokenCopied ? "checkmark" : "doc.on.clipboard")
                                .font(.system(size: 11))
                                .foregroundStyle(tokenCopied ? Color.green : Color.secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.05)))

                    Text("Use this token to authenticate POST/DELETE requests to the API.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("The local API server lets AI assistants (Claude, ChatGPT, etc.) configure your browsers and rules.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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

