import SwiftUI
import UniformTypeIdentifiers

/// A collapsible group container for rules organized by browser or other criteria.
/// Shows a header with group info and expandable list of rule items.
struct CollapsibleRuleGroup: View {
    let group: RuleGroup
    let isExpanded: Bool
    let configuredBrowsers: [BrowserConfig]
    
    let onToggle: () -> Void
    let onUpdateRule: (BrowserRoutingRule) -> Void
    let onEditRule: (BrowserRoutingRule) -> Void
    let onDeleteRule: (BrowserRoutingRule) -> Void
    let onDuplicateRule: (BrowserRoutingRule) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Expand/collapse chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    // Browser icon
                    if let icon = AppMetadataCache.shared.icon(for: group.id) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Group name
                    Text(group.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    // Rule count badge
                    Text("\(group.rules.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                        )
                    
                    Spacer()
                    
                    // Enabled/disabled summary
                    let enabledCount = group.rules.filter { $0.isEnabled }.count
                    if enabledCount > 0 {
                        Text("\(enabledCount) active")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.secondary.opacity(0.06) : Color.primary.opacity(0.02))
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }
            
            // Expandable content
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.rules) { rule in
                        CollapsibleRuleRow(
                            rule: rule,
                            configuredBrowsers: configuredBrowsers,
                            onUpdate: onUpdateRule,
                            onEdit: { onEditRule(rule) },
                            onDelete: { onDeleteRule(rule) },
                            onDuplicate: { onDuplicateRule(rule) }
                        )
                        
                        if rule.id != group.rules.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.top, 4)
            }
        }
    }
}

/// A compact rule row for use inside collapsible groups
struct CollapsibleRuleRow: View {
    let rule: BrowserRoutingRule
    let configuredBrowsers: [BrowserConfig]
    let onUpdate: (BrowserRoutingRule) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    
    @State private var isHovering = false
    
    private var targetBrowserName: String {
        let identity = "\(rule.browserBundleId)|\(rule.profile ?? "")"
        return configuredBrowsers.first(where: { $0.identity == identity })?.name ?? rule.browserBundleId
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(rule.isEnabled ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(rule.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    if rule.useRegex {
                        Text("regex")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                }
                
                HStack(spacing: 4) {
                    Text(rule.hostPattern)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if let path = rule.pathPrefix, !path.isEmpty {
                        Text(path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Target browser
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(targetBrowserName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            // Quick actions
            HStack(spacing: 4) {
                Button(action: {
                    var updated = rule
                    updated.isEnabled = !rule.isEnabled
                    onUpdate(updated)
                }) {
                    Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(rule.isEnabled ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: onDuplicate) {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(isHovering ? 1.0 : 0.5))
                }
                .buttonStyle(.plain)
            }
            .opacity(isHovering ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color.clear
                .contentShape(Rectangle())
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Edit Rule…") { onEdit() }
            Button("Duplicate Rule") { onDuplicate() }
            Divider()
            Button("Remove Rule", role: .destructive) { onDelete() }
        }
    }
}

/// A standalone collapsible section using DisclosureGroup pattern
struct CollapsibleSection<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let content: Content
    let footer: Footer?
    
    @State private var isExpanded: Bool = true
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer? = { nil }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
        self.footer = footer()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                )
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                content
                    .padding(.top, 8)
                
                if let footer = footer {
                    footer
                        .padding(.top, 8)
                }
            }
        }
    }
}

extension CollapsibleSection where Footer == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
        self.footer = nil
    }
}

#Preview("Collapsible Rule Group") {
    let sampleGroup = RuleGroup(
        id: "com.google.Chrome",
        name: "Google Chrome",
        icon: "globe",
        rules: [
            BrowserRoutingRule(name: "GitHub", hostPattern: "github.com", pathPrefix: nil, browserBundleId: "com.google.Chrome"),
            BrowserRoutingRule(name: "Google Docs", hostPattern: "docs.google.com", pathPrefix: "/documents", browserBundleId: "com.google.Chrome", isEnabled: false)
        ]
    )
    
    return VStack(spacing: 16) {
        CollapsibleRuleGroup(
            group: sampleGroup,
            isExpanded: true,
            configuredBrowsers: [
                BrowserConfig(name: "Google Chrome", bundleId: "com.google.Chrome", shortcutKey: "1")
            ],
            onToggle: {},
            onUpdateRule: { _ in },
            onEditRule: { _ in },
            onDeleteRule: { _ in },
            onDuplicateRule: { _ in }
        )
        
        CollapsibleRuleGroup(
            group: RuleGroup(id: "com.brave.Browser", name: "Brave", icon: "globe", rules: []),
            isExpanded: false,
            configuredBrowsers: [],
            onToggle: {},
            onUpdateRule: { _ in },
            onEditRule: { _ in },
            onDeleteRule: { _ in },
            onDuplicateRule: { _ in }
        )
    }
    .padding()
    .frame(width: 500)
}
