//
//  PickupCodeGenerator.swift
//  WakeAndTakeKit
//

import Foundation

public protocol PickupCodeGenerator: Sendable {
    func makeCode() -> String
}

/// Random 4-character codes without look-alike characters (no I, O, 0, 1).
public struct RandomPickupCodeGenerator: PickupCodeGenerator {
    public static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    public static let length = 4

    public init() {}

    public func makeCode() -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<Self.length).map { _ in Self.alphabet.randomElement(using: &generator)! })
    }
}
