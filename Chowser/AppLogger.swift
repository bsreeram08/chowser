import AppKit
import Foundation
import os

struct DiagnosticsSystemInfo: Equatable, Sendable {
    let appVersion: String
    let appBuild: String
    let macOSVersion: String
}

struct DiagnosticsSession: Equatable, Sendable {
    let id: UUID
    let previousSessionEndedUnexpectedly: Bool
}

struct DiagnosticsSnapshot: Equatable, Sendable {
    let logLocation: URL
    let recentEvents: String
    let previousSessionEndedUnexpectedly: Bool
    let systemInfo: DiagnosticsSystemInfo
}

enum DiagnosticsLifecycleBreadcrumb: Equatable, Sendable {
    case activationPolicyTransitionWillBegin(from: String, to: String)
    case activationPolicyTransitionDidComplete(presentationMode: String)
    case activationPolicyTransitionDidFail(from: String, to: String, reason: DiagnosticsTransitionFailureReason)
    case statusItemCreated
    case statusItemRemoved
    case settingsWindowPresented(created: Bool)
    case terminationWillBegin(presentationMode: String)
}

enum DiagnosticsTransitionFailureReason: String, Equatable, Sendable {
    case appDelegateUnavailable = "app-delegate-unavailable"
    case statusItemUnavailable = "status-item-unavailable"
    case activationPolicyRejected = "activation-policy-rejected"
    case rollbackFailed = "rollback-failed"
}

/// Lightweight file-backed logger for incident diagnosis. General logs remain
/// asynchronous, while reports read only the separate typed lifecycle log because
/// sandboxed builds cannot reliably read OSLogStore back.
enum AppLogger {
    private static let subsystem = "in.sreerams.Chowser"
    private static let queueKey = DispatchSpecificKey<UInt8>()
    private static let queue: DispatchQueue = {
        let queue = DispatchQueue(label: "in.sreerams.Chowser.applogger", qos: .utility)
        queue.setSpecific(key: queueKey, value: 1)
        return queue
    }()
    private static let retainedDays = 3
    private static let diagnosticsFilePrefix = "chowser-diagnostics-"
    private static let sessionMarkerName = ".active-diagnostics-session"

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
    nonisolated(unsafe) static var systemInfoOverrideForTesting: DiagnosticsSystemInfo?

