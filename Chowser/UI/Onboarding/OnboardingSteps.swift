//
//  OnboardingSteps.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI
import Combine

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
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            HStack(spacing: 20) {
                // Visual representation of browsers
                BrowserCircle(iconName: "safari", shortcut: "1", color: .blue)
                BrowserCircle(iconName: "globe", shortcut: "2", color: .red)
                BrowserCircle(iconName: "network", shortcut: "3", color: .green)
            }
            .padding(.bottom, 10)
            
            VStack(spacing: 12) {
                Text("Automatic Detection")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("Chowser automatically finds your installed browsers and their profiles.")
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
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - AI Setup Step

// Known AI desktop app bundle IDs
private let knownAIApps: [(bundleId: String, name: String, icon: String)] = [
    ("com.anthropic.claudefordesktop", "Claude", "brain.head.profile"),
    ("com.openai.chat", "ChatGPT", "message.fill"),
    ("ai.perplexity.mac", "Perplexity", "sparkle"),
    ("com.microsoft.Copilot", "Copilot", "wand.and.stars"),
    ("com.google.Gemini", "Gemini", "sparkles"),
]

struct AISetupStepView: View {
    let nextAction: () -> Void

    @State private var serverStarted = false
    @State private var tokenCopied = false
    @State private var instructionsCopied = false
    @State private var detectedAIApps: [(bundleId: String, name: String, icon: String)] = []

    private var server: MCPServer { MCPServer.shared }

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

                    Text("Let any AI assistant configure your browsers and routing rules via the built-in local API server.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if serverStarted {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("API Server running on port \(server.port)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                        }

                        // Token display
                        VStack(spacing: 6) {
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
                        }

                        // Copy instructions button
                        Button(action: copyInstructions) {
                            HStack(spacing: 6) {
                                Image(systemName: instructionsCopied ? "checkmark" : "doc.on.clipboard.fill")
                                Text(instructionsCopied ? "Copied!" : "Copy Setup Instructions")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(instructionsCopied ? Color.green : Color.accentColor)
                            .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)

                        // Detected AI apps
                        if !detectedAIApps.isEmpty {
                            VStack(spacing: 6) {
                                Text("Open in:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 10) {
                                    ForEach(detectedAIApps, id: \.bundleId) { app in
                                        Button(action: { openAIApp(bundleId: app.bundleId) }) {
                                            HStack(spacing: 5) {
                                                Image(systemName: app.icon)
                                                    .font(.system(size: 11))
                                                Text(app.name)
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if !serverStarted {
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
                    Text(serverStarted ? "Done, Continue" : "Skip for now")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(serverStarted ? Color.accentColor : Color.primary.opacity(0.05))
                        .foregroundColor(serverStarted ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: serverStarted)
        .onAppear { detectAIApps() }
    }

    private func startServer() {
        server.start()
        serverStarted = server.isRunning
    }

    private func copyToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.authToken, forType: .string)
        withAnimation { tokenCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { tokenCopied = false }
        }
    }

    private func copyInstructions() {
        let instructions = """
        I want to configure Chowser (a macOS browser chooser app).
        The local API server is running at http://localhost:\(server.port).
        Auth token for POST/DELETE requests: \(server.authToken).
        Please help me set up my browsers and routing rules.
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(instructions, forType: .string)
        withAnimation { instructionsCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { instructionsCopied = false }
        }
    }

    private func openAIApp(bundleId: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func detectAIApps() {
        detectedAIApps = knownAIApps.filter { app in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleId) != nil
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

                Text("Chowser lives in your menu bar. Click any link and the picker will appear.")
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
