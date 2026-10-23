import AppKit
import CoreText
import Foundation

private let ink = NSColor(srgbRed: 36.0 / 255, green: 38.0 / 255, blue: 45.0 / 255, alpha: 1)
private let paper = NSColor(srgbRed: 1, green: 253.0 / 255, blue: 250.0 / 255, alpha: 1)
private let terracotta = NSColor(srgbRed: 36.0 / 255, green: 89.0 / 255, blue: 211.0 / 255, alpha: 1)

private func makeBitmap(width: Int, height: Int, draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true
    context.cgContext.setAllowsAntialiasing(true)
    context.cgContext.setShouldAntialias(true)
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

private func drawCentered(_ text: String, fontSize: CGFloat, baseline: CGFloat, in rect: CGRect, color: NSColor, context: CGContext) {
    let font = CTFontCreateWithName("BrushScriptMT" as CFString, fontSize, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    context.saveGState()
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: rect.midX - width / 2, y: baseline)
    CTLineDraw(line, context)
    context.restoreGState()
}

private func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    let data = bitmap.representation(using: .png, properties: [.compressionFactor: 1])!
    try data.write(to: url, options: .atomic)
}

let projectRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assetFolder = projectRoot.appendingPathComponent("Assets", isDirectory: true)
try FileManager.default.createDirectory(at: assetFolder, withIntermediateDirectories: true)

let wordmark = makeBitmap(width: 2400, height: 560) { context in
    context.clear(CGRect(x: 0, y: 0, width: 2400, height: 560))
    drawCentered("PDF FREE FOR ALL", fontSize: 220, baseline: 188, in: CGRect(x: 40, y: 60, width: 2320, height: 440), color: ink, context: context)

    let stroke = NSBezierPath()
    stroke.lineWidth = 9
    stroke.lineCapStyle = .round
    stroke.lineJoinStyle = .round
    stroke.move(to: NSPoint(x: 775, y: 119))
    stroke.curve(to: NSPoint(x: 1640, y: 121), controlPoint1: NSPoint(x: 1015, y: 72), controlPoint2: NSPoint(x: 1390, y: 168))
    terracotta.setStroke()
    stroke.stroke()
}
try writePNG(wordmark, to: assetFolder.appendingPathComponent("FreePdforall-Wordmark.png"))

let appIcon = makeBitmap(width: 1024, height: 1024) { context in
    context.clear(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let tile = NSBezierPath(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896), xRadius: 196, yRadius: 196)
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 60.0 / 255, green: 122.0 / 255, blue: 247.0 / 255, alpha: 1),
        ending: NSColor(srgbRed: 25.0 / 255, green: 61.0 / 255, blue: 177.0 / 255, alpha: 1)
    )!
    gradient.draw(in: tile, angle: -65)
    // A quiet folded-corner detail ties the wordmark to documents.
    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 765, y: 895))
    fold.line(to: NSPoint(x: 896, y: 764))
    fold.line(to: NSPoint(x: 765, y: 764))
    fold.close()
    NSColor.white.withAlphaComponent(0.16).setFill()
    fold.fill()
    let area = CGRect(x: 135, y: 200, width: 754, height: 600)
    drawCentered("PDF", fontSize: 300, baseline: 478, in: area, color: .white, context: context)
    drawCentered("FREE FOR ALL", fontSize: 108, baseline: 314, in: area, color: .white, context: context)
    let flourish = NSBezierPath()
    flourish.lineWidth = 11
    flourish.lineCapStyle = .round
    flourish.move(to: NSPoint(x: 270, y: 247))
    flourish.curve(to: NSPoint(x: 754, y: 251), controlPoint1: NSPoint(x: 420, y: 212), controlPoint2: NSPoint(x: 600, y: 283))
    NSColor.white.withAlphaComponent(0.72).setStroke()
    flourish.stroke()
}
try writePNG(appIcon, to: assetFolder.appendingPathComponent("FreePdforall-AppIcon-1024.png"))

let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="2400" height="560" viewBox="0 0 2400 560">
  <title>PDF FREE FOR ALL</title>
  <text x="1200" y="372" text-anchor="middle" fill="#24262D" font-family="Brush Script MT, Apple Chancery, cursive" font-size="220">PDF FREE FOR ALL</text>
  <path d="M775 441 C1015 488 1390 392 1640 439" fill="none" stroke="#2459D3" stroke-width="9" stroke-linecap="round"/>
</svg>
"""
try svg.write(to: assetFolder.appendingPathComponent("FreePdforall-Wordmark.svg"), atomically: true, encoding: .utf8)

print("Wrote the wordmark and 1024 px app icon to \(assetFolder.path)")
