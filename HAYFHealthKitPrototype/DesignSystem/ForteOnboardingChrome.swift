import SwiftUI

struct ForteOnboardingPage<Content: View, Footer: View>: View {
    let progressStep: Int
    let totalSteps: Int
    let overline: String
    let title: String
    let copy: String
    let onBack: () -> Void
    let onExit: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        progressStep: Int,
        totalSteps: Int,
        overline: String = "ONBOARDING",
        title: String,
        copy: String,
        onBack: @escaping () -> Void,
        onExit: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.progressStep = progressStep
        self.totalSteps = totalSteps
        self.overline = overline
        self.title = title
        self.copy = copy
        self.onBack = onBack
        self.onExit = onExit
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ZStack {
            ForteColor.background
                .ignoresSafeArea()

            ForteOnboardingAmbientArtwork()

            VStack(spacing: 0) {
                ForteOnboardingProgressHeader(
                    progressStep: progressStep,
                    totalSteps: totalSteps,
                    onBack: onBack,
                    onExit: onExit
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForteOnboardingHero(overline: overline, title: title, copy: copy)
                        content
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)

                footer
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
            }
            .frame(maxWidth: 480)
        }
    }
}

struct ForteOnboardingHero: View {
    let overline: String
    let title: String
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(overline)
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.2)
                .foregroundStyle(ForteColor.indigoDeep)

            Text(title)
                .font(ForteTypography.editorial(size: 31, relativeTo: .largeTitle))
                .tracking(-0.35)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text(copy)
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 22)
        }
    }
}

struct ForteOnboardingProgressHeader: View {
    let progressStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index < progressStep ? ForteColor.indigoDeep : ForteColor.borderSubtle)
                        .frame(height: 3)
                }
            }

            HStack(spacing: 12) {
                Text("Step \(progressStep) of \(totalSteps)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(ForteColor.inkMuted)

                Spacer()

                HStack(spacing: 8) {
                    ForteOnboardingHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteOnboardingHeaderButton(systemName: "xmark", action: onExit)
                        .accessibilityLabel("Exit onboarding")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
}

struct ForteOnboardingHeaderButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ForteColor.indigoDeep)
                .frame(width: 44, height: 44)
                .background(ForteColor.surface.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ForteColor.borderSubtle.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.07), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct ForteOnboardingAmbientArtwork: View {
    var opacity: Double = 0.48

    var body: some View {
        GeometryReader { geometry in
            let artworkWidth = min(164, geometry.size.width * 0.39)

            Image("ForteBalancedObjectsIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: artworkWidth)
                .position(
                    x: geometry.size.width * 0.89,
                    y: min(286, geometry.size.height * 0.30)
                )
                .opacity(opacity)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct ForteOnboardingPrimaryAction: View {
    let title: String
    let isEnabled: Bool
    var accessibilityHint: String = "Shows the next onboarding step."
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .regular))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isEnabled ? Color.white : ForteColor.inkMuted)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(isEnabled ? ForteColor.indigo : ForteColor.surfaceDisabled)
            .clipShape(Capsule())
            .shadow(color: isEnabled ? ForteColor.indigoDeep.opacity(0.18) : .clear, radius: 10, y: 5)
        }
        .buttonStyle(ForteOnboardingPrimaryButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
        .accessibilityHint(accessibilityHint)
    }
}

struct ForteOnboardingSecondaryAction: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isEnabled ? ForteColor.indigoDeep : ForteColor.inkMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(ForteColor.surface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(ForteColor.borderSubtle, lineWidth: 1)
            }
            .disabled(!isEnabled)
    }
}

private struct ForteOnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled ? 0.992 : 1)
            .opacity(configuration.isPressed && isEnabled ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ForteSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.4)
            .foregroundStyle(ForteColor.inkMuted)
    }
}
