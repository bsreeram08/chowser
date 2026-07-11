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
    enum AppModeTransitionError: LocalizedError, Equatable {
        case appDelegateUnavailable
        case statusItemUnavailable
        case activationPolicyRejected(ChowserAppMode)
        case rollbackFailed(ChowserAppMode)

        var errorDescription: String? {
            switch self {
            case .appDelegateUnavailable:
                return "Chowser could not access its application lifecycle. The app mode was not changed."
            case .statusItemUnavailable:
                return "Chowser could not create its menu bar item. App Mode remains active so Settings stays reachable."
            case .activationPolicyRejected(let mode):
                return "macOS rejected the switch to \(mode == .app ? "App" : "Menu Bar") mode. The previous mode remains active."
            case .rollbackFailed:
                return "macOS rejected the mode change and its rollback. Chowser kept every available app entry point visible; restart the app before trying again."
            }
        }
    }

    private var statusItem: NSStatusItem?
    private var pickerWindowObserver: NSObjectProtocol?
    private var pickerPanel: ChowserPanel?
    private var settingsWindowController: NSWindowController?
    private var pendingReopenWorkItem: DispatchWorkItem?
    private var lastURLOpenUptime = -TimeInterval.infinity

    private static let deferredReopenDelay: TimeInterval = 0.2

    private(set) static weak var shared: AppDelegate?

    override init() {
        super.init()
        Self.shared = self
    }

    // Custom NSPanel subclass to support Spotlight-like behavior.
    // .nonactivatingPanel allows the app to appear on top of full-screen apps 
    // without triggering a Space switch. Overriding canBecomeKey allows it 
    // to still handle keyboard shortcuts and text input.
    class ChowserPanel: NSPanel {
        /// Radial mode must keep its visual center on the cursor even when
        /// `NSHostingView` changes the panel's preferred size after presentation.
        var cursorAnchor: NSPoint?
        var pinsCenterToCursor = false

        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }

        func pinnedOrigin(for size: NSSize) -> NSPoint? {
            guard pinsCenterToCursor, let cursorAnchor else { return nil }
            return NSPoint(
                x: cursorAnchor.x - size.width / 2,
                y: cursorAnchor.y - size.height / 2
            )
        }

        override func setFrame(_ frameRect: NSRect, display flag: Bool) {
            var adjustedFrame = frameRect
            if let pinnedOrigin = pinnedOrigin(for: adjustedFrame.size) {
                adjustedFrame.origin = pinnedOrigin
            }
            super.setFrame(adjustedFrame, display: flag)
        }
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
        AppLogger.beginSession(presentationMode: BrowserManager.shared.appMode.rawValue)

        if AppEnvironment.shouldBypassOnboardingForRequestedUITestSurface {
            OnboardingManager.shared.hasCompletedOnboarding = true
            generateStateAndSetupSystem()
            return
        }

        if !OnboardingManager.shared.hasCompletedOnboarding {
            // First time launch: show onboarding (includes the App Mode question)
            OnboardingManager.shared.showOnboardingWindow {
                // Once onboarding is complete, setup the rest of the application
                self.setupApplicationState()
                // Auto-open Settings so new users know where to go
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.openSettings()
                }
            }
        } else if !BrowserManager.shared.hasBeenAskedAppMode {
            // Existing install, new feature: ask once, standalone, rather than silently
            // defaulting either way.
            OnboardingManager.shared.showAppModeQuestionWindow {
                self.generateStateAndSetupSystem()
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
        let manager = BrowserManager.shared
        let persistedMode = manager.appMode
        if case .failure(let error) = transitionAppMode(to: persistedMode) {
            AppLogger.error("AppLifecycle", error.localizedDescription)
            DispatchQueue.main.async { self.openSettings() }
        }

        if manager.mcpAutoStartEnabled {
            MCPServer.shared.start()
        }

        if persistedMode == .app {
            // App Mode has no status item to click, so there's no picker-adjacent affordance
            // to discover Settings from — show it directly, same as the new-user first-launch
            // auto-open below.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.openSettings()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cancelPendingReopen()
        let presentationMode = BrowserManager.shared.appMode.rawValue
        AppLogger.recordCriticalLifecycleBreadcrumb(.terminationWillBegin(presentationMode: presentationMode))
        BrowserManager.shared.flushPendingSaves()
        _ = AppLogger.endSessionCleanly(presentationMode: presentationMode)
        AppLogger.flush()
        if let observer = pickerWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            pickerWindowObserver = nil
        }
    }
    
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let url = Self.appleEventURL(from: event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue) else {
            return
        }

        let senderDescriptor = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr))
        let senderPIDData = senderDescriptor?.coerce(toDescriptorType: typeKernelProcessID)?.data
        let senderBundleIdentifier = senderDescriptor?.coerce(toDescriptorType: typeApplicationBundleID)?.stringValue
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        BrowserManager.shared.currentSourceAppBundleId = Self.sourceAppBundleIdentifier(
            senderPIDData: senderPIDData,
            senderBundleIdentifier: senderBundleIdentifier,
            frontmostBundleIdentifier: frontmostBundleIdentifier
        )

        application(NSApp, open: [url])
    }

    static func appleEventURL(from string: String?) -> URL? {
        guard let string,
              let url = URL(string: string),
              let scheme = url.scheme,
              !scheme.isEmpty else {
            return nil
        }

        return url
    }

    @MainActor
    static func prepareClipboardURLOpen(
        _ url: URL,
        using manager: BrowserManager,
        usePrivateMode: Bool,
        openURL: (URL) -> Void
    ) {
        manager.prepareClipboardPrivateModeRequest(for: url, usePrivateMode: usePrivateMode)
        openURL(url)
    }

    @MainActor
    static func requestedPrivateModeForIncomingURL(
        rule: BrowserRoutingRule?,
        forcedPrivateMode: Bool
    ) -> Bool {
        guard BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild else { return false }
        return forcedPrivateMode || (rule?.usePrivateMode ?? false)
    }

    static func sourceAppBundleIdentifier(
        senderPIDData: Data?,
        senderBundleIdentifier: String?,
        frontmostBundleIdentifier: String?,
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        runningApplicationBundleIdentifier: (pid_t) -> String? = { pid in
            NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        }
    ) -> String? {
        if let pid = senderPID(from: senderPIDData),
           let bundleIdentifier = runningApplicationBundleIdentifier(pid),
           !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }

        if let senderBundleIdentifier,
           !senderBundleIdentifier.isEmpty {
            return senderBundleIdentifier
        }

        guard let frontmostBundleIdentifier,
              !frontmostBundleIdentifier.isEmpty,
              frontmostBundleIdentifier != ownBundleIdentifier else {
            return nil
        }

        return frontmostBundleIdentifier
    }

    @MainActor
    static func resolveIncomingURLRoute(
        for url: URL,
        using manager: BrowserManager,
        forceShowPicker: Bool,
        sourceApp: String? = nil
    ) -> (rule: BrowserRoutingRule?, browser: BrowserConfig)? {
        defer {
            manager.currentSourceAppBundleId = nil
        }

        guard !forceShowPicker else { return nil }
        if let matched = manager.resolvedRoute(for: url, sourceApp: sourceApp) {
            return matched
        }
        return manager.fallbackRoute()
    }

    private static func senderPID(from data: Data?) -> pid_t? {
        guard let data,
              data.count >= MemoryLayout<pid_t>.size else {
            return nil
        }

        var pid: pid_t = 0
        _ = withUnsafeMutableBytes(of: &pid) { buffer in
            data.copyBytes(to: buffer)
        }

        return pid > 0 ? pid : nil
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        cancelPendingReopen()
        lastURLOpenUptime = ProcessInfo.processInfo.systemUptime
        let manager = BrowserManager.shared

        guard let url = urls.first else {
            manager.currentSourceAppBundleId = nil
            return
        }
        let clipboardPrivateModeRequested = manager.consumeClipboardPrivateModeRequest(for: url)

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

        // chowser://settings — a fallback entry point independent of the menu bar icon.
        // Chowser's only other UI entry point is the status item; if it's ever hidden
        // (most commonly: squeezed off-screen by macOS menu-bar overflow on a crowded bar),
        // there was previously no way back in short of a `defaults delete` + relaunch. This
        // is reachable via Terminal (`open "chowser://settings"`), Shortcuts, or a browser
        // address bar. Usage: open "chowser://settings"
        if url.scheme == "chowser", url.host == "settings" {
            openSettings()
            return
        }

        // chowser://mcp/start and chowser://mcp/stop — lets an AI agent with only shell
        // access (e.g. Claude Code) turn the local API on, do configuration tasks, and
        // turn it back off, without any GUI interaction. `open "chowser://mcp/start"`
        // starts the server and writes ~/Library/Application Support/Chowser/mcp-session.json
        // (port + token) that the agent's shell can read directly — see MCPServer.start().
        if url.scheme == "chowser", url.host == "mcp" {
            if url.path == "/start" {
                MCPServer.shared.start()
            } else if url.path == "/stop" {
                MCPServer.shared.stop()
            }
            return
        }

        Task {
            // 0. Apply URL rewrite rules — local, synchronous, before any network call
            // (PRD Architecture Notes pipeline order: rewrites → shortlink → cleanup).
            // Source app is captured explicitly here (still non-nil; the defer below clears
            // it only after route resolution) rather than read ambiently by the pipeline.
            let sourceAppBundleId = manager.currentSourceAppBundleId
            let rewriteResult = manager.applyRewritePipeline(to: url, sourceApp: sourceAppBundleId)
            let rewrittenURL = rewriteResult.finalURL

            // Only show a loading state when shortlink resolution will actually make a
            // network call (up to the 1.5s timeout) — the default one-key path stays instant.
            let willAwaitShortlink = manager.networkLookupsEnabled
                && (rewrittenURL.host.map { manager.isAllowedShortenerHost($0) } ?? false)

            if willAwaitShortlink {
                manager.currentRewriteTrace = rewriteResult.steps
                manager.currentURL = rewrittenURL
                manager.isResolvingIncomingURL = true
                showPicker()
            }

            // 1. Unshorten the URL if it's from a known shortener
            let unshortenedURL = await manager.unshortenURL(rewrittenURL)

            // 2. Clean known tracking parameters
            let cleanedURL = manager.cleanURL(unshortenedURL)

            await MainActor.run {
                manager.isResolvingIncomingURL = false
                manager.currentRewriteTrace = rewriteResult.steps
                manager.addRecentURL(cleanedURL)
                manager.currentURL = cleanedURL

                // Hold Shift (⇧) while clicking a link to bypass auto-rules and force the picker.
                let forceShowPicker = NSEvent.modifierFlags.contains(.shift)
                // Pass the source app captured at the top of this Task explicitly — reading
                // `manager.currentSourceAppBundleId` here (after the `await unshortenURL` gap
                // above) would race a second incoming link overwriting that ambient property
                // before this one's routing decision runs (TOCTOU, found in review).
                let route = Self.resolveIncomingURLRoute(for: cleanedURL, using: manager, forceShowPicker: forceShowPicker, sourceApp: sourceAppBundleId)

                // No hostname/URL in the log — routing decisions are diagnosable from the
                // rule name and destination browser alone, without recording what was visited.
                AppLogger.log("Route", "Received link → \(route.map { "rule '\($0.rule?.name ?? "auto")' → \($0.browser.bundleId)" } ?? "picker")")

                if let route {
                    manager.currentURL = nil
                    let usePrivateMode = Self.requestedPrivateModeForIncomingURL(rule: route.rule, forcedPrivateMode: clipboardPrivateModeRequested)
                    manager.currentURLPrivateModeRequested = false
                    manager.open(url: cleanedURL, withBrowserBundleID: route.browser.bundleId, profile: route.browser.profile, usePrivateMode: usePrivateMode)
                    if willAwaitShortlink { self.closePicker() }
                    return
                }

                manager.currentURLPrivateModeRequested = BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild && clipboardPrivateModeRequested
                showPicker()
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        cancelPendingReopen()
        let secondsSinceLastURLOpen = ProcessInfo.processInfo.systemUptime - lastURLOpenUptime
        guard Self.shouldScheduleDeferredReopen(
            hasVisibleWindows: hasVisibleWindows,
            secondsSinceLastURLOpen: secondsSinceLastURLOpen
        ) else { return true }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingReopenWorkItem = nil
            guard !NSApp.windows.contains(where: \.isVisible) else { return }
            self.openSettings()
        }
        pendingReopenWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.deferredReopenDelay, execute: workItem)
        return true
    }

    static func shouldScheduleDeferredReopen(
        hasVisibleWindows: Bool,
        secondsSinceLastURLOpen: TimeInterval
    ) -> Bool {
        !hasVisibleWindows && secondsSinceLastURLOpen >= deferredReopenDelay
    }

    private func cancelPendingReopen() {
        pendingReopenWorkItem?.cancel()
        pendingReopenWorkItem = nil
    }

    // MARK: - Status Bar

    @MainActor
    static func transitionAppMode(to mode: ChowserAppMode) -> Result<Void, AppModeTransitionError> {
        guard let delegate = shared ?? NSApp.delegate as? AppDelegate else {
            AppLogger.recordCriticalLifecycleBreadcrumb(
                .activationPolicyTransitionDidFail(
                    from: BrowserManager.shared.appMode.rawValue,
                    to: mode.rawValue,
                    reason: .appDelegateUnavailable
                )
            )
            return .failure(.appDelegateUnavailable)
        }
        return delegate.transitionAppMode(to: mode)
    }

    @MainActor
    private func transitionAppMode(to mode: ChowserAppMode) -> Result<Void, AppModeTransitionError> {
        let manager = BrowserManager.shared
        // Onboarding temporarily forces a regular activation policy before persisting the
        // user's choice, so the live presentation is more authoritative than the preference.
        let previousMode: ChowserAppMode = NSApp.activationPolicy() == .accessory ? .menuBar : .app
        AppLogger.recordCriticalLifecycleBreadcrumb(
            .activationPolicyTransitionWillBegin(from: previousMode.rawValue, to: mode.rawValue)
        )

        let result = Self.performAppModeTransition(
            to: mode,
            currentMode: previousMode,
            ensureStatusItem: ensureStatusItem,
            setActivationPolicy: { NSApp.setActivationPolicy($0) },
            removeStatusItem: removeStatusItem,
            persistMode: { manager.appMode = $0 }
        )

        if case .failure(let error) = result {
            let reason: DiagnosticsTransitionFailureReason
            switch error {
            case .appDelegateUnavailable:
                reason = .appDelegateUnavailable
            case .statusItemUnavailable:
                reason = .statusItemUnavailable
            case .activationPolicyRejected:
                reason = .activationPolicyRejected
            case .rollbackFailed:
                reason = .rollbackFailed
            }
            AppLogger.recordCriticalLifecycleBreadcrumb(
                .activationPolicyTransitionDidFail(from: previousMode.rawValue, to: mode.rawValue, reason: reason)
            )
            return result
        }

        AppLogger.log("AppLifecycle", "Applied app mode: \(mode.rawValue)")
        AppLogger.recordCriticalLifecycleBreadcrumb(
            .activationPolicyTransitionDidComplete(presentationMode: mode.rawValue)
        )
        return result
    }

    @MainActor
    static func performAppModeTransition(
        to mode: ChowserAppMode,
        currentMode: ChowserAppMode,
        ensureStatusItem: () -> Bool,
        setActivationPolicy: (NSApplication.ActivationPolicy) -> Bool,
        removeStatusItem: () -> Void,
        persistMode: (ChowserAppMode) -> Void
    ) -> Result<Void, AppModeTransitionError> {
        switch mode {
        case .menuBar:
            guard ensureStatusItem() else {
                if currentMode == .menuBar {
                    guard setActivationPolicy(.regular) else {
                        return .failure(.rollbackFailed(.menuBar))
                    }
                    persistMode(.app)
                }
                return .failure(.statusItemUnavailable)
            }
            guard setActivationPolicy(.accessory) else {
                guard setActivationPolicy(.regular) else {
                    // Keep the new status item as a recovery entry point.
                    persistMode(.menuBar)
                    return .failure(.rollbackFailed(.menuBar))
                }
                removeStatusItem()
                persistMode(.app)
                return .failure(.activationPolicyRejected(.menuBar))
            }
            persistMode(.menuBar)

        case .app:
            guard setActivationPolicy(.regular) else {
                return .failure(.activationPolicyRejected(.app))
            }
            removeStatusItem()
            persistMode(.app)
        }
        return .success(())
    }

    private func ensureStatusItem() -> Bool {
        if let statusItem, statusItem.button != nil {
            return true
        }

        removeStatusItem()
        let newStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = newStatusItem.button else {
            NSStatusBar.system.removeStatusItem(newStatusItem)
            AppLogger.error("StatusBar", "Status item creation failed")
            return false
        }

        statusItem = newStatusItem

        let icon = BrowserManager.currentAppIcon().copy() as? NSImage
        icon?.size = NSSize(width: 16, height: 16)
        icon?.isTemplate = false
        button.image = icon
        button.toolTip = "Chowser — Browser Chooser"

        let menu = NSMenu()
        menu.delegate = self

        newStatusItem.menu = menu
        AppLogger.recordCriticalLifecycleBreadcrumb(.statusItemCreated)
        return true
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        AppLogger.recordCriticalLifecycleBreadcrumb(.statusItemRemoved)
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

        if BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
            let clipboardPrivateItem = NSMenuItem(title: "Open in Private...", action: #selector(openClipboardURLPrivate), keyEquivalent: "")
            clipboardPrivateItem.target = self
            clipboardMenu.addItem(clipboardPrivateItem)
        }
        
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

        let diagnosticsItem = NSMenuItem(title: "Diagnostics…", action: #selector(openDiagnostics), keyEquivalent: "")
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

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
    
    @objc func showAbout() {
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
        clearFocusMode()
    }
    
    @objc private func setFocus1H(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? BrowserConfig else { return }
        setFocusModeForOneHour(browser)
    }

    @objc private func setFocusTomorrow(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? BrowserConfig else { return }
        setFocusModeUntilTomorrow(browser)
    }

    func clearFocusMode() {
        BrowserManager.shared.clearTemporaryRoute()
    }

    func setFocusModeForOneHour(_ browser: BrowserConfig) {
        BrowserManager.shared.setTemporaryRoute(browserBundleId: browser.bundleId, profile: browser.profile, duration: 3600)
    }

    func setFocusModeUntilTomorrow(_ browser: BrowserConfig) {
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
            AppLogger.recordCriticalLifecycleBreadcrumb(.settingsWindowPresented(created: false))
            return
        }

        // Create a fresh, AppKit-managed window hosting the SwiftUI SettingsView.
        // This is the same pattern as the picker panel and avoids SwiftUI scene
        // lifecycle problems (auto-opening on activation, sendAction responder issues).
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Chowser Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        let settingsContentSize = AppEnvironment.shouldUseNarrowSettingsWindow
            ? NSSize(width: 860, height: 560)
            : NSSize(width: 980, height: 660)
        window.setContentSize(settingsContentSize)
        window.minSize = NSSize(width: 860, height: 560)
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        AppLogger.recordCriticalLifecycleBreadcrumb(.settingsWindowPresented(created: true))
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

    private func configurePickerAndShow(_ panel: ChowserPanel) {
        configurePickerWindow(panel)

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        if let screen {
            let mode = BrowserManager.shared.pickerLayoutMode
            if mode == .radial {
                BrowserManager.shared.radialPickerShape = RadialPickerGeometry.shape(
                    anchor: mouseLocation,
                    visibleFrame: screen.visibleFrame
                )
            }
            panel.cursorAnchor = mode == .radial ? mouseLocation : nil
            panel.pinsCenterToCursor = mode == .radial
            panel.acceptsMouseMovedEvents = mode == .radial || mode == .minimal
            panel.isMovableByWindowBackground = mode == .icons || mode == .list
            panel.contentView?.layoutSubtreeIfNeeded()
            positionPickerPanel(panel, mode: mode, mouseLocation: mouseLocation, screen: screen)
        }

        // NSApp.activate(ignoringOtherApps: true) is REMOVED to prevent space-jumping.
        // Instead, we just make the panel key and front.
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        // Observation can change the hosting view's preferred size one runloop after the
        // layout preference changes. Reposition once with that final size while preserving
        // the link-click cursor origin captured above.
        if let screen {
            let mode = BrowserManager.shared.pickerLayoutMode
            DispatchQueue.main.async { [weak panel] in
                guard let panel, panel.isVisible else { return }
                panel.contentView?.layoutSubtreeIfNeeded()
                self.positionPickerPanel(panel, mode: mode, mouseLocation: mouseLocation, screen: screen)
            }
        }
    }

    private func positionPickerPanel(_ panel: ChowserPanel, mode: PickerLayoutMode, mouseLocation: NSPoint, screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let windowFrame = panel.frame
        let origin: NSPoint

        switch mode {
        case .radial:
            // Keep the ring's center exactly under the link-click cursor. The radial view
            // renders only inward-facing wedges at edges/corners, so the transparent half
            // of this borderless panel may safely extend beyond the visible frame.
            guard let pinnedOrigin = panel.pinnedOrigin(for: windowFrame.size) else { return }
            origin = pinnedOrigin
        case .minimal:
            // The switcher stays near the cursor but remains fully reachable at an edge.
            origin = NSPoint(
                x: min(max(mouseLocation.x - windowFrame.width / 2, screenFrame.minX), screenFrame.maxX - windowFrame.width),
                y: min(max(mouseLocation.y - windowFrame.height / 2, screenFrame.minY), screenFrame.maxY - windowFrame.height)
            )
        case .icons, .list:
            origin = NSPoint(
                x: screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2
            )
        }
        panel.setFrameOrigin(origin)
    }

    private func revealSettingsWindow(retries: Int) {
        // Used only in UI testing via AppEnvironment.shouldOpenSettingsOnLaunch.
        openSettings()
    }
    
    @objc private func setDefaultBrowser() {
        BrowserManager.setAsDefaultBrowser()
    }

    @objc func openClipboardURL() {
        guard let url = clipboardURL() else { NSSound.beep(); return }
        Self.prepareClipboardURLOpen(url, using: BrowserManager.shared, usePrivateMode: false) { url in
            application(NSApp, open: [url])
        }
    }

    @objc private func openClipboardURLPrivate() {
        guard let url = clipboardURL() else { NSSound.beep(); return }
        Self.prepareClipboardURLOpen(url, using: BrowserManager.shared, usePrivateMode: true) { url in
            application(NSApp, open: [url])
        }
    }

    private func clipboardURL() -> URL? {
        guard let s = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: s),
              url.scheme == "http" || url.scheme == "https" else { return nil }
        return url
    }

    @objc func openDiagnostics() {
        DiagnosticsWindowController.shared.showDiagnostics()
    }

    @objc func quitApp() {
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
