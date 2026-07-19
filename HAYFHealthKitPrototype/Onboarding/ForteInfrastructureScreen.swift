import SwiftUI

struct ForteInfrastructureScreen: View {
    let options: [InfrastructureAccess]
    let selectedOptions: Set<InfrastructureAccess>
    let progressStep: Int
    let totalSteps: Int
    let onToggle: (InfrastructureAccess) -> Void
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

                        ForteStackedChoiceList(
                            items: choiceItems,
                            selectedIDs: Set(selectedOptions.map(\.id))
                        ) { id in
                            guard let option = options.first(where: { $0.id == id }) else { return }
                            onToggle(option)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }

                continueAction
            }
            .frame(maxWidth: 480)
        }
    }

    private var choiceItems: [ForteStackedChoiceItem] {
        options.map {
            ForteStackedChoiceItem(
                id: $0.id,
                title: $0.title,
                assetName: $0.forteAssetName
            )
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
                    ForteInfrastructureHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteInfrastructureHeaderButton(systemName: "xmark", action: onExit)
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

            Text("What do you\nhave access to?")
                .font(ForteTypography.editorial(size: 31, relativeTo: .largeTitle))
                .tracking(-0.35)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("Forte will only build around equipment\nand environments you can reliably use.")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 18)
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
        .buttonStyle(ForteInfrastructurePrimaryButtonStyle(isEnabled: !selectedOptions.isEmpty))
        .disabled(selectedOptions.isEmpty)
        .accessibilityHint(selectedOptions.isEmpty ? "Select at least one access option first." : "Shows the next onboarding step.")
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }
}

private struct ForteInfrastructureHeaderButton: View {
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

private struct ForteInfrastructurePrimaryButtonStyle: ButtonStyle {
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
