//  Math.swift
//  Ktancraft — engine core
//  Ktan Labs
//
//  Platform independent math. No simd, no CoreGraphics, so this file also
//  compiles and runs on the Linux test harness.

import Foundation

public struct Vec3: Equatable {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(_ x: Float = 0, _ y: Float = 0, _ z: Float = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vec3(0, 0, 0)
    public static let up = Vec3(0, 1, 0)

    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static func * (a: Vec3, s: Float) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    public static func * (s: Float, a: Vec3) -> Vec3 { a * s }
    public static func / (a: Vec3, s: Float) -> Vec3 { Vec3(a.x / s, a.y / s, a.z / s) }
    public static prefix func - (a: Vec3) -> Vec3 { Vec3(-a.x, -a.y, -a.z) }

    public static func += (a: inout Vec3, b: Vec3) { a = a + b }
    public static func -= (a: inout Vec3, b: Vec3) { a = a - b }

    public var lengthSquared: Float { x * x + y * y + z * z }
    public var length: Float { (x * x + y * y + z * z).squareRoot() }

    public func normalized() -> Vec3 {
        let l = length
        return l > 0.00001 ? self / l : .zero
    }

    public func dot(_ other: Vec3) -> Float {
        x * other.x + y * other.y + z * other.z
    }

    public func cross(_ other: Vec3) -> Vec3 {
        Vec3(y * other.z - z * other.y,
             z * other.x - x * other.z,
             x * other.y - y * other.x)
    }

    public func component(_ axis: Int) -> Float {
        switch axis {
        case 0: return x
        case 1: return y
        default: return z
        }
    }

    public mutating func setComponent(_ axis: Int, _ value: Float) {
        switch axis {
        case 0: x = value
        case 1: y = value
        default: z = value
        }
    }

    public func offset(_ axis: Int, _ amount: Float) -> Vec3 {
        var copy = self
        copy.setComponent(axis, copy.component(axis) + amount)
        return copy
    }
}

public struct IVec3: Hashable {
    public var x: Int32
    public var y: Int32
    public var z: Int32

    public init(_ x: Int32 = 0, _ y: Int32 = 0, _ z: Int32 = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = IVec3(0, 0, 0)

    public func offset(_ a: IVec3) -> IVec3 { IVec3(x + a.x, y + a.y, z + a.z) }
}

public struct AABB {
    public var min: Vec3
    public var max: Vec3

    public init(min: Vec3, max: Vec3) {
        self.min = min
        self.max = max
    }

    public func intersects(_ other: AABB) -> Bool {
        min.x < other.max.x && max.x > other.min.x &&
        min.y < other.max.y && max.y > other.min.y &&
        min.z < other.max.z && max.z > other.min.z
    }
}

public enum MathUtil {
    public static func clamp(_ value: Float, _ low: Float, _ high: Float) -> Float {
        min(max(value, low), high)
    }

    public static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }

    /// Deterministic 64 bit hash. Same value on every device and on Linux.
    public static func hash(_ a: Int64, _ b: Int64, _ seed: UInt64) -> UInt64 {
        var h = seed &+ 0x9E37_79B9_7F4A_7C15
        h ^= UInt64(bitPattern: a) &* 0xD6E8_FEB8_6659_FD93
        h = (h ^ (h >> 32)) &* 0xFF51_AFD7_ED55_8CCD
        h ^= UInt64(bitPattern: b) &* 0xC4CE_B9FE_1A85_EC53
        h = (h ^ (h >> 33)) &* 0xC2B2_AE3D_27D4_EB4F
        h ^= h >> 29
        return h
    }

    /// Value in 0..<1 from a hash.
    public static func unit(_ a: Int64, _ b: Int64, _ seed: UInt64) -> Float {
        Float(hash(a, b, seed) >> 11) / Float(1 << 53)
    }
}
