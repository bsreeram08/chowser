//
//  MCPServer.swift
//  Chowser
//
//  A lightweight local HTTP API server for AI-driven management of browsers and routing rules.
//  Start/stop from the menu bar. Listens on localhost only for security.
//
//  Endpoints:
//    GET  /browsers          — list configured browsers
//    POST /browsers          — add or update a browser (JSON body)
//    DELETE /browsers?id=<uuid> — remove a browser by ID
//    GET  /rules             — list routing rules
//    POST /rules             — add or update a rule (JSON body)
//    DELETE /rules?id=<uuid> — remove a rule by ID
//    GET  /status            — server health check + app version
//

import Foundation
import Network

@MainActor
final class MCPServer {
    static let shared = MCPServer()

    private(set) var isRunning = false
    private(set) var port: UInt16 = 24245
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    private init() {}

    func start(port: UInt16 = 24245) {
        guard !isRunning else { return }
        self.port = port

        let params = NWParameters.tcp
        params.acceptLocalOnly = true

        do {
            let nwPort = NWEndpoint.Port(rawValue: port)!
            listener = try NWListener(using: params, on: nwPort)
        } catch {
            print("Chowser MCP: Failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Chowser MCP: Server listening on localhost:\(port)")
            case .failed(let error):
                print("Chowser MCP: Server failed: \(error)")
                Task { @MainActor in self?.stop() }
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleConnection(connection)
            }
        }

        listener?.start(queue: .main)
        isRunning = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
        isRunning = false
        print("Chowser MCP: Server stopped")
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                Task { @MainActor in
                    self?.connections.removeAll { $0 === connection }
                }
            }
        }

        connection.start(queue: .main)
        receiveRequest(on: connection)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let data = data, !data.isEmpty {
                    let response = self.processHTTPRequest(data)
                    connection.send(content: response, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                } else if isComplete || error != nil {
                    connection.cancel()
                }
            }
        }
    }

    private func processHTTPRequest(_ data: Data) -> Data {
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

    private func parseQueryString(_ query: String) -> [String: String] {
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
            return httpResponse(status: 200, body: [
                "status": "ok",
                "app": "Chowser",
                "version": version,
                "browsers_count": manager.configuredBrowsers.count,
                "rules_count": manager.routingRules.count,
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
                manager.configuredBrowsers[existingIndex].customArguments = args.isEmpty ? nil : args
            }
            if let key = shortcutKey {
                manager.updateShortcutKey(id: manager.configuredBrowsers[existingIndex].id, to: key)
            }
            return httpResponse(status: 200, body: [
                "status": "updated",
                "id": manager.configuredBrowsers[existingIndex].id.uuidString,
            ])
        } else {
            // Add new browser
            manager.addBrowser(name: name, bundleId: bundleId, shortcutKey: shortcutKey, profile: profile)
            if let newBrowser = manager.configuredBrowsers.last, let args = customArguments {
                manager.updateBrowserCustomArguments(id: newBrowser.id, to: args)
            }
            let addedId = manager.configuredBrowsers.last?.id.uuidString ?? "unknown"
            return httpResponse(status: 201, body: ["status": "created", "id": addedId])
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
        if let idStr = json["id"] as? String, let uuid = UUID(uuidString: idStr),
           let existingIndex = manager.routingRules.firstIndex(where: { $0.id == uuid }) {
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
            manager.updateRoutingRule(updated)
            return httpResponse(status: 200, body: ["status": "updated", "id": idStr])
        }

        // Add new rule
        manager.addRoutingRule(
            name: name,
            hostPattern: hostPattern,
            pathPrefix: pathPrefix,
            browserBundleId: browserBundleId,
            profile: profile,
            sourceAppBundleId: sourceAppBundleId,
            usePrivateMode: usePrivateMode,
            useRegex: useRegex
        )

        let addedId = manager.routingRules.last?.id.uuidString ?? "unknown"
        return httpResponse(status: 201, body: ["status": "created", "id": addedId])
    }

    private func httpResponse(status: Int, body: [String: Any]) -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let jsonData = (try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(jsonData.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        \r
        \(jsonString)
        """
        return Data(response.utf8)
    }
}
