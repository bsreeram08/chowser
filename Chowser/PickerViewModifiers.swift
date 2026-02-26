import SwiftUI

struct PickerSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.separator.opacity(0.5), lineWidth: 1)
                )
        } else
        if #available(macOS 26.0, *) {
            content
                .padding(1)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 0.8)
                )
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

struct PickerCircleButtonBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Circle())
        } else
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: Circle())
        } else {
            content
                .background(.white.opacity(0.05))
                .clipShape(Circle())
        }
    }
}

struct PickerShortcutBadgeBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .stroke(.separator.opacity(0.5), lineWidth: 1)
                )
        } else
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
