#!/usr/bin/env swift
// Generates a HiDPI (2×) DMG background image using CoreGraphics
// Optimized for Finder's Retina rendering: logical 660×400, physical 1320×800

import Cocoa

// ─────────────────────────────────────────────
// MARK: – Configuration
// ─────────────────────────────────────────────

let appName     = "Chowser"
let scale       = 2                   // HiDPI scale factor
let logicalW    = 660
let logicalH    = 400
let physicalW   = logicalW * scale
let physicalH   = logicalH * scale
let s           = CGFloat(scale)      // shorthand for scaling values

// Colors
let bgColorTop      = CGColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
let bgColorBottom   = CGColor(red: 0.88, green: 0.91, blue: 0.95, alpha: 1.0)
let accentColor     = CGColor(red: 0.35, green: 0.48, blue: 0.95, alpha: 0.75)
let plateColor      = CGColor(red: 1.0,  green: 1.0,  blue: 1.0,  alpha: 0.85)
let plateBorder     = CGColor(gray: 0,   alpha: 0.06)
let plateShadow     = CGColor(gray: 0,   alpha: 0.12)
let glowColor       = CGColor(red: 0.55, green: 0.65, blue: 1.0,  alpha: 0.12)
let textPrimary     = NSColor(white: 0.10, alpha: 1.0)
let textSecondary   = NSColor(white: 0.35, alpha: 1.0)

// Layout (logical points — all values scaled internally)
let leftCenterLogical  = CGPoint(x: 165, y: 190)
let rightCenterLogical = CGPoint(x: 495, y: 190)
let plateRadiusLogical: CGFloat = 80

// ─────────────────────────────────────────────
// MARK: – Canvas setup
// ─────────────────────────────────────────────

guard let context = CGContext(
    data: nil,
    width: physicalW,
    height: physicalH,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("❌ Failed to create graphics context")
    exit(1)
}

// Scale all drawing to physical pixels
context.scaleBy(x: s, y: s)

// ─────────────────────────────────────────────
// MARK: – Helpers
// ─────────────────────────────────────────────

/// Draws an ellipse with an optional radial gradient fill (center → edge).
func drawPlate(center: CGPoint, radius: CGFloat) {
    let rect = CGRect(
        x: center.x - radius, y: center.y - radius,
        width: radius * 2, height: radius * 2
    )

    // Outer glow
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setFillColor(glowColor)
    context.addEllipse(in: rect.insetBy(dx: -12, dy: -12))
    context.fillPath()

    // Drop shadow + plate fill
    context.setShadow(offset: CGSize(width: 0, height: -3), blur: 12, color: plateShadow)
    context.setFillColor(plateColor)
    context.addEllipse(in: rect)
    context.fillPath()

    // Radial gradient overlay ("lit from top-left")
    context.saveGState()
    context.addEllipse(in: rect)
    context.clip()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    let gradColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.55),
        CGColor(red: 0.92, green: 0.94, blue: 0.98, alpha: 0.0)
    ] as CFArray
    let radGrad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: gradColors,
        locations: [0.0, 1.0]
    )!
    let gradCenter = CGPoint(x: center.x - radius * 0.25, y: center.y + radius * 0.25)
    context.drawRadialGradient(
        radGrad,
        startCenter: gradCenter, startRadius: 0,
        endCenter: center, endRadius: radius,
        options: []
    )
    context.restoreGState()

    // Hairline border
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setStrokeColor(plateBorder)
    context.setLineWidth(1.0)
    context.addEllipse(in: rect)
    context.strokePath()
}

