import SwiftUI

private enum PickerGlassStyle {
    static let panelCornerRadius: CGFloat = 16
    static let miniButtonCornerRadius: CGFloat = 6
    static let badgeCornerRadius: CGFloat = 5
    static let inlineCardCornerRadius: CGFloat = 12
}

struct PickerPanelSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
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
