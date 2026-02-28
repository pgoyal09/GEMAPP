import Foundation
import SwiftData

/// Manages demo data: reset (wipe + reseed) and deterministic Style 1 dataset.
@MainActor
struct DemoDataManager {

    /// Deletes all existing records and inserts new demo data.
    static func resetAllData(modelContext: ModelContext) async throws {
        try deleteAllData(modelContext: modelContext)
        try seedDemoData(modelContext: modelContext)
    }

    /// Deletes all Gemstone, Customer, Memo, Invoice, LineItem, HistoryEvent.
    static func deleteAllData(modelContext: ModelContext) throws {
        for event in try modelContext.fetch(FetchDescriptor<HistoryEvent>()) { modelContext.delete(event) }
        for item in try modelContext.fetch(FetchDescriptor<LineItem>()) { modelContext.delete(item) }
        for inv in try modelContext.fetch(FetchDescriptor<Invoice>()) { modelContext.delete(inv) }
        for memo in try modelContext.fetch(FetchDescriptor<Memo>()) { modelContext.delete(memo) }
        for stone in try modelContext.fetch(FetchDescriptor<Gemstone>()) { modelContext.delete(stone) }
        for cust in try modelContext.fetch(FetchDescriptor<Customer>()) { modelContext.delete(cust) }
        try modelContext.save()
    }

    /// Inserts a new Style 1 dataset: 10 customers, 30 gemstones, 12 memos, 10 invoices.
    static func seedDemoData(modelContext: ModelContext) throws {
        let customers = seedCustomers(modelContext: modelContext)
        let gemstones = seedGemstones(modelContext: modelContext)
        let (openMemos, _) = seedMemos(modelContext: modelContext, customers: customers, gemstones: gemstones)
        seedInvoices(modelContext: modelContext, customers: customers, gemstones: gemstones, openMemos: openMemos)
        seedHistoryEvents(modelContext: modelContext, gemstones: gemstones)
        try modelContext.save()
    }

    // MARK: - Customers (10)

    private static func seedCustomers(modelContext: ModelContext) -> [Customer] {
        let data: [(String, String, String?, String?, String?)] = [
            ("Aurora", "Boutique", "contact@auroraboutique.com", "+1-555-1001", "Boutique"),
            ("Crown", "Jeweler", "orders@crownjeweler.com", "+1-555-1002", "Jeweler"),
            ("Elite", "Wholesaler", "sales@elitewholesale.com", "+1-555-1003", "Wholesaler"),
            ("Fiori", "Gems", "info@fiorigems.com", "+1-555-1004", "Boutique"),
            ("Gemstone", "House", nil, "+1-555-1005", "Jeweler"),
            ("Horizon", "Jewelers", "orders@horizonjewelers.com", "+1-555-1006", "Wholesaler"),
            ("Luxe", "Boutique", "hello@luxeboutique.com", "+1-555-1007", "Boutique"),
            ("Monarch", "Gems", "sales@monarchgems.com", "+1-555-1008", "Wholesaler"),
            ("Nova", "Jewelry", "info@novajewelry.com", "+1-555-1009", "Jeweler"),
            ("Opulent", "Collection", "orders@opulentcollection.com", "+1-555-1010", "Boutique"),
        ]
        var result: [Customer] = []
        let baseDate = Date().addingTimeInterval(-86400 * 365)
        for (i, (first, last, email, phone, _)) in data.enumerated() {
            let c = Customer(
                firstName: first,
                lastName: last,
                company: "\(first) \(last)",
                email: email,
                phone: phone,
                createdAt: baseDate.addingTimeInterval(Double(i) * 86400)
            )
            modelContext.insert(c)
            result.append(c)
        }
        return result
    }

    // MARK: - Gemstones (30: DIA001–010, RU001–010, SAP001–010)

