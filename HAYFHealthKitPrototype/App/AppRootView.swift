import SwiftUI

struct AppRootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var accountProfileStore = AccountProfileStore()
    @StateObject private var onboardingProfileStore = OnboardingProfileStore()
    @State private var authMode: AuthMode = .signIn
    @State private var createdProfilePendingFinish: StoredAccountProfile?
    @State private var updatedProfilePendingFinish: StoredAccountProfile?
    @State private var isRestartingAccountCreation = false

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if accountProfileStore.isLoading || onboardingProfileStore.isLoading {
                    AccountProfileLoadingView()
                } else if let accountProfile = accountProfileStore.profile {
                    if isRestartingAccountCreation {
                        AccountCreationView(
                            existingProfile: accountProfile,
                            onCreate: { profile in
                                let updatedProfile = try await accountProfileStore.updateCurrentUserProfile(from: profile, existingProfile: accountProfile)
                                updatedProfilePendingFinish = updatedProfile
                            },
                            onFinish: {
                                if let updatedProfilePendingFinish {
                                    accountProfileStore.useProfile(updatedProfilePendingFinish)
                                }
                                updatedProfilePendingFinish = nil
                                isRestartingAccountCreation = false
                            }
                        )
                    } else if shouldShowOnboarding(for: accountProfile) {
                        OnboardingFlowView(onboardingProfileStore: onboardingProfileStore) {}
                    } else {
                        AuthenticatedHomeView(
                            userEmail: authViewModel.userEmail,
                            displayName: accountProfile.name,
                            restartAccountCreation: {
                                updatedProfilePendingFinish = nil
                                isRestartingAccountCreation = true
                            },
                            restartOnboarding: {
                                Task {
                                    try? await onboardingProfileStore.clearCurrentUserOnboardingProfile()
                                }
                            },
                            signOut: signOut
                        )
                    }
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
                await onboardingProfileStore.loadCurrentUserOnboardingProfile()
            } else {
                accountProfileStore.reset()
                onboardingProfileStore.reset()
                createdProfilePendingFinish = nil
                updatedProfilePendingFinish = nil
                isRestartingAccountCreation = false
            }
        }
    }

    private func shouldShowOnboarding(for profile: StoredAccountProfile) -> Bool {
        onboardingProfileStore.profile?.id != profile.id
    }

    private func signOut() {
        accountProfileStore.reset()
        onboardingProfileStore.reset()
        createdProfilePendingFinish = nil
        updatedProfilePendingFinish = nil
        isRestartingAccountCreation = false
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
