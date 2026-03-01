import Foundation
import SwiftData
import os

private let appTransactionLog = Logger(subsystem: "com.qdi.gemapp", category: "inventory.transaction")

// MARK: - Stone description builder

/// Builds line item descriptions from stone characteristics per spec.
/// Order: [Certified] [Treatment] [Stone Type] [Shape] [Single/Pair/Lot] [Color if lot] \n [Dimensions] [Cert Lab] [Cert No]
enum StoneDescriptionBuilder {
    static func buildDescription(for stone: Gemstone) -> String {
        var lines: [String] = []
        var topParts: [String] = []
        let isCertified = stone.hasCert == true
        if isCertified { topParts.append("Certified") }
        if let treatment = stone.treatment, !treatment.trimmingCharacters(in: .whitespaces).isEmpty {
            topParts.append(treatment.trimmingCharacters(in: .whitespaces))
        }
        topParts.append(stone.stoneType.rawValue)
        if stone.stoneType == .diamond {
            if !stone.color.isEmpty && stone.color != "-" { topParts.append(stone.color) }
            if !stone.clarity.isEmpty && stone.clarity != "-" { topParts.append(stone.clarity) }
            if !stone.cut.isEmpty && stone.cut != "-" { topParts.append(stone.cut) }
        }
        let shape = (stone.shape ?? stone.cut).trimmingCharacters(in: .whitespaces)
        if !shape.isEmpty { topParts.append(shape) }
        let grouping = (stone.grouping ?? "S").uppercased()
        switch grouping {
        case "P": topParts.append("Pair")
        case "L":
            topParts.append("Lot")
            if stone.stoneType != .diamond && !stone.color.isEmpty && stone.color != "-" { topParts.append(stone.color) }
        default: topParts.append("Single")
        }
        if !topParts.isEmpty { lines.append(topParts.joined(separator: " ")) }
        var bottomParts: [String] = []
        if let l = stone.length, let w = stone.width, let h = stone.height {
            bottomParts.append(String(format: "%.2f × %.2f × %.2f", l, w, h))
        }
        if let lab = stone.certLab, !lab.trimmingCharacters(in: .whitespaces).isEmpty {
            bottomParts.append(lab.trimmingCharacters(in: .whitespaces))
        }
        if let no = stone.certNo, !no.trimmingCharacters(in: .whitespaces).isEmpty {
            bottomParts.append(no.trimmingCharacters(in: .whitespaces))
        }
        if !bottomParts.isEmpty { lines.append(bottomParts.joined(separator: " ")) }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Draft line (form state; not persisted until save)

/// Draft line item for the transaction form. Same 3 types as LineItem.
struct DraftLineItem: Identifiable {
    let id = UUID()
    var sku: String
    var description: String
    var carats: Double
    var rate: Decimal
    var gemstone: Gemstone?
    var isService: Bool
    
    var isInventory: Bool { gemstone != nil }
    var isBrokered: Bool { gemstone == nil && !isService }
    var isCustomLine: Bool { gemstone == nil }
    
    /// For inventory/brokered: rate * carats. For service: rate is the total amount.
    var amount: Decimal {
        if isService { return rate }
        return rate * Decimal(carats)
    }
    
    // Display (UI uses these; no if-else in view)
    var displaySku: String { isCustomLine ? "—" : sku }
    var displayName: String {
        gemstone.map { "\($0.stoneType.rawValue) \($0.color) \($0.clarity) \($0.cut)" } ?? description
    }
    var displayCarats: String {
        isService ? "—" : String(format: "%.2f", carats)
    }
    var displayPrice: String {
        DraftLineItem.currencyFormatter.string(from: rate as NSDecimalNumber) ?? "$0"
    }
    var displayAmount: String {
        DraftLineItem.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
    
    fileprivate static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()
}

// MARK: - Transaction ViewModel (all logic here; view only binds)

@MainActor
@Observable
final class TransactionViewModel {
    var customer: Customer?
    var date: Date = Date()
    var dueDate: Date?
    var terms: String = "Net 30"
    var referenceNumber: String = ""
    var notes: String = ""
    var taxRatePercent: Decimal = 0
    
    private(set) var lineItems: [DraftLineItem] = []
    
    // MARK: - Public API for View (bind to these only)
    
    var items: [DraftLineItem] { lineItems }
    
    var subtotal: Decimal {
        lineItems.reduce(0) { $0 + $1.amount }
    }
    
    var tax: Decimal {
        subtotal * taxRatePercent / 100
    }
    
    var total: Decimal {
        subtotal + tax
    }
    
    var canSave: Bool {
        customer != nil && !lineItems.isEmpty
    }
    
    /// Last message from RFID handling (e.g. "Added: SKU123", "Returned: SKU456", "Tag not in database"). View can show briefly.
    private(set) var lastRFIDMessage: String?
    
    // MARK: - RFID tag handling (add to Memo or process Return per PRD)
    
    /// Handle a scanned RFID tag (EPC): if stone is available, add to current transaction (Memo/Invoice); if on memo, process return to stock.
    /// Call from the view when the serial RFID service fires onTagDiscovered (e.g. in TransactionEditorView).
    func handleScannedTag(_ tagID: String, modelContext: ModelContext) {
        guard let canonicalEpc = EPCanonical.normalize(tagID) ?? EPCanonical.canonicalHex(fromRawHex: tagID) else {
            lastRFIDMessage = "Tag format invalid"
            return
        }

        let tagDescriptor = FetchDescriptor<RFIDTag>(predicate: #Predicate<RFIDTag> { $0.epcCurrent == canonicalEpc })
        if let tag = try? modelContext.fetch(tagDescriptor).first,
           let assignedStone = tag.assignedStone {
            handleScannedStone(assignedStone, modelContext: modelContext)
            return
        }

        let descriptor = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { stone in stone.rfidEpc == canonicalEpc || stone.rfidTag == canonicalEpc }
        )
        guard let results = try? modelContext.fetch(descriptor),
              let stone = results.first else {
            lastRFIDMessage = "Tag not in database"
            return
        }

        handleScannedStone(stone, modelContext: modelContext)
    }

    private func handleScannedStone(_ stone: Gemstone, modelContext: ModelContext) {
        switch stone.effectiveStatus {
        case .available:
            if !lineItems.contains(where: { $0.gemstone?.sku == stone.sku }) {
                addStoneFromInventory(stone)
                lastRFIDMessage = "Added: \(stone.sku)"
            } else {
                lastRFIDMessage = "Already in list: \(stone.sku)"
            }
        case .onMemo:
            guard let memo = stone.memo,
                  let lineItem = memo.openLineItems.first(where: { $0.gemstone?.sku == stone.sku }) else {
                lastRFIDMessage = "Stone on memo but line not found"
                return
            }
            Self.returnItemsFromMemo(items: [lineItem], modelContext: modelContext)
            lastRFIDMessage = "Returned to stock: \(stone.sku)"
        case .sold:
            lastRFIDMessage = "Stone already sold: \(stone.sku)"
        }
    }
    
    /// Clear the last RFID message (e.g. so the view can hide the banner).
    func clearLastRFIDMessage() {
        lastRFIDMessage = nil
    }
    
    // MARK: - Add / Remove Line (all logic here)
    
    func addStoneFromInventory(_ stone: Gemstone) {
        let desc = StoneDescriptionBuilder.buildDescription(for: stone)
        lineItems.append(DraftLineItem(
            sku: stone.sku,
            description: desc.isEmpty ? "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)" : desc,
            carats: stone.caratWeight,
            rate: stone.sellPrice,
            gemstone: stone,
            isService: false
        ))
    }
    
    func addBrokeredLine() {
        lineItems.append(DraftLineItem(
            sku: "",
            description: "",
            carats: 0,
            rate: 0,
            gemstone: nil,
            isService: false
        ))
    }
    
    func addServiceLine() {
        lineItems.append(DraftLineItem(
            sku: "",
            description: "Shipping / Service",
            carats: 0,
            rate: 0,
            gemstone: nil,
            isService: true
        ))
    }
    
    func removeLine(at indexSet: IndexSet) {
        lineItems.remove(atOffsets: indexSet)
    }
    
    // MARK: - Updates (view calls these for edits)
    
    func updateDescription(at index: Int, _ value: String) {
        guard lineItems.indices.contains(index) else { return }
        lineItems[index].description = value
    }
    
    func updateCarats(at index: Int, _ value: Double) {
        guard lineItems.indices.contains(index) else { return }
        lineItems[index].carats = max(0, value)
    }
    
    func updateRate(at index: Int, _ value: Decimal) {
        guard lineItems.indices.contains(index) else { return }
        lineItems[index].rate = value
    }
    
    /// For service lines, rate holds the total amount.
    func updateAmount(at index: Int, _ value: Decimal) {
        guard lineItems.indices.contains(index) else { return }
        lineItems[index].rate = value
    }
    
    // MARK: - Reset / Load
    
    func reset() {
        customer = nil
        date = Date()
        dueDate = nil
        terms = "Net 30"
        referenceNumber = ""
        notes = ""
        taxRatePercent = 0
        lineItems = []
    }
    
    func load(memo: Memo) {
        customer = memo.customer
        date = memo.dateAssigned ?? Date()
        referenceNumber = memo.referenceNumber ?? ""
        notes = memo.notes ?? ""
        lineItems = memo.lineItems.map { item in
            DraftLineItem(
                sku: item.sku,
                description: item.itemDescription,
                carats: item.carats,
                rate: item.rate,
                gemstone: item.gemstone,
                isService: item.isService
            )
        }
    }
    
    /// Creates a new blank memo, inserts it, and saves. Use for "New Memo" document flow.
    static func createNewMemo(modelContext: ModelContext) -> Memo {
        let ref = generateNextMemoNumber(modelContext: modelContext)
        let memo = Memo(status: .onMemo, dateAssigned: Date(), referenceNumber: ref, customer: nil)
        modelContext.insert(memo)
        do {
            try modelContext.save()
        } catch {
            appTransactionLog.error("Failed to create memo: \(error.localizedDescription, privacy: .public)")
        }
        return memo
    }

    /// Creates a new blank invoice (standalone, no origin memo), inserts it, and saves. Use for "New Invoice" document flow.
    static func createNewInvoice(modelContext: ModelContext) -> Invoice {
        let invoice = Invoice(invoiceDate: Date(), terms: "Net 30", status: .draft, customer: nil)
        modelContext.insert(invoice)
        do {
            try modelContext.save()
        } catch {
            appTransactionLog.error("Failed to create invoice: \(error.localizedDescription, privacy: .public)")
        }
        return invoice
    }

    /// Next memo number for new memos: max(existing) + 1, or 1001 if none. Call from view with modelContext.
    static func generateNextMemoNumber(modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<Memo>()
        guard let memos = try? modelContext.fetch(descriptor) else { return "1001" }
        let maxNum = memos.compactMap { memo -> Int? in
            guard let ref = memo.referenceNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty else { return nil }
            return Int(ref)
        }.max()
        let next = (maxNum ?? 1000) + 1
        return "\(max(next, 1001))"
    }
    // Add this inside the TransactionViewModel class

    /// Converts selected memo line items to an invoice. Keeps permanent history on the memo:
    /// creates a *copy* of each line item for the invoice; marks the original memo line item as .sold.
    static func convertMemoToInvoice(memo: Memo, selectedLineItems: [LineItem], modelContext: ModelContext) -> Invoice? {
        guard let customer = memo.customer, !selectedLineItems.isEmpty else { return nil }
        
        let newInvoice = Invoice(
            invoiceDate: Date(),
            terms: "Net 30",
            customer: customer,
            originMemo: memo
        )
        modelContext.insert(newInvoice)
        
        let memoRef = memo.referenceNumber ?? "?"
        
        for original in selectedLineItems {
            // Create a copy for the invoice (same data, new LineItem instance)
            let copy = LineItem(
                sku: original.sku,
                itemDescription: original.itemDescription,
                carats: original.carats,
                rate: original.rate,
                amount: original.amount,
                gemstone: original.gemstone,
                isService: original.isService,
                status: .open,
                returnedDate: nil,
                soldDate: nil
            )
            copy.invoice = newInvoice
            copy.memo = nil
            modelContext.insert(copy)
            
            // Mark the original memo line item as sold (keep it on the memo for history)
            original.status = .sold
            original.soldDate = Date()
            original.invoice = nil
            // original.memo stays as memo
            
            // Update linked gemstone (NEVER delete; only update status to .sold)
            if let stone = original.gemstone {
                stone.status = .sold
                stone.memo = nil
                logEvent(
                    stone: stone,
                    type: .sold,
                    message: "Converted from Memo #\(memoRef) to Invoice",
                    modelContext: modelContext
                )
            }
        }
        do {
            try modelContext.save()
        } catch {
            appTransactionLog.error("Failed to convert memo to invoice: \(error.localizedDescription, privacy: .public)")
        }
        return newInvoice
    }
    
    /// Add a gemstone from inventory to an existing memo.
    /// - Parameter persistImmediately: If false, caller is responsible for saving (draft mode).
    static func addStoneToMemo(_ stone: Gemstone, memo: Memo, modelContext: ModelContext, persistImmediately: Bool = true) {
        let amount = stone.sellPrice * Decimal(stone.caratWeight)
        let desc = StoneDescriptionBuilder.buildDescription(for: stone)
        let item = LineItem(
            sku: stone.sku,
            itemDescription: desc.isEmpty ? "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)" : desc,
            carats: stone.caratWeight,
            rate: stone.sellPrice,
            amount: amount,
            gemstone: stone,
            isService: false
        )
        modelContext.insert(item)
        item.memo = memo
        stone.memo = memo
        stone.status = .onMemo
        logEvent(stone: stone, type: .sentToCustomer, message: "Added to Memo", modelContext: modelContext)
        if persistImmediately {
            do {
                try modelContext.save()
            } catch {
                appTransactionLog.error("Failed to persist transaction mutation: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Add a brokered (manual) stone line to an existing memo.
    static func addBrokeredLineToMemo(_ memo: Memo, modelContext: ModelContext, persistImmediately: Bool = true) {
        let item = LineItem(
            sku: "",
            itemDescription: "",
            carats: 0,
            rate: 0,
            amount: 0,
            gemstone: nil,
            isService: false
        )
        modelContext.insert(item)
        item.memo = memo
        if persistImmediately {
            do {
                try modelContext.save()
            } catch {
                appTransactionLog.error("Failed to persist transaction mutation: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Add a custom/service line to an existing memo.
    static func addServiceLineToMemo(_ memo: Memo, modelContext: ModelContext, persistImmediately: Bool = true) {
        let item = LineItem(
            sku: "",
            itemDescription: "Shipping / Service",
            carats: 0,
            rate: 0,
            amount: 0,
            gemstone: nil,
            isService: true
        )
        modelContext.insert(item)
        item.memo = memo
        if persistImmediately {
            do {
                try modelContext.save()
            } catch {
                appTransactionLog.error("Failed to persist transaction mutation: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Add a gemstone from inventory to an existing invoice.
    static func addStoneToInvoice(_ stone: Gemstone, invoice: Invoice, modelContext: ModelContext, persistImmediately: Bool = true) {
        let amount = stone.sellPrice * Decimal(stone.caratWeight)
        let desc = StoneDescriptionBuilder.buildDescription(for: stone)
        let item = LineItem(
            sku: stone.sku,
            itemDescription: desc.isEmpty ? "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)" : desc,
            carats: stone.caratWeight,
            rate: stone.sellPrice,
            amount: amount,
            gemstone: stone,
            isService: false
        )
        modelContext.insert(item)
        item.invoice = invoice
        stone.memo = nil
        stone.status = .sold
        logEvent(stone: stone, type: .sold, message: "Added to Invoice", modelContext: modelContext)
        if persistImmediately {
            do {
                try modelContext.save()
            } catch {
                appTransactionLog.error("Failed to persist transaction mutation: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Add a brokered (manual) stone line to an existing invoice.
    static func addBrokeredLineToInvoice(_ invoice: Invoice, modelContext: ModelContext, persistImmediately: Bool = true) {
        let item = LineItem(
            sku: "",
            itemDescription: "",
            carats: 0,
            rate: 0,
            amount: 0,
            gemstone: nil,
            isService: false
        )
        modelContext.insert(item)
        item.invoice = invoice
        if persistImmediately {
            do {
                try modelContext.save()
            } catch {
                appTransactionLog.error("Failed to persist transaction mutation: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Add a custom/service line to an existing invoice.
    static func addServiceLineToInvoice(_ invoice: Invoice, modelContext: ModelContext, persistImmediately: Bool = true) {
        let item = LineItem(
            sku: "",
            itemDescription: "Shipping / Service",
            carats: 0,
            rate: 0,
            amount: 0,
            gemstone: nil,
            isService: true
        )
        modelContext.insert(item)
        item.invoice = invoice
        if persistImmediately {
            do {
                try modelContext.save()
            } catch {
                appTransactionLog.error("Failed to persist transaction mutation: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Returns selected items from a memo to stock: marks line items as .returned, sets gemstones to .available.
    static func returnItemsFromMemo(items: [LineItem], modelContext: ModelContext) {
        for item in items {
            item.status = .returned
            item.returnedDate = Date()
            
            if let stone = item.gemstone {
                stone.status = .available
                stone.memo = nil
                let memoRef = item.memo?.referenceNumber ?? "?"
                logEvent(
                    stone: stone,
                    type: .returnedFromCustomer,
                    message: "Returned from Memo #\(memoRef)",
                    modelContext: modelContext
                )
            }
        }
        do {
            try modelContext.save()
        } catch {
            appTransactionLog.error("Failed to persist transaction mutation: \(error.localizedDescription, privacy: .public)")
        }
    }
}