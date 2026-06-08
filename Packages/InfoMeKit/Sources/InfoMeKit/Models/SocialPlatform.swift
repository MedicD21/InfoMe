import SwiftUI

/// Every social / messaging platform InfoMe knows how to render a pretty
/// badge for and deep-link into. Intentionally a flat enum (rather than a
/// "free text" model) so the Linktree menu can show a recognizable icon,
/// brand color, and try the native app before falling back to the web.
public enum SocialPlatform: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case instagram
    case tiktok
    case x
    case linkedin
    case facebook
    case youtube
    case snapchat
    case github
    case threads
    case pinterest
    case twitch
    case discord
    case whatsapp
    case telegram
    case spotify
    case website

    public var id: String { rawValue }

    /// Human-readable name shown in pickers and badges.
    public var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .x: return "X"
        case .linkedin: return "LinkedIn"
        case .facebook: return "Facebook"
        case .youtube: return "YouTube"
        case .snapchat: return "Snapchat"
        case .github: return "GitHub"
        case .threads: return "Threads"
        case .pinterest: return "Pinterest"
        case .twitch: return "Twitch"
        case .discord: return "Discord"
        case .whatsapp: return "WhatsApp"
        case .telegram: return "Telegram"
        case .spotify: return "Spotify"
        case .website: return "Website"
        }
    }

    /// SF Symbol used as a fallback badge glyph (no bundled brand-mark assets needed
    /// to get the project running — swap in real brand marks from `Assets.xcassets`
    /// any time by adding an image with the same name as the raw value).
    public var sfSymbolName: String {
        switch self {
        case .instagram: return "camera.circle.fill"
        case .tiktok: return "music.note.tv.fill"
        case .x: return "at.circle.fill"
        case .linkedin: return "briefcase.circle.fill"
        case .facebook: return "person.2.circle.fill"
        case .youtube: return "play.rectangle.fill"
        case .snapchat: return "ghost.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .threads: return "at.badge.plus"
        case .pinterest: return "pin.circle.fill"
        case .twitch: return "gamecontroller.circle.fill"
        case .discord: return "bubble.left.and.bubble.right.fill"
        case .whatsapp: return "phone.circle.fill"
        case .telegram: return "paperplane.circle.fill"
        case .spotify: return "waveform.circle.fill"
        case .website: return "globe"
        }
    }

    /// Approximate brand color, used for the badge background/glow.
    public var brandColor: Color {
        switch self {
        case .instagram: return Color(red: 0.83, green: 0.18, blue: 0.49)
        case .tiktok: return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .x: return Color(red: 0.06, green: 0.06, blue: 0.06)
        case .linkedin: return Color(red: 0.04, green: 0.46, blue: 0.74)
        case .facebook: return Color(red: 0.09, green: 0.46, blue: 0.95)
        case .youtube: return Color(red: 0.94, green: 0.13, blue: 0.13)
        case .snapchat: return Color(red: 1.0, green: 0.87, blue: 0.0)
        case .github: return Color(red: 0.13, green: 0.15, blue: 0.18)
        case .threads: return Color(red: 0.05, green: 0.05, blue: 0.05)
        case .pinterest: return Color(red: 0.78, green: 0.0, blue: 0.09)
        case .twitch: return Color(red: 0.4, green: 0.27, blue: 0.85)
        case .discord: return Color(red: 0.34, green: 0.39, blue: 0.95)
        case .whatsapp: return Color(red: 0.15, green: 0.82, blue: 0.42)
        case .telegram: return Color(red: 0.16, green: 0.62, blue: 0.85)
        case .spotify: return Color(red: 0.11, green: 0.73, blue: 0.33)
        case .website: return Color(red: 0.35, green: 0.38, blue: 0.42)
        }
    }

    /// `true` when this platform is identified by an `@handle`-style username
    /// rather than a free-form URL (controls which editor field is shown).
    public var usesHandle: Bool { self != .website }

    /// The placeholder shown in the username field of the editor.
    public var handlePlaceholder: String {
        switch self {
        case .website: return "https://example.com"
        case .whatsapp, .telegram: return "phone number or handle"
        default: return "username"
        }
    }

    /// Best-effort native-app deep link for a given handle. Tried first;
    /// if the app isn't installed, `profileURL` is used instead.
    public func appDeepLink(for handle: String) -> URL? {
        let h = Self.normalize(handle)
        guard !h.isEmpty else { return nil }
        switch self {
        case .instagram: return URL(string: "instagram://user?username=\(h)")
        case .tiktok: return URL(string: "snssdk1233://user/profile/\(h)")
        case .x: return URL(string: "twitter://user?screen_name=\(h)")
        case .linkedin: return URL(string: "linkedin://in/\(h)")
        case .facebook: return URL(string: "fb://profile/\(h)")
        case .youtube: return URL(string: "youtube://www.youtube.com/\(h)")
        case .snapchat: return URL(string: "snapchat://add/\(h)")
        case .github: return nil
        case .threads: return URL(string: "barcelona://user?username=\(h)")
        case .pinterest: return URL(string: "pinterest://user/\(h)")
        case .twitch: return URL(string: "twitch://stream/\(h)")
        case .discord: return URL(string: "discord://-/users/\(h)")
        case .whatsapp: return URL(string: "https://wa.me/\(h)")
        case .telegram: return URL(string: "tg://resolve?domain=\(h)")
        case .spotify: return URL(string: "spotify://user/\(h)")
        case .website: return nil
        }
    }

    /// Universal/web fallback URL — always resolvable, used by the App Clip
    /// (which should not assume the recipient has any of these apps installed)
    /// and whenever the deep link can't be opened.
    public func profileURL(for handle: String) -> URL? {
        let h = Self.normalize(handle)
        guard !h.isEmpty else { return nil }
        switch self {
        case .instagram: return URL(string: "https://instagram.com/\(h)")
        case .tiktok: return URL(string: "https://tiktok.com/@\(h)")
        case .x: return URL(string: "https://x.com/\(h)")
        case .linkedin: return URL(string: "https://linkedin.com/in/\(h)")
        case .facebook: return URL(string: "https://facebook.com/\(h)")
        case .youtube: return URL(string: "https://youtube.com/\(h)")
        case .snapchat: return URL(string: "https://snapchat.com/add/\(h)")
        case .github: return URL(string: "https://github.com/\(h)")
        case .threads: return URL(string: "https://threads.net/@\(h)")
        case .pinterest: return URL(string: "https://pinterest.com/\(h)")
        case .twitch: return URL(string: "https://twitch.tv/\(h)")
        case .discord: return URL(string: "https://discord.com/users/\(h)")
        case .whatsapp: return URL(string: "https://wa.me/\(h)")
        case .telegram: return URL(string: "https://t.me/\(h)")
        case .spotify: return URL(string: "https://open.spotify.com/user/\(h)")
        case .website: return URL(string: h.hasPrefix("http") ? h : "https://\(h)")
        }
    }

    /// Strips a leading "@" and surrounding whitespace from user-entered handles.
    private static func normalize(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") { trimmed.removeFirst() }
        return trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
    }
}
