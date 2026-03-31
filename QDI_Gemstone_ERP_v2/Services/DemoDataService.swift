import Foundation
import SwiftData

/// Unified demo-data service: seeds initial data on first launch, and supports full reset.
@MainActor
struct DemoDataService {

    // MARK: - Public API

    /// Checks whether data already exists; if the store is empty, seeds demo data.
    /// Throws on any SwiftData failure (never silently swallows errors).
    static func seedIfNeeded(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<Gemstone>()
        let existingCount = try modelContext.fetchCount(descriptor)
        if existingCount > 0 { return }
        try seedDemoData(modelContext: modelContext)
    }

    /// Deletes every record and reseeds from scratch.
    static func resetAllData(modelContext: ModelContext) throws {
        try deleteAllData(modelContext: modelContext)
        try seedDemoData(modelContext: modelContext)
    }

    // MARK: - Delete All

    /// Deletes all entities in dependency-safe order using batch delete.
    static func deleteAllData(modelContext: ModelContext) throws {
        // Use fetch-then-delete instead of batch delete.
        // SwiftData batch delete bypasses relationship cascade rules,
        // causing "mandatory OTO nullify inverse" errors on LotTransaction/gemstone.
        func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
            let items = try modelContext.fetch(FetchDescriptor<T>())
            for item in items { modelContext.delete(item) }
        }
        // Delete in dependency order (children before parents)
        try deleteAll(PaymentReminder.self)
        try deleteAll(ReconciliationRecord.self)
        try deleteAll(LotTransaction.self)
        try deleteAll(HistoryEvent.self)
        try deleteAll(LineItem.self)
        try deleteAll(Invoice.self)
        try deleteAll(Memo.self)
        try deleteAll(RFIDTag.self)
        try deleteAll(Gemstone.self)
        try deleteAll(Customer.self)
        try modelContext.save()
    }

    // MARK: - Seed All Demo Data

    /// Creates demo data using a background context for better performance.
    /// Falls back to the provided context if container is not available.
    static func seedDemoDataInBackground(container: ModelContainer) throws {
        let bgContext = ModelContext(container)
        bgContext.autosaveEnabled = false
        try seedDemoData(modelContext: bgContext)
    }

    /// Creates 10 customers, 30 gemstones, 8 lot stones, 12 memos, 10 invoices,
    /// history events, and lot transactions.
    static func seedDemoData(modelContext: ModelContext) throws {
        let customers = seedCustomers(modelContext: modelContext)
        let gemstones = seedGemstones(modelContext: modelContext)
        let lotStones = seedLotStones(modelContext: modelContext)
        let (openMemos, _) = seedMemos(modelContext: modelContext, customers: customers, gemstones: gemstones)
        seedInvoices(modelContext: modelContext, customers: customers, gemstones: gemstones, openMemos: openMemos)
        seedHistoryEvents(modelContext: modelContext, gemstones: gemstones)
        seedLotTransactions(modelContext: modelContext, lotStones: lotStones, customers: customers)
        seedPaymentReminders(modelContext: modelContext)
        seedReconciliationRecords(modelContext: modelContext)
        try modelContext.save()
    }

    // MARK: - Customers (10)

    private static func seedCustomers(modelContext: ModelContext) -> [Customer] {
        let data: [(String, String, String, String, String)] = [
            ("Aurora",   "Boutique",    "contact@auroraboutique.com",    "+1-555-1001", "Boutique"),
            ("Crown",    "Jeweler",     "orders@crownjeweler.com",       "+1-555-1002", "Jeweler"),
            ("Elite",    "Wholesaler",  "sales@elitewholesale.com",      "+1-555-1003", "Wholesaler"),
            ("Fiori",    "Gems",        "info@fiorigems.com",            "+1-555-1004", "Boutique"),
            ("Gemstone", "House",       "",                              "+1-555-1005", "Jeweler"),
            ("Horizon",  "Jewelers",    "orders@horizonjewelers.com",    "+1-555-1006", "Wholesaler"),
            ("Luxe",     "Boutique",    "hello@luxeboutique.com",        "+1-555-1007", "Boutique"),
            ("Monarch",  "Gems",        "sales@monarchgems.com",         "+1-555-1008", "Wholesaler"),
            ("Nova",     "Jewelry",     "info@novajewelry.com",          "+1-555-1009", "Jeweler"),
            ("Opulent",  "Collection",  "orders@opulentcollection.com",  "+1-555-1010", "Boutique"),
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

    // MARK: - Gemstones (30: DIA001-010, RU001-010, SAP001-010)

    private static func seedGemstones(modelContext: ModelContext) -> [Gemstone] {
        var result: [Gemstone] = []
        let baseDate = Date().addingTimeInterval(-86400 * 180)

        // Diamonds (DIA001-010): 0.30-3.50ct, D-K, IF-SI2, $500-$25k cost
        let diaSpecs: [(Double, String, String, String, Decimal, Decimal)] = [
            (1.25, "D",  "IF",   "Round",    8500,  12500),
            (0.75, "E",  "VVS2", "Princess", 3800,  5200),
            (2.00, "F",  "VS1",  "Emerald",  12000, 18000),
            (0.50, "G",  "VS2",  "Round",    2200,  3200),
            (1.50, "H",  "SI1",  "Cushion",  6500,  9000),
            (0.90, "I",  "SI2",  "Oval",     2800,  4000),
            (1.00, "J",  "VS2",  "Round",    4200,  5800),
            (2.50, "D",  "VVS1", "Round",    18000, 25000),
            (0.35, "E",  "VVS2", "Princess", 1200,  1800),
            (3.00, "K",  "SI2",  "Cushion",  9000,  12000),
        ]
        for (i, (carat, color, clarity, shape, cost, sell)) in diaSpecs.enumerated() {
            let origins = ["India", "Belgium", "South Africa", "Russia"]
            let polishGrades = ["Excellent", "Excellent", "Very Good", "Excellent", "Excellent", "Very Good", "Excellent", "Excellent", "Excellent", "Good"]
            let symGrades = ["Excellent", "Excellent", "Excellent", "Very Good", "Excellent", "Very Good", "Excellent", "Excellent", "Very Good", "Good"]
            let fluors = ["None", "None", "Faint", "None", "Medium", "None", "Faint", "None", "None", "Faint"]
            let certLabs = ["GIA", "GIA", "AGS", "GIA", "IGI", "GIA", "GIA", "GIA", "AGS", "GIA"]
            let certNos = ["6451230987", "2251340876", "AGS-104054321", "7361240567", "IGI-459012345", "5271430678", "8181540789", "1291650890", "AGS-104165432", "4201760901"]
            let lengths = [6.90, 5.30, 8.00, 5.15, 7.32, 6.23, 6.50, 8.50, 4.50, 8.80]
            let widths = [6.90, 5.30, 5.80, 5.15, 6.45, 5.43, 6.50, 8.50, 4.50, 7.70]
            let heights = [4.28, 3.78, 5.12, 3.21, 4.71, 3.62, 4.05, 5.23, 3.20, 5.02]
            let depths = [62.0, 61.3, 64.0, 62.3, 61.8, 60.5, 62.3, 61.5, 61.0, 63.2]
            let tables = [57.0, 56.0, 58.0, 57.5, 56.0, 58.0, 57.0, 55.0, 56.5, 58.5]
            let rapPrices: [Decimal] = [10200, 5500, 15000, 3400, 7200, 3100, 5000, 22000, 1900, 4500]
            let rapDiscs = [-18.0, -20.5, -15.0, -25.0, -12.5, -22.0, -14.0, -10.0, -24.0, -30.0]
            let cities = ["Surat", "Antwerp", "Johannesburg", "Moscow", "Surat", "Antwerp", "Johannesburg", "Moscow", "Surat", "Antwerp"]
            let countries = ["India", "Belgium", "South Africa", "Russia", "India", "Belgium", "South Africa", "Russia", "India", "Belgium"]
            let stone = Gemstone(
                sku: String(format: "DIA%03d", i + 1),
                stoneType: .diamond,
                caratWeight: carat,
                shape: shape,
                grouping: .single,
                origin: origins[i % 4],
                createdAt: baseDate.addingTimeInterval(Double(i) * 3600),
                status: .available,
                color: color,
                clarity: clarity,
                cut: shape,
                treatment: "None",
                polish: polishGrades[i],
                symmetry: symGrades[i],
                fluorescence: fluors[i],
                hasCert: true,
                certLab: certLabs[i],
                certNo: certNos[i],
                length: lengths[i],
                width: widths[i],
                height: heights[i],
                costPrice: cost,
                sellPrice: sell
            )
            stone.depthPct = depths[i]
            stone.tablePct = tables[i]
            stone.rapNetPrice = rapPrices[i]
            stone.rapNetDiscountPct = rapDiscs[i]
            stone.numberOfStones = 1
            stone.stoneCountry = countries[i]
            stone.stoneCity = cities[i]
            stone.fluorescenceIntensity = fluors[i] == "None" ? "N" : (fluors[i] == "Faint" ? "F" : "M")
            stone.fluorescenceColor = fluors[i] == "None" ? "N" : "B"
            stone.eyeClean = clarity.contains("SI") ? "Borderline" : "Yes"
            stone.availability = "G"
            modelContext.insert(stone)
            result.append(stone)
        }

        // Rubies (RU001-010)
        let ruSpecs: [(Double, String, String, String, Decimal, Decimal)] = [
            (2.0,  "Pigeon Blood", "Eye Clean", "Oval",     12000, 18000),
            (1.2,  "Red",          "SI",        "Round",    4200,  5800),
            (1.5,  "Pigeon Blood", "VVS",       "Cushion",  9500,  14000),
            (0.80, "Red",          "Eye Clean", "Round",    2800,  4000),
            (2.5,  "Pigeon Blood", "Eye Clean", "Oval",     18000, 26000),
            (1.0,  "Red",          "VS",        "Princess", 3500,  5000),
            (1.8,  "Pigeon Blood", "VVS",       "Oval",     14000, 20000),
            (0.60, "Red",          "SI",        "Round",    1800,  2600),
            (3.0,  "Pigeon Blood", "Eye Clean", "Cushion",  22000, 32000),
            (1.4,  "Red",          "VS",        "Oval",     6500,  9000),
        ]
        for (i, (carat, color, clarity, shape, cost, sell)) in ruSpecs.enumerated() {
            let ruOrigins = ["Myanmar", "Thailand", "Mozambique"]
            let ruTreatments = ["None", "Heated", "None", "Heated", "None", "Heated", "None", "Heated", "None", "Heated"]
            let ruPolish = ["Excellent", "Very Good", "Excellent", "Very Good", "Excellent", "Good", "Excellent", "Very Good", "Excellent", "Very Good"]
            let ruSym = ["Excellent", "Very Good", "Excellent", "Good", "Excellent", "Very Good", "Excellent", "Very Good", "Excellent", "Good"]
            let ruHasCert = [true, false, true, false, true, false, true, false, true, false]
            let ruCertLabs = ["GRS", "", "Gübelin", "", "GIA", "", "GRS", "", "Gübelin", ""]
            let ruCertNos = ["GRS2024-1001", "", "GUB-2024-5501", "", "6342001234", "", "GRS2024-1002", "", "GUB-2024-5502", ""]
            let ruLengths = [7.80, 5.90, 7.10, 5.50, 8.50, 5.20, 7.60, 4.80, 9.10, 6.50]
            let ruWidths = [5.90, 5.90, 6.20, 5.50, 6.50, 5.20, 5.80, 4.80, 7.00, 5.20]
            let ruHeights = [4.10, 3.80, 4.40, 3.60, 4.90, 3.40, 4.00, 3.10, 5.30, 3.80]
            let ruCountries = ["USA", "Thailand", "USA", "Myanmar", "USA", "Hong Kong", "USA", "Japan", "USA", "Switzerland"]
            let ruCities = ["New York", "Bangkok", "New York", "Mogok", "New York", "Wan Chai", "New York", "Tokyo", "New York", "Geneva"]
            let stone = Gemstone(
                sku: String(format: "RU%03d", i + 1),
                stoneType: .ruby,
                caratWeight: carat,
                shape: shape,
                grouping: .single,
                origin: ruOrigins[i % 3],
                createdAt: baseDate.addingTimeInterval(Double(10 + i) * 3600),
                status: .available,
                color: color,
                clarity: clarity,
                cut: shape,
                treatment: ruTreatments[i],
                polish: ruPolish[i],
                symmetry: ruSym[i],
                fluorescence: "None",
                hasCert: ruHasCert[i],
                certLab: ruCertLabs[i],
                certNo: ruCertNos[i],
                length: ruLengths[i],
                width: ruWidths[i],
                height: ruHeights[i],
                costPrice: cost,
                sellPrice: sell
            )
            stone.numberOfStones = 1
            stone.stoneCountry = ruCountries[i]
            stone.stoneCity = ruCities[i]
            stone.primaryColorVendor = color
            stone.colorIntensityVendor = color.contains("Pigeon") ? "Vivid" : "Strong"
            stone.eyeClean = clarity.contains("Eye Clean") ? "Yes" : (clarity.contains("VVS") ? "Yes" : "Borderline")
            stone.availability = "G"
            modelContext.insert(stone)
            result.append(stone)
        }

        // Sapphires (SAP001-010)
        let sapSpecs: [(Double, String, String, String, Decimal, Decimal)] = [
            (1.5,  "Royal Blue",    "VS",        "Cushion", 8500,  12000),
            (0.9,  "Padparadscha",  "VVS",       "Round",   7200,  10000),
            (2.0,  "Royal Blue",    "Eye Clean", "Oval",    14000, 20000),
            (1.2,  "Yellow",        "Eye Clean", "Cushion", 4200,  6000),
            (1.0,  "Padparadscha",  "VS",        "Oval",    6500,  9000),
            (2.5,  "Royal Blue",    "VVS",       "Cushion", 18000, 26000),
            (0.75, "Pink",          "Eye Clean", "Round",   2800,  4000),
            (1.8,  "Royal Blue",    "VS",        "Oval",    12000, 17000),
            (3.0,  "Yellow",        "Eye Clean", "Oval",    5500,  8000),
            (1.3,  "Padparadscha",  "Eye Clean", "Cushion", 9500,  13000),
        ]
        for (i, (carat, color, clarity, shape, cost, sell)) in sapSpecs.enumerated() {
            let sapOrigins = ["Sri Lanka", "Madagascar", "Thailand"]
            let sapTreatments = ["Heated", "None", "Heated", "None", "None", "Heated", "None", "Heated", "None", "None"]
            let sapPolish = ["Excellent", "Excellent", "Very Good", "Very Good", "Excellent", "Excellent", "Excellent", "Very Good", "Excellent", "Excellent"]
            let sapSym = ["Excellent", "Very Good", "Good", "Very Good", "Excellent", "Excellent", "Very Good", "Excellent", "Excellent", "Very Good"]
            let sapHasCert = [true, true, true, false, true, true, false, true, false, true]
            let sapCertLabs = ["GIA", "AIGS", "Gübelin", "", "GRS", "GIA", "", "AIGS", "", "GRS"]
            let sapCertNos = ["6351120345", "AIGS-BK24-2201", "GUB-2024-6601", "", "GRS2024-3301", "6451230456", "", "AIGS-BK24-2202", "", "GRS2024-3302"]
            let sapLengths = [7.00, 5.80, 8.10, 6.20, 6.00, 8.60, 5.40, 7.50, 9.20, 6.80]
            let sapWidths = [6.10, 5.80, 6.30, 5.50, 5.10, 7.20, 5.40, 5.90, 7.10, 5.90]
            let sapHeights = [4.30, 3.70, 4.80, 3.70, 3.40, 5.00, 3.50, 4.20, 5.10, 4.00]
            let sapCountries = ["Sri Lanka", "USA", "Switzerland", "Thailand", "USA", "Sri Lanka", "Hong Kong", "USA", "Japan", "USA"]
            let sapCities = ["Colombo", "New York", "Geneva", "Bangkok", "New York", "Ratnapura", "Central", "New York", "Tokyo", "New York"]
            let stone = Gemstone(
                sku: String(format: "SAP%03d", i + 1),
                stoneType: .sapphire,
                caratWeight: carat,
                shape: shape,
                grouping: .single,
                origin: sapOrigins[i % 3],
                createdAt: baseDate.addingTimeInterval(Double(20 + i) * 3600),
                status: .available,
                color: color,
                clarity: clarity,
                cut: shape,
                treatment: sapTreatments[i],
                polish: sapPolish[i],
                symmetry: sapSym[i],
                fluorescence: "None",
                hasCert: sapHasCert[i],
                certLab: sapCertLabs[i],
                certNo: sapCertNos[i],
                length: sapLengths[i],
                width: sapWidths[i],
                height: sapHeights[i],
                costPrice: cost,
                sellPrice: sell
            )
            stone.numberOfStones = 1
            stone.stoneCountry = sapCountries[i]
            stone.stoneCity = sapCities[i]
            stone.primaryColorVendor = color
            stone.colorIntensityVendor = color.contains("Royal") ? "Vivid" : (color.contains("Padparadscha") ? "Strong" : "Medium")
            stone.eyeClean = clarity.contains("Eye Clean") ? "Yes" : (clarity.contains("VVS") ? "Yes" : "Borderline")
            stone.availability = "G"
            modelContext.insert(stone)
            result.append(stone)
        }

        return result
    }

    // MARK: - Lot Stones (8: 2 diamond, 2 ruby, 2 sapphire, 2 emerald)

    @discardableResult
    private static func seedLotStones(modelContext: ModelContext) -> [Gemstone] {
        var result: [Gemstone] = []
        let baseDate = Date().addingTimeInterval(-86400 * 200)

        // (sku, type, totalCarats, color, clarity, shape, costTotal, sellPerCarat, descriptor, isDiamond)
        let specs: [(String, StoneType, Double, String, String, String, Decimal, Decimal, String, Bool)] = [
            ("DLOT001", .diamond,  25.0, "G-H",          "SI1-SI2",   "Round",   50000, 3500, "0.10-0.19 ct", true),
            ("DLOT002", .diamond,  18.5, "D-F",          "VS1-VS2",   "Princess", 74000, 5200, "0.20-0.30 ct", true),
            ("RLOT001", .ruby,     30.0, "Red",          "Eye Clean", "Oval",    21000, 900,  "AAA",           false),
            ("RLOT002", .ruby,     15.0, "Pigeon Blood", "VVS",       "Cushion", 27000, 2200, "Premium",       false),
            ("SLOT001", .sapphire, 22.0, "Royal Blue",   "VS",        "Cushion", 17600, 1100, "AAA",           false),
            ("SLOT002", .sapphire, 40.0, "Yellow",       "Eye Clean", "Oval",    16000, 550,  "Commercial",    false),
            ("ELOT001", .emerald,  20.0, "Green",        "Eye Clean", "Oval",    14000, 950,  "AA",            false),
            ("ELOT002", .emerald,  12.0, "Deep Green",   "VS",        "Cushion", 19200, 2000, "Premium",       false),
        ]

        for (i, (sku, type, totalCarats, color, clarity, shape, costTotal, sellPerCarat, descriptor, isDiamond)) in specs.enumerated() {
            let avgCostPerCarat = totalCarats > 0 ? costTotal / Decimal(totalCarats) : costTotal
            let lotOrigins = ["India", "Myanmar", "Sri Lanka", "Colombia", "India", "Myanmar", "Sri Lanka", "Colombia"]
            let lotTreatments = ["None", "None", "Heated", "None", "Heated", "None", "Oiled", "None"]
            let lotCountries = ["India", "India", "Thailand", "Sri Lanka", "USA", "Myanmar", "Colombia", "India"]
            let lotCities = ["Surat", "Mumbai", "Bangkok", "Colombo", "New York", "Mandalay", "Bogota", "Jaipur"]
            let lotCounts = [150, 80, 120, 45, 100, 200, 90, 60]
            let stone = Gemstone(
                sku: sku,
                stoneType: type,
                caratWeight: totalCarats,
                shape: shape,
                grouping: .lot,
                origin: lotOrigins[i],
                createdAt: baseDate.addingTimeInterval(Double(i) * 86400),
                status: .available,
                color: color,
                clarity: clarity,
                cut: "",
                treatment: lotTreatments[i],
                size: isDiamond ? descriptor : nil,
                quality: isDiamond ? nil : descriptor,
                costPrice: costTotal,
                sellPrice: sellPerCarat,
                remainingCarats: totalCarats,
                averageCostPerCarat: avgCostPerCarat
            )
            stone.numberOfStones = lotCounts[i]
            stone.stoneCountry = lotCountries[i]
            stone.stoneCity = lotCities[i]
            stone.availability = "G"
            modelContext.insert(stone)
            result.append(stone)
        }
        return result
    }

    // MARK: - Memos (12: 6 onMemo, 6 returned)

    private static func seedMemos(
        modelContext: ModelContext,
        customers: [Customer],
        gemstones: [Gemstone]
    ) -> ([Memo], [Memo]) {
        var openMemos: [Memo] = []
        var returnedMemos: [Memo] = []

        let baseDate = Date().addingTimeInterval(-86400 * 120)

        // Open memos: 6, at various days ago
        let openDaysAgo = [90, 60, 45, 30, 20, 10]
        // Stones for open memos: DIA001-003, RU001-003, SAP001-004 (indices 0-2, 10-12, 20-23)
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

    private static func addMemoLineItem(
        modelContext: ModelContext,
        memo: Memo,
        stone: Gemstone,
        status: LineItemStatus = .open
    ) {
        let rate = stone.sellPrice
        let amount = rate * Decimal(stone.caratWeight)
        let item = LineItem(
            sku: stone.sku,
            itemDescription: "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)",
            carats: stone.caratWeight,
            rate: rate,
            amount: amount,
            kind: .inventory,
            status: status,
            gemstone: stone
        )
        modelContext.insert(item)
        item.memo = memo
    }

    // MARK: - Invoices (10: 5 paid, 5 sent)

    private static func seedInvoices(
        modelContext: ModelContext,
        customers: [Customer],
        gemstones: [Gemstone],
        openMemos: [Memo]
    ) {
        let baseDate = Date().addingTimeInterval(-86400 * 60)
        // Use stones that are still Available (not in open memos or returned memos)
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
                addInvoiceLineItem(modelContext: modelContext, invoice: inv, stone: stone, isPaid: isPaid)
                stone.status = .sold
                stone.memo = nil
            }
        }
    }

    private static func addInvoiceLineItem(
        modelContext: ModelContext,
        invoice: Invoice,
        stone: Gemstone,
        isPaid: Bool
    ) {
        let rate = stone.sellPrice
        let amount = rate * Decimal(stone.caratWeight)
        let item = LineItem(
            sku: stone.sku,
            itemDescription: "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)",
            carats: stone.caratWeight,
            rate: rate,
            amount: amount,
            kind: .inventory,
            status: .sold,
            gemstone: stone
        )
        item.soldDate = isPaid ? invoice.invoiceDate : nil
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

            if i % 4 == 1, stone.status == .onMemo {
                let e2 = HistoryEvent(
                    date: stone.createdAt.addingTimeInterval(86400),
                    eventDescription: "Sent to customer on memo",
                    eventType: .sentToCustomer,
                    gemstone: stone
                )
                modelContext.insert(e2)
            }
            if stone.status == .sold {
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

    // MARK: - Lot Transactions

    private static func seedLotTransactions(
        modelContext: ModelContext,
        lotStones: [Gemstone],
        customers: [Customer]
    ) {
        let now = Date()

        for lot in lotStones {
            // Initial acquisition entry (6 months ago)
            let initialDate = now.addingTimeInterval(-86400 * 180)
            let initialCost = lot.averageCostPerCarat ?? (lot.costPrice / Decimal(lot.caratWeight))
            let initialCarats = lot.caratWeight * 0.6
            let initialTxn = LotTransaction(
                type: .added,
                carats: initialCarats,
                date: initialDate,
                pricePerCarat: initialCost,
                totalPrice: initialCost * Decimal(initialCarats),
                notes: "Initial lot acquisition",
                gemstone: lot
            )
            modelContext.insert(initialTxn)
            lot.lotTransactions.append(initialTxn)

            // Second batch added (3 months ago)
            let secondDate = now.addingTimeInterval(-86400 * 90)
            let secondCostPerCarat = initialCost * Decimal(floatLiteral: 1.05)
            let secondCarats = lot.caratWeight * 0.4
            let secondTxn = LotTransaction(
                type: .added,
                carats: secondCarats,
                date: secondDate,
                pricePerCarat: secondCostPerCarat,
                totalPrice: secondCostPerCarat * Decimal(secondCarats),
                notes: "Replenishment batch",
                gemstone: lot
            )
            modelContext.insert(secondTxn)
            lot.lotTransactions.append(secondTxn)

            // Some sales history (1-2 months ago)
            let saleCarats = lot.caratWeight * 0.15
            let saleDate = now.addingTimeInterval(-86400 * Double.random(in: 20...60))
            let salePricePerCarat = lot.sellPrice
            let lockedCost = lot.averageCostPerCarat ?? initialCost
            let saleTxn = LotTransaction(
                type: .sold,
                carats: saleCarats,
                date: saleDate,
                pricePerCarat: salePricePerCarat,
                totalPrice: salePricePerCarat * Decimal(saleCarats),
                lockedCostPerCarat: lockedCost,
                notes: "Sold to \(customers[Int.random(in: 0..<customers.count)].displayName)",
                gemstone: lot
            )
            modelContext.insert(saleTxn)
            lot.lotTransactions.append(saleTxn)

            // Adjust remaining carats to reflect the sale
            lot.effectiveRemainingCarats -= saleCarats
        }
    }

    // MARK: - Payment Reminders (4)

    private static func seedPaymentReminders(modelContext: ModelContext) {
        let reminders = [
            PaymentReminder(customerName: "Crown Jeweler", invoiceReferences: "INV-2005, INV-2006", amount: 14200, method: "email"),
            PaymentReminder(customerName: "Elite Wholesaler", invoiceReferences: "INV-2007", amount: 26000, method: "email"),
            PaymentReminder(customerName: "Horizon Jewelers", invoiceReferences: "INV-2008", amount: 9000, method: "memo"),
            PaymentReminder(customerName: "Nova Jewelry", invoiceReferences: "INV-2009", amount: 17500, method: "email"),
        ]
        for r in reminders {
            modelContext.insert(r)
        }
    }

    // MARK: - Reconciliation Records (3)

    private static func seedReconciliationRecords(modelContext: ModelContext) {
        let now = Date()
        let rec1 = ReconciliationRecord(matchedCount: 35, missingCount: 0, unknownCount: 0, missingSkus: "")
        rec1.date = now.addingTimeInterval(-86400 * 30)
        modelContext.insert(rec1)

        let rec2 = ReconciliationRecord(matchedCount: 33, missingCount: 2, unknownCount: 1, missingSkus: "RU005, SAP003")
        rec2.date = now.addingTimeInterval(-86400 * 14)
        modelContext.insert(rec2)

        let rec3 = ReconciliationRecord(matchedCount: 36, missingCount: 1, unknownCount: 0, missingSkus: "DIA008")
        rec3.date = now.addingTimeInterval(-86400 * 2)
        modelContext.insert(rec3)
    }
}
