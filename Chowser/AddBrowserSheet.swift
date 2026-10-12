import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// "Add Browsers" sheet: every installed browser/profile Chowser can detect, with a
/// checkbox each. Already-configured entries stay visible (checked, disabled) so the list
/// reads as "what's on this Mac" rather than shifting as you add things. Apps on the
/// hidden list are excluded. "Other App…" switches to the manual/custom-app form.
struct AddBrowserSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool
    /// Called with the browsers that were added (in order) right before the sheet closes.
    var onAdded: ([BrowserConfig]) -> Void = { _ in }

    typealias BrowserEntry = (name: String, bundleId: String, profile: String?, iconURL: URL?)

    /// One display row. Icons are resolved once per refresh, never inside `body`.
    struct Row: Identifiable {
        let id: String
        let name: String
        let bundleId: String
        let profile: String?
        let detail: String
        let icon: NSImage?
        let isAlreadyAdded: Bool
    }

    private enum Mode {
        case installed
        case otherApp
    }

    @State private var mode: Mode = .installed
    @State private var rows: [Row] = []
    @State private var selectedIDs: Set<String> = []
    @State private var hasLoaded = false
    @State private var profileAccessStatus = SandboxBookmarkManager.shared.grantStatus

    var body: some View {
        Group {
            switch mode {
            case .installed:
                installedContent
            case .otherApp:
                CustomAppForm(
                    manager: manager,
                    onBack: { mode = .installed },
                    onAdded: finish(with:)
                )
            }
        }
        .frame(width: 480, height: 520)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            refreshInstalledBrowsers()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.addSheet.root")
    }

    // MARK: - Installed browsers

    private var installedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Browsers")
                    .font(.headline)
                Text("Chowser found these browsers and profiles on your Mac. Choose the ones to add.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            if profileAccessStatus.needsRecovery {
                profileAccessBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            if rows.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(rows) { row in
                        Toggle(isOn: selectionBinding(for: row)) {
                            AddBrowserOptionLabel(row: row)
                        }
                        .toggleStyle(.checkbox)
                        .disabled(row.isAlreadyAdded)
                        .contextMenu {
                            Button("Hide This App from Chowser") {
                                hide(row.bundleId)
                            }
                        }
                        .accessibilityIdentifier("settings.addSheet.option")
                        .accessibilityLabel(row.isAlreadyAdded ? "\(row.name), already added" : row.name)
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: false))
                .padding(.horizontal, 20)
                .accessibilityIdentifier("settings.addSheet.list")
            }

            Divider()
                .padding(.top, 12)

            HStack {
                Button("Other App…") {
                    mode = .otherApp
                }
                .help("Choose any app, or enter a bundle ID manually")
                .accessibilityIdentifier("settings.addSheet.otherAppButton")

                Spacer()

                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("settings.addSheet.cancelButton")

                Button(addButtonTitle) {
                    addSelected()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedIDs.isEmpty)
                .accessibilityIdentifier("settings.addSheet.addButton")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Text("No browsers found")
                .font(.headline)
            Text("Use Other App… to add any app that can open links.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var addButtonTitle: String {
        switch selectedIDs.count {
        case 0: return "Add Browsers"
        case 1: return "Add 1 Browser"
        default: return "Add \(selectedIDs.count) Browsers"
        }
    }

    private func selectionBinding(for row: Row) -> Binding<Bool> {
        Binding(
            get: { row.isAlreadyAdded || selectedIDs.contains(row.id) },
            set: { isOn in
                guard !row.isAlreadyAdded else { return }
                if isOn {
                    selectedIDs.insert(row.id)
                } else {
                    selectedIDs.remove(row.id)
                }
            }
        )
    }

    private func addSelected() {
        let requests = rows
            .filter { selectedIDs.contains($0.id) && !$0.isAlreadyAdded }
            .map { BrowserManager.BrowserAddRequest(name: $0.name, bundleId: $0.bundleId, profile: $0.profile) }
        let added = manager.addBrowsers(requests)
        finish(with: added)
    }

    private func finish(with added: [BrowserConfig]) {
        onAdded(added)
        isPresented = false
    }

    private func hide(_ bundleId: String) {
        manager.addHiddenBundleID(bundleId)
        refreshInstalledBrowsers()
    }

    private func refreshInstalledBrowsers() {
        BrowserProfileDetector.clearCache()
        profileAccessStatus = SandboxBookmarkManager.shared.grantStatus

        let configuredIdentities = Set(manager.configuredBrowsers.map(\.identity))
        rows = Self.sheetRows(
            for: BrowserManager.getInstalledBrowsers(),
            configuredIdentities: configuredIdentities,
            supportsLaunchArguments: BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild
        ).map { entry in
            let identity = "\(entry.bundleId)|\(entry.profile ?? "")"
            let appName = AppMetadataCache.shared.displayName(for: entry.bundleId) ?? entry.bundleId
            return Row(
                id: identity,
                name: entry.name,
                bundleId: entry.bundleId,
                profile: entry.profile,
                detail: entry.profile.map { "\(appName) · \($0)" } ?? appName,
                icon: BrowserManager.icon(forBrowserBundleID: entry.bundleId, fallbackURL: entry.iconURL),
                isAlreadyAdded: configuredIdentities.contains(identity)
            )
        }
        let addable = Set(rows.filter { !$0.isAlreadyAdded }.map(\.id))
        selectedIDs.formIntersection(addable)
    }

    // MARK: - Candidate shaping (unit-tested)

    /// Installed entries to offer, including ones that are already configured (the sheet
    /// shows those checked and disabled). Builds that can't pass launch arguments (App
    /// Store) collapse profile variants into one plain entry per app, because a profile
    /// can't be opened there.
    static func sheetRows(
        for source: [BrowserEntry],
        configuredIdentities: Set<String>,
        supportsLaunchArguments: Bool
    ) -> [BrowserEntry] {
        guard !supportsLaunchArguments else { return source }

        var seenBundleIDs: Set<String> = []
        var entries: [BrowserEntry] = []
        for entry in source {
            guard seenBundleIDs.insert(entry.bundleId).inserted else { continue }
            entries.append((
                name: plainBrowserName(from: entry),
                bundleId: entry.bundleId,
                profile: nil,
                iconURL: entry.iconURL
            ))
        }
        return entries
    }

    /// Entries that are not configured yet (the addable subset of `sheetRows`).
    static func browserCandidates(
        for source: [BrowserEntry],
        configuredIdentities: Set<String>,
        supportsLaunchArguments: Bool
    ) -> [BrowserEntry] {
        sheetRows(
            for: source,
            configuredIdentities: configuredIdentities,
            supportsLaunchArguments: supportsLaunchArguments
        ).filter { !configuredIdentities.contains("\($0.bundleId)|\($0.profile ?? "")") }
    }

    private static func plainBrowserName(from entry: BrowserEntry) -> String {
        guard entry.profile != nil,
              let dash = entry.name.range(of: " - ") else {
            return entry.name
        }
        return String(entry.name[..<dash.lowerBound])
    }

    // MARK: - Profile access (App Store sandbox)

    private var profileAccessBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild ? "Find browser profiles" : "Profile names are informational")
                    .font(.callout.weight(.semibold))
                Text(profileAccessMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button("Allow Access…") {
                grantProfileAccess()
            }
            .controlSize(.small)
            .accessibilityIdentifier("settings.addSheet.profileAccess.grantButton")
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var profileAccessMessage: String {
        switch profileAccessStatus {
        case .missing:
            if BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
                return "Allow read-only access to Application Support to list Chrome, Brave, Edge, Vivaldi, Firefox, and Zen profiles."
            }
            return "App Store builds can list profile names after access, but macOS sandboxing opens only the selected browser app."
        case .stale:
            return "The saved profile access permission is stale. Grant access again to refresh this list."
        case .invalid:
            return "The saved profile access permission could not be opened. Grant access again to repair profile discovery."
        case .granted:
            return "Profile access is enabled."
        }
    }

    @MainActor
    private func grantProfileAccess() {
        _ = SandboxBookmarkManager.shared.requestApplicationSupportAccess()
        refreshInstalledBrowsers()
    }
}

