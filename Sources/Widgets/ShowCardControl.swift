import SwiftUI
import WidgetKit
import AppIntents
import InfoMeKit

/// The modern (iOS 18+ / watchOS 11+) route to the Action Button:
/// `ControlWidget` makes InfoMe show up in *Settings → Action Button →
/// Controls* and *Settings → Control Center → Customize Controls* — the same
/// picker surfaces Apple's own Flashlight, Camera, and Focus controls live in.
///
/// One tap (from the Lock Screen, Control Center, *or* a configured Action
/// Button press) runs `OpenCardIntent`, which jumps straight to the QR/share
/// screen. This is in addition to — not instead of — the `AppShortcut` in
/// `OpenCardIntent.swift`, since older OS versions only expose the
/// Shortcut-based Action Button binding.
struct ShowCardControl: ControlWidget {
    static let kind = "com.example.infome.ShowCardControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenCardIntent()) {
                Label("Show My Card", systemImage: "qrcode")
            }
        }
        .displayName("Show My InfoMe Card")
        .description("One tap opens your QR code, ready to share — bind it to the Action Button for instant access.")
    }
}
