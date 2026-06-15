import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Rules Page Redesign (Master-Detail)

extension SettingsView {
    
    struct RuleGroup: Identifiable {
        let id: String // browser identity
        let browser: BrowserConfig
        let rules: [BrowserRoutingRule]
    }
    
    var groupedRoutingRules: [RuleGroup] {
        let rules = filteredRoutingRules
        let browsers = browserManager.configuredBrowsers
        
        // Group rules by browser identity
        let grouped = Dictionary(grouping: rules) { rule in
            "\(rule.browserBundleId)|\(rule.profile ?? "")"
        }
        
        // Map to RuleGroup objects, only for browsers that have rules or all browsers?
        // Let's show all configured browsers as sections, so user can easily add rules to any.
        return browsers.map { browser in
            RuleGroup(
                id: browser.identity,
                browser: browser,
                rules: grouped[browser.identity] ?? []
            )
        }
    }
    
    var filteredRoutingRules: [BrowserRoutingRule] {
        let query = ruleSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return browserManager.routingRules
        }
        
        return browserManager.routingRules.filter { rule in
            rule.name.lowercased().contains(query) ||
            rule.hostPattern.lowercased().contains(query) ||
            (rule.pathPrefix ?? "").lowercased().contains(query)
        }
    }
    
    var rulesSection: some View {
        GeometryReader { geometry in
            let sidebarWidth = max(220, min(320, geometry.size.width * 0.36))
            HStack(spacing: 0) {
                // Sidebar List of Rules
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Rules")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        
                        Spacer()

                        Menu {
                            Button(action: exportRules) {
                                Label("Export Rules…", systemImage: "square.and.arrow.up")
                            }
                            .disabled(browserManager.routingRules.isEmpty)

                            Button(action: importRules) {
                                Label("Import Rules…", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 28)
                        .accessibilityIdentifier("settings.rulesMenuButton")
                         
                        Button(action: { 
                            preselectedRuleBrowserIdentity = nil
                            showingAddRuleSheet = true 
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.accent)
                        }
                        .buttonStyle(.plain)
                        .help("Add new routing rule")
                        .accessibilityIdentifier("settings.addRuleButton")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    
                    // Search Field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        TextField("Search rules...", text: $ruleSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    
                    Divider()
                    
                    // Rules List
                    List(selection: $selectedRuleId) {
                        let groups = groupedRoutingRules
                        let isSearching = !ruleSearchText.isEmpty
                        
                        if groups.flatMap({ $0.rules }).isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: isSearching ? "magnifyingglass" : "bolt.horizontal.circle")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                                Text(isSearching ? "No Matches Found" : "No Rules Configured")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 40)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(groups) { group in
                                // Only show browsers that have rules matching the search,
                                // or all browsers if not searching.
                                if !group.rules.isEmpty || (!isSearching && !browserManager.configuredBrowsers.isEmpty) {
                                    Section {
                                        ForEach(group.rules) { rule in
                                            RuleRowView(
                                                rule: rule,
                                                browser: group.browser,
                                                isSelected: selectedRuleId == rule.id
                                            )
                                            .tag(rule.id)
                                            .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(selectedRuleId == rule.id ? Color.accentColor : Color.clear)
                                            )
                                        }
                                    } header: {
                                        HStack {
                                            if let icon = AppMetadataCache.shared.icon(for: group.browser.bundleId) {
                                                Image(nsImage: icon)
                                                    .resizable()
                                                    .frame(width: 14, height: 14)
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }
                                            
                                            Text(group.browser.name)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.secondary)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                preselectedRuleBrowserIdentity = group.id
                                                showingAddRuleSheet = true
                                            }) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityIdentifier("settings.addRuleForBrowserButton")
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar) // SideBar list style handles sections better on macOS
                    .scrollContentBackground(.hidden)
                }
                .frame(width: sidebarWidth)
                .background(Color.primary.opacity(0.01))
                
                Divider()
                
                // Rule Detail Area
                ZStack {
                    if let ruleId = selectedRuleId, let rule = browserManager.routingRules.first(where: { $0.id == ruleId }) {
                        ModernRuleDetailView(
                            rule: rule,
                            manager: browserManager,
                            onUpdate: { updated in
                                browserManager.updateRule(updated)
                            },
                            onDelete: {
                                browserManager.removeRoutingRule(id: ruleId)
                                selectedRuleId = nil
                            }
                        )
                        .id(ruleId)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        rulesPlaceholderView
                            .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedRuleId)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }
    
    private var rulesPlaceholderView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.accent.gradient)
                .shadow(color: .accentColor.opacity(0.15), radius: 20, y: 10)
            
            VStack(spacing: 8) {
                Text("Select a Rule")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Text("View and edit your automatic routing configuration here.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            RuleTesterView(manager: browserManager)
                .frame(maxWidth: 400)
                .padding(.top, 20)
        }
    }

    func exportRules() {
        let panel = NSSavePanel()
        panel.title = "Export Routing Rules"
        panel.nameFieldStringValue = "ChowserRules.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.exportRules(to: url)
        } catch {
            print("Export rules failed: \(error.localizedDescription)")
        }
    }

    func importRules() {
        let panel = NSOpenPanel()
        panel.title = "Import Routing Rules"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try browserManager.importRules(from: url, skipExisting: browserManager.skipExistingImportedRules)
        } catch {
            print("Import rules failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Modern Rule Detail View

struct ModernRuleDetailView: View {
    let rule: BrowserRoutingRule
    let manager: BrowserManager
    let onUpdate: (BrowserRoutingRule) -> Void
    let onDelete: () -> Void
    
    @State private var localRule: BrowserRoutingRule
    
    init(rule: BrowserRoutingRule, manager: BrowserManager, onUpdate: @escaping (BrowserRoutingRule) -> Void, onDelete: @escaping () -> Void) {
        self.rule = rule
        self.manager = manager
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._localRule = State(initialValue: rule)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header Block
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Rule Name", text: $localRule.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .textFieldStyle(.plain)
                            .onChange(of: localRule.name) { _, _ in update() }
                        
                        Text("Configures how links are automatically routed.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { localRule.isEnabled },
                        set: { localRule.isEnabled = $0; update() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                
                // Configuration Sections
                VStack(spacing: 24) {
                    // 1. Matching
                    DetailSection(title: "Matching Conditions", icon: "arrow.triangle.merge") {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Domain / Host Pattern")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                
                                TextField("e.g. *.github.com", text: $localRule.hostPattern)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(10)
                                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                                    .onChange(of: localRule.hostPattern) { _, _ in update() }
                                    .accessibilityIdentifier("settings.rule.hostField")
                            }
                            
                            HStack(spacing: 24) {
                                Toggle("Use Regex", isOn: Binding(
                                    get: { localRule.useRegex },
                                    set: { localRule.useRegex = $0; update() }
                                ))
                                .toggleStyle(.checkbox)
                                
                                Spacer()
                                
                                Button(localRule.pathPrefix == nil ? "Add Path" : "Remove Path") {
                                    if localRule.pathPrefix == nil {
                                        localRule.pathPrefix = "/"
                                    } else {
                                        localRule.pathPrefix = nil
                                    }
                                    update()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.accent)
                            }
                            
                            if let path = localRule.pathPrefix {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Path Prefix")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("/", text: Binding(
                                        get: { path },
                                        set: { localRule.pathPrefix = $0; update() }
                                    ))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(10)
                                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    
                    // 2. Destination
                    DetailSection(title: "Destination", icon: "paperplane.fill") {
                        VStack(spacing: 16) {
                            DetailRow(label: "Browser") {
                                Picker("", selection: Binding(
                                    get: { "\(localRule.browserBundleId)|\(localRule.profile ?? "")" },
                                    set: { val in
                                        let parts = val.split(separator: "|")
                                        localRule.browserBundleId = String(parts[0])
                                        localRule.profile = parts.count > 1 ? String(parts[1]) : nil
                                        update()
                                    }
                                )) {
                                    ForEach(manager.configuredBrowsers) { browser in
                                        Text(browser.name).tag(browser.identity)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .controlSize(.small)
                                .accessibilityIdentifier("settings.rule.browserPicker")
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Use Private Mode", isOn: Binding(
                                    get: { BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild && localRule.usePrivateMode },
                                    set: {
                                        localRule.usePrivateMode = BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild ? $0 : false
                                        update()
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .disabled(!BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)

                                if !BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
                                    Text("Private/incognito routing needs browser launch arguments, which macOS does not deliver to sandboxed App Store builds.")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    
                    // 3. Context
                    DetailSection(title: "Context", icon: "app.badge.checkmark") {
                        DetailRow(label: "Source Application") {
                            Button(action: chooseSourceApp) {
                                AppBadgeView(bundleId: localRule.sourceAppBundleId, fallbackText: "Any Application")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer(minLength: 40)
                
                // Footer Actions
                HStack(spacing: 16) {
                    Button(action: duplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Rule", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(40)
        }
        .onChange(of: rule) { _, newValue in
            localRule = newValue
        }
    }
    
    private func update() {
        onUpdate(localRule)
    }
    
    private func duplicate() {
        manager.duplicateRoutingRule(id: rule.id)
    }
    
    private func chooseSourceApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.applicationBundle]
        if panel.runModal() == .OK, let url = panel.url {
            localRule.sourceAppBundleId = Bundle(url: url)?.bundleIdentifier
            update()
        }
    }
}

// MARK: - Rule Tester View

struct RuleTesterView: View {
    let manager: BrowserManager
    @State private var urlString: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                    .foregroundStyle(.accent)
                Text("Tester")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            
            TextField("Paste a link to see where it goes...", text: $urlString)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(12)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            
            if !urlString.isEmpty {
                ResultView(manager: manager, input: urlString)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: urlString)
    }
}

struct ResultView: View {
    let manager: BrowserManager
    let input: String
    
    var body: some View {
        if let url = URL(string: input.contains("://") ? input : "https://\(input)"), url.host != nil {
            if let result = manager.resolvedRoute(for: url) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Matched: \(result.rule?.name ?? "Default")")
                            .font(.system(size: 12, weight: .bold))
                        Text("Chowser will open \(result.browser.name)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text("No matching rule. The browser picker will appear.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        } else {
            Text("Enter a valid URL to test routing.")
                .font(.system(size: 11))
                .foregroundStyle(.red.opacity(0.8))
                .padding(.leading, 8)
        }
    }
}
