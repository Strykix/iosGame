#!/usr/bin/env swift
// Generates the 1024×1024 App Store icon procedurally (no external assets).
// Usage: swift scripts/generate_icon.swift StarBarge/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import CoreGraphics

let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("context") }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

// Sky gradient (bottom blue → top space black).
let sky = CGGradient(colorsSpace: space, colors: [color(0x3E74CC), color(0x1A2F6B), color(0x02030A)] as CFArray, locations: [0, 0.45, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 1024), options: [])

// Stars.
var seed: UInt64 = 7
func rand() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
}
for _ in 0..<70 {
    let r = 2 + rand() * 4
    ctx.setFillColor(color(0xFFFFFF, 0.4 + rand() * 0.6))
    ctx.fillEllipse(in: CGRect(x: rand() * 1024, y: 450 + rand() * 574, width: r, height: r))
}

// Kármán line.
ctx.setStrokeColor(color(0xFFD23F))
ctx.setLineWidth(8)
ctx.setLineDash(phase: 0, lengths: [40, 24])
ctx.move(to: CGPoint(x: 0, y: 850))
ctx.addLine(to: CGPoint(x: 1024, y: 850))
ctx.strokePath()
ctx.setLineDash(phase: 0, lengths: [])

// Tilt the rocket a bit for energy.
ctx.saveGState()
ctx.translateBy(x: 512, y: 470)
ctx.rotate(by: -0.18)

// Flame.
let flame = CGGradient(colorsSpace: space, colors: [color(0xFFF1B8), color(0xFF8A2A), color(0xFF5A36, 0)] as CFArray, locations: [0, 0.4, 1])!
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: -90, y: -520, width: 180, height: 420))
ctx.clip()
ctx.drawLinearGradient(flame, start: CGPoint(x: 0, y: -110), end: CGPoint(x: 0, y: -520), options: [])
ctx.restoreGState()

// Body (steel gradient).
let bodyW: CGFloat = 170
let body = CGMutablePath()
body.move(to: CGPoint(x: -bodyW / 2, y: -120))
body.addLine(to: CGPoint(x: -bodyW / 2, y: 250))
body.addCurve(to: CGPoint(x: 0, y: 420), control1: CGPoint(x: -bodyW / 2, y: 360), control2: CGPoint(x: -30, y: 420))
body.addCurve(to: CGPoint(x: bodyW / 2, y: 250), control1: CGPoint(x: 30, y: 420), control2: CGPoint(x: bodyW / 2, y: 360))
body.addLine(to: CGPoint(x: bodyW / 2, y: -120))
body.closeSubpath()
ctx.saveGState()
ctx.addPath(body)
ctx.clip()
let steel = CGGradient(colorsSpace: space, colors: [color(0x868D96), color(0xE3E7EC), color(0xE3E7EC), color(0x868D96)] as CFArray, locations: [0, 0.4, 0.6, 1])!
ctx.drawLinearGradient(steel, start: CGPoint(x: -bodyW / 2, y: 0), end: CGPoint(x: bodyW / 2, y: 0), options: [])
ctx.setFillColor(color(0x2B2E33))
ctx.fill(CGRect(x: -bodyW / 2, y: -120, width: bodyW * 0.3, height: 560))
ctx.restoreGState()

// Flaps.
ctx.setFillColor(color(0x5A6069))
for side: CGFloat in [-1, 1] {
    let aft = CGMutablePath()
    aft.move(to: CGPoint(x: side * bodyW / 2, y: -30))
    aft.addLine(to: CGPoint(x: side * (bodyW / 2 + 70), y: -100))
    aft.addLine(to: CGPoint(x: side * (bodyW / 2 + 70), y: -120))
    aft.addLine(to: CGPoint(x: side * bodyW / 2, y: -120))
    aft.closeSubpath()
    ctx.addPath(aft)
    let fwd = CGMutablePath()
    fwd.move(to: CGPoint(x: side * bodyW / 2, y: 290))
    fwd.addLine(to: CGPoint(x: side * (bodyW / 2 + 50), y: 250))
    fwd.addLine(to: CGPoint(x: side * bodyW / 2, y: 200))
    fwd.closeSubpath()
    ctx.addPath(fwd)
}
ctx.fillPath()
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
