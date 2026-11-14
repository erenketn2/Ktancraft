//  AppState.swift
//  Ktancraft
//  Ktan Labs

import Foundation
import SwiftUI

/// One saved world on this device.
struct WorldSummary: Identifiable, Equatable {
    let id: String
    var name: String
    var seed: UInt64
    var savedAt: Date
    var editCount: Int
}

/// What the root view needs to open a game.
struct GameLaunch: Identifiable {
    let id = UUID()
    var saveID: String
    var seed: UInt64
    var name: String
    var existing: SaveFile?
}

/// Worlds live in Documents/Ktancraft as small .ktc files: a seed plus the
/// player's edits.
final class WorldStore {
    static let shared = WorldStore()

    private let fileManager = FileManager.default

    private var directory: URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Ktancraft", isDirectory: true)
    }

    private func ensureDirectory() {
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("ktc")
    }

    func list() -> [WorldSummary] {
        ensureDirectory()
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var result: [WorldSummary] = []
        for file in files where file.pathExtension == "ktc" {
            guard let data = try? Data(contentsOf: file), let save = SaveFile.decode(data) else { continue }
            result.append(WorldSummary(id: file.deletingPathExtension().lastPathComponent,
                                       name: save.name,
                                       seed: save.seed,
                                       savedAt: Date(timeIntervalSince1970: save.savedAt),
                                       editCount: save.edits.count))
        }
        return result.sorted { $0.savedAt > $1.savedAt }
    }

    func load(id: String) -> SaveFile? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return SaveFile.decode(data)
    }

    @discardableResult
    func save(_ save: SaveFile, id: String) -> Bool {
        ensureDirectory()
        guard let data = save.encoded() else { return false }
        do {
            try data.write(to: url(for: id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func delete(id: String) {
        try? fileManager.removeItem(at: url(for: id))
    }

    /// A brand new world: only the seed is stored, the terrain is generated when
    /// the world is opened.
    func create(name: String, seed: UInt64) -> (id: String, save: SaveFile)? {
        ensureDirectory()
        let id = UUID().uuidString
        var player = Player()
        player.position = Vec3(0.5, Float(seaLevel + 2), 0.5)
        let file = SaveFile(seed: seed, name: name, player: player, inventory: Inventory(), edits: [])
        guard self.save(file, id: id) else { return nil }
        return (id, file)
    }
}

/// Render distance and look sensitivity, remembered between launches.
final class GameSettings: ObservableObject {
    private enum Keys {
        static let renderDistance = "ktancraft.renderDistance"
        static let sensitivity = "ktancraft.sensitivity"
    }

    @Published var renderDistance: Int {
        didSet { UserDefaults.standard.set(renderDistance, forKey: Keys.renderDistance) }
    }

    @Published var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: Keys.sensitivity) }
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: Keys.renderDistance)
        renderDistance = stored == 0 ? 5 : min(max(stored, 3), 8)
        let storedSensitivity = UserDefaults.standard.double(forKey: Keys.sensitivity)
        sensitivity = storedSensitivity == 0 ? 1.0 : min(max(storedSensitivity, 0.4), 2.5)
    }
}
