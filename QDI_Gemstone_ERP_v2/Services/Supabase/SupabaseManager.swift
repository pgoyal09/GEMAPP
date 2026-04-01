import Foundation
import Supabase

/// Singleton Supabase client for QDI Gemstone ERP.
/// Offline-first: SwiftData is source of truth, Supabase syncs in background.
final class SupabaseManager: Sendable {
    static let shared = SupabaseManager()

    // nonisolated(unsafe) not needed — SupabaseClient is Sendable

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://sktyjtwghscechbrejim.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdHlqdHdnaHNjZWNoYnJlamltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUwNjcwODUsImV4cCI6MjA5MDY0MzA4NX0.XqhZr5IgmYxvabZ2pU3VScelvAOLlrM5UrjyGxNo-LI"
        )
    }
}
