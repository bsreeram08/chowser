import AppKit
import CoreImage
import Foundation

struct PhoneLinkQRCode {
    let image: NSImage
    /// Alpha-only silhouette of the QR modules (opaque where a module is drawn, fully
    /// transparent elsewhere) so the UI can tint the code with any color via `.mask()`
    /// instead of showing flat black-on-white.
    let maskImage: NSImage
    let pngData: Data
    let encodedMessage: Data
}

struct PhoneLinkQRGenerator {
    enum Error: Swift.Error, Equatable {
        case invalidURL
        case unsupportedURL
        case generationFailed
    }

    /// SwiftUI re-creates the QR popover content view on observed changes; memoizing
    /// per URL keeps re-renders from re-running the filter + pixel loop each pass.
    private final class CacheBox {
        let code: PhoneLinkQRCode
        init(_ code: PhoneLinkQRCode) { self.code = code }
    }
    private static let cache = NSCache<NSString, CacheBox>()

    func makeQRCode(for url: URL?) throws -> PhoneLinkQRCode {
        let validURL = try validate(url)
        if let cached = Self.cache.object(forKey: validURL.absoluteString as NSString) {
            return cached.code
        }
        let encodedMessage = Data(validURL.absoluteString.utf8)
        // Rendering has shown transient first-attempt failures in the wild — retry once
        // before surfacing the error. Each failure point below logs so a repro pins the
        // exact stage instead of guessing.
        let code: PhoneLinkQRCode
        do {
            code = try render(encodedMessage)
        } catch Error.generationFailed {
            AppLogger.error("PhoneLinkQR", "QR render failed on first attempt, retrying")
            code = try render(encodedMessage)
        }
        Self.cache.setObject(CacheBox(code), forKey: validURL.absoluteString as NSString)
        return code
    }

    private func render(_ encodedMessage: Data) throws -> PhoneLinkQRCode {
        let qrImage = try makeQRCIImage(from: encodedMessage)
        let bitmap = try rasterize(qrImage)
        let maskBitmap = try makeMaskBitmap(from: bitmap)

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            AppLogger.error("PhoneLinkQR", "PNG encoding of QR bitmap failed")
            throw Error.generationFailed
        }

        return PhoneLinkQRCode(
            image: nsImage(from: bitmap),
            maskImage: nsImage(from: maskBitmap),
            pngData: pngData,
            encodedMessage: encodedMessage
        )
    }

    private func validate(_ url: URL?) throws -> URL {
        guard let url else { throw Error.invalidURL }
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            throw Error.invalidURL
        }
        guard scheme == "http" || scheme == "https" else {
            throw Error.unsupportedURL
        }
        guard url.host?.isEmpty == false else {
            throw Error.invalidURL
        }
        return url
    }

    private func makeQRCIImage(from encodedMessage: Data) throws -> CIImage {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            AppLogger.error("PhoneLinkQR", "CIQRCodeGenerator filter unavailable")
            throw Error.generationFailed
        }

        filter.setValue(encodedMessage, forKey: "inputMessage")
        // High correction level so the code still scans with a center icon overlaid on top.
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            AppLogger.error("PhoneLinkQR", "CIQRCodeGenerator produced no output image")
            throw Error.generationFailed
        }

        return outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    }

    /// Rasterizes through AppKit's drawing machinery (NSCIImageRep into an explicit
    /// RGBA bitmap) rather than a hand-made CIContext — the direct
    /// CIContext.createCGImage path showed intermittent nil returns in the app.
    private func rasterize(_ ciImage: CIImage) throws -> NSBitmapImageRep {
        let width = Int(ciImage.extent.width)
        let height = Int(ciImage.extent.height)
        guard width > 0, height > 0, let bitmap = makeRGBABitmap(width: width, height: height) else {
            AppLogger.error("PhoneLinkQR", "Could not allocate \(width)x\(height) QR bitmap")
            throw Error.generationFailed
        }

        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            AppLogger.error("PhoneLinkQR", "NSGraphicsContext creation failed for QR bitmap")
            throw Error.generationFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.cgContext.interpolationQuality = .none
        let drewSuccessfully = NSCIImageRep(ciImage: ciImage)
            .draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        graphicsContext.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard drewSuccessfully else {
            AppLogger.error("PhoneLinkQR", "NSCIImageRep.draw reported failure for QR image")
            throw Error.generationFailed
        }
        return bitmap
    }

    /// Pure-CPU mask derivation from the rendered black-on-white bitmap: dark pixel →
    /// opaque, light pixel → transparent. No Core Image chain — cannot transiently fail.
    private func makeMaskBitmap(from source: NSBitmapImageRep) throws -> NSBitmapImageRep {
        let width = source.pixelsWide
        let height = source.pixelsHigh
        guard let sourceBytes = source.bitmapData,
              let mask = makeRGBABitmap(width: width, height: height),
              let maskBytes = mask.bitmapData else {
            AppLogger.error("PhoneLinkQR", "Mask bitmap allocation failed")
            throw Error.generationFailed
        }

        let sourceRowStride = source.bytesPerRow
        let maskRowStride = mask.bytesPerRow
        for y in 0..<height {
            for x in 0..<width {
                let red = sourceBytes[y * sourceRowStride + x * 4]
                let alpha: UInt8 = red < 128 ? 255 : 0
                let offset = y * maskRowStride + x * 4
                maskBytes[offset] = 0
                maskBytes[offset + 1] = 0
                maskBytes[offset + 2] = 0
                maskBytes[offset + 3] = alpha
            }
        }
        return mask
    }

    private func makeRGBABitmap(width: Int, height: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    }

    private func nsImage(from bitmap: NSBitmapImageRep) -> NSImage {
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }
}
