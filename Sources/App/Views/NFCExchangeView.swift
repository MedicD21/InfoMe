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
                    Text("Hold your iPhone near another InfoMe NFC tag (or any tag carrying an InfoMe link) to instantly open their card.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                statusView

                Button {
                    reader.readTag()
                } label: {
                    Label(isReading ? "Listening…" : "Start Reading", systemImage: "wave.3.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isReading)
                .padding(.horizontal, 32)

                if !reader.isAvailable {
                    Label("This device doesn't support NFC tag reading.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Spacer()
            }
            .padding(.top, 48)
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
