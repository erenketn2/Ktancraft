//  World.swift
//  Ktancraft — engine core
//  Ktan Labs

import Foundation

/// The live world: loaded chunks, the generator and the player's edits.
public final class KtancraftWorld: BlockSource {
    public let seed: UInt64
    public let generator: WorldGenerator
    public private(set) var chunks: [Int64: Chunk] = [:]

    /// Player changes, kept per chunk so they can be written to the save file
    /// and replayed on top of the generated terrain.
    public private(set) var edits: [Int64: [Int32: UInt8]] = [:]

    public init(seed: UInt64) {
        self.seed = seed
        self.generator = WorldGenerator(seed: seed)
    }

    public func chunkIfLoaded(_ cx: Int32, _ cz: Int32) -> Chunk? {
        chunks[chunkKey(cx, cz)]
    }

    @discardableResult
    public func loadChunk(_ cx: Int32, _ cz: Int32) -> Chunk {
        let key = chunkKey(cx, cz)
        if let existing = chunks[key] { return existing }

        let chunk = Chunk(cx: cx, cz: cz)
        generator.generate(chunk)
        if let saved = edits[key] {
            for (index, raw) in saved {
                if index >= 0 && Int(index) < chunk.blocks.count {
                    chunk.blocks[Int(index)] = raw
                }
            }
        }
        chunk.needsRemesh = true
        chunks[key] = chunk
        return chunk
    }

    public func unloadChunk(_ cx: Int32, _ cz: Int32) {
        chunks.removeValue(forKey: chunkKey(cx, cz))
    }

    public func blockAt(_ x: Int, _ y: Int, _ z: Int) -> Block {
        guard y >= 0 else { return .bedrock }
        guard y < worldHeight else { return .air }
        let cx = chunkCoord(x)
        let cz = chunkCoord(z)
        guard let chunk = chunks[chunkKey(cx, cz)] else { return .air }
        let lx = x - Int(cx) * chunkSizeX
        let lz = z - Int(cz) * chunkSizeZ
        return chunk.get(lx, y, lz)
    }

    /// Writes a block and records the edit. Returns true if anything changed.
    @discardableResult
    public func setBlock(_ block: Block, x: Int, y: Int, z: Int, record: Bool = true) -> Bool {
        guard y >= 0, y < worldHeight else { return false }
        let cx = chunkCoord(x)
        let cz = chunkCoord(z)
        let key = chunkKey(cx, cz)
        guard let chunk = chunks[key] else { return false }
        let lx = x - Int(cx) * chunkSizeX
        let lz = z - Int(cz) * chunkSizeZ
        guard chunk.get(lx, y, lz) != block else { return false }

        chunk.set(lx, y, lz, block)
        chunk.needsRemesh = true

        if record {
            edits[key, default: [:]][Int32(Chunk.index(lx, y, lz))] = block.rawValue
        }

        // A block on a chunk border changes the neighbour's mesh too.
        if lx == 0, let n = chunkIfLoaded(cx - 1, cz) { n.needsRemesh = true }
        if lx == chunkSizeX - 1, let n = chunkIfLoaded(cx + 1, cz) { n.needsRemesh = true }
        if lz == 0, let n = chunkIfLoaded(cx, cz - 1) { n.needsRemesh = true }
        if lz == chunkSizeZ - 1, let n = chunkIfLoaded(cx, cz + 1) { n.needsRemesh = true }
        return true
    }

    /// Highest solid block at a column, or sea level + 1 when empty.
    public func spawnHeight(atX x: Int, z: Int) -> Int {
        for y in stride(from: worldHeight - 1, through: 0, by: -1) {
            let block = blockAt(x, y, z)
            if block.isSolid { return y + 1 }
        }
        return seaLevel + 1
    }

    public func replaceEdits(_ newEdits: [Int64: [Int32: UInt8]]) {
        edits = newEdits
        for (key, saved) in newEdits {
            guard let chunk = chunks[key] else { continue }
            for (index, raw) in saved where index >= 0 && Int(index) < chunk.blocks.count {
                chunk.blocks[Int(index)] = raw
            }
            chunk.needsRemesh = true
        }
    }
}
