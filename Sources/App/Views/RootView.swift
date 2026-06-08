import SwiftUI
import InfoMeKit

private enum Tab: Hashable {
    case share, card, nfc
}

struct RootView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var incomingLinkRouter: IncomingLinkRouter
    @EnvironmentObject private var cloudSync: CardSyncCoordinator
    @StateObject private var navigationCoordinator = AppNavigationCoordinator.shared

    @State private var selectedTab: Tab = .share

    var body: some View {
        TabView(selection: $selectedTab) {
            ShareHubView()
                .tabItem { Label("Share", systemImage: "qrcode") }
                .tag(Tab.share)

            EditCardView()
                .tabItem { Label("My Card", systemImage: "person.text.rectangle") }
                .tag(Tab.card)

            NFCExchangeView()
                .tabItem { Label("NFC", systemImage: "wave.3.right.circle") }
                .tag(Tab.nfc)
        }
        .tint(store.card.theme.accentColor)
        .sheet(isPresented: $incomingLinkRouter.isPresentingScannedCard) {
            ScannedCardSheet()
        }
        // Lets `OpenCardIntent` (Action Button / Siri / Shortcuts / complications)
        // jump straight to the QR screen the instant the app comes to the foreground.
        .onChange(of: navigationCoordinator.pendingDestination) { _, destination in
            guard let destination else { return }
            switch destination {
            case .shareScreen: selectedTab = .share
            }
            _ = navigationCoordinator.consumePendingDestination()
        }
        .onAppear {
            if navigationCoordinator.consumePendingDestination() == .shareScreen {
                selectedTab = .share
            }
        }
        // Keep the Watch app's mirrored copy current after every edit.
        .onChange(of: store.card) { _, _ in
            cloudSync.pushCurrentCard()
        }
    }
}

/// Shown when the user scans/taps *someone else's* card from inside the app —
/// renders the exact same `LinktreeMenuView` they'd see in the App Clip.
private struct ScannedCardSheet: View {
    @EnvironmentObject private var incomingLinkRouter: IncomingLinkRouter
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var contactToSave: ContactCard?

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            incomingLinkRouter.dismiss()
                            dismiss()
                        }
                    }
                }
        }
        .sheet(item: $contactToSave) { card in
            VCardExporter.AddToContactsSheet(card: card) { contactToSave = nil }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch incomingLinkRouter.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView("Loading card…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView("Couldn't load this card", systemImage: "qrcode.viewfinder", description: Text(message))
        case .loaded(let card):
            LinktreeMenuView(
                card: card,
                onSaveToContacts: { contactToSave = card },
                onOpenSocial: { SocialLinkOpener.open($0, using: openURL) }
            )
        }
    }
}
