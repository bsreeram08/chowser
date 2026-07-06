import SwiftUI
import Foundation
import AppKit

/// Shared between the "Add Rewrite" sheet and the inline row editor.
enum RewriteSchemeFilter: String, CaseIterable {
    case any = "Any"
    case http = "HTTP only"
    case https = "HTTPS only"

    var schemes: [String] {
        switch self {
        case .any: return []
        case .http: return ["http"]
        case .https: return ["https"]
        }
    }

    init(schemes: [String]) {
        self = schemes == ["http"] ? .http : (schemes == ["https"] ? .https : .any)
    }
}

/// Shared field state for the fixed set of rewrite action controls (PRD "Action
/// controls"). Used by both the "Add Rewrite" sheet and the inline row editor so the
/// UI-fields ↔ `[URLRewriteAction]` conversion exists in exactly one place.
struct RewriteActionFieldsState: Equatable {
    var forceSchemeEnabled = false
    var forceScheme = "https"
    var replaceHostEnabled = false
    var replaceHost = ""
    var stripParamNames = ""
    var stripParamPrefixes = ""
    var setParamName = ""
    var setParamValue = ""
    var removeFragmentEnabled = false

    static func derive(from actions: [URLRewriteAction]) -> RewriteActionFieldsState {
        var state = RewriteActionFieldsState()
        for action in actions {
            switch action {
            case .forceScheme(let scheme):
                state.forceSchemeEnabled = true
                state.forceScheme = scheme
            case .replaceHost(let host):
                state.replaceHostEnabled = true
                state.replaceHost = host
            case .stripQueryParameters(let names):
                state.stripParamNames = names.joined(separator: ", ")
            case .stripQueryParameterPrefixes(let prefixes):
                state.stripParamPrefixes = prefixes.joined(separator: ", ")
            case .setQueryParameter(let name, let value):
                state.setParamName = name
                state.setParamValue = value
            case .removeFragment:
                state.removeFragmentEnabled = true
            }
        }
        return state
    }

    /// Actions in the sketch's declared order: forceScheme, replaceHost,
    /// stripQueryParameters, stripQueryParameterPrefixes, setQueryParameter, removeFragment.
    func buildActions() -> [URLRewriteAction] {
        var actions: [URLRewriteAction] = []
        if forceSchemeEnabled {
            actions.append(.forceScheme(forceScheme))
        }
        if replaceHostEnabled, !replaceHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            actions.append(.replaceHost(replaceHost))
        }
        let names = stripParamNames.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !names.isEmpty {
            actions.append(.stripQueryParameters(names))
        }
        let prefixes = stripParamPrefixes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !prefixes.isEmpty {
            actions.append(.stripQueryParameterPrefixes(prefixes))
        }
        if !setParamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            actions.append(.setQueryParameter(name: setParamName, value: setParamValue))
        }
        if removeFragmentEnabled {
            actions.append(.removeFragment)
        }
        return actions
    }
}

/// Reusable fixed action-control fields (PRD "Action controls" list), bound to a shared
/// `RewriteActionFieldsState` so the sheet and the inline row render identical controls.
/// ponytail: text fields commit on Return (`onSubmit`), not on focus-loss like the row's
/// other fields — wiring a shared `FocusState` across this view boundary would need a
/// generic focus binding for one extra behavior; upgrade if commit-on-blur is missed here.
struct RewriteActionFieldsView: View {
    // Self-contained focus tracking (rather than relying on a caller-supplied FocusState) so
    // commit-on-blur works correctly wherever this view is embedded, including inside
    // `SettingsRewriteRow`'s inline editor — a prior version relied on the parent row's
    // `FocusedField` enum declaring cases for these fields, but never actually wired them
    // with `.focused()`, so blur never committed an edit (found in Codex PR review).
    private enum ActionField: Hashable {
        case replaceHost, stripNames, stripPrefixes, setName, setValue
    }

    @Binding var fields: RewriteActionFieldsState
    var onCommit: () -> Void = {}

    @FocusState private var focusedField: ActionField?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            actionRow(isOn: $fields.forceSchemeEnabled, title: "Force scheme") {
                Picker("", selection: $fields.forceScheme) {
                    Text("https").tag("https")
                    Text("http").tag("http")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 90)
            }
            .onChange(of: fields.forceSchemeEnabled) { _, _ in onCommit() }
            .onChange(of: fields.forceScheme) { _, _ in onCommit() }

            actionRow(isOn: $fields.replaceHostEnabled, title: "Replace host") {
                TextField("newhost.example.com", text: $fields.replaceHost)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($focusedField, equals: .replaceHost)
                    .onSubmit(onCommit)
            }
            .onChange(of: fields.replaceHostEnabled) { _, _ in onCommit() }

            actionTextField(label: "Strip query parameters by name", placeholder: "utm_source, utm_campaign", text: $fields.stripParamNames, focusValue: .stripNames, focus: $focusedField, onCommit: onCommit)
                .accessibilityIdentifier("settings.rewrite.stripParamsField")

