//
//  AppDelegate.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import AppKit
import SwiftUI
import ServiceManagement
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var pickerWindowObserver: NSObjectProtocol?
    private var pickerPanel: ChowserPanel?
    private var isHandlingURL = false
    private var settingsWindowController: NSWindowController?

    // Custom NSPanel subclass to support Spotlight-like behavior.
    // .nonactivatingPanel allows the app to appear on top of full-screen apps 
    // without triggering a Space switch. Overriding canBecomeKey allows it 
    // to still handle keyboard shortcuts and text input.
    class ChowserPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register our own Apple Event handler for URL opens BEFORE Cocoa installs its
        // default handler (which fires after WillFinish). This lets us capture the
        // source application's PID for app-based routing rules.
        guard !AppEnvironment.isUITesting else { return }
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !OnboardingManager.shared.hasCompletedOnboarding {
            // First time launch: show onboarding
            OnboardingManager.shared.showOnboardingWindow {
                // Once onboarding is complete, setup the rest of the application
                self.setupApplicationState()
            }
        } else {
            generateStateAndSetupSystem()
        }
    }
    
    private func generateStateAndSetupSystem() {
        setupApplicationState()
        
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
    
    private func setupApplicationState() {
        setupStatusBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        BrowserManager.shared.flushPendingSaves()
        if let observer = pickerWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            pickerWindowObserver = nil
        }
    }
    
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // Extract the source application's bundle ID from the Apple Event sender.
        if let pidDescriptor = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr))?
                .coerce(toDescriptorType: typeKernelProcessID) {
            let pidData = pidDescriptor.data
            let pid = pidData.withUnsafeBytes { $0.load(as: pid_t.self) }
            if let app = NSRunningApplication(processIdentifier: pid) {
                BrowserManager.shared.currentSourceAppBundleId = app.bundleIdentifier
            }
        }

        guard let urlStr = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlStr) else { return }
        self.application(NSApp, open: [url])
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        isHandlingURL = true
        defer {
            // Delay resetting the isHandlingURL flag slightly to catch trailing reopen events.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isHandlingURL = false
            }
            // Clear source app tracking immediately after routing logic completes.
            BrowserManager.shared.currentSourceAppBundleId = nil
        }

        guard let url = urls.first else { return }

        // Feature 4: Handle chowser:// internal scheme (from Share Extension).
        if url.scheme == "chowser", url.host == "open",
           let targetStr = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "url" })?.value,
           let target = URL(string: targetStr),
           target.scheme == "http" || target.scheme == "https" {
            self.application(application, open: [target])
            return
        }

        let manager = BrowserManager.shared
        manager.currentURL = url

        if let route = manager.resolvedRoute(for: url) {
            manager.currentURL = nil
            manager.open(url: url, withBrowserBundleID: route.browser.bundleId, profile: route.browser.profile, usePrivateMode: route.rule.usePrivateMode)
            return
        }

        showPicker()
    }
    
    // applicationShouldHandleReopen is intentionally NOT implemented.
    //
    // Chowser is an LSUIElement (menu-bar-only) app with no Dock icon.
    // This callback would only fire if somehow the app is re-activated via
    // Dock or Exposé, which should never happen in normal use. Including it
    // causes a race with URL-open events (macOS fires reopen before open:)
    // and leads to erroneous Settings window launches during link clicks.
    //
    // If Settings needs to be opened, the user uses the menu bar icon.
    
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


        
        let defaultBrowserItem = NSMenuItem(title: "Set as Default Browser…", action: #selector(setDefaultBrowser), keyEquivalent: "")
        defaultBrowserItem.target = self
        menu.addItem(defaultBrowserItem)

        menu.addItem(NSMenuItem.separator())

        let clipboardItem = NSMenuItem(title: "Open Clipboard URL…", action: #selector(openClipboardURL), keyEquivalent: "")
        clipboardItem.target = self
        menu.addItem(clipboardItem)

        let clipboardPrivateItem = NSMenuItem(title: "Open Clipboard URL in Private…", action: #selector(openClipboardURLPrivate), keyEquivalent: "")
        clipboardPrivateItem.target = self
        clipboardPrivateItem.toolTip = "Hold ⌥ in the picker to open in private mode"
        menu.addItem(clipboardPrivateItem)

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
        // Activate so the Settings window comes to the user's current space.
        NSApp.activate(ignoringOtherApps: true)

        // Clear profile cache so newly added browser profiles are detected.
        BrowserProfileDetector.clearCache()

        // Reuse the existing window if it already exists (avoids recreating state).
        if let controller = settingsWindowController, let window = controller.window {
            if !window.isVisible {
                controller.showWindow(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        // Create a fresh, AppKit-managed window hosting the SwiftUI SettingsView.
        // This is the same pattern as the picker panel and avoids SwiftUI scene
        // lifecycle problems (auto-opening on activation, sendAction responder issues).
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Chowser Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 900, height: 600))
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
    }


    
    func closePicker() {
        pickerPanel?.orderOut(nil)
        BrowserManager.shared.currentURL = nil
    }

    private func showPicker() {
        revealPickerWindow(retries: 8)
    }

    private func revealPickerWindow(retries: Int) {
        if let panel = pickerPanel {
            configurePickerAndShow(panel)
            return
        }

        let panel = createPickerPanel()
        self.pickerPanel = panel
        configurePickerAndShow(panel)
    }

    private func createPickerPanel() -> ChowserPanel {
        let panel = ChowserPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("picker")
        panel.isFloatingPanel = true
        panel.level = .mainMenu + 1
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.hasShadow = false // PickerSurfaceModifier handles shadow
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: ContentView())
        hostingView.sizingOptions = [.preferredContentSize]
        panel.contentView = hostingView
        
        return panel
    }

    private func configurePickerAndShow(_ panel: NSPanel) {
        configurePickerWindow(panel)
        
        // Center on active screen (where the mouse is)
        if let mouseLocation = NSEvent.mouseLocation as Optional<NSPoint>,
           let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = panel.frame
            let newOrigin = NSPoint(
                x: screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2
            )
            panel.setFrameOrigin(newOrigin)
        }
        
        // NSApp.activate(ignoringOtherApps: true) is REMOVED to prevent space-jumping.
        // Instead, we just make the panel key and front.
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func revealSettingsWindow(retries: Int) {
        // Used only in UI testing via AppEnvironment.shouldOpenSettingsOnLaunch.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc private func setDefaultBrowser() {
        BrowserManager.setAsDefaultBrowser()
    }

    @objc private func openClipboardURL() {
        guard let url = clipboardURL() else { NSSound.beep(); return }
        application(NSApp, open: [url])
    }

    @objc private func openClipboardURLPrivate() {
        guard let url = clipboardURL() else { NSSound.beep(); return }
        application(NSApp, open: [url])
        // User holds ⌥ in the picker to activate private mode.
    }

    private func clipboardURL() -> URL? {
        guard let s = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: s),
              url.scheme == "http" || url.scheme == "https" else { return nil }
        return url
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }


    private func configurePickerWindow(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        
        if window is NSPanel {
            window.level = .mainMenu + 1
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }

        if #available(macOS 15.0, *) {
            window.toolbar = nil
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


}
