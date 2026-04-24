import XCTest

/// Phase 3 — Workflow-level smoke tests.
///
/// These tests verify non-destructive, high-value navigation workflows:
/// opening memo/invoice list surfaces, reaching quick-entry/intake screens,
/// search-field focus behavior, and multi-route round-trips that exercise
/// sidebar + keyboard navigation without mutating data.
final class WorkflowSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-onboardingComplete", "YES"]
        app.launchArguments += ["-companyName", "UI Test Corp"]
        app.launchArguments += ["-seedDemoData", "NO"]
        app.launch()
    }

    override func tearDownWithError() throws {
        captureScreenshotOnFailure(app: app)
        app = nil
    }

    // MARK: - Helpers

    /// Navigate via keyboard shortcut and wait for the route title.
    private func navigateViaKeyboard(key: String, expectedTitle: String) {
        let routeTitle = app.staticTexts["route_title"]
        XCTAssertTrue(routeTitle.waitForExistence(timeout: 10),
                      "Route title should exist")
        app.typeKey(key, modifierFlags: .command)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedTitle),
            object: routeTitle
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "Route title should be '\(expectedTitle)' after ⌘\(key)")
    }

    /// Navigate via sidebar button click.
    private func navigateViaSidebar(identifier: String, expectedTitle: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 10),
                      "Sidebar button '\(identifier)' should exist")
        button.click()
        let routeTitle = app.staticTexts["route_title"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedTitle),
            object: routeTitle
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "Route title should be '\(expectedTitle)' after clicking \(identifier)")
    }

    /// Assert a descendant element with the given identifier exists.
    private func assertAnyExists(_ identifier: String, timeout: TimeInterval = 5) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "Element '\(identifier)' should exist (any type)")
    }

    // MARK: - Memo Surface

    func testMemoListSurfaceOpensViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_memos", expectedTitle: "Memos")
        assertAnyExists("MemoListView")
    }

    func testMemoListSurfaceOpensViaKeyboard() throws {
        navigateViaKeyboard(key: "2", expectedTitle: "Memos")
        assertAnyExists("MemoListView")
    }

    func testMemoListHasNewMemoButton() throws {
        navigateViaKeyboard(key: "2", expectedTitle: "Memos")
        let newMemoButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'New Memo'")
        ).firstMatch
        XCTAssertTrue(newMemoButton.waitForExistence(timeout: 5),
                      "Memo list should have a 'New Memo' button")
    }

    func testMemoListHasSearchField() throws {
        navigateViaKeyboard(key: "2", expectedTitle: "Memos")
        assertAnyExists("MemoListView")
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Memo list should have a search field")
    }

    // MARK: - Invoice Surface

    func testInvoiceListSurfaceOpensViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_invoices", expectedTitle: "Invoices")
        assertAnyExists("InvoiceListView")
    }

    func testInvoiceListSurfaceOpensViaKeyboard() throws {
        navigateViaKeyboard(key: "3", expectedTitle: "Invoices")
        assertAnyExists("InvoiceListView")
    }

    func testInvoiceListHasNewInvoiceButton() throws {
        navigateViaKeyboard(key: "3", expectedTitle: "Invoices")
        let newInvoiceButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'New Invoice'")
        ).firstMatch
        XCTAssertTrue(newInvoiceButton.waitForExistence(timeout: 5),
                      "Invoice list should have a 'New Invoice' button")
    }

    func testInvoiceListHasSearchField() throws {
        navigateViaKeyboard(key: "3", expectedTitle: "Invoices")
        assertAnyExists("InvoiceListView")
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Invoice list should have a search field")
    }

    // MARK: - Quick Intake

    func testQuickIntakeOpensViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_quick_intake", expectedTitle: "Quick Intake")
        assertAnyExists("QuickIntakeView")
    }

    func testQuickIntakeOpensViaKeyboard() throws {
        // Quick Intake is ⌘9
        navigateViaKeyboard(key: "9", expectedTitle: "Quick Intake")
        assertAnyExists("QuickIntakeView")
    }

    // MARK: - Quick Entry

    func testQuickEntryOpensViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_quick_entry", expectedTitle: "Quick Entry")
        assertAnyExists("QuickEntryView")
    }

    func testQuickEntryHasCategoryPicker() throws {
        navigateViaSidebar(identifier: "sidebar_quick_entry", expectedTitle: "Quick Entry")
        assertAnyExists("QuickEntryView")
        // The category picker should have an accessibility label
        let categoryPicker = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'Stone Type Category'")
        ).firstMatch
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 5),
                      "Quick Entry should have a stone type category picker")
    }

    // MARK: - Lots & Sold Inventory

    func testLotsScreenRendersViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_lots", expectedTitle: "Lots")
        assertAnyExists("LotInventoryView")
    }

    func testLotsScreenRendersViaKeyboard() throws {
        navigateViaKeyboard(key: "7", expectedTitle: "Lots")
        assertAnyExists("LotInventoryView")
    }

    func testSoldScreenRendersViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_sold", expectedTitle: "Sold")
        assertAnyExists("SoldInventoryView")
    }

    func testSoldScreenRendersViaKeyboard() throws {
        navigateViaKeyboard(key: "8", expectedTitle: "Sold")
        assertAnyExists("SoldInventoryView")
    }

    func testSoldScreenHasSearchField() throws {
        navigateViaKeyboard(key: "8", expectedTitle: "Sold")
        assertAnyExists("SoldInventoryView")
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Sold screen should have a search field")
    }

    // MARK: - Review Queue

    func testReviewQueueRendersViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_review_queue", expectedTitle: "Review Queue")
        assertAnyExists("ReviewQueueView")
    }

    func testReviewQueueHasSearchField() throws {
        navigateViaSidebar(identifier: "sidebar_review_queue", expectedTitle: "Review Queue")
        assertAnyExists("ReviewQueueView")
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Review Queue should have a search field")
    }

    // MARK: - Accounting & AR

    func testAccountingScreenRendersViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_accounting", expectedTitle: "Accounting")
        assertAnyExists("AccountingView")
    }

    func testARScreenRendersViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_ar", expectedTitle: "AR")
        assertAnyExists("ARDashboardView")
    }

    // MARK: - Memo Return & Reconcile

    func testMemoReturnRendersViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_memo_return", expectedTitle: "Memo Return")
        assertAnyExists("MemoReturnScanView")
    }

    func testReconcileRendersViaSidebar() throws {
        navigateViaSidebar(identifier: "sidebar_reconcile", expectedTitle: "Reconcile")
        assertAnyExists("ReconcileView")
    }

    // MARK: - Search / Focus Behavior

    func testDiamondsSearchFieldAcceptsInput() throws {
        navigateViaKeyboard(key: "5", expectedTitle: "Diamonds")
        assertAnyExists("DiamondsInventoryView")
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Diamonds search field should exist")
        searchField.click()
        searchField.typeText("test")
        // Verify the field accepted input (value should contain typed text)
        let typed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS 'test'"),
            object: searchField
        )
        let result = XCTWaiter.wait(for: [typed], timeout: 3)
        XCTAssertEqual(result, .completed,
                       "Search field should contain typed text")
    }

    func testGemstonesSearchFieldAcceptsInput() throws {
        navigateViaKeyboard(key: "6", expectedTitle: "Gemstones")
        assertAnyExists("GemstonesInventoryView")
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Gemstones search field should exist")
        searchField.click()
        searchField.typeText("ruby")
        let typed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS 'ruby'"),
            object: searchField
        )
        let result = XCTWaiter.wait(for: [typed], timeout: 3)
        XCTAssertEqual(result, .completed,
                       "Search field should contain typed text")
    }

    // MARK: - Route Round-Trip Stability

    func testWorkflowRoundTripMemoToInvoiceAndBack() throws {
        // Memo → Invoice → Memo → Dashboard
        navigateViaKeyboard(key: "2", expectedTitle: "Memos")
        assertAnyExists("MemoListView")
        navigateViaKeyboard(key: "3", expectedTitle: "Invoices")
        assertAnyExists("InvoiceListView")
        navigateViaKeyboard(key: "2", expectedTitle: "Memos")
        assertAnyExists("MemoListView")
        navigateViaKeyboard(key: "1", expectedTitle: "Dashboard")
        assertAnyExists("DashboardView")
    }

    func testWorkflowRoundTripInventoryScreens() throws {
        // Diamonds → Gemstones → Lots → Sold → Dashboard
        let screens: [(key: String, title: String, identifier: String)] = [
            ("5", "Diamonds", "DiamondsInventoryView"),
            ("6", "Gemstones", "GemstonesInventoryView"),
            ("7", "Lots", "LotInventoryView"),
            ("8", "Sold", "SoldInventoryView"),
            ("1", "Dashboard", "DashboardView"),
        ]
        for screen in screens {
            navigateViaKeyboard(key: screen.key, expectedTitle: screen.title)
            assertAnyExists(screen.identifier)
        }
    }

    func testWorkflowRoundTripSidebarOnlyScreens() throws {
        // Navigate screens that only have sidebar (no keyboard shortcut)
        let sidebarScreens: [(id: String, title: String, view: String)] = [
            ("sidebar_quick_entry", "Quick Entry", "QuickEntryView"),
            ("sidebar_review_queue", "Review Queue", "ReviewQueueView"),
            ("sidebar_accounting", "Accounting", "AccountingView"),
            ("sidebar_ar", "AR", "ARDashboardView"),
            ("sidebar_memo_return", "Memo Return", "MemoReturnScanView"),
            ("sidebar_reconcile", "Reconcile", "ReconcileView"),
        ]
        for screen in sidebarScreens {
            navigateViaSidebar(identifier: screen.id, expectedTitle: screen.title)
            assertAnyExists(screen.view)
        }
        // Return to Dashboard to confirm shell is stable
        navigateViaKeyboard(key: "1", expectedTitle: "Dashboard")
        assertAnyExists("DashboardView")
    }

    func testFullNavigationRoundTripPreservesShellStability() throws {
        // Comprehensive round trip: keyboard screens + sidebar screens + back to start
        // Keyboard-navigable screens
        navigateViaKeyboard(key: "2", expectedTitle: "Memos")
        navigateViaKeyboard(key: "3", expectedTitle: "Invoices")
        navigateViaKeyboard(key: "4", expectedTitle: "Customers")
        navigateViaKeyboard(key: "5", expectedTitle: "Diamonds")
        navigateViaKeyboard(key: "6", expectedTitle: "Gemstones")
        navigateViaKeyboard(key: "7", expectedTitle: "Lots")
        navigateViaKeyboard(key: "8", expectedTitle: "Sold")
        navigateViaKeyboard(key: "9", expectedTitle: "Quick Intake")
        navigateViaKeyboard(key: "0", expectedTitle: "Scanner")

        // Sidebar-only screens
        navigateViaSidebar(identifier: "sidebar_quick_entry", expectedTitle: "Quick Entry")
        navigateViaSidebar(identifier: "sidebar_review_queue", expectedTitle: "Review Queue")
        navigateViaSidebar(identifier: "sidebar_accounting", expectedTitle: "Accounting")
        navigateViaSidebar(identifier: "sidebar_ar", expectedTitle: "AR")
        navigateViaSidebar(identifier: "sidebar_memo_return", expectedTitle: "Memo Return")
        navigateViaSidebar(identifier: "sidebar_reconcile", expectedTitle: "Reconcile")
        navigateViaSidebar(identifier: "sidebar_reports", expectedTitle: "Reports")

        // Return to Dashboard — shell chrome should be intact
        navigateViaKeyboard(key: "1", expectedTitle: "Dashboard")
        assertAnyExists("DashboardView")

        // Verify shell chrome survived the full round trip
        let shell = app.otherElements["AppShellView"]
        XCTAssertTrue(shell.exists, "AppShellView should still exist after full round trip")
        let sidebar = app.otherElements["SidebarView"]
        XCTAssertTrue(sidebar.exists, "SidebarView should still exist after full round trip")
        let content = app.otherElements["ContentArea"]
        XCTAssertTrue(content.exists, "ContentArea should still exist after full round trip")
    }
}
