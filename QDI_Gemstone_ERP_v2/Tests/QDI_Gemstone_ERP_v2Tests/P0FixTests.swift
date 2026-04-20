import Testing
@testable import QDI_Gemstone_ERP_v2

@MainActor
@Suite("P0 Fix Tests")
struct P0FixTests {

    // MARK: - DocumentDirtyTracker Tests

    @Test("clearMemoDirty only clears memo flag")
    func clearMemoDirtyOnlyClearsMemo() {
        let tracker = DocumentDirtyTracker()
        tracker.hasUnsavedMemo = true
        tracker.hasUnsavedInvoice = true

        tracker.clearMemoDirty()

        #expect(tracker.hasUnsavedMemo == false)
        #expect(tracker.hasUnsavedInvoice == true)
        #expect(tracker.hasAnyDirty == true)
    }

    @Test("clearInvoiceDirty only clears invoice flag")
    func clearInvoiceDirtyOnlyClearsInvoice() {
        let tracker = DocumentDirtyTracker()
        tracker.hasUnsavedMemo = true
        tracker.hasUnsavedInvoice = true

        tracker.clearInvoiceDirty()

        #expect(tracker.hasUnsavedInvoice == false)
        #expect(tracker.hasUnsavedMemo == true)
        #expect(tracker.hasAnyDirty == true)
    }

    @Test("hasAnyDirty returns false when both cleared")
    func hasAnyDirtyWhenBothCleared() {
        let tracker = DocumentDirtyTracker()
        tracker.hasUnsavedMemo = true
        tracker.hasUnsavedInvoice = true

        tracker.clearMemoDirty()
        tracker.clearInvoiceDirty()

        #expect(tracker.hasAnyDirty == false)
        #expect(tracker.isDirty == false)
    }

    @Test("markDirty sets memo flag")
    func markDirtySetsUnsavedMemo() {
        let tracker = DocumentDirtyTracker()
        #expect(tracker.hasUnsavedMemo == false)

        tracker.markDirty()

        #expect(tracker.hasUnsavedMemo == true)
        #expect(tracker.hasAnyDirty == true)
    }

    // MARK: - NavigationGuard Tests

    @Test("NavigationGuard starts clean")
    func navigationGuardStartsClean() {
        let guard_ = NavigationGuard()
        #expect(guard_.hasUnsavedChanges == false)
    }

    @Test("NavigationGuard clearDirty resets flag")
    func navigationGuardClearDirty() {
        let guard_ = NavigationGuard()
        guard_.hasUnsavedChanges = true
        guard_.clearDirty()
        #expect(guard_.hasUnsavedChanges == false)
    }

    // MARK: - StoneFormViewModel dirtyFingerprint Tests

    @Test("dirtyFingerprint changes when field changes")
    func dirtyFingerprintChangesOnFieldChange() {
        let vm = StoneFormViewModel(mode: .intake)
        let initial = vm.dirtyFingerprint

        vm.caratText = "1.5"
        #expect(vm.dirtyFingerprint != initial)
    }

    @Test("dirtyFingerprint changes for different fields")
    func dirtyFingerprintDifferentFields() {
        let vm1 = StoneFormViewModel(mode: .intake)
        let vm2 = StoneFormViewModel(mode: .intake)

        vm1.color = "D"
        vm2.clarity = "VS1"

        #expect(vm1.dirtyFingerprint != vm2.dirtyFingerprint)
    }
}
