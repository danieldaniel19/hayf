import SwiftUI

struct AuthScreen: View {
    let mode: AuthMode
    let isLoading: Bool
    let errorMessage: String?
    let switchMode: () -> Void
    let onGoogleAuth: () -> Void

    private let sidePadding: CGFloat = 30
    private let topPadding: CGFloat = 48
    private let logoToCopySpacing: CGFloat = 54

    init(
        mode: AuthMode,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        switchMode: @escaping () -> Void,
        onGoogleAuth: @escaping () -> Void = {}
    ) {
        self.mode = mode
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.switchMode = switchMode
        self.onGoogleAuth = onGoogleAuth
    }

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HAYFLogo()
                    .padding(.top, topPadding)

                VStack(alignment: .leading, spacing: 0) {
                    Text(mode.eyebrow)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .kerning(3.6)
                        .foregroundStyle(HAYFColor.secondary)
                        .padding(.top, logoToCopySpacing)

                    Text(mode.headline)
                        .font(.system(size: 54, weight: .bold, design: .default))
                        .lineSpacing(-4)
                        .foregroundStyle(HAYFColor.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.82)
                        .padding(.top, 22)

                    Rectangle()
                        .fill(HAYFColor.orange)
                        .frame(width: 34, height: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .padding(.top, 26)

                    Text(mode.bodyCopy)
                        .font(.system(size: 20, weight: .regular, design: .default))
                        .lineSpacing(4)
                        .foregroundStyle(HAYFColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 28)
                }

                Spacer(minLength: 22)

                VStack(spacing: 12) {
                    AuthProviderButton(
                        title: mode.googleTitle,
                        provider: .google,
                        isLoading: isLoading,
                        action: onGoogleAuth
                    )
                    AuthProviderButton(title: mode.appleTitle, provider: .apple)
                    AuthProviderButton(title: mode.emailTitle, provider: .email)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundStyle(HAYFColor.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }

                OrDivider()
                    .padding(.top, 32)

                ModeSwitchPrompt(mode: mode, switchMode: switchMode)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)

                Spacer(minLength: 20)

                LegalCopy()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, sidePadding)
            .frame(maxWidth: 480)
        }
    }
}

private enum AuthProvider {
    case google
    case apple
    case email
}

private struct AuthProviderButton: View {
    let title: String
    let provider: AuthProvider
    var isLoading = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                icon
                    .frame(width: 36, height: 36)

                Group {
                    if isLoading {
                        ProgressView()
                            .tint(HAYFColor.primary)
                    } else {
                        Text(title)
                            .font(.system(size: 19, weight: .regular, design: .default))
                            .foregroundStyle(HAYFColor.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.trailing, 36)
            }
            .padding(.leading, 25)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(HAYFColor.neutral)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var icon: some View {
        switch provider {
        case .google:
            Image("GoogleLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 31, height: 31)
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.black)
        case .email:
            EmailAuthIcon()
                .frame(width: 31, height: 24)
        }
    }
}

private struct EmailAuthIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(HAYFColor.orange, lineWidth: 2)

            Path { path in
                path.move(to: CGPoint(x: 2.5, y: 4.5))
                path.addLine(to: CGPoint(x: 15.5, y: 14))
                path.addLine(to: CGPoint(x: 28.5, y: 4.5))
            }
            .stroke(HAYFColor.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct OrDivider: View {
    var body: some View {
        HStack(spacing: 24) {
            Rectangle()
                .fill(HAYFColor.border)
                .frame(height: 1)

            Text("OR")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(HAYFColor.muted)

            Rectangle()
                .fill(HAYFColor.border)
                .frame(height: 1)
        }
    }
}

private struct ModeSwitchPrompt: View {
    let mode: AuthMode
    let switchMode: () -> Void

    var body: some View {
        Button(action: switchMode) {
            (
                Text("\(mode.switchPrompt) ")
                    .foregroundStyle(HAYFColor.secondary)
                +
                Text(mode.switchAction)
                    .foregroundStyle(HAYFColor.orange)
            )
            .font(.system(size: 18, weight: .regular, design: .default))
        }
        .buttonStyle(.plain)
    }
}

private struct LegalCopy: View {
    var body: some View {
        (
            Text("By continuing, you agree to our ")
            +
            Text("Terms of Service")
                .underline()
            +
            Text("\nand acknowledge our ")
            +
            Text("Privacy Policy.")
                .underline()
        )
            .font(.system(size: 15, weight: .regular, design: .default))
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .foregroundStyle(HAYFColor.muted)
    }
}

#Preview("Sign in") {
    AuthScreen(mode: .signIn, switchMode: {}) {}
}

#Preview("Create account") {
    AuthScreen(mode: .signUp, switchMode: {}) {}
}
