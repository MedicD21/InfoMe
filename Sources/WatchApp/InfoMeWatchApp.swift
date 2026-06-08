import SwiftUI
import InfoMeKit

@main
struct InfoMeWatchApp: App {
    @StateObject private var store = CardStore.shared
    @StateObject private var syncCoordinator = CardSyncCoordinator.shared
    @StateObject private var navigationCoordinator = AppNavigationCoordinator.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(navigationCoordinator)
                .task {
                    syncCoordinator.activate()
                }
                // The complication and `OpenCardIntent` both resolve to
                // `infome://share` — registered as a URL type below — so a
                // single tap on the watch face lands on the big QR page.
                .onOpenURL { url in
                    if url.host == "share" {
                        navigationCoordinator.requestShareScreen()
                    }
                }
        }
    }
}
