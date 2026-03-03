import SwiftUI
import UniformTypeIdentifiers

struct RuleRowView: View {
    let rule: BrowserRoutingRule
    let configuredBrowsers: [BrowserConfig]
    let hasSearchQuery: Bool

    let onUpdate: (BrowserRoutingRule) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
    // Explicit movement state
    let canMoveUp: Bool
    let canMoveDown: Bool

    @State private var isHoveringRow = false

    init(
        rule: BrowserRoutingRule,
        configuredBrowsers: [BrowserConfig],
        hasSearchQuery: Bool,
        onUpdate: @escaping (BrowserRoutingRule) -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDuplicate: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        isValidHostPattern: @escaping (String) -> Bool,
        canMoveUp: Bool,
        canMoveDown: Bool
    ) {
        self.rule = rule
        self.configuredBrowsers = configuredBrowsers
        self.hasSearchQuery = hasSearchQuery
        self.onUpdate = onUpdate
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
    }

    private var matchSummary: String {
        let pathText = (rule.pathPrefix?.isEmpty == false) ? " + path \(rule.pathPrefix!)" : ""
        let statusText = rule.isEnabled ? "Enabled" : "Disabled"
        var summary = "\(statusText): host \(rule.hostPattern)\(pathText)"
        if let bundleId = rule.sourceAppBundleId, !bundleId.isEmpty {
            let name = AppMetadataCache.shared.displayName(for: bundleId) ?? bundleId
            summary += " from \(name)"
        }
        if rule.usePrivateMode {
            summary += " • private"
        }
        return summary
    }

    private var targetBrowserName: String {
        let identity = "\(rule.browserBundleId)|\(rule.profile ?? "")"
        return configuredBrowsers.first(where: { $0.identity == identity })?.name ?? rule.browserBundleId
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { newValue in
                        var updated = rule
                        updated.isEnabled = newValue
                        onUpdate(updated)
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel("Enable rule \(rule.name)")

                Text(rule.isEnabled ? "ON" : "OFF")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(rule.isEnabled ? .green : .secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(rule.name)
                        .font(.system(size: 13, weight: .semibold))
                    if rule.useRegex {
                        Text("regex")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                    Text(rule.hostPattern)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let path = rule.pathPrefix, !path.isEmpty {
                        Text(path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 4) {
                    Text("Opens in")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Text(targetBrowserName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    if let source = rule.sourceAppBundleId, !source.isEmpty {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text("From")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        
                        if let icon = AppMetadataCache.shared.icon(for: source) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 10, height: 10)
                        }
                        
                        Text(AppMetadataCache.shared.displayName(for: source) ?? source)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    if rule.usePrivateMode {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("Private")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: onEdit) {
                Text("Edit")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isHoveringRow ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.rule.editButton")
            .accessibilityLabel("Edit \(rule.name)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHoveringRow ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .onHover { isHoveringRow = $0 }
        .contextMenu {
            Button("Edit Rule…") { onEdit() }
            Divider()
            Button("Move Up") { onMoveUp() }
                .disabled(hasSearchQuery || !canMoveUp)

            Button("Move Down") { onMoveDown() }
                .disabled(hasSearchQuery || !canMoveDown)

            Button("Duplicate Rule") { onDuplicate() }

            Divider()

            Button("Remove Rule", role: .destructive) { onDelete() }
        }
    }
}

extension RuleRowView: Equatable {
    static func == (lhs: RuleRowView, rhs: RuleRowView) -> Bool {
        lhs.rule == rhs.rule &&
        lhs.configuredBrowsers == rhs.configuredBrowsers &&
        lhs.hasSearchQuery == rhs.hasSearchQuery &&
        lhs.canMoveUp == rhs.canMoveUp &&
        lhs.canMoveDown == rhs.canMoveDown
    }
}
