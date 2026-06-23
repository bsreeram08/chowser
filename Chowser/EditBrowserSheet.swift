import SwiftUI

struct EditBrowserSheet: View {
    var browser: BrowserConfig
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var editingName: String
    @State private var editingProfile: String
    @State private var editingCustomArgs: String

    init(browser: BrowserConfig, manager: BrowserManager, isPresented: Binding<Bool>) {
        self.browser = browser
        self.manager = manager
        self._isPresented = isPresented
        self._editingName = State(initialValue: browser.name)
        self._editingProfile = State(initialValue: browser.profile ?? "")
        self._editingCustomArgs = State(initialValue: browser.customArguments ?? "")
    }

    private var canSave: Bool {
        !editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Browser")
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

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Display Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("Display Name", text: $editingName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, weight: .medium))
                            .accessibilityIdentifier("settings.editBrowser.nameField")
                    }

                    // Read-only Context
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bundle ID")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(browser.bundleId)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }

                    // Profile — editable so it can be set manually when auto-detection
                    // is unavailable (e.g. the sandboxed App Store build).
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profile")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("Optional — e.g. Default, Profile 1, Work", text: $editingProfile)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .accessibilityIdentifier("settings.editBrowser.profileField")
                        Text("Chromium profile directory name (\"Default\", \"Profile 1\", …) or a Firefox profile name. Leave blank for the default profile.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    // Custom Args
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Custom Launch Arguments")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("Optional — e.g. --profile-directory={profile} {url}", text: $editingCustomArgs)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .accessibilityIdentifier("settings.editBrowser.argsField")
                        Text("Placeholders: {url}, {profile}. If omitted, URL is appended at the end.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Button(role: .destructive) {
                    manager.removeBrowser(id: browser.id)
                    isPresented = false
                } label: {
                    Text("Delete Browser")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("settings.editBrowser.deleteButton")
                
                Spacer()
                
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)

                Button("Save Changes") {
                    manager.updateBrowserName(id: browser.id, to: editingName.trimmingCharacters(in: .whitespacesAndNewlines))
                    manager.updateBrowserProfile(id: browser.id, to: editingProfile)
                    manager.updateBrowserCustomArguments(id: browser.id, to: editingCustomArgs.trimmingCharacters(in: .whitespacesAndNewlines))
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .accessibilityIdentifier("settings.editBrowser.saveButton")
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 440, height: 440)
        .accessibilityIdentifier("settings.editBrowser.root")
    }
}
