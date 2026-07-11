import SwiftUI
import AppKit

struct SettingsView: View {
    @State var browserManager = BrowserManager.shared

    @State var showingAddSheet = false
    @State var showingAddRuleSheet = false
    @State var currentPrefillURL: URL?
    @State var selectedSection: SettingsSection = .browsers
    @State var showingResetConfirmation = false
    @State var browserSearchText = ""
    @State var ruleSearchText = ""
    @State var rewriteSearchText = ""
    @State var newHiddenBundleId = ""
    @State var newShortenerHost = ""
    @State var browserToEdit: BrowserConfig?
    @State var selectedRuleId: UUID?
    @State var preselectedRuleBrowserIdentity: String?
    @State var showingRuleMergeReview = false
    @State var showingAddRewriteSheet = false
    @State var profileAccessStatus = SandboxBookmarkManager.shared.grantStatus
    @State var operationAlert: SettingsOperationAlert?
    @State var rewriteCatalogSheet: RewriteCatalog?
    @State var isCheckingRewriteCatalog = false

    let shortcutOptions = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

    struct SettingsOperationAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
        case browsers = "Browsers"
        case rules = "Rules"
        case rewrites = "Rewrites"
        case behavior = "Behavior"
        case appearance = "Appearance"
        case apps = "Apps"
        case general = "General"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .browsers: return "globe"
            case .rules: return "point.topleft.down.curvedto.point.bottomright.up"
            case .rewrites: return "arrow.triangle.2.circlepath"
            case .behavior: return "arrow.triangle.branch"
            case .appearance: return "paintpalette"
            case .apps: return "app.badge"
            case .general: return "gearshape"
            }
        }

        var subtitle: String {
            switch self {
            case .browsers: return "Picker options"
            case .rules: return "Automatic routing"
            case .rewrites: return "URL transformations"
            case .behavior: return "Fallback & privacy"
            case .appearance: return "Picker look"
            case .apps: return "Hidden handlers"
            case .general: return "Startup & maintenance"
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .browsers: return "settings.sidebar.browsers"
            case .rules: return "settings.sidebar.rules"
            case .rewrites: return "settings.sidebar.rewrites"
            case .behavior: return "settings.sidebar.behavior"
            case .appearance: return "settings.sidebar.appearance"
            case .apps: return "settings.sidebar.apps"
            case .general: return "settings.sidebar.general"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            settingsSidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
        } detail: {
            settingsDetail
        }
        .frame(minWidth: 860, idealWidth: 980, maxWidth: .infinity, minHeight: 560, idealHeight: 660, maxHeight: .infinity)
        .sheet(isPresented: $showingAddSheet) {
            AddBrowserSheet(manager: browserManager, isPresented: $showingAddSheet)
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddRuleSheet(
                manager: browserManager,
                isPresented: $showingAddRuleSheet,
                prefillURL: currentPrefillURL,
                preselectedBrowserIdentity: preselectedRuleBrowserIdentity
            )
        }
        .sheet(isPresented: $showingRuleMergeReview) {
            RuleMergeReviewSheet(manager: browserManager, isPresented: $showingRuleMergeReview)
        }
        .sheet(isPresented: $showingAddRewriteSheet) {
            RewriteRuleEditorSheet(manager: browserManager, isPresented: $showingAddRewriteSheet)
        }
        .sheet(item: $rewriteCatalogSheet) { catalog in
            RewriteCatalogSelectionSheet(
                catalog: catalog,
                manager: browserManager,
                isPresented: Binding(
                    get: { rewriteCatalogSheet != nil },
                    set: { if !$0 { rewriteCatalogSheet = nil } }
                )
            )
        }
        .sheet(item: $browserToEdit) { browser in
            EditBrowserSheet(
                browser: browser,
                manager: browserManager,
                isPresented: Binding(
                    get: { browserToEdit != nil },
                    set: { if !$0 { browserToEdit = nil } }
                )
            )
        }
        .onChange(of: showingAddRuleSheet) {
            guard !showingAddRuleSheet else { return }
            currentPrefillURL = nil
            preselectedRuleBrowserIdentity = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCreateRuleFromMenu"))) { notification in
            guard let url = notification.object as? URL else { return }
            selectedSection = .rules
            currentPrefillURL = url
            showingAddRuleSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RewriteCatalogApplied"))) { notification in
            guard let added = notification.object as? Int else { return }
            operationAlert = SettingsOperationAlert(
                title: "Rewrites Added",
                message: added == 0 ? "No new rewrite rules were added (the selected rules are already present)." : "Added \(added) new rewrite rule\(added == 1 ? "" : "s")."
            )
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
        .alert(item: $operationAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .accessibilityIdentifier("settings.root")
    }

    func checkForRewriteCatalogUpdates() {
        guard !isCheckingRewriteCatalog else { return }
        isCheckingRewriteCatalog = true
        Task {
            // Always re-fetch (no version gate) so catalog rules can be re-reviewed and
            // re-added after deletion. The selection sheet shows per-rule status.
            let catalog = await RewriteCatalogService.shared.fetchCatalog()
            isCheckingRewriteCatalog = false
            guard let catalog else {
                operationAlert = SettingsOperationAlert(title: "Couldn't Load Rewrites", message: "Check your connection and try again.")
                return
            }
            RewriteCatalogService.shared.notifyUpdateAvailable(catalog)
            rewriteCatalogSheet = catalog
        }
    }

    private var settingsSidebar: some View {
        List(selection: $selectedSection) {
            Section("Configuration") {
                sidebarRow(for: .browsers)
                sidebarRow(for: .rules)
                sidebarRow(for: .rewrites)
                sidebarRow(for: .behavior)
                sidebarRow(for: .appearance)
            }

            Section("System") {
                sidebarRow(for: .apps)
                sidebarRow(for: .general)
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("settings.sidebar")
    }

    private var settingsDetail: some View {
        Group {
            switch selectedSection {
            case .browsers:
                browsersSection
            case .rules:
                rulesSection
            case .rewrites:
                rewritesSection
            case .behavior:
                behaviorSection
            case .appearance:
                appearanceSection
            case .apps:
                appsSection
            case .general:
                generalSection
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func sidebarRow(for section: SettingsSection) -> some View {
        let count = sidebarBadge(for: section)

        NavigationLink(value: section) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(sectionAccentColor(for: section))
                    .frame(width: 18)

                Text(section.rawValue)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
        .accessibilityIdentifier(section.accessibilityIdentifier)
    }

    func sectionSearchField(
        placeholder: String,
        text: Binding<String>,
        accessibilityIdentifier: String
    ) -> some View {
        SettingsSearchField(
            placeholder: placeholder,
            text: text,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    func getAppIcon(bundleId: String) -> NSImage? {
        BrowserManager.icon(forBrowserBundleID: bundleId)
    }

    func presentSettingsMessage(_ title: String, _ message: String) {
        operationAlert = SettingsOperationAlert(title: title, message: message)
    }

    func presentImportSummary(for itemName: String, summary: BrowserManager.ImportSummary, successTitle: String) {
        var rows: [String] = []
        if summary.added > 0 { rows.append("Added: \(summary.added)") }
        if summary.updated > 0 { rows.append("Updated: \(summary.updated)") }
        if summary.skipped > 0 { rows.append("Skipped (existing): \(summary.skipped)") }
        if summary.invalid > 0 { rows.append("Skipped (invalid): \(summary.invalid)") }

        let message = rows.isEmpty
            ? "No changes were made."
            : "Imported \(itemName):\n" + rows.map { "• " + $0 }.joined(separator: "\n")
        presentSettingsMessage(successTitle, message)
    }

    private func sectionAccentColor(for section: SettingsSection) -> Color {
        switch section {
        case .browsers: return .blue
        case .rules: return .orange
        case .rewrites: return .indigo
        case .behavior: return .teal
        case .appearance: return .pink
        case .apps: return .purple
        case .general: return .green
        }
    }

    func sidebarBadge(for section: SettingsSection) -> Int {
        switch section {
        case .browsers:
            return browserManager.configuredBrowsers.count
        case .rules:
            return browserManager.routingRules.filter(\.isEnabled).count
        case .rewrites:
            return browserManager.rewriteRules.filter(\.isEnabled).count
        case .apps:
            return browserManager.hiddenBundleIDs.count
        case .behavior, .appearance, .general:
            return 0
        }
    }

    func browser(for rule: BrowserRoutingRule) -> BrowserConfig? {
        browserManager.configuredBrowsers.first {
            $0.bundleId == rule.browserBundleId && $0.profile == rule.profile
        }
    }

    func browserIdentityParts(from identity: String) -> (bundleId: String, profile: String?) {
        let parts = identity.split(separator: "|", omittingEmptySubsequences: false)
        let bundleId = parts.first.map(String.init) ?? ""
        let profile = parts.count > 1 && !parts[1].isEmpty ? String(parts[1]) : nil
        return (bundleId, profile)
    }
}

struct SettingsDetailScaffold<Actions: View, Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let scrollsContent: Bool
    let actions: Actions
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        scrollsContent: Bool = true,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.scrollsContent = scrollsContent
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.accent)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                actions
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(.bar)

            Divider()

            if scrollsContent {
                ScrollView {
                    content
                        .padding(24)
                        .frame(maxWidth: 920, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

extension SettingsDetailScaffold where Actions == EmptyView {
    init(
        title: String,
        subtitle: String,
        systemImage: String,
        scrollsContent: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            scrollsContent: scrollsContent,
            actions: { EmptyView() },
            content: content
        )
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.separator.opacity(0.35), lineWidth: 1)
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 14)
    }
}

struct SettingsSearchField: View {
    let placeholder: String
    @Binding var text: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .accessibilityIdentifier(accessibilityIdentifier)

            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
        )
    }
}

struct SettingsEmptyContent: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

#Preview {
    SettingsView()
}
