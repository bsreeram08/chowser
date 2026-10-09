import SwiftUI
import AppKit

extension SettingsView {
    var appsSection: some View {
        @Bindable var manager = browserManager

        return SettingsDetailScaffold(
            title: "Apps",
            subtitle: "Review native deep links and hide non-browser URL handlers.",
            systemImage: "app.badge",
            actions: {
                Button("Refresh Signed Directory", systemImage: "arrow.clockwise") {
                    refreshNativeAppDirectory()
                }
                .controlSize(.small)
                .disabled(isRefreshingNativeAppDirectory)
                .accessibilityIdentifier("settings.nativeApps.refreshButton")
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsGroup(
                        "Native Link Apps",
                        subtitle: "Disabled by default. Chowser opens a native URL only after you approve its exact signed hosts and transforms."
                    ) {
                        if let directory = nativeAppDirectory {
                            let installed = installedNativeApps(in: directory)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Signed directory v\(directory.directory.catalogVersion) · key \(directory.provenance.keyID)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(directory.provenance.source == .cache
                                    ? "Using the verified last-known-good cache. Refresh to check for additions."
                                    : "Freshly verified from the hosted directory.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)

                            SettingsDivider()

                            if installed.isEmpty {
                                SettingsRow(
                                    title: "No supported native apps installed",
                                    subtitle: "Refresh after installing an app, or wait for it to be added to the signed directory."
                                ) {
                                    EmptyView()
                                }
                            } else {
                                ForEach(installed) { installedApp in
                                    NativeAppConsentRow(
                                        entry: installedApp.entry,
                                        bundleIdentifier: installedApp.bundleIdentifier,
                                        isApproved: manager.isNativeAppApproved(installedApp.entry),
                                        needsReview: manager.nativeAppApprovals[installedApp.entry.id] != nil
                                            && !manager.isNativeAppApproved(installedApp.entry)
                                    ) { enabled in
                                        if enabled {
                                            manager.approveNativeApp(installedApp.entry)
                                        } else {
                                            manager.revokeNativeApp(entryID: installedApp.entry.id)
                                        }
                                    }
                                    if installedApp.id != installed.last?.id {
                                        SettingsDivider()
                                    }
                                }
                            }
                        } else {
                            SettingsRow(
                                title: "No signed directory cached",
                                subtitle: "Refresh to download the fixed catalog endpoints. Chowser never sends the link you are opening."
                            ) {
                                Button("Refresh") { refreshNativeAppDirectory() }
                                    .controlSize(.small)
                                    .disabled(isRefreshingNativeAppDirectory)
                            }
                        }
                    }

                    SettingsGroup("Hidden Apps", subtitle: "Bundle IDs in this list are excluded from browser discovery.") {
                        if browserManager.hiddenBundleIDs.isEmpty {
                            SettingsRow(title: "No hidden apps", subtitle: "All discovered URL handlers are currently eligible.") {
                                EmptyView()
                            }
                        } else {
                            ForEach(Array(browserManager.hiddenBundleIDs.sorted()), id: \.self) { bundleId in
                                SettingsHiddenAppRow(bundleId: bundleId) {
                                    browserManager.removeHiddenBundleID(bundleId)
                                }
                                if bundleId != browserManager.hiddenBundleIDs.sorted().last {
                                    SettingsDivider()
                                }
                            }
                        }
                    }

                    SettingsGroup("Add Bundle ID", subtitle: "Use this when an app registers as a browser but should stay hidden.") {
                        HStack(spacing: 10) {
                            TextField("com.example.app", text: $newHiddenBundleId)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))

                            Button("Hide") {
                                addHiddenBundleIDFromField()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Reset Defaults") {
                                browserManager.resetHiddenBundleIDs()
                            }
                            .controlSize(.small)
                        }
                        .padding(14)
                    }
                }
            }
        )
        .onAppear {
            guard nativeAppDirectory == nil else { return }
            nativeAppDirectory = NativeAppDirectoryService.shared.currentDirectory
                ?? NativeAppDirectoryService.shared.loadLastKnownGood()
        }
    }

    private func installedNativeApps(
        in directory: VerifiedNativeAppDirectory
    ) -> [InstalledNativeApp] {
        directory.directory.apps.compactMap { entry in
            guard let bundleIdentifier = NativeAppDirectoryService.shared
                .installedBundleIdentifier(for: entry) else {
                return nil
            }
            return InstalledNativeApp(entry: entry, bundleIdentifier: bundleIdentifier)
        }
    }

    private func refreshNativeAppDirectory() {
        guard !isRefreshingNativeAppDirectory else { return }
        isRefreshingNativeAppDirectory = true
        Task {
            let directory = await NativeAppDirectoryService.shared.refresh()
            isRefreshingNativeAppDirectory = false
            guard let directory else {
                presentSettingsMessage(
                    "Couldn't Verify Native App Directory",
                    "The download, signature, or catalog version was rejected. A previously verified directory remains in use if available."
                )
                return
            }
            nativeAppDirectory = directory
        }
    }

    var generalSection: some View {
        @Bindable var manager = browserManager

        return SettingsDetailScaffold(
            title: "General",
            subtitle: "Startup, imports, system integration, and maintenance.",
            systemImage: "gearshape",
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsGroup("App Mode", subtitle: "Choose how Chowser lives on your Mac.") {
                        VStack(spacing: 8) {
                            AppModeOptionRow(
                                icon: "dock.rectangle",
                                title: "App",
                                subtitle: "Dock icon, appears in Cmd-Tab.",
                                isSelected: manager.appMode == .app
                            ) {
                                transitionAppMode(to: .app)
                            }
                            .accessibilityIdentifier("settings.appMode.app")

                            AppModeOptionRow(
                                icon: "menubar.rectangle",
                                title: "Menu Bar",
                                subtitle: "No Dock icon, lives in the menu bar only.",
                                isSelected: manager.appMode == .menuBar
                            ) {
                                transitionAppMode(to: .menuBar)
                            }
                            .accessibilityIdentifier("settings.appMode.menuBar")
                        }
                        .padding(14)
                    }

                    SettingsGroup("Startup") {
                        SettingsRow(
                            title: "Launch Chowser at login",
                            subtitle: "Start automatically when you sign in."
                        ) {
                            Toggle("", isOn: $manager.launchAtLogin)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }

                    SettingsGroup("Import Behavior") {
                        SettingsRow(title: "Skip existing rules", subtitle: "Ignore imported rules that already exist.") {
                            Toggle("", isOn: $manager.skipExistingImportedRules)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityIdentifier("settings.importRulesSkipExisting")
                        }

                        SettingsDivider()

                        SettingsRow(title: "Skip existing browsers", subtitle: "Ignore imported browsers that already exist.") {
                            Toggle("", isOn: $manager.skipExistingImportedBrowsers)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityIdentifier("settings.importBrowsersSkipExisting")
                        }
                    }

                    SettingsGroup("System") {
                        SettingsRow(
                            title: "Default Browser",
                            subtitle: BrowserManager.isDefaultBrowser()
                                ? "Chowser is currently the default browser."
                                : "Set Chowser as the default handler for HTTP and HTTPS links."
                        ) {
                            Button("Set as Default") {
                                BrowserManager.setAsDefaultBrowser()
                            }
                            .disabled(BrowserManager.isDefaultBrowser())
                            .controlSize(.small)
                            .accessibilityLabel("Set Chowser as the default browser")
                        }

                        SettingsDivider()

                        MCPServerSettingsRow()
                    }

                    updatesSettingsGroup

                    SettingsGroup("Maintenance") {
                        SettingsRow(
                            title: "Reset Setup",
                            subtitle: "Restore the first-launch state with Safari as option 1."
                        ) {
                            Button("Reset to Fresh Setup…", role: .destructive) {
                                showingResetConfirmation = true
                            }
                            .controlSize(.small)
                            .accessibilityIdentifier("settings.resetButton")
                        }

                        SettingsDivider()

                        SettingsRow(
                            title: "Replay Onboarding",
                            subtitle: "Open the Welcome and Setup flow again."
                        ) {
                            Button("Replay") {
                                OnboardingManager.shared.resetOnboarding()
                                OnboardingManager.shared.showOnboardingWindow {}
                            }
                            .controlSize(.small)
                        }
                    }

                    SettingsGroup("About") {
                        HStack(spacing: 12) {
                            Image(nsImage: BrowserManager.currentAppIcon())
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chowser")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("A browser chooser for macOS")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("Version \(appVersion)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                        .padding(14)

                        SettingsDivider()

                        SettingsRow(
                            title: "Diagnostics",
                            subtitle: "Review privacy-safe startup, App Mode, window, and termination events or export a support report."
                        ) {
                            Button("Open Diagnostics…") {
                                DiagnosticsWindowController.shared.showDiagnostics()
                            }
                            .controlSize(.small)
                            .accessibilityIdentifier("settings.diagnosticsButton")
                        }
                    }
                }
            }
        )
    }

    var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    @ViewBuilder
    private var updatesSettingsGroup: some View {
        #if DIRECT_DISTRIBUTION
        SettingsGroup(
            "Updates",
            subtitle: updateController.isConfigured
                ? "Keep the direct-download build current through signed GitHub releases."
                : "Update signing is not configured in this local build."
        ) {
            SettingsRow(
                title: "Check for updates automatically",
                subtitle: "Check once a day while Chowser is running."
            ) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { updateController.automaticallyChecksForUpdates },
                        set: { updateController.automaticallyChecksForUpdates = $0 }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!updateController.isConfigured)
                .accessibilityIdentifier("settings.updates.automaticChecks")
            }

            SettingsDivider()

            SettingsRow(
                title: "Download updates automatically",
                subtitle: "Download in the background and install when Chowser quits."
            ) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { updateController.automaticallyDownloadsUpdates },
                        set: { updateController.automaticallyDownloadsUpdates = $0 }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!updateController.isConfigured)
                .accessibilityIdentifier("settings.updates.automaticDownloads")
            }

            SettingsDivider()

            SettingsRow(
                title: "Include beta releases",
                subtitle: "Get early builds that may be less stable. Stable releases remain available."
            ) {
                Toggle("", isOn: $updateController.includesBetaReleases)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.updates.includeBeta")
            }

            SettingsDivider()

            SettingsRow(
                title: "Current Version",
                subtitle: "Version \(appVersion)"
            ) {
                Button("Check Now…") {
                    updateController.checkForUpdates()
                }
                .controlSize(.small)
                .disabled(!updateController.canCheckForUpdates)
                .accessibilityIdentifier("settings.updates.checkNow")
            }
        }
        #else
        SettingsGroup(
            "Updates",
            subtitle: "This build receives reviewed updates from Apple."
        ) {
            SettingsRow(
                title: "Managed by the Mac App Store",
                subtitle: "Automatic update preferences are controlled in the App Store."
            ) {
                Button("Open App Store…") {
                    appStoreUpdateProvider.openAppStore()
                }
                .controlSize(.small)
                .accessibilityIdentifier("settings.updates.openAppStore")
            }
        }
        #endif
    }

    private func addHiddenBundleIDFromField() {
        let trimmed = newHiddenBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        browserManager.addHiddenBundleID(trimmed)
        newHiddenBundleId = ""
    }

    @MainActor
    private func transitionAppMode(to mode: ChowserAppMode) {
        guard case .failure(let error) = AppDelegate.transitionAppMode(to: mode) else { return }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Could Not Change App Mode"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct InstalledNativeApp: Identifiable {
    let entry: NativeAppDirectoryEntry
    let bundleIdentifier: String

    var id: String { entry.id }
}

