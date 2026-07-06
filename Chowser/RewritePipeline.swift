import Foundation

/// A persisted, ordered, typed transformation applied to a URL before routing rules are
/// evaluated. See CONTEXT.md: "Rewrite Rule". Cannot execute arbitrary code (FR-023).
struct URLRewriteRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var isEnabled: Bool = true
    var match: URLRewriteMatch
    var actions: [URLRewriteAction] = []
}

extension URLRewriteRule {
    /// Required fields (`id`, `name`, `match`) throw on decode failure — matching
    /// `BrowserRoutingRule`'s pattern (see PRD Architecture Notes "Correction"). Callers
    /// needing per-item import resilience decode elements individually, not the whole
    /// array at once (see `BrowserManager.importRewrites`).
    private enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, match, actions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isEnabled = (try c.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? true
        match = try c.decode(URLRewriteMatch.self, forKey: .match)
        actions = (try c.decodeIfPresent([URLRewriteAction].self, forKey: .actions)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encode(match, forKey: .match)
        try c.encode(actions, forKey: .actions)
    }
}

struct URLRewriteMatch: Codable, Equatable {
    /// Empty means "any scheme".
    var schemes: [String] = []
    var hostPattern: String
    var useRegex: Bool = false
    var pathPrefix: String?
    /// Empty means "any source app" (reuses Phase 2's matching semantics).
    var sourceAppBundleIDs: [String] = []
}

extension URLRewriteMatch {
    /// Tolerant decode: only `hostPattern` is required, everything else defaults —
    /// matches the "tolerant Codable" pattern already established for `BrowserRoutingRule`.
    private enum CodingKeys: String, CodingKey {
        case schemes, hostPattern, useRegex, pathPrefix, sourceAppBundleIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hostPattern = try c.decode(String.self, forKey: .hostPattern)
        schemes = (try c.decodeIfPresent([String].self, forKey: .schemes)) ?? []
        useRegex = (try c.decodeIfPresent(Bool.self, forKey: .useRegex)) ?? false
        pathPrefix = try c.decodeIfPresent(String.self, forKey: .pathPrefix)
        sourceAppBundleIDs = (try c.decodeIfPresent([String].self, forKey: .sourceAppBundleIDs)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hostPattern, forKey: .hostPattern)
        try c.encode(schemes, forKey: .schemes)
        try c.encode(useRegex, forKey: .useRegex)
        try c.encodeIfPresent(pathPrefix, forKey: .pathPrefix)
        try c.encode(sourceAppBundleIDs, forKey: .sourceAppBundleIDs)
    }
}

enum URLRewriteAction: Codable, Equatable {
    case forceScheme(String)
    case replaceHost(String)
    case stripQueryParameters([String])
    case stripQueryParameterPrefixes([String])
    case setQueryParameter(name: String, value: String)
    case removeFragment
}

extension URLRewriteAction {
    private enum ActionType: String, Codable {
        case forceScheme, replaceHost, stripQueryParameters, stripQueryParameterPrefixes, setQueryParameter, removeFragment
    }

    private enum CodingKeys: String, CodingKey {
        case type, scheme, host, names, prefixes, name, value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(ActionType.self, forKey: .type) {
        case .forceScheme:
            self = .forceScheme(try c.decode(String.self, forKey: .scheme))
        case .replaceHost:
            self = .replaceHost(try c.decode(String.self, forKey: .host))
        case .stripQueryParameters:
            self = .stripQueryParameters(try c.decode([String].self, forKey: .names))
        case .stripQueryParameterPrefixes:
            self = .stripQueryParameterPrefixes(try c.decode([String].self, forKey: .prefixes))
        case .setQueryParameter:
            self = .setQueryParameter(name: try c.decode(String.self, forKey: .name), value: try c.decode(String.self, forKey: .value))
        case .removeFragment:
            self = .removeFragment
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .forceScheme(let scheme):
            try c.encode(ActionType.forceScheme, forKey: .type)
            try c.encode(scheme, forKey: .scheme)
        case .replaceHost(let host):
            try c.encode(ActionType.replaceHost, forKey: .type)
            try c.encode(host, forKey: .host)
        case .stripQueryParameters(let names):
            try c.encode(ActionType.stripQueryParameters, forKey: .type)
            try c.encode(names, forKey: .names)
        case .stripQueryParameterPrefixes(let prefixes):
            try c.encode(ActionType.stripQueryParameterPrefixes, forKey: .type)
            try c.encode(prefixes, forKey: .prefixes)
        case .setQueryParameter(let name, let value):
            try c.encode(ActionType.setQueryParameter, forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(value, forKey: .value)
        case .removeFragment:
            try c.encode(ActionType.removeFragment, forKey: .type)
        }
    }
}

/// A separate pure type (not more `BrowserManager` methods) — see PRD Eng Review
/// "Rewrite engine is a separate pure type" and Architecture Diagram. This guarantees
/// FR-025 ("the tester must invoke the same rewrite-pipeline function used at runtime")
/// is literally true: both `BrowserManager.applyRewritePipeline` (runtime) and the
/// Settings tester call `RewritePipeline.apply` directly. Source app is an explicit
/// parameter, never read from ambient state.
enum RewritePipeline {
    /// One rule's before/after (FR-021's chained-pipeline tester requirement: each fired
    /// rule gets its own step, not a single collapsed "Original → Final" summary).
    struct Step: Identifiable, Equatable {
        var id = UUID()
        var ruleID: UUID
        var ruleName: String
        var beforeURL: URL
        var afterURL: URL
        var skipped: Bool
        var skipReason: String?
    }

