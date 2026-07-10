import AppKit
import Testing
@testable import Chowser

struct AppModeTransitionTests {
    @Test("Reopen is deferred only when no URL open is in flight")
    func reopenSuppression() {
        #expect(!AppDelegate.shouldScheduleDeferredReopen(
            hasVisibleWindows: false,
            secondsSinceLastURLOpen: 0.1
        ))
        #expect(!AppDelegate.shouldScheduleDeferredReopen(
            hasVisibleWindows: true,
            secondsSinceLastURLOpen: 10
        ))
        #expect(AppDelegate.shouldScheduleDeferredReopen(
            hasVisibleWindows: false,
            secondsSinceLastURLOpen: 10
        ))
    }

    @Test("Menu Bar transition creates status item before hiding the Dock icon")
    @MainActor
    func menuBarTransitionOrder() {
        var events: [String] = []

        let result = AppDelegate.performAppModeTransition(
            to: .menuBar,
            currentMode: .app,
            ensureStatusItem: { events.append("status-created"); return true },
            setActivationPolicy: { events.append("policy-\($0.rawValue)"); return true },
            removeStatusItem: { events.append("status-removed") },
            persistMode: { events.append("persist-\($0.rawValue)") }
        )

        if case .failure(let error) = result {
            Issue.record("Expected success, got \(error)")
        }
        #expect(events == ["status-created", "policy-\(NSApplication.ActivationPolicy.accessory.rawValue)", "persist-menuBar"])
    }

    @Test("App transition shows the Dock icon before removing the status item")
    @MainActor
    func appTransitionOrder() {
        var events: [String] = []

        let result = AppDelegate.performAppModeTransition(
            to: .app,
            currentMode: .menuBar,
            ensureStatusItem: { events.append("status-created"); return true },
            setActivationPolicy: { events.append("policy-\($0.rawValue)"); return true },
            removeStatusItem: { events.append("status-removed") },
            persistMode: { events.append("persist-\($0.rawValue)") }
        )

        if case .failure(let error) = result {
            Issue.record("Expected success, got \(error)")
        }
        #expect(events == ["policy-\(NSApplication.ActivationPolicy.regular.rawValue)", "status-removed", "persist-app"])
    }

    @Test("Missing status item rolls back to reachable App Mode")
    @MainActor
    func statusItemFailureRollsBack() {
        var events: [String] = []

        let result = AppDelegate.performAppModeTransition(
            to: .menuBar,
            currentMode: .app,
            ensureStatusItem: { events.append("status-failed"); return false },
            setActivationPolicy: { events.append("policy-\($0.rawValue)"); return true },
            removeStatusItem: { events.append("status-removed") },
            persistMode: { events.append("persist-\($0.rawValue)") }
        )

        guard case .failure(.statusItemUnavailable) = result else {
            Issue.record("Expected statusItemUnavailable")
            return
        }
        #expect(events == ["status-failed"])
    }

    @Test("Rejected accessory policy removes the attempted item and rolls back")
    @MainActor
    func accessoryFailureRollsBack() {
        var events: [String] = []

        let result = AppDelegate.performAppModeTransition(
            to: .menuBar,
            currentMode: .app,
            ensureStatusItem: { events.append("status-created"); return true },
            setActivationPolicy: {
                events.append("policy-\($0.rawValue)")
                return $0 == .regular
            },
            removeStatusItem: { events.append("status-removed") },
            persistMode: { events.append("persist-\($0.rawValue)") }
        )

        guard case .failure(.activationPolicyRejected(.menuBar)) = result else {
            Issue.record("Expected menuBar activationPolicyRejected")
            return
        }
        #expect(events == [
            "status-created",
            "policy-\(NSApplication.ActivationPolicy.accessory.rawValue)",
            "policy-\(NSApplication.ActivationPolicy.regular.rawValue)",
            "status-removed",
            "persist-app",
        ])
    }

    @Test("Rejected regular policy leaves the menu item and persisted mode unchanged")
    @MainActor
    func regularFailurePreservesCurrentMode() {
        var events: [String] = []

        let result = AppDelegate.performAppModeTransition(
            to: .app,
            currentMode: .menuBar,
            ensureStatusItem: { events.append("status-created"); return true },
            setActivationPolicy: { events.append("policy-\($0.rawValue)"); return false },
            removeStatusItem: { events.append("status-removed") },
            persistMode: { events.append("persist-\($0.rawValue)") }
        )

        guard case .failure(.activationPolicyRejected(.app)) = result else {
            Issue.record("Expected app activationPolicyRejected")
            return
        }
        #expect(events == ["policy-\(NSApplication.ActivationPolicy.regular.rawValue)"])
    }

    @Test("Failed accessory rollback keeps the status item as a recovery entry point")
    @MainActor
    func failedRollbackKeepsRecoveryEntryPoint() {
        var events: [String] = []

        let result = AppDelegate.performAppModeTransition(
            to: .menuBar,
            currentMode: .app,
            ensureStatusItem: { events.append("status-created"); return true },
            setActivationPolicy: { events.append("policy-\($0.rawValue)"); return false },
            removeStatusItem: { events.append("status-removed") },
            persistMode: { events.append("persist-\($0.rawValue)") }
        )

        guard case .failure(.rollbackFailed(.menuBar)) = result else {
            Issue.record("Expected menuBar rollbackFailed")
            return
        }
        #expect(events == [
            "status-created",
            "policy-\(NSApplication.ActivationPolicy.accessory.rawValue)",
            "policy-\(NSApplication.ActivationPolicy.regular.rawValue)",
            "persist-menuBar",
        ])
    }
}
