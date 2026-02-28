//
//  OnboardingManager.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import AppKit
import SwiftUI

final class OnboardingManager {
    static let shared = OnboardingManager()
    
    // Allows clearing for testing
    private let userDefaultsKey = "hasCompletedOnboarding"
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: userDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }
    
    private var onboardingWindowController: NSWindowController?
    
    private init() {}
    
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
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
