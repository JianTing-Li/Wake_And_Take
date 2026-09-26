//
//  QRCodeGenerator.swift
//  WalkAndTakeKit
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Renders a pickup code as a crisp QR image for the pickup screen.
public enum QRCodeGenerator {
    /// A QR image scaled up by `scale` pixels per module, or nil if rendering fails.
    public static func image(for text: String, scale: CGFloat = 10) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
