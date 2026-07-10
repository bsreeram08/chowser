import Foundation
import UserNotifications

/// A single predefined rewrite rule as published in the hosted catalog. Shape mirrors
/// the POST /rewrites MCP body so the same JSON can be handed to an AI agent or decoded
/// here directly.
struct RewriteCatalogEntry: Codable {
    var name: String
    var hostPattern: String
    var useRegex: Bool = false
    var schemes: [String] = []
    var excludeHostPatterns: [String] = []
    var actions: [URLRewriteAction] = []
}

extension RewriteCatalogEntry {
    /// Tolerant decode: only `name`/`hostPattern` are required — synthesized Decodable
    /// does NOT apply a property's `= default` for a missing key, it throws
    /// `keyNotFound`, so any catalog entry omitting an optional field (e.g. `schemes`)
    /// would fail the whole array decode. Matches the tolerant-Codable pattern already
    /// established for `URLRewriteMatch`/`BrowserRoutingRule`.
    private enum CodingKeys: String, CodingKey {
        case name, hostPattern, useRegex, schemes, excludeHostPatterns, actions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        hostPattern = try c.decode(String.self, forKey: .hostPattern)
        useRegex = (try c.decodeIfPresent(Bool.self, forKey: .useRegex)) ?? false
        schemes = (try c.decodeIfPresent([String].self, forKey: .schemes)) ?? []
        excludeHostPatterns = (try c.decodeIfPresent([String].self, forKey: .excludeHostPatterns)) ?? []
        actions = (try c.decodeIfPresent([URLRewriteAction].self, forKey: .actions)) ?? []
    }
}

struct RewriteCatalog: Codable, Identifiable {
    var version: Int
    var updatedAt: String
    var rules: [RewriteCatalogEntry]

    var id: Int { version }
}

/// Fetches the predefined rewrite-rule catalog hosted on GitHub Pages alongside
/// agentic-setup.md. Explicit/user-triggered only (Settings button, AI Setup step,
/// or a menu bar item once available) — never runs automatically in the background,
/// consistent with network calls being opt-in by default (docs/adr/0003).
@MainActor
final class RewriteCatalogService {
    static let shared = RewriteCatalogService()

    static let catalogURL = URL(string: "https://chowser.sreerams.in/rewrite-catalog.json")!
    static let catalogPageURL = URL(string: "https://chowser.sreerams.in/rewrites")!

    private init() {}

    /// Returns the catalog only if it's newer than what the user has already seen/applied.
    func checkForUpdates(manager: BrowserManager) async -> RewriteCatalog? {
        guard let (data, response) = try? await URLSession.shared.data(from: Self.catalogURL),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            AppLogger.error("RewriteCatalog", "Fetch failed for \(Self.catalogURL.absoluteString)")
            return nil
        }
        guard let catalog = try? JSONDecoder().decode(RewriteCatalog.self, from: data) else {
            AppLogger.error("RewriteCatalog", "Failed to decode catalog response")
            return nil
        }
        guard catalog.version > manager.lastSeenRewriteCatalogVersion else { return nil }
        return catalog
    }

    /// Fetches the catalog **without** the version gate. Used for explicit user actions
    /// ("Check for Updates" / "Browse Predefined Rewrites") so rules can be re-reviewed —
    /// and re-added — even after the version has already been seen/applied.
    func fetchCatalog() async -> RewriteCatalog? {
        guard let (data, response) = try? await URLSession.shared.data(from: Self.catalogURL),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            AppLogger.error("RewriteCatalog", "Fetch failed for \(Self.catalogURL.absoluteString)")
            return nil
        }
        guard let catalog = try? JSONDecoder().decode(RewriteCatalog.self, from: data) else {
            AppLogger.error("RewriteCatalog", "Failed to decode catalog response")
            return nil
        }
        return catalog
    }

    /// Best-effort local notification. Requests authorization on first use — if the user
    /// has already denied notifications system-wide for Chowser, this silently no-ops;
    /// the in-app alert (SettingsView's pendingRewriteCatalog) is the guaranteed path.
    func notifyUpdateAvailable(_ catalog: RewriteCatalog) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted, error == nil else { return }
            let content = UNMutableNotificationContent()
            content.title = "New Chowser rewrite rules available"
            content.body = "\(catalog.rules.count) predefined rewrite rules ready to add — tracking-parameter cleanup, HTTPS upgrade, and more. Open Settings > Rewrites to review."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "in.sreerams.Chowser.rewriteCatalogUpdate", content: content, trigger: nil)
            center.add(request) { error in
                if let error {
                    AppLogger.error("RewriteCatalog", "Notification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Adds every catalog rule not already present (matched by name), skipping the rest.
    /// Returns the number actually added. Marks the catalog version seen regardless, so
    /// a user who declines isn't asked about the same version again. Records each added
    /// rule's name in `manager.catalogAppliedRuleNames` for later deletion detection.
    @discardableResult
    func apply(_ catalog: RewriteCatalog, manager: BrowserManager) -> Int {
        var added = 0
        for entry in catalog.rules {
            guard !manager.rewriteRules.contains(where: { $0.name == entry.name }) else { continue }
            let rule = URLRewriteRule(
                name: entry.name,
                match: URLRewriteMatch(
                    schemes: entry.schemes,
                    hostPattern: entry.hostPattern,
                    useRegex: entry.useRegex,
                    excludeHostPatterns: entry.excludeHostPatterns
                ),
                actions: entry.actions
            )
            if case .success = manager.addRewriteRule(rule) {
                added += 1
                manager.catalogAppliedRuleNames.insert(entry.name)
            }
        }
        manager.lastSeenRewriteCatalogVersion = catalog.version
        return added
    }

    /// Adds only the checked catalog rules (matched by name), skipping collisions. Returns
    /// the number actually added. Marks the catalog version seen. Records each added rule's
    /// name in `manager.catalogAppliedRuleNames` for later deletion detection.
    @discardableResult
    func applySelected(_ catalog: RewriteCatalog, manager: BrowserManager, selectedNames: Set<String>) -> Int {
        var added = 0
        for entry in catalog.rules where selectedNames.contains(entry.name) {
            guard !manager.rewriteRules.contains(where: { $0.name == entry.name }) else { continue }
            let rule = URLRewriteRule(
                name: entry.name,
                match: URLRewriteMatch(
                    schemes: entry.schemes,
                    hostPattern: entry.hostPattern,
                    useRegex: entry.useRegex,
                    excludeHostPatterns: entry.excludeHostPatterns
                ),
                actions: entry.actions
            )
            if case .success = manager.addRewriteRule(rule) {
                added += 1
                manager.catalogAppliedRuleNames.insert(entry.name)
            }
        }
        manager.lastSeenRewriteCatalogVersion = catalog.version
        return added
    }
}
