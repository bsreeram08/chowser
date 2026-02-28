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

            if !browserManager.configuredBrowsers.isEmpty {
                sectionSearchField(
                    placeholder: "Filter browsers by name or bundle ID",
                    text: $browserSearchText,
                    accessibilityIdentifier: "settings.browser.searchField"
                )
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
            } else {
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

            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)

                Text(hasBrowserSearchQuery
                 ? "Clear search to drag reorder • Use 1–9, initials, or Tab/↑/↓ + Return in picker"
                 : "Drag to reorder • Use 1–9, initials, or Tab/↑/↓ + Return in picker")
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
            try browserManager.importBrowsers(from: url)
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
