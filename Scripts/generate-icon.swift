import AppKit
import Foundation

let canvasSize = NSSize(width: 1024, height: 1024)
let canvas = NSImage(size: canvasSize)

canvas.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("无法创建图标绘图上下文")
}

let bounds = NSRect(origin: .zero, size: canvasSize)
let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 36, dy: 36), xRadius: 224, yRadius: 224)
let gradient = NSGradient(colors: [
    NSColor(red: 0.035, green: 0.18, blue: 0.14, alpha: 1),
    NSColor(red: 0.08, green: 0.42, blue: 0.31, alpha: 1)
])!
gradient.draw(in: background, angle: -48)

context.saveGState()
background.addClip()
for (point, radius, alpha) in [
    (NSPoint(x: 770, y: 795), CGFloat(210), CGFloat(0.075)),
    (NSPoint(x: 205, y: 250), CGFloat(150), CGFloat(0.055)),
    (NSPoint(x: 820, y: 205), CGFloat(95), CGFloat(0.05))
] {
    NSColor.white.withAlphaComponent(alpha).setFill()
    NSBezierPath(ovalIn: NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)).fill()
}
context.restoreGState()

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()

let stem = NSBezierPath()
stem.move(to: NSPoint(x: 500, y: 245))
stem.curve(
    to: NSPoint(x: 525, y: 680),
    controlPoint1: NSPoint(x: 440, y: 390),
    controlPoint2: NSPoint(x: 560, y: 525)
)
stem.lineWidth = 44
stem.lineCapStyle = .round
NSColor(red: 0.56, green: 0.96, blue: 0.70, alpha: 1).setStroke()
stem.stroke()

func drawLeaf(center: NSPoint, size: NSSize, rotation: CGFloat, colors: [NSColor]) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: rotation * .pi / 180)
    let rect = NSRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    let leaf = NSBezierPath(ovalIn: rect)
    NSGradient(colors: colors)!.draw(in: leaf, angle: -30)
    context.restoreGState()
}

drawLeaf(
    center: NSPoint(x: 388, y: 545),
    size: NSSize(width: 310, height: 190),
    rotation: 34,
    colors: [NSColor(red: 0.37, green: 0.93, blue: 0.60, alpha: 1), .systemMint]
)
drawLeaf(
    center: NSPoint(x: 650, y: 670),
    size: NSSize(width: 330, height: 205),
    rotation: -35,
    colors: [.systemMint, NSColor(red: 0.55, green: 1.0, blue: 0.72, alpha: 1)]
)

NSColor.white.withAlphaComponent(0.82).setFill()
NSBezierPath(ovalIn: NSRect(x: 725, y: 735, width: 70, height: 70)).fill()

canvas.unlockFocus()

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let projectURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let iconsetURL = projectURL.appendingPathComponent(".build/FocusGarden.iconset")
let outputURL = projectURL.appendingPathComponent("Resources/FocusGarden.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, pixels) in variants {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("无法创建 \(filename)") }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    canvas.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: bounds,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("无法编码 \(filename)")
    }
    try data.write(to: iconsetURL.appendingPathComponent(filename))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil 生成失败")
}

print(outputURL.path)