            actionTextField(label: "Strip query parameters by prefix", placeholder: "utm_, hsa_", text: $fields.stripParamPrefixes, focusValue: .stripPrefixes, focus: $focusedField, onCommit: onCommit)

            VStack(alignment: .leading, spacing: 6) {
                Text("Add / replace query parameter")
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 8) {
                    TextField("name", text: $fields.setParamName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        .focused($focusedField, equals: .setName)
                        .onSubmit(onCommit)
                    TextField("value", text: $fields.setParamValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        .focused($focusedField, equals: .setValue)
                        .onSubmit(onCommit)
                }
            }

            Toggle("Remove fragment (#...)", isOn: $fields.removeFragmentEnabled)
                .toggleStyle(.checkbox)
                .onChange(of: fields.removeFragmentEnabled) { _, _ in onCommit() }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            onCommit()
        }
    }

    @ViewBuilder
    private func actionRow<Content: View>(isOn: Binding<Bool>, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Toggle(title, isOn: isOn)
                .toggleStyle(.checkbox)
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 8)
            content()
                .disabled(!isOn.wrappedValue)
                .opacity(isOn.wrappedValue ? 1 : 0.45)
        }
    }

    private func actionTextField(label: String, placeholder: String, text: Binding<String>, focusValue: ActionField, focus: FocusState<ActionField?>.Binding, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                .focused(focus, equals: focusValue)
                .onSubmit(onCommit)
        }
    }
}

/// "Add Rewrite" creation sheet for URL rewrite rules (FR-020) — mirrors `AddRuleSheet`'s
/// explicit-Save-button pattern. Editing an existing rule happens inline on its row
/// (`SettingsRewriteRow`, commit-on-blur), matching `SettingsRuleRow`'s structure
/// (design review: "structurally the same kind of row" as routing rules), not a modal.
/// Action controls are a fixed set of toggleable fields (matching the PRD's "Action
/// controls" list exactly, applied in the sketch's declared order at save time), not a
/// free-form action builder.
struct RewriteRuleEditorSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var hostPattern = ""
    @State private var useRegex = false
    @State private var pathPrefix = ""
    @State private var sourceAppBundleIDs: [String] = []
    @State private var schemeFilter = RewriteSchemeFilter.any
    @State private var actionFields = RewriteActionFieldsState()

    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Rewrite Rule")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Transform a URL before routing rules are evaluated.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(Color.primary.opacity(0.02))

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name".uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextField("Strip tracking params, Force HTTPS, etc.", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityIdentifier("settings.addRewrite.nameField")
                    }

                    DetailSection(title: "Matching", icon: "app.connected.to.app.below.fill") {
                        VStack(spacing: 16) {
                            DetailRow(label: "Host Pattern") {
                                TextField("e.g. *.example.com", text: $hostPattern)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .accessibilityIdentifier("settings.addRewrite.hostField")
                            }

                            HStack {
                                Toggle("Regex", isOn: $useRegex)
                                    .toggleStyle(.checkbox)

                                Spacer()

                                Button(pathPrefix.isEmpty ? "Add Path" : "Path: \(pathPrefix)") {
                                    pathPrefix = pathPrefix.isEmpty ? "/" : ""
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(.accent)
                            }

                            if !pathPrefix.isEmpty {
                                TextField("Path Prefix", text: $pathPrefix)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(8)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                            }

                            DetailRow(label: "Scheme") {
                                Picker("", selection: $schemeFilter) {
                                    ForEach(RewriteSchemeFilter.allCases, id: \.self) { filter in
                                        Text(filter.rawValue).tag(filter)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .accessibilityIdentifier("settings.addRewrite.schemePicker")
                            }
                        }
                    }

                    DetailSection(title: "Actions", icon: "wand.and.stars") {
                        RewriteActionFieldsView(fields: $actionFields)
                    }

                    DetailSection(title: "Context", icon: "cpu.fill") {
                        DetailRow(label: "Source Apps") {
                            SourceAppChipsView(bundleIDs: $sourceAppBundleIDs)
                        }
                    }

                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: save) {
                    Text("Create Rewrite")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.accentColor : Color.secondary.opacity(0.3), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityIdentifier("settings.addRewrite.confirmButton")
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(Color.primary.opacity(0.01))
        }
        .frame(width: 520, height: 700)
        .accessibilityIdentifier("settings.addRewrite.root")
    }

    /// Save disabled until required fields are complete (design review), not just
    /// validated after clicking Save: a non-empty host pattern and at least one action.
    private var canSave: Bool {
        !hostPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !actionFields.buildActions().isEmpty
    }

    private func save() {
        let match = URLRewriteMatch(
            schemes: schemeFilter.schemes,
            hostPattern: hostPattern,
            useRegex: useRegex,
            pathPrefix: pathPrefix.isEmpty ? nil : pathPrefix,
            sourceAppBundleIDs: sourceAppBundleIDs
        )

        let newRule = URLRewriteRule(name: name, match: match, actions: actionFields.buildActions())
        switch manager.addRewriteRule(newRule) {
        case .success:
            isPresented = false
        case .failure(let error):
            saveError = error.message
        }
    }
}
