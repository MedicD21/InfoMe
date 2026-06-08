import SwiftUI
import InfoMeKit

/// "Show them your @handle real quick" — a scrollable list of social badges
/// that opens the corresponding app (or its web profile) right from the
/// wrist, for moments when pulling out a phone — or asking someone to scan a
/// code — is more friction than just saying "here, look".
struct WatchSocialListView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                AvatarView(card: store.card, diameter: 52)
                Text(store.card.fullName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(store.card.theme.onGradientForeground)

                ForEach(store.card.socialLinks) { link in
                    Button {
                        SocialLinkOpener.open(link, using: openURL)
                    } label: {
                        SocialBadge(link: link, foreground: store.card.theme.onGradientForeground)
                    }
                    .buttonStyle(.plain)
                }

                if store.card.socialLinks.isEmpty {
                    Text("Add socials in the InfoMe app on your iPhone.")
                        .font(.caption2)
                        .foregroundStyle(store.card.theme.onGradientForeground.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
        .containerBackground(store.card.theme.backgroundGradient, for: .tabView)
    }
}

#if DEBUG
#Preview {
    WatchSocialListView().environmentObject(CardStore.shared)
}
#endif
