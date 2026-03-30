import Foundation
import SwiftData

// MARK: - Draft Line Item (form state, not persisted until save)

struct DraftLineItem: Identifiable {
    let id = UUID()
    var sku: String
    var description: String
    var carats: Double
    var rate: Decimal
    var gemstone: Gemstone?
    var kind: LineItemKind
    var brokeredStoneType: String = ""
    var isLotLineItem: Bool = false
    var lockedCostPerCarat: Decimal?

    var amount: Decimal {
        kind == .service ? rate : rate * Decimal(carats)
    }

    var displaySku: String {
        gemstone?.sku ?? (kind == .service ? "" : (sku.isEmpty ? "—" : sku))
    }

    var displayCarats: String {
        kind == .service ? "—" : String(format: "%.2f", carats)
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class TransactionEditorViewModel {

    // MARK: - Form State

    var customer: Customer?
    var date: Date = Date()
    var dueDate: Date?
    var terms: String = "Net 30"
    var referenceNumber: String = ""
    var notes: String = ""
    var taxRatePercent: Decimal = 0

    private(set) var lineItems: [DraftLineItem] = []

    // MARK: - RFID

    private(set) var lastRFIDMessage: String?

    // MARK: - Computed

    var subtotal: Decimal { lineItems.reduce(0) { $0 + $1.amount } }
    var tax: Decimal { subtotal * taxRatePercent / 100 }
    var total: Decimal { subtotal + tax }
    var canSave: Bool { customer != nil && !lineItems.isEmpty }

    // MARK: - Add Lines

    func addStoneFromInventory(_ stone: Gemstone) {
        let desc = StoneDescriptionBuilder.buildDescription(for: stone)
        lineItems.append(DraftLineItem(
            sku: stone.sku,
            description: desc,
            carats: stone.caratWeight,
            rate: stone.sellPrice,
            gemstone: stone,
            kind: .inventory
        ))
    }

    func addLotFromInventory(_ lot: Gemstone, carats: Double) {
        let desc = StoneDescriptionBuilder.buildDescription(for: lot)
        lineItems.append(DraftLineItem(
            sku: lot.sku,
            description: desc,
            carats: carats,
            rate: lot.sellPrice,
            gemstone: lot,
            kind: .inventory,
            isLotLineItem: true,
            lockedCostPerCarat: lot.effectiveAverageCost
        ))
    }

    func addBrokeredLine() {
        lineItems.append(DraftLineItem(
            sku: "", description: "", carats: 0, rate: 0, gemstone: nil, kind: .brokered
        ))
    }

    func addServiceLine() {
        lineItems.append(DraftLineItem(
            sku: "", description: "Shipping / Service", carats: 0, rate: 0, gemstone: nil, kind: .service
        ))
    }

    // MARK: - Remove / Update Lines

    func removeLine(at indexSet: IndexSet) {
        lineItems.remove(atOffsets: indexSet)
    }

    func removeLine(id: UUID) {
        lineItems.removeAll { $0.id == id }
    }

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
        lineItems[index].rate = max(0, min(value, InputValidator.maxPrice))
    }

    func updateAmount(at index: Int, _ value: Decimal) {
        guard lineItems.indices.contains(index) else { return }
        lineItems[index].rate = max(0, min(value, InputValidator.maxPrice))  // For service lines, rate IS the amount
    }

    /// Validates all line items before saving. Returns first error or nil.
    func validateLineItems() -> String? {
        if let err = InputValidator.validateLineItemCount(lineItems.count) { return err }
        for (i, item) in lineItems.enumerated() {
            if item.kind == .brokered || item.kind == .service {
                if let err = InputValidator.validatePositiveAmount(item.rate, field: "Line \(i + 1) rate") {
                    return err
                }
            }
            if item.kind == .brokered {
                if item.carats < 0 {
                    return "Line \(i + 1) carats cannot be negative."
                }
            }
        }
        return nil
    }

    // MARK: - Load / Reset

    func reset() {
        customer = nil
        date = Date()
        dueDate = nil
        terms = "Net 30"
        referenceNumber = ""
        notes = ""
        taxRatePercent = 0
        lineItems = []
        lastRFIDMessage = nil
    }

    func load(memo: Memo) {
        customer = memo.customer
        date = memo.dateAssigned ?? Date()
        referenceNumber = memo.referenceNumber
        notes = memo.notes
        lineItems = memo.lineItems.map { item in
            DraftLineItem(
                sku: item.sku,
                description: item.itemDescription,
                carats: item.carats,
                rate: item.rate,
                gemstone: item.gemstone,
                kind: item.kind,
                brokeredStoneType: item.brokeredStoneType,
                isLotLineItem: item.isLotLineItem,
                lockedCostPerCarat: item.lockedCostPerCarat
            )
        }
    }

    func load(invoice: Invoice) {
        customer = invoice.customer
        date = invoice.invoiceDate
        dueDate = invoice.dueDate
        terms = invoice.terms
        referenceNumber = invoice.referenceNumber
        notes = invoice.notes
        lineItems = invoice.lineItems.map { item in
            DraftLineItem(
                sku: item.sku,
                description: item.itemDescription,
                carats: item.carats,
                rate: item.rate,
                gemstone: item.gemstone,
                kind: item.kind,
                brokeredStoneType: item.brokeredStoneType,
                isLotLineItem: item.isLotLineItem,
                lockedCostPerCarat: item.lockedCostPerCarat
            )
        }
    }

    // MARK: - RFID Handling

    func handleScannedTag(_ tagID: String, modelContext: ModelContext) {
        lastRFIDMessage = nil
        guard let canonicalEpc = EPCanonical.normalize(tagID) ?? EPCanonical.canonicalHex(fromRawHex: tagID) else {
            lastRFIDMessage = "Tag format invalid"
            return
        }

        // Look up via RFIDTag table first
        let tagDescriptor = FetchDescriptor<RFIDTag>(
            predicate: #Predicate<RFIDTag> { $0.epcCurrent == canonicalEpc }
        )
        if let tag = try? modelContext.fetch(tagDescriptor).first,
           let stone = tag.assignedStone {
            handleScannedStone(stone, modelContext: modelContext)
            return
        }

        // Fallback to Gemstone.rfidEpc
        let stoneDescriptor = FetchDescriptor<Gemstone>(
            predicate: #Predicate<Gemstone> { $0.rfidEpc == canonicalEpc }
        )
        guard let stone = try? modelContext.fetch(stoneDescriptor).first else {
            lastRFIDMessage = "Tag not in database"
            return
        }
        handleScannedStone(stone, modelContext: modelContext)
    }

    func clearLastRFIDMessage() { lastRFIDMessage = nil }

    private func handleScannedStone(_ stone: Gemstone, modelContext: ModelContext) {
        switch stone.status {
        case .available:
            if lineItems.contains(where: { $0.gemstone?.sku == stone.sku }) {
                lastRFIDMessage = "Already in list: \(stone.sku)"
            } else {
                addStoneFromInventory(stone)
                lastRFIDMessage = "Added: \(stone.sku)"
            }
        case .onMemo:
            guard let memo = stone.memo,
                  let item = memo.openLineItems.first(where: { $0.gemstone?.sku == stone.sku }) else {
                lastRFIDMessage = "Stone on memo but line item not found"
                return
            }
            do {
                try MemoService.returnItems([item], modelContext: modelContext)
                lastRFIDMessage = "Returned to stock: \(stone.sku)"
            } catch {
                lastRFIDMessage = "Failed to return stone: \(ErrorMapper.userMessage(from: error))"
            }
        case .sold:
            lastRFIDMessage = "Stone already sold: \(stone.sku)"
        }
    }
}
