import XCTest
@testable import QDI_Gemstone_ERP

final class RFIDAssignmentConflictTests: XCTestCase {
    func testConflictWhenEPCAlreadyAssignedToAnotherStone() {
        let input = AssignmentConflictInput(
            targetStoneSKU: "DIA-001",
            targetHasExistingRFID: false,
            replaceExisting: false,
            epcAssignedToOtherSKU: "DIA-999",
            tidAssignedToOtherSKU: nil
        )

        let conflict = RFIDScanService.evaluateAssignmentConflict(input)
        XCTAssertEqual(conflict?.message, "EPC already assigned to DIA-999")
    }

    func testConflictWhenTIDAlreadyAssignedToAnotherStone() {
        let input = AssignmentConflictInput(
            targetStoneSKU: "DIA-001",
            targetHasExistingRFID: false,
            replaceExisting: false,
            epcAssignedToOtherSKU: nil,
            tidAssignedToOtherSKU: "RUB-123"
        )

        let conflict = RFIDScanService.evaluateAssignmentConflict(input)
        XCTAssertEqual(conflict?.message, "TID already assigned to RUB-123")
    }

    func testConflictWhenReplaceNotConfirmed() {
        let input = AssignmentConflictInput(
            targetStoneSKU: "DIA-001",
            targetHasExistingRFID: true,
            replaceExisting: false,
            epcAssignedToOtherSKU: nil,
            tidAssignedToOtherSKU: nil
        )

        let conflict = RFIDScanService.evaluateAssignmentConflict(input)
        XCTAssertEqual(conflict?.message, "Stone already has RFID. Confirm replace.")
    }

    func testNoConflictWhenReplaceConfirmedAndNoDuplicates() {
        let input = AssignmentConflictInput(
            targetStoneSKU: "DIA-001",
            targetHasExistingRFID: true,
            replaceExisting: true,
            epcAssignedToOtherSKU: nil,
            tidAssignedToOtherSKU: nil
        )

        XCTAssertNil(RFIDScanService.evaluateAssignmentConflict(input))
    }
}
