import Foundation
import SwiftUI
import Network
import CryptoKit
import SwiftData
import os

private let printLog = Logger(subsystem: "com.qdi.gemapp", category: "zebra.print")

// MARK: - Printer Status

enum PrinterStatus: String {
    case idle = "Idle"
    case connecting = "Connecting"
    case sending = "Sending"
    case success = "Success"
    case error = "Error"
}

enum PrintProfile: Int, CaseIterable, Identifiable {
    case profile1 = 1
    case profile2 = 2
    case profile3 = 3
    case profile4 = 4
    case profile5 = 5

    var id: Int { rawValue }
    var title: String { "Setting \(rawValue)" }
}

// MARK: - Print Error

enum ZebraPrintError: LocalizedError {
    case noPrinterIP
    case connectionFailed(String)
    case sendFailed(String)
    case timeout
    case epcGenerationFailed

    var errorDescription: String? {
        switch self {
        case .noPrinterIP: return "Printer IP address is not configured."
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .sendFailed(let msg): return "Send failed: \(msg)"
        case .timeout: return "Printer did not respond in time."
        case .epcGenerationFailed: return "Failed to generate EPC for this stone."
        }
    }
}

// MARK: - Zebra Print Service

@Observable
final class ZebraPrintService {
    var status: PrinterStatus = .idle
    var lastError: String?
    var printerIP: String {
        get { UserDefaults.standard.string(forKey: "ZebraPrinterIP") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "ZebraPrinterIP") }
    }
    var printProfile: PrintProfile {
        get { PrintProfile(rawValue: UserDefaults.standard.integer(forKey: "ZebraPrintProfile")) ?? .profile2 }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "ZebraPrintProfile") }
    }

    private let port: UInt16 = 9100
    private let timeoutSeconds: TimeInterval = 8

    // MARK: - Label dimensions (25.4mm × 13.9mm at 203 DPI)
    // 203 dots/inch × (25.4mm / 25.4mm/inch) = 203 dots wide
    // 203 dots/inch × (13.9mm / 25.4mm/inch) = 111 dots tall
    private let labelWidthDots = 203
    private let labelHeightDots = 111

    /// Candidate forward programming positions for Link-OS RFID printers (`^RS8,F{n}`).
    /// Small jewelry labels can have inlay position drift; trying nearby positions increases
    /// the chance the inlay crosses the RFID antenna sweet spot on each label.
    private let rfidProgramPositionsForwardMm = [5, 6, 7, 8]
    /// EPC payload length in bytes (24 hex chars => 12 bytes).
    private let rfidEpcBytes = 12

    // MARK: - Public API

    /// Print a label and encode the RFID tag for a gemstone. Registers the EPC in the database on success.
    func printAndEncode(stone: Gemstone, modelContext: ModelContext) async throws {
        guard !printerIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ZebraPrintError.noPrinterIP
        }

        guard let epc = generateEPC(for: stone) else {
            throw ZebraPrintError.epcGenerationFailed
        }

        let zpl = buildZPL(for: stone, epc: epc)
        printLog.info("ZPL payload for \(stone.sku, privacy: .public):\n\(zpl, privacy: .public)")

        await MainActor.run { status = .connecting; lastError = nil }

        try await sendZPL(zpl)

        await MainActor.run { status = .success }

        let result = await MainActor.run {
            RFIDScanService.assignTagToStone(
                epc: epc,
                tid: nil,
                stone: stone,
                replaceExisting: true,
                modelContext: modelContext
            )
        }

        switch result {
        case .assigned, .replaced:
            printLog.info("EPC \(epc, privacy: .public) registered to \(stone.sku, privacy: .public)")
        case .conflict(let msg):
            printLog.warning("Tag printed but DB registration conflict: \(msg, privacy: .public)")
        }
    }

    /// Quick connectivity check — sends a host status query and waits for any response.
    func checkConnection() async -> Bool {
        guard !printerIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        do {
            try await sendZPL("~HS")
            return true
        } catch {
            return false
        }
    }

    // MARK: - EPC Generation (Deterministic from SKU)

    func generateEPC(for stone: Gemstone) -> String? {
        let skuData = Data(stone.sku.utf8)
        let hash = SHA256.hash(data: skuData)
        let hashBytes = Array(hash)
        guard hashBytes.count >= 10 else { return nil }

        var epcBytes: [UInt8] = [0xE2, 0x80]
        epcBytes.append(contentsOf: hashBytes.prefix(10))
        let hex = epcBytes.map { String(format: "%02X", $0) }.joined()

        guard hex.count == 24 else { return nil }
        return hex
    }

    // MARK: - ZPL Builder

    func buildZPL(for stone: Gemstone, epc: String) -> String {
        let line1 = stone.sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "[NO SKU]" : stone.sku
        let line2 = buildLine2(for: stone)
        let line3 = buildLine3(for: stone)
        switch printProfile {
        case .profile1:
            return zplProfile1(line1: line1, line2: line2, line3: line3)
        case .profile2:
            return zplProfile2(line1: line1, line2: line2, line3: line3, epc: epc)
        case .profile3:
            return zplProfile3(line1: line1, line2: line2, line3: line3)
        case .profile4:
            return zplProfile4(line1: line1, line2: line2, line3: line3)
        case .profile5:
            return zplProfile5(line1: line1, line2: line2, line3: line3)
        }
    }

    // MARK: - Line Builders

    private func buildLine2(for stone: Gemstone) -> String {
        if stone.isLot {
            return buildLotLine2(for: stone)
        } else if stone.stoneType == .diamond {
            return buildDiamondLine2(for: stone)
        } else {
            return buildOtherLine2(for: stone)
        }
    }

    /// Diamond (single/pair): "{carats}ct {color} {clarity} {shape}"
    private func buildDiamondLine2(for stone: Gemstone) -> String {
        var parts: [String] = []
        parts.append(String(format: "%.2fct", stone.caratWeight))
        if !stone.color.isEmpty { parts.append(stone.color) }
        if !stone.clarity.isEmpty { parts.append(stone.clarity) }
        if let shape = stone.shape, !shape.isEmpty { parts.append(shape) }
        return parts.joined(separator: " ")
    }

    /// Lot: "{LxW}mm {quality} {carats}ct"
    private func buildLotLine2(for stone: Gemstone) -> String {
        var parts: [String] = []
        if let l = stone.length, let w = stone.width {
            parts.append(String(format: "%.1fx%.1fmm", l, w))
        } else if let l = stone.length {
            parts.append(String(format: "%.1fmm", l))
        } else if let w = stone.width {
            parts.append(String(format: "%.1fmm", w))
        }
        if let q = stone.quality, !q.isEmpty { parts.append(q) }
        parts.append(String(format: "%.2fct", stone.caratWeight))
        return parts.joined(separator: " ")
    }

    /// Other gemstones: "{carats}ct {treatment}"
    private func buildOtherLine2(for stone: Gemstone) -> String {
        var parts: [String] = []
        parts.append(String(format: "%.2fct", stone.caratWeight))
        if let t = stone.treatment, !t.isEmpty { parts.append(t) }
        return parts.joined(separator: " ")
    }

    /// Line 3: Cost code + sell price (cost code is placeholder for now)
    private func buildLine3(for stone: Gemstone) -> String {
        let costCode = "----"
        let sell = stone.sellPrice.asCurrency
        return "\(costCode)  \(sell)"
    }

    // MARK: - ZPL Print Profiles (text-only debug)

    // Profile 1: Baseline compact format, no media mode overrides.
    private func zplProfile1(line1: String, line2: String, line3: String) -> String {
        var zpl = "^XA\n"
        zpl += "^CI28\n"
        zpl += "^PW\(labelWidthDots)\n"
        zpl += "^LL\(labelHeightDots)\n"
        zpl += "^LH0,0\n"
        zpl += "^FO4,4^A0N,30,26^FD\(sanitize(line1))^FS\n"
        zpl += "^FO4,38^A0N,22,18^FD\(sanitize(line2))^FS\n"
        zpl += "^FO4,66^A0N,22,18^FD\(sanitize(line3))^FS\n"
        zpl += "^XZ\n"
        return zpl
    }

    // Profile 2: Slightly larger label length and conservative print speed/darkness.
    private func zplProfile2(line1: String, line2: String, line3: String, epc: String) -> String {
        var zpl = "^XA\n"
        zpl += "^CI28\n"
        zpl += "^PW\(labelWidthDots)\n"
        zpl += "^LL130\n"
        zpl += "^PR2,2\n"
        zpl += "^MD20\n"
        zpl += "^LH0,0\n"
        // RFID: try a small sweep of forward programming positions to tolerate stock variation.
        // At each position we attempt:
        // 1) explicit EPC bank write (bank 1, block 2, 12 bytes), then
        // 2) auto-PC write (bank A) as firmware-compatibility fallback.
        for mm in rfidProgramPositionsForwardMm {
            zpl += "^RS8,F\(mm)\n"
            zpl += "^RFW,H,2,\(rfidEpcBytes),1^FD\(epc)^FS\n"
            zpl += "^RFW,H,,,A^FD\(epc)^FS\n"
        }
        // Move line 1 down to avoid top non-printable margin on ZD611R.
        // Large shift down/right to clear top dead zone and use open space.
        zpl += "^FO22,46^A0N,24,20^FD\(sanitize(line1))^FS\n"
        zpl += "^FO22,76^A0N,20,16^FD\(sanitize(line2))^FS\n"
        zpl += "^FO22,102^A0N,20,16^FD\(sanitize(line3))^FS\n"
        zpl += "^XZ\n"
        return zpl
    }

    // Profile 3: Wide fallback canvas in case printer ignores small ^PW/^LL.
    private func zplProfile3(line1: String, line2: String, line3: String) -> String {
        var zpl = "^XA\n"
        zpl += "^CI28\n"
        zpl += "^PW406\n"
        zpl += "^LL240\n"
        zpl += "^LH0,0\n"
        zpl += "^FO20,20^A0N,44,34^FD\(sanitize(line1))^FS\n"
        zpl += "^FO20,86^A0N,28,22^FD\(sanitize(line2))^FS\n"
        zpl += "^FO20,126^A0N,28,22^FD\(sanitize(line3))^FS\n"
        zpl += "^XZ\n"
        return zpl
    }

    // Profile 4: Minimal fixed test text to validate visibility independent of data.
    private func zplProfile4(line1: String, line2: String, line3: String) -> String {
        var zpl = "^XA\n"
        zpl += "^CI28\n"
        zpl += "^PW406\n"
        zpl += "^LL240\n"
        zpl += "^PR2,2\n"
        zpl += "^MD24\n"
        zpl += "^LH0,0\n"
        zpl += "^FO20,20^A0N,50,38^FDTEST 1^FS\n"
        zpl += "^FO20,90^A0N,34,28^FD\(sanitize(line1))^FS\n"
        zpl += "^FO20,140^A0N,30,24^FD\(sanitize(line2))^FS\n"
        zpl += "^XZ\n"
        return zpl
    }

    // Profile 5: Explicit darkness/speed + print quantity command.
    private func zplProfile5(line1: String, line2: String, line3: String) -> String {
        var zpl = "^XA\n"
        zpl += "^CI28\n"
        zpl += "^PW\(labelWidthDots)\n"
        zpl += "^LL\(labelHeightDots)\n"
        zpl += "^PR1,1\n"
        zpl += "^MD28\n"
        zpl += "^LH0,0\n"
        zpl += "^PQ1,0,1,N\n"
        zpl += "^FO2,2^A0N,28,22^FD\(sanitize(line1))^FS\n"
        zpl += "^FO2,34^A0N,20,16^FD\(sanitize(line2))^FS\n"
        zpl += "^FO2,60^A0N,20,16^FD\(sanitize(line3))^FS\n"
        zpl += "^XZ\n"
        return zpl
    }

    /// Strip ZPL-unsafe characters (caret, tilde, null)
    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "^", with: "")
            .replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: "\0", with: "")
    }

    // MARK: - TCP Send

    private func sendZPL(_ zpl: String) async throws {
        let ip = printerIP.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = NWEndpoint.Host(ip)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let connection = NWConnection(host: host, port: nwPort, using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "com.qdi.zebra.tcp")
            var resumed = false
            let lock = NSLock()

            func complete(_ result: Result<Void, Error>) {
                lock.lock()
                guard !resumed else { lock.unlock(); return }
                resumed = true
                lock.unlock()
                connection.cancel()
                continuation.resume(with: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard let data = zpl.data(using: .utf8) else {
                        complete(.failure(ZebraPrintError.sendFailed("UTF8 encoding failed")))
                        return
                    }
                    Task { @MainActor in self.status = .sending }
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error {
                            printLog.error("TCP send error: \(error.localizedDescription, privacy: .public)")
                            complete(.failure(ZebraPrintError.sendFailed(error.localizedDescription)))
                        } else {
                            printLog.info("ZPL sent to \(ip, privacy: .public):\(self.port)")
                            complete(.success(()))
                        }
                    })
                case .failed(let error):
                    printLog.error("TCP connection failed: \(error.localizedDescription, privacy: .public)")
                    complete(.failure(ZebraPrintError.connectionFailed(error.localizedDescription)))
                case .cancelled:
                    break
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + self.timeoutSeconds) {
                complete(.failure(ZebraPrintError.timeout))
            }
        }
    }
}

// MARK: - Environment Key

private struct ZebraPrintServiceKey: EnvironmentKey {
    static let defaultValue: ZebraPrintService? = nil
}

extension EnvironmentValues {
    var zebraPrintService: ZebraPrintService? {
        get { self[ZebraPrintServiceKey.self] }
        set { self[ZebraPrintServiceKey.self] = newValue }
    }
}
