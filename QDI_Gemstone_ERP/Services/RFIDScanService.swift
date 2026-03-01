import Foundation
import SwiftData
import os

private let rfidLog = Logger(subsystem: "com.qdi.gemapp", category: "rfid.scan")

// MARK: - EPC Canonical Contract

enum EPCanonical {
    static let markerPrefix: [UInt8] = [0xE2, 0x80]
    static let canonicalByteCount = 12
    static let canonicalHexCount = canonicalByteCount * 2

    /// Canonical format: uppercase hex string with exactly 24 chars (12 bytes).
    static func normalize(_ input: String) -> String? {
        let filtered = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter(\.isHexDigit)
        guard filtered.count == canonicalHexCount else { return nil }
        return filtered
    }

    static func isValid(_ input: String) -> Bool {
        normalize(input) != nil
    }

    static func canonicalHex(fromRawHex rawHex: String) -> String? {
        let compact = rawHex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter(\.isHexDigit)

        guard !compact.isEmpty else { return nil }
        guard let bytes = bytes(fromHex: compact), !bytes.isEmpty else { return nil }

        if let candidate = canonicalHex(fromPayload: bytes) {
            return candidate
        }

        return normalize(compact)
    }

    static func canonicalHex(fromPayload payload: [UInt8]) -> String? {
        guard payload.count >= 2 else { return nil }

        for i in 0..<(payload.count - 1) where payload[i] == markerPrefix[0] && payload[i + 1] == markerPrefix[1] {
            let end = min(i + canonicalByteCount, payload.count)
            let chunk = Array(payload[i..<end])
            let hex = hexString(chunk)
            if let normalized = normalize(hex) {
                return normalized
            }
        }

        let fallbackStart = max(0, payload.count - canonicalByteCount)
        let fallbackHex = hexString(Array(payload[fallbackStart...]))
        return normalize(fallbackHex)
    }

    static func bytes(fromHex hex: String) -> [UInt8]? {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var output: [UInt8] = []
        output.reserveCapacity(hex.count / 2)

        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            let pair = String(hex[idx..<next])
            guard let byte = UInt8(pair, radix: 16) else { return nil }
            output.append(byte)
            idx = next
        }

        return output
    }

    static func hexString(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}

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

struct AssignmentConflictInput {
    let targetStoneSKU: String
    let targetHasExistingRFID: Bool
    let replaceExisting: Bool
    let epcAssignedToOtherSKU: String?
    let tidAssignedToOtherSKU: String?
}

enum AssignmentConflict {
    case epcAlreadyAssigned(String)
    case tidAlreadyAssigned(String)
    case replaceNotConfirmed(String)

    var message: String {
        switch self {
        case .epcAlreadyAssigned(let sku): return "EPC already assigned to \(sku)"
        case .tidAlreadyAssigned(let sku): return "TID already assigned to \(sku)"
        case .replaceNotConfirmed: return "Stone already has RFID. Confirm replace."
        }
    }
}

// MARK: - RFID Scan Service

/// Handles RFID tag lookup and assignment. Use canonical EPC for primary lookup; TID as fallback when available.
enum RFIDScanService {

    static func evaluateAssignmentConflict(_ input: AssignmentConflictInput) -> AssignmentConflict? {
        if let sku = input.epcAssignedToOtherSKU {
            return .epcAlreadyAssigned(sku)
        }
        if let sku = input.tidAssignedToOtherSKU {
            return .tidAlreadyAssigned(sku)
        }
        if input.targetHasExistingRFID && !input.replaceExisting {
            return .replaceNotConfirmed(input.targetStoneSKU)
        }
        return nil
    }