    static var logsDirectory: URL {
        if let directoryOverrideForTesting { return directoryOverrideForTesting }
        if let testDirectory = AppEnvironment.automatedTestLogsDirectory { return testDirectory }
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

    /// Starts one diagnostics session and leaves a small marker on disk. A marker
    /// inherited from an earlier process means that process never recorded a clean end.
    @discardableResult
    static func beginSession(presentationMode: String) -> DiagnosticsSession {
        syncOnQueue {
            if let currentSession { return currentSession }

            let fileManager = FileManager.default
            let directory = logsDirectory
            let markerURL = directory.appendingPathComponent(sessionMarkerName)
            let previousSessionEndedUnexpectedly = fileManager.fileExists(atPath: markerURL.path)
            let session = DiagnosticsSession(
                id: UUID(),
                previousSessionEndedUnexpectedly: previousSessionEndedUnexpectedly
            )

            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let marker = ActiveSessionMarker(sessionID: session.id)
            let markerWasWritten: Bool
            if let data = try? JSONEncoder().encode(marker) {
                markerWasWritten = (try? data.write(to: markerURL, options: .atomic)) != nil
            } else {
                markerWasWritten = false
            }

            Self.previousSessionEndedUnexpectedly = previousSessionEndedUnexpectedly
            currentSession = session

            if previousSessionEndedUnexpectedly {
                _ = appendDiagnosticsLine("previous-session-ended-unexpectedly", in: directory)
            }
            if !markerWasWritten {
                _ = appendDiagnosticsLine("active-session-marker-write-failed", in: directory)
            }

            let info = systemInfo
            let mode = safePresentationMode(presentationMode)
            _ = appendDiagnosticsLine(
                "session-start id=\(session.id.uuidString) app=\(info.appVersion) build=\(info.appBuild) macOS=\(info.macOSVersion) presentation-mode=\(mode)",
                in: directory
            )
            return session
        }
    }

    /// Records a durable clean end before removing the active-session marker.
    /// If the write fails, the marker is deliberately retained for the next launch.
    @discardableResult
    static func endSessionCleanly(presentationMode: String) -> Bool {
        syncOnQueue {
            guard let session = currentSession else { return false }

            let directory = logsDirectory
            let mode = safePresentationMode(presentationMode)
            let wroteEnd = appendDiagnosticsLine(
                "session-end-clean id=\(session.id.uuidString) presentation-mode=\(mode)",
                in: directory
            )
            guard wroteEnd else { return false }

            let markerURL = directory.appendingPathComponent(sessionMarkerName)
            let markerMatches = (try? Data(contentsOf: markerURL))
                .flatMap { try? JSONDecoder().decode(ActiveSessionMarker.self, from: $0) }
                .map { $0.sessionID == session.id } ?? false
            if markerMatches {
                try? FileManager.default.removeItem(at: markerURL)
            }
            let markerRemoved = !FileManager.default.fileExists(atPath: markerURL.path)
            if markerRemoved {
                currentSession = nil
            }
            return markerRemoved
        }
    }

    /// Typed events prevent transition diagnostics from accepting URLs, paths,
    /// source-app identifiers, or arbitrary error text. This call is synchronous.
    @discardableResult
    static func recordCriticalLifecycleBreadcrumb(_ breadcrumb: DiagnosticsLifecycleBreadcrumb) -> Bool {
        syncOnQueue {
            let message: String
            switch breadcrumb {
            case let .activationPolicyTransitionWillBegin(from, to):
                message = "activation-policy-transition-will-begin from=\(safePresentationMode(from)) to=\(safePresentationMode(to))"
            case let .activationPolicyTransitionDidComplete(presentationMode):
                message = "activation-policy-transition-did-complete presentation-mode=\(safePresentationMode(presentationMode))"
            case let .activationPolicyTransitionDidFail(from, to, reason):
                message = "activation-policy-transition-did-fail from=\(safePresentationMode(from)) to=\(safePresentationMode(to)) reason=\(reason.rawValue)"
            case .statusItemCreated:
                message = "status-item-created"
            case .statusItemRemoved:
                message = "status-item-removed"
            case let .settingsWindowPresented(created):
                message = "settings-window-presented state=\(created ? "created" : "reused")"
            case let .terminationWillBegin(presentationMode):
                message = "termination-will-begin presentation-mode=\(safePresentationMode(presentationMode))"
            }
            return appendDiagnosticsLine(message, in: logsDirectory)
        }
    }

    /// Waits for ordinary asynchronous writes. The queue-specific check makes this
    /// safe even when a future logger operation needs to flush from the logging queue.
    static func flush() {
        syncOnQueue {}
    }

    /// Concatenated content of the last `days` daily log files, newest last.
    static func recentLogs(days: Int = 1) -> String {
        syncOnQueue {
            recentText(filePrefix: "chowser-", days: days, in: logsDirectory)
        }
    }

    static func diagnosticsSnapshot(days: Int = 2) -> DiagnosticsSnapshot {
        syncOnQueue {
            DiagnosticsSnapshot(
                logLocation: logsDirectory,
                recentEvents: recentText(filePrefix: diagnosticsFilePrefix, days: days, in: logsDirectory),
                previousSessionEndedUnexpectedly: previousSessionEndedUnexpectedly,
                systemInfo: systemInfo
            )
        }
    }

    static func diagnosticsReportText(days: Int = 2) -> String {
        syncOnQueue {
            reportText(for: DiagnosticsSnapshot(
                logLocation: logsDirectory,
                recentEvents: recentText(filePrefix: diagnosticsFilePrefix, days: days, in: logsDirectory),
                previousSessionEndedUnexpectedly: previousSessionEndedUnexpectedly,
                systemInfo: systemInfo
            ))
        }
    }

    /// Writes a diagnostics report (system info + typed lifecycle events) into the temp
    /// directory and returns its location.
    static func createBugReportFile() -> URL? {
        let report = diagnosticsReportText()
        let reportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chowser-diagnostics-report-\(UUID().uuidString).txt")
        do {
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            return reportURL
        } catch {
            Logger(subsystem: subsystem, category: "BugReport").error("Failed writing diagnostics report")
            return nil
        }
    }

    static func exportDiagnosticsReport(to destination: URL) throws {
        let report = diagnosticsReportText()
        try report.write(to: destination, atomically: true, encoding: .utf8)
    }

    /// Reveals the diagnostics report in Finder and opens a prefilled GitHub issue.
    /// The report is generated exclusively from the typed lifecycle channel.
    @MainActor
    static func startBugReport() {
        guard let reportURL = createBugReportFile() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([reportURL])

        let info = systemInfo
        let body = """
        **What happened?**

        (describe the issue)

        **Environment**
        - Chowser \(info.appVersion) (\(info.appBuild))
        - \(info.macOSVersion)

        **Diagnostics**
        Drag the revealed `chowser-diagnostics-report` text file into this issue.
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
        let directory = logsDirectory
        queue.async {
            let line = "\(timestampFormatter.string(from: Date())) [\(level)] [\(category)] \(message)\n"
            _ = append(line, filePrefix: "chowser-", in: directory, synchronize: false)
            pruneOldLogsIfNeeded(in: directory)
        }
    }

    /// Long-running menu-bar sessions cross day boundaries, so prune at most once per day.
    nonisolated(unsafe) private static var lastPrunedDay: String?
    nonisolated(unsafe) private static var currentSession: DiagnosticsSession?
    nonisolated(unsafe) private static var previousSessionEndedUnexpectedly = false

    private struct ActiveSessionMarker: Codable {
        let sessionID: UUID
    }

    private static var systemInfo: DiagnosticsSystemInfo {
        if let systemInfoOverrideForTesting { return systemInfoOverrideForTesting }
        return DiagnosticsSystemInfo(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }

    private static func syncOnQueue<T>(_ operation: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return try operation()
        }
        return try queue.sync(execute: operation)
    }

    private static func appendDiagnosticsLine(_ message: String, in directory: URL) -> Bool {
        let line = "\(timestampFormatter.string(from: Date())) [DIAGNOSTICS] \(message)\n"
        let wrote = append(line, filePrefix: diagnosticsFilePrefix, in: directory, synchronize: true)
        pruneOldLogsIfNeeded(in: directory)
        Logger(subsystem: subsystem, category: "Diagnostics").notice("\(message, privacy: .private)")
        return wrote
    }

    private static func append(
        _ line: String,
        filePrefix: String,
        in directory: URL,
        synchronize: Bool
    ) -> Bool {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent("\(filePrefix)\(dayFormatter.string(from: Date())).log")
            if !fileManager.fileExists(atPath: fileURL.path) {
                guard fileManager.createFile(atPath: fileURL.path, contents: nil) else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
            if synchronize { try handle.synchronize() }
            return true
        } catch {
            Logger(subsystem: subsystem, category: "Diagnostics").error("Failed writing local log")
            return false
        }
    }

    private static func recentText(filePrefix: String, days: Int, in directory: URL) -> String {
        let calendar = Calendar.current
        let fileURLs = (0..<max(1, days)).reversed().compactMap { offset -> URL? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return directory.appendingPathComponent("\(filePrefix)\(dayFormatter.string(from: day)).log")
        }
        return fileURLs
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    private static func reportText(for snapshot: DiagnosticsSnapshot) -> String {
        let events = snapshot.recentEvents.isEmpty ? "(no lifecycle events recorded)" : snapshot.recentEvents
        return """
        Chowser Diagnostics Report
        ==========================
        App version: \(snapshot.systemInfo.appVersion) (\(snapshot.systemInfo.appBuild))
        macOS: \(snapshot.systemInfo.macOSVersion)
        Previous session ended unexpectedly: \(snapshot.previousSessionEndedUnexpectedly ? "yes" : "no")
        Generated: \(timestampFormatter.string(from: Date()))

        Privacy: This report contains only typed app lifecycle events. It excludes
        visited URLs and hostnames, source applications, usernames, clipboard data,
        local file paths, and arbitrary error descriptions.

        Lifecycle events (last 2 days)
        ------------------------------
        \(events)
        """
    }

    private static func safePresentationMode(_ mode: String) -> String {
        switch mode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "app", "regular", "app mode":
            return "app"
        case "menu bar", "menu-bar", "menubar", "accessory", "menu bar mode":
            return "menu-bar"
        case "prohibited", "none":
            return "prohibited"
        default:
            return "unknown"
        }
    }

    private static func pruneOldLogsIfNeeded(in directory: URL) {
        let today = dayFormatter.string(from: Date())
        guard lastPrunedDay != today else { return }
        lastPrunedDay = today
        pruneOldLogs(in: directory, fileManager: .default)
    }

    static func resetDiagnosticsStateForTesting(preservingSessionMarker: Bool = true) {
        syncOnQueue {
            currentSession = nil
            previousSessionEndedUnexpectedly = false
            lastPrunedDay = nil
            if !preservingSessionMarker {
                try? FileManager.default.removeItem(
                    at: logsDirectory.appendingPathComponent(sessionMarkerName)
                )
            }
        }
    }

    private static func pruneOldLogs(in directory: URL, fileManager: FileManager) {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -(retainedDays - 1), to: Date()) else { return }
        let cutoffDay = dayFormatter.string(from: cutoff)
        for file in files {
            let name = file.lastPathComponent
            let prefix = name.hasPrefix(diagnosticsFilePrefix) ? diagnosticsFilePrefix : "chowser-"
            guard name.hasPrefix(prefix), name.hasSuffix(".log") else { continue }
            let day = name.dropFirst(prefix.count).dropLast(4)
            if day < cutoffDay {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
