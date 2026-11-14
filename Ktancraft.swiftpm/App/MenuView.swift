//  MenuView.swift
//  Ktancraft
//  Ktan Labs

import SwiftUI

struct MenuView: View {
    @ObservedObject var settings: GameSettings
    var onStart: (GameLaunch) -> Void

    @State private var worlds: [WorldSummary] = []
    @State private var showingNewWorld = false
    @State private var showingHelp = false
    @State private var newName = ""
    @State private var newSeed = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.11, blue: 0.17),
                                    Color(red: 0.10, green: 0.22, blue: 0.20),
                                    Color(red: 0.05, green: 0.09, blue: 0.13)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 22) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        newWorldButton
                        settingsPanel
                        helpButton
                    }
                    .padding(18)
                }
                .frame(maxWidth: 380)

                ScrollView(showsIndicators: false) {
                    worldsPanel
                        .padding(18)
                }
            }
            .padding(14)
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingNewWorld) { newWorldSheet }
        .sheet(isPresented: $showingHelp) { helpSheet }
    }

    // MARK: - Left column

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KTANCRAFT")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Ktan Labs tarafından geliştirildi")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.55, green: 0.90, blue: 0.58))
            Text("Cebinde sonsuz bir dünya. Kaz, inşa et, keşfet.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var newWorldButton: some View {
        Button {
            newName = "Dünya \(worlds.count + 1)"
            newSeed = ""
            showingNewWorld = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Yeni Dünya")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.24, green: 0.60, blue: 0.31))
            )
        }
        .buttonStyle(.plain)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ayarlar")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            Text("Görüş mesafesi: \(settings.renderDistance) chunk")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Slider(value: Binding(
                get: { Double(settings.renderDistance) },
                set: { settings.renderDistance = Int($0.rounded()) }
            ), in: 3...8, step: 1)
            .tint(Color(red: 0.45, green: 0.80, blue: 0.45))

            Text("Bakış hassasiyeti: \(String(format: "%.1f", settings.sensitivity))x")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Slider(value: Binding(
                get: { settings.sensitivity },
                set: { settings.sensitivity = $0 }
            ), in: 0.4...2.5)
            .tint(Color(red: 0.45, green: 0.80, blue: 0.45))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
    }

    private var helpButton: some View {
        Button {
            showingHelp = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                Text("Nasıl oynanır")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Right column

    private var worldsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dünyaların")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if worlds.isEmpty {
                Text("Henüz bir dünya yok. “Yeni Dünya” ile başla.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 8)
            }

            ForEach(worlds) { world in
                Button {
                    open(world)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.30, green: 0.55, blue: 0.28))
                            Image(systemName: "square.grid.3x3.fill")
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(world.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("Tohum \(String(world.seed))  ·  \(world.editCount) değişiklik  ·  \(formatted(world.savedAt))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(red: 0.55, green: 0.90, blue: 0.58))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        WorldStore.shared.delete(id: world.id)
                        reload()
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.red.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sheets

    private var newWorldSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Yeni Dünya")
                .font(.system(size: 24, weight: .heavy, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                Text("Dünya adı").font(.system(size: 12, weight: .semibold))
                TextField("Dünya", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tohum (boş bırakırsan rastgele)").font(.system(size: 12, weight: .semibold))
                TextField("ör. 1234567", text: $newSeed)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled(true)
            }

            Text("Aynı tohum her zaman aynı dünyayı üretir: arkadaşınla aynı tohumu paylaş, aynı yeri kaz.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Button("Vazgeç") { showingNewWorld = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Başla") { createWorld() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.28, green: 0.62, blue: 0.30))
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
    }

    private var helpSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ktancraft nasıl oynanır")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))

                helpRow("hand.draw", "Sol yarıda parmağını sürükle: yürü. Parmağı nereye koyarsan joystick orada belirir.")
                helpRow("eye", "Sağ yarıda sürükle: etrafına bak.")
                helpRow("hammer", "Çekiç tuşunu basılı tut: baktığın bloğu kır. Sert bloklar daha uzun sürer.")
                helpRow("cube", "Küp tuşu: seçili bloğu baktığın yüzeye koy.")
                helpRow("arrow.up", "Yukarı ok: zıpla. Su içinde yüz.")
                helpRow("airplane", "Uçak: uçuşu aç. Uçarken yukarı ok yükselir, aşağı ok alçalır.")
                helpRow("square.grid.3x3", "Alttaki çubuktan blok seç; cam, taş, tahta, yaprak ve daha fazlası var.")
                helpRow("sun.max", "Gün ve gece kendi kendine döner. Dünya otomatik kaydedilir.")

                Text("Ktancraft · 1.0 · Ktan Labs tarafından geliştirildi")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
            }
            .padding(24)
        }
    }

    private func helpRow(_ system: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 22)
                .foregroundColor(Color(red: 0.24, green: 0.55, blue: 0.30))
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func reload() {
        worlds = WorldStore.shared.list()
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM HH:mm"
        return formatter.string(from: date)
    }

    private func seedValue() -> UInt64 {
        let trimmed = newSeed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return UInt64.random(in: 1...9_999_999_999)
        }
        if let numeric = UInt64(trimmed) {
            return numeric
        }
        // Words work as seeds too, through the engine's own hash.
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in trimmed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3
        }
        return hash == 0 ? 42 : hash
    }

    private func createWorld() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? "Dünya \(worlds.count + 1)" : name
        guard let created = WorldStore.shared.create(name: finalName, seed: seedValue()) else {
            errorMessage = "Dünya oluşturulamadı. Cihazda yer var mı?"
            return
        }
        showingNewWorld = false
        errorMessage = nil
        reload()
        onStart(GameLaunch(saveID: created.id, seed: created.save.seed,
                           name: created.save.name, existing: created.save))
    }

    private func open(_ world: WorldSummary) {
        guard let save = WorldStore.shared.load(id: world.id) else {
            errorMessage = "Bu dünya açılamadı."
            reload()
            return
        }
        onStart(GameLaunch(saveID: world.id, seed: save.seed, name: save.name, existing: save))
    }
}
