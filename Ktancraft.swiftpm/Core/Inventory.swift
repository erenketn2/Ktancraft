//  Inventory.swift
//  Ktancraft — engine core
//  Ktan Labs

import Foundation

public struct Inventory: Codable {
    public var slots: [UInt8]
    public var selected: Int

    public static let defaultSlots: [UInt8] = [
        Block.grass.rawValue,
        Block.dirt.rawValue,
        Block.stone.rawValue,
        Block.cobblestone.rawValue,
        Block.sand.rawValue,
        Block.planks.rawValue,
        Block.log.rawValue,
        Block.glass.rawValue,
        Block.leaves.rawValue
    ]

    public init() {
        slots = Inventory.defaultSlots
        selected = 0
    }

    public static let slotCount = 9

    public mutating func select(_ index: Int) {
        guard index >= 0, index < slots.count else { return }
        selected = index
    }

    public func block(at index: Int) -> Block {
        guard index >= 0, index < slots.count else { return .air }
        return Block(rawValue: slots[index]) ?? .air
    }

    public var selectedBlock: Block { block(at: selected) }

    /// Repairs a save file with a different slot count.
    public mutating func normalize() {
        if slots.isEmpty { slots = Inventory.defaultSlots }
        while slots.count < Inventory.slotCount { slots.append(Inventory.defaultSlots[slots.count % Inventory.defaultSlots.count]) }
        if slots.count > Inventory.slotCount { slots = Array(slots.prefix(Inventory.slotCount)) }
        selected = min(max(selected, 0), slots.count - 1)
    }
}
