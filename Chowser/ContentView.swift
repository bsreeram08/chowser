//
//  ContentView.swift
//  Chowser
//
//  Created by Sreeram Balamurugan on 2/20/26.
//

import SwiftUI
import AppKit
import CoreImage
import os

struct ContentView: View {
    var browserManager = BrowserManager.shared
    /// When true the view is embedded in Settings as a live preview: no key monitor,
    /// no focus-dismiss, and clicks open the browser without tearing the preview down.
    var isPreview = false
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
    @State private var runningBundleIDs: Set<String> = []
    @State private var showingPhoneActionMenu = false
    @State private var showingPhoneQRSheet = false
    @State private var phoneMenuSelectedIndex = 0
    @State private var showingShortcutsInfo = false
    @State private var phoneHandoffAdapter = PhoneLinkHandoffAdapter()
    /// Link-preview lifecycle. One value at a time — no impossible combos.
    enum PreviewState {
        case idle
        case loading
        case skippedSingleUse  // one-time link; fetching would burn the token
        case unavailable(Int)  // server returned an HTTP error (e.g. 404)
        case noPreview         // reached, but no usable metadata (JSON/API/bare page)
        case loaded(LinkMetadata)

        var metadata: LinkMetadata? {
            if case let .loaded(meta) = self { return meta }
            return nil
        }
    }

    @State private var previewState: PreviewState = .idle
    @State private var previewTask: Task<Void, Never>?

