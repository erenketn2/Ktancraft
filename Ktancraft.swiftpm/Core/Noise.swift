//  Noise.swift
//  Ktancraft — engine core
//  Ktan Labs

import Foundation

/// Classic Perlin noise with a SplitMix64 seeded permutation table.
/// Deterministic across platforms, which is what lets a seed give the same
/// world on every iPhone and in the test harness.
public struct Noise {
    private var perm = [Int](repeating: 0, count: 512)

    public init(seed: UInt64) {
        var state = seed &+ 0x9E37_79B9_7F4A_7C15
        var table = [Int](0..<256)
        // SplitMix64 shuffle: no Foundation randomness, so it repeats exactly.
        var i = 255
        while i > 0 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z = z ^ (z >> 31)
            let j = Int(z % UInt64(i + 1))
            table.swapAt(i, j)
            i -= 1
        }
        for k in 0..<512 {
            perm[k] = table[k & 255]
        }
    }

    private static func fade(_ t: Float) -> Float {
        t * t * t * (t * (t * 6 - 15) + 10)
    }

    private static func grad2(_ hash: Int, _ x: Float, _ y: Float) -> Float {
        switch hash & 7 {
        case 0: return x + y
        case 1: return -x + y
        case 2: return x - y
        case 3: return -x - y
        case 4: return x
        case 5: return -x
        case 6: return y
        default: return -y
        }
    }

    private static func grad3(_ hash: Int, _ x: Float, _ y: Float, _ z: Float) -> Float {
        switch hash & 15 {
        case 0: return x + y
        case 1: return -x + y
        case 2: return x - y
        case 3: return -x - y
        case 4: return x + z
        case 5: return -x + z
        case 6: return x - z
        case 7: return -x - z
        case 8: return y + z
        case 9: return -y + z
        case 10: return y - z
        case 11: return -y - z
        case 12: return x + y
        case 13: return -y + z
        case 14: return -x + y
        default: return -y - z
        }
    }

    /// 2D Perlin noise in -1...1.
    public func noise2(_ x: Float, _ y: Float) -> Float {
        let xi = Int(floor(x)) & 255
        let yi = Int(floor(y)) & 255
        let xf = x - floor(x)
        let yf = y - floor(y)
        let u = Noise.fade(xf)
        let v = Noise.fade(yf)

        let aa = perm[perm[xi] + yi]
        let ab = perm[perm[xi] + yi + 1]
        let ba = perm[perm[xi + 1] + yi]
        let bb = perm[perm[xi + 1] + yi + 1]

        let x1 = MathUtil.lerp(Noise.grad2(aa, xf, yf), Noise.grad2(ba, xf - 1, yf), u)
        let x2 = MathUtil.lerp(Noise.grad2(ab, xf, yf - 1), Noise.grad2(bb, xf - 1, yf - 1), u)
        return MathUtil.lerp(x1, x2, v)
    }

    /// 3D Perlin noise in -1...1.
    public func noise3(_ x: Float, _ y: Float, _ z: Float) -> Float {
        let xi = Int(floor(x)) & 255
        let yi = Int(floor(y)) & 255
        let zi = Int(floor(z)) & 255
        let xf = x - floor(x)
        let yf = y - floor(y)
        let zf = z - floor(z)
        let u = Noise.fade(xf)
        let v = Noise.fade(yf)
        let w = Noise.fade(zf)

        let a = perm[xi] + yi
        let aa = perm[a] + zi
        let ab = perm[a + 1] + zi
        let b = perm[xi + 1] + yi
        let ba = perm[b] + zi
        let bb = perm[b + 1] + zi

        let x1 = MathUtil.lerp(Noise.grad3(perm[aa], xf, yf, zf),
                               Noise.grad3(perm[ba], xf - 1, yf, zf), u)
        let x2 = MathUtil.lerp(Noise.grad3(perm[ab], xf, yf - 1, zf),
                               Noise.grad3(perm[bb], xf - 1, yf - 1, zf), u)
        let y1 = MathUtil.lerp(x1, x2, v)

        let x3 = MathUtil.lerp(Noise.grad3(perm[aa + 1], xf, yf, zf - 1),
                               Noise.grad3(perm[ba + 1], xf - 1, yf, zf - 1), u)
        let x4 = MathUtil.lerp(Noise.grad3(perm[ab + 1], xf, yf - 1, zf - 1),
                               Noise.grad3(perm[bb + 1], xf - 1, yf - 1, zf - 1), u)
        let y2 = MathUtil.lerp(x3, x4, v)

        return MathUtil.lerp(y1, y2, w)
    }

    /// Fractal Brownian motion over 2D Perlin noise.
    public func fbm2(_ x: Float, _ y: Float, octaves: Int, lacunarity: Float = 2, gain: Float = 0.5) -> Float {
        var amplitude: Float = 1
        var frequency: Float = 1
        var sum: Float = 0
        var norm: Float = 0
        for _ in 0..<octaves {
            sum += noise2(x * frequency, y * frequency) * amplitude
            norm += amplitude
            amplitude *= gain
            frequency *= lacunarity
        }
        return norm > 0 ? sum / norm : 0
    }
}
