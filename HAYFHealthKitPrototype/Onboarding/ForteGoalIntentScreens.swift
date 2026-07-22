import SwiftUI

enum ForteGoalCandidateSelectionMode {
    case single
    case multiple
}

enum ForteGoalCandidateVisualRole: CaseIterable, Equatable {
    case running
    case cycling
    case strength
    case sport
    case blended
    case general

    init(candidate: GoalCandidate) {
        let signal = "\(candidate.id) \(candidate.title) \(candidate.systemImage)".lowercased()

        if signal.contains("blend") || signal.contains("curvedto") {
            self = .blended
        } else if signal.contains("cycl") || signal.contains("bike") || signal.contains("speedometer") {
            self = .cycling
        } else if signal.contains("strength") || signal.contains("dumbbell") {
            self = .strength
        } else if signal.contains("run") || signal.contains("10k") || signal.contains("5k") || signal.contains("marathon") {
            self = .running
        } else if signal.contains("sport") || signal.contains("court") || signal.contains("ball") {
            self = .sport
        } else {
            self = .general
        }
    }

    var forteAssetName: String {
        switch self {
        case .running: return "ForteModalityRunning"
        case .cycling: return "ForteModalityCycling"
        case .strength: return "ForteModalityStrength"
        case .sport: return "ForteModalityFootball"
        case .blended: return "ForteSupportExplainTradeoff"
        case .general: return "ForteIntentFindGoal"
        }
    }
}

extension GoalExperience {
    var forteAssetName: String {
        switch self {
        case .underOneYear: return "ForteExperienceUnderOneYear"
        case .oneToThreeYears: return "ForteExperienceOneToThreeYears"
        case .threeToFiveYears: return "ForteExperienceThreeToFiveYears"
        case .fivePlusYears: return "ForteExperienceFivePlusYears"
        }
    }
}

extension GoalPriority {
    var forteAssetName: String {
        switch self {
        case .goalProgress: return "FortePriorityGoalProgress"
        case .stayingBalanced: return "FortePriorityBalance"
        case .avoidInjury: return "FortePriorityInjuryProtection"
        case .preserveStrength: return "FortePriorityPreserveTraining"
        }
    }
}

extension GoalDirection {
    var forteAssetName: String {
        switch self {
        case .moreAthletic: return "ForteDirectionAthletic"
        case .stronger: return "ForteDirectionStrength"
        case .betterEndurance: return "ForteDirectionEndurance"
        case .sportReady: return "ForteDirectionSport"
        }
    }
}

extension ChallengeStyle {
    var forteAssetName: String {
        switch self {
        case .numbersTargets: return "ForteChallengeNumbers"
        case .eventsDeadlines: return "ForteChallengeDeadline"
        case .skillProgression: return "ForteChallengeSkill"
        case .competeWithSelf: return "ForteChallengeSelf"
        }
    }
}

extension GoalAvoidance {
    var forteAssetName: String {
        switch self {
        case .running: return "ForteModalityRunning"
        case .heavyLifting: return "ForteModalityStrength"
        case .longWorkouts: return "ForteIntentSpecificGoal"
        case .strictPlans: return "ForteBlockerNoPlan"
        case .highIntensity: return "ForteBlockerLowEnergy"
        case .gymDependence: return "ForteAccessHomeWeights"
        case .nothingSpecific: return "ForteAvailabilityFlexible"
        }
    }
}

struct ForteGoalBriefScreen: View {
    @Binding var goalBrief: String
    let progressStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            title: "What are you\nworking toward?",
            copy: "Say it naturally. Forte will pull out the target, timeline, and anything that needs clarifying.",
            onBack: onBack,
            onExit: onExit
        ) {
            ForteTextArea(
                title: "Goal brief",
                placeholder: "Run a half marathon under 2 hours in October while keeping some strength.",
                text: $goalBrief,
                characterLimit: 280
            )
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Continue",
                isEnabled: !goalBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                accessibilityHint: "Enter your goal before continuing.",
                action: onContinue
            )
        }
    }
}

struct ForteGoalExperienceScreen: View {
    let selectedExperience: GoalExperience?
    let progressStep: Int
    let totalSteps: Int
    let onSelect: (GoalExperience) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            title: "How long have\nyou trained?",
            copy: "Forte will combine this with your workout history later to understand your starting point.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(spacing: 12) {
                ForEach(GoalExperience.allCases) { experience in
                    ForteEditorialChoiceCard(
                        title: experience.title,
                        subtitle: experience.forteSubtitle,
                        assetName: experience.forteAssetName,
                        isSelected: selectedExperience == experience
                    ) {
                        onSelect(experience)
                    }
                }
            }
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Continue",
                isEnabled: selectedExperience != nil,
                accessibilityHint: "Select your experience before continuing.",
                action: onContinue
            )
        }
    }
}

