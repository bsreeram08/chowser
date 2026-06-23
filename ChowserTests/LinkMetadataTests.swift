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
