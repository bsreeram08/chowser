//
//  ContentView.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI
import AppKit

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

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // URL bubble — floating pill above the browser bar
            if let url = browserManager.currentURL {
                urlBubble(url: url)
            }

            // Main browser bar pill or empty state
            if browserManager.configuredBrowsers.isEmpty {
                emptyStatePill
            } else {
                browserBarPill
            }

            // Keyboard hints row
            if !browserManager.configuredBrowsers.isEmpty {
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
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14) // room for pill shadows/stroke to breathe
        .scaleEffect(appeared ? 1.0 : 0.94)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
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
        .onDisappear {
            if let observer = focusObserver {
                NotificationCenter.default.removeObserver(observer)
                focusObserver = nil
            }
            removeKeyEventMonitor()
            dismissTask?.cancel()
            dismissTask = nil
        }
        .onChange(of: browserManager.configuredBrowsers) {
            syncKeyboardSelection(with: browserManager.configuredBrowsers)
        }
        .sheet(isPresented: $showingConfigureRule) {
            if let url = browserManager.currentURL {
                ConfigureRuleView(
                    browserManager: browserManager,
                    interceptedURL: url,
                    isPresented: $showingConfigureRule,
                    onSave: { dismissPicker() }
                )
            }
        }
    }

    // MARK: - URL Bubble

    private func urlBubble(url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            Text(url.host ?? url.absoluteString)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Button(action: { copyCurrentURL(url) }) {
                Image(systemName: urlCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(urlCopied ? Color.green : .white.opacity(0.35))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help("Copy URL (⌘C)")
            .accessibilityLabel("Copy URL")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(pillBackground))
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 5)
        .accessibilityIdentifier("picker.urlDisplay")
    }

    // MARK: - Browser Bar Pill

    private var browserBarPill: some View {
        let browsers = browserManager.configuredBrowsers
        let hasActions = browserManager.currentURL != nil
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

            if hasActions {
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)

                privateModeButton
                addRuleButton
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(pillBackground))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 22, y: 8)
    }

    private func browserIconButton(browser: BrowserConfig, index: Int) -> some View {
        let isSelected = keyboardSelectedBrowserId == browser.id
        let isHovered = hoveredBrowserId == browser.id

        return Button(action: {
            let usePrivate = privateMode || NSEvent.modifierFlags.contains(.option)
            openUrl(with: browser, usePrivateMode: usePrivate)
        }) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(isSelected ? 0.15 : (isHovered ? 0.07 : 0)))
                        .frame(width: 48, height: 48)

                    if let icon = BrowserManager.icon(forBrowserBundleID: browser.bundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(browser.shortcutKey)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .padding(2)
                }

                // Selection indicator dot
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)

                // Browser name label
                Text(displayName(for: browser))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 0.85 : 0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 52)
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
        .scaleEffect(isHovered ? 1.08 : (isSelected ? 1.04 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isSelected)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.5)
        .animation(
            .spring(response: 0.38, dampingFraction: 0.6).delay(Double(index) * 0.045),
            value: appeared
        )
    }

    private var privateModeButton: some View {
        VStack(spacing: 2) {
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                    privateMode.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(privateMode ? Color.purple.opacity(0.22) : Color.clear)
                        .frame(width: 38, height: 38)
                    Image(systemName: privateMode ? "eye.slash.fill" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(privateMode ? Color.purple : .white.opacity(0.45))
                }
                .frame(width: 48, height: 48) // matches browser icon frame
            }
            .buttonStyle(.plain)
            .help(privateMode ? "Private mode on – click to disable (P)" : "Enable private mode (P)")
            .accessibilityLabel(privateMode ? "Disable private mode" : "Enable private mode")

            Color.clear.frame(width: 4, height: 4) // dot-row spacer

            Text("Private")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(privateMode ? Color.purple.opacity(0.8) : .white.opacity(0.35))
                .lineLimit(1)
        }
    }

    private var addRuleButton: some View {
        VStack(spacing: 2) {
            Button(action: { showingConfigureRule = true }) {
                ZStack {
                    Color.clear.frame(width: 38, height: 38)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(width: 48, height: 48) // matches browser icon frame
            }
            .buttonStyle(.plain)
            .help("Add routing rule (R)")
            .accessibilityIdentifier("picker.configureRuleButton")
            .accessibilityLabel("Add routing rule for this URL")

            Color.clear.frame(width: 4, height: 4) // dot-row spacer

            Text("Rule")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
                .lineLimit(1)
        }
    }

    // MARK: - Keyboard Hints Row

    private var keyboardHintsRow: some View {
        HStack(spacing: 6) {
            keyHintChip(keys: ["P"], label: "PRIVATE", isActive: privateMode)
            keyHintChip(keys: ["R"], label: "RULE", isDisabled: browserManager.currentURL == nil)
            keyHintChip(keys: ["Esc"], label: "CLOSE")
            Spacer()
            keyHintChip(keys: ["↵"], label: "LAUNCH", isAccent: true)
        }
        .padding(.horizontal, 2)
        .opacity(appeared ? 1 : 0)
        .animation(.easeIn(duration: 0.2).delay(0.3), value: appeared)
    }

    private func keyHintChip(keys: [String], label: String, isActive: Bool = false, isAccent: Bool = false, isDisabled: Bool = false) -> some View {
        let opacity: Double = isDisabled ? 0.3 : 1.0
        return HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isAccent ? .white : (isActive ? Color.purple : .white.opacity(0.55)))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                isAccent ? Color.accentColor.opacity(0.75) :
                                    (isActive ? Color.purple.opacity(0.3) : .white.opacity(0.1))
                            )
                    )
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(
                    isAccent ? Color.accentColor :
                        (isActive ? Color.purple : .white.opacity(0.32))
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
                .frame(width: 28, height: 28)
                .opacity(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text("No browsers configured")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Open Settings from the menu bar to add a browser.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(pillBackground))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.4), radius: 18, y: 6)
        .accessibilityIdentifier("picker.emptyState")
    }

    // MARK: - Layout

    private var pillBackground: Color {
        Color(red: 0.118, green: 0.118, blue: 0.118)
    }

    private var pickerWidth: CGFloat {
        let count = max(1, CGFloat(browserManager.configuredBrowsers.count))
        let iconSize: CGFloat = 52  // 48pt circle + small horizontal margin
        let iconSpacing: CGFloat = 2
        let actionsWidth: CGFloat = browserManager.currentURL != nil ? (1 + 16 + 38 + 4 + 38) : 0
        let horizontalPad: CGFloat = 20
        let computed = horizontalPad + count * iconSize + max(0, count - 1) * iconSpacing + actionsWidth
        return max(270, min(620, computed))
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
}

#Preview {
    ContentView()
        .onAppear {
            BrowserManager.shared.currentURL = URL(string: "https://github.com/nickcoutsos")
        }
}
