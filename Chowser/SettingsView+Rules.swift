import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

extension SettingsView {
    var filteredRoutingRules: [BrowserRoutingRule] {
        let query = ruleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return browserManager.routingRules
        }

        return browserManager.routingRules.filter { rule in
            rule.name.localizedStandardContains(query)
                || rule.hostPattern.localizedStandardContains(query)
                || (rule.pathPrefix?.localizedStandardContains(query) ?? false)
                || rule.sourceAppBundleIDs.contains(where: { $0.localizedStandardContains(query) })
        }
    }

    var rulesSection: some View {
        SettingsDetailScaffold(
            title: "Rules",
            subtitle: "Route matching links directly to the right browser.",
            systemImage: "point.topleft.down.curvedto.point.bottomright.up",
            actions: {
                HStack(spacing: 8) {
                    Menu {
                        Button(action: exportRules) {
                            Label("Export Rules…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(browserManager.routingRules.isEmpty)

                        Button(action: importRules) {
                            Label("Import Rules…", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("Rule Actions", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityIdentifier("settings.rulesMenuButton")

                    Button("Add Rule", systemImage: "plus") {
                        preselectedRuleBrowserIdentity = nil
                        showingAddRuleSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.addRuleButton")
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    if !browserManager.pendingRuleMergeSuggestions.isEmpty {
                        mergeSuggestionBanner
                    }

                    HStack(spacing: 12) {
                        sectionSearchField(
                            placeholder: "Filter rules by name, host, path, or source app",
                            text: $ruleSearchText,
                            accessibilityIdentifier: "settings.rule.searchField"
                        )

                        Text("\(browserManager.routingRules.filter(\.isEnabled).count) enabled")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    rulesListContent

                    SettingsRuleTester(manager: browserManager)
                }
            }
        )
    }

    private var mergeSuggestionBanner: some View {
        let count = browserManager.pendingRuleMergeSuggestions.count
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) rule merge\(count == 1 ? "" : "s") suggested")
                    .font(.system(size: 12, weight: .semibold))
                Text("These rules differ only by source app and route to the same browser.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Review") { showingRuleMergeReview = true }
                .controlSize(.small)
                .accessibilityIdentifier("settings.rules.reviewMergeSuggestionsButton")
        }
        .padding(12)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("settings.rules.mergeSuggestionBanner")
    }

    @ViewBuilder
    private var rulesListContent: some View {
        if browserManager.routingRules.isEmpty {
            SettingsEmptyContent(
                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                title: "No routing rules",
                message: "Add a rule to send matching links straight to a browser.",
                actionTitle: "Add Rule"
            ) {
                preselectedRuleBrowserIdentity = nil
                showingAddRuleSheet = true
            }
        } else if filteredRoutingRules.isEmpty {
            SettingsEmptyContent(
                systemImage: "magnifyingglass",
                title: "No matching rules",
                message: "Clear the filter to show all routing rules."
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filteredRoutingRules) { rule in
                    SettingsRuleRow(
                        rule: rule,
                        browser: browser(for: rule),
                        browsers: browserManager.configuredBrowsers,
                        identityParser: browserIdentityParts(from:),
                        onUpdate: { updated in
                            _ = browserManager.updateRule(updated)
                        },
                        onDelete: {
                            browserManager.removeRoutingRule(id: rule.id)
                        },
                        onDuplicate: {
                            browserManager.duplicateRoutingRule(id: rule.id)
                        }
                    )
                    .id(rule.id)
                }
            }
        }
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

private struct SettingsRuleRow: View {
    enum FocusedField: Hashable {
        case name
        case host
        case path
    }

    let rule: BrowserRoutingRule
    let browser: BrowserConfig?
    let browsers: [BrowserConfig]
    let identityParser: (String) -> (bundleId: String, profile: String?)
    let onUpdate: (BrowserRoutingRule) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    @State private var draft: BrowserRoutingRule
    @FocusState private var focusedField: FocusedField?

    init(
        rule: BrowserRoutingRule,
        browser: BrowserConfig?,
        browsers: [BrowserConfig],
        identityParser: @escaping (String) -> (bundleId: String, profile: String?),
        onUpdate: @escaping (BrowserRoutingRule) -> Void,
        onDelete: @escaping () -> Void,
        onDuplicate: @escaping () -> Void
    ) {
        self.rule = rule
        self.browser = browser
        self.browsers = browsers
        self.identityParser = identityParser
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self._draft = State(initialValue: rule)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                browserIcon
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        TextField("Rule name", text: $draft.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .focused($focusedField, equals: .name)
                            .onSubmit(commitDraft)

                        Spacer()

                        Toggle("Enabled", isOn: Binding(
                            get: { draft.isEnabled },
                            set: { draft.isEnabled = $0; commitDraft() }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Host")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)

                            TextField("github.com or *.example.com", text: $draft.hostPattern)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .focused($focusedField, equals: .host)
                                .onSubmit(commitDraft)
                                .accessibilityIdentifier("settings.rule.hostField")
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("Path")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                Button(draft.pathPrefix == nil ? "Add" : "Remove") {
                                    draft.pathPrefix = draft.pathPrefix == nil ? "/" : nil
                                    commitDraft()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .medium))
                            }

                            TextField("/", text: Binding(
                                get: { draft.pathPrefix ?? "" },
                                set: { draft.pathPrefix = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .focused($focusedField, equals: .path)
                            .onSubmit(commitDraft)
                            .disabled(draft.pathPrefix == nil)
                            .opacity(draft.pathPrefix == nil ? 0.45 : 1)
                        }
                    }

                    HStack(alignment: .center, spacing: 14) {
                        Picker("Browser", selection: Binding(get: { draft.identity }, set: updateBrowserIdentity)) {
                            if browsers.isEmpty {
                                Text("No browsers configured").tag(draft.identity)
                            } else {
                                ForEach(browsers) { browser in
                                    Text(browserDisplayName(browser)).tag(browser.identity)
                                }

                                if browser == nil && !browsers.contains(where: { $0.identity == draft.identity }) {
                                    Text("Missing browser").tag(draft.identity)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 240, alignment: .leading)
                        .accessibilityIdentifier("settings.rule.browserPicker")

                        Toggle("Regex", isOn: Binding(
                            get: { draft.useRegex },
                            set: { draft.useRegex = $0; commitDraft() }
                        ))
                        .toggleStyle(.checkbox)

                        Toggle("Private", isOn: Binding(
                            get: { BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild && draft.usePrivateMode },
                            set: {
                                draft.usePrivateMode = BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild ? $0 : false
                                commitDraft()
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .disabled(!BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source Apps")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            SourceAppChipsView(bundleIDs: $draft.sourceAppBundleIDs, onCommit: commitDraft)

                            Spacer()

                            Button("Duplicate", systemImage: "doc.on.doc") {
                                onDuplicate()
                            }
                            .controlSize(.small)

                            Button("Delete", systemImage: "trash", role: .destructive) {
                                onDelete()
                            }
                            .controlSize(.small)
                        }

                        Text(sourceSummaryText)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(rule.isEnabled ? Color.accentColor.opacity(0.25) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .onChange(of: rule) { _, newValue in
            guard focusedField == nil else { return }
            draft = newValue
        }
        .onChange(of: focusedField) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            commitDraft()
        }
    }

    @ViewBuilder
    private var browserIcon: some View {
        if let browser, let icon = AppMetadataCache.shared.icon(for: browser.bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: rule.isEnabled ? "point.topleft.down.curvedto.point.bottomright.up" : "pause.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
    }

    private func browserDisplayName(_ browser: BrowserConfig) -> String {
        if let profile = browser.profile {
            return "\(browser.name) (\(profile))"
        }
        return browser.name
    }

    private func updateBrowserIdentity(_ identity: String) {
        let parsed = identityParser(identity)
        draft.browserBundleId = parsed.bundleId
        draft.profile = parsed.profile
        commitDraft()
    }

    private func commitDraft() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = draft.hostPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = draft.pathPrefix?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedHost.isEmpty else {
            draft = rule
            return
        }

        draft.name = trimmedName
        draft.hostPattern = trimmedHost
        draft.pathPrefix = trimmedPath?.isEmpty == true ? nil : trimmedPath

        guard draft != rule else { return }
        onUpdate(draft)
    }

    /// Compact source condition summary, e.g. "Slack, Mail → Chrome Work" (PRD: Settings: Rules).
    private var sourceSummaryText: String {
        let sourceNames = draft.sourceAppBundleIDs.isEmpty
            ? "Any source app"
            : draft.sourceAppBundleIDs.map(appDisplayName).joined(separator: ", ")
        return "\(sourceNames) → \(browser.map(browserDisplayName) ?? "missing browser")"
    }

    private func appDisplayName(for bundleId: String) -> String {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return bundleId
        }
        return (Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? bundleId
    }
}

private extension BrowserRoutingRule {
    var identity: String {
        "\(browserBundleId)|\(profile ?? "")"
    }
}

private struct SettingsRuleTester: View {
    let manager: BrowserManager
    @State private var urlString = ""
    @State private var sourceAppBundleId = ""

    var body: some View {
        SettingsGroup("Rule Tester", subtitle: "Check how a link resolves before leaving Settings.") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("https://example.com/docs", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .accessibilityIdentifier("settings.ruleTester.urlField")

                TextField("Source app bundle ID (optional)", text: $sourceAppBundleId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .accessibilityIdentifier("settings.ruleTester.sourceAppField")

                testerResult
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var testerResult: some View {
        if urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("Enter a URL to test the current rule order.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else if let url = parsedURL {
            // Explicit source app (Eng Review: the tester must not rely on the ambient
            // currentSourceAppBundleId, which is only set during a live URL open).
            let trimmedSourceApp = sourceAppBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
            if let route = manager.resolvedRoute(for: url, sourceApp: trimmedSourceApp.isEmpty ? nil : trimmedSourceApp) {
                Label("Matches \(route.rule?.name ?? "temporary route") and opens \(route.browser.name)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Label("No rule matches. Chowser will show the picker.", systemImage: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
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
