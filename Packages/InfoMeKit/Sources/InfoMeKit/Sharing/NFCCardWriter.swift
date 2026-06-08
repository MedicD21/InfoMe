#if canImport(CoreNFC)
import CoreNFC
import Combine
import Foundation

/// Status updates published while a tag-read/write session is in flight, so
/// the UI can show the right "bring tag near the top of your iPhone…" prompt.
public enum NFCSessionPhase: Equatable, Sendable {
    case idle
    case waitingForTag(prompt: String)
    case writing
    case success(String)
    case readURL(URL)
    case failed(String)
}

/// Writes the user's share-link to a blank/rewritable NFC tag (NTAG213/215/216,
/// or any ISO 14443-A tag exposing the `NFCNDEFTag` protocol), and can also read
/// someone else's InfoMe tag.
///
/// ### Why a tag instead of phone-to-phone?
/// iOS deliberately does not expose 3rd-party phone-to-phone NFC data exchange
/// (that's reserved for system features like AirDrop / NameDrop). Writing a
/// share-link to a tag — a sticker on a phone case, a metal card, a wristband —
/// is the supported, App-Review-safe way to put "tap to share" into the world:
/// anyone (iPhone *or* Android) taps their phone to the tag, the OS offers to
/// open the link, and they land on the same Linktree menu the QR code opens.
@MainActor
public final class NFCCardWriter: NSObject, ObservableObject {
    @Published public private(set) var phase: NFCSessionPhase = .idle

    private var session: NFCTagReaderSession?
    private var pendingWriteURL: URL?
    private var mode: Mode = .write

    private enum Mode { case write, read }

    public override init() { super.init() }

    public var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    /// Starts a session that writes `url` (typically `CardLinkConfiguration.shareURL`)
    /// as a `URI` NDEF record to the next compatible tag the user taps.
    public func writeShareLink(_ url: URL) {
        guard isAvailable else {
            phase = .failed("This device doesn't support NFC tag writing.")
            return
        }
        mode = .write
        pendingWriteURL = url
        phase = .waitingForTag(prompt: "Hold your iPhone near a blank NFC tag to write your InfoMe link.")
        beginSession()
    }

    /// Starts a session that reads the first NDEF URI record off the next tag —
    /// used for "scan someone else's NFC card" in the main app.
    public func readTag() {
        guard isAvailable else {
            phase = .failed("This device doesn't support NFC tag reading.")
            return
        }
        mode = .read
        pendingWriteURL = nil
        phase = .waitingForTag(prompt: "Hold your iPhone near an InfoMe tag to read it.")
        beginSession()
    }

    public func cancel() {
        session?.invalidate()
        session = nil
        phase = .idle
    }

    private func beginSession() {
        let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self)
        session?.alertMessage = currentPrompt
        session?.begin()
        self.session = session
    }

    private var currentPrompt: String {
        if case .waitingForTag(let prompt) = phase { return prompt }
        return "Hold your iPhone near the tag…"
    }
}

extension NFCCardWriter: NFCTagReaderSessionDelegate {
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    public nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            if let readerError = error as? NFCReaderError,
               readerError.code == .readerSessionInvalidationErrorUserCanceled {
                self.phase = .idle
            } else if case .success = self.phase {
                // Already reported success before the session naturally ended — leave it.
            } else if case .readURL = self.phase {
                // Already reported the read result.
            } else {
                self.phase = .failed(error.localizedDescription)
            }
            self.session = nil
        }
    }

    public nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            guard let ndefTag = self.asNDEFTag(tag) else {
                session.invalidate(errorMessage: "That tag isn't NDEF-formatted.")
                return
            }

            Task { @MainActor in
                switch self.mode {
                case .write: await self.performWrite(ndefTag: ndefTag, session: session)
                case .read: await self.performRead(ndefTag: ndefTag, session: session)
                }
            }
        }
    }

    nonisolated private func asNDEFTag(_ tag: NFCTag) -> NFCNDEFTag? {
        switch tag {
        case .miFare(let t): return t
        case .iso7816(let t): return t
        case .iso15693(let t): return t
        case .feliCa(let t): return t
        @unknown default: return nil
        }
    }

    @MainActor
    private func performWrite(ndefTag: NFCNDEFTag, session: NFCTagReaderSession) async {
        guard let url = pendingWriteURL else { return }

        do {
            let status = try await queryStatus(ndefTag)
            switch status.0 {
            case .notSupported:
                session.invalidate(errorMessage: "This tag doesn't support NDEF.")
                return
            case .readOnly:
                session.invalidate(errorMessage: "This tag is read-only and can't be rewritten.")
                return
            case .readWrite:
                break
            @unknown default:
                break
            }

            guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
                session.invalidate(errorMessage: "Couldn't encode that link for NFC.")
                return
            }
            let message = NFCNDEFMessage(records: [payload])

            phase = .writing
            session.alertMessage = "Writing your InfoMe link…"
            try await write(message, to: ndefTag)

            phase = .success("Your InfoMe link is now on this tag. Anyone can tap their phone to it.")
            session.alertMessage = "✅ Link written! You can move your phone away."
            session.invalidate()
        } catch {
            phase = .failed(error.localizedDescription)
            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func performRead(ndefTag: NFCNDEFTag, session: NFCTagReaderSession) async {
        do {
            let message = try await read(ndefTag)
            guard
                let record = message.records.first,
                let url = record.wellKnownTypeURIPayload()
            else {
                session.invalidate(errorMessage: "This tag doesn't contain an InfoMe link.")
                return
            }
            phase = .readURL(url)
            session.alertMessage = "✅ Found a card!"
            session.invalidate()
        } catch {
            phase = .failed(error.localizedDescription)
            session.invalidate(errorMessage: "Read failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Async wrappers around the completion-handler NFCNDEFTag API

    private func queryStatus(_ tag: NFCNDEFTag) async throws -> (NFCNDEFStatus, Int) {
        try await withCheckedThrowingContinuation { continuation in
            tag.queryNDEFStatus { status, capacity, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (status, capacity)) }
            }
        }
    }

    private func write(_ message: NFCNDEFMessage, to tag: NFCNDEFTag) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            tag.writeNDEF(message) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    private func read(_ tag: NFCNDEFTag) async throws -> NFCNDEFMessage {
        try await withCheckedThrowingContinuation { continuation in
            tag.readNDEF { message, error in
                if let error { continuation.resume(throwing: error) }
                else if let message { continuation.resume(returning: message) }
                else { continuation.resume(throwing: EmptyTagError()) }
            }
        }
    }
}

private struct EmptyTagError: Error, LocalizedError {
    var errorDescription: String? { "This tag doesn't contain any data." }
}
#endif