private extension GoalExperience {
    var forteSubtitle: String {
        switch self {
        case .underOneYear: return "You’re still building your training base."
        case .oneToThreeYears: return "You have some history and room to learn."
        case .threeToFiveYears: return "You already have a solid training base."
        case .fivePlusYears: return "You bring long-term training experience."
        }
    }
}

struct ForteGoalTimelineScreen: View {
    @Binding var selectedTimeline: GoalTimeline?
    @Binding var goalDate: Date
    let progressStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            title: "What horizon\nare we coaching?",
            copy: "Choose a useful horizon, or set the date your goal needs to work toward.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForteSectionLabel(title: "Timeline")

                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        ForEach(GoalTimeline.allCases) { timeline in
                            ForteCompactChoiceButton(
                                title: timeline.title,
                                isSelected: selectedTimeline == timeline
                            ) {
                                selectedTimeline = timeline
                            }
                        }
                    }

                    if selectedTimeline == .specificDate {
                        Divider()
                            .overlay(ForteColor.borderSubtle)

                        HStack(spacing: 12) {
                            Image("ForteStrategyCadence")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .accessibilityHidden(true)

                            Text("Goal date")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ForteColor.ink)

                            Spacer()

                            DatePicker(
                                "Goal date",
                                selection: $goalDate,
                                in: Date.now...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .tint(ForteColor.indigo)
                        }
                    }
                }
                .padding(16)
                .background(ForteColor.surface.opacity(0.98))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(ForteColor.borderSubtle.opacity(0.78), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.045), radius: 12, y: 5)
            }
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Continue",
                isEnabled: selectedTimeline != nil,
                accessibilityHint: "Select a timeline before continuing.",
                action: onContinue
            )
        }
    }
}

struct ForteGoalPriorityScreen: View {
    let selectedPriority: GoalPriority?
    let progressStep: Int
    let totalSteps: Int
    let onSelect: (GoalPriority) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            title: "What should Forte\nprotect first?",
            copy: "This gives Forte a clear rule for making tradeoffs when a week gets tight.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(spacing: 12) {
                ForEach(GoalPriority.allCases) { priority in
                    ForteEditorialChoiceCard(
                        title: priority.title,
                        subtitle: priority.forteSubtitle,
                        assetName: priority.forteAssetName,
                        isSelected: selectedPriority == priority
                    ) {
                        onSelect(priority)
                    }
                }
            }
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Continue",
                isEnabled: selectedPriority != nil,
                accessibilityHint: "Select a priority before continuing.",
                action: onContinue
            )
        }
    }
}

private extension GoalPriority {
    var forteSubtitle: String {
        switch self {
        case .goalProgress: return "Protect sessions that move your goal."
        case .stayingBalanced: return "Keep training broad across the week."
        case .avoidInjury: return "Choose the safer path when tradeoffs appear."
        case .preserveStrength: return "Preserve your strength and cardio base."
        }
    }
}

struct ForteGoalDirectionScreen: View {
    let selectedDirection: GoalDirection?
    let progressStep: Int
    let totalSteps: Int
    let onSelect: (GoalDirection) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            title: "What kind of change\nwould feel exciting?",
            copy: "Forte will use this as the emotional direction before shaping a concrete goal.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(spacing: 12) {
                ForEach(GoalDirection.allCases) { direction in
                    ForteEditorialChoiceCard(
                        title: direction.title,
                        subtitle: direction.subtitle,
                        assetName: direction.forteAssetName,
                        isSelected: selectedDirection == direction
                    ) {
                        onSelect(direction)
                    }
                }
            }
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Continue",
                isEnabled: selectedDirection != nil,
                accessibilityHint: "Select a direction before continuing.",
                action: onContinue
            )
        }
    }
}

struct ForteChallengeStyleScreen: View {
    let selectedStyle: ChallengeStyle?
    let progressStep: Int
    let totalSteps: Int
    let onSelect: (ChallengeStyle) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            title: "What kind of challenge\nkeeps you interested?",
            copy: "Different goals motivate differently. Pick the style that feels easiest to care about.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(spacing: 12) {
                ForEach(ChallengeStyle.allCases) { style in
                    ForteEditorialChoiceCard(
                        title: style.title,
                        subtitle: style.subtitle,
                        assetName: style.forteAssetName,
                        isSelected: selectedStyle == style
                    ) {
                        onSelect(style)
                    }
                }
            }
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Continue",
                isEnabled: selectedStyle != nil,
                accessibilityHint: "Select a challenge style before continuing.",
                action: onContinue
            )
        }
    }
}

