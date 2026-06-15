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
    @State private var isUnshortening = false
    @State private var unshorteningError: String? = nil

    private var supportsPrivateLaunchMode: Bool {
        BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild
    }

    private var effectivePrivateMode: Bool {
        supportsPrivateLaunchMode && privateMode
    }

    @ViewBuilder
    private var panelContent: some View {
        if showingConfigureRule, let url = browserManager.currentURL {
            ConfigureRuleView(
                browserManager: browserManager,
                interceptedURL: url,
                isPresented: $showingConfigureRule,
                onSave: { dismissPicker() },
                preselectedBrowserBundleId: suggestedBrowserBundleId
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
            .pickerPanelSurface()
            .padding(64) // Increased room for softer, wider glowing shadows
            .scaleEffect(appeared ? 1.0 : 0.96)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0.2), value: effectivePrivateMode)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingConfigureRule)
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
            .onChange(of: browserManager.currentURL) {
                syncPrivateModeRequest()
            }
            .onChange(of: browserManager.currentURLPrivateModeRequested) {
                syncPrivateModeRequest()
            }
            .onChange(of: browserManager.configuredBrowsers) {
                syncKeyboardSelection(with: browserManager.configuredBrowsers)
            }
    }

    private func handleAppear() {
        syncPrivateModeRequest()

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

    private func syncPrivateModeRequest() {
        privateMode = supportsPrivateLaunchMode && browserManager.currentURLPrivateModeRequested
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
                        .foregroundStyle(effectivePrivateMode ? Color.purple.opacity(0.8) : Color.secondary)
                        .padding(6)
                        .pickerInteractiveMiniButton()
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
                        .foregroundStyle(urlCopied ? Color.green : (effectivePrivateMode ? Color.purple.opacity(0.8) : Color.secondary))
                        .contentTransition(.symbolEffect(.replace))
                        .padding(6)
                        .pickerInteractiveMiniButton()
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

    /// Returns browsers in the user's configured order (never reordered).
    private var sortedBrowsers: [BrowserConfig] {
        browserManager.configuredBrowsers
    }

    /// Returns the bundle ID of the browser most frequently used for the current domain,
    /// but only when there is a clear dominant choice (≥5 uses and ≥60% of total clicks).
    private var suggestedBrowserBundleId: String? {
        guard let url = browserManager.currentURL,
              let domain = url.host?.lowercased() else { return nil }
        let domainStats = DomainFrequencyTracker.shared.stats(for: domain)
        guard !domainStats.isEmpty else { return nil }

        // Already have a routing rule for this domain — no need to suggest
        if browserManager.resolvedRoute(for: url) != nil { return nil }

        let total = domainStats.values.reduce(0, +)
        guard total >= 5 else { return nil }

        if let (topBundleId, topCount) = domainStats.max(by: { $0.value < $1.value }),
           Double(topCount) / Double(total) >= 0.6 {
            // Only suggest if the browser is still configured
            guard browserManager.configuredBrowsers.contains(where: { $0.bundleId == topBundleId }) else { return nil }
            return topBundleId
        }
        return nil
    }

    private var browserBarPill: some View {
        let browsers = sortedBrowsers
        let isListMode = browserManager.pickerLayoutMode == "list"

        return VStack(spacing: 0) {
            if isListMode {
                browserListLayout(browsers: browsers)
            } else {
                browserIconsLayout(browsers: browsers)
            }

            // Subtle rule suggestion banner
            if let suggestedId = suggestedBrowserBundleId,
               let browser = browserManager.configuredBrowsers.first(where: { $0.bundleId == suggestedId }),
               let domain = browserManager.currentURL?.host {
                Button(action: { showingConfigureRule = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        Text("Always open \(domain) in \(browser.name)?")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .pickerInlineCard()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func browserIconsLayout(browsers: [BrowserConfig]) -> some View {
        let showScroll = browsers.count > 8

        HStack(alignment: .top, spacing: 4) {
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

    @ViewBuilder
    private func browserListLayout(browsers: [BrowserConfig]) -> some View {
        let showScroll = browsers.count > 6

        if showScroll {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
                            browserListRow(browser: browser, index: index)
                                .id(browser.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .onChange(of: keyboardSelectedBrowserId) { _, id in
                        guard let id else { return }
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        } else {
            VStack(spacing: 2) {
                ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
                    browserListRow(browser: browser, index: index)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func browserListRow(browser: BrowserConfig, index: Int) -> some View {
        let isSelected = keyboardSelectedBrowserId == browser.id
        let isHovered = hoveredBrowserId == browser.id
        let isSuggested = suggestedBrowserBundleId == browser.bundleId

        return Button(action: {
            let usePrivate = requestedPrivateMode(modifierFlags: NSEvent.modifierFlags)
            openUrl(with: browser, usePrivateMode: usePrivate)
        }) {
            HStack(spacing: 10) {
                if let icon = BrowserManager.icon(forBrowserBundleID: browser.bundleId) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(browser.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? (effectivePrivateMode ? Color.purple : .primary) : .primary)
                        .lineLimit(1)

                    if let profileLabel = displayProfileLabel(for: browser) {
                        Text(profileLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSuggested {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }

                Text(browser.shortcutKey)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .pickerBadgeChip()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? (effectivePrivateMode ? Color.purple.opacity(0.2) : Color.primary.opacity(0.1)) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("picker.browserRow")
        .accessibilityLabel("Open in \(browser.name)")
        .onHover { hovering in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.65)) {
                hoveredBrowserId = hovering ? browser.id : nil
                if hovering { keyboardSelectedBrowserId = browser.id }
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.02),
            value: appeared
        )
    }

    private func browserIconButton(browser: BrowserConfig, index: Int) -> some View {
        let isSelected = keyboardSelectedBrowserId == browser.id
        let isHovered = hoveredBrowserId == browser.id
        let isSuggested = suggestedBrowserBundleId == browser.bundleId
        let iconDimensions = pickerIconDimensions

        return Button(action: {
            let usePrivate = requestedPrivateMode(modifierFlags: NSEvent.modifierFlags)
            openUrl(with: browser, usePrivateMode: usePrivate)
        }) {
            VStack(spacing: 4) {
                ZStack {
                    browserIconHitAreaSurface(
                        isSelected: isSelected,
                        isHovered: isHovered,
                        isSuggested: isSuggested,
                        iconDimensions: iconDimensions
                    )

                    if let icon = BrowserManager.icon(forBrowserBundleID: browser.bundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: iconDimensions.icon, height: iconDimensions.icon)
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: iconDimensions.icon * 0.53))
                            .foregroundStyle(Color.secondary)
                            .frame(width: iconDimensions.icon, height: iconDimensions.icon)
                    }
                }
                .overlay(alignment: .topLeading) {
                    // Small suggested star badge
                    if isSuggested {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .padding(3)
                            .background(Circle().fill(Color(NSColor.windowBackgroundColor).opacity(0.95)))
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 2)
                            .offset(x: -2, y: -2)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(browser.shortcutKey)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .pickerBadgeChip()
                        .padding(2)
                        .offset(x: 2, y: 2)
                }

                // Selection & Browser name label
                if browserManager.pickerShowLabels {
                    Text(displayName(for: browser))
                        .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? (effectivePrivateMode ? Color.purple : Color.primary) : Color.primary.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: iconDimensions.hitArea + 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("picker.browserRow")
        .accessibilityLabel("Open in \(browser.name)")
        .help(isSuggested ? "Suggested — you often open this domain in \(browser.name)" : toolTip(for: browser))
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

    @ViewBuilder
    private func browserIconHitAreaSurface(
        isSelected: Bool,
        isHovered: Bool,
        isSuggested: Bool,
        iconDimensions: IconDimensions
    ) -> some View {
        let cornerRadius: CGFloat = 12
        let highlightColor = isSelected
            ? (effectivePrivateMode ? Color.purple.opacity(0.3) : Color.primary.opacity(0.12))
            : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
        let selectionStrokeColor = isSelected
            ? (effectivePrivateMode ? Color.purple.opacity(0.5) : Color.primary.opacity(0.08))
            : Color.clear

        ZStack {
            if isSelected || isHovered {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(highlightColor)
                    .frame(width: iconDimensions.hitArea, height: iconDimensions.hitArea)
                    .pickerInlineCard()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: iconDimensions.hitArea, height: iconDimensions.hitArea)
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(selectionStrokeColor, lineWidth: 1)
                .frame(width: iconDimensions.hitArea, height: iconDimensions.hitArea)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isSuggested ? 0.5 : 0), lineWidth: 1.5)
                .shadow(color: Color.accentColor.opacity(isSuggested ? 0.3 : 0), radius: 4)
                .frame(width: iconDimensions.hitArea, height: iconDimensions.hitArea)
        }
    }

    // MARK: - Keyboard Hints Row

    private var keyboardHintsRow: some View {
        HStack(spacing: 6) {
            if supportsPrivateLaunchMode {
                keyHintChip(keys: ["P"], label: "Private", isActive: effectivePrivateMode)
            }
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
                    .foregroundStyle(isAccent ? Color.accentColor : (isActive ? Color.purple : Color.primary.opacity(0.6)))
                    .fixedSize()
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .pickerBadgeChip()
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .fixedSize()
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

    private struct IconDimensions {
        let hitArea: CGFloat
        let icon: CGFloat
    }

    private var pickerIconDimensions: IconDimensions {
        switch browserManager.pickerIconSize {
        case "small":  return IconDimensions(hitArea: 40, icon: 24)
        case "large":  return IconDimensions(hitArea: 66, icon: 42)
        default:       return IconDimensions(hitArea: 54, icon: 34) // medium
        }
    }

    private var pickerWidth: CGFloat {
        if browserManager.pickerLayoutMode == "list" {
            return 400
        }
        let count = max(1, CGFloat(browserManager.configuredBrowsers.count))
        let dims = pickerIconDimensions
        let iconSize: CGFloat = dims.hitArea + 4 // hit area + margin
        let iconSpacing: CGFloat = 4
        let horizontalPad: CGFloat = 36 // 18 each side
        let computed = horizontalPad + count * iconSize + max(0, count - 1) * iconSpacing
        // Use available screen width as the upper bound instead of a fixed cap
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1440
        let maxWidth = min(screenWidth * 0.8, computed)
        return max(320, maxWidth)
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
        browserManager.currentURLPrivateModeRequested = false
        showingConfigureRule = false
        browserManager.currentURL = nil
        for window in NSApp.windows where window.isVisible && window.identifier?.rawValue == "picker" {
            window.orderOut(nil)
        }
    }

    // MARK: - Browser Action

    private func openUrl(with browser: BrowserConfig, usePrivateMode: Bool = false) {
        guard let url = browserManager.currentURL else { return }
        let effectiveUsePrivateMode = supportsPrivateLaunchMode && usePrivateMode
        dismissPicker()
        browserManager.open(url: url, withBrowserBundleID: browser.bundleId, profile: browser.profile, usePrivateMode: effectiveUsePrivateMode)
    }

    private func requestedPrivateMode(modifierFlags: NSEvent.ModifierFlags) -> Bool {
        supportsPrivateLaunchMode && (privateMode || modifierFlags.contains(.option))
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
            let usePrivateMode = requestedPrivateMode(modifierFlags: event.modifierFlags)
            return openBrowser(matchingShortcutKey: shortcutKey, usePrivateMode: usePrivateMode)
        }

        // Letter shortcuts (handled before general initial-navigation)
        if let letter = normalizedLetterKey(from: event) {
            switch letter {
            case "p":
                guard supportsPrivateLaunchMode else { return false }
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

        // Arrow keys — handled before the general modifier check because macOS
        // always sets the .function flag for arrow keys which would otherwise
        // cause them to be filtered out. Still reject command/control/shift.
        if [125, 126, 123, 124].contains(event.keyCode) {
            let arrowDisallowed: NSEvent.ModifierFlags = [.command, .control, .shift]
            guard modifiers.subtracting(.function).intersection(arrowDisallowed).isEmpty else { return false }
            switch event.keyCode {
            case 125: moveSelection(by: 1); return true       // ↓
            case 126: moveSelection(by: -1); return true      // ↑
            case 123: moveSelection(by: -1); return true      // ←
            case 124: moveSelection(by: 1); return true       // →
            default: break
            }
        }

        // .option excluded so ⌥+Return triggers private-mode open
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .function, .shift]
        if !modifiers.intersection(disallowed).isEmpty { return false }

        switch event.keyCode {
        case 36, 76, 49:                                  // return / enter / space
            let usePrivateMode = requestedPrivateMode(modifierFlags: event.modifierFlags)
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
        let matching = sortedBrowsers.filter {
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
        let browsers = sortedBrowsers
        guard !browsers.isEmpty else { keyboardSelectedBrowserId = nil; return }
        guard let currentId = keyboardSelectedBrowserId,
              let currentIndex = browsers.firstIndex(where: { $0.id == currentId }) else {
            keyboardSelectedBrowserId = browsers.first?.id
            return
        }
        keyboardSelectedBrowserId = browsers[(currentIndex + delta + browsers.count) % browsers.count].id
    }

    private func openSelectedBrowser(usePrivateMode: Bool = false) -> Bool {
        let browsers = sortedBrowsers
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
