import SwiftUI
import UIKit
import InfoMeKit

/// The heart of the app: shows the owner's themed QR code, lets them publish/
/// refresh their share link, write it to an NFC tag, share it as text/AirDrop,
/// or preview exactly what a recipient will see.
struct ShareHubView: View {
    @EnvironmentObject private var store: CardStore
    @StateObject private var viewModel = ShareHubViewModel()
    @StateObject private var nfcWriter = NFCCardWriter()

    @State private var isShowingPreview = false
    @State private var isShowingShareSheet = false
    @State private var isShowingNFCSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    qrSection
                    modePicker
                    actionButtons
                    statusBanner
                }
                .padding(20)
            }
            .background(store.card.theme.backgroundGradient.opacity(0.12).ignoresSafeArea())
            .navigationTitle("Share")
            .task { await viewModel.refreshLinkIfNeeded(card: store.card, store: store) }
            .onChange(of: store.card) { _, newCard in
                Task { await viewModel.refreshLinkIfNeeded(card: newCard, store: store) }
            }
            .sheet(isPresented: $isShowingPreview) {
                CardPreviewSheet(card: store.card)
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let url = viewModel.shareURL {
                    ActivityShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $isShowingNFCSheet) {
                NFCWriteSheet(writer: nfcWriter, url: viewModel.shareURL)
            }
        }
    }

    // MARK: - Sections

    private var qrSection: some View {
        VStack(spacing: 14) {
            if let url = viewModel.shareURL {
                QRCodeView(payload: url.absoluteString, theme: store.card.theme, size: 252)
                    .background(store.card.theme.backgroundGradient, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))

                Text(url.absoluteString)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal)
            } else if viewModel.isPublishing {
                ProgressView("Generating your link…")
                    .frame(height: 252)
            } else {
                QRCodeView(payload: "https://infome.app", theme: store.card.theme, size: 252)
                    .redacted(reason: .placeholder)
                    .frame(height: 252)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Sharing mode", selection: $viewModel.mode) {
                Text("Hosted (editable)").tag(CardShareLinkBuilder.Mode.hosted)
                Text("Offline (no iCloud)").tag(CardShareLinkBuilder.Mode.offline)
            }
            .pickerStyle(.segmented)

            Text(modeExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: viewModel.mode) { _, _ in
            Task { await viewModel.regenerateLink(card: store.card, store: store) }
        }
    }

    private var modeExplanation: String {
        switch viewModel.mode {
        case .hosted:
            return "Your QR/NFC link stays the same forever — edit your card any time and everyone's existing copy updates automatically. Requires iCloud."
        case .offline:
            return "Your whole card is packed straight into the link — no account needed, but you'll need to re-share if you ever edit it."
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            ShareActionButton(title: "Write to NFC Tag", systemImage: "wave.3.right", tint: store.card.theme.accentColor) {
                isShowingNFCSheet = true
            }
            .disabled(viewModel.shareURL == nil)

            ShareActionButton(title: "Share Link (Text, AirDrop…)", systemImage: "square.and.arrow.up", tint: store.card.theme.accentColor) {
                isShowingShareSheet = true
            }
            .disabled(viewModel.shareURL == nil)

            ShareActionButton(title: "Preview What They'll See", systemImage: "eye", tint: .secondary) {
                isShowingPreview = true
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let message = viewModel.statusMessage {
            Label(message, systemImage: viewModel.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(viewModel.isError ? .red : .green)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - View model

@MainActor
final class ShareHubViewModel: ObservableObject {
    @Published var mode: CardShareLinkBuilder.Mode = .hosted
    @Published private(set) var shareURL: URL?
    @Published private(set) var isPublishing = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var isError = false

    private var lastPublishedCardHash: Int?

    /// Publishes/encodes a link only if the card actually changed since the
    /// last time, so editing your bio doesn't spam CloudKit on every keystroke.
    func refreshLinkIfNeeded(card: ContactCard, store: CardStore) async {
        guard lastPublishedCardHash != card.hashValue else { return }
        await regenerateLink(card: card, store: store)
    }

    func regenerateLink(card: ContactCard, store: CardStore) async {
        isPublishing = true
        statusMessage = nil
        isError = false
        defer { isPublishing = false }

        do {
            let result = try await CardShareLinkBuilder.buildShareURL(
                for: card,
                mode: mode,
                existingShortCode: store.shortCode
            )
            shareURL = result.url
            if let code = result.shortCode {
                store.setShortCode(code)
            }
            syncQRImage(payload: result.url.absoluteString, store: store)
            lastPublishedCardHash = card.hashValue
            statusMessage = mode == .hosted ? "Published — your link will keep working as you edit your card." : "Ready to share — re-generate after any edits."
        } catch {
            isError = true
            statusMessage = error.localizedDescription
            // Offer a graceful downgrade: if iCloud isn't available, fall back to offline mode automatically.
            if mode == .hosted, (error as? CardCloudStore.CloudError) == .notSignedIn {
                mode = .offline
                await regenerateLink(card: card, store: store)
            }
        }
    }

    /// Renders the QR code for the freshly-built share URL (Core Image is only
    /// available here, on iOS) and syncs it to the Watch — which can't render
    /// its own — over `WatchConnectivity` via `CardSyncCoordinator`.
    private func syncQRImage(payload: String, store: CardStore) {
        guard
            let cgImage = QRCodeGenerator.image(
                for: payload,
                foreground: CGColor(gray: 0.05, alpha: 1),
                background: CGColor(gray: 1, alpha: 1)
            ),
            let pngData = UIImage(cgImage: cgImage).pngData()
        else { return }

        store.setQRCodeImage(pngData)
        CardSyncCoordinator.shared.pushCurrentCard()
    }
}

// MARK: - Small reusable pieces

private struct ShareActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
    }
}

private struct CardPreviewSheet: View {
    let card: ContactCard
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var contactToSave: ContactCard?

    var body: some View {
        NavigationStack {
            LinktreeMenuView(
                card: card,
                onSaveToContacts: { contactToSave = card },
                onOpenSocial: { SocialLinkOpener.open($0, using: openURL) }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(item: $contactToSave) { card in
            VCardExporter.AddToContactsSheet(card: card) { contactToSave = nil }
        }
    }
}

/// `UIActivityViewController` wrapper for sharing the link via Messages, Mail, AirDrop, etc.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
