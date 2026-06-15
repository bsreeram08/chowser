import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Browser Grid Drop Delegate

struct BrowserGridDropDelegate: DropDelegate {
    let targetBrowser: BrowserConfig
    let browsers: [BrowserConfig]
    @Binding var draggedBrowserId: UUID?
    @Binding var dropTargetBrowserId: UUID?
    let onMove: (Int, Int) -> Void
    
    func dropEntered(info: DropInfo) {
        dropTargetBrowserId = targetBrowser.id
        
        guard let draggedId = draggedBrowserId,
              draggedId != targetBrowser.id,
              let fromIndex = browsers.firstIndex(where: { $0.id == draggedId }),
              let toIndex = browsers.firstIndex(where: { $0.id == targetBrowser.id }) else {
            return
        }
        
        // Only update if the indices are different
        if fromIndex != toIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                onMove(fromIndex, toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
    
    func dropExited(info: DropInfo) {
        dropTargetBrowserId = nil
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggedBrowserId = nil
        dropTargetBrowserId = nil
        return true
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.plainText])
    }
}

extension SettingsView {
    
    /// View mode for browser display
    enum BrowserViewMode: String, CaseIterable, Identifiable {
        case grid
        case list
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }

    

    var hasBrowserSearchQuery: Bool {
        !browserSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filteredBrowsers: [BrowserConfig] {
        guard hasBrowserSearchQuery else {
            return browserManager.configuredBrowsers
        }
        let query = browserSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return browserManager.configuredBrowsers.filter {
            $0.name.localizedStandardContains(query) || $0.bundleId.localizedStandardContains(query)
        }
    }

    var browsersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Browsers")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Configure which browsers appear in the picker.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Picker shortcuts use keys 1–9 and support Shift/Option variants. You can also type a browser initial, then press Return.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 8) {
                    // View mode toggle
                    Picker("View", selection: $browserViewMode) {
                        ForEach(BrowserViewMode.allCases) { mode in
                            Label(mode.rawValue.capitalized, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .accessibilityIdentifier("settings.browser.viewModeToggle")

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
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .accessibilityIdentifier("settings.browsersMenuButton")

                    Button(action: { showingAddSheet = true }) {
                        Label("Add Browser", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .accessibilityIdentifier("settings.addBrowserButton")
                    .accessibilityLabel("Add a new browser to the picker")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            if profileAccessStatus.needsRecovery {
                profileAccessBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            if !browserManager.configuredBrowsers.isEmpty {
                HStack(spacing: 8) {
                    sectionSearchField(
                        placeholder: "Filter browsers by name or bundle ID",
                        text: $browserSearchText,
                        accessibilityIdentifier: "settings.browser.searchField"
                    )
                    
                    Spacer()
                    
                    // Quick stats
                    HStack(spacing: 6) {
                        Label("\(browserManager.configuredBrowsers.count) browsers", systemImage: "globe")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            if browserManager.configuredBrowsers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("No browsers configured")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Add one manually or restore the default setup.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Button("Restore Default Browser") {
                        browserManager.restoreDefaultBrowserList()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.restoreDefaultButton")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if browserViewMode == .grid {
                // Grid view for browsers
                browserGridView
            } else {
                // List view for browsers
                browserListView
            }

            HStack(spacing: 4) {
                Image(systemName: hasBrowserSearchQuery
                    ? "magnifyingglass"
                    : (browserViewMode == .grid ? "square.grid.2x2" : "arrow.up.arrow.down")
                )
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)

                Text(hasBrowserSearchQuery
                 ? "Clear search to drag and reorder browsers."
                 : "Drag to reorder · Use 1–9, initials, or Tab/↑/↓ + Return in picker")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .sheet(item: $browserToEdit) { browser in
            EditBrowserSheet(browser: browser, manager: browserManager, isPresented: Binding(
                get: { browserToEdit != nil },
                set: { if !$0 { browserToEdit = nil } }
            ))
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
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(profileAccessIconColor.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(profileAccessIconColor.opacity(0.18))
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
                return "To discover Chrome, Brave, Edge, Vivaldi, Firefox, and Zen profiles, allow read-only access to ~/Library/Application Support."
            }
            return "App Store builds can read profile names after access, but macOS sandboxing opens only the selected browser app."
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
        if SandboxBookmarkManager.shared.requestApplicationSupportAccess() {
            BrowserProfileDetector.clearCache()
            profileAccessStatus = SandboxBookmarkManager.shared.grantStatus
        } else {
            profileAccessStatus = SandboxBookmarkManager.shared.grantStatus
        }
    }

    private func resetProfileAccessFromSettings() {
        SandboxBookmarkManager.shared.clearGrant()
        BrowserProfileDetector.clearCache()
        profileAccessStatus = SandboxBookmarkManager.shared.grantStatus
    }

    // MARK: - Browser Grid View
    
    private var browserGridView: some View {
        let browsers = hasBrowserSearchQuery ? filteredBrowsers : browserManager.configuredBrowsers
        let gridSpacing = dynamicPadding(16)
        let cardMinWidth = max(180, 220 * densityMultiplier)
        let cardMaxWidth = max(240, 280 * densityMultiplier)
        
        return ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: cardMinWidth, maximum: cardMaxWidth), spacing: gridSpacing)
            ], spacing: gridSpacing) {
                ForEach(browsers) { browser in
                    BrowserCardView(
                        browser: browser,
                        currentShortcut: browserManager.shortcutKey(for: browser.id),
                        shortcutOptions: shortcutOptions,
                        densityPreference: browserManager.densityPreference,
                        onEdit: {
                            browserToEdit = browser
                        },
                        onUpdateShortcut: { newShortcut in
                            browserManager.updateShortcutKey(id: browser.id, to: newShortcut)
                        },
                        onDelete: {
                            browserManager.removeBrowser(id: browser.id)
                        }
                    )
                    .equatable()
                    .opacity(draggedBrowserId == browser.id ? 0.5 : 1.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                dropTargetBrowserId == browser.id ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .onDrag(
                        {
                            draggedBrowserId = browser.id
                            return NSItemProvider(object: browser.id.uuidString as NSString)
                        },
                        preview: {
                            BrowserCardView(
                                browser: browser,
                                currentShortcut: browserManager.shortcutKey(for: browser.id),
                                shortcutOptions: shortcutOptions,
                                densityPreference: browserManager.densityPreference,
                                onEdit: {},
                                onUpdateShortcut: { _ in },
                                onDelete: {}
                            )
                            .frame(width: cardMinWidth)
                        }
                    )
                    .onDrop(
                        of: [.plainText],
                        delegate: BrowserGridDropDelegate(
                            targetBrowser: browser,
                            browsers: browserManager.configuredBrowsers,
                            draggedBrowserId: $draggedBrowserId,
                            dropTargetBrowserId: $dropTargetBrowserId,
                            onMove: { from, to in
                                browserManager.moveBrowsers(from: IndexSet(integer: from), to: to)
                            }
                        )
                    )
                    .animation(.easeInOut(duration: 0.2), value: draggedBrowserId)
                }
            }
            .padding(dynamicPadding(20))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Browser List View
    
    private var browserListView: some View {
        List {
            if hasBrowserSearchQuery {
                ForEach(filteredBrowsers) { browser in
                    browserRow(for: browser, hasSearchQuery: true)
                }
                .onDelete(perform: removeFilteredBrowsers)
            } else {
                ForEach(browserManager.configuredBrowsers) { browser in
                    browserRow(for: browser, hasSearchQuery: false)
                }
                .onMove { indices, destination in
                    browserManager.moveBrowsers(from: indices, to: destination)
                }
                .onDelete { indices in
                    browserManager.removeBrowsers(at: indices)
                }
            }
        }
        .id(UUID())
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .accessibilityIdentifier("settings.browserList")
    }

    func removeFilteredBrowsers(at offsets: IndexSet) {
        var idsToRemove: [UUID] = []
        for offset in offsets where filteredBrowsers.indices.contains(offset) {
            idsToRemove.append(filteredBrowsers[offset].id)
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
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }

    func importBrowsers() {
        let panel = NSOpenPanel()
        panel.title = "Import Browser Configuration"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.importBrowsers(from: url, skipExisting: browserManager.skipExistingImportedBrowsers)
        } catch {
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    @ViewBuilder
    private func browserRow(for browser: BrowserConfig, hasSearchQuery: Bool) -> some View {
        let currentIndex = browserManager.configuredBrowsers.firstIndex(where: { $0.id == browser.id }) ?? 0
        let canMoveUp = currentIndex > 0
        let canMoveDown = currentIndex < browserManager.configuredBrowsers.count - 1
        
        BrowserConfigRow(
            browser: browser,
            currentShortcut: browserManager.shortcutKey(for: browser.id),
            shortcutOptions: shortcutOptions,
            hasSearchQuery: hasSearchQuery,
            onEdit: {
                browserToEdit = browser
            },
            onUpdateShortcut: { newShortcut in
                browserManager.updateShortcutKey(id: browser.id, to: newShortcut)
            },
            onMoveUp: {
                let dest = currentIndex - 1
                browserManager.moveBrowsers(from: IndexSet(integer: currentIndex), to: dest)
            },
            onMoveDown: {
                let dest = currentIndex + 1
                browserManager.moveBrowsers(from: IndexSet(integer: currentIndex), to: dest + 1)
            },
            onDelete: {
                browserManager.removeBrowser(id: browser.id)
            },
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown
        )
        .equatable() // Uses Equatable conformance
        .id(browser.id)
    }
}
