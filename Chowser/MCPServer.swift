//
//  MCPServer.swift
//  Chowser
//
//  A lightweight local HTTP API server for AI-driven management of browsers and routing rules.
//  Start/stop from the menu bar. Listens on localhost only for security.
//
//  Endpoints:
//    GET  /browsers          — list configured browsers (token required)
//    POST /browsers          — add or update a browser (JSON body, token required)
//    DELETE /browsers?id=<uuid> — remove a browser by ID (token required)
//    GET  /rules             — list routing rules (token required)
//    POST /rules             — add or update a rule (JSON body, token required)
//    DELETE /rules?id=<uuid> — remove a rule by ID (token required)
//    GET  /status            — server health check + app version (token required)
//
//  Authentication:
//    Every request requires the header:
//      Authorization: Bearer <token>
//    The token is generated on server start and shown in Settings/onboarding.
//

import Foundation
import Network
import Observation

@MainActor
@Observable
final class MCPServer {
    static let shared = MCPServer()

    private(set) var isRunning = false
    private(set) var port: UInt16 = 24245
    private(set) var authToken: String = ""
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let serverQueue = DispatchQueue(label: "in.sreerams.Chowser.MCPServer", qos: .userInitiated)

    private init() {}

    func start(port: UInt16 = 24245) {
        guard !isRunning else { return }
        self.port = port
        self.authToken = UUID().uuidString

        let params = NWParameters.tcp
        params.acceptLocalOnly = true

        do {
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                print("Chowser MCP: Invalid port \(port)")
                return
            }
            listener = try NWListener(using: params, on: nwPort)
        } catch {
            print("Chowser MCP: Failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            let capturedSelf = self
            switch state {
            case .ready:
                Task { @MainActor in
                    guard let s = capturedSelf else { return }
                    s.isRunning = true
                    print("Chowser MCP: Server listening on localhost:\(s.port)")
                }
            case .failed(let error):
                print("Chowser MCP: Server failed: \(error)")
                Task { @MainActor in capturedSelf?.stop() }
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.connections.append(connection)
                connection.stateUpdateHandler = { [weak self] state in
                    if case .cancelled = state {
                        Task { @MainActor [weak self] in
                            self?.connections.removeAll { $0 === connection }
                        }
                    }
                }
                connection.start(queue: self.serverQueue)
                self.receiveFullRequest(on: connection, accumulated: Data())
            }
        }

        listener?.start(queue: serverQueue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
        isRunning = false
        authToken = ""
        print("Chowser MCP: Server stopped")
    }

    /// Accumulates data from the connection until the full HTTP request (headers + body based on Content-Length) is received.
    private nonisolated func receiveFullRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            // Check if we have the full request: headers parsed and body complete
            if let requestString = String(data: buffer, encoding: .utf8),
               let headerEndRange = requestString.range(of: "\r\n\r\n") {

                // Try to determine expected content length
                let headerSection = String(requestString[..<headerEndRange.lowerBound])
                let contentLength = self.parseContentLength(from: headerSection)
                let headerEndOffset = requestString.distance(from: requestString.startIndex, to: headerEndRange.upperBound)
                let bodyStart = headerEndOffset
                let bodyReceived = buffer.count - bodyStart

                if bodyReceived >= contentLength {
                    // Full request received — process on MainActor
                    let requestData = buffer
                    let token = self.parseAuthToken(from: headerSection)
                    Task { @MainActor in
                        let response = self.processHTTPRequest(requestData, authToken: token)
                        connection.send(content: response, completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    }
                    return
                }
            }

            // Request not yet complete — keep reading (or stop if connection closed/errored)
            if isComplete || error != nil {
                // Incomplete request, try to process what we have
                let requestData = buffer
                let headerSection: String
                if let rs = String(data: buffer, encoding: .utf8),
                   let r = rs.range(of: "\r\n\r\n") {
                    headerSection = String(rs[..<r.lowerBound])
                } else {
                    headerSection = ""
                }
                let token = self.parseAuthToken(from: headerSection)
                Task { @MainActor in
                    let response = self.processHTTPRequest(requestData, authToken: token)
                    connection.send(content: response, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            } else {
                // Continue accumulating
                self.receiveFullRequest(on: connection, accumulated: buffer)
            }
        }
    }

    private nonisolated func parseContentLength(from headerSection: String) -> Int {
        for line in headerSection.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2,
               parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length",
               let length = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                return length
            }
        }
        return 0
    }

