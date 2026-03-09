import SwiftUI
import AppKit

/// A standalone row view for the browser list in Settings.
/// Uses local @State for editable fields so keystrokes don't trigger
/// a full-list re-render via BrowserManager. Changes commit only on
/// submit or focus loss — the same pattern as RuleRowView.
struct BrowserConfigRow: View {
    let browser: BrowserConfig
    let currentShortcut: String
    let shortcutOptions: [String]
    let hasSearchQuery: Bool

    // Callbacks
    let onEdit: () -> Void
    let onUpdateShortcut: (String) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool

    @State private var isHoveringRow = false

    init(
        browser: BrowserConfig,
        currentShortcut: String,
        shortcutOptions: [String],
        hasSearchQuery: Bool,
        onEdit: @escaping () -> Void,
        onUpdateShortcut: @escaping (String) -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        canMoveUp: Bool,
        canMoveDown: Bool
    ) {
        self.browser = browser
        self.currentShortcut = currentShortcut
        self.shortcutOptions = shortcutOptions
        self.hasSearchQuery = hasSearchQuery
        self.onEdit = onEdit
        self.onUpdateShortcut = onUpdateShortcut
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onDelete = onDelete
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
    }

    /// Quick action buttons that appear on hover
    private var quickActionsView: some View {
        HStack(spacing: 4) {
            // Move up button
            Button(action: onMoveUp) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10))
                    .foregroundStyle(canMoveUp ? .secondary : .quaternary)
            }
            .buttonStyle(.plain)
            .disabled(!canMoveUp || hasSearchQuery)
            .help("Move up")
            
            // Move down button
            Button(action: onMoveDown) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10))
                    .foregroundStyle(canMoveDown ? .secondary : .quaternary)
            }
            .buttonStyle(.plain)
            .disabled(!canMoveDown || hasSearchQuery)
            .help("Move down")
            
            Divider()
                .frame(height: 12)
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(isHoveringRow ? 1.0 : 0.5))
            }
            .buttonStyle(.plain)
            .help("Remove browser")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }

    var body: some View {
        HStack(spacing: 16) {
            browserIconView
            nameAndBundleView
            Spacer()
            shortcutPickerView
            
            // Quick actions (visible on hover)
            quickActionsView
                .opacity(isHoveringRow ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.15), value: isHoveringRow)
            
            editButtonView
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHoveringRow ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .onHover { isHoveringRow = $0 }
        .contextMenu {
            Button("Edit Browser…") { onEdit() }
            Divider()
            Button("Move Up") { onMoveUp() }
                .disabled(hasSearchQuery || !canMoveUp)
            Button("Move Down") { onMoveDown() }
                .disabled(hasSearchQuery || !canMoveDown)
            Divider()
            Button("Remove Browser", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onDelete()
                }
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var browserIconView: some View {
        if let icon = AppMetadataCache.shared.icon(for: browser.bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
        }
    }

    private var nameAndBundleView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(browser.name)
                    .font(.system(size: 13, weight: .semibold))
                
                if let args = browser.customArguments, !args.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .help("Has custom launch arguments")
                }
            }

            if let profile = browser.profile {
                Text("\(browser.bundleId) (\(profile))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                Text(browser.bundleId)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var shortcutPickerView: some View {
        let shortcutBinding = Binding<String>(
            get: { currentShortcut },
            set: { onUpdateShortcut($0) }
        )

        return HStack(spacing: 4) {
            Text("Key")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Picker("", selection: shortcutBinding) {
                ForEach(shortcutOptions, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 50)
            .labelsHidden()
            .accessibilityIdentifier("settings.browser.shortcutPicker")
            .accessibilityLabel("Shortcut key for \(browser.name)")
        }
    }

    private var editButtonView: some View {
        Button(action: onEdit) {
            Text("Edit")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isHoveringRow ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.browser.editButton")
        .accessibilityLabel("Edit \(browser.name)")
    }

    // Deletion removed from row, now in sheet
}

extension BrowserConfigRow: Equatable {
    static func == (lhs: BrowserConfigRow, rhs: BrowserConfigRow) -> Bool {
        lhs.browser == rhs.browser &&
        lhs.currentShortcut == rhs.currentShortcut &&
        lhs.shortcutOptions == rhs.shortcutOptions &&
        lhs.hasSearchQuery == rhs.hasSearchQuery &&
        lhs.canMoveUp == rhs.canMoveUp &&
        lhs.canMoveDown == rhs.canMoveDown
    }
}
