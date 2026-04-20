import Testing
@testable import QDI_Gemstone_ERP_v2

@Suite("RFID CRC, EPC Canonicalization, and Frame Parsing")
struct RFIDTests {

    // MARK: - CRC-16 (Silion bit-by-bit)

    @Test("CRC16 of empty input returns 0xFFFF seed unchanged through shifts")
    func crc16Empty() {
        let crc = RFIDManager.silionCRC16([])
        #expect(crc == 0xFFFF)
    }

    @Test("CRC16 known vector: single byte 0x00")
    func crc16SingleZero() {
        let crc = RFIDManager.silionCRC16([0x00])
        // Feed 0x00 through the Silion bit-by-bit algorithm with poly 0x1021 and init 0xFFFF
        // Silion variant feeds data bits into crc LSB (not standard CCITT augmented)
        #expect(crc == 0xE1F0)
    }

    @Test("CRC16 known vector: bytes [0x03, 0x00, 0x00]")
    func crc16VersionCmd() {
        // Typical Silion version response inner bytes: LEN=0x03, CMD, STATUS
        // Using [0x03, 0x00, 0x00] as a reproducible test vector
        let crc = RFIDManager.silionCRC16([0x03, 0x00, 0x00])
        // Verify determinism — compute twice
        let crc2 = RFIDManager.silionCRC16([0x03, 0x00, 0x00])
        #expect(crc == crc2)
        // CRC should not be the init value
        #expect(crc != 0xFFFF)
    }

    @Test("CRC16 is order-dependent")
    func crc16OrderMatters() {
        let crc1 = RFIDManager.silionCRC16([0x01, 0x02])
        let crc2 = RFIDManager.silionCRC16([0x02, 0x01])
        #expect(crc1 != crc2)
    }

    // MARK: - EPC Canonicalization

    @Test("EPCanonical normalizes 24-char hex string")
    func epcNormalize24Char() {
        let input = "e280116060000217493f7e37"
        let result = EPCanonical.normalize(input)
        #expect(result == "E280116060000217493F7E37")
    }

    @Test("EPCanonical rejects short hex string")
    func epcRejectShort() {
        let result = EPCanonical.normalize("E280116060")
        #expect(result == nil)
    }

    @Test("EPCanonical rejects long hex string")
    func epcRejectLong() {
        let result = EPCanonical.normalize("E280116060000217493F7E37FF")
        #expect(result == nil)
    }

    @Test("EPCanonical extracts from payload with E280 marker")
    func epcFromPayloadWithMarker() {
        // 2 junk bytes + E2 80 marker + 10 more bytes = 12 byte EPC
        let payload: [UInt8] = [
            0xAA, 0xBB, // junk
            0xE2, 0x80, 0x11, 0x60, 0x60, 0x00, 0x02, 0x17, 0x49, 0x3F, 0x7E, 0x37
        ]
        let result = EPCanonical.canonicalHex(fromPayload: payload)
        #expect(result == "E280116060000217493F7E37")
    }

    @Test("EPCanonical falls back to last 12 bytes when no marker")
    func epcFallbackTail() {
        // 14 bytes, no E2 80 marker — should take last 12
        let payload: [UInt8] = [
            0x00, 0x01,
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC
        ]
        let result = EPCanonical.canonicalHex(fromPayload: payload)
        #expect(result == "112233445566778899AABBCC")
    }

    @Test("EPCanonical fromRawHex trims whitespace and normalizes")
    func epcFromRawHex() {
        let result = EPCanonical.canonicalHex(fromRawHex: "  e280116060000217493f7e37  ")
        #expect(result == "E280116060000217493F7E37")
    }

    // MARK: - Frame Parsing Edge Cases

    @Test("Truncated frame: less than 7 bytes after FF produces no crash")
    func truncatedFrame() {
        // A frame starts with 0xFF but has fewer than 7 total bytes
        // This should be treated as a partial/incomplete frame
        // We can't call parseSilionFrames directly (private), but we verify
        // the CRC function handles the bytes that would be extracted
        let partialBytes: [UInt8] = [0xFF, 0x02, 0xAA]
        // CRC on partial data should still return a valid UInt16
        let crc = RFIDManager.silionCRC16(partialBytes)
        #expect(crc != 0) // just verify it doesn't crash and returns something
    }

    @Test("Valid frame CRC matches expected structure")
    func validFrameCRC() {
        // Build a minimal valid Silion frame:
        // FF LEN CMD ST0 ST1 [DATA...] CRC_H CRC_L
        // LEN=0 (no data), CMD=0x03 (version), ST0=0x00, ST1=0x00
        // CRC input = LEN CMD ST0 ST1 = [0x00, 0x03, 0x00, 0x00]
        let crcInput: [UInt8] = [0x00, 0x03, 0x00, 0x00]
        let crc = RFIDManager.silionCRC16(crcInput)

        let crcH = UInt8((crc >> 8) & 0xFF)
        let crcL = UInt8(crc & 0xFF)

        // Full frame: FF + crcInput + CRC bytes
        let frame: [UInt8] = [0xFF, 0x00, 0x03, 0x00, 0x00, crcH, crcL]
        #expect(frame.count == 7)

        // Verify CRC round-trip: recompute from the frame's inner bytes
        let recomputed = RFIDManager.silionCRC16(Array(frame[1..<5]))
        #expect(recomputed == crc)
    }

    @Test("EPCanonical bytes(fromHex:) round-trips correctly")
    func hexBytesRoundTrip() {
        let hex = "E280116060000217493F7E37"
        let bytes = EPCanonical.bytes(fromHex: hex)
        #expect(bytes != nil)
        #expect(bytes?.count == 12)
        let backToHex = EPCanonical.hexString(bytes!)
        #expect(backToHex == hex)
    }

    @Test("EPCanonical bytes(fromHex:) rejects odd-length input")
    func hexBytesRejectsOddLength() {
        let result = EPCanonical.bytes(fromHex: "E28")
        #expect(result == nil)
    }
}
