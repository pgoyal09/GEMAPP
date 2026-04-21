import Foundation

/// Protocol abstracting label printing operations for testability.
/// Allows mocking the printer connection in unit tests.
protocol LabelPrintServiceProtocol {
    /// Send ZPL data to the printer with pre-flight status check.
    static func printLabel(zpl: String, host: String, port: UInt16, retryOnRecoverable: Bool) async throws

    /// Query the printer for its current status.
    static func queryPrinterStatus(host: String, port: UInt16) async throws -> PrinterStatus?
}
