import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The recipient-facing "Linktree-style" menu: a themed, animated card with
/// the owner's avatar/name/bio, a prominent **Save to Contacts** button, and a
/// grid of social badges. Lives in `InfoMeKit` so the App Clip, the main app's
/// "preview my card" screen, and the Watch app's expanded view all render the
/// *exact same* experience — what the recipient sees is what the owner designed.
public struct LinktreeMenuView: View {
    public let card: ContactCard
    public let onSaveToContacts: () -> Void
    public let onOpenSocial: (SocialLink) -> Void

    @State private var animateGradient = false

    public init(
        card: ContactCard,
        onSaveToContacts: @escaping () -> Void,
        onOpenSocial: @escaping (SocialLink) -> Void
    ) {
        self.card = card
        self.onSaveToContacts = onSaveToContacts
        self.onOpenSocial = onOpenSocial
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                saveButton
                socialGrid
                footer
            }
            .padding(24)
            .padding(.top, 12)
        }
        .background(themedBackground.ignoresSafeArea())
        .scrollIndicators(.hidden)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            AvatarView(card: card, diameter: 104)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)

            Text(card.fullName.isEmpty ? "Your Name" : card.fullName)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(card.theme.onGradientForeground)
                .multilineTextAlignment(.center)

            if !card.subtitle.isEmpty {
                Text(card.subtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(card.theme.onGradientForeground.opacity(0.8))
            }

            if !card.bio.isEmpty {
                Text(card.bio)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(card.theme.onGradientForeground.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 8)
    }

    private var saveButton: some View {
        Button(action: onSaveToContacts) {
            Label("Save to Contacts", systemImage: "person.crop.circle.badge.plus")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(card.theme.onGradientForeground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(card.theme.backgroundGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(card.theme.onGradientForeground.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        .accessibilityHint("Adds \(card.fullName) to your contacts")
    }

    @ViewBuilder
    private var socialGrid: some View {
        if !card.socialLinks.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 14)], spacing: 14) {
                ForEach(card.socialLinks) { link in
                    Button { onOpenSocial(link) } label: {
                        SocialBadge(link: link, foreground: card.theme.onGradientForeground)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Image(systemName: "qrcode")
                .font(.title3)
            Text("Shared via InfoMe")
                .font(.system(.caption2, design: .rounded, weight: .medium))
        }
        .foregroundStyle(card.theme.onGradientForeground.opacity(0.45))
        .padding(.top, 8)
    }

    private var themedBackground: some View {
        TimelineView(.animation(minimumInterval: 1/12, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            card.theme.backgroundGradient
                .hueRotation(.degrees(sin(t / 18) * 6))
                .overlay(
                    RadialGradient(
                        colors: [card.theme.onGradientForeground.opacity(0.10), .clear],
                        center: UnitPoint(x: 0.5 + sin(t / 11) * 0.3, y: 0.2),
                        startRadius: 10,
                        endRadius: 420
                    )
                )
        }
    }
}

/// Circular avatar that shows the user's photo if present, otherwise their
/// initials over a soft tint of the theme's accent color.
public struct AvatarView: View {
    public let card: ContactCard
    public let diameter: CGFloat

    public init(card: ContactCard, diameter: CGFloat) {
        self.card = card
        self.diameter = diameter
    }

    public var body: some View {
        Group {
            if let data = card.avatarJPEGData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Circle().fill(card.theme.accentColor.opacity(0.25))
                    Text(card.initials)
                        .font(.system(size: diameter * 0.36, weight: .bold, design: .rounded))
                        .foregroundStyle(card.theme.onGradientForeground)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(card.theme.onGradientForeground.opacity(0.5), lineWidth: 2))
    }
}

/// One tile in the social grid: brand-colored glyph, platform name, and handle.
public struct SocialBadge: View {
    public let link: SocialLink
    public let foreground: Color

    public init(link: SocialLink, foreground: Color) {
        self.link = link
        self.foreground = foreground
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(link.platform.brandColor.gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: link.platform.sfSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(link.platform.displayName)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Text(link.displayHandle)
                    .font(.system(.caption2, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .opacity(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(foreground)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(foreground.opacity(0.12), lineWidth: 1)
        )
    }
}

#if DEBUG
#Preview("Linktree Menu") {
    LinktreeMenuView(card: .placeholder, onSaveToContacts: {}, onOpenSocial: { _ in })
}
#endif
