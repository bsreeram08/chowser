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

    /// Clamps a desired window content size to the screen it'll appear on (minus a margin
    /// for the menu bar / Dock), so a hardcoded design-time size never exceeds an actual
    /// display — generic to any window, not specific to any one onboarding screen.
    private static func clampedContentSize(preferred: NSSize) -> NSSize {
        let visible = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1280, height: 800)
        let margin: CGFloat = 40
        return NSSize(
            width: min(preferred.width, visible.width - margin),
            height: min(preferred.height, visible.height - margin)
        )
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
        
        // Size it beautifully — clamped to fit the actual screen, since the design-time
        // 500x600 target can exceed a smaller display's usable height.
        window.setContentSize(Self.clampedContentSize(preferred: NSSize(width: 500, height: 600)))
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

        // Respect the mode chosen in AppModeStepView instead of always reverting to
        // accessory — App Mode users keep their Dock icon after onboarding closes.
        NSApp.setActivationPolicy(BrowserManager.shared.appMode == .app ? .regular : .accessory)
    }

    private func markOnboardingComplete() {
        hasCompletedOnboarding = true
    }

    // For debugging/testing
    func resetOnboarding() {
        Self.resetOnboarding(in: defaults)
    }

    /// One-time prompt for existing installs upgrading into App Mode support — the
    /// onboarding flow only runs for brand-new installs, so this is the equivalent ask
    /// for everyone who already completed onboarding before this feature existed.
    private var appModeQuestionWindowController: NSWindowController?

    func showAppModeQuestionWindow(completion: @escaping () -> Void) {
        NSApp.setActivationPolicy(.regular)

        if appModeQuestionWindowController != nil {
            appModeQuestionWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = AppModeStepView(manager: BrowserManager.shared, nextAction: { [weak self] in
            guard let self else { return }
            self.appModeQuestionWindowController?.window?.orderOut(nil)
            self.appModeQuestionWindowController = nil
            NSApp.setActivationPolicy(BrowserManager.shared.appMode == .app ? .regular : .accessory)
            completion()
        })

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Chowser"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor.windowBackgroundColor
        window.setContentSize(Self.clampedContentSize(preferred: NSSize(width: 500, height: 420)))
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        appModeQuestionWindowController = controller

        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
