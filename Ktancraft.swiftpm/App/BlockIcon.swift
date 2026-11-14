//  BlockIcon.swift
//  Ktancraft
//  Ktan Labs
//
//  Turns the engine's raw RGBA block pixels into UIImages. This is the only
//  place where the procedural textures meet Core Graphics.

import UIKit

enum BlockIcon {
    private static var cache: [String: UIImage] = [:]

    static func image(for block: Block, face: TextureFace = .side) -> UIImage {
        let key = "\(block.rawValue)-\(faceKey(face))"
        if let cached = cache[key] { return cached }
        let image = makeImage(for: block, face: face) ?? fallback(block)
        cache[key] = image
        return image
    }

    private static func faceKey(_ face: TextureFace) -> Int {
        switch face {
        case .top: return 1
        case .side: return 0
        case .bottom: return 2
        }
    }

    private static func makeImage(for block: Block, face: TextureFace) -> UIImage? {
        let size = BlockTextures.size
        let source = BlockTextures.rgba(for: block, face: face)

        // CGBitmapContext wants premultiplied alpha and a bottom-left origin,
        // the engine produces straight RGBA from the top left.
        let byteCount = size * size * 4
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 4)
        defer { buffer.deallocate() }
        let out = buffer.bindMemory(to: UInt8.self, capacity: byteCount)

        for y in 0..<size {
            let sourceRow = (size - 1 - y) * size * 4
            let targetRow = y * size * 4
            for x in 0..<size {
                let s = sourceRow + x * 4
                let t = targetRow + x * 4
                let alpha = Float(source[s + 3]) / 255
                out[t + 0] = UInt8(Float(source[s + 0]) * alpha)
                out[t + 1] = UInt8(Float(source[s + 1]) * alpha)
                out[t + 2] = UInt8(Float(source[s + 2]) * alpha)
                out[t + 3] = source[s + 3]
            }
        }

        guard let context = CGContext(data: buffer,
                                      width: size,
                                      height: size,
                                      bitsPerComponent: 8,
                                      bytesPerRow: size * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func fallback(_ block: Block) -> UIImage {
        let color: UIColor
        switch block {
        case .grass: color = UIColor(red: 0.35, green: 0.62, blue: 0.27, alpha: 1)
        case .dirt: color = UIColor(red: 0.42, green: 0.30, blue: 0.20, alpha: 1)
        case .sand: color = UIColor(red: 0.86, green: 0.79, blue: 0.55, alpha: 1)
        case .log, .planks: color = UIColor(red: 0.48, green: 0.35, blue: 0.21, alpha: 1)
        case .leaves: color = UIColor(red: 0.24, green: 0.47, blue: 0.19, alpha: 1)
        case .water: color = UIColor(red: 0.16, green: 0.42, blue: 0.72, alpha: 1)
        case .glass: color = UIColor(red: 0.85, green: 0.93, blue: 0.98, alpha: 1)
        case .snow: color = UIColor(red: 0.94, green: 0.96, blue: 0.99, alpha: 1)
        default: color = UIColor(red: 0.5, green: 0.5, blue: 0.52, alpha: 1)
        }
        let size = CGSize(width: BlockTextures.size, height: BlockTextures.size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
