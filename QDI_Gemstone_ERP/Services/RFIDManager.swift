import Foundation
import Darwin
import Darwin.POSIX
import os
import Combine
import SwiftUI
import ORSSerial
import AppKit

// MARK: - Connection Status (UI-facing)

enum RFIDConnectionStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case initializing = "Initializing"
    case connected = "Connected"
    case scanning = "Scanning"
    case error = "Error"
}

// MARK: - Internal State Machine

private enum InternalRFIDState {
    case disconnected
    case connecting
    case initializing
    case ready
    case scanning
    case error
}

/// Non-blocking startup state: which response we're waiting for.
private enum StartupState: Equatable {
    case waitingForVersion
    case waitingForBoot
    case waitingForUID
    case waitingForAsyncAck
}

// MARK: - Tag Scan Event

struct TagScan {
    let identifier: String
    let timestamp: Date
}

// MARK: - RFIDManager (Silion Framing)

/// Manages FTDI USB-Serial RFID reader using Silion framing: FF LEN CMD [DATA...] CRC_H CRC_L.
/// Implements observed startup: Get Version → Boot Firmware → Get UID (optional) → Start Async Inventory.
/// UID is non-fatal: if Version+Boot succeed but UID times out, startup continues.
final class RFIDManager: NSObject, ObservableObject, RFIDService, ORSSerialPortDelegate {

    var onTagDiscovered: ((String) -> Void)?

    // MARK: - Published State

    @Published private(set) var connectionStatus: RFIDConnectionStatus = .disconnected
    @Published private(set) var tagsDetectedCount: Int = 0
    @Published private(set) var lastTagIdentifier: String?
    @Published private(set) var lastSeen: Date?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastScannedTag: String?
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionError: String?
    @Published var availablePorts: [ORSSerialPort] = []
    @Published private(set) var isScanningPaused: Bool = false
    @Published private(set) var uniqueTagsThisSession: Int = 0
    var selectedPortPath: String? { selectedPort?.path }

    // MARK: - Silion Frames (known-good bytes from working serial tester)

    /// Append 0x0D (carriage return) after each command as required by device.
    private static func withCarriageReturn(_ frame: [UInt8]) -> [UInt8] {
        frame + [0x0D]
    }

    /// GetVersionInfo - exact known-good bytes: FF 00 03 1D 0C + 0x0D
    private static let getVersionFrame: [UInt8] = withCarriageReturn([0xFF, 0x00, 0x03, 0x1D, 0x0C])

    /// BootFirmware - exact known-good bytes: FF 00 04 1D 0B + 0x0D
    private static let bootFirmwareFrame: [UInt8] = withCarriageReturn([0xFF, 0x00, 0x04, 0x1D, 0x0B])

    /// GetUID - exact known-good bytes: FF 02 10 00 00 F0 93 + 0x0D
    private static let getUIDFrame: [UInt8] = withCarriageReturn([0xFF, 0x02, 0x10, 0x00, 0x00, 0xF0, 0x93])

    /// Start Async Inventory - known-good bytes + 0x0D
    private static let startAsyncInventory: [UInt8] = withCarriageReturn([
        0xFF, 0x1F, 0xAA, 0x4D, 0x6F, 0x64, 0x75, 0x6C, 0x65, 0x74, 0x65, 0x63, 0x68, 0xAA, 0x48, 0x00,
        0xFF, 0x00, 0x00, 0x04, 0x01, 0x09, 0x28, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x04,
        0x2D, 0xBB, 0xD1, 0x0C
    ])

    /// Stop Async Inventory + 0x0D for consistency
    private static let stopAsyncInventory: [UInt8] = withCarriageReturn([
        0xFF, 0x0E, 0xAA, 0x4D, 0x6F, 0x64, 0x75, 0x6C, 0x65, 0x74, 0x65, 0x63, 0x68, 0xAA, 0x49, 0xF3,
        0xBB, 0x03, 0x91
    ])

    /// Async-start ack DATA (after status bytes) starts with: 4D 6F 64 75 6C 65 74 65 63 68 ("Moduletech")
    private static let asyncAckDataPrefix: [UInt8] = [0x4D, 0x6F, 0x64, 0x75, 0x6C, 0x65, 0x74, 0x65, 0x63, 0x68]

