import XCTest

/// Shared screenshot capture utilities for UI tests.
///
/// Usage:
/// 1. In `tearDownWithError()`, call `captureScreenshotOnFailure(name:)` to
///    automatically attach a screenshot when a test fails.
/// 2. Call `captureScreenshot(name:lifetime:)` at any point to take an
///    explicit evidence snapshot.
///
/// Screenshots are attached to the test's XCTActivity log and appear in
/// the Xcode Test Report (`.xcresult` bundle). To export:
///
///     xcrun xcresulttool get --path Build/Logs/Test/*.xcresult \
///         --format json
///
extension XCTestCase {

    // MARK: - Automatic Failure Capture

    /// Call from `tearDownWithError()` to attach a screenshot when the
    /// current test has recorded a failure.
    ///
    /// ```swift
    /// override func tearDownWithError() throws {
    ///     captureScreenshotOnFailure()
    ///     app = nil
    /// }
    /// ```
    func captureScreenshotOnFailure(
        name: String? = nil,
        app: XCUIApplication? = nil
    ) {
        // `testRun?.hasSucceeded` is false when any assertion has failed.
        guard let testRun = testRun, !testRun.hasSucceeded else { return }

        let label = name ?? "failure_\(self.name)"
        let screenshot = (app ?? XCUIApplication()).screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = label
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Explicit Evidence Capture

    /// Take a screenshot and attach it to the current test activity.
    ///
    /// - Parameters:
    ///   - name: Descriptive label for the attachment (appears in Xcode Test Report).
    ///   - lifetime: `.keepAlways` to persist in the `.xcresult`, or
    ///               `.deleteOnSuccess` to discard when tests pass.
    ///   - app: Optional explicit app reference; defaults to `XCUIApplication()`.
    func captureScreenshot(
        name: String,
        lifetime: XCTAttachment.Lifetime = .keepAlways,
        app: XCUIApplication? = nil
    ) {
        let screenshot = (app ?? XCUIApplication()).screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = lifetime
        add(attachment)
    }
}
