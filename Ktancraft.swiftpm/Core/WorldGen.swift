//  WorldGen.swift
//  Ktancraft — engine core
//  Ktan Labs
//
//  Terrain: continental noise for coastlines, a hill layer, ridged mountains,
//  interpolated 3D caves, beaches, snow caps and trees. Everything is a pure
//  function of the seed, so the same seed is the same world on every device.

import Foundation

public struct WorldGenerator {
    public let seed: UInt64

    private let continent: Noise
    private let hills: Noise
    private let ridgeNoise: Noise
    private let detail: Noise
    private let caveA: Noise
    private let caveB: Noise
    private let forest: Noise

    public init(seed: UInt64) {
        self.seed = seed
        continent = Noise(seed: seed &+ 1)
        hills = Noise(seed: seed &+ 2)
        ridgeNoise = Noise(seed: seed &+ 3)
        detail = Noise(seed: seed &+ 4)
        caveA = Noise(seed: seed &+ 5)
        caveB = Noise(seed: seed &+ 6)
        forest = Noise(seed: seed &+ 7)
    }

    /// Surface height of a world column. 2 ... worldHeight - 12.
    public func surfaceHeight(_ wx: Int, _ wz: Int) -> Int {
        let fx = Float(wx)
        let fz = Float(wz)
        let base = Float(seaLevel) + 3
            + continent.fbm2(fx * 0.0035, fz * 0.0035, octaves: 4) * 17
            + hills.fbm2(fx * 0.014, fz * 0.014, octaves: 4) * 8
            + detail.fbm2(fx * 0.06, fz * 0.06, octaves: 2) * 2

        let ridge = 1 - abs(ridgeNoise.fbm2(fx * 0.007 + 40, fz * 0.007 + 40, octaves: 3))
        var h = base + pow(ridge, 6) * 24
        if h < 2 { h = 2 }
        let highest = Float(worldHeight - 13)
        if h > highest { h = highest }
        return Int(h.rounded())
    }

