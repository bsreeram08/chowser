import SwiftUI
import UniformTypeIdentifiers

extension SettingsView {

    var hasRuleSearchQuery: Bool {
        !ruleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filteredRoutingRules: [BrowserRoutingRule] {
        hasRuleSearchQuery ? filteredRules : browserManager.routingRules
    }

    func updateFilteredRules() {
        guard hasRuleSearchQuery else { filteredRules = []; return }
        let query = ruleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let browserNames = Dictionary(
            browserManager.configuredBrowsers.map { ($0.bundleId, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        filteredRules = browserManager.routingRules.filter { rule in
            let targetBrowser = browserNames[rule.browserBundleId] ?? ""
            return rule.name.localizedStandardContains(query)
                || rule.hostPattern.localizedStandardContains(query)
                || (rule.pathPrefix ?? "").localizedStandardContains(query)
                || targetBrowser.localizedStandardContains(query)
        }
    }

    var activeRoutingRulesCount: Int {
        browserManager.routingRules.filter(\.isEnabled).count
    }

    func sidebarBadge(for section: SettingsSection) -> Int {
        switch section {
        case .browsers:
            return browserManager.configuredBrowsers.count
        case .rules:
            return activeRoutingRulesCount
        case .apps:
            return browserManager.hiddenBundleIDs.count
        case .general:
            return 0
        }
    }

    var rulesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rules")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Automatically route links by domain and optional path prefix.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        rulesStatusBadge(title: "\(browserManager.routingRules.count) Total", color: .secondary)
                        rulesStatusBadge(
                            title: "\(activeRoutingRulesCount) Active",
                            color: activeRoutingRulesCount > 0 ? .green : .secondary
                        )
                    }
                    .padding(.top, 4)
                }

                Spacer()

                HStack(spacing: 8) {
                    Menu {
                        Button(action: exportRules) {
                            Label("Export Rules…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(browserManager.routingRules.isEmpty)
                        .accessibilityIdentifier("settings.exportRulesButton")

                        Button(action: importRules) {
                            Label("Import Rules…", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("settings.importRulesButton")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .accessibilityIdentifier("settings.rulesMenuButton")

                    Button(action: { showingAddRuleSheet = true }) {
                        Label("Add Rule", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .disabled(browserManager.configuredBrowsers.isEmpty)
                    .accessibilityIdentifier("settings.addRuleButton")
                    .accessibilityLabel("Add a new routing rule")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            if !browserManager.configuredBrowsers.isEmpty && !browserManager.routingRules.isEmpty {
                sectionSearchField(
                    placeholder: "Filter rules by name, host, path, or browser",
                    text: $ruleSearchText,
                    accessibilityIdentifier: "settings.rule.searchField"
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

            if browserManager.configuredBrowsers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text("Add at least one browser first")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Routing rules need a target browser. Configure browsers in the Browsers tab.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if browserManager.routingRules.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No routing rules yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Create a rule like *.github.com → Arc.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button("Add Rule") {
                        showingAddRuleSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.emptyRules.addRuleButton")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if hasRuleSearchQuery {
                        ForEach(filteredRoutingRules) { rule in
                            ruleRow(rule, hasSearchQuery: true)
                        }
                        .onDelete(perform: removeFilteredRules)
                    } else {
                        ForEach(browserManager.routingRules) { rule in
                            ruleRow(rule, hasSearchQuery: false)
                        }
                        .onMove { indices, destination in
                            browserManager.moveRoutingRules(from: indices, to: destination)
                        }
                        .onDelete { indices in
                            browserManager.removeRoutingRules(at: indices)
                        }
                    }
                }
                .id(UUID())
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .accessibilityIdentifier("settings.rulesList")
                .onChange(of: ruleSearchText) { updateFilteredRules() }
                .onChange(of: browserManager.routingRules) { updateFilteredRules() }
                .onAppear { updateFilteredRules() }
            }

            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
                Text(hasRuleSearchQuery
                     ? "Clear search to drag reorder rules. First enabled match opens directly in the selected browser."
                     : "Rules are evaluated top-to-bottom. First enabled match opens directly in the selected browser.")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .sheet(item: $ruleToEdit) { rule in
            EditRuleSheet(rule: rule, manager: browserManager, isPresented: Binding(
                get: { ruleToEdit != nil },
                set: { if !$0 { ruleToEdit = nil } }
            ))
        }
    }

    /// Creates a `RuleRowView` with all closure callbacks bound to `browserManager`.
    @ViewBuilder
    func ruleRow(_ rule: BrowserRoutingRule, hasSearchQuery: Bool) -> some View {
        let currentIndex = browserManager.routingRules.firstIndex(where: { $0.id == rule.id }) ?? 0
        let canMoveUp = currentIndex > 0
        let canMoveDown = currentIndex < browserManager.routingRules.count - 1
        
        RuleRowView(
            rule: rule,
            configuredBrowsers: browserManager.configuredBrowsers,
            hasSearchQuery: hasSearchQuery,
            onUpdate: { updated in
                browserManager.updateRoutingRule(updated)
            },
            onEdit: {
                ruleToEdit = rule
            },
            onDelete: { withAnimation(.easeInOut(duration: 0.2)) { browserManager.removeRoutingRule(id: rule.id) } },
            onDuplicate: { browserManager.duplicateRoutingRule(id: rule.id) },
            onMoveUp: {
                guard let index = browserManager.routingRules.firstIndex(where: { $0.id == rule.id }),
                      index > 0 else { return }
                browserManager.moveRoutingRules(from: IndexSet(integer: index), to: index - 1)
            },
            onMoveDown: {
                guard let index = browserManager.routingRules.firstIndex(where: { $0.id == rule.id }),
                      index < browserManager.routingRules.count - 1 else { return }
                browserManager.moveRoutingRules(from: IndexSet(integer: index), to: index + 2)
            },
            isValidHostPattern: { browserManager.isValidRoutingHostPattern($0) },
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown
        )
        .equatable()
        .id(rule.id)
    }

    func rulesStatusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    func exportRules() {
        let panel = NSSavePanel()
        panel.title = "Export Routing Rules"
        panel.nameFieldStringValue = "ChowserRules.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.exportRules(to: url)
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }

    func importRules() {
        let panel = NSOpenPanel()
        panel.title = "Import Routing Rules"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.importRules(from: url)
        } catch {
            print("Import failed: \(error.localizedDescription)")
        }
    }

    func removeFilteredRules(at offsets: IndexSet) {
        var idsToRemove: [UUID] = []
        for offset in offsets where filteredRoutingRules.indices.contains(offset) {
            idsToRemove.append(filteredRoutingRules[offset].id)
        }
        for id in idsToRemove {
            browserManager.removeRoutingRule(id: id)
        }
    }
}
