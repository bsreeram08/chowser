//
//  OnboardingManager.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import AppKit
import SwiftUI

final class OnboardingManager {
    static let shared = OnboardingManager(defaults: AppEnvironment.makeDefaultStore())

    static let completionDefaultsKey = "hasCompletedOnboarding"

    private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool {
        get { Self.hasCompletedOnboarding(in: defaults) }
        set { Self.setHasCompletedOnboarding(newValue, in: defaults) }
    }
    
    private var onboardingWindowController: NSWindowController?
    
    init(defaults: UserDefaults = AppEnvironment.makeDefaultStore()) {
        self.defaults = defaults
        if AppEnvironment.shouldClearDataOnLaunch {
            Self.resetOnboarding(in: defaults)
        }
    }

    static func hasCompletedOnboarding(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: completionDefaultsKey)
    }

    static func setHasCompletedOnboarding(_ isComplete: Bool, in defaults: UserDefaults) {
        defaults.set(isComplete, forKey: completionDefaultsKey)
    }

    static func resetOnboarding(in defaults: UserDefaults) {
        defaults.removeObject(forKey: completionDefaultsKey)
    }
    
    func showOnboardingWindow(completion: @escaping () -> Void) {
        // Force the app to act like a regular app so the window comes to the very front
        // and gains focus, because LSUIElement apps usually stay out of the way.
        NSApp.setActivationPolicy(.regular)
        
        if onboardingWindowController != nil {
            onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let view = OnboardingView(onComplete: { [weak self] in
            guard let self = self else { return }
            self.markOnboardingComplete()
            self.closeOnboardingWindow()
            completion()
        })
        
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Chowser"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor.windowBackgroundColor
        
        // Size it beautifully
        window.setContentSize(NSSize(width: 500, height: 600))
        window.center()
        window.isReleasedWhenClosed = false
        
        let controller = NSWindowController(window: window)
        onboardingWindowController = controller
        
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeOnboardingWindow() {
        onboardingWindowController?.window?.orderOut(nil)
        onboardingWindowController = nil
        
        // Return to background accessory mode
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }
    
    // For debugging/testing
    func resetOnboarding() {
        Self.resetOnboarding(in: defaults)
    }
}
