import SwiftUI
import AppKit

extension SettingsView {
    var behaviorSection: some View {
        SettingsDetailScaffold(
            title: "Behavior",
            subtitle: "Fallback routing and privacy controls for network-backed lookups.",
            systemImage: "arrow.triangle.branch",
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    if !browserManager.hasSeenNetworkPrivacyUpgradeNotice {
                        networkPrivacyUpgradeNote
                    }

                    fallbackGroup

                    if fallbackBrowserMissing {
                        fallbackBrowserMissingNote
                    }

                    networkLookupsGroup

                    trackingCleanupGroup
                }
            }
        )
        .onAppear {
            browserManager.markNetworkPrivacyUpgradeNoticeSeen()
        }
        .accessibilityIdentifier("settings.behaviorSection")
    }

    // MARK: - Upgrade notice

    private var networkPrivacyUpgradeNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "network.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Network lookups are now off by default")
                    .font(.system(size: 12, weight: .semibold))
                Text("Shortlink resolution and link previews used to run automatically. Turn them back on below if you want them.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("settings.behavior.networkPrivacyUpgradeNote")
    }

    // MARK: - Fallback routing

    private var fallbackGroup: some View {
        SettingsGroup("Fallback Routing", subtitle: "What happens when a link matches no routing rule.") {
            SettingsRow(title: "When no rule matches") {
                Picker("", selection: fallbackModeBinding) {
                    Text("Show Picker").tag(BrowserFallbackPolicy.Mode.picker)
                    Text("Open in Browser/Profile").tag(BrowserFallbackPolicy.Mode.browser)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)
                .accessibilityIdentifier("settings.behavior.fallbackModePicker")
            }

            SettingsDivider()

            SettingsRow(
                title: "Browser/Profile",
                subtitle: browserManager.configuredBrowsers.isEmpty ? "Add a browser to enable fallback" : nil
            ) {
                Picker("", selection: fallbackBrowserBinding) {
                    ForEach(browserManager.configuredBrowsers) { browser in
                        Text(fallbackBrowserDisplayName(browser)).tag(Optional(browser.id))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240)
                .disabled(browserManager.configuredBrowsers.isEmpty || browserManager.fallbackPolicy.mode != .browser)
                .accessibilityIdentifier("settings.behavior.fallbackBrowserPicker")
            }
        }
    }

    private var fallbackModeBinding: Binding<BrowserFallbackPolicy.Mode> {
        Binding(
            get: { browserManager.fallbackPolicy.mode },
            set: { browserManager.fallbackPolicy.mode = $0 }
        )
    }

    private var fallbackBrowserBinding: Binding<UUID?> {
        Binding(
            get: { browserManager.fallbackPolicy.browserID },
            set: { newID in
                browserManager.fallbackPolicy.browserID = newID
                browserManager.fallbackPolicy.profile = browserManager.configuredBrowsers.first(where: { $0.id == newID })?.profile
            }
        )
    }

    private func fallbackBrowserDisplayName(_ browser: BrowserConfig) -> String {
        if let profile = browser.profile {
            return "\(browser.name) (\(profile))"
        }
        return browser.name
    }

    /// True when the persisted fallback browser was deleted or hidden since it was chosen
    /// (FR-003). Routing already falls back to the picker at runtime; this just surfaces
    /// that silent revert in Settings instead of leaving no trace.
    private var fallbackBrowserMissing: Bool {
        guard browserManager.fallbackPolicy.mode == .browser,
              let browserID = browserManager.fallbackPolicy.browserID else {
            return false
        }
        guard let browser = browserManager.configuredBrowsers.first(where: { $0.id == browserID }) else {
            return true
        }
        return browserManager.hiddenBundleIDs.contains(browser.bundleId)
    }

    private var fallbackBrowserMissingNote: some View {
        Label("The browser chosen for fallback is no longer available. Chowser shows the picker until you choose another.", systemImage: "exclamationmark.triangle")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 4)
            .accessibilityIdentifier("settings.behavior.fallbackBrowserMissingNote")
    }

    // MARK: - Network lookups

    private var networkLookupsGroup: some View {
        @Bindable var manager = browserManager

        return SettingsGroup("Network Lookups", subtitle: "Off by default. Enables shortlink resolution and link-preview fetches before a link is routed.") {
            SettingsRow(title: "Network Lookups", subtitle: "Contacts the destination host before routing.") {
                HStack(spacing: 8) {
                    networkIndicator
                    Toggle("", isOn: $manager.networkLookupsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.behavior.networkLookupsToggle")
                }
            }

            SettingsDivider()

            SettingsRow(title: "Built-in Shorteners", subtitle: Self.builtInShortenerList) {
                EmptyView()
            }

            SettingsDivider()

            SettingsRow(title: "Additional Hosts", subtitle: "Appended to the built-in list. The built-in list itself can't be edited.") {
                EmptyView()
            }

            if !browserManager.userShortenerHosts.isEmpty {
                ForEach(Array(browserManager.userShortenerHosts.sorted()), id: \.self) { host in
                    SettingsDivider()
                    userShortenerHostRow(host)
                }
            }

            SettingsDivider()

            addShortenerHostRow

            SettingsDivider()

            SettingsRow(title: "Timeout", subtitle: "How long to wait for a shortlink to resolve before opening the original link.") {
                HStack(spacing: 8) {
                    Slider(value: $manager.shortlinkResolutionTimeout, in: 0.5...5.0, step: 0.5)
                        .frame(maxWidth: 160)
                    Text("\(manager.shortlinkResolutionTimeout, specifier: "%.1f")s")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                .accessibilityIdentifier("settings.behavior.shortlinkTimeout")
            }
        }
    }

    private static let builtInShortenerList = "t.co, bit.ly, tinyurl.com, is.gd, buff.ly, ow.ly, goo.gl, lnkd.in"

    private var networkIndicator: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 11))
            .foregroundStyle(.blue)
            .help("This feature contacts the network before routing.")
            .accessibilityLabel("Contacts the network")
    }

    private func userShortenerHostRow(_ host: String) -> some View {
        SettingsRow(title: host) {
            Button("Remove", systemImage: "minus.circle") {
                browserManager.removeUserShortenerHost(host)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    private var addShortenerHostRow: some View {
        HStack(spacing: 10) {
            TextField("short.example.com", text: $newShortenerHost)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .accessibilityIdentifier("settings.behavior.addShortenerHostField")

            Button("Add") {
                browserManager.addUserShortenerHost(newShortenerHost)
                newShortenerHost = ""
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(newShortenerHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
    }

    // MARK: - Tracking cleanup

    private var trackingCleanupGroup: some View {
        @Bindable var manager = browserManager

        return SettingsGroup("Tracking Cleanup", subtitle: "Strips known tracking query parameters (utm_*, gclid, etc.) — entirely local, no network involved.") {
            SettingsRow(title: "Tracking Cleanup") {
                Toggle("", isOn: $manager.trackingCleanupEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.behavior.trackingCleanupToggle")
            }
        }
    }
}
