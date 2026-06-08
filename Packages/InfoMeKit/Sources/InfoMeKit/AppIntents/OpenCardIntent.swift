import AppIntents
import SwiftUI

/// "Show My InfoMe Card" — the single intent that powers every one-tap entry
/// point InfoMe offers: Siri/Spotlight, the Shortcuts app, watch face
/// complications, and — most importantly — **the Action Button**.
///
/// Lives in `InfoMeKit` (rather than the app target) so the **same** intent
/// type can be referenced from the iOS widget extension's `ControlWidget`,
/// the watch app, and the watch widget extension's complications — App Intent
/// types must be visible to every target that wants to run or surface them.
///
/// There is no public API to bind directly to the Action Button. Apple routes
/// all third-party Action Button integrations through one of two
/// user-configurable layers, and this intent is the foundation of both:
///
/// 1. *Settings → Action Button → Shortcut* (iPhone 15 Pro/16, watchOS Ultra)
///    — the user picks any installed Shortcut, including the
///    `AppShortcut` this intent is wrapped in below (`InfoMeShortcutsProvider`).
/// 2. *Settings → Action Button → Controls* (iOS 18+) — `ShowCardControl`
///    (in the Widgets target) wraps this same intent as a `ControlWidget`,
///    which shows up in the same picker Apple's own Flashlight/Camera live in.
///
/// Either path the user picks, one press lands them on `ShareHubView` /
/// `WatchQRView` — the fastest possible "show my card" gesture.
public struct OpenCardIntent: AppIntent {
    public static var title: LocalizedStringResource = "Show My InfoMe Card"
    public static var description = IntentDescription(
        "Instantly opens your InfoMe share screen with your QR code ready to scan — perfect for binding to the Action Button."
    )

    /// Opens the app to the share screen rather than just returning data —
    /// `openAppWhenRun` plus a snippet view gives a true "one tap and you're
    /// looking at your QR code" experience from the lock screen / wrist.
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = CardStore.shared
        AppNavigationCoordinator.shared.requestShareScreen()

        return .result(
            dialog: IntentDialog("Here's your InfoMe card, ready to share."),
            view: OpenCardSnippetView(card: store.card, shortCode: store.shortCode, qrImageData: store.qrCodeImageData)
        )
    }
}

/// Minimal "here's your QR" snippet shown by Siri/Shortcuts/Controls while
/// the full app finishes launching to the share screen.
///
/// On platforms with Core Image, this renders the QR live via `QRCodeView` so
/// it matches the in-app presentation exactly. On watchOS (no Core Image),
/// it falls back to `qrImageData` — the PNG `CardSyncCoordinator` synced over
/// from the iPhone — via `SyncedQRCodeView`.
public struct OpenCardSnippetView: View {
    public let card: ContactCard
    public let shortCode: String?
    public let qrImageData: Data?

    public init(card: ContactCard, shortCode: String?, qrImageData: Data? = nil) {
        self.card = card
        self.shortCode = shortCode
        self.qrImageData = qrImageData
    }

    public var body: some View {
        VStack(spacing: 12) {
            #if canImport(CoreImage)
            QRCodeView(payload: payloadURL.absoluteString, theme: card.theme, size: 180)
            #else
            SyncedQRCodeView(imageData: qrImageData, size: 180)
            #endif
            Text(card.fullName)
                .font(.headline)
        }
        .padding()
    }

    #if canImport(CoreImage)
    private var payloadURL: URL {
        if let shortCode {
            return CardLinkConfiguration.shareURL(shortCode: shortCode)
        }
        let encoded = (try? CardLinkCodec.encode(card)) ?? ""
        return CardLinkConfiguration.offlineShareURL(encodedCard: encoded)
    }
    #endif
}

/// Surfaces `OpenCardIntent` to Siri, Spotlight, and the Shortcuts app under
/// friendly phrases, and gives it a system image so it looks at home in the
/// Action Button's Shortcut picker.
public struct InfoMeShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCardIntent(),
            phrases: [
                "Show my \(.applicationName) card",
                "Open my \(.applicationName) QR code",
                "Share my \(.applicationName) contact card",
                "\(.applicationName) share"
            ],
            shortTitle: "Show My Card",
            systemImageName: "qrcode"
        )
    }
}

/// Tiny seam that lets an `AppIntent` (which can't hold SwiftUI navigation
/// state directly) tell the already-running (or about-to-launch) app "jump to
/// the share tab" — observed by `RootView`/`WatchRootView` to drive a
/// `TabView` selection.
@MainActor
public final class AppNavigationCoordinator: ObservableObject {
    public static let shared = AppNavigationCoordinator()

    @Published public var pendingDestination: Destination?

    public enum Destination: Equatable, Sendable {
        case shareScreen
    }

    public init() {}

    public func requestShareScreen() {
        pendingDestination = .shareScreen
    }

    @discardableResult
    public func consumePendingDestination() -> Destination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }
}
