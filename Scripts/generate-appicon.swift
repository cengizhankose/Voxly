#!/usr/bin/env swift
// Generates the Voxly macOS app icon as an .appiconset (PNGs + Contents.json).
//
// Design source: brand mark in design/signal.html — rose (#E11D54) rounded
// square with a centered white "record" dot. Rendered on the macOS icon grid
// (rounded square inset within a transparent canvas), flat fill per the brand
// rule "no gradients".
//
// Usage: swift Scripts/generate-appicon.swift [output-appiconset-dir]
// Default output: Resources/Assets.xcassets/AppIcon.appiconset

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Brand rose #E11D54
let rose = (r: 0xE1 / 255.0, g: 0x1D / 255.0, b: 0x54 / 255.0)

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/Assets.xcassets/AppIcon.appiconset"

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func renderIcon(size: Int) -> CGImage {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high

    // macOS icon grid: rounded square inset within the canvas.
    let margin = s * 0.092
    let rect = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let inner = rect.width
    let corner = inner * 0.2237 // continuous-corner approximation

    // Soft contact shadow under the rounded square.
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -inner * 0.012),
        blur: inner * 0.04,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
    let body = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.addPath(body)
    ctx.setFillColor(red: rose.r, green: rose.g, blue: rose.b, alpha: 1)
    ctx.fillPath()
    ctx.restoreGState()

    // Centered white record dot (brand mark ratio ≈ 0.30 of the square).
    let dotD = inner * 0.30
    let dot = CGRect(
        x: rect.midX - dotD / 2, y: rect.midY - dotD / 2, width: dotD, height: dotD)
    ctx.addEllipse(in: dot)
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fillPath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// Distinct pixel sizes needed across the macOS app icon set.
let pixelSizes = [16, 32, 64, 128, 256, 512, 1024]
for px in pixelSizes {
    writePNG(renderIcon(size: px), to: "\(outDir)/icon_\(px).png")
    print("wrote icon_\(px).png")
}

// Asset catalog Contents.json (macOS idiom, 1x/2x pairs).
struct Img { let size: String; let scale: String; let file: String }
let images: [Img] = [
    Img(size: "16x16",   scale: "1x", file: "icon_16.png"),
    Img(size: "16x16",   scale: "2x", file: "icon_32.png"),
    Img(size: "32x32",   scale: "1x", file: "icon_32.png"),
    Img(size: "32x32",   scale: "2x", file: "icon_64.png"),
    Img(size: "128x128", scale: "1x", file: "icon_128.png"),
    Img(size: "128x128", scale: "2x", file: "icon_256.png"),
    Img(size: "256x256", scale: "1x", file: "icon_256.png"),
    Img(size: "256x256", scale: "2x", file: "icon_512.png"),
    Img(size: "512x512", scale: "1x", file: "icon_512.png"),
    Img(size: "512x512", scale: "2x", file: "icon_1024.png"),
]
let imageEntries = images.map {
    "    { \"size\" : \"\($0.size)\", \"idiom\" : \"mac\", \"filename\" : \"\($0.file)\", \"scale\" : \"\($0.scale)\" }"
}.joined(separator: ",\n")
let contents = """
{
  "images" : [
\(imageEntries)
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
"""
try! contents.write(toFile: "\(outDir)/Contents.json", atomically: true, encoding: .utf8)
print("wrote Contents.json -> \(outDir)")
