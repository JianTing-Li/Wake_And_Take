//
//  Money+Display.swift
//  WakeAndTakeKit
//
//  The UI edge: the only place cents become "$5.99".
//

import Domain
import Foundation

extension Money {
    /// "$5.99"
    public var usd: String {
        decimalDollars.formatted(.currency(code: "USD"))
    }
}
