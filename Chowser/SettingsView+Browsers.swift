import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension SettingsView {
    var browsersSection: some View {
        BrowsersSettingsPage(
            browserManager: browserManager,
            profileAccessStatus: $profileAccessStatus,
            onExport: exportBrowsers,
            onImport: importBrowsers
        )
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
}

// MARK: - Page

/// The Browsers settings page: a reorderable list in picker order, an inspector for the
/// selected browser, the Add Browsers sheet, undoable removal, and hidden apps.
///
/// Reordering uses `List` + `ForEach.onMove` rather than `Table`: on macOS 14 table rows
/// have no `onMove`, only drag/drop-payload reordering, while `List.onMove` gives the
/// native drag-to-reorder insertion line with no custom transfer types.
struct BrowsersSettingsPage: View {
    let browserManager: BrowserManager
    @Binding var profileAccessStatus: SandboxBookmarkManager.GrantStatus
    let onExport: () -> Void
    let onImport: () -> Void

    @Environment(\.undoManager) private var undoManager

    @State private var selection: UUID?
    @State private var renamingID: UUID?
    @State private var showingAddSheet = false
    @State private var status: StatusMessage?
    @State private var showsHiddenApps = false
    @State private var newHiddenBundleId = ""

    /// One-line feedback under the list (shortcut swaps, removals, additions).
    struct StatusMessage: Equatable {
        let text: String
        /// Set when the message is about a removal that Undo can reverse.
        var removedBrowserID: UUID?
        var removedBrowserName: String?
    }

    private var browsers: [BrowserConfig] { browserManager.configuredBrowsers }

    var body: some View {
        let browsers = self.browsers
        let selectedBrowser = selection.flatMap { id in browsers.first { $0.id == id } }

        SettingsDetailScaffold(
            title: "Browsers",
            subtitle: "Choose the browsers and profiles that appear in the picker.",
            systemImage: "globe",
            scrollsContent: false,
            actions: { actionsMenu },
            content: {
                HStack(spacing: 0) {
                    mainColumn(browsers: browsers)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    if let selectedBrowser {
                        Divider()
                        BrowserInspector(
                            browser: selectedBrowser,
                            manager: browserManager,
                            ruleCount: browserManager.routingRuleCount(forBrowser: selectedBrowser),
                            profileAccessNeedsRecovery: profileAccessStatus.needsRecovery,
                            onRemove: { remove(selectedBrowser.id) }
                        )
                        .id(selectedBrowser.id)
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)
                    }
                }
            }
        )
        .sheet(isPresented: $showingAddSheet) {
            AddBrowserSheet(manager: browserManager, isPresented: $showingAddSheet) { added in
                handleAdded(added)
            }
        }
    }

    // MARK: Toolbar menu

    private var actionsMenu: some View {
        Menu {
            Button("Import Browsers…", systemImage: "square.and.arrow.down", action: onImport)
                .accessibilityIdentifier("settings.importBrowsersButton")

            Button("Export Browsers…", systemImage: "square.and.arrow.up", action: onExport)
                .disabled(browserManager.configuredBrowsers.isEmpty)
                .accessibilityIdentifier("settings.exportBrowsersButton")
        } label: {
            Label("More", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Import or export browsers")
        .accessibilityLabel("More browser actions")
        .accessibilityIdentifier("settings.browsersMenuButton")
    }

    // MARK: Main column

    private func mainColumn(browsers: [BrowserConfig]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if profileAccessStatus.needsRecovery {
                ProfileAccessBanner(status: $profileAccessStatus)
            }

            browserTable(browsers: browsers)
                .frame(minHeight: 180, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text("This is the order browsers appear in the picker. Drag to reorder; double-click a name to rename it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let status {
                    statusLine(status)
                }
            }

            hiddenAppsSection
        }
        .padding(20)
    }

    private func browserTable(browsers: [BrowserConfig]) -> some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section {
                    ForEach(browsers) { browser in
                        BrowserTableRow(
                            browser: browser,
                            isRenaming: renamingID == browser.id,
                            onRename: { newName in
                                browserManager.updateBrowserName(id: browser.id, to: newName)
                            },
                            onEndRename: {
                                if renamingID == browser.id { renamingID = nil }
                            },
                            onSelectShortcut: { key in
                                setShortcut(key, for: browser)
                            }
                        )
                        .tag(browser.id)
                    }
                    .onMove { offsets, destination in
                        browserManager.moveBrowsers(from: offsets, to: destination)
                    }
                } header: {
                    BrowserTableHeader()
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let id = ids.first {
                    Button("Rename") { renamingID = id }
                    Divider()
                    Button("Remove Browser") { remove(id) }
                }
            } primaryAction: { ids in
                // Double-click or Return renames inline.
                guard let id = ids.first else { return }
                selection = id
                renamingID = id
            }
            .onDeleteCommand {
                guard renamingID == nil, let selection else { return }
                remove(selection)
            }
            .overlay {
                if browsers.isEmpty {
                    emptyListContent
                }
            }
            .accessibilityLabel("Browsers, in picker order")
            .accessibilityIdentifier("settings.browserTable")

            Divider()

            tableFooter
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator)
        )
    }

    private var emptyListContent: some View {
        VStack(spacing: 8) {
            Text("No browsers")
                .font(.headline)
            Text("Add browsers with the + button, or restore the default Safari setup.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Restore Default Browser") {
                browserManager.restoreDefaultBrowserList()
            }
            .accessibilityIdentifier("settings.restoreDefaultButton")
        }
        .padding()
    }

    private var tableFooter: some View {
        HStack(spacing: 0) {
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 20)
                    .contentShape(Rectangle())
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Add browsers")
            .accessibilityLabel("Add Browsers")
            .accessibilityIdentifier("settings.addBrowserButton")

            Divider()
                .frame(height: 14)

            Button {
                if let selection { remove(selection) }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 20)
                    .contentShape(Rectangle())
            }
            .disabled(selection == nil)
            .help("Remove the selected browser")
            .accessibilityLabel("Remove Browser")
            .accessibilityIdentifier("settings.browser.removeButton")

            Spacer()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
    }

    private func statusLine(_ status: StatusMessage) -> some View {
        // After Undo (button or Edit > Undo) the removed browser is back; say so instead
        // of leaving a stale "Removed" line.
        let isRestored = status.removedBrowserID.map { id in browsers.contains { $0.id == id } } ?? false
        let text = isRestored ? "Restored \(status.removedBrowserName ?? "browser")." : status.text

        return HStack(spacing: 6) {
            Text(text)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.browser.statusText")

            if canUndoRemoval(status) {
                Button("Undo") {
                    undoManager?.undo()
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("settings.browser.undoRemoveButton")
            }
        }
        .font(.caption)
    }

    private func canUndoRemoval(_ status: StatusMessage) -> Bool {
        guard let removedID = status.removedBrowserID, let undoManager else { return false }
        return undoManager.canUndo
            && undoManager.undoActionName == "Remove Browser"
            && !browsers.contains { $0.id == removedID }
    }

    // MARK: Hidden apps

    private struct HiddenApp: Identifiable {
        let bundleId: String
        let name: String?
        let icon: NSImage?
        var id: String { bundleId }
    }

    private var hiddenAppsSection: some View {
        let hiddenIDs = browserManager.hiddenBundleIDs
        return DisclosureGroup(isExpanded: $showsHiddenApps) {
            hiddenAppsContent(hiddenIDs: hiddenIDs)
                .padding(.top, 6)
        } label: {
            // Identifier on the label, not the group: a group-level identifier would
            // override the identifiers of every control inside the expanded content.
            Text("Hidden apps (\(hiddenIDs.count))")
                .accessibilityIdentifier("settings.hiddenApps.disclosure")
        }
    }

    private func hiddenAppsContent(hiddenIDs: Set<String>) -> some View {
        // Resolved once per render of the expanded group; AppMetadataCache memoises the
        // Launch Services lookups.
        let apps = hiddenIDs.sorted().map { bundleId in
            HiddenApp(
                bundleId: bundleId,
                name: AppMetadataCache.shared.displayName(for: bundleId),
                icon: AppMetadataCache.shared.icon(for: bundleId)
            )
        }
        let trimmedNewID = newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 8) {
            if apps.isEmpty {
                Text("No hidden apps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(apps) { app in
                            HiddenAppRow(
                                bundleId: app.bundleId,
                                name: app.name,
                                icon: app.icon
                            ) {
                                browserManager.removeHiddenBundleID(app.bundleId)
                            }
                            if app.id != apps.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator)
                )
                .accessibilityIdentifier("settings.hiddenApps.list")
            }

            Text("Hidden apps can open links, but Chowser doesn't offer them in Add Browsers or use them as the fallback browser.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                TextField("Bundle ID", text: $newHiddenBundleId, prompt: Text("com.example.app"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .onSubmit(hideNewBundleID)
                    .accessibilityLabel("Bundle ID to hide")
                    .accessibilityIdentifier("settings.hiddenApps.bundleIdField")

                Button("Hide App", action: hideNewBundleID)
                    .disabled(trimmedNewID.isEmpty)
                    .accessibilityIdentifier("settings.hiddenApps.hideButton")

                Button("Restore Defaults") {
                    browserManager.resetHiddenBundleIDs()
                }
                .help("Reset the hidden list to Chowser's built-in media players")
                .accessibilityIdentifier("settings.hiddenApps.resetButton")
            }
        }
    }

    private func hideNewBundleID() {
        let trimmed = newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        browserManager.addHiddenBundleID(trimmed)
        newHiddenBundleId = ""
    }

    // MARK: Actions

    private func setShortcut(_ key: String, for browser: BrowserConfig) {
        guard key != browser.shortcutKey else { return }
        if let swapped = browserManager.updateShortcutKey(id: browser.id, to: key) {
            announce(StatusMessage(
                text: "\(browser.name) now uses \(key). \(swapped.name) moved to \(swapped.shortcutKey)."
            ))
        }
    }

    private func remove(_ id: UUID) {
        guard let index = browsers.firstIndex(where: { $0.id == id }) else { return }
        renamingID = nil

        guard let snapshot = browserManager.removeBrowser(id: id, undoManager: undoManager) else { return }

        // Keep keyboard flow: select the row that slid into the removed one's place.
        let remaining = browserManager.configuredBrowsers
        if selection == id {
            selection = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        }

        let ruleCount = browserManager.routingRuleCount(forBrowser: snapshot.browser)
        let rulesNote = ruleCount == 0
            ? ""
            : " \(ruleCount) \(ruleCount == 1 ? "rule" : "rules") for it won't match until you undo."
        announce(StatusMessage(
            text: "Removed \(snapshot.browser.name).\(rulesNote)",
            removedBrowserID: snapshot.browser.id,
            removedBrowserName: snapshot.browser.name
        ))
    }

    private func handleAdded(_ added: [BrowserConfig]) {
        guard let last = added.last else { return }
        selection = last.id
        let text = added.count == 1
            ? "Added \(last.name) with shortcut \(last.shortcutKey)."
            : "Added \(added.count) browsers."
        announce(StatusMessage(text: text))
    }

    private func announce(_ message: StatusMessage) {
        status = message
        AccessibilityNotification.Announcement(message.text).post()
    }
}

