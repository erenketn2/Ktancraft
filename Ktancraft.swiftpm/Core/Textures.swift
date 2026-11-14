//  Textures.swift
//  Ktancraft — engine core
//  Ktan Labs
//
//  Every texture in Ktancraft is drawn here, pixel by pixel, on the device.
//  There is no image file in the project and no asset to prepare: that is what
//  lets the game install and run with nothing but the phone.

import Foundation

public enum TextureFace {
    case top
    case side
    case bottom
}

public enum BlockTextures {
    public static let size = 16

    /// A 16x16 RGBA8 image for one face of one block.
    public static func rgba(for block: Block, face: TextureFace) -> [UInt8] {
        var canvas = Canvas()
        switch block {
        case .air:
            break
        case .stone:
            canvas.fill(r: 0.50, g: 0.50, b: 0.52)
            canvas.noiseStrenght(0.055, salt: 11)
            canvas.speckles(count: 26, r: 0.40, g: 0.40, b: 0.43, salt: 12)
            canvas.speckles(count: 14, r: 0.60, g: 0.60, b: 0.62, salt: 13)
        case .dirt:
            canvas.fill(r: 0.42, g: 0.30, b: 0.20)
            canvas.noiseStrenght(0.07, salt: 21)
            canvas.speckles(count: 22, r: 0.32, g: 0.22, b: 0.14, salt: 22)
        case .grass:
            if face == .top {
                canvas.fill(r: 0.35, g: 0.62, b: 0.27)
                canvas.noiseStrenght(0.075, salt: 31)
                canvas.speckles(count: 30, r: 0.28, g: 0.53, b: 0.21, salt: 32)
            } else if face == .bottom {
                canvas.fill(r: 0.42, g: 0.30, b: 0.20)
                canvas.noiseStrenght(0.07, salt: 33)
            } else {
                canvas.fill(r: 0.42, g: 0.30, b: 0.20)
                canvas.noiseStrenght(0.07, salt: 34)
                // Ragged green lip along the top of the side face.
                for x in 0..<size {
                    let depth = 3 + Int(MathUtil.unit(Int64(x), 0, 0x6FB) * 2.99)
                    for y in 0..<depth {
                        let n = MathUtil.unit(Int64(x), Int64(y), 0x9A1) * 0.09 - 0.045
                        canvas.set(x, y, r: 0.35 + n, g: 0.62 + n, b: 0.27)
                    }
                }
            }
        case .sand:
            canvas.fill(r: 0.86, g: 0.79, b: 0.55)
            canvas.noiseStrenght(0.045, salt: 41)
            canvas.speckles(count: 20, r: 0.79, g: 0.72, b: 0.48, salt: 42)
        case .sandstone:
            canvas.fill(r: 0.84, g: 0.77, b: 0.53)
            canvas.noiseStrenght(0.03, salt: 51)
            if face != .top {
                for x in 0..<size {
                    let band = 0.03 * MathUtil.unit(Int64(x), 0, 0x13)
                    canvas.set(x, 4, r: 0.79 - band, g: 0.71 - band, b: 0.47)
                    canvas.set(x, 5, r: 0.79 - band, g: 0.71 - band, b: 0.47)
                    canvas.set(x, 11, r: 0.90, g: 0.84, b: 0.62)
                }
            }
        case .log:
            if face == .top || face == .bottom {
                canvas.fill(r: 0.62, g: 0.48, b: 0.28)
                let c: Float = 7.5
                for x in 0..<size {
                    for y in 0..<size {
                        let dx = Float(x) - c
                        let dy = Float(y) - c
                        let d = (dx * dx + dy * dy).squareRoot()
                        if Int(d.rounded()) % 3 == 0 {
                            canvas.set(x, y, r: 0.50, g: 0.37, b: 0.21)
                        }
                    }
                }
            } else {
                canvas.fill(r: 0.35, g: 0.25, b: 0.15)
                for x in 0..<size {
                    let streak = MathUtil.unit(Int64(x), 0, 0x77) * 0.10
                    for y in 0..<size {
                        let n = MathUtil.unit(Int64(x), Int64(y), 0x78) * 0.05
                        canvas.set(x, y, r: 0.33 + streak + n, g: 0.23 + streak + n, b: 0.14 + streak * 0.5)
                    }
                }
            }
        case .leaves:
            canvas.fill(r: 0.24, g: 0.47, b: 0.19)
            for x in 0..<size {
                for y in 0..<size {
                    let v = MathUtil.unit(Int64(x), Int64(y), 0x91)
                    if v > 0.82 {
                        canvas.set(x, y, r: 0.15, g: 0.31, b: 0.12)
                    } else if v < 0.18 {
                        canvas.set(x, y, r: 0.33, g: 0.58, b: 0.25)
                    } else {
                        let n = v * 0.10 - 0.05
                        canvas.set(x, y, r: 0.24 + n, g: 0.47 + n, b: 0.19 + n)
                    }
                }
            }
        case .planks:
            canvas.fill(r: 0.62, g: 0.47, b: 0.28)
            for x in 0..<size {
                for y in 0..<size {
                    let n = MathUtil.unit(Int64(x), Int64(y), 0xA2) * 0.06 - 0.03
                    canvas.set(x, y, r: 0.62 + n, g: 0.47 + n, b: 0.28 + n)
                }
            }
            for x in 0..<size {
                canvas.set(x, 3, r: 0.46, g: 0.34, b: 0.20)
                canvas.set(x, 7, r: 0.46, g: 0.34, b: 0.20)
                canvas.set(x, 11, r: 0.46, g: 0.34, b: 0.20)
                canvas.set(x, 15, r: 0.46, g: 0.34, b: 0.20)
            }
            for y in 0..<size {
                canvas.set(8, y, r: 0.50, g: 0.37, b: 0.22)
            }
        case .cobblestone:
            canvas.fill(r: 0.44, g: 0.44, b: 0.46)
            for x in 0..<size {
                for y in 0..<size {
                    let cellX = x / 4
                    let cellY = y / 4
                    let h = MathUtil.unit(Int64(cellX), Int64(cellY), 0xB3)
                    let shade = 0.34 + h * 0.26
                    let edge = (x % 4 == 0) || (y % 4 == 0)
                    let n = MathUtil.unit(Int64(x), Int64(y), 0xB4) * 0.05
                    if edge {
                        canvas.set(x, y, r: 0.28 + n, g: 0.28 + n, b: 0.30 + n)
                    } else {
                        canvas.set(x, y, r: shade + n, g: shade + n, b: shade + 0.02 + n)
                    }
                }
            }
        case .glass:
            canvas.fill(r: 0.80, g: 0.90, b: 0.95, a: 0.12)
            for i in 0..<size {
                canvas.set(i, 0, r: 0.92, g: 0.97, b: 1.0, a: 0.85)
                canvas.set(0, i, r: 0.92, g: 0.97, b: 1.0, a: 0.85)
                canvas.set(i, size - 1, r: 0.72, g: 0.82, b: 0.88, a: 0.85)
                canvas.set(size - 1, i, r: 0.72, g: 0.82, b: 0.88, a: 0.85)
            }
            for k in 0..<6 {
                canvas.set(k + 4, k + 4, r: 1.0, g: 1.0, b: 1.0, a: 0.55)
                canvas.set(k + 5, k + 4, r: 1.0, g: 1.0, b: 1.0, a: 0.35)
            }
        case .water:
            canvas.fill(r: 0.16, g: 0.42, b: 0.72, a: 0.78)
            for x in 0..<size {
                for y in 0..<size {
                    let wave = MathUtil.noiseSalt(x, y, 0xC5) * 0.06 - 0.03
                    canvas.set(x, y, r: 0.16 + wave, g: 0.42 + wave, b: 0.72 + wave, a: 0.78)
                }
            }
        case .snow:
            canvas.fill(r: 0.94, g: 0.96, b: 0.99)
            canvas.noiseStrenght(0.025, salt: 71)
            canvas.speckles(count: 12, r: 0.87, g: 0.91, b: 0.96, salt: 72)
        case .bedrock:
            canvas.fill(r: 0.22, g: 0.22, b: 0.24)
            for x in 0..<size {
                for y in 0..<size {
                    let v = MathUtil.unit(Int64(x), Int64(y), 0xD1)
                    let shade: Float = v > 0.72 ? 0.36 : (v < 0.3 ? 0.14 : 0.22)
                    canvas.set(x, y, r: shade, g: shade, b: shade + 0.02)
                }
            }
        }
        return canvas.pixels
    }
}

