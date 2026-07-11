import SwiftUI
import AppKit

enum AppearancePreviewLayout {
    enum Presentation: Equatable {
        case sideBySide
        case stacked
    }

    static let sideBySideBreakpoint: CGFloat = 740

    static func presentation(for width: CGFloat) -> Presentation {
        width >= sideBySideBreakpoint ? .sideBySide : .stacked
    }

    static func scale(contentSize: CGSize, availableSize: CGSize) -> CGFloat {
        guard contentSize.width > 0,
              contentSize.height > 0,
              availableSize.width > 0,
              availableSize.height > 0 else { return 1 }
        return min(1, availableSize.width / contentSize.width, availableSize.height / contentSize.height)
    }
}

extension SettingsView {
    var appearanceSection: some View {
        SettingsDetailScaffold(
            title: "Appearance",
            subtitle: "Customize how the link picker looks. Changes update the pinned preview immediately.",
            systemImage: "paintpalette",
            scrollsContent: false,
            content: {
                GeometryReader { geometry in
                    if AppearancePreviewLayout.presentation(for: geometry.size.width) == .sideBySide {
                        sideBySideAppearance
                    } else {
                        stackedAppearance
                    }
                }
            }
        )
    }

    private var sideBySideAppearance: some View {
        HStack(alignment: .top, spacing: 0) {
            appearanceControlsScroll
                .frame(minWidth: 360, maxWidth: .infinity)

            Divider()

            AppearancePreview(compact: false)
                .frame(width: 320)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(20)
        }
    }

