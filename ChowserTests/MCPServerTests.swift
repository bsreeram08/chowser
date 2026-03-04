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
        // Let the OS fully release the port before the next test binds it
        try? await Task.sleep(for: .milliseconds(200))
    }

    /// Starts the server, runs `work`, then always stops and waits for port release.
    /// This is the canonical test wrapper — ensures cleanup is always awaited, unlike
    /// `defer { Task { ... } }` which spawns an unstructured task the suite doesn't wait for.
    private func withServer<T>(_ work: () async throws -> T) async rethrows -> T {
        await startAndWait()
        do {
            let result = try await work()
            await stopAndWait()
            return result
        } catch {
            await stopAndWait()
            throw error
        }
    }

    // Minimal HTTP helpers

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
        if MCPServer.shared.isRunning { await stopAndWait() }
        #expect(MCPServer.shared.isRunning == false)
        #expect(MCPServer.shared.authToken == "")
    }

    /// Regression for the App Store rejection:
    /// `isRunning` must only become `true` once the NWListener actually reaches `.ready`,
    /// not synchronously inside `start()`. Previously `isRunning = true` was set eagerly, so
    /// a sandbox-denied bind caused an async `stop()` that reverted the UI toggle immediately.
    @Test("isRunning becomes true only after listener reaches .ready (not synchronously)")
    func isRunningSetAsynchronously() async {
        MCPServer.shared.start(port: testPort)
        let synchronousValue = MCPServer.shared.isRunning   // must still be false
        _ = await waitFor { MCPServer.shared.isRunning }
        #expect(synchronousValue == false, "isRunning must not be set synchronously in start()")
        #expect(MCPServer.shared.isRunning == true)
        await stopAndWait()
    }

    @Test("stop() immediately sets isRunning false and clears auth token")
    func stopClearsState() async {
        await startAndWait()
        MCPServer.shared.stop()
        #expect(MCPServer.shared.isRunning == false)
        #expect(MCPServer.shared.authToken == "")
        await stopAndWait()
    }

    @Test("Calling start() while already running is a no-op")
    func doubleStartIsNoOp() async {
        await withServer {
            let tokenBefore = MCPServer.shared.authToken
            MCPServer.shared.start(port: testPort)
            #expect(MCPServer.shared.authToken == tokenBefore)
            #expect(MCPServer.shared.isRunning == true)
        }
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

    @Test("Server can be restarted after stop")
    func serverRestart() async {
        await startAndWait()
        #expect(MCPServer.shared.isRunning == true)
        let token1 = MCPServer.shared.authToken

        await stopAndWait()
        #expect(MCPServer.shared.isRunning == false)

        await startAndWait()
        #expect(MCPServer.shared.isRunning == true)
        #expect(MCPServer.shared.authToken != token1)
        #expect(MCPServer.shared.authToken.isEmpty == false)

        await stopAndWait()
    }

    // MARK: - GET Endpoints (no auth required)

    @Test("GET /status returns 200 with app info and full endpoint schema")
    func statusEndpoint() async throws {
        try await withServer {
            let (status, body) = try await get("/status")
            #expect(status == 200)
            #expect(body["status"] as? String == "ok")
            #expect(body["app"] as? String == "Chowser")
            #expect(body["version"] != nil)
            #expect(body["browsers_count"] != nil)
            #expect(body["rules_count"] != nil)
            #expect(body["auth_header"] as? String == "X-Chowser-Token")

            // Endpoint schema must be present and cover all operations
            let endpoints = body["endpoints"] as? [[String: Any]]
            #expect(endpoints != nil)
            let methods = endpoints?.compactMap { $0["method"] as? String } ?? []
            let paths  = endpoints?.compactMap { $0["path"]   as? String } ?? []
            // Every CRUD operation must be documented
            #expect(methods.filter { $0 == "GET"    }.count >= 3)  // /status, /browsers, /rules
            #expect(methods.filter { $0 == "POST"   }.count >= 2)  // /browsers, /rules
            #expect(methods.filter { $0 == "DELETE" }.count >= 2)  // /browsers, /rules
            #expect(paths.contains("/browsers"))
            #expect(paths.contains("/rules"))
            // Each entry must document auth requirement
            let allHaveAuth = endpoints?.allSatisfy { $0["auth"] != nil } ?? false
            #expect(allHaveAuth)
        }
    }

    @Test("GET /browsers returns 200 with browsers array")
    func getBrowsers() async throws {
        try await withServer {
            let (status, body) = try await get("/browsers")
            #expect(status == 200)
            #expect(body["browsers"] is [Any])
        }
    }

    @Test("GET /rules returns 200 with rules array")
    func getRules() async throws {
        try await withServer {
            let (status, body) = try await get("/rules")
            #expect(status == 200)
            #expect(body["rules"] is [Any])
        }
    }

    @Test("GET to unknown path returns 404")
    func unknownPath() async throws {
        try await withServer {
            let (status, _) = try await get("/doesnotexist")
            #expect(status == 404)
        }
    }

    // MARK: - Auth Enforcement (POST / DELETE)

    @Test("POST /browsers without token returns 401")
    func postBrowserNoToken() async throws {
        try await withServer {
            let (status, body) = try await post("/browsers", token: nil,
                body: ["name": "Chrome", "bundleId": "com.google.Chrome"])
            #expect(status == 401)
            #expect(body["error"] != nil)
        }
    }

    @Test("POST /browsers with wrong token returns 401")
    func postBrowserWrongToken() async throws {
        try await withServer {
            let (status, body) = try await post("/browsers", token: "not-the-real-token",
                body: ["name": "Chrome", "bundleId": "com.google.Chrome"])
            #expect(status == 401)
            #expect(body["error"] != nil)
        }
    }

    @Test("POST /rules without token returns 401")
    func postRuleNoToken() async throws {
        try await withServer {
            let (status, body) = try await post("/rules", token: nil,
                body: ["hostPattern": "example.com", "browserBundleId": "com.apple.Safari"])
            #expect(status == 401)
            #expect(body["error"] != nil)
        }
    }

    @Test("DELETE /browsers without token returns 401")
    func deleteBrowserNoToken() async throws {
        try await withServer {
            let (status, body) = try await delete("/browsers?id=\(UUID().uuidString)", token: nil)
            #expect(status == 401)
            #expect(body["error"] != nil)
        }
    }

    @Test("DELETE /rules without token returns 401")
    func deleteRuleNoToken() async throws {
        try await withServer {
            let (status, body) = try await delete("/rules?id=\(UUID().uuidString)", token: nil)
            #expect(status == 401)
            #expect(body["error"] != nil)
        }
    }

    // MARK: - Request Validation (authenticated, bad input)

    @Test("POST /browsers missing bundleId returns 400")
    func postBrowserMissingBundleId() async throws {
        try await withServer {
            let (status, body) = try await post("/browsers", token: MCPServer.shared.authToken,
                body: ["name": "Chrome"]) // bundleId missing
            #expect(status == 400)
            #expect(body["error"] != nil)
        }
    }

    @Test("POST /rules missing browserBundleId returns 400")
    func postRuleMissingBrowserId() async throws {
        try await withServer {
            let (status, body) = try await post("/rules", token: MCPServer.shared.authToken,
                body: ["hostPattern": "example.com"]) // browserBundleId missing
            #expect(status == 400)
            #expect(body["error"] != nil)
        }
    }

    @Test("DELETE /browsers missing id param returns 400")
    func deleteBrowserMissingId() async throws {
        try await withServer {
            let (status, body) = try await delete("/browsers", token: MCPServer.shared.authToken)
            #expect(status == 400)
            #expect(body["error"] != nil)
        }
    }

    @Test("DELETE /rules missing id param returns 400")
    func deleteRuleMissingId() async throws {
        try await withServer {
            let (status, body) = try await delete("/rules", token: MCPServer.shared.authToken)
            #expect(status == 400)
            #expect(body["error"] != nil)
        }
    }

    @Test("DELETE /browsers with malformed (non-UUID) id returns 400")
    func deleteBrowserMalformedId() async throws {
        try await withServer {
            let (status, body) = try await delete("/browsers?id=not-a-uuid", token: MCPServer.shared.authToken)
            #expect(status == 400)
            #expect(body["error"] != nil)
        }
    }

    @Test("DELETE /rules with malformed (non-UUID) id returns 400")
    func deleteRuleMalformedId() async throws {
        try await withServer {
            let (status, body) = try await delete("/rules?id=not-a-uuid", token: MCPServer.shared.authToken)
            #expect(status == 400)
            #expect(body["error"] != nil)
        }
    }

    @Test("DELETE /browsers with non-existent id returns 404")
    func deleteBrowserNotFound() async throws {
        try await withServer {
            let (status, body) = try await delete("/browsers?id=\(UUID().uuidString)", token: MCPServer.shared.authToken)
            #expect(status == 404)
            #expect(body["error"] != nil)
        }
    }

    @Test("DELETE /rules with non-existent id returns 404")
    func deleteRuleNotFound() async throws {
        try await withServer {
            let (status, body) = try await delete("/rules?id=\(UUID().uuidString)", token: MCPServer.shared.authToken)
            #expect(status == 404)
            #expect(body["error"] != nil)
        }
    }

    @Test("POST /browsers with empty body returns 400")
    func postBrowserEmptyBody() async throws {
        try await withServer {
            var req = URLRequest(url: URL(string: "http://localhost:\(testPort)/browsers")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(MCPServer.shared.authToken, forHTTPHeaderField: "X-Chowser-Token")
            req.httpBody = Data()   // empty — triggers "Missing request body" guard
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as! HTTPURLResponse).statusCode
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            #expect(status == 400)
            #expect(json["error"] != nil)
        }
    }

    @Test("POST /rules with empty body returns 400")
    func postRuleEmptyBody() async throws {
        try await withServer {
            var req = URLRequest(url: URL(string: "http://localhost:\(testPort)/rules")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(MCPServer.shared.authToken, forHTTPHeaderField: "X-Chowser-Token")
            req.httpBody = Data()
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as! HTTPURLResponse).statusCode
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            #expect(status == 400)
            #expect(json["error"] != nil)
        }
    }

    @Test("POST /rules targeting non-existent browser returns 422")
    func postRuleForMissingBrowser() async throws {
        try await withServer {
            let (status, body) = try await post("/rules", token: MCPServer.shared.authToken, body: [
                "hostPattern": "example.com",
                "browserBundleId": "com.nonexistent.browser.\(UUID().uuidString)"
            ])
            #expect(status == 422)
            #expect(body["error"] != nil)
        }
    }

    @Test("POST /rules with invalid host pattern returns 422 even when browser exists")
    func postRuleInvalidHostPattern() async throws {
        try await withServer {
            let token = MCPServer.shared.authToken
            let uniqueBundle = "com.chowser.invalidhost.\(UUID().uuidString.prefix(8))"

            // Add a browser so the browser-exists check passes
            let (_, browserBody) = try await post("/browsers", token: token,
                body: ["name": "Invalid Host Test", "bundleId": uniqueBundle])
            let browserId = browserBody["id"] as? String

            // An empty hostPattern fails BrowserManager's validation after the browser check
            let (status, body) = try await post("/rules", token: token, body: [
                "hostPattern": "",   // blank — fails isValidHostPatterns
                "browserBundleId": uniqueBundle
            ])
            #expect(status == 422)
            #expect(body["error"] != nil)

            // Clean up
            if let bid = browserId {
                _ = try await delete("/browsers?id=\(bid)", token: token)
            }
        }
    }

    // MARK: - Full CRUD Round-Trips

    @Test("POST /browsers creates browser; duplicate POST updates it; DELETE removes it")
    func browserCRUD() async throws {
        try await withServer {
            let token = MCPServer.shared.authToken
            let uniqueBundle = "com.chowser.test.\(UUID().uuidString.prefix(8))"

            // Create
            let (createStatus, createBody) = try await post("/browsers", token: token,
                body: ["name": "Test Browser", "bundleId": uniqueBundle])
            #expect(createStatus == 201)
            let addedId = createBody["id"] as? String
            #expect(addedId != nil)

            // Update — same bundleId returns 200, not 201
            let (updateStatus, updateBody) = try await post("/browsers", token: token,
                body: ["name": "Test Browser Renamed", "bundleId": uniqueBundle])
            #expect(updateStatus == 200)
            #expect(updateBody["id"] as? String == addedId)

            // Verify rename
            let (_, listBody) = try await get("/browsers")
            let browsers = listBody["browsers"] as? [[String: Any]] ?? []
            let updated = browsers.first { $0["bundleId"] as? String == uniqueBundle }
            #expect(updated?["name"] as? String == "Test Browser Renamed")

            // Delete
            let (deleteStatus, _) = try await delete("/browsers?id=\(addedId!)", token: token)
            #expect(deleteStatus == 200)

            // Verify gone
            let (_, listBody2) = try await get("/browsers")
            let browsers2 = listBody2["browsers"] as? [[String: Any]] ?? []
            #expect(!browsers2.contains { $0["bundleId"] as? String == uniqueBundle })
        }
    }

    @Test("POST /rules creates rule; POST with id updates it; DELETE removes it")
    func rulesCRUD() async throws {
        try await withServer {
            let token = MCPServer.shared.authToken
            let uniqueBundle = "com.chowser.rulestest.\(UUID().uuidString.prefix(8))"

            // Need a browser to attach the rule to
            let (_, browserBody) = try await post("/browsers", token: token,
                body: ["name": "Rules Test Browser", "bundleId": uniqueBundle])
            let browserId = browserBody["id"] as? String

            // Create rule
            let (createStatus, createBody) = try await post("/rules", token: token, body: [
                "hostPattern": "rules-test.example.com",
                "browserBundleId": uniqueBundle
            ])
            #expect(createStatus == 201)
            let ruleId = createBody["id"] as? String
            #expect(ruleId != nil)

            // Verify in GET /rules
            let (_, rulesBody) = try await get("/rules")
            let rules = rulesBody["rules"] as? [[String: Any]] ?? []
            #expect(rules.contains { $0["id"] as? String == ruleId })

            // Update via POST with id in body
            let (updateStatus, _) = try await post("/rules", token: token, body: [
                "id": ruleId!,
                "hostPattern": "rules-test-updated.example.com",
                "browserBundleId": uniqueBundle
            ])
            #expect(updateStatus == 200)

            // Verify update
            let (_, rulesBody2) = try await get("/rules")
            let rules2 = rulesBody2["rules"] as? [[String: Any]] ?? []
            let updatedRule = rules2.first { $0["id"] as? String == ruleId }
            #expect(updatedRule?["hostPattern"] as? String == "rules-test-updated.example.com")

            // Delete rule
            let (deleteRuleStatus, _) = try await delete("/rules?id=\(ruleId!)", token: token)
            #expect(deleteRuleStatus == 200)

            // Clean up browser
            if let bid = browserId {
                _ = try await delete("/browsers?id=\(bid)", token: token)
            }

            // Verify rule gone
            let (_, rulesBody3) = try await get("/rules")
            let rules3 = rulesBody3["rules"] as? [[String: Any]] ?? []
            #expect(!rules3.contains { $0["id"] as? String == ruleId })
        }
    }
}
