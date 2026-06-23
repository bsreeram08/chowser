import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension SettingsView {
    var hasBrowserSearchQuery: Bool {
        !browserSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filteredBrowsers: [BrowserConfig] {
        guard hasBrowserSearchQuery else {
            return browserManager.configuredBrowsers
        }

        let query = browserSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return browserManager.configuredBrowsers.filter {
            $0.name.localizedStandardContains(query)
                || $0.bundleId.localizedStandardContains(query)
                || ($0.profile?.localizedStandardContains(query) ?? false)
        }
    }

    var browsersSection: some View {
        SettingsDetailScaffold(
            title: "Browsers",
            subtitle: "Choose the browsers and profiles that appear in the picker.",
            systemImage: "globe",
            actions: {
                HStack(spacing: 8) {
                    Menu {
                        Button(action: exportBrowsers) {
                            Label("Export Browsers…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(browserManager.configuredBrowsers.isEmpty)
                        .accessibilityIdentifier("settings.exportBrowsersButton")

                        Button(action: importBrowsers) {
                            Label("Import Browsers…", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("settings.importBrowsersButton")
                    } label: {
                        Label("Browser Actions", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityIdentifier("settings.browsersMenuButton")

                    Button("Add Browser", systemImage: "plus") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut("n", modifiers: .command)
                    .accessibilityIdentifier("settings.addBrowserButton")
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    if profileAccessStatus.needsRecovery {
                        profileAccessBanner
                    }

                    HStack(spacing: 12) {
                        sectionSearchField(
                            placeholder: "Filter browsers by name, bundle ID, or profile",
                            text: $browserSearchText,
                            accessibilityIdentifier: "settings.browser.searchField"
                        )

                        Text("\(browserManager.configuredBrowsers.count) configured")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    browserListContent
                }
            }
        )
    }

    @ViewBuilder
    private var browserListContent: some View {
        if browserManager.configuredBrowsers.isEmpty {
            SettingsEmptyContent(
                systemImage: "globe",
                title: "No browsers configured",
                message: "Restore the default Safari setup or add an app manually.",
                actionTitle: "Restore Default Browser"
            ) {
                browserManager.restoreDefaultBrowserList()
            }
            .accessibilityIdentifier("settings.restoreDefaultButton")
        } else if filteredBrowsers.isEmpty {
            SettingsEmptyContent(
                systemImage: "magnifyingglass",
                title: "No matching browsers",
                message: "Clear the filter to show all configured browsers."
            )
        } else {
            // Plain VStack of rows (not a List): a List nested in this NavigationSplitView
            // detail mis-lays-out until a window resize. Scaffold supplies the ScrollView.
            VStack(spacing: 0) {
                ForEach(Array(filteredBrowsers.enumerated()), id: \.element.id) { index, browser in
                    browserRow(for: browser, hasSearchQuery: hasBrowserSearchQuery)
                    if index < filteredBrowsers.count - 1 {
                        SettingsDivider()
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.separator.opacity(0.35), lineWidth: 1)
            )
            .accessibilityIdentifier("settings.browserList")
        }
    }

    private var profileAccessBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: profileAccessIconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(profileAccessIconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(profileAccessTitle)
                    .font(.system(size: 12, weight: .semibold))
                Text(profileAccessMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button("Allow Access…") {
                grantProfileAccessFromSettings()
            }
            .controlSize(.small)
            .accessibilityIdentifier("settings.profileAccess.grantButton")

            if profileAccessStatus.hasStoredBookmark {
                Button("Reset") {
                    resetProfileAccessFromSettings()
                }
                .controlSize(.small)
                .accessibilityIdentifier("settings.profileAccess.resetButton")
            }
        }
        .padding(12)
        .background(profileAccessIconColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(profileAccessIconColor.opacity(0.18), lineWidth: 1)
        )
        .accessibilityIdentifier("settings.profileAccess.banner")
    }

    private var profileAccessIconName: String {
        switch profileAccessStatus {
        case .missing:
            return "folder.badge.questionmark"
        case .stale, .invalid:
            return "exclamationmark.triangle"
        case .granted:
            return "checkmark.shield"
        }
    }

    private var profileAccessIconColor: Color {
        switch profileAccessStatus {
        case .missing:
            return .blue
        case .stale, .invalid:
            return .orange
        case .granted:
            return .green
        }
    }

    private var profileAccessTitle: String {
        switch profileAccessStatus {
        case .missing:
            return "Browser profile access is optional"
        case .stale:
            return "Browser profile access needs renewal"
        case .invalid:
            return "Browser profile access needs repair"
        case .granted:
            return "Browser profile access enabled"
        }
    }

    private var profileAccessMessage: String {
        switch profileAccessStatus {
        case .missing:
            if BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
                return "Allow read-only access to ~/Library/Application Support to discover Chrome, Brave, Edge, Vivaldi, Firefox, and Zen profiles."
            }
            return "App Store builds can list profile names after access, but macOS sandboxing opens only the selected browser app."
        case .stale:
            return "The saved Application Support permission is stale. Grant access again to refresh browser profile discovery."
        case .invalid:
            return "The saved Application Support permission could not be opened. Reset it or grant access again."
        case .granted:
            if BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
                return "Chowser can read browser profile names from Application Support."
            }
            return "Chowser can read browser profile names, but App Store builds cannot pass profile/private launch arguments to browsers."
        }
    }

    @MainActor
    private func grantProfileAccessFromSettings() {
        _ = SandboxBookmarkManager.shared.requestApplicationSupportAccess()
        BrowserProfileDetector.clearCache()
        profileAccessStatus = SandboxBookmarkManager.shared.grantStatus
    }

    private func resetProfileAccessFromSettings() {
        SandboxBookmarkManager.shared.clearGrant()
        BrowserProfileDetector.clearCache()
        profileAccessStatus = SandboxBookmarkManager.shared.grantStatus
    }

    func removeFilteredBrowsers(at offsets: IndexSet) {
        let idsToRemove = offsets.compactMap { offset in
            filteredBrowsers.indices.contains(offset) ? filteredBrowsers[offset].id : nil
        }

        for id in idsToRemove {
            browserManager.removeBrowser(id: id)
        }
    }

    func exportBrowsers() {
        let panel = NSSavePanel()
        panel.title = "Export Browser Configuration"
        panel.nameFieldStringValue = "ChowserBrowsers.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.exportBrowsers(to: url)
            presentSettingsMessage("Export complete", "Browsers exported to \(url.lastPathComponent).")
        } catch {
            presentSettingsMessage("Export failed", "Could not export browsers.\n\n\(error.localizedDescription)")
        }
    }

    func importBrowsers() {
        let panel = NSOpenPanel()
        panel.title = "Import Browser Configuration"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let summary = try browserManager.importBrowsers(
                from: url,
                skipExisting: browserManager.skipExistingImportedBrowsers
            )
            presentImportSummary(for: "Browsers", summary: summary, successTitle: "Browsers import complete")
        } catch {
            presentSettingsMessage("Import failed", "Could not import browsers.\n\n\(error.localizedDescription)")
        }
    }

    private func browserRow(for browser: BrowserConfig, hasSearchQuery: Bool) -> some View {
        let currentIndex = browserManager.configuredBrowsers.firstIndex(where: { $0.id == browser.id }) ?? 0
        let canMoveUp = currentIndex > 0
        let canMoveDown = currentIndex < browserManager.configuredBrowsers.count - 1

        return SettingsBrowserRow(
            browser: browser,
            currentShortcut: browserManager.shortcutKey(for: browser.id),
            shortcutOptions: shortcutOptions,
            hasSearchQuery: hasSearchQuery,
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            onRename: { newName in
                browserManager.updateBrowserName(id: browser.id, to: newName)
            },
            onUpdateShortcut: { newShortcut in
                browserManager.updateShortcutKey(id: browser.id, to: newShortcut)
            },
            onMoveUp: {
                browserManager.moveBrowsers(from: IndexSet(integer: currentIndex), to: currentIndex - 1)
            },
            onMoveDown: {
                browserManager.moveBrowsers(from: IndexSet(integer: currentIndex), to: currentIndex + 2)
            },
            onEdit: {
                browserToEdit = browser
            },
            onDelete: {
                browserManager.removeBrowser(id: browser.id)
            }
        )
    }
}

private struct BrowserListHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Browser")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Shortcut")
                .frame(width: 92, alignment: .leading)
            Text("Order")
                .frame(width: 84, alignment: .leading)
            Text("Actions")
                .frame(width: 112, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct SettingsBrowserRow: View {
    let browser: BrowserConfig
    let currentShortcut: String
    let shortcutOptions: [String]
    let hasSearchQuery: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onRename: (String) -> Void
    let onUpdateShortcut: (String) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var editingName: String
    @FocusState private var isNameFocused: Bool

    init(
        browser: BrowserConfig,
        currentShortcut: String,
        shortcutOptions: [String],
        hasSearchQuery: Bool,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onRename: @escaping (String) -> Void,
        onUpdateShortcut: @escaping (String) -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.browser = browser
        self.currentShortcut = currentShortcut
        self.shortcutOptions = shortcutOptions
        self.hasSearchQuery = hasSearchQuery
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onRename = onRename
        self.onUpdateShortcut = onUpdateShortcut
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onEdit = onEdit
        self.onDelete = onDelete
        self._editingName = State(initialValue: browser.name)
    }

    var body: some View {
        HStack(spacing: 12) {
            browserIdentityView
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Shortcut", selection: Binding(get: { currentShortcut }, set: onUpdateShortcut)) {
                ForEach(shortcutOptions, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 92, alignment: .leading)
            .accessibilityIdentifier("settings.browser.shortcutPicker")
            .accessibilityLabel("Shortcut key for \(browser.name)")

            HStack(spacing: 4) {
                Button("Move Up", systemImage: "arrow.up") {
                    onMoveUp()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(hasSearchQuery || !canMoveUp)
                .help(hasSearchQuery ? "Clear search before reordering" : "Move up")

                Button("Move Down", systemImage: "arrow.down") {
                    onMoveDown()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(hasSearchQuery || !canMoveDown)
                .help(hasSearchQuery ? "Clear search before reordering" : "Move down")
            }
            .frame(width: 84, alignment: .leading)

            HStack(spacing: 6) {
                Button("Edit") {
                    onEdit()
                }
                .controlSize(.small)
                .accessibilityIdentifier("settings.browser.editButton")
                .accessibilityLabel("Edit \(browser.name)")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("Remove")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("settings.browser.deleteButton")
                .accessibilityLabel("Remove \(browser.name)")
            }
            .frame(width: 112, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onChange(of: browser.name) { _, newValue in
            guard !isNameFocused else { return }
            editingName = newValue
        }
        .onChange(of: isNameFocused) { _, focused in
            guard !focused else { return }
            commitName()
        }
        .contextMenu {
            Button("Edit Browser…", action: onEdit)
            Divider()
            Button("Move Up", action: onMoveUp)
                .disabled(hasSearchQuery || !canMoveUp)
            Button("Move Down", action: onMoveDown)
                .disabled(hasSearchQuery || !canMoveDown)
            Divider()
            Button("Remove Browser", role: .destructive, action: onDelete)
        }
    }

    private var browserIdentityView: some View {
        HStack(spacing: 12) {
            if let icon = AppMetadataCache.shared.icon(for: browser.bundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
            }

            VStack(alignment: .leading, spacing: 3) {
                TextField("Browser name", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .focused($isNameFocused)
                    .onSubmit(commitName)
                    .accessibilityIdentifier("settings.browser.nameField")

                HStack(spacing: 6) {
                    Text(browser.bundleId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let engine = BrowserManager.browserEngineLabel(forBundleID: browser.bundleId) {
                        Text(engine)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }

                    if let profile = browser.profile {
                        Text(profile)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }

                    if let args = browser.customArguments, !args.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .help("Has custom launch arguments")
                    }
                }
            }
        }
    }

    private func commitName() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editingName = browser.name
            return
        }

        guard trimmed != browser.name else { return }
        onRename(trimmed)
    }
}
