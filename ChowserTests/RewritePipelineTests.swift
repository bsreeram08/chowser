import Testing
import Foundation
@testable import Chowser

// MARK: - RewritePipeline (pure engine) Tests

struct RewritePipelineTests {

    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    private func rule(name: String = "Rule", host: String = "*", useRegex: Bool = false, sourceApps: [String] = [], actions: [URLRewriteAction], isEnabled: Bool = true) -> URLRewriteRule {
        URLRewriteRule(
            name: name,
            isEnabled: isEnabled,
            match: URLRewriteMatch(hostPattern: host, useRegex: useRegex, sourceAppBundleIDs: sourceApps),
            actions: actions
        )
    }

    @Test("Force scheme leaves loopback hosts (localhost) unchanged")
    func forceSchemeSkipsLoopbackLocalhost() {
        let result = RewritePipeline.apply(url: url("http://localhost:5173/path"), rules: [rule(actions: [.forceScheme("https")])], sourceApp: nil)
        #expect(result.finalURL.scheme == "http")
        #expect(result.finalURL.absoluteString == "http://localhost:5173/path")
    }

    @Test("Force scheme leaves 127.0.0.1 and *.local unchanged")
    func forceSchemeSkipsOtherLoopbackHosts() {
        let httpLocal = RewritePipeline.apply(url: url("http://127.0.0.1:8000/x"), rules: [rule(actions: [.forceScheme("https")])], sourceApp: nil)
        #expect(httpLocal.finalURL.scheme == "http")

        let mdns = RewritePipeline.apply(url: url("http://app.local/api"), rules: [rule(actions: [.forceScheme("https")])], sourceApp: nil)
        #expect(mdns.finalURL.scheme == "http")
    }

    @Test("isLoopbackHost classifies loopback and mDNS hosts")
    func isLoopbackHostClassification() {
        #expect(RewritePipeline.isLoopbackHost("localhost"))
        #expect(RewritePipeline.isLoopbackHost("LOCALHOST"))
        #expect(RewritePipeline.isLoopbackHost("localhost.dev"))   // localhost.* namespace
        #expect(RewritePipeline.isLoopbackHost("localhost.internal"))
        #expect(RewritePipeline.isLoopbackHost("127.0.0.1"))
        #expect(RewritePipeline.isLoopbackHost("127.0.0.5"))       // 127.0.0.0/8
        #expect(RewritePipeline.isLoopbackHost("::1"))
        #expect(RewritePipeline.isLoopbackHost("::ffff:127.0.0.1"))
        #expect(RewritePipeline.isLoopbackHost("169.254.1.1"))     // link-local
        #expect(RewritePipeline.isLoopbackHost("app.local"))
        #expect(!RewritePipeline.isLoopbackHost("example.com"))
        #expect(!RewritePipeline.isLoopbackHost("sub.example.com"))
    }

    @Test("Force scheme leaves localhost.* dev hosts (e.g. localhost.dev) unchanged")
    func forceSchemeSkipsLocalhostSubdomain() {
        let result = RewritePipeline.apply(url: url("http://localhost.dev:8080/health-check"), rules: [rule(actions: [.forceScheme("https")])], sourceApp: nil)
        #expect(result.finalURL.scheme == "http")
        #expect(result.finalURL.absoluteString == "http://localhost.dev:8080/health-check")
    }

    @Test("Exclude host patterns skip matching hosts but not others")
    func excludeHostPatterns() {
        let rule = URLRewriteRule(
            name: "Force HTTPS except local",
            match: URLRewriteMatch(hostPattern: "*", excludeHostPatterns: ["*.local"]),
            actions: [.forceScheme("https")]
        )

        let excluded = RewritePipeline.apply(url: url("http://app.local/x"), rules: [rule], sourceApp: nil)
        #expect(excluded.steps.isEmpty, "excludeHostPatterns should prevent the rule from firing")

        let notExcluded = RewritePipeline.apply(url: url("http://example.com/x"), rules: [rule], sourceApp: nil)
        #expect(notExcluded.finalURL.scheme == "https")
    }

    @Test("Exclude host patterns decode tolerantly when missing from JSON")
    func excludeHostPatternsTolerantDecode() throws {
        let json = """
        {"hostPattern": "*", "actions": [{"type": "removeFragment"}]}
        """
        let match = try JSONDecoder().decode(URLRewriteMatch.self, from: Data(json.utf8))
        #expect(match.excludeHostPatterns.isEmpty)
    }

