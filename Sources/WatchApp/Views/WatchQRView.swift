import SwiftUI
import InfoMeKit

/// Full-bleed, high-contrast QR code sized for a 41/45/49mm display — the
/// entire point of the watch app: raise your wrist, someone scans it, done.
/// No chrome, no scrolling, nothing between "look at watch" and "scan complete".
struct WatchQRView: View {
    @EnvironmentObject private var store: CardStore

    var body: some View {
        VStack(spacing: 8) {
            // The watch can't render QR codes itself (no Core Image on watchOS),
            // so it just displays the PNG `CardSyncCoordinator` synced over from
            // the iPhone, which renders it via `QRCodeGenerator`.
            SyncedQRCodeView(imageData: store.qrCodeImageData, size: qrSize)

            Text(store.card.fullName)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(store.card.theme.onGradientForeground)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .containerBackground(store.card.theme.backgroundGradient, for: .tabView)
    }

    private var qrSize: CGFloat {
        #if os(watchOS)
        return 150
        #else
        return 220
        #endif
    }
}

#if DEBUG
#Preview {
    WatchQRView().environmentObject(CardStore.shared)
}
#endif
