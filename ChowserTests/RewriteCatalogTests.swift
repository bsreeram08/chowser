import CryptoKit
import Foundation
import Testing
@testable import Chowser

struct RewriteCatalogTests {
    private struct SignedFixture {
        let privateKey = Curve25519.Signing.PrivateKey()
        let keyID = "rewrite-fixture"

        var trust: HostedCatalogTrust {
            HostedCatalogTrust(keys: [
                HostedCatalogKey(keyID: keyID, publicKey: privateKey.publicKey.rawRepresentation)
            ])
        }

        func verified(
            version: Int,
            rules: [RewriteCatalogEntry]
        ) throws -> VerifiedRewriteCatalog {
            let catalog = RewriteCatalog(
                schemaVersion: 1,
                catalogKind: RewriteCatalog.expectedCatalogKind,
                catalogVersion: version,
                publishedAt: "2026-07-17T00:00:00Z",
                rules: rules
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let document = try encoder.encode(catalog)
            let digest = HostedCatalogTrust.sha256Hex(document)
            let metadata = HostedCatalogSignatureMetadata(
                schemaVersion: 1,
                catalogKind: RewriteCatalog.expectedCatalogKind,
                keyID: keyID,
                algorithm: "ed25519",
                sha256: digest,
                signature: try privateKey.signature(for: document).base64EncodedString()
            )
            let artifact = HostedCatalogArtifact(
                documentData: document,
                signatureData: try encoder.encode(metadata)
            )
            return VerifiedRewriteCatalog(try trust.verify(artifact, as: RewriteCatalog.self))
        }
    }

    private func entry(
        id: String = "strip-tracking",
        name: String = "Strip Tracking",
        hostPattern: String = "*",
        useRegex: Bool = false,
        actions: [URLRewriteAction] = [.stripQueryParameterPrefixes(["utm_"])]
    ) -> RewriteCatalogEntry {
        RewriteCatalogEntry(
            id: id,
            name: name,
            summary: "Removes known tracking parameters.",
            hostPattern: hostPattern,
            useRegex: useRegex,
            schemes: [],
            excludeHostPatterns: [],
            actions: actions
        )
    }

    private func manager() -> BrowserManager {
        let defaults = UserDefaults(suiteName: "in.sreerams.Chowser.RewriteCatalogTests.\(UUID().uuidString)")!
        return BrowserManager(defaults: defaults)
    }

    @Test("Committed rewrite catalog verifies with the public key bundled in the app")
    func committedArtifactVerifies() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let keyringData = try Data(contentsOf: repository.appendingPathComponent("Chowser/HostedCatalogKeys.json"))
        let keyring = try JSONDecoder().decode(HostedCatalogKeyring.self, from: keyringData)
        let artifact = HostedCatalogArtifact(
            documentData: try Data(contentsOf: repository.appendingPathComponent("docs/public/rewrite-catalog.json")),
            signatureData: try Data(contentsOf: repository.appendingPathComponent("docs/public/rewrite-catalog.sig.json"))
        )

        let verified = try HostedCatalogTrust(keys: keyring.trustedKeys())
            .verify(artifact, as: RewriteCatalog.self)

        #expect(verified.document.catalogVersion == 3)
        #expect(verified.document.rules.count == 6)
    }

    @Test("Review model starts with no catalog rules selected")
    func explicitSelectionDefault() throws {
        let review = try SignedFixture().verified(version: 1, rules: [entry()])

        #expect(review.defaultSelectedEntryIDs.isEmpty)
    }

