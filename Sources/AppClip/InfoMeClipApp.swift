import SwiftUI
import InfoMeKit

@main
struct InfoMeClipApp: App {
    @StateObject private var viewModel = ClipViewModel()

    var body: some Scene {
        WindowGroup {
            ClipRootView()
                .environmentObject(viewModel)
                // App Clips are launched *by* a URL — there's no "open the
                // app and look around" step. Both invocation paths funnel
                // into the same resolver so a QR scan and an NFC tap behave
                // identically.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        viewModel.resolve(url: url)
                    }
                }
                .onOpenURL { url in
                    viewModel.resolve(url: url)
                }
        }
    }
}
