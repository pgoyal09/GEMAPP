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

    private let logger = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "sync")
    /// Non-optional accessor — callers guard availability at entry points.
    /// Force-unwrap is safe because syncAll/sync check `isAvailable` first.
    private var client: SupabaseClient { SupabaseManager.shared.client! }
    private var isAvailable: Bool { SupabaseManager.shared.client != nil }
    private var tracker: SyncTracker { SyncTracker.shared }

    private init() {}

    // MARK: - Full Sync (Push + Pull)

    /// Push then pull — the main entry point for UI "Sync Now" buttons.
    func syncAll(modelContext: ModelContext) async {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }
        guard isAvailable else {
            syncError = "Cloud sync is not configured."
            return
        }
        guard SupabaseAuthService.shared.isAuthenticated else {
            syncError = "Not signed in"
            return
        }

        isSyncing = true
        syncError = nil
        syncProgress = "Starting sync..."
        let syncStart = ContinuousClock.now
        logger.info("Starting full sync (push + pull)")

        do {
            // Push
            let pushStart = ContinuousClock.now
            try await pushAll(modelContext: modelContext)
            let pushDuration = pushStart.duration(to: .now)
            logger.info("Push phase completed in \(pushDuration, privacy: .public)")

            // Pull
            let pullStart = ContinuousClock.now
            try await pullAll(modelContext: modelContext)
            let pullDuration = pullStart.duration(to: .now)
            logger.info("Pull phase completed in \(pullDuration, privacy: .public)")

            lastSyncDate = Date()
            tracker.resetPending()
            syncProgress = nil
            let totalDuration = syncStart.duration(to: .now)
            logger.info("Full sync completed successfully in \(totalDuration, privacy: .public)")
        } catch {
            syncError = error.localizedDescription
            syncProgress = nil
            let totalDuration = syncStart.duration(to: .now)
            logger.error("Sync failed after \(totalDuration, privacy: .public): \(error.localizedDescription)")
        }

        isSyncing = false
    }

    // MARK: - Push Only (upload local)

    /// Runs upload-only sync cycle (legacy entry point).
    func sync(modelContext: ModelContext) async {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }
        guard isAvailable else {
            syncError = "Cloud sync is not configured."
            return
        }
        guard SupabaseAuthService.shared.isAuthenticated else {
            syncError = "Not signed in"
            return
        }

        isSyncing = true
        syncError = nil
        syncProgress = "Starting push sync..."
        let pushStart = ContinuousClock.now
        logger.info("Starting push sync")

        do {
            try await pushAll(modelContext: modelContext)
            lastSyncDate = Date()
            tracker.resetPending()
            syncProgress = nil
            let duration = pushStart.duration(to: .now)
            logger.info("Push sync completed successfully in \(duration, privacy: .public)")
        } catch {
            syncError = error.localizedDescription
            syncProgress = nil
            let duration = pushStart.duration(to: .now)
            logger.error("Push sync failed after \(duration, privacy: .public): \(error.localizedDescription)")
        }

        isSyncing = false
    }

    // MARK: - Push All (internal)

    private func pushAll(modelContext: ModelContext) async throws {
        syncProgress = "Uploading customers..."
        try await uploadCustomers(context: modelContext)

        syncProgress = "Uploading gemstones..."
        try await uploadGemstones(context: modelContext)

        syncProgress = "Uploading memos..."
        try await uploadMemos(context: modelContext)

        syncProgress = "Uploading invoices..."
        try await uploadInvoices(context: modelContext)

        syncProgress = "Uploading line items..."
        try await uploadLineItems(context: modelContext)

        syncProgress = "Uploading lot transactions..."
        try await uploadLotTransactions(context: modelContext)

        syncProgress = "Uploading payments..."
        try await uploadPayments(context: modelContext)

        syncProgress = "Uploading history events..."
        try await uploadHistoryEvents(context: modelContext)

        syncProgress = "Uploading RFID tags..."
        try await uploadRFIDTags(context: modelContext)
    }

    // MARK: - Pull All (download remote → SwiftData)

    /// Downloads rows from Supabase where updated_at > last sync timestamp,
    /// then upserts into SwiftData (match on business key: email/sku/referenceNumber).
    /// If a local match is found, all fields are overwritten (last-write-wins). If not, a new entity is created.
    ///
    /// SYNC GUARDRAIL: Only 4 of 9 entities are pulled (Customers, Gemstones, Memos, Invoices).
    /// LineItems, LotTransactions, Payments, HistoryEvents, and RFIDTags are push-only.
    /// A fresh local install cannot reconstruct full state from remote alone.
    func pullAll(modelContext: ModelContext) async throws {
        syncProgress = "Downloading customers..."
        try await pullCustomers(context: modelContext)

        syncProgress = "Downloading gemstones..."
        try await pullGemstones(context: modelContext)

        syncProgress = "Downloading memos..."
        try await pullMemos(context: modelContext)

        syncProgress = "Downloading invoices..."
        try await pullInvoices(context: modelContext)

        try modelContext.save()
        logger.info("Pull sync completed — all tables downloaded")
    }

    // MARK: - Pull Customers

    /// Pull identity rule: match by `email` (unique business key).
    /// Conflict: last-write-wins — all local fields overwritten by remote values.
    /// See SYNC-MODEL.md §4 for identity rules, §5 for conflict model.
    private func pullCustomers(context: ModelContext) async throws {
        var query = client.from("customers").select()
        if let lastSync = tracker.lastSync(for: "customers") {
            query = query.gt("updated_at", value: lastSync.ISO8601Format())
        }
        let dtos: [CustomerDTO] = try await query.execute().value

        var updatedCount = 0
        var insertedCount = 0
        var duplicateWarnings = 0

        for dto in dtos {
            // SYNC GUARDRAIL: Validate business key is non-empty before matching
            guard !dto.email.trimmingCharacters(in: .whitespaces).isEmpty else {
                logger.warning("Pull customers: skipping DTO with empty email (remote id: \(dto.id?.uuidString ?? "nil"))")
                continue
            }

            // Match by email (unique business key) or insert new
            let email = dto.email
            let descriptor = FetchDescriptor<Customer>(
                predicate: #Predicate { $0.email == email }
            )
            let matches = try context.fetch(descriptor)

            // SYNC GUARDRAIL: Warn if business key matched multiple local records
            if matches.count > 1 {
                duplicateWarnings += 1
                logger.warning("Pull customers: duplicate business key detected — \(matches.count) local customers match email '\(email)'. Only first match will be updated.")
            }

            if let customer = matches.first {
                logger.debug("Pull customers: updating existing customer with email '\(email)'")
                customer.firstName = dto.firstName
                customer.lastName = dto.lastName
                customer.company = dto.company
                customer.phone = dto.phone
                customer.address = dto.address
                customer.city = dto.city
                customer.country = dto.country
                customer.zip = dto.zip
                customer.notes = dto.notes
                updatedCount += 1
            } else {
                logger.debug("Pull customers: inserting new customer with email '\(email)'")
                let customer = Customer(
                    firstName: dto.firstName,
                    lastName: dto.lastName,
                    company: dto.company,
                    email: dto.email,
                    phone: dto.phone,
                    address: dto.address,
                    city: dto.city,
                    country: dto.country,
                    zip: dto.zip,
                    notes: dto.notes
                )
                context.insert(customer)
                insertedCount += 1
            }
        }
        tracker.setLastSync(Date(), for: "customers")
        logger.info("Pulled \(dtos.count) customers (updated: \(updatedCount), inserted: \(insertedCount), duplicate warnings: \(duplicateWarnings))")
    }

    // MARK: - Pull Gemstones

    /// Pull identity rule: match by `sku` (unique business key, format TYPE-SHAPE-GROUP-NNN).
    /// Conflict: last-write-wins — all mutable fields overwritten by remote values.
    /// Note: Decimal→Double precision loss possible on cost/price fields. See SYNC-MODEL.md §7.
    private func pullGemstones(context: ModelContext) async throws {
        var query = client.from("gemstones").select()
        if let lastSync = tracker.lastSync(for: "gemstones") {
            query = query.gt("updated_at", value: lastSync.ISO8601Format())
        }
        let dtos: [GemstoneDTO] = try await query.execute().value

        var updatedCount = 0
        var insertedCount = 0
        var duplicateWarnings = 0

        for dto in dtos {
            // SYNC GUARDRAIL: Validate business key is non-empty before matching
            guard !dto.sku.trimmingCharacters(in: .whitespaces).isEmpty else {
                logger.warning("Pull gemstones: skipping DTO with empty SKU (remote id: \(dto.id?.uuidString ?? "nil"))")
                continue
            }

            let sku = dto.sku
            let descriptor = FetchDescriptor<Gemstone>(
                predicate: #Predicate { $0.sku == sku }
            )
            let matches = try context.fetch(descriptor)

            // SYNC GUARDRAIL: Warn if business key matched multiple local records
            if matches.count > 1 {
                duplicateWarnings += 1
                logger.warning("Pull gemstones: duplicate business key detected — \(matches.count) local gemstones match SKU '\(sku)'. Only first match will be updated.")
            }

            if let stone = matches.first {
                logger.debug("Pull gemstones: updating existing gemstone with SKU '\(sku)'")
                stone.caratWeight = dto.caratWeight
                stone.shape = dto.shape
                stone.origin = dto.origin
                stone.status = GemstoneStatus(rawValue: dto.status) ?? stone.status
                stone.color = dto.color
                stone.clarity = dto.clarity
                if let cut = dto.cut.nilIfEmpty { stone.cut = cut }
                stone.treatment = dto.treatment
                stone.polish = dto.polish
                stone.symmetry = dto.symmetry
                stone.fluorescence = dto.fluorescence
                stone.hasCert = dto.hasCert
                stone.certLab = dto.certLab
                stone.certNo = dto.certNo
                stone.length = dto.length
                stone.width = dto.width
                stone.height = dto.height
                stone.costPrice = Decimal(dto.costPrice)
                stone.sellPrice = Decimal(dto.sellPrice)
                stone.remainingCarats = dto.remainingCarats
                if let avg = dto.averageCostPerCarat { stone.averageCostPerCarat = Decimal(avg) }
                updatedCount += 1
            } else {
                logger.debug("Pull gemstones: inserting new gemstone with SKU '\(sku)'")
                let stone = Gemstone(
                    sku: dto.sku,
                    stoneType: StoneType(rawValue: dto.stoneType) ?? .diamond,
                    caratWeight: dto.caratWeight,
                    shape: dto.shape,
                    grouping: StoneGrouping(rawValue: dto.grouping) ?? .single,
                    origin: dto.origin,
                    color: dto.color,
                    clarity: dto.clarity,
                    cut: dto.cut,
                    treatment: dto.treatment
                )
                stone.status = GemstoneStatus(rawValue: dto.status) ?? .available
                stone.polish = dto.polish
                stone.symmetry = dto.symmetry
                stone.fluorescence = dto.fluorescence
                stone.hasCert = dto.hasCert
                stone.certLab = dto.certLab
                stone.certNo = dto.certNo
                stone.length = dto.length
                stone.width = dto.width
                stone.height = dto.height
                stone.costPrice = Decimal(dto.costPrice)
                stone.sellPrice = Decimal(dto.sellPrice)
                stone.currencyType = CurrencyType(rawValue: dto.currencyType) ?? .usd
                stone.exchangeRate = Decimal(dto.exchangeRate)
                stone.remainingCarats = dto.remainingCarats
                if let avg = dto.averageCostPerCarat { stone.averageCostPerCarat = Decimal(avg) }
                context.insert(stone)
                insertedCount += 1
            }
        }
        tracker.setLastSync(Date(), for: "gemstones")
        logger.info("Pulled \(dtos.count) gemstones (updated: \(updatedCount), inserted: \(insertedCount), duplicate warnings: \(duplicateWarnings))")
    }

    // MARK: - Pull Memos

    /// Pull identity rule: match by `referenceNumber` (unique business key).
    /// Conflict: last-write-wins — status, notes, salesperson, dateAssigned overwritten.
    /// Relationships: customer link is NOT re-established on pull. See SYNC-MODEL.md §5.
    private func pullMemos(context: ModelContext) async throws {
        var query = client.from("memos").select()
        if let lastSync = tracker.lastSync(for: "memos") {
            query = query.gt("updated_at", value: lastSync.ISO8601Format())
        }
        let dtos: [MemoDTO] = try await query.execute().value

        var updatedCount = 0
        var insertedCount = 0
        var duplicateWarnings = 0

        for dto in dtos {
            // SYNC GUARDRAIL: Validate business key is non-empty before matching
            guard !dto.referenceNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
                logger.warning("Pull memos: skipping DTO with empty referenceNumber (remote id: \(dto.id?.uuidString ?? "nil"))")
                continue
            }

            let refNum = dto.referenceNumber
            let descriptor = FetchDescriptor<Memo>(
                predicate: #Predicate { $0.referenceNumber == refNum }
            )
            let matches = try context.fetch(descriptor)

            // SYNC GUARDRAIL: Warn if business key matched multiple local records
            if matches.count > 1 {
                duplicateWarnings += 1
                logger.warning("Pull memos: duplicate business key detected — \(matches.count) local memos match referenceNumber '\(refNum)'. Only first match will be updated.")
            }

            if let memo = matches.first {
                logger.debug("Pull memos: updating existing memo '\(refNum)'")
                memo.status = MemoStatus(rawValue: dto.status) ?? memo.status
                memo.notes = dto.notes
                memo.salesperson = dto.salesperson
                memo.dateAssigned = dto.dateAssigned
                updatedCount += 1
            } else {
                logger.debug("Pull memos: inserting new memo '\(refNum)'")
                let memo = Memo(referenceNumber: dto.referenceNumber)
                memo.status = MemoStatus(rawValue: dto.status) ?? .onMemo
                memo.notes = dto.notes
                memo.salesperson = dto.salesperson
                memo.dateAssigned = dto.dateAssigned
                context.insert(memo)
                insertedCount += 1
            }
        }
        tracker.setLastSync(Date(), for: "memos")
        logger.info("Pulled \(dtos.count) memos (updated: \(updatedCount), inserted: \(insertedCount), duplicate warnings: \(duplicateWarnings))")
    }

    // MARK: - Pull Invoices

    /// Pull identity rule: match by `referenceNumber` (unique business key).
    /// Conflict: last-write-wins — status, notes, dueDate overwritten.
    /// Relationships: customer link is NOT re-established on pull. See SYNC-MODEL.md §5.
    private func pullInvoices(context: ModelContext) async throws {
        var query = client.from("invoices").select()
        if let lastSync = tracker.lastSync(for: "invoices") {
            query = query.gt("updated_at", value: lastSync.ISO8601Format())
        }
        let dtos: [InvoiceDTO] = try await query.execute().value

        var updatedCount = 0
        var insertedCount = 0
        var duplicateWarnings = 0

        for dto in dtos {
            // SYNC GUARDRAIL: Validate business key is non-empty before matching
            guard !dto.referenceNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
                logger.warning("Pull invoices: skipping DTO with empty referenceNumber (remote id: \(dto.id?.uuidString ?? "nil"))")
                continue
            }

            let refNum = dto.referenceNumber
            let descriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.referenceNumber == refNum }
            )
            let matches = try context.fetch(descriptor)

            // SYNC GUARDRAIL: Warn if business key matched multiple local records
            if matches.count > 1 {
                duplicateWarnings += 1
                logger.warning("Pull invoices: duplicate business key detected — \(matches.count) local invoices match referenceNumber '\(refNum)'. Only first match will be updated.")
            }

            if let invoice = matches.first {
                logger.debug("Pull invoices: updating existing invoice '\(refNum)'")
                invoice.status = InvoiceStatus(rawValue: dto.status) ?? invoice.status
                invoice.notes = dto.notes
                invoice.dueDate = dto.dueDate
                updatedCount += 1
            } else {
                logger.debug("Pull invoices: inserting new invoice '\(refNum)'")
                let invoice = Invoice(referenceNumber: dto.referenceNumber)
                invoice.status = InvoiceStatus(rawValue: dto.status) ?? .sent
                invoice.notes = dto.notes
                invoice.invoiceDate = dto.dateIssued ?? Date()
                invoice.dueDate = dto.dueDate
                context.insert(invoice)
                insertedCount += 1
            }
        }
        tracker.setLastSync(Date(), for: "invoices")
        logger.info("Pulled \(dtos.count) invoices (updated: \(updatedCount), inserted: \(insertedCount), duplicate warnings: \(duplicateWarnings))")
    }

    // MARK: - Upload Methods
    // Push strategy: upload ALL local records via upsert on `id` (stableSyncID).
    // No delta tracking — every sync re-uploads the full table.
    // updatedAt is always set to Date() at DTO conversion, so pushed rows always appear "just changed" remotely.

    private func uploadCustomers(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Customer>()
        let customers = try context.fetch(descriptor)
        let dtos = customers.map { CustomerDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                try await client.from("customers").upsert(dtos, onConflict: "id").execute()
                tracker.setLastSync(Date(), for: "customers")
                logger.info("Uploaded \(dtos.count) customers")
            } catch {
                logger.error("Upload customers failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func uploadGemstones(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Gemstone>()
        let stones = try context.fetch(descriptor)
        let dtos = stones.map { GemstoneDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                // Batch in groups of 100 to avoid payload limits
                for (index, batch) in dtos.chunked(into: 100).enumerated() {
                    try await client.from("gemstones").upsert(batch, onConflict: "id").execute()
                    logger.debug("Uploaded gemstone batch \(index + 1) (\(batch.count) records)")
                }
                tracker.setLastSync(Date(), for: "gemstones")
                logger.info("Uploaded \(dtos.count) gemstones")
            } catch {
                logger.error("Upload gemstones failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func uploadMemos(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Memo>()
        let memos = try context.fetch(descriptor)
        let dtos = memos.map { MemoDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                try await client.from("memos").upsert(dtos, onConflict: "id").execute()
                tracker.setLastSync(Date(), for: "memos")
                logger.info("Uploaded \(dtos.count) memos")
            } catch {
                logger.error("Upload memos failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func uploadInvoices(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Invoice>()
        let invoices = try context.fetch(descriptor)
        let dtos = invoices.map { InvoiceDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                try await client.from("invoices").upsert(dtos, onConflict: "id").execute()
                tracker.setLastSync(Date(), for: "invoices")
                logger.info("Uploaded \(dtos.count) invoices")
            } catch {
                logger.error("Upload invoices failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func uploadLineItems(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LineItem>()
        let items = try context.fetch(descriptor)
        let dtos = items.map { LineItemDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                for (index, batch) in dtos.chunked(into: 100).enumerated() {
                    try await client.from("line_items").upsert(batch, onConflict: "id").execute()
                    logger.debug("Uploaded line item batch \(index + 1) (\(batch.count) records)")
                }
                tracker.setLastSync(Date(), for: "line_items")
                logger.info("Uploaded \(dtos.count) line items")
            } catch {
                logger.error("Upload line items failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func uploadLotTransactions(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LotTransaction>()
        let txns = try context.fetch(descriptor)
        let dtos = txns.map { LotTransactionDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                try await client.from("lot_transactions").upsert(dtos, onConflict: "id").execute()
                tracker.setLastSync(Date(), for: "lot_transactions")
                logger.info("Uploaded \(dtos.count) lot transactions")
            } catch {
                logger.error("Upload lot transactions failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func uploadPayments(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Payment>()
        let payments = try context.fetch(descriptor)
        let dtos = payments.map { PaymentDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                try await client.from("payments").upsert(dtos, onConflict: "id").execute()
                tracker.setLastSync(Date(), for: "payments")
                logger.info("Uploaded \(dtos.count) payments")
            } catch {
                logger.error("Upload payments failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func uploadHistoryEvents(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<HistoryEvent>()
        let events = try context.fetch(descriptor)
        let dtos = events.map { HistoryEventDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                for (index, batch) in dtos.chunked(into: 100).enumerated() {
                    try await client.from("history_events").upsert(batch, onConflict: "id").execute()
                    logger.debug("Uploaded history event batch \(index + 1) (\(batch.count) records)")
                }
                tracker.setLastSync(Date(), for: "history_events")
                logger.info("Uploaded \(dtos.count) history events")
            } catch {
                logger.error("Upload history events failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func uploadRFIDTags(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<RFIDTag>()
        let tags = try context.fetch(descriptor)
        let dtos = tags.map { RFIDTagDTO(from: $0) }

        if !dtos.isEmpty {
            do {
                try await client.from("rfid_tags").upsert(dtos, onConflict: "id").execute()
                tracker.setLastSync(Date(), for: "rfid_tags")
                logger.info("Uploaded \(dtos.count) RFID tags")
            } catch {
                logger.error("Upload RFID tags failed (\(dtos.count) records): \(error.localizedDescription)")
                throw error
            }
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
