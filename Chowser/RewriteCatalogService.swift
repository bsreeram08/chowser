import CryptoKit
import Foundation
import UserNotifications

struct RewriteCatalogEntry: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var summary: String = ""
    var hostPattern: String
    var useRegex: Bool = false
    var schemes: [String] = []
    var excludeHostPatterns: [String] = []
    var actions: [URLRewriteAction] = []
}

extension RewriteCatalogEntry {
    private enum CodingKeys: String, CodingKey {
        case id, name, summary, hostPattern, useRegex, schemes, excludeHostPatterns, actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        summary = (try container.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        hostPattern = try container.decode(String.self, forKey: .hostPattern)
        useRegex = (try container.decodeIfPresent(Bool.self, forKey: .useRegex)) ?? false
        schemes = (try container.decodeIfPresent([String].self, forKey: .schemes)) ?? []
        excludeHostPatterns = (try container.decodeIfPresent([String].self, forKey: .excludeHostPatterns)) ?? []
        actions = (try container.decodeIfPresent([URLRewriteAction].self, forKey: .actions)) ?? []
    }

    var review: RewriteCatalogEntryReview {
        var riskReasons: [String] = []
        if hostPattern.trimmingCharacters(in: .whitespacesAndNewlines) == "*" {
            riskReasons.append("Matches every host")
        }
        if useRegex {
            riskReasons.append("Uses a regular-expression host match")
        }
        if actions.contains(where: { action in
            if case .replaceHost = action { return true }
            return false
        }) {
            riskReasons.append("Changes the destination host")
        }

        return RewriteCatalogEntryReview(
            riskLevel: riskReasons.isEmpty ? .standard : .elevated,
            riskReasons: riskReasons,
            actionDescriptions: actions.map(\.reviewDescription)
        )
    }

    var behaviorSHA256: String {
        RewriteCatalogBehavior.sha256(
            match: URLRewriteMatch(
                schemes: schemes,
                hostPattern: hostPattern,
                useRegex: useRegex,
                excludeHostPatterns: excludeHostPatterns
            ),
            actions: actions
        )
    }

    func makeRule(
        id ruleID: UUID = UUID(),
        isEnabled: Bool = true,
        provenance: RewriteCatalogRuleProvenance? = nil
    ) -> URLRewriteRule {
        URLRewriteRule(
            id: ruleID,
            name: name,
            isEnabled: isEnabled,
            match: URLRewriteMatch(
                schemes: schemes,
                hostPattern: hostPattern,
                useRegex: useRegex,
                excludeHostPatterns: excludeHostPatterns
            ),
            actions: actions,
            catalogProvenance: provenance
        )
    }
}

struct RewriteCatalog: Codable, Identifiable, HostedCatalogDocument {
    static let expectedCatalogKind = "rewrite-rules"

    let schemaVersion: Int
    let catalogKind: String
    let catalogVersion: Int
    let publishedAt: String
    let rules: [RewriteCatalogEntry]

    var id: Int { catalogVersion }
    var itemCount: Int { rules.count }
}

enum RewriteCatalogRiskLevel: String, Codable, Equatable {
    case standard
    case elevated
}

struct RewriteCatalogEntryReview: Equatable {
    let riskLevel: RewriteCatalogRiskLevel
    let riskReasons: [String]
    let actionDescriptions: [String]
}

enum RewriteCatalogEntryStatus: Equatable {
    case new
    case added
    case changed
    case conflict
}

struct VerifiedRewriteCatalog: Identifiable {
    let verified: VerifiedHostedCatalog<RewriteCatalog>

    init(_ verified: VerifiedHostedCatalog<RewriteCatalog>) {
        self.verified = verified
    }

    var id: String { "\(catalog.catalogVersion):\(provenance.sha256)" }
    var catalog: RewriteCatalog { verified.document }
    var provenance: HostedCatalogProvenance { verified.provenance }

    /// Catalog changes never arrive pre-approved. Every install or behavior update starts
    /// with an empty selection and requires a direct user choice.
    var defaultSelectedEntryIDs: Set<String> { [] }

    func status(for entry: RewriteCatalogEntry, manager: BrowserManager) -> RewriteCatalogEntryStatus {
        if let existing = manager.rewriteRules.first(where: {
            $0.catalogProvenance?.entryID == entry.id
        }) {
            return existing.catalogProvenance?.behaviorSHA256 == entry.behaviorSHA256
                ? .added
                : .changed
        }
        if manager.rewriteRules.contains(where: { $0.name == entry.name }) {
            return .conflict
        }
        return .new
    }
}

struct RewriteCatalogApplyResult: Equatable {
    var added = 0
    var updated = 0
    var skipped = 0

    var changedCount: Int { added + updated }
}

enum RewriteCatalogBehavior {
    private struct Value: Codable {
        let match: URLRewriteMatch
        let actions: [URLRewriteAction]
    }

    static func sha256(for rule: URLRewriteRule) -> String {
        sha256(match: rule.match, actions: rule.actions)
    }

