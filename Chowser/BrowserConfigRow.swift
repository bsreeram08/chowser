import SwiftUI
import AppKit

/// A standalone row view for the browser list in Settings.
/// Uses local @State for editable fields so keystrokes don't trigger
/// a full-list re-render via BrowserManager. Changes commit only on
/// submit or focus loss — the same pattern as RuleRowView.
struct BrowserConfigRow: View {
    let browser: BrowserConfig
    var browserManager: BrowserManager
    let shortcutOptions: [String]
    let hasSearchQuery: Bool

    @State private var editingName: String
    @State private var editingCustomArgs: String
    @State private var isHoveringName = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, customArgs
    }

    init(browser: BrowserConfig, browserManager: BrowserManager, shortcutOptions: [String], hasSearchQuery: Bool) {
        self.browser = browser
        self.browserManager = browserManager
        self.shortcutOptions = shortcutOptions
        self.hasSearchQuery = hasSearchQuery
        self._editingName = State(initialValue: browser.name)
        self._editingCustomArgs = State(initialValue: browser.customArguments ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                browserIconView
                nameAndBundleView
                Spacer()
                shortcutPickerView
                deleteButtonView
            }
            .padding(.vertical, 4)

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Launch Arguments")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("--profile-directory={profile} {url}", text: $editingCustomArgs)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .focused($focusedField, equals: .customArgs)
                        .onSubmit { commitField(.customArgs) }

                    Text("Placeholders: {profile}, {url}. Defaults used if empty.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 40)
                .padding(.vertical, 4)
            } label: {
                Text("Advanced")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 40)
        }
        .contextMenu {
            Button("Move Up") { moveBrowser(by: -1) }
                .disabled(hasSearchQuery || !canMove(by: -1))
            Button("Move Down") { moveBrowser(by: 1) }
                .disabled(hasSearchQuery || !canMove(by: 1))
            Divider()
            Button("Remove Browser", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    browserManager.removeBrowser(id: browser.id)
                }
            }
        }
        .onChange(of: focusedField) { oldValue, _ in
            if let field = oldValue { commitField(field) }
        }
        .onChange(of: browser) { _, newBrowser in
            if focusedField != .name { editingName = newBrowser.name }
            if focusedField != .customArgs { editingCustomArgs = newBrowser.customArguments ?? "" }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var browserIconView: some View {
        if let icon = BrowserManager.icon(forBrowserBundleID: browser.bundleId) {
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
            TextField("Name", text: $editingName)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($focusedField, equals: .name)
                .onSubmit { commitField(.name) }
                .accessibilityIdentifier("settings.browser.nameField")
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill((isHoveringName || focusedField == .name)
                              ? Color.secondary.opacity(0.12)
                              : Color.clear)
                )
                .onHover { isHoveringName = $0 }
                .help("Click to rename")

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
            get: { browserManager.shortcutKey(for: browser.id) },
            set: { browserManager.updateShortcutKey(id: browser.id, to: $0) }
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

    private var deleteButtonView: some View {
        Button(role: .destructive) {
            withAnimation(.easeInOut(duration: 0.2)) {
                browserManager.removeBrowser(id: browser.id)
            }
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(.red.opacity(0.75))
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("settings.browser.deleteButton")
        .accessibilityLabel("Remove \(browser.name)")
    }

    // MARK: - Helpers

    private func commitField(_ field: Field) {
        switch field {
        case .name:
            browserManager.updateBrowserName(id: browser.id, to: editingName)
        case .customArgs:
            browserManager.updateBrowserCustomArguments(id: browser.id, to: editingCustomArgs)
        }
    }

    private func canMove(by delta: Int) -> Bool {
        guard let currentIndex = browserManager.configuredBrowsers.firstIndex(where: { $0.id == browser.id }) else {
            return false
        }
        let dest = currentIndex + delta
        return dest >= 0 && dest < browserManager.configuredBrowsers.count
    }

    private func moveBrowser(by delta: Int) {
        guard canMove(by: delta),
              let currentIndex = browserManager.configuredBrowsers.firstIndex(where: { $0.id == browser.id }) else {
            return
        }
        let dest = currentIndex + delta
        browserManager.moveBrowsers(from: IndexSet(integer: currentIndex), to: delta > 0 ? dest + 1 : dest)
    }
}
