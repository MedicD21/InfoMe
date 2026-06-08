import WidgetKit
import SwiftUI
import InfoMeKit

/// Watch-face "compilation" (complication) — the literal "one tap to share"
/// the brief asked for. The user adds it via *Edit Watch Face → tap a
/// complication slot → InfoMe*; one tap launches `InfoMe Watch App` straight
/// to `WatchQRView` (driven by `OpenCardIntent.openAppWhenRun`).
///
/// Ships every accessory family so it fits any modern face — the big circular
//// corner / inline slots on Modular, Infograph, and the new watch faces all differ.
struct ShareCardComplication: Widget {
    let kind = "ShareCardComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("InfoMe — Quick Share")
        .description("One tap from your watch face opens your InfoMe QR code.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let card: ContactCard
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now, card: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        Task { @MainActor in
            completion(ComplicationEntry(date: .now, card: currentCard()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        Task { @MainActor in
            let entry = ComplicationEntry(date: .now, card: currentCard())
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(12 * 3600))))
        }
    }

    @MainActor
    private func currentCard() -> ContactCard { CardStore.shared.card }
}

struct ComplicationView: View {
    let entry: ComplicationEntry
    @Environment(\.widgetFamily) private var family

    /// Deep link the system uses to launch straight to the QR page when this
    /// complication is tapped — handled by `WatchRootView`/`onOpenURL`-style
    /// routing (or, on watchOS, simply by the app's default scene since
    /// `WatchQRView` is page one).
    private var launchURL: URL { URL(string: "infome://share")! }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 9, weight: .medium))
                    }
                }

            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("InfoMe").font(.headline)
                        Text("Tap to show your QR").font(.caption2).foregroundStyle(.secondary)
                    }
                }

            case .accessoryCorner:
                Image(systemName: "qrcode")
                    .font(.system(size: 18, weight: .semibold))
                    .widgetLabel("InfoMe")

            case .accessoryInline:
                Label("Show InfoMe card", systemImage: "qrcode")

            default:
                Image(systemName: "qrcode")
            }
        }
        .widgetURL(launchURL)
    }
}

#if DEBUG
#Preview(as: .accessoryCircular) {
    ShareCardComplication()
} timeline: {
    ComplicationEntry(date: .now, card: .placeholder)
}
#endif
