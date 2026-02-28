import Foundation
import SwiftData

@MainActor
struct DataSeeder {
    
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Gemstone>()
        
        do {
            let existingCount = try modelContext.fetchCount(descriptor)
            if existingCount > 0 {
                return // Already seeded
            }
        } catch {
            print("DataSeeder: Failed to check existing data: \(error)")
            return
        }
        
        seedGemstones(modelContext: modelContext)
        seedCustomers(modelContext: modelContext)
        seedMemos(modelContext: modelContext)
        
        do {
            try modelContext.save()
        } catch {
            print("DataSeeder: Failed to save: \(error)")
        }
    }
    
    private static func seedGemstones(modelContext: ModelContext) {
        let gemstones: [(String, StoneType, Double, String, String, String, String, Decimal, Decimal)] = [
            ("SKU-001", .diamond, 1.25, "D", "VS1", "Round", "India", 4500, 6200),
            ("SKU-002", .diamond, 0.75, "E", "VVS2", "Princess", "Belgium", 2800, 3800),
            ("SKU-003", .ruby, 2.0, "Pigeon Blood", "Eye Clean", "Oval", "Myanmar", 8500, 12000),
            ("SKU-004", .sapphire, 1.5, "Royal Blue", "VS", "Cushion", "Sri Lanka", 4200, 5800),
            ("SKU-005", .diamond, 2.0, "F", "SI1", "Emerald", "South Africa", 7200, 9500),
            ("SKU-006", .sapphire, 0.9, "Padparadscha", "VVS", "Round", "Sri Lanka", 6500, 8900),
            ("SKU-007", .ruby, 1.2, "Red", "SI", "Round", "Thailand", 3200, 4500),
            ("SKU-008", .diamond, 1.0, "G", "VS2", "Round", "India", 3800, 5200),
            ("SKU-009", .sapphire, 3.0, "Yellow", "Eye Clean", "Oval", "Madagascar", 2100, 3100),
            ("SKU-010", .diamond, 1.5, "H", "SI2", "Cushion", "Russia", 4200, 5600)
        ]
        
        for (sku, type, carat, color, clarity, cut, origin, cost, sell) in gemstones {
            let stone = Gemstone(
                sku: sku,
                stoneType: type,
                caratWeight: carat,
                color: color,
                clarity: clarity,
                cut: cut,
                origin: origin,
                costPrice: cost,
                sellPrice: sell
            )
            modelContext.insert(stone)
        }
    }
    
    private static func seedCustomers(modelContext: ModelContext) {
        let customers: [(String, String, String?, String?)] = [
            ("Acme", "Jewelers", "contact@acmejewelers.com", "+1-555-0100"),
            ("Luxury Gems", "Co", "orders@luxurygems.com", "+1-555-0200"),
            ("Sparkle", "Boutique", nil, "+1-555-0300")
        ]
        
        for (firstName, lastName, email, phone) in customers {
            let customer = Customer(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phone
            )
            modelContext.insert(customer)
        }
    }
    
    private static func seedMemos(modelContext: ModelContext) {
        let gemstoneDescriptor = FetchDescriptor<Gemstone>(sortBy: [SortDescriptor(\.sku)])
        let customerDescriptor = FetchDescriptor<Customer>(sortBy: [SortDescriptor(\.lastName)])
        
        guard let gemstones = try? modelContext.fetch(gemstoneDescriptor),
              let customers = try? modelContext.fetch(customerDescriptor),
              gemstones.count >= 4,
              customers.count >= 2 else {
            return
        }
        
        // Memo 1: two stones + optional custom line
        let memo1 = Memo(
            status: .onMemo,
            dateAssigned: Date().addingTimeInterval(-86400 * 5),
            notes: "Sample memo for display",
            referenceNumber: "101",
            customer: customers[0]
        )
        modelContext.insert(memo1)
        
        for (stone, rate) in [(gemstones[0], Decimal(6200)), (gemstones[1], Decimal(3800))] {
            let item = LineItem(
                sku: stone.sku,
                itemDescription: "\(stone.stoneType.rawValue) \(stone.color) \(stone.clarity) \(stone.cut)",
                carats: stone.caratWeight,
                rate: rate,
                amount: rate * Decimal(stone.caratWeight),
                gemstone: stone,
                isService: false
            )
            modelContext.insert(item)
            item.memo = memo1
            stone.memo = memo1
            stone.status = .onMemo
        }
        
        // Memo 2: one stone
        let memo2 = Memo(
            status: .onMemo,
            dateAssigned: Date().addingTimeInterval(-86400 * 2),
            referenceNumber: "102",
            customer: customers[1]
        )
        modelContext.insert(memo2)
        
        let stone2 = gemstones[2]
        let item2 = LineItem(
            sku: stone2.sku,
            itemDescription: "\(stone2.stoneType.rawValue) \(stone2.color) \(stone2.clarity) \(stone2.cut)",
            carats: stone2.caratWeight,
            rate: stone2.sellPrice,
            amount: stone2.sellPrice * Decimal(stone2.caratWeight),
            gemstone: stone2,
            isService: false
        )
        modelContext.insert(item2)
        item2.memo = memo2
        stone2.memo = memo2
        stone2.status = .onMemo
    }
}
