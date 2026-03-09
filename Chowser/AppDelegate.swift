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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
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
                // Auto-open Settings so new users know where to go
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.openSettings()
                }
            }
        } else {
            generateStateAndSetupSystem()
        }
    }
    
    private func generateStateAndSetupSystem() {
        setupApplicationState()
        // Removed: handleCLIImportArguments()
        
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
        var resolved = false

        // Approach 1: Extract PID via typeKernelProcessID coercion
        if let pidDescriptor = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr))?
                .coerce(toDescriptorType: typeKernelProcessID) {
            let pidData = pidDescriptor.data
            if pidData.count >= MemoryLayout<pid_t>.size {
                let pid = pidData.withUnsafeBytes { $0.load(as: pid_t.self) }
                if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                    BrowserManager.shared.currentSourceAppBundleId = app.bundleIdentifier
                    resolved = true
                }
            }
        }

        // Approach 2: Try extracting the sender's process serial number (legacy path)
        if !resolved,
           let senderDesc = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)) {
            // Some apps send typeApplSignature or typeProcessSerialNumber descriptors.
            // Try coercing to typeApplicationBundleID directly (macOS 10.15+)
            if let bundleDesc = senderDesc.coerce(toDescriptorType: typeApplicationBundleID),
               let bundleId = bundleDesc.stringValue, !bundleId.isEmpty {
                BrowserManager.shared.currentSourceAppBundleId = bundleId
                resolved = true
            }
        }

        // Approach 3: Fall back to the frontmost application (heuristic)
        if !resolved {
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                BrowserManager.shared.currentSourceAppBundleId = frontApp.bundleIdentifier
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

        // Feature 4: Handle chowser://internal scheme (from Share Extension).
        if url.scheme == "chowser", url.host == "open",
           let targetStr = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "url" })?.value,
           let target = URL(string: targetStr),
           target.scheme == "http" || target.scheme == "https" {
            self.application(application, open: [target])
            return
        }

        // Handle chowser://import for runtime import of browsers/rules via URL scheme.
        // Usage: open "chowser://import?browsers=/path/to/browsers.json&rules=/path/to/rules.json"
        if url.scheme == "chowser", url.host == "import" {
            // Legacy functionality removed: handleImportURL(url)
        }
        // The `return` statement was removed as part of the legacy functionality removal.

        let manager = BrowserManager.shared
        
        Task {
            // 1. Unshorten the URL if it's from a known shortener
            let unshortenedURL = await manager.unshortenURL(url)
            
            // 2. Clean known tracking parameters
            let cleanedURL = manager.cleanURL(unshortenedURL)

            await MainActor.run {
                manager.addRecentURL(cleanedURL)
                manager.currentURL = cleanedURL

                // Hold Shift (⇧) while clicking a link to bypass auto-rules and force the picker
                let forceShowPicker = NSEvent.modifierFlags.contains(.shift)

                if !forceShowPicker, let route = manager.resolvedRoute(for: cleanedURL) {
                    manager.currentURL = nil
                    manager.open(url: cleanedURL, withBrowserBundleID: route.browser.bundleId, profile: route.browser.profile, usePrivateMode: route.rule?.usePrivateMode ?? false)
                    return
                }

                showPicker()
            }
        }
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
        menu.delegate = self
        
        statusItem?.menu = menu
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // 1. Hide if default browser (meaning if we ALREADY are the default, don't show the "Set as Default Browser" option later on, OR do we completely hide the menu? Wait, the prompt says "If chowser is already default browser, don't show in menu bar". I'll assume they mean the "Set as Default Browser" item.)
        let isDefault = BrowserManager.isDefaultBrowser()
        
        let recentURLsItem = NSMenuItem(title: "Recent URLs", action: nil, keyEquivalent: "")
        if let icon = NSImage(systemSymbolName: "clock", accessibilityDescription: nil) {
            icon.isTemplate = true
            recentURLsItem.image = icon
        }
        
        // Dynamic: Recent URLs
        let recentURLs = BrowserManager.shared.recentURLs
        if !recentURLs.isEmpty {
            let recentUrlsMenu = NSMenu()
            for url in recentURLs {
                let host = url.host ?? url.absoluteString
                let title = host.prefix(40) + (host.count > 40 ? "..." : "")
                
                let item = NSMenuItem(title: String(title), action: #selector(openRecentURL(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                if let icon = NSImage(systemSymbolName: "safari", accessibilityDescription: nil) {
                    item.image = icon
                }
                item.toolTip = url.absoluteString
                recentUrlsMenu.addItem(item)
                
                let altItem = NSMenuItem(title: "Create Rule for \(host)", action: #selector(createRuleFromRecentURL(_:)), keyEquivalent: "")
                altItem.target = self
                altItem.representedObject = url
                altItem.isAlternate = true
                altItem.keyEquivalentModifierMask = .option
                if let icon = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil) {
                    altItem.image = icon
                }
                altItem.toolTip = "Create a routing rule for this domain"
                recentUrlsMenu.addItem(altItem)
            }
            recentURLsItem.submenu = recentUrlsMenu
            menu.addItem(recentURLsItem)
        }

        // 3. Open Clipboard URL -> submenu
        let clipboardTitleItem = NSMenuItem(title: "Open Clipboard URL...", action: nil, keyEquivalent: "")
        if let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil) {
            icon.isTemplate = true
            clipboardTitleItem.image = icon
        }
        let clipboardMenu = NSMenu()
        let clipboardItem = NSMenuItem(title: "Open in Browser...", action: #selector(openClipboardURL), keyEquivalent: "")
        clipboardItem.target = self
        clipboardMenu.addItem(clipboardItem)

        let clipboardPrivateItem = NSMenuItem(title: "Open in Private...", action: #selector(openClipboardURLPrivate), keyEquivalent: "")
        clipboardPrivateItem.target = self
        clipboardMenu.addItem(clipboardPrivateItem)
        
        clipboardTitleItem.submenu = clipboardMenu
        menu.addItem(clipboardTitleItem)

        
        
        // 4. Set focus mode
        if let tempRoute = BrowserManager.shared.temporaryRoute,
           let browser = BrowserManager.shared.configuredBrowsers.first(where: { $0.bundleId == tempRoute.browserBundleId && $0.profile == tempRoute.profile }) {
            
            let remaining = Int(tempRoute.expiresAt.timeIntervalSinceNow / 60)
            let browserName = browser.name + (browser.profile != nil ? " (\(browser.profile!))" : "")
            
            let clearItem = NSMenuItem(title: "Clear Focus: \(browserName) (\(remaining)m left)", action: #selector(clearTemporaryDefault), keyEquivalent: "")
            clearItem.target = self
            if let icon = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil) {
                icon.isTemplate = true
                clearItem.image = icon
            }
            menu.addItem(clearItem)
        } else if !BrowserManager.shared.configuredBrowsers.isEmpty {
            let focusMenu = NSMenu()
            for browser in BrowserManager.shared.configuredBrowsers {
                let durationMenu = NSMenu()
                
                let item1H = NSMenuItem(title: "1 Hour", action: #selector(setFocus1H(_:)), keyEquivalent: "")
                item1H.representedObject = browser
                item1H.target = self
                durationMenu.addItem(item1H)
                
                let itemTomorrow = NSMenuItem(title: "Until Tomorrow", action: #selector(setFocusTomorrow(_:)), keyEquivalent: "")
                itemTomorrow.representedObject = browser
                itemTomorrow.target = self
                durationMenu.addItem(itemTomorrow)
                
                let browserName = browser.name + (browser.profile != nil ? " (\(browser.profile!))" : "")
                let browserItem = NSMenuItem(title: browserName, action: nil, keyEquivalent: "")
                browserItem.submenu = durationMenu
                
                let iconSize = NSSize(width: 16, height: 16)
                if let originalIcon = BrowserManager.icon(forBrowserBundleID: browser.bundleId),
                   let resizedIcon = originalIcon.copy() as? NSImage {
                    resizedIcon.size = iconSize
                    browserItem.image = resizedIcon
                } else if let fallback = NSImage(systemSymbolName: "globe", accessibilityDescription: nil) {
                    fallback.isTemplate = true
                    browserItem.image = fallback
                }
                focusMenu.addItem(browserItem)
            }
            
            let focusItem = NSMenuItem(title: "Set Focus Mode...", action: nil, keyEquivalent: "")
            if let icon = NSImage(systemSymbolName: "target", accessibilityDescription: nil) {
                icon.isTemplate = true
                focusItem.image = icon
            }
            focusItem.submenu = focusMenu
            menu.addItem(focusItem)
        }
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // 5. API Server (MCP-like)
        let server = MCPServer.shared
        if server.isRunning {
            let stopItem = NSMenuItem(title: "Stop API Server (port \(server.port))", action: #selector(toggleMCPServer), keyEquivalent: "")
            stopItem.target = self
            if let icon = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: nil) {
                icon.isTemplate = true
                stopItem.image = icon
            }
            menu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(title: "Start API Server", action: #selector(toggleMCPServer), keyEquivalent: "")
            startItem.target = self
            if let icon = NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil) {
                icon.isTemplate = true
                startItem.image = icon
            }
            menu.addItem(startItem)
        }

        // 6. Settings
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        if !isDefault {
            let defaultBrowserItem = NSMenuItem(title: "Set as Default Browser…", action: #selector(setDefaultBrowser), keyEquivalent: "")
            defaultBrowserItem.target = self
            menu.addItem(defaultBrowserItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 6. About Chowser
        let aboutItem = NSMenuItem(title: "About Chowser", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())

        // 8. Quit Chowser
        let quitItem = NSMenuItem(title: "Quit Chowser", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // MARK: - Actions

    @objc private func toggleMCPServer() {
        let server = MCPServer.shared
        if server.isRunning {
            server.stop()
        } else {
            server.start()
        }
    }
    
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel([
            NSApplication.AboutPanelOptionKey.applicationName: "Chowser",
            NSApplication.AboutPanelOptionKey.applicationIcon: BrowserManager.currentAppIcon(),
        ])
    }

    @objc private func openRecentURL(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        self.application(NSApp, open: [url])
    }

    @objc private func createRuleFromRecentURL(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        BrowserManager.shared.currentURL = url
        openSettings()
        // Wait a tick for Settings window to appear, then we will trigger the rule sheet
        // We can communicate this via NotificationCenter or just setting a property on BrowserManager.
        NotificationCenter.default.post(name: NSNotification.Name("OpenCreateRuleFromMenu"), object: url)
    }

    @objc private func clearTemporaryDefault() {
        BrowserManager.shared.clearTemporaryRoute()
    }
    
    @objc private func setFocus1H(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? BrowserConfig else { return }
        BrowserManager.shared.setTemporaryRoute(browserBundleId: browser.bundleId, profile: browser.profile, duration: 3600)
    }

    @objc private func setFocusTomorrow(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? BrowserConfig else { return }
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day = (components.day ?? 0) + 1
        components.hour = 8 // Tomorrow at 8 AM
        let tomorrow = calendar.date(from: components) ?? now.addingTimeInterval(86400)
        let duration = tomorrow.timeIntervalSince(now)
        
        BrowserManager.shared.setTemporaryRoute(browserBundleId: browser.bundleId, profile: browser.profile, duration: duration)
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
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1100, height: 700))
        window.minSize = NSSize(width: 900, height: 600)
        window.maxSize = NSSize(width: 2000, height: 1500)
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
