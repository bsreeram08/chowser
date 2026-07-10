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
import AppKit

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

    /// Written on start, removed on stop — lets an agent that started the server via
    /// `chowser://mcp/start` (no GUI, shell/fetch tools only) discover the port and
    /// token without any UI interaction. Local file, not networked; same trust level
    /// as the server itself (localhost-only).
    private static var sessionFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        // Isolated under UI testing so a test run never clobbers a real running
        // instance's session file (both would otherwise share one path).
        let subpath = AppEnvironment.isUITesting ? "Chowser-UITests/mcp-session.json" : "Chowser/mcp-session.json"
        return base.appendingPathComponent(subpath, isDirectory: false)
    }

    private func writeSessionFile() {
        let payload: [String: Any] = ["port": port, "authToken": authToken, "authHeader": "Authorization: Bearer \(authToken)"]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else { return }
        let url = Self.sessionFileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func removeSessionFile() {
        try? FileManager.default.removeItem(at: Self.sessionFileURL)
    }

    func start(port: UInt16 = 24245) {
        guard !isRunning else { return }
        self.port = port
        self.authToken = AppEnvironment.fixedMCPAuthToken ?? UUID().uuidString

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
                    s.writeSessionFile()
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
        removeSessionFile()
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
        return Self.constantTimeEquals(requestToken, authToken)
    }

    /// Loopback-only and requires local code execution already, but comparing tokens
    /// byte-by-byte instead of short-circuiting on the first mismatch closes the timing
    /// side-channel cheaply while this file is already being touched.
    static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }

        var diff: UInt8 = 0
        for i in 0..<aBytes.count {
            diff |= aBytes[i] ^ bBytes[i]
        }
        return diff == 0
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
                    "response_fields": ["id", "name", "bundleId", "shortcutKey", "profile?", "customArguments?", "privateArguments?"],
                ],
                [
                    "method": "POST", "path": "/browsers",
                    "auth": true,
                    "description": "Add a new browser, or update an existing one (matched by bundleId + profile). Returns 201/200. AGENT GUIDANCE: to make a browser open the right profile and a private/incognito window reliably, research that specific browser's actual launch arguments (web-search the exact CLI flags) and set them here. `customArguments` is the normal-launch template; `privateArguments` is the private/incognito template. Both support {profile} and {url} placeholders ({url} optional — if omitted the URL is appended). Examples: Chrome/Brave/Edge → customArguments \"--profile-directory={profile}\", privateArguments \"--incognito --profile-directory={profile}\"; Firefox/Zen → customArguments \"-P {profile}\", privateArguments \"-private -P {profile}\". These are STORED in every build and APPLIED at launch in the direct-download build. The App Store (sandboxed) build attempts them but macOS may strip launch arguments (`launchArgumentsSupported:false` signals this).",
                    "body_fields": ["name (required)", "bundleId (required)", "profile? (Chromium profile-directory name or Firefox profile name)", "shortcutKey?", "customArguments? (normal-launch arg template)", "privateArguments? (private/incognito arg template)"],
                ],
                [
                    "method": "POST", "path": "/browsers/preview",
                    "auth": true,
                    "description": "DRY-RUN: resolve exactly how a launch would be framed for a browser + args, WITHOUT launching. Use this to verify researched arguments before saving: send the candidate profile/customArguments/privateArguments, read back the exact `command` string and `deliveredArguments`, then ask the user to confirm it opens the right profile/window. Returns mode, command, requestedArguments, deliveredArguments, launchArgumentsSupported, and a note.",
                    "body_fields": ["bundleId (required)", "profile?", "customArguments?", "privateArguments?", "usePrivateMode? (default false)", "url? (default https://example.com)"],
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
                    "response_fields": ["id", "name", "hostPattern", "browserBundleId", "isEnabled", "usePrivateMode", "useRegex", "pathPrefix?", "profile?", "sourceAppBundleIDs (always present, may be empty)", "sourceAppBundleId? (legacy, present only when sourceAppBundleIDs has exactly one entry)"],
                ],
                [
                    "method": "POST", "path": "/rules",
                    "auth": true,
                    "description": "Create a new rule (201), or update an existing one by including its id in the body (200). The target browser must already exist. useRegex=true treats hostPattern as a regex. Empty/omitted sourceAppBundleIDs means the rule matches any source app.",
                    "body_fields": ["hostPattern (required)", "browserBundleId (required)", "id? (provide to update existing rule)", "name?", "pathPrefix?", "profile?", "sourceAppBundleIDs? ([String], preferred)", "sourceAppBundleId? (legacy single-string, still accepted)", "usePrivateMode?", "useRegex?", "isEnabled?"],
                ],
                [
                    "method": "DELETE", "path": "/rules",
                    "auth": true,
                    "description": "Remove a routing rule by id. Query param: ?id=<uuid>",
                    "query_params": ["id (required): rule UUID from GET /rules"],
                ],
                [
                    "method": "GET", "path": "/rewrites",
                    "auth": true,
                    "description": "List all URL rewrite rules, applied in order before routing rules (FR-021/022). Requires Authorization: Bearer <token>.",
                    "response_fields": ["id", "name", "isEnabled", "match { schemes, hostPattern, useRegex, pathPrefix?, sourceAppBundleIDs }", "actions ([{type, ...}], see POST /rewrites for shapes)"],
                ],
                [
                    "method": "POST", "path": "/rewrites",
                    "auth": true,
                    "description": "Create a new rewrite rule (201), or update an existing one by including its id in the body (200). Mirrors /rules' create-or-update shape.",
                    "body_fields": ["hostPattern (required)", "id? (provide to update existing rewrite)", "name?", "useRegex?", "pathPrefix?", "schemes? ([String], e.g. [\"https\"]; empty/omitted means any scheme)", "sourceAppBundleIDs?", "isEnabled?", "actions? ([Object]) — each is {type, ...}: {type:\"forceScheme\",scheme}, {type:\"replaceHost\",host}, {type:\"stripQueryParameters\",names:[String]}, {type:\"stripQueryParameterPrefixes\",prefixes:[String]}, {type:\"setQueryParameter\",name,value}, {type:\"removeFragment\"}"],
                ],
                [
                    "method": "DELETE", "path": "/rewrites",
                    "auth": true,
                    "description": "Remove a rewrite rule by id. Query param: ?id=<uuid>",
                    "query_params": ["id (required): rewrite UUID from GET /rewrites"],
                ],
                [
                    "method": "GET", "path": "/settings",
                    "auth": true,
                    "description": "Read every app-level setting Chowser's Settings UI exposes — everything here is also editable by hand in Settings, this is the full surface for AI-driven configuration.",
                    "response_fields": ["appMode", "fallbackPolicy { mode, browserId?, profile? }", "networkLookupsEnabled", "userShortenerHosts", "shortlinkResolutionTimeout", "trackingCleanupEnabled", "mcpAutoStartEnabled", "launchAtLogin", "skipExistingImportedRules", "skipExistingImportedBrowsers", "hiddenBundleIDs", "picker { iconSize, showLabels, layoutMode, appearanceMode, tintHex, backgroundOpacity, cornerRadius, accentHex, qrCodeAccentHex, dimInactiveBrowsers, colorScheme, showLinkPreview, densityPreference }"],
                ],
                [
                    "method": "POST", "path": "/settings",
                    "auth": true,
                    "description": "Update one or more app-level settings — the full Settings UI surface. Only include the keys you want to change; everything else is left as-is. AGENT GUIDANCE: when a user asks to configure Chowser conversationally (\"turn on dark mode for the picker\", \"stop launching at login\", \"hide the picker labels\"), call GET /settings first to see current values, then POST just the fields that changed. Ask before changing anything the user didn't explicitly request.",
                    "body_fields": ["appMode? (\"app\" or \"menuBar\")", "fallbackPolicy? { mode (\"picker\" or \"browser\"), browserId? (required when mode is \"browser\" — must be an existing browser's id), profile? }", "networkLookupsEnabled?", "userShortenerHosts? ([String])", "shortlinkResolutionTimeout? (seconds)", "trackingCleanupEnabled?", "mcpAutoStartEnabled?", "launchAtLogin?", "skipExistingImportedRules?", "skipExistingImportedBrowsers?", "hiddenBundleIDs? ([String], full replacement)", "picker? { iconSize? (\"small\"/\"medium\"/\"large\"), showLabels?, layoutMode? (\"icons\"/\"list\"/\"radial\"/\"minimal\"), appearanceMode? (\"auto\"/\"custom\"), tintHex?, backgroundOpacity? (0-1), cornerRadius?, accentHex?, qrCodeAccentHex?, dimInactiveBrowsers?, colorScheme? (\"system\"/\"light\"/\"dark\"), showLinkPreview?, densityPreference? (\"default\"/\"compact\") }"],
                ],
            ]
            return httpResponse(status: 200, body: [
                "status": "ok",
                "app": "Chowser",
                "version": version,
                "browsers_count": manager.configuredBrowsers.count,
                "rules_count": manager.routingRules.count,
                "rewrites_count": manager.rewriteRules.count,
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
                if let args = browser.privateArguments { dict["privateArguments"] = args }
                return dict
            }
            return httpResponse(status: 200, body: ["browsers": browsers])

        case ("POST", "/browsers"):
            guard let body = body else {
                return httpResponse(status: 400, body: ["error": "Missing request body"])
            }
            return handleAddOrUpdateBrowser(body: body, manager: manager)

        case ("POST", "/browsers/preview"):
            guard let body = body else {
                return httpResponse(status: 400, body: ["error": "Missing request body"])
            }
            return handleBrowserLaunchPreview(body: body, manager: manager)

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
                // Dual-field compatibility window (pinned to drop at the next major
                // version): singular only when there's exactly one source app.
                dict["sourceAppBundleIDs"] = rule.sourceAppBundleIDs
                if rule.sourceAppBundleIDs.count == 1 { dict["sourceAppBundleId"] = rule.sourceAppBundleIDs[0] }
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

        // MARK: - Rewrites
        case ("GET", "/rewrites"):
            let encoder = JSONEncoder()
            let rewrites = manager.rewriteRules.compactMap { rule -> [String: Any]? in
                guard let data = try? encoder.encode(rule),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                return dict
            }
            return httpResponse(status: 200, body: ["rewrites": rewrites])

        case ("POST", "/rewrites"):
            guard let body = body else {
                return httpResponse(status: 400, body: ["error": "Missing request body"])
            }
            return handleAddOrUpdateRewrite(body: body, manager: manager)

        case ("DELETE", "/rewrites"):
            guard let idStr = queryParams["id"], let uuid = UUID(uuidString: idStr) else {
                return httpResponse(status: 400, body: ["error": "Missing or invalid 'id' query parameter"])
            }
            guard manager.rewriteRules.contains(where: { $0.id == uuid }) else {
                return httpResponse(status: 404, body: ["error": "Rewrite not found"])
            }
            manager.removeRewriteRule(id: uuid)
            return httpResponse(status: 200, body: ["status": "deleted", "id": idStr])

        // MARK: - Settings
        case ("GET", "/settings"):
            var fallback: [String: Any] = ["mode": manager.fallbackPolicy.mode.rawValue]
            if let browserID = manager.fallbackPolicy.browserID { fallback["browserId"] = browserID.uuidString }
            if let profile = manager.fallbackPolicy.profile { fallback["profile"] = profile }
            return httpResponse(status: 200, body: [
                "appMode": manager.appMode.rawValue,
                "fallbackPolicy": fallback,
                "networkLookupsEnabled": manager.networkLookupsEnabled,
                "userShortenerHosts": Array(manager.userShortenerHosts),
                "shortlinkResolutionTimeout": manager.shortlinkResolutionTimeout,
                "trackingCleanupEnabled": manager.trackingCleanupEnabled,
                "mcpAutoStartEnabled": manager.mcpAutoStartEnabled,
                "launchAtLogin": manager.launchAtLogin,
                "skipExistingImportedRules": manager.skipExistingImportedRules,
                "skipExistingImportedBrowsers": manager.skipExistingImportedBrowsers,
                "hiddenBundleIDs": Array(manager.hiddenBundleIDs),
                "picker": [
                    "iconSize": manager.pickerIconSize,
                    "showLabels": manager.pickerShowLabels,
                    "layoutMode": manager.pickerLayoutMode.rawValue,
                    "appearanceMode": manager.pickerAppearanceMode,
                    "tintHex": manager.pickerTintHex,
                    "backgroundOpacity": manager.pickerBackgroundOpacity,
                    "cornerRadius": manager.pickerCornerRadius,
                    "accentHex": manager.pickerAccentHex,
                    "qrCodeAccentHex": manager.qrCodeAccentHex,
                    "dimInactiveBrowsers": manager.pickerDimInactiveBrowsers,
                    "colorScheme": manager.pickerColorScheme,
                    "showLinkPreview": manager.showLinkPreview,
                    "densityPreference": manager.densityPreference,
                ],
            ])

        case ("POST", "/settings"):
            guard let body = body else {
                return httpResponse(status: 400, body: ["error": "Missing request body"])
            }
            return handleUpdateSettings(body: body, manager: manager)

        default:
            return httpResponse(status: 404, body: ["error": "Not found", "path": path, "method": method])
        }
    }

    private func handleUpdateSettings(body: Data, manager: BrowserManager) -> Data {
        do {
            try MCPSettingsUpdate.decodeAndValidate(body, using: manager).apply(to: manager)
            return httpResponse(status: 200, body: ["status": "updated"])
        } catch let error as MCPSettingsUpdateError {
            return httpResponse(status: error.httpStatus, body: error.responseBody(currentMode: manager.appMode))
        } catch {
            return httpResponse(status: 400, body: ["error": "Invalid settings payload"])
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
        let privateArguments = json["privateArguments"] as? String

        let identity = "\(bundleId)|\(profile ?? "")"

        if let existingIndex = manager.configuredBrowsers.firstIndex(where: { $0.identity == identity }) {
            // Update existing browser. The local API can force profile/custom/private args
            // in every build (the App Store UI keeps manual entry, this forces it for
            // agents). They persist; they apply at launch in the direct-download build.
            manager.configuredBrowsers[existingIndex].name = name
            manager.configuredBrowsers[existingIndex].profile = profile
            if let args = customArguments {
                manager.configuredBrowsers[existingIndex].customArguments = args.isEmpty ? nil : args
            }
            if let args = privateArguments {
                manager.configuredBrowsers[existingIndex].privateArguments = args.isEmpty ? nil : args
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
            if let newBrowser = manager.configuredBrowsers.last,
               let newIndex = manager.configuredBrowsers.firstIndex(where: { $0.id == newBrowser.id }) {
                if let args = customArguments, !args.isEmpty {
                    manager.configuredBrowsers[newIndex].customArguments = args
                }
                if let args = privateArguments, !args.isEmpty {
                    manager.configuredBrowsers[newIndex].privateArguments = args
                }
            }
            let addedId = manager.configuredBrowsers.last?.id.uuidString ?? "unknown"
            return httpResponse(status: 201, body: [
                "status": "created",
                "id": addedId,
                "launchArgumentsSupported": BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild,
            ])
        }
    }

    /// Dry-run: resolve exactly how a launch would be framed for the given browser/args,
    /// WITHOUT launching. Lets an agent show the user the precise command and confirm.
    private func handleBrowserLaunchPreview(body: Data, manager: BrowserManager) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let bundleId = json["bundleId"] as? String else {
            return httpResponse(status: 400, body: ["error": "Invalid JSON. Required field: bundleId"])
        }

        let profile = json["profile"] as? String
        let customArguments = json["customArguments"] as? String
        let privateArguments = json["privateArguments"] as? String
        let usePrivateMode = json["usePrivateMode"] as? Bool ?? false
        let urlString = json["url"] as? String ?? "https://example.com"
        guard let url = URL(string: urlString) else {
            return httpResponse(status: 400, body: ["error": "Invalid url", "url": urlString])
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return httpResponse(status: 404, body: ["error": "App not found for bundleId", "bundleId": bundleId])
        }

        #if APP_STORE
        let mode = BrowserManager.BrowserLaunchMode.appStoreSandbox
        #else
        let mode = BrowserManager.BrowserLaunchMode.directDownload
        #endif

        let plan = BrowserManager.launchPlan(
            forBundleID: bundleId,
            appURL: appURL,
            url: url,
            profile: profile,
            customArguments: customArguments,
            privateArguments: privateArguments,
            usePrivateMode: usePrivateMode,
            mode: mode
        )

        let command: String
        if plan.usesDirectOpenTool {
            command = "/usr/bin/open " + plan.directOpenArguments.joined(separator: " ")
        } else {
            let argsDesc = plan.deliveredApplicationArguments.isEmpty
                ? "(no extra arguments)"
                : plan.deliveredApplicationArguments.joined(separator: " ")
            command = "NSWorkspace.open([\(url.absoluteString)]) app=\(appURL.path) arguments=[\(argsDesc)]"
        }

        return httpResponse(status: 200, body: [
            "bundleId": bundleId,
            "appPath": appURL.path,
            "mode": mode == .directDownload ? "directDownload" : "appStoreSandbox",
            "usePrivateMode": usePrivateMode,
            "argumentType": plan.argumentType ?? "default",
            "requestedArguments": plan.requestedApplicationArguments,
            "deliveredArguments": plan.deliveredApplicationArguments,
            "command": command,
            "launchArgumentsSupported": BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild,
            "note": BrowserManager.supportsApplicationLaunchArgumentsInCurrentBuild
                ? "Arguments are delivered via /usr/bin/open and applied reliably."
                : "Sandboxed build: macOS may ignore these arguments at launch. Verify by testing.",
        ])
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
        // Write-path parity: accept the plural array as well as the legacy singular
        // field, so multi-source rules can be created/edited via MCP, not just listed.
        let sourceAppBundleIDs: [String]
        if let ids = json["sourceAppBundleIDs"] as? [String] {
            sourceAppBundleIDs = ids
        } else if let legacy = json["sourceAppBundleId"] as? String, !legacy.isEmpty {
            sourceAppBundleIDs = [legacy]
        } else {
            sourceAppBundleIDs = []
        }
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
            updated.sourceAppBundleIDs = sourceAppBundleIDs
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
            sourceAppBundleIDs: sourceAppBundleIDs,
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

    /// Write-path parity with /rules: mirrors the create-or-update shape. The `actions`
    /// array is re-serialized and decoded through `URLRewriteAction`'s existing tagged-union
    /// Codable rather than hand-parsing each of the 6 action shapes here.
    private func handleAddOrUpdateRewrite(body: Data, manager: BrowserManager) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let hostPattern = json["hostPattern"] as? String else {
            return httpResponse(status: 400, body: ["error": "Invalid JSON. Required field: hostPattern"])
        }

        let name = json["name"] as? String ?? hostPattern
        let useRegex = json["useRegex"] as? Bool ?? false
        let pathPrefix = json["pathPrefix"] as? String
        let schemes = json["schemes"] as? [String] ?? []
        let sourceAppBundleIDs = json["sourceAppBundleIDs"] as? [String] ?? []
        let isEnabled = json["isEnabled"] as? Bool ?? true

        var actions: [URLRewriteAction] = []
        if let actionsJSON = json["actions"],
           let actionsData = try? JSONSerialization.data(withJSONObject: actionsJSON),
           let decodedActions = try? JSONDecoder().decode([URLRewriteAction].self, from: actionsData) {
            actions = decodedActions
        }

        let match = URLRewriteMatch(schemes: schemes, hostPattern: hostPattern, useRegex: useRegex, pathPrefix: pathPrefix, sourceAppBundleIDs: sourceAppBundleIDs)

        if let idStr = json["id"] as? String {
            guard let uuid = UUID(uuidString: idStr) else {
                return httpResponse(status: 400, body: ["error": "Invalid rewrite id", "id": idStr])
            }
            guard var existing = manager.rewriteRules.first(where: { $0.id == uuid }) else {
                return httpResponse(status: 404, body: ["error": "Rewrite not found", "id": idStr])
            }
            existing.name = name
            existing.match = match
            existing.actions = actions
            existing.isEnabled = isEnabled

            switch manager.updateRewriteRule(existing) {
            case .success(let rule):
                return httpResponse(status: 200, body: ["status": "updated", "id": rule.id.uuidString])
            case .failure(let error):
                return httpResponse(status: 422, body: ["error": error.message])
            }
        }

        var newRule = URLRewriteRule(name: name, match: match, actions: actions)
        newRule.isEnabled = isEnabled

        switch manager.addRewriteRule(newRule) {
        case .success(let rule):
            return httpResponse(status: 201, body: ["status": "created", "id": rule.id.uuidString])
        case .failure(let error):
            return httpResponse(status: 422, body: ["error": error.message])
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

private struct MCPSettingsUpdate {
    private let request: Request
    private let fallbackPolicy: BrowserFallbackPolicy?

    static func decodeAndValidate(_ body: Data, using manager: BrowserManager) throws -> Self {
        let request: Request
        do {
            request = try JSONDecoder().decode(Request.self, from: body)
        } catch {
            throw MCPSettingsUpdateError.invalidPayload
        }

        try require(request.shortlinkResolutionTimeout, in: 0.5...5.0, field: "shortlinkResolutionTimeout")
        try require(request.picker?.backgroundOpacity, in: 0.2...1.0, field: "picker.backgroundOpacity")
        try require(request.picker?.cornerRadius, in: 8.0...28.0, field: "picker.cornerRadius")

        return MCPSettingsUpdate(
            request: request,
            fallbackPolicy: try request.fallbackPolicy.map { try $0.resolve(using: manager) }
        )
    }

    func apply(to manager: BrowserManager) throws {
        _ = try request.appMode.map {
            try AppDelegate.transitionAppMode(to: $0)
                .mapError(MCPSettingsUpdateError.transitionFailed)
                .get()
        }

        assign(fallbackPolicy, to: \BrowserManager.fallbackPolicy, on: manager)
        assign(request.networkLookupsEnabled, to: \BrowserManager.networkLookupsEnabled, on: manager)
        assign(request.userShortenerHosts.map(Set.init), to: \BrowserManager.userShortenerHosts, on: manager)
        assign(request.shortlinkResolutionTimeout, to: \BrowserManager.shortlinkResolutionTimeout, on: manager)
        assign(request.trackingCleanupEnabled, to: \BrowserManager.trackingCleanupEnabled, on: manager)
        assign(request.mcpAutoStartEnabled, to: \BrowserManager.mcpAutoStartEnabled, on: manager)
        assign(request.launchAtLogin, to: \BrowserManager.launchAtLogin, on: manager)
        assign(request.skipExistingImportedRules, to: \BrowserManager.skipExistingImportedRules, on: manager)
        assign(request.skipExistingImportedBrowsers, to: \BrowserManager.skipExistingImportedBrowsers, on: manager)
        assign(request.hiddenBundleIDs.map(Set.init), to: \BrowserManager.hiddenBundleIDs, on: manager)
        request.picker?.apply(to: manager)
    }

    private static func require(
        _ value: Double?,
        in range: ClosedRange<Double>,
        field: String
    ) throws {
        guard value.map(range.contains) != false else {
            throw MCPSettingsUpdateError.outOfRange(field: field, range: range)
        }
    }

    private struct Request: Decodable {
        let appMode: ChowserAppMode?
        let fallbackPolicy: FallbackPolicyRequest?
        let networkLookupsEnabled: Bool?
        let userShortenerHosts: [String]?
        let shortlinkResolutionTimeout: Double?
        let trackingCleanupEnabled: Bool?
        let mcpAutoStartEnabled: Bool?
        let launchAtLogin: Bool?
        let skipExistingImportedRules: Bool?
        let skipExistingImportedBrowsers: Bool?
        let hiddenBundleIDs: [String]?
        let picker: PickerRequest?
    }

    private struct FallbackPolicyRequest: Decodable {
        let mode: BrowserFallbackPolicy.Mode
        let browserID: UUID?
        let profile: String?

        private enum CodingKeys: String, CodingKey {
            case mode, profile
            case browserID = "browserId"
        }

        func resolve(using manager: BrowserManager) throws -> BrowserFallbackPolicy {
            let browserExists = browserID.map { id in
                manager.configuredBrowsers.contains(where: { $0.id == id })
            } ?? false
            guard mode != .browser || browserExists else {
                throw MCPSettingsUpdateError.fallbackBrowserRequired
            }
            return BrowserFallbackPolicy(mode: mode, browserID: browserID, profile: profile)
        }
    }

    private struct PickerRequest: Decodable {
        enum IconSize: String, Decodable { case small, medium, large }
        enum AppearanceMode: String, Decodable { case auto, custom }
        enum ColorScheme: String, Decodable { case system, light, dark }
        enum Density: String, Decodable { case compact, `default`, comfortable }

        let iconSize: IconSize?
        let showLabels: Bool?
        let layoutMode: PickerLayoutMode?
        let appearanceMode: AppearanceMode?
        let tintHex: String?
        let backgroundOpacity: Double?
        let cornerRadius: Double?
        let accentHex: String?
        let qrCodeAccentHex: String?
        let dimInactiveBrowsers: Bool?
        let colorScheme: ColorScheme?
        let showLinkPreview: Bool?
        let densityPreference: Density?

        func apply(to manager: BrowserManager) {
            assign(iconSize?.rawValue, to: \BrowserManager.pickerIconSize, on: manager)
            assign(showLabels, to: \BrowserManager.pickerShowLabels, on: manager)
            assign(layoutMode, to: \BrowserManager.pickerLayoutMode, on: manager)
            assign(appearanceMode?.rawValue, to: \BrowserManager.pickerAppearanceMode, on: manager)
            assign(tintHex, to: \BrowserManager.pickerTintHex, on: manager)
            assign(backgroundOpacity, to: \BrowserManager.pickerBackgroundOpacity, on: manager)
            assign(cornerRadius, to: \BrowserManager.pickerCornerRadius, on: manager)
            assign(accentHex, to: \BrowserManager.pickerAccentHex, on: manager)
            assign(qrCodeAccentHex, to: \BrowserManager.qrCodeAccentHex, on: manager)
            assign(dimInactiveBrowsers, to: \BrowserManager.pickerDimInactiveBrowsers, on: manager)
            assign(colorScheme?.rawValue, to: \BrowserManager.pickerColorScheme, on: manager)
            assign(showLinkPreview, to: \BrowserManager.showLinkPreview, on: manager)
            assign(densityPreference?.rawValue, to: \BrowserManager.densityPreference, on: manager)
        }
    }
}

private enum MCPSettingsUpdateError: Error {
    case invalidPayload
    case outOfRange(field: String, range: ClosedRange<Double>)
    case fallbackBrowserRequired
    case transitionFailed(AppDelegate.AppModeTransitionError)

    var httpStatus: Int {
        switch self {
        case .transitionFailed: 500
        default: 400
        }
    }

    func responseBody(currentMode: ChowserAppMode) -> [String: Any] {
        switch self {
        case .invalidPayload:
            ["error": "Invalid settings payload"]
        case let .outOfRange(field, range):
            ["error": "Invalid \(field). Expected a number from \(range.lowerBound) through \(range.upperBound)"]
        case .fallbackBrowserRequired:
            ["error": "fallbackPolicy.browserId is required and must reference an existing browser when mode is \"browser\""]
        case let .transitionFailed(error):
            ["error": error.localizedDescription, "appMode": currentMode.rawValue]
        }
    }
}

private func assign<Value>(
    _ value: Value?,
    to keyPath: ReferenceWritableKeyPath<BrowserManager, Value>,
    on manager: BrowserManager
) {
    _ = value.map { manager[keyPath: keyPath] = $0 }
}