    /// Fills one chunk with generated terrain.
    public func generate(_ chunk: Chunk) {
        // Cave field on a coarse lattice, trilinearly interpolated per block.
        // Sampling Perlin per block would cost four times as much for no
        // visible difference at this scale.
        let gx = chunkSizeX / 4 + 1
        let gz = chunkSizeZ / 4 + 1
        let gy = worldHeight / 4 + 1
        var caveFieldA = [Float](repeating: 0, count: gx * gy * gz)
        var caveFieldB = [Float](repeating: 0, count: gx * gy * gz)
        let originX = Int(chunk.cx) * chunkSizeX
        let originZ = Int(chunk.cz) * chunkSizeZ

        for iy in 0..<gy {
            for iz in 0..<gz {
                for ix in 0..<gx {
                    let wx = Float(originX + ix * 4) * 0.045
                    let wy = Float(iy * 4) * 0.062
                    let wz = Float(originZ + iz * 4) * 0.045
                    let idx = (iy * gz + iz) * gx + ix
                    caveFieldA[idx] = caveA.noise3(wx, wy, wz)
                    caveFieldB[idx] = caveB.noise3(wx + 17, wy + 3, wz + 29)
                }
            }
        }

        func caveSample(_ x: Int, _ y: Int, _ z: Int) -> (Float, Float) {
            let fx = Float(x) / 4
            let fy = Float(y) / 4
            let fz = Float(z) / 4
            let ix = min(Int(fx), gx - 2)
            let iy = min(Int(fy), gy - 2)
            let iz = min(Int(fz), gz - 2)
            let tx = fx - Float(ix)
            let ty = fy - Float(iy)
            let tz = fz - Float(iz)

            @inline(__always)
            func value(_ field: [Float]) -> Float {
                let c000 = field[(iy * gz + iz) * gx + ix]
                let c100 = field[(iy * gz + iz) * gx + ix + 1]
                let c010 = field[((iy + 1) * gz + iz) * gx + ix]
                let c110 = field[((iy + 1) * gz + iz) * gx + ix + 1]
                let c001 = field[(iy * gz + iz + 1) * gx + ix]
                let c101 = field[(iy * gz + iz + 1) * gx + ix + 1]
                let c011 = field[((iy + 1) * gz + iz + 1) * gx + ix]
                let c111 = field[((iy + 1) * gz + iz + 1) * gx + ix + 1]
                let x00 = MathUtil.lerp(c000, c100, tx)
                let x10 = MathUtil.lerp(c010, c110, tx)
                let x01 = MathUtil.lerp(c001, c101, tx)
                let x11 = MathUtil.lerp(c011, c111, tx)
                return MathUtil.lerp(MathUtil.lerp(x00, x10, ty), MathUtil.lerp(x01, x11, ty), tz)
            }
            return (value(caveFieldA), value(caveFieldB))
        }

        for x in 0..<chunkSizeX {
            let wx = originX + x
            for z in 0..<chunkSizeZ {
                let wz = originZ + z
                let height = surfaceHeight(wx, wz)
                let temperature = forest.fbm2(Float(wx) * 0.004, Float(wz) * 0.004, octaves: 3)

                let top: Block
                let filler: Block
                if height <= seaLevel + 1 {
                    top = .sand
                    filler = .sand
                } else if height > 66 {
                    top = .snow
                    filler = .stone
                } else {
                    top = .grass
                    filler = .dirt
                }

                for y in 0...max(height, seaLevel) {
                    var block: Block = .air
                    if y == 0 {
                        block = .bedrock
                    } else if y <= height {
                        if y == height {
                            block = top
                        } else if y > height - 4 {
                            block = filler
                        } else {
                            block = .stone
                        }
                        // Caves: where both noise sheets cross zero, a tunnel
                        // opens. Kept above the bedrock and below the surface.
                        if y > 1 && y < height - 1 && height > seaLevel {
                            let (a, b) = caveSample(x, y, z)
                            if abs(a) < 0.075 && abs(b) < 0.075 {
                                block = .air
                            }
                        }
                    } else if y <= seaLevel {
                        block = .water
                    }
                    if block != .air {
                        chunk.set(x, y, z, block)
                    }
                }

                // Trees, deterministic per column and kept away from the chunk
                // border so a canopy is never cut in half.
                if top == .grass, x >= 3, x <= chunkSizeX - 4, z >= 3, z <= chunkSizeZ - 4 {
                    let roll = MathUtil.unit(Int64(wx), Int64(wz), seed &+ 0x5EED)
                    let density: Float = temperature > 0.1 ? 0.012 : 0.004
                    if roll < density {
                        placeTree(chunk, x: x, groundY: height, z: z, seed: seed)
                    }
                }
            }
        }
    }

    private func placeTree(_ chunk: Chunk, x: Int, groundY: Int, z: Int, seed: UInt64) {
        let trunk = 4 + Int(MathUtil.unit(Int64(x), Int64(z), seed &+ 0x7A1) * 2.99)
        let topY = groundY + trunk
        guard topY + 2 < worldHeight else { return }

        for y in (groundY + 1)...topY {
            chunk.set(x, y, z, .log)
        }
        // Leaf blob: two wide layers then a cross.
        for dy in 0...2 {
            let y = topY - 1 + dy
            let radius = dy == 0 ? 2 : (dy == 1 ? 1 : 1)
            for dx in -radius...radius {
                for dz in -radius...radius {
                    if dy == 2 && abs(dx) + abs(dz) > 1 { continue }
                    if abs(dx) == radius && abs(dz) == radius && radius > 1 { continue }
                    let lx = x + dx
                    let lz = z + dz
                    guard lx >= 0, lz >= 0, lx < chunkSizeX, lz < chunkSizeZ else { continue }
                    if chunk.get(lx, y, lz) == .air {
                        chunk.set(lx, y, lz, .leaves)
                    }
                }
            }
        }
        if chunk.get(x, topY + 2, z) == .air {
            chunk.set(x, topY + 2, z, .leaves)
        }
    }
}
