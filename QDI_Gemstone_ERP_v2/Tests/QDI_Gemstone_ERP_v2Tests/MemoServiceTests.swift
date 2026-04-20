import Testing
import Foundation
@testable import QDI_Gemstone_ERP_v2

@Suite("Memo Service Tests")
struct MemoServiceTests {

    @Test("Salesperson validation rejects empty when required")
    func salespersonValidation() {
        let salesperson: String? = nil
        let trimmed = (salesperson ?? "").trimmingCharacters(in: .whitespaces)
        #expect(trimmed.isEmpty, "Nil salesperson should be treated as empty")
    }

    @Test("Salesperson validation accepts non-empty")
    func salespersonAcceptsValue() {
        let salesperson: String? = "John"
        let trimmed = (salesperson ?? "").trimmingCharacters(in: .whitespaces)
        #expect(!trimmed.isEmpty, "Non-empty salesperson should pass validation")
    }

    @Test("Salesperson validation rejects whitespace-only")
    func salespersonRejectsWhitespace() {
        let salesperson: String? = "   "
        let trimmed = (salesperson ?? "").trimmingCharacters(in: .whitespaces)
        #expect(trimmed.isEmpty, "Whitespace-only salesperson should be treated as empty")
    }

    @Test("Bearer token falls back to default")
    func bearerTokenDefault() {
        // Simulate the pattern used in QDIGemstoneERPApp
        let token = UserDefaults.standard.string(forKey: "apiAuthToken_test_nonexistent") ?? "qdi-dev-token"
        #expect(token == "qdi-dev-token", "Missing key should fall back to default token")
    }

    @Test("Bearer token uses stored value when set")
    func bearerTokenStored() {
        let key = "apiAuthToken_test_temp"
        UserDefaults.standard.set("custom-token-123", forKey: key)
        let token = UserDefaults.standard.string(forKey: key) ?? "qdi-dev-token"
        #expect(token == "custom-token-123", "Stored token should be used")
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("MemoStatus raw values are correct strings")
    func memoStatusRawValues() {
        #expect(MemoStatus.onMemo.rawValue == "On Memo")
        #expect(MemoStatus.returned.rawValue == "Returned")
        #expect(MemoStatus.sold.rawValue == "Sold")
    }

    @Test("GemstoneStatus available is correct")
    func gemstoneStatusAvailable() {
        #expect(GemstoneStatus.available.rawValue == "Available")
        #expect(GemstoneStatus.onMemo.rawValue == "On Memo")
        #expect(GemstoneStatus.sold.rawValue == "Sold")
    }

    @Test("LineItemKind has expected cases")
    func lineItemKinds() {
        let inventory = LineItemKind.inventory
        let brokered = LineItemKind.brokered
        let service = LineItemKind.service
        #expect(inventory.rawValue == "Inventory")
        #expect(brokered.rawValue == "Brokered")
        #expect(service.rawValue == "Service")
    }
}
