import Foundation

/// Produces the URL that goes into the QR code / NFC tag, picking between
/// the CloudKit-backed "short code" mode (preferred — editable later, shorter
/// payload) and the fully self-contained offline mode (works without iCloud,
/// but the link *is* the data: regenerating the QR/tag is required after edits).
public enum CardShareLinkBuilder {
    public enum Mode: Equatable, Sendable {
        /// CloudKit-backed: `https://infome.app/u/<shortCode>`. Preferred —
        /// the owner can keep editing their card without reprinting/rewriting.
        case hosted
        /// Fully offline: `https://infome.app/c/<encodedCard>`. No iCloud
        /// account required; the card is baked into the link itself.
        case offline
    }

    public enum BuildError: Error, LocalizedError {
        case offlineEncodingFailed

        public var errorDescription: String? {
            switch self {
            case .offlineEncodingFailed:
                return "Couldn't pack this card into a link. Try removing the photo or shortening your bio."
            }
        }
    }

    /// Builds (and, in `.hosted` mode, publishes) the share URL for `card`.
    /// - Returns: the URL to encode into the QR/NFC payload, and — for
    ///   `.hosted` — the short code that was published, so the caller can
    ///   persist it via `CardStore.setShortCode`.
    public static func buildShareURL(
        for card: ContactCard,
        mode: Mode,
        existingShortCode: String?,
        cloudStore: CardCloudStore = .shared
    ) async throws -> (url: URL, shortCode: String?) {
        switch mode {
        case .hosted:
            let code: String
            if let existingShortCode {
                code = existingShortCode
            } else {
                code = await cloudStore.generateAvailableShortCode()
            }
            try await cloudStore.publish(card, shortCode: code)
            return (CardLinkConfiguration.shareURL(shortCode: code), code)

        case .offline:
            guard let encoded = try? CardLinkCodec.encode(card, includingAvatar: false) else {
                throw BuildError.offlineEncodingFailed
            }
            return (CardLinkConfiguration.offlineShareURL(encodedCard: encoded), nil)
        }
    }

    /// Resolves an *incoming* link (from a QR scan, NFC tap, or Universal
    /// Link launch) back into a `ContactCard` — used by the App Clip and the
    /// main app's "I scanned someone else's card" flow.
    public static func resolveIncomingLink(
        _ url: URL,
        cloudStore: CardCloudStore = .shared
    ) async throws -> ContactCard {
        switch CardLinkConfiguration.IncomingLink(url: url) {
        case .shortCode(let code):
            return try await cloudStore.fetchCard(shortCode: code)
        case .offlinePayload(let encoded):
            return try CardLinkCodec.decode(encoded)
        case .unrecognized:
            throw CardCloudStore.CloudError.notFound
        }
    }
}