    private nonisolated func parseAuthToken(from headerSection: String) -> String? {
        var legacyHeaderToken: String?

        for line in headerSection.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let name = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            if name == "authorization" {
                let components = value.split(separator: " ", maxSplits: 1).map(String.init)
                guard components.count == 2,
                      components[0].lowercased() == "bearer" else {
                    return nil
                }
                return components[1].trimmingCharacters(in: .whitespaces)
            }

            if name == "x-chowser-token" {
                legacyHeaderToken = value
            }
        }

        return legacyHeaderToken
    }

    private func processHTTPRequest(_ data: Data, authToken requestToken: String?) -> Data {
        guard let requestString = String(data: data, encoding: .utf8) else {
            return httpResponse(status: 400, body: ["error": "Invalid request"])
        }

        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return httpResponse(status: 400, body: ["error": "Empty request"])
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else {
            return httpResponse(status: 400, body: ["error": "Malformed request line"])
        }

        let method = String(parts[0])
        let rawPath = String(parts[1])

        // Parse path and query string
        let pathComponents = rawPath.split(separator: "?", maxSplits: 1)
        let path = String(pathComponents[0])
        let queryString = pathComponents.count > 1 ? String(pathComponents[1]) : ""
        let queryParams = parseQueryString(queryString)

        guard isAuthorized(requestToken) else {
            return unauthorizedResponse()
        }

        // Extract body (after empty line)
        var body: Data?
        if let emptyLineIndex = requestString.range(of: "\r\n\r\n") {
            let bodyString = String(requestString[emptyLineIndex.upperBound...])
            if !bodyString.isEmpty {
                body = bodyString.data(using: .utf8)
            }
        }

        return routeRequest(method: method, path: path, queryParams: queryParams, body: body)
    }

    private func isAuthorized(_ requestToken: String?) -> Bool {
        guard isRunning, !authToken.isEmpty, let requestToken else {
            return false
        }
        return requestToken == authToken
    }

    private nonisolated func unauthorizedResponse() -> Data {
        httpResponse(status: 401, body: [
            "error": "Unauthorized. Provide Authorization: Bearer <token> with the current local API token.",
        ])
    }

    private nonisolated func parseQueryString(_ query: String) -> [String: String] {
        guard !query.isEmpty else { return [:] }
        var params: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                params[key] = value
            }
        }
        return params
    }

    private func routeRequest(method: String, path: String, queryParams: [String: String], body: Data?) -> Data {
        let manager = BrowserManager.shared

        switch (method, path) {

        // MARK: - Status
        case ("GET", "/status"):
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            let endpoints: [[String: Any]] = [
                [
                    "method": "GET", "path": "/status",
                    "auth": true,
                    "description": "Server health check, app version, and full API schema. Requires Authorization: Bearer <token>.",
                ],
                [
                    "method": "GET", "path": "/browsers",
                    "auth": true,
                    "description": "List all configured browsers. Requires Authorization: Bearer <token>.",
                    "response_fields": ["id", "name", "bundleId", "shortcutKey", "profile?", "customArguments?"],
                ],
                [
                    "method": "POST", "path": "/browsers",
                    "auth": true,
                    "description": "Add a new browser, or update an existing one (matched by bundleId + profile). Returns 201 on create, 200 on update.",
                    "body_fields": ["name (required)", "bundleId (required)", "profile?", "shortcutKey?", "customArguments?"],
                ],
                [
                    "method": "DELETE", "path": "/browsers",
                    "auth": true,
                    "description": "Remove a browser by id. Query param: ?id=<uuid>",
                    "query_params": ["id (required): browser UUID from GET /browsers"],
                ],
                [
                    "method": "GET", "path": "/rules",
                    "auth": true,
                    "description": "List all routing rules. Requires Authorization: Bearer <token>.",
                    "response_fields": ["id", "name", "hostPattern", "browserBundleId", "isEnabled", "usePrivateMode", "useRegex", "pathPrefix?", "profile?", "sourceAppBundleId?"],
                ],
                [
                    "method": "POST", "path": "/rules",
                    "auth": true,
                    "description": "Create a new rule (201), or update an existing one by including its id in the body (200). The target browser must already exist. useRegex=true treats hostPattern as a regex.",
                    "body_fields": ["hostPattern (required)", "browserBundleId (required)", "id? (provide to update existing rule)", "name?", "pathPrefix?", "profile?", "sourceAppBundleId?", "usePrivateMode?", "useRegex?", "isEnabled?"],
                ],
                [
                    "method": "DELETE", "path": "/rules",
                    "auth": true,
                    "description": "Remove a routing rule by id. Query param: ?id=<uuid>",
                    "query_params": ["id (required): rule UUID from GET /rules"],
                ],
            ]
            return httpResponse(status: 200, body: [
                "status": "ok",
                "app": "Chowser",
                "version": version,
                "browsers_count": manager.configuredBrowsers.count,
                "rules_count": manager.routingRules.count,
                "auth_header": "Authorization",
                "auth_scheme": "Bearer",
                "endpoints": endpoints,
            ] as [String: Any])

        // MARK: - Browsers
        case ("GET", "/browsers"):
            let browsers = manager.configuredBrowsers.map { browser -> [String: Any] in
                var dict: [String: Any] = [
                    "id": browser.id.uuidString,
                    "name": browser.name,
                    "bundleId": browser.bundleId,
                    "shortcutKey": browser.shortcutKey,
                ]
                if let profile = browser.profile { dict["profile"] = profile }
                if let args = browser.customArguments { dict["customArguments"] = args }
                return dict
            }
            return httpResponse(status: 200, body: ["browsers": browsers])

        case ("POST", "/browsers"):
            guard let body = body else {
                return httpResponse(status: 400, body: ["error": "Missing request body"])
            }
            return handleAddOrUpdateBrowser(body: body, manager: manager)

        case ("DELETE", "/browsers"):
            guard let idStr = queryParams["id"], let uuid = UUID(uuidString: idStr) else {
                return httpResponse(status: 400, body: ["error": "Missing or invalid 'id' query parameter"])
            }
            guard manager.configuredBrowsers.contains(where: { $0.id == uuid }) else {
                return httpResponse(status: 404, body: ["error": "Browser not found"])
            }
            manager.removeBrowser(id: uuid)
            return httpResponse(status: 200, body: ["status": "deleted", "id": idStr])

        // MARK: - Rules
        case ("GET", "/rules"):
            let rules = manager.routingRules.map { rule -> [String: Any] in
                var dict: [String: Any] = [
                    "id": rule.id.uuidString,
                    "name": rule.name,
                    "hostPattern": rule.hostPattern,
                    "browserBundleId": rule.browserBundleId,
                    "isEnabled": rule.isEnabled,
                    "usePrivateMode": rule.usePrivateMode,
                    "useRegex": rule.useRegex,
                ]
                if let prefix = rule.pathPrefix { dict["pathPrefix"] = prefix }
                if let profile = rule.profile { dict["profile"] = profile }
                if let source = rule.sourceAppBundleId { dict["sourceAppBundleId"] = source }
                return dict
            }
            return httpResponse(status: 200, body: ["rules": rules])

        case ("POST", "/rules"):
            guard let body = body else {
                return httpResponse(status: 400, body: ["error": "Missing request body"])
            }
            return handleAddOrUpdateRule(body: body, manager: manager)

        case ("DELETE", "/rules"):
            guard let idStr = queryParams["id"], let uuid = UUID(uuidString: idStr) else {
                return httpResponse(status: 400, body: ["error": "Missing or invalid 'id' query parameter"])
            }
            guard manager.routingRules.contains(where: { $0.id == uuid }) else {
                return httpResponse(status: 404, body: ["error": "Rule not found"])
            }
            manager.removeRoutingRule(id: uuid)
            return httpResponse(status: 200, body: ["status": "deleted", "id": idStr])

        default:
            return httpResponse(status: 404, body: ["error": "Not found", "path": path, "method": method])
        }
    }

    private func handleAddOrUpdateBrowser(body: Data, manager: BrowserManager) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let name = json["name"] as? String,
              let bundleId = json["bundleId"] as? String else {
            return httpResponse(status: 400, body: ["error": "Invalid JSON. Required fields: name, bundleId"])
        }

        let profile = json["profile"] as? String
        let shortcutKey = json["shortcutKey"] as? String
        let customArguments = json["customArguments"] as? String

        let identity = "\(bundleId)|\(profile ?? "")"

        if let existingIndex = manager.configuredBrowsers.firstIndex(where: { $0.identity == identity }) {
            // Update existing browser
            manager.configuredBrowsers[existingIndex].name = name
            if let args = customArguments {
                manager.updateBrowserCustomArguments(id: manager.configuredBrowsers[existingIndex].id, to: args)
            }
            if let key = shortcutKey {
                manager.updateShortcutKey(id: manager.configuredBrowsers[existingIndex].id, to: key)
            }
            return httpResponse(status: 200, body: [
                "status": "updated",
                "id": manager.configuredBrowsers[existingIndex].id.uuidString,
                "launchArgumentsSupported": BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild,
            ])
        } else {
            // Add new browser
            manager.addBrowser(name: name, bundleId: bundleId, shortcutKey: shortcutKey, profile: profile)
            if let newBrowser = manager.configuredBrowsers.last, let args = customArguments {
                manager.updateBrowserCustomArguments(id: newBrowser.id, to: args)
            }
            let addedId = manager.configuredBrowsers.last?.id.uuidString ?? "unknown"
            return httpResponse(status: 201, body: [
                "status": "created",
                "id": addedId,
                "launchArgumentsSupported": BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild,
            ])
        }
    }

    private func handleAddOrUpdateRule(body: Data, manager: BrowserManager) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let hostPattern = json["hostPattern"] as? String,
              let browserBundleId = json["browserBundleId"] as? String else {
            return httpResponse(status: 400, body: ["error": "Invalid JSON. Required fields: hostPattern, browserBundleId"])
        }

        let name = json["name"] as? String ?? hostPattern
        let pathPrefix = json["pathPrefix"] as? String
        let profile = json["profile"] as? String
        let sourceAppBundleId = json["sourceAppBundleId"] as? String
        let usePrivateMode = json["usePrivateMode"] as? Bool ?? false
        let useRegex = json["useRegex"] as? Bool ?? false
        let isEnabled = json["isEnabled"] as? Bool ?? true

        // If an ID is provided, try to update an existing rule
        if let idStr = json["id"] as? String {
            guard let uuid = UUID(uuidString: idStr) else {
                return httpResponse(status: 400, body: ["error": "Invalid rule id", "id": idStr])
            }
            guard let existingIndex = manager.routingRules.firstIndex(where: { $0.id == uuid }) else {
                return httpResponse(status: 404, body: ["error": "Rule not found", "id": idStr])
            }

            var updated = manager.routingRules[existingIndex]
            updated.name = name
            updated.hostPattern = hostPattern
            updated.pathPrefix = pathPrefix
            updated.browserBundleId = browserBundleId
            updated.profile = profile
            updated.sourceAppBundleId = sourceAppBundleId
            updated.usePrivateMode = usePrivateMode
            updated.useRegex = useRegex
            updated.isEnabled = isEnabled

            switch manager.updateRule(updated) {
            case .success(let normalizedRule):
                return httpResponse(status: 200, body: [
                    "status": "updated",
                    "id": normalizedRule.id.uuidString,
                    "launchArgumentsSupported": BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild,
                ])
            case .failure(let error):
                return routingRuleValidationResponse(error, browserBundleId: browserBundleId)
            }
        }

        let result = manager.addRoutingRule(
            name: name,
            hostPattern: hostPattern,
            pathPrefix: pathPrefix,
            browserBundleId: browserBundleId,
            profile: profile,
            sourceAppBundleId: sourceAppBundleId,
            usePrivateMode: usePrivateMode,
            useRegex: useRegex
        )

        switch result {
        case .success(let addedRule):
            return httpResponse(status: 201, body: [
                "status": "created",
                "id": addedRule.id.uuidString,
                "launchArgumentsSupported": BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild,
            ])
        case .failure(let error):
            return routingRuleValidationResponse(error, browserBundleId: browserBundleId)
        }
    }

    private func routingRuleValidationResponse(_ error: BrowserManager.RoutingRuleValidationError, browserBundleId: String) -> Data {
        var body: [String: Any] = ["error": error.message]
        if case .browserNotFound = error {
            body["browserBundleId"] = browserBundleId
        }
        return httpResponse(status: 422, body: body)
    }

    private nonisolated func httpResponse(status: Int, body: [String: Any]) -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 422: statusText = "Unprocessable Entity"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let jsonData = (try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])) ?? Data()

        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: application/json\r\n"
        header += "Content-Length: \(jsonData.count)\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"

        var responseData = Data(header.utf8)
        responseData.append(jsonData)
        return responseData
    }
}