    private static func seedGemstones(modelContext: ModelContext) -> [Gemstone] {
        var result: [Gemstone] = []
        let baseDate = Date().addingTimeInterval(-86400 * 180)

        // Diamonds (DIA001–010): 0.30–3.50ct, D–K, IF–SI2, $500–$25k cost
        let diaSpecs: [(Double, String, String, String, Decimal, Decimal)] = [
            (1.25, "D", "IF", "Round", 8500, 12500),
            (0.75, "E", "VVS2", "Princess", 3800, 5200),
            (2.00, "F", "VS1", "Emerald", 12000, 18000),
            (0.50, "G", "VS2", "Round", 2200, 3200),
            (1.50, "H", "SI1", "Cushion", 6500, 9000),
            (0.90, "I", "SI2", "Oval", 2800, 4000),
            (1.00, "J", "VS2", "Round", 4200, 5800),
            (2.50, "D", "VVS1", "Round", 18000, 25000),
            (0.35, "E", "VVS2", "Princess", 1200, 1800),
            (3.00, "K", "SI2", "Cushion", 9000, 12000),
        ]
        for (i, (carat, color, clarity, cut, cost, sell)) in diaSpecs.enumerated() {
            let stone = Gemstone(
                sku: String(format: "DIA%03d", i + 1),
                stoneType: .diamond,
                caratWeight: carat,
                color: color,
                clarity: clarity,
                cut: cut,
                origin: ["India", "Belgium", "South Africa", "Russia"][i % 4],
                costPrice: cost,
                sellPrice: sell,
                createdAt: baseDate.addingTimeInterval(Double(i) * 3600)
            )
            modelContext.insert(stone)
            result.append(stone)
        }

        // Rubies (RU001–010): Pigeon Blood, colors
        let ruSpecs: [(Double, String, String, String, Decimal, Decimal)] = [
            (2.0, "Pigeon Blood", "Eye Clean", "Oval", 12000, 18000),
            (1.2, "Red", "SI", "Round", 4200, 5800),
            (1.5, "Pigeon Blood", "VVS", "Cushion", 9500, 14000),
            (0.80, "Red", "Eye Clean", "Round", 2800, 4000),
            (2.5, "Pigeon Blood", "Eye Clean", "Oval", 18000, 26000),
            (1.0, "Red", "VS", "Princess", 3500, 5000),
            (1.8, "Pigeon Blood", "VVS", "Oval", 14000, 20000),
            (0.60, "Red", "SI", "Round", 1800, 2600),
            (3.0, "Pigeon Blood", "Eye Clean", "Cushion", 22000, 32000),
            (1.4, "Red", "VS", "Oval", 6500, 9000),
        ]
        for (i, (carat, color, clarity, cut, cost, sell)) in ruSpecs.enumerated() {
            let stone = Gemstone(
                sku: String(format: "RU%03d", i + 1),
                stoneType: .ruby,
                caratWeight: carat,
                color: color,
                clarity: clarity,
                cut: cut,
                origin: ["Myanmar", "Thailand", "Mozambique"][i % 3],
                costPrice: cost,
                sellPrice: sell,
                createdAt: baseDate.addingTimeInterval(Double(10 + i) * 3600)
            )
            modelContext.insert(stone)
            result.append(stone)
        }

        // Sapphires (SAP001–010)
        let sapSpecs: [(Double, String, String, String, Decimal, Decimal)] = [
            (1.5, "Royal Blue", "VS", "Cushion", 8500, 12000),
            (0.9, "Padparadscha", "VVS", "Round", 7200, 10000),
            (2.0, "Royal Blue", "Eye Clean", "Oval", 14000, 20000),
            (1.2, "Yellow", "Eye Clean", "Cushion", 4200, 6000),
            (1.0, "Padparadscha", "VS", "Oval", 6500, 9000),
            (2.5, "Royal Blue", "VVS", "Cushion", 18000, 26000),
            (0.75, "Pink", "Eye Clean", "Round", 2800, 4000),
            (1.8, "Royal Blue", "VS", "Oval", 12000, 17000),
            (3.0, "Yellow", "Eye Clean", "Oval", 5500, 8000),
            (1.3, "Padparadscha", "Eye Clean", "Cushion", 9500, 13000),
        ]
        for (i, (carat, color, clarity, cut, cost, sell)) in sapSpecs.enumerated() {
            let stone = Gemstone(
                sku: String(format: "SAP%03d", i + 1),
                stoneType: .sapphire,
                caratWeight: carat,
                color: color,
                clarity: clarity,
                cut: cut,
                origin: ["Sri Lanka", "Madagascar", "Thailand"][i % 3],
                costPrice: cost,
                sellPrice: sell,
                createdAt: baseDate.addingTimeInterval(Double(20 + i) * 3600)
            )
            modelContext.insert(stone)
            result.append(stone)
        }

        return result
    }

    // MARK: - Memos (12: 6 onMemo, 6 returned)

