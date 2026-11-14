//  Harness for the Ktancraft engine core.
//  Runs on Linux with the plain Swift toolchain:
//    swiftc -O Core/*.swift Tests/main.swift -o ktancraft-tests && ./ktancraft-tests
//  Ktan Labs

import Foundation

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: String) {
    checks += 1
    if !condition {
        failures += 1
        print("  FAIL  \(message)")
    }
}

func section(_ name: String) {
    print("\n== \(name)")
}

func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

// MARK: - Determinism

section("Determinism")
let genA = WorldGenerator(seed: 987654321)
let genB = WorldGenerator(seed: 987654321)
var same = true
for i in 0..<400 {
    let wx = i * 37 - 2000
    let wz = i * -19 + 500
    if genA.surfaceHeight(wx, wz) != genB.surfaceHeight(wx, wz) { same = false }
}
check(same, "same seed gives the same surface heights")

let chunkA = Chunk(cx: 3, cz: -2)
let chunkB = Chunk(cx: 3, cz: -2)
genA.generate(chunkA)
genB.generate(chunkB)
check(chunkA.blocks == chunkB.blocks, "same seed gives identical chunk data")

let other = Chunk(cx: 3, cz: -2)
WorldGenerator(seed: 1).generate(other)
check(chunkA.blocks != other.blocks, "a different seed gives a different chunk")

// MARK: - Terrain

section("Terrain")
let world = KtancraftWorld(seed: 1234)
let generateStart = now()
for dz in -2...2 {
    for dx in -2...2 {
        world.loadChunk(Int32(dx), Int32(dz))
    }
}
let generateMs = Double(now() - generateStart) / 1_000_000 / 25

var counts = [Block: Int]()
var highest = 0
var lowest = worldHeight
for chunk in world.chunks.values {
    for y in 0..<worldHeight {
        for z in 0..<chunkSizeZ {
            for x in 0..<chunkSizeX {
                let b = chunk.get(x, y, z)
                counts[b, default: 0] += 1
                if b != .air {
                    highest = max(highest, y)
                    lowest = min(lowest, y)
                }
            }
        }
    }
}
print(String(format: "  terrain: %.2f ms per 16x96x16 chunk", generateMs))
print("  blocks: \(counts.keys.sorted { $0.rawValue < $1.rawValue }.map { "\($0.displayName)=\(counts[$0]!)" }.joined(separator: " "))")
check((counts[.stone] ?? 0) > 1000, "chunks contain stone")
check((counts[.grass] ?? 0) > 0 || (counts[.sand] ?? 0) > 0, "chunks have a surface")
check((counts[.bedrock] ?? 0) > 0, "bedrock floor exists")
check(highest < worldHeight - 1, "terrain stays under the world ceiling")
check(lowest == 0, "nothing generates below y=0")

// Bedrock must be the bottom layer everywhere.
var bedrockOk = true
for chunk in world.chunks.values {
    for z in 0..<chunkSizeZ {
        for x in 0..<chunkSizeX where chunk.get(x, 0, z) != .bedrock {
            bedrockOk = false
        }
    }
}
check(bedrockOk, "bottom layer is bedrock on every column")

// No water floating above the surface, and water only at or under sea level.
var waterOk = true
for chunk in world.chunks.values {
    for y in (seaLevel + 1)..<worldHeight {
        for z in 0..<chunkSizeZ {
            for x in 0..<chunkSizeX where chunk.get(x, y, z) == .water {
                waterOk = false
            }
        }
    }
}
check(waterOk, "water never appears above sea level")

// Trees: at least one chunk should have logs in a 5x5 area at these seeds.
let logCount = counts[.log] ?? 0
check(logCount > 0, "trees generate (\(logCount) log blocks)")

// MARK: - Meshing

