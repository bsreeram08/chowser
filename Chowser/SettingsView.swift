import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var browserManager = BrowserManager.shared
    @State private var showingAddSheet = false
    @State private var selectedSection: SettingsSection = .browsers
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case browsers = "Browsers"
        case general = "General"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .browsers: return "globe"
            case .general: return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selectedSection {
            case .browsers:
                browsersSection
            case .general:
                generalSection
            }
        }
        .frame(width: 620, height: 440)
        .sheet(isPresented: $showingAddSheet) {
            AddBrowserSheet(manager: browserManager, isPresented: $showingAddSheet)
        }
    }
    
    // MARK: - Browsers Section
    
    private var browsersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
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
                .accessibilityLabel("Add a new browser to the picker")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Browser list
            if browserManager.configuredBrowsers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("No browsers configured")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Click \"Add Browser\" to get started.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($browserManager.configuredBrowsers) { $browser in
                        browserConfigRow(browser: $browser)
                    }
                    .onMove { indices, newOffset in
                        browserManager.configuredBrowsers.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { indices in
                        browserManager.configuredBrowsers.remove(atOffsets: indices)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            
            // Footer hint
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
    
    private func browserConfigRow(browser: Binding<BrowserConfig>) -> some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = getAppIcon(bundleId: browser.wrappedValue.bundleId) {
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
            
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: browser.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .accessibilityLabel("Browser display name")
                
                Text(browser.wrappedValue.bundleId)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Shortcut picker
            HStack(spacing: 4) {
                Text("⌘⇧")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                
                Picker("", selection: browser.shortcutKey) {
                    ForEach(["1","2","3","4","5","6","7","8","9"], id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 50)
                .labelsHidden()
                .accessibilityLabel("Keyboard shortcut number for \(browser.wrappedValue.name)")
            }
            
            // Delete button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    browserManager.configuredBrowsers.removeAll { $0.id == browser.wrappedValue.id }
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(browser.wrappedValue.name)")
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - General Section
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
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
                Section {
                    Toggle("Launch Chowser at login", isOn: $browserManager.launchAtLogin)
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
                        Text("Chowser")
                            .font(.system(size: 13, weight: .semibold))
                        Text("A browser chooser for macOS")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("Version 1.0")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About")
                }
            }
            .formStyle(.grouped)
        }
    }
    
    // MARK: - Helpers
    
    private func getAppIcon(bundleId: String) -> NSImage? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
}

// MARK: - Add Browser Sheet

struct AddBrowserSheet: View {
    @ObservedObject var manager: BrowserManager
    @Binding var isPresented: Bool
    
    @State private var availableBrowsers: [(name: String, bundleId: String, iconURL: URL?)] = []
    @State private var hoveredBundleId: String?
    
    private var filteredBrowsers: [(name: String, bundleId: String, iconURL: URL?)] {
        let configuredIds = Set(manager.configuredBrowsers.map(\.bundleId))
        return availableBrowsers.filter { !configuredIds.contains($0.bundleId) }
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
            
            Divider()
            
            if filteredBrowsers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                    Text("All installed browsers are configured")
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
        .frame(width: 400, height: 360)
        .onAppear {
            availableBrowsers = BrowserManager.getInstalledBrowsers()
        }
    }
    
    private func browserOption(entry: (name: String, bundleId: String, iconURL: URL?)) -> some View {
        let isHovered = hoveredBundleId == entry.bundleId
        
        return Button(action: {
            let defaultShortcut = String(min(manager.configuredBrowsers.count + 1, 9))
            let newBrowser = BrowserConfig(name: entry.name, bundleId: entry.bundleId, shortcutKey: defaultShortcut)
            withAnimation(.easeInOut(duration: 0.2)) {
                manager.configuredBrowsers.append(newBrowser)
            }
            isPresented = false
        }) {
            HStack(spacing: 12) {
                if let url = entry.iconURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .interpolation(.high)
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
                hoveredBundleId = hovering ? entry.bundleId : nil
            }
        }
        .accessibilityLabel("Add \(entry.name)")
        .accessibilityHint("Adds \(entry.name) to the browser picker")
    }
}

#Preview {
    SettingsView()
}