    @Test("Replace host action swaps the host")
    func replaceHost() {
        let result = RewritePipeline.apply(url: url("https://old.example.com/x"), rules: [rule(actions: [.replaceHost("new.example.com")])], sourceApp: nil)
        #expect(result.finalURL.host == "new.example.com")
    }

    @Test("Strip query parameters by exact name removes only matching params")
    func stripQueryParametersByName() {
        let result = RewritePipeline.apply(
            url: url("https://example.com/?utm_source=x&keep=1"),
            rules: [rule(actions: [.stripQueryParameters(["utm_source"])])],
            sourceApp: nil
        )
        #expect(result.finalURL.query == "keep=1")
    }

    @Test("Strip query parameters by prefix removes all matching params")
    func stripQueryParametersByPrefix() {
        let result = RewritePipeline.apply(
            url: url("https://example.com/?utm_source=x&utm_campaign=y&keep=1"),
            rules: [rule(actions: [.stripQueryParameterPrefixes(["utm_"])])],
            sourceApp: nil
        )
        #expect(result.finalURL.query == "keep=1")
    }

    @Test("Set query parameter adds a new param and replaces an existing one")
    func setQueryParameter() {
        let result = RewritePipeline.apply(
            url: url("https://example.com/?ref=old"),
            rules: [rule(actions: [.setQueryParameter(name: "ref", value: "new")])],
            sourceApp: nil
        )
        #expect(result.finalURL.query == "ref=new")
    }

    @Test("Remove fragment strips the URL fragment")
    func removeFragment() {
        let result = RewritePipeline.apply(url: url("https://example.com/page#section"), rules: [rule(actions: [.removeFragment])], sourceApp: nil)
        #expect(result.finalURL.fragment == nil)
        #expect(result.finalURL.absoluteString == "https://example.com/page")
    }

    @Test("FR-021: chained pipeline feeds first rule's output into the second rule's input")
    func chainedPipelineOrder() {
        let ruleA = rule(name: "Force HTTPS", actions: [.forceScheme("https")])
        let ruleB = rule(name: "Strip UTM", actions: [.stripQueryParameters(["utm_source"])])
        let result = RewritePipeline.apply(url: url("http://example.com/?utm_source=x"), rules: [ruleA, ruleB], sourceApp: nil)

        #expect(result.finalURL.absoluteString == "https://example.com/")
        #expect(result.steps.count == 2)
        #expect(result.steps[0].ruleName == "Force HTTPS")
        #expect(result.steps[0].afterURL.scheme == "https")
        #expect(result.steps[1].ruleName == "Strip UTM")
        #expect(result.steps[1].beforeURL.scheme == "https", "second rule must see the first rule's output, not the original URL")
    }

    @Test("FR-024: a rule whose output is invalid is skipped and the original URL proceeds unchanged")
    func invalidOutputIsSkipped() {
        let badRule = rule(name: "Break it", actions: [.forceScheme("ftp")])
        let goodRule = rule(name: "Strip UTM", actions: [.stripQueryParameters(["utm_source"])])
        let result = RewritePipeline.apply(url: url("https://example.com/?utm_source=x"), rules: [badRule, goodRule], sourceApp: nil)

        #expect(result.steps.count == 2)
        #expect(result.steps[0].skipped)
        #expect(result.steps[0].skipReason != nil)
        // Skipped rule's "afterURL" mirrors "before" — the rewrite didn't happen.
        #expect(result.steps[0].afterURL == result.steps[0].beforeURL)
        // The good rule still ran against the original (unmodified-by-the-bad-rule) URL.
        #expect(result.finalURL.query == nil)
    }

    @Test("Disabled rules never fire")
    func disabledRulesDoNotFire() {
        let result = RewritePipeline.apply(url: url("https://example.com/"), rules: [rule(actions: [.forceScheme("http")], isEnabled: false)], sourceApp: nil)
        #expect(result.steps.isEmpty)
        #expect(result.finalURL.scheme == "https")
    }

    @Test("Source app match: empty list matches any source; non-empty list requires a match")
    func sourceAppMatching() {
        let anySource = rule(actions: [.removeFragment])
        let slackOnly = rule(sourceApps: ["com.tinyspeck.slackmacgap"], actions: [.removeFragment])

        let anyResult = RewritePipeline.apply(url: url("https://example.com/#x"), rules: [anySource], sourceApp: nil)
        #expect(anyResult.steps.count == 1)

        let matchedResult = RewritePipeline.apply(url: url("https://example.com/#x"), rules: [slackOnly], sourceApp: "com.tinyspeck.slackmacgap")
        #expect(matchedResult.steps.count == 1)

        let unmatchedResult = RewritePipeline.apply(url: url("https://example.com/#x"), rules: [slackOnly], sourceApp: "com.apple.mail")
        #expect(unmatchedResult.steps.isEmpty)

        let noSourceResult = RewritePipeline.apply(url: url("https://example.com/#x"), rules: [slackOnly], sourceApp: nil)
        #expect(noSourceResult.steps.isEmpty)
    }

