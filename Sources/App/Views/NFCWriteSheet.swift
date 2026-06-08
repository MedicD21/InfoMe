import SwiftUI
import InfoMeKit

/// Walks the user through writing their share link to a physical NFC tag:
/// shows the live session phase (`waitingForTag` → `writing` → `success`)
/// with friendly copy at each step, since Core NFC's system sheet alone can
/// feel a bit cryptic to people who've never programmed a tag before.
struct NFCWriteSheet: View {
    @ObservedObject var writer: NFCCardWriter
    let url: URL?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                phaseIcon
                phaseText
                Spacer()
                primaryButton
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
            .background {
                ZStack {
                    Color.black
                    CardTheme.midnight.backgroundGradient.opacity(0.22)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Write NFC Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        writer.cancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(isBusy)
    }

    private var isBusy: Bool {
        switch writer.phase {
        case .waitingForTag, .writing: return true
        default: return false
        }
    }

    @ViewBuilder
    private var phaseIcon: some View {
        switch writer.phase {
        case .idle:
            Image(systemName: "wave.3.right.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
        case .waitingForTag:
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 64))
                .symbolEffect(.pulse)
                .foregroundStyle(.tint)
        case .writing:
            ProgressView().controlSize(.large)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
        case .readURL:
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
        }
    }

    private var phaseText: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch writer.phase {
        case .idle: return "Ready to write"
        case .waitingForTag: return "Hold near a tag"
        case .writing: return "Writing…"
        case .success: return "Done!"
        case .readURL: return "Tag read"
        case .failed: return "Something went wrong"
        }
    }

    private var message: String {
        switch writer.phase {
        case .idle:
            return "Grab a blank NFC sticker or card (NTAG213/215 work great — they cost pennies), hold it near the top of your iPhone, and tap below."
        case .waitingForTag(let prompt):
            return prompt
        case .writing:
            return "Don't move your iPhone — writing your link to the tag now."
        case .success(let detail):
            return detail
        case .readURL(let url):
            return "This tag points to: \(url.absoluteString)"
        case .failed(let reason):
            return reason
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch writer.phase {
        case .idle, .failed:
            Button {
                if let url { writer.writeShareLink(url) }
            } label: {
                Label("Start Writing", systemImage: "wave.3.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(url == nil)

        case .success:
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .waitingForTag, .writing, .readURL:
            EmptyView()
        }
    }
}
