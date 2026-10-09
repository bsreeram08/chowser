#!/usr/bin/env swift
// Generates the DMG window background for Chowser.
// Logical 660×400 (matches the Finder window bounds in release-macos.yml), rendered @2x.
// Finder places the icons at (165, 190) and (495, 190) from the top-left and draws
// their labels itself, so this image only provides the canvas, heading, and arrow.

import Cocoa
import UniformTypeIdentifiers

let logicalW: CGFloat = 660
let logicalH: CGFloat = 400
let scale = 2

// Finder icon centres, converted from Finder's top-left origin to CoreGraphics' bottom-left.
let iconY = logicalH - 190
let appX: CGFloat = 165
let applicationsX: CGFloat = 495

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(
    data: nil, width: Int(logicalW) * scale, height: Int(logicalH) * scale,
    bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }
context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Soft light canvas: the app icon is a black squircle, so it needs a light ground to read.
let canvas = CGGradient(colorsSpace: space,
                        colors: [rgb(0xFBFBFD), rgb(0xEEF0F5)] as CFArray,
                        locations: [0, 1])!
context.drawLinearGradient(canvas, start: CGPoint(x: 0, y: logicalH), end: CGPoint(x: 0, y: 0), options: [])

// Faint halos under each icon so they sit on the canvas rather than float.
for x in [appX, applicationsX] {
    let halo = CGGradient(colorsSpace: space,
                          colors: [rgb(0xFFFFFF, 0.9), rgb(0xFFFFFF, 0)] as CFArray,
                          locations: [0, 1])!
    context.drawRadialGradient(halo, startCenter: CGPoint(x: x, y: iconY), startRadius: 0,
                               endCenter: CGPoint(x: x, y: iconY), endRadius: 95, options: [])
}

// Curved arrow from the app towards Applications.
let accent = rgb(0x5B6CFF)
let start = CGPoint(x: appX + 72, y: iconY + 6)
let end = CGPoint(x: applicationsX - 74, y: iconY + 6)
let control = CGPoint(x: (start.x + end.x) / 2, y: iconY + 46)

context.setLineCap(.round)
context.setLineJoin(.round)
context.setStrokeColor(accent)
context.setLineWidth(2.5)
context.setLineDash(phase: 0, lengths: [0.1, 7])
context.move(to: start)
context.addQuadCurve(to: end, control: control)
context.strokePath()

// Arrowhead aligned with the curve's end tangent.
let angle = atan2(end.y - control.y, end.x - control.x)
let head: CGFloat = 10
context.setLineDash(phase: 0, lengths: [])
context.setLineWidth(2.5)
context.move(to: CGPoint(x: end.x - head * cos(angle - .pi / 6), y: end.y - head * sin(angle - .pi / 6)))
context.addLine(to: end)
context.addLine(to: CGPoint(x: end.x - head * cos(angle + .pi / 6), y: end.y - head * sin(angle + .pi / 6)))
context.strokePath()

// Text.
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

func drawCentered(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor, kern: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: kern
    ]
    let width = text.size(withAttributes: attrs).width
    text.draw(at: CGPoint(x: (logicalW - width) / 2, y: y), withAttributes: attrs)
}

drawCentered("Install Chowser", y: 334, size: 21, weight: .semibold,
             color: NSColor(srgbRed: 0.07, green: 0.08, blue: 0.11, alpha: 1), kern: -0.3)
drawCentered("Drag Chowser into your Applications folder", y: 312, size: 12.5, weight: .regular,
             color: NSColor(srgbRed: 0.42, green: 0.44, blue: 0.50, alpha: 1))
drawCentered("Then open it from Applications and set it as your default browser.", y: 34, size: 11, weight: .regular,
             color: NSColor(srgbRed: 0.52, green: 0.54, blue: 0.60, alpha: 1))

guard let image = context.makeImage() else { exit(1) }
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outputPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("DMG background generated: \(outputPath)")
