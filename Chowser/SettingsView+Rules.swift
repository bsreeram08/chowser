import SwiftUI
import UniformTypeIdentifiers

// MARK: - Rule Detail View (Master-Detail Panel)

struct RuleDetailView: View {
    let rule: BrowserRoutingRule
    let manager: BrowserManager
    let onUpdate: (BrowserRoutingRule) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    @State private var ruleName: String
    @State private var hostPattern: String
    @State private var pathPrefix: String
    @State private var selectedBrowserIdentity: String
    @State private var sourceAppBundleId: String?
    @State private var usePrivateMode: Bool
    @State private var useRegex: Bool
    @State private var isEnabled: Bool

    init(rule: BrowserRoutingRule, manager: BrowserManager, onUpdate: @escaping (BrowserRoutingRule) -> Void, onDelete: @escaping () -> Void, onDuplicate: @escaping () -> Void) {
        self.rule = rule
        self.manager = manager
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate

        self._ruleName = State(initialValue: rule.name)
        self._hostPattern = State(initialValue: rule.hostPattern)
        self._pathPrefix = State(initialValue: rule.pathPrefix ?? "")
        self._usePrivateMode = State(initialValue: rule.usePrivateMode)
        self._useRegex = State(initialValue: rule.useRegex)
        self._isEnabled = State(initialValue: rule.isEnabled)

        // Find existing identity or fallback to first
        let identity = "\(rule.browserBundleId)|\(rule.profile ?? "")"
        if manager.configuredBrowsers.contains(where: { $0.identity == identity }) {
            self._selectedBrowserIdentity = State(initialValue: identity)
        } else {
            self._selectedBrowserIdentity = State(initialValue: manager.configuredBrowsers.first?.identity ?? "")
        }

        self._sourceAppBundleId = State(initialValue: rule.sourceAppBundleId)
    }

    private var effectiveBrowserIdentity: String {
        if !selectedBrowserIdentity.isEmpty { return selectedBrowserIdentity }
        return manager.configuredBrowsers.first?.identity ?? ""
    }

    private var hostPatternIsValid: Bool {
        manager.isValidRoutingHostPattern(hostPattern, useRegex: useRegex)
    }

    private var canSaveRule: Bool {
        hostPatternIsValid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with rule name and status toggle
                detailHeader
                    .padding(20)

                Divider()

                // Main rule configuration
                VStack(alignment: .leading, spacing: 14) {
                    ruleNameSection
                    hostPatternSection
                    pathPrefixSection
                    browserPickerSection
                    sourceAppSection
                    privateModeSection
                }
                .padding(20)

                Divider()

                // Test URL section
                RuleTesterView(manager: manager)
                    .padding(20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rule Details")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    HStack(spacing: 8) {
                        Toggle("Enabled", isOn: $isEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onChange(of: isEnabled) { _, newValue in
                                commitChanges(isEnabled: newValue)
                            }

                        if isEnabled {
                            Text("Active")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12), in: Capsule())
                        } else {
                            Text("Disabled")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var ruleNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rule Name")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Work links", text: $ruleName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onChange(of: ruleName) { _, _ in commitChanges() }
        }
    }

    private var hostPatternSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Host Pattern")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Regex", isOn: $useRegex)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 10))
                    .onChange(of: useRegex) { _, _ in commitChanges() }
            }

            TextField(useRegex ? ".*\\.internal-dev\\.company\\.com" : "*, example.com, or *.example.com", text: $hostPattern)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .onChange(of: hostPattern) { _, _ in commitChanges() }

            if !hostPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hostPatternIsValid {
                Text(useRegex ? "Invalid regular expression" : "Host pattern must be *, example.com, or *.example.com")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
    }

    private var pathPrefixSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Path Prefix (Optional)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("/team", text: $pathPrefix)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .onChange(of: pathPrefix) { _, _ in commitChanges() }

            Text("Only match URLs with paths starting with this prefix")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var browserPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open In")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("Browser", selection: $selectedBrowserIdentity) {
                ForEach(manager.configuredBrowsers) { browser in
                    HStack {
                        if let icon = AppMetadataCache.shared.icon(for: browser.bundleId) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        }
                        Text(browser.name)
                    }
                    .tag(browser.identity)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedBrowserIdentity) { _, _ in commitChanges() }
        }
    }

    private var sourceAppSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source App (Optional)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if let bundleId = sourceAppBundleId,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable()
                        .frame(width: 16, height: 16)
                    let name = (Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? bundleId
                    Text(name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Button("Clear") { sourceAppBundleId = nil; commitChanges() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Any app")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Choose App…") { chooseSourceApp() }
                    .buttonStyle(.bordered)
            }

            Text("Only route links opened from this specific app.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var privateModeSection: some View {
        Toggle("Open in Private / Incognito", isOn: $usePrivateMode)
            .font(.system(size: 12))
            .onChange(of: usePrivateMode) { _, _ in commitChanges() }
    }

    private func chooseSourceApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.title = "Choose Source App"
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            sourceAppBundleId = Bundle(url: url)?.bundleIdentifier
            commitChanges()
        }
    }

    private func commitChanges(isEnabled: Bool? = nil) {
        guard let browser = manager.configuredBrowsers.first(where: { $0.identity == effectiveBrowserIdentity }) else { return }

        var updated = rule
        let pName = ruleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let pHost = hostPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let pPath = pathPrefix.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedHost = useRegex ? pHost : manager.normalizedRoutingHostPattern(pHost)

        updated.name = pName.isEmpty ? normalizedHost : pName
        updated.hostPattern = normalizedHost
        updated.pathPrefix = pPath.isEmpty ? nil : (pPath.hasPrefix("/") ? pPath : "/\(pPath)")
        updated.browserBundleId = browser.bundleId
        updated.profile = browser.profile
        updated.sourceAppBundleId = sourceAppBundleId
        updated.usePrivateMode = usePrivateMode
        updated.useRegex = useRegex
        if let isEnabled = isEnabled {
            updated.isEnabled = isEnabled
        }

        onUpdate(updated)
    }
}

