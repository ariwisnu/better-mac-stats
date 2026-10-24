// Renders the 1024 px app icon master: a white gauge on a blue gradient squircle,
// sized to Apple's macOS icon grid (824 px body inside a 1024 px canvas).
//
//   swift Scripts/make-icon.swift out.png   (Scripts/make-icon.sh builds the .icns)
import AppKit

let size: CGFloat = 1024
let inset: CGFloat = 100
let body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Soft drop shadow under the body.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor(srgbRed: 0.12, green: 0.42, blue: 0.94, alpha: 1).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

// Top-light gradient body.
NSGradient(starting: NSColor(srgbRed: 0.36, green: 0.68, blue: 1.0, alpha: 1),
           ending: NSColor(srgbRed: 0.10, green: 0.38, blue: 0.90, alpha: 1))!
    .draw(in: shape, angle: -90)

// White gauge glyph, centered.
let config = NSImage.SymbolConfiguration(pointSize: 500, weight: .medium)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
let glyph = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                    accessibilityDescription: nil)!.withSymbolConfiguration(config)!
let g = glyph.size
glyph.draw(in: NSRect(x: (size - g.width) / 2, y: (size - g.height) / 2, width: g.width, height: g.height))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
