#!/usr/bin/env swift

import AppKit
import Foundation

let svgPath = "/Users/matejbaco/Desktop/Revisibility/icon.svg"
let outDir = "/Users/matejbaco/Desktop/Revisibility/Revisibility/Assets.xcassets/AppIcon.appiconset"
let sizes = [16, 32, 64, 128, 256, 512, 1024]

guard let svgData = FileManager.default.contents(atPath: svgPath) else {
    print("Cannot read SVG")
    exit(1)
}

guard let svgImage = NSImage(data: svgData) else {
    print("Failed to create image from SVG")
    exit(1)
}

for sz in sizes {
    // Create a bitmap rep at exact pixel dimensions (no Retina scaling)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: sz,
        pixelsHigh: sz,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: sz, height: sz)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    svgImage.draw(in: NSRect(x: 0, y: 0, width: sz, height: sz),
                  from: NSRect(origin: .zero, size: svgImage.size),
                  operation: .copy, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(sz)")
        continue
    }

    let outPath = "\(outDir)/icon_\(sz)x\(sz).png"
    try! png.write(to: URL(fileURLWithPath: outPath))
    print("Generated \(sz)x\(sz)")
}
print("Done!")
