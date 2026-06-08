import Foundation

/// Centralizes every place the share domain / App Group / iCloud container
/// identifiers are referenced from Swift, so swapping in your own domain is a
/// one-file change (the matching entitlements/Info.plist values live in
/// `project.yml` — keep both in sync).
public enum CardLinkConfiguration {
    /// The Universal Link / App Clip domain. Replace with a domain you own
    /// and control the `apple-app-site-association` file for.
    public static let shareDomain = "infome.app"

    /// `https://infome.app/u/<shortCode>` — what gets encoded into the QR
    /// code and NFC tag when "online" (CloudKit-backed) sharing is enabled.
    public static func shareURL(shortCode: String) -> URL {
        URL(string: "https://\(shareDomain)/u/\(shortCode)")!
    }

    /// `https://infome.app/c/<encodedCard>` — fully self-contained link used
    /// in offline mode (see `CardLinkCodec`); the entire card lives in the URL.
    public static func offlineShareURL(encodedCard: String) -> URL {
        URL(string: "https://\(shareDomain)/c/\(encodedCard)")!
    }

    public static let appGroupIdentifier = "group.com.dushin.infome"
    public static let cloudKitContainerIdentifier = "iCloud.com.dushin.infome"
    public static let cloudKitRecordType = "PublishedCard"

    /// Parses an incoming Universal Link / App Clip invocation URL into
    /// either a CloudKit short code or a fully-encoded offline payload.
    public enum IncomingLink: Equatable {
        case shortCode(String)
        case offlinePayload(String)
        case unrecognized

        public init(url: URL) {
            let path = url.pathComponents.filter { $0 != "/" }
            guard path.count >= 2 else {
                self = .unrecognized
                return
            }
            switch path[0] {
            case "u": self = .shortCode(path[1])
            case "c": self = .offlinePayload(path[1])
            default: self = .unrecognized
            }
        }
    }
}
