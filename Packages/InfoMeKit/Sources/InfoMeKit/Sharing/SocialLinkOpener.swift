import SwiftUI

/// Opens a `SocialLink`, trying the platform's native app deep link first and
/// falling back to the web profile URL when the app isn't installed.
///
/// Built around SwiftUI's `OpenURLAction` (via `@Environment(\.openURL)`)
/// rather than `UIApplication.shared` so the exact same call works from the
/// main iOS app, the App Clip, and the watchOS app — `UIApplication` isn't
/// available on watchOS or inside extensions, but the environment action is.
public enum SocialLinkOpener {
    /// Resolves which URL to try first/second for a given link. The caller
    /// feeds these to `OpenURLAction`, which reports back whether the first
    /// one actually opened (e.g. the native app was installed) so we know
    /// whether to fall back to the web profile.
    public static func candidateURLs(for link: SocialLink) -> [URL] {
        [link.deepLink, link.webURL].compactMap { $0 }
    }

    /// Performs the open-with-fallback dance using the environment's
    /// `OpenURLAction`. Call from a `Button` action with
    /// `@Environment(\.openURL) private var openURL`.
    @MainActor
    public static func open(_ link: SocialLink, using openURL: OpenURLAction) {
        let candidates = candidateURLs(for: link)
        #if os(watchOS)
        // The completion-handler overload of `OpenURLAction` (needed to detect
        // a failed deep link and fall back to the web URL) isn't available on
        // watchOS, and there's no other way to tell whether a deep link
        // "took" — so just hand the system the best candidate and let it
        // route to an installed app, Handoff to iPhone, or the web.
        if let url = candidates.first {
            _ = openURL(url)
        }
        #else
        attempt(candidates: candidates, index: 0, using: openURL)
        #endif
    }

    #if !os(watchOS)
    @MainActor
    private static func attempt(candidates: [URL], index: Int, using openURL: OpenURLAction) {
        guard index < candidates.count else { return }
        openURL(candidates[index]) { accepted in
            if !accepted {
                attempt(candidates: candidates, index: index + 1, using: openURL)
            }
        }
    }
    #endif
}
