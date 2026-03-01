import SwiftUI

/// Shared state for intercepting navigation when the current screen has unsaved changes.
@Observable
final class NavigationGuard {
    var hasUnsavedChanges: Bool = false
    private var discardHandler: (() -> Void)?

    func reportDirty(_ dirty: Bool, onDiscard: (() -> Void)? = nil) {
        hasUnsavedChanges = dirty
        discardHandler = onDiscard
    }

    func clearDirty() {
        hasUnsavedChanges = false
        discardHandler = nil
    }

    func performDiscard() {
        discardHandler?()
        clearDirty()
    }
}

private struct NavigationGuardKey: EnvironmentKey {
    static let defaultValue: NavigationGuard? = nil
}

extension EnvironmentValues {
    var navigationGuard: NavigationGuard? {
        get { self[NavigationGuardKey.self] }
        set { self[NavigationGuardKey.self] = newValue }
    }
}