// MARK: - Rule Grouping

struct RuleGroup: Identifiable {
    let id: String
    let name: String
    let icon: String
    let rules: [BrowserRoutingRule]
    var isExpanded: Bool = true
}

// MARK: - Rules View Mode

enum RulesViewMode: String, CaseIterable, Identifiable {
    case flat = "List"
    case grouped = "Grouped"
    case compact = "Compact"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .flat:
            return "list.bullet"
        case .grouped:
            return "square.grid.2x2"
        case .compact:
            return "list.dash"
        }
    }
}

extension SettingsView {

    /// Groups rules by target browser for collapsible sections
    var rulesByBrowser: [RuleGroup] {
        let grouped = Dictionary(grouping: browserManager.routingRules) { rule in
            rule.browserBundleId
        }
        
        return grouped.compactMap { (bundleId, rules) -> RuleGroup? in
            let browser = browserManager.configuredBrowsers.first { $0.bundleId == bundleId }
            let name = browser?.name ?? bundleId
            return RuleGroup(
                id: bundleId,
                name: name,
                icon: "globe",
                rules: rules.sorted { ($0.name) < ($1.name) }
            )
        }.sorted { $0.name < $1.name }
    }

    /// Groups rules by enabled/disabled status
    var rulesByStatus: [RuleGroup] {
        let enabled = browserManager.routingRules.filter { $0.isEnabled }
        let disabled = browserManager.routingRules.filter { !$0.isEnabled }
        
        return [
            RuleGroup(id: "enabled", name: "Active Rules", icon: "checkmark.circle.fill", rules: enabled),
            RuleGroup(id: "disabled", name: "Disabled Rules", icon: "circle.slash", rules: disabled)
        ]
    }

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

    var rulesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            rulesHeader

