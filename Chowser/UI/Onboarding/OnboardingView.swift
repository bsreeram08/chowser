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
        ZStack {
            // Premium background
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            // Subtle glow effect
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
                
            Group {
                switch currentStep {
                case 0:
                    WelcomeStepView(nextAction: goNext)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                case 1:
                    if isDefaultBrowser {
                        Color.clear.onAppear {
                            DispatchQueue.main.async { goNext() }
                        }
                    } else {
                        DefaultBrowserStepView(nextAction: goNext)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                case 2:
                    BrowsersStepView(nextAction: goNext)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                case 3:
                    if SandboxBookmarkManager.shared.hasBookmark {
                        Color.clear.onAppear {
                            DispatchQueue.main.async { goNext() }
                        }
                    } else {
                        ProfileAccessStepView(nextAction: goNext)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    }
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
        }
        .frame(width: 500, height: 600)
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
