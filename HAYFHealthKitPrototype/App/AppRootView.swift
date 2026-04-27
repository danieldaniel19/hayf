import SwiftUI

struct AppRootView: View {
    @State private var authMode: AuthMode = .signIn

    var body: some View {
        AuthScreen(mode: authMode) {
            withAnimation(.easeInOut(duration: 0.22)) {
                authMode = authMode.alternate
            }
        }
    }
}

#Preview {
    AppRootView()
}
