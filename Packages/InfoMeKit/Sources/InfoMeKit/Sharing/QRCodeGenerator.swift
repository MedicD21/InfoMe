#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Renders crisp, themeable QR codes from a string (typically a share URL).
///
/// Uses `CIFilter.qrCodeGenerator` then `CIFilter.falseColor` to recolor the
/// black/white output to the card's theme, and scales with nearest-neighbor
/// interpolation so edges stay crisp instead of blurry.
public enum QRCodeGenerator {
    private static let context = CIContext()

    /// Generates a themed QR code image.
    /// - Parameters:
    ///   - string: Payload to encode (typically a share URL — keep it short for best scan reliability).
    ///   - foreground: Module (dot) color.
    ///   - background: Background color.
    ///   - scale: Pixel multiplier applied to the native QR matrix before returning (higher = crisper on Retina displays).
    ///   - correctionLevel: Error-correction level — "M" is a good default; use "H" if you plan to overlay a logo.
    public static func image(
        for string: String,
        foreground: CGColor = CGColor(gray: 0, alpha: 1),
        background: CGColor = CGColor(gray: 1, alpha: 1),
        scale: CGFloat = 12,
        correctionLevel: String = "M"
    ) -> CGImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue(correctionLevel, forKey: "inputCorrectionLevel")
        guard let qrImage = qrFilter.outputImage else { return nil }

        guard let colorFilter = CIFilter(name: "CIFalseColor") else { return nil }
        colorFilter.setValue(qrImage, forKey: "inputImage")
        colorFilter.setValue(CIColor(cgColor: foreground), forKey: "inputColor0")
        colorFilter.setValue(CIColor(cgColor: background), forKey: "inputColor1")
        guard let coloredImage = colorFilter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = coloredImage.transformed(by: transform)

        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }
}

/// Drop-in SwiftUI view that renders a themed QR code for a payload string,
/// with a soft card behind it so it stays scannable on any background.
public struct QRCodeView: View {
    public let payload: String
    public let theme: CardTheme
    public let size: CGFloat

    public init(payload: String, theme: CardTheme, size: CGFloat = 260) {
        self.payload = payload
        self.theme = theme
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

            if let cgImage = QRCodeGenerator.image(
                for: payload,
                foreground: CGColor(gray: 0.05, alpha: 1),
                background: CGColor(gray: 1, alpha: 1)
            ) {
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.09)
            } else {
                ProgressView()
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("QR code to share contact card")
        .accessibilityHint(payload)
    }
}
#endif