struct ForteGoalAvoidanceScreen: View {
    let selectedAvoidances: Set<GoalAvoidance>
    let progressStep: Int
    let totalSteps: Int
    let onToggle: (GoalAvoidance) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            title: "What should Forte\navoid building around?",
            copy: "This keeps the goal ideas useful for your life, not just impressive on paper.",
            onBack: onBack,
            onExit: onExit
        ) {
            ForteStackedChoiceList(
                items: GoalAvoidance.onboardingCases.map {
                    ForteStackedChoiceItem(id: $0.id, title: $0.title, assetName: $0.forteAssetName)
                },
                selectedIDs: Set(selectedAvoidances.map(\.id))
            ) { id in
                guard let avoidance = GoalAvoidance.onboardingCases.first(where: { $0.id == id }) else { return }
                onToggle(avoidance)
            }
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Continue",
                isEnabled: !selectedAvoidances.isEmpty,
                accessibilityHint: "Select at least one answer before continuing.",
                action: onContinue
            )
        }
    }
}

struct ForteGoalIntensityScreen: View {
    let selectedIntensity: GoalIntensity
    let progressStep: Int
    let totalSteps: Int
    let onSelect: (GoalIntensity) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            title: "How ambitious should\nyour goal feel?",
            copy: "Choose how much challenge Forte should build into the directions it suggests.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(spacing: 18) {
                ForteGoalIntensitySelector(selection: selectedIntensity, onSelectionChanged: onSelect)

                HStack(alignment: .top, spacing: 12) {
                    Image("ForteStrategyPriority")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(selectedIntensity.title)
                            .font(ForteTypography.editorial(size: 18, relativeTo: .headline))
                            .foregroundStyle(ForteColor.ink)

                        Text(selectedIntensity.forteExplanation)
                            .font(.system(size: 14, weight: .regular))
                            .lineSpacing(3)
                            .foregroundStyle(ForteColor.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(ForteColor.indigoMist)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        } footer: {
            ForteOnboardingPrimaryAction(title: "Continue", isEnabled: true, action: onContinue)
        }
    }
}

private extension GoalIntensity {
    var forteExplanation: String {
        explanation.replacingOccurrences(of: "HAYF", with: "Forte")
    }
}

private struct ForteGoalIntensitySelector: View {
    let selection: GoalIntensity
    let onSelectionChanged: (GoalIntensity) -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(GoalIntensity.allCases) { intensity in
                    VStack(spacing: 4) {
                        Text("\(intensity.level + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text(intensity.title)
                            .font(.system(size: 12, weight: selection == intensity ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }
                    .foregroundStyle(selection == intensity ? ForteColor.indigoDeep : ForteColor.inkMuted)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectionChanged(intensity) }
                }
            }
            .accessibilityHidden(true)

            GeometryReader { geometry in
                let thumbDiameter: CGFloat = 28
                let leading = thumbDiameter / 2
                let usableWidth = max(0, geometry.size.width - thumbDiameter)
                let fraction = CGFloat(selection.rawValue) / CGFloat(GoalIntensity.allCases.count - 1)
                let thumbX = leading + (usableWidth * fraction)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ForteColor.surfaceRaised)
                        .frame(height: 5)
                        .padding(.horizontal, leading)

                    Capsule()
                        .fill(ForteColor.indigo)
                        .frame(width: max(0, thumbX - leading), height: 5)
                        .offset(x: leading)

                    ForEach(GoalIntensity.allCases) { intensity in
                        let markerFraction = CGFloat(intensity.rawValue) / CGFloat(GoalIntensity.allCases.count - 1)
                        let markerX = leading + (usableWidth * markerFraction)

                        Circle()
                            .fill(intensity.rawValue <= selection.rawValue ? ForteColor.indigo : ForteColor.surfaceRaised)
                            .frame(width: 8, height: 8)
                            .position(x: markerX, y: geometry.size.height / 2)
                    }

                    Circle()
                        .fill(ForteColor.indigo)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .overlay { Circle().fill(.white).frame(width: 8, height: 8) }
                        .shadow(color: ForteColor.indigoDeep.opacity(0.20), radius: 6, y: 3)
                        .position(x: thumbX, y: geometry.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let normalized = Double((value.location.x - leading) / max(1, usableWidth))
                            onSelectionChanged(GoalIntensity.nearest(to: normalized * 3))
                        }
                )
            }
            .frame(height: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Goal ambition")
            .accessibilityValue(selection.title)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    onSelectionChanged(GoalIntensity(rawValue: min(3, selection.rawValue + 1)) ?? selection)
                case .decrement:
                    onSelectionChanged(GoalIntensity(rawValue: max(0, selection.rawValue - 1)) ?? selection)
                @unknown default:
                    break
                }
            }
        }
        .padding(18)
        .background(ForteColor.surface.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.045), radius: 12, y: 5)
        .animation(.easeOut(duration: 0.16), value: selection)
    }
}

