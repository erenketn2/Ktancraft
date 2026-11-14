//  Block.swift
//  Ktancraft — engine core
//  Ktan Labs

import Foundation

/// Every block Ktancraft knows about. Raw values are what the save file and the
/// chunk storage hold, so never renumber an existing case.
public enum Block: UInt8, CaseIterable, Codable {
    case air = 0
    case stone = 1
    case dirt = 2
    case grass = 3
    case sand = 4
    case sandstone = 5
    case log = 6
    case leaves = 7
    case planks = 8
    case cobblestone = 9
    case glass = 10
    case water = 11
    case snow = 12
    case bedrock = 13

    /// Can the player stand on it / walk into it?
    public var isSolid: Bool {
        switch self {
        case .air, .water:
            return false
        default:
            return true
        }
    }

    /// Does it completely block the view of the face behind it?
    public var isOpaque: Bool {
        switch self {
        case .air, .water, .glass, .leaves:
            return false
        default:
            return true
        }
    }

    /// Should the neighbouring block's face be drawn when it touches this one?
    public func hidesFaceOf(_ other: Block) -> Bool {
        if self == .air { return false }
        if self == other { return true }
        return isOpaque
    }

    /// Seconds to break by hand. `.infinity` means unbreakable.
    public var hardness: Float {
        switch self {
        case .air: return 0
        case .stone, .cobblestone: return 1.5
        case .dirt, .grass, .sand: return 0.55
        case .sandstone: return 1.2
        case .log, .planks: return 1.1
        case .leaves: return 0.25
        case .glass: return 0.3
        case .water: return 0
        case .snow: return 0.3
        case .bedrock: return .infinity
        }
    }

    public var isBreakable: Bool { self != .air && self != .water && self != .bedrock }

    /// Blocks the light and the sun, used by the mesher's face lighting.
    public var blocksSky: Bool { isOpaque }

    /// Top, side and bottom look different, so the mesher keeps their faces
    /// in separate vertex buffers with their own material.
    public var hasDistinctFaces: Bool {
        switch self {
        case .grass, .log, .sandstone:
            return true
        default:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .air: return "Hava"
        case .stone: return "Taş"
        case .dirt: return "Toprak"
        case .grass: return "Çimen"
        case .sand: return "Kum"
        case .sandstone: return "Kumtaşı"
        case .log: return "Kütük"
        case .leaves: return "Yaprak"
        case .planks: return "Tahta"
        case .cobblestone: return "Parke Taşı"
        case .glass: return "Cam"
        case .water: return "Su"
        case .snow: return "Kar"
        case .bedrock: return "Ana Kaya"
        }
    }
}
