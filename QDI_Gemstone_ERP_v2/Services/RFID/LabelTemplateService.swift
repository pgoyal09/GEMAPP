import Foundation
import Network

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

/// Generates ZPL (Zebra Programming Language) for jewelry labels.
/// Paper size: 2" x 1" (standard jewelry label).
/// Printer target: Zebra ZD611R.
enum LabelTemplateService {

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

    static func printLabel(zpl: String, host: String, port: UInt16) async throws {
        let host = host.isEmpty ? "localhost" : host
        guard let data = zpl.data(using: .utf8) else {
            throw LabelPrintError.invalidData
        }

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
                            continuation.resume(throwing: error)
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

    enum LabelPrintError: LocalizedError {
        case invalidData
        case timeout

        var errorDescription: String? {
            switch self {
            case .invalidData: return "Invalid label data"
            case .timeout: return "Printer connection timed out"
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
