//  Chunk.swift
//  Ktancraft — engine core
//  Ktan Labs

import Foundation

public let chunkSizeX = 16
public let chunkSizeZ = 16
public let worldHeight = 96
public let seaLevel = 40

/// A 16 x 96 x 16 column of blocks.
public final class Chunk {
    public let cx: Int32
    public let cz: Int32
    public var blocks: [UInt8]

    /// Set when the block data changed and the mesh has to be rebuilt.
    public var needsRemesh = true
    /// Set when the mesh exists, so the renderer knows what to show.
    public var hasMesh = false

    public init(cx: Int32, cz: Int32) {
        self.cx = cx
        self.cz = cz
        self.blocks = [UInt8](repeating: Block.air.rawValue,
                              count: chunkSizeX * chunkSizeZ * worldHeight)
    }

    @inline(__always)
    public static func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
        (y * chunkSizeZ + z) * chunkSizeX + x
    }

    @inline(__always)
    public func get(_ x: Int, _ y: Int, _ z: Int) -> Block {
        guard x >= 0, z >= 0, x < chunkSizeX, z < chunkSizeZ, y >= 0, y < worldHeight else { return .air }
        return Block(rawValue: blocks[Chunk.index(x, y, z)]) ?? .air
    }

    @inline(__always)
    public func set(_ x: Int, _ y: Int, _ z: Int, _ block: Block) {
        guard x >= 0, z >= 0, x < chunkSizeX, z < chunkSizeZ, y >= 0, y < worldHeight else { return }
        blocks[Chunk.index(x, y, z)] = block.rawValue
    }

    /// Y of the highest block that is not air, used to spawn the player and to
    /// place trees. Returns 0 for an empty column.
    public func heightAt(_ x: Int, _ z: Int) -> Int {
        guard x >= 0, z >= 0, x < chunkSizeX, z < chunkSizeZ else { return 0 }
        var y = worldHeight - 1
        while y >= 0 {
            if blocks[Chunk.index(x, y, z)] != Block.air.rawValue { return y }
            y -= 1
        }
        return 0
    }
}

/// World block coordinate to chunk coordinate, rounded towards minus infinity
/// so negative coordinates land in the chunk that contains them.
@inline(__always)
public func chunkCoord(_ value: Int) -> Int32 {
    Int32((value >= 0 ? value : value - chunkSizeX + 1) / chunkSizeX)
}

/// Chunk coordinates packed into one hashable key.
@inline(__always)
public func chunkKey(_ cx: Int32, _ cz: Int32) -> Int64 {
    (Int64(cx) << 32) | (Int64(cz) & 0xFFFF_FFFF)
}

@inline(__always)
public func chunkCoordX(_ key: Int64) -> Int32 { Int32(truncatingIfNeeded: key >> 32) }
@inline(__always)
public func chunkCoordZ(_ key: Int64) -> Int32 { Int32(truncatingIfNeeded: key) }

/// Reads blocks by world coordinate. The mesher, the physics and the ray caster
/// all talk to the world through this.
public protocol BlockSource: AnyObject {
    func blockAt(_ x: Int, _ y: Int, _ z: Int) -> Block
}
