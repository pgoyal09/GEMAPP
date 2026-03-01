import XCTest
@testable import QDI_Gemstone_ERP

final class RFIDWorkflowLogicTests: XCTestCase {
    func testLifecycleIncludesAssignedState() {
        XCTAssertTrue(RFIDTagLifecycleStatus.allCases.contains(.assigned))
    }

    func testGemstoneEffectiveRfidEpcPrefersCanonicalField() {
        let stone = Gemstone(
            sku: "DIA-001",
            stoneType: .diamond,
            caratWeight: 1.0,
            color: "D",
            clarity: "VVS1",
            cut: "Excellent",
            origin: "IN",
            costPrice: 100,
            sellPrice: 120
        )
        stone.rfidTag = "LEGACY"
        stone.rfidEpc = "E28069952000500D103000E2"

        XCTAssertEqual(stone.effectiveRfidEpc, "E28069952000500D103000E2")
    }
}
