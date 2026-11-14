//  GameSurfaceView.swift
//  Ktancraft
//  Ktan Labs
//
//  The game surface: an SCNView plus the two touch zones that make a block game
//  work on glass. Left half is a floating joystick, right half is look-drag.

import UIKit
import SceneKit
import SwiftUI

final class GameSurfaceView: UIView {
    let scnView = SCNView(frame: .zero)
    weak var model: GameModel?

    private var moveTouch: UITouch?
    private var lookTouch: UITouch?
    private var moveOrigin: CGPoint = .zero
    private var lookLast: CGPoint = .zero

    private let stickBase = UIView()
    private let stickKnob = UIView()

    private let stickRadius: CGFloat = 62
    private let knobRadius: CGFloat = 26

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor(red: 0.12, green: 0.18, blue: 0.28, alpha: 1)
        isMultipleTouchEnabled = true
        clipsToBounds = true

        scnView.frame = bounds
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.isUserInteractionEnabled = false
        addSubview(scnView)

        stickBase.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        stickBase.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        stickBase.layer.borderWidth = 2
        stickBase.layer.cornerRadius = stickRadius
        stickBase.isHidden = true
        stickBase.isUserInteractionEnabled = false

        stickKnob.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        stickKnob.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        stickKnob.layer.borderWidth = 2
        stickKnob.layer.cornerRadius = knobRadius
        stickKnob.isHidden = true
        stickKnob.isUserInteractionEnabled = false

        addSubview(stickBase)
        addSubview(stickKnob)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            model?.renderer.attachIfNeeded(to: scnView)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scnView.frame = bounds
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            if point.x < bounds.midX, moveTouch == nil {
                moveTouch = touch
                moveOrigin = point
                showStick(origin: point, knobOffset: .zero)
                model?.setJoystick(forward: 0, strafe: 0)
            } else if point.x >= bounds.midX, lookTouch == nil {
                lookTouch = touch
                lookLast = point
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            if touch === moveTouch {
                var dx = point.x - moveOrigin.x
                var dy = point.y - moveOrigin.y
                let distance = (dx * dx + dy * dy).squareRoot()
                if distance > stickRadius {
                    let scale = stickRadius / distance
                    dx *= scale
                    dy *= scale
                }
                showStick(origin: moveOrigin, knobOffset: CGPoint(x: dx, y: dy))
                model?.setJoystick(forward: Float(-dy / stickRadius), strafe: Float(dx / stickRadius))
            } else if touch === lookTouch {
                let dx = point.x - lookLast.x
                let dy = point.y - lookLast.y
                lookLast = point
                model?.look(deltaX: Float(dx), deltaY: Float(dy))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            if touch === moveTouch {
                moveTouch = nil
                stickBase.isHidden = true
                stickKnob.isHidden = true
                model?.setJoystick(forward: 0, strafe: 0)
            }
            if touch === lookTouch {
                lookTouch = nil
            }
        }
    }

    private func showStick(origin: CGPoint, knobOffset: CGPoint) {
        stickBase.isHidden = false
        stickKnob.isHidden = false
        stickBase.frame = CGRect(x: origin.x - stickRadius, y: origin.y - stickRadius,
                                 width: stickRadius * 2, height: stickRadius * 2)
        let center = CGPoint(x: origin.x + knobOffset.x, y: origin.y + knobOffset.y)
        stickKnob.frame = CGRect(x: center.x - knobRadius, y: center.y - knobRadius,
                                 width: knobRadius * 2, height: knobRadius * 2)
    }
}

struct GameSceneView: UIViewRepresentable {
    @ObservedObject var model: GameModel

    func makeUIView(context: Context) -> GameSurfaceView {
        let view = GameSurfaceView()
        view.model = model
        return view
    }

    func updateUIView(_ uiView: GameSurfaceView, context: Context) {
        uiView.model = model
    }
}