    @Test("Host pattern and scheme conditions gate whether a rule fires")
    func hostAndSchemeMatching() {
        let httpsOnly = URLRewriteRule(name: "R", match: URLRewriteMatch(schemes: ["https"], hostPattern: "*.example.com"), actions: [.removeFragment])

        let matched = RewritePipeline.apply(url: url("https://sub.example.com/#x"), rules: [httpsOnly], sourceApp: nil)
        #expect(matched.steps.count == 1)

        let wrongScheme = RewritePipeline.apply(url: url("http://sub.example.com/#x"), rules: [httpsOnly], sourceApp: nil)
        #expect(wrongScheme.steps.isEmpty)

        let wrongHost = RewritePipeline.apply(url: url("https://other.com/#x"), rules: [httpsOnly], sourceApp: nil)
        #expect(wrongHost.steps.isEmpty)
    }
}

// MARK: - BrowserManager rewrite CRUD / validation / import Tests

struct BrowserManagerRewriteTests {

    private func makeTestDefaults() -> UserDefaults {
        UserDefaults(suiteName: "com.chowser.tests.\(UUID().uuidString)")!
    }

    @Test("Hosted catalog preserves exclusion patterns when applying a rule")
    @MainActor
    func hostedCatalogPreservesExclusions() throws {
        let data = Data("""
        {
          "schemaVersion": 1,
          "catalogKind": "rewrite-rules",
          "catalogVersion": 2,
          "publishedAt": "2026-07-08T00:00:00Z",
          "rules": [{
            "id": "force-https",
            "name": "Force HTTPS",
            "summary": "Upgrade HTTP links.",
            "hostPattern": "*",
            "schemes": ["http"],
            "excludeHostPatterns": ["localhost", "127.0.0.1", "*.local"],
            "actions": [{"type": "forceScheme", "scheme": "https"}]
          }]
        }
        """.utf8)
        let catalog = try JSONDecoder().decode(RewriteCatalog.self, from: data)
        let manager = BrowserManager(defaults: makeTestDefaults())
        let verified = VerifiedRewriteCatalog(VerifiedHostedCatalog(
            document: catalog,
            artifact: HostedCatalogArtifact(documentData: data, signatureData: Data()),
            provenance: HostedCatalogProvenance(
                catalogKind: RewriteCatalog.expectedCatalogKind,
                catalogVersion: 2,
                keyID: "fixture",
                sha256: HostedCatalogTrust.sha256Hex(data),
                source: .remote
            )
        ))

        #expect(RewriteCatalogService.shared.applySelected(
            verified,
            manager: manager,
            selectedEntryIDs: ["force-https"]
        ).added == 1)
        #expect(manager.rewriteRules.first?.match.excludeHostPatterns == ["localhost", "127.0.0.1", "*.local"])
        #expect(manager.applyRewritePipeline(
            to: URL(string: "http://app.local:8080/")!,
            sourceApp: nil
        ).finalURL.scheme == "http")
        #expect(manager.applyRewritePipeline(
            to: URL(string: "http://example.com/")!,
            sourceApp: nil
        ).finalURL.scheme == "https")
    }

    @Test("Adding a rewrite rule with no actions is rejected")
    @MainActor
    func rejectsRuleWithNoActions() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let rule = URLRewriteRule(name: "Empty", match: URLRewriteMatch(hostPattern: "example.com"), actions: [])
        let result = manager.addRewriteRule(rule)
        guard case .failure(let error) = result else {
            Issue.record("Expected failure for a rule with no actions")
            return
        }
        #expect(error == .noActions)
        #expect(manager.rewriteRules.isEmpty)
    }

    @Test("Catastrophic-backtracking rewrite host patterns are rejected at save time (FR-028)")
    @MainActor
    func rejectsCatastrophicRegex() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let rule = URLRewriteRule(
            name: "Bad",
            match: URLRewriteMatch(hostPattern: "(a+)+", useRegex: true),
            actions: [.removeFragment]
        )
        let result = manager.addRewriteRule(rule)
        guard case .failure(let error) = result else {
            Issue.record("Expected the catastrophic pattern to be rejected")
            return
        }
        #expect(error == .regexTooComplex)
    }

    @Test("Valid rewrite rule round-trips through persistence")
    @MainActor
    func saveAndLoad() {
        let defaults = makeTestDefaults()
        let manager1 = BrowserManager(defaults: defaults)
        let rule = URLRewriteRule(name: "Strip UTM", match: URLRewriteMatch(hostPattern: "*"), actions: [.stripQueryParameterPrefixes(["utm_"])])
        let result = manager1.addRewriteRule(rule)
        #expect(result.isSuccess)

        let manager2 = BrowserManager(defaults: defaults)
        #expect(manager2.rewriteRules.count == 1)
        #expect(manager2.rewriteRules[0].name == "Strip UTM")
    }

    @Test("applyRewritePipeline records a skip reason for a rule that produces an invalid URL")
    @MainActor
    func appliesPipelineAndRecordsSkipReason() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let badRule = URLRewriteRule(name: "Bad", match: URLRewriteMatch(hostPattern: "*"), actions: [.forceScheme("ftp")])
        _ = manager.addRewriteRule(badRule)
        let savedRule = manager.rewriteRules[0]

        let result = manager.applyRewritePipeline(to: URL(string: "https://example.com/")!, sourceApp: nil)
        #expect(result.steps.first?.skipped == true)
        #expect(manager.rewriteSkipReasons[savedRule.id] != nil)
    }

    @Test("Import skips a malformed rewrite element without failing the whole array (per-item resilience)")
    @MainActor
    func importSkipsMalformedElement() throws {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let json = """
        [
          {"id": "\(UUID().uuidString)", "name": "Valid", "match": {"hostPattern": "*"}, "actions": [{"type": "removeFragment"}]},
          {"name": "Missing id and match entirely"},
          {"id": "\(UUID().uuidString)", "name": "No actions", "match": {"hostPattern": "*"}, "actions": []}
        ]
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try json.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let summary = try manager.importRewrites(from: tempURL)
        #expect(summary.added == 1)
        #expect(summary.invalid == 2)
        #expect(manager.rewriteRules.count == 1)
        #expect(manager.rewriteRules[0].name == "Valid")
    }

    @Test("Import skips non-object rewrite array elements (null/string/number) without failing the whole array")
    @MainActor
    func importSkipsNonObjectRewriteElements() throws {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let json = """
        [
          {"id": "\(UUID().uuidString)", "name": "Valid", "match": {"hostPattern": "*"}, "actions": [{"type": "removeFragment"}]},
          null,
          "not an object",
          7
        ]
        """
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try json.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let summary = try manager.importRewrites(from: tempURL)
        #expect(summary.added == 1)
        #expect(summary.invalid == 3)
        #expect(manager.rewriteRules.count == 1)
        #expect(manager.rewriteRules[0].name == "Valid")
    }

    @Test("Export then import round-trips a rewrite rule including its actions")
    @MainActor
    func exportImportRoundTrip() throws {
        let manager1 = BrowserManager(defaults: makeTestDefaults())
        let rule = URLRewriteRule(
            name: "Full",
            match: URLRewriteMatch(schemes: ["https"], hostPattern: "*.example.com", sourceAppBundleIDs: ["com.apple.mail"]),
            actions: [.forceScheme("https"), .setQueryParameter(name: "ref", value: "chowser"), .removeFragment]
        )
        _ = manager1.addRewriteRule(rule)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try manager1.exportRewrites(to: tempURL)

        let manager2 = BrowserManager(defaults: makeTestDefaults())
        let summary = try manager2.importRewrites(from: tempURL)
        #expect(summary.added == 1)
        #expect(manager2.rewriteRules.count == 1)
        #expect(manager2.rewriteRules[0].actions.count == 3)
        #expect(manager2.rewriteRules[0].match.sourceAppBundleIDs == ["com.apple.mail"])
    }

    @Test("moveRewriteRule reorders by id")
    @MainActor
    func moveRewriteRule() {
        let manager = BrowserManager(defaults: makeTestDefaults())
        let first = URLRewriteRule(name: "First", match: URLRewriteMatch(hostPattern: "*"), actions: [.removeFragment])
        let second = URLRewriteRule(name: "Second", match: URLRewriteMatch(hostPattern: "*"), actions: [.removeFragment])
        _ = manager.addRewriteRule(first)
        _ = manager.addRewriteRule(second)

        manager.moveRewriteRule(id: second.id, offsetBy: -1)
        #expect(manager.rewriteRules.map(\.name) == ["Second", "First"])
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
