import Testing
import Foundation
@testable import Chowser

@MainActor
struct UpdateManagerTests {

    // MARK: - Initial State

    @Test("Starts with no update available and no latest version")
    func initialState() {
        let manager = UpdateManager.shared
        #expect(manager.updateAvailable == false)
        #expect(manager.latestVersion == nil)
    }

    @Test("currentVersion returns a non-empty string from the bundle")
    func currentVersionNonEmpty() {
        #expect(UpdateManager.shared.currentVersion.isEmpty == false)
    }

    // MARK: - Version Comparison

    @Test("Newer major version is detected as an update")
    func newerMajor() {
        let m = UpdateManager.shared
        #expect(m.isNewerVersion("2.0.0", than: "1.9.9") == true)
    }

    @Test("Newer minor version is detected as an update")
    func newerMinor() {
        let m = UpdateManager.shared
        #expect(m.isNewerVersion("1.1.0", than: "1.0.9") == true)
    }

    @Test("Newer patch version is detected as an update")
    func newerPatch() {
        let m = UpdateManager.shared
        #expect(m.isNewerVersion("1.0.1", than: "1.0.0") == true)
    }

    @Test("Equal versions are not treated as an update")
    func equalVersions() {
        let m = UpdateManager.shared
        #expect(m.isNewerVersion("1.2.3", than: "1.2.3") == false)
    }

    @Test("Older store version is not treated as an update")
    func olderStoreVersion() {
        let m = UpdateManager.shared
        #expect(m.isNewerVersion("1.0.0", than: "1.0.1") == false)
        #expect(m.isNewerVersion("0.9.9", than: "1.0.0") == false)
    }

    @Test("Shorter version string is padded with zeros for comparison")
    func shorterVersionPadded() {
        let m = UpdateManager.shared
        // "2" vs "1.9.9" — store major is higher
        #expect(m.isNewerVersion("2", than: "1.9.9") == true)
        // "1.1" vs "1.0.99" — store minor is higher
        #expect(m.isNewerVersion("1.1", than: "1.0.99") == true)
        // "1.0" == "1.0.0"
        #expect(m.isNewerVersion("1.0", than: "1.0.0") == false)
    }

    @Test("Pre-release local version is not falsely shown as outdated")
    func localAheadOfStore() {
        let m = UpdateManager.shared
        // e.g. developer has a newer local build than what's on the store
        #expect(m.isNewerVersion("1.0.0", than: "1.1.0") == false)
    }

    // MARK: - TestFlight Detection

    @Test("isTestFlight is false when no sandboxReceipt file exists")
    func testFlightFalseWithoutReceipt() throws {
        let m = UpdateManager.shared
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // No receipt file created — should be false
        #expect(m.hasSandboxReceipt(in: tempDir) == false)
    }

    @Test("isTestFlight is true when sandboxReceipt file exists at expected path")
    func testFlightTrueWithReceipt() throws {
        let m = UpdateManager.shared
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let receiptDir = tempDir.appendingPathComponent("Contents/_MASReceipt")
        try FileManager.default.createDirectory(at: receiptDir, withIntermediateDirectories: true)
        let receiptFile = receiptDir.appendingPathComponent("sandboxReceipt")
        FileManager.default.createFile(atPath: receiptFile.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(m.hasSandboxReceipt(in: tempDir) == true)
    }

    @Test("isTestFlight is false when only the production receipt exists (App Store build)")
    func testFlightFalseWithProductionReceipt() throws {
        let m = UpdateManager.shared
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let receiptDir = tempDir.appendingPathComponent("Contents/_MASReceipt")
        try FileManager.default.createDirectory(at: receiptDir, withIntermediateDirectories: true)
        // Create the production receipt, NOT the sandbox one
        let receiptFile = receiptDir.appendingPathComponent("receipt")
        FileManager.default.createFile(atPath: receiptFile.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(m.hasSandboxReceipt(in: tempDir) == false)
    }

    @Test("Running in test environment is not detected as TestFlight")
    func notTestFlightInTestEnvironment() {
        // Unit tests run from a standard .xctest bundle — no sandboxReceipt
        #expect(UpdateManager.shared.isTestFlight == false)
    }
}
