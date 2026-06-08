import SwiftUI
import StoreKit
import InfoMeKit

/// The entire App Clip experience: resolve the invocation URL → render
/// `LinktreeMenuView` (the *exact* shared component the main app previews
/// with) → let the recipient save the contact or follow a social → gently
/// offer the full app for people who want to make their *own* card.
///
/// Kept intentionally to a single screen — App Clips are judged on "can a
/// stranger get value in under a few seconds", and every extra tap works
/// against that.
struct ClipRootView: View {
    @EnvironmentObject private var viewModel: ClipViewModel
    @Environment(\.openURL) private var openURL
    @State private var contactToSave: ContactCard?
    @State private var isShowingFullAppCard = false

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .resolving:
                resolvingView
            case .loaded(let card):
                LinktreeMenuView(
                    card: card,
                    onSaveToContacts: { contactToSave = card },
                    onOpenSocial: { SocialLinkOpener.open($0, using: openURL) }
                )
                .overlay(alignment: .top) { getTheAppBanner }
            case .failed(let message):
                failureView(message: message)
            }
        }
        .sheet(item: $contactToSave) { card in
            VCardExporter.AddToContactsSheet(card: card) { contactToSave = nil }
        }
        // Apple's standard "Get the full app" prompt — App Store Connect
        // controls exactly when/whether this appears based on the App Clip
        // Experience configuration.
        .appStoreOverlay(isPresented: $isShowingFullAppCard) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
    }

    private var resolvingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading card…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func failureView(message: String) -> some View {
        ContentUnavailableView {
            Label("Card Not Found", systemImage: "qrcode.viewfinder")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { viewModel.retry() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A subtle, dismissible nudge — separate from the system `appStoreOverlay`
    /// — that explains *why* someone would want the full app (to make their
    /// own card), without getting in the way of the primary "save/follow" tasks.
    private var getTheAppBanner: some View {
        Button {
            isShowingFullAppCard = true
        } label: {
            Label("Make your own InfoMe card", systemImage: "sparkles")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }
}

@MainActor
final class ClipViewModel: ObservableObject {
    enum State {
        case resolving
        case loaded(ContactCard)
        case failed(String)
    }

    @Published private(set) var state: State = .resolving
    private var lastURL: URL?

    func resolve(url: URL) {
        lastURL = url
        state = .resolving
        Task {
            do {
                let card = try await CardShareLinkBuilder.resolveIncomingLink(url)
                state = .loaded(card)
            } catch {
                state = .failed("This link doesn't seem to point to a valid InfoMe card. \(error.localizedDescription)")
            }
        }
    }

    func retry() {
        guard let lastURL else { return }
        resolve(url: lastURL)
    }
}
