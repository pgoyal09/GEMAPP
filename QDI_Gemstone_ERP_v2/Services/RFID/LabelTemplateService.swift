import Foundation
import Network
import os

private let logger = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "label-printer")

/// Label template types for Zebra ZD611R thermal printer.
enum LabelTemplate: String, CaseIterable {
    case standard = "Standard"
    case rapaport = "Rapaport"
    case minimal = "Minimal"

    var description: String {
        switch self {
        case .standard: return "SKU, specs, price, cert, barcode"
        case .rapaport: return "Industry-standard Rapaport format"
        case .minimal: return "SKU, carat weight, price only"
        }
    }
}

/// Zebra ZD611R printer status parsed from `~HS` host status response.
struct PrinterStatus: Sendable, Equatable {
    let paperOut: Bool
    let ribbonOut: Bool
    let headOpen: Bool
    let paused: Bool
    let bufferFull: Bool
    let isReady: Bool

    /// Human-readable description of any active faults.
    var faultDescription: String? {
        var faults: [String] = []
        if paperOut { faults.append("Paper out — load a new label roll") }
        if ribbonOut { faults.append("Ribbon out — replace the ribbon cartridge") }
        if headOpen { faults.append("Print head open — close the printer lid") }
        if paused { faults.append("Printer is paused — press the feed button to resume") }
        if bufferFull { faults.append("Print buffer full — wait and retry") }
        return faults.isEmpty ? nil : faults.joined(separator: "; ")
    }

    /// Parse Zebra SGD/Host Status response (`~HS`).
    /// Format: Three lines starting with STX (0x02), containing comma-separated status fields.
    /// Line 1 fields: comm diagnostics, paper-out, pause, label-length, formats-in-buffer, buffer-full, ...
    /// Line 2 fields: function-settings, head-up, ribbon-out, ...
    static func parse(from data: Data) -> PrinterStatus? {
        guard let raw = String(data: data, encoding: .ascii) else { return nil }
        // Strip STX/ETX control characters and split into lines
        let cleaned = raw.replacingOccurrences(of: "\u{02}", with: "")
            .replacingOccurrences(of: "\u{03}", with: "")
        let lines = cleaned.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let fields1 = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let fields2 = lines[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // Line 1: index 1 = paper-out, index 2 = pause, index 5 = buffer-full
        let paperOut = fields1.count > 1 && fields1[1] == "1"
        let paused = fields1.count > 2 && fields1[2] == "1"
        let bufferFull = fields1.count > 5 && fields1[5] == "1"

        // Line 2: index 1 = head-open, index 2 = ribbon-out
        let headOpen = fields2.count > 1 && fields2[1] == "1"
        let ribbonOut = fields2.count > 2 && fields2[2] == "1"

        let isReady = !paperOut && !ribbonOut && !headOpen && !paused && !bufferFull

        return PrinterStatus(
            paperOut: paperOut,
            ribbonOut: ribbonOut,
            headOpen: headOpen,
            paused: paused,
            bufferFull: bufferFull,
            isReady: isReady
        )
    }
}

/// Generates ZPL (Zebra Programming Language) for jewelry labels.
/// Paper size: 2" x 1" (standard jewelry label).
/// Printer target: Zebra ZD611R.
enum LabelTemplateService: LabelPrintServiceProtocol {

    /// ZPL header for 2x1 inch label at 203 DPI (print width 406 dots, height 203 dots).
    private static let header = "^XA^PW406^LL203^FO0,0^GB406,203,1^FS"
    private static let footer = "^XZ"

    // MARK: - Generate ZPL

    static func generateZPL(for stone: Gemstone, template: LabelTemplate) -> String {
        switch template {
        case .standard: return standardZPL(stone)
        case .rapaport: return rapaportZPL(stone)
        case .minimal: return minimalZPL(stone)
        }
    }

    // MARK: - Standard Template

    private static func standardZPL(_ s: Gemstone) -> String {
        let specs = [
            s.stoneType.rawValue.capitalized,
            s.shape,
            String(format: "%.2f ct", s.caratWeight),
            s.color,
            s.clarity
        ].filter { !$0.isEmpty }.joined(separator: " | ")

        let price = "$\(s.sellPrice)"
        let cert = s.hasCert ? "\(s.certLab) \(s.certNo)" : ""

        return """
        \(header)
        ^FO10,10^A0N,28,28^FD\(s.sku)^FS
        ^FO10,45^A0N,18,18^FD\(specs)^FS
        ^FO10,70^A0N,22,22^FD\(price)^FS
        ^FO10,100^A0N,16,16^FD\(cert)^FS
        ^FO10,130^BY2^BCN,50,N,N,N^FD\(s.sku)^FS
        \(footer)
        """
    }

    // MARK: - Rapaport Template

