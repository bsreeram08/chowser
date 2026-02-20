//
//  AppDelegate.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import AppKit
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var pickerWindowObserver: NSObjectProtocol?
    private var onboardingRequestObserver: NSObjectProtocol?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        startObservingPickerWindows()
        startObservingOnboardingRequests()
        configureVisiblePickerWindows()

        if shouldShowOnboardingOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.showOnboardingWindow(markAsSeen: true)
            }
        }

        if AppEnvironment.shouldOpenSettingsOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.revealSettingsWindow(retries: 8)
            }
        }

        if AppEnvironment.shouldOpenPickerOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.revealPickerWindow(retries: 8)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = pickerWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            pickerWindowObserver = nil
        }
        if let observer = onboardingRequestObserver {
            NotificationCenter.default.removeObserver(observer)
            onboardingRequestObserver = nil
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        let manager = BrowserManager.shared
        manager.currentURL = url

        if let route = manager.resolvedRoute(for: url) {
            manager.currentURL = nil
            manager.open(url: url, withBrowserBundleID: route.browser.bundleId)
            return
        }

        showPicker()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When dock icon is clicked (if visible), show settings
        if !flag {
            openSettings()
        }
        return true
    }
    
    // MARK: - Status Bar
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            let icon = BrowserManager.currentAppIcon().copy() as? NSImage
            icon?.size = NSSize(width: 16, height: 16)
            icon?.isTemplate = false
            button.image = icon
            button.toolTip = "Chowser — Browser Chooser"
        }
        
        let menu = NSMenu()
        
        let aboutItem = NSMenuItem(title: "About Chowser", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let onboardingItem = NSMenuItem(title: "Welcome & Setup…", action: #selector(openOnboarding), keyEquivalent: "")
        onboardingItem.target = self
        menu.addItem(onboardingItem)
        
        let defaultBrowserItem = NSMenuItem(title: "Set as Default Browser…", action: #selector(setDefaultBrowser), keyEquivalent: "")
        defaultBrowserItem.target = self
        menu.addItem(defaultBrowserItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Chowser", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Actions
    
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel([
            NSApplication.AboutPanelOptionKey.applicationName: "Chowser",
            NSApplication.AboutPanelOptionKey.applicationIcon: BrowserManager.currentAppIcon(),
        ])
    }
    
    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            return
        }

        NotificationCenter.default.post(name: Notification.Name("openSettingsWindow"), object: nil)
    }

    @objc private func openOnboarding() {
        showOnboardingWindow()
    }
    
    private func showPicker() {
        NSApp.activate(ignoringOtherApps: true)
        revealPickerWindow(retries: 8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.configureVisiblePickerWindows()
        }
    }

    private func revealPickerWindow(retries: Int) {
        guard retries > 0 else { return }

        if let pickerWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "picker" }) {
            configurePickerWindow(pickerWindow)
            NSApp.activate(ignoringOtherApps: true)
            pickerWindow.makeMain()
            pickerWindow.makeKeyAndOrderFront(nil)
            pickerWindow.orderFrontRegardless()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.revealPickerWindow(retries: retries - 1)
        }
    }

    private func revealSettingsWindow(retries: Int) {
        guard retries > 0 else { return }

        NSApp.activate(ignoringOtherApps: true)

        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            return
        }

        if let settingsWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
            return
        }

        NotificationCenter.default.post(name: Notification.Name("openSettingsWindow"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.revealSettingsWindow(retries: retries - 1)
        }
    }
    
    @objc private func setDefaultBrowser() {
        BrowserManager.setAsDefaultBrowser()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func startObservingPickerWindows() {
        pickerWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let window = notification.object as? NSWindow,
                window.identifier?.rawValue == "picker"
            else {
                return
            }
            self?.configurePickerWindow(window)
        }
    }

    private func configureVisiblePickerWindows() {
        for window in NSApp.windows where window.identifier?.rawValue == "picker" {
            configurePickerWindow(window)
        }
    }

    private func configurePickerWindow(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.remove(.miniaturizable)
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        // The picker card draws its own shadow; disable window shadow/chrome artifacts.
        window.hasShadow = false
        if #available(macOS 15.0, *) {
            window.toolbar = nil
            // Keep the titled/full-size style so the window can reliably become key for keyboard shortcuts.
            window.styleMask.insert(.titled)
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarSeparatorStyle = .none
        } else {
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarSeparatorStyle = .none
        }
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private var shouldShowOnboardingOnLaunch: Bool {
        if AppEnvironment.isUITesting {
            return false
        }

        return !BrowserManager.shared.hasCompletedOnboarding
    }

    private func startObservingOnboardingRequests() {
        onboardingRequestObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("openOnboardingWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showOnboardingWindow()
        }
    }

    private func showOnboardingWindow(markAsSeen: Bool = false) {
        if markAsSeen {
            BrowserManager.shared.completeOnboarding()
        }

        if let window = onboardingWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let content = OnboardingView(
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onFinish: { [weak self] in
                self?.finishOnboarding()
            }
        )

        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Chowser"
        window.styleMask.remove(.miniaturizable)
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.setContentSize(NSSize(width: 700, height: 520))
        window.minSize = NSSize(width: 700, height: 520)
        window.center()
        window.delegate = self

        onboardingWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func finishOnboarding() {
        BrowserManager.shared.completeOnboarding()
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == onboardingWindow {
            onboardingWindow = nil
        }
    }
}
