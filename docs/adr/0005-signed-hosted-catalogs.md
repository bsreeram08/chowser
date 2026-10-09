# Signed hosted catalogs and native-app deep links

Chowser hosts two remotely updateable data sets: optional URL rewrites and a directory that maps exact HTTPS link shapes to installed native apps. Both can change where a link opens, so availability from the Chowser domain is not enough to establish trust.

## Trust boundary

Each catalog is signed offline with Ed25519 over its exact file bytes. The detached metadata names the catalog kind and key ID and repeats the SHA-256 digest. Chowser accepts an artifact only when the digest matches, the signature verifies against a public key bundled in the app, the signed catalog kind and schema match the expected type, and the feature-specific semantic validator accepts every entry. Document, signature, and item counts are bounded before use.

The last accepted document and signature are cached together and reverified on every load. Chowser rejects a catalog version lower than the highest accepted version and rejects different bytes that reuse the same version. A failed download, signature, or validation check can fall back only to that reverified last-known-good artifact.

This model addresses a compromised web host or CDN, accidental unsigned publication, local cache modification, rollback, and malformed signed input. It does not protect against compromise of the offline signing key, a maliciously modified Chowser binary, or a local account that can alter the running process.

## Restricted behavior languages

Rewrite entries contain only Chowser's typed URL actions. They cannot execute code or shell commands. The review UI starts with no selection, displays exact actions and elevated-risk reasons, never overwrites a same-name user rule, and records signed provenance. Editing an installed rule makes it user-owned. Catalog behavior updates require another explicit selection.

Native-app entries are data, not app-specific Swift code. Source rules use exact lowercase HTTP(S) hosts, fixed path lengths, bounded typed captures, and structured query requirements. Targets use a declared custom scheme plus either structured hierarchical components or an opaque colon-separated component list. Regex, scripts, free-form URL interpolation, credentials, ports, fragments, and reserved schemes such as `file`, `data`, `javascript`, `http`, `https`, and `chowser` are not allowed.

An entry is disabled by default. Approval is stored against a digest of its bundle identifiers, schemes, and rules, so a behavior change revokes the old approval. At resolution and again immediately before launch, Chowser requires macOS's registered handler for the custom scheme to match a bundle identifier in the signed entry. Explicit browser and Focus Mode routes take precedence; holding Shift forces the picker; private-mode requests bypass native-app routing.

Catalog fetches use fixed artifact URLs and never include the intercepted URL, host, source app, or browsing history. Catalog and native-routing diagnostics identify only catalog entries, versions, keys, and handler bundle identifiers; they do not log the clicked URL.

## Publishing workflow

The signing private key must remain outside this repository and outside CI. To publish a catalog:

1. Edit the catalog JSON, increment `catalogVersion`, and update `publishedAt`.
2. Review the complete diff. Preserve the restricted schema and do not add executable or free-form transformation fields.
3. Sign the exact committed bytes using the offline key:

   ```bash
   scripts/catalog-signing.swift sign \
     --private-key /secure/offline/chowser-catalog-key.json \
     --catalog docs/public/rewrite-catalog.json \
     --signature docs/public/rewrite-catalog.sig.json
   ```

   Substitute `native-app-directory.json` and its signature path for the native directory.

4. Verify both artifacts against the app keyring:

   ```bash
   scripts/catalog-signing.swift verify \
     --keyring Chowser/HostedCatalogKeys.json \
     --catalog docs/public/rewrite-catalog.json \
     --signature docs/public/rewrite-catalog.sig.json
   ```

5. Run the focused catalog tests and open a pull request. CI repeats detached-signature verification and the app's semantic trust-boundary tests before the docs artifact can deploy.

Changing whitespace after signing invalidates the signature by design. CI never signs content and no private key belongs in GitHub secrets for this workflow.

## Key rotation and recovery

Add a new public key to `Chowser/HostedCatalogKeys.json` and ship it in an app release before signing catalogs with the corresponding private key. Keep the previous public key during the migration window for older clients. Removing or revoking a key also requires an app release; stop publishing newly signed artifacts with a suspected key immediately and restore a known-safe catalog signed by a still-trusted key when available. Offline backups of the active private key are required because the public key cannot recover it.
