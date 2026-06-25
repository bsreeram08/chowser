import Testing
import Foundation
@testable import Chowser

struct LinkMetadataTests {
    @Test("Parses Open Graph title, description, and image")
    func parsesOpenGraph() {
        let html = """
        <html><head>
        <title>Fallback Title</title>
        <meta property="og:title" content="PR #42 &amp; the fix">
        <meta name="description" content="A short description.">
        <meta property="og:image" content="/preview.png">
        <link rel="icon" href="/favicon.ico">
        </head></html>
        """
        let url = URL(string: "https://example.com/page")!
        let meta = LinkMetadataFetcher.parse(html: html, finalURL: url)
        #expect(meta.title == "PR #42 & the fix")
        #expect(meta.description == "A short description.")
        #expect(meta.imageURL?.absoluteString == "https://example.com/preview.png")
        #expect(meta.faviconURL?.absoluteString == "https://example.com/favicon.ico")
        #expect(meta.isMeaningful)
    }

    @Test("Falls back to <title> when no og:title")
    func fallsBackToTitle() {
        let html = "<html><head><title>Just A Title</title></head></html>"
        let meta = LinkMetadataFetcher.parse(html: html, finalURL: URL(string: "https://x.com")!)
        #expect(meta.title == "Just A Title")
    }
}

extension LinkMetadataTests {
    @Test("Skips preview for likely single-use / auth links (would burn the token)")
    func skipsSingleUseLinks() {
        let consumed = [
            "https://app.example.com/login?token=abc123",
            "https://example.com/auth/callback?code=xyz&state=foo",  // /callback standalone
            "https://example.com/magic-link/abcdef",                 // magic-link standalone
            "https://example.com/verify/user-9f3a",                  // verify + sub-segment
            "https://example.com/reset-password?reset_token=q",      // reset_token param
            "https://example.com/account/confirm-email",             // confirm-email standalone
            "https://www.npmjs.com/auth/cli/f2bfad3c-776a-49a4-a120-1727c2b9b7d6",  // auth + uuid
        ]
        for s in consumed {
            #expect(LinkMetadataFetcher.isLikelySingleUse(URL(string: s)!), "should skip: \(s)")
        }
        let safe = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://github.com/bsreeram08/Chowser/pull/42",
            "https://example.com/blog/some-article",
            // Opaque IDs but idempotent GET (no auth-flow segment) — must NOT be skipped.
            "https://surfreceipts.com/8431650d6fa1b09706",
            "https://carbon.beta.surfboard.se/api/orders/online/843018ef708bb8900",
            // False positives the heuristic must NOT trip on:
            "https://shop.example.com/sale?code=SAVE20",   // coupon code, not OAuth
            "https://shop.example.com/reset",              // bare word, likely a product page
            "https://docs.example.com/sso",                // docs article about SSO
        ]
        for s in safe {
            #expect(!LinkMetadataFetcher.isLikelySingleUse(URL(string: s)!), "should NOT skip: \(s)")
        }
    }

    @Test("Prefers a raster favicon (apple-touch-icon) over SVG")
    func prefersRasterFavicon() {
        let html = """
        <head>
        <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
        <link rel="icon" href="/favicon.ico" sizes="32x32" />
        <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
        </head>
        """
        let meta = LinkMetadataFetcher.parse(html: html, finalURL: URL(string: "https://sreerams.in")!)
        #expect(meta.faviconURL?.absoluteString == "https://sreerams.in/apple-touch-icon.png")
    }
}
