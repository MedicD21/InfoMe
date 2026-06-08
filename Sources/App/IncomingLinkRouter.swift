import Foundation
import InfoMeKit
import SwiftUI

/// Handles "I scanned/tapped someone *else's* InfoMe card while inside the
/// full app" — e.g. you used the in-app NFC reader, or tapped an `infome.app`
/// link in Messages while the app was already installed (so iOS opened the
/// full app instead of the App Clip). Resolves the link and surfaces the
/// scanned `LinktreeMenuView` as a sheet.
@MainActor
final class IncomingLinkRouter: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(ContactCard)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var isPresentingScannedCard = false

    func handle(_ url: URL) {
        // Don't hijack links to the owner's *own* short code — those just mean
        // "open the app", which already happened.
        guard CardLinkConfiguration.IncomingLink(url: url) != .unrecognized else { return }

        state = .loading
        isPresentingScannedCard = true

        Task {
            do {
                let card = try await CardShareLinkBuilder.resolveIncomingLink(url)
                state = .loaded(card)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func dismiss() {
        isPresentingScannedCard = false
        state = .idle
    }
}
