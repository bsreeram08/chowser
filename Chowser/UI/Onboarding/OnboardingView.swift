//
//  OnboardingView.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentStep: Int = 0
    
    // Detect if the user has already set it as default
    @State private var isDefaultBrowser: Bool = BrowserManager.isDefaultBrowser()
    
    var body: some View {
        Group {
            switch currentStep {
            case 0:
                WelcomeStepView(nextAction: goNext)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            case 1:
                AppModeStepView(manager: BrowserManager.shared, nextAction: goNext)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            case 2:
                if isDefaultBrowser {
                    Color.clear.onAppear {
                        DispatchQueue.main.async { goNext() }
                    }
                } else {
                    DefaultBrowserStepView(nextAction: goNext)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
            case 3:
                BrowsersStepView(nextAction: goNext)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            case 4:
                AISetupStepView(nextAction: goNext)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            case 5:
                RulesStepView(nextAction: goNext)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            case 6:
                FinishStepView(doneAction: onComplete)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
        .frame(width: 500)
        // Fixed vertical, flexible horizontal — exactly the picker's own sizing pattern
        // (ContentView.swift). Height tracks whichever step is showing; the window (via
        // NSHostingView.sizingOptions = [.preferredContentSize] in OnboardingManager)
        // resizes to match, so there's no hardcoded window height to get wrong on a
        // smaller screen.
        .fixedSize(horizontal: false, vertical: true)
        .background {
            // Decoration lives in .background, not as ZStack siblings — background content
            // is sized to MATCH the view it's attached to, so it can never influence the
            // intrinsic size calculation above (a `.ignoresSafeArea()` Color as a ZStack
            // sibling, by contrast, wants to expand to fill all available space, which
            // breaks fixedSize's "size to content" intent).
            ZStack {
                Color(NSColor.windowBackgroundColor)
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .offset(x: -100, y: -100)
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(x: 150, y: 150)
            }
        }
    }
    
    private func goNext() {
        withAnimation {
            currentStep += 1
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