    // MARK: - Config (region/power optional - not part of mandatory bring-up)

    /// Optional: set region. Called after Boot, before Async Start, only if configured.
    private var applyRegionConfig: (() -> Void)? = nil
    /// Optional: set power. Called after Boot, before Async Start, only if configured.
    private var applyPowerConfig: (() -> Void)? = nil

    // MARK: - Timing

    private let baudRate: speed_t
    private let startupResponseTimeout: TimeInterval = 2.0  // logged at failure
    private let reconnectMinDelay: TimeInterval = 2.0
    private let reconnectMaxDelay: TimeInterval = 10.0

    // MARK: - State

    private var internalState: InternalRFIDState = .disconnected
    private var selectedPort: ORSSerialPort?
    private var fileDescriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.qdi.rfid-manager", qos: .userInitiated)
    private var iolock = os_unfair_lock()

    private var frameBuffer = Data()
    private let frameBufferLock = NSLock()

    private var reconnectWorkItem: DispatchWorkItem?
    private var reconnectDelay: TimeInterval = 2.0
    private var framesReceivedCount: Int = 0
    private var crcFailuresCount: Int = 0

    /// Non-blocking startup: current state (nil = not in startup handshake)
    private var startupState: StartupState?
    private var startupTimeoutWorkItem: DispatchWorkItem?
    private var startupAborted: Bool = false

    /// Stored UID when GetUID succeeds (informational)
    private var storedReaderUID: String?

    /// Session dedupe: canonical tag IDs seen this session (one physical tag = one event per session)
    private var seenTagIDsThisSession: Set<String> = []
    private let sessionLock = NSLock()

