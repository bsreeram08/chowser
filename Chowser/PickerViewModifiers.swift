import SwiftUI
import AppKit

private enum PickerGlassStyle {
    static let miniButtonCornerRadius: CGFloat = 6
    static let badgeCornerRadius: CGFloat = 5
    static let inlineCardCornerRadius: CGFloat = 12

    /// User-tunable panel corner radius (falls back to 16 if unset/invalid).
    static var panelCornerRadius: CGFloat {
        CGFloat(BrowserManager.shared.pickerCornerRadius)
    }
}

extension Color {
    /// "#RRGGBB" / "RRGGBB" → Color. Returns nil on malformed input.
    init?(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).trimmingCharacters(in: .whitespaces)
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }

    var toHex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X",
                      Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)),
                      Int(round(c.blueComponent * 255)))
    }

    /// Accent used for picker highlights — user override or system accent.
    static var pickerAccent: Color {
        let hex = BrowserManager.shared.pickerAccentHex
        return hex.isEmpty ? .accentColor : (Color(hex: hex) ?? .accentColor)
    }

    /// Accent adjusted to stay legible as TEXT/icons on the dark picker panel: if the
    /// chosen accent is too dark, raise its lightness (HSB) keeping hue/saturation.
    static var pickerAccentText: Color {
        let ns = NSColor(pickerAccent).usingColorSpace(.sRGB) ?? .white
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        guard b < 0.6 else { return pickerAccent }
        return Color(nsColor: NSColor(hue: h, saturation: s, brightness: 0.85, alpha: a))
    }
}

struct PickerPanelSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var manager: BrowserManager { .shared }

    @ViewBuilder
    func body(content: Content) -> some View {
        let radius = PickerGlassStyle.panelCornerRadius
        if manager.pickerAppearanceMode == "custom" && !reduceTransparency {
            // User-tuned surface: solid tint/window color whose alpha IS the opacity slider,
            // so 100% = solid panel and low values let the desktop show through.
            let tint = Color(hex: manager.pickerTintHex)
            let fill = (tint ?? Color(nsColor: .windowBackgroundColor)).opacity(manager.pickerBackgroundOpacity)
            content
                .background(fill)
                .clipShape(.rect(cornerRadius: radius))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(1)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke((tint ?? .white).opacity(0.15), lineWidth: 1)
                )
        } else if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(.rect(cornerRadius: PickerGlassStyle.panelCornerRadius))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(1)
                .overlay(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.panelCornerRadius, style: .continuous)
                        .stroke(.separator.opacity(0.5), lineWidth: 1)
                )
        } else
        if #available(macOS 26.0, *) {
            content
                .padding(1)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PickerGlassStyle.panelCornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.panelCornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 0.8)
                )
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: PickerGlassStyle.panelCornerRadius))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(1)
                .overlay(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.panelCornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

struct PickerInteractiveMiniButtonModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(.rect(cornerRadius: PickerGlassStyle.miniButtonCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.miniButtonCornerRadius, style: .continuous)
                        .stroke(.separator.opacity(0.45), lineWidth: 1)
                )
        } else
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: PickerGlassStyle.miniButtonCornerRadius, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.miniButtonCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
        }
    }
}

struct PickerBadgeChipModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.badgeCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .stroke(.separator.opacity(0.5), lineWidth: 1)
                )
        } else
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PickerGlassStyle.badgeCornerRadius, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.badgeCornerRadius, style: .continuous)
                        .fill(.white.opacity(0.06))
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
        }
    }
}

struct PickerInlineCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.inlineCardCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .stroke(.separator.opacity(0.45), lineWidth: 1)
                )
        } else
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PickerGlassStyle.inlineCardCornerRadius, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.inlineCardCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
    }
}

struct CustomCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .stroke(.separator.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)
        } else
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)
        }
    }
}

struct CustomChipSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isSelected: Bool
    let selectedColor: Color
    let hoverOpacity: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSelected {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(selectedColor)
                )
        } else if reduceTransparency {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .stroke(.separator.opacity(0.45), lineWidth: 1)
                )
        } else
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(hoverOpacity))
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

typealias PickerSurfaceModifier = PickerPanelSurfaceModifier
typealias PickerCircleButtonBackgroundModifier = PickerInteractiveMiniButtonModifier
typealias PickerShortcutBadgeBackgroundModifier = PickerBadgeChipModifier

extension View {
    func pickerPanelSurface() -> some View {
        modifier(PickerPanelSurfaceModifier())
    }

    func pickerInteractiveMiniButton() -> some View {
        modifier(PickerInteractiveMiniButtonModifier())
    }

    func pickerBadgeChip() -> some View {
        modifier(PickerBadgeChipModifier())
    }

    func pickerInlineCard() -> some View {
        modifier(PickerInlineCardModifier())
    }

    func customCardSurface(
        cornerRadius: CGFloat = 12,
        shadowOpacity: Double = 0,
        shadowRadius: CGFloat = 0,
        shadowYOffset: CGFloat = 0
    ) -> some View {
        modifier(CustomCardSurfaceModifier(
            cornerRadius: cornerRadius,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowYOffset: shadowYOffset
        ))
    }

    func customChipSurface(
        cornerRadius: CGFloat = 6,
        isSelected: Bool = false,
        selectedColor: Color = .accentColor,
        hoverOpacity: Double = 0.03
    ) -> some View {
        modifier(CustomChipSurfaceModifier(
            cornerRadius: cornerRadius,
            isSelected: isSelected,
            selectedColor: selectedColor,
            hoverOpacity: hoverOpacity
        ))
    }
}
