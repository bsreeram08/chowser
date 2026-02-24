import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    var browserManager = BrowserManager.shared

    @State private var showingAddSheet = false
    @State private var showingAddRuleSheet = false
    @State private var selectedSection: SettingsSection = .browsers
    @State private var showingResetConfirmation = false
    @State private var browserSearchText = ""
    @State private var ruleSearchText = ""
    @State private var newHiddenBundleId = ""

    private let shortcutOptions = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

    private var hasBrowserSearchQuery: Bool {
        !browserSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasRuleSearchQuery: Bool {
        !ruleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredBrowsers: [BrowserConfig] {
        guard hasBrowserSearchQuery else {
            return browserManager.configuredBrowsers
        }

        let query = browserSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return browserManager.configuredBrowsers.filter {
            $0.name.localizedStandardContains(query) || $0.bundleId.localizedStandardContains(query)
        }
    }

    private var filteredRoutingRules: [BrowserRoutingRule] {
        guard hasRuleSearchQuery else {
            return browserManager.routingRules
        }

        let query = ruleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return browserManager.routingRules.filter { rule in
            let targetBrowser = browserManager.configuredBrowsers.first(where: { $0.bundleId == rule.browserBundleId })?.name ?? ""

            return rule.name.localizedStandardContains(query)
                || rule.hostPattern.localizedStandardContains(query)
                || (rule.pathPrefix ?? "").localizedStandardContains(query)
                || targetBrowser.localizedStandardContains(query)
        }
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case browsers = "Browsers"
        case rules = "Rules"
        case general = "General"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .browsers:
                return "globe"
            case .rules:
                return "line.3.horizontal.decrease.circle"
            case .general:
                return "gearshape"
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .browsers:
                return "settings.sidebar.browsers"
            case .rules:
                return "settings.sidebar.rules"
            case .general:
                return "settings.sidebar.general"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
                    .accessibilityIdentifier(section.accessibilityIdentifier)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .accessibilityIdentifier("settings.sidebar")
        } detail: {
            switch selectedSection {
            case .browsers:
                browsersSection
            case .rules:
                rulesSection
            case .general:
                generalSection
            }
        }
        .frame(width: 900, height: 600)
        .sheet(isPresented: $showingAddSheet) {
            AddBrowserSheet(manager: browserManager, isPresented: $showingAddSheet)
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddRuleSheet(manager: browserManager, isPresented: $showingAddRuleSheet)
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
                    Text("Picker shortcuts use keys 1–9 and support Shift/Option variants. You can also type a browser initial, then press Return.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Menu {
                        Button(action: exportBrowsers) {
                            Label("Export Browsers…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(browserManager.configuredBrowsers.isEmpty)
                        .accessibilityIdentifier("settings.exportBrowsersButton")

                        Button(action: importBrowsers) {
                            Label("Import Browsers…", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("settings.importBrowsersButton")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .accessibilityIdentifier("settings.browsersMenuButton")

                    Button(action: { showingAddSheet = true }) {
                        Label("Add Browser", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .accessibilityIdentifier("settings.addBrowserButton")
                    .accessibilityLabel("Add a new browser to the picker")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            if !browserManager.configuredBrowsers.isEmpty {
                sectionSearchField(
                    placeholder: "Filter browsers by name or bundle ID",
                    text: $browserSearchText,
                    accessibilityIdentifier: "settings.browser.searchField"
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

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
                    if hasBrowserSearchQuery {
                        ForEach(filteredBrowsers) { browser in
                            browserConfigRow(browser: browser)
                                .id(browser.id)
                        }
                        .onDelete(perform: removeFilteredBrowsers)
                    } else {
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
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .animation(.easeInOut(duration: 0.2), value: browserManager.configuredBrowsers)
                .accessibilityIdentifier("settings.browserList")
            }

            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)

                Text(hasBrowserSearchQuery
                 ? "Clear search to drag reorder • Use 1–9, initials, or Tab/↑/↓ + Return in picker"
                 : "Drag to reorder • Use 1–9, initials, or Tab/↑/↓ + Return in picker")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private func browserConfigRow(browser: BrowserConfig) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                browserIconView(bundleID: browser.bundleId)
                browserIdentityView(browser: browser)
                Spacer()
                browserShortcutPicker(browser: browser)
                deleteBrowserButton(browser: browser)
            }
            .padding(.vertical, 4)
            
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Launch Arguments")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    TextField("--profile-directory={profile} {url}", text: browserCustomArgumentsBinding(for: browser.id))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    
                    Text("Placeholders: {profile}, {url}. Defaults used if empty.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 40)
                .padding(.vertical, 4)
            } label: {
                Text("Advanced")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 40)
        }
        .contextMenu {
            Button("Move Up") {
                moveBrowser(id: browser.id, by: -1)
            }
            .disabled(hasBrowserSearchQuery || !canMoveBrowser(id: browser.id, by: -1))

            Button("Move Down") {
                moveBrowser(id: browser.id, by: 1)
            }
            .disabled(hasBrowserSearchQuery || !canMoveBrowser(id: browser.id, by: 1))

            Divider()

            Button("Remove Browser", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    browserManager.removeBrowser(id: browser.id)
                }
            }
        }
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

    private func browserCustomArgumentsBinding(for browserID: UUID) -> Binding<String> {
        Binding(
            get: { browserManager.configuredBrowsers.first(where: { $0.id == browserID })?.customArguments ?? "" },
            set: { browserManager.updateBrowserCustomArguments(id: browserID, to: $0) }
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

            if let profile = browser.profile {
                Text("\(browser.bundleId) (\(profile))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                Text(browser.bundleId)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func browserShortcutPicker(browser: BrowserConfig) -> some View {
        let shortcutBinding = browserShortcutBinding(for: browser.id)

        return HStack(spacing: 4) {
            Text("Key")
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
            .accessibilityLabel("Shortcut key for \(browser.name)")
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

    // MARK: - Rules Section

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rules")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Automatically route links by domain and optional path prefix.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        rulesStatusBadge(title: "\(browserManager.routingRules.count) Total", color: .secondary)
                        rulesStatusBadge(
                            title: "\(activeRoutingRulesCount) Active",
                            color: activeRoutingRulesCount > 0 ? .green : .secondary
                        )
                    }
                    .padding(.top, 4)
                }

                Spacer()

                HStack(spacing: 8) {
                    Menu {
                        Button(action: exportRules) {
                            Label("Export Rules…", systemImage: "square.and.arrow.up")
                        }
                        .disabled(browserManager.routingRules.isEmpty)
                        .accessibilityIdentifier("settings.exportRulesButton")

                        Button(action: importRules) {
                            Label("Import Rules…", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("settings.importRulesButton")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                    .accessibilityIdentifier("settings.rulesMenuButton")

                    Button(action: { showingAddRuleSheet = true }) {
                        Label("Add Rule", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .disabled(browserManager.configuredBrowsers.isEmpty)
                    .accessibilityIdentifier("settings.addRuleButton")
                    .accessibilityLabel("Add a new routing rule")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            if !browserManager.configuredBrowsers.isEmpty && !browserManager.routingRules.isEmpty {
                sectionSearchField(
                    placeholder: "Filter rules by name, host, path, or browser",
                    text: $ruleSearchText,
                    accessibilityIdentifier: "settings.rule.searchField"
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

            if browserManager.configuredBrowsers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text("Add at least one browser first")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Routing rules need a target browser. Configure browsers in the Browsers tab.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if browserManager.routingRules.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No routing rules yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Create a rule like *.github.com → Arc.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button("Add Rule") {
                        showingAddRuleSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.emptyRules.addRuleButton")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if hasRuleSearchQuery {
                        ForEach(filteredRoutingRules) { rule in
                            RuleRowView(rule: rule, browserManager: browserManager, hasSearchQuery: true)
                        }
                        .onDelete(perform: removeFilteredRules)
                    } else {
                        ForEach(browserManager.routingRules) { rule in
                            RuleRowView(rule: rule, browserManager: browserManager, hasSearchQuery: false)
                        }
                        .onMove { indices, destination in
                            browserManager.moveRoutingRules(from: indices, to: destination)
                        }
                        .onDelete { indices in
                            browserManager.removeRoutingRules(at: indices)
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .accessibilityIdentifier("settings.rulesList")
            }

            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
                Text(hasRuleSearchQuery
                     ? "Clear search to drag reorder rules. First enabled match opens directly in the selected browser."
                     : "Rules are evaluated top-to-bottom. First enabled match opens directly in the selected browser.")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private var activeRoutingRulesCount: Int {
        browserManager.routingRules.filter(\.isEnabled).count
    }

    private func rulesStatusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Import / Export

    private func exportRules() {
        let panel = NSSavePanel()
        panel.title = "Export Routing Rules"
        panel.nameFieldStringValue = "ChowserRules.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.exportRules(to: url)
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }

    private func importRules() {
        let panel = NSOpenPanel()
        panel.title = "Import Routing Rules"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.importRules(from: url)
        } catch {
            print("Import failed: \(error.localizedDescription)")
        }
    }

    private func exportBrowsers() {
        let panel = NSSavePanel()
        panel.title = "Export Browser Configuration"
        panel.nameFieldStringValue = "ChowserBrowsers.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.exportBrowsers(to: url)
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }

    private func importBrowsers() {
        let panel = NSOpenPanel()
        panel.title = "Import Browser Configuration"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.importBrowsers(from: url)
        } catch {
            print("Import failed: \(error.localizedDescription)")
        }
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apps registered as URL handlers that you don't want in the browser list.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        if browserManager.hiddenBundleIDs.isEmpty {
                            Text("No hidden apps.")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(browserManager.hiddenBundleIDs.sorted()), id: \.self) { bundleId in
                                HStack {
                                    Text(bundleId)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Button {
                                        browserManager.removeHiddenBundleID(bundleId)
                                    } label: {
                                        Image(systemName: "eye")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Show this app in the browser list")
                                }
                            }
                        }

                        Divider()

                        HStack(spacing: 8) {
                            TextField("Bundle ID (e.g. com.example.app)", text: $newHiddenBundleId)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))

                            Button("Hide") {
                                let trimmed = newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                browserManager.addHiddenBundleID(trimmed)
                                newHiddenBundleId = ""
                            }
                            .disabled(newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        Button("Reset to Defaults") {
                            browserManager.resetHiddenBundleIDs()
                        }
                        .font(.system(size: 11))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Hidden Apps")
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

    private func sectionSearchField(
        placeholder: String,
        text: Binding<String>,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.12))
        )
    }

    private func removeFilteredBrowsers(at offsets: IndexSet) {
        var idsToRemove: [UUID] = []
        for offset in offsets where filteredBrowsers.indices.contains(offset) {
            idsToRemove.append(filteredBrowsers[offset].id)
        }

        for id in idsToRemove {
            browserManager.removeBrowser(id: id)
        }
    }

    private func removeFilteredRules(at offsets: IndexSet) {
        var idsToRemove: [UUID] = []
        for offset in offsets where filteredRoutingRules.indices.contains(offset) {
            idsToRemove.append(filteredRoutingRules[offset].id)
        }

        for id in idsToRemove {
            browserManager.removeRoutingRule(id: id)
        }
    }

    private func canMoveBrowser(id: UUID, by delta: Int) -> Bool {
        guard let currentIndex = browserManager.configuredBrowsers.firstIndex(where: { $0.id == id }) else {
            return false
        }

        let destinationIndex = currentIndex + delta
        return destinationIndex >= 0 && destinationIndex < browserManager.configuredBrowsers.count
    }

    private func moveBrowser(id: UUID, by delta: Int) {
        guard canMoveBrowser(id: id, by: delta),
              let currentIndex = browserManager.configuredBrowsers.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex = currentIndex + delta
        let destinationOffset = delta > 0 ? destinationIndex + 1 : destinationIndex
        browserManager.moveBrowsers(from: IndexSet(integer: currentIndex), to: destinationOffset)
    }

    private func getAppIcon(bundleId: String) -> NSImage? {
        BrowserManager.icon(forBrowserBundleID: bundleId)
    }
}

// MARK: - Rule Row View

private struct RuleRowView: View {
    let rule: BrowserRoutingRule
    var browserManager: BrowserManager
    let hasSearchQuery: Bool

    @State private var editingName: String
    @State private var editingHost: String
    @State private var editingPath: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, host, path
    }

    init(rule: BrowserRoutingRule, browserManager: BrowserManager, hasSearchQuery: Bool) {
        self.rule = rule
        self.browserManager = browserManager
        self.hasSearchQuery = hasSearchQuery
        self._editingName = State(initialValue: rule.name)
        self._editingHost = State(initialValue: rule.hostPattern)
        self._editingPath = State(initialValue: rule.pathPrefix ?? "")
    }

    private var hostPatternIsValid: Bool {
        browserManager.isValidRoutingHostPattern(editingHost)
    }

    private var matchSummary: String {
        let pathText = (rule.pathPrefix?.isEmpty == false) ? " + path \(rule.pathPrefix!)" : ""
        let statusText = rule.isEnabled ? "Enabled" : "Disabled"
        return "\(statusText): host \(rule.hostPattern)\(pathText)"
    }

    private var browserIdentity: Binding<String> {
        Binding(
            get: {
                let identity = "\(rule.browserBundleId)|\(rule.profile ?? "")"
                if browserManager.configuredBrowsers.contains(where: { $0.identity == identity }) {
                    return identity
                }
                return browserManager.configuredBrowsers.first?.identity ?? ""
            },
            set: { newValue in
                if let browser = browserManager.configuredBrowsers.first(where: { $0.identity == newValue }) {
                    browserManager.updateRoutingRuleBrowser(id: rule.id, to: browser.bundleId, profile: browser.profile)
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { browserManager.updateRoutingRuleIsEnabled(id: rule.id, to: $0) }
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
                            ForEach(browserManager.configuredBrowsers) { browser in
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

                Text(matchSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, -4)
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    browserManager.removeRoutingRule(id: rule.id)
                }
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
            Button("Move Up") {
                moveRule(by: -1)
            }
            .disabled(hasSearchQuery || !canMoveRule(by: -1))

            Button("Move Down") {
                moveRule(by: 1)
            }
            .disabled(hasSearchQuery || !canMoveRule(by: 1))

            Button("Duplicate Rule") {
                browserManager.duplicateRoutingRule(id: rule.id)
            }

            Divider()

            Button("Remove Rule", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    browserManager.removeRoutingRule(id: rule.id)
                }
            }
        }
    }

    private func commitField(_ field: Field) {
        switch field {
        case .name:
            browserManager.updateRoutingRuleName(id: rule.id, to: editingName)
        case .host:
            browserManager.updateRoutingRuleHostPattern(id: rule.id, to: editingHost)
        case .path:
            browserManager.updateRoutingRulePathPrefix(id: rule.id, to: editingPath)
        }
    }

    private func canMoveRule(by delta: Int) -> Bool {
        guard let currentIndex = browserManager.routingRules.firstIndex(where: { $0.id == rule.id }) else {
            return false
        }
        let destinationIndex = currentIndex + delta
        return destinationIndex >= 0 && destinationIndex < browserManager.routingRules.count
    }

    private func moveRule(by delta: Int) {
        guard let currentIndex = browserManager.routingRules.firstIndex(where: { $0.id == rule.id }) else {
            return
        }
        let destinationIndex = currentIndex + delta
        let destinationOffset = delta > 0 ? destinationIndex + 1 : destinationIndex
        browserManager.moveRoutingRules(from: IndexSet(integer: currentIndex), to: destinationOffset)
    }
}

// MARK: - Add Browser Sheet

struct AddBrowserSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

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

            Divider()
            AddCustomAppSection(manager: manager, isPresented: $isPresented)
        }
        .frame(width: 420, height: 500)
        .onAppear {
            availableBrowsers = BrowserManager.getInstalledBrowsers()
            allBrowsersIncludingHidden = BrowserManager.getInstalledBrowsers(includeHidden: true)
        }
        .accessibilityIdentifier("settings.addSheet.root")
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
                    // Refresh the lists
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

// MARK: - Add Custom App Section (inside AddBrowserSheet)

private struct AddCustomAppSection: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var isExpanded = false
    @State private var customName = ""
    @State private var customBundleId = ""
    @State private var customArgs = ""
    @State private var pickedAppIcon: NSImage? = nil

    private var canAdd: Bool {
        !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !customBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                // App picker row
                HStack(spacing: 8) {
                    Group {
                        if let icon = pickedAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 20))
                                .foregroundStyle(.quaternary)
                                .frame(width: 28, height: 28)
                        }
                    }

                    Button("Choose App…") {
                        pickApp()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.addSheet.custom.pickAppButton")

                    Text("or fill in manually below")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                // Name field
                VStack(alignment: .leading, spacing: 3) {
                    Text("Display Name")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Arc, Kagi, MyApp", text: $customName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .accessibilityIdentifier("settings.addSheet.custom.nameField")
                }

                // Bundle ID field
                VStack(alignment: .leading, spacing: 3) {
                    Text("Bundle ID")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("com.example.MyApp", text: $customBundleId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .accessibilityIdentifier("settings.addSheet.custom.bundleIdField")
                    Text("Found in Info.plist or via: mdls -name kMDItemCFBundleIdentifier /Applications/MyApp.app")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Custom args field
                VStack(alignment: .leading, spacing: 3) {
                    Text("Custom Launch Arguments (Optional)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("--profile-directory={profile} {url}", text: $customArgs)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .accessibilityIdentifier("settings.addSheet.custom.argsField")
                    Text("Placeholders: {url}, {profile}. If omitted, URL is appended at the end.")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                // Add button
                HStack {
                    Spacer()
                    Button("Add Custom App") {
                        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let bundleId = customBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
                        let args = customArgs.trimmingCharacters(in: .whitespacesAndNewlines)

                        manager.addBrowser(name: name, bundleId: bundleId)
                        // Apply custom args if provided
                        if !args.isEmpty, let id = manager.configuredBrowsers.last(where: { $0.bundleId == bundleId })?.id {
                            manager.updateBrowserCustomArguments(id: id, to: args)
                        }
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canAdd)
                    .accessibilityIdentifier("settings.addSheet.custom.addButton")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.square.dashed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Add custom app not in list above")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .disclosureGroupStyle(PlainDisclosureStyle())
        .padding(.bottom, 4)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Auto-fill name + bundle ID from the app bundle
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

private struct PlainDisclosureStyle: DisclosureGroupStyle {
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

struct AddRuleSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var ruleName = ""
    @State private var hostPattern = ""
    @State private var pathPrefix = ""
    @State private var selectedBrowserIdentity = ""

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
                        profile: browser.profile
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

#Preview {
    SettingsView()
}
