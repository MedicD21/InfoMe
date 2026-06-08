#if canImport(WatchConnectivity)
import WatchConnectivity
import Foundation

/// Pushes the latest `ContactCard` from iPhone → Apple Watch (and vice versa,
/// for the rare case the user edits from their wrist) over `WatchConnectivity`,
/// so `WatchQRView` can render instantly without waiting on a network round-trip.
///
/// Uses `updateApplicationContext`, which is the right tool for "always keep
/// the counterpart's copy of the latest state" — the system coalesces updates
/// and delivers the most recent one even if the counterpart wasn't reachable
/// when it was sent.
@MainActor
public final class CardSyncCoordinator: NSObject, ObservableObject {
    public static let shared = CardSyncCoordinator()

    private let store: CardStore

    public init(store: CardStore = .shared) {
        self.store = store
        super.init()
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Call after every local save so the counterpart device picks up the change.
    public func pushCurrentCard() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(store.card) else { return }
        var context: [String: Any] = ["card": data]
        if let shortCode = store.shortCode { context["shortCode"] = shortCode }
        try? WCSession.default.updateApplicationContext(context)
    }

    private func ingest(_ context: [String: Any]) {
        guard
            let data = context["card"] as? Data,
            let card = try? JSONDecoder().decode(ContactCard.self, from: data)
        else { return }

        Task { @MainActor in
            store.save(card)
            if let shortCode = context["shortCode"] as? String {
                store.setShortCode(shortCode)
            }
        }
    }
}

extension CardSyncCoordinator: WCSessionDelegate {
    public nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            Task { @MainActor in self.pushCurrentCard() }
        }
    }

    public nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.ingest(applicationContext) }
    }

    #if os(iOS)
    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
