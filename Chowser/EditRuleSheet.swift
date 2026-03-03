import SwiftUI
import UniformTypeIdentifiers

struct EditRuleSheet: View {
    var rule: BrowserRoutingRule
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var ruleName: String
    @State private var hostPattern: String
    @State private var pathPrefix: String
    @State private var selectedBrowserIdentity: String
    @State private var sourceAppBundleId: String?
    @State private var usePrivateMode: Bool
    @State private var useRegex: Bool

    init(rule: BrowserRoutingRule, manager: BrowserManager, isPresented: Binding<Bool>) {
        self.rule = rule
        self.manager = manager
        self._isPresented = isPresented
        
        self._ruleName = State(initialValue: rule.name)
        self._hostPattern = State(initialValue: rule.hostPattern)
        self._pathPrefix = State(initialValue: rule.pathPrefix ?? "")
        
        // Find existing identity or fallback to first
        let identity = "\(rule.browserBundleId)|\(rule.profile ?? "")"
        if manager.configuredBrowsers.contains(where: { $0.identity == identity }) {
            self._selectedBrowserIdentity = State(initialValue: identity)
        } else {
            self._selectedBrowserIdentity = State(initialValue: manager.configuredBrowsers.first?.identity ?? "")
        }
        
        self._sourceAppBundleId = State(initialValue: rule.sourceAppBundleId)
        self._usePrivateMode = State(initialValue: rule.usePrivateMode)
        self._useRegex = State(initialValue: rule.useRegex)
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
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ruleNameSection
                    hostPatternSection
                    pathPrefixSection
                    browserPickerSection
                    sourceAppSection
                    privateModeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)
            }

            Divider()

            footer
        }
        .frame(width: 460, height: 420)
        .accessibilityIdentifier("settings.editRule.root")
    }

    private var header: some View {
        HStack {
            Text("Edit Routing Rule")
                .font(.system(size: 16, weight: .semibold, design: .rounded))

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var ruleNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rule Name")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("Work links", text: $ruleName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("settings.editRule.nameField")
        }
    }

    private var hostPatternSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Host Pattern")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Regex", isOn: $useRegex)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 10))
            }

            TextField(useRegex ? ".*\\.internal-dev\\.company\\.com" : "*, example.com, or *.example.com", text: $hostPattern)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .accessibilityIdentifier("settings.editRule.hostField")

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
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("/team", text: $pathPrefix)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .accessibilityIdentifier("settings.editRule.pathField")
        }
    }

    private var browserPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Open In")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Picker("Browser", selection: $selectedBrowserIdentity) {
                ForEach(manager.configuredBrowsers) { browser in
                    Text(browser.name).tag(browser.identity)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("settings.editRule.browserPicker")
        }
    }

    private var sourceAppSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source App (Optional)")
                .font(.system(size: 11))
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
                    Button("Clear") { sourceAppBundleId = nil }
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
        }
    }

    private func commitForm() {
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
        
        manager.updateRoutingRule(updated)
    }

    private var footer: some View {
        HStack {
            Button(role: .destructive) {
                manager.removeRoutingRule(id: rule.id)
                isPresented = false
            } label: {
                Text("Delete Rule")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("settings.editRule.deleteButton")

            Spacer()

            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("settings.editRule.cancelButton")

            Button("Save Changes") {
                commitForm()
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSaveRule)
            .accessibilityIdentifier("settings.editRule.confirmButton")
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
