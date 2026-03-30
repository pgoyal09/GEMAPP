import Foundation
import SwiftUI

// MARK: - Protocol

/// Abstraction for RFID tag scanning hardware.
/// Implement with real hardware (Silion serial reader) or a mock for previews/testing.
protocol RFIDService: AnyObject {

    /// Called on the main thread when a tag EPC hex string is read.
    var onTagDiscovered: ((String) -> Void)? { get set }

    /// Called on the main thread when the service encounters an error.
    var onError: ((String) -> Void)? { get set }

    /// Begin listening for tag scans. Opens the serial port and runs the startup handshake.
    func startScanning()

    /// Stop listening and close the serial port.
    func stopScanning()

    /// Temporarily suppress tag events without tearing down the connection.
    func pauseScanning()

    /// Resume tag events after a pause. Resets session deduplication.
    func resumeScanning()

    /// Clear all session counters and dedupe state.
    func resetScanSession()
}

// MARK: - Environment Keys

private struct RFIDServiceKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: RFIDService? = nil
}

extension EnvironmentValues {
    var rfidService: RFIDService? {
        get { self[RFIDServiceKey.self] }
        set { self[RFIDServiceKey.self] = newValue }
    }
}

private struct RFIDCoordinatorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: RFIDCoordinator? = nil
}

extension EnvironmentValues {
    var rfidCoordinator: RFIDCoordinator? {
        get { self[RFIDCoordinatorKey.self] }
        set { self[RFIDCoordinatorKey.self] = newValue }
    }
}
