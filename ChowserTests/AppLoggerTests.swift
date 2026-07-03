import Testing
import Foundation
@testable import Chowser

struct AppLoggerTests {
    /// Points the logger at a temp directory so tests never touch (or read) the
    /// real user's log files.
    private func withIsolatedLogsDirectory<T>(_ body: () throws -> T) rethrows -> T {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("applogger-tests-\(UUID().uuidString)", isDirectory: true)
        AppLogger.directoryOverrideForTesting = temp
        defer {
            AppLogger.directoryOverrideForTesting = nil
            try? FileManager.default.removeItem(at: temp)
        }
        return try body()
    }

    @Test("Logged lines appear in recent logs")
    func loggedLinesAppearInRecentLogs() async throws {
        try withIsolatedLogsDirectory {
            let marker = "test-marker-\(UUID().uuidString)"
            AppLogger.log("Test", marker)

            // Writes are queued to a utility queue; recentLogs syncs on the same queue,
            // so a single call after the write observes it.
            let logs = AppLogger.recentLogs(days: 1)
            #expect(logs.contains(marker))
            #expect(logs.contains("[INFO] [Test]"))
        }
    }

    @Test("Bug report file contains version, disclosure note, and recent logs")
    func bugReportContainsVersionAndLogs() async throws {
        try withIsolatedLogsDirectory {
            let marker = "bug-report-marker-\(UUID().uuidString)"
            AppLogger.error("Test", marker)

            let reportURL = try #require(AppLogger.createBugReportFile())
            let report = try String(contentsOf: reportURL, encoding: .utf8)
            #expect(report.contains("Chowser Bug Report"))
            #expect(report.contains("App version:"))
            #expect(report.contains("hostnames"))
            #expect(report.contains(marker))
            #expect(report.contains("[ERROR] [Test]"))
        }
    }
}