    @Test("Review model shows exact actions and elevates broad or redirecting rewrites")
    func riskAndActionReview() {
        let broad = entry(actions: [
            .replaceHost("privacy.example"),
            .stripQueryParameters(["fbclid", "gclid"])
        ])
        let review = broad.review

        #expect(review.riskLevel == .elevated)
        #expect(review.riskReasons.contains("Matches every host"))
        #expect(review.riskReasons.contains("Changes the destination host"))
        #expect(review.actionDescriptions == [
            "Replace host with privacy.example",
            "Remove query parameters: fbclid, gclid"
        ])

        let regex = entry(hostPattern: "^(.+\\.)?example\\.com$", useRegex: true)
        #expect(regex.review.riskReasons.contains("Uses a regular-expression host match"))
    }

    @Test("Only explicitly selected entries are installed with signed provenance")
    @MainActor
    func selectedOnlyWithProvenance() throws {
        let fixture = SignedFixture()
        let first = entry(id: "first", name: "First")
        let second = entry(id: "second", name: "Second")
        let review = try fixture.verified(version: 3, rules: [first, second])
        let manager = manager()

        let result = RewriteCatalogService.shared.applySelected(
            review,
            manager: manager,
            selectedEntryIDs: [second.id]
        )

        #expect(result.added == 1)
        #expect(result.updated == 0)
        #expect(manager.rewriteRules.map(\.name) == ["Second"])
        #expect(manager.rewriteRules[0].catalogProvenance?.entryID == second.id)
        #expect(manager.rewriteRules[0].catalogProvenance?.catalogVersion == 3)
        #expect(manager.rewriteRules[0].catalogProvenance?.catalogSHA256 == review.provenance.sha256)
    }

    @Test("Changed catalog behavior is updated only after explicit selection")
    @MainActor
    func changedBehaviorRequiresSelection() throws {
        let fixture = SignedFixture()
        let manager = manager()
        let original = try fixture.verified(version: 1, rules: [entry()])
        _ = RewriteCatalogService.shared.applySelected(
            original,
            manager: manager,
            selectedEntryIDs: ["strip-tracking"]
        )
        let originalRuleID = manager.rewriteRules[0].id

        let changedEntry = entry(actions: [.stripQueryParameters(["fbclid"])])
        let changed = try fixture.verified(version: 2, rules: [changedEntry])
        #expect(changed.status(for: changedEntry, manager: manager) == .changed)

        let notSelected = RewriteCatalogService.shared.applySelected(
            changed,
            manager: manager,
            selectedEntryIDs: []
        )
        #expect(notSelected.updated == 0)
        #expect(manager.rewriteRules[0].actions == [.stripQueryParameterPrefixes(["utm_"])])

        let selected = RewriteCatalogService.shared.applySelected(
            changed,
            manager: manager,
            selectedEntryIDs: [changedEntry.id]
        )
        #expect(selected.updated == 1)
        #expect(manager.rewriteRules[0].id == originalRuleID)
        #expect(manager.rewriteRules[0].actions == [.stripQueryParameters(["fbclid"])])
    }

    @Test("Catalog installation never overwrites a same-name user rule")
    @MainActor
    func userRuleCollision() throws {
        let manager = manager()
        _ = manager.addRewriteRule(URLRewriteRule(
            name: "Strip Tracking",
            match: URLRewriteMatch(hostPattern: "example.com"),
            actions: [.removeFragment]
        ))
        let review = try SignedFixture().verified(version: 1, rules: [entry()])

        let result = RewriteCatalogService.shared.applySelected(
            review,
            manager: manager,
            selectedEntryIDs: ["strip-tracking"]
        )

        #expect(result.skipped == 1)
        #expect(manager.rewriteRules.count == 1)
        #expect(manager.rewriteRules[0].catalogProvenance == nil)
        #expect(manager.rewriteRules[0].actions == [.removeFragment])
    }

    @Test("Editing catalog behavior converts the rule to user-owned")
    @MainActor
    func editClearsProvenance() throws {
        let manager = manager()
        let review = try SignedFixture().verified(version: 1, rules: [entry()])
        _ = RewriteCatalogService.shared.applySelected(
            review,
            manager: manager,
            selectedEntryIDs: ["strip-tracking"]
        )

        var edited = manager.rewriteRules[0]
        edited.match.hostPattern = "example.com"
        _ = manager.updateRewriteRule(edited)

        #expect(manager.rewriteRules[0].catalogProvenance == nil)
    }

    @Test("Imported JSON cannot claim signed catalog provenance")
    @MainActor
    func importStripsProvenance() throws {
        let manager = manager()
        let provenance = RewriteCatalogRuleProvenance(
            entryID: "spoofed",
            catalogVersion: 999,
            catalogSHA256: String(repeating: "a", count: 64),
            behaviorSHA256: String(repeating: "b", count: 64),
            keyID: "spoofed-key"
        )
        let rule = URLRewriteRule(
            name: "Imported",
            match: URLRewriteMatch(hostPattern: "example.com"),
            actions: [.removeFragment],
            catalogProvenance: provenance
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rewrite-catalog-import-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode([rule]).write(to: url)

        let result = try manager.importRewrites(from: url)

        #expect(result.added == 1)
        #expect(manager.rewriteRules[0].catalogProvenance == nil)
    }
}