    static func sha256(match: URLRewriteMatch, actions: [URLRewriteAction]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(Value(match: match, actions: actions)) else {
            return ""
        }
        return HostedCatalogTrust.sha256Hex(data)
    }
}

extension URLRewriteAction {
    var reviewDescription: String {
        switch self {
        case .forceScheme(let scheme):
            return "Force scheme to \(scheme)"
        case .replaceHost(let host):
            return "Replace host with \(host)"
        case .stripQueryParameters(let names):
            return "Remove query parameters: \(names.joined(separator: ", "))"
        case .stripQueryParameterPrefixes(let prefixes):
            return "Remove query parameters beginning with: \(prefixes.joined(separator: ", "))"
        case .setQueryParameter(let name, let value):
            return "Set query parameter \(name) to \(value)"
        case .removeFragment:
            return "Remove URL fragment"
        }
    }
}

@MainActor
final class RewriteCatalogService {
    static let shared = RewriteCatalogService()

    static let catalogURL = URL(string: "https://chowser.sreerams.in/rewrite-catalog.json")!
    static let signatureURL = URL(string: "https://chowser.sreerams.in/rewrite-catalog.sig.json")!
    static let catalogPageURL = URL(string: "https://chowser.sreerams.in/rewrites")!

    private let client: HostedCatalogClient

    init(client: HostedCatalogClient? = nil) {
        self.client = client ?? Self.makeProductionClient()
    }

    private static func makeProductionClient() -> HostedCatalogClient {
        HostedCatalogClient(
            repository: HostedCatalogRepository(
                trust: HostedCatalogTrustConfiguration.production,
                cache: HostedCatalogCache()
            ),
            transport: URLSessionHostedCatalogTransport.shared
        )
    }

    func checkForUpdates(manager: BrowserManager) async -> VerifiedRewriteCatalog? {
        guard let catalog = await fetchCatalog(),
              catalog.catalog.catalogVersion > manager.lastSeenRewriteCatalogVersion else {
            return nil
        }
        return catalog
    }

    func fetchCatalog() async -> VerifiedRewriteCatalog? {
        do {
            let result = try await client.load(
                endpoint: HostedCatalogEndpoint(
                    documentURL: Self.catalogURL,
                    signatureURL: Self.signatureURL
                ),
                as: RewriteCatalog.self
            )
            if result.usedCachedFallback {
                AppLogger.log("RewriteCatalog", "Using the verified last-known-good rewrite catalog")
            }
            return VerifiedRewriteCatalog(result.verified)
        } catch {
            AppLogger.error(
                "RewriteCatalog",
                "Catalog fetch or verification failed (\(String(describing: type(of: error))))"
            )
            return nil
        }
    }

    func notifyUpdateAvailable(_ verifiedCatalog: VerifiedRewriteCatalog) {
        let catalog = verifiedCatalog.catalog
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted, error == nil else { return }
            let content = UNMutableNotificationContent()
            content.title = "New Chowser rewrite rules available"
            content.body = "\(catalog.rules.count) signed rewrite rules are ready to review. Nothing is selected automatically."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "in.sreerams.Chowser.rewriteCatalogUpdate",
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                if let error {
                    AppLogger.error("RewriteCatalog", "Notification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @discardableResult
    func applySelected(
        _ verifiedCatalog: VerifiedRewriteCatalog,
        manager: BrowserManager,
        selectedEntryIDs: Set<String>
    ) -> RewriteCatalogApplyResult {
        var result = RewriteCatalogApplyResult()
        let catalog = verifiedCatalog.catalog

        for entry in catalog.rules where selectedEntryIDs.contains(entry.id) {
            let provenance = RewriteCatalogRuleProvenance(
                entryID: entry.id,
                catalogVersion: catalog.catalogVersion,
                catalogSHA256: verifiedCatalog.provenance.sha256,
                behaviorSHA256: entry.behaviorSHA256,
                keyID: verifiedCatalog.provenance.keyID
            )

            if let existing = manager.rewriteRules.first(where: {
                $0.catalogProvenance?.entryID == entry.id
            }) {
                guard existing.catalogProvenance?.behaviorSHA256 != entry.behaviorSHA256 else {
                    result.skipped += 1
                    continue
                }
                let replacement = entry.makeRule(
                    id: existing.id,
                    isEnabled: existing.isEnabled,
                    provenance: provenance
                )
                if case .success = manager.updateRewriteRule(replacement) {
                    result.updated += 1
                    manager.catalogAppliedRuleNames.insert(entry.name)
                } else {
                    result.skipped += 1
                }
                continue
            }

            guard !manager.rewriteRules.contains(where: { $0.name == entry.name }) else {
                result.skipped += 1
                continue
            }
            if case .success = manager.addRewriteRule(entry.makeRule(provenance: provenance)) {
                result.added += 1
                manager.catalogAppliedRuleNames.insert(entry.name)
            } else {
                result.skipped += 1
            }
        }

        manager.lastSeenRewriteCatalogVersion = catalog.catalogVersion
        return result
    }
}
