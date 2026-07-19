import SwiftUI

struct ForteWeeklyCapacityScreen: View {
    let intent: OnboardingIntent
    @Binding var frequency: TrainingFrequency?
    @Binding var sessionLength: SessionLength?
    let progressStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ForteColor.background
                .ignoresSafeArea()

            balancedObjectsBackground

            VStack(spacing: 0) {
                progressHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero
                        weeklyRhythmSelector
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                continueAction
            }
            .frame(maxWidth: 480)
        }
        .onAppear {
            frequency = frequency ?? .three
            sessionLength = sessionLength ?? .thirty
        }
    }

    private var frequencySelection: Binding<TrainingFrequency> {
        Binding(
            get: { frequency ?? .three },
            set: { frequency = $0 }
        )
    }

    private var sessionLengthSelection: Binding<SessionLength> {
        Binding(
            get: { sessionLength ?? .thirty },
            set: { sessionLength = $0 }
        )
    }

    private var balancedObjectsBackground: some View {
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
                .opacity(0.52)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var progressHeader: some View {
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
                    ForteWeeklyCapacityHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteWeeklyCapacityHeaderButton(systemName: "xmark", action: onExit)
                        .accessibilityLabel("Exit onboarding")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ONBOARDING")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.4)
                .foregroundStyle(ForteColor.indigoDeep)

            Text("What feels realistic\nmost weeks?")
                .font(ForteTypography.editorial(size: 31, relativeTo: .largeTitle))
                .tracking(-0.35)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("Choose a rhythm you can count on.\nForte can adapt when plans change.")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
    }

    private var weeklyRhythmSelector: some View {
        HStack(alignment: .top, spacing: 0) {
            ForteWeeklyCapacityColumn(
                title: intent == .concreteGoal ? "Total days / week" : "Days per week"
            ) {
                ForteWheelSelector(
                    options: TrainingFrequency.allCases,
                    selection: frequencySelection,
                    title: \.title,
                    accessibilityLabel: "Training days per week"
                )
            }

            Rectangle()
                .fill(ForteColor.borderSubtle.opacity(0.74))
                .frame(width: 1, height: 190)
                .padding(.top, 14)

            ForteWeeklyCapacityColumn(title: "Session length") {
                ForteWheelSelector(
                    options: SessionLength.allCases,
                    selection: sessionLengthSelection,
                    title: \.title,
                    accessibilityLabel: "Typical session length"
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(ForteColor.surface.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)
    }

    private var continueAction: some View {
        let isEnabled = frequency != nil && sessionLength != nil

        return Button(action: onContinue) {
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
        .buttonStyle(ForteWeeklyCapacityPrimaryButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
        .accessibilityHint(isEnabled ? "Shows the next onboarding step." : "Choose both weekly rhythm values first.")
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }
}

private struct ForteWeeklyCapacityColumn<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ForteColor.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 8)

            content()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ForteWeeklyCapacityHeaderButton: View {
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

private struct ForteWeeklyCapacityPrimaryButtonStyle: ButtonStyle {
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
