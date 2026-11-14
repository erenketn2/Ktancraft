//  Game.swift
//  Ktancraft — engine core
//  Ktan Labs

import Foundation

/// Ties the world, the player, the inventory and the interaction rules together.
/// The renderer and the touch controls only talk to this class.
public final class KtancraftGame {
    public let world: KtancraftWorld
    public var player: Player
    public var inventory: Inventory

    public var name: String
    public var miningTarget: IVec3?
    public var miningProgress: Float = 0
    public private(set) var playSeconds: Double = 0

    public static let reach: Float = 5.5
    public static let maxRenderRadius = 12

    public init(seed: UInt64, name: String = "Dünya") {
        self.world = KtancraftWorld(seed: seed)
        self.name = name
        var spawn = Player()
        let surface = world.spawnHeight(atX: 0, z: 0)
        spawn.position = Vec3(0.5, Float(surface) + 0.1, 0.5)
        self.player = spawn
        self.inventory = Inventory()
    }

    public init(save: SaveFile) {
        self.world = KtancraftWorld(seed: save.seed)
        self.name = save.name
        var loadedInventory = save.inventory
        loadedInventory.normalize()
        self.inventory = loadedInventory
        self.player = save.player
        self.world.replaceEdits(SaveFile.editTable(from: save.edits))
    }

    public var seed: UInt64 { world.seed }

    public func makeSave() -> SaveFile {
        SaveFile(seed: world.seed, name: name, player: player,
                 inventory: inventory, edits: SaveFile.edits(from: world))
    }

    // MARK: - Streaming

    /// Chunk offsets that make up the visible area at a given radius.
    public func chunkOffsets(radius: Int) -> [(Int, Int)] {
        var offsets: [(Int, Int)] = []
        for dz in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dz * dz > radius * radius + radius { continue }
                offsets.append((dx, dz))
            }
        }
        return offsets
    }

    /// Loads the nearest missing chunks, a few per call, and drops the ones that
    /// fell out of range. Called once a frame by the renderer.
    @discardableResult
    public func stream(radius: Int, chunkBudget: Int) -> [Chunk] {
        let clampedRadius = min(max(radius, 1), KtancraftGame.maxRenderRadius)
        let centerX = Int(chunkCoord(Int(floor(player.x))))
        let centerZ = Int(chunkCoord(Int(floor(player.z))))

        var loaded: [Chunk] = []
        if chunkBudget > 0 {
            var missing: [(Int, Int, Int)] = []
            for (dx, dz) in chunkOffsets(radius: clampedRadius) {
                let cx = centerX + dx
                let cz = centerZ + dz
                if world.chunkIfLoaded(Int32(cx), Int32(cz)) == nil {
                    missing.append((dx * dx + dz * dz, cx, cz))
                }
            }
            missing.sort { $0.0 < $1.0 }
            for entry in missing.prefix(chunkBudget) {
                loaded.append(world.loadChunk(Int32(entry.1), Int32(entry.2)))
            }
        }

        // Forget chunks well outside the view so memory stays flat.
        let dropDistance = clampedRadius + 3
        var toUnload: [Int64] = []
        for key in world.chunks.keys {
            let dx = Int(chunkCoordX(key)) - centerX
            let dz = Int(chunkCoordZ(key)) - centerZ
            if abs(dx) > dropDistance || abs(dz) > dropDistance {
                toUnload.append(key)
            }
        }
        for key in toUnload {
            world.unloadChunk(chunkCoordX(key), chunkCoordZ(key))
        }
        return loaded
    }

    /// Chunks that need a mesh, nearest first.
    public func dirtyChunks(limit: Int) -> [Chunk] {
        let centerX = Int(chunkCoord(Int(floor(player.x))))
        let centerZ = Int(chunkCoord(Int(floor(player.z))))
        var candidates: [(Int, Chunk)] = []
        for chunk in world.chunks.values where chunk.needsRemesh {
            let dx = Int(chunk.cx) - centerX
            let dz = Int(chunk.cz) - centerZ
            candidates.append((dx * dx + dz * dz, chunk))
        }
        candidates.sort { $0.0 < $1.0 }
        return candidates.prefix(limit).map { $0.1 }
    }

    /// True once every chunk in range has terrain, so the spawn screen can wait.
    public func isAreaReady(radius: Int) -> Bool {
        let centerX = Int(chunkCoord(Int(floor(player.x))))
        let centerZ = Int(chunkCoord(Int(floor(player.z))))
        for (dx, dz) in chunkOffsets(radius: min(max(radius, 1), KtancraftGame.maxRenderRadius)) {
            if world.chunkIfLoaded(Int32(centerX + dx), Int32(centerZ + dz)) == nil {
                return false
            }
        }
        return true
    }

    // MARK: - Frame

    public func update(dt: Float, input: PlayerInput) {
        playSeconds += Double(dt)
        Movement.step(player: &player, input: input, world: world, dt: dt)
        if !player.flying && player.inWater && input.jump && player.onGround {
            player.velocityY = Movement.jumpSpeed * 0.6
        }
    }

    public func look(yawDelta: Float, pitchDelta: Float) {
        player.yaw -= yawDelta
        player.pitch = MathUtil.clamp(player.pitch + pitchDelta, -1.53, 1.53)
        if player.yaw > Float.pi * 2 { player.yaw -= Float.pi * 2 }
        if player.yaw < -Float.pi * 2 { player.yaw += Float.pi * 2 }
    }

    // MARK: - Interaction

    public func currentTarget() -> RayHit? {
        Raycaster.cast(world: world, origin: player.eyePosition,
                       direction: player.lookDirection, maxDistance: KtancraftGame.reach)
    }

    /// Mines while the button is held. Returns the block that broke this frame.
    public func mine(dt: Float, holding: Bool) -> Block? {
        guard holding, let hit = currentTarget(), hit.hitBlock.isBreakable else {
            miningTarget = nil
            miningProgress = 0
            return nil
        }
        if miningTarget != hit.block {
            miningTarget = hit.block
            miningProgress = 0
        }
        let hardness = max(hit.hitBlock.hardness, 0.05)
        miningProgress += dt / hardness
        if miningProgress >= 1 {
            world.setBlock(.air, x: Int(hit.block.x), y: Int(hit.block.y), z: Int(hit.block.z))
            miningTarget = nil
            miningProgress = 0
            return hit.hitBlock
        }
        return nil
    }

    /// Places the selected hotbar block next to the targeted block.
    @discardableResult
    public func placeSelected() -> Bool {
        guard let hit = currentTarget() else { return false }
        let target = IVec3(hit.block.x + hit.normal.x,
                           hit.block.y + hit.normal.y,
                           hit.block.z + hit.normal.z)
        guard target.y >= 0, target.y < worldHeight else { return false }
        let block = inventory.selectedBlock
        guard block != .air, Movement.canPlace(at: target, player: player, world: world) else { return false }
        if world.setBlock(block, x: Int(target.x), y: Int(target.y), z: Int(target.z)) {
            miningTarget = nil
            miningProgress = 0
            return true
        }
        return false
    }

    public func toggleFlying() {
        player.flying.toggle()
        if player.flying {
            player.velocityY = 0
        }
    }

    /// Drops the player onto the surface, used by the "respawn" button.
    public func respawn() {
        let x = Int(floor(player.x))
        let z = Int(floor(player.z))
        let surface = world.spawnHeight(atX: x, z: z)
        player.position = Vec3(player.x, Float(surface) + 0.2, player.z)
        player.velocityX = 0
        player.velocityY = 0
        player.velocityZ = 0
        player.flying = false
    }
}
