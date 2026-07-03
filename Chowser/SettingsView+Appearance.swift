import SwiftUI
import AppKit

extension SettingsView {
    var appearanceSection: some View {
        @Bindable var manager = browserManager

        return SettingsDetailScaffold(
            title: "Appearance",
            subtitle: "Customize how the link picker looks. Changes apply live to the preview below.",
            systemImage: "paintpalette",
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    AppearancePreview()

                    SettingsGroup("Layout", subtitle: "Controls the link picker shown when no rule matches.") {
                        SettingsRow(title: "Layout", subtitle: "Use an icon strip or a denser list.") {
                            Picker("Layout", selection: $manager.pickerLayoutMode) {
                                Text("Icons").tag("icons")
                                Text("List").tag("list")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .labelsHidden()
                        }

                        SettingsDivider()

                        SettingsRow(title: "Icon Size", subtitle: "Applies when the picker is using icon layout.") {
                            Picker("Icon Size", selection: $manager.pickerIconSize) {
                                Text("Small").tag("small")
                                Text("Medium").tag("medium")
                                Text("Large").tag("large")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                            .labelsHidden()
                            .disabled(manager.pickerLayoutMode != "icons")
                        }

                        SettingsDivider()

                        SettingsRow(title: "Show Labels", subtitle: "Display browser names under picker icons.") {
                            Toggle("", isOn: $manager.pickerShowLabels)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .disabled(manager.pickerLayoutMode != "icons")
                        }

                        SettingsDivider()

                        SettingsRow(title: "Dim Inactive Browsers", subtitle: "Fade browsers that aren't currently running.") {
                            Toggle("", isOn: $manager.pickerDimInactiveBrowsers)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }

                        SettingsDivider()

                        SettingsRow(title: "Link Preview", subtitle: "Fetch the link's title, description, and image in the picker. Also resolves shortlinks.") {
                            Toggle("", isOn: $manager.showLinkPreview)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }

                    SettingsGroup("Surface", subtitle: "Auto uses the native macOS material. Custom unlocks tint and opacity.") {
                        SettingsRow(title: "Color Scheme", subtitle: "Force the picker to light or dark, or follow the system.") {
                            Picker("Color Scheme", selection: $manager.pickerColorScheme) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                            .labelsHidden()
                        }

                        SettingsDivider()

                        SettingsRow(title: "Style", subtitle: "Auto follows the system glass effect.") {
                            Picker("Style", selection: $manager.pickerAppearanceMode) {
                                Text("Auto").tag("auto")
                                Text("Custom").tag("custom")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
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

                        SettingsRow(title: "Transparency", subtitle: "Higher lets more of the desktop show through.") {
                            let transparency = Binding(
                                get: { 1 - manager.pickerBackgroundOpacity },
                                set: { manager.pickerBackgroundOpacity = 1 - $0 }
                            )
                            HStack(spacing: 10) {
                                Slider(value: transparency, in: 0...0.8)
                                    .frame(width: 180)
                                Text("\(Int(transparency.wrappedValue * 100))%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            .disabled(manager.pickerAppearanceMode != "custom")
                        }

                        SettingsDivider()

                        SettingsRow(title: "Corner Radius", subtitle: "Roundness of the panel. Applies in both styles.") {
                            HStack(spacing: 10) {
                                Slider(value: $manager.pickerCornerRadius, in: 8...28)
                                    .frame(width: 180)
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
        )
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

/// Live preview that embeds the real picker (`ContentView`) so it looks exactly like
/// the picker — no separate mock. `currentURL` points at a sample link, so clicking a
/// browser actually opens it.
private struct AppearancePreview: View {
    @State private var manager = BrowserManager.shared
    @State private var backdrop: PreviewBackdrop = .color
    private static let sampleURL = URL(string: "https://sreerams.in")!

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
                .frame(maxWidth: 280)
            }
            Text("This is the real picker. Clicking a browser opens \(Self.sampleURL.absoluteString).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // Real picker sizes itself; backdrop sits behind (not a sizing sibling) so
            // nothing — including the footer hints row — is clipped.
            ContentView(isPreview: true)
                .frame(maxWidth: .infinity)
                .background(backdropView)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.separator.opacity(0.35), lineWidth: 1)
                )
        }
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
