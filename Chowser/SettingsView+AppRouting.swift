import SwiftUI
import AppKit

extension SettingsView {
    var appRoutingSection: some View {
        @Bindable var manager = browserManager

        return SettingsDetailScaffold(
            title: "App Routing",
            subtitle: "Send links straight to native apps instead of a browser.",
            systemImage: "arrow.triangle.branch",
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsGroup("Automatic Routing") {
                        SettingsRow(
                            title: "Open links in their app automatically",
                            subtitle: "When a link belongs to an installed app below, send it straight there without showing the picker. Rules and temporary overrides still win."
                        ) {
                            Toggle("", isOn: $manager.autoNativeAppRouting)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityIdentifier("settings.appRouting.autoToggle")
                        }
                    }

                    SettingsGroup("Apps", subtitle: "Installed apps Chowser knows how to route to. Add one to also create its domain rules.") {
                        if installedRoutingApps.isEmpty {
                            SettingsRow(title: "No known apps installed", subtitle: "Install an app like Slack, Zoom, or Figma, or add any app from Browsers → Add Browser → Custom App.") {
                                EmptyView()
                            }
                        } else {
                            ForEach(Array(installedRoutingApps.enumerated()), id: \.element.id) { index, app in
                                appRoutingRow(app)
                                if index < installedRoutingApps.count - 1 {
                                    SettingsDivider()
                                }
                            }
                        }
                    }

                    SettingsGroup("More apps") {
                        SettingsRow(
                            title: "Add any app with AI",
                            subtitle: "Start the local API server (General → Local API Server) and ask your AI assistant to configure newer apps — it researches the bundle ID and domains and sets them up."
                        ) {
                            EmptyView()
                        }
                    }
                }
            }
        )
    }

    private var installedRoutingApps: [NativeAppSuggestion] {
        NativeAppCatalog.all.filter { $0.isInstalled && !$0.domains.isEmpty }
    }

    @ViewBuilder
    private func appRoutingRow(_ app: NativeAppSuggestion) -> some View {
        let isConfigured = browserManager.configuredBrowsers.contains { $0.bundleId.lowercased() == app.bundleId.lowercased() }

        SettingsRow(title: app.name, subtitle: app.domains.joined(separator: ", ")) {
            HStack(spacing: 10) {
                if let icon = BrowserManager.icon(forBrowserBundleID: app.bundleId) {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 22, height: 22)
                }
                if isConfigured {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    Button("Route") {
                        addRoutingApp(app)
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func addRoutingApp(_ app: NativeAppSuggestion) {
        browserManager.addBrowser(name: app.name, bundleId: app.bundleId)
        for domain in app.domains {
            _ = browserManager.addRoutingRule(
                name: "\(app.name) — \(domain)",
                hostPattern: domain,
                pathPrefix: nil,
                browserBundleId: app.bundleId
            )
        }
    }
}
