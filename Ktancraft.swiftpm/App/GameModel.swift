//  GameModel.swift
//  Ktancraft
//  Ktan Labs
//
//  Owns the engine, the renderer, the frame clock and the save file. Everything
//  the SwiftUI layer shows comes from `hud`.

import Foundation
import UIKit
import QuartzCore
import SwiftUI

struct HUDState: Equatable {
    var fps: Int = 0
    var x: Int = 0
    var y: Int = 0
    var z: Int = 0
    var selected: Int = 0
    var miningProgress: Float = 0
    var flying: Bool = false
    var ready: Bool = false
    var inWater: Bool = false
    var slots: [UInt8] = Inventory.defaultSlots
    var dayTime: Float = 0
}

final class GameModel: ObservableObject {
    @Published var hud = HUDState()
    @Published var isPaused = false
    @Published var showHelp = false
    @Published var toast: String? = nil

    let game: KtancraftGame
    let renderer = WorldRenderer()
    let settings: GameSettings
    let saveID: String

    private let store = WorldStore.shared
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var hudTimer: Double = 0
    private var frameCounter = 0
    private var fpsTimer: Double = 0
    private var ready = false
    private var pendingSpawn = false

    // Touch state, written from the surface view and the HUD.
    private var joystickForward: Float = 0
    private var joystickStrafe: Float = 0
    var jumpHeld = false
    var descendHeld = false
    var miningHeld = false

    var onRequestExit: (() -> Void)?

    init(launch: GameLaunch, settings: GameSettings) {
        self.settings = settings
        self.saveID = launch.saveID
        if let existing = launch.existing {
            self.game = KtancraftGame(save: existing)
        } else {
            self.game = KtancraftGame(seed: launch.seed, name: launch.name)
            pendingSpawn = true
        }
        prepareSpawn()
    }

    // MARK: - Lifecycle

    /// Fills the area around the player before the first frame so nothing falls
    /// through unloaded terrain.
    private func prepareSpawn() {
        var guardCounter = 0
        while !game.isAreaReady(radius: 2) && guardCounter < 40 {
            game.stream(radius: 2, chunkBudget: 24)
            guardCounter += 1
        }
        // A saved world keeps the player exactly where they left off.
        if pendingSpawn {
            game.respawn()
            pendingSpawn = false
        }
        ready = game.isAreaReady(radius: 1)
        publishHUD()
    }

    func start() {
        guard displayLink == nil else { return }
        lastTime = 0
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Frame

    @objc private func tick() {
        let now = CACurrentMediaTime()
        var dt = Float(now - lastTime)
        if lastTime == 0 || dt <= 0 || dt > 0.25 {
            dt = 1.0 / 60.0
        }
        lastTime = now

        frameCounter += 1
        fpsTimer += Double(dt)
        if fpsTimer >= 0.5 {
            hudTimer = 0
            var state = hud
            state.fps = Int(Double(frameCounter) / fpsTimer)
            frameCounter = 0
            fpsTimer = 0
            publishHUD(state)
        }

        if isPaused { return }

        // Terrain streaming, a couple of chunks per frame.
        game.stream(radius: settings.renderDistance, chunkBudget: 2)
        if !ready {
            ready = game.isAreaReady(radius: 1)
            if ready {
                if pendingSpawn {
                    game.respawn()
                    pendingSpawn = false
                }
                publishHUD()
            }
        }

        if ready {
            var input = PlayerInput()
            input.forward = joystickForward
            input.strafe = joystickStrafe
            input.sprint = joystickForward > 0.9
            if game.player.flying {
                input.flyUp = jumpHeld
                input.flyDown = descendHeld
            } else {
                input.jump = jumpHeld
            }
            game.update(dt: dt, input: input)
            _ = game.mine(dt: dt, holding: miningHeld)
        }

        renderer.update(game: game, dt: dt, dirtyBudget: ready ? 1 : 2, renderDistance: settings.renderDistance)

        hudTimer += Double(dt)
        if hudTimer >= 0.12 {
            hudTimer = 0
            publishHUD()
        }
    }

    private func publishHUD(_ base: HUDState? = nil) {
        var state = base ?? hud
        state.x = Int(game.player.x.rounded(.down))
        state.y = Int(game.player.y.rounded(.down))
        state.z = Int(game.player.z.rounded(.down))
        state.selected = game.inventory.selected
        state.miningProgress = game.miningProgress
        state.flying = game.player.flying
        state.ready = ready
        state.inWater = game.player.inWater
        state.slots = game.inventory.slots
        hud = state
    }

    // MARK: - Input

    func setJoystick(forward: Float, strafe: Float) {
        joystickForward = forward
        joystickStrafe = strafe
    }

    func look(deltaX: Float, deltaY: Float) {
        let scale = Float(0.0032 * settings.sensitivity)
        game.look(yawDelta: deltaX * scale, pitchDelta: -deltaY * scale)
    }

    func selectSlot(_ index: Int) {
        game.inventory.select(index)
        publishHUD()
    }

    func place() {
        if game.placeSelected() {
            publishHUD()
        }
    }

    func toggleFly() {
        game.toggleFlying()
        publishHUD()
    }

    func respawn() {
        game.respawn()
        publishHUD()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused { saveNow() }
    }

    // MARK: - Saving

    @discardableResult
    func saveNow() -> Bool {
        let saved = store.save(game.makeSave(), id: saveID)
        if saved {
            showToast("Kaydedildi")
        } else {
            showToast("Kaydedilemedi")
        }
        return saved
    }

    func saveAndExit() {
        _ = saveNow()
        stop()
        renderer.reset()
        onRequestExit?()
    }

    func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            if self?.toast == text {
                self?.toast = nil
            }
        }
    }
}
