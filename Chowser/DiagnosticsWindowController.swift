import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DiagnosticsWindowController: NSWindowController {
    static let shared = DiagnosticsWindowController()

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDiagnostics() {
        let snapshot = AppLogger.diagnosticsSnapshot()
        let view = DiagnosticsView(
            snapshot: snapshot,
            copyAction: { Self.copyReport() },
            exportAction: { [weak self] in self?.exportReport() },
            revealAction: { Self.revealLogs(snapshot.logLocation) },
            reportProblemAction: { AppLogger.startBugReport() },
            closeAction: { [weak self] in self?.close() }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = [.preferredContentSize]

        if let window {
            window.contentView = hostingView
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            window.title = "Chowser Diagnostics"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .windowBackgroundColor
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 560, height: 420)
            window.center()
            self.window = window
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func copyReport() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(AppLogger.diagnosticsReportText(), forType: .string)
    }

    private func exportReport() {
        let panel = NSSavePanel()
        panel.title = "Export Diagnostics Report"
        panel.nameFieldStringValue = "chowser-diagnostics-report.txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try AppLogger.exportDiagnosticsReport(to: destination)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "The diagnostics report could not be exported."
            alert.informativeText = "Choose another location and try again."
            alert.runModal()
        }
    }

    private static func revealLogs(_ directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }
}

private struct DiagnosticsView: View {
    let snapshot: DiagnosticsSnapshot
    let copyAction: () -> Void
    let exportAction: () -> Void
    let revealAction: () -> Void
    let reportProblemAction: () -> Void
    let closeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Diagnostics")
                    .font(.title2.weight(.semibold))
                Text("Privacy-safe lifecycle events for troubleshooting startup, mode changes, and termination.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                Label("Chowser \(snapshot.systemInfo.appVersion) (\(snapshot.systemInfo.appBuild))", systemImage: "app.badge")
                Label(snapshot.systemInfo.macOSVersion, systemImage: "desktopcomputer")
            }
            .font(.callout)

            if snapshot.previousSessionEndedUnexpectedly {
                Label("Previous session ended unexpectedly", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout.weight(.medium))
                    .accessibilityIdentifier("diagnosticsUnexpectedSession")
            }

            GroupBox("Recent lifecycle events") {
                ScrollView {
                    Text(snapshot.recentEvents.isEmpty ? "No lifecycle events recorded." : snapshot.recentEvents)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityIdentifier("diagnosticsRecentEvents")
                .accessibilityValue(snapshot.recentEvents)
            }
            .frame(maxHeight: .infinity)

            Text("Reports contain only app and system versions plus typed lifecycle events. Browsing data and local paths are excluded. Raw logs may contain rule, browser, or error details; review them before sharing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Copy", action: copyAction)
                Button("Export Report…", action: exportAction)
                Button("Reveal Raw Logs", action: revealAction)
                Button("Report a Problem…", action: reportProblemAction)
                Spacer()
                Button("Close", action: closeAction)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(minWidth: 560, idealWidth: 680, minHeight: 420, idealHeight: 560)
    }
}
