//  Mesher.swift
//  Ktancraft — engine core
//  Ktan Labs
//
//  Greedy meshing: faces of the same block that touch are merged into one
//  rectangle, so a flat field of grass becomes a handful of quads instead of
//  thousands. That is what keeps SceneKit comfortable on a phone.

import Foundation

public struct MeshBuffers {
    public var positions: [Float] = []
    public var normals: [Float] = []
    public var uvs: [Float] = []
    public var indices: [UInt32] = []

    public init() {}

    public var isEmpty: Bool { indices.isEmpty }
    public var vertexCount: Int { positions.count / 3 }
}

/// A vertex buffer key: one material per block, split into top, side and bottom
/// only for the blocks whose faces really differ.
public enum MeshKey {
    public static func encode(_ block: Block, face: TextureFace) -> UInt8 {
        guard block.hasDistinctFaces else { return block.rawValue }
        let bits: UInt8 = face == .top ? 1 : (face == .bottom ? 2 : 0)
        return block.rawValue | (bits << 4)
    }

    public static func decode(_ key: UInt8) -> (block: Block, face: TextureFace) {
        let raw = key & 0x0F
        let bits = key >> 4
        let face: TextureFace = bits == 1 ? .top : (bits == 2 ? .bottom : .side)
        return (Block(rawValue: raw) ?? .air, face)
    }
}

public enum Mesher {
    /// Builds one buffer per block type present in the chunk's visible surface.
    /// Coordinates are kept in scalars: allocating a small array per block made
    /// this several times slower.
    public static func build(chunk: Chunk, world: BlockSource, originX: Int, originZ: Int) -> [UInt8: MeshBuffers] {
        let dimsX = chunkSizeX
        let dimsY = worldHeight
        let dimsZ = chunkSizeZ
        var output: [UInt8: MeshBuffers] = [:]

        // The highest block in this chunk: no faces above it, so no slices.
        var maxY = 0
        var scan = chunk.blocks.count - 1
        while scan >= 0 {
            if chunk.blocks[scan] != Block.air.rawValue {
                maxY = scan / (dimsX * dimsZ)
                break
            }
            scan -= 1
        }

        @inline(__always)
        func blockAtLocal(_ x: Int, _ y: Int, _ z: Int) -> Block {
            if y < 0 { return .bedrock }        // nothing to see under the world
            if y >= dimsY { return .air }
            if x >= 0 && x < dimsX && z >= 0 && z < dimsZ {
                return chunk.get(x, y, z)
            }
            return world.blockAt(originX + x, y, originZ + z)
        }

        for axis in 0..<3 {
            let u = (axis + 1) % 3
            let v = (axis + 2) % 3
            // Slices and rows above the chunk's highest block are all air, so
            // they never produce a face and are never scanned.
            var du = u == 0 ? dimsX : (u == 1 ? dimsY : dimsZ)
            var dv = v == 0 ? dimsX : (v == 1 ? dimsY : dimsZ)
            var dk = axis == 0 ? dimsX : (axis == 1 ? dimsY : dimsZ)
            if u == 1 { du = maxY + 1 }
            if v == 1 { dv = maxY + 1 }
            if axis == 1 { dk = maxY + 1 }

            for sign in [1, -1] {
                var mask = [Int16](repeating: -1, count: du * dv)

                for k in 0..<dk {
                    for j in 0..<dv {
                        for i in 0..<du {
                            // Local coordinates from the (axis, u, v) triple.
                            var x = 0
                            var y = 0
                            var z = 0
                            switch axis {
                            case 0:
                                x = k; y = i; z = j
                            case 1:
                                y = k; z = i; x = j
                            default:
                                z = k; x = i; y = j
                            }
                            let here = blockAtLocal(x, y, z)
                            if here == .air {
                                mask[j * du + i] = -1
                                continue
                            }
                            let nx = x + (axis == 0 ? sign : 0)
                            let ny = y + (axis == 1 ? sign : 0)
                            let nz = z + (axis == 2 ? sign : 0)
                            if blockAtLocal(nx, ny, nz).hidesFaceOf(here) {
                                mask[j * du + i] = -1
                            } else {
                                mask[j * du + i] = Int16(here.rawValue)
                            }
                        }
                    }

                    // Merge the mask into rectangles.
                    for j in 0..<dv {
                        var i = 0
                        while i < du {
                            let value = mask[j * du + i]
                            if value < 0 {
                                i += 1
                                continue
                            }
                            var width = 1
                            while i + width < du && mask[j * du + i + width] == value {
                                width += 1
                            }
                            var height = 1
                            var growing = true
                            while growing && j + height < dv {
                                for t in 0..<width where mask[(j + height) * du + i + t] != value {
                                    growing = false
                                    break
                                }
                                if growing { height += 1 }
                            }
                            for jj in j..<(j + height) {
                                for ii in i..<(i + width) {
                                    mask[jj * du + ii] = -1
                                }
                            }
                            if let rawValue = UInt8(exactly: value), let blockType = Block(rawValue: rawValue) {
                                let face: TextureFace = axis == 1 ? (sign > 0 ? .top : .bottom) : .side
                                emit(into: &output, key: MeshKey.encode(blockType, face: face), axis: axis,
                                     k: k, sign: sign, i0: i, j0: j, width: width, height: height)
                            }
                            i += width
                        }
                    }
                }
            }
        }
        return output
    }

    private static func emit(into output: inout [UInt8: MeshBuffers],
                             key: UInt8, axis: Int,
                             k: Int, sign: Int, i0: Int, j0: Int,
                             width: Int, height: Int) {
        let plane = Float(k) + (sign > 0 ? 1 : 0)
        let w = Float(width)
        let h = Float(height)
        let fi = Float(i0)
        let fj = Float(j0)
        let zero: Float = 0

        // Corners in (u, v) space, counter clockwise seen from the face side.
        var corners: [(Float, Float)] = [
            (fi, fj),
            (fi + w, fj),
            (fi + w, fj + h),
            (fi, fj + h)
        ]
        if sign < 0 { corners.reverse() }

        // Side faces along X keep the vertical axis in `u`, so the texture
        // coordinates are flipped to leave grass lips and planks upright.
        let uvCorners: [(Float, Float)] = axis == 0
            ? [(zero, zero), (zero, w), (h, w), (h, zero)]
            : [(zero, zero), (w, zero), (w, h), (zero, h)]

        var buffers = output[key] ?? MeshBuffers()
        let base = UInt32(buffers.vertexCount)

        for (index, corner) in corners.enumerated() {
            let cu = corner.0
            let cv = corner.1
            var px: Float = 0
            var py: Float = 0
            var pz: Float = 0
            switch axis {
            case 0:
                px = plane; py = cu; pz = cv
            case 1:
                py = plane; pz = cu; px = cv
            default:
                pz = plane; px = cu; py = cv
            }
            buffers.positions.append(px)
            buffers.positions.append(py)
            buffers.positions.append(pz)
            buffers.normals.append(axis == 0 ? Float(sign) : 0)
            buffers.normals.append(axis == 1 ? Float(sign) : 0)
            buffers.normals.append(axis == 2 ? Float(sign) : 0)
            buffers.uvs.append(uvCorners[index].0)
            buffers.uvs.append(uvCorners[index].1)
        }

        buffers.indices.append(base + 0)
        buffers.indices.append(base + 1)
        buffers.indices.append(base + 2)
        buffers.indices.append(base + 0)
        buffers.indices.append(base + 2)
        buffers.indices.append(base + 3)

        output[key] = buffers
    }
}
