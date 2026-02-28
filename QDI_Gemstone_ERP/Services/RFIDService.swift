import Foundation
import AppKit
import Darwin
import Darwin.POSIX

// MARK: - Protocol (Section 4A: mock until drivers installed)

/// Abstraction for RFID tag scanning. Implement with hardware (e.g. GoToTags E310 keyboard wedge or serial) or mock for testing.
protocol RFIDService: AnyObject {
    /// Called when a tag ID is read. Invoked on main thread.
    var onTagDiscovered: ((String) -> Void)? { get set }
    
    /// Start listening for tag scans.
    func startScanning()
    
    /// Stop listening.
    func stopScanning()
}

// MARK: - Environment (for TransactionEditorView to receive serial tags)

import SwiftUI

private struct RFIDServiceKey: EnvironmentKey {
    static let defaultValue: RFIDService? = nil
}

extension EnvironmentValues {
    var rfidService: RFIDService? {
        get { self[RFIDServiceKey.self] }
        set { self[RFIDServiceKey.self] = newValue }
    }
}

// MARK: - RFIDCoordinator environment

private struct RFIDCoordinatorKey: EnvironmentKey {
    static let defaultValue: RFIDCoordinator? = nil
}

extension EnvironmentValues {
    var rfidCoordinator: RFIDCoordinator? {
        get { self[RFIDCoordinatorKey.self] }
        set { self[RFIDCoordinatorKey.self] = newValue }
    }
}

// MARK: - Serial: Kcosit / E310 over USB serial (EPC hex from stream)

/// Connects to /dev/cu.usbserial-* at 115200 baud and parses EPC hex strings from the serial stream.
/// When a complete EPC is read (newline-terminated or valid hex block), calls onTagDiscovered(epc).
final class SerialRFIDService: RFIDService {
    var onTagDiscovered: ((String) -> Void)?
    
    private let path: String
    private let baudRate: speed_t
    private var readSource: DispatchSourceRead?
    private var fileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.qdi.serial-rfid", qos: .userInitiated)
    private var buffer = Data()
    private var isRunning = false
    private let bufferLock = NSLock()
    
    /// - Parameter path: Serial device path (e.g. "/dev/cu.usbserial-BG01QLE2").
    /// - Parameter baudRate: Baud rate; default 115200 (standard for E310).
    init(path: String = "/dev/cu.usbserial-BG01QLE2", baudRate: speed_t = speed_t(B115200)) {
        self.path = path
        self.baudRate = baudRate
    }
    
    func startScanning() {
        stopScanning()
        queue.async { [weak self] in
            self?.openAndRead()
        }
    }
    
    func stopScanning() {
        bufferLock.lock()
        isRunning = false
        bufferLock.unlock()
        readSource?.cancel()
        readSource = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }
    
    private func openAndRead() {
        let fd = open(path, O_RDONLY | O_NOCTTY)
        guard fd >= 0 else {
            return
        }
        fileDescriptor = fd
        
        var t = termios()
        guard tcgetattr(fd, &t) == 0 else {
            close(fd)
            fileDescriptor = -1
            return
        }
        cfsetispeed(&t, baudRate)
        cfsetospeed(&t, baudRate)
        t.c_lflag = 0
        t.c_oflag = 0
        t.c_iflag = 0
        t.c_cflag = tcflag_t(CS8 | CREAD | CLOCAL)
        t.c_cc.16 = 1   // VMIN
        t.c_cc.17 = 0  // VTIME
        guard tcsetattr(fd, TCSANOW, &t) == 0 else {
            close(fd)
            fileDescriptor = -1
            return
        }
        
        bufferLock.lock()
        isRunning = true
        bufferLock.unlock()
        
        readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        readSource?.setEventHandler { [weak self] in
            self?.readAvailable()
        }
        readSource?.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        readSource?.resume()
    }
    
    private func readAvailable() {
        guard fileDescriptor >= 0 else { return }
        var buf = [UInt8](repeating: 0, count: 256)
        let n = read(fileDescriptor, &buf, buf.count)
        guard n > 0 else { return }
        
        bufferLock.lock()
        buffer.append(contentsOf: buf[..<n])
        let data = buffer
        bufferLock.unlock()
        
        parseEPCFromBuffer(data)
    }
    
    /// Parse EPC hex strings from buffer. EPC is typically newline- or CR-terminated hex. Emit non-empty hex tokens (6–48 hex chars).
    private func parseEPCFromBuffer(_ data: Data) {
        guard let text = String(data: data, encoding: .ascii) else { return }
        
        let lines = text.components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: "\r") }
        var remainder = ""
        var emitted = Set<String>()
        
        for (idx, line) in lines.enumerated() {
            let part = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let hex = part.filter { $0.isHexDigit }
            if hex.count >= 6 && hex.count <= 48 {
                let upper = hex.uppercased()
                if !emitted.contains(upper) {
                    emitted.insert(upper)
                    DispatchQueue.main.async { [weak self] in
                        self?.onTagDiscovered?(upper)
                    }
                }
                remainder = ""
            } else {
                let isLast = idx == lines.count - 1
                if isLast { remainder = part }
                else if !part.isEmpty { remainder = part }
            }
        }
        
        bufferLock.lock()
        buffer = remainder.isEmpty ? Data() : Data(remainder.utf8)
        bufferLock.unlock()
    }
}

// MARK: - Hardware: GoToTags E310 (Keyboard Wedge / HID)

/// Listens for input from a reader that acts as a keyboard (HID). The reader types the tag ID and sends Enter.
/// Use when the app (or scanner window) is key so key events are delivered.
final class HardwareRFIDService: RFIDService {
    var onTagDiscovered: ((String) -> Void)?
    
    private var keyMonitor: Any?
    private var scanBuffer = ""
    
    /// Key code for Enter / Return (keyboard wedge typically sends this after the tag ID).
    private let enterKeyCode: UInt16 = 36
    
    func startScanning() {
        stopScanning()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }
    }
    
    func stopScanning() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        scanBuffer = ""
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == enterKeyCode {
            let tagID = scanBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            scanBuffer = ""
            if !tagID.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.onTagDiscovered?(tagID)
                }
            }
            return
        }
        guard let chars = event.characters, !chars.isEmpty else { return }
        scanBuffer += chars
    }
}

// MARK: - Mock (for tests and when hardware is not connected)

/// Simulates tag discovery. Call `simulateTag(id:)` to fire a tag, or enable auto-simulate for periodic fake tags.
final class MockRFIDService: RFIDService {
    var onTagDiscovered: ((String) -> Void)?
    
    private var autoSimulateTimer: Timer?
    private var simulatedCount = 0
    
    func startScanning() {
        simulatedCount = 0
        autoSimulateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.simulateTag(id: "MOCK-TAG-\(self?.simulatedCount ?? 0)")
            self?.simulatedCount += 1
        }
        autoSimulateTimer?.tolerance = 0.2
        RunLoop.main.add(autoSimulateTimer!, forMode: .common)
    }
    
    func stopScanning() {
        autoSimulateTimer?.invalidate()
        autoSimulateTimer = nil
    }
    
    /// Call from tests or UI to simulate a scan without hardware.
    func simulateTag(id: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onTagDiscovered?(id)
        }
    }
}