private struct AddBrowserOptionLabel: View {
    let row: AddBrowserSheet.Row

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = row.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .lineLimit(1)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if row.isAlreadyAdded {
                Text("Already added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Other App (custom app form)

/// Manual path for apps Chowser doesn't detect as browsers: pick an app bundle with
/// NSOpenPanel (auto-fills name + bundle ID) or type the bundle ID.
struct CustomAppForm: View {
    var manager: BrowserManager
    var onBack: () -> Void
    var onAdded: ([BrowserConfig]) -> Void

    @State private var customName = ""
    @State private var customBundleId = ""
    @State private var customArgs = ""
    @State private var pickedAppIcon: NSImage?
    @State private var errorMessage: String?

    private var trimmedName: String { customName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedBundleId: String { customBundleId.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canAdd: Bool { !trimmedName.isEmpty && !trimmedBundleId.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Other App")
                    .font(.headline)
                Text("Add any app that can open links, even if Chowser doesn't list it as a browser.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.horizontal, .top], 20)

            Form {
                Section {
                    LabeledContent("App") {
                        HStack(spacing: 8) {
                            if let pickedAppIcon {
                                Image(nsImage: pickedAppIcon)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 20, height: 20)
                                    .accessibilityHidden(true)
                            }
                            Button("Choose App…") {
                                pickApp()
                            }
                            .accessibilityIdentifier("settings.addSheet.custom.pickAppButton")
                        }
                    }

                    TextField("Name", text: $customName, prompt: Text("e.g. Arc"))
                        .accessibilityIdentifier("settings.addSheet.custom.nameField")

                    TextField("Bundle ID", text: $customBundleId, prompt: Text("com.example.MyApp"))
                        .font(.body.monospaced())
                        .accessibilityIdentifier("settings.addSheet.custom.bundleIdField")
                } footer: {
                    Text("Choosing an app fills in the name and bundle ID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextField("Launch arguments", text: $customArgs, prompt: Text("Optional"))
                        .font(.body.monospaced())
                        .disabled(!BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)
                        .accessibilityIdentifier("settings.addSheet.custom.argsField")
                } footer: {
                    Text(BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild
                         ? "Placeholders: {url}, {profile}. If {url} is omitted, the link is appended at the end."
                         : "Launch arguments are unavailable in App Store builds because macOS ignores them from sandboxed apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("settings.addSheet.custom.error")
            }

            Divider()

            HStack {
                Button("Back") {
                    onBack()
                }
                .accessibilityIdentifier("settings.addSheet.custom.backButton")

                Spacer()

                Button("Add App") {
                    addApp()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
                .accessibilityIdentifier("settings.addSheet.custom.addButton")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func addApp() {
        let added = manager.addBrowsers([
            BrowserManager.BrowserAddRequest(name: trimmedName, bundleId: trimmedBundleId, profile: nil)
        ])
        guard let browser = added.first else {
            errorMessage = "\(trimmedName) is already in your browser list."
            return
        }

        let args = BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild
            ? customArgs.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        if !args.isEmpty {
            manager.updateBrowserCustomArguments(id: browser.id, to: args)
        }
        onAdded(added)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url) else { return }

        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        if trimmedName.isEmpty { customName = name }
        customBundleId = bundle.bundleIdentifier ?? customBundleId
        pickedAppIcon = NSWorkspace.shared.icon(forFile: url.path)
        errorMessage = nil
    }
}
