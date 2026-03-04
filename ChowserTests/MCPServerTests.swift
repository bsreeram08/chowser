import Testing
import Foundation
@testable import Chowser

// Run serially — MCPServer is a singleton and binds a real port
@Suite(.serialized)
@MainActor
struct MCPServerTests {

    private let testPort: UInt16 = 24246

    // MARK: - Helpers

    /// Polls `condition` up to `timeout`, returning whether it became true.
    private func waitFor(
        timeout: Duration = .seconds(3),
        condition: () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(30))
        }
        return condition()
    }

    private func startAndWait() async {
        MCPServer.shared.start(port: testPort)
        _ = await waitFor { MCPServer.shared.isRunning }
    }

    private func stopAndWait() async {
        MCPServer.shared.stop()
        _ = await waitFor { !MCPServer.shared.isRunning }
        // Brief pause so the OS releases the port before the next test
        try? await Task.sleep(for: .milliseconds(100))
    }

    // Minimal HTTP helpers — avoids URLSession config noise in test bodies

    private func get(_ path: String) async throws -> (Int, [String: Any]) {
        let url = URL(string: "http://localhost:\(testPort)\(path)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as! HTTPURLResponse).statusCode
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return (status, json)
    }

    private func post(_ path: String, token: String?, body: [String: Any]) async throws -> (Int, [String: Any]) {
        var req = URLRequest(url: URL(string: "http://localhost:\(testPort)\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue(token, forHTTPHeaderField: "X-Chowser-Token") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as! HTTPURLResponse).statusCode
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return (status, json)
    }

    private func delete(_ path: String, token: String?) async throws -> (Int, [String: Any]) {
        var req = URLRequest(url: URL(string: "http://localhost:\(testPort)\(path)")!)
        req.httpMethod = "DELETE"
        if let token { req.setValue(token, forHTTPHeaderField: "X-Chowser-Token") }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as! HTTPURLResponse).statusCode
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return (status, json)
    }

    // MARK: - Lifecycle / State

    @Test("Server is stopped and has no token before first start")
    func initialState() async {
        // Ensure clean state in case a previous test leaked
        if MCPServer.shared.isRunning { await stopAndWait() }
        #expect(MCPServer.shared.isRunning == false)
        #expect(MCPServer.shared.authToken == "")
    }

    /// Regression test for the App Store rejection bug:
    /// `isRunning` must only become `true` once the NWListener actually reaches `.ready`,
    /// not synchronously inside `start()`. Previously `isRunning = true` was set before the
    /// listener was ready, so a sandbox-denied bind caused an async `stop()` that immediately
    /// reverted the toggle in the UI.
    @Test("isRunning becomes true only after listener reaches .ready (not synchronously)")
    func isRunningSetAsynchronously() async {
        defer { Task { await self.stopAndWait() } }

        // Capture the value synchronously right after start() returns
        MCPServer.shared.start(port: testPort)
        let synchronousValue = MCPServer.shared.isRunning

        // Wait for the async .ready callback
        _ = await waitFor { MCPServer.shared.isRunning }

        // The value should NOT have been true the instant start() returned
        #expect(synchronousValue == false, "isRunning must not be set synchronously in start()")
        // And it must eventually become true (listener did bind)
        #expect(MCPServer.shared.isRunning == true)
    }

    @Test("stop() immediately sets isRunning false and clears auth token")
    func stopClearsState() async {
        await startAndWait()
        MCPServer.shared.stop()
        #expect(MCPServer.shared.isRunning == false)
        #expect(MCPServer.shared.authToken == "")
        await stopAndWait() // flush port release
    }

    @Test("Calling start() while already running is a no-op")
    func doubleStartIsNoOp() async {
        defer { Task { await self.stopAndWait() } }
        await startAndWait()
        let tokenBefore = MCPServer.shared.authToken
        MCPServer.shared.start(port: testPort)
        #expect(MCPServer.shared.authToken == tokenBefore)
        #expect(MCPServer.shared.isRunning == true)
    }

    @Test("Each start generates a distinct auth token")
    func uniqueTokenPerStart() async {
        await startAndWait()
        let token1 = MCPServer.shared.authToken
        #expect(token1.isEmpty == false)
        await stopAndWait()

        await startAndWait()
        let token2 = MCPServer.shared.authToken
        await stopAndWait()

        #expect(token2.isEmpty == false)
        #expect(token1 != token2)
    }

    // MARK: - GET Endpoints (no auth required)

    @Test("GET /status returns 200 with expected shape")
    func statusEndpoint() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await get("/status")
        #expect(status == 200)
        #expect(body["status"] as? String == "ok")
        #expect(body["app"] as? String == "Chowser")
        #expect(body["version"] != nil)
        #expect(body["browsers_count"] != nil)
        #expect(body["rules_count"] != nil)
    }

    @Test("GET /browsers returns 200 with browsers array")
    func getBrowsers() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await get("/browsers")
        #expect(status == 200)
        #expect(body["browsers"] is [Any])
    }

    @Test("GET /rules returns 200 with rules array")
    func getRules() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await get("/rules")
        #expect(status == 200)
        #expect(body["rules"] is [Any])
    }

    @Test("GET to unknown path returns 404")
    func unknownPath() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, _) = try await get("/doesnotexist")
        #expect(status == 404)
    }

    // MARK: - Auth Enforcement (POST / DELETE)

    @Test("POST /browsers without token returns 401")
    func postBrowserNoToken() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await post("/browsers", token: nil,
            body: ["name": "Chrome", "bundleId": "com.google.Chrome"])
        #expect(status == 401)
        #expect(body["error"] != nil)
    }

    @Test("POST /browsers with wrong token returns 401")
    func postBrowserWrongToken() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await post("/browsers", token: "not-the-real-token",
            body: ["name": "Chrome", "bundleId": "com.google.Chrome"])
        #expect(status == 401)
        #expect(body["error"] != nil)
    }

    @Test("POST /rules without token returns 401")
    func postRuleNoToken() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await post("/rules", token: nil,
            body: ["hostPattern": "example.com", "browserBundleId": "com.apple.Safari"])
        #expect(status == 401)
        #expect(body["error"] != nil)
    }

    @Test("DELETE /browsers without token returns 401")
    func deleteBrowserNoToken() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await delete("/browsers?id=\(UUID().uuidString)", token: nil)
        #expect(status == 401)
        #expect(body["error"] != nil)
    }

    @Test("DELETE /rules without token returns 401")
    func deleteRuleNoToken() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await delete("/rules?id=\(UUID().uuidString)", token: nil)
        #expect(status == 401)
        #expect(body["error"] != nil)
    }

    // MARK: - Request Validation (authenticated, bad input)

    @Test("POST /browsers missing bundleId returns 400")
    func postBrowserMissingBundleId() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await post("/browsers", token: MCPServer.shared.authToken,
            body: ["name": "Chrome"]) // bundleId missing
        #expect(status == 400)
        #expect(body["error"] != nil)
    }

    @Test("POST /rules missing browserBundleId returns 400")
    func postRuleMissingBrowserId() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await post("/rules", token: MCPServer.shared.authToken,
            body: ["hostPattern": "example.com"]) // browserBundleId missing
        #expect(status == 400)
        #expect(body["error"] != nil)
    }

    @Test("DELETE /browsers missing id param returns 400")
    func deleteBrowserMissingId() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await delete("/browsers", token: MCPServer.shared.authToken)
        #expect(status == 400)
        #expect(body["error"] != nil)
    }

    @Test("DELETE /browsers with non-existent id returns 404")
    func deleteBrowserNotFound() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await delete("/browsers?id=\(UUID().uuidString)", token: MCPServer.shared.authToken)
        #expect(status == 404)
        #expect(body["error"] != nil)
    }

    @Test("DELETE /rules with non-existent id returns 404")
    func deleteRuleNotFound() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let (status, body) = try await delete("/rules?id=\(UUID().uuidString)", token: MCPServer.shared.authToken)
        #expect(status == 404)
        #expect(body["error"] != nil)
    }

    // MARK: - Full CRUD Round-Trip

    @Test("POST /browsers with valid token adds browser; DELETE removes it")
    func browserCRUD() async throws {
        await startAndWait()
        defer { Task { await self.stopAndWait() } }

        let token = MCPServer.shared.authToken
        let uniqueBundle = "com.chowser.test.\(UUID().uuidString.prefix(8))"

        // Add
        let (createStatus, createBody) = try await post("/browsers", token: token,
            body: ["name": "Test Browser", "bundleId": uniqueBundle])
        #expect(createStatus == 201)
        let addedId = createBody["id"] as? String
        #expect(addedId != nil)

        // Verify it appears in GET /browsers
        let (_, listBody) = try await get("/browsers")
        let browsers = listBody["browsers"] as? [[String: Any]] ?? []
        #expect(browsers.contains { $0["bundleId"] as? String == uniqueBundle })

        // Remove
        let (deleteStatus, _) = try await delete("/browsers?id=\(addedId!)", token: token)
        #expect(deleteStatus == 200)

        // Verify it's gone
        let (_, listBody2) = try await get("/browsers")
        let browsers2 = listBody2["browsers"] as? [[String: Any]] ?? []
        #expect(!browsers2.contains { $0["bundleId"] as? String == uniqueBundle })
    }
}