    private static func seedMemos(modelContext: ModelContext, customers: [Customer], gemstones: [Gemstone]) -> ([Memo], [Memo]) {
        var openMemos: [Memo] = []
        var returnedMemos: [Memo] = []

        let baseDate = Date().addingTimeInterval(-86400 * 120)
        // Open memos: 6, days 90, 60, 45, 30, 20, 10 ago
        let openDaysAgo = [90, 60, 45, 30, 20, 10]
        // Stones for open memos: DIA001-003, RU001-003, SAP001-004 (10 stones)
        let openStoneIndices = [0, 1, 2, 10, 11, 12, 20, 21, 22, 23]
        var stoneCursor = 0

        for (i, daysAgo) in openDaysAgo.enumerated() {
            let date = baseDate.addingTimeInterval(Double(-daysAgo) * 86400)
            let memo = Memo(
                status: .onMemo,
                dateAssigned: date,
                createdAt: date,
                referenceNumber: "\(1001 + i)",
                customer: customers[i % customers.count]
            )
            modelContext.insert(memo)
            openMemos.append(memo)

            let count = (i < 3) ? 2 : 1
            for _ in 0..<count where stoneCursor < openStoneIndices.count {
                let idx = openStoneIndices[stoneCursor]
                let stone = gemstones[idx]
                stoneCursor += 1
                addMemoLineItem(modelContext: modelContext, memo: memo, stone: stone)
                stone.memo = memo
                stone.status = .onMemo
            }
        }

        // Returned memos: 6 (historical; stones came back, now Available)
        let returnedStoneIndices = [3, 19, 26, 27, 28, 29]
        for (i, stoneIdx) in returnedStoneIndices.enumerated() {
            guard stoneIdx < gemstones.count else { continue }
            let daysAgo = 150 - i * 5
            let date = baseDate.addingTimeInterval(Double(-daysAgo) * 86400)
            let memo = Memo(
                status: .returned,
                dateAssigned: date,
                dateCompleted: date.addingTimeInterval(86400 * 30),
                createdAt: date,
                referenceNumber: "\(900 + i)",
                customer: customers[(i + 2) % customers.count]
            )
            modelContext.insert(memo)
            returnedMemos.append(memo)
            let stone = gemstones[stoneIdx]
            addMemoLineItem(modelContext: modelContext, memo: memo, stone: stone, status: .returned)
        }

        return (openMemos, returnedMemos)
    }

    private static func addMemoLineItem(modelContext: ModelContext, memo: Memo, stone: Gemstone, status: LineItemStatus = .open) {
        let rate = stone.sellPrice
        let amount = rate * Decimal(stone.caratWeight)
        let item = LineItem(
            sku: stone.sku,
            itemDescription: "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)",
            carats: stone.caratWeight,
            rate: rate,
            amount: amount,
            gemstone: stone,
            isService: false,
            status: status
        )
        modelContext.insert(item)
        item.memo = memo
    }

    // MARK: - Invoices (10: 5 paid, 5 sent)

    private static func seedInvoices(modelContext: ModelContext, customers: [Customer], gemstones: [Gemstone], openMemos: [Memo]) {
        let baseDate = Date().addingTimeInterval(-86400 * 60)
        // Use stones that are Available (not in open memos 0,1,2,10,11,12,20,21,22,23 or returned 3,19,26-29)
        let soldStoneIndices = [4, 5, 6, 7, 8, 9, 13, 14, 15, 16, 17, 18, 24, 25]
        var stoneCursor = 0

        for i in 0..<10 {
            let daysAgo = 50 - i * 4
            let invDate = baseDate.addingTimeInterval(Double(-daysAgo) * 86400)
            let isPaid = i < 5
            let inv = Invoice(
                invoiceDate: invDate,
                dueDate: invDate.addingTimeInterval(86400 * 30),
                terms: "Net 30",
                referenceNumber: "INV-\(2000 + i)",
                createdAt: invDate,
                status: isPaid ? .paid : .sent,
                customer: customers[(i + 3) % customers.count]
            )
            modelContext.insert(inv)

            let lineCount = (i % 2 == 0) ? 2 : 1
            for _ in 0..<lineCount where stoneCursor < soldStoneIndices.count {
                let idx = soldStoneIndices[stoneCursor]
                let stone = gemstones[idx]
                stoneCursor += 1
                addInvoiceLineItem(modelContext: modelContext, invoice: inv, stone: stone)
                stone.status = .sold
                stone.memo = nil
            }
        }
    }

    private static func addInvoiceLineItem(modelContext: ModelContext, invoice: Invoice, stone: Gemstone) {
        let rate = stone.sellPrice
        let amount = rate * Decimal(stone.caratWeight)
        let item = LineItem(
            sku: stone.sku,
            itemDescription: "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)",
            carats: stone.caratWeight,
            rate: rate,
            amount: amount,
            gemstone: stone,
            isService: false,
            status: .sold,
            soldDate: invoice.effectiveStatus == .paid ? invoice.invoiceDate : nil
        )
        modelContext.insert(item)
        item.invoice = invoice
    }

    // MARK: - History Events

    private static func seedHistoryEvents(modelContext: ModelContext, gemstones: [Gemstone]) {
        for (i, stone) in gemstones.prefix(20).enumerated() {
            let event = HistoryEvent(
                date: stone.createdAt.addingTimeInterval(3600),
                eventDescription: "Created in system",
                eventType: .dateAdded,
                gemstone: stone
            )
            modelContext.insert(event)

            if i % 4 == 1, stone.effectiveStatus == .onMemo {
                let e2 = HistoryEvent(
                    date: stone.createdAt.addingTimeInterval(86400),
                    eventDescription: "Sent to customer on memo",
                    eventType: .sentToCustomer,
                    gemstone: stone
                )
                modelContext.insert(e2)
            }
            if stone.effectiveStatus == .sold {
                let e3 = HistoryEvent(
                    date: stone.createdAt.addingTimeInterval(86400 * 2),
                    eventDescription: "Sold via invoice",
                    eventType: .sold,
                    gemstone: stone
                )
                modelContext.insert(e3)
            }
        }
    }
}
