import ImageIO
import SwiftUI

/// Displays a QR code PNG that was rendered on the iPhone (via `QRCodeGenerator`,
/// which needs Core Image — unavailable on watchOS) and synced to the Watch as
/// `Data` over `WatchConnectivity` by `CardSyncCoordinator`.
///
/// This is the watchOS counterpart to `QRCodeView`: same card-shaped chrome,
/// but it just decodes and displays bytes instead of generating them.
public struct SyncedQRCodeView: View {
    public let imageData: Data?
    public let size: CGFloat

    public init(imageData: Data?, size: CGFloat = 260) {
        self.imageData = imageData
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

            if let imageData, let cgImage = Self.cgImage(from: imageData) {
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
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
