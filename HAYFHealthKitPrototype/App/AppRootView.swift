import SwiftUI

struct AppRootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var authMode: AuthMode = .signIn

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                AuthenticatedHomeView(
                    userEmail: authViewModel.userEmail,
                    signOut: authViewModel.signOut
                )
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
    }
}

#Preview {
    AppRootView()
}
