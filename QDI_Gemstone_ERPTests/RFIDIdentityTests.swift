import XCTest
@testable import QDI_Gemstone_ERP

final class RFIDIdentityTests: XCTestCase {
    func testNormalizeAcceptsValid24HexCharacters() {
        XCTAssertEqual(EPCanonical.normalize("e28069952000500d103000e2"), "E28069952000500D103000E2")
    }

    func testNormalizeRejectsWrongLength() {
        XCTAssertNil(EPCanonical.normalize("E28069952000"))
    }

    func testNormalizeRejectsNonHexInput() {
        XCTAssertNil(EPCanonical.normalize("E28069952000500D103000EZ"))
    }

    func testCanonicalHexFromRawPayloadUsesMarkerWindow() {
        let raw = "010203E28069952000500D103000E2AABBCC"
        XCTAssertEqual(EPCanonical.canonicalHex(fromRawHex: raw), "E28069952000500D103000E2")
    }

    func testCanonicalHexFromPayloadFallsBackToLast12Bytes() {
        let payload: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A]
        XCTAssertEqual(EPCanonical.canonicalHex(fromPayload: payload), "04101112131415161718191A")
    }
}
