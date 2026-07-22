import SwiftUI

struct ForteIntentScreen: View {
    @Binding var selectedIntent: OnboardingIntent?
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ForteColor.background
                .ignoresSafeArea()

            balancedObjectsBackground

            VStack(spacing: 0) {
                closeHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero

                        VStack(spacing: 12) {
                            ForEach(OnboardingIntent.allCases) { intent in
                                ForteEditorialChoiceCard(
                                    title: intent.title,
                                    subtitle: intent.subtitle,
                                    assetName: intent.forteAssetName,
                                    isSelected: selectedIntent == intent,
                                    accessibilityHint: "Selects this training setup."
                                ) {
                                    selectedIntent = intent
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                }

                continueAction
            }
            .frame(maxWidth: 480)
        }
    }

    private var balancedObjectsBackground: some View {
        GeometryReader { geometry in
            let artworkWidth = min(220, geometry.size.width * 0.52)

            Image("ForteBalancedObjectsIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: artworkWidth)
                .position(
                    x: geometry.size.width * 0.83,
                    y: min(235, geometry.size.height * 0.26)
                )
                .opacity(0.96)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var closeHeader: some View {
        HStack {
            Spacer()

            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ForteColor.indigoDeep)
                    .frame(width: 48, height: 48)
                    .background(ForteColor.surface.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.black.opacity(0.09), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exit onboarding")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ONBOARDING")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.4)
                .foregroundStyle(ForteColor.indigoDeep)

            Text("What kind of\nhelp do you want?")
                .font(ForteTypography.editorial(size: 34, relativeTo: .largeTitle))
                .tracking(-0.4)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            Text("Forte will adapt the setup based\non how you want to train.")
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(6)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
    }

    private var continueAction: some View {
        Button(action: onContinue) {
            HStack(spacing: 12) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .regular))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
        }
        .buttonStyle(FortePrimaryButtonStyle(isEnabled: selectedIntent != nil))
        .disabled(selectedIntent == nil)
        .accessibilityHint(selectedIntent == nil ? "Select a kind of help first." : "Shows the next onboarding step.")
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }
}

private struct FortePrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.white : ForteColor.inkMuted)
            .background(buttonColor(isPressed: configuration.isPressed))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed && isEnabled ? 0.992 : 1)
            .shadow(
                color: isEnabled ? ForteColor.indigoDeep.opacity(0.18) : .clear,
                radius: 10,
                y: 5
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func buttonColor(isPressed: Bool) -> Color {
        guard isEnabled else { return ForteColor.surfaceDisabled }
        return isPressed ? ForteColor.indigoDeep : ForteColor.indigo
    }
}

private extension OnboardingIntent {
    var forteAssetName: String {
        switch self {
        case .stayConsistent:
            return "ForteIntentConsistency"
        case .concreteGoal:
            return "ForteIntentSpecificGoal"
        case .findGoal:
            return "ForteIntentFindGoal"
        }
    }
}
