import Testing
import Foundation
@testable import Chowser

@Suite(.serialized)
struct AppLoggerTests {
    private let testSystemInfo = DiagnosticsSystemInfo(
        appVersion: "9.8.7",
        appBuild: "654",
        macOSVersion: "macOS Test 14.0"
    )

    /// Points the logger at a temp directory so tests never touch (or read) the
    /// real user's log files.
    private func withIsolatedLogsDirectory<T>(_ body: () throws -> T) rethrows -> T {
        AppLogger.flush()
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("applogger-tests-\(UUID().uuidString)", isDirectory: true)
        let previousDirectoryOverride = AppLogger.directoryOverrideForTesting
        let previousSystemInfoOverride = AppLogger.systemInfoOverrideForTesting
        AppLogger.directoryOverrideForTesting = temp
        AppLogger.systemInfoOverrideForTesting = testSystemInfo
        AppLogger.resetDiagnosticsStateForTesting(preservingSessionMarker: false)
        defer {
            AppLogger.flush()
            AppLogger.resetDiagnosticsStateForTesting(preservingSessionMarker: false)
            AppLogger.directoryOverrideForTesting = previousDirectoryOverride
            AppLogger.systemInfoOverrideForTesting = previousSystemInfoOverride
            try? FileManager.default.removeItem(at: temp)
        }
        return try body()
    }

    @Test("Logged lines appear in recent logs")
    func loggedLinesAppearInRecentLogs() {
        withIsolatedLogsDirectory {
            let marker = "test-marker-\(UUID().uuidString)"
            AppLogger.log("Test", marker)

            // Writes are queued to a utility queue; recentLogs syncs on the same queue,
            // so a single call after the write observes it.
            let logs = AppLogger.recentLogs(days: 1)
            #expect(logs.contains(marker))
            #expect(logs.contains("[INFO] [Test]"))
        }
    }

    @Test("Session start and clean end record durable markers")
    func sessionStartAndCleanEnd() {
        withIsolatedLogsDirectory {
            let session = AppLogger.beginSession(presentationMode: "App Mode")
            #expect(!session.previousSessionEndedUnexpectedly)
            #expect(AppLogger.endSessionCleanly(presentationMode: "app"))

            let snapshot = AppLogger.diagnosticsSnapshot()
            #expect(snapshot.recentEvents.contains("session-start id=\(session.id.uuidString)"))
            #expect(snapshot.recentEvents.contains("app=9.8.7 build=654"))
            #expect(snapshot.recentEvents.contains("macOS=macOS Test 14.0"))
            #expect(snapshot.recentEvents.contains("presentation-mode=app"))
            #expect(snapshot.recentEvents.contains("session-end-clean id=\(session.id.uuidString)"))

            AppLogger.resetDiagnosticsStateForTesting()
            let nextSession = AppLogger.beginSession(presentationMode: "menu bar")
            #expect(!nextSession.previousSessionEndedUnexpectedly)
        }
    }

    @Test("An active marker reports the previous session as unexpected")
    func unexpectedPreviousSession() {
        withIsolatedLogsDirectory {
            _ = AppLogger.beginSession(presentationMode: "menu bar")

            // Preserve the marker while clearing process memory to simulate a crash/relaunch.
            AppLogger.resetDiagnosticsStateForTesting(preservingSessionMarker: true)
            let relaunchedSession = AppLogger.beginSession(presentationMode: "menu bar")

            #expect(relaunchedSession.previousSessionEndedUnexpectedly)
            let snapshot = AppLogger.diagnosticsSnapshot()
            #expect(snapshot.previousSessionEndedUnexpectedly)
            #expect(snapshot.recentEvents.contains("previous-session-ended-unexpectedly"))
        }
    }

