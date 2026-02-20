import SwiftUI
import AppKit

struct SettingsView: View {
    var browserManager = BrowserManager.shared

    @State private var showingAddSheet = false
    @State private var showingAddRuleSheet = false
    @State private var selectedSection: SettingsSection = .browsers
    @State private var showingResetConfirmation = false
    @State private var ruleTestInput = ""
    @State private var browserSearchText = ""
    @State private var ruleSearchText = ""

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
        .frame(width: 640, height: 460)
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
        HStack(spacing: 12) {
            browserIconView(bundleID: browser.bundleId)
            browserIdentityView(browser: browser)
            Spacer()
            browserShortcutPicker(browser: browser)
            deleteBrowserButton(browser: browser)
        }
        .padding(.vertical, 4)
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

                Button(action: { showingAddRuleSheet = true }) {
                    Label("Add Rule", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .disabled(browserManager.configuredBrowsers.isEmpty)
                .accessibilityIdentifier("settings.addRuleButton")
                .accessibilityLabel("Add a new routing rule")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            if !browserManager.configuredBrowsers.isEmpty {
                ruleDiagnosticsPanel
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

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
                            ruleRow(rule: rule)
                                .id(rule.id)
                        }
                        .onDelete(perform: removeFilteredRules)
                    } else {
                        ForEach(browserManager.routingRules) { rule in
                            ruleRow(rule: rule)
                                .id(rule.id)
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
                .animation(.easeInOut(duration: 0.2), value: browserManager.routingRules)
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

    private var ruleDiagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Route Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            TextField("Try a URL (for example: github.com/orgs/openai)", text: $ruleTestInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .accessibilityIdentifier("settings.rules.previewURLField")

            Group {
                if let previewURL = parsedRulePreviewURL {
                    if let route = browserManager.resolvedRoute(for: previewURL) {
                        Label(
                            "Matches “\(route.rule.name)” → opens in \(route.browser.name)",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                    } else {
                        Label("No rule matched. Chowser will show the picker.", systemImage: "circle.dashed")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label("Enter a URL to preview routing.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 11))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.08))
        )
    }

    private var parsedRulePreviewURL: URL? {
        let trimmedInput = ruleTestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }

        if let explicitURL = URL(string: trimmedInput), explicitURL.scheme != nil {
            return explicitURL
        }

        return URL(string: "https://\(trimmedInput)")
    }

    private func rulesStatusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func ruleRow(rule: BrowserRoutingRule) -> some View {
        let hostPatternIsValid = browserManager.isValidRoutingHostPattern(rule.hostPattern)

        return HStack(spacing: 10) {
            Toggle("", isOn: ruleEnabledBinding(for: rule.id))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel("Enable rule \(rule.name)")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    TextField("Rule name", text: ruleNameBinding(for: rule.id))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, weight: .medium))
                        .accessibilityIdentifier("settings.rule.nameField")

                    Picker("Browser", selection: ruleBrowserBinding(for: rule.id)) {
                        ForEach(browserManager.configuredBrowsers) { browser in
                            Text(browser.name).tag(browser.bundleId)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .accessibilityIdentifier("settings.rule.browserPicker")
                    .accessibilityLabel("Target browser")
                }

                HStack(spacing: 8) {
                    TextField("Host pattern (example.com or *.example.com)", text: ruleHostBinding(for: rule.id))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .accessibilityIdentifier("settings.rule.hostField")

                    TextField("Path prefix (optional)", text: rulePathPrefixBinding(for: rule.id))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 170)
                        .accessibilityIdentifier("settings.rule.pathField")
                }

                if !hostPatternIsValid {
                    Label("Invalid host pattern. Use example.com or *.example.com", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }

                Text(ruleMatchSummary(rule))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

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
        .padding(.vertical, 4)
        .contextMenu {
            Button("Move Up") {
                moveRoutingRule(id: rule.id, by: -1)
            }
            .disabled(hasRuleSearchQuery || !canMoveRoutingRule(id: rule.id, by: -1))

            Button("Move Down") {
                moveRoutingRule(id: rule.id, by: 1)
            }
            .disabled(hasRuleSearchQuery || !canMoveRoutingRule(id: rule.id, by: 1))

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

    private func ruleNameBinding(for ruleID: UUID) -> Binding<String> {
        Binding(
            get: { browserManager.routingRuleName(for: ruleID) },
            set: { browserManager.updateRoutingRuleName(id: ruleID, to: $0) }
        )
    }

    private func ruleHostBinding(for ruleID: UUID) -> Binding<String> {
        Binding(
            get: { browserManager.routingRuleHostPattern(for: ruleID) },
            set: { browserManager.updateRoutingRuleHostPattern(id: ruleID, to: $0) }
        )
    }

    private func rulePathPrefixBinding(for ruleID: UUID) -> Binding<String> {
        Binding(
            get: { browserManager.routingRulePathPrefix(for: ruleID) },
            set: { browserManager.updateRoutingRulePathPrefix(id: ruleID, to: $0) }
        )
    }

    private func ruleBrowserBinding(for ruleID: UUID) -> Binding<String> {
        Binding(
            get: {
                let current = browserManager.routingRuleBrowserBundleID(for: ruleID)
                if !current.isEmpty {
                    return current
                }
                return browserManager.configuredBrowsers.first?.bundleId ?? ""
            },
            set: { browserManager.updateRoutingRuleBrowser(id: ruleID, to: $0) }
        )
    }

    private func ruleEnabledBinding(for ruleID: UUID) -> Binding<Bool> {
        Binding(
            get: { browserManager.routingRuleIsEnabled(for: ruleID) },
            set: { browserManager.updateRoutingRuleIsEnabled(id: ruleID, to: $0) }
        )
    }

    private func ruleMatchSummary(_ rule: BrowserRoutingRule) -> String {
        let pathText: String
        if let pathPrefix = rule.pathPrefix, !pathPrefix.isEmpty {
            pathText = " + path \(pathPrefix)"
        } else {
            pathText = ""
        }
        let statusText = rule.isEnabled ? "Enabled" : "Disabled"
        return "\(statusText): host \(rule.hostPattern)\(pathText)"
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

    private func canMoveRoutingRule(id: UUID, by delta: Int) -> Bool {
        guard let currentIndex = browserManager.routingRules.firstIndex(where: { $0.id == id }) else {
            return false
        }

        let destinationIndex = currentIndex + delta
        return destinationIndex >= 0 && destinationIndex < browserManager.routingRules.count
    }

    private func moveRoutingRule(id: UUID, by delta: Int) {
        guard canMoveRoutingRule(id: id, by: delta),
              let currentIndex = browserManager.routingRules.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex = currentIndex + delta
        let destinationOffset = delta > 0 ? destinationIndex + 1 : destinationIndex
        browserManager.moveRoutingRules(from: IndexSet(integer: currentIndex), to: destinationOffset)
    }

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

struct AddRuleSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool

    @State private var ruleName = ""
    @State private var hostPattern = ""
    @State private var pathPrefix = ""
    @State private var selectedBrowserBundleID = ""

    private var hostPatternIsValid: Bool {
        manager.isValidRoutingHostPattern(hostPattern)
    }

    private var canCreateRule: Bool {
        hostPatternIsValid && !selectedBrowserBundleID.isEmpty
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
            if selectedBrowserBundleID.isEmpty {
                selectedBrowserBundleID = manager.configuredBrowsers.first?.bundleId ?? ""
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

            Picker("Browser", selection: $selectedBrowserBundleID) {
                ForEach(manager.configuredBrowsers) { browser in
                    Text(browser.name).tag(browser.bundleId)
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
                manager.addRoutingRule(
                    name: ruleName,
                    hostPattern: hostPattern,
                    pathPrefix: pathPrefix,
                    browserBundleId: selectedBrowserBundleID
                )
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
