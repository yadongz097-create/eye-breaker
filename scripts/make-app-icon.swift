import AppKit
import Foundation

struct IconGenerationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    if let context = NSGraphicsContext.current {
        context.shouldAntialias = true
        context.imageInterpolation = .high
    }

    let bounds = NSRect(origin: .zero, size: NSSize(width: size, height: size))
    NSColor(calibratedRed: 0.17, green: 0.66, blue: 0.36, alpha: 1.0).setFill()

    let background = NSBezierPath(
        roundedRect: bounds.insetBy(dx: size * 0.10, dy: size * 0.10),
        xRadius: size * 0.22,
        yRadius: size * 0.22
    )
    background.fill()

    let eyeRect = bounds.insetBy(dx: size * 0.18, dy: size * 0.28)
    let eyePath = NSBezierPath()
    eyePath.move(to: NSPoint(x: eyeRect.minX, y: eyeRect.midY))
    eyePath.curve(
        to: NSPoint(x: eyeRect.midX, y: eyeRect.maxY),
        controlPoint1: NSPoint(x: eyeRect.minX + eyeRect.width * 0.12, y: eyeRect.maxY),
        controlPoint2: NSPoint(x: eyeRect.midX - eyeRect.width * 0.18, y: eyeRect.maxY)
    )
    eyePath.curve(
        to: NSPoint(x: eyeRect.maxX, y: eyeRect.midY),
        controlPoint1: NSPoint(x: eyeRect.midX + eyeRect.width * 0.18, y: eyeRect.maxY),
        controlPoint2: NSPoint(x: eyeRect.maxX - eyeRect.width * 0.12, y: eyeRect.maxY)
    )
    eyePath.curve(
        to: NSPoint(x: eyeRect.midX, y: eyeRect.minY),
        controlPoint1: NSPoint(x: eyeRect.maxX - eyeRect.width * 0.12, y: eyeRect.minY),
        controlPoint2: NSPoint(x: eyeRect.midX + eyeRect.width * 0.18, y: eyeRect.minY)
    )
    eyePath.curve(
        to: NSPoint(x: eyeRect.minX, y: eyeRect.midY),
        controlPoint1: NSPoint(x: eyeRect.midX - eyeRect.width * 0.18, y: eyeRect.minY),
        controlPoint2: NSPoint(x: eyeRect.minX + eyeRect.width * 0.12, y: eyeRect.minY)
    )
    eyePath.close()
    NSColor.white.setFill()
    eyePath.fill()

    let irisRect = eyeRect.insetBy(dx: size * 0.18, dy: size * 0.16)
    NSColor(calibratedRed: 0.18, green: 0.70, blue: 0.42, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: irisRect).fill()

    let pupilRect = irisRect.insetBy(dx: size * 0.18, dy: size * 0.18)
    NSColor.black.setFill()
    NSBezierPath(ovalIn: pupilRect).fill()

    let highlightRect = NSRect(
        x: pupilRect.minX + pupilRect.width * 0.10,
        y: pupilRect.maxY - pupilRect.height * 0.28,
        width: pupilRect.width * 0.20,
        height: pupilRect.height * 0.20
    )
    NSColor.white.setFill()
    NSBezierPath(ovalIn: highlightRect).fill()

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw IconGenerationError(message: "无法生成 PNG 图标")
    }

    try data.write(to: url, options: .atomic)
}

guard CommandLine.arguments.count == 2 else {
    throw IconGenerationError(message: "用法: swift make-app-icon.swift <output-directory>")
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconsetDir = outputDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let fileManager = FileManager.default

try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
try? fileManager.removeItem(at: iconsetDir)
try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in iconSizes {
    let image = renderIcon(size: size)
    try writePNG(image, to: iconsetDir.appendingPathComponent(name))
}

print(iconsetDir.path)
