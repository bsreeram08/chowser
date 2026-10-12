//
//  OnboardingSteps.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI
import Combine
import AppKit

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
