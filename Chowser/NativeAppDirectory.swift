import Foundation

enum NativeCaptureCharacterSet: String, Codable, Equatable {
    case digits
    case asciiAlphanumeric
    case urlUnreserved
}

struct NativeCapture: Codable, Equatable {
    let name: String
    let characterSet: NativeCaptureCharacterSet
    let maxLength: Int

    func accepts(_ value: String) -> Bool {
        guard !name.isEmpty,
              name.count <= 64,
              maxLength > 0,
              maxLength <= 512,
              !value.isEmpty,
              value.count <= maxLength else {
            return false
        }

        return value.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            switch characterSet {
            case .digits:
                return value >= 48 && value <= 57
            case .asciiAlphanumeric:
                return (value >= 48 && value <= 57)
                    || (value >= 65 && value <= 90)
                    || (value >= 97 && value <= 122)
            case .urlUnreserved:
                return (value >= 48 && value <= 57)
                    || (value >= 65 && value <= 90)
                    || (value >= 97 && value <= 122)
                    || scalar == "-" || scalar == "." || scalar == "_" || scalar == "~"
            }
        }
    }
}

enum NativeSourcePathSegment: Codable, Equatable {
    case literal(String)
    case capture(NativeCapture)

    private enum Kind: String, Codable {
        case literal
        case capture
    }

    private enum CodingKeys: String, CodingKey {
        case type, value, name, characterSet, maxLength
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .literal:
            self = .literal(try container.decode(String.self, forKey: .value))
        case .capture:
            self = .capture(NativeCapture(
                name: try container.decode(String.self, forKey: .name),
                characterSet: try container.decode(NativeCaptureCharacterSet.self, forKey: .characterSet),
                maxLength: try container.decode(Int.self, forKey: .maxLength)
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .literal(let value):
            try container.encode(Kind.literal, forKey: .type)
            try container.encode(value, forKey: .value)
        case .capture(let capture):
            try container.encode(Kind.capture, forKey: .type)
            try container.encode(capture.name, forKey: .name)
            try container.encode(capture.characterSet, forKey: .characterSet)
            try container.encode(capture.maxLength, forKey: .maxLength)
        }
    }
}

struct NativeSourceQueryCapture: Codable, Equatable {
    let queryName: String
    let capture: NativeCapture
    let required: Bool
}

enum NativeTemplateValue: Codable, Equatable {
    case literal(String)
    case capture(String)

    private enum Kind: String, Codable {
        case literal
        case capture
    }

    private enum CodingKeys: String, CodingKey {
        case type, value, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .literal:
            self = .literal(try container.decode(String.self, forKey: .value))
        case .capture:
            self = .capture(try container.decode(String.self, forKey: .name))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .literal(let value):
            try container.encode(Kind.literal, forKey: .type)
            try container.encode(value, forKey: .value)
        case .capture(let name):
            try container.encode(Kind.capture, forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
}

struct NativeTargetQueryItem: Codable, Equatable {
    let name: String
    let value: NativeTemplateValue
}

struct NativeDeepLinkSource: Codable, Equatable {
    let hosts: [String]
    let path: [NativeSourcePathSegment]
    let query: [NativeSourceQueryCapture]
}

struct NativeDeepLinkTarget: Codable, Equatable {
    var scheme: String
    let host: String
    let path: [NativeTemplateValue]
    let query: [NativeTargetQueryItem]
}

struct NativeDeepLinkRule: Codable, Equatable, Identifiable {
    let id: String
    let source: NativeDeepLinkSource
    var target: NativeDeepLinkTarget
}

struct NativeAppDirectoryEntry: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    let summary: String
    let bundleIdentifiers: [String]
    var nativeSchemes: [String]
    var rules: [NativeDeepLinkRule]

    var behaviorSHA256: String {
        struct Behavior: Codable {
            let bundleIdentifiers: [String]
            let nativeSchemes: [String]
            let rules: [NativeDeepLinkRule]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(Behavior(
            bundleIdentifiers: bundleIdentifiers,
            nativeSchemes: nativeSchemes,
            rules: rules
        )) else {
            return ""
        }
        return HostedCatalogTrust.sha256Hex(data)
    }
}

struct NativeAppDirectory: Codable, Identifiable, HostedCatalogDocument {
    static let expectedCatalogKind = "native-apps"

    let schemaVersion: Int
    let catalogKind: String
    let catalogVersion: Int
    let publishedAt: String
    let apps: [NativeAppDirectoryEntry]

    var id: Int { catalogVersion }
    var itemCount: Int { apps.count }
}

struct NativeDeepLinkResolution: Equatable {
    let entryID: String
    let appName: String
    let matchedRuleID: String
    let handlerBundleIdentifier: String
    let nativeURL: URL
}

/// Pure, catalog-driven native URL resolver. It supports only exact HTTPS host matches,
/// bounded typed captures, and structured target construction. There is no executable
/// code, shell command, regex, arbitrary URL interpolation, or app-specific Swift branch.
enum NativeDeepLinkResolver {
    private static let reservedSchemes: Set<String> = [
        "http", "https", "file", "data", "javascript", "chowser"
    ]

    static func resolve(
        webURL: URL,
        in directory: NativeAppDirectory,
        approvedBehaviorSHA256ByEntryID approvals: [String: String],
        handlerBundleIdentifier: (URL) -> String?
    ) -> NativeDeepLinkResolution? {
        guard let sourceScheme = webURL.scheme?.lowercased(),
              sourceScheme == "http" || sourceScheme == "https" else {
            return nil
        }

        for entry in directory.apps {
            guard approvals[entry.id] == entry.behaviorSHA256 else { continue }
            for rule in entry.rules {
                guard let nativeURL = transformedURL(webURL, entry: entry, rule: rule),
                      let handler = handlerBundleIdentifier(nativeURL),
                      entry.bundleIdentifiers.contains(where: {
                          $0.caseInsensitiveCompare(handler) == .orderedSame
                      }) else {
                    continue
                }
                return NativeDeepLinkResolution(
                    entryID: entry.id,
                    appName: entry.name,
                    matchedRuleID: rule.id,
                    handlerBundleIdentifier: handler,
                    nativeURL: nativeURL
                )
            }
        }
        return nil
    }