extension MathUtil {
    /// Cheap per-pixel "noise" that does not need the Perlin tables.
    public static func noiseSalt(_ x: Int, _ y: Int, _ salt: UInt64) -> Float {
        var h = salt &* 0x2545_F491_4F6C_DD1D
        h ^= UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15
        h = (h ^ (h >> 30)) &* 0xBF58_476D_1CE4_E5B9
        h ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2_AE3D_27D4_EB4F
        h = (h ^ (h >> 27)) &* 0x94D0_49BB_1331_11EB
        h ^= h >> 31
        return Float(h >> 40) / Float(1 << 24)
    }
}

/// Straight RGBA8 pixel buffer with the little helpers the block textures use.
struct Canvas {
    let n = BlockTextures.size
    var pixels: [UInt8]

    init() {
        pixels = [UInt8](repeating: 0, count: BlockTextures.size * BlockTextures.size * 4)
    }

    mutating func set(_ x: Int, _ y: Int, r: Float, g: Float, b: Float, a: Float = 1) {
        guard x >= 0, y >= 0, x < n, y < n else { return }
        let i = (y * n + x) * 4
        pixels[i + 0] = UInt8(MathUtil.clamp(r, 0, 1) * 255)
        pixels[i + 1] = UInt8(MathUtil.clamp(g, 0, 1) * 255)
        pixels[i + 2] = UInt8(MathUtil.clamp(b, 0, 1) * 255)
        pixels[i + 3] = UInt8(MathUtil.clamp(a, 0, 1) * 255)
    }

    mutating func fill(r: Float, g: Float, b: Float, a: Float = 1) {
        for y in 0..<n {
            for x in 0..<n {
                set(x, y, r: r, g: g, b: b, a: a)
            }
        }
    }

    mutating func noiseStrenght(_ amount: Float, salt: UInt64) {
        for y in 0..<n {
            for x in 0..<n {
                let i = (y * n + x) * 4
                let s = (MathUtil.noiseSalt(x, y, salt) - 0.5) * 2 * amount
                for c in 0..<3 {
                    pixels[i + c] = UInt8(MathUtil.clamp(Float(pixels[i + c]) / 255 + s, 0, 1) * 255)
                }
            }
        }
    }

    mutating func speckles(count: Int, r: Float, g: Float, b: Float, salt: UInt64) {
        for k in 0..<count {
            let x = Int(MathUtil.noiseSalt(k, 0, salt) * Float(n)) % n
            let y = Int(MathUtil.noiseSalt(k, 1, salt) * Float(n)) % n
            set(x, y, r: r, g: g, b: b)
        }
    }
}