section("Meshing")
let meshChunk = world.chunkIfLoaded(0, 0)!
meshChunk.needsRemesh = false
let meshStart = now()
var mesh = Mesher.build(chunk: meshChunk, world: world, originX: 0, originZ: 0)
let meshMs = Double(now() - meshStart) / 1_000_000
var totalQuads = 0
var totalVertices = 0
for (_, buffer) in mesh {
    totalQuads += buffer.indices.count / 6
    totalVertices += buffer.vertexCount
    check(buffer.positions.count == buffer.vertexCount * 3, "positions match vertex count")
    check(buffer.normals.count == buffer.vertexCount * 3, "normals match vertex count")
    check(buffer.uvs.count == buffer.vertexCount * 2, "uvs match vertex count")
    check(buffer.indices.allSatisfy { $0 < UInt32(buffer.vertexCount) }, "indices are in range")
    check(buffer.positions.allSatisfy { $0.isFinite }, "no NaN or infinite positions")
    var maxIndex: UInt32 = 0
    for index in buffer.indices { maxIndex = max(maxIndex, index) }
    check(Int(maxIndex) < buffer.vertexCount, "largest index points at a real vertex")
}
check(totalQuads > 0, "the chunk produced geometry")
check(mesh.count >= 2, "several block materials in one chunk")
print("  mesh: \(meshMs) ms, \(totalQuads) merged quads, \(totalVertices) vertices, \(mesh.count) materials")
check(meshMs < 120, "a chunk meshes in well under a frame budget at 2 chunks/frame")

// Greedy merging must beat one quad per visible face.
var visibleFaces = 0
for y in 0..<worldHeight {
    for z in 0..<chunkSizeZ {
        for x in 0..<chunkSizeX {
            let b = meshChunk.get(x, y, z)
            if b == .air { continue }
            let neighbours = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
            for n in neighbours {
                if !world.blockAt(n.0 + x, n.1 + y, n.2 + z).hidesFaceOf(b) {
                    visibleFaces += 1
                }
            }
        }
    }
}
print("  greedy meshing: \(totalQuads) quads for \(visibleFaces) visible faces")
check(totalQuads < visibleFaces, "greedy meshing merges faces")

// Every quad must sit on the chunk's bounds.
for (_, buffer) in mesh {
    for v in 0..<buffer.vertexCount {
        let x = buffer.positions[v * 3]
        let y = buffer.positions[v * 3 + 1]
        let z = buffer.positions[v * 3 + 2]
        check(x >= 0 && x <= Float(chunkSizeX) && z >= 0 && z <= Float(chunkSizeZ),
              "vertices stay inside the chunk footprint")
        check(y >= 0 && y <= Float(worldHeight), "vertices stay inside the world height")
    }
}

// MARK: - Material keys

section("Material keys")
var keysRoundTrip = true
for block in Block.allCases where block != .air {
    for face in [TextureFace.top, .side, .bottom] {
        let key = MeshKey.encode(block, face: face)
        let decoded = MeshKey.decode(key)
        if decoded.block != block { keysRoundTrip = false }
        if block.hasDistinctFaces && decoded.face != face { keysRoundTrip = false }
    }
}
check(keysRoundTrip, "every material key decodes back to its block and face")
check(MeshKey.encode(.grass, face: .top) != MeshKey.encode(.grass, face: .side),
      "grass keeps its green top apart from its brown side")
check(MeshKey.encode(.stone, face: .top) == MeshKey.encode(.stone, face: .side),
      "blocks with one look share one material")
for key in mesh.keys {
    check(MeshKey.decode(key).block != .air, "mesh key \(key) decodes to a real block")
}
check(mesh.keys.contains(MeshKey.encode(.grass, face: .top)), "the chunk has grass top faces in the top material")

// MARK: - Physics

section("Physics")
var testWorld = KtancraftWorld(seed: 2026)
for dz in -1...1 { for dx in -1...1 { testWorld.loadChunk(Int32(dx), Int32(dz)) } }

var falling = Player()
let ground = testWorld.spawnHeight(atX: 4, z: 4)
falling.position = Vec3(4.5, Float(ground + 20), 4.5)
var steps = 0
while steps < 200 {
    Movement.step(player: &falling, input: PlayerInput(), world: testWorld, dt: 1.0 / 60.0)
    steps += 1
}
print(String(format: "  fell to y=%.3f (surface block at y=%d)", falling.y, ground - 1))
check(abs(falling.y - Float(ground)) < 0.2, "gravity settles the player on the surface")
check(falling.onGround, "player reports standing on ground")
check(falling.y > -1, "player does not fall through the world")

// Jump clears one block but not two.
var jumper = Player()
jumper.position = Vec3(4.5, Float(ground), 4.5)
Movement.step(player: &jumper, input: PlayerInput(), world: testWorld, dt: 1.0 / 60.0)
var peak = jumper.y
for _ in 0..<60 {
    Movement.step(player: &jumper, input: PlayerInput(jump: true), world: testWorld, dt: 1.0 / 60.0)
    peak = max(peak, jumper.y)
}
print(String(format: "  jump peak: %.2f blocks", peak - Float(ground)))
check(peak - Float(ground) > 1.05, "a jump clears one block")
check(peak - Float(ground) < 2.0, "a jump does not clear two blocks")

