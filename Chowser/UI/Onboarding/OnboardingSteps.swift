//
//  OnboardingSteps.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI
import Combine
import AppKit

// MARK: - Welcome Step
struct WelcomeStepView: View {
    let nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Big beautiful icon
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 120, height: 120)
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
            
            VStack(spacing: 12) {
                Text("Welcome to Chowser")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("The beautifully fast browser chooser for macOS.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - App Mode Step

/// New-feature announcement, same shape whether it's shown during onboarding for a new
/// install or as a standalone one-time screen for an existing install after updating
/// (`OnboardingManager.showAppModeQuestionWindow`) — generic "here's a new setting," not
/// framed around any specific problem it happens to also solve.
struct AppModeStepView: View {
    let manager: BrowserManager
    let nextAction: (ChowserAppMode) -> Void

    @State private var selectedMode: ChowserAppMode

    init(manager: BrowserManager, nextAction: @escaping (ChowserAppMode) -> Void) {
        self.manager = manager
        self.nextAction = nextAction
        self._selectedMode = State(initialValue: manager.appMode)
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "menubar.dock.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.blue.gradient)
                .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 5)

            VStack(spacing: 10) {
                Text("New in Chowser: App Mode")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Choose how Chowser lives on your Mac. You can change this anytime in Settings → General.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                AppModeOptionRow(
                    icon: "dock.rectangle",
                    title: "App",
                    subtitle: "Dock icon, appears in Cmd-Tab.",
                    isSelected: selectedMode == .app
                ) {
                    selectedMode = .app
                }

                AppModeOptionRow(
                    icon: "menubar.rectangle",
                    title: "Menu Bar",
                    subtitle: "No Dock icon, lives in the menu bar only.",
                    isSelected: selectedMode == .menuBar
                ) {
                    selectedMode = .menuBar
                }
            }
            .padding(.horizontal, 40)

            Button(action: {
                nextAction(selectedMode)
            }) {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
        // Same sizing pattern as the picker (ContentView.swift) and OnboardingView: fixed
        // vertical (size to content), flexible horizontal. Needed here directly since this
        // view is also used standalone (OnboardingManager.showAppModeQuestionWindow) without
        // OnboardingView's wrapper.
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Selectable row for a single App Mode choice — replaces a segmented toggle with an
/// explicit, labeled option a user picks (not a switch they flip), reused by both the
/// onboarding step and the Settings row.
struct AppModeOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }
}

// MARK: - Default Browser Step
struct DefaultBrowserStepView: View {
    let nextAction: () -> Void
    @State private var hasClickedSetDefault = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "cursorarrow.click.badge.clock")
                .font(.system(size: 60))
                .foregroundStyle(Color.purple.gradient)
                .shadow(color: Color.purple.opacity(0.3), radius: 10, y: 5)
            
            VStack(spacing: 12) {
                Text("Make it Default")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text(hasClickedSetDefault ? "Great! Now select Chowser in System Settings." : "To intercept your links, Chowser needs to be your default browser. Click below to open System Settings.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    hasClickedSetDefault = true
                    // Try to open System Settings explicitly
                    BrowserManager.setAsDefaultBrowser()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open System Settings")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(hasClickedSetDefault ? Color.green.opacity(0.2) : Color.accentColor.opacity(0.15))
                    .foregroundColor(hasClickedSetDefault ? .green : .accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: nextAction) {
                    Text(hasClickedSetDefault ? "Continue" : "Skip for now")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(hasClickedSetDefault ? Color.accentColor : Color.primary.opacity(0.05))
                        .foregroundColor(hasClickedSetDefault ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if hasClickedSetDefault && BrowserManager.isDefaultBrowser() {
                nextAction()
            }
        }
    }
}

// MARK: - Browsers Step
struct BrowsersStepView: View {
    let nextAction: () -> Void

    @State private var profileAccessStatus = SandboxBookmarkManager.shared.grantStatus
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            HStack(spacing: 20) {
                // Visual representation of browsers
                BrowserCircle(iconName: "safari", shortcut: "1", color: .blue)
                BrowserCircle(iconName: "globe", shortcut: "2", color: .red)
                BrowserCircle(iconName: "network", shortcut: "3", color: .green)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                Text("Browser Detection")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text(BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild
                     ? "Chowser finds installed browsers and supported profiles automatically."
                     : "Chowser finds installed browsers automatically. In App Store builds, profile names are informational because macOS opens only the selected browser app.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
                    
                Text("When the picker pops up, simply press the number key on your keyboard to instantly open the link.")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild
                     ? "Note: Direct profile switching is unsupported for Arc and Dia."
                     : "Profile/private launch arguments are unavailable in App Store builds.")
                    .font(.system(size: 11, weight: .thin))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)

                if profileAccessStatus.needsRecovery {
                    Button(action: grantProfileAccess) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text("Allow Profile Access")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.profileAccess.grantButton")
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    @MainActor
    private func grantProfileAccess() {
        _ = SandboxBookmarkManager.shared.requestApplicationSupportAccess()
        BrowserProfileDetector.clearCache()
        profileAccessStatus = SandboxBookmarkManager.shared.grantStatus
    }
}

// Helper for BrowsersStepView
struct BrowserCircle: View {
    let iconName: String
    let shortcut: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(color.gradient)
            }
            Text("Press \(shortcut)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .customChipSurface(cornerRadius: 999, hoverOpacity: 0.03)
        }
    }
}


// MARK: - AI Setup Step

private let agenticSetupURL = "https://chowser.sreerams.in/agentic-setup.md"

struct AISetupStepView: View {
    let nextAction: () -> Void

    @State private var promptCopied = false
    @State private var fetchedTemplate: String? = nil
    @State private var isFetching = false

    private let server = MCPServer.shared

    /// Full prompt: remote template + API credentials appended.
    private var setupPrompt: String {
        let base = fetchedTemplate ?? """
I have installed Chowser (bundle ID: in.sreerams.Chowser) on my Mac. It's a browser chooser app with an opt-in, localhost-only HTTP API server for configuration.

Your goal is to configure my browsers and routing rules.

0. **Check your tools first**: if you have no shell/filesystem access and no HTTP fetch tool, say so and stop — you can't complete this. If you have HTTP fetch but no filesystem access (e.g. a plain chat app), skip step 3's filesystem scan and ask me for my browsers/profiles directly instead.
1. **Authenticate**: every request needs the exact header `Authorization: Bearer <token>` (the token is below) — no other header name works.
2. **Discover API Schema**: Call `GET /status` — its `endpoints` field lists every available endpoint and required JSON fields for this running version.
3. **Discover Browsers**: Scan my Mac for browsers and profiles (Chrome, Brave, Edge, Vivaldi, Arc, Dia, Opera, Firefox, Zen, Safari), or ask me if you can't scan the filesystem.
4. **Configure**: Use `POST /browsers` to add profiles and `POST /rules` to set routing. Use the credentials below.
5. **Rewrites (optional)**: Offer to open `chowser://settings` so I can review and install signed predefined rewrites in Chowser. Do not copy raw catalog JSON into `POST /rewrites`; that bypasses signature verification and signed provenance.
6. **Confirm**: Show a summary and ask for confirmation before making any changes.

**Note**: Direct profile switching is unsupported for Arc and Dia browsers; do not attempt to configure specific profiles for these apps.
"""
        return """
        \(base)

        ---
        API server: http://localhost:\(server.port)
        Authorization header: Bearer \(server.authToken)
        """
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.purple.gradient)
                    .shadow(color: Color.purple.opacity(0.3), radius: 10, y: 5)

                VStack(spacing: 10) {
                    Text("Set Up with AI")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Start the local-only API server, copy the setup prompt, then paste it into an AI assistant. The API is off by default and requires the token for every request.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Chowser also publishes predefined rewrite rules — browse them") {
                        NSWorkspace.shared.open(RewriteCatalogService.catalogPageURL)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                }

                if server.isRunning {
                    VStack(spacing: 12) {
                        // Status badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                            Text("Running on port \(server.port)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())

                        // Visible prompt card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Setup Prompt")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if isFetching {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                } else {
                                    Button(action: copyPrompt) {
                                        HStack(spacing: 4) {
                                            Image(systemName: promptCopied ? "checkmark" : "doc.on.clipboard")
                                                .contentTransition(.symbolEffect(.replace))
                                            Text(promptCopied ? "Copied!" : "Copy")
                                        }
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(promptCopied ? Color.green : Color.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Text(setupPrompt)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(6)
                                .truncationMode(.tail)
                        }
                        .padding(12)
                        .customCardSurface(cornerRadius: 10)

                    }
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if !server.isRunning {
                    Button(action: startServer) {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack")
                            Text("Start API Server")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: nextAction) {
                    Text(server.isRunning ? "Done, Continue" : "Skip for now")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(server.isRunning ? Color.accentColor : Color.primary.opacity(0.05))
                        .foregroundColor(server.isRunning ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: server.isRunning)
        .onAppear {
            fetchSetupTemplate()
        }
    }

    private func startServer() {
        server.start()
        if server.isRunning && fetchedTemplate == nil {
            fetchSetupTemplate()
        }
    }

    private func fetchSetupTemplate() {
        guard !isFetching else { return }
        isFetching = true
        Task {
            guard let url = URL(string: agenticSetupURL),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let content = String(data: data, encoding: .utf8) else {
                isFetching = false
                return
            }
            fetchedTemplate = content
            isFetching = false
        }
    }

    private func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(setupPrompt, forType: .string)
        withAnimation { promptCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { promptCopied = false }
        }
    }
}


// MARK: - Rules Step
struct RulesStepView: View {
    let nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 15) {
                Image(systemName: "link")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                    
                Image(systemName: "arrow.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.tertiary)
                    
                HStack(spacing: 40) {
                    VStack {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue.gradient)
                        Text("github.com")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    VStack {
                        Image(systemName: "house.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green.gradient)
                        Text("youtube.com")
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
            }
            .padding(.bottom, 10)
            
            VStack(spacing: 12) {
                Text("Smart Routing Rules")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("Never pick a browser twice. Set up rules to automatically route specific websites to specific browsers.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
                    
                Text("E.g., open all Jira links in Chrome Work Profile, and all Netflix links in Safari.")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button(action: nextAction) {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Finish Step
struct FinishStepView: View {
    let doneAction: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.yellow.gradient)
                .shadow(color: Color.yellow.opacity(0.3), radius: 10, y: 5)

            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Chowser is ready. Click any link and the picker will appear.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("Settings will open automatically so you can add browsers and configure rules.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button(action: doneAction) {
                HStack(spacing: 8) {
                    Text("Open Settings")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}


// Previews for fast iteration
#Preview("Welcome") { WelcomeStepView(nextAction: {}) }
#Preview("Default Browser") { DefaultBrowserStepView(nextAction: {}) }
#Preview("Browsers") { BrowsersStepView(nextAction: {}) }
#Preview("AI Setup") { AISetupStepView(nextAction: {}) }
#Preview("Rules") { RulesStepView(nextAction: {}) }
#Preview("Finish") { FinishStepView(doneAction: {}) }
