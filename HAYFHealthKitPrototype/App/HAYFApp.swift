import SwiftUI

@main
struct HAYFApp: App {
    var body: some Scene {
        WindowGroup {
            #if FORTE_DEV
            if let goalPreview = ForteGoalPreviewLaunch.screen {
                ForteGoalPreviewHost(screen: goalPreview)
            } else if let previewIntent = ForteInfrastructurePreviewLaunch.intent {
                ForteInfrastructurePreviewHost(intent: previewIntent)
            } else if let previewIntent = ForteModalityPreviewLaunch.intent {
                ForteModalityPreviewHost(intent: previewIntent)
            } else if let previewIntent = ForteIntentPreviewLaunch.intent {
                ForteIntentPreviewHost(initialIntent: previewIntent)
            } else if ForteIntentPreviewLaunch.showsUnselectedIntent {
                ForteIntentPreviewHost(initialIntent: nil)
            } else {
                AppRootView()
            }
            #else
            AppRootView()
            #endif
        }
    }
}

#if FORTE_DEV
private enum ForteGoalPreviewLaunch {
    private static let argumentPrefix = "--forte-goal-preview="

    static var screen: String? {
        ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(argumentPrefix) })
            .map { String($0.dropFirst(argumentPrefix.count)) }
    }
}

private enum ForteInfrastructurePreviewLaunch {
    private static let selectedArgumentPrefix = "--forte-infrastructure-preview="

    static var intent: OnboardingIntent? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(selectedArgumentPrefix) }) else {
            return nil
        }

        return OnboardingIntent(rawValue: String(argument.dropFirst(selectedArgumentPrefix.count)))
    }
}

private enum ForteModalityPreviewLaunch {
    private static let selectedArgumentPrefix = "--forte-modality-preview="

    static var intent: OnboardingIntent? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(selectedArgumentPrefix) }) else {
            return nil
        }

        return OnboardingIntent(rawValue: String(argument.dropFirst(selectedArgumentPrefix.count)))
    }
}

private enum ForteIntentPreviewLaunch {
    private static let unselectedArgument = "--forte-intent-preview"
    private static let selectedArgumentPrefix = "--forte-intent-preview="

    static var showsUnselectedIntent: Bool {
        ProcessInfo.processInfo.arguments.contains(unselectedArgument)
    }

    static var intent: OnboardingIntent? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(selectedArgumentPrefix) }) else {
            return nil
        }

        return OnboardingIntent(rawValue: String(argument.dropFirst(selectedArgumentPrefix.count)))
    }
}

private struct ForteInfrastructurePreviewHost: View {
    let intent: OnboardingIntent
    private let options: [InfrastructureAccess] = [
        .gym,
        .indoorBike,
        .outdoorBike,
        .outdoorRoutes,
        .treadmill,
        .homeWeights
    ]
    @State private var selectedOptions: Set<InfrastructureAccess> = [.gym, .outdoorRoutes]
    @State private var didExit = false

    var body: some View {
        if didExit {
            Text("Onboarding closed")
                .accessibilityIdentifier("forte.infrastructure.closed")
        } else {
            ForteInfrastructureScreen(
                options: options,
                selectedOptions: selectedOptions,
                progressStep: OnboardingStep.infrastructure.activeSegments(for: intent),
                totalSteps: OnboardingStep.totalSegments(for: intent),
                onToggle: toggle,
                onBack: {},
                onExit: { didExit = true },
                onContinue: {}
            )
        }
    }

    private func toggle(_ option: InfrastructureAccess) {
        if selectedOptions.contains(option) {
            selectedOptions.remove(option)
        } else {
            selectedOptions.insert(option)
        }
    }
}

private struct ForteModalityPreviewHost: View {
    let intent: OnboardingIntent
    @State private var selectedOptions: [TrainingOption] = [.cycling, .strength, .running]
    @State private var didExit = false

    var body: some View {
        if didExit {
            Text("Onboarding closed")
                .accessibilityIdentifier("forte.modality.closed")
        } else {
            ForteModalityScreen(
                intent: intent,
                selectedOptions: selectedOptions,
                progressStep: OnboardingStep.options.activeSegments(for: intent),
                totalSteps: OnboardingStep.totalSegments(for: intent),
                onToggle: toggle,
                onBack: {},
                onExit: { didExit = true },
                onContinue: {}
            )
        }
    }

    private func toggle(_ option: TrainingOption) {
        guard option.isOnboardingEnabled else { return }
        if let index = selectedOptions.firstIndex(of: option) {
            selectedOptions.remove(at: index)
        } else {
            selectedOptions.append(option)
        }
    }
}

private struct ForteIntentPreviewHost: View {
    let initialIntent: OnboardingIntent?
    @State private var didExit = false

    var body: some View {
        if didExit {
            Text("Onboarding closed")
                .accessibilityIdentifier("forte.intent.closed")
        } else {
            OnboardingFlowView(
                physiologyReference: .male,
                birthdate: Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now,
                onboardingProfileStore: OnboardingProfileStore(),
                initialIntent: initialIntent,
                onExit: { didExit = true }
            ) {}
        }
    }
}

