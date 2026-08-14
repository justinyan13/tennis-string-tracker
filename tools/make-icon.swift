// Renders the Stringbed app icon: a lime stringbed on a night court.
// Run with: swift tools/make-icon.swift <output.png>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let path = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Stringbed/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r / 255, g / 255, b / 255, a])!
}

let court = rgb(7, 12, 9)
let courtLift = rgb(16, 26, 19)
let ball = rgb(212, 255, 62)
let frame = rgb(26, 34, 30)

// Background: a soft vertical lift so it doesn't read as flat black.
ctx.saveGState()
let bg = CGGradient(
    colorsSpace: space,
    colors: [courtLift, court] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// Floodlight behind the hoop.
ctx.saveGState()
let glow = CGGradient(
    colorsSpace: space,
    colors: [rgb(212, 255, 62, 0.28), rgb(212, 255, 62, 0.06), rgb(212, 255, 62, 0)] as CFArray,
    locations: [0, 0.45, 1]
)!
ctx.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: size / 2, y: size * 0.56), startRadius: 0,
    endCenter: CGPoint(x: size / 2, y: size * 0.56), endRadius: size * 0.55,
    options: []
)
ctx.restoreGState()

// Hoop geometry — same proportions as the in-app stringbed.
let cx = size / 2
let cy = size * 0.50
let a = size * 0.265
let b = a / 0.80
let frameWidth = a * 0.115
let ia = a - frameWidth
let ib = b - frameWidth
let yokeY = cy - ib * 0.985  // CoreGraphics y is flipped: the bed runs the full hoop

func halfHeight(atX x: Double) -> Double {
    let n = (x - cx) / ia
    guard abs(n) < 1 else { return 0 }
    return ib * (1 - n * n).squareRoot()
}

func halfWidth(atY y: Double) -> Double {
    let n = (y - cy) / ib
    guard abs(n) < 1 else { return 0 }
    return ia * (1 - n * n).squareRoot()
}

// Strings.
let mains = 7
let crosses = 8
ctx.setLineCap(.round)

ctx.setStrokeColor(ball)
ctx.setLineWidth(size * 0.026)
for i in 0..<mains {
    let t = (Double(i) + 1) / Double(mains + 1)
    let x = cx + (t * 2 - 1) * ia * 0.93
    let half = halfHeight(atX: x)
    guard half > 1 else { continue }
    let top = cy + half
    let bottom = max(cy - half, yokeY)
    guard top > bottom else { continue }
    ctx.move(to: CGPoint(x: x, y: top))
    ctx.addLine(to: CGPoint(x: x, y: bottom))
    ctx.strokePath()
}

ctx.setStrokeColor(rgb(241, 245, 238, 0.75))
ctx.setLineWidth(size * 0.022)
let topY = cy + ib * 0.965
for j in 0..<crosses {
    let t = (Double(j) + 1) / Double(crosses + 1)
    let y = topY - t * (topY - yokeY)
    let half = halfWidth(atY: y)
    guard half > 1 else { continue }
    ctx.move(to: CGPoint(x: cx - half, y: y))
    ctx.addLine(to: CGPoint(x: cx + half, y: y))
    ctx.strokePath()
}

// Frame band.
ctx.setStrokeColor(frame)
ctx.setLineWidth(frameWidth)
ctx.addEllipse(in: CGRect(
    x: cx - (ia + a) / 2, y: cy - (ib + b) / 2,
    width: ia + a, height: ib + b
))
ctx.strokePath()

// Outer highlight.
ctx.setStrokeColor(rgb(255, 255, 255, 0.16))
ctx.setLineWidth(size * 0.004)
ctx.addEllipse(in: CGRect(x: cx - a, y: cy - b, width: a * 2, height: b * 2))
ctx.strokePath()

guard let image = ctx.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: path)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(path)")
