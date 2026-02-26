import SwiftUI
import UniformTypeIdentifiers

struct AddRuleSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var ruleName = ""
    @State private var hostPattern = ""
    @State private var pathPrefix = ""
    @State private var selectedBrowserIdentity = ""
    @State private var sourceAppBundleId: String? = nil
    @State private var usePrivateMode = false

    private var effectiveBrowserIdentity: String {
        if !selectedBrowserIdentity.isEmpty { return selectedBrowserIdentity }
        return manager.configuredBrowsers.first?.identity ?? ""
    }

    private var hostPatternIsValid: Bool {
        manager.isValidRoutingHostPattern(hostPattern)
    }

    private var canCreateRule: Bool {
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

                    Text("Rules are checked in order. First enabled match opens directly.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)
            }

            Divider()

            footer
        }
        .frame(width: 460, height: 420)
        .onAppear {
            if selectedBrowserIdentity.isEmpty {
                selectedBrowserIdentity = manager.configuredBrowsers.first?.identity ?? ""
            }
        }
        .accessibilityIdentifier("settings.addRule.root")
    }

    private var header: some View {
        HStack {
            Text("Add Routing Rule")
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
                .accessibilityIdentifier("settings.addRule.nameField")
        }
    }

    private var hostPatternSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Host Pattern")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("example.com or *.example.com", text: $hostPattern)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .accessibilityIdentifier("settings.addRule.hostField")

            if !hostPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hostPatternIsValid {
                Text("Host pattern must be like example.com or *.example.com")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }

            Button("Use example host") {
                hostPattern = "github.com"
                if ruleName.isEmpty {
                    ruleName = "github"
                }
                if selectedBrowserIdentity.isEmpty {
                    selectedBrowserIdentity = manager.configuredBrowsers.first?.identity ?? ""
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("settings.addRule.fillTestHostButton")
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
                .accessibilityIdentifier("settings.addRule.pathField")
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
            .accessibilityIdentifier("settings.addRule.browserPicker")
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

    private var footer: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("settings.addRule.cancelButton")

            Spacer()

            Button("Add Rule") {
                if let browser = manager.configuredBrowsers.first(where: { $0.identity == effectiveBrowserIdentity }) {
                    manager.addRoutingRule(
                        name: ruleName,
                        hostPattern: hostPattern,
                        pathPrefix: pathPrefix,
                        browserBundleId: browser.bundleId,
                        profile: browser.profile,
                        sourceAppBundleId: sourceAppBundleId,
                        usePrivateMode: usePrivateMode
                    )
                }
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canCreateRule)
            .accessibilityIdentifier("settings.addRule.confirmButton")
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