private struct ForteGoalPreviewHost: View {
    let screen: String

    @State private var goalBrief = "Run a half marathon under two hours while keeping one strength day."
    @State private var experience: GoalExperience? = .oneToThreeYears
    @State private var timeline: GoalTimeline? = .eightWeeks
    @State private var goalDate = Calendar.current.date(byAdding: .day, value: 84, to: .now) ?? .now
    @State private var priority: GoalPriority? = .stayingBalanced
    @State private var direction: GoalDirection? = .betterEndurance
    @State private var challenge: ChallengeStyle? = .numbersTargets
    @State private var avoidances: Set<GoalAvoidance> = [.strictPlans]
    @State private var intensity: GoalIntensity = .steady
    @State private var selectedCandidateID: String? = "run"
    @State private var blendCandidateIDs: Set<String> = ["run", "strength"]
    @State private var editedGoal = "Improve my 10K pace while keeping one useful strength session every week."
    @State private var editedTimeline: GoalTimeline = .eightWeeks

    private let candidates: [GoalCandidate] = [
        GoalCandidate(
            id: "run",
            title: "Build toward a faster, more controlled 10K",
            rationale: "Your endurance direction and preference for measurable progress make pace durability the clearest first target.",
            tracking: "Weekly easy-volume consistency and one controlled pace marker",
            timeline: .eightWeeks,
            systemImage: "figure.run"
        ),
        GoalCandidate(
            id: "strength",
            title: "Build a dependable full-body strength base",
            rationale: "This keeps the target measurable while protecting the flexible training setup you asked for.",
            tracking: "Two repeatable strength sessions each week",
            timeline: .twelveWeeks,
            systemImage: "dumbbell"
        ),
        GoalCandidate(
            id: "sport",
            title: "Feel quicker and more capable for your sport",
            rationale: "A mixed athletic goal can connect coordination, repeat effort, and confidence without forcing a gym-dependent plan.",
            tracking: "Movement quality and repeat-effort check-ins",
            timeline: .fourWeeks,
            systemImage: "sportscourt"
        )
    ]

    private var longCopyCandidate: GoalCandidate {
        GoalCandidate(
            id: "long-copy",
            title: "Build enough repeatable endurance to finish a challenging community event with controlled effort and confidence",
            rationale: "This intentionally long preview checks that a detailed generated rationale wraps cleanly, preserves the timeframe signal, and never crowds the selection control or fixed action rail at larger text sizes.",
            tracking: "Consistent weekly exposure, controlled effort, and a simple confidence check after the longest session",
            timeline: .twelveWeeks,
            systemImage: "arbitrary-ai-value"
        )
    }

