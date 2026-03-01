//
//  ContentView.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI
import AppKit

// MARK: - Visual Effect View Wrapper
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ContentView: View {
    var browserManager = BrowserManager.shared
    @State private var hoveredBrowserId: UUID?
    @State private var keyboardSelectedBrowserId: UUID?
    @State private var appeared = false
    @State private var dismissTask: DispatchWorkItem?
    @State private var focusObserver: NSObjectProtocol?
    @State private var keyEventMonitor: Any?
    @State private var showingConfigureRule = false
    @State private var urlCopied = false
    @State private var privateMode = false
    @State private var isUnshortening = false
    @State private var unshorteningError: String? = nil

    @ViewBuilder
    private var panelContent: some View {
        if showingConfigureRule, let url = browserManager.currentURL {
            ConfigureRuleView(
                browserManager: browserManager,
                interceptedURL: url,
                isPresented: $showingConfigureRule,
                onSave: { dismissPicker() }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            VStack(alignment: .center, spacing: 0) {
                // URL bubble — header of the panel
                if let url = browserManager.currentURL {
                    urlBubble(url: url)
                    Divider().opacity(0.5)
                }

                // Main browser bar or empty state
                if browserManager.configuredBrowsers.isEmpty {
                    emptyStatePill
                } else {
                    browserBarPill
                }

                // Keyboard hints row — footer
                if !browserManager.configuredBrowsers.isEmpty {
                    Divider().opacity(0.5)
                    keyboardHintsRow
                }

                // Hidden test label for UI tests
                if AppEnvironment.isUITesting {
                    Text(browserManager.lastOpenedBrowserBundleIDForTesting ?? "none")
                        .font(.system(size: 1))
                        .foregroundStyle(.clear)
                        .accessibilityIdentifier("picker.lastOpenedBrowser")
                }
            }
            .frame(width: pickerWidth)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    var body: some View {
        panelContent
            .fixedSize(horizontal: false, vertical: true)
            .background(panelBackground)
            .overlay(panelOverlay)
            .padding(64) // Increased room for softer, wider glowing shadows
            .scaleEffect(appeared ? 1.0 : 0.96)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0.2), value: privateMode)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingConfigureRule)
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
            .onChange(of: browserManager.configuredBrowsers) {
                syncKeyboardSelection(with: browserManager.configuredBrowsers)
            }
    }

    @ViewBuilder
    private var panelBackground: some View {
        ZStack {
            // 1. Isolate the shadow safely so it perfectly traces a RoundedRectangle 
            // without being dragged into a box shape by the VisualEffectView NSView bounds.
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black)
                    .shadow(
                        color: privateMode ? Color.purple.opacity(0.7) : .black.opacity(0.25),
                        radius: privateMode ? 20 : 10,
                        y: privateMode ? 0 : 4
                    )
                
                // Punch out the center completely so the NSVisualEffectView can see the desktop through the window
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()

            // 2. Frosted glass backdrop blur beneath the tint
            VisualEffectBackground(material: .menu, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // 3. The actual color tint
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(privateMode ? Color(red: 0.15, green: 0.05, blue: 0.25).opacity(0.85) : Color(NSColor.windowBackgroundColor).opacity(0.65))
        }
    }

    @ViewBuilder
    private var panelOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(privateMode ? Color.purple.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 0.5)
    }

    private func handleAppear() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            appeared = true
        }
        syncKeyboardSelection(with: browserManager.configuredBrowsers)
        installKeyEventMonitor()

        if !AppEnvironment.isUITesting {
            DispatchQueue.main.async {
                guard let window = NSApp.windows.first(where: {
                    $0.isVisible && $0.identifier?.rawValue == "picker" && $0.contentView != nil
                }) else { return }

                focusObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResignKeyNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    dismissTask?.cancel()
                    let work = DispatchWorkItem {
                        if let w = NSApp.windows.first(where: {
                            $0.identifier?.rawValue == "picker" && $0.isVisible
                        }), !w.isKeyWindow, w.attachedSheet == nil {
                            dismissPicker()
                        }
                    }
                    dismissTask = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
                }
            }
        }
    }

    private func handleDisappear() {
        if let observer = focusObserver {
            NotificationCenter.default.removeObserver(observer)
            focusObserver = nil
        }
        removeKeyEventMonitor()
        dismissTask?.cancel()
        dismissTask = nil
    }

    // MARK: - URL Bubble

    private func urlBubble(url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(url.host ?? url.absoluteString)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(action: { showingConfigureRule = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(privateMode ? Color.purple.opacity(0.8) : Color.secondary)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Add routing rule for this URL (R)")
                .accessibilityIdentifier("picker.configureRuleButton")
                .accessibilityLabel("Add routing rule")

                if isUnshortening {
                    ProgressView()
                        .controlSize(.small)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
                } else if unshorteningError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.red)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
                        .help(unshorteningError ?? "Failed to unshorten")
                }

                Button(action: { copyCurrentURL(url) }) {
                    Image(systemName: urlCopied ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(urlCopied ? Color.green : (privateMode ? Color.purple.opacity(0.8) : Color.secondary))
                        .contentTransition(.symbolEffect(.replace))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Copy URL (⌘C)")
                .accessibilityLabel("Copy URL")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityIdentifier("picker.urlDisplay")
    }

    // MARK: - Browser Bar Pill

    private var browserBarPill: some View {
        let browsers = browserManager.configuredBrowsers
        let showScroll = browsers.count > 8

        return HStack(alignment: .top, spacing: 4) {
            if showScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 2) {
                        ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
                            browserIconButton(browser: browser, index: index)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            } else {
                ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
                    browserIconButton(browser: browser, index: index)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func browserIconButton(browser: BrowserConfig, index: Int) -> some View {
        let isSelected = keyboardSelectedBrowserId == browser.id
        let isHovered = hoveredBrowserId == browser.id

        return Button(action: {
            let usePrivate = privateMode || NSEvent.modifierFlags.contains(.option)
            openUrl(with: browser, usePrivateMode: usePrivate)
        }) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? (privateMode ? Color.purple.opacity(0.3) : Color.primary.opacity(0.12)) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isSelected ? (privateMode ? Color.purple.opacity(0.5) : Color.primary.opacity(0.08)) : Color.clear, lineWidth: 1)
                        )
                        .frame(width: 54, height: 54)

                    if let icon = BrowserManager.icon(forBrowserBundleID: browser.bundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 34, height: 34)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 32, height: 32)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(browser.shortcutKey)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(NSColor.windowBackgroundColor).opacity(0.95)))
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .padding(2)
                        .offset(x: 2, y: 2)
                }

                // Selection & Browser name label
                Text(displayName(for: browser))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? (privateMode ? Color.purple : Color.primary) : Color.primary.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 58)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("picker.browserRow")
        .accessibilityLabel("Open in \(browser.name)")
        .help(toolTip(for: browser))
        .onHover { hovering in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.65)) {
                hoveredBrowserId = hovering ? browser.id : nil
                if hovering { keyboardSelectedBrowserId = browser.id }
            }
        }
        .scaleEffect(isHovered ? 1.05 : (isSelected ? 1.02 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.8)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.65).delay(Double(index) * 0.03),
            value: appeared
        )
    }

    // MARK: - Keyboard Hints Row

    private var keyboardHintsRow: some View {
        HStack(spacing: 6) {
            keyHintChip(keys: ["P"], label: "Private", isActive: privateMode)
            keyHintChip(keys: ["H"], label: "Resolve", isDisabled: browserManager.currentURL == nil || isUnshortening)
            keyHintChip(keys: ["R"], label: "Rules", isDisabled: browserManager.currentURL == nil)
            keyHintChip(keys: ["Esc"], label: "Close")
            Spacer()
            keyHintChip(keys: ["↵"], label: "Launch", isAccent: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(appeared ? 1 : 0)
        .animation(.easeIn(duration: 0.2).delay(0.3), value: appeared)
    }

    private func keyHintChip(keys: [String], label: String, isActive: Bool = false, isAccent: Bool = false, isDisabled: Bool = false) -> some View {
        let opacity: Double = isDisabled ? 0.3 : 1.0
        return HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isAccent ? .white : (isActive ? Color.purple : Color.primary.opacity(0.6)))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                isAccent ? Color.accentColor.opacity(0.8) :
                                    (isActive ? Color.purple.opacity(0.2) : Color.primary.opacity(0.1))
                            )
                    )
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(
                    isAccent ? Color.accentColor :
                        (isActive ? Color.purple : Color.secondary)
                )
        }
        .opacity(opacity)
    }

    // MARK: - Empty State

    private var emptyStatePill: some View {
        HStack(spacing: 12) {
            Image(nsImage: BrowserManager.currentAppIcon())
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
                .opacity(0.8)
            VStack(alignment: .leading, spacing: 2) {
                Text("No browsers configured")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Open Settings from the menu bar to add a browser.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .accessibilityIdentifier("picker.emptyState")
    }

    // MARK: - Layout

    private var pickerWidth: CGFloat {
        let count = max(1, CGFloat(browserManager.configuredBrowsers.count))
        let iconSize: CGFloat = 58  // 54pt hit area + margin
        let iconSpacing: CGFloat = 4
        let horizontalPad: CGFloat = 36 // 18 each side
        let computed = horizontalPad + count * iconSize + max(0, count - 1) * iconSpacing
        return max(320, min(800, computed)) // Limits 
    }

    private func displayName(for browser: BrowserConfig) -> String {
        guard browser.profile != nil,
              let dash = browser.name.range(of: " - ") else {
            return browser.name
        }
        return String(browser.name[..<dash.lowerBound])
    }

    private func displayProfileLabel(for browser: BrowserConfig) -> String? {
        guard browser.profile != nil else { return nil }
        if let dash = browser.name.range(of: " - ") {
            let suffix = String(browser.name[dash.upperBound...])
            return suffix.isEmpty ? nil : suffix
        }
        return browser.profile
    }

    private func toolTip(for browser: BrowserConfig) -> String {
        var tip = browser.name
        if let label = displayProfileLabel(for: browser) {
            tip += " – \(label)"
        }
        return tip
    }

    // MARK: - Dismiss

    private func dismissPicker() {
        privateMode = false
        showingConfigureRule = false
        browserManager.currentURL = nil
        for window in NSApp.windows where window.isVisible && window.identifier?.rawValue == "picker" {
            window.orderOut(nil)
        }
    }

    // MARK: - Browser Action

    private func openUrl(with browser: BrowserConfig, usePrivateMode: Bool = false) {
        guard let url = browserManager.currentURL else { return }
        dismissPicker()
        browserManager.open(url: url, withBrowserBundleID: browser.bundleId, profile: browser.profile, usePrivateMode: usePrivateMode)
    }

    private func copyCurrentURL(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        withAnimation(.spring(response: 0.2)) { urlCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.2)) { urlCopied = false }
        }
    }

    // MARK: - Keyboard Selection

    private func syncKeyboardSelection(with browsers: [BrowserConfig]) {
        guard !browsers.isEmpty else { keyboardSelectedBrowserId = nil; return }
        if let selectedId = keyboardSelectedBrowserId, browsers.contains(where: { $0.id == selectedId }) { return }
        keyboardSelectedBrowserId = browsers.first?.id
    }

    private func installKeyEventMonitor() {
        removeKeyEventMonitor()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handlePickerKeyDown(event) ? nil : event
        }
    }

    private func removeKeyEventMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    private func handlePickerKeyDown(_ event: NSEvent) -> Bool {
        guard isPickerEvent(event) else { return false }

        // Escape — close sheet if open, otherwise dismiss picker
        if event.keyCode == 53 {
            if showingConfigureRule { showingConfigureRule = false; return true }
            dismissPicker()
            return true
        }

        // Cmd+C — copy URL
        if event.modifierFlags.contains(.command) && event.keyCode == 8 {
            if let url = browserManager.currentURL { copyCurrentURL(url) }
            return true
        }

        // Number keys — open by shortcut
        if let shortcutKey = normalizedShortcutKey(from: event) {
            let usePrivateMode = privateMode || event.modifierFlags.contains(.option)
            return openBrowser(matchingShortcutKey: shortcutKey, usePrivateMode: usePrivateMode)
        }

        // Letter shortcuts (handled before general initial-navigation)
        if let letter = normalizedLetterKey(from: event) {
            switch letter {
            case "p":
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) { privateMode.toggle() }
                return true
            case "r":
                if browserManager.currentURL != nil { showingConfigureRule = true }
                return true
            case "h", "s":
                if !isUnshortening, browserManager.currentURL != nil { performManualUnshorten() }
                return true
            default:
                return selectNextBrowser(matchingInitial: letter)
            }
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 48 { // tab
            let blocked: NSEvent.ModifierFlags = [.command, .control, .option, .function]
            if modifiers.intersection(blocked).isEmpty {
                moveSelection(by: modifiers.contains(.shift) ? -1 : 1)
                return true
            }
        }

        // .option excluded so ⌥+Return triggers private-mode open
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .function, .shift]
        if !modifiers.intersection(disallowed).isEmpty { return false }

        switch event.keyCode {
        case 125: moveSelection(by: 1); return true       // ↓
        case 126: moveSelection(by: -1); return true      // ↑
        case 123: moveSelection(by: -1); return true      // ←
        case 124: moveSelection(by: 1); return true       // →
        case 36, 76, 49:                                  // return / enter / space
            let usePrivateMode = privateMode || event.modifierFlags.contains(.option)
            return openSelectedBrowser(usePrivateMode: usePrivateMode)
        default: return false
        }
    }

    private func normalizedShortcutKey(from event: NSEvent) -> String? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.intersection([.control, .function]).isEmpty else { return nil }
        if let key = digitKeycodeMap[event.keyCode] { return key }
        guard let chars = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines),
              chars.count == 1, let c = chars.first, c.isNumber else { return nil }
        return String(c)
    }

    private func normalizedLetterKey(from event: NSEvent) -> Character? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.intersection([.command, .control, .function, .option]).isEmpty else { return nil }
        guard let chars = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines),
              chars.count == 1,
              let c = chars.lowercased().first,
              String(c).rangeOfCharacter(from: .letters) != nil else { return nil }
        return c
    }

    private func isPickerEvent(_ event: NSEvent) -> Bool {
        event.window?.identifier?.rawValue == "picker"
            || NSApp.keyWindow?.identifier?.rawValue == "picker"
            || NSApp.mainWindow?.identifier?.rawValue == "picker"
    }

    private var digitKeycodeMap: [UInt16: String] {
        [18:"1", 19:"2", 20:"3", 21:"4", 23:"5", 22:"6", 26:"7", 28:"8", 25:"9",
         83:"1", 84:"2", 85:"3", 86:"4", 87:"5", 88:"6", 89:"7", 91:"8", 92:"9"]
    }

    private func openBrowser(matchingShortcutKey key: String, usePrivateMode: Bool = false) -> Bool {
        guard let browser = browserManager.configuredBrowsers.first(where: { $0.shortcutKey == key }) else { return false }
        keyboardSelectedBrowserId = browser.id
        openUrl(with: browser, usePrivateMode: usePrivateMode)
        return true
    }

    private func selectNextBrowser(matchingInitial initial: Character) -> Bool {
        let normalizedInitial = String(initial).lowercased()
        let matching = browserManager.configuredBrowsers.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().first.map { String($0) } == normalizedInitial
        }
        guard !matching.isEmpty else { return false }
        if let selectedId = keyboardSelectedBrowserId,
           let currentIndex = matching.firstIndex(where: { $0.id == selectedId }) {
            keyboardSelectedBrowserId = matching[(currentIndex + 1) % matching.count].id
        } else {
            keyboardSelectedBrowserId = matching.first?.id
        }
        return true
    }

    private func moveSelection(by delta: Int) {
        let browsers = browserManager.configuredBrowsers
        guard !browsers.isEmpty else { keyboardSelectedBrowserId = nil; return }
        guard let currentId = keyboardSelectedBrowserId,
              let currentIndex = browsers.firstIndex(where: { $0.id == currentId }) else {
            keyboardSelectedBrowserId = browsers.first?.id
            return
        }
        keyboardSelectedBrowserId = browsers[(currentIndex + delta + browsers.count) % browsers.count].id
    }

    private func openSelectedBrowser(usePrivateMode: Bool = false) -> Bool {
        let browsers = browserManager.configuredBrowsers
        guard !browsers.isEmpty else { return false }
        guard let selectedId = keyboardSelectedBrowserId,
              let browser = browsers.first(where: { $0.id == selectedId }) else {
            if let first = browsers.first {
                keyboardSelectedBrowserId = first.id
                openUrl(with: first, usePrivateMode: usePrivateMode)
                return true
            }
            return false
        }
        openUrl(with: browser, usePrivateMode: usePrivateMode)
        return true
    }

    private func performManualUnshorten() {
        guard let url = browserManager.currentURL else { return }
        isUnshortening = true
        unshorteningError = nil
        
        Task {
            do {
                let resolved = try await browserManager.manualUnshortenURL(url)
                await MainActor.run {
                    browserManager.currentURL = resolved
                    self.isUnshortening = false
                }
            } catch {
                await MainActor.run {
                    self.isUnshortening = false
                    self.unshorteningError = "Couldn't resolve. It might not be a redirect."
                    
                    // Clear error after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.unshorteningError != nil {
                            withAnimation { self.unshorteningError = nil }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .onAppear {
            BrowserManager.shared.currentURL = URL(string: "https://github.com/nickcoutsos")
        }
}