    private var stackedAppearance: some View {
        VStack(spacing: 0) {
            AppearancePreview(compact: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            appearanceControlsScroll
        }
    }

    private var appearanceControlsScroll: some View {
        ScrollView {
            appearanceControls
                .padding(20)
        }
        .accessibilityIdentifier("settings.appearance.controls")
    }

    private var appearanceControls: some View {
        @Bindable var manager = browserManager

        return VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Layout", subtitle: "Controls the link picker shown when no rule matches.") {
                AppearanceStackedRow(title: "Layout", subtitle: "Choose a classic picker or a cursor-first quick picker.") {
                    Picker("Layout", selection: $manager.pickerLayoutMode) {
                        Text("Icons").tag(PickerLayoutMode.icons)
                        Text("List").tag(PickerLayoutMode.list)
                        Text("Radial").tag(PickerLayoutMode.radial)
                        Text("Minimal").tag(PickerLayoutMode.minimal)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("settings.appearance.layoutPicker")
                }

                SettingsDivider()

                AppearanceStackedRow(title: "Icon Size", subtitle: "Applies when the picker is using icon layout.") {
                    Picker("Icon Size", selection: $manager.pickerIconSize) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                        Text("Large").tag("large")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(manager.pickerLayoutMode != .icons)
                }

                SettingsDivider()

                SettingsRow(title: "Show Labels", subtitle: "Display browser names under picker icons.") {
                    Toggle("", isOn: $manager.pickerShowLabels)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(manager.pickerLayoutMode != .icons)
                }

                SettingsDivider()

                SettingsRow(title: "Dim Inactive Browsers", subtitle: "Fade browsers that aren't currently running.") {
                    Toggle("", isOn: $manager.pickerDimInactiveBrowsers)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingsDivider()

                SettingsRow(title: "Link Preview", subtitle: "Fetch title, description, and image in Icons and List modes. Also resolves shortlinks.") {
                    Toggle("", isOn: $manager.showLinkPreview)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            SettingsGroup("Surface", subtitle: "Auto uses the native macOS material. Custom unlocks tint and opacity.") {
                AppearanceStackedRow(title: "Color Scheme", subtitle: "Force the picker to light or dark, or follow the system.") {
                    Picker("Color Scheme", selection: $manager.pickerColorScheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                SettingsDivider()

                AppearanceStackedRow(title: "Style", subtitle: "Auto follows the system glass effect.") {
                    Picker("Style", selection: $manager.pickerAppearanceMode) {
                        Text("Auto").tag("auto")
                        Text("Custom").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                SettingsDivider()

                SettingsRow(title: "Tint", subtitle: "Color washed over the picker panel.") {
                    HStack(spacing: 8) {
                        ColorPicker("", selection: hexBinding(\.pickerTintHex), supportsOpacity: false)
                            .labelsHidden()
                        if !manager.pickerTintHex.isEmpty {
                            Button("Clear") { manager.pickerTintHex = "" }
                                .controlSize(.small)
                        }
                    }
                    .disabled(manager.pickerAppearanceMode != "custom")
                }

                SettingsDivider()

                AppearanceStackedRow(title: "Transparency", subtitle: "Higher lets more of the desktop show through.") {
                    let transparency = Binding(
                        get: { 1 - manager.pickerBackgroundOpacity },
                        set: { manager.pickerBackgroundOpacity = 1 - $0 }
                    )
                    HStack(spacing: 10) {
                        Slider(value: transparency, in: 0...0.8)
                        Text("\(Int(transparency.wrappedValue * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .disabled(manager.pickerAppearanceMode != "custom")
                }

                SettingsDivider()

                AppearanceStackedRow(title: "Corner Radius", subtitle: "Roundness of the panel. Applies in both styles.") {
                    HStack(spacing: 10) {
                        Slider(value: $manager.pickerCornerRadius, in: 8...28)
                        Text("\(Int(manager.pickerCornerRadius))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            SettingsGroup("Accent", subtitle: "Highlight color for selection rings and shortcut badges.") {
                SettingsRow(title: "Accent Color", subtitle: "Overrides the system accent in the picker.") {
                    HStack(spacing: 8) {
                        ColorPicker("", selection: hexBinding(\.pickerAccentHex), supportsOpacity: false)
                            .labelsHidden()
                        if !manager.pickerAccentHex.isEmpty {
                            Button("Use System") { manager.pickerAccentHex = "" }
                                .controlSize(.small)
                        }
                    }
                }

                SettingsDivider()

                SettingsRow(title: "QR Code Color", subtitle: "Color of the \"Send to Phone\" QR code. Defaults to the accent color.") {
                    HStack(spacing: 8) {
                        ColorPicker("", selection: qrCodeColorBinding, supportsOpacity: false)
                            .labelsHidden()
                        if !manager.qrCodeAccentHex.isEmpty {
                            Button("Use Accent") { manager.qrCodeAccentHex = "" }
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    /// QR color falls back to the effective picker accent (not raw system accent), so the
    /// swatch matches what actually renders when no override is set.
    private var qrCodeColorBinding: Binding<Color> {
        Binding(
            get: {
                let hex = browserManager.qrCodeAccentHex
                return hex.isEmpty ? Color.qrCodeAccent : (Color(hex: hex) ?? Color.qrCodeAccent)
            },
            set: { browserManager.qrCodeAccentHex = $0.toHex }
        )
    }

    /// Bridges a stored hex-string keypath to a `Color` binding for ColorPicker.
    private func hexBinding(_ keyPath: ReferenceWritableKeyPath<BrowserManager, String>) -> Binding<Color> {
        Binding(
            get: {
                let hex = browserManager[keyPath: keyPath]
                return hex.isEmpty ? .accentColor : (Color(hex: hex) ?? .accentColor)
            },
            set: { browserManager[keyPath: keyPath] = $0.toHex }
        )
    }
}

private struct AppearanceStackedRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Live preview that embeds the real picker (`ContentView`) so it looks exactly like
/// the picker. `currentURL` points at a sample link, so clicking a browser actually
/// opens it; metadata is deterministic so Settings never performs an unsolicited GET.
private struct AppearancePreview: View {
    @State private var manager = BrowserManager.shared
    @State private var backdrop: PreviewBackdrop = .color
    let compact: Bool
    private static let sampleURL = URL(string: "https://sreerams.in")!
    private static let sampleMetadata = LinkMetadata(
        finalURL: sampleURL,
        title: "sreerams.in",
        description: "Page titles and descriptions appear here before you choose a browser.",
        imageURL: nil,
        faviconURL: nil
    )

    private enum PreviewBackdrop: String, CaseIterable, Identifiable {
        case light = "Light", dark = "Dark", color = "Color", checker = "Checker"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Picker("Backdrop", selection: $backdrop) {
                    ForEach(PreviewBackdrop.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 210)
            }
            Text("Live picker sample. Clicking a browser opens \(Self.sampleURL.absoluteString).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            ZStack {
                backdropView
                FittedPickerPreview(metadata: Self.sampleMetadata)
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 190 : 320)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.separator.opacity(0.35), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("settings.appearance.preview")
        .onAppear { manager.currentURL = Self.sampleURL }
        .onDisappear {
            if manager.currentURL == Self.sampleURL { manager.currentURL = nil }
        }
    }

    @ViewBuilder
    private var backdropView: some View {
        switch backdrop {
        case .light:
            Color(white: 0.92)
        case .dark:
            Color(white: 0.08)
        case .color:
            LinearGradient(
                colors: [.blue.opacity(0.45), .purple.opacity(0.45), .pink.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .checker:
            Checkerboard()
        }
    }
}

private struct PickerPreviewContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}

private struct FittedPickerPreview: View {
    let metadata: LinkMetadata
    @State private var contentSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let scale = AppearancePreviewLayout.scale(
                contentSize: contentSize,
                availableSize: geometry.size
            )

            ContentView(isPreview: true, previewMetadata: metadata)
                .fixedSize()
                .background {
                    GeometryReader { contentGeometry in
                        Color.clear.preference(
                            key: PickerPreviewContentSizeKey.self,
                            value: contentGeometry.size
                        )
                    }
                }
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onPreferenceChange(PickerPreviewContentSizeKey.self) { contentSize = $0 }
        .clipped()
    }
}

/// Simple checkerboard so panel transparency is obvious against it.
private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 16
            let cols = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.55)))
            for r in 0..<rows {
                for c in 0..<cols where (r + c) % 2 == 0 {
                    let rect = CGRect(x: CGFloat(c) * tile, y: CGFloat(r) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(Color(white: 0.78)))
                }
            }
        }
    }
}
