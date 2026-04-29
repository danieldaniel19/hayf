import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var userEmail: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClientProvider.shared

    func startAuthStateListener() async {
        for await state in supabase.auth.authStateChanges {
            if [.initialSession, .signedIn, .signedOut].contains(state.event) {
                updateSession(state.session)
            }
        }
    }

    func signInWithGoogle() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let session = try await supabase.auth.signInWithOAuth(provider: .google)
                updateSession(session)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                updateSession(nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func updateSession(_ session: Session?) {
        isAuthenticated = session != nil
        userEmail = session?.user.email
    }
}
