import Foundation
import SwiftData
import os

private let rfidLog = Logger(subsystem: "com.qdi.gemapp", category: "rfid.scan")

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

// MARK: - Assignment Conflict

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
        case .replaceNotConfirmed:         return "Stone already has RFID. Confirm replace."
        }
    }
}

// MARK: - RFID Scan Service

/// Handles RFID tag lookup and assignment.
/// Uses canonical EPC for primary lookup; TID as fallback when available.
///
/// v2 changes:
/// - Gemstone no longer has `rfidTag` or `rfidStatus` fields.
/// - `rfidEpc` is the sole EPC field on Gemstone.
/// - Legacy migration path removed (no `rfidTag` to migrate from).
enum RFIDScanService {

    // MARK: - Save Batching

    private static let saveBatchSize = 50
    private static let saveInterval: TimeInterval = 2.0
    nonisolated(unsafe) private static var pendingSaveCount = 0
    nonisolated(unsafe) private static var lastSaveTime = Date()

    private static func saveIfNeeded(_ modelContext: ModelContext) {
        pendingSaveCount += 1
        if pendingSaveCount >= saveBatchSize || Date().timeIntervalSince(lastSaveTime) >= saveInterval {
            try? modelContext.save()
            pendingSaveCount = 0
            lastSaveTime = Date()
        }
    }

    /// Flush any pending unsaved changes (call when scanning stops).
    static func flushPendingSaves(_ modelContext: ModelContext) {
        guard pendingSaveCount > 0 else { return }
        try? modelContext.save()
        pendingSaveCount = 0
        lastSaveTime = Date()
    }

    // MARK: - Conflict Evaluation

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

    // MARK: - Tag Lookup

    /// Process a scanned tag: normalize the raw hex, look up by canonical EPC,
    /// and update lastSeen on match.
    static func processScannedTag(rawHex: String, modelContext: ModelContext) -> ScanResult {
        guard let epc = EPCanonical.canonicalHex(fromRawHex: rawHex) else {
            rfidLog.error("Scan rejected: raw payload does not contain a valid canonical EPC")
            return .unknownTag(epc: rawHex.trimmingCharacters(in: .whitespacesAndNewlines), tid: nil)
        }

        rfidLog.debug("Scan normalized EPC=\(epc, privacy: .public)")

        // 1. Primary source: dedicated RFIDTag model.
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
                saveIfNeeded(modelContext)
                return .matched(stone)
            }
        } catch {
            rfidLog.error("RFIDTag lookup failed: \(error.localizedDescription, privacy: .public)")
        }

        // 2. Fallback: direct lookup on Gemstone.rfidEpc.
        let epcPredicate = #Predicate<Gemstone> { stone in
            stone.rfidEpc == epc
        }
        let epcDescriptor = FetchDescriptor<Gemstone>(predicate: epcPredicate)

        do {
            if let stone = try modelContext.fetch(epcDescriptor).first {
                stone.rfidLastSeenAt = Date()
                saveIfNeeded(modelContext)
                return .matched(stone)
            }
        } catch {
            rfidLog.error("Gemstone EPC lookup failed: \(error.localizedDescription, privacy: .public)")
        }

        rfidLog.info("Lookup result: unknown_tag EPC=\(epc, privacy: .public)")
        return .unknownTag(epc: epc, tid: nil)
    }

    // MARK: - Tag Assignment

    /// Assign EPC (and optionally TID) to a stone. Enforces uniqueness;
    /// requires `replaceExisting` if stone already has a different RFID.
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

        // --- EPC uniqueness on RFIDTag ---
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
            return .conflict(ErrorMapper.userMessage(from: error))
        }

        // --- EPC uniqueness on Gemstone.rfidEpc ---
        do {
            let epcGemstonePredicate = #Predicate<Gemstone> { s in
                s.rfidEpc == epcCanonical
            }
            let epcGemstoneDescriptor = FetchDescriptor<Gemstone>(predicate: epcGemstonePredicate)
            if let existing = try modelContext.fetch(epcGemstoneDescriptor).first(where: { $0.id != stone.id }) {
                epcConflictSKU = existing.sku
            }
        } catch {
            rfidLog.error("EPC uniqueness check failed: \(error.localizedDescription, privacy: .public)")
            return .conflict(ErrorMapper.userMessage(from: error))
        }

        // --- TID uniqueness ---
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
                return .conflict(ErrorMapper.userMessage(from: error))
            }
        }

        // --- Conflict evaluation ---
        let hadExisting = stone.rfidEpc != nil
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

        // --- Write ---
        let now = Date()
        stone.rfidEpc = epcCanonical
        stone.rfidTid = tid?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        stone.rfidAssignedAt = now
        stone.rfidLastSeenAt = now

        // Route writes through dedicated RFIDTag model.
        let allTagsDescriptor = FetchDescriptor<RFIDTag>()
        let stoneTag: RFIDTag?
        do {
            stoneTag = try modelContext.fetch(allTagsDescriptor).first(where: { $0.assignedStone?.id == stone.id })
        } catch {
            rfidLog.error("Existing tag lookup by stone failed: \(error.localizedDescription, privacy: .public)")
            return .conflict(ErrorMapper.userMessage(from: error))
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
            return .conflict(ErrorMapper.userMessage(from: error))
        }
    }
}

// nilIfEmpty is provided by Utilities/Extensions/String+Helpers.swift
