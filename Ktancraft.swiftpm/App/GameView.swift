//  GameView.swift
//  Ktancraft
//  Ktan Labs

import SwiftUI

struct GameView: View {
    @StateObject private var model: GameModel
    @Environment(\.scenePhase) private var scenePhase

    private let onExit: () -> Void

    init(launch: GameLaunch, settings: GameSettings, onExit: @escaping () -> Void) {
        _model = StateObject(wrappedValue: GameModel(launch: launch, settings: settings))
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            GameSceneView(model: model)
                .ignoresSafeArea()

            HUDView(model: model)

            if model.isPaused {
                PauseOverlay(model: model, onExit: onExit)
            }

            if let toast = model.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .padding(.bottom, 70)
                }
                .allowsHitTesting(false)
            }
        }
        .background(Color.black)
        .onAppear {
            model.onRequestExit = onExit
            model.start()
        }
        .onDisappear {
            model.stop()
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                _ = model.saveNow()
            }
        }
    }
}

struct PauseOverlay: View {
    @ObservedObject var model: GameModel
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ktancraft")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("Ktan Labs tarafından geliştirildi")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Button("Devam Et") {
                            model.togglePause()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.28, green: 0.62, blue: 0.30))
                    }

                    Divider().background(Color.white.opacity(0.2))

                    HStack(spacing: 12) {
                        actionButton("Kaydet", system: "square.and.arrow.down") {
                            _ = model.saveNow()
                        }
                        actionButton("Doğduğun yere dön", system: "location.fill") {
                            model.respawn()
                            model.togglePause()
                        }
                        actionButton(model.hud.flying ? "Uçuşu Kapat" : "Uçuşu Aç", system: "airplane") {
                            model.toggleFly()
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Görüş mesafesi: \(model.settings.renderDistance) chunk")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                        Slider(value: Binding(
                            get: { Double(model.settings.renderDistance) },
                            set: { model.settings.renderDistance = Int($0.rounded()) }
                        ), in: 3...8, step: 1)
                        .tint(Color(red: 0.45, green: 0.80, blue: 0.45))

                        Text("Bakış hassasiyeti: \(String(format: "%.1f", model.settings.sensitivity))x")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                        Slider(value: Binding(
                            get: { model.settings.sensitivity },
                            set: { model.settings.sensitivity = $0 }
                        ), in: 0.4...2.5)
                        .tint(Color(red: 0.45, green: 0.80, blue: 0.45))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nasıl oynanır")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Sol yarı: parmağını sürükle, yürü. Sağ yarı: sürükle, etrafına bak. Çekiç tuşunu basılı tut: bloğu kır. Küp tuşu: seçili bloğu koy. Yukarı ok: zıpla. Uçak tuşu: uçuşu aç/kapat. Alt sıradaki bloklara dokunarak seçim yap.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(role: .destructive) {
                        model.saveAndExit()
                    } label: {
                        Text("Kaydet ve Çık")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Text("Dünya: \(model.game.name)   ·   Tohum: \(String(model.game.seed))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.10, green: 0.13, blue: 0.19).opacity(0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(20)
            }
        }
    }

    private func actionButton(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: system)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
