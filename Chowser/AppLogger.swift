import AppKit
import Foundation
import os

/// Lightweight file-backed logger for incident diagnosis. Mirrors to the unified log
/// (os.Logger) and appends to daily files under Application Support so "Report a Bug"
/// can bundle the last day's activity — sandboxed builds can't read OSLogStore back,
/// which is why the file copy exists.
enum AppLogger {
    private static let subsystem = "in.sreerams.Chowser"
    private static let queue = DispatchQueue(label: "in.sreerams.Chowser.applogger", qos: .utility)
    private static let retainedDays = 3

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    /// Tests point this at a temp directory so they never touch the real user's logs.
    nonisolated(unsafe) static var directoryOverrideForTesting: URL?

    static var logsDirectory: URL {
        if let directoryOverrideForTesting { return directoryOverrideForTesting }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Chowser/Logs", isDirectory: true)
    }

    static func log(_ category: String, _ message: String) {
        write(level: "INFO", category: category, message: message)
        // Default (redacting) privacy: visited hosts must not be readable in the
        // unified log / sysdiagnoses. The local file keeps the full detail.
        Logger(subsystem: subsystem, category: category).info("\(message, privacy: .private)")
    }

    static func error(_ category: String, _ message: String) {
        write(level: "ERROR", category: category, message: message)
        Logger(subsystem: subsystem, category: category).error("\(message, privacy: .private)")
    }

    /// Concatenated content of the last `days` daily log files, newest last.
    static func recentLogs(days: Int = 1) -> String {
        let calendar = Calendar.current
        let fileURLs = (0...max(0, days)).reversed().compactMap { offset -> URL? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return logsDirectory.appendingPathComponent("chowser-\(dayFormatter.string(from: day)).log")
        }
        return queue.sync {
            fileURLs
                .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
                .joined(separator: "\n")
        }
    }

    /// Writes a bug-report text file (system info + recent logs) into the temp
    /// directory and returns its location.
    static func createBugReportFile() -> URL? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        var report = """
        Chowser Bug Report
        ==================
        App version: \(version) (\(build))
        macOS: \(osVersion)
        Generated: \(timestampFormatter.string(from: Date()))

        NOTE: The log below includes the hostnames of links Chowser handled in the
        last two days. Review before sharing.

        Logs (last 2 days)
        ------------------

        """
        let logs = recentLogs(days: 1)
        report += logs.isEmpty ? "(no logs recorded)" : logs

        let reportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chowser-bug-report.txt")
        do {
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            return reportURL
        } catch {
            Logger(subsystem: subsystem, category: "BugReport").error("Failed writing bug report: \(error)")
            return nil
        }
    }

    /// Reveals the bug-report file in Finder and opens a prefilled GitHub issue.
    /// Logs are attached by dragging the revealed file into the issue — GitHub URLs
    /// can't carry a day of logs in the query string.
    @MainActor
    static func startBugReport() {
        guard let reportURL = createBugReportFile() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([reportURL])

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let body = """
        **What happened?**

        (describe the issue)

        **Environment**
        - Chowser \(version) (\(build))
        - \(ProcessInfo.processInfo.operatingSystemVersionString)

        **Logs**
        Drag `chowser-bug-report.txt` (revealed in Finder) into this issue.
        """
        var components = URLComponents(string: "https://github.com/bsreeram08/chowser/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "title", value: "[Bug] "),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private static func write(level: String, category: String, message: String) {
        let line = "\(timestampFormatter.string(from: Date())) [\(level)] [\(category)] \(message)\n"
        queue.async {
            let fileManager = FileManager.default
            let directory = logsDirectory
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let fileURL = directory.appendingPathComponent("chowser-\(dayFormatter.string(from: Date())).log")
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            } else {
                try? Data(line.utf8).write(to: fileURL)
            }

            if !hasPruned {
                hasPruned = true
                pruneOldLogs(in: directory, fileManager: fileManager)
            }
        }
    }

    /// Prune is cheap but pointless per-line; once per launch is plenty.
    nonisolated(unsafe) private static var hasPruned = false

    private static func pruneOldLogs(in directory: URL, fileManager: FileManager) {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retainedDays, to: Date()) else { return }
        let cutoffName = "chowser-\(dayFormatter.string(from: cutoff)).log"
        for file in files where file.lastPathComponent.hasPrefix("chowser-") && file.lastPathComponent < cutoffName {
            try? fileManager.removeItem(at: file)
        }
    }
}
