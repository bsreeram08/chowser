import SwiftUI
import AppKit

struct SettingsView: View {
    @State var browserManager = BrowserManager.shared

    @State var showingAddSheet = false
    @State var showingAddRuleSheet = false
    @State var currentPrefillURL: URL? = nil
    @State var selectedSection: SettingsSection = .browsers
    @State var showingResetConfirmation = false
    @State var browserSearchText = ""
    @State var ruleSearchText = ""
    @State var newHiddenBundleId = ""
    
    @State var browserToEdit: BrowserConfig? = nil
    @State var ruleToEdit: BrowserRoutingRule? = nil
    @State var selectedRuleId: UUID? = nil
    @State var preselectedRuleBrowserIdentity: String? = nil
    @State var browserViewMode: SettingsView.BrowserViewMode = .grid
    @State var draggedBrowserId: UUID? = nil
    @State var dropTargetBrowserId: UUID? = nil


    let shortcutOptions = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

    enum SettingsSection: String, CaseIterable, Identifiable {
        case browsers = "Browsers"
        case rules = "Rules"
        case apps = "Apps"
        case general = "General"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .browsers: return "globe"
            case .rules: return "line.3.horizontal.decrease.circle"
            case .apps: return "app.badge.checkmark"
            case .general: return "gearshape"
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .browsers: return "settings.sidebar.browsers"
            case .rules: return "settings.sidebar.rules"
            case .apps: return "settings.sidebar.apps"
            case .general: return "settings.sidebar.general"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                // Configuration section
                Section {
                    ForEach([SettingsSection.browsers, .rules], id: \.self) { section in
                        sidebarRow(for: section)
                    }
                } header: {
                    Text("Configuration")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                
                // System section
                Section {
                    ForEach([SettingsSection.apps, .general], id: \.self) { section in
                        sidebarRow(for: section)
                    }
                } header: {
                    Text("System")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
            .accessibilityIdentifier("settings.sidebar")
        } detail: {
            switch selectedSection {
            case .browsers: browsersSection
            case .rules: rulesSection
            case .apps: appsSection
            case .general: generalSection
            }
        }
        .frame(minWidth: 1100, idealWidth: 1300, minHeight: 700, idealHeight: 900)
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showingAddSheet) {
            AddBrowserSheet(manager: browserManager, isPresented: $showingAddSheet)
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddRuleSheet(manager: browserManager, isPresented: $showingAddRuleSheet, prefillURL: currentPrefillURL, preselectedBrowserIdentity: preselectedRuleBrowserIdentity)
        }
        .onChange(of: showingAddRuleSheet) { 
            if !showingAddRuleSheet { 
                currentPrefillURL = nil
                preselectedRuleBrowserIdentity = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCreateRuleFromMenu"))) { notification in
            if let url = notification.object as? URL {
                selectedSection = .rules
                currentPrefillURL = url
                showingAddRuleSheet = true
            }
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

    // MARK: - Shared Helpers

    func sectionSearchField(
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

    func getAppIcon(bundleId: String) -> NSImage? {
        BrowserManager.icon(forBrowserBundleID: bundleId)
    }

    @ViewBuilder
    private func sidebarRow(for section: SettingsSection) -> some View {
        let count = sidebarBadge(for: section)
        let isSelected = selectedSection == section
        let accentColor = sectionAccentColor(for: section)
        
        HStack(spacing: 0) {
            Label {
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            } icon: {
                Image(systemName: section.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? accentColor : .secondary)
            }
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? accentColor.opacity(0.15) : .secondary.opacity(0.18), in: Capsule())
            }
        }
        .tag(section)
        .accessibilityIdentifier(section.accessibilityIdentifier)
    }

    private func sectionAccentColor(for section: SettingsSection) -> Color {
        switch section {
        case .browsers: return .blue
        case .rules: return .orange
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
        case .apps:
            return browserManager.hiddenBundleIDs.count
        case .general:
            return 0
        }
    }
    
    // MARK: - Density Helpers
    
    var densityMultiplier: CGFloat {
        switch browserManager.densityPreference {
        case "compact": return 0.75
        case "comfortable": return 1.25
        default: return 1.0
        }
    }
    
    private var baseSpacing: CGFloat { 4 }
    
    private var densityPadding: CGFloat {
        baseSpacing * densityMultiplier
    }
    
    private var densitySpacing: CGFloat {
        baseSpacing * densityMultiplier
    }
    
    private var densityFontSize: CGFloat {
        13 * densityMultiplier
    }
    
    private var densityIconSize: CGFloat {
        24 * densityMultiplier
    }
    
    /// Returns dynamic spacing that respects the density preference
    func dynamicPadding(_ points: CGFloat) -> CGFloat {
        points * densityMultiplier
    }
    
    /// Returns a font size that respects the density preference
    func dynamicFontSize(_ baseSize: CGFloat) -> CGFloat {
        baseSize * densityMultiplier
    }
}

#Preview {
    SettingsView()
}
