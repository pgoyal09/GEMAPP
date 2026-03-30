import Foundation

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

