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
                
                Text("Chowser runs quietly in your menu bar. Click a link anywhere, and watch it work.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button(action: doneAction) {
                Text("Finish Setup")
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
#Preview("Rules") { RulesStepView(nextAction: {}) }
#Preview("Finish") { FinishStepView(doneAction: {}) }
