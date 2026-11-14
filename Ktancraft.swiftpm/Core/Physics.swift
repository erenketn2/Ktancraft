//  Physics.swift
//  Ktancraft — engine core
//  Ktan Labs
//
//  Block collision for an axis aligned player box, gravity, jumping, sprinting,
//  swimming and creative flight. Fixed numbers, no randomness, so the tests can
//  assert exact outcomes.

import Foundation

public struct PlayerInput: Equatable {
    /// -1 ... 1, forward is positive.
    public var forward: Float = 0
    /// -1 ... 1, right is positive.
    public var strafe: Float = 0
    public var jump: Bool = false
    public var sneak: Bool = false
    public var sprint: Bool = false
    public var flyUp: Bool = false
    public var flyDown: Bool = false

    public init(forward: Float = 0, strafe: Float = 0, jump: Bool = false, sneak: Bool = false,
                sprint: Bool = false, flyUp: Bool = false, flyDown: Bool = false) {
        self.forward = forward
        self.strafe = strafe
        self.jump = jump
        self.sneak = sneak
        self.sprint = sprint
        self.flyUp = flyUp
        self.flyDown = flyDown
    }
}

public struct Player: Codable {
    /// Feet position, centre of the player box horizontally.
    public var x: Float
    public var y: Float
    public var z: Float
    public var velocityX: Float = 0
    public var velocityY: Float = 0
    public var velocityZ: Float = 0
    public var yaw: Float = 0
    public var pitch: Float = 0
    public var onGround: Bool = false
    public var inWater: Bool = false
    public var flying: Bool = false
    public var creative: Bool = true

    public init(x: Float = 0.5, y: Float = 48, z: Float = 0.5) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let halfWidth: Float = 0.3
    public static let height: Float = 1.8
    public static let eyeHeight: Float = 1.62

    public var position: Vec3 {
        get { Vec3(x, y, z) }
        set { x = newValue.x; y = newValue.y; z = newValue.z }
    }

    public var eyePosition: Vec3 { Vec3(x, y + Player.eyeHeight, z) }

    public var box: AABB {
        AABB(min: Vec3(x - Player.halfWidth, y, z - Player.halfWidth),
             max: Vec3(x + Player.halfWidth, y + Player.height, z + Player.halfWidth))
    }

    /// Unit vector the player looks along. yaw 0 faces -Z.
    public var lookDirection: Vec3 {
        let cp = cos(pitch)
        return Vec3(-sin(yaw) * cp, sin(pitch), -cos(yaw) * cp).normalized()
    }

    public var forwardOnPlane: Vec3 { Vec3(-sin(yaw), 0, -cos(yaw)) }
    public var rightOnPlane: Vec3 { Vec3(cos(yaw), 0, -sin(yaw)) }
}

public enum Movement {
    public static let gravity: Float = 28
    public static let maxFallSpeed: Float = 55
    public static let walkSpeed: Float = 4.4
    public static let sprintSpeed: Float = 6.6
    public static let sneakSpeed: Float = 1.6
    public static let flySpeed: Float = 11
    public static let jumpSpeed: Float = 8.6
    public static let terminalSubstep: Float = 0.05

    public static func step(player: inout Player, input: PlayerInput, world: BlockSource, dt: Float) {
        let clampedDt = min(max(dt, 0), 0.1)

        // Water and ground tests first, they change how the rest behaves.
        let feetBlock = world.blockAt(Int(floor(player.x)), Int(floor(player.y + 0.2)), Int(floor(player.z)))
        let chestBlock = world.blockAt(Int(floor(player.x)), Int(floor(player.y + 1.2)), Int(floor(player.z)))
        player.inWater = feetBlock == .water || chestBlock == .water

        if input.sneak && !player.flying && player.onGround {
            player.flying = false
        }

        var wish = player.forwardOnPlane * input.forward + player.rightOnPlane * input.strafe
        if wish.lengthSquared > 1 {
            wish = wish.normalized()
        }

        let speed: Float
        if player.flying {
            speed = flySpeed
        } else if player.inWater {
            speed = walkSpeed * 0.65
        } else if input.sneak {
            speed = sneakSpeed
        } else if input.sprint {
            speed = sprintSpeed
        } else {
            speed = walkSpeed
        }

        let targetX = wish.x * speed
        let targetZ = wish.z * speed
        // Ground friction is snappy, air control is not.
        let accel: Float
        if player.flying {
            accel = 12
        } else if player.onGround {
            accel = 18
        } else if player.inWater {
            accel = 8
        } else {
            accel = 5
        }
        let blend = min(1, accel * clampedDt)
        player.velocityX += (targetX - player.velocityX) * blend
        player.velocityZ += (targetZ - player.velocityZ) * blend

        if player.flying {
            var vertical: Float = 0
            if input.flyUp { vertical += 1 }
            if input.flyDown { vertical -= 1 }
            if vertical == 0 { vertical = input.jump ? 1 : (input.sneak ? -1 : 0) }
            player.velocityY += (vertical * flySpeed - player.velocityY) * min(1, 12 * clampedDt)
        } else if player.inWater {
            player.velocityY -= gravity * 0.28 * clampedDt
            if input.jump {
                player.velocityY = min(player.velocityY + 26 * clampedDt, 3.4)
            }
            player.velocityY = max(player.velocityY, -4)
        } else {
            player.velocityY -= gravity * clampedDt
            player.velocityY = max(player.velocityY, -maxFallSpeed)
            if input.jump && player.onGround {
                player.velocityY = jumpSpeed
                player.onGround = false
            }
        }

        move(player: &player, dx: player.velocityX * clampedDt, dy: player.velocityY * clampedDt,
             dz: player.velocityZ * clampedDt, world: world)
    }