private struct NativeAppConsentRow: View {
    let entry: NativeAppDirectoryEntry
    let bundleIdentifier: String
    let isApproved: Bool
    let needsReview: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if let icon = BrowserManager.icon(forBrowserBundleID: bundleIdentifier) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 24))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(entry.name)
                            .font(.system(size: 13, weight: .semibold))
                        if needsReview {
                            Text("CHANGED — REVIEW AGAIN")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(entry.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(bundleIdentifier)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }

                Spacer()

                Toggle("Open links in \(entry.name)", isOn: Binding(
                    get: { isApproved },
                    set: onToggle
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.nativeApps.\(entry.id).toggle")
            }

            VStack(alignment: .leading, spacing: 5) {
                Label("Web hosts: \(sourceHosts.joined(separator: ", "))", systemImage: "globe")
                Label("Native schemes: \(entry.nativeSchemes.map { $0 + ":" }.joined(separator: ", "))", systemImage: "app.badge.checkmark")
                ForEach(entry.rules) { rule in
                    Text("• \(rule.reviewDescription)")
                        .textSelection(.enabled)
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)

            Label(
                "Approval is revoked automatically if hosts, bundle IDs, schemes, or transforms change.",
                systemImage: "checkmark.shield"
            )
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    private var sourceHosts: [String] {
        var hosts: [String] = []
        for host in entry.rules.flatMap(\.source.hosts) where !hosts.contains(host) {
            hosts.append(host)
        }
        return hosts
    }

}

private struct SettingsHiddenAppRow: View {
    let bundleId: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(bundleId)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button("Show", systemImage: "eye") {
                onRemove()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Show this app in the browser list")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct MCPServerSettingsRow: View {
    @State private var tokenCopied = false

    private let server = MCPServer.shared
    @Bindable private var manager = BrowserManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Local API Server")
                        .font(.system(size: 13, weight: .medium))

                    Text(server.isRunning ? "Running on port \(server.port)" : "Stopped")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(server.isRunning ? "Stop" : "Start") {
                    if server.isRunning {
                        server.stop()
                    } else {
                        server.start()
                    }
                }
                .controlSize(.small)
            }

            if server.isRunning {
                HStack(spacing: 8) {
                    Text(server.authToken)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("settings.mcpAuthToken")

                    Button(tokenCopied ? "Copied" : "Copy", systemImage: tokenCopied ? "checkmark" : "doc.on.clipboard") {
                        copyToken()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(tokenCopied ? .green : .secondary)
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Text("The server listens only on this Mac and requires the generated bearer token.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start automatically at launch")
                        .font(.system(size: 12, weight: .medium))
                    Text("Or set from Terminal: defaults write in.sreerams.Chowser mcpAutoStartEnabled -bool true")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Toggle("", isOn: $manager.mcpAutoStartEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.mcpAutoStart")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: server.isRunning)
    }

    private func copyToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.authToken, forType: .string)
        withAnimation { tokenCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { tokenCopied = false }
        }
    }
}
