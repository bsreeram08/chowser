#!/usr/bin/env swift
// Generates a Premium Dark-Theme (Zinc-950) DMG background for Chowser
// Optimized for Retina displays: logical 660×400, physical 1320×800

import Cocoa
import UniformTypeIdentifiers

// ─────────────────────────────────────────────
// MARK: – Configuration
// ─────────────────────────────────────────────

let appName     = "Chowser"
let scale       = 2
let logicalW    = 660
let logicalH    = 400
let physicalW   = logicalW * scale
let physicalH   = logicalH * scale
let s           = CGFloat(scale)

// Colors (Zinc-950 Palette)
let colorBg         = CGColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1.0)
let colorPlate      = CGColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 0.8)
let colorBorder     = CGColor(gray: 1.0, alpha: 0.08)
let colorAccent     = CGColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0) // Blue-500
let colorGlow       = CGColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.06)
let textWhite       = NSColor(white: 0.95, alpha: 1.0)
let textMuted       = NSColor(white: 0.50, alpha: 1.0)

// ─────────────────────────────────────────────
// MARK: – Canvas Setup
// ─────────────────────────────────────────────

guard let context = CGContext(
    data: nil, width: physicalW, height: physicalH,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("❌ Failed to create context")
    exit(1)
}

context.scaleBy(x: s, y: s)

// ─────────────────────────────────────────────
// MARK: – Drawing Logic
// ─────────────────────────────────────────────

func drawBackground() {
    // 1. Base Dark Fill
    context.setFillColor(colorBg)
    context.fill(CGRect(x: 0, y: 0, width: logicalW, height: logicalH))
    
    // 2. Subtle Radial Glow (Center)
    let gradColors = [colorGlow, CGColor(gray: 0, alpha: 0)] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(gradient, 
                               startCenter: CGPoint(x: logicalW/2, y: logicalH/2), startRadius: 0, 
                               endCenter: CGPoint(x: logicalW/2, y: logicalH/2), endRadius: 300, 
                               options: [])
}

func drawSquirclePlate(at center: CGPoint) {
    let size: CGFloat = 110
    let rect = CGRect(x: center.x - size/2, y: center.y - size/2, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28).cgPath
    
    // Plate Fill
    context.setFillColor(colorPlate)
    context.addPath(path)
    context.fillPath()
    
    // Plate Border
    context.setStrokeColor(colorBorder)
    context.setLineWidth(1.0)
    context.addPath(path)
    context.strokePath()
}

func drawConnectingLine() {
    let startX: CGFloat = 165 + 60
    let endX: CGFloat = 495 - 60
    let y: CGFloat = 190
    
    // Path Glow
    context.setStrokeColor(colorAccent.copy(alpha: 0.1)!)
    context.setLineWidth(4.0)
    context.move(to: CGPoint(x: startX, y: y))
    context.addLine(to: CGPoint(x: endX, y: y))
    context.strokePath()
    
    // Sharp Accent Line
    context.setStrokeColor(colorAccent)
    context.setLineWidth(1.5)
    context.setLineDash(phase: 0, lengths: [4, 4])
    context.move(to: CGPoint(x: startX, y: y))
    context.addLine(to: CGPoint(x: endX, y: y))
    context.strokePath()
    
    // Arrowhead
    context.setLineDash(phase: 0, lengths: [])
    context.move(to: CGPoint(x: endX - 8, y: y + 5))
    context.addLine(to: CGPoint(x: endX, y: y))
    context.addLine(to: CGPoint(x: endX - 8, y: y - 5))
    context.strokePath()
}

func drawText() {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: textWhite,
        .kern: 0.5
    ]
    
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: textMuted
    ]
    
    // "Install Chowser"
    let titleStr = "Install \(appName)"
    let titleSize = titleStr.size(withAttributes: titleAttrs)
    titleStr.draw(at: CGPoint(x: (CGFloat(logicalW) - titleSize.width) / 2, y: 340), withAttributes: titleAttrs)
    
    // Source/Target Labels
    "\(appName).app".draw(at: CGPoint(x: 165 - 35, y: 110), withAttributes: subAttrs)
    "Applications".draw(at: CGPoint(x: 495 - 35, y: 110), withAttributes: subAttrs)
    
    // Onboarding Instructions
    let step1Str = "Step 1: Drag to Applications"
    let step1Size = step1Str.size(withAttributes: subAttrs)
    step1Str.draw(at: CGPoint(x: 165 - (step1Size.width / 2), y: 80), withAttributes: subAttrs)
    
    let step2Str = "Step 2: Right-Click and select 'Open'"
    let step2Size = step2Str.size(withAttributes: subAttrs)
    step2Str.draw(at: CGPoint(x: 495 - (step2Size.width / 2), y: 80), withAttributes: subAttrs)
    
    NSGraphicsContext.restoreGraphicsState()
}

// ─────────────────────────────────────────────
// MARK: – Execution
// ─────────────────────────────────────────────

drawBackground()
drawConnectingLine()
drawSquirclePlate(at: CGPoint(x: 165, y: 190))
drawSquirclePlate(at: CGPoint(x: 495, y: 190))
drawText()

guard let image = context.makeImage() else { exit(1) }

// Use first command line argument as output path, or default to dmg_background.png
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
let outputURL = URL(fileURLWithPath: outputPath) as CFURL

guard let dest = CGImageDestinationCreateWithURL(outputURL, UTType.png.identifier as CFString, 1, nil) else {
    print("❌ Failed to create image destination at \(outputPath)")
    exit(1)
}

CGImageDestinationAddImage(dest, image, [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary)
CGImageDestinationFinalize(dest)

print("✅ High-end Dark DMG Background generated: \(outputPath)")