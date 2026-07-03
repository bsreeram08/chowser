import Testing
import Foundation
@testable import Chowser

struct PhoneLinkQRGeneratorTests {
    @Test("HTTPS URLs generate non-empty QR image output")
    func httpsURLGeneratesNonEmptyImageOutput() throws {
        let generator = PhoneLinkQRGenerator()
        let url = URL(string: "https://example.com/path?q=1")!

        let code = try generator.makeQRCode(for: url)

        #expect(code.encodedMessage == Data("https://example.com/path?q=1".utf8))
        #expect(!code.pngData.isEmpty)
        #expect(code.image.size.width > 0)
        #expect(code.image.size.height > 0)
    }

    @Test("QR payload preserves the exact absolute URL string")
    func payloadPreservesExactAbsoluteURLString() throws {
        let generator = PhoneLinkQRGenerator()
        let url = URL(string: "https://example.com/path?q=1&utm_source=Exact%20Value#section")!

        let code = try generator.makeQRCode(for: url)

        #expect(code.encodedMessage == Data(url.absoluteString.utf8))
        #expect(String(data: code.encodedMessage, encoding: .utf8) == url.absoluteString)
    }

    @Test("Invalid QR inputs return typed errors and no image")
    func invalidInputsReturnTypedErrorsAndNoImage() {
        let generator = PhoneLinkQRGenerator()
        let cases: [(String, URL?, PhoneLinkQRGenerator.Error)] = [
            ("nil", nil, .invalidURL),
            ("empty", URL(string: ""), .invalidURL),
            ("malformed", URL(string: "not a url"), .invalidURL),
            ("file", URL(fileURLWithPath: "/tmp/example.html"), .unsupportedURL),
            ("mailto", URL(string: "mailto:hello@example.com"), .unsupportedURL),
            ("ftp", URL(string: "ftp://example.com/file"), .unsupportedURL),
        ]

        for (name, url, expectedError) in cases {
            do {
                _ = try generator.makeQRCode(for: url)
                Issue.record("Expected typed error for invalid QR input: \(name)")
            } catch let error as PhoneLinkQRGenerator.Error {
                #expect(error == expectedError, "Unexpected QR error for \(name)")
            } catch {
                Issue.record("Expected PhoneLinkQRGenerator.Error for \(name), got \(error)")
            }
        }
    }
}
