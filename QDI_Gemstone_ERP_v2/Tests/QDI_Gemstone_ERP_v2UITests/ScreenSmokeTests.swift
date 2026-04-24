import XCTest

/// Phase 2 — Screen-level smoke tests.
///
/// After navigating to each top-level screen, verify that the screen's
/// root view and key landmark elements exist. This catches regressions
/// where a screen fails to render after a navigation change.
///
/// These tests build on the Phase 1 shell harness and reuse the same
/// onboarding-bypass launch arguments.
final class ScreenSmokeTests: XCTestCase {

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
        app = nil
    }

    // MARK: - Helpers

    /// Navigate to a route via keyboard shortcut and wait for the route title.
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

    /// Navigate to a route via sidebar button click.
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

    /// Assert an element with the given identifier exists within a timeout.
    private func assertExists(_ identifier: String, type: XCUIElement.ElementType = .other, timeout: TimeInterval = 5) {
        let query: XCUIElementQuery
        switch type {
        case .staticText:
            query = app.staticTexts
        case .button:
            query = app.buttons
        default:
            query = app.otherElements
        }
        let element = query[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "Element '\(identifier)' should exist")
    }

    /// Check that any element matching the identifier exists (searches all element types).
    private func assertAnyExists(_ identifier: String, timeout: TimeInterval = 5) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "Element '\(identifier)' should exist (any type)")
    }

    // MARK: - Dashboard Screen

    func testDashboardScreenRendersOnLaunch() throws {
        // Dashboard is the default route — no navigation needed
        assertAnyExists("DashboardView")
    }

    func testDashboardKPICardsExist() throws {
        assertAnyExists("DashboardView")
        assertAnyExists("KPICardRow")
    }

    func testDashboardGettingStartedChecklistExists() throws {
        assertAnyExists("DashboardView")
        assertAnyExists("GettingStartedChecklist")
    }

    // MARK: - Diamonds Screen

    func testDiamondsScreenRendersAfterNavigation() throws {
        navigateViaKeyboard(key: "5", expectedTitle: "Diamonds")
        assertAnyExists("DiamondsInventoryView")
    }

    func testDiamondsScreenHasSearchField() throws {
        navigateViaKeyboard(key: "5", expectedTitle: "Diamonds")
        assertAnyExists("DiamondsInventoryView")
        // The search field should be present in the filter bar
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Diamonds screen should have a search field")
    }

    // MARK: - Gemstones Screen

    func testGemstonesScreenRendersAfterNavigation() throws {
        navigateViaKeyboard(key: "6", expectedTitle: "Gemstones")
        assertAnyExists("GemstonesInventoryView")
    }

    func testGemstonesScreenHasSearchField() throws {
        navigateViaKeyboard(key: "6", expectedTitle: "Gemstones")
        assertAnyExists("GemstonesInventoryView")
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "Gemstones screen should have a search field")
    }

    // MARK: - Memos Screen

    func testMemosScreenRendersAfterNavigation() throws {
        navigateViaKeyboard(key: "2", expectedTitle: "Memos")
        assertAnyExists("MemoListView")
    }

    func testMemosScreenHasNewMemoButton() throws {
        navigateViaKeyboard(key: "2", expectedTitle: "Memos")
        assertAnyExists("MemoListView")
        let newMemoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'New Memo'")).firstMatch
        XCTAssertTrue(newMemoButton.waitForExistence(timeout: 5),
                      "Memos screen should have a 'New Memo' button")
    }

    // MARK: - Invoices Screen

    func testInvoicesScreenRendersAfterNavigation() throws {
        navigateViaKeyboard(key: "3", expectedTitle: "Invoices")
        assertAnyExists("InvoiceListView")
    }

    func testInvoicesScreenHasNewInvoiceButton() throws {
        navigateViaKeyboard(key: "3", expectedTitle: "Invoices")
        assertAnyExists("InvoiceListView")
        let newInvoiceButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'New Invoice'")).firstMatch
        XCTAssertTrue(newInvoiceButton.waitForExistence(timeout: 5),
                      "Invoices screen should have a 'New Invoice' button")
    }

    // MARK: - Customers Screen

    func testCustomersScreenRendersAfterNavigation() throws {
        navigateViaKeyboard(key: "4", expectedTitle: "Customers")
        assertAnyExists("CustomerListView")
    }

    func testCustomersScreenHasAddButton() throws {
        navigateViaKeyboard(key: "4", expectedTitle: "Customers")
        assertAnyExists("CustomerListView")
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add Customer'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                      "Customers screen should have an 'Add Customer' button")
    }

    // MARK: - Reports Screen

    func testReportsScreenRendersAfterNavigation() throws {
        navigateViaSidebar(identifier: "sidebar_reports", expectedTitle: "Reports")
        assertAnyExists("ReportsView")
    }

    func testReportsScreenHasReportTypePills() throws {
        navigateViaSidebar(identifier: "sidebar_reports", expectedTitle: "Reports")
        assertAnyExists("ReportsView")
        // Check that the default "Profit & Loss" report pill is present
        let plPill = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Profit'")).firstMatch
        XCTAssertTrue(plPill.waitForExistence(timeout: 5),
                      "Reports screen should have Profit & Loss pill")
    }

    // MARK: - Scanner Screen (safe read-only check)

    func testScannerScreenRendersAfterNavigation() throws {
        // Scanner uses Cmd+0
        navigateViaKeyboard(key: "0", expectedTitle: "Scanner")
        assertAnyExists("ScannerView")
    }

    func testScannerScreenHasStartButton() throws {
        navigateViaKeyboard(key: "0", expectedTitle: "Scanner")
        assertAnyExists("ScannerView")
        // Check for the Start Scanning button (do NOT click it — hardware safety)
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start RFID Scanning'")).firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5),
                      "Scanner screen should have a Start Scanning button")
    }

    // MARK: - Cross-Screen Round Trip

    func testNavigateAllScreensSequentially() throws {
        // Visit each screen and verify its root view renders
        let screens: [(key: String, title: String, identifier: String)] = [
            ("5", "Diamonds", "DiamondsInventoryView"),
            ("6", "Gemstones", "GemstonesInventoryView"),
            ("2", "Memos", "MemoListView"),
            ("3", "Invoices", "InvoiceListView"),
            ("4", "Customers", "CustomerListView"),
            ("1", "Dashboard", "DashboardView"),
        ]

        for screen in screens {
            navigateViaKeyboard(key: screen.key, expectedTitle: screen.title)
            assertAnyExists(screen.identifier)
        }
    }
}
