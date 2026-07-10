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

        let view = OnboardingView(onComplete: { [weak self] selectedMode in
            guard let self = self else { return }
            guard self.applySelectedAppMode(selectedMode) else { return }
            BrowserManager.shared.hasBeenAskedAppMode = true
            self.markOnboardingComplete()
            self.closeOnboardingWindow()
            completion()
        })

        // NSHostingView + sizingOptions, not NSHostingController + a hardcoded
        // setContentSize — the exact pattern the picker panel already uses
        // (AppDelegate.createPickerPanel). The window sizes itself to OnboardingView's
        // actual content (which is itself `.fixedSize(vertical: true)`), so there's no
        // design-time pixel guess that can exceed a smaller screen.
        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = [.preferredContentSize]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Welcome to Chowser"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor.windowBackgroundColor
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

        let view = AppModeStepView(manager: BrowserManager.shared, nextAction: { [weak self] selectedMode in
            guard let self else { return }
            guard self.applySelectedAppMode(selectedMode) else { return }
            BrowserManager.shared.hasBeenAskedAppMode = true
            self.appModeQuestionWindowController?.window?.orderOut(nil)
            self.appModeQuestionWindowController = nil
            completion()
        })

        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = [.preferredContentSize]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Chowser"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor.windowBackgroundColor
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        appModeQuestionWindowController = controller

        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applySelectedAppMode(_ mode: ChowserAppMode) -> Bool {
        guard case .failure(let error) = AppDelegate.transitionAppMode(to: mode) else { return true }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Could Not Change App Mode"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        return false
    }
}