    struct Result: Equatable {
        var finalURL: URL
        var steps: [Step]
    }

    /// Applies every enabled, matching rule in order, feeding each rule's output into the
    /// next rule's input (FR-021 — chained, not first-match-wins). A rule whose action
    /// chain produces an invalid (non-http/https) URL is skipped (FR-024): the original
    /// URL proceeds unchanged, as if the rewrite never happened.
    static func apply(url: URL, rules: [URLRewriteRule], sourceApp: String?) -> Result {
        var current = url
        var steps: [Step] = []

        for rule in rules where rule.isEnabled {
            guard matches(rule.match, url: current, sourceApp: sourceApp) else { continue }

            if let output = applyActions(rule.actions, to: current), isValidRewriteOutput(output) {
                steps.append(Step(ruleID: rule.id, ruleName: rule.name, beforeURL: current, afterURL: output, skipped: false, skipReason: nil))
                current = output
            } else {
                steps.append(Step(ruleID: rule.id, ruleName: rule.name, beforeURL: current, afterURL: current, skipped: true, skipReason: "Produced an invalid URL — skipped"))
            }
        }

        return Result(finalURL: current, steps: steps)
    }

    static func matches(_ match: URLRewriteMatch, url: URL, sourceApp: String?) -> Bool {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return false }

        if !match.schemes.isEmpty {
            guard let scheme = url.scheme?.lowercased(), match.schemes.contains(scheme) else { return false }
        }

        guard BrowserManager.hostMatches(host, pattern: match.hostPattern, useRegex: match.useRegex) else { return false }

        let path = url.path.isEmpty ? "/" : url.path
        guard BrowserManager.pathMatches(path, prefix: match.pathPrefix) else { return false }

        if !match.sourceAppBundleIDs.isEmpty {
            guard let sourceApp, match.sourceAppBundleIDs.contains(sourceApp) else { return false }
        }

        return true
    }

    static func isValidRewriteOutput(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        guard let host = url.host, !host.isEmpty else { return false }
        return true
    }

    private static func applyActions(_ actions: [URLRewriteAction], to url: URL) -> URL? {
        var current = url
        for action in actions {
            guard let next = applyAction(action, to: current) else { return nil }
            current = next
        }
        return current
    }

    private static func applyAction(_ action: URLRewriteAction, to url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        switch action {
        case .forceScheme(let scheme):
            components.scheme = scheme
        case .replaceHost(let host):
            components.host = host
        case .stripQueryParameters(let names):
            let lowered = Set(names.map { $0.lowercased() })
            components.queryItems = components.queryItems?.filter { !lowered.contains($0.name.lowercased()) }
            if components.queryItems?.isEmpty == true { components.queryItems = nil }
        case .stripQueryParameterPrefixes(let prefixes):
            let loweredPrefixes = prefixes.map { $0.lowercased() }
            components.queryItems = components.queryItems?.filter { item in
                !loweredPrefixes.contains { item.name.lowercased().hasPrefix($0) }
            }
            if components.queryItems?.isEmpty == true { components.queryItems = nil }
        case .setQueryParameter(let name, let value):
            var items = components.queryItems ?? []
            items.removeAll { $0.name == name }
            items.append(URLQueryItem(name: name, value: value))
            components.queryItems = items
        case .removeFragment:
            components.fragment = nil
        }

        return components.url
    }
}
