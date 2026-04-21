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
        logger.info("Starting full sync (push + pull)")

        do {
            // Push
            try await pushAll(modelContext: modelContext)

            // Pull
            try await pullAll(modelContext: modelContext)

            lastSyncDate = Date()
            tracker.resetPending()
            syncProgress = nil
            logger.info("Full sync (push + pull) completed successfully")
        } catch {
            syncError = error.localizedDescription
            syncProgress = nil
            logger.error("Sync failed: \(error.localizedDescription)")
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
        logger.info("Starting push sync")

        do {
            try await pushAll(modelContext: modelContext)
            lastSyncDate = Date()
            tracker.resetPending()
            syncProgress = nil
            logger.info("Push sync completed successfully")
        } catch {
            syncError = error.localizedDescription
            syncProgress = nil
            logger.error("Push sync failed: \(error.localizedDescription)")
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
    /// then upserts into SwiftData (match on sku/referenceNumber/id, create if missing, update if exists).
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

    private func pullCustomers(context: ModelContext) async throws {
        var query = client.from("customers").select()
        if let lastSync = tracker.lastSync(for: "customers") {
            query = query.gt("updated_at", value: lastSync.ISO8601Format())
        }
        let dtos: [CustomerDTO] = try await query.execute().value

        for dto in dtos {
            // Match by email (unique business key) or insert new
            let email = dto.email
            let descriptor = FetchDescriptor<Customer>(
                predicate: #Predicate { $0.email == email }
            )
            let existing = try context.fetch(descriptor).first

            if let customer = existing {
                customer.firstName = dto.firstName
                customer.lastName = dto.lastName
                customer.company = dto.company
                customer.phone = dto.phone
                customer.address = dto.address
                customer.city = dto.city
                customer.country = dto.country
                customer.zip = dto.zip
                customer.notes = dto.notes
            } else {
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
            }
        }
        tracker.setLastSync(Date(), for: "customers")
        logger.info("Pulled \(dtos.count) customers")
    }

    // MARK: - Pull Gemstones

    private func pullGemstones(context: ModelContext) async throws {
        var query = client.from("gemstones").select()
        if let lastSync = tracker.lastSync(for: "gemstones") {
            query = query.gt("updated_at", value: lastSync.ISO8601Format())
        }
        let dtos: [GemstoneDTO] = try await query.execute().value

        for dto in dtos {
            let sku = dto.sku
            let descriptor = FetchDescriptor<Gemstone>(
                predicate: #Predicate { $0.sku == sku }
            )
            let existing = try context.fetch(descriptor).first

            if let stone = existing {
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
            } else {
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
            }
        }
        tracker.setLastSync(Date(), for: "gemstones")
        logger.info("Pulled \(dtos.count) gemstones")
    }

    // MARK: - Pull Memos

    private func pullMemos(context: ModelContext) async throws {
        var query = client.from("memos").select()
        if let lastSync = tracker.lastSync(for: "memos") {
            query = query.gt("updated_at", value: lastSync.ISO8601Format())
        }
        let dtos: [MemoDTO] = try await query.execute().value

        for dto in dtos {
            let refNum = dto.referenceNumber
            let descriptor = FetchDescriptor<Memo>(
                predicate: #Predicate { $0.referenceNumber == refNum }
            )
            let existing = try context.fetch(descriptor).first

            if let memo = existing {
                memo.status = MemoStatus(rawValue: dto.status) ?? memo.status
                memo.notes = dto.notes
                memo.salesperson = dto.salesperson
                memo.dateAssigned = dto.dateAssigned
            } else {
                let memo = Memo(referenceNumber: dto.referenceNumber)
                memo.status = MemoStatus(rawValue: dto.status) ?? .onMemo
                memo.notes = dto.notes
                memo.salesperson = dto.salesperson
                memo.dateAssigned = dto.dateAssigned
                context.insert(memo)
            }
        }
        tracker.setLastSync(Date(), for: "memos")
        logger.info("Pulled \(dtos.count) memos")
    }

    // MARK: - Pull Invoices

    private func pullInvoices(context: ModelContext) async throws {
        var query = client.from("invoices").select()
        if let lastSync = tracker.lastSync(for: "invoices") {
            query = query.gt("updated_at", value: lastSync.ISO8601Format())
        }
        let dtos: [InvoiceDTO] = try await query.execute().value

        for dto in dtos {
            let refNum = dto.referenceNumber
            let descriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.referenceNumber == refNum }
            )
            let existing = try context.fetch(descriptor).first

            if let invoice = existing {
                invoice.status = InvoiceStatus(rawValue: dto.status) ?? invoice.status
                invoice.notes = dto.notes
                invoice.dueDate = dto.dueDate
            } else {
                let invoice = Invoice(referenceNumber: dto.referenceNumber)
                invoice.status = InvoiceStatus(rawValue: dto.status) ?? .sent
                invoice.notes = dto.notes
                invoice.invoiceDate = dto.dateIssued ?? Date()
                invoice.dueDate = dto.dueDate
                context.insert(invoice)
            }
        }
        tracker.setLastSync(Date(), for: "invoices")
        logger.info("Pulled \(dtos.count) invoices")
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
