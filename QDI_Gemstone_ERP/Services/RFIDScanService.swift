import Foundation
import SwiftData

// MARK: - Scan Result

enum ScanResult {
    case matched(Gemstone)
    case unknownTag(epc: String, tid: String?)
}

// MARK: - Assignment Result

enum AssignmentResult {
    case assigned
    case conflict(String)
    case replaced
}

// MARK: - RFID Scan Service

/// Handles RFID tag lookup and assignment. Use EPC for primary lookup; TID as fallback when available.
enum RFIDScanService {

    /// Extract stable canonical EPC from raw hex payload. Matches RFIDManager logic (E2 80 marker + 12 bytes).
    static func extractCanonicalEPC(from rawHex: String) -> String {
        let hex = rawHex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !hex.isEmpty else { return rawHex }

        // Convert hex string to bytes (pairs)
        var bytes: [UInt8] = []
        var i = hex.startIndex
        while i < hex.endIndex {
            let next = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            let pair = String(hex[i..<next])
            if pair.count == 2, let byte = UInt8(pair, radix: 16) {
                bytes.append(byte)
            }
            i = next
        }

        let stableChunkLen = 12
        guard bytes.count >= 2 else {
            return rawHex
        }
        for i in 0..<(bytes.count - 1) {
            if bytes[i] == 0xE2 && bytes[i + 1] == 0x80 {
                let start = i
                let end = min(start + stableChunkLen, bytes.count)
                let chunk = Array(bytes[start..<end])
                return chunk.map { String(format: "%02X", $0) }.joined()
            }
        }
        let fallbackStart = max(0, bytes.count - stableChunkLen)
        let chunk = Array(bytes[fallbackStart...])
        return chunk.map { String(format: "%02X", $0) }.joined()
    }

    /// Process a scanned tag: lookup by EPC then TID; update lastSeen on match; return matched or unknownTag.
    static func processScannedTag(rawHex: String, modelContext: ModelContext) -> ScanResult {
        let epc = extractCanonicalEPC(from: rawHex)
        #if DEBUG
        print("[RFID] Scan raw=\(rawHex.prefix(40))… epc=\(epc)")
        #endif

        // 1. Try EPC (rfidEpc or rfidTag for backward compat)
        let epcPredicate = #Predicate<Gemstone> { stone in
            stone.rfidEpc == epc || stone.rfidTag == epc
        }
        let epcDescriptor = FetchDescriptor<Gemstone>(predicate: epcPredicate)
        if let stones = try? modelContext.fetch(epcDescriptor), let stone = stones.first {
            stone.rfidLastSeenAt = Date()
            try? modelContext.save()
            #if DEBUG
            print("[RFID] Lookup result: matched stone \(stone.sku)")
            #endif
            return .matched(stone)
        }

        // 2. TID not typically in raw payload; if we had TID we'd try rfidTid == tid
        // For now we only use EPC. unknownTag returns the EPC (and raw as fallback for display).
        #if DEBUG
        print("[RFID] Lookup result: unknown_tag epc=\(epc)")
        #endif
        return .unknownTag(epc: epc, tid: nil)
    }

    /// Assign EPC (and optionally TID) to a stone. Enforces uniqueness; requires replaceExisting if stone already has different RFID.
    static func assignTagToStone(
        epc: String,
        tid: String?,
        stone: Gemstone,
        replaceExisting: Bool,
        modelContext: ModelContext
    ) -> AssignmentResult {
        let epcTrimmed = epc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !epcTrimmed.isEmpty else {
            #if DEBUG
            print("[RFID] Assignment conflict: empty EPC")
            #endif
            return .conflict("Empty EPC")
        }

        // Check EPC not already on another stone
        let epcPredicate = #Predicate<Gemstone> { s in
            s.rfidEpc == epcTrimmed || s.rfidTag == epcTrimmed
        }
        let epcDescriptor = FetchDescriptor<Gemstone>(predicate: epcPredicate)
        if let existing = (try? modelContext.fetch(epcDescriptor))?.first(where: { $0.id != stone.id }) {
            #if DEBUG
            print("[RFID] Assignment conflict: EPC already on stone \(existing.sku)")
            #endif
            return .conflict("EPC already assigned to \(existing.sku)")
        }

        if let tidTrimmed = tid?.trimmingCharacters(in: .whitespacesAndNewlines), !tidTrimmed.isEmpty {
            let tidPredicate = #Predicate<Gemstone> { s in s.rfidTid == tidTrimmed }
            let tidDescriptor = FetchDescriptor<Gemstone>(predicate: tidPredicate)
            if let existing = (try? modelContext.fetch(tidDescriptor))?.first(where: { $0.id != stone.id }) {
                #if DEBUG
                print("[RFID] Assignment conflict: TID already on stone \(existing.sku)")
                #endif
                return .conflict("TID already assigned to \(existing.sku)")
            }
        }

        let hadExisting = stone.rfidEpc != nil || stone.rfidTag != nil
        if hadExisting && !replaceExisting {
            #if DEBUG
            print("[RFID] Assignment conflict: stone \(stone.sku) already has RFID, replace not confirmed")
            #endif
            return .conflict("Stone already has RFID. Confirm replace.")
        }

        stone.rfidEpc = epcTrimmed
        stone.rfidTid = tid?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        stone.rfidAssignedAt = Date()
        stone.rfidLastSeenAt = Date()
        stone.rfidStatus = "assigned"
        stone.rfidTag = nil  // migrate to rfidEpc only

        do {
            try modelContext.save()
            #if DEBUG
            print("[RFID] Assignment success: \(hadExisting ? "replaced" : "assigned") stone \(stone.sku) epc=\(epcTrimmed.prefix(16))…")
            #endif
            return hadExisting ? .replaced : .assigned
        } catch {
            #if DEBUG
            print("[RFID] Assignment failed: \(error)")
            #endif
            return .conflict(error.localizedDescription)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
