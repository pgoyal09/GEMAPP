import AppKit

/// Shares files via macOS system sharing (email, AirDrop, Messages, etc.).
enum ShareService {

    /// Presents the macOS sharing service picker for the given file URL.
    /// Uses NSSharingServicePicker anchored to the given view, or falls back to
    /// the key window's content view.
    @MainActor
    static func shareViaNSSharingService(fileURL: URL, anchorView: NSView? = nil) {
        let picker = NSSharingServicePicker(items: [fileURL])
        if let view = anchorView ?? NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }

    /// Presents the macOS sharing service picker for multiple file URLs.
    @MainActor
    static func shareViaNSSharingService(fileURLs: [URL], anchorView: NSView? = nil) {
        let picker = NSSharingServicePicker(items: fileURLs)
        if let view = anchorView ?? NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
}
