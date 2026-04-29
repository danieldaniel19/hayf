import SwiftUI

struct AuthenticatedHomeView: View {
    let userEmail: String?
    let displayName: String?
    let restartAccountCreation: () -> Void
    let restartOnboarding: () -> Void
    let signOut: () -> Void

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                HAYFLogo()

                VStack(alignment: .leading, spacing: 12) {
                    Text(displayName.map { "You're in,\n\($0)." } ?? "You're in.")
                        .font(.system(size: 44, weight: .bold, design: .default))
                        .foregroundStyle(HAYFColor.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(userEmail ?? "Google auth completed.")
                        .font(.system(size: 18, weight: .regular, design: .default))
                        .foregroundStyle(HAYFColor.secondary)
                }

                VStack(spacing: 12) {
                    TesterHomeButton(title: "Restart account creation", systemImage: "person.crop.circle.badge.plus", action: restartAccountCreation)
                    TesterHomeButton(title: "Restart onboarding", systemImage: "arrow.triangle.2.circlepath", action: restartOnboarding)

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
                }

                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 48)
            .frame(maxWidth: 480)
        }
    }
}

private struct TesterHomeButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(HAYFColor.orange)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuthenticatedHomeView(
        userEmail: "you@example.com",
        displayName: "Daniel",
        restartAccountCreation: {},
        restartOnboarding: {},
        signOut: {}
    )
}
