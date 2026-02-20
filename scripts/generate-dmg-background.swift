#!/usr/bin/env swift
// Generates a DMG background image using CoreGraphics (no dependencies)

import Cocoa

let width = 660
let height = 400

guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("❌ Failed to create graphics context")
    exit(1)
}

// ── Background gradient (dark indigo → deep purple) ──
let gradientColors = [
    CGColor(red: 0.09, green: 0.08, blue: 0.18, alpha: 1.0),
    CGColor(red: 0.14, green: 0.10, blue: 0.28, alpha: 1.0),
    CGColor(red: 0.10, green: 0.08, blue: 0.22, alpha: 1.0)
] as CFArray

let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: gradientColors,
    locations: [0.0, 0.5, 1.0]
)!

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: Double(height)),
    end: CGPoint(x: Double(width), y: 0),
    options: []
)

// ── Subtle glow circles for icon positions ──
let leftCenter = CGPoint(x: 165, y: 190)
let rightCenter = CGPoint(x: 495, y: 190)
let glowRadius: CGFloat = 70

for center in [leftCenter, rightCenter] {
    let glowGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 0.4, green: 0.35, blue: 0.7, alpha: 0.15),
            CGColor(red: 0.2, green: 0.15, blue: 0.4, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawRadialGradient(
        glowGradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: glowRadius * 1.5,
        options: []
    )
}

// ── Arrow between icons ──
let arrowY: CGFloat = 190
let arrowStartX: CGFloat = 250
let arrowEndX: CGFloat = 410
let arrowHeadSize: CGFloat = 10

context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
context.setLineWidth(2.0)
context.setLineCap(.round)

// Arrow line
context.move(to: CGPoint(x: arrowStartX, y: arrowY))
context.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
context.strokePath()

// Arrow head
context.move(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY + arrowHeadSize))
context.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
context.addLine(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY - arrowHeadSize))
context.strokePath()

// ── "Drag to install" text ──
let text = "Drag to Applications" as NSString
let font = NSFont.systemFont(ofSize: 18, weight: .light)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(white: 1.0, alpha: 0.7)
]
let textSize = text.size(withAttributes: attrs)

// Flip context for text drawing
context.saveGState()
context.translateBy(x: 0, y: CGFloat(height))
context.scaleBy(x: 1, y: -1)

let textX = (CGFloat(width) - textSize.width) / 2
let textY: CGFloat = 70 // from top after flip
let textRect = CGRect(x: textX, y: textY, width: textSize.width, height: textSize.height)

NSGraphicsContext.saveGraphicsState()
let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
NSGraphicsContext.current = nsContext
text.draw(in: textRect, withAttributes: attrs)
NSGraphicsContext.restoreGraphicsState()

context.restoreGState()

// ── Subtle bottom text ──
let bottomText = "Chowser — Browser Chooser for macOS" as NSString
let bottomFont = NSFont.systemFont(ofSize: 11, weight: .regular)
let bottomAttrs: [NSAttributedString.Key: Any] = [
    .font: bottomFont,
    .foregroundColor: NSColor(white: 1.0, alpha: 0.25)
]
let bottomSize = bottomText.size(withAttributes: bottomAttrs)

context.saveGState()
context.translateBy(x: 0, y: CGFloat(height))
context.scaleBy(x: 1, y: -1)

let bottomX = (CGFloat(width) - bottomSize.width) / 2
let bottomY = CGFloat(height) - 35
let bottomRect = CGRect(x: bottomX, y: bottomY, width: bottomSize.width, height: bottomSize.height)

NSGraphicsContext.saveGraphicsState()
let nsContext2 = NSGraphicsContext(cgContext: context, flipped: true)
NSGraphicsContext.current = nsContext2
bottomText.draw(in: bottomRect, withAttributes: bottomAttrs)
NSGraphicsContext.restoreGraphicsState()

context.restoreGState()

// ── Save to PNG ──
guard let image = context.makeImage() else {
    print("❌ Failed to create image")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    print("❌ Failed to create image destination")
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)

print("✅ Background generated: \(outputPath)")
