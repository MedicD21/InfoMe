import XCTest
@testable import InfoMeKit

final class CardLinkCodecTests: XCTestCase {
    func testRoundTripPreservesAllFields() throws {
        let card = ContactCard.placeholder
        let encoded = try CardLinkCodec.encode(card)
        let decoded = try CardLinkCodec.decode(encoded)
        XCTAssertEqual(card, decoded)
    }

    func testEncodedStringIsURLPathSafe() throws {
        let encoded = try CardLinkCodec.encode(.placeholder)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        XCTAssertTrue(encoded.unicodeScalars.allSatisfy(allowed.contains))
    }

    func testRoundTripWithEmptyCard() throws {
        let card = ContactCard(givenName: "A", familyName: "B")
        let encoded = try CardLinkCodec.encode(card)
        let decoded = try CardLinkCodec.decode(encoded)
        XCTAssertEqual(card, decoded)
    }

    func testCompressionMeaningfullyShrinksRepetitiveContent() throws {
        var card = ContactCard.placeholder
        card.bio = String(repeating: "Let's connect! ", count: 40)
        let encoded = try CardLinkCodec.encode(card)
        let rawJSONSize = try JSONEncoder().encode(card).count
        // base64 inflates by ~4/3, so even after that overhead the compressed
        // route should still be meaningfully smaller than raw JSON for repetitive text.
        XCTAssertLessThan(encoded.count, rawJSONSize)
    }

    func testDecodeGarbageThrows() {
        XCTAssertThrowsError(try CardLinkCodec.decode("not-a-valid-payload!!"))
    }
}

final class CardLinkConfigurationTests: XCTestCase {
    func testParsesHostedShortCodeLink() {
        let url = URL(string: "https://infome.app/u/aB3xQ9")!
        XCTAssertEqual(CardLinkConfiguration.IncomingLink(url: url), .shortCode("aB3xQ9"))
    }

    func testParsesOfflinePayloadLink() {
        let url = URL(string: "https://infome.app/c/eJzT0yMAAAB")!
        XCTAssertEqual(CardLinkConfiguration.IncomingLink(url: url), .offlinePayload("eJzT0yMAAAB"))
    }

    func testUnrecognizedLinkShape() {
        let url = URL(string: "https://infome.app/about")!
        XCTAssertEqual(CardLinkConfiguration.IncomingLink(url: url), .unrecognized)
    }
}