private struct ForteCompactChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? ForteColor.indigoDeep : ForteColor.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? ForteColor.indigoSoft : ForteColor.surfaceRaised)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? ForteColor.indigo.opacity(0.38) : Color.clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ForteGoalCandidateCard: View {
    let candidate: GoalCandidate
    let isSelected: Bool
    let selectionMode: ForteGoalCandidateSelectionMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(ForteGoalCandidateVisualRole(candidate: candidate).forteAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    .accessibilityHidden(true)

                Rectangle()
                    .fill(ForteColor.borderSubtle.opacity(0.72))
                    .frame(width: 1, height: 76)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 9) {
                    Text(candidate.title.forteGoalCardTitle(timeline: candidate.timeline))
                        .font(ForteTypography.editorial(size: 18, relativeTo: .headline))
                        .foregroundStyle(ForteColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(candidate.timeline.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ForteColor.indigoDeep)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(ForteColor.indigoSoft)
                        .clipShape(Capsule())

                    Text(candidate.rationale.forteGoalCardRationale().replacingOccurrences(of: "HAYF", with: "Forte"))
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(ForteColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                ForteGoalCandidateIndicator(isSelected: isSelected, mode: selectionMode)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? ForteColor.indigoMist : ForteColor.surface.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ForteColor.borderSubtle.opacity(isSelected ? 0 : 0.72), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(isSelected ? 0.09 : 0.055), radius: 13, y: 7)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(candidate.title). \(candidate.timeline.title). \(candidate.rationale)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ForteGoalCandidateIndicator: View {
    let isSelected: Bool
    let mode: ForteGoalCandidateSelectionMode

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? ForteColor.indigo : Color.clear)

            Circle()
                .stroke(isSelected ? ForteColor.indigo : ForteColor.inkMuted.opacity(0.50), lineWidth: 1.6)

            if isSelected {
                switch mode {
                case .single:
                    Circle().fill(.white).frame(width: 8, height: 8)
                case .multiple:
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 26, height: 26)
    }
}

struct ForteGoalCandidatesScreen: View {
    let candidates: [GoalCandidate]
    let selectedCandidateID: String?
    let progressStep: Int
    let totalSteps: Int
    let onSelect: (GoalCandidate) -> Void
    let onEdit: () -> Void
    let onBlend: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            overline: "GOAL DIRECTIONS",
            title: "Which goal feels\nmost like you?",
            copy: "Forte shaped three directions from what you told it. Choose the one you want to chase first.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(spacing: 12) {
                ForEach(candidates) { candidate in
                    ForteGoalCandidateCard(
                        candidate: candidate,
                        isSelected: selectedCandidateID == candidate.id,
                        selectionMode: .single
                    ) {
                        onSelect(candidate)
                    }
                }
            }

            ForteCandidatePrivacyNote()
                .padding(.top, 18)
        } footer: {
            VStack(spacing: 10) {
                ForteOnboardingPrimaryAction(
                    title: "Continue",
                    isEnabled: selectedCandidateID != nil,
                    accessibilityHint: "Select a goal before continuing.",
                    action: onContinue
                )

                HStack(spacing: 10) {
                    ForteOnboardingSecondaryAction(
                        title: "Edit selected",
                        isEnabled: selectedCandidateID != nil,
                        action: onEdit
                    )
                    ForteOnboardingSecondaryAction(title: "Blend two", action: onBlend)
                }
            }
        }
    }
}