    private static func transformedURL(
        _ webURL: URL,
        entry: NativeAppDirectoryEntry,
        rule: NativeDeepLinkRule
    ) -> URL? {
        guard let host = webURL.host?.lowercased(),
              rule.source.hosts.contains(where: { $0.lowercased() == host }),
              entry.nativeSchemes.contains(where: {
                  $0.caseInsensitiveCompare(rule.target.scheme) == .orderedSame
              }),
              isAllowedTargetScheme(rule.target.scheme),
              isSafeTargetHost(rule.target.host) else {
            return nil
        }

        guard let sourceSegments = decodedPathSegments(webURL),
              sourceSegments.count == rule.source.path.count else {
            return nil
        }
        var captures: [String: String] = [:]
        for (pattern, value) in zip(rule.source.path, sourceSegments) {
            switch pattern {
            case .literal(let expected):
                guard isSafeLiteral(expected), value == expected else { return nil }
            case .capture(let capture):
                guard capture.accepts(value), store(value, as: capture.name, in: &captures) else {
                    return nil
                }
            }
        }

        guard let components = URLComponents(url: webURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let sourceQuery = components.queryItems ?? []
        for requirement in rule.source.query {
            guard isSafeQueryName(requirement.queryName) else { return nil }
            let matchingValues = sourceQuery
                .filter { $0.name == requirement.queryName }
                .compactMap(\.value)
            if matchingValues.isEmpty, !requirement.required { continue }
            guard matchingValues.count == 1,
                  let value = matchingValues.first,
                  requirement.capture.accepts(value),
                  store(value, as: requirement.capture.name, in: &captures) else {
                return nil
            }
        }

        let targetSegments: [String] = rule.target.path.compactMap {
            resolve($0, captures: captures)
        }
        guard targetSegments.count == rule.target.path.count,
              targetSegments.allSatisfy({ isSafeTargetSegment($0) }) else {
            return nil
        }

        var target = URLComponents()
        target.scheme = rule.target.scheme.lowercased()
        target.host = rule.target.host
        if !targetSegments.isEmpty {
            target.path = "/" + targetSegments.joined(separator: "/")
        }

        var queryItems: [URLQueryItem] = []
        for item in rule.target.query {
            guard isSafeQueryName(item.name),
                  let value = resolve(item.value, captures: captures),
                  isSafeTargetQueryValue(value) else {
                return nil
            }
            queryItems.append(URLQueryItem(name: item.name, value: value))
        }
        target.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = target.url,
              url.scheme?.lowercased() == rule.target.scheme.lowercased(),
              url.host == rule.target.host,
              url.user == nil,
              url.password == nil,
              url.port == nil else {
            return nil
        }
        return url
    }

    private static func decodedPathSegments(_ url: URL) -> [String]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .map { encoded -> String? in
                guard let decoded = encoded.removingPercentEncoding,
                      !decoded.contains("/"),
                      !decoded.contains("\\") else {
                    return nil
                }
                return decoded
            }
            .reduce(into: Optional<[String]>([])) { result, value in
                guard var values = result, let value else {
                    result = nil
                    return
                }
                values.append(value)
                result = values
            }
    }

    private static func store(
        _ value: String,
        as name: String,
        in captures: inout [String: String]
    ) -> Bool {
        if let existing = captures[name] {
            return existing == value
        }
        captures[name] = value
        return true
    }

    private static func resolve(
        _ value: NativeTemplateValue,
        captures: [String: String]
    ) -> String? {
        switch value {
        case .literal(let literal):
            return literal
        case .capture(let name):
            return captures[name]
        }
    }

    private static func isAllowedTargetScheme(_ scheme: String) -> Bool {
        let lowered = scheme.lowercased()
        guard scheme == lowered,
              !reservedSchemes.contains(lowered),
              (1...32).contains(lowered.count),
              let first = lowered.unicodeScalars.first,
              isASCIILetter(first) else {
            return false
        }
        return lowered.unicodeScalars.dropFirst().allSatisfy { scalar in
            isASCIILetter(scalar)
                || (scalar.value >= 48 && scalar.value <= 57)
                || scalar == "+" || scalar == "-" || scalar == "."
        }
    }

    private static func isSafeTargetHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 128 else { return false }
        return host.unicodeScalars.allSatisfy { scalar in
            isASCIILetter(scalar)
                || (scalar.value >= 48 && scalar.value <= 57)
                || scalar == "-" || scalar == "."
        }
    }

    private static func isSafeLiteral(_ value: String) -> Bool {
        NativeCapture(name: "literal", characterSet: .urlUnreserved, maxLength: 256)
            .accepts(value)
    }

    private static func isSafeTargetSegment(_ value: String) -> Bool {
        value != "." && value != ".." && isSafeLiteral(value)
    }

    private static func isSafeQueryName(_ value: String) -> Bool {
        NativeCapture(name: "query", characterSet: .urlUnreserved, maxLength: 64)
            .accepts(value)
    }

    private static func isSafeTargetQueryValue(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 512
            && value.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value != 0x7F }
    }

    private static func isASCIILetter(_ scalar: UnicodeScalar) -> Bool {
        (scalar.value >= 65 && scalar.value <= 90)
            || (scalar.value >= 97 && scalar.value <= 122)
    }
}
