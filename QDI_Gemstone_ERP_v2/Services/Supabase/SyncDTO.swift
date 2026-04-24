import Foundation
import SwiftData

// MARK: - Current User ID

/// Returns the current Supabase auth user ID, or nil if not logged in.
/// Used to tag remote rows with the owning user. Currently single-user assumed — no RLS enforcement.
private func currentUserId() -> UUID? {
    guard let client = SupabaseManager.shared.client,
          let session = try? client.auth.currentSession else { return nil }
    return session.user.id
}

// MARK: - Stable Sync ID

/// Generates a deterministic UUID from entity type + persistentModelID.
/// This ensures the same record always maps to the same Supabase row ID.
///
/// SYNC GUARDRAIL NOTE: This relies on `persistentModelID.hashValue` being stable across app launches.
/// If SwiftData changes hash behavior (OS update, schema migration, store re-creation), the same entity
/// could produce a different UUID, creating remote duplicates. See SYNC-MODEL.md §8 R4.
private func stableSyncID(entity: String, hashValue: Int) -> UUID {
    // Create a deterministic UUID v5-style from entity name + hash
    var data = Data(entity.utf8)
    withUnsafeBytes(of: hashValue) { data.append(contentsOf: $0) }
    // SHA256 would be ideal but use simple byte mapping for zero dependencies
    var bytes = [UInt8](repeating: 0, count: 16)
    for (i, byte) in data.enumerated() {
        bytes[i % 16] ^= byte
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x50 // UUID version 5
    bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
}

// MARK: - Customer DTO

/// Sync identity rules:
/// - Push: upserts to remote on `id` (deterministic UUID from stableSyncID).
/// - Pull: matched by `email` (unique business key). If multiple local customers share an email,
///   only the first match is updated — duplicates are silently ignored.
/// - Conflict: last-write-wins. All local fields overwritten on pull; all remote fields overwritten on push.
/// - Relationships: none synced directly on this DTO.
struct CustomerDTO: Codable, Sendable {
    let id: UUID?
    let firstName: String
    let lastName: String
    let company: String
    let email: String
    let phone: String
    let address: String
    let city: String
    let country: String
    let zip: String
    let notes: String
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case company, email, phone, address, city, country, zip, notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: Customer) {
        self.id = stableSyncID(entity: "Customer", hashValue: model.persistentModelID.hashValue)
        self.firstName = model.firstName
        self.lastName = model.lastName
        self.company = model.company
        self.email = model.email
        self.phone = model.phone
        self.address = model.address
        self.city = model.city
        self.country = model.country
        self.zip = model.zip
        self.notes = model.notes
        self.createdAt = model.createdAt
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}

// MARK: - Gemstone DTO

/// Sync identity rules:
/// - Push: upserts to remote on `id` (deterministic UUID from stableSyncID). Batched in groups of 100.
/// - Pull: matched by `sku` (unique business key, format TYPE-SHAPE-GROUP-NNN). If multiple local
///   gemstones share a SKU, only the first match is updated — duplicates are silently ignored.
/// - Conflict: last-write-wins. All mutable fields overwritten on pull.
/// - Relationships: push populates gemstoneId on related DTOs via stableSyncID; pull does NOT re-link.
/// - Precision: Decimal→Double conversion on cost/price fields may introduce rounding.
struct GemstoneDTO: Codable, Sendable {
    let id: UUID?
    let sku: String
    let stoneType: String
    let caratWeight: Double
    let shape: String
    let grouping: String
    let origin: String
    let status: String
    let color: String
    let clarity: String
    let cut: String
    let treatment: String
    let polish: String
    let symmetry: String
    let fluorescence: String
    let size: String?
    let quality: String?
    let hasCert: Bool
    let certLab: String
    let certNo: String
    let length: Double?
    let width: Double?
    let height: Double?
    let length2: Double?
    let width2: Double?
    let height2: Double?
    let costPrice: Double
    let sellPrice: Double
    let currencyType: String
    let exchangeRate: Double
    let remainingCarats: Double?
    let averageCostPerCarat: Double?
    let rfidEpc: String?
    let rfidTid: String?
    let rfidAssignedAt: Date?
    let rfidLastSeenAt: Date?
    let rapnetSyncStatus: String
    let rapnetLastSynced: Date?
    let numberOfStones: Int?
    let gemVariety: String
    let notes: String
    let vendor: String
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, sku, shape, origin, color, clarity, cut, treatment, polish, symmetry, fluorescence
        case size, quality, length, width, height, length2, width2, height2, notes, vendor
        case stoneType = "stone_type"
        case caratWeight = "carat_weight"
        case grouping, status
        case hasCert = "has_cert"
        case certLab = "cert_lab"
        case certNo = "cert_no"
        case costPrice = "cost_price"
        case sellPrice = "sell_price"
        case currencyType = "currency_type"
        case exchangeRate = "exchange_rate"
        case remainingCarats = "remaining_carats"
        case averageCostPerCarat = "average_cost_per_carat"
        case rfidEpc = "rfid_epc"
        case rfidTid = "rfid_tid"
        case rfidAssignedAt = "rfid_assigned_at"
        case rfidLastSeenAt = "rfid_last_seen_at"
        case rapnetSyncStatus = "rapnet_sync_status"
        case rapnetLastSynced = "rapnet_last_synced"
        case numberOfStones = "number_of_stones"
        case gemVariety = "gem_variety"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: Gemstone) {
        self.id = stableSyncID(entity: "Gemstone", hashValue: model.persistentModelID.hashValue)
        self.sku = model.sku
        self.stoneType = model.stoneType.rawValue
        self.caratWeight = model.caratWeight
        self.shape = model.shape
        self.grouping = model.grouping.rawValue
        self.origin = model.origin
        self.status = model.status.rawValue
        self.color = model.color
        self.clarity = model.clarity
        self.cut = model.cut ?? ""
        self.treatment = model.treatment
        self.polish = model.polish
        self.symmetry = model.symmetry
        self.fluorescence = model.fluorescence
        self.size = model.size
        self.quality = model.quality
        self.hasCert = model.hasCert
        self.certLab = model.certLab
        self.certNo = model.certNo
        self.length = model.length
        self.width = model.width
        self.height = model.height
        self.length2 = model.length2
        self.width2 = model.width2
        self.height2 = model.height2
        self.costPrice = NSDecimalNumber(decimal: model.costPrice).doubleValue
        self.sellPrice = NSDecimalNumber(decimal: model.sellPrice).doubleValue
        self.currencyType = model.currencyType.rawValue
        self.exchangeRate = NSDecimalNumber(decimal: model.exchangeRate).doubleValue
        self.remainingCarats = model.remainingCarats
        self.averageCostPerCarat = model.averageCostPerCarat.map { NSDecimalNumber(decimal: $0).doubleValue }
        self.rfidEpc = model.rfidEpc
        self.rfidTid = model.rfidTid
        self.rfidAssignedAt = model.rfidAssignedAt
        self.rfidLastSeenAt = model.rfidLastSeenAt
        self.rapnetSyncStatus = model.rapNetSyncStatus.rawValue
        self.rapnetLastSynced = model.rapNetLastSynced
        self.numberOfStones = nil
        self.gemVariety = ""
        self.notes = ""
        self.vendor = ""
        self.createdAt = model.createdAt
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}

// MARK: - Memo DTO

/// Sync identity rules:
/// - Push: upserts to remote on `id` (deterministic UUID from stableSyncID).
/// - Pull: matched by `referenceNumber` (unique business key). If multiple local memos share a
///   referenceNumber, only the first match is updated.
/// - Conflict: last-write-wins. Status, notes, salesperson, dateAssigned overwritten on pull.
/// - Relationships: customerId set to nil on push (TODO: resolve via sync mapping). Pull does not re-link customer.
struct MemoDTO: Codable, Sendable {
    let id: UUID?
    let referenceNumber: String
    let customerId: UUID?
    let dateAssigned: Date?
    let salesperson: String?
    let status: String
    let notes: String
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, salesperson, status, notes
        case referenceNumber = "reference_number"
        case customerId = "customer_id"
        case dateAssigned = "date_assigned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: Memo) {
        self.id = stableSyncID(entity: "Memo", hashValue: model.persistentModelID.hashValue)
        self.referenceNumber = model.referenceNumber
        self.customerId = nil // resolved via sync mapping
        self.dateAssigned = model.dateAssigned
        self.salesperson = model.salesperson
        self.status = model.status.rawValue
        self.notes = model.notes
        self.createdAt = model.createdAt
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}

// MARK: - Invoice DTO

/// Sync identity rules:
/// - Push: upserts to remote on `id` (deterministic UUID from stableSyncID).
/// - Pull: matched by `referenceNumber` (unique business key). If multiple local invoices share a
///   referenceNumber, only the first match is updated.
/// - Conflict: last-write-wins. Status, notes, dueDate overwritten on pull.
/// - Relationships: customerId set to nil on push. Pull does not re-link customer.
struct InvoiceDTO: Codable, Sendable {
    let id: UUID?
    let referenceNumber: String
    let customerId: UUID?
    let dateIssued: Date?
    let dueDate: Date?
    let status: String
    let notes: String
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, status, notes
        case referenceNumber = "reference_number"
        case customerId = "customer_id"
        case dateIssued = "date_issued"
        case dueDate = "due_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: Invoice) {
        self.id = stableSyncID(entity: "Invoice", hashValue: model.persistentModelID.hashValue)
        self.referenceNumber = model.referenceNumber
        self.customerId = nil
        self.dateIssued = model.invoiceDate
        self.dueDate = model.dueDate
        self.status = model.status.rawValue
        self.notes = model.notes
        self.createdAt = model.createdAt
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}

// MARK: - LineItem DTO

/// Sync identity rules:
/// - Push-only: upserts to remote on `id`. No pull implementation exists.
/// - Relationships: memoId, invoiceId, gemstoneId set to nil on push (not resolved).
/// - Cannot be restored from remote if local store is lost.
struct LineItemDTO: Codable, Sendable {
    let id: UUID?
    let sku: String
    let itemDescription: String
    let carats: Double
    let rate: Double
    let amount: Double
    let kind: String
    let status: String
    let discount: Double
    let memoId: UUID?
    let invoiceId: UUID?
    let gemstoneId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, sku, carats, rate, amount, kind, status, discount
        case itemDescription = "item_description"
        case memoId = "memo_id"
        case invoiceId = "invoice_id"
        case gemstoneId = "gemstone_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: LineItem) {
        self.id = stableSyncID(entity: "LineItem", hashValue: model.persistentModelID.hashValue)
        self.sku = model.sku
        self.itemDescription = model.itemDescription
        self.carats = model.carats
        self.rate = NSDecimalNumber(decimal: model.rate).doubleValue
        self.amount = NSDecimalNumber(decimal: model.amount).doubleValue
        self.kind = model.kind.rawValue
        self.status = model.status.rawValue
        self.discount = NSDecimalNumber(decimal: model.discount).doubleValue
        self.memoId = nil
        self.invoiceId = nil
        self.gemstoneId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}

// MARK: - LotTransaction DTO

/// Sync identity rules:
/// - Push-only: upserts to remote on `id`. No pull implementation exists.
/// - Relationships: gemstoneId set to nil on push (not resolved).
/// - Cannot be restored from remote if local store is lost.
struct LotTransactionDTO: Codable, Sendable {
    let id: UUID?
    let type: String
    let carats: Double
    let date: Date
    let pricePerCarat: Double
    let totalPrice: Double
    let notes: String
    let gemstoneId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, type, carats, date, notes
        case pricePerCarat = "price_per_carat"
        case totalPrice = "total_price"
        case gemstoneId = "gemstone_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: LotTransaction) {
        self.id = stableSyncID(entity: "LotTransaction", hashValue: model.persistentModelID.hashValue)
        self.type = model.type.rawValue
        self.carats = model.carats
        self.date = model.date
        self.pricePerCarat = NSDecimalNumber(decimal: model.pricePerCarat).doubleValue
        self.totalPrice = NSDecimalNumber(decimal: model.totalPrice).doubleValue
        self.notes = model.notes
        self.gemstoneId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}

// MARK: - Payment DTO

/// Sync identity rules:
/// - Push-only: upserts to remote on `id`. No pull implementation exists.
/// - Business key: `referenceNumber` (not used for matching since no pull).
/// - Relationships: invoiceId set to nil on push (not resolved).
struct PaymentDTO: Codable, Sendable {
    let id: UUID?
    let date: Date
    let amount: Double
    let method: String
    let referenceNumber: String
    let invoiceId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, date, amount, method
        case referenceNumber = "reference_number"
        case invoiceId = "invoice_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: Payment) {
        self.id = stableSyncID(entity: "Payment", hashValue: model.persistentModelID.hashValue)
        self.date = model.date
        self.amount = NSDecimalNumber(decimal: model.amount).doubleValue
        self.method = model.method.rawValue
        self.referenceNumber = model.referenceNumber
        self.invoiceId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}

// MARK: - HistoryEvent DTO

/// Sync identity rules:
/// - Push-only: upserts to remote on `id`. No pull implementation exists.
/// - No natural business key — identity is solely from stableSyncID.
/// - Relationships: gemstoneId set to nil on push (not resolved).
struct HistoryEventDTO: Codable, Sendable {
    let id: UUID?
    let date: Date
    let eventDescription: String
    let eventType: String
    let gemstoneId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, date
        case eventDescription = "event_description"
        case eventType = "event_type"
        case gemstoneId = "gemstone_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: HistoryEvent) {
        self.id = stableSyncID(entity: "HistoryEvent", hashValue: model.persistentModelID.hashValue)
        self.date = model.date
        self.eventDescription = model.eventDescription
        self.eventType = model.eventType.rawValue
        self.gemstoneId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}

// MARK: - RFIDTag DTO

/// Sync identity rules:
/// - Push-only: upserts to remote on `id`. No pull implementation exists.
/// - Business key: `epcCurrent` / `tidLastVerified` (not used for matching since no pull).
/// - Relationships: gemstoneId set to nil on push (not resolved).
struct RFIDTagDTO: Codable, Sendable {
    let id: UUID?
    let tidLastVerified: String?
    let status: String
    let firstSeenAt: Date?
    let lastSeenAt: Date?
    let lastVerifiedAt: Date?
    let printerJobId: String?
    let notes: String?
    let gemstoneId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, status, notes
        case tidLastVerified = "tid_last_verified"
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
        case lastVerifiedAt = "last_verified_at"
        case printerJobId = "printer_job_id"
        case gemstoneId = "gemstone_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }

    init(from model: RFIDTag) {
        self.id = stableSyncID(entity: "RFIDTag", hashValue: model.persistentModelID.hashValue)
        self.tidLastVerified = model.tidLastVerified
        self.status = model.status.rawValue
        self.firstSeenAt = model.firstSeenAt
        self.lastSeenAt = model.lastSeenAt
        self.lastVerifiedAt = model.lastVerifiedAt
        self.printerJobId = model.printerJobID
        self.notes = model.notes
        self.gemstoneId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = currentUserId()
    }
}
