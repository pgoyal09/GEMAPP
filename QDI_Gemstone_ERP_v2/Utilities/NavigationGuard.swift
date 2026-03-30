import SwiftUI

/// Tracks unsaved changes to prevent accidental navigation away from dirty views.
@Observable
final class NavigationGuard {
    var hasUnsavedChanges = false
    private var onDiscardHandler: (() -> Void)?

    func reportDirty(_ dirty: Bool, onDiscard: (() -> Void)? = nil) {
        hasUnsavedChanges = dirty
        onDiscardHandler = onDiscard
    }

    func clearDirty() {
        hasUnsavedChanges = false
        onDiscardHandler = nil
    }

    func performDiscard() {
        onDiscardHandler?()
        clearDirty()
    }
}

// MARK: - Environment Key

private struct NavigationGuardKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = NavigationGuard()
}

extension EnvironmentValues {
    var navigationGuard: NavigationGuard {
        get { self[NavigationGuardKey.self] }
        set { self[NavigationGuardKey.self] = newValue }
    }
}
