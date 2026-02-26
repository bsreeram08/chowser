import SwiftUI
import UniformTypeIdentifiers

struct RuleRowView: View {
    let rule: BrowserRoutingRule
    let configuredBrowsers: [BrowserConfig]
    let hasSearchQuery: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool

    // Callbacks — excluded from Equatable comparison intentionally
    let onUpdate: (BrowserRoutingRule) -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let isValidHostPattern: (String) -> Bool

    @State private var editingName: String
    @State private var editingHost: String
    @State private var editingPath: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, host, path
    }

    init(
        rule: BrowserRoutingRule,
        configuredBrowsers: [BrowserConfig],
        hasSearchQuery: Bool,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onUpdate: @escaping (BrowserRoutingRule) -> Void,
        onDelete: @escaping () -> Void,
        onDuplicate: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        isValidHostPattern: @escaping (String) -> Bool
    ) {
        self.rule = rule
        self.configuredBrowsers = configuredBrowsers
        self.hasSearchQuery = hasSearchQuery
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.isValidHostPattern = isValidHostPattern
        self._editingName = State(initialValue: rule.name)
        self._editingHost = State(initialValue: rule.hostPattern)
        self._editingPath = State(initialValue: rule.pathPrefix ?? "")
    }

    private var hostPatternIsValid: Bool {
        isValidHostPattern(editingHost)
    }

    private var matchSummary: String {
        let pathText = (rule.pathPrefix?.isEmpty == false) ? " + path \(rule.pathPrefix!)" : ""
        let statusText = rule.isEnabled ? "Enabled" : "Disabled"
        var summary = "\(statusText): host \(rule.hostPattern)\(pathText)"
        if let bundleId = rule.sourceAppBundleId, !bundleId.isEmpty {
            let name = appDisplayName(for: bundleId) ?? bundleId
            summary += " from \(name)"
        }
        if rule.usePrivateMode {
            summary += " • private"
        }
        return summary
    }

    private var browserIdentity: Binding<String> {
        Binding(
            get: {
                let identity = "\(rule.browserBundleId)|\(rule.profile ?? "")"
                if configuredBrowsers.contains(where: { $0.identity == identity }) {
                    return identity
                }
                return configuredBrowsers.first?.identity ?? ""
            },
            set: { newValue in
                if let browser = configuredBrowsers.first(where: { $0.identity == newValue }) {
                    var updated = rule
                    updated.browserBundleId = browser.bundleId
                    updated.profile = browser.profile
                    onUpdate(updated)
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { newValue in
                        var updated = rule
                        updated.isEnabled = newValue
                        onUpdate(updated)
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel("Enable rule \(rule.name)")

                Text(rule.isEnabled ? "ON" : "OFF")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(rule.isEnabled ? .green : .secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RULE NAME")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextField("Rule name", text: $editingName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, weight: .medium))
                            .focused($focusedField, equals: .name)
                            .onSubmit { commitField(.name) }
                            .accessibilityIdentifier("settings.rule.nameField")
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TARGET BROWSER")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Picker("", selection: browserIdentity) {
                            ForEach(configuredBrowsers) { browser in
                                Text(browser.name).tag(browser.identity)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("settings.rule.browserPicker")
                        .accessibilityLabel("Target browser")
                    }
                    .frame(width: 220)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOST PATTERN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextField("example.com or *.example.com", text: $editingHost)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .focused($focusedField, equals: .host)
                            .onSubmit { commitField(.host) }
                            .accessibilityIdentifier("settings.rule.hostField")

                        if !hostPatternIsValid {
                            Label("Invalid host pattern", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PATH PREFIX")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextField("Optional", text: $editingPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .focused($focusedField, equals: .path)
                            .onSubmit { commitField(.path) }
                            .accessibilityIdentifier("settings.rule.pathField")
                    }
                    .frame(width: 220)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SOURCE APP")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            if let bundleId = rule.sourceAppBundleId,
                               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text(appDisplayName(for: bundleId) ?? bundleId)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Button("Clear") {
                                    var updated = rule
                                    updated.sourceAppBundleId = nil
                                    onUpdate(updated)
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            } else {
                                Text("Any App")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                            Button("Choose…") {
                                chooseSourceApp()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("OPTIONS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Toggle("Private / Incognito", isOn: Binding(
                            get: { rule.usePrivateMode },
                            set: { newValue in
                                var updated = rule
                                updated.usePrivateMode = newValue
                                onUpdate(updated)
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                    }
                    .frame(width: 220)
                }

                Text(matchSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, -4)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.75))
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("settings.rule.deleteButton")
            .accessibilityLabel("Remove \(rule.name)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .onChange(of: focusedField) { oldValue, _ in
            if let field = oldValue {
                commitField(field)
            }
        }
        .onChange(of: rule) { _, newRule in
            if focusedField != .name { editingName = newRule.name }
            if focusedField != .host { editingHost = newRule.hostPattern }
            if focusedField != .path { editingPath = newRule.pathPrefix ?? "" }
        }
        .contextMenu {
            Button("Move Up") { onMoveUp() }
                .disabled(hasSearchQuery || !canMoveUp)

            Button("Move Down") { onMoveDown() }
                .disabled(hasSearchQuery || !canMoveDown)

            Button("Duplicate Rule") { onDuplicate() }

            Divider()

            Button("Remove Rule", role: .destructive) { onDelete() }
        }
    }

    // MARK: - Helpers

    private func commitField(_ field: Field) {
        var updated = rule
        switch field {
        case .name:
            let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.name = trimmed.isEmpty ? rule.hostPattern : trimmed
        case .host:
            let trimmed = editingHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            updated.hostPattern = trimmed
        case .path:
            let trimmed = editingPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                updated.pathPrefix = nil
            } else {
                updated.pathPrefix = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
            }
        }
        onUpdate(updated)
    }

    private func appDisplayName(for bundleId: String) -> String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        let bundle = Bundle(url: appURL)
        return (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
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
            var updated = rule
            updated.sourceAppBundleId = Bundle(url: url)?.bundleIdentifier
            onUpdate(updated)
        }
    }
}

extension RuleRowView: Equatable {
    static func == (lhs: RuleRowView, rhs: RuleRowView) -> Bool {
        lhs.rule == rhs.rule &&
        lhs.configuredBrowsers == rhs.configuredBrowsers &&
        lhs.hasSearchQuery == rhs.hasSearchQuery &&
        lhs.canMoveUp == rhs.canMoveUp &&
        lhs.canMoveDown == rhs.canMoveDown
    }
}
