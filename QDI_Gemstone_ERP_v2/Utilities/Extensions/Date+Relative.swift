import Foundation

extension Date {
    /// Returns a human-readable relative time string: "just now", "2m ago", "1h ago", "3d ago", etc.
    var relativeTimeString: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}
