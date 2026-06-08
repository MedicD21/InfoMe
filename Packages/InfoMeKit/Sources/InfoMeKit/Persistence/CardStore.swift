import Foundation
import Combine

/// The single local source of truth for "my card", persisted as JSON inside
/// the shared **App Group container** so the main app, the App Clip (for
/// "preview as recipient"), the Watch app's mirrored copy, and both widget
/// extensions can all read the same file without round-tripping to the network.
///
/// The Watch app additionally receives pushes over `WatchConnectivity` (see
/// `CardSyncCoordinator`) so it stays current even when offline; this store is
/// what that coordinator reads from / writes into on each side.
@MainActor
public final class CardStore: ObservableObject {
    public static let shared = CardStore()

    @Published public private(set) var card: ContactCard
    @Published public private(set) var shortCode: String?

    /// PNG bytes of the most recently rendered QR code. Rendered on the iPhone
    /// (the only platform where Core Image — and therefore `QRCodeGenerator` —
    /// is available) and synced to the Watch via `CardSyncCoordinator`, so
    /// `SyncedQRCodeView` has something to show without needing Core Image.
    @Published public private(set) var qrCodeImageData: Data?

    private let fileURL: URL?
    private let qrImageFileURL: URL?
    private let defaults: UserDefaults?

    private enum DefaultsKey {
        static let shortCode = "InfoMe.shortCode"
    }

    public init(appGroupIdentifier: String = CardLinkConfiguration.appGroupIdentifier) {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        self.fileURL = containerURL?.appendingPathComponent("card.json")
        self.qrImageFileURL = containerURL?.appendingPathComponent("qr.png")
        self.defaults = UserDefaults(suiteName: appGroupIdentifier)

        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ContactCard.self, from: data) {
            self.card = decoded
        } else {
            self.card = .placeholder
        }
        self.shortCode = defaults?.string(forKey: DefaultsKey.shortCode)
        if let qrImageFileURL {
            self.qrCodeImageData = try? Data(contentsOf: qrImageFileURL)
        }
    }

    /// Replaces the stored card and persists it to the App Group container.
    public func save(_ card: ContactCard) {
        self.card = card
        persist()
    }

    /// Records the CloudKit short code once the card has been published, so
    /// the share screen can render the QR/NFC payload without re-publishing
    /// on every launch.
    public func setShortCode(_ code: String) {
        shortCode = code
        defaults?.set(code, forKey: DefaultsKey.shortCode)
    }

    /// Stores the latest rendered QR PNG and persists it to the App Group
    /// container so it survives relaunch — both the side that renders it
    /// (iPhone) and the side that only displays a synced copy (Watch) call
    /// this, via `CardSyncCoordinator`.
    public func setQRCodeImage(_ data: Data?) {
        qrCodeImageData = data
        guard let qrImageFileURL else { return }
        if let data {
            try? data.write(to: qrImageFileURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: qrImageFileURL)
        }
    }

    private func persist() {
        guard let fileURL else { return }
        guard let data = try? JSONEncoder().encode(card) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
