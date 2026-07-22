import SwiftUI

struct ForteBodyFatEstimateScreen: View {
    let options: [BodyFatBand]
    let selectedBand: BodyFatBand?
    let estimatedPercentage: Double?
    let isEstimatedSelection: Bool
    let progressStep: Int
    let totalSteps: Int
    let onSelectBand: (BodyFatBand) -> Void
    let onSelectEstimate: () -> Void
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

                        VStack(spacing: 12) {
                            ForEach(options) { band in
                                ForteEditorialChoiceCard(
                                    title: band.title,
                                    subtitle: band.subtitle,
                                    assetName: band.forteAssetName,
                                    badge: band.badgeTitle,
                                    isSelected: selectedBand == band && !isEstimatedSelection,
                                    accessibilityHint: "Uses this range as your estimated baseline."
                                ) {
                                    onSelectBand(band)
                                }
                            }

                            ForteEditorialChoiceCard(
                                title: "Calculate for me",
                                subtitle: estimateSubtitle,
                                assetName: "ForteBodyFatTreeEstimate",
                                badge: "Estimate",
                                isSelected: isEstimatedSelection,
                                isEnabled: estimatedPercentage != nil,
                                accessibilityHint: estimatedPercentage == nil
                                    ? "Enter valid weight and height on the previous screen first."
                                    : "Uses Forte's profile-based estimate as your baseline."
                            ) {
                                onSelectEstimate()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                continueAction
            }
            .frame(maxWidth: 480)
        }
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
                    ForteBodyFatHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteBodyFatHeaderButton(systemName: "xmark", action: onExit)
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

            Text("Estimate your\nbody-fat range.")
                .font(ForteTypography.editorial(size: 31, relativeTo: .largeTitle))
                .tracking(-0.35)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("A range is enough. Forte will use it as\nan estimated baseline, not a measurement.")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
    }

    private var estimateSubtitle: String {
        guard let estimatedPercentage else {
            return "Add valid weight and height on the previous screen to unlock this estimate."
        }

        return "About \(Int(estimatedPercentage.rounded()))%, based on your body basics and profile."
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
        .buttonStyle(ForteBodyFatPrimaryButtonStyle(isEnabled: selectedBand != nil))
        .disabled(selectedBand == nil)
        .accessibilityHint(selectedBand == nil ? "Choose a body-fat range first." : "Shows the next onboarding step.")
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }
}

private struct ForteBodyFatHeaderButton: View {
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

private struct ForteBodyFatPrimaryButtonStyle: ButtonStyle {
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
