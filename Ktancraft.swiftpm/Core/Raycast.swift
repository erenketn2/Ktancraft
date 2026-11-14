//  Raycast.swift
//  Ktancraft — engine core
//  Ktan Labs
//
//  Amanatides & Woo voxel traversal. Used for the block under the crosshair,
//  both for breaking and for placing.

import Foundation

public struct RayHit {
    public var block: IVec3
    public var normal: IVec3
    public var distance: Float
    public var hitBlock: Block

    public init(block: IVec3, normal: IVec3, distance: Float, hitBlock: Block) {
        self.block = block
        self.normal = normal
        self.distance = distance
        self.hitBlock = hitBlock
    }
}

public enum Raycaster {
    /// Walks the grid from `origin` along `direction`.
    /// `solidOnly` skips water so a pool does not block the crosshair.
    public static func cast(world: BlockSource, origin: Vec3, direction: Vec3,
                            maxDistance: Float, solidOnly: Bool = true) -> RayHit? {
        let dir = direction.normalized()
        guard dir.lengthSquared > 0 else { return nil }

        var x = Int(floor(origin.x))
        var y = Int(floor(origin.y))
        var z = Int(floor(origin.z))

        let stepX = dir.x > 0 ? 1 : (dir.x < 0 ? -1 : 0)
        let stepY = dir.y > 0 ? 1 : (dir.y < 0 ? -1 : 0)
        let stepZ = dir.z > 0 ? 1 : (dir.z < 0 ? -1 : 0)

        let tDeltaX = stepX != 0 ? abs(1 / dir.x) : Float.infinity
        let tDeltaY = stepY != 0 ? abs(1 / dir.y) : Float.infinity
        let tDeltaZ = stepZ != 0 ? abs(1 / dir.z) : Float.infinity

        var tMaxX = stepX != 0 ? ((stepX > 0 ? Float(x + 1) - origin.x : origin.x - Float(x)) / abs(dir.x)) : Float.infinity
        var tMaxY = stepY != 0 ? ((stepY > 0 ? Float(y + 1) - origin.y : origin.y - Float(y)) / abs(dir.y)) : Float.infinity
        var tMaxZ = stepZ != 0 ? ((stepZ > 0 ? Float(z + 1) - origin.z : origin.z - Float(z)) / abs(dir.z)) : Float.infinity

        var normal = IVec3.zero
        var travelled: Float = 0

        // The starting cell counts too, so you can break a block you stand in.
        var guardCounter = 0
        while travelled <= maxDistance && guardCounter < 512 {
            guardCounter += 1
            let block = world.blockAt(x, y, z)
            if block != .air && (!solidOnly || block.isSolid) {
                return RayHit(block: IVec3(Int32(x), Int32(y), Int32(z)),
                              normal: normal,
                              distance: travelled,
                              hitBlock: block)
            }
            if tMaxX < tMaxY && tMaxX < tMaxZ {
                x += stepX
                travelled = tMaxX
                tMaxX += tDeltaX
                normal = IVec3(Int32(-stepX), 0, 0)
            } else if tMaxY < tMaxZ {
                y += stepY
                travelled = tMaxY
                tMaxY += tDeltaY
                normal = IVec3(0, Int32(-stepY), 0)
            } else {
                z += stepZ
                travelled = tMaxZ
                tMaxZ += tDeltaZ
                normal = IVec3(0, 0, Int32(-stepZ))
            }
        }
        return nil
    }
}
