import SwiftUI
import InfoMeKit

/// The "receive" side of NFC: read someone else's InfoMe tag (or any URL-NDEF
/// tag) and immediately resolve it to a `LinktreeMenuView`, exactly like
/// scanning a QR code would. Complements `ShareHubView`'s "write" flow so the
/// NFC tab covers both directions of the exchange.
struct NFCExchangeView: View {
    @StateObject private var reader = NFCCardWriter()
    @EnvironmentObject private var incomingLinkRouter: IncomingLinkRouter

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, isActive: isReading)

                VStack(spacing: 8) {
                    Text("Tap Someone's Tag")
                        .font(.title2.bold())
                    Text("Scan an InfoMe NFC tag to open their card.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                statusView

                Button {
                    reader.readTag()
                } label: {
                    Label(isReading ? "Scanning…" : "Scan Tag", systemImage: "wave.3.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NFCPrimaryButtonStyle())
                .disabled(isReading)
                .padding(.horizontal, 32)

                if !reader.isAvailable {
                    Label("This device doesn't support NFC tag reading.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 48)
            .background {
                ZStack {
                    Color.black
                    CardTheme.midnight.backgroundGradient.opacity(0.22)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("NFC")
            .onChange(of: reader.phase) { _, phase in
                if case .readURL(let url) = phase {
                    incomingLinkRouter.handle(url)
                }
            }
        }
    }

    private var isReading: Bool {
        if case .waitingForTag = reader.phase { return true }
        return false
    }

    @ViewBuilder
    private var statusView: some View {
        switch reader.phase {
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        case .readURL:
            Label("Card found — opening…", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)
        default:
            EmptyView()
        }
    }
}

private struct NFCPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(isEnabled ? Color.black.opacity(0.82) : Color.white.opacity(0.42))
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(isEnabled ? Color(red: 0.78, green: 0.64, blue: 1.0) : Color.white.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.28 : 0.10), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
