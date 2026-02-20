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
    @Environment(\.openWindow) var openWindow
    @State private var hoveredBrowserId: UUID?
    @State private var appeared = false
    @State private var dismissTask: DispatchWorkItem?
    @State private var focusObserver: NSObjectProtocol?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .opacity(0.3)
            
            // URL display
            if let url = browserManager.currentURL {
                urlDisplay(url: url)
            }
            
            // Browser list
            browserList

            if AppEnvironment.isUITesting {
                Text(browserManager.lastOpenedBrowserBundleIDForTesting ?? "none")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("picker.lastOpenedBrowser")
            }
        }
        .frame(width: 364)
        .modifier(PickerSurfaceModifier())
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
            if !AppEnvironment.isUITesting {
                // Close when the picker window itself loses focus (click outside).
                // Use DispatchQueue.main.async so the window is available.
                DispatchQueue.main.async {
                    guard let window = NSApp.windows.first(where: {
                        $0.isVisible && $0.identifier?.rawValue == "picker"
                        && $0.contentView != nil
                    }) else { return }

                    focusObserver = NotificationCenter.default.addObserver(
                        forName: NSWindow.didResignKeyNotification,
                        object: window,
                        queue: .main
                    ) { _ in
                        // Debounce: tolerate transient focus losses.
                        dismissTask?.cancel()
                        let work = DispatchWorkItem {
                            // Only dismiss if the picker window is still not key.
                            if let w = NSApp.windows.first(where: {
                                $0.identifier?.rawValue == "picker" && $0.isVisible
                            }), !w.isKeyWindow {
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
            // Clean up observer to prevent accumulation
            if let observer = focusObserver {
                NotificationCenter.default.removeObserver(observer)
                focusObserver = nil
            }
            dismissTask?.cancel()
            dismissTask = nil
        }
        .scaleEffect(appeared ? 1.0 : 0.9)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("openSettingsWindow"))) { _ in
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 0) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text("Open with…")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button(action: {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .modifier(PickerCircleButtonBackgroundModifier())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("picker.openSettingsButton")
            .accessibilityLabel("Open Settings")
            .accessibilityHint("Opens the Chowser settings window")
            

            Button(action: dismissPicker) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .modifier(PickerCircleButtonBackgroundModifier())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("picker.closeButton")
            .accessibilityLabel("Close browser picker")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    // MARK: - URL Display
    
    private func urlDisplay(url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(url.path.isEmpty ? "/" : url.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.03))
        .accessibilityIdentifier("picker.urlDisplay")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("URL: \(url.absoluteString)")
    }
    
    // MARK: - Browser List
    
    private var browserList: some View {
        Group {
            if browserManager.configuredBrowsers.isEmpty {
                VStack(spacing: 10) {
                    Image(nsImage: BrowserManager.currentAppIcon())
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 42, height: 42)
                        .opacity(0.9)
                    Text("No browsers configured")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Open Settings to add at least one browser.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Button("Open Settings") {
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("picker.emptyState.openSettingsButton")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(browserManager.configuredBrowsers.enumerated()), id: \.element.id) { index, browser in
                        browserRow(browser: browser, index: index)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }
    
    private func browserRow(browser: BrowserConfig, index: Int) -> some View {
        let isHovered = hoveredBrowserId == browser.id
        
        return Button(action: {
            openUrl(with: browser)
        }) {
            HStack(spacing: 10) {
                // App icon
                Group {
                    if let icon = getAppIcon(bundleId: browser.bundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                
                // Browser name
                Text(browser.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Keyboard shortcut badge
                Text("⌘ ⇧ \(browser.shortcutKey)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .modifier(PickerShortcutBadgeBackgroundModifier())
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? .white.opacity(0.1) : .clear)
            )
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("picker.browserRow")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredBrowserId = hovering ? browser.id : nil
            }
        }
        .keyboardShortcut(KeyEquivalent(browser.shortcutKey.first ?? "1"), modifiers: [.command, .shift])
        .accessibilityLabel("Open in \(browser.name)")
        .accessibilityHint("Opens the link in \(browser.name). Shortcut: Command + Shift + \(browser.shortcutKey)")
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.03), value: appeared)
    }
    
    // MARK: - Dismiss
    
    private func dismissPicker() {
        browserManager.currentURL = nil
        // Close the picker window(s) — don't hide the entire app.
        // As an LSUIElement app, Chowser naturally stays in the background.
        for window in NSApp.windows where window.isVisible && window.identifier?.rawValue == "picker" {
            window.close()
        }
    }

    // MARK: - Helpers
    
    private func getAppIcon(bundleId: String) -> NSImage? {
        BrowserManager.icon(forBrowserBundleID: bundleId)
    }

    private func openUrl(with browser: BrowserConfig) {
        guard let url = browserManager.currentURL else { return }
        
        // Dismiss immediately — don't wait for the browser to open
        dismissPicker()

        if AppEnvironment.shouldDisableExternalURLOpen {
            browserManager.lastOpenedBrowserBundleIDForTesting = browser.bundleId
            return
        }
        
        let workspace = NSWorkspace.shared
        if let appUrl = workspace.urlForApplication(withBundleIdentifier: browser.bundleId) {
            let configuration = NSWorkspace.OpenConfiguration()
            workspace.open([url], withApplicationAt: appUrl, configuration: configuration) { _, error in
                if let error = error {
                    print("Failed to open URL: \(error)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .onAppear {
            BrowserManager.shared.currentURL = URL(string: "https://sreerams.in")
        }
}

private struct PickerSurfaceModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                content
                    .padding(1)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 0.8)
                    )
            }
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

private struct PickerCircleButtonBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.white.opacity(0.05))
                .clipShape(Circle())
        }
    }
}

private struct PickerShortcutBadgeBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.white.opacity(0.06))
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
        }
    }
}
