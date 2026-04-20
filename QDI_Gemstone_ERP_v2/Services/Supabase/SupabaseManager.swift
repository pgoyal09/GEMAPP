import Foundation
import Supabase

/// Singleton Supabase client for QDI Gemstone ERP.
/// Offline-first: SwiftData is source of truth, Supabase syncs in background.
final class SupabaseManager: Sendable {
    static let shared = SupabaseManager()

    // nonisolated(unsafe) not needed — SupabaseClient is Sendable

    let client: SupabaseClient

    private init() {
        let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ?? UserDefaults.standard.string(forKey: "supabaseURL")
            ?? "https://sktyjtwghscechbrejim.supabase.co"
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? UserDefaults.standard.string(forKey: "supabaseAnonKey")
            ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrdHlqdHdnaHNjZWNoYnJlamltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUwNjcwODUsImV4cCI6MjA5MDY0MzA4NX0.XqhZr5IgmYxvabZ2pU3VScelvAOLlrM5UrjyGxNo-LI"
        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
    }
}