struct ForteEditGoalCandidateScreen: View {
    @Binding var goalText: String
    @Binding var timeline: GoalTimeline
    let progressStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            overline: "MAKE IT YOURS",
            title: "Shape the goal\nin your own words.",
            copy: "Keep the useful direction, but rewrite anything that does not sound like the target you want.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(alignment: .leading, spacing: 22) {
                ForteTextArea(
                    title: "Edited goal",
                    placeholder: "Improve 10K pace while keeping one weekly strength session.",
                    text: $goalText,
                    characterLimit: 320
                )

                VStack(alignment: .leading, spacing: 12) {
                    ForteSectionLabel(title: "Timeframe")

                    HStack(spacing: 8) {
                        ForEach(GoalTimeline.discoveryCases) { option in
                            ForteCompactChoiceButton(title: option.title, isSelected: timeline == option) {
                                timeline = option
                            }
                        }
                    }
                    .padding(14)
                    .background(ForteColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Use edited goal",
                isEnabled: !goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                accessibilityHint: "Enter the edited goal before continuing.",
                action: onContinue
            )
        }
    }
}

struct ForteBlendGoalCandidatesScreen: View {
    let candidates: [GoalCandidate]
    let selectedCandidateIDs: Set<String>
    let progressStep: Int
    let totalSteps: Int
    let onToggle: (GoalCandidate) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            overline: "BLEND DIRECTIONS",
            title: "Pick two goals\nto bring together.",
            copy: "Forte will keep the clearest target and borrow the most useful support from the second direction.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(spacing: 12) {
                ForEach(candidates) { candidate in
                    ForteGoalCandidateCard(
                        candidate: candidate,
                        isSelected: selectedCandidateIDs.contains(candidate.id),
                        selectionMode: .multiple
                    ) {
                        onToggle(candidate)
                    }
                }
            }
        } footer: {
            ForteOnboardingPrimaryAction(
                title: "Preview blend",
                isEnabled: selectedCandidateIDs.count == 2,
                accessibilityHint: "Select exactly two goals before previewing the blend.",
                action: onContinue
            )
        }
    }
}

struct ForteBlendGoalPreviewScreen: View {
    let candidate: GoalCandidate
    let progressStep: Int
    let totalSteps: Int
    let onChooseDifferent: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            overline: "BLENDED GOAL",
            title: "Here’s the direction\nForte brought together.",
            copy: "Use this goal, or choose a different pair if the balance does not feel right.",
            onBack: onBack,
            onExit: onExit
        ) {
            ForteGoalCandidateCard(
                candidate: candidate,
                isSelected: true,
                selectionMode: .single,
                action: {}
            )

            ForteCandidatePrivacyNote()
                .padding(.top, 18)
        } footer: {
            VStack(spacing: 10) {
                ForteOnboardingPrimaryAction(title: "Use blended goal", isEnabled: true, action: onContinue)
                ForteOnboardingSecondaryAction(title: "Choose different goals", action: onChooseDifferent)
            }
        }
    }
}

private struct ForteCandidatePrivacyNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ForteColor.indigoDeep)
                .frame(width: 22, height: 22)

            Text("These directions personalize your setup. You stay in control of what Forte remembers.")
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(ForteColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum ForteStrategyPhaseVisualRole: CaseIterable, Equatable {
    case base
    case build
    case review

    init(phaseID: String) {
        switch phaseID.lowercased() {
        case "base": self = .base
        case "build": self = .build
        default: self = .review
        }
    }

    var assetName: String {
        switch self {
        case .base: return "ForteBlueprintCurrentState"
        case .build: return "ForteStrategyDriver"
        case .review: return "ForteStrategyTarget"
        }
    }
}

enum ForteStrategyPhaseTargetVisualRole: CaseIterable, Equatable {
    case strength
    case running
    case cycling
    case recovery
    case floor
    case capacity
    case goalSignal
    case general

    init(targetID: String, title targetTitle: String) {
        let id = targetID.lowercased()
        let title = targetTitle.lowercased()

        if title.contains("strength") {
            self = .strength
        } else if title.contains("running") || title.contains("run ") {
            self = .running
        } else if title.contains("cycling") || title.contains("ride") {
            self = .cycling
        } else if id.contains("recovery") || id.contains("drop") || title.contains("recovery") || title.contains("drop-off") {
            self = .recovery
        } else if id.contains("floor") || title.contains("skip") {
            self = .floor
        } else if id.contains("week") || id.contains("exposure") || title.contains("week") || title.contains("exposure") {
            self = .capacity
        } else if id.contains("goal") || title.contains("signal") || title.contains("result") {
            self = .goalSignal
        } else {
            self = .general
        }
    }

    var assetName: String {
        switch self {
        case .strength: return "ForteModalityStrength"
        case .running: return "ForteModalityRunning"
        case .cycling: return "ForteModalityCycling"
        case .recovery: return "ForteHealthRecovery"
        case .floor: return "ForteSummaryFloor"
        case .capacity: return "ForteSummaryCapacity"
        case .goalSignal: return "ForteStrategyGoalSignal"
        case .general: return "ForteStrategyTarget"
        }
    }
}

struct ForteStrategyPhaseTargetItem: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let displayValue: String?
    let assetName: String
}

