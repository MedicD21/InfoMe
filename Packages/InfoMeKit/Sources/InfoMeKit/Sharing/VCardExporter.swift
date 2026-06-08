#if canImport(ContactsUI)
import Contacts
import ContactsUI
import Foundation
import SwiftUI

// `Contacts`/`ContactsUI` (and the `UIViewControllerRepresentable` sheet below)
// are iOS/Mac Catalyst-only — not available on watchOS — so this entire file
// is compiled out there. The watch app shows social links instead; saving a
// contact is a phone-sized task anyway.

/// Turns a `ContactCard` into a real `CNContact`, and offers two ways to get
/// it onto the recipient's device:
///
/// 1. **`contactViewController(for:)`** — presents Apple's native "Add to
///    Contacts" / "Edit" sheet (`CNContactViewController`). This is the
///    primary path from the App Clip and the main app's "Save to Contacts"
///    button: zero permission prompts for the *recipient*, because they're
///    the ones choosing to add a contact — InfoMe never reads their address book.
/// 2. **`vCardData(for:)`** — raw `.vcf` `Data` for AirDrop / Messages / Mail
///    / the share sheet, for people who'd rather forward the card than open it
///    in-app.
public enum VCardExporter {

    /// Builds a `CNMutableContact` from a `ContactCard`, including name,
    /// organization, phone, email, urls, social profiles, note, and photo.
    public static func makeContact(from card: ContactCard) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = card.givenName
        contact.familyName = card.familyName
        contact.organizationName = card.organization
        contact.jobTitle = card.jobTitle

        if !card.phoneNumber.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: card.phoneNumber))]
        }
        if !card.email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: card.email as NSString)]
        }
        if !card.bio.isEmpty {
            contact.note = card.bio
        }

        var urlValues: [CNLabeledValue<NSString>] = []
        var socialValues: [CNLabeledValue<CNSocialProfile>] = []

        for link in card.socialLinks {
            if link.platform == .website, let url = link.webURL {
                urlValues.append(CNLabeledValue(label: CNLabelURLAddressHomePage, value: url.absoluteString as NSString))
            } else {
                let service = socialProfileServiceName(for: link.platform)
                let profile = CNSocialProfile(
                    urlString: link.webURL?.absoluteString,
                    username: link.handle,
                    userIdentifier: nil,
                    service: service
                )
                socialValues.append(CNLabeledValue(label: link.platform.displayName, value: profile))
            }
        }
        contact.urlAddresses = urlValues
        contact.socialProfiles = socialValues

        if let avatarData = card.avatarJPEGData {
            contact.imageData = avatarData
        }

        return contact
    }

    /// Maps an InfoMe platform to one of `CNSocialProfileService*` where
    /// Apple defines a constant, or the display name otherwise (Contacts
    /// renders unknown services fine — it just won't show a special icon).
    private static func socialProfileServiceName(for platform: SocialPlatform) -> String {
        switch platform {
        case .x: return CNSocialProfileServiceTwitter
        case .facebook: return CNSocialProfileServiceFacebook
        case .linkedin: return CNSocialProfileServiceLinkedIn
        default: return platform.displayName
        }
    }

    /// Serializes the card to `.vcf` bytes for sharing via the system share sheet.
    public static func vCardData(for card: ContactCard) throws -> Data {
        try CNContactVCardSerialization.data(with: [makeContact(from: card)])
    }

    /// A `UIViewControllerRepresentable` wrapper around `CNContactViewController`
    /// configured to let the recipient add the scanned card straight to their
    /// address book with Apple's native UI.
    public struct AddToContactsSheet: UIViewControllerRepresentable {
        public let card: ContactCard
        public let onDismiss: () -> Void

        public init(card: ContactCard, onDismiss: @escaping () -> Void) {
            self.card = card
            self.onDismiss = onDismiss
        }

        public func makeUIViewController(context: Context) -> UINavigationController {
            let contact = VCardExporter.makeContact(from: card)
            let controller = CNContactViewController(forUnknownContact: contact)
            controller.contactStore = CNContactStore()
            controller.allowsEditing = true
            controller.allowsActions = true
            controller.delegate = context.coordinator
            controller.title = card.fullName
            return UINavigationController(rootViewController: controller)
        }

        public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

        public func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

        public final class Coordinator: NSObject, CNContactViewControllerDelegate {
            let onDismiss: () -> Void
            init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

            public func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
                onDismiss()
            }
        }
    }
}
#endif
