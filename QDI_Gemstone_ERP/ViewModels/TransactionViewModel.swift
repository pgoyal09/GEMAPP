import Foundation
import SwiftData
import os

private let appTransactionLog = Logger(subsystem: "com.qdi.gemapp", category: "inventory.transaction")

// MARK: - Stone description builder

/// Builds line item descriptions from stone characteristics per spec.
/// Diamond: lot = [type][color][carat value][clarity]; single/pair = [type][Carat][Color][clarity]([cut][polish][symmetry])-[Fluorescence] newline [Cert Lab] [Cert No] when certified.
/// Non-diamond: [Certified] [Treatment] [Stone Type] [Shape] [single/pair/lot] [if lot: color] \n [Dimensions] [Lab] [Cert No]
enum StoneDescriptionBuilder {
    static func buildDescription(for stone: Gemstone) -> String {
        if stone.stoneType == .diamond {
            return buildDiamondDescription(for: stone)
        }
        return buildNonDiamondDescription(for: stone)
    }

    /// Diamond lot: [color] [size] [clarity]
    /// Diamond single/pair: [stone type] [Carat] [Color] [clarity] ([cut][polish][symmetry])-[Fluorescence] newline [Cert Lab] [Cert No] when certified.
    private static func buildDiamondDescription(for stone: Gemstone) -> String {
        let grouping = (stone.grouping ?? "S").uppercased()
        let typeStr = stone.stoneType.rawValue
        let colorStr = stone.color.trimmingCharacters(in: .whitespaces)
        let colorVal = (colorStr.isEmpty || colorStr == "-") ? "" : colorStr
        let caratVal = stone.caratWeight
        let caratStr = caratVal.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(caratVal))" : "\(caratVal)"
        let clarityStr = stone.clarity.trimmingCharacters(in: .whitespaces)
        let clarityVal = (clarityStr.isEmpty || clarityStr == "-") ? "" : clarityStr

        if grouping == "L" {
            let sizeVal = (stone.size ?? "").trimmingCharacters(in: .whitespaces)
            let parts = [colorVal, sizeVal, clarityVal].filter { !$0.isEmpty }
            return parts.joined(separator: " ")
        }

