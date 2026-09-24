//
//  Spacing.swift
//  WakeAndTakeKit
//

import SwiftUI

/// Spacing steps used across screens.
public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let s: CGFloat = 10
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
}

/// Corner radii used across cards and tiles.
public enum Radius {
    /// Category tiles in rows.
    public static let tile: CGFloat = 10
    /// Larger category tiles (map card).
    public static let largeTile: CGFloat = 12
    /// Info panels and code boxes.
    public static let panel: CGFloat = 14
    /// Cards.
    public static let card: CGFloat = 16
    /// Floating map card.
    public static let floating: CGFloat = 18
}
