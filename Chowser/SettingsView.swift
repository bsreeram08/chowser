import SwiftUI
import AppKit

struct SettingsView: View {
    var browserManager = BrowserManager.shared

    @State var showingAddSheet = false
    @State var showingAddRuleSheet = false
    @State var selectedSection: SettingsSection = .browsers
    @State var showingResetConfirmation = false
    @State var browserSearchText = ""
    @State var ruleSearchText = ""
    @State var filteredRules: [BrowserRoutingRule] = []
    @State var newHiddenBundleId = ""

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
                ForEach(SettingsSection.allCases) { section in
                    let count = sidebarBadge(for: section)
                    HStack(spacing: 0) {
                        Label(section.rawValue, systemImage: section.icon)
                        Spacer()
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.18), in: Capsule())
                        }
                    }
                    .tag(section)
                    .accessibilityIdentifier(section.accessibilityIdentifier)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .accessibilityIdentifier("settings.sidebar")
        } detail: {
            switch selectedSection {
            case .browsers: browsersSection
            case .rules: rulesSection
            case .apps: appsSection
            case .general: generalSection
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
}

#Preview {
    SettingsView()
}
