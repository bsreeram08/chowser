import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

struct AddRuleSheet: View {
    var manager: BrowserManager
    @Binding var isPresented: Bool
    
    var prefillURL: URL? = nil
    var preselectedBrowserIdentity: String? = nil

    @State private var ruleName = ""
    @State private var hostPattern = ""
    @State private var pathPrefix = ""
    @State private var selectedBrowserIdentity = ""
    @State private var sourceAppBundleId: String? = nil
    @State private var usePrivateMode = false
    @State private var useRegex = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Routing Rule")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Define how links should be routed automatically.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(Color.primary.opacity(0.02))

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Rule Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name".uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextField("Work, Personal, etc.", text: $ruleName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Matching logic
                    DetailSection(title: "Matching", icon: "app.connected.to.app.below.fill") {
                        VStack(spacing: 16) {
                            DetailRow(label: "URL Pattern") {
                                TextField("e.g. *.github.com", text: $hostPattern)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .onChange(of: hostPattern) { _, _ in updateRuleNameIfNeeded() }
                            }
                            
                            HStack {
                                Toggle("Regex", isOn: $useRegex)
                                    .toggleStyle(.checkbox)
                                
                                Spacer()
                                
                                Button(pathPrefix.isEmpty ? "Add Path" : "Path: \(pathPrefix)") {
                                    if pathPrefix.isEmpty { pathPrefix = "/" }
                                    else { pathPrefix = "" }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(.accent)
                            }
                            
                            if !pathPrefix.isEmpty {
                                TextField("Path Prefix", text: $pathPrefix)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(8)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    // Destination
                    DetailSection(title: "Destination", icon: "paperplane.fill") {
                        VStack(spacing: 16) {
                            DetailRow(label: "Browser") {
                                Picker("", selection: $selectedBrowserIdentity) {
                                    ForEach(manager.configuredBrowsers) { browser in
                                        Text(browser.name).tag(browser.identity)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            
                            Toggle("Use Private Mode", isOn: $usePrivateMode)
                                .toggleStyle(.checkbox)
                        }
                    }
                    
                    // Context
                    DetailSection(title: "Context", icon: "cpu.fill") {
                        DetailRow(label: "Source App") {
                            Button(action: chooseSourceApp) {
                                AppBadgeView(bundleId: sourceAppBundleId, fallbackText: "Any Application")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: saveRule) {
                    Text("Create Rule")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.accentColor : Color.secondary.opacity(0.3), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(20)
            .background(Color.primary.opacity(0.01))
        }
        .frame(width: 500, height: 620)
        .onAppear {
            if let prefillURL = prefillURL, hostPattern.isEmpty {
                hostPattern = prefillURL.host ?? ""
                updateRuleNameIfNeeded()
            }
            if let identity = preselectedBrowserIdentity, !identity.isEmpty {
                selectedBrowserIdentity = identity
            } else if selectedBrowserIdentity.isEmpty {
                selectedBrowserIdentity = manager.configuredBrowsers.first?.identity ?? ""
            }
        }
    }
    
    private var canSave: Bool {
        !hostPattern.isEmpty && !selectedBrowserIdentity.isEmpty
    }
    
    private func updateRuleNameIfNeeded() {
        guard ruleName.isEmpty else { return }
        let components = hostPattern.split(separator: ".")
        if components.count >= 2 {
            ruleName = String(components[components.count - 2]).capitalized
        } else {
            ruleName = hostPattern.capitalized
        }
    }
    
    private func chooseSourceApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.applicationBundle]
        if panel.runModal() == .OK, let url = panel.url {
            sourceAppBundleId = Bundle(url: url)?.bundleIdentifier
        }
    }
    
    private func saveRule() {
        let parts = selectedBrowserIdentity.split(separator: "|")
        let browserBundleId = String(parts[0])
        let profile = parts.count > 1 ? String(parts[1]) : nil
        
        manager.addRoutingRule(
            name: ruleName,
            hostPattern: hostPattern,
            pathPrefix: pathPrefix.isEmpty ? nil : pathPrefix,
            browserBundleId: browserBundleId,
            profile: profile,
            sourceAppBundleId: sourceAppBundleId,
            usePrivateMode: usePrivateMode,
            useRegex: useRegex
        )
        isPresented = false
    }
}
