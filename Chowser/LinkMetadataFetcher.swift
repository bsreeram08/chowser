import Foundation

/// Open-graph / page metadata for a clicked link, so the picker can show what the
/// user is about to open. `finalURL` is the destination after redirects (resolves
/// shortlinks for free, since URLSession follows redirects).
struct LinkMetadata: Equatable {
    var finalURL: URL
    var title: String?
    var description: String?
    var imageURL: URL?
    var faviconURL: URL?

    var isMeaningful: Bool {
        title?.isEmpty == false || description?.isEmpty == false || imageURL != nil
    }
}

enum LinkMetadataFetcher {
    /// Fetches metadata for `url`, following redirects. Uses an ephemeral session (no
    /// cookies) to limit tracking. Returns nil on failure/timeout.
    static func fetch(_ url: URL, timeout: TimeInterval = 6) async -> LinkMetadata? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        // A browser-like UA: many sites return bare/blocked HTML to unknown agents.
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)

        guard let (data, response) = try? await session.data(for: request) else { return nil }
        let finalURL = response.url ?? url
        // Parse only the head-ish prefix; metadata lives near the top.
        let html = String(decoding: data.prefix(400_000), as: UTF8.self)
        return parse(html: html, finalURL: finalURL)
    }

    /// Pure parser, separated from networking so it can be unit-tested offline.
    static func parse(html: String, finalURL: URL) -> LinkMetadata {
        let title = metaProperty(html, "og:title") ?? metaProperty(html, "twitter:title") ?? htmlTitle(html)
        let description = metaProperty(html, "og:description")
            ?? metaName(html, "description")
            ?? metaProperty(html, "twitter:description")
        let image = (metaProperty(html, "og:image") ?? metaProperty(html, "twitter:image"))
            .flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: finalURL)?.absoluteURL }
        let favicon = faviconURL(html, base: finalURL)

        return LinkMetadata(
            finalURL: finalURL,
            title: title?.decodedHTMLEntities().trimmed(),
            description: description?.decodedHTMLEntities().trimmed(),
            imageURL: image,
            faviconURL: favicon
        )
    }

    // MARK: - Parsing helpers (regex; intentionally dependency-free)

    private static func metaProperty(_ html: String, _ property: String) -> String? {
        // Matches <meta property="og:title" content="..."> in either attribute order.
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]+content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+(?:property|name)=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"']",
        ]
        for pattern in patterns {
            if let value = firstCapture(html, pattern), !value.isEmpty { return value }
        }
        return nil
    }

    private static func metaName(_ html: String, _ name: String) -> String? {
        metaProperty(html, name)
    }

    private static func htmlTitle(_ html: String) -> String? {
        firstCapture(html, "<title[^>]*>([^<]*)</title>")
    }

    private static func faviconURL(_ html: String, base: URL) -> URL? {
        if let href = firstCapture(html, "<link[^>]+rel=[\"'][^\"']*icon[^\"']*[\"'][^>]+href=[\"']([^\"']*)[\"']")
            ?? firstCapture(html, "<link[^>]+href=[\"']([^\"']*)[\"'][^>]+rel=[\"'][^\"']*icon[^\"']*[\"']"),
           let url = URL(string: href.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: base)?.absoluteURL {
            return url
        }
        // Fallback to the conventional /favicon.ico.
        return URL(string: "/favicon.ico", relativeTo: base)?.absoluteURL
    }

    private static func firstCapture(_ text: String, _ pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

private extension String {
    func trimmed() -> String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    func decodedHTMLEntities() -> String {
        guard contains("&") else { return self }
        let replacements = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " "]
        var result = self
        for (entity, char) in replacements { result = result.replacingOccurrences(of: entity, with: char) }
        return result
    }
}
