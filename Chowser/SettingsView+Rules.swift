import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

extension SettingsView {
    var rulesSection: some View {
        RulesSettingsPage(
            manager: browserManager,
            model: rulesEditor,
            createRequested: $showingAddRuleSheet,
            prefillURL: $currentPrefillURL,
            preselectedBrowserIdentity: $preselectedRuleBrowserIdentity,
            showingRuleMergeReview: $showingRuleMergeReview,
            onExport: exportRules,
            onImport: importRules
        )
    }

    func exportRules() {
        let panel = NSSavePanel()
        panel.title = "Export Routing Rules"
        panel.nameFieldStringValue = "ChowserRules.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.exportRules(to: url)
            presentSettingsMessage("Export complete", "Rules exported to \(url.lastPathComponent).")
        } catch {
            presentSettingsMessage("Export failed", "Could not export rules.\n\n\(error.localizedDescription)")
        }
    }

    func importRules() {
        let panel = NSOpenPanel()
        panel.title = "Import Routing Rules"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let summary = try browserManager.importRules(
                from: url,
                skipExisting: browserManager.skipExistingImportedRules
            )
            presentImportSummary(for: "Rules", summary: summary, successTitle: "Rules import complete")
        } catch {
            presentSettingsMessage("Import failed", "Could not import rules.\n\n\(error.localizedDescription)")
        }
    }
}

// MARK: - Page

/// Settings ▸ Rules: fallback policy, a priority-ordered rules table with drag to
/// reorder, an inspector for the selected rule, and a "Test a Link" popover.
struct RulesSettingsPage: View {
    let manager: BrowserManager
    @Bindable var model: RulesEditorModel
    /// Set by SettingsView when another part of the app asks to create a rule
    /// (e.g. the menu's "Create Rule for Link"). Consumed by inserting a new rule.
    @Binding var createRequested: Bool
    @Binding var prefillURL: URL?
    @Binding var preselectedBrowserIdentity: String?
    @Binding var showingRuleMergeReview: Bool
    let onExport: () -> Void
    let onImport: () -> Void

    @Environment(\.undoManager) private var undoManager
    @State private var showingTester = false

    var body: some View {
        SettingsDetailScaffold(
            title: "Rules",
            subtitle: "Route matching links directly to the right browser.",
            systemImage: "point.topleft.down.curvedto.point.bottomright.up",
            scrollsContent: false,
            actions: { headerActions },
            content: { pageContent }
        )
        .inspector(isPresented: inspectorPresented) {
            inspectorContent
                .inspectorColumnWidth(min: 280, ideal: 310, max: 420)
        }
        .onAppear(perform: consumeCreateRequest)
        .onChange(of: createRequested) { consumeCreateRequest() }
        .accessibilityIdentifier("settings.rulesSection")
    }

    // MARK: Header actions

