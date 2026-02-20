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

// ── Background color (Lighter gray/blue for better text contrast) ──
let backgroundColor = CGColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
context.setFillColor(backgroundColor)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

// ── Subtle gradient at the bottom ──
let gradientColors = [
    CGColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1.0),
    CGColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [0.0, 1.0])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height), options: [])

// ── Left and Right "Plates" for icons ──
let leftCenter = CGPoint(x: 165, y: 190)
let rightCenter = CGPoint(x: 495, y: 190)
let plateRadius: CGFloat = 80

context.setShadow(offset: CGSize(width: 0, height: -2), blur: 10, color: CGColor(gray: 0, alpha: 0.1))

for center in [leftCenter, rightCenter] {
    context.setFillColor(CGColor(gray: 1.0, alpha: 0.8))
    context.addEllipse(in: CGRect(x: center.x - plateRadius, y: center.y - plateRadius, width: plateRadius * 2, height: plateRadius * 2))
    context.fillPath()
    
    context.setStrokeColor(CGColor(gray: 0, alpha: 0.05))
    context.setLineWidth(1.0)
    context.addEllipse(in: CGRect(x: center.x - plateRadius, y: center.y - plateRadius, width: plateRadius * 2, height: plateRadius * 2))
    context.strokePath()
}

// ── Arrow ──
let arrowY: CGFloat = 190
let arrowStartX: CGFloat = 260
let arrowEndX: CGFloat = 400
let arrowHeadSize: CGFloat = 12

context.setShadow(offset: .zero, blur: 0, color: nil) // Remove shadow
context.setStrokeColor(CGColor(red: 0.4, green: 0.5, blue: 1.0, alpha: 0.6))
context.setLineWidth(4.0)
context.setLineCap(.round)

context.move(to: CGPoint(x: arrowStartX, y: arrowY))
context.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
context.strokePath()

context.move(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY + arrowHeadSize))
context.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
context.addLine(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY - arrowHeadSize))
context.strokePath()

// ── Text Labels ──
let textFont = NSFont.systemFont(ofSize: 22, weight: .medium)
let labelFont = NSFont.systemFont(ofSize: 14, weight: .regular)

func drawText(_ string: String, at center: CGPoint, font: NSFont, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let size = string.size(withAttributes: attrs)
    
    context.saveGState()
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    
    let rect = CGRect(x: center.x - size.width/2, y: CGFloat(height) - center.y - size.height/2, width: size.width, height: size.height)
    
    NSGraphicsContext.saveGraphicsState()
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = nsContext
    string.draw(in: rect, withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
    
    context.restoreGState()
}

drawText("Drag to Applications", at: CGPoint(x: width/2, y: 60), font: textFont, color: NSColor.labelColor)

// Labels under plates (in case Finder labels are messy)
drawText("Chowser", at: CGPoint(x: leftCenter.x, y: 290), font: labelFont, color: NSColor.secondaryLabelColor)
drawText("Applications", at: CGPoint(x: rightCenter.x, y: 290), font: labelFont, color: NSColor.secondaryLabelColor)

// ── Save ──
guard let image = context.makeImage() else { exit(1) }
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outputPath) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("✅ Styled Background generated: \(outputPath)")
