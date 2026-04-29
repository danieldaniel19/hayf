import SwiftUI

struct AuthenticatedHomeView: View {
    let userEmail: String?
    let signOut: () -> Void

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                HAYFLogo()

                VStack(alignment: .leading, spacing: 12) {
                    Text("You're in.")
                        .font(.system(size: 44, weight: .bold, design: .default))
                        .foregroundStyle(HAYFColor.primary)

                    Text(userEmail ?? "Google auth completed.")
                        .font(.system(size: 18, weight: .regular, design: .default))
                        .foregroundStyle(HAYFColor.secondary)
                }

                Button(action: signOut) {
                    Text("Sign out")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(HAYFColor.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 48)
            .frame(maxWidth: 480)
        }
    }
}

#Preview {
    AuthenticatedHomeView(userEmail: "you@example.com") {}
}
