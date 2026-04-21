import Foundation
import Supabase
import AuthenticationServices

/// Handles Supabase email/password auth with session persistence.
@MainActor
@Observable
final class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    var isAuthenticated = false
    var currentUserEmail: String?
    var authError: String?
    var isLoading = false

    private nonisolated(unsafe) var authListener: Task<Void, Never>?

    private var client: SupabaseClient? { SupabaseManager.shared.client }

    private init() {
        startAuthListener()
    }

    deinit {
        authListener?.cancel()
    }

    // MARK: - Auth State Listener

    private func startAuthListener() {
        guard let supabaseClient = SupabaseManager.shared.client else { return }
        authListener = Task { [weak self] in
            for await (event, session) in supabaseClient.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .signedIn, .tokenRefreshed:
                    self.isAuthenticated = true
                    self.currentUserEmail = session?.user.email
                    self.authError = nil
                case .signedOut:
                    self.isAuthenticated = false
                    self.currentUserEmail = nil
                default:
                    break
                }
            }
        }
    }

    // MARK: - Check Existing Session

    func checkSession() async {
        guard let client else { return }
        do {
            let session = try await client.auth.session
            isAuthenticated = true
            currentUserEmail = session.user.email
        } catch {
            isAuthenticated = false
            currentUserEmail = nil
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async {
        guard let client else {
            authError = "Cloud sync is not configured."
            return
        }
        isLoading = true
        authError = nil
        do {
            let result = try await client.auth.signUp(email: email, password: password)
            isAuthenticated = result.session != nil
            currentUserEmail = result.user.email
        } catch {
            authError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        guard let client else {
            authError = "Cloud sync is not configured."
            return
        }
        isLoading = true
        authError = nil
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            isAuthenticated = true
            currentUserEmail = session.user.email
        } catch {
            authError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() async {
        guard let client else { return }
        isLoading = true
        do {
            try await client.auth.signOut()
            isAuthenticated = false
            currentUserEmail = nil
            authError = nil
        } catch {
            authError = error.localizedDescription
        }
        isLoading = false
    }
}
