import SwiftUI
import InfoMeKit

/// Two-page watch experience reachable with the Digital Crown / a swipe:
/// 1. **Big QR** — the "raise your wrist, they scan it" page. This is also
///    where the complication (`InfoMeWatchWidgets`), the Action Button
///    (`OpenCardIntent` via `infome://share`), and Siri all land you, so it's page one.
/// 2. **Socials** — "show them your @handle real quick" without needing the
///    other person's camera at all.
struct WatchRootView: View {
    @EnvironmentObject private var store: CardStore
    @EnvironmentObject private var navigationCoordinator: AppNavigationCoordinator
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            WatchQRView()
                .tag(0)
            WatchSocialListView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .background(store.card.theme.backgroundGradient.ignoresSafeArea())
        .onChange(of: navigationCoordinator.pendingDestination) { _, destination in
            guard destination == .shareScreen else { return }
            selection = 0
            _ = navigationCoordinator.consumePendingDestination()
        }
        .onAppear {
            if navigationCoordinator.consumePendingDestination() == .shareScreen {
                selection = 0
            }
        }
    }
}