    private static func rapaportZPL(_ s: Gemstone) -> String {
        let line1 = "\(s.stoneType.rawValue.uppercased()) \(s.shape)"
        let line2 = "\(String(format: "%.2f", s.caratWeight))ct \(s.color) \(s.clarity) \(s.cut)"
        let line3 = s.hasCert ? "\(s.certLab) #\(s.certNo)" : ""
        let line4 = s.rapNetPrice != nil ? "Rap: $\(s.rapNetPrice!)/ct" : "$\(s.sellPrice)"

        return """
        \(header)
        ^FO10,8^A0N,22,22^FD\(s.sku)^FS
        ^FO10,35^A0N,20,20^FD\(line1)^FS
        ^FO10,58^A0N,20,20^FD\(line2)^FS
        ^FO10,80^A0N,16,16^FD\(line3)^FS
        ^FO10,100^A0N,20,20^FD\(line4)^FS
        ^FO10,128^BY2^BCN,50,N,N,N^FD\(s.sku)^FS
        \(footer)
        """
    }

    // MARK: - Minimal Template

    private static func minimalZPL(_ s: Gemstone) -> String {
        return """
        \(header)
        ^FO10,15^A0N,36,36^FD\(s.sku)^FS
        ^FO10,60^A0N,28,28^FD\(String(format: "%.2f ct", s.caratWeight))^FS
        ^FO10,95^A0N,32,32^FD$\(s.sellPrice)^FS
        ^FO10,140^BY2^BCN,40,N,N,N^FD\(s.sku)^FS
        \(footer)
        """
    }

    // MARK: - Preview (text representation for settings)

    static func previewText(for stone: Gemstone, template: LabelTemplate) -> String {
        switch template {
        case .standard:
            return """
            ┌──────────────────────────┐
            │ \(s: stone.sku, w: 24) │
            │ \(s: "\(stone.stoneType.rawValue.capitalized) \(stone.shape) \(String(format: "%.2f", stone.caratWeight))ct", w: 24) │
            │ \(s: "\(stone.color) \(stone.clarity) $\(stone.sellPrice)", w: 24) │
            │ \(s: stone.hasCert ? "\(stone.certLab) \(stone.certNo)" : "", w: 24) │
            │ ▮▮▮▮▮▮▮▮▮▮▮▮              │
            └──────────────────────────┘
            """
        case .rapaport:
            return """
            ┌──────────────────────────┐
            │ \(s: stone.sku, w: 24) │
            │ \(s: "\(stone.stoneType.rawValue.uppercased()) \(stone.shape)", w: 24) │
            │ \(s: "\(String(format: "%.2f", stone.caratWeight))ct \(stone.color) \(stone.clarity)", w: 24) │
            │ \(s: stone.hasCert ? "\(stone.certLab) #\(stone.certNo)" : "", w: 24) │
            │ \(s: "$\(stone.sellPrice)", w: 24) │
            │ ▮▮▮▮▮▮▮▮▮▮▮▮              │
            └──────────────────────────┘
            """
        case .minimal:
            return """
            ┌──────────────────────────┐
            │ \(s: stone.sku, w: 24) │
            │ \(s: "\(String(format: "%.2f ct", stone.caratWeight))", w: 24) │
            │ \(s: "$\(stone.sellPrice)", w: 24) │
            │ ▮▮▮▮▮▮▮▮▮▮▮▮              │
            └──────────────────────────┘
            """
        }
    }

    // MARK: - Send to Printer

    /// Send ZPL data to the printer, with pre-flight status check.
    /// Queries the Zebra printer for host status (`~HS`) before printing.
    /// Throws `LabelPrintError` with specific fault details if the printer reports an issue.
    static func printLabel(zpl: String, host: String, port: UInt16, retryOnRecoverable: Bool = true) async throws {
        let resolvedHost = host.isEmpty ? "localhost" : host
        guard let data = zpl.data(using: .utf8) else {
            throw LabelPrintError.invalidData
        }

        // Pre-flight: query printer status
        let status = try await queryPrinterStatus(host: resolvedHost, port: port)
        if let status, !status.isReady {
            logger.warning("Printer not ready: \(status.faultDescription ?? "unknown fault", privacy: .public)")
            throw LabelPrintError.printerFault(status)
        }

        // Send ZPL
        try await sendData(data, host: resolvedHost, port: port)

        // Post-print: verify printer didn't encounter an error during printing
        // Wait briefly for the printer to process the label
        try await Task.sleep(for: .milliseconds(500))
        let postStatus = try? await queryPrinterStatus(host: resolvedHost, port: port)
        if let postStatus, !postStatus.isReady {
            // Printer faulted during print — the label may be partially printed
            logger.error("Printer faulted after send: \(postStatus.faultDescription ?? "unknown", privacy: .public)")
            throw LabelPrintError.printFailedMidJob(postStatus)
        }

        logger.info("Label sent to printer at \(resolvedHost, privacy: .public):\(port)")
    }

