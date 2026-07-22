import SwiftUI

struct ForteBodyBasicsScreen: View {
    @Binding var bodyMassKilogramsInput: String
    @Binding var heightCentimetersInput: String
    let progressStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    private let weightOptions = (25...250).map(ForteMeasurementOption.init)
    private let heightOptions = (100...230).map(ForteMeasurementOption.init)

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
                        bodyMeasurementSelector
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                continueAction
            }
            .frame(maxWidth: 480)
        }
        .onAppear(perform: normalizeInputs)
    }

    private var weightSelection: Binding<ForteMeasurementOption> {
        Binding(
            get: { ForteMeasurementOption(value: parsedValue(bodyMassKilogramsInput, in: 25...250) ?? 70) },
            set: { bodyMassKilogramsInput = String($0.value) }
        )
    }

    private var heightSelection: Binding<ForteMeasurementOption> {
        Binding(
            get: { ForteMeasurementOption(value: parsedValue(heightCentimetersInput, in: 100...230) ?? 173) },
            set: { heightCentimetersInput = String($0.value) }
        )
    }

    private var hasValidSelection: Bool {
        parsedValue(bodyMassKilogramsInput, in: 25...250) != nil
            && parsedValue(heightCentimetersInput, in: 100...230) != nil
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
                    ForteBodyBasicsHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteBodyBasicsHeaderButton(systemName: "xmark", action: onExit)
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

            Text("Let’s set your\ncurrent baseline.")
                .font(ForteTypography.editorial(size: 31, relativeTo: .largeTitle))
                .tracking(-0.35)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("Health imports can be stale. These answers\nset a baseline Forte can trust today.")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 28)
        }
    }

    private var bodyMeasurementSelector: some View {
        HStack(alignment: .top, spacing: 0) {
            ForteBodyBasicsColumn(title: "Weight") {
                ForteWheelSelector(
                    options: weightOptions,
                    selection: weightSelection,
                    title: { "\($0.value) kg" },
                    accessibilityLabel: "Current weight"
                )
            }

            Rectangle()
                .fill(ForteColor.borderSubtle.opacity(0.74))
                .frame(width: 1, height: 150)
                .padding(.horizontal, 8)
                .padding(.top, 12)

            ForteBodyBasicsColumn(title: "Height") {
                ForteWheelSelector(
                    options: heightOptions,
                    selection: heightSelection,
                    title: { "\($0.value) cm" },
                    accessibilityLabel: "Current height"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(ForteColor.surface.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity)
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
        .buttonStyle(ForteBodyBasicsPrimaryButtonStyle(isEnabled: hasValidSelection))
        .disabled(!hasValidSelection)
        .accessibilityHint(hasValidSelection ? "Shows the next onboarding step." : "Choose both body measurements first.")
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }

    private func parsedValue(_ input: String, in range: ClosedRange<Int>) -> Int? {
        guard let number = Double(input.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let value = Int(number.rounded())
        return range.contains(value) ? value : nil
    }

    private func normalizeInputs() {
        bodyMassKilogramsInput = String(parsedValue(bodyMassKilogramsInput, in: 25...250) ?? 70)
        heightCentimetersInput = String(parsedValue(heightCentimetersInput, in: 100...230) ?? 173)
    }
}

private struct ForteMeasurementOption: Identifiable, Hashable {
    let value: Int
    var id: Int { value }
}

private struct ForteBodyBasicsColumn<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ForteColor.inkSoft)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            content()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ForteBodyBasicsHeaderButton: View {
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

private struct ForteBodyBasicsPrimaryButtonStyle: ButtonStyle {
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