    init(baudRate: speed_t = speed_t(B115200)) {
        self.baudRate = baudRate
        super.init()
        refreshPorts()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopScanning()
        }
    }

    deinit {
        stopScanning()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    func connect() {
        startScanning()
    }

    func startScanning() {
        cancelReconnect()
        performFullStop()
        setInternalState(.connecting)
        setStatus(.connecting)
        setConnected(false)
        setError(nil)
        debugLog("[RFID] Connect requested, opening port...")
        queue.async { [weak self] in
            self?.runStartupSequence()
        }
    }

    func stopScanning() {
        cancelReconnect()
        performFullStop()
    }

    func reconnect() {
        debugLog("[RFID] Reconnect requested")
        setError(nil)
        reconnectDelay = reconnectMinDelay
        startScanning()
    }

    func refreshPorts() {
        let ports = ORSSerialPortManager.shared().availablePorts
        DispatchQueue.main.async { [weak self] in
            self?.availablePorts = ports
        }
    }

    func selectPort(byPath path: String?) {
        selectedPort = path.flatMap { p in availablePorts.first { $0.path == p } }
    }

    func autoConnect() {
        refreshPorts()
        let ports = ORSSerialPortManager.shared().availablePorts
        let match = ports.first { port in
            let p = port.path.lowercased()
            return p.contains("usbserial") || p.contains("cu.")
        }
        selectedPort = match
        connect()
    }

    func clearLastScannedTag() {
        DispatchQueue.main.async { [weak self] in
            self?.lastScannedTag = nil
            self?.lastTagIdentifier = nil
        }
    }

    func pauseScanning() {
        DispatchQueue.main.async { [weak self] in
            self?.isScanningPaused = true
            debugLog("[RFID] Scanning paused")
        }
    }

    func resumeScanning() {
        sessionLock.lock()
        seenTagIDsThisSession.removeAll()
        sessionLock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.isScanningPaused = false
            self?.uniqueTagsThisSession = 0
            debugLog("[RFID] Scanning resumed")
        }
    }

    func resetScanSession() {
        sessionLock.lock()
        seenTagIDsThisSession.removeAll()
        let count = seenTagIDsThisSession.count
        sessionLock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.uniqueTagsThisSession = 0
            self?.tagsDetectedCount = 0
            self?.lastScannedTag = nil
            self?.lastTagIdentifier = nil
            debugLog("[RFID] Session reset")
        }
    }

    // MARK: - ORSSerialPortDelegate

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        debugLog("[RFID] Serial port error: \(error.localizedDescription)")
        handleDisconnect(reason: "Serial error: \(error.localizedDescription)")
        scheduleReconnectAsync()
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        debugLog("[RFID] Serial port removed from system")
        if selectedPort === serialPort {
            selectedPort = nil
        }
        handleDisconnect(reason: "Reader unplugged")
        scheduleReconnectAsync()
    }

    // MARK: - Full Stop & Cleanup

    private func performFullStop() {
        startupAborted = true
        startupTimeoutWorkItem?.cancel()
        startupTimeoutWorkItem = nil
        startupState = nil

        os_unfair_lock_lock(&iolock)
        readSource?.cancel()
        readSource = nil
        if fileDescriptor >= 0 {
            sendStopFrameLocked()
            close(fileDescriptor)
            fileDescriptor = -1
        }
        os_unfair_lock_unlock(&iolock)

        frameBufferLock.lock()
        frameBuffer = Data()
        frameBufferLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setConnected(false)
            self.setInternalState(.disconnected)
            self.setStatus(.disconnected)
        }
    }

    private func cancelReconnect() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
    }

    // MARK: - Disconnect Detection & Handling

    private func handleDisconnect(reason: String) {
        debugLog("[RFID] Disconnect detected: \(reason)")
        performFullStop()
        DispatchQueue.main.async { [weak self] in
            self?.setError(reason)
            self?.setStatus(.disconnected)
        }
    }

    // MARK: - State Helpers

    private func setInternalState(_ state: InternalRFIDState) {
        internalState = state
    }

    private func setStatus(_ status: RFIDConnectionStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = status
        }
    }

    private func setConnected(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = value
        }
    }

    private func setError(_ message: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionError = message
            self?.lastErrorMessage = message
        }
    }

    // MARK: - Startup Sequence (non-blocking state machine)

    private func runStartupSequence() {
        startupAborted = false

        guard let path = selectedPort?.path ?? findUsbSerialPort() else {
            debugLog("[RFID] No port selected or found")
            setStatus(.error)
            setError("No /dev/cu.usbserial* port. Connect reader and tap Reconnect.")
            scheduleReconnectAsync()
            return
        }

        debugLog("[RFID] Opening port: \(path)")
        let fd = open(path, O_RDWR | O_NOCTTY)
        guard fd >= 0 else {
            let msg = errnoMessage()
            debugLog("[RFID] Open failed: \(msg)")
            setStatus(.error)
            setError(msg)
            scheduleReconnectAsync()
            return
        }
        debugLog("[RFID] Serial port opened successfully")

        os_unfair_lock_lock(&iolock)
        fileDescriptor = fd
        configurePort(fd)
        setDTRRTS(fd)
        os_unfair_lock_unlock(&iolock)

        startReadSource(fd)
        setInternalState(.initializing)
        setStatus(.initializing)
        debugLog("[RFID] Startup timeout: \(startupResponseTimeout)s per step (non-blocking)")

        queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, !self.startupAborted else { return }
            self.sendGetVersionAndWait()
        }
    }

    private func sendGetVersionAndWait() {
        guard !startupAborted, fileDescriptor >= 0 else { return }
        startupState = .waitingForVersion
        debugLog("[RFID] state -> waitingForVersion")
        let n = writeFrame(Self.getVersionFrame, label: "GetVersionInfo")
        guard n == Self.getVersionFrame.count else {
            handleStartupFailure("GetVersionInfo send failed")
            return
        }
        scheduleStartupTimeout(step: "GetVersionInfo", fatal: true) { [weak self] in
            self?.handleStartupFailure("GetVersionInfo - no response within \(self?.startupResponseTimeout ?? 2)s")
        }
    }

    private func sendBootAndWait() {
        guard !startupAborted, fileDescriptor >= 0 else { return }
        startupState = .waitingForBoot
        debugLog("[RFID] state -> waitingForBoot")
        let n = writeFrame(Self.bootFirmwareFrame, label: "BootFirmware")
        guard n == Self.bootFirmwareFrame.count else {
            handleStartupFailure("BootFirmware send failed")
            return
        }
        scheduleStartupTimeout(step: "BootFirmware", fatal: true) { [weak self] in
            self?.handleStartupFailure("BootFirmware - no response within \(self?.startupResponseTimeout ?? 2)s")
        }
    }

    private func sendUIDAndWait() {
        guard !startupAborted, fileDescriptor >= 0 else { return }
        startupState = .waitingForUID
        debugLog("[RFID] state -> waitingForUID")
        let n = writeFrame(Self.getUIDFrame, label: "GetUID")
        guard n == Self.getUIDFrame.count else {
            advanceToAsyncStart()
            return
        }
        scheduleStartupTimeout(step: "GetUID", fatal: false) { [weak self] in
            self?.advanceToAsyncStart()
        }
    }

    private func advanceToAsyncStart() {
        guard !startupAborted else { return }
        startupTimeoutWorkItem?.cancel()
        startupTimeoutWorkItem = nil
        debugLog("[RFID] GetUID timeout or skipped - non-fatal, advancing to async start")
        applyRegionConfig?()
        applyPowerConfig?()
        sendAsyncStartAndWait()
    }

    private func sendAsyncStartAndWait() {
        guard !startupAborted, fileDescriptor >= 0 else { return }
        startupState = .waitingForAsyncAck
        debugLog("[RFID] state -> waitingForAsyncAck")
        let n = writeFrame(Self.startAsyncInventory, label: "Start Async Inventory")
        guard n == Self.startAsyncInventory.count else {
            handleStartupFailure("Start Async Inventory send failed")
            return
        }
        scheduleStartupTimeout(step: "Start Async Inventory", fatal: true) { [weak self] in
            self?.handleStartupFailure("Start Async Inventory - no ack within \(self?.startupResponseTimeout ?? 2)s")
        }
    }

    private func scheduleStartupTimeout(step: String, fatal: Bool, handler: @escaping () -> Void) {
        startupTimeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.startupTimeoutWorkItem = nil
            handler()
        }
        startupTimeoutWorkItem = item
        queue.asyncAfter(deadline: .now() + startupResponseTimeout, execute: item)
    }

    private func cancelStartupTimeout() {
        startupTimeoutWorkItem?.cancel()
        startupTimeoutWorkItem = nil
    }

    private func handleStartupFailure(_ message: String) {
        debugLog("[RFID] Startup FAILED: \(message)")
        setError(message)
        setStatus(.error)
        startupState = nil
        performFullStop()
        scheduleReconnectAsync()
    }

    private func completeStartup() {
        debugLog("[RFID] Startup complete, entering scanning state")
        cancelStartupTimeout()
        startupState = nil
        setInternalState(.scanning)
        setConnected(true)
        setError(nil)
        setStatus(.scanning)
    }

    /// Low-level write with exact TX logging. Sends raw bytes via withUnsafeBytes.
    private func writeFrame(_ frame: [UInt8], label: String) -> Int {
        let hex = frame.map { String(format: "%02X", $0) }.joined(separator: " ")
        debugLog("[RFID] TX \(label): \(hex)")
        os_unfair_lock_lock(&iolock)
        defer { os_unfair_lock_unlock(&iolock) }
        guard fileDescriptor >= 0 else { return -1 }
        let n = frame.withUnsafeBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return -1 }
            return Darwin.write(fileDescriptor, base, ptr.count)
        }
        return n
    }


    private func findUsbSerialPort() -> String? {
        let ports = ORSSerialPortManager.shared().availablePorts
        return ports.first { $0.path.lowercased().contains("usbserial") }?.path
    }

    private func configurePort(_ fd: Int32) {
        var t = termios()
        guard tcgetattr(fd, &t) == 0 else { return }
        cfmakeraw(&t)
        cfsetispeed(&t, baudRate)
        cfsetospeed(&t, baudRate)
        // 8N1
        t.c_cflag = tcflag_t(CS8 | CREAD | CLOCAL)
        t.c_cflag &= ~tcflag_t(CRTSCTS)  // flow control OFF (clear hardware flow control)
        t.c_iflag &= ~tcflag_t(IXON | IXOFF)  // flow control OFF (clear software flow control)
        // VMIN/VTIME: Darwin c_cc indices 16=VMIN, 17=VTIME
        t.c_cc.16 = 0   // VMIN: min chars to read (0 = non-blocking with VTIME)
        t.c_cc.17 = 10  // VTIME: 0.1s units, 10 = 1s read timeout
        tcsetattr(fd, TCSANOW, &t)
        tcflush(fd, TCIOFLUSH)
    }

    private func setDTRRTS(_ fd: Int32) {
        var dtr = Int32(TIOCM_DTR)
        ioctl(fd, TIOCMBIS, &dtr)
        var rts = Int32(TIOCM_RTS)
        ioctl(fd, TIOCMBIS, &rts)
        debugLog("[RFID] DTR and RTS enabled")
    }

    private func sendStopFrameLocked() {
        guard fileDescriptor >= 0 else { return }
        let f = Self.stopAsyncInventory
        let n = f.withUnsafeBytes { ptr -> Int in
            guard let base = ptr.baseAddress else { return -1 }
            return Darwin.write(fileDescriptor, base, ptr.count)
        }
        let hex = f.map { String(format: "%02X", $0) }.joined(separator: " ")
        debugLog("[RFID] TX StopAsyncInventory: \(hex) -> \(n >= 0 ? "\(n) bytes" : "err")")
    }

    // MARK: - Reconnect (non-blocking)

    private func scheduleReconnectAsync() {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleReconnectMain()
        }
    }

    private func scheduleReconnectMain() {
        cancelReconnect()
        let delay = reconnectDelay
        reconnectDelay = min(reconnectMaxDelay, reconnectDelay + 2.0)
        debugLog("[RFID] Reconnect scheduled in \(String(format: "%.1f", delay))s...")
        let item = DispatchWorkItem { [weak self] in
            debugLog("[RFID] Reconnect started")
            self?.startScanning()
        }
        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    // MARK: - Read & Parse

    private func startReadSource(_ fd: Int32) {
        readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        readSource?.setEventHandler { [weak self] in
            self?.readAvailable()
        }
        readSource?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            os_unfair_lock_lock(&self.iolock)
            defer { os_unfair_lock_unlock(&self.iolock) }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        readSource?.resume()
    }

    private func readAvailable() {
        os_unfair_lock_lock(&iolock)
        guard fileDescriptor >= 0 else { os_unfair_lock_unlock(&iolock); return }
        var buf = [UInt8](repeating: 0, count: 512)
        let n = read(fileDescriptor, &buf, buf.count)
        os_unfair_lock_unlock(&iolock)

        if n < 0 {
            let reason = String(cString: strerror(errno))
            debugLog("[RFID] Read error: \(reason)")
            handleDisconnect(reason: "Read failed: \(reason)")
            scheduleReconnectAsync()
            return
        }
        if n == 0 {
            debugLog("[RFID] Read returned 0 (EOF/disconnect)")
            handleDisconnect(reason: "Reader disconnected")
            scheduleReconnectAsync()
            return
        }

        frameBufferLock.lock()
        frameBuffer.append(contentsOf: buf[..<n])
        let snapshot = Array(frameBuffer)
        frameBufferLock.unlock()

        #if DEBUG
        let hex = snapshot.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " ")
        let suffix = snapshot.count > 64 ? " ..." : ""
        debugLog("[RFID] RX raw (\(snapshot.count) bytes): \(hex)\(suffix)")
        #endif

        parseSilionFrames(bytes: snapshot)
    }

    /// Response frame structure (verified):
    /// FF LEN CMD ST0 ST1 DATA[LEN] CRC_H CRC_L
    /// totalLen = 1 + 1 + 1 + 2 + LEN + 2
    /// CRC input: LEN CMD ST0 ST1 DATA[LEN] (do NOT include FF)
    private func parseSilionFrames(bytes: [UInt8]) {
        let count = bytes.count
        var idx = 0
        var remainder = Data()

        while idx < count {
            guard idx < count else { break }
            if bytes[idx] != 0xFF {
                idx += 1
                continue
            }
            if idx + 7 > count {
                debugLog("[RFID] Partial frame at \(idx), need min 7 bytes, have \(count - idx) remaining")
                remainder = Data(bytes[idx...])
                break
            }
            let lenByte = bytes[idx + 1]
            let len = Int(lenByte)
            let totalLen = 7 + len
            if len > 128 {
                debugLog("[RFID] Malformed length \(len), resync to next 0xFF")
                idx += 1
                continue
            }
            if idx + totalLen > count {
                debugLog("[RFID] Partial frame len=\(len) total=\(totalLen), need \(totalLen - (count - idx)) more bytes")
                remainder = Data(bytes[idx...])
                break
            }
            let cmd = bytes[idx + 2]
            let st0 = bytes[idx + 3]
            let st1 = bytes[idx + 4]
            let dataStart = idx + 5
            let payloadEnd = dataStart + len
            let crcStart = payloadEnd
            guard crcStart + 2 <= count else {
                debugLog("[RFID] Bounds check failed for CRC")
                idx += 1
                continue
            }
            let payload = Array(bytes[dataStart..<payloadEnd])
            let crcRecv = (UInt16(bytes[crcStart]) << 8) | UInt16(bytes[crcStart + 1])
            let crcPayload = [lenByte, cmd, st0, st1] + payload
            let crcCalc = Self.silionCRC16(crcPayload)

            framesReceivedCount += 1

            if crcRecv != crcCalc {
                crcFailuresCount += 1
                if crcFailuresCount <= 5 || crcFailuresCount % 100 == 0 {
                    debugLog("[RFID] CRC mismatch cmd=0x\(String(format: "%02X", cmd)) status=\(String(format: "%02X", st0))\(String(format: "%02X", st1)) len=\(len) crcCalc=\(String(format: "%04X", crcCalc)) crcRecv=\(String(format: "%04X", crcRecv))")
                }
                idx += 1
                continue
            }

            let isAsyncAck = isAsyncStartAck(cmd: cmd, payload: payload)
            let isTagEvent = isTagEventFrame(cmd: cmd, payload: payload)
            if !isTagEvent {
                debugLog("[RFID] Frame parsed cmd=0x\(String(format: "%02X", cmd)) status=\(String(format: "%02X", st0)) \(String(format: "%02X", st1)) len=\(len) crcCalc=\(String(format: "%04X", crcCalc)) crcRecv=\(String(format: "%04X", crcRecv))")
            }

            if isAsyncAck {
                if startupState == .waitingForAsyncAck {
                    debugLog("[RFID] parsed async-start ack")
                    cancelStartupTimeout()
                    completeStartup()
                }
            } else if isTagEvent {
                debugLog("[RFID] Tag frame detected len=\(len)")
                if internalState == .scanning && !isScanningPaused {
                    let payloadBytes = payload
                    let rawHex = payloadBytes.map { String(format: "%02X", $0) }.joined().uppercased()
                    let canonicalTagID = deriveCanonicalTagID(from: payloadBytes)
                    debugLog("[RFID] Raw payload: \(rawHex.prefix(48))\(rawHex.count > 48 ? "..." : "")")
                    debugLog("[RFID] Canonical tag ID (stable): \(canonicalTagID.prefix(24))\(canonicalTagID.count > 24 ? "..." : "")")
                    sessionLock.lock()
                    let alreadySeen = seenTagIDsThisSession.contains(canonicalTagID)
                    if alreadySeen {
                        sessionLock.unlock()
                        debugLog("[RFID] Duplicate tag suppressed: \(canonicalTagID.prefix(24))...")
                        idx += totalLen
                        continue
                    }
                    seenTagIDsThisSession.insert(canonicalTagID)
                    let uniqueCount = seenTagIDsThisSession.count
                    sessionLock.unlock()
                    DispatchQueue.main.async { [weak self] in
                        self?.uniqueTagsThisSession = uniqueCount
                    }
                    emitTagScan(identifier: rawHex)
                }
            } else {
                handleControlFrame(cmd: cmd, payload: payload, payloadSlice: Data(payload))
            }

            idx += totalLen
        }

        frameBufferLock.lock()
        if idx >= count {
            frameBuffer = Data()
        } else {
            frameBuffer = remainder
        }
        frameBufferLock.unlock()
    }

    private func handleControlFrame(cmd: UInt8, payload: [UInt8], payloadSlice: Data) {
        guard let state = startupState else { return }
        switch state {
        case .waitingForVersion:
            if cmd == 0x03 {
                debugLog("[RFID] parsed version response")
                cancelStartupTimeout()
                queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.sendBootAndWait()
                }
            }
        case .waitingForBoot:
            if cmd == 0x04 {
                debugLog("[RFID] parsed boot response")
                cancelStartupTimeout()
                queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.sendUIDAndWait()
                }
            }
        case .waitingForUID:
            if cmd == 0x10 {
                debugLog("[RFID] parsed uid response")
                cancelStartupTimeout()
                storedReaderUID = payloadSlice.map { String(format: "%02X", $0) }.joined()
                queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self = self else { return }
                    self.applyRegionConfig?()
                    self.applyPowerConfig?()
                    self.sendAsyncStartAndWait()
                }
            }
        case .waitingForAsyncAck:
            break
        }
    }

    /// Async-start ack: cmd 0xAA, DATA (after status) starts with 4D 6F 64 75 6C 65 74 65 63 68 ("Moduletech")
    private func isAsyncStartAck(cmd: UInt8, payload: [UInt8]) -> Bool {
        guard cmd == 0xAA else { return false }
        let prefix = Self.asyncAckDataPrefix
        guard payload.count >= prefix.count else { return false }
        return prefix.enumerated().allSatisfy { payload[$0.offset] == $0.element }
    }

    private func frameTypeLabel(cmd: UInt8, isAsyncAck: Bool) -> String {
        if isAsyncAck { return "async-ack" }
        switch cmd {
        case 0x03: return "version"
        case 0x04: return "boot"
        case 0x10: return "uid"
        case 0xAA: return "tag-event"
        default: return "control"
        }
    }

    /// Derive stable canonical tag ID from payload. Do NOT use leading metadata bytes.
    /// Search for E2 80 (stable identity marker in observed frames) and extract chunk from there.
    /// Fallback: use last 12 bytes (EPC often at end) to avoid leading metadata.
    private func deriveCanonicalTagID(from payload: [UInt8]) -> String {
        let stableChunkLen = 12
        guard payload.count >= 2 else {
            return payload.map { String(format: "%02X", $0) }.joined().uppercased()
        }
        for i in 0..<(payload.count - 1) {
            if payload[i] == 0xE2 && payload[i + 1] == 0x80 {
                let start = i
                let end = min(start + stableChunkLen, payload.count)
                let chunk = Array(payload[start..<end])
                return chunk.map { String(format: "%02X", $0) }.joined().uppercased()
            }
        }
        let fallbackStart = max(0, payload.count - stableChunkLen)
        let chunk = Array(payload[fallbackStart...])
        return chunk.map { String(format: "%02X", $0) }.joined().uppercased()
    }

    /// Tag events: cmd 0xAA with EPC-sized payload, NOT the async ack.
    private func isTagEventFrame(cmd: UInt8, payload: [UInt8]) -> Bool {
        guard cmd == 0xAA else { return false }
        guard payload.count >= 8 else { return false }
        return !isAsyncStartAck(cmd: cmd, payload: payload)
    }

    /// Shared Silion bit-by-bit CRC. Used for both RX validation and TX generation.
    /// Do NOT use standard CCITT helpers; reader requires this exact algorithm.
    private static func silionCRC16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for b in bytes {
            var mask: UInt8 = 0x80
            for _ in 0..<8 {
                let msbSet = (crc & 0x8000) != 0
                crc = (crc << 1) & 0xFFFF
                if (b & mask) != 0 {
                    crc |= 1
                }
                if msbSet {
                    crc ^= 0x1021
                }
                mask >>= 1
            }
        }
        return crc
    }

    private func emitTagScan(identifier: String) {
        debugLog("[RFID] Tag event emitted: \(identifier.prefix(48))\(identifier.count > 48 ? "..." : "")")
        let scan = TagScan(identifier: identifier, timestamp: Date())
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tagsDetectedCount += 1
            self.lastTagIdentifier = identifier
            self.lastSeen = scan.timestamp
            self.lastScannedTag = identifier
            self.onTagDiscovered?(identifier)
            debugLog("[RFID] Scan handed off to app flow")
        }
    }

    private func errnoMessage() -> String {
        switch errno {
        case EACCES: return "Access denied. Use 'Allow' if macOS asked."
        case ENOENT: return "Device not found. Is the reader connected?"
        case EBUSY: return "Port busy. Close other apps using the reader."
        case EIO: return "I/O error. Try unplugging and reconnecting."
        default: return "Error \(errno): \(String(cString: strerror(errno)))"
        }
    }
}

private var time_base_info: mach_timebase_info_data_t = {
    var t = mach_timebase_info_data_t()
    mach_timebase_info(&t)
    return t
}()

private func debugLog(_ msg: String) {
    #if DEBUG
    print(msg)
    #endif
}
