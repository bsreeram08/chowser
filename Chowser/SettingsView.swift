import SwiftUI
import AppKit

struct SettingsView: View {
    var browserManager = BrowserManager.shared

    @State private var showingAddSheet = false
    @State private var selectedSection: SettingsSection = .browsers
    @State private var showingResetConfirmation = false

    private let shortcutOptions = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

    enum SettingsSection: String, CaseIterable, Identifiable {
        case browsers = "Browsers"
        case general = "General"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .browsers:
                return "globe"
            case .general:
                return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
                    .accessibilityIdentifier(section == .browsers ? "settings.sidebar.browsers" : "settings.sidebar.general")
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .accessibilityIdentifier("settings.sidebar")
        } detail: {
            switch selectedSection {
            case .browsers:
                browsersSection
            case .general:
                generalSection
            }
        }
        .frame(width: 640, height: 460)
        .sheet(isPresented: $showingAddSheet) {
            AddBrowserSheet(manager: browserManager, isPresented: $showingAddSheet)
        }
        .alert("Reset Chowser setup?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                browserManager.resetToFreshSetup()
                selectedSection = .browsers
            }
        } message: {
            Text("This restores browser configuration to the first-launch state with Safari as option 1.")
        }
        .accessibilityIdentifier("settings.root")
    }

    // MARK: - Browsers Section

    private var browsersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Browsers")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Configure which browsers appear in the picker.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("Add Browser", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("settings.addBrowserButton")
                .accessibilityLabel("Add a new browser to the picker")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            if browserManager.configuredBrowsers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("No browsers configured")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Add one manually or restore the default setup.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Button("Restore Default Browser") {
                        browserManager.restoreDefaultBrowserList()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.restoreDefaultButton")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(browserManager.configuredBrowsers) { browser in
                        browserConfigRow(browser: browser)
                            .id(browser.id)
                    }
                    .onMove { indices, destination in
                        browserManager.moveBrowsers(from: indices, to: destination)
                    }
                    .onDelete { indices in
                        browserManager.removeBrowsers(at: indices)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .animation(.easeInOut(duration: 0.2), value: browserManager.configuredBrowsers)
                .accessibilityIdentifier("settings.browserList")
            }

            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
                Text("Drag to reorder • Order determines picker layout")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private func browserConfigRow(browser: BrowserConfig) -> some View {
        return HStack(spacing: 12) {
            browserIconView(bundleID: browser.bundleId)
            browserIdentityView(browser: browser)
            Spacer()
            browserShortcutPicker(browser: browser)
            deleteBrowserButton(browser: browser)
        }
        .padding(.vertical, 4)
    }

    private func browserNameBinding(for browserID: UUID) -> Binding<String> {
        Binding(
            get: { browserManager.browserName(for: browserID) },
            set: { browserManager.updateBrowserName(id: browserID, to: $0) }
        )
    }

    private func browserShortcutBinding(for browserID: UUID) -> Binding<String> {
        Binding(
            get: { browserManager.shortcutKey(for: browserID) },
            set: { browserManager.updateShortcutKey(id: browserID, to: $0) }
        )
    }

    @ViewBuilder
    private func browserIconView(bundleID: String) -> some View {
        if let icon = getAppIcon(bundleId: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
        }
    }

    private func browserIdentityView(browser: BrowserConfig) -> some View {
        let nameBinding = browserNameBinding(for: browser.id)

        return VStack(alignment: .leading, spacing: 2) {
            TextField("Name", text: nameBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .accessibilityIdentifier("settings.browser.nameField")

            Text(browser.bundleId)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private func browserShortcutPicker(browser: BrowserConfig) -> some View {
        let shortcutBinding = browserShortcutBinding(for: browser.id)

        return HStack(spacing: 4) {
            Text("⌘ ⇧")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Picker("", selection: shortcutBinding) {
                ForEach(shortcutOptions, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 50)
            .labelsHidden()
            .accessibilityIdentifier("settings.browser.shortcutPicker")
            .accessibilityLabel("Keyboard shortcut number for \(browser.name)")
        }
    }

    private func deleteBrowserButton(browser: BrowserConfig) -> some View {
        Button(role: .destructive) {
            withAnimation(.easeInOut(duration: 0.2)) {
                browserManager.removeBrowser(id: browser.id)
            }
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(.red.opacity(0.75))
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("settings.browser.deleteButton")
        .accessibilityLabel("Remove \(browser.name)")
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("General")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("App behavior and system integration.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            Form {
                @Bindable var manager = browserManager

                Section {
                    Toggle("Launch Chowser at login", isOn: $manager.launchAtLogin)
                        .accessibilityHint("When enabled, Chowser starts automatically when you log in")
                } header: {
                    Text("Startup")
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Browser")
                                .font(.system(size: 13))

                            if BrowserManager.isDefaultBrowser() {
                                Text("Chowser is your default browser ✓")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.green)
                            } else {
                                Text("Another app is set as default")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Set as Default") {
                            BrowserManager.setAsDefaultBrowser()
                        }
                        .disabled(BrowserManager.isDefaultBrowser())
                        .accessibilityLabel("Set Chowser as the default browser")
                    }
                } header: {
                    Text("System")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reset Chowser setup to a clean state.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Button("Reset to Fresh Setup…", role: .destructive) {
                            showingResetConfirmation = true
                        }
                        .accessibilityIdentifier("settings.resetButton")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Maintenance")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Replay onboarding and installation guidance.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Button("Open Onboarding") {
                            NotificationCenter.default.post(name: Notification.Name("openOnboardingWindow"), object: nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                        .accessibilityIdentifier("settings.openOnboardingButton")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Setup")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(nsImage: BrowserManager.currentAppIcon())
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Chowser")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("A browser chooser for macOS")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("Version \(appVersion)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About")
                }
            }
            .formStyle(.grouped)
        }
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    // MARK: - Helpers

    private func getAppIcon(bundleId: String) -> NSImage? {
        BrowserManager.icon(forBrowserBundleID: bundleId)
    }
}

// MARK: - Add Browser Sheet

struct AddBrowserSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var availableBrowsers: [(name: String, bundleId: String, iconURL: URL?)] = []
    @State private var hoveredBundleID: String?
    @State private var searchText = ""

    private var filteredBrowsers: [(name: String, bundleId: String, iconURL: URL?)] {
        let configuredIDs = Set(manager.configuredBrowsers.map(\.bundleId))

        let candidates = availableBrowsers.filter { !configuredIDs.contains($0.bundleId) }
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return candidates
        }

        return candidates.filter {
            $0.name.localizedStandardContains(trimmedQuery) ||
            $0.bundleId.localizedStandardContains(trimmedQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search installed browsers", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .accessibilityIdentifier("settings.addSheet.searchField")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary.opacity(0.12))
            )
            .padding(12)

            if filteredBrowsers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                    Text(searchText.isEmpty ? "All installed browsers are configured" : "No matching browsers")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredBrowsers, id: \.bundleId) { entry in
                            browserOption(entry: entry)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 420, height: 420)
        .onAppear {
            availableBrowsers = BrowserManager.getInstalledBrowsers()
        }
        .accessibilityIdentifier("settings.addSheet.root")
    }

    private func browserOption(entry: (name: String, bundleId: String, iconURL: URL?)) -> some View {
        let isHovered = hoveredBundleID == entry.bundleId

        return Button(action: {
            manager.addBrowser(
                name: entry.name,
                bundleId: entry.bundleId,
                shortcutKey: manager.nextAvailableShortcutKey()
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
                        .foregroundStyle(.primary)
                    Text(entry.bundleId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                    .opacity(isHovered ? 1.0 : 0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? .white.opacity(0.08) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredBundleID = hovering ? entry.bundleId : nil
            }
        }
        .accessibilityIdentifier("settings.addSheet.option")
        .accessibilityLabel("Add \(entry.name)")
        .accessibilityHint("Adds \(entry.name) to the browser picker")
    }
}

#Preview {
    SettingsView()
}
