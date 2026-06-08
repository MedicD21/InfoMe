import SwiftUI
import PhotosUI
import UIKit
import InfoMeKit

/// The card editor: identity fields, theme picker, avatar, and a reorderable
/// list of social links. Saves into `CardStore` (which fans the change out to
/// CloudKit, the Watch app, and the widgets) on every meaningful edit.
struct EditCardView: View {
    @EnvironmentObject private var store: CardStore
    @State private var draft = ContactCard.placeholder
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isAddingSocialLink = false

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                bioSection
                themeSection
                socialsSection
            }
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Color.black
                    CardTheme.midnight.backgroundGradient.opacity(0.22)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("My Card")
            .onAppear { draft = store.card }
            .onChange(of: draft) { _, newValue in
                store.save(newValue)
            }
            .onChange(of: photoPickerItem) { _, item in
                Task { await loadAvatar(from: item) }
            }
            .sheet(isPresented: $isAddingSocialLink) {
                AddSocialLinkSheet { link in
                    draft.socialLinks.append(link)
                }
            }
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section("Identity") {
            HStack(spacing: 16) {
                AvatarView(card: draft, diameter: 64)
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label(draft.avatarJPEGData == nil ? "Add Photo" : "Change Photo", systemImage: "photo.badge.plus")
                }
            }
            TextField("First Name", text: $draft.givenName)
                .textContentType(.givenName)
            TextField("Last Name", text: $draft.familyName)
                .textContentType(.familyName)
            TextField("Job Title", text: $draft.jobTitle)
                .textContentType(.jobTitle)
            TextField("Organization", text: $draft.organization)
                .textContentType(.organizationName)
            TextField("Phone", text: $draft.phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
            TextField("Email", text: $draft.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
        }
    }

    private var bioSection: some View {
        Section {
            TextField("A line about you — what you do, where you're based…", text: $draft.bio, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("Bio")
        } footer: {
            Text("Shown under your name on the card recipients see. Keep it short — it helps your link stay scannable.")
        }
    }

    private var themeSection: some View {
        Section("Theme") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(CardTheme.all) { theme in
                        ThemeSwatch(theme: theme, isSelected: theme.id == draft.themeID)
                            .onTapGesture { draft.themeID = theme.id }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var socialsSection: some View {
        Section {
            ForEach(draft.socialLinks) { link in
                HStack {
                    Image(systemName: link.platform.sfSymbolName)
                        .foregroundStyle(link.platform.brandColor)
                        .frame(width: 28)
                    VStack(alignment: .leading) {
                        Text(link.platform.displayName).font(.subheadline.weight(.semibold))
                        Text(link.displayHandle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in draft.socialLinks.remove(atOffsets: offsets) }
            .onMove { source, destination in draft.socialLinks.move(fromOffsets: source, toOffset: destination) }

            Button {
                isAddingSocialLink = true
            } label: {
                Label("Add Social Link", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Socials")
        } footer: {
            Text("Drag to reorder — this is the order recipients will see them in.")
        }
    }

    // MARK: - Avatar loading

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let image = UIImage(data: data) else { return }
        // Keep the avatar small — it travels inside QR codes/NFC tags in offline mode.
        let resized = image.resized(maxDimension: 320)
        draft.avatarJPEGData = resized.jpegData(compressionQuality: 0.6)
    }
}

private struct ThemeSwatch: View {
    let theme: CardTheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(theme.backgroundGradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().strokeBorder(.primary, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(theme.onGradientForeground)
                        .opacity(isSelected ? 1 : 0)
                )
            Text(theme.displayName).font(.caption2)
        }
    }
}

private struct AddSocialLinkSheet: View {
    let onAdd: (SocialLink) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var platform: SocialPlatform = .instagram
    @State private var handle: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Platform", selection: $platform) {
                    ForEach(SocialPlatform.allCases) { platform in
                        Label(platform.displayName, systemImage: platform.sfSymbolName).tag(platform)
                    }
                }
                TextField(platform.handlePlaceholder, text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(platform == .website ? .URL : .default)
            }
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Color.black
                    CardTheme.midnight.backgroundGradient.opacity(0.22)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Add Social Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(SocialLink(platform: platform, handle: handle))
                        dismiss()
                    }
                    .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
