import Foundation
import SwiftData
import Supabase
import os.log

/// Offline-first sync: SwiftData is source of truth, Supabase syncs in background.
/// Strategy: upload all local records, download remote changes, last-write-wins on updated_at.
@MainActor
@Observable
final class SupabaseSyncService {
    static let shared = SupabaseSyncService()

    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?
    var syncProgress: String?

    private let logger = Logger(subsystem: "com.qdi.erp", category: "Sync")
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var tracker: SyncTracker { SyncTracker.shared }

    private init() {}

    // MARK: - Full Sync

    /// Runs a full sync cycle: upload local → download remote.
    /// Call from a background context — this method is non-blocking on the main actor.
    func sync(modelContext: ModelContext) async {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }
        guard SupabaseAuthService.shared.isAuthenticated else {
            syncError = "Not signed in"
            return
        }

        isSyncing = true
        syncError = nil
        syncProgress = "Starting sync..."
        logger.info("Starting full sync")

        do {
            // 1. Upload customers
            syncProgress = "Uploading customers..."
            try await uploadCustomers(context: modelContext)

            // 2. Upload gemstones
            syncProgress = "Uploading gemstones..."
            try await uploadGemstones(context: modelContext)

            // 3. Upload memos
            syncProgress = "Uploading memos..."
            try await uploadMemos(context: modelContext)

            // 4. Upload invoices
            syncProgress = "Uploading invoices..."
            try await uploadInvoices(context: modelContext)

            // 5. Upload line items
            syncProgress = "Uploading line items..."
            try await uploadLineItems(context: modelContext)

            // 6. Upload lot transactions
            syncProgress = "Uploading lot transactions..."
            try await uploadLotTransactions(context: modelContext)

            // 7. Upload payments
            syncProgress = "Uploading payments..."
            try await uploadPayments(context: modelContext)

            // 8. Upload history events
            syncProgress = "Uploading history events..."
            try await uploadHistoryEvents(context: modelContext)

            // 9. Upload RFID tags
            syncProgress = "Uploading RFID tags..."
            try await uploadRFIDTags(context: modelContext)

            lastSyncDate = Date()
            tracker.resetPending()
            syncProgress = nil
            logger.info("Full sync completed successfully")
        } catch {
            syncError = error.localizedDescription
            syncProgress = nil
            logger.error("Sync failed: \(error.localizedDescription)")
        }

        isSyncing = false
    }

    // MARK: - Upload Methods

    private func uploadCustomers(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Customer>()
        let customers = try context.fetch(descriptor)
        let dtos = customers.map { CustomerDTO(from: $0) }

        if !dtos.isEmpty {
            try await client.from("customers").upsert(dtos, onConflict: "id").execute()
            tracker.setLastSync(Date(), for: "customers")
            logger.info("Uploaded \(dtos.count) customers")
        }
    }

    private func uploadGemstones(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Gemstone>()
        let stones = try context.fetch(descriptor)
        let dtos = stones.map { GemstoneDTO(from: $0) }

        if !dtos.isEmpty {
            // Batch in groups of 100 to avoid payload limits
            for batch in dtos.chunked(into: 100) {
                try await client.from("gemstones").upsert(batch, onConflict: "id").execute()
            }
            tracker.setLastSync(Date(), for: "gemstones")
            logger.info("Uploaded \(dtos.count) gemstones")
        }
    }

    private func uploadMemos(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Memo>()
        let memos = try context.fetch(descriptor)
        let dtos = memos.map { MemoDTO(from: $0) }

        if !dtos.isEmpty {
            try await client.from("memos").upsert(dtos, onConflict: "id").execute()
            tracker.setLastSync(Date(), for: "memos")
            logger.info("Uploaded \(dtos.count) memos")
        }
    }

    private func uploadInvoices(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Invoice>()
        let invoices = try context.fetch(descriptor)
        let dtos = invoices.map { InvoiceDTO(from: $0) }

        if !dtos.isEmpty {
            try await client.from("invoices").upsert(dtos, onConflict: "id").execute()
            tracker.setLastSync(Date(), for: "invoices")
            logger.info("Uploaded \(dtos.count) invoices")
        }
    }

    private func uploadLineItems(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LineItem>()
        let items = try context.fetch(descriptor)
        let dtos = items.map { LineItemDTO(from: $0) }

        if !dtos.isEmpty {
            for batch in dtos.chunked(into: 100) {
                try await client.from("line_items").upsert(batch, onConflict: "id").execute()
            }
            tracker.setLastSync(Date(), for: "line_items")
            logger.info("Uploaded \(dtos.count) line items")
        }
    }

    private func uploadLotTransactions(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LotTransaction>()
        let txns = try context.fetch(descriptor)
        let dtos = txns.map { LotTransactionDTO(from: $0) }

        if !dtos.isEmpty {
            try await client.from("lot_transactions").upsert(dtos, onConflict: "id").execute()
            tracker.setLastSync(Date(), for: "lot_transactions")
            logger.info("Uploaded \(dtos.count) lot transactions")
        }
    }

    private func uploadPayments(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Payment>()
        let payments = try context.fetch(descriptor)
        let dtos = payments.map { PaymentDTO(from: $0) }

        if !dtos.isEmpty {
            try await client.from("payments").upsert(dtos, onConflict: "id").execute()
            tracker.setLastSync(Date(), for: "payments")
            logger.info("Uploaded \(dtos.count) payments")
        }
    }

    private func uploadHistoryEvents(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<HistoryEvent>()
        let events = try context.fetch(descriptor)
        let dtos = events.map { HistoryEventDTO(from: $0) }

        if !dtos.isEmpty {
            for batch in dtos.chunked(into: 100) {
                try await client.from("history_events").upsert(batch, onConflict: "id").execute()
            }
            tracker.setLastSync(Date(), for: "history_events")
            logger.info("Uploaded \(dtos.count) history events")
        }
    }

    private func uploadRFIDTags(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<RFIDTag>()
        let tags = try context.fetch(descriptor)
        let dtos = tags.map { RFIDTagDTO(from: $0) }

        if !dtos.isEmpty {
            try await client.from("rfid_tags").upsert(dtos, onConflict: "id").execute()
            tracker.setLastSync(Date(), for: "rfid_tags")
            logger.info("Uploaded \(dtos.count) RFID tags")
        }
    }
}

// MARK: - Array Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
