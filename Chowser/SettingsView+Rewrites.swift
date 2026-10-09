import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

extension SettingsView {
    var filteredRewriteRules: [URLRewriteRule] {
        let query = rewriteSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return browserManager.rewriteRules }
        return browserManager.rewriteRules.filter { rule in
            rule.name.localizedStandardContains(query) || rule.match.hostPattern.localizedStandardContains(query)
        }
    }

    var rewritesSection: some View {
        SettingsDetailScaffold(
            title: "Rewrites",
            subtitle: "Transform URLs before routing rules are evaluated.",
            systemImage: "arrow.triangle.2.circlepath",
            actions: {
                HStack(spacing: 8) {
                    Menu {
                        Button(action: exportRewrites) {
                            Label("Export Rewrites…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(browserManager.rewriteRules.isEmpty)

                        Button(action: importRewrites) {
                            Label("Import Rewrites…", systemImage: "square.and.arrow.down")
                        }

                        Divider()

                        Button(action: checkForRewriteCatalogUpdates) {
                            Label("Check for Predefined Rewrites…", systemImage: "sparkle.magnifyingglass")
                        }
                        .disabled(isCheckingRewriteCatalog)
                        .accessibilityIdentifier("settings.checkRewriteCatalogButton")
                    } label: {
                        Label("Rewrite Actions", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityIdentifier("settings.rewritesMenuButton")

                    Button("Add Rewrite", systemImage: "plus") {
                        showingAddRewriteSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.addRewriteButton")
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        sectionSearchField(
                            placeholder: "Filter rewrites by name or host",
                            text: $rewriteSearchText,
                            accessibilityIdentifier: "settings.rewrite.searchField"
                        )

                        Text("\(browserManager.rewriteRules.filter(\.isEnabled).count) enabled")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    rewritesListContent

                    SettingsRewriteTester(manager: browserManager)
                }
            }
        )
        .accessibilityIdentifier("settings.rewritesSection")
    }

    @ViewBuilder
    private var rewritesListContent: some View {
        if browserManager.rewriteRules.isEmpty {
            SettingsEmptyContent(
                systemImage: "arrow.triangle.2.circlepath",
                title: "No rewrites yet",
                message: "Rewrites clean up or redirect a URL before routing rules run.",
                actionTitle: "Strip Tracking Parameters"
            ) {
                addStripTrackingParametersExample()
            }
        } else if filteredRewriteRules.isEmpty {
            SettingsEmptyContent(
                systemImage: "magnifyingglass",
                title: "No matching rewrites",
                message: "Clear the filter to show all rewrite rules."
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(filteredRewriteRules.enumerated()), id: \.element.id) { index, rule in
                    SettingsRewriteRow(
                        rule: rule,
                        skipReason: browserManager.rewriteSkipReasons[rule.id],
                        canMoveUp: index > 0,
                        canMoveDown: index < filteredRewriteRules.count - 1,
                        onUpdate: { updated in
                            _ = browserManager.updateRewriteRule(updated)
                        },
                        onDuplicate: { browserManager.duplicateRewriteRule(id: rule.id) },
                        onDelete: { browserManager.removeRewriteRule(id: rule.id) },
                        onMoveUp: { browserManager.moveRewriteRule(id: rule.id, offsetBy: -1) },
                        onMoveDown: { browserManager.moveRewriteRule(id: rule.id, offsetBy: 1) }
                    )
                    .id(rule.id)
                }
            }
        }
    }

    /// One-click concrete example for the empty state (design review: "not a bare 'No
    /// items found'").
    private func addStripTrackingParametersExample() {
        let match = URLRewriteMatch(hostPattern: "*")
        let rule = URLRewriteRule(
            name: "Strip tracking parameters",
            match: match,
            actions: [.stripQueryParameterPrefixes(["utm_"]), .stripQueryParameters(["fbclid", "gclid"])]
        )
        _ = browserManager.addRewriteRule(rule)
    }

    func exportRewrites() {
        let panel = NSSavePanel()
        panel.title = "Export Rewrite Rules"
        panel.nameFieldStringValue = "ChowserRewrites.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.exportRewrites(to: url)
            presentSettingsMessage("Export complete", "Rewrites exported to \(url.lastPathComponent).")
        } catch {
            presentSettingsMessage("Export failed", "Could not export rewrites.\n\n\(error.localizedDescription)")
        }
    }

    func importRewrites() {
        let panel = NSOpenPanel()
        panel.title = "Import Rewrite Rules"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let summary = try browserManager.importRewrites(
                from: url,
                skipExisting: browserManager.skipExistingImportedRules
            )
            presentImportSummary(for: "Rewrites", summary: summary, successTitle: "Rewrites import complete")
        } catch {
            presentSettingsMessage("Import failed", "Could not import rewrites.\n\n\(error.localizedDescription)")
        }
    }
}

/// Inline-editable row with local `@State` and commit-on-blur — the same pattern
/// `SettingsRuleRow` (routing rules) already uses, per design review: rewrite rows are
/// "structurally the same kind of row" as routing rules, not a separate modal-edit flow.
private struct SettingsRewriteRow: View {
    // Action-field focus (replaceHost/stripNames/stripPrefixes/setName/setValue) is now
    // tracked inside `RewriteActionFieldsView` itself, not here — see its own `ActionField`
    // enum. Those cases used to live in this enum but were never wired to a `.focused()`
    // modifier, so blur never committed an action-field edit (found in Codex PR review).
    enum FocusedField: Hashable {
        case name, host, path
    }

    let rule: URLRewriteRule
    let skipReason: String?
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onUpdate: (URLRewriteRule) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var draft: URLRewriteRule
    @State private var schemeFilter: RewriteSchemeFilter
    @State private var actionFields: RewriteActionFieldsState
    @State private var excludeHostPatternsText: String
    @FocusState private var focusedField: FocusedField?

    init(
        rule: URLRewriteRule,
        skipReason: String?,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onUpdate: @escaping (URLRewriteRule) -> Void,
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void
    ) {
        self.rule = rule
        self.skipReason = skipReason
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onUpdate = onUpdate
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self._draft = State(initialValue: rule)
        self._schemeFilter = State(initialValue: RewriteSchemeFilter(schemes: rule.match.schemes))
        self._actionFields = State(initialValue: RewriteActionFieldsState.derive(from: rule.actions))
        self._excludeHostPatternsText = State(initialValue: rule.match.excludeHostPatterns.joined(separator: ", "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(draft.isEnabled ? Color.accentColor : .secondary)

                TextField("Rewrite name", text: $draft.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .focused($focusedField, equals: .name)
                    .onSubmit(commit)
                    .accessibilityIdentifier("settings.rewrite.nameField")

                if draft.match.useRegex {
                    Text("REGEX")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                }

                Spacer()

                // Keyboard-accessible reordering alternative to drag-and-drop (design review).
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)
                .accessibilityLabel("Move up")
                .accessibilityIdentifier("settings.rewrite.moveUpButton")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
                .accessibilityLabel("Move down")
                .accessibilityIdentifier("settings.rewrite.moveDownButton")

                Toggle("Enabled", isOn: Binding(get: { draft.isEnabled }, set: { draft.isEnabled = $0; commit() }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Host")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("*.example.com", text: $draft.match.hostPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .focused($focusedField, equals: .host)
                        .onSubmit(commit)
                        .accessibilityIdentifier("settings.rewrite.hostField")
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Path")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Button(draft.match.pathPrefix == nil ? "Add" : "Remove") {
                            draft.match.pathPrefix = draft.match.pathPrefix == nil ? "/" : nil
                            commit()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                    }
                    TextField("/", text: Binding(
                        get: { draft.match.pathPrefix ?? "" },
                        set: { draft.match.pathPrefix = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($focusedField, equals: .path)
                    .onSubmit(commit)
                    .disabled(draft.match.pathPrefix == nil)
                    .opacity(draft.match.pathPrefix == nil ? 0.45 : 1)
                }
            }

            HStack(spacing: 14) {
                Toggle("Regex", isOn: Binding(get: { draft.match.useRegex }, set: { draft.match.useRegex = $0; commit() }))
                    .toggleStyle(.checkbox)

                Picker("Scheme", selection: Binding(
                    get: { schemeFilter },
                    set: { schemeFilter = $0; draft.match.schemes = $0.schemes; commit() }
                )) {
                    ForEach(RewriteSchemeFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 180)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Source Apps")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                SourceAppChipsView(bundleIDs: $draft.match.sourceAppBundleIDs, onCommit: commit)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Exclude Hosts")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("localhost.dev, 127.0.0.1, *.local", text: $excludeHostPatternsText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit(commit)
                    .accessibilityIdentifier("settings.rewrite.excludeHostsField")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Actions")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                RewriteActionFieldsView(fields: $actionFields, onCommit: commit)
            }

            // Last-skip-reason badge (FR-024) — visible on the row without opening a tester.
            if let skipReason {
                Text("Skipped: \(skipReason)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .accessibilityIdentifier("settings.rewrite.skipBadge")
            }

            HStack(spacing: 10) {
                Button("Duplicate", systemImage: "doc.on.doc") { onDuplicate() }
                    .controlSize(.small)

                Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
                    .controlSize(.small)

                Spacer()
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(draft.isEnabled ? Color.accentColor.opacity(0.25) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .onChange(of: rule) { _, newValue in
            guard focusedField == nil else { return }
            draft = newValue
            schemeFilter = RewriteSchemeFilter(schemes: newValue.match.schemes)
            actionFields = RewriteActionFieldsState.derive(from: newValue.actions)
        }
        .onChange(of: focusedField) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            commit()
        }
    }

    private func commit() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = draft.match.hostPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let actions = actionFields.buildActions()

        guard !trimmedHost.isEmpty, !actions.isEmpty else {
            draft = rule
            schemeFilter = RewriteSchemeFilter(schemes: rule.match.schemes)
            actionFields = RewriteActionFieldsState.derive(from: rule.actions)
            return
        }

        draft.name = trimmedName.isEmpty ? trimmedHost : trimmedName
        draft.match.hostPattern = trimmedHost
        draft.actions = actions
        draft.match.excludeHostPatterns = excludeHostPatternsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard draft != rule else { return }
        onUpdate(draft)
    }
}

/// FR-025: invokes the exact same `RewritePipeline.apply` function used at runtime — no
/// separate interpreter. FR-021: shows one step per rule that actually fired, not a
/// collapsed summary.
private struct SettingsRewriteTester: View {
    let manager: BrowserManager
    @State private var urlString = ""
    @State private var sourceAppBundleId = ""

    var body: some View {
        SettingsGroup("Rewrite Tester", subtitle: "See exactly which rewrite rules fire, in order, before a link is routed.") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("https://example.com/docs?utm_source=x", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .accessibilityIdentifier("settings.rewriteTester.urlField")

                TextField("Source app bundle ID (optional)", text: $sourceAppBundleId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .accessibilityIdentifier("settings.rewriteTester.sourceAppField")

                testerResult
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var testerResult: some View {
        if urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("Enter a URL to see how rewrites would transform it.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else if let url = parsedURL {
            let trimmedSourceApp = sourceAppBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = RewritePipeline.apply(url: url, rules: manager.rewriteRules, sourceApp: trimmedSourceApp.isEmpty ? nil : trimmedSourceApp)

            if result.steps.isEmpty {
                Label("No rewrite rules match this URL.", systemImage: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.steps) { step in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: step.skipped ? "exclamationmark.triangle.fill" : "arrow.right.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(step.skipped ? .orange : .green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.ruleName)
                                    .font(.system(size: 11, weight: .semibold))
                                if step.skipped {
                                    Text(step.skipReason ?? "Skipped")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.orange)
                                } else {
                                    Text("\(step.beforeURL.absoluteString) → \(step.afterURL.absoluteString)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }

                    Divider()

                    Label("Final URL: \(result.finalURL.absoluteString)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                        .textSelection(.enabled)
                }
            }
        } else {
            Label("Enter a valid URL.", systemImage: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
        }
    }

    private var parsedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), url.host != nil else { return nil }
        return url
    }
}

/// Explicit review surface for the signed rewrite catalog. Nothing starts selected; each
/// rule exposes its match scope, exact typed actions, and elevated-risk reasons before it
/// can be installed or updated.
struct RewriteCatalogSelectionSheet: View {
    let catalog: VerifiedRewriteCatalog
    let manager: BrowserManager
    @Binding var isPresented: Bool

    enum RuleStatus {
        case new, added, changed, conflict

        var label: String {
            switch self {
            case .new: return "New"
            case .added: return "Added"
            case .changed: return "Changed"
            case .conflict: return "Name conflict"
            }
        }

        var color: Color {
            switch self {
            case .new: return Color.accentColor
            case .added: return .secondary
            case .changed: return .orange
            case .conflict: return .red
            }
        }

        var icon: String {
            switch self {
            case .new: return "plus.circle"
            case .added: return "checkmark.circle.fill"
            case .changed: return "exclamationmark.arrow.triangle.2.circlepath"
            case .conflict: return "exclamationmark.triangle"
            }
        }
    }

    private struct Item: Identifiable {
        let id = UUID()
        let entry: RewriteCatalogEntry
        let status: RuleStatus
    }

    private var items: [Item] {
        catalog.catalog.rules.map { entry in
            let status: RuleStatus = switch catalog.status(for: entry, manager: manager) {
            case .new: .new
            case .added: .added
            case .changed: .changed
            case .conflict: .conflict
            }
            return Item(entry: entry, status: status)
        }
    }

    @State private var selected: Set<String> = []

    init(catalog: VerifiedRewriteCatalog, manager: BrowserManager, isPresented: Binding<Bool>) {
        self.catalog = catalog
        self.manager = manager
        self._isPresented = isPresented
        self._selected = State(initialValue: catalog.defaultSelectedEntryIDs)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.status.icon)
                            .foregroundStyle(item.status.color)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 7) {
                                Text(item.entry.name)
                                    .font(.system(size: 13, weight: .medium))
                                if item.entry.review.riskLevel == .elevated {
                                    Text("ELEVATED")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.16), in: Capsule())
                                        .foregroundStyle(.orange)
                                }
                            }
                            if !item.entry.summary.isEmpty {
                                Text(item.entry.summary)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Text("Match host: \(item.entry.hostPattern)\(item.entry.useRegex ? " (regular expression)" : "")")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            ForEach(item.entry.review.actionDescriptions, id: \.self) { action in
                                Text("• \(action)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            ForEach(item.entry.review.riskReasons, id: \.self) { reason in
                                Label(reason, systemImage: "exclamationmark.shield")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        Text(item.status.label)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(item.status.color.opacity(0.15), in: Capsule())
                            .foregroundStyle(item.status.color)
                        Toggle("", isOn: Binding(
                            get: { selected.contains(item.entry.id) },
                            set: { on in
                                if on { selected.insert(item.entry.id) } else { selected.remove(item.entry.id) }
                            }
                        ))
                        .labelsHidden()
                        .disabled(item.status == .added || item.status == .conflict)
                        .accessibilityIdentifier("catalog.rule.\(item.entry.id)")
                    }
                    .padding(.vertical, 5)
                    .accessibilityIdentifier("catalog.row.\(item.entry.id)")
                }
            }
            .listStyle(.plain)
            footer
        }
        .frame(width: 660, height: 600)
        .accessibilityIdentifier("catalog.selectionSheet")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20))
                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Predefined Rewrites")
                    .font(.system(size: 16, weight: .semibold))
                Text("Signed catalog v\(catalog.catalog.catalogVersion) · \(catalog.catalog.rules.count) rules · nothing selected automatically")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Verified with key \(catalog.provenance.keyID) · \(catalog.provenance.source == .cache ? "last-known-good cache" : "fresh download")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Clear Selection") { selected.removeAll() }
                .disabled(selected.isEmpty)
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Text("\(selected.count) selected")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", role: .cancel) { isPresented = false }
                .keyboardShortcut(.cancelAction)
            Button("Add Selected") {
                let result = RewriteCatalogService.shared.applySelected(
                    catalog,
                    manager: manager,
                    selectedEntryIDs: selected
                )
                isPresented = false
                NotificationCenter.default.post(
                    name: NSNotification.Name("RewriteCatalogApplied"),
                    object: result
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty)
        }
        .padding(16)
    }
}
