import CloudKit
import Foundation

/// Publishes a `ContactCard` to CloudKit's **public** database under a short,
/// memorable share code, and fetches cards by that code.
///
/// This is what lets the QR code / NFC tag stay constant while the owner
/// keeps editing their card — the link only ever encodes the short code; all
/// the actual data lives in (and can be updated in) CloudKit.
///
/// No backend to deploy or pay for: CloudKit's public database is free at
/// this scale and fully managed by Apple, which keeps the whole stack inside
/// a single trusted ecosystem — exactly what an App Clip's tight permission
/// and size budget wants.
public actor CardCloudStore {
    public static let shared = CardCloudStore()

    private let container: CKContainer
    private let database: CKDatabase

    private enum Field: String {
        case shortCode, payload, updatedAt
    }

    public init(containerIdentifier: String = CardLinkConfiguration.cloudKitContainerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.publicCloudDatabase
    }

    public enum CloudError: Error, LocalizedError, Equatable {
        case notSignedIn
        case codeCollision
        case notFound
        case encodingFailed

        public var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Sign in to iCloud to publish your card, or use offline sharing instead."
            case .codeCollision: return "That share code is taken — generating a new one."
            case .notFound: return "No card found for that link."
            case .encodingFailed: return "Couldn't prepare your card for upload."
            }
        }
    }

    /// Publishes (inserts or updates) `card` under `shortCode`, returning the
    /// record's `recordID.recordName` for diagnostics. Callers typically don't
    /// need the return value — the short code itself is the stable handle.
    @discardableResult
    public func publish(_ card: ContactCard, shortCode: String) async throws -> String {
        guard try await accountIsAvailable() else { throw CloudError.notSignedIn }

        let recordID = CKRecord.ID(recordName: shortCode)
        let record: CKRecord
        if let existing = try? await database.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: CardLinkConfiguration.cloudKitRecordType, recordID: recordID)
        }

        guard let payload = try? JSONEncoder().encode(card) else { throw CloudError.encodingFailed }
        record[Field.shortCode.rawValue] = shortCode as NSString
        record[Field.payload.rawValue] = payload as NSData
        record[Field.updatedAt.rawValue] = Date() as NSDate

        let saved = try await database.save(record)
        return saved.recordID.recordName
    }

    /// Fetches and decodes the card published under `shortCode`.
    /// Used by the App Clip (primary path) and the main app's "scan a code" flow.
    public func fetchCard(shortCode: String) async throws -> ContactCard {
        let recordID = CKRecord.ID(recordName: shortCode)
        do {
            let record = try await database.record(for: recordID)
            guard
                let payload = record[Field.payload.rawValue] as? Data,
                let card = try? JSONDecoder().decode(ContactCard.self, from: payload)
            else {
                throw CloudError.notFound
            }
            return card
        } catch let error as CKError where error.code == .unknownItem {
            throw CloudError.notFound
        }
    }

    /// Generates a short, URL-friendly, collision-checked code (`aB3xQ9`-style)
    /// for first-time publishing.
    public func generateAvailableShortCode(length: Int = 6) async -> String {
        let alphabet = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789") // no ambiguous chars
        for _ in 0..<5 {
            let candidate = String((0..<length).map { _ in alphabet.randomElement()! })
            let recordID = CKRecord.ID(recordName: candidate)
            if (try? await database.record(for: recordID)) == nil {
                return candidate
            }
        }
        // Extremely unlikely fallback — widen the alphabet space.
        return String((0..<(length + 2)).map { _ in alphabet.randomElement()! })
    }

    private func accountIsAvailable() async throws -> Bool {
        let status = try await container.accountStatus()
        return status == .available
    }
}