// MARK: - Table pieces

private enum BrowserTableMetrics {
    static let iconSize: CGFloat = 20
    static let profileWidth: CGFloat = 120
    static let shortcutWidth: CGFloat = 64
    static let spacing: CGFloat = 8
}

private struct BrowserTableHeader: View {
    var body: some View {
        HStack(spacing: BrowserTableMetrics.spacing) {
            Color.clear
                .frame(width: BrowserTableMetrics.iconSize, height: 1)
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Profile")
                .frame(width: BrowserTableMetrics.profileWidth, alignment: .leading)
            Text("Shortcut")
                .frame(width: BrowserTableMetrics.shortcutWidth, alignment: .leading)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

private struct BrowserTableRow: View {
    let browser: BrowserConfig
    let isRenaming: Bool
    let onRename: (String) -> Void
    let onEndRename: () -> Void
    let onSelectShortcut: (String) -> Void

    private static let shortcutKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

    var body: some View {
        HStack(spacing: BrowserTableMetrics.spacing) {
            BrowserAppIcon(bundleId: browser.bundleId, size: BrowserTableMetrics.iconSize)

            Group {
                if isRenaming {
                    InlineRenameField(name: browser.name, onCommit: onRename, onEnd: onEndRename)
                } else {
                    Text(browser.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .accessibilityIdentifier("settings.browser.name")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(browser.profile ?? "—")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: BrowserTableMetrics.profileWidth, alignment: .leading)
                .accessibilityLabel(browser.profile.map { "Profile \($0)" } ?? "No profile")

            Picker("Shortcut", selection: Binding(get: { browser.shortcutKey }, set: onSelectShortcut)) {
                ForEach(Self.shortcutKeys, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
            .frame(width: BrowserTableMetrics.shortcutWidth, alignment: .leading)
            .accessibilityLabel("Shortcut for \(browser.name)")
            .accessibilityIdentifier("settings.browser.shortcutPicker")
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.browser.row")
    }
}

/// Inline name editor shown in place of the name label. Commits on Return or when focus
/// leaves; Escape cancels.
private struct InlineRenameField: View {
    let onCommit: (String) -> Void
    let onEnd: () -> Void

    @State private var text: String
    @State private var original: String
    @State private var didFinish = false
    @FocusState private var isFocused: Bool

    init(name: String, onCommit: @escaping (String) -> Void, onEnd: @escaping () -> Void) {
        self.onCommit = onCommit
        self.onEnd = onEnd
        _text = State(initialValue: name)
        _original = State(initialValue: name)
    }

    var body: some View {
        TextField("Name", text: $text)
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onSubmit { finish(commit: true) }
            .onExitCommand { finish(commit: false) }
            .onChange(of: isFocused) { _, focused in
                if !focused { finish(commit: true) }
            }
            .onAppear {
                // Focus after the row swaps in the field; same-pass focus is dropped in Lists.
                DispatchQueue.main.async { isFocused = true }
            }
            .accessibilityLabel("Browser name")
            .accessibilityIdentifier("settings.browser.nameField")
    }

    private func finish(commit: Bool) {
        guard !didFinish else { return }
        didFinish = true
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if commit, !trimmed.isEmpty, trimmed != original {
            onCommit(trimmed)
        }
        onEnd()
    }
}

/// App icon from the process-lifetime cache, with a monochrome fallback glyph.
struct BrowserAppIcon: View {
    let bundleId: String
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = AppMetadataCache.shared.icon(for: bundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "globe")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.15)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct HiddenAppRow: View {
    let bundleId: String
    let name: String?
    let icon: NSImage?
    let onUnhide: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app.dashed")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(name ?? bundleId)
                    .lineLimit(1)
                if name != nil {
                    Text(bundleId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            Button("Unhide", action: onUnhide)
                .controlSize(.small)
                .help("Offer this app in Add Browsers again")
                .accessibilityLabel("Unhide \(name ?? bundleId)")
                .accessibilityIdentifier("settings.hiddenApps.showButton")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Inspector

private struct BrowserInspector: View {
    let browser: BrowserConfig
    let manager: BrowserManager
    let ruleCount: Int
    let profileAccessNeedsRecovery: Bool
    let onRemove: () -> Void

    private enum Field: Hashable {
        case name, customArguments, privateArguments
    }

    @State private var name: String
    @State private var customArguments: String
    @State private var privateArguments: String
    @State private var detectedProfiles: [BrowserProfile] = []
    @State private var showsAdvanced: Bool
    @FocusState private var focusedField: Field?

    init(
        browser: BrowserConfig,
        manager: BrowserManager,
        ruleCount: Int,
        profileAccessNeedsRecovery: Bool,
        onRemove: @escaping () -> Void
    ) {
        self.browser = browser
        self.manager = manager
        self.ruleCount = ruleCount
        self.profileAccessNeedsRecovery = profileAccessNeedsRecovery
        self.onRemove = onRemove
        _name = State(initialValue: browser.name)
        _customArguments = State(initialValue: browser.customArguments ?? "")
        _privateArguments = State(initialValue: browser.privateArguments ?? "")
        _showsAdvanced = State(initialValue: false)
    }

    private var appName: String {
        AppMetadataCache.shared.displayName(for: browser.bundleId) ?? browser.bundleId
    }

    var body: some View {
        let appName = self.appName
        let profileOptions = self.profileOptions

        Form {
            Section {
                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .onSubmit(commitName)
                    .accessibilityIdentifier("settings.browserInspector.nameField")

                LabeledContent("Browser app") {
                    HStack(spacing: 6) {
                        BrowserAppIcon(bundleId: browser.bundleId, size: 16)
                        Text(appName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help(browser.bundleId)
                }
                .accessibilityIdentifier("settings.browserInspector.appLabel")

                Picker("Profile", selection: profileBinding) {
                    Text("No specific profile").tag(String?.none)
                    ForEach(profileOptions, id: \.id) { option in
                        Text(option.label).tag(Optional(option.id))
                    }
                }
                .disabled(profileOptions.isEmpty && browser.profile == nil)
                .accessibilityIdentifier("settings.browserInspector.profilePicker")
            } footer: {
                Text(profileHint(appName: appName, optionCount: profileOptions.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(isExpanded: $showsAdvanced) {
                    TextField("Launch arguments", text: $customArguments, prompt: Text("--profile-directory={profile}"))
                        .font(.body.monospaced())
                        .focused($focusedField, equals: .customArguments)
                        .onSubmit(commitCustomArguments)
                        .accessibilityIdentifier("settings.browserInspector.argsField")

                    TextField("Private window arguments", text: $privateArguments, prompt: Text("--incognito"))
                        .font(.body.monospaced())
                        .focused($focusedField, equals: .privateArguments)
                        .onSubmit(commitPrivateArguments)
                        .accessibilityIdentifier("settings.browserInspector.privateArgsField")

                    Text(argumentsHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Advanced")
                    .accessibilityIdentifier("settings.browserInspector.advancedDisclosure")
            }

            Section {
                if ruleCount > 0 {
                    Text("\(ruleCount) \(ruleCount == 1 ? "rule uses" : "rules use") this browser. Undo brings them back if you remove it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.browserInspector.ruleUsageNote")
                }

                Button("Remove Browser", role: .destructive, action: onRemove)
                    .accessibilityIdentifier("settings.browserInspector.removeButton")
            }
        }
        .formStyle(.grouped)
        .task(id: browser.bundleId) {
            detectedProfiles = BrowserProfileDetector.detectProfiles(for: browser.bundleId)
        }
        .onChange(of: focusedField) { oldField, _ in
            commit(oldField)
        }
        .onChange(of: browser.name) { _, newValue in
            // Inline renames in the table update the model while the inspector is open.
            guard focusedField != .name else { return }
            name = newValue
        }
        .onDisappear {
            commit(.name)
            commit(.customArguments)
            commit(.privateArguments)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.browserInspector")
    }

    // MARK: Profile

    private struct ProfileOption {
        let id: String
        let label: String
    }

    /// Detected profiles for this app, minus ones another configured entry already uses
    /// (bundle ID + profile must stay unique). Keeps the current value even if it wasn't
    /// detected (typed manually, imported, or no profile access).
    private var profileOptions: [ProfileOption] {
        let takenByOthers = Set(manager.configuredBrowsers.compactMap { other -> String? in
            guard other.id != browser.id, other.bundleId == browser.bundleId else { return nil }
            return other.profile
        })

        var options = detectedProfiles
            .filter { !takenByOthers.contains($0.id) }
            .map { ProfileOption(id: $0.id, label: $0.name == $0.id ? $0.name : "\($0.name) (\($0.id))") }

        if let current = browser.profile, !options.contains(where: { $0.id == current }) {
            options.insert(ProfileOption(id: current, label: current), at: 0)
        }
        return options
    }

    private var profileBinding: Binding<String?> {
        Binding(
            get: { browser.profile },
            set: { manager.updateBrowserProfile(id: browser.id, to: $0 ?? "") }
        )
    }

    private func profileHint(appName: String, optionCount: Int) -> String {
        if !BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
            return "App Store builds can't open a specific profile, so links open in \(appName)'s last-used window. The setting is kept for the direct-download version."
        }
        if detectedProfiles.isEmpty {
            if profileAccessNeedsRecovery {
                return "Allow profile access to look for \(appName) profiles."
            }
            return "No profiles found for \(appName). Links open in its last-used window."
        }
        let count = detectedProfiles.count
        return "\(count) \(count == 1 ? "profile" : "profiles") found in \(appName) on this Mac."
    }

    private var argumentsHint: String {
        if BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
            return "Extra flags passed when Chowser opens this browser. Placeholders: {profile}, {url}; if {url} is omitted the link is appended. Private window arguments are used in private mode."
        }
        return "Saved for the direct-download version. macOS may ignore launch arguments from the sandboxed App Store build."
    }

    // MARK: Commit

    private func commit(_ field: Field?) {
        switch field {
        case .name: commitName()
        case .customArguments: commitCustomArguments()
        case .privateArguments: commitPrivateArguments()
        case nil: break
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            name = browser.name
            return
        }
        guard trimmed != browser.name else { return }
        manager.updateBrowserName(id: browser.id, to: trimmed)
    }

    private func commitCustomArguments() {
        let trimmed = customArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (browser.customArguments ?? "") else { return }
        manager.updateBrowserCustomArguments(id: browser.id, to: trimmed)
    }

    private func commitPrivateArguments() {
        let trimmed = privateArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (browser.privateArguments ?? "") else { return }
        manager.updateBrowserPrivateArguments(id: browser.id, to: trimmed)
    }
}

// MARK: - Profile access banner (App Store sandbox)

private struct ProfileAccessBanner: View {
    @Binding var status: SandboxBookmarkManager.GrantStatus

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button("Allow Access…") {
                grantAccess()
            }
            .controlSize(.small)
            .accessibilityIdentifier("settings.profileAccess.grantButton")

            if status.hasStoredBookmark {
                Button("Reset") {
                    resetAccess()
                }
                .controlSize(.small)
                .accessibilityIdentifier("settings.profileAccess.resetButton")
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.profileAccess.banner")
    }

    private var iconName: String {
        switch status {
        case .missing: return "folder.badge.questionmark"
        case .stale, .invalid: return "exclamationmark.triangle"
        case .granted: return "checkmark.shield"
        }
    }

    private var title: String {
        switch status {
        case .missing: return "Browser profile access is optional"
        case .stale: return "Browser profile access needs renewal"
        case .invalid: return "Browser profile access needs repair"
        case .granted: return "Browser profile access enabled"
        }
    }

    private var message: String {
        switch status {
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
    private func grantAccess() {
        _ = SandboxBookmarkManager.shared.requestApplicationSupportAccess()
        BrowserProfileDetector.clearCache()
        status = SandboxBookmarkManager.shared.grantStatus
    }

    private func resetAccess() {
        SandboxBookmarkManager.shared.clearGrant()
        BrowserProfileDetector.clearCache()
        status = SandboxBookmarkManager.shared.grantStatus
    }
}