    private var headerActions: some View {
        HStack(spacing: 8) {
            Menu {
                Button("Export Rules…", systemImage: "square.and.arrow.up", action: onExport)
                    .disabled(manager.routingRules.isEmpty)
                Button("Import Rules…", systemImage: "square.and.arrow.down", action: onImport)
            } label: {
                Label("Rule Actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Import or export rules")
            .accessibilityLabel("Rule Actions")
            .accessibilityIdentifier("settings.rulesMenuButton")

            Button("Set Up with AI", systemImage: "sparkles") { AISetup.run() }
                .help("Copy a prompt that lets an AI assistant write your rules")
                .accessibilityIdentifier("settings.aiSetupButton")

            Button("Test a Link", systemImage: "checkmark.circle") { showingTester.toggle() }
                .help("Check which rule a link matches")
                .accessibilityIdentifier("settings.rules.testButton")
                .popover(isPresented: $showingTester, arrowEdge: .bottom) {
                    RuleTesterPopover(model: model, sourceAppOptions: testerSourceAppOptions)
                }

            Button("Add Rule", systemImage: "plus", action: addRule)
                .labelStyle(.iconOnly)
                .help("Add Rule")
                .accessibilityIdentifier("settings.addRuleButton")
        }
        .controlSize(.regular)
    }

    // MARK: Content

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !manager.pendingRuleMergeSuggestions.isEmpty {
                mergeSuggestionBanner
            }

            fallbackGroup

            VStack(spacing: 0) {
                rulesTable
                tableFooter
            }

            Text("Rules are checked top to bottom; the first match wins. Drag a rule to change its priority.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }

    private var mergeSuggestionBanner: some View {
        let count = manager.pendingRuleMergeSuggestions.count
        return GroupBox {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "arrow.triangle.merge")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) rule merge\(count == 1 ? "" : "s") suggested")
                        .font(.headline)
                    Text("These rules differ only by source app and route to the same browser.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Review") { showingRuleMergeReview = true }
                    .accessibilityIdentifier("settings.rules.reviewMergeSuggestionsButton")
            }
            .padding(4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.rules.mergeSuggestionBanner")
    }

    // MARK: Fallback

    private enum FallbackChoice: Hashable {
        case picker
        case browser(UUID)
        case unavailable
    }

    private var fallbackGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("When no rule matches") {
                    Picker("When no rule matches", selection: fallbackChoice) {
                        Text("Show the picker").tag(FallbackChoice.picker)
                        if !manager.configuredBrowsers.isEmpty {
                            Divider()
                            ForEach(manager.configuredBrowsers) { browser in
                                Text("Open in \(browser.profileQualifiedName)").tag(FallbackChoice.browser(browser.id))
                            }
                        }
                        if fallbackChoice.wrappedValue == .unavailable {
                            Text("Missing browser").tag(FallbackChoice.unavailable)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("settings.rules.fallbackPicker")
                }

                if fallbackBrowserUnavailable {
                    Label("The fallback browser isn’t available, so Chowser shows the picker until you choose another.", systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.rules.fallbackBrowserMissingNote")
                }
            }
            .padding(4)
        }
    }

    private var fallbackChoice: Binding<FallbackChoice> {
        Binding(
            get: {
                let policy = manager.fallbackPolicy
                guard policy.mode == .browser else { return .picker }
                guard let id = policy.browserID, manager.configuredBrowsers.contains(where: { $0.id == id }) else {
                    return .unavailable
                }
                return .browser(id)
            },
            set: { choice in
                switch choice {
                case .picker:
                    manager.fallbackPolicy.mode = .picker
                case .browser(let id):
                    let profile = manager.configuredBrowsers.first(where: { $0.id == id })?.profile
                    manager.fallbackPolicy = BrowserFallbackPolicy(mode: .browser, browserID: id, profile: profile)
                case .unavailable:
                    break
                }
            }
        )
    }

    /// Mirrors `BrowserManager.fallbackRoute()`: a browser fallback that can't be used
    /// (deleted, disabled, or hidden) silently reverts to the picker at runtime.
    private var fallbackBrowserUnavailable: Bool {
        guard manager.fallbackPolicy.mode == .browser else { return false }
        return manager.fallbackRoute() == nil
    }

    // MARK: Table

    private var rulesTable: some View {
        let rows = model.rows
        let matchedID = showingTester ? model.testOutcome().matchedRuleID : nil

        return Table(of: RulesEditorModel.Row.self, selection: $model.selection) {
            TableColumn("#") { row in
                Text("\(row.position)")
                    .monospacedDigit()
                    .fontWeight(row.id == matchedID ? .semibold : .regular)
                    .foregroundStyle(row.id == matchedID ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .help("Priority \(row.position). Drag to reorder.")
                    .accessibilityLabel(row.id == matchedID ? "Priority \(row.position), matches the tested link" : "Priority \(row.position)")
            }
            .width(min: 22, ideal: 26, max: 40)

            TableColumn("On") { row in
                Toggle("Enabled", isOn: Binding(
                    get: { row.rule.isEnabled },
                    set: { model.setEnabled(row.id, $0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel("Enable rule \(row.position)")
                .accessibilityIdentifier("settings.rule.enabledToggle")
            }
            .width(26)

            TableColumn("Link matches") { row in
                linkCell(row)
            }
            .width(min: 110, ideal: 190)

            TableColumn("From app") { row in
                Text(sourceSummary(row.rule))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(row.rule.sourceAppBundleIDs.isEmpty || !row.rule.isEnabled ? .secondary : .primary)
                    .help(sourceSummary(row.rule))
            }
            .width(min: 50, ideal: 90)

            TableColumn("Opens in") { row in
                opensInCell(row)
            }
            .width(min: 80, ideal: 130)

            TableColumn("") { row in
                if row.rule.usePrivateMode {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .help("Opens privately")
                        .accessibilityLabel("Opens privately")
                }
            }
            .width(14)
        } rows: {
            ForEach(rows) { row in
                TableRow(row)
                    .draggable(RuleDragPayload.string(for: row.id))
            }
            .dropDestination(for: String.self) { index, items in
                let ids = items.compactMap(RuleDragPayload.id(from:))
                guard !ids.isEmpty else { return }
                model.move(ids: ids, toDisplayIndex: index)
            }
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first {
                Button("Duplicate") { manager.duplicateRoutingRule(id: id) }
                    .disabled(model.isUnsaved(id))
                Divider()
                Button("Delete Rule") { model.delete(id, undoManager: undoManager) }
            }
        }
        .onDeleteCommand(perform: deleteSelection)
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("No Rules", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                } description: {
                    Text("Add a rule to send matching links straight to a browser.")
                } actions: {
                    Button("Add Rule", action: addRule)
                        .accessibilityIdentifier("settings.rules.emptyAddButton")
                }
            }
        }
        .accessibilityLabel("Rules, in priority order")
        .accessibilityIdentifier("settings.rules.table")
    }

    private func linkCell(_ row: RulesEditorModel.Row) -> some View {
        let host = row.rule.hostPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = (row.rule.pathPrefix ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let issueMessage = row.issue.map { RoutingRuleMessages.message(for: $0, rule: row.rule) }

        return HStack(spacing: 4) {
            if let issueMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .help(issueMessage)
                    .accessibilityLabel("Needs attention: \(issueMessage)")
            }
            if host.isEmpty {
                Text("No link yet")
                    .foregroundStyle(.secondary)
            } else {
                (Text(host) + (path.isEmpty ? Text("") : Text(" · \(path)").foregroundStyle(.secondary)))
                    .foregroundStyle(row.rule.isEnabled ? .primary : .secondary)
            }
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .help(row.rule.name.isEmpty || row.rule.name == row.rule.hostPattern ? (issueMessage ?? host) : row.rule.name)
    }

    @ViewBuilder
    private func opensInCell(_ row: RulesEditorModel.Row) -> some View {
        if let browser = browser(for: row.rule) {
            HStack(spacing: 6) {
                CachedAppIcon(bundleId: browser.bundleId, size: 16)
                Text(browser.profileQualifiedName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(row.rule.isEnabled ? .primary : .secondary)
            }
        } else {
            Label("Missing browser", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    private var tableFooter: some View {
        HStack(spacing: 0) {
            Button(action: addRule) {
                Image(systemName: "plus")
                    .frame(width: 24, height: 20)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Add Rule")
            .help("Add Rule")
            .accessibilityIdentifier("settings.rules.footerAddButton")

            Divider()
                .frame(height: 14)

            Button(action: deleteSelection) {
                Image(systemName: "minus")
                    .frame(width: 24, height: 20)
                    .contentShape(Rectangle())
            }
            .disabled(model.selection == nil)
            .accessibilityLabel("Delete Selected Rule")
            .help("Delete Selected Rule")
            .accessibilityIdentifier("settings.rules.footerRemoveButton")

            Spacer()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .top) { Divider() }
        .overlay {
            Rectangle()
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                .padding(.top, -1)
                .allowsHitTesting(false)
        }
    }

    // MARK: Inspector

    private var inspectorPresented: Binding<Bool> {
        Binding(
            get: {
                guard let id = model.selection else { return false }
                return model.editableRule(for: id) != nil
            },
            set: { isPresented in
                if !isPresented { model.selection = nil }
            }
        )
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let id = model.selection, model.editableRule(for: id) != nil {
            RuleInspector(
                model: model,
                manager: manager,
                ruleID: id,
                onDelete: { model.delete(id, undoManager: undoManager) }
            )
            .id(id)
        } else {
            Text("Select a rule to edit it.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Actions

    private func addRule() {
        model.addRule()
    }

    private func deleteSelection() {
        guard let id = model.selection else { return }
        model.delete(id, undoManager: undoManager)
    }

    private func consumeCreateRequest() {
        guard createRequested else { return }
        let host = prefillURL?.host
        model.addRule(prefillHost: host, browserIdentity: preselectedBrowserIdentity)
        createRequested = false
    }

    // MARK: Helpers

    private func browser(for rule: BrowserRoutingRule) -> BrowserConfig? {
        manager.configuredBrowsers.first { $0.bundleId == rule.browserBundleId && $0.profile == rule.profile }
    }

    private func sourceSummary(_ rule: BrowserRoutingRule) -> String {
        rule.sourceAppBundleIDs.isEmpty
            ? "Any"
            : rule.sourceAppBundleIDs.map { appDisplayName(forBundleID: $0) }.joined(separator: ", ")
    }

    /// Apps used by any rule first (most relevant to testing), then running apps.
    private var testerSourceAppOptions: [String] {
        var seen = Set<String>()
        var options: [String] = []
        for id in manager.routingRules.flatMap(\.sourceAppBundleIDs) where seen.insert(id).inserted {
            options.append(id)
        }
        let ownID = Bundle.main.bundleIdentifier
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { $0 != ownID }
            .sorted { appDisplayName(forBundleID: $0).localizedStandardCompare(appDisplayName(forBundleID: $1)) == .orderedAscending }
        for id in running where seen.insert(id).inserted {
            options.append(id)
        }
        if let selected = model.testSourceApp, seen.insert(selected).inserted {
            options.append(selected)
        }
        return options
    }
}

/// Drag payload for reordering rules. A prefixed plain string keeps drops from other
/// apps (arbitrary text) from being mistaken for a rule.
enum RuleDragPayload {
    nonisolated static let prefix = "chowser-rule:"

    nonisolated static func string(for id: UUID) -> String {
        prefix + id.uuidString
    }

    nonisolated static func id(from string: String) -> UUID? {
        guard string.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(string.dropFirst(prefix.count)))
    }
}

// MARK: - Inspector

private struct RuleInspector: View {
    @Bindable var model: RulesEditorModel
    let manager: BrowserManager
    let ruleID: UUID
    let onDelete: () -> Void

    @FocusState private var focus: RuleEditorField?
    @State private var showsAdvanced = false

    var body: some View {
        let rule = model.editableRule(for: ruleID) ?? BrowserRoutingRule(name: "", hostPattern: "", browserBundleId: "")
        let error = model.validationError(for: rule)
        let errorField = error.flatMap(RoutingRuleMessages.field(for:))
        let errorMessage = error.map { RoutingRuleMessages.message(for: $0, rule: rule) }
        let position = model.rows.first(where: { $0.id == ruleID })?.position ?? 0

        Form {
            Section {
                labeledField("Name", optional: true) {
                    TextField("Name", text: binding(\.name), prompt: Text(rule.hostPattern.isEmpty ? "Untitled rule" : rule.hostPattern))
                        .focused($focus, equals: .name)
                        .accessibilityIdentifier("settings.rule.nameField")
                }

                labeledField("Link matches") {
                    TextField("Link matches", text: binding(\.hostPattern), prompt: Text(rule.useRegex ? "^(www\\.)?github\\.com$" : "github.com"))
                        .font(rule.useRegex ? .body.monospaced() : .body)
                        .focused($focus, equals: .pattern)
                        .accessibilityIdentifier("settings.rule.hostField")
                    if errorField == .pattern, let errorMessage {
                        errorText(errorMessage, identifier: "settings.rule.hostError")
                    } else if !rule.useRegex, let ignoredPath = RoutingRuleMessages.ignoredPathInPattern(rule.hostPattern) {
                        hintText("Only the domain is matched here. To match “\(ignoredPath)”, put it in Path starts with.")
                    }
                    hintText(rule.useRegex
                        ? "Matched against the whole host name, like www.github.com."
                        : "Examples: github.com, *.slack.com. Separate several with commas.")
                }

                labeledField("Path starts with", optional: true) {
                    TextField("Path starts with", text: pathBinding, prompt: Text("/acme"))
                        .focused($focus, equals: .path)
                        .accessibilityIdentifier("settings.rule.pathField")
                    if errorField == .path, let errorMessage {
                        errorText(errorMessage, identifier: "settings.rule.pathError")
                    }
                }
            } header: {
                HStack {
                    Text("Rule \(position)")
                    if model.isUnsaved(ruleID) {
                        Text("Not saved yet")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("From App") {
                SourceAppTokenList(bundleIDs: rule.sourceAppBundleIDs) { newValue in
                    model.update(ruleID) { $0.sourceAppBundleIDs = newValue }
                    model.endEditing(ruleID, discardBlank: false)
                }
                .accessibilityIdentifier("settings.rule.sourceApps")
                if errorField == .sourceApps, let errorMessage {
                    errorText(errorMessage, identifier: "settings.rule.sourceAppsError")
                }
                hintText("Leave empty to match links clicked in any app.")
            }

            Section {
                Picker("Opens in", selection: browserBinding(rule)) {
                    ForEach(manager.configuredBrowsers) { browser in
                        Text(browser.profileQualifiedName).tag(browser.identity)
                    }
                    if !manager.configuredBrowsers.contains(where: { $0.identity == rule.routeIdentity }) {
                        Text(manager.configuredBrowsers.isEmpty ? "No browsers configured" : "Missing browser")
                            .tag(rule.routeIdentity)
                    }
                }
                .accessibilityIdentifier("settings.rule.browserPicker")
                if errorField == .browser, let errorMessage {
                    errorText(errorMessage, identifier: "settings.rule.browserError")
                }

                Toggle("Open privately", isOn: Binding(
                    get: { BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild && rule.usePrivateMode },
                    set: { newValue in
                        model.update(ruleID) { $0.usePrivateMode = newValue }
                        model.endEditing(ruleID, discardBlank: false)
                    }
                ))
                .disabled(!BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)
                .accessibilityIdentifier("settings.rule.privateToggle")
                if !BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
                    hintText("Private windows aren’t available in the App Store version.")
                }
            }

            Section {
                DisclosureGroup("Advanced", isExpanded: $showsAdvanced) {
                    Toggle("Use regular expression", isOn: Binding(
                        get: { rule.useRegex },
                        set: { newValue in model.update(ruleID) { $0.useRegex = newValue } }
                    ))
                    .accessibilityIdentifier("settings.rule.regexToggle")
                    hintText("For patterns a domain can’t express. The expression must match the entire host name.")
                }
                .accessibilityIdentifier("settings.rule.advancedDisclosure")
            }

            if model.hasUnsavedInvalidEdits(ruleID) {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text("These changes aren’t saved until the error is fixed.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Revert") { model.revert(ruleID) }
                            .help("Discard these changes and go back to the last saved version")
                            .accessibilityIdentifier("settings.rule.revertButton")
                    }
                }
            }

            Section {
                Button("Delete Rule", role: .destructive, action: onDelete)
                    .accessibilityIdentifier("settings.rule.deleteButton")
            }
        }
        .formStyle(.grouped)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("settings.rules.inspector")
        .onAppear {
            showsAdvanced = rule.useRegex
            applyFocusRequest()
        }
        .onChange(of: model.focusPatternRequest) { applyFocusRequest() }
        .onChange(of: focus) { oldValue, newValue in
            guard oldValue != nil, oldValue != newValue else { return }
            model.endEditing(ruleID, discardBlank: false)
        }
    }

    // MARK: Bindings

    private func binding(_ keyPath: WritableKeyPath<BrowserRoutingRule, String>) -> Binding<String> {
        Binding(
            get: { model.editableRule(for: ruleID)?[keyPath: keyPath] ?? "" },
            set: { newValue in model.update(ruleID) { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var pathBinding: Binding<String> {
        Binding(
            get: { model.editableRule(for: ruleID)?.pathPrefix ?? "" },
            set: { newValue in model.update(ruleID) { $0.pathPrefix = newValue.isEmpty ? nil : newValue } }
        )
    }

    private func browserBinding(_ rule: BrowserRoutingRule) -> Binding<String> {
        Binding(
            get: { model.editableRule(for: ruleID)?.routeIdentity ?? rule.routeIdentity },
            set: { identity in
                guard let browser = manager.configuredBrowsers.first(where: { $0.identity == identity }) else { return }
                model.update(ruleID) {
                    $0.browserBundleId = browser.bundleId
                    $0.profile = browser.profile
                }
                model.endEditing(ruleID, discardBlank: false)
            }
        )
    }

    private func applyFocusRequest() {
        guard model.focusPatternRequest == ruleID else { return }
        model.focusPatternRequest = nil
        // Defer one runloop turn so the field exists in the window before focusing it.
        DispatchQueue.main.async { focus = .pattern }
    }

    // MARK: Building blocks

    private func labeledField<Field: View>(_ title: String, optional: Bool = false, @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                if optional {
                    Text("(optional)")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            field()
                .labelsHidden()
        }
    }

    private func errorText(_ message: String, identifier: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }

    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension BrowserRoutingRule {
    /// Matches `BrowserConfig.identity` for the browser/profile this rule opens.
    var routeIdentity: String {
        "\(browserBundleId)|\(profile ?? "")"
    }
}
