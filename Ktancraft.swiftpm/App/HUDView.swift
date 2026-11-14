//  HUDView.swift
//  Ktancraft
//  Ktan Labs
//
//  Everything drawn over the 3D view: crosshair, mining ring, coordinates, the
//  hotbar and the action buttons. All of it is sized from the safe area so it
//  clears the notch, the home indicator and the rounded corners.

import SwiftUI

struct HUDView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let slot = min(36, max(26, w * 0.045))

            ZStack(alignment: .topLeading) {
                crosshair
                    .position(x: w / 2, y: h / 2)

                infoBadge
                    .padding(8)
                    .position(x: 96, y: 26)

                topButton(system: "pause.fill", size: 46) {
                    model.togglePause()
                }
                .position(x: w - 34, y: 28)

                topButton(system: model.hud.flying ? "airplane.circle.fill" : "airplane", size: 46) {
                    model.toggleFly()
                }
                .position(x: w - 88, y: 28)

                hotbar(slot: slot)
                    .position(x: w / 2, y: h - slot / 2 - 8)

                HoldButton(system: "hammer.fill", size: 86) { pressed in
                    model.miningHeld = pressed
                }
                .position(x: w - 60, y: h - 62)

                TapButton(system: "cube.fill", size: 64) {
                    model.place()
                }
                .position(x: w - 152, y: h - 50)

                HoldButton(system: "arrow.up", size: 66) { pressed in
                    model.jumpHeld = pressed
                }
                .position(x: w - 62, y: h - 150)

                if model.hud.flying {
                    HoldButton(system: "arrow.down", size: 56) { pressed in
                        model.descendHeld = pressed
                    }
                    .position(x: w - 150, y: h - 132)
                }

                if !model.hud.ready {
                    Text("Dünya hazırlanıyor…")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .position(x: w / 2, y: h / 2 - 44)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
    }

    // MARK: - Pieces

    private var crosshair: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .frame(width: 18, height: 18)
            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 1.5, height: 9)
            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 9, height: 1.5)
            if model.hud.miningProgress > 0.01 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(model.hud.miningProgress, 1)))
                    .stroke(Color(red: 0.55, green: 0.95, blue: 0.45), lineWidth: 4)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 44, height: 44)
    }

    private var infoBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("X \(model.hud.x)   Y \(model.hud.y)   Z \(model.hud.z)")
            Text("\(model.hud.fps) FPS\(model.hud.flying ? "   ·   Uçuş" : "")")
                .foregroundColor(.white.opacity(0.7))
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
    }

    private func hotbar(slot: CGFloat) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<model.hud.slots.count, id: \.self) { index in
                let block = Block(rawValue: model.hud.slots[index]) ?? .stone
                let selected = index == model.hud.selected
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(selected ? 0.55 : 0.30))
                    Image(uiImage: BlockIcon.image(for: block))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: slot - 10, height: slot - 10)
                }
                .frame(width: slot, height: slot)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color.white : Color.white.opacity(0.3),
                                lineWidth: selected ? 2 : 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .onTapGesture {
                    model.selectSlot(index)
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.22)))
    }

    private func topButton(system: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.black.opacity(0.35))
                Circle().stroke(Color.white.opacity(0.45), lineWidth: 1.5)
                Image(systemName: system)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}

/// Press and hold, used for mining and jumping.
struct HoldButton: View {
    let system: String
    let size: CGFloat
    let action: (Bool) -> Void

    @State private var pressed = false

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(pressed ? 0.5 : 0.3))
            Circle().stroke(Color.white.opacity(pressed ? 0.85 : 0.5), lineWidth: 2)
            Image(systemName: system)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        pressed = true
                        action(true)
                    }
                }
                .onEnded { _ in
                    pressed = false
                    action(false)
                }
        )
    }
}

/// Tap once, used for placing blocks.
struct TapButton: View {
    let system: String
    let size: CGFloat
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(pressed ? 0.5 : 0.3))
            Circle().stroke(Color.white.opacity(0.5), lineWidth: 2)
            Image(systemName: system)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in
                    pressed = false
                    action()
                }
        )
    }
}
