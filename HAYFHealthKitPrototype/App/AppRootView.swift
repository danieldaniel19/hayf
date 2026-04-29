import SwiftUI

struct AppRootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var accountProfileStore = AccountProfileStore()
    @State private var authMode: AuthMode = .signIn
    @State private var createdProfilePendingFinish: StoredAccountProfile?

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if accountProfileStore.isLoading {
                    AccountProfileLoadingView()
                } else if let accountProfile = accountProfileStore.profile {
                    AuthenticatedHomeView(
                        userEmail: authViewModel.userEmail,
                        displayName: accountProfile.name,
                        signOut: signOut
                    )
                } else {
                    AccountCreationView(
                        prefilledName: authViewModel.userDisplayName,
                        prefilledAvatarURL: authViewModel.userAvatarURL,
                        onCreate: { profile in
                            let createdProfile = try await accountProfileStore.createCurrentUserProfile(from: profile)
                            createdProfilePendingFinish = createdProfile
                        },
                        onFinish: {
                            if let createdProfilePendingFinish {
                                accountProfileStore.useProfile(createdProfilePendingFinish)
                            }
                        }
                    )
                }
            } else {
                AuthScreen(
                    mode: authMode,
                    isLoading: authViewModel.isLoading,
                    errorMessage: authViewModel.errorMessage,
                    switchMode: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            authMode = authMode.alternate
                        }
                    },
                    onGoogleAuth: authViewModel.signInWithGoogle
                )
            }
        }
        .task {
            await authViewModel.startAuthStateListener()
        }
        .task(id: authViewModel.userID) {
            if authViewModel.userID != nil {
                await accountProfileStore.loadCurrentUserProfile()
            } else {
                accountProfileStore.reset()
                createdProfilePendingFinish = nil
            }
        }
    }

    private func signOut() {
        accountProfileStore.reset()
        createdProfilePendingFinish = nil
        authViewModel.signOut()
    }
}

private struct AccountProfileLoadingView: View {
    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HAYFLogo(markSize: 28, textSize: 24, spacing: 8)

                ProgressView()
                    .tint(HAYFColor.orange)
            }
        }
    }
}

#Preview {
    AppRootView()
}
