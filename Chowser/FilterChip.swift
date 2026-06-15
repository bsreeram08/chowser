import SwiftUI

/// A compact filter chip button for toggling filter states.
/// Shows an optional icon, title, and optional count badge.
struct FilterChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    @State private var isHovering = false
    
    init(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        count: Int? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.count = count
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .customChipSurface(
                cornerRadius: 999,
                isSelected: isSelected,
                selectedColor: .accentColor,
                hoverOpacity: isHovering ? 0.06 : 0.03
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// A sticky header container that stays at the top of scrollable content
struct StickyHeader<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.regularMaterial)
    }
}

/// A section header with optional action button
struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let actionIcon: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        actionIcon: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.actionIcon = actionIcon
        self.action = action
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    HStack(spacing: 4) {
                        if let icon = actionIcon {
                            Image(systemName: icon)
                                .font(.system(size: 10, weight: .medium))
                        }
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

/// Empty state view with icon, title, and optional action
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            if let message = message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Filter Chips") {
    VStack(spacing: 20) {
        HStack(spacing: 8) {
            FilterChip(title: "All", icon: "line.3.horizontal.decrease.circle", isSelected: true, count: 12) {}
            FilterChip(title: "Enabled", icon: "checkmark.circle.fill", isSelected: false, count: 8) {}
            FilterChip(title: "Disabled", icon: "circle.slash", isSelected: false, count: 4) {}
        }
        
        HStack(spacing: 8) {
            FilterChip(title: "All", isSelected: false, count: nil) {}
            FilterChip(title: "Enabled", isSelected: true, count: 5) {}
        }
    }
    .padding()
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "globe",
        title: "No browsers configured",
        message: "Add one manually or restore the default setup.",
        actionTitle: "Restore Default",
        action: {}
    )
    .frame(width: 400, height: 300)
}
