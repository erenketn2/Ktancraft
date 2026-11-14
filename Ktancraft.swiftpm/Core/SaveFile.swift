//  SaveFile.swift
//  Ktancraft — engine core
//  Ktan Labs
//
//  A world is saved as the seed plus the player's edits. Regenerating terrain is
//  cheap, so a save stays tiny however far you build.

import Foundation

public struct SavedEdit: Codable {
    public var x: Int32
    public var y: Int32
    public var z: Int32
    public var b: UInt8

    public init(x: Int32, y: Int32, z: Int32, b: UInt8) {
        self.x = x
        self.y = y
        self.z = z
        self.b = b
    }
}

public struct SaveFile: Codable {
    public static let currentVersion = 1

    public var version: Int
    public var seed: UInt64
    public var name: String
    public var savedAt: Double
    public var player: Player
    public var inventory: Inventory
    public var edits: [SavedEdit]

    public init(seed: UInt64, name: String, player: Player, inventory: Inventory, edits: [SavedEdit]) {
        self.version = SaveFile.currentVersion
        self.seed = seed
        self.name = name
        self.savedAt = Date().timeIntervalSince1970
        self.player = player
        self.inventory = inventory
        self.edits = edits
    }

    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try? encoder.encode(self)
    }

    public static func decode(_ data: Data) -> SaveFile? {
        guard let file = try? JSONDecoder().decode(SaveFile.self, from: data) else { return nil }
        guard file.version <= SaveFile.currentVersion else { return nil }
        return file
    }

    /// Turns the world's per chunk edit table into a flat list for the file.
    public static func edits(from world: KtancraftWorld) -> [SavedEdit] {
        var result: [SavedEdit] = []
        for (key, table) in world.edits {
            let cx = chunkCoordX(key)
            let cz = chunkCoordZ(key)
            let originX = Int(cx) * chunkSizeX
            let originZ = Int(cz) * chunkSizeZ
            for (index, raw) in table {
                let i = Int(index)
                let x = i % chunkSizeX
                let z = (i / chunkSizeX) % chunkSizeZ
                let y = i / (chunkSizeX * chunkSizeZ)
                result.append(SavedEdit(x: Int32(originX + x), y: Int32(y), z: Int32(originZ + z), b: raw))
            }
        }
        return result
    }

    /// Rebuilds the per chunk edit table that a world applies on top of terrain.
    public static func editTable(from edits: [SavedEdit]) -> [Int64: [Int32: UInt8]] {
        var table: [Int64: [Int32: UInt8]] = [:]
        for edit in edits {
            guard edit.y >= 0, edit.y < worldHeight else { continue }
            let wx = Int(edit.x)
            let wz = Int(edit.z)
            let cx = chunkCoord(wx)
            let cz = chunkCoord(wz)
            let lx = wx - Int(cx) * chunkSizeX
            let lz = wz - Int(cz) * chunkSizeZ
            table[chunkKey(cx, cz), default: [:]][Int32(Chunk.index(lx, Int(edit.y), lz))] = edit.b
        }
        return table
    }
}
