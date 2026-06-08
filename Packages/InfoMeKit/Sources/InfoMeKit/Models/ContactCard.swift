import Foundation

/// One entry in the social grid — a platform plus the owner's handle (or, for
/// `.website`, a free-form URL string).
public struct SocialLink: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var platform: SocialPlatform
    public var handle: String

    public init(id: UUID = UUID(), platform: SocialPlatform, handle: String) {
        self.id = id
        self.platform = platform
        self.handle = handle
    }

    /// The link to open when the badge is tapped: native app first, web profile as fallback.
    public var deepLink: URL? { platform.appDeepLink(for: handle) }
    public var webURL: URL? { platform.profileURL(for: handle) }

    public var displayHandle: String {
        platform.displayHandle(for: handle)
    }
}

/// The complete shareable "digital business card". This is the single source
/// of truth that flows: Editor → local store → CloudKit → QR/NFC payload →
/// App Clip → `LinktreeMenuView`.
public struct ContactCard: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var givenName: String
    public var familyName: String
    public var organization: String
    public var jobTitle: String
    public var phoneNumber: String
    public var email: String
    public var bio: String
    public var themeID: String
    public var socialLinks: [SocialLink]
    /// Small (≤ ~40KB) JPEG avatar, kept tiny on purpose so the card stays
    /// compact enough to round-trip through a QR code in offline mode.
    public var avatarJPEGData: Data?

    public init(
        id: UUID = UUID(),
        givenName: String = "",
        familyName: String = "",
        organization: String = "",
        jobTitle: String = "",
        phoneNumber: String = "",
        email: String = "",
        bio: String = "",
        themeID: String = CardTheme.midnight.id,
        socialLinks: [SocialLink] = [],
        avatarJPEGData: Data? = nil
    ) {
        self.id = id
        self.givenName = givenName
        self.familyName = familyName
        self.organization = organization
        self.jobTitle = jobTitle
        self.phoneNumber = phoneNumber
        self.email = email
        self.bio = bio
        self.themeID = themeID
        self.socialLinks = socialLinks
        self.avatarJPEGData = avatarJPEGData
    }

    public var fullName: String {
        [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    public var initials: String {
        let first = givenName.first.map(String.init) ?? ""
        let last = familyName.first.map(String.init) ?? ""
        let combined = (first + last).uppercased()
        return combined.isEmpty ? "🙂" : combined
    }

    public var subtitle: String {
        [jobTitle, organization].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public var theme: CardTheme { CardTheme.theme(id: themeID) }

    /// A friendly placeholder card so previews, the App Clip placeholder
    /// state, and watch complications never render empty.
    public static var placeholder: ContactCard {
        ContactCard(
            givenName: "Jordan",
            familyName: "Avery",
            organization: "Studio Nine",
            jobTitle: "Creative Director",
            phoneNumber: "+1 (555) 010-9988",
            email: "jordan@studionine.example",
            bio: "Making things people love to look at. Based in Austin, TX.",
            themeID: CardTheme.aurora.id,
            socialLinks: [
                SocialLink(platform: .instagram, handle: "jordanavery"),
                SocialLink(platform: .x, handle: "jordanavery"),
                SocialLink(platform: .linkedin, handle: "jordan-avery"),
                SocialLink(platform: .website, handle: "https://studionine.example"),
            ]
        )
    }
}
