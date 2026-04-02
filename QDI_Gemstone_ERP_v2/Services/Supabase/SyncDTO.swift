import Foundation

// MARK: - Customer DTO

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
        self.id = model.persistentModelID.hashValue != 0 ? UUID() : UUID() // SwiftData doesn't expose UUID directly
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
        self.userId = nil
    }
}

// MARK: - Gemstone DTO

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
        self.id = UUID()
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
        self.userId = nil
    }
}

// MARK: - Memo DTO

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
        self.id = UUID()
        self.referenceNumber = model.referenceNumber
        self.customerId = nil // resolved via sync mapping
        self.dateAssigned = model.dateAssigned
        self.salesperson = model.salesperson
        self.status = model.status.rawValue
        self.notes = model.notes
        self.createdAt = model.createdAt
        self.updatedAt = Date()
        self.userId = nil
    }
}

// MARK: - Invoice DTO

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
        self.id = UUID()
        self.referenceNumber = model.referenceNumber
        self.customerId = nil
        self.dateIssued = model.invoiceDate
        self.dueDate = model.dueDate
        self.status = model.status.rawValue
        self.notes = model.notes
        self.createdAt = model.createdAt
        self.updatedAt = Date()
        self.userId = nil
    }
}

// MARK: - LineItem DTO

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
        self.id = UUID()
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
        self.userId = nil
    }
}

// MARK: - LotTransaction DTO

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
        self.id = UUID()
        self.type = model.type.rawValue
        self.carats = model.carats
        self.date = model.date
        self.pricePerCarat = NSDecimalNumber(decimal: model.pricePerCarat).doubleValue
        self.totalPrice = NSDecimalNumber(decimal: model.totalPrice).doubleValue
        self.notes = model.notes
        self.gemstoneId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = nil
    }
}

// MARK: - Payment DTO

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
        self.id = UUID()
        self.date = model.date
        self.amount = NSDecimalNumber(decimal: model.amount).doubleValue
        self.method = model.method.rawValue
        self.referenceNumber = model.referenceNumber
        self.invoiceId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = nil
    }
}

// MARK: - HistoryEvent DTO

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
        self.id = UUID()
        self.date = model.date
        self.eventDescription = model.eventDescription
        self.eventType = model.eventType.rawValue
        self.gemstoneId = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userId = nil
    }
}

// MARK: - RFIDTag DTO

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
        self.id = UUID()
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
        self.userId = nil
    }
}