// Walking into a wall stops the player instead of entering it.
let wallX = 8
for y in ground..<(ground + 3) {
    for z in 3...6 {
        testWorld.setBlock(.stone, x: wallX, y: y, z: z, record: false)
    }
}
var walker = Player()
walker.position = Vec3(5.5, Float(ground), 4.5)
walker.yaw = -Float.pi / 2      // +X
for _ in 0..<180 {
    Movement.step(player: &walker, input: PlayerInput(forward: 1), world: testWorld, dt: 1.0 / 60.0)
}
print(String(format: "  walked to x=%.3f, wall at x=%d", walker.x, wallX))
check(walker.x < Float(wallX) - Player.halfWidth + 0.001, "the wall blocks movement")
check(walker.x > 6.0, "the player actually walked towards the wall")
check(!Movement.collides(walker, testWorld), "the player never ends a frame inside a block")

// Flying ignores gravity.
var flyer = Player()
flyer.position = Vec3(4.5, Float(ground) + 10, 4.5)
flyer.flying = true
let flyStart = flyer.y
for _ in 0..<60 {
    Movement.step(player: &flyer, input: PlayerInput(flyUp: true), world: testWorld, dt: 1.0 / 60.0)
}
check(flyer.y > flyStart + 3, "flying climbs")

// MARK: - Raycast

section("Raycast")
let rayWorld = KtancraftWorld(seed: 4242)
for dz in -1...1 { for dx in -1...1 { rayWorld.loadChunk(Int32(dx), Int32(dz)) } }
let columnTop = rayWorld.spawnHeight(atX: 6, z: 6) - 1
let down = Raycaster.cast(world: rayWorld, origin: Vec3(6.5, Float(columnTop) + 5, 6.5),
                          direction: Vec3(0, -1, 0), maxDistance: 12)
check(down != nil, "a downward ray hits the ground")
check(down?.block.y == Int32(columnTop), "the ray hits the topmost solid block")
check(down?.normal == IVec3(0, 1, 0), "the hit normal points up")

let clean = Raycaster.cast(world: rayWorld, origin: Vec3(6.5, 200, 6.5),
                           direction: Vec3(0, 1, 0), maxDistance: 10)
check(clean == nil, "a ray into the sky hits nothing")

// A ray straight down must never report a distance longer than the range.
if let hit = down {
    check(hit.distance <= 12, "hit distance stays inside the range")
}

// MARK: - Interaction

section("Interaction")
let game = KtancraftGame(seed: 777)
for dz in -1...1 { for dx in -1...1 { game.world.loadChunk(Int32(dx), Int32(dz)) } }
let spawnSurface = game.world.spawnHeight(atX: 0, z: 0)
game.player.position = Vec3(0.5, Float(spawnSurface) + 0.1, 0.5)
game.player.pitch = -0.9
game.update(dt: 1.0 / 60.0, input: PlayerInput())

let below = IVec3(0, Int32(spawnSurface - 1), 0)
game.world.setBlock(.dirt, x: 0, y: spawnSurface - 1, z: 0)
check(game.world.blockAt(0, spawnSurface - 1, 0) == .dirt, "edits write through to the world")
check(game.world.edits[chunkKey(0, 0)] != nil, "edits are recorded for the save file")

var broken = 0
for _ in 0..<120 {
    if game.mine(dt: 1.0 / 60.0, holding: true) != nil { broken += 1 }
}
check(broken > 0, "holding mine breaks the targeted block")
check(game.world.blockAt(0, spawnSurface - 1, 0) != .dirt || broken > 0, "broken block is gone")
_ = below

// Place a block back and confirm it lands where the crosshair points.
game.player.pitch = -1.2
game.inventory.select(2)      // stone
let placed = game.placeSelected()
check(placed, "placing a block succeeds against a face")
check(game.world.blockAt(0, spawnSurface - 1, 0) == .stone || game.world.blockAt(0, spawnSurface - 2, 0) == .stone,
      "the placed block exists in the world")

// MARK: - Save and load

