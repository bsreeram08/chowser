import SwiftUI
import AppKit

private enum PickerGlassStyle {
    static let miniButtonCornerRadius: CGFloat = 6
    static let badgeCornerRadius: CGFloat = 5
    static let inlineCardCornerRadius: CGFloat = 12

    /// User-tunable panel corner radius (falls back to 16 if unset/invalid).
    @MainActor static var panelCornerRadius: CGFloat {
        CGFloat(BrowserManager.shared.pickerCornerRadius)
    }
}

enum PickerMotion {
    static let press = Animation.easeOut(duration: 0.1)

    static func occasional(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.2, dampingFraction: 1.0)
    }

    static func transition(
        reduceMotion: Bool,
        scale: CGFloat = 0.98,
        anchor: UnitPoint = .center
    ) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: scale, anchor: anchor))
    }
}

struct PickerPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .opacity(reduceMotion && configuration.isPressed ? 0.72 : 1)
            .animation(PickerMotion.press, value: configuration.isPressed)
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
    @MainActor static var pickerAccent: Color {
        let hex = BrowserManager.shared.pickerAccentHex
        return hex.isEmpty ? .accentColor : (Color(hex: hex) ?? .accentColor)
    }

    /// Pleasant fallback so the QR looks good out of the box — deliberately NOT the raw
    /// system accent, which can be Graphite/gray and looks dull against a white card.
    private static let defaultQRAccent = Color(red: 0.33, green: 0.24, blue: 0.94)

    /// Color used for "Send to Phone" QR code modules — user override, else a
    /// user-customized picker accent (if set), else a fixed pleasant default.
    @MainActor static var qrCodeAccent: Color {
        let hex = BrowserManager.shared.qrCodeAccentHex
        if !hex.isEmpty, let custom = Color(hex: hex) { return custom }
        let pickerHex = BrowserManager.shared.pickerAccentHex
        if !pickerHex.isEmpty, let custom = Color(hex: pickerHex) { return custom }
        return defaultQRAccent
    }

}

struct PickerPanelSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var manager: BrowserManager { .shared }

    @ViewBuilder
    func body(content: Content) -> some View {
        let radius = PickerGlassStyle.panelCornerRadius
        if manager.pickerAppearanceMode == "custom" && !reduceTransparency && contrast != .increased {
            // Glassy translucent surface: ultraThinMaterial blurs the desktop (the "glass"),
            // a colored veil sits over it for the tint. The veil's alpha IS the opacity
            // slider, so dragging transparency up genuinely lets the desktop show through —
            // which `.glassEffect`'s fixed-density material can't do.
            let tint = Color(hex: manager.pickerTintHex)
            let veil = (tint ?? Color(nsColor: .windowBackgroundColor)).opacity(manager.pickerBackgroundOpacity)
            content
                .background(veil)               // colored veil, directly behind content
                .background(.ultraThinMaterial) // glass blur, behind the veil
                .clipShape(.rect(cornerRadius: radius))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(1)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke((tint ?? .white).opacity(0.15), lineWidth: 1)
                )
        } else if reduceTransparency || contrast == .increased {
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
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(.rect(cornerRadius: PickerGlassStyle.miniButtonCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.miniButtonCornerRadius, style: .continuous)
                        .stroke(.separator.opacity(0.45), lineWidth: 1)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.miniButtonCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
}

struct PickerBadgeChipModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.badgeCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .stroke(.separator.opacity(0.5), lineWidth: 1)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.badgeCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
}

struct PickerInlineCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.inlineCardCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .stroke(.separator.opacity(0.45), lineWidth: 1)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: PickerGlassStyle.inlineCardCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
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
