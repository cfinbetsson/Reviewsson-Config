#!/usr/bin/env swift
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Generates a 1200x630 Open Graph / Slack preview banner using the app icon.
// Usage: swift make-og-image.swift <icon.png> <output.png>

let iconPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/appicon.png"
let outPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "docs/og-image.png"

let W = 1200, H = 630
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("context") }

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)])!
}

// Dark diagonal gradient backdrop.
let grad = CGGradient(colorsSpace: cs,
    colors: [color(0.05, 0.06, 0.11), color(0.10, 0.12, 0.22)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

// App icon (rounded) on the left.
let iconRect = CGRect(x: 90, y: (CGFloat(H) - 300) / 2, width: 300, height: 300)
if let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: iconPath) as CFURL, nil),
   let icon = CGImageSourceCreateImageAtIndex(src, 0, nil) {
    let clip = CGPath(roundedRect: iconRect, cornerWidth: 66, cornerHeight: 66, transform: nil)
    ctx.saveGState()
    ctx.addPath(clip)
    ctx.clip()
    ctx.draw(icon, in: iconRect)
    ctx.restoreGState()
}

// Left-aligned text helper (bottom-left origin).
func drawText(_ string: String, size: CGFloat, bold: Bool, color textColor: CGColor, x: CGFloat, y: CGFloat) {
    let fontName = bold ? "HelveticaNeue-Bold" : "HelveticaNeue"
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: textColor]
    let astr = CFAttributedStringCreate(nil, string as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(astr)
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
}

let textX: CGFloat = 450
drawText("Reviewsson", size: 76, bold: true, color: color(1, 1, 1), x: textX, y: 360)
drawText("Performance reviews, powered by your Jira data.",
         size: 30, bold: false, color: color(0.72, 0.74, 0.82), x: textX, y: 300)
drawText("Download for macOS", size: 27, bold: true, color: color(0.29, 0.62, 1.0), x: textX, y: 240)

guard let image = ctx.makeImage() else { fatalError("image") }
guard let dest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil
) else { fatalError("destination") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write") }
print("Wrote \(outPath)")