    /// Transitional migration: copy canonicalized legacy `rfidTag` values into `rfidEpc` if missing.
    static func migrateLegacyFieldsIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Gemstone>()
        let stones: [Gemstone]
        do {
            stones = try modelContext.fetch(descriptor)
        } catch {
            rfidLog.error("Legacy migration fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        var changed = 0
        for stone in stones {
            guard stone.rfidEpc == nil,
                  let legacy = stone.rfidTag,
                  let canonical = EPCanonical.normalize(legacy) ?? EPCanonical.canonicalHex(fromRawHex: legacy)
            else { continue }

            stone.rfidEpc = canonical
            changed += 1
        }

        guard changed > 0 else { return }
        do {
            try modelContext.save()
            rfidLog.info("Migrated \(changed) legacy RFID value(s) to canonical EPC")
        } catch {
            rfidLog.error("Legacy migration save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Process a scanned tag: lookup by canonical EPC and update lastSeen on match.
    static func processScannedTag(rawHex: String, modelContext: ModelContext) -> ScanResult {
        guard let epc = EPCanonical.canonicalHex(fromRawHex: rawHex) else {
            rfidLog.error("Scan rejected: raw payload does not contain a valid canonical EPC")
            return .unknownTag(epc: rawHex.trimmingCharacters(in: .whitespacesAndNewlines), tid: nil)
        }

        rfidLog.debug("Scan normalized EPC=\(epc, privacy: .public)")

        // 1. Preferred source: dedicated RFIDTag model.
        let tagPredicate = #Predicate<RFIDTag> { tag in
            tag.epcCurrent == epc
        }
        let tagDescriptor = FetchDescriptor<RFIDTag>(predicate: tagPredicate)

        do {
            if let tag = try modelContext.fetch(tagDescriptor).first,
               let stone = tag.assignedStone {
                let now = Date()
                tag.lastSeenAt = now
                stone.rfidLastSeenAt = now
                do {
                    try modelContext.save()
                } catch {
                    rfidLog.error("Failed to persist tag lastSeen update: \(error.localizedDescription, privacy: .public)")
                }
                return .matched(stone)
            }
        } catch {
            rfidLog.error("RFIDTag lookup failed: \(error.localizedDescription, privacy: .public)")
        }

        // 2. Transitional fallback for legacy rows.
        // TODO: remove legacy read bridge once all historical records are migrated to RFIDTag + rfidEpc.
        let epcPredicate = #Predicate<Gemstone> { stone in
            stone.rfidEpc == epc || stone.rfidTag == epc
        }
        let epcDescriptor = FetchDescriptor<Gemstone>(predicate: epcPredicate)

        do {
            if let stone = try modelContext.fetch(epcDescriptor).first {
                stone.rfidLastSeenAt = Date()
                do {
                    try modelContext.save()
                } catch {
                    rfidLog.error("Failed to persist legacy stone lastSeen update: \(error.localizedDescription, privacy: .public)")
                }
                return .matched(stone)
            }
        } catch {
            rfidLog.error("Legacy gemstone lookup failed: \(error.localizedDescription, privacy: .public)")
        }

        rfidLog.info("Lookup result: unknown_tag EPC=\(epc, privacy: .public)")
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
        guard let epcCanonical = EPCanonical.normalize(epc) ?? EPCanonical.canonicalHex(fromRawHex: epc) else {
            rfidLog.error("Assignment conflict: invalid EPC format")
            return .conflict("Invalid EPC format")
        }

        // Check EPC not already assigned on another RFIDTag.
        var epcConflictSKU: String?
        do {
            let epcTagPredicate = #Predicate<RFIDTag> { tag in
                tag.epcCurrent == epcCanonical
            }
            let epcTagDescriptor = FetchDescriptor<RFIDTag>(predicate: epcTagPredicate)
            if let existingTag = try modelContext.fetch(epcTagDescriptor).first,
               let assignedStone = existingTag.assignedStone,
               assignedStone.id != stone.id {
                epcConflictSKU = assignedStone.sku
            }
        } catch {
            rfidLog.error("RFIDTag uniqueness check failed: \(error.localizedDescription, privacy: .public)")
            return .conflict(error.localizedDescription)
        }

        // Transitional fallback uniqueness check on legacy gemstone fields.
        // TODO: remove this bridge after full legacy cleanup.
        do {
            let epcLegacyPredicate = #Predicate<Gemstone> { s in
                s.rfidEpc == epcCanonical || s.rfidTag == epcCanonical
            }
            let epcLegacyDescriptor = FetchDescriptor<Gemstone>(predicate: epcLegacyPredicate)
            if let existing = try modelContext.fetch(epcLegacyDescriptor).first(where: { $0.id != stone.id }) {
                epcConflictSKU = existing.sku
            }
        } catch {
            rfidLog.error("Legacy EPC uniqueness check failed: \(error.localizedDescription, privacy: .public)")
            return .conflict(error.localizedDescription)
        }

        var tidConflictSKU: String?
        if let tidTrimmed = tid?.trimmingCharacters(in: .whitespacesAndNewlines), !tidTrimmed.isEmpty {
            do {
                let tidPredicate = #Predicate<Gemstone> { s in s.rfidTid == tidTrimmed }
                let tidDescriptor = FetchDescriptor<Gemstone>(predicate: tidPredicate)
                if let existing = try modelContext.fetch(tidDescriptor).first(where: { $0.id != stone.id }) {
                    tidConflictSKU = existing.sku
                }
            } catch {
                rfidLog.error("TID uniqueness check failed: \(error.localizedDescription, privacy: .public)")
                return .conflict(error.localizedDescription)
            }
        }

        let hadExisting = stone.effectiveRfidEpc != nil
        let conflictInput = AssignmentConflictInput(
            targetStoneSKU: stone.sku,
            targetHasExistingRFID: hadExisting,
            replaceExisting: replaceExisting,
            epcAssignedToOtherSKU: epcConflictSKU,
            tidAssignedToOtherSKU: tidConflictSKU
        )
        if let conflict = evaluateAssignmentConflict(conflictInput) {
            rfidLog.info("Assignment conflict for stone=\(stone.sku, privacy: .public): \(conflict.message, privacy: .public)")
            return .conflict(conflict.message)
        }

        let now = Date()
        stone.rfidEpc = epcCanonical
        stone.rfidTid = tid?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        stone.rfidAssignedAt = now
        stone.rfidLastSeenAt = now
        stone.rfidStatus = RFIDTagLifecycleStatus.assigned.rawValue
        stone.rfidTag = nil // migration step: canonical write target only.

        // Route new writes through dedicated RFIDTag model.
        let allTagsDescriptor = FetchDescriptor<RFIDTag>()
        let stoneTag: RFIDTag?
        do {
            stoneTag = try modelContext.fetch(allTagsDescriptor).first(where: { $0.assignedStone?.id == stone.id })
        } catch {
            rfidLog.error("Existing tag lookup by stone failed: \(error.localizedDescription, privacy: .public)")
            return .conflict(error.localizedDescription)
        }

        if let stoneTag {
            stoneTag.epcCurrent = epcCanonical
            stoneTag.tidLastVerified = stone.rfidTid
            stoneTag.status = .assigned
            stoneTag.lastSeenAt = now
            stoneTag.lastVerifiedAt = now
        } else {
            let newTag = RFIDTag(
                epcCurrent: epcCanonical,
                tidLastVerified: stone.rfidTid,
                assignedStone: stone,
                status: .assigned,
                firstSeenAt: now,
                lastSeenAt: now,
                lastVerifiedAt: now
            )
            modelContext.insert(newTag)
        }

        do {
            try modelContext.save()
            rfidLog.info("Assignment success: \(hadExisting ? "replaced" : "assigned", privacy: .public) stone=\(stone.sku, privacy: .public)")
            return hadExisting ? .replaced : .assigned
        } catch {
            rfidLog.error("Assignment failed: \(error.localizedDescription, privacy: .public)")
            return .conflict(error.localizedDescription)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
