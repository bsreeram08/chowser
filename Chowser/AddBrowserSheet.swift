import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AddBrowserSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    enum SheetTab: String, CaseIterable {
        case installed = "Installed Apps"
        case custom = "Custom App"
    }

    @State private var activeTab: SheetTab = .installed
    @State private var availableBrowsers: [(name: String, bundleId: String, profile: String?, iconURL: URL?)] = []
    @State private var allBrowsersIncludingHidden: [(name: String, bundleId: String, profile: String?, iconURL: URL?)] = []
    @State private var hoveredIdentity: String?
    @State private var searchText = ""
    @State private var showHiddenApps = false

    private var filteredBrowsers: [(name: String, bundleId: String, profile: String?, iconURL: URL?)] {
        let configuredIdentities = Set(manager.configuredBrowsers.map { "\($0.bundleId)|\($0.profile ?? "")" })
        let source = showHiddenApps ? allBrowsersIncludingHidden : availableBrowsers
        let candidates = source.filter { !configuredIdentities.contains("\($0.bundleId)|\($0.profile ?? "")") }
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return candidates }
        return candidates.filter {
            $0.name.localizedStandardContains(trimmedQuery) ||
            $0.bundleId.localizedStandardContains(trimmedQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Browser")
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

            // Tab switcher
            Picker("", selection: $activeTab) {
                ForEach(SheetTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()

            // Content
            switch activeTab {
            case .installed:
                installedAppsContent
            case .custom:
                CustomAppForm(manager: manager, isPresented: $isPresented)
            }
        }
        .frame(width: 440, height: 520)
        .onAppear {
            availableBrowsers = BrowserManager.getInstalledBrowsers()
            allBrowsersIncludingHidden = BrowserManager.getInstalledBrowsers(includeHidden: true)
        }
        .accessibilityIdentifier("settings.addSheet.root")
    }

    // MARK: - Installed Apps Tab

    @ViewBuilder
    private var installedAppsContent: some View {
        VStack(spacing: 0) {
            // Search + hidden toggle
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search installed browsers", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .accessibilityIdentifier("settings.addSheet.searchField")

                Toggle("Show hidden", isOn: $showHiddenApps)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 10))
                    .accessibilityIdentifier("settings.addSheet.showHiddenToggle")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary.opacity(0.12))
            )
            .padding(12)

            if filteredBrowsers.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                    Text("All installed browsers are configured")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Use the \"Custom App\" tab to add any other app.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredBrowsers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No matching browsers")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        let items = filteredBrowsers
                        ForEach(items.indices, id: \.self) { index in
                            let entry = items[index]
                            let isHidden = manager.hiddenBundleIDs.contains(entry.bundleId)
                            browserOption(entry: entry, isHidden: isHidden)
                                .id("\(entry.bundleId)|\(entry.profile ?? "")")
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func browserOption(entry: (name: String, bundleId: String, profile: String?, iconURL: URL?), isHidden: Bool = false) -> some View {
        let identifier = "\(entry.bundleId)|\(entry.profile ?? "")"
        let isHovered = hoveredIdentity == identifier

        return HStack(spacing: 0) {
            Button(action: {
                manager.addBrowser(
                    name: entry.name,
                    bundleId: entry.bundleId,
                    shortcutKey: manager.nextAvailableShortcutKey(),
                    profile: entry.profile
                )
                isPresented = false
            }) {
                HStack(spacing: 12) {
                    if let icon = BrowserManager.icon(forBrowserBundleID: entry.bundleId, fallbackURL: entry.iconURL) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isHidden ? .secondary : .primary)

                        if let profile = entry.profile {
                            Text("\(entry.bundleId) (\(profile))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(entry.bundleId)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                        .opacity(isHovered ? 1.0 : 0.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if showHiddenApps {
                Button {
                    if isHidden {
                        manager.removeHiddenBundleID(entry.bundleId)
                    } else {
                        manager.addHiddenBundleID(entry.bundleId)
                    }
                    availableBrowsers = BrowserManager.getInstalledBrowsers()
                    allBrowsersIncludingHidden = BrowserManager.getInstalledBrowsers(includeHidden: true)
                } label: {
                    Image(systemName: isHidden ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundStyle(isHidden ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(isHidden ? "Unhide from browser list" : "Hide from browser list")
                .padding(.trailing, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? .white.opacity(0.08) : .clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredIdentity = hovering ? identifier : nil
            }
        }
        .accessibilityIdentifier("settings.addSheet.option")
        .accessibilityLabel("Add \(entry.name)")
        .accessibilityHint("Adds \(entry.name) to the browser picker")
    }
}

// MARK: - Custom App Form

struct CustomAppForm: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var customName = ""
    @State private var customBundleId = ""
    @State private var customArgs = ""
    @State private var pickedAppIcon: NSImage? = nil

    private var canAdd: Bool {
        !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !customBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // App picker row
                HStack(spacing: 12) {
                    Group {
                        if let icon = pickedAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 36, height: 36)
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.quaternary.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "app.dashed")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.quaternary)
                                )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Button("Choose App…") {
                            pickApp()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("settings.addSheet.custom.pickAppButton")

                        Text("Auto-fills name and bundle ID from the app bundle.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                // Name field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Name")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Arc, Kagi, MyApp", text: $customName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .accessibilityIdentifier("settings.addSheet.custom.nameField")
                }

                // Bundle ID field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bundle ID")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("com.example.MyApp", text: $customBundleId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .accessibilityIdentifier("settings.addSheet.custom.bundleIdField")
                    Text("Run in Terminal: mdls -name kMDItemCFBundleIdentifier /Applications/MyApp.app")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Custom args field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Launch Arguments")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Optional — e.g. --profile-directory={profile} {url}", text: $customArgs)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .accessibilityIdentifier("settings.addSheet.custom.argsField")
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
            Button("Cancel") { isPresented = false }
                .buttonStyle(.bordered)

            Spacer()

            Button("Add App") {
                let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                let bundleId = customBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
                let args = customArgs.trimmingCharacters(in: .whitespacesAndNewlines)

                manager.addBrowser(name: name, bundleId: bundleId)
                if !args.isEmpty, let id = manager.configuredBrowsers.last(where: { $0.bundleId == bundleId })?.id {
                    manager.updateBrowserCustomArguments(id: id, to: args)
                }
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdd)
            .accessibilityIdentifier("settings.addSheet.custom.addButton")
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if let bundle = Bundle(url: url) {
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            if customName.isEmpty { customName = name }
            customBundleId = bundle.bundleIdentifier ?? customBundleId
            pickedAppIcon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}

// MARK: - Plain Disclosure Style (used elsewhere)

struct PlainDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    configuration.label
                    Spacer()
                    Image(systemName: configuration.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 16)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
