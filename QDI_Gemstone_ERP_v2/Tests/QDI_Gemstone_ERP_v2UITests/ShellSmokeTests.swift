import XCTest

/// Phase 1 — Shell / keyboard-navigation smoke tests.
///
/// These tests verify the app launches, the shell chrome is present,
/// and sidebar + keyboard shortcuts drive route changes correctly.
///
/// The tests bypass onboarding by writing the same `@AppStorage` keys
/// the app checks (`onboardingComplete`, `companyName`) into the
/// app's UserDefaults via launch arguments.
final class ShellSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Bypass onboarding gate
        app.launchArguments += ["-onboardingComplete", "YES"]
        app.launchArguments += ["-companyName", "UI Test Corp"]
        // Disable demo data seeding to avoid side effects
        app.launchArguments += ["-seedDemoData", "NO"]
        app.launch()
    }

    override func tearDownWithError() throws {
        captureScreenshotOnFailure(app: app)
        app = nil
    }

    // MARK: - Launch & Shell Existence

    func testAppLaunchesAndShellExists() throws {
        let shell = app.otherElements["AppShellView"]
        XCTAssertTrue(shell.waitForExistence(timeout: 10),
                      "AppShellView should exist after launch")
    }

    func testSidebarVisibleOnLaunch() throws {
        let sidebar = app.otherElements["SidebarView"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10),
                      "Sidebar should be visible on launch")
    }

    func testDefaultRouteIsDashboard() throws {
        let routeTitle = app.staticTexts["route_title"]
        XCTAssertTrue(routeTitle.waitForExistence(timeout: 10),
                      "Route title label should exist")
        XCTAssertEqual(routeTitle.label, "Dashboard",
                       "Default route should be Dashboard")
    }

    // MARK: - Sidebar Navigation

    func testSidebarNavigatesToMemos() throws {
        let memosButton = app.buttons["sidebar_memos"]
        XCTAssertTrue(memosButton.waitForExistence(timeout: 10),
                      "Sidebar Memos button should exist")
        memosButton.click()

        let routeTitle = app.staticTexts["route_title"]
        XCTAssertTrue(routeTitle.waitForExistence(timeout: 5))
        // Allow a moment for the route change animation
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Memos'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    func testSidebarNavigatesToInvoices() throws {
        let invoicesButton = app.buttons["sidebar_invoices"]
        XCTAssertTrue(invoicesButton.waitForExistence(timeout: 10))
        invoicesButton.click()

        let routeTitle = app.staticTexts["route_title"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Invoices'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    func testSidebarNavigatesToCustomers() throws {
        let customersButton = app.buttons["sidebar_customers"]
        XCTAssertTrue(customersButton.waitForExistence(timeout: 10))
        customersButton.click()

        let routeTitle = app.staticTexts["route_title"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Customers'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    func testSidebarNavigatesToDiamonds() throws {
        let diamondsButton = app.buttons["sidebar_diamonds"]
        XCTAssertTrue(diamondsButton.waitForExistence(timeout: 10))
        diamondsButton.click()

        let routeTitle = app.staticTexts["route_title"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Diamonds'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    func testSidebarNavigatesToReports() throws {
        let reportsButton = app.buttons["sidebar_reports"]
        XCTAssertTrue(reportsButton.waitForExistence(timeout: 10))
        reportsButton.click()

        let routeTitle = app.staticTexts["route_title"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Reports'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    func testSidebarNavigatesToSettings() throws {
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.click()

        let routeTitle = app.staticTexts["route_title"]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Settings'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    // MARK: - Keyboard Shortcut Navigation

    func testKeyboardShortcutCmd2NavigatesToMemos() throws {
        // Ensure we start from Dashboard
        let routeTitle = app.staticTexts["route_title"]
        XCTAssertTrue(routeTitle.waitForExistence(timeout: 10))

        app.typeKey("2", modifierFlags: .command)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Memos'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    func testKeyboardShortcutCmd5NavigatesToDiamonds() throws {
        let routeTitle = app.staticTexts["route_title"]
        XCTAssertTrue(routeTitle.waitForExistence(timeout: 10))

        app.typeKey("5", modifierFlags: .command)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Diamonds'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    func testKeyboardShortcutCmd6NavigatesToGemstones() throws {
        let routeTitle = app.staticTexts["route_title"]
        XCTAssertTrue(routeTitle.waitForExistence(timeout: 10))

        app.typeKey("6", modifierFlags: .command)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Gemstones'"),
            object: routeTitle
        )
        wait(for: [expectation], timeout: 3)
    }

    func testKeyboardShortcutCmd1ReturnsToDashboard() throws {
        let routeTitle = app.staticTexts["route_title"]
        XCTAssertTrue(routeTitle.waitForExistence(timeout: 10))

        // Navigate away first
        app.typeKey("3", modifierFlags: .command)
        let invoiceExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Invoices'"),
            object: routeTitle
        )
        wait(for: [invoiceExpectation], timeout: 3)

        // Now go back to Dashboard
        app.typeKey("1", modifierFlags: .command)
        let dashExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'Dashboard'"),
            object: routeTitle
        )
        wait(for: [dashExpectation], timeout: 3)
    }

    // MARK: - Content Area Existence

    func testContentAreaExistsOnLaunch() throws {
        let content = app.otherElements["ContentArea"]
        XCTAssertTrue(content.waitForExistence(timeout: 10),
                      "Content area should exist after launch")
    }

    // MARK: - Multi-Route Round Trip

    func testRoundTripNavigationViaKeyboard() throws {
        let routeTitle = app.staticTexts["route_title"]
        XCTAssertTrue(routeTitle.waitForExistence(timeout: 10))

        // Visit several routes in sequence via keyboard
        let routes: [(key: String, expected: String)] = [
            ("4", "Customers"),
            ("7", "Lots"),
            ("8", "Sold"),
            ("1", "Dashboard"),
        ]

        for route in routes {
            app.typeKey(route.key, modifierFlags: .command)
            let exp = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", route.expected),
                object: routeTitle
            )
            let result = XCTWaiter.wait(for: [exp], timeout: 3)
            XCTAssertEqual(result, .completed,
                           "Expected route title '\(route.expected)' after ⌘\(route.key)")
        }
    }
}
