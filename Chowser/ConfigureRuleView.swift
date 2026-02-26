import SwiftUI

/// Compact sheet for creating a routing rule directly from the intercepted URL context.
/// Pre-populates rule name and host pattern from the intercepted URL's domain.
struct ConfigureRuleView: View {
    var browserManager: BrowserManager
    let interceptedURL: URL
    @Binding var isPresented: Bool
    var onSave: () -> Void

    @State private var ruleName = ""
    @State private var hostPattern = ""
    @State private var selectedBrowserIdentity = ""
    @State private var usePrivateMode = false

    enum Field: Hashable {
        case ruleName
        case hostPattern
    }

    @FocusState private var focusedField: Field?

    private var isFormValid: Bool {
        !ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hostPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && browserManager.isValidRoutingHostPattern(hostPattern)
            && !selectedBrowserIdentity.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formFields
            Divider()
            footer
        }
        .frame(width: 340)
        .onAppear {
            prefillFromURL()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .ruleName
            }
        }
        .accessibilityIdentifier("picker.configureRule.root")
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Configure Rule")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Form Fields

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rule Name")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("e.g. github", text: $ruleName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .focused($focusedField, equals: .ruleName)
                    .accessibilityIdentifier("picker.configureRule.nameField")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("URL Pattern")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("example.com or *.example.com", text: $hostPattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .accessibilityIdentifier("picker.configureRule.hostField")

                if !hostPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !browserManager.isValidRoutingHostPattern(hostPattern) {
                    Text("Invalid pattern. Use example.com or *.example.com")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Open In")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Picker("Browser", selection: $selectedBrowserIdentity) {
                    ForEach(browserManager.configuredBrowsers) { browser in
                        Text(browser.name).tag(browser.identity)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityIdentifier("picker.configureRule.browserPicker")
            }

            Toggle("Open in Private / Incognito", isOn: $usePrivateMode)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("picker.configureRule.cancelButton")

            Spacer()

            Button("Save Rule") {
                if let browser = browserManager.configuredBrowsers.first(where: { $0.identity == selectedBrowserIdentity }) {
                    browserManager.addRoutingRule(
                        name: ruleName,
                        hostPattern: hostPattern,
                        pathPrefix: nil,
                        browserBundleId: browser.bundleId,
                        profile: browser.profile,
                        usePrivateMode: usePrivateMode
                    )
                }
                isPresented = false
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .accessibilityIdentifier("picker.configureRule.saveButton")
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Helpers

    private func prefillFromURL() {
        let host = interceptedURL.host ?? ""
        hostPattern = host

        let components = host.split(separator: ".")
        if components.count >= 2 {
            ruleName = String(components[components.count - 2])
        } else {
            ruleName = host
        }

        selectedBrowserIdentity = browserManager.configuredBrowsers.first?.identity ?? ""
    }
}
