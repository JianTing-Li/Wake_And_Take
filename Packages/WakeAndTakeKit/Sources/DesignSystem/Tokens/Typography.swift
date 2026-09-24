//
//  Typography.swift
//  WakeAndTakeKit
//

import SwiftUI

extension Font {
    /// Big monospaced pickup code, e.g. on confirmation and pickup screens.
    public static func pickupCode(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }

    /// Rounded brand type used by the splash.
    public static func brand(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
