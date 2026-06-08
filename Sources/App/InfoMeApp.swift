import SwiftUI
import InfoMeKit

@main
struct InfoMeApp: App {
    @StateObject private var store = CardStore.shared
    @StateObject private var syncCoordinator = CardSyncCoordinator.shared
    @StateObject private var incomingLinkRouter = IncomingLinkRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(incomingLinkRouter)
                .environmentObject(syncCoordinator)
                .preferredColorScheme(.dark)
                .task {
                    syncCoordinator.activate()
                }
                .onOpenURL { url in
                    incomingLinkRouter.handle(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        incomingLinkRouter.handle(url)
                    }
                }
        }
    }
}
