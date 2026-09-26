//
//  QRCodeView.swift
//  WalkAndTakeKit
//

import Platform
import SwiftUI

/// A crisp QR image of a pickup code, for staff to scan.
struct QRCodeView: View {
    let text: String
    var size: CGFloat = 160

    var body: some View {
        Group {
            if let image = QRCodeGenerator.image(for: text) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode").resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("QR code for pickup code \(text.map(String.init).joined(separator: " "))")
    }
}
