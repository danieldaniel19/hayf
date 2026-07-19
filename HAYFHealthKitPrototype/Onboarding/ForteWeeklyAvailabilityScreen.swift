import SwiftUI

struct ForteWeeklyAvailabilityScreen: View {
    let selectedDays: Set<Weekday>
    let selectedDayParts: Set<DayPart>
    let isFlexible: Bool
    let progressStep: Int
    let totalSteps: Int
    let onToggleDay: (Weekday) -> Void
    let onToggleDayPart: (DayPart) -> Void
    let onToggleFlexible: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

                        availabilitySection(title: "Available days") {
                            ForteWeekdaySelector(
                                selectedDays: selectedDays,
                                onToggle: onToggleDay
                            )
                        }

                        availabilitySection(title: "Available times") {
                            LazyVGrid(columns: timeColumns, spacing: 10) {
                                ForEach(DayPart.allCases) { dayPart in
                                    ForteImageChoiceTile(
                                        title: dayPart.title,
                                        assetName: dayPart.forteAssetName,
                                        isSelected: selectedDayParts.contains(dayPart),
                                        accessibilityHint: selectedDayParts.contains(dayPart)
                                            ? "Removes this available time."
                                            : "Adds this available time."
                                    ) {
                                        onToggleDayPart(dayPart)
                                    }
                                }
                            }
                        }
                        .padding(.top, 24)

                        ForteStackedChoiceList(
                            items: [
                                ForteStackedChoiceItem(
                                    id: "flexible",
                                    title: "Whenever, I’m flexible",
                                    assetName: "ForteAvailabilityFlexible"
                                )
                            ],
                            selectedIDs: isFlexible ? ["flexible"] : []
                        ) { _ in
                            onToggleFlexible()
                        }
                        .padding(.top, 18)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }

                continueAction
            }
            .frame(maxWidth: 480)
        }
    }

    private var timeColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private var canContinue: Bool {
        !selectedDays.isEmpty && !selectedDayParts.isEmpty
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
                    ForteWeeklyAvailabilityHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteWeeklyAvailabilityHeaderButton(systemName: "xmark", action: onExit)
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

            Text("When can training\nusually happen?")
                .font(ForteTypography.editorial(size: 31, relativeTo: .largeTitle))
                .tracking(-0.35)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("Choose the days and times that work.\nForte will plan around your availability.")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 22)
        }
    }

    private func availabilitySection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ForteColor.ink)

            content()
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
        .buttonStyle(ForteWeeklyAvailabilityPrimaryButtonStyle(isEnabled: canContinue))
        .disabled(!canContinue)
        .accessibilityHint(canContinue ? "Shows the next onboarding step." : "Choose at least one day and one available time first.")
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }
}

private struct ForteWeekdaySelector: View {
    let selectedDays: Set<Weekday>
    let onToggle: (Weekday) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(Weekday.allCases.enumerated()), id: \.element.id) { index, day in
                if index == 5 {
                    Rectangle()
                        .fill(ForteColor.borderSubtle)
                        .frame(width: 1, height: 28)
                        .padding(.horizontal, 3)
                        .accessibilityHidden(true)
                }

                ForteWeekdayButton(
                    day: day,
                    isSelected: selectedDays.contains(day)
                ) {
                    onToggle(day)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ForteWeekdayButton: View {
    let day: Weekday
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(day.singleLetterTitle)
                .font(.system(size: 16, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? ForteColor.indigoDeep : ForteColor.inkSoft)
                .frame(width: 42, height: 48)
                .background(isSelected ? ForteColor.indigoMist : ForteColor.surface.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected ? ForteColor.indigo.opacity(0.62) : ForteColor.borderSubtle.opacity(0.8),
                            lineWidth: isSelected ? 1.3 : 1
                        )
                }
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
        }
        .buttonStyle(ForteWeekdayButtonStyle())
        .accessibilityLabel(day.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isSelected ? "Removes this available day." : "Adds this available day.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ForteWeekdayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ForteWeeklyAvailabilityHeaderButton: View {
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

private struct ForteWeeklyAvailabilityPrimaryButtonStyle: ButtonStyle {
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