struct ForteStrategyPhaseItem: Identifiable, Equatable {
    let id: String
    let name: String
    let objective: String
    let assetName: String
    let targets: [ForteStrategyPhaseTargetItem]
}

struct ForteFitnessStrategyPhasesScreen: View {
    let phases: [ForteStrategyPhaseItem]
    let completionErrorMessage: String?
    let progressStep: Int
    let totalSteps: Int
    let onAccept: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        ForteOnboardingPage(
            progressStep: progressStep,
            totalSteps: totalSteps,
            overline: "STRATEGY PHASES",
            title: "How Forte will\nsequence this.",
            copy: "Each phase has a clear job. Weekly targets and sessions come next in your plan.",
            onBack: onBack,
            onExit: onExit
        ) {
            VStack(spacing: 14) {
                ForEach(phases) { phase in
                    ForteStrategyPhaseCard(phase: phase)
                }
            }

            FortePlanBridgeCard()
                .padding(.top, 20)
        } footer: {
            VStack(spacing: 10) {
                if let completionErrorMessage {
                    Text(completionErrorMessage)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(red: 0.68, green: 0.23, blue: 0.30))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                        .background(Color(red: 0.99, green: 0.94, blue: 0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                ForteOnboardingPrimaryAction(title: "Accept strategy", isEnabled: true, action: onAccept)
            }
        }
    }
}

private struct ForteStrategyPhaseCard: View {
    let phase: ForteStrategyPhaseItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(phase.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.name)
                        .font(ForteTypography.editorial(size: 20, relativeTo: .title3))
                        .foregroundStyle(ForteColor.ink)

                    Text(phase.objective)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(ForteColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().overlay(ForteColor.borderSubtle)

            VStack(spacing: 0) {
                ForEach(Array(phase.targets.enumerated()), id: \.element.id) { index, target in
                    HStack(alignment: .top, spacing: 12) {
                        Image(target.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(target.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(ForteColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 4)

                                if let displayValue = target.displayValue {
                                    Text(displayValue)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(ForteColor.indigoDeep)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ForteColor.indigoSoft)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(target.summary)
                                .font(.system(size: 13, weight: .regular))
                                .lineSpacing(3)
                                .foregroundStyle(ForteColor.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 11)

                    if index < phase.targets.count - 1 {
                        Divider()
                            .overlay(ForteColor.borderSubtle.opacity(0.78))
                            .padding(.leading, 54)
                    }
                }
            }
        }
        .padding(16)
        .background(ForteColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.84), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 14, y: 7)
        .accessibilityElement(children: .contain)
    }
}

private struct FortePlanBridgeCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("ForteStrategyCadence")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("Your first two weeks come next")
                    .font(ForteTypography.editorial(size: 18, relativeTo: .headline))
                    .foregroundStyle(ForteColor.ink)

                Text("After you accept, Forte turns this strategy into a committed current week and a flexible draft for the week after.")
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(ForteColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(ForteColor.indigoMist)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension String {
    func forteGoalCardTitle(timeline: GoalTimeline) -> String {
        let weeks = timeline.weeks
        let cleaned = replacingOccurrences(of: "—", with: ". ")
            .replacingOccurrences(of: "–", with: ". ")
            .replacingOccurrences(
                of: "\\s+(in|over)\\s+\(weeks)\\s+weeks\\b",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\b\(weeks)[ -]week\\b\\s*",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(of: "^[\\s:;,.\\-]+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }

    func forteGoalCardRationale() -> String {
        replacingOccurrences(of: ";", with: ".")
            .replacingOccurrences(of: "—", with: ". ")
            .replacingOccurrences(of: "–", with: ". ")
            .replacingOccurrences(of: "/", with: " or ")
            .replacingOccurrences(of: " + ", with: " and ")
            .replacingOccurrences(of: "\\bthe athlete's\\b", with: "your", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\\bathlete\\b", with: "you", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\\bthe user\\b", with: "you", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