    @ViewBuilder
    var body: some View {
        switch screen {
        case "brief-disabled":
            ForteGoalBriefScreen(goalBrief: .constant(""), progressStep: 2, totalSteps: 20, onBack: {}, onExit: {}, onContinue: {})
        case "brief":
            ForteGoalBriefScreen(goalBrief: $goalBrief, progressStep: 2, totalSteps: 20, onBack: {}, onExit: {}, onContinue: {})
        case "experience":
            ForteGoalExperienceScreen(selectedExperience: experience, progressStep: 3, totalSteps: 20, onSelect: { experience = $0 }, onBack: {}, onExit: {}, onContinue: {})
        case "timeline":
            ForteGoalTimelineScreen(selectedTimeline: $timeline, goalDate: $goalDate, progressStep: 4, totalSteps: 20, onBack: {}, onExit: {}, onContinue: {})
        case "priority":
            ForteGoalPriorityScreen(selectedPriority: priority, progressStep: 9, totalSteps: 20, onSelect: { priority = $0 }, onBack: {}, onExit: {}, onContinue: {})
        case "direction":
            ForteGoalDirectionScreen(selectedDirection: direction, progressStep: 4, totalSteps: 21, onSelect: { direction = $0 }, onBack: {}, onExit: {}, onContinue: {})
        case "challenge":
            ForteChallengeStyleScreen(selectedStyle: challenge, progressStep: 5, totalSteps: 21, onSelect: { challenge = $0 }, onBack: {}, onExit: {}, onContinue: {})
        case "avoidances":
            ForteGoalAvoidanceScreen(selectedAvoidances: avoidances, progressStep: 6, totalSteps: 21, onToggle: toggleAvoidance, onBack: {}, onExit: {}, onContinue: {})
        case "intensity":
            ForteGoalIntensityScreen(selectedIntensity: intensity, progressStep: 7, totalSteps: 21, onSelect: { intensity = $0 }, onBack: {}, onExit: {}, onContinue: {})
        case "candidates-disabled":
            ForteGoalCandidatesScreen(candidates: candidates, selectedCandidateID: nil, progressStep: 8, totalSteps: 21, onSelect: { _ in }, onEdit: {}, onBlend: {}, onBack: {}, onExit: {}, onContinue: {})
        case "candidate-long-copy":
            ForteGoalCandidatesScreen(candidates: [longCopyCandidate], selectedCandidateID: longCopyCandidate.id, progressStep: 8, totalSteps: 21, onSelect: { _ in }, onEdit: {}, onBlend: {}, onBack: {}, onExit: {}, onContinue: {})
        case "edit":
            ForteEditGoalCandidateScreen(goalText: $editedGoal, timeline: $editedTimeline, progressStep: 8, totalSteps: 21, onBack: {}, onExit: {}, onContinue: {})
        case "blend":
            ForteBlendGoalCandidatesScreen(candidates: candidates, selectedCandidateIDs: blendCandidateIDs, progressStep: 8, totalSteps: 21, onToggle: toggleBlend, onBack: {}, onExit: {}, onContinue: {})
        case "blended":
            ForteBlendGoalPreviewScreen(candidate: blendedCandidate, progressStep: 8, totalSteps: 21, onChooseDifferent: {}, onBack: {}, onExit: {}, onContinue: {})
        case "loading":
            ForteOnboardingLoadingScreen(content: loadingContent, failure: nil, progressStep: 7, totalSteps: 21, onRetry: {}, onBack: {}, onExit: {})
        case "failure":
            ForteOnboardingLoadingScreen(content: loadingContent, failure: ForteOnboardingLoadingFailure(title: "We could not shape your goals", copy: "Your answers are safe.", detail: "Check your connection and try again."), progressStep: 7, totalSteps: 21, onRetry: {}, onBack: {}, onExit: {})
        case "phases":
            ForteFitnessStrategyPhasesScreen(phases: previewPhases, completionErrorMessage: nil, progressStep: 20, totalSteps: 20, onAccept: {}, onBack: {}, onExit: {})
        default:
            ForteGoalCandidatesScreen(candidates: candidates, selectedCandidateID: selectedCandidateID, progressStep: 8, totalSteps: 21, onSelect: { selectedCandidateID = $0.id }, onEdit: {}, onBlend: {}, onBack: {}, onExit: {}, onContinue: {})
        }
    }

    private var blendedCandidate: GoalCandidate {
        GoalCandidate(
            id: "blended-run-strength",
            title: "Improve 10K durability while preserving strength",
            rationale: "Use endurance as the lead signal and keep one dependable strength exposure in the week.",
            tracking: "10K pace durability plus weekly strength continuity",
            timeline: .eightWeeks,
            systemImage: "arrow.triangle.merge"
        )
    }

    private var loadingContent: ForteOnboardingLoadingContent {
        ForteOnboardingLoadingContent(
            title: "Shaping your\ngoal directions.",
            copy: "Forte is balancing ambition, access, and the kind of challenge that keeps you engaged.",
            activityTitle: "Building three useful directions",
            activityCopy: "This normally takes a few seconds."
        )
    }

    private var previewPhases: [ForteStrategyPhaseItem] {
        [
            ForteStrategyPhaseItem(id: "base", name: "Base", objective: "Make the weekly rhythm repeatable before adding pressure.", assetName: ForteStrategyPhaseVisualRole.base.assetName, targets: previewTargets),
            ForteStrategyPhaseItem(id: "build", name: "Build", objective: "Progress the lead signal without dropping useful support work.", assetName: ForteStrategyPhaseVisualRole.build.assetName, targets: previewTargets),
            ForteStrategyPhaseItem(id: "review", name: "Review", objective: "Check the result and choose the next useful direction.", assetName: ForteStrategyPhaseVisualRole.review.assetName, targets: previewTargets)
        ]
    }

    private var previewTargets: [ForteStrategyPhaseTargetItem] {
        [
            ForteStrategyPhaseTargetItem(id: "exposure", title: "Weekly exposure", summary: "Complete the planned sessions with a rhythm you can repeat.", displayValue: "3 / week", assetName: ForteSummaryAnswerRole.capacity.assetName),
            ForteStrategyPhaseTargetItem(id: "signal", title: "Goal signal", summary: "Move the lead metric while keeping effort controlled.", displayValue: "+5%", assetName: ForteStrategyPhaseTargetVisualRole.goalSignal.assetName),
            ForteStrategyPhaseTargetItem(id: "recovery", title: "Recovery protection", summary: "Avoid a meaningful drop in readiness across the phase.", displayValue: "Stable", assetName: ForteStrategyPhaseTargetVisualRole.recovery.assetName)
        ]
    }

    private func toggleAvoidance(_ value: GoalAvoidance) {
        avoidances.toggleOnboardingAvoidance(value)
    }

    private func toggleBlend(_ candidate: GoalCandidate) {
        blendCandidateIDs = GoalCandidateBlendSelection.toggling(candidate.id, in: blendCandidateIDs)
    }
}
#endif