    /// Moves the box in sub steps and stops it flush against blocks.
    public static func move(player: inout Player, dx: Float, dy: Float, dz: Float, world: BlockSource) {
        let distance = max(abs(dx), max(abs(dy), abs(dz)))
        let steps = max(1, Int((distance / terminalSubstep).rounded(.up)))
        let stepX = dx / Float(steps)
        let stepY = dy / Float(steps)
        let stepZ = dz / Float(steps)
        var hitGround = false

        for _ in 0..<steps {
            if stepX != 0 {
                player.x += stepX
                if collides(player, world) {
                    player.x -= stepX
                    if !collides(player, world) {
                        player.velocityX = 0
                    } else {
                        player.x += stepX
                    }
                }
            }
            if stepZ != 0 {
                player.z += stepZ
                if collides(player, world) {
                    player.z -= stepZ
                    if !collides(player, world) {
                        player.velocityZ = 0
                    } else {
                        player.z += stepZ
                    }
                }
            }
            if stepY != 0 {
                player.y += stepY
                if collides(player, world) {
                    player.y -= stepY
                    if !collides(player, world) {
                        if stepY < 0 { hitGround = true }
                        player.velocityY = 0
                        break
                    } else {
                        player.y += stepY
                    }
                }
            }
        }

        player.onGround = hitGround || isStandingOnGround(player, world)
        if hitGround {
            player.velocityY = min(player.velocityY, 0)
        }
        // Never let the player fall out of the world.
        if player.y < -4 {
            player.y = Float(seaLevel + 2)
            player.velocityY = 0
        }
    }

    public static func collides(_ player: Player, _ world: BlockSource) -> Bool {
        let minX = Int(floor(player.x - Player.halfWidth))
        let maxX = Int(floor(player.x + Player.halfWidth - 0.0001))
        let minY = Int(floor(player.y + 0.0001))
        let maxY = Int(floor(player.y + Player.height - 0.0001))
        let minZ = Int(floor(player.z - Player.halfWidth))
        let maxZ = Int(floor(player.z + Player.halfWidth - 0.0001))

        var y = minY
        while y <= maxY {
            var z = minZ
            while z <= maxZ {
                var x = minX
                while x <= maxX {
                    if world.blockAt(x, y, z).isSolid { return true }
                    x += 1
                }
                z += 1
            }
            y += 1
        }
        return false
    }

    public static func isStandingOnGround(_ player: Player, _ world: BlockSource) -> Bool {
        let y = Int(floor(player.y - 0.02))
        let minX = Int(floor(player.x - Player.halfWidth))
        let maxX = Int(floor(player.x + Player.halfWidth - 0.0001))
        let minZ = Int(floor(player.z - Player.halfWidth))
        let maxZ = Int(floor(player.z + Player.halfWidth - 0.0001))
        var z = minZ
        while z <= maxZ {
            var x = minX
            while x <= maxX {
                if world.blockAt(x, y, z).isSolid { return true }
                x += 1
            }
            z += 1
        }
        return false
    }

    /// True when the block the player would occupy is free.
    public static func canPlace(at position: IVec3, player: Player, world: BlockSource) -> Bool {
        let blockBox = AABB(min: Vec3(Float(position.x), Float(position.y), Float(position.z)),
                           max: Vec3(Float(position.x) + 1, Float(position.y) + 1, Float(position.z) + 1))
        if player.box.intersects(blockBox) { return false }
        let existing = world.blockAt(Int(position.x), Int(position.y), Int(position.z))
        return existing == .air || existing == .water
    }
}
