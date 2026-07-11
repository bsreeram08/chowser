import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

struct ConfigureRuleView: View {
    var browserManager: BrowserManager
    let interceptedURL: URL
    @Binding var isPresented: Bool
    var onSave: () -> Void
    var preselectedBrowserBundleId: String? = nil

    @State private var ruleName = ""
    @State private var hostPattern = ""
    @State private var selectedBrowserIdentity = ""
    @State private var usePrivateMode = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Routing Rule")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Automatic routing for \(interceptedURL.host ?? "this domain")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.primary.opacity(0.02))

            Divider()

            VStack(spacing: 20) {
                // Rule Identity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rule Name".uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter name...", text: $ruleName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }

                // Configuration Card
                VStack(spacing: 16) {
                    DetailRow(label: "Host") {
                        Text(hostPattern)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .pickerBadgeChip()
                    }
                    
                    Divider().opacity(0.5)
                    
                    DetailRow(label: "Open In") {
                        Picker("", selection: $selectedBrowserIdentity) {
                            if selectedBrowserIdentity.isEmpty {
                                Text("Choose Browser").tag("")
                            }
                            ForEach(browserManager.configuredBrowsers) { browser in
                                Text(browser.name).tag(browser.identity)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .controlSize(.small)
                    }
                    
                    Divider().opacity(0.5)
                    
                    Toggle("Use Private Mode", isOn: $usePrivateMode)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11, weight: .medium))
                        .disabled(!BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    if !BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild {
                        Text("Private mode is unavailable in App Store builds.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(16)
                .pickerInlineCard()
            }
            .padding(20)

            Divider()

            // Footer
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: saveRule) {
                    Text("Save Rule")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.accentColor : Color.secondary.opacity(0.3), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(16)
            .background(Color.primary.opacity(0.01))
        }
        .frame(width: 360)
        .onAppear {
            prefillFromURL()
        }
    }
    
    private var canSave: Bool {
        !ruleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedBrowserIdentity.isEmpty
    }
    
    private func prefillFromURL() {
        let host = interceptedURL.host ?? ""
        hostPattern = host
        
        let components = host.split(separator: ".")
        if components.count >= 2 {
            ruleName = String(components[components.count - 2]).capitalized
        } else {
            ruleName = host.capitalized
        }
        
        if let preselected = preselectedBrowserBundleId,
           let browser = browserManager.configuredBrowsers.first(where: { $0.bundleId == preselected }) {
            selectedBrowserIdentity = browser.identity
        } else {
            selectedBrowserIdentity = browserManager.configuredBrowsers.first?.identity ?? ""
        }
    }
    
    private func saveRule() {
        let parts = selectedBrowserIdentity.split(separator: "|")
        let browserBundleId = String(parts[0])
        let profile = parts.count > 1 ? String(parts[1]) : nil
        
        browserManager.addRoutingRule(
            name: ruleName,
            hostPattern: hostPattern,
            pathPrefix: nil,
            browserBundleId: browserBundleId,
            profile: profile,
            usePrivateMode: BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild ? usePrivateMode : false
        )
        isPresented = false
        onSave()
    }
}
