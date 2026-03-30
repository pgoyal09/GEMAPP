import Foundation
import SwiftData

@MainActor
@Observable
final class LotInventoryViewModel {
    var searchText: String = ""
    var selectedLotID: PersistentIdentifier? = nil
    var showAddQuantitySheet: Bool = false

    // Add-quantity form state
    var addCarats: Double = 0
    var addCostPerCarat: Decimal = 0
    var addNotes: String = ""

    func filtered(from lots: [Gemstone]) -> [Gemstone] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return lots }
        return lots.filter { lot in
            lot.sku.lowercased().contains(q) ||
            lot.stoneType.rawValue.lowercased().contains(q) ||
            lot.color.lowercased().contains(q)
        }
    }

    func addQuantity(to lot: Gemstone, modelContext: ModelContext) throws {
        try LotService.addQuantity(
            to: lot,
            carats: addCarats,
            costPerCarat: addCostPerCarat,
            notes: addNotes,
            modelContext: modelContext
        )
        resetAddForm()
    }

    func resetAddForm() {
        addCarats = 0
        addCostPerCarat = 0
        addNotes = ""
        showAddQuantitySheet = false
    }
}