    /// Query Zebra printer host status by sending `~HS` and reading the response.
    /// Returns `nil` if the printer doesn't respond with a parseable status (non-Zebra or incompatible firmware).
    static func queryPrinterStatus(host: String, port: UInt16) async throws -> PrinterStatus? {
        let command = "~HS"
        guard let data = command.data(using: .utf8) else { return nil }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PrinterStatus?, Error>) in
                nonisolated(unsafe) var didResume = false
                let queue = DispatchQueue(label: "com.qdi.labelprint.status")

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        // Send ~HS status query
                        connection.send(content: data, completion: .contentProcessed { error in
                            if let error {
                                connection.cancel()
                                queue.async {
                                    guard !didResume else { return }
                                    didResume = true
                                    continuation.resume(throwing: error)
                                }
                                return
                            }
                            // Read response (Zebra status is typically < 256 bytes)
                            connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { content, _, _, recvError in
                                connection.cancel()
                                queue.async {
                                    guard !didResume else { return }
                                    didResume = true
                                    if let recvError {
                                        // Connection error reading status — printer may not support ~HS
                                        logger.debug("Status read error (may be non-Zebra printer): \(recvError.localizedDescription, privacy: .public)")
                                        continuation.resume(returning: nil)
                                    } else if let content {
                                        continuation.resume(returning: PrinterStatus.parse(from: content))
                                    } else {
                                        continuation.resume(returning: nil)
                                    }
                                }
                            }
                        })
                    case .failed(let error):
                        connection.cancel()
                        queue.async {
                            guard !didResume else { return }
                            didResume = true
                            continuation.resume(throwing: LabelPrintError.connectionFailed(error.localizedDescription))
                        }
                    case .cancelled:
                        queue.async {
                            guard !didResume else { return }
                            didResume = true
                            continuation.resume(throwing: LabelPrintError.timeout)
                        }
                    default:
                        break
                    }
                }
                connection.start(queue: queue)

                // Timeout for status query (3 seconds)
                queue.asyncAfter(deadline: .now() + 3) {
                    guard !didResume else { return }
                    connection.cancel()
                }
            }
        } onCancel: {
            connection.cancel()
        }
    }

    /// Low-level: send raw data to the printer over TCP.
    private static func sendData(_ data: Data, host: String, port: UInt16) async throws {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                nonisolated(unsafe) var didResume = false
                let queue = DispatchQueue(label: "com.qdi.labelprint")

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        connection.send(content: data, completion: .contentProcessed { error in
                            connection.cancel()
                            queue.async {
                                guard !didResume else { return }
                                didResume = true
                                if let error {
                                    continuation.resume(throwing: error)
                                } else {
                                    continuation.resume()
                                }
                            }
                        })
                    case .failed(let error):
                        connection.cancel()
                        queue.async {
                            guard !didResume else { return }
                            didResume = true
                            continuation.resume(throwing: LabelPrintError.connectionFailed(error.localizedDescription))
                        }
                    case .cancelled:
                        queue.async {
                            guard !didResume else { return }
                            didResume = true
                            continuation.resume(throwing: LabelPrintError.timeout)
                        }
                    default:
                        break
                    }
                }
                connection.start(queue: queue)

                // Timeout
                queue.asyncAfter(deadline: .now() + 5) {
                    guard !didResume else { return }
                    connection.cancel()
                }
            }
        } onCancel: {
            connection.cancel()
        }
    }

    /// Errors specific to label printing operations.
    enum LabelPrintError: LocalizedError {
        case invalidData
        case timeout
        case connectionFailed(String)
        case printerFault(PrinterStatus)
        case printFailedMidJob(PrinterStatus)

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "Invalid label data"
            case .timeout:
                return "Printer connection timed out — check that the printer is powered on and connected"
            case .connectionFailed(let detail):
                return "Cannot connect to printer: \(detail)"
            case .printerFault(let status):
                return "Printer not ready: \(status.faultDescription ?? "unknown error")"
            case .printFailedMidJob(let status):
                return "Print may have failed: \(status.faultDescription ?? "unknown error"). Check the label output."
            }
        }

        /// Whether the error is potentially recoverable by user action (e.g., closing the lid, loading paper).
        var isUserRecoverable: Bool {
            switch self {
            case .printerFault(let s):
                return s.paperOut || s.ribbonOut || s.headOpen || s.paused
            case .printFailedMidJob(let s):
                return s.paperOut || s.ribbonOut || s.headOpen
            default:
                return false
            }
        }
    }
}

// MARK: - String Padding Helper

private extension DefaultStringInterpolation {
    mutating func appendInterpolation(s value: String, w width: Int) {
        let padded = value.count >= width ? String(value.prefix(width)) : value + String(repeating: " ", count: width - value.count)
        appendLiteral(padded)
    }
}
