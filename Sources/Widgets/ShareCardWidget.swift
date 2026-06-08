import WidgetKit
import SwiftUI
import InfoMeKit

/// Lock Screen / Home Screen / StandBy widget that surfaces a tappable QR
/// code for "share without even unlocking your phone". Reads the same
/// App-Group-backed `CardStore` the app writes to, so it always reflects the
/// owner's current card without any network round trip.
struct ShareCardWidget: Widget {
    let kind = "ShareCardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShareCardTimelineProvider()) { entry in
            ShareCardWidgetView(entry: entry)
        }
        .configurationDisplayName("InfoMe QR")
        .description("Your share QR code, ready to scan straight from the Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall])
    }
}

struct ShareCardEntry: TimelineEntry {
    let date: Date
    let card: ContactCard
    let shareURL: URL
}

struct ShareCardTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShareCardEntry {
        entry(for: .placeholder, shortCode: "preview")
    }

    func getSnapshot(in context: Context, completion: @escaping (ShareCardEntry) -> Void) {
        Task { @MainActor in
            completion(currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShareCardEntry>) -> Void) {
        // The card rarely changes; a daily refresh (plus the store's own
        // `WidgetCenter.shared.reloadAllTimelines()` call on save) keeps this cheap.
        Task { @MainActor in
            let entry = currentEntry()
            let nextRefresh = Calendar.current.date(byAdding: .hour, value: 12, to: entry.date) ?? entry.date.addingTimeInterval(43_200)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private func currentEntry() -> ShareCardEntry {
        let store = CardStore.shared
        return entry(for: store.card, shortCode: store.shortCode)
    }

    private func entry(for card: ContactCard, shortCode: String?) -> ShareCardEntry {
        let url: URL
        if let shortCode {
            url = CardLinkConfiguration.shareURL(shortCode: shortCode)
        } else if let encoded = try? CardLinkCodec.encode(card) {
            url = CardLinkConfiguration.offlineShareURL(encodedCard: encoded)
        } else {
            url = CardLinkConfiguration.shareURL(shortCode: "me")
        }
        return ShareCardEntry(date: .now, card: card, shareURL: url)
    }
}

struct ShareCardWidgetView: View {
    let entry: ShareCardEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            QRCodeGlyph(payload: entry.shareURL.absoluteString)
                .widgetURL(entry.shareURL)

        case .accessoryRectangular:
            HStack(spacing: 8) {
                QRCodeGlyph(payload: entry.shareURL.absoluteString)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.card.fullName).font(.headline).lineLimit(1)
                    Text("Tap to show your QR").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .widgetURL(entry.shareURL)

        default:
            VStack(spacing: 6) {
                QRCodeGlyph(payload: entry.shareURL.absoluteString)
                Text(entry.card.fullName).font(.caption.bold()).lineLimit(1)
            }
            .padding(8)
            .widgetURL(entry.shareURL)
        }
    }
}

/// Small monochrome QR rendering tuned for widget surfaces (which recolor
/// content via `widgetAccentable`/tinting on the Lock Screen).
private struct QRCodeGlyph: View {
    let payload: String

    var body: some View {
        if let cgImage = QRCodeGenerator.image(
            for: payload,
            foreground: CGColor(gray: 0, alpha: 1),
            background: CGColor(gray: 0, alpha: 0),
            scale: 8
        ) {
            Image(decorative: cgImage, scale: 1)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .widgetAccentable()
        } else {
            Image(systemName: "qrcode")
        }
    }
}