/// Draws an arrow from `start` to `end` with a rounded arrowhead.
func drawArrow(from start: CGPoint, to end: CGPoint, headSize: CGFloat) {
    context.setShadow(offset: CGSize(width: 0, height: -1), blur: 6, color: CGColor(gray: 0, alpha: 0.15))
    context.setStrokeColor(accentColor)
    context.setLineWidth(5.0)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // Shaft
    context.move(to: start)
    context.addLine(to: CGPoint(x: end.x - headSize * 0.5, y: end.y))
    context.strokePath()

    // Head
    context.move(to: CGPoint(x: end.x - headSize, y: end.y + headSize))
    context.addLine(to: end)
    context.addLine(to: CGPoint(x: end.x - headSize, y: end.y - headSize))
    context.strokePath()

    context.setShadow(offset: .zero, blur: 0, color: nil)
}

// ─────────────────────────────────────────────
// MARK: – Background gradient
// ─────────────────────────────────────────────

let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [bgColorBottom, bgColorTop] as CFArray,
    locations: [0.0, 1.0]
)!
context.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: CGFloat(logicalH)),
    options: []
)

// ─────────────────────────────────────────────
// MARK: – Plates & Arrow
// ─────────────────────────────────────────────

drawPlate(center: leftCenterLogical,  radius: plateRadiusLogical)
drawPlate(center: rightCenterLogical, radius: plateRadiusLogical)

drawArrow(
    from: CGPoint(x: leftCenterLogical.x  + plateRadiusLogical + 14, y: leftCenterLogical.y),
    to:   CGPoint(x: rightCenterLogical.x - plateRadiusLogical - 14, y: rightCenterLogical.y),
    headSize: 11
)

// ─────────────────────────────────────────────
// MARK: – Text (single NSGraphicsContext batch)
// ─────────────────────────────────────────────

let titleFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
let labelFont = NSFont.systemFont(ofSize: 13, weight: .regular)

struct TextEntry {
    let string: String
    let center: CGPoint   // logical coords, origin bottom-left
    let font: NSFont
    let color: NSColor
}

let textEntries: [TextEntry] = [
    TextEntry(
        string: "Drag \(appName) to Applications to install",
        center: CGPoint(x: logicalW / 2, y: 58),
        font: titleFont,
        color: textPrimary
    ),
    TextEntry(
        string: appName,
        center: CGPoint(x: leftCenterLogical.x, y: 94),
        font: labelFont,
        color: textSecondary
    ),
    TextEntry(
        string: "Applications",
        center: CGPoint(x: rightCenterLogical.x, y: 94),
        font: labelFont,
        color: textSecondary
    ),
]

// One save/restore for all text
context.saveGState()
context.translateBy(x: 0, y: CGFloat(logicalH))
context.scaleBy(x: 1, y: -1)

NSGraphicsContext.saveGraphicsState()
let nsCtx = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = nsCtx

for entry in textEntries {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: entry.font,
        .foregroundColor: entry.color
    ]
    let size = entry.string.size(withAttributes: attrs)
    let rect = CGRect(
        x: entry.center.x - size.width / 2,
        y: CGFloat(logicalH) - entry.center.y - size.height / 2,
        width: size.width,
        height: size.height
    )
    entry.string.draw(in: rect, withAttributes: attrs)
}

NSGraphicsContext.restoreGraphicsState()
context.restoreGState()

// ─────────────────────────────────────────────
// MARK: – Export
// ─────────────────────────────────────────────

guard let image = context.makeImage() else {
    print("❌ Failed to create image from context")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "dmg_background.png"

let outputURL = URL(fileURLWithPath: outputPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(outputURL, "public.png" as CFString, 1, nil) else {
    print("❌ Failed to create image destination")
    exit(1)
}

// Embed 144 dpi metadata so Finder treats this as @2x
let pngProps = [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary
CGImageDestinationAddImage(dest, image, pngProps)

guard CGImageDestinationFinalize(dest) else {
    print("❌ Failed to write image to disk")
    exit(1)
}

print("✅ HiDPI background written to: \(outputPath)")
print("   Physical size: \(physicalW)×\(physicalH)px @ 144dpi (logical \(logicalW)×\(logicalH)pt)")