    private var pickerColorSchemeOverride: ColorScheme? {
        switch browserManager.pickerColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func isBrowserRunning(_ browser: BrowserConfig) -> Bool {
        runningBundleIDs.contains(browser.bundleId.lowercased())
    }

    private func browserDimOpacity(_ browser: BrowserConfig) -> Double {
        guard browserManager.pickerDimInactiveBrowsers, !isPreview else { return 1.0 }
        return isBrowserRunning(browser) ? 1.0 : 0.4
    }

    private var supportsPrivateLaunchMode: Bool {
        BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild
    }

    private var effectivePrivateMode: Bool {
        supportsPrivateLaunchMode && privateMode
    }

    private var privateModeHelpText: String {
        supportsPrivateLaunchMode
            ? "Toggle private mode for the next launch (P)"
            : "Private mode is unavailable in App Store/TestFlight builds."
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
                    shortcutsInfoRow
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
            .padding(isPreview ? 24 : 64) // glow-shadow room; tighter in the Settings preview so the footer fits
            .scaleEffect(appeared ? 1.0 : 0.96)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0.2), value: effectivePrivateMode)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingConfigureRule)
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
            .onChange(of: browserManager.currentURL) {
                syncPrivateModeRequest()
                loadLinkPreview(for: browserManager.currentURL)
                syncPhoneHandoff()
            }
            .onChange(of: browserManager.currentURLPrivateModeRequested) {
                syncPrivateModeRequest()
            }
            .onChange(of: browserManager.configuredBrowsers) {
                syncKeyboardSelection(with: browserManager.configuredBrowsers)
            }
            .preferredColorScheme(pickerColorSchemeOverride)
    }

    private func handleAppear() {
        syncPrivateModeRequest()
        runningBundleIDs = BrowserManager.runningBrowserBundleIDs()
        loadLinkPreview(for: browserManager.currentURL)
        syncPhoneHandoff()

        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            appeared = true
        }
        syncKeyboardSelection(with: browserManager.configuredBrowsers)
        guard !isPreview else { return }
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
                        // Popovers (Send to Phone menu, QR, shortcuts help) take key
                        // status from the panel — that's not the user leaving, so don't
                        // tear the picker down under them.
                        if showingPhoneActionMenu || showingPhoneQRSheet || showingShortcutsInfo { return }
                        if let w = NSApp.windows.first(where: {
                            $0.identifier?.rawValue == "picker" && $0.isVisible
                        }), !w.isKeyWindow, w.attachedSheet == nil {
                            // Key window being one of the panel's children (e.g. a
                            // popover window) also counts as still-focused.
                            if let key = NSApp.keyWindow, w.childWindows?.contains(key) == true { return }
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
        previewTask?.cancel()
        previewTask = nil
        phoneHandoffAdapter.stop()
    }

    private func syncPrivateModeRequest() {
        privateMode = supportsPrivateLaunchMode && browserManager.currentURLPrivateModeRequested
    }

    /// Best-effort Handoff advertising, scoped to the picker's current URL — starts/updates
    /// while a valid HTTP(S) URL is showing, stops otherwise. `startOrUpdate` itself is a
    /// no-op for non-HTTP(S) URLs, so no extra validation is needed here.
    private func syncPhoneHandoff() {
        // Never broadcast a link the user marked private to every iCloud-paired device.
        if let url = browserManager.currentURL, !browserManager.currentURLPrivateModeRequested, !effectivePrivateMode {
            phoneHandoffAdapter.startOrUpdate(url)
        } else {
            phoneHandoffAdapter.stop()
        }
    }

    // MARK: - URL Bubble

    private func urlBubble(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(previewState.metadata?.finalURL.host ?? url.host ?? url.absoluteString)
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

                if !PhoneLinkTransferManager.shared.availableActions(for: url).isEmpty {
                    Button(action: { openPhoneActionMenu(url: url) }) {
                        Image(systemName: "iphone")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(effectivePrivateMode ? Color.purple.opacity(0.8) : Color.secondary)
                            .padding(6)
                            .pickerInteractiveMiniButton()
                    }
                    .buttonStyle(.plain)
                    .help("\(PhoneLinkTransferManager.Strings.buttonLabel) (I)")
                    .accessibilityIdentifier("picker.sendToIPhoneButton")
                    .accessibilityLabel(PhoneLinkTransferManager.Strings.buttonLabel)
                    .popover(isPresented: $showingPhoneActionMenu, arrowEdge: .top) {
                        phoneActionMenu(url: url)
                            .presentationBackground(.ultraThinMaterial)
                    }
                    .popover(isPresented: $showingPhoneQRSheet, arrowEdge: .top) {
                        PhoneQRPanelView(
                            url: url,
                            faviconURL: previewState.metadata?.faviconURL,
                            onClose: { showingPhoneQRSheet = false }
                        )
                        .presentationBackground(.ultraThinMaterial)
                    }
                }
            }
        }

            if browserManager.showLinkPreview {
                previewRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityIdentifier("picker.urlDisplay")
    }

    // MARK: - Send to Phone

    private struct PhoneMenuAction {
        let title: String
        let systemImage: String
        let identifier: String
        let perform: () -> Void
    }

    private func phoneMenuActions(url: URL) -> [PhoneMenuAction] {
        [
            PhoneMenuAction(title: "AirDrop…", systemImage: "square.and.arrow.up", identifier: "iphoneAction.airDropButton") {
                if PhoneLinkAirDropAdapter().share(url) == .unavailable {
                    NSSound.beep()
                }
            },
            PhoneMenuAction(title: "Show QR Code", systemImage: "qrcode", identifier: "iphoneAction.showQRCodeButton") {
                showingPhoneQRSheet = true
            },
            PhoneMenuAction(title: "Copy URL", systemImage: "doc.on.clipboard", identifier: "iphoneAction.copyURLButton") {
                PhoneLinkPasteboardAdapter().copy(url)
            },
        ]
    }

    /// Opens the Send to Phone menu. Also briefly activates the app: macOS only
    /// advertises Handoff (NSUserActivity) for the frontmost app, and Chowser's
    /// non-activating panel never makes us frontmost on its own — without this,
    /// the Handoff advertisement silently never appears on nearby devices. Scoped
    /// to this explicit user action so the URL-open flow stays non-activating.
    private func openPhoneActionMenu(url: URL) {
        phoneMenuSelectedIndex = 0
        showingPhoneActionMenu = true
        guard !isPreview, !AppEnvironment.isUITesting else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !browserManager.currentURLPrivateModeRequested && !effectivePrivateMode {
            phoneHandoffAdapter.startOrUpdate(url)
        }
    }

    private func activatePhoneMenuSelection(url: URL) {
        let actions = phoneMenuActions(url: url)
        guard actions.indices.contains(phoneMenuSelectedIndex) else { return }
        showingPhoneActionMenu = false
        actions[phoneMenuSelectedIndex].perform()
    }

    @ViewBuilder
    private func phoneActionMenu(url: URL) -> some View {
        let actions = phoneMenuActions(url: url)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, item in
                phoneMenuButton(
                    title: item.title,
                    systemImage: item.systemImage,
                    identifier: item.identifier,
                    isSelected: phoneMenuSelectedIndex == index
                ) {
                    phoneMenuSelectedIndex = index
                    showingPhoneActionMenu = false
                    item.perform()
                }
                .onHover { hovering in
                    if hovering { phoneMenuSelectedIndex = index }
                }
            }

            Divider().padding(.vertical, 4)

            Text(PhoneLinkTransferManager.Strings.handoffExplanation)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.bottom, 2)
                .accessibilityIdentifier("iphoneAction.handoffStatusText")
        }
        .padding(10)
        .frame(width: 240)
    }

    private func phoneMenuButton(title: String, systemImage: String, identifier: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
    }

    /// Self-contained QR popover content. Generates the QR code in its own init — at
    /// the moment the popover presents — so it never depends on `@State` written from
    /// the action-menu popover's separate hosting view. That cross-window state handoff
    /// was the "fails the first time, works the second" bug: the QR popover could
    /// present before it observed the menu popover's state write.
    private struct PhoneQRPanelView: View {
        let url: URL
        let faviconURL: URL?
        let onClose: () -> Void

        private let qrResult: Result<PhoneLinkQRCode, Swift.Error>
        @State private var faviconImage: NSImage?
        @State private var faviconAccent: Color?

        init(url: URL, faviconURL: URL?, onClose: @escaping () -> Void) {
            self.url = url
            self.faviconURL = faviconURL
            self.onClose = onClose
            self.qrResult = Result { try PhoneLinkQRGenerator().makeQRCode(for: url) }
        }

        var body: some View {
            VStack(spacing: 16) {
                HStack {
                    Text(PhoneLinkTransferManager.Strings.buttonLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("iphoneQR.closeButton")
                    .accessibilityLabel("Close")
                }

                switch qrResult {
                case .success(let qrCode):
                    VStack(spacing: 10) {
                        ZStack {
                            effectiveAccent
                                .mask(
                                    Image(nsImage: qrCode.maskImage)
                                        .interpolation(.none)
                                        .resizable()
                                )
                                .frame(width: 200, height: 200)

                            if let faviconImage {
                                Image(nsImage: faviconImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 26, height: 26)
                                    .padding(7)
                                    .background(Circle().fill(Color.white))
                                    .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
                            }
                        }
                        .frame(width: 220, height: 220)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                        .accessibilityIdentifier("iphoneQR.image")

                        Text("Scan with your phone camera")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(url.host ?? url.absoluteString)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .pickerBadgeChip()
                            .accessibilityIdentifier("iphoneQR.urlText")
                    }
                case .failure(let error):
                    VStack(spacing: 8) {
                        Text("Couldn't generate a QR code for this link.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("\(error) — \(url.absoluteString.prefix(120))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 220, height: 220)
                }
            }
            .padding(24)
            .frame(width: 280)
            .accessibilityIdentifier("iphoneQR.sheet")
            .task(id: url) {
                // Favicon is a pure overlay inside the fixed-size QR square — fetching
                // it asynchronously can't change this panel's layout/size.
                guard let faviconURL,
                      let (data, _) = try? await URLSession.shared.data(from: faviconURL),
                      let image = NSImage(data: data) else { return }
                faviconImage = image
                if let dominant = Self.averageColor(of: image) {
                    faviconAccent = Self.vividAccent(from: dominant)
                }
            }
        }

        /// Explicit user override wins; otherwise prefer the loaded site's own color so
        /// the QR feels branded to the link, falling back to the picker accent / default.
        private var effectiveAccent: Color {
            if !BrowserManager.shared.qrCodeAccentHex.isEmpty { return Color.qrCodeAccent }
            if let faviconAccent { return faviconAccent }
            return Color.qrCodeAccent
        }

        /// Fast dominant-color extraction via Core Image's built-in area-average filter —
        /// no third-party image-processing dependency needed for a single average pixel.
        private static func averageColor(of image: NSImage) -> Color? {
            guard let tiffData = image.tiffRepresentation, let ciImage = CIImage(data: tiffData) else { return nil }
            let extent = CIVector(cgRect: ciImage.extent)
            guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extent]),
                  let outputImage = filter.outputImage else { return nil }

            var pixel = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.workingColorSpace: NSNull()])
            context.render(outputImage, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
            guard pixel[3] > 0 else { return nil }
            return Color(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255)
        }

        /// Boosts a raw sampled color into something legible/punchy as QR modules — a pale
        /// or washed-out favicon average would otherwise render as a near-invisible QR.
        private static func vividAccent(from color: Color) -> Color {
            let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            ns.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            let boostedSaturation = max(saturation, 0.5)
            let clampedBrightness = min(max(brightness, 0.35), 0.65)
            return Color(nsColor: NSColor(hue: hue, saturation: boostedSaturation, brightness: clampedBrightness, alpha: 1))
        }
    }

    @ViewBuilder
    private var previewRow: some View {
        switch previewState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Loading preview…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 60, alignment: .leading)
            .transition(.opacity)
        case .skippedSingleUse:
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
                Text("Preview skipped — looks like a one-time link. Loading it here could use it up before your browser opens.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 60, alignment: .leading)
            .transition(.opacity)
        case let .unavailable(code):
            HStack(spacing: 8) {
                Image(systemName: unavailableIcon(code))
                    .foregroundStyle(.secondary)
                Text(unavailableMessage(code))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 60, alignment: .leading)
            .transition(.opacity)
        case .noPreview:
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("No preview available for this link.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 60, alignment: .leading)
            .transition(.opacity)
        case let .loaded(meta):  // assignment only stores meaningful metadata here
            HStack(alignment: .top, spacing: 10) {
                previewThumbnail(meta)
                VStack(alignment: .leading, spacing: 2) {
                    if let title = meta.title {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    if let description = meta.description {
                        Text(description)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .pickerInlineCard()
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func previewThumbnail(_ meta: LinkMetadata) -> some View {
        if let image = meta.imageURL {
            AsyncImage(url: image) { phase in
                if let img = phase.image {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else if let favicon = meta.faviconURL {
                    faviconImage(favicon)
                } else {
                    faviconFallback
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            faviconImage(meta.faviconURL)
                .frame(width: 22, height: 22)
        }
    }

    @ViewBuilder
    private func faviconImage(_ url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().aspectRatio(contentMode: .fit)
                } else {
                    faviconFallback
                }
            }
        } else {
            faviconFallback
        }
    }

    private var faviconFallback: some View {
        Image(systemName: "globe")
            .foregroundStyle(.secondary)
    }

    /// 401/403 mean "sign-in required", not broken — the link opens fine in the user's
    /// signed-in browser; only our cookie-less preview fetch is refused.
    private func unavailableMessage(_ code: Int) -> String {
        switch code {
        case 401, 403: return "No preview — this link needs you to be signed in. It’ll open normally in your browser."
        case 404, 410: return "Page not found (\(code)) — this link may no longer be available."
        default: return "This page may not be available (HTTP \(code))."
        }
    }

    private func unavailableIcon(_ code: Int) -> String {
        switch code {
        case 401, 403: return "lock"
        default: return "exclamationmark.triangle"
        }
    }

    private func loadLinkPreview(for url: URL?) {
        previewTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { previewState = .idle }
        guard browserManager.showLinkPreview, let url else { return }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        // Single-use links: don't fetch (would burn the token) and tell the user why.
        if LinkMetadataFetcher.isLikelySingleUse(url) {
            withAnimation(.easeOut(duration: 0.2)) { previewState = .skippedSingleUse }
            return
        }
        previewState = .loading
        previewTask = Task {
            let result = await LinkMetadataFetcher.fetch(url)
            if Task.isCancelled { return }
            await MainActor.run {
                guard browserManager.currentURL == url else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    switch result {
                    case let .metadata(meta) where meta.isMeaningful: previewState = .loaded(meta)
                    case .metadata: previewState = .noPreview  // reached, but nothing worth showing
                    case let .unavailable(code): previewState = .unavailable(code)
                    case .failed: previewState = .noPreview    // couldn't reach / not a web page
                    }
                }
            }
        }
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
                            .foregroundStyle(Color.pickerAccentText)
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
                Group {
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
                }
                .opacity(browserDimOpacity(browser))
                .help(isBrowserRunning(browser) ? "" : "\(browser.name) is not running")

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
                        .foregroundStyle(Color.pickerAccentText)
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

                    Group {
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
                    .opacity(browserDimOpacity(browser))
                    .help(isBrowserRunning(browser) ? "" : "\(browser.name) is not running")
                }
                .overlay(alignment: .topLeading) {
                    // Small suggested star badge
                    if isSuggested {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.pickerAccent)
                            .padding(3)
                            .background(Circle().fill(Color(NSColor.windowBackgroundColor).opacity(0.95)))
                            .shadow(color: Color.pickerAccent.opacity(0.3), radius: 2)
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
                .strokeBorder(Color.pickerAccent.opacity(isSuggested ? 0.5 : 0), lineWidth: 1.5)
                .shadow(color: Color.pickerAccent.opacity(isSuggested ? 0.3 : 0), radius: 4)
                .frame(width: iconDimensions.hitArea, height: iconDimensions.hitArea)
        }
    }

    // MARK: - Keyboard Hints Row

    /// Decluttered footer: a single tiny info affordance instead of a permanently-visible
    /// row of shortcut chips with its own divider/section. The chips (and their click
    /// actions) still exist — they're just tucked behind the info popover now, on demand.
    private var shortcutsInfoRow: some View {
        HStack {
            Spacer()
            Button(action: { showingShortcutsInfo.toggle() }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Keyboard shortcuts")
            .accessibilityIdentifier("picker.shortcutsInfoButton")
            .popover(isPresented: $showingShortcutsInfo, arrowEdge: .bottom) {
                shortcutsInfoPopover
                    .presentationBackground(.ultraThinMaterial)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .opacity(appeared ? 1 : 0)
        .animation(.easeIn(duration: 0.2).delay(0.3), value: appeared)
    }

    private var shortcutsInfoPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            keyHintChip(
                keys: ["P"],
                label: "Private",
                isActive: effectivePrivateMode,
                isDisabled: !supportsPrivateLaunchMode,
                action: { togglePrivateMode() }
            )
            .help(privateModeHelpText)
            .accessibilityIdentifier("picker.privateModeHint")
            keyHintChip(keys: ["H"], label: "Resolve", isDisabled: browserManager.currentURL == nil || isUnshortening) {
                if !isUnshortening, browserManager.currentURL != nil { performManualUnshorten() }
            }
            keyHintChip(keys: ["R"], label: "Rules", isDisabled: browserManager.currentURL == nil) {
                if browserManager.currentURL != nil { showingConfigureRule = true }
            }
            keyHintChip(
                keys: ["I"],
                label: "Send to Phone",
                isDisabled: browserManager.currentURL.map { PhoneLinkTransferManager.shared.availableActions(for: $0).isEmpty } ?? true
            ) {
                guard let url = browserManager.currentURL,
                      !PhoneLinkTransferManager.shared.availableActions(for: url).isEmpty else { return }
                showingShortcutsInfo = false
                openPhoneActionMenu(url: url)
            }
            keyHintChip(keys: ["1-9"], label: "Open browser")
            keyHintChip(keys: ["Esc"], label: "Close") {
                showingShortcutsInfo = false
                if showingConfigureRule { showingConfigureRule = false } else { dismissPicker() }
            }
            keyHintChip(keys: ["↵"], label: "Launch", isAccent: true) {
                showingShortcutsInfo = false
                _ = openSelectedBrowser(usePrivateMode: effectivePrivateMode)
            }
        }
        .padding(10)
        .frame(width: 210)
    }

    @ViewBuilder
    private func keyHintChip(keys: [String], label: String, isActive: Bool = false, isAccent: Bool = false, isDisabled: Bool = false, action: (() -> Void)? = nil) -> some View {
        let chip = HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    // Key glyph = the "shortcut badge"; all of them honor the accent
                    // (purple only while a toggle like Private is active).
                    .foregroundStyle(isActive ? Color.purple : Color.pickerAccentText)
                    .fixedSize()
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .pickerBadgeChip()
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .fixedSize()
                .foregroundStyle(
                    isAccent ? Color.pickerAccentText :
                        (isActive ? Color.purple : Color.secondary)
                )
            Spacer(minLength: 0)
        }
        .opacity(isDisabled ? 0.3 : 1.0)

        if let action {
            Button(action: action) { chip }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .help("\(label) (\(keys.joined()))")
        } else {
            chip
        }
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
        showingPhoneActionMenu = false
        showingPhoneQRSheet = false
        showingShortcutsInfo = false
        phoneHandoffAdapter.stop()
        browserManager.currentURL = nil
        for window in NSApp.windows where window.isVisible && window.identifier?.rawValue == "picker" {
            window.orderOut(nil)
        }
    }

    // MARK: - Browser Action

    private func openUrl(with browser: BrowserConfig, usePrivateMode: Bool = false) {
        guard let url = browserManager.currentURL else { return }
        let effectiveUsePrivateMode = supportsPrivateLaunchMode && usePrivateMode
        if !isPreview { dismissPicker() }
        browserManager.open(url: url, withBrowserBundleID: browser.bundleId, profile: browser.profile, usePrivateMode: effectiveUsePrivateMode)
    }

    private func requestedPrivateMode(modifierFlags: NSEvent.ModifierFlags) -> Bool {
        supportsPrivateLaunchMode && (privateMode || modifierFlags.contains(.option))
    }

    private func togglePrivateMode() {
        guard supportsPrivateLaunchMode else { return }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) { privateMode.toggle() }
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

        // Send to Phone menu — while open, arrow keys move selection, Return/digits
        // activate it, Escape closes it. Swallows everything else so the browser list
        // underneath can't be triggered by accident.
        if showingPhoneActionMenu, let url = browserManager.currentURL {
            // Command shortcuts (Cmd+Q/W/C…) must keep working — only swallow plain keys.
            if event.modifierFlags.contains(.command) { return false }
            let actionCount = phoneMenuActions(url: url).count
            switch event.keyCode {
            case 53: // escape
                showingPhoneActionMenu = false
            case 36, 76: // return / enter
                activatePhoneMenuSelection(url: url)
            case 125: // down arrow
                phoneMenuSelectedIndex = (phoneMenuSelectedIndex + 1) % max(actionCount, 1)
            case 126: // up arrow
                phoneMenuSelectedIndex = (phoneMenuSelectedIndex - 1 + actionCount) % max(actionCount, 1)
            default:
                if let chars = event.charactersIgnoringModifiers, let number = Int(chars), (1...actionCount).contains(number) {
                    phoneMenuSelectedIndex = number - 1
                    activatePhoneMenuSelection(url: url)
                }
            }
            return true
        }

        // Send to Phone QR sheet — Escape closes it
        if showingPhoneQRSheet, event.keyCode == 53 {
            showingPhoneQRSheet = false
            return true
        }

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
            case "i":
                guard let url = browserManager.currentURL,
                      !PhoneLinkTransferManager.shared.availableActions(for: url).isEmpty else { return false }
                openPhoneActionMenu(url: url)
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