    @Test("Flush and critical breadcrumbs are immediately visible")
    func flushAndCriticalBreadcrumbVisibility() throws {
        try withIsolatedLogsDirectory {
            let marker = "flush-marker-\(UUID().uuidString)"
            AppLogger.log("Test", marker)
            AppLogger.flush()

            let files = try FileManager.default.contentsOfDirectory(
                at: AppLogger.logsDirectory,
                includingPropertiesForKeys: nil
            )
            let ordinaryLog = try #require(files.first {
                $0.lastPathComponent.hasPrefix("chowser-")
                    && !$0.lastPathComponent.hasPrefix("chowser-diagnostics-")
            })
            #expect(try String(contentsOf: ordinaryLog, encoding: .utf8).contains(marker))

            #expect(AppLogger.recordCriticalLifecycleBreadcrumb(
                .activationPolicyTransitionWillBegin(from: "menu bar", to: "app")
            ))
            let report = AppLogger.diagnosticsReportText()
            #expect(report.contains("activation-policy-transition-will-begin from=menu-bar to=app"))
        }
    }

    @Test("Diagnostics reports include lifecycle metadata and exclude private general logs")
    func reportContentAndPrivacy() throws {
        try withIsolatedLogsDirectory {
            _ = AppLogger.beginSession(presentationMode: "https://private.example/secret")
            AppLogger.log("Test", "ordinary-log-fixture")
            AppLogger.flush()
            let ordinaryLog = try #require(
                FileManager.default.contentsOfDirectory(
                    at: AppLogger.logsDirectory,
                    includingPropertiesForKeys: nil
                ).first {
                    $0.lastPathComponent.hasPrefix("chowser-")
                        && !$0.lastPathComponent.hasPrefix("chowser-diagnostics-")
                }
            )
            try "https://private.example/secret /Users/alice/private.txt com.private.source"
                .write(to: ordinaryLog, atomically: true, encoding: .utf8)
            #expect(AppLogger.recordCriticalLifecycleBreadcrumb(
                .activationPolicyTransitionWillBegin(
                    from: "/Users/alice/private-mode",
                    to: "regular"
                )
            ))

            let reportURL = try #require(AppLogger.createBugReportFile())
            defer { try? FileManager.default.removeItem(at: reportURL) }
            let report = try String(contentsOf: reportURL, encoding: .utf8)
            #expect(report.contains("Chowser Diagnostics Report"))
            #expect(report.contains("App version: 9.8.7 (654)"))
            #expect(report.contains("macOS: macOS Test 14.0"))
            #expect(report.contains("session-start"))
            #expect(report.contains("presentation-mode=unknown"))
            #expect(report.contains("from=unknown to=app"))
            #expect(report.contains("local file paths"))
            #expect(!report.contains("private.example"))
            #expect(!report.contains("/Users/alice"))
            #expect(!report.contains("com.private.source"))
            #expect(!report.contains("[ERROR] [Test]"))
            #expect(!report.contains(AppLogger.logsDirectory.path))
        }
    }

    @Test("Retention keeps exactly the configured three calendar days")
    func retentionBoundary() throws {
        try withIsolatedLogsDirectory {
            let calendar = Calendar.current
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current

            let retainedDate = try #require(calendar.date(byAdding: .day, value: -2, to: Date()))
            let expiredDate = try #require(calendar.date(byAdding: .day, value: -3, to: Date()))
            let retained = AppLogger.logsDirectory.appendingPathComponent("chowser-\(formatter.string(from: retainedDate)).log")
            let expired = AppLogger.logsDirectory.appendingPathComponent("chowser-diagnostics-\(formatter.string(from: expiredDate)).log")
            try FileManager.default.createDirectory(at: AppLogger.logsDirectory, withIntermediateDirectories: true)
            try "retained".write(to: retained, atomically: true, encoding: .utf8)
            try "expired".write(to: expired, atomically: true, encoding: .utf8)

            AppLogger.log("Test", "trigger daily prune")
            AppLogger.flush()

            #expect(FileManager.default.fileExists(atPath: retained.path))
            #expect(!FileManager.default.fileExists(atPath: expired.path))
        }
    }
}
