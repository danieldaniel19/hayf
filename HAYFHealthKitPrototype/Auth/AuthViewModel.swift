import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var userID: UUID?
    @Published private(set) var userEmail: String?
    @Published private(set) var userDisplayName: String?
    @Published private(set) var userAvatarURL: URL?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClientProvider.shared
    private var didAttemptLocalLangGraphAutoLogin = false

    func startAuthStateListener() async {
        await attemptLocalLangGraphAutoLoginIfNeeded()

        for await state in supabase.auth.authStateChanges {
            if [.initialSession, .signedIn, .signedOut].contains(state.event) {
                if state.session == nil {
                    await attemptLocalLangGraphAutoLoginIfNeeded()
                    if isAuthenticated {
                        continue
                    }
                }
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
        userID = session?.user.id
        userEmail = session?.user.email
        userDisplayName = session?.user.googleDisplayName
        userAvatarURL = session?.user.googleAvatarURL
    }

    private func attemptLocalLangGraphAutoLoginIfNeeded() async {
        #if DEBUG
        guard SupabaseClientProvider.isLocalLangGraphEnabled else { return }
        guard !didAttemptLocalLangGraphAutoLogin else { return }
        guard !isAuthenticated else { return }
        guard
            let email = SupabaseClientProvider.environmentValue("HAYF_LOCAL_AUTH_EMAIL"),
            let password = SupabaseClientProvider.environmentValue("HAYF_LOCAL_AUTH_PASSWORD")
        else {
            errorMessage = "Local LangGraph auth requires HAYF_LOCAL_AUTH_EMAIL and HAYF_LOCAL_AUTH_PASSWORD."
            return
        }

        didAttemptLocalLangGraphAutoLogin = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            updateSession(session)
        } catch {
            errorMessage = "Local LangGraph auto-login failed: \(error.localizedDescription)"
        }
        #endif
    }
}

private extension User {
    var googleDisplayName: String? {
        userMetadata["full_name"]?.stringValue
            ?? userMetadata["name"]?.stringValue
            ?? userMetadata["display_name"]?.stringValue
    }

    var googleAvatarURL: URL? {
        guard let avatarString = userMetadata["avatar_url"]?.stringValue
            ?? userMetadata["picture"]?.stringValue
        else {
            return nil
        }

        return URL(string: avatarString)
    }
}
