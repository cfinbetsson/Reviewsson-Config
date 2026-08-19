#!/usr/bin/env swift
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Generates the DMG window background (640x400) with a title, an arrow pointing
// from the app to the Applications folder, and a hint line.
// Usage: swift make-dmg-background.swift <output.png>

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "assets/dmg-background.png"

let W = 640, H = 400
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("context") }

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)])!
}

// Vertical gradient backdrop.
let grad = CGGradient(colorsSpace: cs,
    colors: [color(0.97, 0.98, 1.0), color(0.88, 0.92, 0.97)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// Arrow from the app (left icon) to the Applications folder (right icon).
// Icons are centered at (160,200) and (480,200) from the top in a 640x400 window,
// i.e. y = 200 from the bottom here. Draw the arrow across the gap between them.
let accent = color(0.04, 0.52, 1.0)
let ay: CGFloat = 200
ctx.setStrokeColor(accent)
ctx.setFillColor(accent)
ctx.setLineWidth(10)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 250, y: ay))
ctx.addLine(to: CGPoint(x: 372, y: ay))
ctx.strokePath()
// Arrowhead.
ctx.move(to: CGPoint(x: 366, y: ay + 16))
ctx.addLine(to: CGPoint(x: 398, y: ay))
ctx.addLine(to: CGPoint(x: 366, y: ay - 16))
ctx.closePath()
ctx.fillPath()

// Centered text helper (CoreText, bottom-left origin).
func drawCenteredText(_ string: String, size: CGFloat, bold: Bool, color textColor: CGColor, y: CGFloat) {
    let fontName = bold ? "HelveticaNeue-Bold" : "HelveticaNeue"
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: textColor,
    ]
    let astr = CFAttributedStringCreate(nil, string as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(astr)
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
    ctx.textPosition = CGPoint(x: (CGFloat(W) - width) / 2, y: y)
    CTLineDraw(line, ctx)
}

drawCenteredText("Reviewsson", size: 30, bold: true, color: color(0.11, 0.11, 0.12), y: 340)
drawCenteredText("Drag Reviewsson onto the Applications folder to install",
                 size: 14, bold: false, color: color(0.42, 0.42, 0.46), y: 44)

guard let image = ctx.makeImage() else { fatalError("image") }
let url = URL(fileURLWithPath: outPath) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)
else { fatalError("destination") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write") }
print("Wrote \(outPath)")
