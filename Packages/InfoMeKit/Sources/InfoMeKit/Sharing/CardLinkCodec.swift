import Compression
import Foundation

/// Packs a whole `ContactCard` into a URL-safe string and back, for the
/// fully-offline sharing mode (no CloudKit / iCloud account required).
///
/// Pipeline: `JSONEncoder` → zlib deflate (`Compression` framework) →
/// base64url (no padding). A typical card with 4–6 social links and no
/// avatar encodes to roughly 180–260 characters — comfortably scannable as a
/// QR code (version ~8–11 at correction level M) and well within NDEF tag
/// capacity on a standard NTAG213/215 (137/480 bytes user memory — encode
/// without an avatar for 213 tags, or omit the photo, which the editor warns about).
public enum CardLinkCodec {

    public enum CodecError: Error {
        case encodingFailed
        case decodingFailed
        case compressionFailed
        case decompressionFailed
    }

    /// Encodes a card to a base64url string suitable for embedding in a URL path.
    public static func encode(_ card: ContactCard, includingAvatar: Bool = true) throws -> String {
        var card = card
        if !includingAvatar {
            card.avatarJPEGData = nil
        }

        let json: Data
        do {
            json = try JSONEncoder().encode(card)
        } catch {
            throw CodecError.encodingFailed
        }
        let compressed = try deflate(json)
        return base64URLEncode(compressed)
    }

    /// Decodes a previously-encoded string back into a `ContactCard`.
    public static func decode(_ encoded: String) throws -> ContactCard {
        guard let compressed = base64URLDecode(encoded) else { throw CodecError.decodingFailed }
        let json = try inflate(compressed)
        do {
            return try JSONDecoder().decode(ContactCard.self, from: json)
        } catch {
            throw CodecError.decodingFailed
        }
    }

    // MARK: - zlib via the Compression framework

    private static func deflate(_ data: Data) throws -> Data {
        try run(data, operation: COMPRESSION_STREAM_ENCODE)
    }

    private static func inflate(_ data: Data) throws -> Data {
        try run(data, operation: COMPRESSION_STREAM_DECODE)
    }

    private static func run(_ input: Data, operation: compression_stream_operation) throws -> Data {
        let failure = (operation == COMPRESSION_STREAM_ENCODE) ? CodecError.compressionFailed : CodecError.decompressionFailed
        let bufferSize = 64 * 1024

        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        // Copy into a plain array first so `withUnsafeBufferPointer` always
        // hands back a valid base address — including for empty input, which
        // `Data.withUnsafeBytes` can return `nil` for.
        let sourceBytes = [UInt8](input)

        var output = Data()
        var encounteredError = false

        sourceBytes.withUnsafeBufferPointer { sourceBuffer in
            var stream = compression_stream(
                dst_ptr: destinationBuffer,
                dst_size: bufferSize,
                src_ptr: sourceBuffer.baseAddress ?? UnsafePointer(destinationBuffer),
                src_size: sourceBuffer.count,
                state: nil
            )

            guard compression_stream_init(&stream, operation, COMPRESSION_ZLIB) != COMPRESSION_STATUS_ERROR else {
                encounteredError = true
                return
            }
            defer { compression_stream_destroy(&stream) }

            // `compression_stream_init` zeroes out the buffer pointers/sizes,
            // so they must be (re)assigned after init, not just at construction.
            stream.src_ptr = sourceBuffer.baseAddress ?? UnsafePointer(destinationBuffer)
            stream.src_size = sourceBuffer.count
            stream.dst_ptr = destinationBuffer
            stream.dst_size = bufferSize

            let flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)

            loop: while true {
                let status = compression_stream_process(&stream, flags)
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let produced = bufferSize - stream.dst_size
                    if produced > 0 {
                        output.append(destinationBuffer, count: produced)
                    }
                    if status == COMPRESSION_STATUS_END { break loop }
                    stream.dst_ptr = destinationBuffer
                    stream.dst_size = bufferSize
                default: // COMPRESSION_STATUS_ERROR or anything unexpected
                    encounteredError = true
                    break loop
                }
            }
        }

        guard !encounteredError else { throw failure }
        return output
    }

    // MARK: - base64url (RFC 4648 §5), unpadded

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}
