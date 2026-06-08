import SwiftUI
import InfoMeKit

/// Full-bleed, high-contrast QR code sized for a 41/45/49mm display — the
/// entire point of the watch app: raise your wrist, someone scans it, done.
/// No chrome, no scrolling, nothing between "look at watch" and "scan complete".
struct WatchQRView: View {
    @EnvironmentObject private var store: CardStore

    var body: some View {
        VStack(spacing: 8) {
            if let shortCode = store.shortCode {
                QRCodeView(
                    payload: CardLinkConfiguration.shareURL(shortCode: shortCode).absoluteString,
                    theme: store.card.theme,
                    size: qrSize
                )
            } else {
                // No short code synced yet (first launch before the phone app
                // has published) — fall back to the fully self-contained
                // offline payload so the watch is never without something to show.
                offlineQR
            }

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

    @ViewBuilder
    private var offlineQR: some View {
        if let encoded = try? CardLinkCodec.encode(store.card) {
            QRCodeView(
                payload: CardLinkConfiguration.offlineShareURL(encodedCard: encoded).absoluteString,
                theme: store.card.theme,
                size: qrSize
            )
        } else {
            ProgressView()
        }
    }
}

#if DEBUG
#Preview {
    WatchQRView().environmentObject(CardStore.shared)
}
#endif