            if browserManager.configuredBrowsers.isEmpty {
                rulesEmptyState(showBrowserWarning: true)
            } else if browserManager.routingRules.isEmpty {
                rulesEmptyState(showBrowserWarning: false)
            } else {
                rulesMasterDetailView
            }
        }
        .sheet(item: $ruleToEdit) { rule in
            EditRuleSheet(rule: rule, manager: browserManager, isPresented: Binding(
                get: { ruleToEdit != nil },
                set: { if !$0 { ruleToEdit = nil } }
            ))
        }
    }

    private var rulesHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
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

                // View mode picker
                Picker("View", selection: $rulesViewMode) {
                    ForEach(RulesViewMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .help("Switch between list, grouped, and compact views")

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

            if !browserManager.configuredBrowsers.isEmpty && !browserManager.routingRules.isEmpty {
                sectionSearchField(
                    placeholder: "Filter rules by name, host, path, or browser",
                    text: $ruleSearchText,
                    accessibilityIdentifier: "settings.rule.searchField"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private func rulesEmptyState(showBrowserWarning: Bool) -> some View {
        VStack(spacing: 10) {
            if showBrowserWarning {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                Text("Add at least one browser first")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Routing rules need a target browser. Configure browsers in the Browsers tab.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rulesMasterDetailView: some View {
        // Use the selected view mode
        Group {
            switch rulesViewMode {
            case .flat, .compact:
                rulesListPanelWithDetail
            case .grouped:
                rulesGroupedView
            }
        }
    }

    private var rulesListPanelWithDetail: some View {
        NavigationSplitView {
            rulesListPanel
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    rulesFooter
                        .background(.bar)
                }
        } detail: {
            if let rule = selectedRule {
                RuleDetailView(
                    rule: rule,
                    manager: browserManager,
                    onUpdate: { updated in
                        browserManager.updateRoutingRule(updated)
                        selectedRule = updated
                    },
                    onDelete: {
                        browserManager.removeRoutingRule(id: rule.id)
                        selectedRule = nil
                    },
                    onDuplicate: {
                        browserManager.duplicateRoutingRule(id: rule.id)
                    }
                )
                .id(rule.id)
            } else {
                rulesPlaceholderView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ruleSearchText) { updateFilteredRules() }
        .onChange(of: browserManager.routingRules) { updateFilteredRules() }
        .onAppear { updateFilteredRules() }
    }

    private var rulesGroupedView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Group by enabled status
                ForEach(rulesByStatus) { group in
                    if !group.rules.isEmpty {
                        CollapsibleRuleGroup(
                            group: group,
                            isExpanded: expandedRuleGroups.contains(group.id),
                            configuredBrowsers: browserManager.configuredBrowsers,
                            onToggle: {
                                if expandedRuleGroups.contains(group.id) {
                                    expandedRuleGroups.remove(group.id)
                                } else {
                                    expandedRuleGroups.insert(group.id)
                                }
                            },
                            onUpdateRule: { updated in
                                browserManager.updateRoutingRule(updated)
                            },
                            onEditRule: { rule in
                                selectedRule = rule
                            },
                            onDeleteRule: { rule in
                                browserManager.removeRoutingRule(id: rule.id)
                            },
                            onDuplicateRule: { rule in
                                browserManager.duplicateRoutingRule(id: rule.id)
                            }
                        )
                    }
                }

                // Group by browser
                if !rulesByBrowser.isEmpty {
                    Divider()
                        .padding(.horizontal, 20)

                    Text("By Browser")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                    ForEach(rulesByBrowser) { group in
                        if !group.rules.isEmpty {
                            CollapsibleRuleGroup(
                                group: group,
                                isExpanded: expandedRuleGroups.contains(group.id),
                                configuredBrowsers: browserManager.configuredBrowsers,
                                onToggle: {
                                    if expandedRuleGroups.contains(group.id) {
                                        expandedRuleGroups.remove(group.id)
                                    } else {
                                        expandedRuleGroups.insert(group.id)
                                    }
                                },
                                onUpdateRule: { updated in
                                    browserManager.updateRoutingRule(updated)
                                },
                                onEditRule: { rule in
                                    selectedRule = rule
                                },
                                onDeleteRule: { rule in
                                    browserManager.removeRoutingRule(id: rule.id)
                                },
                                onDuplicateRule: { rule in
                                    browserManager.duplicateRoutingRule(id: rule.id)
                                }
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var rulesListPanel: some View {
        List(selection: $selectedRule) {
            if hasRuleSearchQuery {
                ForEach(filteredRoutingRules) { rule in
                    ruleCompactRow(rule)
                        .tag(rule)
                }
                .onDelete(perform: removeFilteredRules)
            } else {
                ForEach(browserManager.routingRules) { rule in
                    ruleCompactRow(rule)
                        .tag(rule)
                }
                .onMove { indices, destination in
                    browserManager.moveRoutingRules(from: indices, to: destination)
                }
                .onDelete { indices in
                    browserManager.removeRoutingRules(at: indices)
                }
            }
        }
        .listStyle(.inset)
        .accessibilityIdentifier("settings.rulesList")
        .frame(minWidth: 260, maxWidth: 340)
    }

    private func ruleCompactRow(_ rule: BrowserRoutingRule) -> some View {
        let targetBrowserName: String = {
            let identity = "\(rule.browserBundleId)|\(rule.profile ?? "")"
            return browserManager.configuredBrowsers.first(where: { $0.identity == identity })?.name ?? rule.browserBundleId
        }()

        return HStack(spacing: 10) {
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
                Text(rule.hostPattern)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Text(targetBrowserName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private var rulesPlaceholderView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 32))
                    .foregroundStyle(.quaternary)
                Text("Select a rule to view details")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Click any rule in the list to edit it")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            RuleTesterView(manager: browserManager)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var rulesFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: hasRuleSearchQuery ? "magnifyingglass" : "arrow.up.arrow.down")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
            Text(hasRuleSearchQuery
                 ? "Clear search to drag and reorder rules."
                 : "Drag to reorder · First enabled match wins.")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            densityPreference: browserManager.densityPreference,
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

struct RuleTesterView: View {
    var manager: BrowserManager
    @State private var testURLText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Test a Link")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            TextField("Paste a URL here...", text: $testURLText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
            
            if !testURLText.isEmpty {
                let cleaned = testURLText.trimmingCharacters(in: .whitespacesAndNewlines)
                // Add https schema if it's just a raw domain or path for easier testing
                let urlString = cleaned.contains("://") ? cleaned : "https://\(cleaned)"
                
                if let url = URL(string: urlString), url.host != nil {
                    if let route = manager.resolvedRoute(for: url) {
                        let browserName = route.browser.name + (route.browser.profile != nil ? " (\(route.browser.profile!))" : "")
                        if let rule = route.rule {
                            Text("Opens in **\(browserName)** (Matches rule: '\(rule.name)')")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                        } else {
                            Text("Opens in **\(browserName)** (Temporary Focus Mode)")
                                .font(.system(size: 11))
                                .foregroundStyle(.purple)
                        }
                    } else if !manager.configuredBrowsers.isEmpty {
                        Text("No rules match. Choose from the browsers picker.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Waiting for a valid URL...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}