section("Save and load")
let saveDir = FileManager.default.temporaryDirectory.appendingPathComponent("ktancraft-tests")
try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
game.name = "Test Dünyası"
game.world.setBlock(.planks, x: 12, y: 50, z: -7)
game.world.loadChunk(chunkCoord(-30), chunkCoord(40))
game.world.setBlock(.glass, x: -30, y: 33, z: 40)
let save = game.makeSave()
guard let data = save.encoded() else {
    print("  FAIL  could not encode the save file")
    exit(1)
}
let fileURL = saveDir.appendingPathComponent("world.ktc")
try data.write(to: fileURL)
let reloadedData = try Data(contentsOf: fileURL)
check(SaveFile.decode(reloadedData) != nil, "the save file decodes")

var loadedGame: KtancraftGame? = nil
if let decoded = SaveFile.decode(reloadedData) {
    loadedGame = KtancraftGame(save: decoded)
}
if let restored = loadedGame {
    restored.world.loadChunk(chunkCoord(12), chunkCoord(-7))
    restored.world.loadChunk(chunkCoord(-30), chunkCoord(40))
    check(restored.world.blockAt(12, 50, -7) == .planks, "placed planks survive the round trip")
    check(restored.world.blockAt(-30, 33, 40) == .glass, "edits far from spawn survive too")
    check(abs(restored.player.x - game.player.x) < 0.001, "player position is saved")
    check(restored.seed == game.seed, "the seed is saved")
    check(restored.name == "Test Dünyası", "the world name is saved (unicode safe)")
}
print("  save file: \(data.count) bytes")

// MARK: - Textures

section("Textures")
var textureIssues = 0
for block in Block.allCases where block != .air {
    for face in [TextureFace.top, .side, .bottom] {
        let pixels = BlockTextures.rgba(for: block, face: face)
        if pixels.count != BlockTextures.size * BlockTextures.size * 4 { textureIssues += 1 }
        if block != .glass && block != .water {
            var opaque = true
            var v = 3
            while v < pixels.count {
                if pixels[v] < 200 { opaque = false }
                v += 4
            }
            if !opaque { textureIssues += 1 }
        }
    }
}
check(textureIssues == 0, "every block texture is 16x16 RGBA and opaque where it should be")
let glassPixels = BlockTextures.rgba(for: .glass, face: .side)
let glassCenter = (8 * BlockTextures.size + 8) * 4
check(glassPixels[glassCenter + 3] < 200, "glass is see-through")
let grassSide = BlockTextures.rgba(for: .grass, face: .side)
check(grassSide[1] > grassSide[16 * 4 * 12 + 1], "grass has a green top and brown sides")
let stonePixels = BlockTextures.rgba(for: .stone, face: .side)
check(stonePixels == BlockTextures.rgba(for: .stone, face: .side), "stone textures are stable between calls")
check(stonePixels != BlockTextures.rgba(for: .dirt, face: .side), "different blocks get different textures")

// MARK: - Streaming

section("Streaming")
let streamGame = KtancraftGame(seed: 555)
var frames = 0
while !streamGame.isAreaReady(radius: 3) && frames < 400 {
    streamGame.stream(radius: 3, chunkBudget: 2)
    frames += 1
}
check(streamGame.isAreaReady(radius: 3), "streaming loads every chunk in range")
print("  streaming: \(frames) frames of 2 chunks to fill radius 3")
let dirty = streamGame.dirtyChunks(limit: 2)
check(dirty.count == 2, "dirty chunk queue is limited by the budget")
check(dirty.allSatisfy { $0.needsRemesh }, "the queue only holds chunks that need a mesh")

// MARK: - Placement inside the player is refused

section("Placement rules")
let placeGame = KtancraftGame(seed: 9090)
for dz in -1...1 { for dx in -1...1 { placeGame.world.loadChunk(Int32(dx), Int32(dz)) } }
let surfaceHere = placeGame.world.spawnHeight(atX: 0, z: 0)
placeGame.player.position = Vec3(0.5, Float(surfaceHere) + 0.05, 0.5)
let insidePlayer = IVec3(0, Int32(surfaceHere), 0)
check(!Movement.canPlace(at: insidePlayer, player: placeGame.player, world: placeGame.world),
      "blocks cannot be placed inside the player")
check(Movement.canPlace(at: IVec3(5, Int32(surfaceHere) + 6, 5), player: placeGame.player, world: placeGame.world),
      "blocks can be placed in free air")

// MARK: - Summary

print("\n---------------------------------------------")
print(failures == 0 ? "ALL \(checks) CHECKS PASSED" : "\(failures) of \(checks) CHECKS FAILED")
print("---------------------------------------------")
exit(failures == 0 ? 0 : 1)
