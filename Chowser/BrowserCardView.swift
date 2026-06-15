import SwiftUI
import AppKit

/// A card view for displaying browser configuration in a grid layout.
/// Shows browser icon, name, profile badge, shortcut key prominently, and action buttons.
/// Supports density preferences: compact, default, comfortable.
struct BrowserCardView: View {
    let browser: BrowserConfig
    let currentShortcut: String
    let shortcutOptions: [String]
    let densityPreference: String
    let onEdit: () -> Void
    let onUpdateShortcut: (String) -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    // Density multipliers
    private var densityMultiplier: CGFloat {
        switch densityPreference {
        case "compact": return 0.8
        case "comfortable": return 1.2
        default: return 1.0
        }
    }
    
    private var basePadding: CGFloat { 16 * densityMultiplier }
    private var iconSize: CGFloat { 48 * densityMultiplier }
    private var fontSize: CGFloat { 15 * densityMultiplier }
    private var smallFontSize: CGFloat { 10 * densityMultiplier }
    private var cardMinWidth: CGFloat { 220 * densityMultiplier }
    private var cardMinHeight: CGFloat { 180 * densityMultiplier }
    private var cardMaxWidth: CGFloat { 280 * densityMultiplier }
    private var spacing: CGFloat { max(8, 12 * densityMultiplier) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with icon and name
            HStack {
                browserIconView
                    .frame(width: iconSize, height: iconSize)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.name)
                        .font(.system(size: fontSize, weight: .semibold))
                        .lineLimit(1)
                        .accessibilityIdentifier("settings.browser.nameText")
                    
                    if let profile = browser.profile {
                        ProfileBadge(profile: profile, densityPreference: densityPreference)
                    }
                }
                
                Spacer()
                
                // Shortcut key badge
                ShortcutKeyBadge(key: currentShortcut, densityPreference: densityPreference)
            }
            .padding(.horizontal, basePadding)
            .padding(.top, basePadding)
            
            // Bundle ID
            Text(browser.bundleId)
                .font(.system(size: smallFontSize - 2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, basePadding)
                .padding(.top, 4)
            
            // Custom arguments indicator
            if let args = browser.customArguments, !args.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: smallFontSize - 2))
                    Text("Custom arguments")
                        .font(.system(size: smallFontSize - 2))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, basePadding)
                .padding(.top, 2)
            }
            
            Spacer(minLength: spacing)
            
            // Actions
            HStack(spacing: 8) {
                // Shortcut picker
                HStack(spacing: 4) {
                    Text("Key")
                        .font(.system(size: smallFontSize - 2, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { currentShortcut },
                        set: { onUpdateShortcut($0) }
                    )) {
                        ForEach(shortcutOptions, id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 50 * densityMultiplier)
                    .labelsHidden()
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: smallFontSize, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(densityPreference == "compact" ? .small : .regular)
                
                Button(action: onDelete) {
                    Label("Remove", systemImage: "trash")
                        .font(.system(size: smallFontSize, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(densityPreference == "compact" ? .small : .regular)
                .accessibilityIdentifier("settings.browser.deleteButton")
                .accessibilityLabel("Remove \(browser.name)")
            }
            .padding(.horizontal, basePadding)
            .padding(.bottom, basePadding)
        }
        .frame(minWidth: cardMinWidth, maxWidth: cardMaxWidth, minHeight: cardMinHeight)
        .customCardSurface(
            cornerRadius: 12,
            shadowOpacity: isHovering ? 0.12 : 0.06,
            shadowRadius: isHovering ? 8 : 4,
            shadowYOffset: isHovering ? 4 : 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovering ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .contextMenu {
            Button("Edit Browser…") { onEdit() }
            Divider()
            Button("Remove Browser", role: .destructive) { onDelete() }
        }
    }
    
    @ViewBuilder
    private var browserIconView: some View {
        if let icon = AppMetadataCache.shared.icon(for: browser.bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "globe")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
        }
    }
}

/// A small badge showing the browser profile name
struct ProfileBadge: View {
    let profile: String
    let densityPreference: String
    
    private var fontSize: CGFloat {
        switch densityPreference {
        case "compact": return 7
        case "comfortable": return 11
        default: return 9
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch densityPreference {
        case "compact": return 4
        case "comfortable": return 8
        default: return 6
        }
    }
    
    private var verticalPadding: CGFloat {
        switch densityPreference {
        case "compact": return 1
        case "comfortable": return 3
        default: return 2
        }
    }
    
    var body: some View {
        Text(profile)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.7))
            )
    }
}

/// A badge showing the shortcut key
struct ShortcutKeyBadge: View {
    let key: String
    let densityPreference: String
    
    private var size: CGFloat {
        switch densityPreference {
        case "compact": return 22
        case "comfortable": return 32
        default: return 28
        }
    }
    
    private var fontSize: CGFloat {
        switch densityPreference {
        case "compact": return 11
        case "comfortable": return 16
        default: return 14
        }
    }
    
    var body: some View {
        Text(key)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor)
            )
    }
}

extension BrowserCardView: Equatable {
    static func == (lhs: BrowserCardView, rhs: BrowserCardView) -> Bool {
        lhs.browser == rhs.browser &&
        lhs.currentShortcut == rhs.currentShortcut &&
        lhs.shortcutOptions == rhs.shortcutOptions &&
        lhs.densityPreference == rhs.densityPreference
    }
}

#Preview("Browser Card - Default") {
    BrowserCardView(
        browser: BrowserConfig(name: "Google Chrome", bundleId: "com.google.Chrome", shortcutKey: "2", profile: "Work"),
        currentShortcut: "2",
        shortcutOptions: ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
        densityPreference: "default",
        onEdit: {},
        onUpdateShortcut: { _ in },
        onDelete: {}
    )
    .frame(width: 260, height: 200)
    .padding()
}

#Preview("Browser Card - Compact") {
    BrowserCardView(
        browser: BrowserConfig(name: "Google Chrome", bundleId: "com.google.Chrome", shortcutKey: "2", profile: "Work"),
        currentShortcut: "2",
        shortcutOptions: ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
        densityPreference: "compact",
        onEdit: {},
        onUpdateShortcut: { _ in },
        onDelete: {}
    )
    .frame(width: 220, height: 160)
    .padding()
}

#Preview("Browser Card - Comfortable") {
    BrowserCardView(
        browser: BrowserConfig(name: "Google Chrome", bundleId: "com.google.Chrome", shortcutKey: "2", profile: "Work"),
        currentShortcut: "2",
        shortcutOptions: ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
        densityPreference: "comfortable",
        onEdit: {},
        onUpdateShortcut: { _ in },
        onDelete: {}
    )
    .frame(width: 320, height: 240)
    .padding()
}
