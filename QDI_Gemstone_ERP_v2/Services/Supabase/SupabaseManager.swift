import Foundation
import Supabase
import os

/// Singleton Supabase client for QDI Gemstone ERP.
/// Offline-first: SwiftData is source of truth, Supabase syncs in background.
/// URL and anon key are read from Info.plist (build-injected) or UserDefaults;
/// hardcoded defaults are removed to avoid leaking credentials in source.
final class SupabaseManager: Sendable {
    static let shared = SupabaseManager()

    private static let logger = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "supabase")

    /// Non-nil when Supabase is properly configured. Callers must check before use.
    let client: SupabaseClient?

    /// True when Supabase configuration is missing or invalid.
    let isUnavailable: Bool

    private init() {
        let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ?? UserDefaults.standard.string(forKey: "supabaseURL")
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? UserDefaults.standard.string(forKey: "supabaseAnonKey")

        guard let urlString = url, let supabaseURL = URL(string: urlString) else {
            Self.logger.warning("Supabase URL not configured or invalid. Cloud sync disabled.")
            self.client = nil
            self.isUnavailable = true
            return
        }
        guard let anonKey = key, !anonKey.isEmpty else {
            Self.logger.warning("Supabase anon key not configured. Cloud sync disabled.")
            self.client = nil
            self.isUnavailable = true
            return
        }
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: anonKey
        )
        self.isUnavailable = false
    }
}
