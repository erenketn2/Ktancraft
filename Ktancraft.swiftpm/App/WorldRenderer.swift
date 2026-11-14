//  WorldRenderer.swift
//  Ktancraft
//  Ktan Labs
//
//  SceneKit side of the game: one node per chunk, one geometry per material,
//  a sun that crosses the sky, fog matched to the sky colour and a first person
//  camera driven by the engine's player state.

import Foundation
import SceneKit
import UIKit

final class WorldRenderer {
    let scene = SCNScene()

    private let chunkRoot = SCNNode()
    private let cameraRig = SCNNode()
    private let yawNode = SCNNode()
    private let pitchNode = SCNNode()
    private let cameraNode = SCNNode()
    private let sunNode = SCNNode()
    private let ambientNode = SCNNode()

    private var chunkNodes: [Int64: SCNNode] = [:]
    private var materials: [UInt8: SCNMaterial] = [:]
    private var attached = false
    private var dayTime: Float = 0.32

    private let nightSky = UIColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1)
    private let daySky = UIColor(red: 0.55, green: 0.73, blue: 0.96, alpha: 1)

    /// Connects the renderer to a view once.
    func attachIfNeeded(to view: SCNView) {
        guard !attached else { return }
        attached = true
        scene.rootNode.addChildNode(chunkRoot)
        setupCamera()
        setupLights()
        scene.background.contents = daySky
        scene.fogColor = daySky

        view.scene = scene
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling2X
        view.backgroundColor = daySky
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.showsStatistics = false
        view.isJitteringEnabled = false
        view.pointOfView = cameraNode
    }

    private func setupCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 74
        camera.zNear = 0.05
        camera.zFar = 400
        camera.wantsHDR = false
        cameraNode.camera = camera

        cameraRig.addChildNode(yawNode)
        yawNode.addChildNode(pitchNode)
        pitchNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraRig)
    }

    private func setupLights() {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1150
        sun.color = UIColor.white
        sun.castsShadow = false
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.9, 0.6, 0)
        scene.rootNode.addChildNode(sunNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 420
        ambient.color = UIColor(red: 0.76, green: 0.84, blue: 0.98, alpha: 1)
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    // MARK: - Frame

    func update(game: KtancraftGame, dt: Float, dirtyBudget: Int, renderDistance: Int) {
        let player = game.player

        // Chunks that were unloaded while the player walked away.
        var stale: [Int64] = []
        for key in chunkNodes.keys where game.world.chunks[key] == nil {
            stale.append(key)
        }
        for key in stale {
            chunkNodes[key]?.removeFromParentNode()
            chunkNodes[key] = nil
        }

        for chunk in game.dirtyChunks(limit: dirtyBudget) {
            rebuild(chunk: chunk, game: game)
        }

        cameraRig.position = SCNVector3(player.x, player.y + Player.eyeHeight, player.z)
        yawNode.eulerAngles = SCNVector3(0, player.yaw, 0)
        pitchNode.eulerAngles = SCNVector3(player.pitch, 0, 0)

        if let camera = cameraNode.camera {
            let far = CGFloat(renderDistance + 2) * 16 * 1.3
            camera.zFar = Double(max(far, 120))
        }
        let viewDistance = Float(renderDistance) * 16
        scene.fogStartDistance = CGFloat(viewDistance * 0.5)
        scene.fogEndDistance = CGFloat(viewDistance * 1.05)

        updateSky(dt: dt)
    }

    private func updateSky(dt: Float) {
        dayTime += dt / 480
        if dayTime >= 1 { dayTime -= 1 }
        let angle = dayTime * Float.pi * 2
        let elevation = sin(angle)
        let daylight = max(0, elevation)

        sunNode.eulerAngles = SCNVector3(-(Float.pi / 2) * (0.30 + 0.60 * max(daylight, 0.02)), angle * 0.35, 0)
        sunNode.light?.intensity = CGFloat(120 + 1050 * daylight)
        ambientNode.light?.intensity = CGFloat(190 + 290 * daylight)
        ambientNode.light?.color = UIColor(red: 0.30 + 0.46 * CGFloat(daylight),
                                           green: 0.36 + 0.48 * CGFloat(daylight),
                                           blue: 0.55 + 0.43 * CGFloat(daylight),
                                           alpha: 1)

        let sky = blend(nightSky, daySky, CGFloat(daylight))
        scene.background.contents = sky
        scene.fogColor = sky
    }

    private func blend(_ from: UIColor, _ to: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t,
                       green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t,
                       alpha: 1)
    }

    // MARK: - Chunks

    private func rebuild(chunk: Chunk, game: KtancraftGame) {
        chunk.needsRemesh = false
        let key = chunkKey(chunk.cx, chunk.cz)
        chunkNodes[key]?.removeFromParentNode()

        let originX = Int(chunk.cx) * chunkSizeX
        let originZ = Int(chunk.cz) * chunkSizeZ
        let buffers = Mesher.build(chunk: chunk, world: game.world, originX: originX, originZ: originZ)

        let node = SCNNode()
        node.position = SCNVector3(Float(originX), 0, Float(originZ))
        for (rawKey, buffer) in buffers where !buffer.isEmpty {
            let (block, face) = MeshKey.decode(rawKey)
            guard block != .air, let geometry = makeGeometry(buffer, materialKey: rawKey, block: block, face: face) else {
                continue
            }
            node.addChildNode(SCNNode(geometry: geometry))
        }
        chunkRoot.addChildNode(node)
        chunkNodes[key] = node
        chunk.hasMesh = true
    }

    private func makeGeometry(_ buffer: MeshBuffers, materialKey: UInt8, block: Block, face: TextureFace) -> SCNGeometry? {
        guard buffer.vertexCount > 0, !buffer.indices.isEmpty else { return nil }

        let positionData = buffer.positions.withUnsafeBufferPointer { Data(buffer: $0) }
        let normalData = buffer.normals.withUnsafeBufferPointer { Data(buffer: $0) }
        let uvData = buffer.uvs.withUnsafeBufferPointer { Data(buffer: $0) }
        let indexData = buffer.indices.withUnsafeBufferPointer { Data(buffer: $0) }

        let stride = MemoryLayout<Float>.size
        let positions = SCNGeometrySource(data: positionData,
                                          semantic: .vertex,
                                          vectorCount: buffer.vertexCount,
                                          usesFloatComponents: true,
                                          componentsPerVector: 3,
                                          bytesPerComponent: stride,
                                          dataOffset: 0,
                                          dataStride: stride * 3)
        let normals = SCNGeometrySource(data: normalData,
                                        semantic: .normal,
                                        vectorCount: buffer.vertexCount,
                                        usesFloatComponents: true,
                                        componentsPerVector: 3,
                                        bytesPerComponent: stride,
                                        dataOffset: 0,
                                        dataStride: stride * 3)
        let uvs = SCNGeometrySource(data: uvData,
                                    semantic: .texcoord,
                                    vectorCount: buffer.vertexCount,
                                    usesFloatComponents: true,
                                    componentsPerVector: 2,
                                    bytesPerComponent: stride,
                                    dataOffset: 0,
                                    dataStride: stride * 2)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangles,
                                         primitiveCount: buffer.indices.count / 3,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)

        let geometry = SCNGeometry(sources: [positions, normals, uvs], elements: [element])
        geometry.firstMaterial = material(for: block, face: face, key: materialKey)
        return geometry
    }

    private func material(for block: Block, face: TextureFace, key: UInt8) -> SCNMaterial {
        if let cached = materials[key] { return cached }

        let material = SCNMaterial()
        material.diffuse.contents = BlockIcon.image(for: block, face: face)
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.magnificationFilter = .nearest
        material.diffuse.minificationFilter = .nearest
        material.diffuse.mipFilter = .nearest
        material.lightingModel = .lambert
        material.isDoubleSided = false
        material.locksAmbientWithDiffuse = true

        switch block {
        case .water:
            material.transparency = 0.82
            material.writesToDepthBuffer = false
            material.blendMode = .alpha
        case .glass:
            material.transparency = 1.0
            material.writesToDepthBuffer = false
            material.blendMode = .alpha
        case .leaves:
            material.transparency = 1.0
        default:
            break
        }

        materials[key] = material
        return material
    }

    /// Frees every chunk node, used when a world closes.
    func reset() {
        for node in chunkNodes.values {
            node.removeFromParentNode()
        }
        chunkNodes.removeAll()
    }
}