        // Single or Pair: [Carat] [Color] [clarity] [cut] [polish] [symmetry] [Fluorescence]
        // newline [Cert Lab] [Cert No] when certified
        let cut = (stone.cut ?? "").trimmingCharacters(in: .whitespaces)
        let polish = (stone.polish ?? "").trimmingCharacters(in: .whitespaces)
        let symmetry = (stone.symmetry ?? "").trimmingCharacters(in: .whitespaces)
        let fluo = (stone.fluorescence ?? "").trimmingCharacters(in: .whitespaces)
        let fluoVal = (fluo.isEmpty || fluo == "-") ? "" : fluo
        let cutVal = (cut.isEmpty || cut == "-") ? "" : cut
        let polishVal = (polish.isEmpty || polish == "-") ? "" : polish
        let symmetryVal = (symmetry.isEmpty || symmetry == "-") ? "" : symmetry
        let line1Parts = [caratStr, colorVal, clarityVal, cutVal, polishVal, symmetryVal, fluoVal].filter { !$0.isEmpty }
        var result = line1Parts.joined(separator: " ")
        if stone.hasCert == true {
            var certLine: [String] = []
            if let lab = stone.certLab?.trimmingCharacters(in: .whitespaces), !lab.isEmpty {
                certLine.append(lab)
            }
            if let no = stone.certNo?.trimmingCharacters(in: .whitespaces), !no.isEmpty {
                certLine.append(no)
            }
            if !certLine.isEmpty {
                result += "\n" + certLine.joined(separator: " ")
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func buildNonDiamondDescription(for stone: Gemstone) -> String {
        let grouping = (stone.grouping ?? "S").uppercased()
        let typeStr = stone.stoneType.rawValue
        let shape = (stone.shape ?? stone.cut).trimmingCharacters(in: .whitespaces)

        if grouping == "L" {
            // Lot format: [Shape] ([L]x[W]mm) [Quality]
            // Partial dimensions: if only one measurement exists, show just that value + mm
            let fmt = { (v: Double) -> String in
                let s = "\(v)"
                return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
            }
            var parts: [String] = []
            if !shape.isEmpty { parts.append(shape) }
            let l = stone.length
            let w = stone.width
            if let l, let w {
                parts.append("(\(fmt(l))x\(fmt(w))mm)")
            } else if let l {
                parts.append("(\(fmt(l))mm)")
            } else if let w {
                parts.append("(\(fmt(w))mm)")
            }
            if let q = stone.quality?.trimmingCharacters(in: .whitespaces), !q.isEmpty {
                parts.append(q)
            }
            return parts.joined(separator: " ")
        }

        // Single / Pair: original descriptive format
        var lines: [String] = []
        var topParts: [String] = []
        if stone.hasCert == true { topParts.append("Certified") }
        if let t = stone.treatment, !t.trimmingCharacters(in: .whitespaces).isEmpty {
            topParts.append(t.trimmingCharacters(in: .whitespaces))
        }
        topParts.append(typeStr)
        if !shape.isEmpty { topParts.append(shape) }
        topParts.append(grouping == "P" ? "Pair" : "Single")
        if !topParts.isEmpty { lines.append(topParts.joined(separator: " ")) }
        var bottomParts: [String] = []
        if let l = stone.length, let w = stone.width, let h = stone.height {
            bottomParts.append(formatDimensions(l: l, w: w, h: h))
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

    /// Formats dimensions using exact decimals (no forced rounding); ends with mm.
    private static func formatDimensions(l: Double, w: Double, h: Double) -> String {
        let fmt = { (v: Double) -> String in
            let s = "\(v)"
            return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
        }
        return "\(fmt(l)) × \(fmt(w)) × \(fmt(h)) mm"
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
    /// Stone type label for manually-entered (brokered) lines (not linked to a Gemstone)
    var brokeredStoneType: String = ""
    
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
        rate.asCurrency
    }
    var displayAmount: String {
        amount.asCurrency
    }
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

    func updateBrokeredStoneType(at index: Int, _ value: String) {
        guard lineItems.indices.contains(index) else { return }
        lineItems[index].brokeredStoneType = value
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
        let ref = generateNextInvoiceNumber(modelContext: modelContext)
        let invoice = Invoice(invoiceDate: Date(), terms: "Net 30", referenceNumber: ref, status: .draft, customer: nil)
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

    /// Next invoice number: max(existing numeric ref) + 1, or 2001 if none. Handles "INV-2001" or "2001" style refs.
    static func generateNextInvoiceNumber(modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<Invoice>()
        guard let invoices = try? modelContext.fetch(descriptor) else { return "2001" }
        let maxNum = invoices.compactMap { inv -> Int? in
            guard let ref = inv.referenceNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty else { return nil }
            let s = ref.hasPrefix("INV-") ? String(ref.dropFirst(4)) : ref
            return Int(s)
        }.max()
        let next = (maxNum ?? 2000) + 1
        return "\(max(next, 2001))"
    }

    /// Converts selected memo line items to an invoice. Creates invoice and line item copies but does NOT save and does NOT mark stones/memo items as sold. Caller opens the invoice window; when user saves the invoice, markConvertedLineItemsAsSold is used to mark originals and stones sold.
    static func convertMemoToInvoice(memo: Memo, selectedLineItems: [LineItem], modelContext: ModelContext) -> Invoice? {
        guard let customer = memo.customer, !selectedLineItems.isEmpty else { return nil }
        
        let ref = generateNextInvoiceNumber(modelContext: modelContext)
        let newInvoice = Invoice(
            invoiceDate: Date(),
            terms: "Net 30",
            referenceNumber: ref,
            customer: customer,
            originMemo: memo
        )
        modelContext.insert(newInvoice)
        
        for original in selectedLineItems {
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
            copy.originLineItem = original
            modelContext.insert(copy)
            // Do NOT mark original as sold or update stone; that happens when the invoice is saved.
        }
        // Do not save here; invoice is a draft until user saves.
        return newInvoice
    }
    
    /// Call when saving an invoice that may contain line items converted from a memo. Marks each origin line item and linked gemstone as sold and logs the event.
    static func markConvertedLineItemsAsSold(invoice: Invoice, modelContext: ModelContext) {
        let custName = invoice.customer?.displayName ?? "Unknown"
        for item in invoice.lineItems {
            guard let original = item.originLineItem else { continue }
            original.status = .sold
            original.soldDate = Date()
            original.invoice = nil
            if let stone = item.gemstone {
                if item.isLotLineItem || original.isLotLineItem {
                    // Lot: lock cost and record sale; don't change stone status
                    let lockedCost = original.lockedCostPerCarat ?? stone.effectiveAverageCost
                    item.lockedCostPerCarat = lockedCost
                    original.lockedCostPerCarat = lockedCost
                    let txn = LotTransaction(
                        type: .sold,
                        carats: item.carats,
                        date: Date(),
                        pricePerCarat: item.rate,
                        totalPrice: item.amount,
                        lockedCostPerCarat: lockedCost,
                        notes: "Converted from Memo — Sold to \(custName)",
                        gemstone: stone
                    )
                    modelContext.insert(txn)
                    logEvent(stone: stone, type: .sold, message: "Lot sold to \(custName)", modelContext: modelContext)
                } else {
                    stone.status = .sold
                    stone.memo = nil
                    logEvent(stone: stone, type: .sold, message: "Sold to \(custName)", modelContext: modelContext)
                }
            }
        }
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
        let custName = memo.customer?.displayName ?? "Unknown"
        logEvent(stone: stone, type: .sentToCustomer, message: "On memo to \(custName)", modelContext: modelContext)
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
        let custName = invoice.customer?.displayName ?? "Unknown"
        logEvent(stone: stone, type: .sold, message: "Sold to \(custName)", modelContext: modelContext)
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

    /// Voids an invoice: sets status to .void and restores linked gemstones to .available.
    /// For lot line items, restores carats instead of changing stone status.
    static func voidInvoice(_ invoice: Invoice, modelContext: ModelContext) {
        invoice.status = .void
        for item in invoice.lineItems {
            if let stone = item.gemstone {
                if item.isLotLineItem {
                    stone.effectiveRemainingCarats += item.carats
                } else {
                    stone.status = .available
                    stone.memo = nil
                }
            }
        }
        do {
            try modelContext.save()
        } catch {
            appTransactionLog.error("Failed to void invoice: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes an invoice: restores stones to available, deletes line items and invoice. Use for draft/unpaid invoices.
    /// For lot line items, restores carats instead of changing stone status.
    static func deleteInvoice(_ invoice: Invoice, modelContext: ModelContext) {
        for item in invoice.lineItems {
            if let stone = item.gemstone {
                if item.isLotLineItem {
                    stone.effectiveRemainingCarats += item.carats
                } else {
                    stone.status = .available
                    stone.memo = nil
                }
            }
            modelContext.delete(item)
        }
        modelContext.delete(invoice)
        do {
            try modelContext.save()
        } catch {
            appTransactionLog.error("Failed to delete invoice: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns selected items from a memo to stock: marks line items as .returned, sets gemstones to .available.
    /// For lot line items, restores the carats to remainingCarats instead of changing stone status.
    static func returnItemsFromMemo(items: [LineItem], modelContext: ModelContext) {
        for item in items {
            item.status = .returned
            item.returnedDate = Date()

            if let stone = item.gemstone {
                let memoRef = item.memo?.referenceNumber ?? "?"
                if item.isLotLineItem {
                    // Restore carats for lot line items; status stays .available
                    stone.effectiveRemainingCarats += item.carats
                    let txn = LotTransaction(
                        type: .returned,
                        carats: item.carats,
                        date: Date(),
                        pricePerCarat: item.rate,
                        totalPrice: item.amount,
                        notes: "Returned from Memo #\(memoRef)",
                        gemstone: stone
                    )
                    modelContext.insert(txn)
                    logEvent(stone: stone, type: .returnedFromCustomer,
                             message: "Lot returned from Memo #\(memoRef)", modelContext: modelContext)
                } else {
                    stone.status = .available
                    stone.memo = nil
                    logEvent(stone: stone, type: .returnedFromCustomer,
                             message: "Returned from Memo #\(memoRef)", modelContext: modelContext)
                }
            }
        }
        do {
            try modelContext.save()
        } catch {
            appTransactionLog.error("Failed to persist transaction mutation: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Lot-Specific Methods

    /// Add a partial lot allocation to an existing memo (carats deducted from lot's remainingCarats).
    static func addLotToMemo(_ lot: Gemstone, carats: Double, memo: Memo, modelContext: ModelContext, persistImmediately: Bool = true) {
        guard carats > 0, lot.isLot else { return }
        let rate = lot.sellPrice
        let amount = rate * Decimal(carats)
        let desc = StoneDescriptionBuilder.buildDescription(for: lot)
        let item = LineItem(
            sku: lot.sku,
            itemDescription: desc.isEmpty ? "\(lot.stoneType.rawValue) \(lot.color) \(lot.clarity)" : desc,
            carats: carats,
            rate: rate,
            amount: amount,
            gemstone: lot,
            isService: false,
            isLotLineItem: true,
            lockedCostPerCarat: lot.effectiveAverageCost
        )
        modelContext.insert(item)
        item.memo = memo
        lot.effectiveRemainingCarats -= carats
        let custName = memo.customer?.displayName ?? "Unknown"
        let txn = LotTransaction(
            type: .onMemo,
            carats: carats,
            date: Date(),
            pricePerCarat: rate,
            totalPrice: amount,
            notes: "On memo to \(custName)",
            gemstone: lot
        )
        modelContext.insert(txn)
        logEvent(stone: lot, type: .sentToCustomer, message: "Lot on memo to \(custName)", modelContext: modelContext)
        if persistImmediately {
            do { try modelContext.save() } catch {
                appTransactionLog.error("Failed to persist lot memo line: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Add a partial lot allocation directly to an existing invoice (carats deducted from lot's remainingCarats).
    static func addLotToInvoice(_ lot: Gemstone, carats: Double, invoice: Invoice, modelContext: ModelContext, persistImmediately: Bool = true) {
        guard carats > 0, lot.isLot else { return }
        let rate = lot.sellPrice
        let amount = rate * Decimal(carats)
        let desc = StoneDescriptionBuilder.buildDescription(for: lot)
        let lockedCost = lot.effectiveAverageCost
        let item = LineItem(
            sku: lot.sku,
            itemDescription: desc.isEmpty ? "\(lot.stoneType.rawValue) \(lot.color) \(lot.clarity)" : desc,
            carats: carats,
            rate: rate,
            amount: amount,
            gemstone: lot,
            isService: false,
            isLotLineItem: true,
            lockedCostPerCarat: lockedCost,
            status: .sold
        )
        modelContext.insert(item)
        item.invoice = invoice
        lot.effectiveRemainingCarats -= carats
        let custName = invoice.customer?.displayName ?? "Unknown"
        let txn = LotTransaction(
            type: .sold,
            carats: carats,
            date: Date(),
            pricePerCarat: rate,
            totalPrice: amount,
            lockedCostPerCarat: lockedCost,
            notes: "Sold to \(custName)",
            gemstone: lot
        )
        modelContext.insert(txn)
        logEvent(stone: lot, type: .sold, message: "Lot sold to \(custName)", modelContext: modelContext)
        if persistImmediately {
            do { try modelContext.save() } catch {
                appTransactionLog.error("Failed to persist lot invoice line: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Called when invoice is saved/paid: marks lot line items as sold and records LotTransaction(.sold).
    static func markLotLineItemsAsSold(invoice: Invoice, modelContext: ModelContext) {
        let custName = invoice.customer?.displayName ?? "Unknown"
        for item in invoice.lineItems where item.isLotLineItem {
            guard let lot = item.gemstone else { continue }
            item.status = .sold
            item.soldDate = Date()
            let lockedCost = item.lockedCostPerCarat ?? lot.effectiveAverageCost
            item.lockedCostPerCarat = lockedCost
            // Record the sale in lot history
            let txn = LotTransaction(
                type: .sold,
                carats: item.carats,
                date: Date(),
                pricePerCarat: item.rate,
                totalPrice: item.amount,
                lockedCostPerCarat: lockedCost,
                notes: "Sold to \(custName) via Invoice \(invoice.referenceNumber ?? "")",
                gemstone: lot
            )
            modelContext.insert(txn)
            logEvent(stone: lot, type: .sold, message: "Lot sold to \(custName)", modelContext: modelContext)
        }
    }
}