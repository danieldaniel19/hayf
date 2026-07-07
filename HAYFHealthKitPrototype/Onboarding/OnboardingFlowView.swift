import SwiftUI
import Supabase
import OSLog

struct OnboardingFlowView: View {
    let physiologyReference: PhysiologyReference
    let onExit: () -> Void
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .intent
    @State private var draft = ConsistencyOnboardingDraft()
    @State private var selectedIntent: OnboardingIntent?
    @State private var summaryOutput: OnboardingSummaryOutput?
    @State private var goalCandidates: [GoalCandidate] = []
    @State private var selectedGoalCandidateID: String?
    @State private var editingGoalText = ""
    @State private var editingGoalTimeline: GoalTimeline = .eightWeeks
    @State private var blendCandidateIDs: Set<String> = []
    @State private var blendedCandidate: GoalCandidate?
    @State private var healthRequestState: HealthRequestState = .idle
    @State private var athleteBlueprint: AthleteBlueprintOutput?
    @State private var fitnessStrategy: FitnessStrategyOutput?
    @State private var pendingHealthSnapshot: HealthFeatureSnapshot?
    @State private var selectedBlueprintDetail: AthleteBlueprintDetail?
    @State private var completionErrorMessage: String?
    @State private var aiGenerationFailure: OnboardingAIGenerationFailure?
    @State private var useMockHealthData = false
    @State private var mockHealthDataMessage: String?
    @State private var isCompleting = false

    private let healthKitManager = HealthKitManager()
    private let healthSyncService = HealthSyncService()
    private let aiProvider: any OnboardingAIProvider = RemoteOnboardingAIProvider()
    private let planningAIProvider = PlanningAIProvider()
    private let completionLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HAYF", category: "onboarding.completion")
    private let onboardingProfileStore: OnboardingProfileStore

    init(
        physiologyReference: PhysiologyReference,
        onboardingProfileStore: OnboardingProfileStore,
        onExit: @escaping () -> Void = {},
        onComplete: @escaping () -> Void
    ) {
        self.physiologyReference = physiologyReference
        self.onboardingProfileStore = onboardingProfileStore
        self.onExit = onExit
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(spacing: 0) {
                onboardingHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                ScrollView(showsIndicators: false) {
                    screenContent
                        .padding(.horizontal, 24)
                        .padding(.top, 30)
                        .padding(.bottom, 24)
                }
                .id(step)

                bottomAction
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: 480)
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .sheet(item: $selectedBlueprintDetail) { detail in
            AthleteBlueprintDetailSheet(detail: detail)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.visible)
        }
        .task(id: step) {
            switch step {
            case .health:
                await refreshHealthState()
            case .generatingBlueprint:
                await generateAthleteBlueprint()
            case .generatingStrategy:
                await generateFitnessStrategy()
            case .generatingSummary:
                await generateSummary()
            case .generatingCandidates:
                await generateGoalCandidates()
            case .generatingBlend:
                await generateBlendedCandidate()
            default:
                break
            }
        }
    }

    private var onboardingHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<totalSegments, id: \.self) { index in
                    Capsule()
                        .fill(index < activeSegments ? HAYFColor.orange : HAYFColor.borderStrong)
                        .frame(height: 3)
                }
            }

            HStack {
                Text(progressLabel)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)

                Spacer()

                HStack(spacing: 8) {
                    if step.showsBackButton {
                        Button {
                            goBack()
                        } label: {
                            OnboardingHeaderIcon(systemName: "arrow.left")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                    }

                    Button {
                        onExit()
                    } label: {
                        OnboardingHeaderIcon(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Exit onboarding")
                }
            }
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch step {
        case .intent:
            intentScreen
        case .goalBrief:
            concreteGoalBriefScreen
        case .goalExperience:
            goalExperienceScreen
        case .goalTimeline:
            goalTimelineScreen
        case .goalPriority:
            goalPriorityScreen
        case .options:
            trainingOptionsScreen
        case .infrastructure:
            infrastructureScreen
        case .anchor:
            motivationAnchorScreen
        case .findDirection:
            goalDirectionScreen
        case .findChallenge:
            challengeStyleScreen
        case .findAvoids:
            goalAvoidsScreen
        case .generatingCandidates:
            loadingScreen(title: "Finding goal directions.", copy: "HAYF is turning your preferences into a few concrete options.")
        case .goalCandidates:
            goalCandidatesScreen
        case .editCandidate:
            editCandidateScreen
        case .blendCandidates:
            blendCandidatesScreen
        case .generatingBlend:
            loadingScreen(title: "Blending those goals.", copy: "HAYF is combining the useful parts into one direction.")
        case .blendPreview:
            blendPreviewScreen
        case .weeklyCommitment:
            weeklyCommitmentScreen
        case .sessionCapacity:
            sessionCapacityScreen
        case .weeklyAvailability:
            weeklyAvailabilityScreen
        case .friction:
            frictionScreen
        case .injuries:
            injuryScreen
        case .bodyBasics:
            bodyBasicsScreen
        case .bodyFatEstimate:
            bodyFatEstimateScreen
        case .support:
            supportStyleScreen
        case .floor:
            badDayFloorScreen
        case .generatingSummary:
            loadingScreen(title: "Reading this back.", copy: "HAYF is turning your answers into a coach-style setup.")
        case .summary:
            summaryScreen
        case .health:
            healthScreen
        case .generatingBlueprint:
            loadingScreen(title: "Reading your athlete profile.", copy: "HAYF is combining what you told us with your training history.")
        case .athleteBlueprint:
            athleteBlueprintScreen
        case .generatingStrategy:
            loadingScreen(title: "Building your strategy.", copy: "HAYF is turning your goal and Athlete Blueprint into the approach it will coach from.")
        case .fitnessStrategy:
            fitnessStrategyScreen
        case .fitnessStrategyPhases:
            fitnessStrategyPhasesScreen
        }
    }

    private var intentScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What kind of help\ndo you want?",
                copy: "HAYF will adapt the setup based on how you want to train."
            )

            VStack(spacing: 12) {
                ForEach(OnboardingIntent.allCases) { intent in
                    OnboardingOptionCard(
                        title: intent.title,
                        subtitle: intent.subtitle,
                        systemImage: intent.systemImage,
                        isSelected: selectedIntent == intent
                    ) {
                        selectedIntent = intent
                    }
                }
            }
        }
    }

    private var trainingOptionsScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: selectedIntent == .concreteGoal ? "What else can HAYF\nuse around this?" : "What can HAYF\nrealistically recommend?",
                copy: selectedIntent == .concreteGoal
                    ? "Tap the training options in the order you want HAYF to prioritize them around your goal."
                    : "Tap the training options in the order you want HAYF to prioritize them."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TrainingOption.allCases) { option in
                    SelectableTile(
                        title: option.title,
                        systemImage: option.systemImage,
                        selectionRank: draft.trainingOptionRank(for: option)
                    ) {
                        draft.toggleTrainingOption(option)
                    }
                }
            }

        }
    }

    private var concreteGoalBriefScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What are you\nworking toward?",
                copy: "Say it naturally. HAYF will pull out the target, timeline, and what needs clarifying."
            )

            OnboardingTextArea(
                title: "Goal brief",
                placeholder: "Run a half marathon under 2 hours in October while keeping some strength.",
                text: $draft.goalBrief,
                characterLimit: 280
            )
        }
    }

    private var goalExperienceScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "How long have\nyou trained?",
                copy: "HAYF will read your workout history from Apple Health later, but your own input helps when tracked history is patchy."
            )

            OptionGroup(title: "How experienced are you with training?") {
                VStack(spacing: 10) {
                    ForEach(GoalExperience.allCases) { experience in
                        DetailedSelectableRow(
                            title: experience.title,
                            subtitle: experience.subtitle,
                            systemImage: experience.systemImage,
                            isSelected: draft.goalExperience == experience
                        ) {
                            draft.goalExperience = experience
                        }
                    }
                }
            }

        }
    }

    private var goalTimelineScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What horizon\nare we coaching?",
                copy: "If you do not have a fixed date, HAYF will default to a 12-week horizon whenever it needs one."
            )

            OptionGroup(title: "Timeline") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(GoalTimeline.allCases) { timeline in
                            CompactChoiceButton(
                                title: timeline.title,
                                isSelected: draft.goalTimeline == timeline
                            ) {
                                draft.goalTimeline = timeline
                            }
                        }
                    }

                    if draft.goalTimeline == .specificDate {
                        GoalDatePicker(date: $draft.goalDate)
                    }
                }
            }
        }
    }

    private var goalPriorityScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "When tradeoffs show up,\nwhat should win?",
                copy: "This gives HAYF a clear rule for busy weeks."
            )

            OptionGroup(title: "If the week gets tight, protect...") {
                VStack(spacing: 10) {
                    ForEach(GoalPriority.allCases) { priority in
                        DetailedSelectableRow(
                            title: priority.title,
                            subtitle: priority.subtitle,
                            systemImage: priority.systemImage,
                            isSelected: draft.goalPriority == priority
                        ) {
                            draft.goalPriority = priority
                        }
                    }
                }
            }
        }
    }

    private var motivationAnchorScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What are you trying\nto keep true?",
                copy: "Consistency usually protects something. Pick what HAYF should help you come back to."
            )

            VStack(spacing: 10) {
                ForEach(MotivationAnchor.allCases) { anchor in
                    SelectableRow(
                        title: anchor.title,
                        systemImage: anchor.systemImage,
                        isSelected: draft.motivationAnchors.contains(anchor)
                    ) {
                        draft.motivationAnchors.toggle(anchor)
                    }
                }
            }

            OnboardingTextArea(
                title: "Anything behind that?",
                placeholder: "I feel better when I train, but I lose the rhythm whenever work gets intense...",
                text: $draft.motivationNote,
                characterLimit: 240
            )
        }
    }

    private var goalDirectionScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What kind of change\nwould feel exciting?",
                copy: "HAYF will use this as the emotional direction before turning it into a concrete goal."
            )

            VStack(spacing: 10) {
                ForEach(GoalDirection.allCases) { direction in
                    DetailedSelectableRow(
                        title: direction.title,
                        subtitle: direction.subtitle,
                        systemImage: direction.systemImage,
                        isSelected: draft.goalDirection == direction
                    ) {
                        draft.goalDirection = direction
                    }
                }
            }
        }
    }

    private var challengeStyleScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What kind of challenge\nkeeps you interested?",
                copy: "Different goals motivate differently. Pick the style that feels easiest to care about."
            )

            VStack(spacing: 10) {
                ForEach(ChallengeStyle.allCases) { style in
                    DetailedSelectableRow(
                        title: style.title,
                        subtitle: style.subtitle,
                        systemImage: style.systemImage,
                        isSelected: draft.challengeStyle == style
                    ) {
                        draft.challengeStyle = style
                    }
                }
            }
        }
    }

    private var goalAvoidsScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What should HAYF\navoid building around?",
                copy: "This keeps goal ideas useful instead of technically impressive but wrong for your life."
            )

            VStack(spacing: 10) {
                ForEach(GoalAvoidance.allCases) { avoidance in
                    SelectableRow(
                        title: avoidance.title,
                        systemImage: avoidance.systemImage,
                        isSelected: draft.goalAvoidances.contains(avoidance)
                    ) {
                        toggleAvoidance(avoidance)
                    }
                }
            }

        }
    }

    private var infrastructureScreen: some View {
        let options = draft.requiredInfrastructureOptions

        return VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What do you\nactually have access to?",
                copy: "HAYF should only build around equipment and environments you can reliably use."
            )

            VStack(spacing: 10) {
                ForEach(options) { option in
                    SelectableRow(
                        title: option.title,
                        systemImage: option.systemImage,
                        isSelected: draft.infrastructureAccess.contains(option)
                    ) {
                        draft.infrastructureAccess.toggle(option)
                    }
                }
            }
        }
    }

    private var goalCandidatesScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Which goal feels\nmost like you?",
                copy: "HAYF shaped three goals from what you told us. Choose the one you want to chase first."
            )

            VStack(spacing: 12) {
                ForEach(displayGoalCandidates) { candidate in
                    GoalCandidateCard(
                        candidate: candidate,
                        isSelected: selectedGoalCandidateID == candidate.id,
                        selectionStyle: .single
                    ) {
                        selectedGoalCandidateID = candidate.id
                        draft.chosenGoal = candidate
                    }
                }
            }

            PersonalizationNote()
        }
    }

    private var editCandidateScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Make the goal\nyours.",
                copy: "Keep the useful shape, but rewrite anything that does not sound like the target you want."
            )

            OnboardingTextArea(
                title: "Edited goal",
                placeholder: "Improve 10K pace while keeping one weekly strength session...",
                text: $editingGoalText,
                characterLimit: 320
            )

            OptionGroup(title: "Timeframe") {
                HStack(spacing: 10) {
                    ForEach(GoalTimeline.discoveryCases) { timeline in
                        CompactChoiceButton(
                            title: timeline.title,
                            isSelected: editingGoalTimeline == timeline
                        ) {
                            editingGoalTimeline = timeline
                        }
                    }
                }
            }
        }
    }

    private var blendCandidatesScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Pick two goals\nto blend.",
                copy: "HAYF will combine the useful parts into one clearer direction."
            )

            VStack(spacing: 12) {
                ForEach(displayGoalCandidates) { candidate in
                    GoalCandidateCard(
                        candidate: candidate,
                        isSelected: blendCandidateIDs.contains(candidate.id),
                        selectionStyle: .multiple
                    ) {
                        toggleBlendCandidate(candidate)
                    }
                }
            }
        }
    }

    private var blendPreviewScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Here's the\nblended goal.",
                copy: "Use this direction, or go back if the mix does not feel right."
            )

            GoalCandidateCard(
                candidate: blendedCandidate ?? fallbackBlendedCandidate,
                isSelected: true,
                selectionStyle: .single
            ) {
                blendedCandidate = blendedCandidate ?? fallbackBlendedCandidate
            }

            PersonalizationNote()
        }
    }

    private func loadingScreen(title: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                eyebrow: aiGenerationFailure(for: step) == nil ? "HAYF IS THINKING" : "AI FAILED",
                title: aiGenerationFailure(for: step)?.title ?? title,
                copy: aiGenerationFailure(for: step)?.copy ?? copy
            )

            if let failure = aiGenerationFailure(for: step) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(HAYFColor.orange)
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("HAYF could not reach its AI coach.")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(HAYFColor.primary)

                            Text(failure.detail)
                                .font(.system(size: 14, weight: .regular))
                                .lineSpacing(3)
                                .foregroundStyle(HAYFColor.secondary)
                        }
                    }

                    Button {
                        retryCurrentGeneration()
                    } label: {
                        HStack {
                            Text("Try again")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(HAYFColor.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .padding(.horizontal, 16)
                        .background(HAYFColor.surface)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(HAYFColor.borderStrong, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(HAYFColor.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(HAYFColor.orange.opacity(0.22), lineWidth: 1)
                }
            } else {
                HStack(spacing: 14) {
                    ProgressView()
                        .tint(HAYFColor.orange)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Personalizing your setup")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)

                        Text("HAYF is turning your answers into a compact coach profile.")
                            .font(.system(size: 14, weight: .regular))
                            .lineSpacing(3)
                            .foregroundStyle(HAYFColor.secondary)
                    }
                }
                .padding(16)
                .background(HAYFColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(HAYFColor.border, lineWidth: 1)
                }
            }
        }
    }

    private var weeklyCommitmentScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: currentIntent == .concreteGoal ? "How many days can\nyou train?" : "What feels realistic\nmost weeks?",
                copy: currentIntent == .concreteGoal ? "This is your total weekly exercise budget: goal sessions plus support work." : "This helps HAYF protect consistency before ambition."
            )

            OptionGroup(title: currentIntent == .concreteGoal ? "Total training days per week" : "Days per week") {
                WheelChoicePicker(
                    options: TrainingFrequency.allCases,
                    selection: Binding(
                        get: { draft.frequency ?? .three },
                        set: { draft.frequency = $0 }
                    )
                )
            }
        }
        .onAppear {
            draft.frequency = draft.frequency ?? .three
        }
    }

    private var sessionCapacityScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "How much time\nfits one session?",
                copy: "This tells HAYF how large a normal training unit can be before the week becomes unrealistic."
            )

            OptionGroup(title: "Typical session length") {
                WheelChoicePicker(
                    options: SessionLength.allCases,
                    selection: Binding(
                        get: { draft.sessionLength ?? .thirty },
                        set: { draft.sessionLength = $0 }
                    )
                )
            }
        }
        .onAppear {
            draft.sessionLength = draft.sessionLength ?? .thirty
        }
    }

    private var weeklyAvailabilityScreen: some View {
        VStack(alignment: .leading, spacing: 28) {
            OnboardingIntro(
                title: "When can training\nusually happen?",
                copy: "Pick every day and time window that is genuinely available most weeks."
            )

            OptionGroup(title: "Available days") {
                WeekdayAvailabilityRow(selection: $draft.availableDays)
            }

            OptionGroup(title: "Available times") {
                DayPartAvailabilityRow(selection: $draft.availableDayParts)
            }
        }
        .onAppear {
            draft.availableDayParts.remove(.midday)
        }
    }

    private var frictionScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "What usually breaks\nconsistency?",
                copy: "HAYF will plan around these instead of pretending they don't exist."
            )

            VStack(spacing: 10) {
                ForEach(ConsistencyBlocker.allCases) { blocker in
                    SelectableRow(
                        title: blocker.title,
                        systemImage: blocker.systemImage,
                        isSelected: draft.blockers.contains(blocker)
                    ) {
                        draft.blockers.toggle(blocker)
                    }
                }
            }

            OnboardingTextArea(
                title: "Anything specific?",
                placeholder: "Early meetings, late workdays, weekends away...",
                text: $draft.blockerNote,
                characterLimit: 220
            )
        }
    }

    private var injuryScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Anything HAYF\nshould protect?",
                copy: "Even minor discomforts matter if they should change load, exercise choices, or progression."
            )

            OnboardingTextArea(
                title: "Injuries or discomforts",
                placeholder: "Knee pain on descents, shoulder discomfort overhead, returning from an ankle issue, or anything HAYF should plan around...",
                text: $draft.injuryNotes,
                characterLimit: 220
            )
        }
    }

    private var bodyBasicsScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Let's set your\ncurrent baseline.",
                copy: "Health imports can be stale. These answers become the first body-composition baseline HAYF can trust today."
            )

            HStack(alignment: .top, spacing: 12) {
                NumberWheelPicker(
                    title: "Weight",
                    unit: "kg",
                    values: Array(25...250),
                    defaultValue: 70,
                    text: $draft.bodyMassKilogramsInput
                )

                NumberWheelPicker(
                    title: "Height",
                    unit: "cm",
                    values: Array(100...230),
                    defaultValue: 173,
                    text: $draft.heightCentimetersInput
                )
            }
        }
        .onAppear {
            if draft.bodyMassKilogramsInput.trimmed.isEmpty {
                draft.bodyMassKilogramsInput = "70"
            }
            if draft.heightCentimetersInput.trimmed.isEmpty {
                draft.heightCentimetersInput = "173"
            }
        }
    }

    private var bodyFatEstimateScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Estimate your\nbody-fat range.",
                copy: "A range is enough. HAYF will use it as an estimated baseline, not as a lab measurement."
            )

            VStack(spacing: 10) {
                ForEach(BodyFatBand.options(for: physiologyReference)) { band in
                    DetailedSelectableRow(
                        title: band.title,
                        subtitle: band.subtitle,
                        systemImage: "figure",
                        isSelected: draft.bodyFatBand == band
                    ) {
                        draft.bodyFatBand = band
                    }
                }
            }
        }
    }

    private var supportStyleScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "When you're drifting,\nwhat kind of coach helps?",
                copy: "HAYF can adjust how it nudges you when the week starts slipping."
            )

            VStack(spacing: 10) {
                ForEach(CoachingSupportStyle.allCases) { supportStyle in
                    DetailedSelectableRow(
                        title: supportStyle.title,
                        subtitle: supportStyle.subtitle,
                        systemImage: supportStyle.systemImage,
                        isSelected: draft.supportStyle == supportStyle
                    ) {
                        draft.supportStyle = supportStyle
                    }
                }
            }
        }
    }

    private var badDayFloorScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: currentIntent == .concreteGoal ? "What's the smallest\ngoal-safe version?" : "On a bad day,\nwhat still counts?",
                copy: currentIntent == .concreteGoal ? "Earlier you chose what to protect when the week gets tight. This sets the minimum action that still keeps the plan alive." : "This gives HAYF a floor, so consistency doesn't become all-or-nothing."
            )

            VStack(spacing: 12) {
                ForEach(BadDayFloor.allCases) { floor in
                    DetailedSelectableRow(
                        title: floor.title,
                        subtitle: floor.subtitle,
                        systemImage: floor.systemImage,
                        isSelected: draft.badDayFloor == floor
                    ) {
                        draft.badDayFloor = floor
                    }
                }
            }
        }
    }

    private var summaryScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Here's what HAYF\nunderstood.",
                copy: "Check HAYF's readback against the answers you gave."
            )

            SummarySection(title: "What HAYF understood") {
                CoachNote(text: currentSummary.readback)
            }

            SummarySection(title: "Your answers") {
                VStack(spacing: 10) {
                    ForEach(currentInputSummaryRows) { row in
                        SummaryRow(systemImage: row.systemImage, label: row.label, value: row.value)
                    }
                }
            }

            PersonalizationNote()
        }
    }

    private var currentInputSummaryRows: [SummaryItem] {
        switch currentIntent {
        case .stayConsistent:
            return [
                SummaryItem(systemImage: "figure.strengthtraining.traditional", label: "Training", value: draft.trainingSummary),
                SummaryItem(systemImage: "building.2", label: "Access", value: draft.infrastructureSummary),
                SummaryItem(systemImage: "bolt.heart", label: "Anchor", value: draft.motivationInputSummary),
                SummaryItem(systemImage: "calendar.badge.clock", label: "Availability", value: draft.availabilitySummary),
                SummaryItem(systemImage: "timer", label: "Capacity", value: draft.rhythmSummary),
                SummaryItem(systemImage: "exclamationmark.triangle", label: "Risks", value: draft.blockerInputSummary),
                SummaryItem(systemImage: "cross.case", label: "Injuries", value: draft.injurySummary),
                SummaryItem(systemImage: "figure", label: "Body baseline", value: draft.bodyBaselineSummary),
                SummaryItem(systemImage: "figure.cooldown", label: "Support", value: draft.supportSummary),
                SummaryItem(systemImage: "arrow.down.circle", label: "Floor", value: draft.floorSummary)
            ]
        case .concreteGoal:
            return [
                SummaryItem(systemImage: "flag", label: "Goal", value: draft.goalSummary),
                SummaryItem(systemImage: "calendar", label: "Timeline", value: draft.timelineSummary),
                SummaryItem(systemImage: "figure.run", label: "Experience", value: draft.experienceSummary),
                SummaryItem(systemImage: "arrow.left.arrow.right", label: "Tradeoff", value: draft.prioritySummary),
                SummaryItem(systemImage: "cross.case", label: "Injuries", value: draft.injurySummary),
                SummaryItem(systemImage: "figure.strengthtraining.traditional", label: "Training", value: draft.trainingSummary),
                SummaryItem(systemImage: "building.2", label: "Access", value: draft.infrastructureSummary),
                SummaryItem(systemImage: "calendar.badge.clock", label: "Availability", value: draft.availabilitySummary),
                SummaryItem(systemImage: "timer", label: "Capacity", value: draft.rhythmSummary),
                SummaryItem(systemImage: "figure", label: "Body baseline", value: draft.bodyBaselineSummary),
                SummaryItem(systemImage: "arrow.down.circle", label: "Floor", value: draft.floorSummary)
            ]
        case .findGoal:
            return [
                SummaryItem(systemImage: "target", label: "Chosen goal", value: draft.goalSummary),
                SummaryItem(systemImage: "calendar", label: "Timeframe", value: draft.timelineSummary),
                SummaryItem(systemImage: "sparkle", label: "Direction", value: draft.directionSummary),
                SummaryItem(systemImage: "flag", label: "Challenge", value: draft.challengeSummary),
                SummaryItem(systemImage: "nosign", label: "Avoid", value: draft.avoidsSummary),
                SummaryItem(systemImage: "cross.case", label: "Injuries", value: draft.injurySummary),
                SummaryItem(systemImage: "figure.strengthtraining.traditional", label: "Training", value: draft.trainingSummary),
                SummaryItem(systemImage: "building.2", label: "Access", value: draft.infrastructureSummary),
                SummaryItem(systemImage: "calendar.badge.clock", label: "Availability", value: draft.availabilitySummary),
                SummaryItem(systemImage: "timer", label: "Capacity", value: draft.rhythmSummary),
                SummaryItem(systemImage: "figure", label: "Body baseline", value: draft.bodyBaselineSummary),
                SummaryItem(systemImage: "arrow.down.circle", label: "Floor", value: draft.floorSummary)
            ]
        }
    }

    private var healthScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Connect\nApple Health.",
                copy: "HAYF reads your workouts, daily movement, sleep, recovery, body metrics, and available nutrition logs before building the first plan."
            )

            VStack(alignment: .leading, spacing: 0) {
                Text("WHAT HAYF USES")
                    .font(.system(size: 10, weight: .medium))
                    .kerning(1.2)
                    .foregroundStyle(HAYFColor.secondary)
                    .padding(.bottom, 14)

                HealthUseRow(systemImage: "figure.strengthtraining.traditional", title: "Workout ledger", subtitle: "Workout history, type mix, duration, distance, and recency.")
                HealthUseRow(systemImage: "figure.walk", title: "Activity baseline", subtitle: "Steps, active energy, exercise minutes, and distance trends.")
                HealthUseRow(systemImage: "moon", title: "Recovery signals", subtitle: "Sleep, resting heart rate, HRV, respiratory rate, and cardio fitness.")
                HealthUseRow(systemImage: "fork.knife", title: "Body and nutrition context", subtitle: "Body metrics and any available nutrition logs, treated cautiously if stale.", showsDivider: false)
            }
            .padding(18)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Used locally first to compute deterministic features.")
                    Text("AI receives compact summaries, not raw HealthKit samples.")
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
            }

            Toggle(isOn: $useMockHealthData) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add mock Health data")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)

                    Text("Use Daniel's fixture snapshot instead of asking the Simulator for Apple Health data.")
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(HAYFColor.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: HAYFColor.orange))
            .padding(16)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
            .onChange(of: useMockHealthData) { _, isEnabled in
                if isEnabled {
                    loadMockHealthSnapshot()
                } else {
                    pendingHealthSnapshot = nil
                    mockHealthDataMessage = nil
                    if healthRequestState == .connected {
                        healthRequestState = .idle
                    }
                }
            }

            if let mockHealthDataMessage {
                Text(mockHealthDataMessage)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = healthRequestState.message {
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(healthRequestState.isError ? HAYFColor.error : HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let completionErrorMessage {
                Text(completionErrorMessage)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(HAYFColor.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var athleteBlueprintScreen: some View {
        let blueprint = currentAthleteBlueprint

        return VStack(alignment: .leading, spacing: 26) {
            OnboardingIntro(
                eyebrow: "ATHLETE BLUEPRINT",
                title: "Here's what HAYF\nsees so far.",
                copy: "A quick read on your training history, current baseline, and how your goal fits."
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("COACH'S READ")
                    .font(.system(size: 10, weight: .medium))
                    .kerning(1.2)
                    .foregroundStyle(HAYFColor.secondary)

                Text(blueprint.coachRead.preview)
                    .font(.system(size: 18, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(HAYFColor.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
            }

            VStack(spacing: 12) {
                AthleteBlueprintSummaryRow(
                    systemImage: "person.text.rectangle",
                    eyebrow: "ATHLETE TYPE",
                    title: blueprint.archetype.label,
                    summary: blueprint.archetype.explanation
                )

                AthleteBlueprintSummaryRow(
                    systemImage: "waveform.path.ecg",
                    eyebrow: "CURRENT STATE",
                    title: blueprint.currentTrainingState.label,
                    summary: blueprint.currentTrainingState.summary
                )

                AthleteBlueprintSummaryRow(
                    systemImage: "figure",
                    eyebrow: "PHYSICAL BASELINE",
                    title: blueprint.physicalBaseline.label,
                    summary: blueprint.physicalBaseline.summary
                )
            }

            SummarySection(title: "What your history shows") {
                VStack(spacing: 10) {
                    ForEach(blueprint.historyFindings) { finding in
                        AthleteBlueprintFindingRow(finding: finding)
                    }
                }
            }

            SummarySection(title: "Goal fit") {
                AthleteBlueprintGoalFitCard(goalFit: blueprint.goalFit)
            }
        }
    }

    private var fitnessStrategyScreen: some View {
        let strategy = currentFitnessStrategy

        return VStack(alignment: .leading, spacing: 26) {
            OnboardingIntro(
                eyebrow: "FITNESS STRATEGY",
                title: "Your strategy\nis ready.",
                copy: "Built from your goal and Athlete Blueprint, this is the approach HAYF will coach from before it turns the first weeks into workouts."
            )

            SummarySection(title: "Strategy snapshot") {
                FitnessStrategySnapshotGrid(items: strategy.snapshotItems)
            }

            FitnessStrategyReadCard(read: strategy.read)

            SummarySection(title: "Why this fits you") {
                VStack(spacing: 10) {
                    ForEach(strategy.fitReasons) { reason in
                        FitnessStrategyFitReasonRow(reason: reason)
                    }
                }
            }

            SummarySection(title: "What HAYF will prioritize") {
                VStack(spacing: 10) {
                    ForEach(strategy.pillars) { pillar in
                        FitnessStrategyPillarRow(pillar: pillar)
                    }
                }
            }

            SummarySection(title: "Strategy targets") {
                VStack(spacing: 10) {
                    ForEach(strategy.targets) { target in
                        FitnessStrategyTargetRow(target: target, label: "Strategy target")
                    }
                }
            }

            if let operatingRhythm = strategy.operatingRhythm {
                SummarySection(title: "Operating rhythm") {
                    FitnessStrategyOperatingRhythmCard(rhythm: operatingRhythm)
                }
            }
        }
    }

    private var fitnessStrategyPhasesScreen: some View {
        let strategy = currentFitnessStrategy

        return VStack(alignment: .leading, spacing: 26) {
            OnboardingIntro(
                eyebrow: "STRATEGY PHASES",
                title: "How HAYF will\nsequence this.",
                copy: "These phases turn the strategy targets into a simple progression. Weekly targets come next with your plan."
            )

            SummarySection(title: "How the strategy unfolds") {
                VStack(spacing: 10) {
                    ForEach(strategy.phases) { phase in
                        FitnessStrategyPhaseRow(phase: phase)
                    }
                }
            }

            FitnessStrategyPlanBridgeCard()
        }
    }

    private var bottomAction: some View {
        VStack(spacing: 14) {
            OnboardingPrimaryButton(
                title: primaryButtonTitle,
                isEnabled: canContinue,
                isLoading: healthRequestState == .requesting || step.isGenerating || isCompleting
            ) {
                primaryAction()
            }

            if step == .summary {
                Button("Edit answers") {
                    step = summaryEditStep
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(HAYFColor.surface)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(HAYFColor.borderStrong, lineWidth: 1)
                }
            } else if step == .athleteBlueprint {
                Button("Edit answers") {
                    athleteBlueprint = nil
                    fitnessStrategy = nil
                    pendingHealthSnapshot = nil
                    step = summaryEditStep
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(HAYFColor.surface)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(HAYFColor.borderStrong, lineWidth: 1)
                }
            } else if step == .goalCandidates {
                HStack(spacing: 12) {
                    Button("Edit selected") {
                        prepareCandidateEdit()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selectedGoalCandidateID == nil ? HAYFColor.muted : HAYFColor.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(HAYFColor.surface)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(HAYFColor.border, lineWidth: 1)
                    }
                    .disabled(selectedGoalCandidateID == nil)

                    Button("Blend two") {
                        blendCandidateIDs = []
                        blendedCandidate = nil
                        step = .blendCandidates
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(HAYFColor.surface)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(HAYFColor.border, lineWidth: 1)
                    }
                }
            } else if step == .blendPreview {
                Button("Choose different goals") {
                    step = .blendCandidates
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingBlueprint, .generatingStrategy:
            return "Working"
        case .summary:
            return "Looks right"
        case .health:
            if isCompleting {
                return "Finishing"
            }
            if healthRequestState == .connected || healthRequestState == .unavailable {
                return "Build athlete blueprint"
            }
            return "Connect Apple Health"
        case .athleteBlueprint:
            return "Accept blueprint"
        case .fitnessStrategy:
            if currentFitnessStrategy.phases.isEmpty {
                return "Accept strategy"
            }
            return "Review phases"
        case .fitnessStrategyPhases:
            return "Accept strategy"
        case .blendPreview:
            return "Use blended goal"
        case .editCandidate:
            return "Use edited goal"
        case .blendCandidates:
            return "Preview blend"
        default:
            return "Continue"
        }
    }

    private var canContinue: Bool {
        switch step {
        case .intent:
            return selectedIntent != nil
        case .goalBrief:
            return !draft.goalBrief.trimmed.isEmpty
        case .goalExperience:
            return draft.goalExperience != nil
        case .goalTimeline:
            return draft.goalTimeline != nil
        case .goalPriority:
            return draft.goalPriority != nil
        case .options:
            return !draft.trainingOptions.isEmpty
        case .infrastructure:
            return !draft.infrastructureAccess.isEmpty
        case .anchor:
            return !draft.motivationAnchors.isEmpty
        case .findDirection:
            return draft.goalDirection != nil
        case .findChallenge:
            return draft.challengeStyle != nil
        case .findAvoids:
            return !draft.goalAvoidances.isEmpty
        case .goalCandidates:
            return selectedGoalCandidateID != nil
        case .editCandidate:
            return !editingGoalText.trimmed.isEmpty
        case .blendCandidates:
            return blendCandidateIDs.count == 2
        case .blendPreview:
            return blendedCandidate != nil
        case .weeklyCommitment:
            return draft.frequency != nil
        case .sessionCapacity:
            return draft.sessionLength != nil
        case .weeklyAvailability:
            return !draft.availableDays.isEmpty && !draft.availableDayParts.isEmpty
        case .friction:
            return !draft.blockers.isEmpty
        case .injuries:
            return true
        case .bodyBasics:
            return draft.hasValidBodyBasics
        case .bodyFatEstimate:
            return draft.bodyFatBand != nil
        case .support:
            return draft.supportStyle != nil
        case .floor:
            return draft.badDayFloor != nil
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingBlueprint, .generatingStrategy:
            return false
        default:
            return true
        }
    }

    private func primaryAction() {
        switch step {
        case .intent:
            guard let selectedIntent else { return }
            resetGeneratedOutputs()
            if selectedIntent == .stayConsistent {
                step = .options
            } else if selectedIntent == .concreteGoal {
                step = .goalBrief
            } else {
                step = .options
            }
        case .goalBrief:
            step = .goalExperience
        case .goalExperience:
            step = .goalTimeline
        case .goalTimeline:
            step = .goalPriority
        case .goalPriority:
            step = .options
        case .options:
            step = .infrastructure
        case .infrastructure:
            if selectedIntent == .findGoal {
                step = .findDirection
            } else if selectedIntent == .concreteGoal {
                step = .weeklyCommitment
            } else {
                step = .anchor
            }
        case .anchor:
            step = .weeklyCommitment
        case .findDirection:
            step = .findChallenge
        case .findChallenge:
            step = .findAvoids
        case .findAvoids:
            step = .generatingCandidates
        case .goalCandidates:
            if let selectedCandidate {
                draft.chosenGoal = selectedCandidate
                draft.goalTimeline = selectedCandidate.timeline
            }
            step = .weeklyCommitment
        case .editCandidate:
            draft.chosenGoal = GoalCandidate(
                id: "edited-goal",
                title: editingGoalText.trimmed,
                rationale: "Edited by you from HAYF's suggested direction.",
                tracking: "HAYF will track consistency, recovery, and the goal markers you choose.",
                timeline: editingGoalTimeline,
                systemImage: "pencil"
            )
            draft.goalTimeline = editingGoalTimeline
            step = .weeklyCommitment
        case .blendCandidates:
            step = .generatingBlend
        case .blendPreview:
            draft.chosenGoal = blendedCandidate
            draft.goalTimeline = blendedCandidate?.timeline
            step = .weeklyCommitment
        case .weeklyCommitment:
            step = .sessionCapacity
        case .sessionCapacity:
            step = .weeklyAvailability
        case .weeklyAvailability:
            step = .friction
        case .friction:
            step = .injuries
        case .injuries:
            step = .bodyBasics
        case .bodyBasics:
            step = .bodyFatEstimate
        case .bodyFatEstimate:
            step = .support
        case .support:
            step = .floor
        case .floor:
            step = .generatingSummary
        case .generatingSummary:
            break
        case .summary:
            step = .health
        case .health:
            if useMockHealthData {
                loadMockHealthSnapshot()
                prepareAthleteBlueprint()
                return
            }
            if healthRequestState == .connected || healthRequestState == .unavailable {
                prepareAthleteBlueprint()
            } else {
                requestHealthAccess()
            }
        case .athleteBlueprint:
            prepareFitnessStrategy()
        case .fitnessStrategy:
            if !currentFitnessStrategy.phases.isEmpty {
                step = .fitnessStrategyPhases
                return
            }
            completeOnboarding()
        case .fitnessStrategyPhases:
            completeOnboarding()
        case .generatingCandidates, .generatingBlend, .generatingBlueprint, .generatingStrategy:
            break
        }
    }

    private func goBack() {
        switch step {
        case .intent:
            break
        case .goalBrief:
            step = .intent
        case .goalExperience:
            step = .goalBrief
        case .goalTimeline:
            step = .goalExperience
        case .goalPriority:
            step = .goalTimeline
        case .options:
            step = selectedIntent == .concreteGoal ? .goalPriority : .intent
        case .infrastructure:
            step = .options
        case .anchor:
            step = .options
        case .findDirection:
            step = .options
        case .findChallenge:
            step = .findDirection
        case .findAvoids:
            step = .findChallenge
        case .generatingCandidates:
            step = .findAvoids
        case .goalCandidates:
            step = .findAvoids
        case .editCandidate:
            step = .goalCandidates
        case .blendCandidates:
            step = .goalCandidates
        case .generatingBlend:
            step = .blendCandidates
        case .blendPreview:
            step = .blendCandidates
        case .weeklyCommitment:
            if selectedIntent == .stayConsistent {
                step = .anchor
            } else if selectedIntent == .findGoal {
                step = .goalCandidates
            } else {
                step = .infrastructure
            }
        case .sessionCapacity:
            step = .weeklyCommitment
        case .weeklyAvailability:
            step = .sessionCapacity
        case .friction:
            step = .weeklyAvailability
        case .injuries:
            step = .friction
        case .bodyBasics:
            step = .injuries
        case .bodyFatEstimate:
            step = .bodyBasics
        case .support:
            step = .bodyFatEstimate
        case .floor:
            step = .support
        case .generatingSummary:
            step = .floor
        case .summary:
            step = .floor
        case .health:
            step = .summary
        case .generatingBlueprint, .athleteBlueprint:
            step = .health
        case .generatingStrategy, .fitnessStrategy:
            step = .athleteBlueprint
        case .fitnessStrategyPhases:
            step = .fitnessStrategy
        }
    }

    private var currentIntent: OnboardingIntent {
        selectedIntent ?? .stayConsistent
    }

    private var totalSegments: Int {
        OnboardingStep.totalSegments(for: currentIntent)
    }

    private var activeSegments: Int {
        step.activeSegments(for: currentIntent)
    }

    private var progressLabel: String {
        if step.isGenerating {
            return "Building"
        }

        return "Step \(activeSegments) of \(totalSegments)"
    }

    private var displayGoalCandidates: [GoalCandidate] {
        goalCandidates.isEmpty ? MockOnboardingAIProvider.fallbackGoalCandidates(for: draft) : goalCandidates
    }

    private var selectedCandidate: GoalCandidate? {
        guard let selectedGoalCandidateID else { return nil }
        return displayGoalCandidates.first { $0.id == selectedGoalCandidateID }
    }

    private var fallbackBlendedCandidate: GoalCandidate {
        let candidates = displayGoalCandidates.filter { blendCandidateIDs.contains($0.id) }
        return MockOnboardingAIProvider.blend(candidates: candidates, draft: draft)
    }

    private var currentSummary: OnboardingSummaryOutput {
        summaryOutput ?? MockOnboardingAIProvider.fallbackSummary(intent: currentIntent, draft: draft)
    }

    private var currentAthleteBlueprint: AthleteBlueprintOutput {
        athleteBlueprint ?? AthleteBlueprintBuilder.build(
            intent: currentIntent,
            draft: draft,
            snapshot: pendingHealthSnapshot
        )
    }

    private var currentFitnessStrategy: FitnessStrategyOutput {
        fitnessStrategy ?? FitnessStrategyBuilder.build(
            intent: currentIntent,
            draft: draft,
            blueprint: currentAthleteBlueprint,
            snapshot: pendingHealthSnapshot
        )
    }

    private var summaryEditStep: OnboardingStep {
        .options
    }

    private func resetGeneratedOutputs() {
        summaryOutput = nil
        goalCandidates = []
        selectedGoalCandidateID = nil
        editingGoalText = ""
        editingGoalTimeline = .eightWeeks
        blendCandidateIDs = []
        blendedCandidate = nil
        athleteBlueprint = nil
        fitnessStrategy = nil
        aiGenerationFailure = nil
    }

    private func prepareCandidateEdit() {
        guard let selectedCandidate else { return }
        editingGoalText = "\(selectedCandidate.title): \(selectedCandidate.rationale)"
        editingGoalTimeline = selectedCandidate.timeline
        step = .editCandidate
    }

    private func toggleAvoidance(_ avoidance: GoalAvoidance) {
        if avoidance == .nothingSpecific {
            draft.goalAvoidances = [.nothingSpecific]
            return
        }

        draft.goalAvoidances.remove(.nothingSpecific)
        draft.goalAvoidances.toggle(avoidance)
    }

    private func toggleBlendCandidate(_ candidate: GoalCandidate) {
        if blendCandidateIDs.contains(candidate.id) {
            blendCandidateIDs.remove(candidate.id)
        } else if blendCandidateIDs.count < 2 {
            blendCandidateIDs.insert(candidate.id)
        } else if let first = blendCandidateIDs.first {
            blendCandidateIDs.remove(first)
            blendCandidateIDs.insert(candidate.id)
        }
    }

    private func generateSummary() async {
        aiGenerationFailure = nil
        do {
            let output = try await aiProvider.generateSummary(intent: currentIntent, draft: draft)
            guard output.isValid else {
                throw OnboardingAIError.emptyOutput
            }
            summaryOutput = output
            step = .summary
        } catch {
            aiGenerationFailure = OnboardingAIGenerationFailure(step: .generatingSummary, error: error)
        }
    }

    private func generateGoalCandidates() async {
        aiGenerationFailure = nil
        do {
            let candidates = try await aiProvider.generateGoalCandidates(draft: draft)
            guard candidates.count == 3 else {
                throw OnboardingAIError.invalidCandidateCount
            }
            goalCandidates = candidates
            selectedGoalCandidateID = nil
            step = .goalCandidates
        } catch {
            aiGenerationFailure = OnboardingAIGenerationFailure(step: .generatingCandidates, error: error)
        }
    }

    private func generateBlendedCandidate() async {
        aiGenerationFailure = nil
        let candidates = displayGoalCandidates.filter { blendCandidateIDs.contains($0.id) }
        do {
            blendedCandidate = try await aiProvider.generateBlendedCandidate(from: candidates, draft: draft)
            guard blendedCandidate != nil else {
                throw OnboardingAIError.emptyOutput
            }
            step = .blendPreview
        } catch {
            aiGenerationFailure = OnboardingAIGenerationFailure(step: .generatingBlend, error: error)
        }
    }

    private func refreshHealthState() async {
        guard !useMockHealthData else {
            loadMockHealthSnapshot()
            return
        }

        let state = await healthKitManager.requestStatus()
        switch state {
        case .unnecessary:
            healthRequestState = .connected
        case .unavailable:
            healthRequestState = .unavailable
        case .shouldRequest, .unknown:
            if healthRequestState != .requesting {
                healthRequestState = .idle
            }
        }
    }

    private func requestHealthAccess() {
        if useMockHealthData {
            loadMockHealthSnapshot()
            prepareAthleteBlueprint()
            return
        }

        Task {
            healthRequestState = .requesting
            do {
                try await healthKitManager.requestReadAuthorization()
                healthRequestState = .connected
                prepareAthleteBlueprint()
            } catch HealthKitError.healthDataUnavailable {
                healthRequestState = .unavailable
            } catch {
                healthRequestState = .failed(error.localizedDescription)
            }
        }
    }

    private func prepareAthleteBlueprint() {
        completionErrorMessage = nil
        step = .generatingBlueprint
    }

    private func generateAthleteBlueprint() async {
        aiGenerationFailure = nil
        let snapshot = await planningHealthSnapshot()
        pendingHealthSnapshot = snapshot
        let fallback = AthleteBlueprintBuilder.build(
            intent: currentIntent,
            draft: draft,
            snapshot: snapshot
        )
        do {
            athleteBlueprint = try await aiProvider.generateAthleteBlueprint(
                intent: currentIntent,
                draft: draft,
                snapshot: snapshot,
                fallback: fallback
            )
            step = .athleteBlueprint
        } catch {
            aiGenerationFailure = OnboardingAIGenerationFailure(step: .generatingBlueprint, error: error)
        }
    }

    private func prepareFitnessStrategy() {
        completionErrorMessage = nil
        step = .generatingStrategy
    }

    private func generateFitnessStrategy() async {
        aiGenerationFailure = nil
        let fallback = FitnessStrategyBuilder.build(
            intent: currentIntent,
            draft: draft,
            blueprint: currentAthleteBlueprint,
            snapshot: pendingHealthSnapshot
        )
        do {
            fitnessStrategy = try await aiProvider.generateFitnessStrategy(
                intent: currentIntent,
                draft: draft,
                blueprint: currentAthleteBlueprint,
                fallback: fallback
            )
            step = .fitnessStrategy
        } catch {
            aiGenerationFailure = OnboardingAIGenerationFailure(step: .generatingStrategy, error: error)
        }
    }

    private func retryCurrentGeneration() {
        aiGenerationFailure = nil
        Task {
            switch step {
            case .generatingSummary:
                await generateSummary()
            case .generatingCandidates:
                await generateGoalCandidates()
            case .generatingBlend:
                await generateBlendedCandidate()
            case .generatingBlueprint:
                await generateAthleteBlueprint()
            case .generatingStrategy:
                await generateFitnessStrategy()
            default:
                break
            }
        }
    }

    private func aiGenerationFailure(for step: OnboardingStep) -> OnboardingAIGenerationFailure? {
        guard aiGenerationFailure?.step == step else { return nil }
        return aiGenerationFailure
    }

    private func completeOnboarding() {
        guard !isCompleting else { return }

        Task {
            await MainActor.run {
                isCompleting = true
                completionErrorMessage = nil
            }
            defer {
                Task { @MainActor in
                    isCompleting = false
                }
            }

            do {
                let acceptedAt = Date()
                let acceptedBlueprint = currentAthleteBlueprint
                let acceptedStrategy = currentFitnessStrategy
                let syncPayload = try? await healthSyncService.buildSyncPayload(daysBack: 14)
                let healthSnapshot: HealthFeatureSnapshot?
                if let pendingHealthSnapshot {
                    healthSnapshot = pendingHealthSnapshot
                } else if let syncPayload {
                    healthSnapshot = syncPayload.healthSnapshot
                } else {
                    healthSnapshot = await planningHealthSnapshot()
                }
                let completedProfile = try await onboardingProfileStore.completeCurrentUserOnboarding(
                    intent: currentIntent,
                    draft: draft,
                    summary: currentSummary,
                    healthRequestState: healthRequestState
                )
                _ = try await planningAIProvider.acceptStrategyAndCreateInitialPlan(
                    healthSnapshot: healthSnapshot,
                    actualWorkouts: syncPayload?.actualWorkouts ?? [],
                    acceptedBlueprint: acceptedBlueprintArtifact(from: acceptedBlueprint),
                    acceptedStrategy: acceptedStrategyArtifact(from: acceptedStrategy),
                    deviceTimezone: TimeZone.current.identifier,
                    acceptedAt: acceptedAt
                )
                await MainActor.run {
                    onboardingProfileStore.useProfile(completedProfile)
                    onComplete()
                }
            } catch {
                completionLogger.error("Onboarding completion failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    completionErrorMessage = "HAYF could not generate your AI plan yet. Try again in a moment."
                }
            }
        }
    }

    private func acceptedBlueprintArtifact(from blueprint: AthleteBlueprintOutput) -> JSONValue {
        .object([
            "coachRead": .object([
                "preview": .string(blueprint.coachRead.preview),
                "text": .string(blueprint.coachRead.text),
                "detail": blueprintDetailArtifact(blueprint.coachRead.detail)
            ]),
            "archetype": .object([
                "label": .string(blueprint.archetype.label),
                "explanation": .string(blueprint.archetype.explanation),
                "detail": blueprintDetailArtifact(blueprint.archetype.detail)
            ]),
            "currentTrainingState": .object([
                "label": .string(blueprint.currentTrainingState.label),
                "summary": .string(blueprint.currentTrainingState.summary),
                "detail": blueprintDetailArtifact(blueprint.currentTrainingState.detail)
            ]),
            "physicalBaseline": .object([
                "label": .string(blueprint.physicalBaseline.label),
                "summary": .string(blueprint.physicalBaseline.summary),
                "detail": blueprintDetailArtifact(blueprint.physicalBaseline.detail)
            ]),
            "historyFindings": .array(blueprint.historyFindings.map { finding in
                .object([
                    "id": .string(finding.id),
                    "title": .string(finding.title),
                    "summary": .string(finding.summary),
                    "detail": blueprintDetailArtifact(finding.detail)
                ])
            }),
            "goalFit": .object([
                "headline": .string(blueprint.goalFit.headline),
                "summary": .string(blueprint.goalFit.summary),
                "supports": .array(blueprint.goalFit.supports.map { .string($0) }),
                "gaps": .array(blueprint.goalFit.gaps.map { .string($0) }),
                "detail": blueprintDetailArtifact(blueprint.goalFit.detail)
            ])
        ])
    }

    private func blueprintDetailArtifact(_ detail: AthleteBlueprintDetail) -> JSONValue {
        .object([
            "id": .string(detail.id),
            "title": .string(detail.title),
            "summary": .string(detail.summary),
            "body": detail.body.map(JSONValue.string) ?? .null,
            "confidence": .string(detail.confidence),
            "observationWindow": .string(detail.observationWindow),
            "evidence": .array(detail.evidence.map { .string($0) }),
            "caveat": detail.caveat.map(JSONValue.string) ?? .null
        ])
    }

    private func acceptedStrategyArtifact(from strategy: FitnessStrategyOutput) -> JSONValue {
        .object([
            "read": .string(strategy.read),
            "goalTargetContext": .object([
                "title": .string(strategy.goalTargetContext.title),
                "summary": .string(strategy.goalTargetContext.summary)
            ]),
            "snapshotItems": .array(strategy.snapshotItems.map { item in
                .object([
                    "id": .string(item.id),
                    "systemImage": .string(item.systemImage),
                    "value": .string(item.value),
                    "label": .string(item.label)
                ])
            }),
            "fitReasons": .array(strategy.fitReasons.map { reason in
                .object([
                    "id": .string(reason.id),
                    "systemImage": .string(reason.systemImage),
                    "title": .string(reason.title),
                    "summary": .string(reason.summary)
                ])
            }),
            "pillars": .array(strategy.pillars.map { pillar in
                .object([
                    "id": .string(pillar.id),
                    "title": .string(pillar.title),
                    "summary": .string(pillar.summary)
                ])
            }),
            "phases": .array(strategy.phases.map { phase in
                .object([
                    "id": .string(phase.id),
                    "name": .string(phase.name),
                    "objective": .string(phase.objective),
                    "targetSummary": .string(phase.targetSummary),
                    "targets": .array(phase.targets.map(strategyTargetArtifact)
                    )
                ])
            }),
            "operatingRhythm": strategy.operatingRhythm.map { rhythm in
                .object([
                    "summary": .string(rhythm.summary),
                    "anchors": .array(rhythm.anchors.map { .string($0) })
                ])
            } ?? .null,
            "targets": .array(strategy.targets.map(strategyTargetArtifact))
        ])
    }

    private func strategyTargetArtifact(_ target: FitnessStrategyTarget) -> JSONValue {
        .object([
            "id": .string(target.id),
            "scope": .string(target.scope.rawValue),
            "kind": .string(target.kind.rawValue),
            "title": .string(target.title),
            "summary": .string(target.summary),
            "metricKey": target.metricKey.map(JSONValue.string) ?? .null,
            "metricCategory": .string(target.metricCategory),
            "direction": .string(target.direction.rawValue),
            "targetValue": target.targetValue.map(JSONValue.number) ?? .null,
            "unit": target.unit.map(JSONValue.string) ?? .null,
            "displayValue": target.displayValue.map(JSONValue.string) ?? .null
        ])
    }

    private func compactHealthSnapshot() async -> OnboardingAIHealthSnapshot? {
        guard let snapshot = await planningHealthSnapshot() else { return nil }
        return OnboardingAIHealthSnapshot(snapshot: snapshot)
    }

    private func planningHealthSnapshot() async -> HealthFeatureSnapshot? {
        if useMockHealthData {
            if let pendingHealthSnapshot {
                return pendingHealthSnapshot
            }
            return HealthFeatureSnapshotFixtureStore.danielSnapshot()
        }

        guard healthRequestState == .connected else { return nil }

        do {
            return try await healthKitManager.fetchFeatureSnapshot()
        } catch {
            return nil
        }
    }

    private func loadMockHealthSnapshot() {
        guard let snapshot = HealthFeatureSnapshotFixtureStore.danielSnapshot() else {
            healthRequestState = .failed("Could not load the mock Health data fixture.")
            mockHealthDataMessage = nil
            return
        }

        pendingHealthSnapshot = snapshot
        healthRequestState = .connected
        mockHealthDataMessage = "Mock Health data loaded: \(snapshot.fitnessHistory.trainingIdentity.label), \(snapshot.workoutLedger.totalWorkouts) workouts, longest cycling ride \(Int((snapshot.workoutLedger.longestCyclingDistanceKilometers ?? 0).rounded())) km."
    }
}

private enum OnboardingStep: Equatable {
    case intent
    case goalBrief
    case goalExperience
    case goalTimeline
    case goalPriority
    case options
    case infrastructure
    case anchor
    case findDirection
    case findChallenge
    case findAvoids
    case generatingCandidates
    case goalCandidates
    case editCandidate
    case blendCandidates
    case generatingBlend
    case blendPreview
    case weeklyCommitment
    case sessionCapacity
    case weeklyAvailability
    case friction
    case injuries
    case bodyBasics
    case bodyFatEstimate
    case support
    case floor
    case generatingSummary
    case summary
    case health
    case generatingBlueprint
    case athleteBlueprint
    case generatingStrategy
    case fitnessStrategy
    case fitnessStrategyPhases

    var isGenerating: Bool {
        switch self {
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingBlueprint, .generatingStrategy:
            return true
        default:
            return false
        }
    }

    static func totalSegments(for intent: OnboardingIntent) -> Int {
        switch intent {
        case .stayConsistent:
            return 17
        case .concreteGoal:
            return 21
        case .findGoal:
            return 21
        }
    }

    func activeSegments(for intent: OnboardingIntent) -> Int {
        switch intent {
        case .stayConsistent:
            switch self {
            case .intent: return 1
            case .options: return 2
            case .infrastructure: return 3
            case .anchor: return 4
            case .weeklyCommitment: return 5
            case .sessionCapacity: return 6
            case .weeklyAvailability: return 7
            case .friction: return 8
            case .injuries: return 9
            case .bodyBasics: return 10
            case .bodyFatEstimate: return 11
            case .support: return 12
            case .floor, .generatingSummary: return 13
            case .summary: return 14
            case .health, .generatingBlueprint: return 15
            case .athleteBlueprint, .generatingStrategy: return 16
            case .fitnessStrategy: return 17
            default: return 1
            }
        case .concreteGoal:
            switch self {
            case .intent: return 1
            case .goalBrief: return 2
            case .goalExperience: return 3
            case .goalTimeline: return 4
            case .goalPriority: return 5
            case .options: return 6
            case .infrastructure: return 7
            case .weeklyCommitment: return 8
            case .sessionCapacity: return 9
            case .weeklyAvailability: return 10
            case .friction: return 11
            case .injuries: return 12
            case .bodyBasics: return 13
            case .bodyFatEstimate: return 14
            case .support: return 15
            case .floor, .generatingSummary: return 16
            case .summary: return 17
            case .health, .generatingBlueprint: return 18
            case .athleteBlueprint, .generatingStrategy: return 19
            case .fitnessStrategy: return 20
            case .fitnessStrategyPhases: return 21
            default: return 1
            }
        case .findGoal:
            switch self {
            case .intent: return 1
            case .options: return 2
            case .infrastructure: return 3
            case .findDirection: return 4
            case .findChallenge: return 5
            case .findAvoids, .generatingCandidates: return 6
            case .goalCandidates, .editCandidate, .blendCandidates, .generatingBlend, .blendPreview: return 7
            case .weeklyCommitment: return 8
            case .sessionCapacity: return 9
            case .weeklyAvailability: return 10
            case .friction: return 11
            case .injuries: return 12
            case .bodyBasics: return 13
            case .bodyFatEstimate: return 14
            case .support: return 15
            case .floor, .generatingSummary: return 16
            case .summary: return 17
            case .health, .generatingBlueprint: return 18
            case .athleteBlueprint, .generatingStrategy: return 19
            case .fitnessStrategy: return 20
            case .fitnessStrategyPhases: return 21
            default: return 1
            }
        }
    }

    var showsBackButton: Bool {
        self != .intent
    }
}

private struct OnboardingAIGenerationFailure: Equatable {
    let step: OnboardingStep
    let technicalMessage: String

    init(step: OnboardingStep, error: Error) {
        self.step = step
        technicalMessage = error.localizedDescription
    }

    var title: String {
        switch step {
        case .generatingCandidates:
            return "Could not create goal options."
        case .generatingBlend:
            return "Could not blend those goals."
        case .generatingSummary:
            return "Could not write your readback."
        case .generatingBlueprint:
            return "Could not build your Athlete Blueprint."
        case .generatingStrategy:
            return "Could not build your strategy."
        default:
            return "AI step failed."
        }
    }

    var copy: String {
        "This part needs AI. HAYF will not show generic fallback copy here because it would be pretending to know more than it does."
    }

    var detail: String {
        let trimmed = technicalMessage.trimmed
        guard !trimmed.isEmpty else {
            return "Check your connection and try again."
        }
        return "Check your connection and try again. Technical detail: \(trimmed)"
    }
}

private enum OnboardingIntent: String, CaseIterable, Identifiable {
    case stayConsistent
    case concreteGoal
    case findGoal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stayConsistent: return "Help me stay consistent"
        case .concreteGoal: return "I have a specific goal"
        case .findGoal: return "Help me find a goal"
        }
    }

    var subtitle: String {
        switch self {
        case .stayConsistent: return "No fixed goal. Keep me balanced and moving."
        case .concreteGoal: return "Build around a target, event, or timeline."
        case .findGoal: return "Suggest a direction that fits me."
        }
    }

    var systemImage: String {
        switch self {
        case .stayConsistent: return "timer"
        case .concreteGoal: return "flag"
        case .findGoal: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }

    var placeholderTitle: String {
        switch self {
        case .stayConsistent: return title
        case .concreteGoal: return "Specific goal setup\nis coming next."
        case .findGoal: return "Goal discovery\nis coming next."
        }
    }

    var placeholderCopy: String {
        switch self {
        case .stayConsistent:
            return subtitle
        case .concreteGoal:
            return "This path will capture target, baseline, timeline, constraints, and realism."
        case .findGoal:
            return "This path will help HAYF propose goal candidates from identity, preferences, and constraints."
        }
    }
}

private struct ConsistencyOnboardingDraft {
    var trainingOptions: [TrainingOption] = []
    var infrastructureAccess: Set<InfrastructureAccess> = []
    var motivationAnchors: Set<MotivationAnchor> = []
    var motivationNote = ""
    var goalBrief = ""
    var injuryNotes = ""
    var goalExperience: GoalExperience?
    var goalTimeline: GoalTimeline?
    var goalDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    var goalPriority: GoalPriority?
    var goalDirection: GoalDirection?
    var challengeStyle: ChallengeStyle?
    var goalAvoidances: Set<GoalAvoidance> = []
    var chosenGoal: GoalCandidate?
    var frequency: TrainingFrequency?
    var sessionLength: SessionLength?
    var availableDays: Set<Weekday> = []
    var availableDayParts: Set<DayPart> = []
    var blockers: Set<ConsistencyBlocker> = []
    var blockerNote = ""
    var bodyMassKilogramsInput = ""
    var heightCentimetersInput = ""
    var bodyFatBand: BodyFatBand?
    var supportStyle: CoachingSupportStyle?
    var badDayFloor: BadDayFloor?

    var motivationSummary: String {
        summary(for: motivationAnchors.map(\.title), fallback: "Not set")
    }

    var motivationInputSummary: String {
        summaryWithOptionalNote(values: motivationAnchors.map(\.title), note: motivationNote, fallback: "Not set")
    }

    var trainingSummary: String {
        guard !trainingOptions.isEmpty else { return "Not set" }
        return trainingOptions.enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: ", ")
    }

    var rhythmSummary: String {
        guard let frequency, let sessionLength else { return "Not set" }
        return "\(frequency.summary), usually \(sessionLength.title)"
    }

    var infrastructureSummary: String {
        summary(for: infrastructureAccess.map(\.title), fallback: "Not set")
    }

    var availabilitySummary: String {
        let days = summary(for: availableDays.map(\.shortTitle), fallback: "No days set")
        let dayParts = summary(for: availableDayParts.map(\.title), fallback: "no times set")
        return "\(days); \(dayParts)"
    }

    var blockerSummary: String {
        summary(for: blockers.map(\.title), fallback: "Not set")
    }

    var blockerInputSummary: String {
        summaryWithOptionalNote(values: blockers.map(\.title), note: blockerNote, fallback: "Not set")
    }

    var supportSummary: String {
        supportStyle?.summaryTitle ?? "Not set"
    }

    var floorSummary: String {
        badDayFloor?.title ?? "Not set"
    }

    var goalSummary: String {
        if let chosenGoal {
            return chosenGoal.title
        }

        let trimmedGoal = goalBrief.trimmed
        return trimmedGoal.isEmpty ? "Not set" : trimmedGoal
    }

    var experienceSummary: String {
        goalExperience?.title ?? "Not set"
    }

    var injurySummary: String {
        let trimmedInjuryNotes = injuryNotes.trimmed
        return trimmedInjuryNotes.isEmpty ? "None noted" : trimmedInjuryNotes
    }

    var bodyMassKilograms: Double? {
        Double(bodyMassKilogramsInput.replacingOccurrences(of: ",", with: "."))
    }

    var heightCentimeters: Double? {
        Double(heightCentimetersInput.replacingOccurrences(of: ",", with: "."))
    }

    var hasValidBodyBasics: Bool {
        guard let bodyMassKilograms, let heightCentimeters else { return false }
        return (25...350).contains(bodyMassKilograms) && (100...250).contains(heightCentimeters)
    }

    var bodyBaselineSummary: String {
        let bodyMass = bodyMassKilograms.map { String(format: "%.1f kg", $0) } ?? "weight not set"
        let height = heightCentimeters.map { "\(Int($0.rounded())) cm" } ?? "height not set"
        let bodyFat = bodyFatBand?.title ?? "body fat not set"
        return "\(bodyMass), \(height), \(bodyFat)"
    }

    var timelineSummary: String {
        guard let goalTimeline else { return "Not set" }
        if goalTimeline == .specificDate {
            return Self.goalDateFormatter.string(from: goalDate)
        }

        return goalTimeline.title
    }

    var prioritySummary: String {
        goalPriority?.summaryTitle ?? "Not set"
    }

    var directionSummary: String {
        goalDirection?.title ?? "Not set"
    }

    var challengeSummary: String {
        challengeStyle?.title ?? "Not set"
    }

    var avoidsSummary: String {
        summary(for: goalAvoidances.map(\.title), fallback: "No avoids set")
    }

    private func summary(for values: [String], fallback: String) -> String {
        let sortedValues = values.sorted()
        guard !sortedValues.isEmpty else { return fallback }
        return sortedValues.prefix(3).joined(separator: ", ") + (sortedValues.count > 3 ? " +" : "")
    }

    private func summaryWithOptionalNote(values: [String], note: String, fallback: String) -> String {
        let base = summary(for: values, fallback: fallback)
        let trimmedNote = note.trimmed
        guard !trimmedNote.isEmpty else { return base }
        return base == fallback ? trimmedNote : "\(base). \(trimmedNote)"
    }

    func trainingOptionRank(for option: TrainingOption) -> Int? {
        guard let index = trainingOptions.firstIndex(of: option) else { return nil }
        return index + 1
    }

    mutating func toggleTrainingOption(_ option: TrainingOption) {
        if let index = trainingOptions.firstIndex(of: option) {
            trainingOptions.remove(at: index)
        } else {
            trainingOptions.append(option)
        }
    }

    var requiredInfrastructureOptions: [InfrastructureAccess] {
        let options = trainingOptions.flatMap(\.infrastructureOptions)
        return Array(Set(options)).sorted { $0.title < $1.title }
    }

    private static let goalDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private protocol OnboardingAIProvider {
    func generateSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) async throws -> OnboardingSummaryOutput
    func generateGoalCandidates(draft: ConsistencyOnboardingDraft) async throws -> [GoalCandidate]
    func generateBlendedCandidate(from candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) async throws -> GoalCandidate?
    func generateAthleteBlueprint(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        snapshot: HealthFeatureSnapshot?,
        fallback: AthleteBlueprintOutput
    ) async throws -> AthleteBlueprintOutput
    func generateFitnessStrategy(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        blueprint: AthleteBlueprintOutput,
        fallback: FitnessStrategyOutput
    ) async throws -> FitnessStrategyOutput
}

private enum OnboardingAIError: LocalizedError {
    case emptyOutput
    case invalidCandidateCount

    var errorDescription: String? {
        switch self {
        case .emptyOutput:
            return "The AI response was empty."
        case .invalidCandidateCount:
            return "The AI response did not include the expected goal options."
        }
    }
}

private enum OnboardingAITask: String, Codable {
    case generateSummary = "generate_summary"
    case generateGoalCandidates = "generate_goal_candidates"
    case generateBlendedCandidate = "generate_blended_candidate"
    case generateAthleteBlueprint = "generate_athlete_blueprint"
    case generateFitnessStrategyTargets = "generate_fitness_strategy_targets"
    case generateFitnessStrategy = "generate_fitness_strategy"
}

private struct OnboardingAIHealthSnapshot: Codable {
    let sleepHoursLastNight: Double?
    let workoutsLast7Days: Int
    let averageStepsLast7Days: Double?
    let heightCentimeters: Double?
    let bodyMassKilograms: Double?
    let deterministicFeatureSnapshot: HealthFeatureSnapshot

    init(snapshot: HealthFeatureSnapshot) {
        sleepHoursLastNight = snapshot.recovery.sleepHoursLastNight
        workoutsLast7Days = snapshot.workoutLedger.windows.first { $0.window == "7d" }?.workouts ?? 0
        averageStepsLast7Days = snapshot.activity.averageSteps7Days
        heightCentimeters = snapshot.body.heightCentimeters
        bodyMassKilograms = snapshot.body.bodyMassKilograms
        deterministicFeatureSnapshot = snapshot
    }
}

private struct OnboardingAICompactContext: Codable {
    let intent: String
    let intentTitle: String
    let trainingOptions: [RankedTrainingOptionPayload]
    let infrastructureAccess: [String]
    let motivationAnchors: [String]
    let motivationNote: String
    let goalBrief: String
    let injuryNotes: String
    let goalExperience: String
    let goalTimeline: String
    let goalPriority: String
    let goalDirection: String
    let challengeStyle: String
    let goalAvoidances: [String]
    let chosenGoal: GoalCandidatePayload?
    let frequency: String
    let sessionLength: String
    let availableDays: [String]
    let availableDayParts: [String]
    let blockers: [String]
    let blockerNote: String
    let supportStyle: String
    let badDayFloor: String
    let bodyBaseline: BodyBaselinePayload?
    let healthSnapshot: OnboardingAIHealthSnapshot?

    init(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft, healthSnapshot: OnboardingAIHealthSnapshot? = nil) {
        self.intent = intent.rawValue
        intentTitle = intent.title
        trainingOptions = draft.trainingOptions.enumerated().map { index, option in
            RankedTrainingOptionPayload(option: option, priority: index + 1)
        }
        infrastructureAccess = draft.infrastructureAccess.map(\.title).sorted()
        motivationAnchors = draft.motivationAnchors.map(\.title).sorted()
        motivationNote = draft.motivationNote.trimmed
        goalBrief = draft.goalBrief.trimmed
        injuryNotes = draft.injuryNotes.trimmed
        goalExperience = draft.experienceSummary
        goalTimeline = draft.timelineSummary
        goalPriority = draft.prioritySummary
        goalDirection = draft.directionSummary
        challengeStyle = draft.challengeSummary
        goalAvoidances = draft.goalAvoidances.map(\.title).sorted()
        chosenGoal = draft.chosenGoal.map(GoalCandidatePayload.init(candidate:))
        frequency = draft.frequency?.summary ?? ""
        sessionLength = draft.sessionLength?.title ?? ""
        availableDays = draft.availableDays.map(\.title).sorted()
        availableDayParts = draft.availableDayParts.map(\.title).sorted()
        blockers = draft.blockers.map(\.title).sorted()
        blockerNote = draft.blockerNote.trimmed
        supportStyle = draft.supportSummary
        badDayFloor = draft.floorSummary
        bodyBaseline = BodyBaselinePayload(draft: draft)
        self.healthSnapshot = healthSnapshot
    }
}

private struct BodyBaselinePayload: Codable {
    let heightCentimeters: Double
    let bodyMassKilograms: Double
    let bodyFatBand: String
    let bodyFatEstimateMidpoint: Double
    let source: String

    init?(draft: ConsistencyOnboardingDraft) {
        guard let heightCentimeters = draft.heightCentimeters,
              let bodyMassKilograms = draft.bodyMassKilograms,
              let bodyFatBand = draft.bodyFatBand else {
            return nil
        }

        self.heightCentimeters = heightCentimeters
        self.bodyMassKilograms = bodyMassKilograms
        self.bodyFatBand = bodyFatBand.title
        bodyFatEstimateMidpoint = bodyFatBand.midpointEstimate
        source = "onboarding_self_report"
    }
}

private struct GoalCandidatePayload: Codable {
    let id: String
    let title: String
    let rationale: String
    let tracking: String
    let timeframeWeeks: Int
    let systemImage: String

    init(candidate: GoalCandidate) {
        id = candidate.id
        title = candidate.title
        rationale = candidate.rationale
        tracking = candidate.tracking
        timeframeWeeks = candidate.timeline.weeks
        systemImage = candidate.systemImage
    }

    func goalCandidate() -> GoalCandidate {
        GoalCandidate(
            id: id,
            title: title,
            rationale: rationale,
            tracking: tracking,
            timeline: GoalTimeline(weeks: timeframeWeeks) ?? .eightWeeks,
            systemImage: systemImage
        )
    }
}

private struct RankedTrainingOptionPayload: Codable {
    let activity: String
    let title: String
    let priority: Int

    init(option: TrainingOption, priority: Int) {
        activity = option.rawValue
        title = option.title
        self.priority = priority
    }
}

private struct OnboardingAIFunctionRequest: Codable {
    let task: OnboardingAITask
    let context: OnboardingAICompactContext
    let candidates: [GoalCandidatePayload]?
}

private struct AthleteBlueprintAIFunctionRequest: Codable {
    let task: OnboardingAITask
    let context: AthleteBlueprintAICompactContext
}

private struct FitnessStrategyAIFunctionRequest: Codable {
    let task: OnboardingAITask
    let context: FitnessStrategyAICompactContext
}

private struct FitnessStrategyTargetAIFunctionRequest: Codable {
    let task: OnboardingAITask
    let context: FitnessStrategyAITargetGenerationContext
}

private struct AthleteBlueprintAICompactContext: Codable {
    let intent: String
    let normalizedGoal: AthleteBlueprintAIGoalPayload
    let feasibleTrainingOptions: [RankedTrainingOptionPayload]
    let onboardingSignals: AthleteBlueprintAIOnboardingSignals
    let evidenceSummary: AthleteBlueprintAIEvidenceSummary
    let sectionSeeds: AthleteBlueprintAISectionSeeds
    let doNotClaim: [String]

    init(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        snapshot: HealthFeatureSnapshot?,
        fallback: AthleteBlueprintOutput
    ) {
        let goal = AthleteBlueprintBuilder.normalizedGoal(intent: intent, draft: draft)
        let evidence = AthleteBlueprintEvidence(snapshot: snapshot)

        self.intent = intent.rawValue
        normalizedGoal = AthleteBlueprintAIGoalPayload(goal: goal)
        feasibleTrainingOptions = draft.trainingOptions.enumerated().map { index, option in
            RankedTrainingOptionPayload(option: option, priority: index + 1)
        }
        onboardingSignals = AthleteBlueprintAIOnboardingSignals(
            goalPriority: draft.prioritySummary,
            frequencyPreference: draft.frequency?.summary ?? "",
            sessionLengthPreference: draft.sessionLength?.title ?? "",
            availableDays: draft.availableDays.map(\.title).sorted(),
            availableDayParts: draft.availableDayParts.map(\.title).sorted(),
            infrastructureAccess: draft.infrastructureAccess.map(\.title).sorted(),
            blockers: draft.blockers.map(\.title).sorted(),
            blockerNote: draft.blockerNote.trimmed,
            supportStyle: draft.supportSummary,
            badDayFloor: draft.floorSummary,
            injuryNotes: draft.injuryNotes.trimmed,
            bodyBaseline: BodyBaselinePayload(draft: draft)
        )
        evidenceSummary = AthleteBlueprintAIEvidenceSummary(evidence: evidence)
        sectionSeeds = AthleteBlueprintAISectionSeeds(output: fallback)
        doNotClaim = [
            "Treat onboarding bodyBaseline as the current body-composition truth. Treat imported HealthKit body metrics as trend context only when section seeds explicitly include them.",
            "Do not infer motivation, personality, or physiology beyond the section seeds and onboarding signals.",
            "Do not reject the user's selected goal because historical dominant modalities differ from their chosen feasible training options."
        ]
    }
}

private struct AthleteBlueprintAIGoalPayload: Codable {
    let displayText: String
    let horizonWeeks: Int
    let category: String

    init(goal: AthleteBlueprintGoal) {
        displayText = goal.displayText
        horizonWeeks = goal.horizonWeeks
        category = goal.category.rawValue
    }
}

private struct AthleteBlueprintAIOnboardingSignals: Codable {
    let goalPriority: String
    let frequencyPreference: String
    let sessionLengthPreference: String
    let availableDays: [String]
    let availableDayParts: [String]
    let infrastructureAccess: [String]
    let blockers: [String]
    let blockerNote: String
    let supportStyle: String
    let badDayFloor: String
    let injuryNotes: String
    let bodyBaseline: BodyBaselinePayload?
}

private struct AthleteBlueprintAIEvidenceSummary: Codable {
    let totalImportedWorkouts: Int
    let dominantModalities: [String]
    let longestActiveWeekStreak: Int
    let activeWeeks: Int
    let longestGapDays: Int?
    let workouts7Days: Int
    let minutes7Days: Int
    let workouts28Days: Int
    let averageWeeklyMinutes28Days: Int
    let strengthWorkouts90Days: Int
    let strongestMonthLabel: String?
    let longestWorkout: AthleteBlueprintAILongestWorkoutPayload?
    let hasRecentBodyTrend: Bool
    let bodyMass28DayAverageKilograms: Double?
    let bodyFat28DayAveragePercentage: Double?
    let bodyMassTrend: BodyMetricTrendSummary?
    let bodyFatTrend: BodyMetricTrendSummary?

    init(evidence: AthleteBlueprintEvidence) {
        totalImportedWorkouts = evidence.totalWorkouts
        dominantModalities = evidence.dominantModalities
        longestActiveWeekStreak = evidence.longestActiveWeekStreak
        activeWeeks = evidence.activeWeeks
        longestGapDays = evidence.longestGapDays
        workouts7Days = evidence.windowWorkouts("7d")
        minutes7Days = Int(evidence.windowMinutes("7d").rounded())
        workouts28Days = evidence.windowWorkouts("28d")
        averageWeeklyMinutes28Days = Int((evidence.windowMinutes("28d") / 4).rounded())
        strengthWorkouts90Days = evidence.strengthWorkouts90Days
        strongestMonthLabel = evidence.strongestMonth?.label
        longestWorkout = evidence.longestWorkout.map(AthleteBlueprintAILongestWorkoutPayload.init(summary:))
        hasRecentBodyTrend = evidence.hasRecentBodyTrend
        bodyMass28DayAverageKilograms = evidence.snapshot?.body.bodyMass28DayAverageKilograms
        bodyFat28DayAveragePercentage = evidence.snapshot?.body.bodyFat28DayAveragePercentage
        bodyMassTrend = evidence.bodyMassTrend
        bodyFatTrend = evidence.bodyFatTrend
    }
}

private struct AthleteBlueprintAILongestWorkoutPayload: Codable {
    let modality: String
    let durationMinutes: Int
    let distanceKilometers: Double?

    init(summary: FitnessLongestWorkoutSummary) {
        modality = summary.modality
        durationMinutes = Int(summary.durationMinutes.rounded())
        distanceKilometers = summary.distanceKilometers
    }
}

private struct AthleteBlueprintAISectionSeeds: Codable {
    let archetype: AthleteBlueprintAIArchetypeSeed
    let currentTrainingState: AthleteBlueprintAICurrentStateSeed
    let physicalBaseline: AthleteBlueprintAIPhysicalBaselineSeed
    let historyFindings: [AthleteBlueprintAIHistoryFindingSeed]
    let goalFit: AthleteBlueprintAIGoalFitSeed

    init(output: AthleteBlueprintOutput) {
        archetype = AthleteBlueprintAIArchetypeSeed(
            canonicalLabel: output.archetype.label,
            evidence: output.archetype.detail.evidence
        )
        currentTrainingState = AthleteBlueprintAICurrentStateSeed(
            canonicalLabel: output.currentTrainingState.label,
            evidence: output.currentTrainingState.detail.evidence
        )
        physicalBaseline = AthleteBlueprintAIPhysicalBaselineSeed(
            canonicalLabel: output.physicalBaseline.label,
            evidence: output.physicalBaseline.detail.evidence
        )
        historyFindings = output.historyFindings.map {
            AthleteBlueprintAIHistoryFindingSeed(
                id: $0.id,
                evidence: $0.detail.evidence
            )
        }
        goalFit = AthleteBlueprintAIGoalFitSeed(
            canonicalHeadline: output.goalFit.headline,
            supports: output.goalFit.supports,
            gaps: output.goalFit.gaps
        )
    }
}

private struct AthleteBlueprintAIArchetypeSeed: Codable {
    let canonicalLabel: String
    let evidence: [String]
}

private struct AthleteBlueprintAICurrentStateSeed: Codable {
    let canonicalLabel: String
    let evidence: [String]
}

private struct AthleteBlueprintAIPhysicalBaselineSeed: Codable {
    let canonicalLabel: String
    let evidence: [String]
}

private struct AthleteBlueprintAITextPair: Codable {
    let label: String
    let summary: String
}

private struct AthleteBlueprintAIGoalFitSeed: Codable {
    let canonicalHeadline: String
    let supports: [String]
    let gaps: [String]
}

private struct AthleteBlueprintAIPayload: Codable {
    let coachRead: String
    let athleteArchetype: AthleteBlueprintAITextPair
    let currentTrainingState: AthleteBlueprintAITextPair
    let physicalBaseline: AthleteBlueprintAITextPair
    let historyFindings: [AthleteBlueprintAIHistoryFindingPayload]
    let goalFit: AthleteBlueprintAIGoalFitPayload

    func merged(with fallback: AthleteBlueprintOutput) -> AthleteBlueprintOutput {
        return AthleteBlueprintOutput(
            coachRead: AthleteBlueprintCoachRead(
                preview: (coachRead.trimmed.isEmpty ? fallback.coachRead.text : coachRead.trimmed)
                    .limitedSentences(maxSentences: 2, maxCharacters: 190),
                text: coachRead.trimmed.isEmpty ? fallback.coachRead.text : coachRead.trimmed,
                detail: fallback.coachRead.detail
                    .withBody(coachRead.trimmed.isEmpty ? fallback.coachRead.text : coachRead.trimmed)
            ),
            archetype: AthleteBlueprintArchetype(
                label: fallback.archetype.label,
                explanation: fallback.archetype.explanation,
                detail: fallback.archetype.detail
            ),
            currentTrainingState: AthleteBlueprintCurrentState(
                label: fallback.currentTrainingState.label,
                summary: fallback.currentTrainingState.summary,
                detail: fallback.currentTrainingState.detail
            ),
            physicalBaseline: AthleteBlueprintPhysicalBaseline(
                label: fallback.physicalBaseline.label,
                summary: fallback.physicalBaseline.summary,
                detail: fallback.physicalBaseline.detail
            ),
            historyFindings: fallback.historyFindings,
            goalFit: AthleteBlueprintGoalFit(
                headline: fallback.goalFit.headline,
                summary: fallback.goalFit.summary,
                supports: fallback.goalFit.supports,
                gaps: fallback.goalFit.gaps,
                detail: fallback.goalFit.detail
            )
        )
    }
}

private struct AthleteBlueprintAIHistoryFindingPayload: Codable {
    let id: String
    let title: String
    let summary: String
}

private struct AthleteBlueprintAIHistoryFindingSeed: Codable {
    let id: String
    let evidence: [String]
}

private struct AthleteBlueprintAIGoalFitPayload: Codable {
    let headline: String
    let summary: String
}

private struct FitnessStrategyAICompactContext: Codable {
    let intent: String
    let normalizedGoal: AthleteBlueprintAIGoalPayload
    let blueprint: FitnessStrategyAIBlueprintSummary
    let onboardingSignals: AthleteBlueprintAIOnboardingSignals
    let sectionSeeds: FitnessStrategyAISectionSeeds
    let doNotClaim: [String]

    init(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        blueprint: AthleteBlueprintOutput,
        fallback: FitnessStrategyOutput
    ) {
        let goal = AthleteBlueprintBuilder.normalizedGoal(intent: intent, draft: draft)
        self.intent = intent.rawValue
        normalizedGoal = AthleteBlueprintAIGoalPayload(goal: goal)
        self.blueprint = FitnessStrategyAIBlueprintSummary(blueprint: blueprint)
        onboardingSignals = AthleteBlueprintAIOnboardingSignals(
            goalPriority: draft.prioritySummary,
            frequencyPreference: draft.frequency?.summary ?? "",
            sessionLengthPreference: draft.sessionLength?.title ?? "",
            availableDays: draft.availableDays.map(\.title).sorted(),
            availableDayParts: draft.availableDayParts.map(\.title).sorted(),
            infrastructureAccess: draft.infrastructureAccess.map(\.title).sorted(),
            blockers: draft.blockers.map(\.title).sorted(),
            blockerNote: draft.blockerNote.trimmed,
            supportStyle: draft.supportSummary,
            badDayFloor: draft.floorSummary,
            injuryNotes: draft.injuryNotes.trimmed,
            bodyBaseline: BodyBaselinePayload(draft: draft)
        )
        sectionSeeds = FitnessStrategyAISectionSeeds(strategy: fallback)
        doNotClaim = [
            "Do not repeat the user's goal summary back to them as the strategy.",
            "Do not invent phases for consistency goals.",
            "Do not create new athlete facts beyond the Athlete Blueprint summary and onboarding signals."
        ]
    }
}

private struct FitnessStrategyAITargetGenerationContext: Codable {
    let intent: String
    let normalizedGoal: AthleteBlueprintAIGoalPayload
    let blueprint: FitnessStrategyAIBlueprintSummary
    let onboardingSignals: AthleteBlueprintAIOnboardingSignals
    let targetBrief: FitnessStrategyAITargetBrief
    let targetSlots: FitnessStrategyAITargetSlots
    let doNotClaim: [String]

    init(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        blueprint: AthleteBlueprintOutput,
        fallback: FitnessStrategyOutput
    ) {
        let goal = AthleteBlueprintBuilder.normalizedGoal(intent: intent, draft: draft)
        self.intent = intent.rawValue
        normalizedGoal = AthleteBlueprintAIGoalPayload(goal: goal)
        self.blueprint = FitnessStrategyAIBlueprintSummary(blueprint: blueprint)
        onboardingSignals = AthleteBlueprintAIOnboardingSignals(
            goalPriority: draft.prioritySummary,
            frequencyPreference: draft.frequency?.summary ?? "",
            sessionLengthPreference: draft.sessionLength?.title ?? "",
            availableDays: draft.availableDays.map(\.title).sorted(),
            availableDayParts: draft.availableDayParts.map(\.title).sorted(),
            infrastructureAccess: draft.infrastructureAccess.map(\.title).sorted(),
            blockers: draft.blockers.map(\.title).sorted(),
            blockerNote: draft.blockerNote.trimmed,
            supportStyle: draft.supportSummary,
            badDayFloor: draft.floorSummary,
            injuryNotes: draft.injuryNotes.trimmed,
            bodyBaseline: BodyBaselinePayload(draft: draft)
        )
        targetBrief = FitnessStrategyAITargetBrief(goal: goal, draft: draft, blueprint: blueprint, fallback: fallback)
        targetSlots = FitnessStrategyAITargetSlots(strategy: fallback)
        doNotClaim = [
            "Do not repeat the user's goal summary back to them as a target.",
            "Do not invent phases for consistency goals.",
            "Do not create new athlete facts beyond the Athlete Blueprint summary and onboarding signals."
        ]
    }
}

private struct FitnessStrategyAITargetBrief: Codable {
    let goalText: String
    let goalCategory: String
    let horizonWeeks: Int
    let progressType: String
    let goalDistanceLabel: String?
    let goalDistanceKilometers: Double?
    let selectedTrainingPriorities: [String]
    let allowedModalities: [String]
    let supportModalities: [String]
    let availableAccess: [String]
    let avoidances: [String]
    let availability: FitnessStrategyAIAvailabilityBrief
    let blockers: [String]
    let badDayFloor: String
    let historySignals: [String]
    let caveats: [String]
    let concreteGoalTargets: [FitnessStrategyAIConcreteTarget]
    let allowedTargetFamilies: [String]
    let phases: [String]

    init(
        goal: AthleteBlueprintGoal,
        draft: ConsistencyOnboardingDraft,
        blueprint: AthleteBlueprintOutput,
        fallback: FitnessStrategyOutput
    ) {
        let priorities = draft.trainingOptions.map(\.title)
        let allowed = FitnessStrategyAITargetBrief.allowedModalities(from: draft)
        let distance = FitnessStrategyAITargetBrief.goalDistance(in: goal.displayText)

        goalText = goal.displayText
        goalCategory = goal.category.rawValue
        horizonWeeks = goal.horizonWeeks
        progressType = FitnessStrategyAITargetBrief.progressType(for: goal)
        goalDistanceLabel = distance?.label
        goalDistanceKilometers = distance?.kilometers
        selectedTrainingPriorities = priorities
        allowedModalities = allowed
        supportModalities = Array(allowed.dropFirst())
        availableAccess = draft.infrastructureAccess.map(\.title).sorted()
        avoidances = draft.goalAvoidances.map(\.title).sorted()
        availability = FitnessStrategyAIAvailabilityBrief(draft: draft)
        blockers = draft.blockers.map(\.title).sorted()
        badDayFloor = draft.floorSummary
        historySignals = [
            blueprint.currentTrainingState.summary,
            blueprint.archetype.explanation
        ] + blueprint.historyFindings.map { "\($0.title): \($0.summary)" }
        caveats = [
            "Selected training priorities, access, avoidances, and availability outrank historical modalities.",
            "General training volume is not the same as goal-specific volume.",
            "Historical data may size confidence and feasibility, but must not create targets outside the selected training path."
        ]
        concreteGoalTargets = FitnessStrategyAITargetBrief.concreteTargets(in: goal.displayText)
        allowedTargetFamilies = [
            "consistency",
            "modality_presence",
            "capacity_metric",
            "performance_metric",
            "body_trend",
            "capstone"
        ]
        phases = fallback.phases.map(\.id)
    }

    private static func allowedModalities(from draft: ConsistencyOnboardingDraft) -> [String] {
        draft.trainingOptions
            .filter { option in
                switch option {
                case .running:
                    return !draft.goalAvoidances.contains(.running)
                case .strength:
                    return !draft.goalAvoidances.contains(.heavyLifting) && !draft.goalAvoidances.contains(.gymDependence)
                default:
                    return true
                }
            }
            .filter { option in
                let required = option.infrastructureOptions
                return required.isEmpty || !draft.infrastructureAccess.isDisjoint(with: Set(required))
            }
            .map { normalizedModality($0.title) }
    }

    private static func progressType(for goal: AthleteBlueprintGoal) -> String {
        let text = goal.displayText.lowercased()
        if goal.category == .consistency {
            return "adherence_consistency"
        }
        if goal.category == .bodyComposition {
            return "body_composition"
        }
        if text.contains("pace") || text.contains("speed") || text.contains("faster") || text.contains("pr") || text.contains("race pace") || text.contains("time") {
            return "speed_performance"
        }
        if text.contains("event") || text.contains("race") || text.contains("complete") || text.contains("finish") {
            return "completion_event_readiness"
        }
        if goal.category == .strength {
            return "strength_power"
        }
        if goal.category == .sportPerformance {
            return "skill_sport_readiness"
        }
        if goal.category == .endurance {
            return "capacity_endurance"
        }
        return "general_fitness_athleticism"
    }

    private static func normalizedModality(_ value: String) -> String {
        let lowercased = value.lowercased()
        if lowercased.contains("run") { return "running" }
        if lowercased.contains("swim") { return "swimming" }
        if lowercased.contains("cycl") || lowercased.contains("bike") { return "cycling" }
        if lowercased.contains("strength") || lowercased.contains("lift") { return "strength" }
        if lowercased.contains("mobility") { return "mobility" }
        if lowercased.contains("tennis") { return "tennis" }
        if lowercased.contains("football") { return "football" }
        if lowercased.contains("basketball") { return "basketball" }
        return lowercased
    }

    private static func goalDistance(in text: String) -> (label: String, kilometers: Double)? {
        let lowercased = text.lowercased()
        if lowercased.contains("5k") { return ("5K", 5) }
        if lowercased.contains("10k") { return ("10K", 10) }
        if lowercased.contains("half marathon") { return ("half marathon", 21.1) }
        if lowercased.contains("marathon") { return ("marathon", 42.2) }

        let pattern = #"(\d+(?:[\.,]\d+)?)\s*(?:k|km|kilometer|kilometers)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
              let range = Range(match.range(at: 1), in: lowercased),
              let value = Double(lowercased[range].replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        let label = value.rounded() == value ? "\(Int(value))K" : "\(value)K"
        return (label, value)
    }

    static func concreteTargets(in text: String) -> [FitnessStrategyAIConcreteTarget] {
        var targets: [FitnessStrategyAIConcreteTarget] = []
        let lowercased = text.lowercased()

        if lowercased.contains("ftp") || lowercased.contains("functional threshold power") {
            let percentPattern = #"(?:(?:ftp|functional threshold power)[^\d]{0,32}(\d+(?:[\.,]\d+)?)\s*(?:%|percent))|(?:(\d+(?:[\.,]\d+)?)\s*(?:%|percent)[^\w]{0,12}(?:ftp|functional threshold power))"#
            if let value = firstNumber(in: lowercased, pattern: percentPattern) {
                targets.append(
                    FitnessStrategyAIConcreteTarget(
                        metric: "functional_threshold_power_percent_change",
                        modality: "cycling",
                        title: "FTP +\(formattedNumber(value))%",
                        targetValue: value,
                        unit: "%",
                        direction: "increase",
                        displayValue: "+\(formattedNumber(value))%"
                    )
                )
            }
        }

        if lowercased.contains("5k") {
            let secondsPattern = #"(?:(?:cut|reduce|drop|lower|improve)[^\d]{0,40}(\d+(?:[\.,]\d+)?)\s*(?:sec|second|seconds))|(?:(\d+(?:[\.,]\d+)?)\s*(?:sec|second|seconds)[^\w]{0,16}(?:faster|improvement|reduction))"#
            if let value = firstNumber(in: lowercased, pattern: secondsPattern) {
                targets.append(
                    FitnessStrategyAIConcreteTarget(
                        metric: "five_k_time_seconds_reduction",
                        modality: "running",
                        title: "5K -\(formattedNumber(value)) sec",
                        targetValue: value,
                        unit: "sec",
                        direction: "decrease",
                        displayValue: "-\(formattedNumber(value)) sec"
                    )
                )
            }
        }

        return targets
    }

    private static func firstNumber(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        for index in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at: index), in: text) else { continue }
            return Double(text[range].replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    private static func formattedNumber(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

private struct FitnessStrategyAIConcreteTarget: Codable {
    let metric: String
    let modality: String
    let title: String
    let targetValue: Double
    let unit: String
    let direction: String
    let displayValue: String
}

private struct FitnessStrategyAIAvailabilityBrief: Codable {
    let daysPerWeek: Int
    let sessionLength: String
    let sessionLengthMinutes: Int
    let days: [String]
    let dayParts: [String]

    init(draft: ConsistencyOnboardingDraft) {
        daysPerWeek = FitnessStrategyAIAvailabilityBrief.weeklySessions(from: draft.frequency)
        sessionLength = draft.sessionLength?.title ?? ""
        sessionLengthMinutes = FitnessStrategyAIAvailabilityBrief.sessionMinutes(from: draft.sessionLength)
        days = draft.availableDays.map(\.title).sorted()
        dayParts = draft.availableDayParts.map(\.title).sorted()
    }

    private static func weeklySessions(from frequency: TrainingFrequency?) -> Int {
        switch frequency {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .fivePlus: return 5
        case .changes, nil: return 3
        }
    }

    private static func sessionMinutes(from length: SessionLength?) -> Int {
        switch length {
        case .twenty: return 20
        case .thirty: return 30
        case .fortyFive: return 45
        case .sixtyPlus: return 60
        case .varies, nil: return 35
        }
    }
}

private struct FitnessStrategyAIBlueprintSummary: Codable {
    let coachRead: String
    let athleteArchetype: String
    let currentTrainingState: String
    let historyFindings: [String]
    let goalFit: String

    init(blueprint: AthleteBlueprintOutput) {
        coachRead = blueprint.coachRead.text
        athleteArchetype = "\(blueprint.archetype.label): \(blueprint.archetype.explanation)"
        currentTrainingState = "\(blueprint.currentTrainingState.label): \(blueprint.currentTrainingState.summary)"
        historyFindings = blueprint.historyFindings.map { "\($0.title): \($0.summary)" }
        goalFit = "\(blueprint.goalFit.headline): \(blueprint.goalFit.summary)"
    }
}

private struct FitnessStrategyAISectionSeeds: Codable {
    let goalTargetContext: FitnessStrategyAIGoalTargetContextSeed
    let fitReasons: [FitnessStrategyAIFitReasonSeed]
    let strategyPillars: [FitnessStrategyAIPillarSeed]
    let phaseOutline: [FitnessStrategyAIPhaseSeed]
    let operatingRhythm: FitnessStrategyAIOperatingRhythmSeed?
    let strategyTargets: [FitnessStrategyAITargetSeed]

    init(strategy: FitnessStrategyOutput) {
        goalTargetContext = FitnessStrategyAIGoalTargetContextSeed(context: strategy.goalTargetContext)
        fitReasons = strategy.fitReasons.map(FitnessStrategyAIFitReasonSeed.init(reason:))
        strategyPillars = strategy.pillars.map(FitnessStrategyAIPillarSeed.init(pillar:))
        phaseOutline = strategy.phases.map(FitnessStrategyAIPhaseSeed.init(phase:))
        operatingRhythm = strategy.operatingRhythm.map(FitnessStrategyAIOperatingRhythmSeed.init(rhythm:))
        strategyTargets = strategy.targets.map(FitnessStrategyAITargetSeed.init(target:))
    }
}

private struct FitnessStrategyAITargetSlots: Codable {
    let strategyTargets: [FitnessStrategyAITargetSlot]
    let phaseOutline: [FitnessStrategyAIPhaseTargetSlots]

    init(strategy: FitnessStrategyOutput) {
        strategyTargets = strategy.targets.map(FitnessStrategyAITargetSlot.init(target:))
        phaseOutline = strategy.phases.map(FitnessStrategyAIPhaseTargetSlots.init(phase:))
    }
}

private struct FitnessStrategyAIPhaseTargetSlots: Codable {
    let id: String
    let name: String
    let phaseTargets: [FitnessStrategyAITargetSlot]

    init(phase: FitnessStrategyPhase) {
        id = phase.id
        name = phase.name
        phaseTargets = phase.targets.map(FitnessStrategyAITargetSlot.init(target:))
    }
}

private struct FitnessStrategyAITargetSlot: Codable {
    let id: String
    let scope: String
    let kind: String

    init(target: FitnessStrategyTarget) {
        id = target.id
        scope = target.scope.rawValue
        kind = target.kind.rawValue
    }
}

private struct FitnessStrategyAIGoalTargetContextSeed: Codable {
    let title: String

    init(context: FitnessStrategyGoalTargetContext) {
        title = context.title
    }
}

private struct FitnessStrategyAIFitReasonSeed: Codable {
    let id: String
    let title: String

    init(reason: FitnessStrategyFitReason) {
        id = reason.id
        title = reason.title
    }
}

private struct FitnessStrategyAIPillarSeed: Codable {
    let id: String
    let title: String

    init(pillar: FitnessStrategyPillar) {
        id = pillar.id
        title = pillar.title
    }
}

private struct FitnessStrategyAIPhaseSeed: Codable {
    let id: String
    let name: String
    let phaseTargets: [FitnessStrategyAITargetSeed]

    init(phase: FitnessStrategyPhase) {
        id = phase.id
        name = phase.name
        phaseTargets = phase.targets.map(FitnessStrategyAITargetSeed.init(target:))
    }
}

private struct FitnessStrategyAIOperatingRhythmSeed: Codable {
    let summary: String

    init(rhythm: FitnessStrategyOperatingRhythm) {
        summary = rhythm.summary
    }
}

private struct FitnessStrategyAITargetSeed: Codable {
    let id: String
    let scope: String
    let kind: String
    let title: String
    let metricKey: String?
    let targetValue: Double?
    let unit: String?
    let displayValue: String?

    init(target: FitnessStrategyTarget) {
        id = target.id
        scope = target.scope.rawValue
        kind = target.kind.rawValue
        title = target.title
        metricKey = target.metricKey
        targetValue = target.targetValue
        unit = target.unit
        displayValue = target.displayValue
    }
}

private struct FitnessStrategyAIPayload: Codable {
    let strategyRead: String
    let goalTargetContext: FitnessStrategyAIGoalTargetContextPayload?
    let fitReasons: [FitnessStrategyAIFitReasonPayload]?
    let strategyPillars: [FitnessStrategyAIPillarPayload]
    let phaseOutline: [FitnessStrategyAIPhasePayload]
    let operatingRhythm: FitnessStrategyAIOperatingRhythmPayload?
    let strategyTargets: [FitnessStrategyAITargetPayload]?

    func merged(with fallback: FitnessStrategyOutput, targetBrief: FitnessStrategyAITargetBrief) -> FitnessStrategyOutput {
        let validator = FitnessStrategyAITargetProposalValidator(brief: targetBrief)
        let fitReasonCopy = Dictionary(uniqueKeysWithValues: (fitReasons ?? []).map { ($0.id, $0) })
        let pillarCopy = Dictionary(uniqueKeysWithValues: strategyPillars.map { ($0.id, $0) })
        let phaseCopy = Dictionary(uniqueKeysWithValues: phaseOutline.map { ($0.id, $0) })

        return FitnessStrategyOutput(
            read: validator.safeCopy(strategyRead, fallback: fallback.read),
            goalTargetContext: FitnessStrategyGoalTargetContext(
                title: goalTargetContext?.title.trimmed.isEmpty == false ? goalTargetContext?.title.trimmed ?? fallback.goalTargetContext.title : fallback.goalTargetContext.title,
                summary: validator.safeCopy(goalTargetContext?.summary ?? "", fallback: fallback.goalTargetContext.summary)
            ),
            snapshotItems: fallback.snapshotItems,
            fitReasons: fallback.fitReasons.map { reason in
                guard let aiReason = fitReasonCopy[reason.id] else { return reason }
                return FitnessStrategyFitReason(
                    id: reason.id,
                    systemImage: reason.systemImage,
                    title: aiReason.title.trimmed.isEmpty ? reason.title : aiReason.title.trimmed,
                    summary: validator.safeCopy(aiReason.summary, fallback: reason.summary)
                )
            },
            pillars: fallback.pillars.map { pillar in
                guard let aiPillar = pillarCopy[pillar.id] else { return pillar }
                return FitnessStrategyPillar(
                    id: pillar.id,
                    title: aiPillar.title.trimmed.isEmpty ? pillar.title : aiPillar.title.trimmed,
                    summary: validator.safeCopy(aiPillar.summary, fallback: pillar.summary)
                )
            },
            phases: fallback.phases.map { phase in
                guard let aiPhase = phaseCopy[phase.id] else { return phase }
                return FitnessStrategyPhase(
                    id: phase.id,
                    name: aiPhase.name.trimmed.isEmpty ? phase.name : aiPhase.name.trimmed,
                    objective: validator.safeCopy(aiPhase.objective, fallback: phase.objective),
                    targetSummary: validator.safeCopy(aiPhase.targetSummary, fallback: phase.targetSummary),
                    targets: validator.mergePhaseTargets(
                        aiPhase.phaseTargets ?? [],
                        fallback: phase.targets,
                        phaseID: phase.id
                    )
                )
            },
            operatingRhythm: fallback.operatingRhythm.map { fallbackRhythm in
                guard let operatingRhythm else { return fallbackRhythm }
                return FitnessStrategyOperatingRhythm(
                    summary: validator.safeCopy(operatingRhythm.summary, fallback: fallbackRhythm.summary),
                    anchors: operatingRhythm.anchors.isEmpty ? fallbackRhythm.anchors : operatingRhythm.anchors.map(\.trimmed).filter { !$0.isEmpty }
                )
            },
            targets: validator.mergeStrategyTargets(strategyTargets ?? [], fallback: fallback.targets)
        )
    }
}

private struct FitnessStrategyAITargetProposalPayload: Codable {
    let strategyTargets: [FitnessStrategyAITargetPayload]
    let phaseOutline: [FitnessStrategyAIPhaseTargetProposalPayload]

    func merged(with fallback: FitnessStrategyOutput, targetBrief: FitnessStrategyAITargetBrief) -> FitnessStrategyOutput {
        let validator = FitnessStrategyAITargetProposalValidator(brief: targetBrief)
        let phaseCopy = Dictionary(uniqueKeysWithValues: phaseOutline.map { ($0.id, $0) })

        return FitnessStrategyOutput(
            read: fallback.read,
            goalTargetContext: fallback.goalTargetContext,
            snapshotItems: fallback.snapshotItems,
            fitReasons: fallback.fitReasons,
            pillars: fallback.pillars,
            phases: fallback.phases.map { phase in
                guard let proposalPhase = phaseCopy[phase.id] else { return phase }
                return FitnessStrategyPhase(
                    id: phase.id,
                    name: phase.name,
                    objective: phase.objective,
                    targetSummary: phase.targetSummary,
                    targets: validator.mergePhaseTargets(
                        proposalPhase.phaseTargets,
                        fallback: phase.targets,
                        phaseID: phase.id
                    )
                )
            },
            operatingRhythm: fallback.operatingRhythm,
            targets: validator.mergeStrategyTargets(strategyTargets, fallback: fallback.targets)
        )
    }
}

private struct FitnessStrategyAIPhaseTargetProposalPayload: Codable {
    let id: String
    let phaseTargets: [FitnessStrategyAITargetPayload]
}

private struct FitnessStrategyAIGoalTargetContextPayload: Codable {
    let title: String
    let summary: String
}

private struct FitnessStrategyAIFitReasonPayload: Codable {
    let id: String
    let title: String
    let summary: String
}

private struct FitnessStrategyAIPillarPayload: Codable {
    let id: String
    let title: String
    let summary: String
}

private struct FitnessStrategyAIPhasePayload: Codable {
    let id: String
    let name: String
    let objective: String
    let targetSummary: String
    let phaseTargets: [FitnessStrategyAITargetPayload]?
}

private struct FitnessStrategyAIOperatingRhythmPayload: Codable {
    let summary: String
    let anchors: [String]
}

private struct FitnessStrategyAITargetPayload: Codable {
    let id: String
    let title: String
    let summary: String
    let family: String?
    let modality: String?
    let proposedDisplayValue: String?
    let targetValue: Double?
    let unit: String?
    let rationale: String?
    let capstone: FitnessStrategyAICapstonePayload?
}

private struct FitnessStrategyAICapstonePayload: Codable {
    let isCapstone: Bool
    let whyAppropriate: String?
}

private struct FitnessStrategyAITargetProposalValidator {
    let brief: FitnessStrategyAITargetBrief

    private var allowedModalities: Set<String> {
        Set(brief.allowedModalities.map(Self.normalizedModality))
    }

    func safeCopy(_ copy: String, fallback: String) -> String {
        let trimmed = copy.trimmed
        guard !trimmed.isEmpty else { return fallback }
        return cleanUserFacingCopy(trimmed)
    }

    func mergeStrategyTargets(
        _ proposals: [FitnessStrategyAITargetPayload],
        fallback: [FitnessStrategyTarget]
    ) -> [FitnessStrategyTarget] {
        mergeTargets(proposals, fallback: fallback, phaseID: nil)
    }

    func mergePhaseTargets(
        _ proposals: [FitnessStrategyAITargetPayload],
        fallback: [FitnessStrategyTarget],
        phaseID: String
    ) -> [FitnessStrategyTarget] {
        mergeTargets(proposals, fallback: fallback, phaseID: phaseID)
    }

    private func mergeTargets(
        _ proposals: [FitnessStrategyAITargetPayload],
        fallback: [FitnessStrategyTarget],
        phaseID: String?
    ) -> [FitnessStrategyTarget] {
        let proposalByID = proposals.reduce(into: [String: FitnessStrategyAITargetPayload]()) { partial, proposal in
            partial[proposal.id] = proposal
        }

        return fallback.map { fallbackTarget in
            guard let proposal = proposalByID[fallbackTarget.id] else {
                return fallbackTarget
            }
            return acceptedTarget(from: proposal, fallback: fallbackTarget, phaseID: phaseID)
        }
    }

    private func acceptedTarget(
        from proposal: FitnessStrategyAITargetPayload,
        fallback: FitnessStrategyTarget,
        phaseID: String?
    ) -> FitnessStrategyTarget {
        let family = normalizedFamily(proposal.family, fallback: fallback)
        let modality = normalizedModality(proposal.modality ?? modalityFromText("\(proposal.title) \(proposal.summary)") ?? "")
        let targetValue = proposal.targetValue ?? fallback.targetValue
        let unit = sanitizedUnit(proposal.unit) ?? defaultUnit(for: family, fallback: fallback)
        let displayValue = sanitizedDisplayValue(proposal.proposedDisplayValue)
            ?? displayValue(from: targetValue, unit: unit)
            ?? fallback.displayValue
        let title = safeTargetTitle(proposal.title, family: family, modality: modality, displayValue: displayValue, fallback: fallback)
        let summary = safeCopy(proposal.summary, fallback: fallback.summary)

        return FitnessStrategyTarget(
            id: fallback.id,
            scope: fallback.scope,
            kind: fallback.kind,
            title: title,
            summary: summary,
            metricKey: metricKey(for: family, modality: modality, fallback: fallback),
            metricCategory: metricCategory(for: family, modality: modality, fallback: fallback),
            direction: direction(for: family, fallback: fallback),
            targetValue: targetValue,
            unit: unit,
            displayValueOverride: displayValue
        )
    }

    private func normalizedFamily(_ family: String?, fallback: FitnessStrategyTarget?) -> String {
        let raw = family?.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") ?? ""
        if raw == "performance_benchmark" { return "performance_metric" }
        if raw == "capacity_benchmark" { return "capacity_metric" }
        if brief.allowedTargetFamilies.contains(raw) {
            return raw
        }

        if let fallback {
            if fallback.metricCategory == "consistency" { return "consistency" }
            if fallback.metricCategory == "training_balance" { return "modality_presence" }
            if fallback.title.lowercased().contains("capstone") { return "capstone" }
        }

        return "performance_metric"
    }

    private func metricKey(for family: String, modality: String, fallback: FitnessStrategyTarget) -> String? {
        switch family {
        case "consistency":
            return fallback.metricKey == "weeks_with_min_sessions_12w" ? "weeks_with_min_sessions_strategy" : fallback.metricKey
        case "modality_presence":
            return "chosen_training_modalities_present_7d"
        case "body_trend":
            return "body_mass_28d_avg_kg"
        case "capstone":
            return modality.isEmpty ? "capstone_strategy" : "\(modality)_capstone_strategy"
        case "performance_metric", "performance_benchmark":
            if fallback.unit == "%" || fallback.displayValue?.contains("%") == true {
                return modality.isEmpty ? "performance_percent_change" : "\(modality)_performance_percent_change"
            }
            if fallback.unit == "sec" || fallback.displayValue?.contains("sec") == true {
                return modality.isEmpty ? "performance_seconds_delta" : "\(modality)_performance_seconds_delta"
            }
            return modality.isEmpty ? "performance_result_count" : "\(modality)_performance_result_count"
        case "capacity_metric", "capacity_benchmark":
            return modality.isEmpty ? "capacity_result_count" : "\(modality)_capacity_result_count"
        default:
            if !modality.isEmpty {
                return "\(modality)_performance_result"
            }
            return fallback.metricKey
        }
    }

    private func metricCategory(for family: String, modality: String, fallback: FitnessStrategyTarget) -> String {
        if family == "body_trend" { return "body_composition" }
        if family == "consistency" { return "consistency" }
        if family == "modality_presence" { return "training_balance" }
        if brief.progressType == "speed_performance", !modality.isEmpty {
            return "\(modality)_speed"
        }
        if !modality.isEmpty {
            return modality
        }
        return fallback.metricCategory
    }

    private func direction(for family: String, fallback: FitnessStrategyTarget) -> FitnessStrategyTargetDirection {
        switch family {
        case "consistency", "capacity_metric", "capacity_benchmark", "performance_metric", "performance_benchmark", "capstone":
            return .increase
        case "modality_presence", "body_trend":
            return .maintain
        default:
            return fallback.direction == .review || fallback.direction == .complete ? .increase : fallback.direction
        }
    }

    private func validatedTargetValue(_ value: Double?, family: String, fallback: FitnessStrategyTarget) -> Double? {
        guard let value else { return fallback.targetValue }
        if family == "consistency" {
            return (1...Double(max(1, brief.horizonWeeks))).contains(value) ? value : fallback.targetValue
        }
        if value <= 0 { return fallback.targetValue }
        return value
    }

    private func defaultUnit(for family: String, fallback: FitnessStrategyTarget) -> String? {
        fallback.unit
    }

    private func defaultDisplayValue(
        for family: String,
        proposal: FitnessStrategyAITargetPayload,
        fallback: FitnessStrategyTarget
    ) -> String? {
        if family == "consistency",
           let value = validatedTargetValue(proposal.targetValue, family: family, fallback: fallback),
           value.rounded() == value {
            return "\(Int(value)) of \(brief.horizonWeeks)"
        }
        return fallback.displayValue
    }

    private func safeTargetTitle(
        _ copy: String,
        family: String,
        modality: String,
        displayValue: String?,
        fallback: FitnessStrategyTarget
    ) -> String {
        var title = safeCopy(copy, fallback: fallback.title)
        if let colonIndex = title.firstIndex(of: ":") {
            let suffix = String(title[title.index(after: colonIndex)...]).trimmed
            if !suffix.isEmpty {
                title = suffix
            }
        }
        title = compactTargetTitle(title)
        if title.count <= 36 && title.split(separator: " ").count <= 6 {
            return title
        }

        let words = title.split(separator: " ")
        if words.count > 6 {
            return words.prefix(6).joined(separator: " ")
        }

        return String(title.prefix(42)).trimmed
    }

    private func compactTargetTitle(_ title: String) -> String {
        cleanUserFacingCopy(title)
            .replacingOccurrences(of: "20-minute", with: "20-min")
            .replacingOccurrences(of: "20 minute", with: "20-min")
            .replacingOccurrences(of: "normalized power", with: "power")
            .replacingOccurrences(of: "functional threshold power", with: "FTP", options: .caseInsensitive)
            .replacingOccurrences(of: "completed per week", with: "per week")
            .replacingOccurrences(of: "sessions/week", with: "sessions per week")
            .replacingOccurrences(of: "meeting target sessions/week", with: "rhythm weeks")
            .trimmed
    }

    private func sanitizedDisplayValue(_ value: String?) -> String? {
        guard let value = value?.trimmed, !value.isEmpty else { return nil }
        guard !containsInternalMetricLanguage(value) else { return nil }
        let compact = compactDisplayValue(value)
        return compact.count <= 14 ? compact : nil
    }

    private func sanitizedUnit(_ value: String?) -> String? {
        guard let value = value?.trimmed, !value.isEmpty else { return nil }
        guard !containsInternalMetricLanguage(value) else { return nil }
        let unit = cleanUserFacingCopy(value)
        return unit.lowercased() == "benchmark" ? "result" : unit
    }

    private func displayValue(from value: Double?, unit: String?) -> String? {
        guard let value else { return nil }
        let formatted = value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
        guard let unit, !unit.isEmpty else { return formatted }

        switch unit.lowercased() {
        case "%":
            return "\(formatted)%"
        case "seconds", "second", "sec":
            return "\(formatted) sec"
        case "minutes", "minute", "min":
            return "\(formatted) min"
        case "weeks", "week":
            return "\(formatted) wks"
        case "sessions/week", "session/week":
            return "\(formatted)/wk"
        default:
            return compactDisplayValue("\(formatted) \(unit)")
        }
    }

    private func cleanUserFacingCopy(_ value: String) -> String {
        value
            .replacingOccurrences(of: "benchmark", with: "result", options: .caseInsensitive)
            .replacingOccurrences(of: "Benchmark", with: "Result")
            .trimmed
    }

    private func compactDisplayValue(_ value: String) -> String {
        var compact = value
            .replacingOccurrences(of: "seconds", with: "sec")
            .replacingOccurrences(of: "second", with: "sec")
            .replacingOccurrences(of: "minutes", with: "min")
            .replacingOccurrences(of: "minute", with: "min")
            .replacingOccurrences(of: "weeks", with: "wks")
            .replacingOccurrences(of: "week", with: "wk")
            .replacingOccurrences(of: "sessions/week", with: "sessions/wk")
            .replacingOccurrences(of: "session/week", with: "session/wk")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let replacements = [
            (#"(?i)^median sessions/wk\s*(?:>=|≥)\s*(\d+(?:\.\d+)?)$"#, "≥$1/wk"),
            (#"(?i)^sessions/wk\s*(?:>=|≥)\s*(\d+(?:\.\d+)?)$"#, "≥$1/wk"),
            (#"(?i)^strength sessions\s*(?:>=|≥)\s*(\d+(?:\.\d+)?)\s*total$"#, "$1 total"),
            (#"(?i)^(\d+(?:\.\d+)?)\s*sessions/wk$"#, "$1/wk"),
            (#"(?i)^(\d+(?:\.\d+)?)\s*of\s*(\d+(?:\.\d+)?)$"#, "$1/$2")
        ]

        for (pattern, template) in replacements {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(compact.startIndex..., in: compact)
            let replaced = regex.stringByReplacingMatches(in: compact, range: range, withTemplate: template)
            if replaced != compact {
                compact = replaced
                break
            }
        }

        return compact
    }

    private func containsWorkoutProgramming(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        let banned = [
            "tempo",
            "interval",
            "time trial",
            "quality run",
            "easy run",
            "long run",
            "long ride",
            "workout split",
            "sets and reps",
            "twice within",
            "two quality",
            "zone 2",
            "vo2"
        ]
        return banned.contains { lowercased.contains($0) }
    }

    private func containsNonTargetLanguage(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        let banned = [
            "review",
            "signal",
            "reflect",
            "decide",
            "decision",
            "next move",
            "next plan",
            "plan to iterate",
            "check-in",
            "check in",
            "before skip",
            "stable",
            "felt better",
            "confidence improved",
            "plan adjusted",
            "goal selected",
            "goal selection"
        ]
        return banned.contains { lowercased.contains($0) }
    }

    private func containsDisallowedModality(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        let terms: [String: [String]] = [
            "running": ["run", "running", "10k", "5k", "marathon"],
            "cycling": ["cycling", "bike", "ride"],
            "swimming": ["swim", "swimming", "pool"],
            "strength": ["strength", "lifting", "weights", "gym"],
            "tennis": ["tennis"],
            "football": ["football"],
            "basketball": ["basketball"]
        ]

        return terms.contains { modality, modalityTerms in
            !allowedModalities.contains(modality) && modalityTerms.contains { lowercased.contains($0) }
        }
    }

    private func containsAvoidedDependency(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        let avoidances = brief.avoidances.map { $0.lowercased() }
        if avoidances.contains("running") && (lowercased.contains("run") || lowercased.contains("10k") || lowercased.contains("5k")) {
            return true
        }
        if avoidances.contains("gym dependence") && lowercased.contains("gym") {
            return true
        }
        if avoidances.contains("heavy lifting") && (lowercased.contains("heavy") || lowercased.contains("lifting")) {
            return true
        }
        if avoidances.contains("long workouts") && (lowercased.contains("long run") || lowercased.contains("long ride") || lowercased.contains("long session")) {
            return true
        }
        if avoidances.contains("high intensity") && (lowercased.contains("high intensity") || lowercased.contains("interval") || lowercased.contains("tempo")) {
            return true
        }
        return false
    }

    private func containsInternalMetricLanguage(_ value: String) -> Bool {
        value.contains("_") || value.contains(">=") || value.contains("<=")
    }

    private func isMeasurableDisplayValue(_ displayValue: String?, targetValue: Double?, unit: String?) -> Bool {
        if let displayValue, displayValue.range(of: #"\d"#, options: .regularExpression) != nil {
            return !containsNonTargetLanguage(displayValue)
        }
        return targetValue != nil && unit?.trimmed.isEmpty == false
    }

    private func modalityFromText(_ value: String) -> String? {
        let lowercased = value.lowercased()
        if lowercased.contains("run") || lowercased.contains("10k") || lowercased.contains("5k") { return "running" }
        if lowercased.contains("swim") || lowercased.contains("pool") { return "swimming" }
        if lowercased.contains("cycl") || lowercased.contains("bike") || lowercased.contains("ride") { return "cycling" }
        if lowercased.contains("strength") || lowercased.contains("gym") || lowercased.contains("lifting") { return "strength" }
        return nil
    }

    private func normalizedModality(_ value: String) -> String {
        Self.normalizedModality(value)
    }

    private static func normalizedModality(_ value: String) -> String {
        let lowercased = value.lowercased()
        if lowercased.contains("run") { return "running" }
        if lowercased.contains("swim") { return "swimming" }
        if lowercased.contains("cycl") || lowercased.contains("bike") || lowercased.contains("ride") { return "cycling" }
        if lowercased.contains("strength") || lowercased.contains("lift") || lowercased.contains("gym") { return "strength" }
        if lowercased.contains("tennis") { return "tennis" }
        if lowercased.contains("football") { return "football" }
        if lowercased.contains("basketball") { return "basketball" }
        return lowercased.trimmed
    }

    private func distanceKilometers(in value: String) -> Double? {
        let lowercased = value.lowercased()
        if lowercased.contains("5k") { return 5 }
        if lowercased.contains("10k") { return 10 }
        if lowercased.contains("half marathon") { return 21.1 }
        if lowercased.contains("marathon") { return 42.2 }

        let pattern = #"(\d+(?:[\.,]\d+)?)\s*(?:k|km|kilometer|kilometers)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
              let range = Range(match.range(at: 1), in: lowercased) else {
            return nil
        }
        return Double(lowercased[range].replacingOccurrences(of: ",", with: "."))
    }
}

private struct OnboardingAISummaryFunctionResponse: Decodable {
    let output: OnboardingAISummaryPayload
}

private struct OnboardingAIGoalCandidatesFunctionResponse: Decodable {
    let output: OnboardingAIGoalCandidatesPayload
}

private struct OnboardingAIBlendedCandidateFunctionResponse: Decodable {
    let output: GoalCandidatePayload
}

private struct OnboardingAIAthleteBlueprintFunctionResponse: Decodable {
    let output: AthleteBlueprintAIPayload
}

private struct OnboardingAIFitnessStrategyTargetFunctionResponse: Decodable {
    let output: FitnessStrategyAITargetProposalPayload
}

private struct OnboardingAIFitnessStrategyFunctionResponse: Decodable {
    let output: FitnessStrategyAIPayload
}

private struct OnboardingAISummaryPayload: Codable {
    let readback: String

    init(summary: OnboardingSummaryOutput) {
        readback = summary.readback
    }

    func summaryOutput() -> OnboardingSummaryOutput {
        OnboardingSummaryOutput(
            readback: readback.trimmed
        )
    }
}

private struct OnboardingAIGoalCandidatesPayload: Codable {
    let candidates: [GoalCandidatePayload]
}

private struct OnboardingSummaryOutput {
    let readback: String

    var isValid: Bool {
        !readback.trimmed.isEmpty
    }
}

private struct SummaryItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let label: String
    let value: String
}

private struct GoalCandidate: Identifiable, Equatable {
    let id: String
    let title: String
    let rationale: String
    let tracking: String
    let timeline: GoalTimeline
    let systemImage: String
}

private struct RemoteOnboardingAIProvider: OnboardingAIProvider {
    private let supabase = SupabaseClientProvider.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HAYF", category: "onboarding.ai")

    func generateSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) async throws -> OnboardingSummaryOutput {
        do {
            let request = OnboardingAIFunctionRequest(
                task: .generateSummary,
                context: OnboardingAICompactContext(intent: intent, draft: draft),
                candidates: nil
            )
            let response: OnboardingAISummaryFunctionResponse = try await invoke(request)
            return response.output.summaryOutput()
        } catch {
            logger.error("Onboarding summary AI generation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func generateGoalCandidates(draft: ConsistencyOnboardingDraft) async throws -> [GoalCandidate] {
        do {
            let request = OnboardingAIFunctionRequest(
                task: .generateGoalCandidates,
                context: OnboardingAICompactContext(intent: .findGoal, draft: draft),
                candidates: nil
            )
            let response: OnboardingAIGoalCandidatesFunctionResponse = try await invoke(request)
            return response.output.candidates.map { $0.goalCandidate() }
        } catch {
            logger.error("Goal candidate AI generation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func generateBlendedCandidate(from candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) async throws -> GoalCandidate? {
        do {
            let request = OnboardingAIFunctionRequest(
                task: .generateBlendedCandidate,
                context: OnboardingAICompactContext(intent: .findGoal, draft: draft),
                candidates: candidates.map(GoalCandidatePayload.init(candidate:))
            )
            let response: OnboardingAIBlendedCandidateFunctionResponse = try await invoke(request)
            return response.output.goalCandidate()
        } catch {
            logger.error("Blended candidate AI generation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func generateAthleteBlueprint(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        snapshot: HealthFeatureSnapshot?,
        fallback: AthleteBlueprintOutput
    ) async throws -> AthleteBlueprintOutput {
        do {
            let request = AthleteBlueprintAIFunctionRequest(
                task: .generateAthleteBlueprint,
                context: AthleteBlueprintAICompactContext(
                    intent: intent,
                    draft: draft,
                    snapshot: snapshot,
                    fallback: fallback
                )
            )
            let response: OnboardingAIAthleteBlueprintFunctionResponse = try await invoke(request)
            return response.output.merged(with: fallback)
        } catch {
            logger.error("Athlete Blueprint AI generation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func generateFitnessStrategy(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        blueprint: AthleteBlueprintOutput,
        fallback: FitnessStrategyOutput
    ) async throws -> FitnessStrategyOutput {
        do {
            let targetContext = FitnessStrategyAITargetGenerationContext(
                intent: intent,
                draft: draft,
                blueprint: blueprint,
                fallback: fallback
            )
            let targetRequest = FitnessStrategyTargetAIFunctionRequest(
                task: .generateFitnessStrategyTargets,
                context: targetContext
            )
            let targetResponse: OnboardingAIFitnessStrategyTargetFunctionResponse = try await invoke(targetRequest)
            let targetStrategy = targetResponse.output.merged(with: fallback, targetBrief: targetContext.targetBrief)

            let context = FitnessStrategyAICompactContext(
                intent: intent,
                draft: draft,
                blueprint: blueprint,
                fallback: targetStrategy
            )
            let request = FitnessStrategyAIFunctionRequest(
                task: .generateFitnessStrategy,
                context: context
            )
            let response: OnboardingAIFitnessStrategyFunctionResponse = try await invoke(request)
            return response.output.merged(with: targetStrategy, targetBrief: targetContext.targetBrief)
        } catch {
            logger.error("Fitness Strategy AI generation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func invoke<Response: Decodable>(_ request: OnboardingAIFunctionRequest) async throws -> Response {
        do {
            return try await supabase.functions.invoke(
                "onboarding-ai",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            throw Self.readableFunctionError(error)
        }
    }

    private func invoke<Response: Decodable>(_ request: AthleteBlueprintAIFunctionRequest) async throws -> Response {
        do {
            return try await supabase.functions.invoke(
                "onboarding-ai",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            throw Self.readableFunctionError(error)
        }
    }

    private func invoke<Response: Decodable>(_ request: FitnessStrategyAIFunctionRequest) async throws -> Response {
        do {
            return try await supabase.functions.invoke(
                "onboarding-ai",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            throw Self.readableFunctionError(error)
        }
    }

    private func invoke<Response: Decodable>(_ request: FitnessStrategyTargetAIFunctionRequest) async throws -> Response {
        do {
            return try await supabase.functions.invoke(
                "onboarding-ai",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            throw Self.readableFunctionError(error)
        }
    }

    private static func readableFunctionError(_ error: Error) -> Error {
        guard case let FunctionsError.httpError(code, data) = error else {
            return error
        }

        let message: String
        if
            let payload = try? JSONDecoder().decode(OnboardingAIFunctionErrorPayload.self, from: data),
            let errorMessage = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines),
            !errorMessage.isEmpty
        {
            message = errorMessage
        } else if
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !body.isEmpty
        {
            message = body
        } else {
            message = "Edge Function returned a non-2xx status code: \(code)"
        }

        return OnboardingAIFunctionError(statusCode: code, message: message)
    }
}

private struct OnboardingAIFunctionError: LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? {
        "Onboarding AI error \(statusCode): \(message)"
    }
}

private struct OnboardingAIFunctionErrorPayload: Decodable {
    let error: String?
}

private struct MockOnboardingAIProvider: OnboardingAIProvider {
    func generateSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) async throws -> OnboardingSummaryOutput {
        await mockDelay()
        return Self.fallbackSummary(intent: intent, draft: draft)
    }

    func generateGoalCandidates(draft: ConsistencyOnboardingDraft) async throws -> [GoalCandidate] {
        await mockDelay()
        return Self.fallbackGoalCandidates(for: draft)
    }

    func generateBlendedCandidate(from candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) async throws -> GoalCandidate? {
        await mockDelay()
        return Self.blend(candidates: candidates, draft: draft)
    }

    func generateAthleteBlueprint(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        snapshot: HealthFeatureSnapshot?,
        fallback: AthleteBlueprintOutput
    ) async throws -> AthleteBlueprintOutput {
        await mockDelay()
        return fallback
    }

    func generateFitnessStrategy(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        blueprint: AthleteBlueprintOutput,
        fallback: FitnessStrategyOutput
    ) async throws -> FitnessStrategyOutput {
        await mockDelay()
        return fallback
    }

    private func mockDelay() async {
        try? await Task.sleep(nanoseconds: 550_000_000)
    }

    static func fallbackSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) -> OnboardingSummaryOutput {
        switch intent {
        case .stayConsistent:
            let frequency = draft.frequency?.summary ?? "a repeatable weekly rhythm"
            return OnboardingSummaryOutput(
                readback: "You want \(frequency) to become durable, with a realistic floor for weeks that get messy."
            )
        case .concreteGoal:
            let goal = draft.goalSummary == "Not set" ? "a concrete target" : draft.goalSummary.lowercased()
            return OnboardingSummaryOutput(
                readback: "You want HAYF to coach toward \(goal), while respecting your available training menu and recovery constraints."
            )
        case .findGoal:
            let goal = draft.goalSummary == "Not set" ? "a goal direction" : draft.goalSummary.lowercased()
            let primary = draft.trainingOptions.first?.title.lowercased() ?? "your preferred training"
            let support = draft.trainingOptions.dropFirst().prefix(2).map { $0.title.lowercased() }
            let supportClause = support.isEmpty ? "" : ", with \(support.joined(separator: " and ")) as support"
            return OnboardingSummaryOutput(
                readback: "You landed on \(goal), led by \(primary)\(supportClause), because that gives the next block a clear fitness direction without ignoring what you actually want to train."
            )
        }
    }

    static func fallbackGoalCandidates(for draft: ConsistencyOnboardingDraft) -> [GoalCandidate] {
        let avoidsRunning = draft.goalAvoidances.contains(.running)
        let avoidsGym = draft.goalAvoidances.contains(.gymDependence)
        let wantsEndurance = draft.goalDirection == .betterEndurance || draft.challengeStyle == .eventsDeadlines
        let wantsStrength = draft.goalDirection == .stronger || draft.trainingOptions.contains(.strength)
        let sportReady = draft.goalDirection == .sportReady || draft.trainingOptions.contains(.tennis) || draft.trainingOptions.contains(.football) || draft.trainingOptions.contains(.basketball)

        let first = avoidsRunning
            ? GoalCandidate(
                id: "balanced-athlete",
                title: "Balanced athlete rhythm",
                rationale: "Because you want progress without leaning on running, this gives us a steady mix of strength, low-impact cardio, and mobility to build from together.",
                tracking: "Sessions completed, strength exposure, cardio exposure, recovery trend.",
                timeline: .eightWeeks,
                systemImage: "circle.lefthalf.filled"
            )
            : GoalCandidate(
                id: "endurance-base",
                title: wantsEndurance ? "Improve 10K readiness" : "Build an aerobic base",
                rationale: "Your endurance focus gives us a clear first project, and we can make it feel ambitious while still light enough to repeat.",
                tracking: "Easy minutes, long-session confidence, consistency, recovery.",
                timeline: wantsEndurance ? .twelveWeeks : .eightWeeks,
                systemImage: "figure.run"
            )

        let second = wantsStrength
            ? GoalCandidate(
                id: "strength-base",
                title: "Build strength with one cardio anchor",
                rationale: avoidsGym ? "Your strength priority still has plenty of room to grow without depending on a gym, so we will keep the work simple and focused." : "Your strength priority gives us the main target, while one cardio anchor keeps the build feeling athletic and useful.",
                tracking: "Strength sessions, movement quality, conditioning touchpoint, soreness.",
                timeline: .twelveWeeks,
                systemImage: "figure.strengthtraining.traditional"
            )
            : GoalCandidate(
                id: "consistency-reset",
                title: "Consistency reset",
                rationale: "This turns the first win into something repeatable, with a clear floor for messy weeks and less friction around getting started.",
                tracking: "Weekly sessions, bad-day floor used, skipped-week recovery.",
                timeline: .fourWeeks,
                systemImage: "arrow.triangle.2.circlepath"
            )

        let third = sportReady
            ? GoalCandidate(
                id: "sport-ready",
                title: "Build sport-ready conditioning",
                rationale: "Because feeling better in your sport is the payoff, we will build the engine, mobility, and strength base that makes sessions more fun.",
                tracking: "Conditioning, mobility, strength support, sport-session readiness.",
                timeline: .eightWeeks,
                systemImage: "sportscourt"
            )
            : GoalCandidate(
                id: "balanced-energy",
                title: "Feel-fit build",
                rationale: "This gives your training a positive direction without forcing a hard event, so we can build energy and capability week by week.",
                tracking: "Energy, consistency, cardio exposure, strength exposure.",
                timeline: .eightWeeks,
                systemImage: "bolt.heart"
            )

        return [first, second, third]
    }

    static func blend(candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) -> GoalCandidate {
        guard candidates.count >= 2 else {
            return fallbackGoalCandidates(for: draft).first ?? GoalCandidate(
                id: "blended-fallback",
                title: "Balanced training goal",
                rationale: "This blends consistency, strength, and easy cardio into a rhythm we can actually make stick.",
                tracking: "Sessions, recovery, strength exposure, cardio exposure.",
                timeline: .eightWeeks,
                systemImage: "point.topleft.down.curvedto.point.bottomright.up"
            )
        }

        return GoalCandidate(
            id: "blended-\(candidates.map(\.id).joined(separator: "-"))",
            title: "Blended goal",
            rationale: "We will keep the clearest target from \(candidates[0].title.removingGoalTimeline(candidates[0].timeline).lowercased()) and borrow the support structure from \(candidates[1].title.removingGoalTimeline(candidates[1].timeline).lowercased()), so the goal feels focused without becoming too narrow.",
            tracking: "\(candidates[0].tracking) Also watch: \(candidates[1].tracking.lowercased())",
            timeline: candidates.map(\.timeline).max(by: { $0.weeks < $1.weeks }) ?? .eightWeeks,
            systemImage: "point.topleft.down.curvedto.point.bottomright.up"
        )
    }

    private static func concreteGoalTitle(from draft: ConsistencyOnboardingDraft) -> String {
        let goal = draft.goalBrief.trimmed
        if goal.isEmpty {
            return "Concrete training goal"
        }

        if containsAny(goal, values: ["half", "marathon"]) && containsAny(goal, values: ["2 hours", "sub 2", "sub-2", "under 2"]) {
            return "Run a sub-2 half marathon"
        }

        return goal
    }

    private static func containsAny(_ text: String, values: [String]) -> Bool {
        let lowercasedText = text.lowercased()
        return values.contains { lowercasedText.contains($0) }
    }
}

private enum TrainingOption: String, CaseIterable, Identifiable {
    case strength
    case running
    case cycling
    case swimming
    case tennis
    case football
    case basketball
    case mobility
    case walking
    case yoga

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .strength: return "figure.strengthtraining.traditional"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .tennis: return "tennis.racket"
        case .football: return "soccerball"
        case .basketball: return "basketball"
        case .mobility: return "figure.cooldown"
        case .walking: return "figure.walk"
        case .yoga: return "figure.mind.and.body"
        }
    }

    var infrastructureOptions: [InfrastructureAccess] {
        switch self {
        case .strength:
            return [.gym, .homeWeights]
        case .running, .walking:
            return [.outdoorRoutes, .treadmill]
        case .cycling:
            return [.outdoorBike, .indoorBike]
        case .swimming:
            return [.pool]
        case .tennis:
            return [.tennisCourt]
        case .football:
            return [.field]
        case .basketball:
            return [.court]
        case .mobility, .yoga:
            return [.homeSpace]
        }
    }
}

private enum InfrastructureAccess: String, CaseIterable, Identifiable {
    case gym
    case homeWeights
    case outdoorRoutes
    case treadmill
    case outdoorBike
    case indoorBike
    case pool
    case tennisCourt
    case field
    case court
    case homeSpace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gym: return "Gym"
        case .homeWeights: return "Weights at home"
        case .outdoorRoutes: return "Outdoor routes"
        case .treadmill: return "Treadmill"
        case .outdoorBike: return "Outdoor bike"
        case .indoorBike: return "Indoor bike"
        case .pool: return "Pool"
        case .tennisCourt: return "Tennis court"
        case .field: return "Field"
        case .court: return "Basketball court"
        case .homeSpace: return "Space at home"
        }
    }

    var systemImage: String {
        switch self {
        case .gym: return "dumbbell"
        case .homeWeights: return "figure.strengthtraining.traditional"
        case .outdoorRoutes: return "figure.run"
        case .treadmill: return "figure.run.treadmill"
        case .outdoorBike: return "bicycle"
        case .indoorBike: return "bicycle.circle"
        case .pool: return "figure.pool.swim"
        case .tennisCourt: return "tennis.racket"
        case .field: return "soccerball"
        case .court: return "basketball"
        case .homeSpace: return "house"
        }
    }
}

private enum Weekday: String, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var shortTitle: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    var singleLetterTitle: String {
        switch self {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "S"
        }
    }
}

private enum DayPart: String, CaseIterable, Identifiable {
    case morning
    case midday
    case afternoon
    case evening

    static let allCases: [DayPart] = [.morning, .afternoon, .evening]

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .morning: return "sunrise"
        case .midday: return "sun.max"
        case .afternoon: return "sun.max"
        case .evening: return "moon"
        }
    }
}

private enum BodyFatBand: String, CaseIterable, Identifiable {
    case maleUnder10
    case male10To12
    case male12To15
    case male15To17
    case male17To20
    case maleAbove20
    case femaleUnder18
    case female18To21
    case female21To25
    case female25To28
    case female28To32
    case femaleAbove32

    var id: String { rawValue }

    static func options(for reference: PhysiologyReference) -> [BodyFatBand] {
        switch reference {
        case .male:
            return [.maleUnder10, .male10To12, .male12To15, .male15To17, .male17To20, .maleAbove20]
        case .female:
            return [.femaleUnder18, .female18To21, .female21To25, .female25To28, .female28To32, .femaleAbove32]
        }
    }

    var title: String {
        switch self {
        case .maleUnder10: return "<10%"
        case .male10To12: return "10-12%"
        case .male12To15: return "12-15%"
        case .male15To17: return "15-17%"
        case .male17To20: return "17-20%"
        case .maleAbove20: return "20%+"
        case .femaleUnder18: return "<18%"
        case .female18To21: return "18-21%"
        case .female21To25: return "21-25%"
        case .female25To28: return "25-28%"
        case .female28To32: return "28-32%"
        case .femaleAbove32: return "32%+"
        }
    }

    var subtitle: String {
        switch self {
        case .maleUnder10:
            return "Athlete-level leanness; uncommon outside serious training or physique focus."
        case .male10To12:
            return "Visibly lean with clear abs and vascularity; usually demands sustained discipline."
        case .male12To15:
            return "Lean around major muscle groups; some vascularity, with abs depending on genetics and diet."
        case .male15To17:
            return "Strong and sporty without necessarily looking lean; muscle outlines remain clear."
        case .male17To20:
            return "Athletic build with softer definition; strength can show more than leanness."
        case .maleAbove20:
            return "Less visible definition day to day; body-composition goals may matter more than appearance cues."
        case .femaleUnder18:
            return "Very lean and athletic; uncommon without high training load or physique focus."
        case .female18To21:
            return "Visibly lean and athletic with clear muscle shape and some definition."
        case .female21To25:
            return "Fit and toned; muscle definition shows, especially with regular training."
        case .female25To28:
            return "Strong and healthy-looking with softer definition but clear athletic potential."
        case .female28To32:
            return "Active-looking with less visible definition; performance can still be strong."
        case .femaleAbove32:
            return "Less visible definition day to day; body-composition goals may matter more than appearance cues."
        }
    }

    var midpointEstimate: Double {
        switch self {
        case .maleUnder10: return 9
        case .male10To12: return 11
        case .male12To15: return 13.5
        case .male15To17: return 16
        case .male17To20: return 18.5
        case .maleAbove20: return 22
        case .femaleUnder18: return 17
        case .female18To21: return 19.5
        case .female21To25: return 23
        case .female25To28: return 26.5
        case .female28To32: return 30
        case .femaleAbove32: return 34
        }
    }
}

private enum MotivationAnchor: String, CaseIterable, Identifiable {
    case capable
    case energy
    case balanced
    case momentum
    case overthinking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capable: return "Feeling capable in my body"
        case .energy: return "Having energy for my life"
        case .balanced: return "Staying balanced, not extreme"
        case .momentum: return "Not losing momentum again"
        case .overthinking: return "Training without overthinking"
        }
    }

    var systemImage: String {
        switch self {
        case .capable: return "figure.walk.motion"
        case .energy: return "bolt.heart"
        case .balanced: return "circle.lefthalf.filled"
        case .momentum: return "arrow.triangle.2.circlepath"
        case .overthinking: return "scope"
        }
    }
}

private enum TrainingFrequency: String, CaseIterable, Identifiable {
    case two
    case three
    case four
    case fivePlus
    case changes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .two: return "2 days"
        case .three: return "3 days"
        case .four: return "4 days"
        case .fivePlus: return "5+ days"
        case .changes: return "It changes"
        }
    }

    var summary: String {
        switch self {
        case .two: return "2 days/week"
        case .three: return "3 days/week"
        case .four: return "4 days/week"
        case .fivePlus: return "5+ days/week"
        case .changes: return "variable weeks"
        }
    }
}

private enum SessionLength: String, CaseIterable, Identifiable {
    case twenty
    case thirty
    case fortyFive
    case sixtyPlus
    case varies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twenty: return "20 min"
        case .thirty: return "30 min"
        case .fortyFive: return "45 min"
        case .sixtyPlus: return "60+ min"
        case .varies: return "Varies"
        }
    }

    var previewDuration: String {
        switch self {
        case .twenty: return "20 min"
        case .thirty: return "30 min"
        case .fortyFive: return "45 min"
        case .sixtyPlus: return "60 min"
        case .varies: return "30-45 min"
        }
    }
}

private enum GoalExperience: String, CaseIterable, Identifiable {
    case underOneYear
    case oneToThreeYears
    case threeToFiveYears
    case fivePlusYears

    var id: String { rawValue }

    var title: String {
        switch self {
        case .underOneYear: return "Under 1 year"
        case .oneToThreeYears: return "1-3 years"
        case .threeToFiveYears: return "3-5 years"
        case .fivePlusYears: return "5+ years"
        }
    }

    var subtitle: String {
        switch self {
        case .underOneYear: return "Still building your base."
        case .oneToThreeYears: return "Some history, still plenty of room to shape."
        case .threeToFiveYears: return "A solid base HAYF should respect."
        case .fivePlusYears: return "Long-term training experience."
        }
    }

    var systemImage: String {
        switch self {
        case .underOneYear: return "leaf"
        case .oneToThreeYears: return "figure.walk.motion"
        case .threeToFiveYears: return "figure.run"
        case .fivePlusYears: return "chart.line.uptrend.xyaxis"
        }
    }
}

private enum GoalTimeline: String, CaseIterable, Identifiable {
    case fourWeeks
    case eightWeeks
    case twelveWeeks
    case specificDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fourWeeks: return "4 weeks"
        case .eightWeeks: return "8 weeks"
        case .twelveWeeks: return "12 weeks"
        case .specificDate: return "Date"
        }
    }

    static let discoveryCases: [GoalTimeline] = [.fourWeeks, .eightWeeks, .twelveWeeks]

    var weeks: Int {
        switch self {
        case .fourWeeks: return 4
        case .eightWeeks: return 8
        case .twelveWeeks: return 12
        case .specificDate: return 12
        }
    }

    init?(weeks: Int) {
        switch weeks {
        case 4: self = .fourWeeks
        case 8: self = .eightWeeks
        case 12: self = .twelveWeeks
        default: return nil
        }
    }
}

private enum GoalPriority: String, CaseIterable, Identifiable {
    case goalProgress
    case stayingBalanced
    case avoidInjury
    case preserveStrength

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goalProgress: return "Goal progress"
        case .stayingBalanced: return "Staying balanced"
        case .avoidInjury: return "Avoiding injury"
        case .preserveStrength: return "Keeping strength/cardio"
        }
    }

    var summaryTitle: String {
        switch self {
        case .goalProgress: return "protect goal progress"
        case .stayingBalanced: return "stay balanced"
        case .avoidInjury: return "avoid injury"
        case .preserveStrength: return "preserve strength/cardio"
        }
    }

    var subtitle: String {
        switch self {
        case .goalProgress: return "Keep the target moving, even if extras drop."
        case .stayingBalanced: return "Do not let the goal take over the whole week."
        case .avoidInjury: return "Progress only if the risk stays reasonable."
        case .preserveStrength: return "Keep the hybrid base alive around the goal."
        }
    }

    var systemImage: String {
        switch self {
        case .goalProgress: return "target"
        case .stayingBalanced: return "circle.lefthalf.filled"
        case .avoidInjury: return "cross.case"
        case .preserveStrength: return "figure.strengthtraining.traditional"
        }
    }
}

private enum GoalDirection: String, CaseIterable, Identifiable {
    case moreAthletic
    case stronger
    case betterEndurance
    case sportReady
    case moreConsistent
    case lessTired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moreAthletic: return "More athletic"
        case .stronger: return "Stronger"
        case .betterEndurance: return "Better endurance"
        case .sportReady: return "Ready for a sport"
        case .moreConsistent: return "More consistent"
        case .lessTired: return "Less tired or stressed"
        }
    }

    var subtitle: String {
        switch self {
        case .moreAthletic: return "Feel capable across strength, cardio, and movement."
        case .stronger: return "Build a clearer strength base."
        case .betterEndurance: return "Make cardio feel less costly."
        case .sportReady: return "Move better when the game starts."
        case .moreConsistent: return "Make training repeatable before it gets ambitious."
        case .lessTired: return "Use training to support energy, not drain it."
        }
    }

    var systemImage: String {
        switch self {
        case .moreAthletic: return "figure.mixed.cardio"
        case .stronger: return "figure.strengthtraining.traditional"
        case .betterEndurance: return "figure.run"
        case .sportReady: return "sportscourt"
        case .moreConsistent: return "calendar.badge.checkmark"
        case .lessTired: return "bolt.heart"
        }
    }
}

private enum ChallengeStyle: String, CaseIterable, Identifiable {
    case numbersTargets
    case eventsDeadlines
    case skillProgression
    case feelingBetter
    case competeWithSelf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .numbersTargets: return "Numbers and targets"
        case .eventsDeadlines: return "Events and deadlines"
        case .skillProgression: return "Skill progression"
        case .feelingBetter: return "Feeling better"
        case .competeWithSelf: return "Competing with myself"
        }
    }

    var subtitle: String {
        switch self {
        case .numbersTargets: return "Give me a clear metric to move."
        case .eventsDeadlines: return "A date helps me care."
        case .skillProgression: return "I like getting visibly better at something."
        case .feelingBetter: return "The goal should improve daily life."
        case .competeWithSelf: return "I want a challenge without external pressure."
        }
    }

    var systemImage: String {
        switch self {
        case .numbersTargets: return "number"
        case .eventsDeadlines: return "flag"
        case .skillProgression: return "arrow.up.forward"
        case .feelingBetter: return "heart"
        case .competeWithSelf: return "person"
        }
    }
}

private enum GoalAvoidance: String, CaseIterable, Identifiable {
    case running
    case heavyLifting
    case longWorkouts
    case strictPlans
    case highIntensity
    case gymDependence
    case nothingSpecific

    var id: String { rawValue }

    var title: String {
        switch self {
        case .running: return "Running"
        case .heavyLifting: return "Heavy lifting"
        case .longWorkouts: return "Long workouts"
        case .strictPlans: return "Strict plans"
        case .highIntensity: return "High intensity"
        case .gymDependence: return "Gym dependence"
        case .nothingSpecific: return "Nothing specific"
        }
    }

    var systemImage: String {
        switch self {
        case .running: return "figure.run"
        case .heavyLifting: return "dumbbell"
        case .longWorkouts: return "timer"
        case .strictPlans: return "list.clipboard"
        case .highIntensity: return "flame"
        case .gymDependence: return "building.2"
        case .nothingSpecific: return "checkmark"
        }
    }
}

private enum ConsistencyBlocker: String, CaseIterable, Identifiable {
    case workSchedule
    case lowEnergy
    case soreness
    case noPlan
    case travel
    case motivation
    case weather
    case gymAccess
    case allOrNothing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workSchedule: return "Work schedule"
        case .lowEnergy: return "Low energy"
        case .soreness: return "Soreness"
        case .noPlan: return "No plan"
        case .travel: return "Travel"
        case .motivation: return "Motivation"
        case .weather: return "Weather"
        case .gymAccess: return "Gym access"
        case .allOrNothing: return "All-or-nothing weeks"
        }
    }

    var systemImage: String {
        switch self {
        case .workSchedule: return "calendar"
        case .lowEnergy: return "battery.25"
        case .soreness: return "figure.strengthtraining.traditional"
        case .noPlan: return "clipboard"
        case .travel: return "airplane"
        case .motivation: return "bolt"
        case .weather: return "cloud.rain"
        case .gymAccess: return "building.2"
        case .allOrNothing: return "arrow.left.and.right"
        }
    }
}

private enum CoachingSupportStyle: String, CaseIterable, Identifiable {
    case calmReset
    case directPush
    case easiestUseful
    case explainTradeoff
    case remindWhy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calmReset: return "Give me a calm reset"
        case .directPush: return "Push me directly"
        case .easiestUseful: return "Offer the easiest useful option"
        case .explainTradeoff: return "Explain the tradeoff"
        case .remindWhy: return "Remind me why this matters"
        }
    }

    var summaryTitle: String {
        switch self {
        case .calmReset: return "calm reset"
        case .directPush: return "direct push"
        case .easiestUseful: return "easiest useful option"
        case .explainTradeoff: return "tradeoff explanation"
        case .remindWhy: return "remind me why"
        }
    }

    var subtitle: String {
        switch self {
        case .calmReset: return "Help me restart without guilt."
        case .directPush: return "Be clear when I'm avoiding it."
        case .easiestUseful: return "Reduce the workout, keep the rhythm."
        case .explainTradeoff: return "Show what changes if I skip or swap."
        case .remindWhy: return "Connect it back to my reason."
        }
    }

    var systemImage: String {
        switch self {
        case .calmReset: return "arrow.triangle.2.circlepath"
        case .directPush: return "figure.run"
        case .easiestUseful: return "arrow.down.circle"
        case .explainTradeoff: return "arrow.left.arrow.right"
        case .remindWhy: return "target"
        }
    }
}

private enum BadDayFloor: String, CaseIterable, Identifiable {
    case walkMobility
    case twentyEasy
    case strengthCircuit
    case intentionalRest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walkMobility: return "10-min walk or mobility"
        case .twentyEasy: return "20-min easy session"
        case .strengthCircuit: return "Short strength circuit"
        case .intentionalRest: return "Intentional rest"
        }
    }

    var shortTitle: String {
        switch self {
        case .walkMobility: return "10-minute floor"
        case .twentyEasy: return "20-minute fallback"
        case .strengthCircuit: return "short strength circuit"
        case .intentionalRest: return "intentional rest option"
        }
    }

    var subtitle: String {
        switch self {
        case .walkMobility: return "Keep the streak alive gently."
        case .twentyEasy: return "Enough to move without draining you."
        case .strengthCircuit: return "Simple, contained, effective."
        case .intentionalRest: return "Recovery counts when it is deliberate."
        }
    }

    var systemImage: String {
        switch self {
        case .walkMobility: return "figure.walk"
        case .twentyEasy: return "heart"
        case .strengthCircuit: return "figure.strengthtraining.traditional"
        case .intentionalRest: return "moon"
        }
    }
}

private enum HealthRequestState: Equatable {
    case idle
    case requesting
    case connected
    case unavailable
    case failed(String)

    var message: String? {
        switch self {
        case .idle, .requesting:
            return nil
        case .connected:
            return "Apple Health is connected. HAYF will build the first plan from local deterministic health features."
        case .unavailable:
            return "Health data is not available on this device. You can continue the prototype here."
        case .failed(let message):
            return message
        }
    }

    var isError: Bool {
        if case .failed = self { return true }
        return false
    }
}

private struct OnboardingIntro: View {
    var eyebrow = "ONBOARDING"
    let title: String
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .medium))
                .kerning(1.2)
                .foregroundStyle(HAYFColor.secondary)

            Text(title)
                .font(.system(size: 32, weight: .bold, design: .default))
                .lineSpacing(1)
                .foregroundStyle(HAYFColor.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

            Text(copy)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
        }
    }
}

private struct OnboardingHeaderIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(HAYFColor.primary)
            .frame(width: 42, height: 42)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
    }
}

private struct OnboardingOptionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                HAYFIcon(systemImage: systemImage, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(HAYFColor.secondary)
                }

                Spacer()

                RadioDot(isSelected: isSelected)
            }
            .padding(18)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? HAYFColor.orange : HAYFColor.border, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SelectableTile: View {
    let title: String
    let systemImage: String
    let selectionRank: Int?
    let action: () -> Void

    private var isSelected: Bool {
        selectionRank != nil
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HAYFIcon(systemImage: systemImage, isSelected: isSelected)

                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .overlay(alignment: .topTrailing) {
                if let selectionRank {
                    PriorityBadge(rank: selectionRank)
                        .padding(10)
                }
            }
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? HAYFColor.orange : HAYFColor.border, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PriorityBadge: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 24, height: 24)
            .background(HAYFColor.orange)
            .clipShape(Circle())
    }
}

private struct SelectableRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                HAYFIcon(systemImage: systemImage, isSelected: isSelected, size: 32, iconSize: 17)

                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)

                Spacer()

                CheckmarkBox(isSelected: isSelected)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 54)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? HAYFColor.orange : HAYFColor.border, lineWidth: isSelected ? 1.3 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DetailedSelectableRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                HAYFIcon(systemImage: systemImage, isSelected: isSelected, size: 42, iconSize: 22)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(HAYFColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                RadioDot(isSelected: isSelected)
            }
            .padding(16)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? HAYFColor.orange : HAYFColor.border, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct OptionGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.secondary)

            content()
        }
    }
}

private struct CompactChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isSelected ? HAYFColor.orange : HAYFColor.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .background(HAYFColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? HAYFColor.orange : HAYFColor.border, lineWidth: isSelected ? 1.4 : 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct FlexibleChoiceGrid<Item: Identifiable & Hashable>: View where Item: ChoiceDisplayable {
    let items: [Item]
    @Binding var selection: Set<Item>

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                CompactChoiceButton(
                    title: item.choiceTitle,
                    isSelected: selection.contains(item)
                ) {
                    selection.toggle(item)
                }
            }
        }
    }
}

private struct WeekdayAvailabilityRow: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Weekday.allCases) { day in
                CompactWeekdayButton(
                    title: day.singleLetterTitle,
                    isSelected: selection.contains(day)
                ) {
                    selection.toggle(day)
                }
            }
        }
    }
}

private struct CompactWeekdayButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? HAYFColor.orange : HAYFColor.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(isSelected ? HAYFColor.orange.opacity(0.06) : HAYFColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? HAYFColor.orange : HAYFColor.border, lineWidth: isSelected ? 1.3 : 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct DayPartAvailabilityRow: View {
    @Binding var selection: Set<DayPart>

    var body: some View {
        HStack(spacing: 10) {
            ForEach(DayPart.allCases) { dayPart in
                DayPartAvailabilityButton(
                    title: dayPart.title,
                    systemImage: dayPart.systemImage,
                    isSelected: selection.contains(dayPart)
                ) {
                    selection.toggle(dayPart)
                }
            }
        }
    }
}

private struct DayPartAvailabilityButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .regular))
                    .symbolRenderingMode(.monochrome)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isSelected ? HAYFColor.orange : HAYFColor.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(isSelected ? HAYFColor.orange.opacity(0.06) : HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? HAYFColor.orange : HAYFColor.border, lineWidth: isSelected ? 1.3 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private protocol ChoiceDisplayable {
    var choiceTitle: String { get }
}

extension Weekday: ChoiceDisplayable {
    var choiceTitle: String { shortTitle }
}

extension DayPart: ChoiceDisplayable {
    var choiceTitle: String { title }
}

private protocol WheelDisplayable {
    var wheelTitle: String { get }
}

extension TrainingFrequency: WheelDisplayable {
    var wheelTitle: String { title }
}

extension SessionLength: WheelDisplayable {
    var wheelTitle: String { title }
}

private struct WheelChoicePicker<Option: Identifiable & Hashable & WheelDisplayable>: View {
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                Text(option.wheelTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .colorScheme(.light)
        .tint(HAYFColor.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipped()
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct NumberWheelPicker: View {
    let title: String
    let unit: String
    let values: [Int]
    let defaultValue: Int
    @Binding var text: String

    private var selection: Binding<Int> {
        Binding(
            get: {
                let parsed = Double(text.replacingOccurrences(of: ",", with: ".")) ?? Double(defaultValue)
                let value = Int(parsed.rounded())
                guard values.contains(value) else {
                    return defaultValue
                }
                return value
            },
            set: { value in
                text = "\(value)"
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HAYFColor.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            Picker("", selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text("\(value) \(unit)")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)
                        .tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            .colorScheme(.light)
            .tint(HAYFColor.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 118)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct NumericInputField: View {
    let title: String
    let placeholder: String
    let unit: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HAYFColor.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text(unit)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct GoalDatePicker: View {
    @Binding var date: Date

    var body: some View {
        HStack(spacing: 12) {
            HAYFIcon(systemImage: "calendar", isSelected: true, size: 32, iconSize: 17)

            Text("Goal date")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            Spacer()

            DatePicker(
                "Goal date",
                selection: $date,
                in: Date.now...,
                displayedComponents: .date
            )
            .labelsHidden()
            .tint(HAYFColor.orange)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HAYFColor.orange, lineWidth: 1.3)
        }
    }
}

private struct OnboardingTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let characterLimit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HAYFColor.secondary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(Color(red: 163 / 255, green: 163 / 255, blue: 163 / 255))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: Binding(
                    get: { text },
                    set: { text = String($0.prefix(characterLimit)) }
                ))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.primary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(10)
            }
            .frame(height: 128)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(text.count)/\(characterLimit)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .padding(14)
            }
        }
    }
}

private struct SummaryRow: View {
    let systemImage: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            HAYFIcon(systemImage: systemImage, isSelected: true, size: 34, iconSize: 18)

            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .frame(width: 116, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(HAYFColor.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct SummarySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .kerning(1.2)
                .foregroundStyle(HAYFColor.secondary)

            content()
        }
    }
}

private enum GoalCandidateSelectionStyle {
    case single
    case multiple
}

private struct GoalCandidateCard: View {
    let candidate: GoalCandidate
    let isSelected: Bool
    let selectionStyle: GoalCandidateSelectionStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(candidate.title.goalCardTitle(timeline: candidate.timeline))
                            .font(.system(size: 17, weight: .semibold))
                            .lineSpacing(2)
                            .foregroundStyle(HAYFColor.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        GoalTimeframeChip(title: candidate.timeline.title, isSelected: isSelected)
                    }

                    Spacer(minLength: 10)

                    switch selectionStyle {
                    case .single:
                        RadioDot(isSelected: isSelected)
                    case .multiple:
                        CheckmarkBox(isSelected: isSelected)
                    }
                }

                Text(candidate.rationale.goalCardRationale())
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(isSelected ? HAYFColor.orange.opacity(0.06) : HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? HAYFColor.orange.opacity(0.72) : HAYFColor.border, lineWidth: isSelected ? 1.3 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct GoalTimeframeChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? HAYFColor.orange : HAYFColor.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? HAYFColor.orange.opacity(0.10) : HAYFColor.surfaceRaised)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? HAYFColor.orange.opacity(0.18) : HAYFColor.border, lineWidth: 1)
            }
    }
}

private struct PersonalizationNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HAYFIcon(systemImage: "lock", isSelected: true, size: 30, iconSize: 15)

            Text("Used to personalize your setup. You stay in control of what HAYF remembers.")
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(HAYFColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HealthUseRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var showsDivider = true

    var body: some View {
        HStack(spacing: 14) {
            HAYFIcon(systemImage: systemImage, isSelected: true, size: 38, iconSize: 21)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(HAYFColor.border)
                    .frame(height: 1)
                    .padding(.leading, 52)
            }
        }
    }
}

private struct CoachNote: View {
    var systemImage = "sparkle"
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            HAYFIcon(systemImage: systemImage, isSelected: true, size: 34, iconSize: 17)

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(HAYFColor.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.orange.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct FitnessStrategyOutput {
    let read: String
    let goalTargetContext: FitnessStrategyGoalTargetContext
    let snapshotItems: [FitnessStrategySnapshotItem]
    let fitReasons: [FitnessStrategyFitReason]
    let pillars: [FitnessStrategyPillar]
    let phases: [FitnessStrategyPhase]
    let operatingRhythm: FitnessStrategyOperatingRhythm?
    let targets: [FitnessStrategyTarget]
}

private struct FitnessStrategyGoalTargetContext {
    let title: String
    let summary: String
}

private struct FitnessStrategySnapshotItem: Identifiable {
    let id: String
    let systemImage: String
    let value: String
    let label: String
}

private struct FitnessStrategyFitReason: Identifiable {
    let id: String
    let systemImage: String
    let title: String
    let summary: String
}

private struct FitnessStrategyPillar: Identifiable {
    let id: String
    let title: String
    let summary: String
}

private struct FitnessStrategyPhase: Identifiable {
    let id: String
    let name: String
    let objective: String
    let targetSummary: String
    let targets: [FitnessStrategyTarget]
}

private struct FitnessStrategyOperatingRhythm {
    let summary: String
    let anchors: [String]
}

private enum FitnessStrategyTargetScope: String {
    case goal
    case strategy
    case phase
    case week
}

private enum FitnessStrategyTargetKind: String {
    case primary
    case supporting

    var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .supporting: return "Supporting"
        }
    }
}

private enum FitnessStrategyTargetDirection: String {
    case increase
    case decrease
    case maintain
    case complete
    case review
}

private struct FitnessStrategyTarget: Identifiable {
    let id: String
    let scope: FitnessStrategyTargetScope
    let kind: FitnessStrategyTargetKind
    let title: String
    let summary: String
    let metricKey: String?
    let metricCategory: String
    let direction: FitnessStrategyTargetDirection
    let targetValue: Double?
    let unit: String?
    let displayValueOverride: String?

    init(
        id: String,
        scope: FitnessStrategyTargetScope,
        kind: FitnessStrategyTargetKind,
        title: String,
        summary: String,
        metricKey: String?,
        metricCategory: String,
        direction: FitnessStrategyTargetDirection,
        targetValue: Double?,
        unit: String?,
        displayValueOverride: String? = nil
    ) {
        self.id = id
        self.scope = scope
        self.kind = kind
        self.title = title
        self.summary = summary
        self.metricKey = metricKey
        self.metricCategory = metricCategory
        self.direction = direction
        self.targetValue = targetValue
        self.unit = unit
        self.displayValueOverride = displayValueOverride
    }

    var displayValue: String? {
        if let displayValueOverride, !displayValueOverride.isEmpty {
            return displayValueOverride
        }

        guard let targetValue else { return nil }

        let formatted: String
        if targetValue.rounded() == targetValue {
            formatted = "\(Int(targetValue))"
        } else {
            formatted = String(format: "%.1f", targetValue)
        }

        guard let unit, !unit.isEmpty else { return formatted }
        if unit == "%" { return "\(formatted)%" }
        if unit == "weeks" { return "\(formatted) wks" }
        if unit == "modalities" { return "\(formatted) modes" }
        if unit == "sessions/week" || unit == "session/week" { return "\(formatted)/wk" }
        return "\(formatted) \(unit)"
    }
}

private enum FitnessStrategyBuilder {
    static func build(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        blueprint: AthleteBlueprintOutput,
        snapshot: HealthFeatureSnapshot?
    ) -> FitnessStrategyOutput {
        let goal = AthleteBlueprintBuilder.normalizedGoal(intent: intent, draft: draft)
        let usesPhases = goal.category != .consistency
        let anchor = dominantAnchor(from: blueprint, draft: draft)
        let frequency = draft.frequency?.summary ?? "a repeatable weekly rhythm"
        let floor = draft.floorSummary.lowercased()
        let goalTargetContext = FitnessStrategyGoalTargetContext(
            title: goal.displayText,
            summary: "This is the user target HAYF is translating into a coaching strategy, not a separate HAYF target."
        )
        let snapshotItems = snapshotItems(
            goal: goal,
            draft: draft,
            anchor: anchor,
            usesPhases: usesPhases
        )
        let fitReasons = fitReasons(
            goal: goal,
            draft: draft,
            blueprint: blueprint,
            anchor: anchor
        )

        let read: String
        if usesPhases {
            read = "HAYF will coach this through the training path you chose: \(anchor). First the week has to hold, then the work becomes more goal-specific. The strategy is to protect continuity while gradually shifting more of the training toward \(goal.displayText)."
        } else {
            read = "HAYF will coach consistency as the goal itself: build a rhythm that survives ordinary life before it asks for more. The strategy is to keep \(frequency) repeatable, use \(floor) when the week gets tight, and let durable behavior become the first win."
        }

        let pillars = usesPhases
            ? [
                FitnessStrategyPillar(
                    id: "protect_anchor",
                    title: "Protect the chosen path",
                    summary: "Keep \(anchor) visible in the week so the strategy follows what you asked HAYF to coach."
                ),
                FitnessStrategyPillar(
                    id: "earn_progression",
                    title: "Earn progression",
                    summary: "Add harder or more specific work only after the recurring week is holding."
                ),
                FitnessStrategyPillar(
                    id: "preserve_recovery",
                    title: "Preserve recovery slack",
                    summary: "Leave enough room to adapt without turning one missed session into a broken week."
                )
            ]
            : [
                FitnessStrategyPillar(
                    id: "protect_exposures",
                    title: "Protect repeatable exposures",
                    summary: "The first job is to keep training showing up often enough to become normal."
                ),
                FitnessStrategyPillar(
                    id: "reduce_friction",
                    title: "Reduce friction first",
                    summary: "Use the simplest useful session before chasing a more impressive one."
                ),
                FitnessStrategyPillar(
                    id: "use_floor",
                    title: "Use the floor",
                    summary: "A smaller intentional session should keep the rhythm alive when a full session is not realistic."
                )
            ]

        let phases = usesPhases
            ? [
                FitnessStrategyPhase(
                    id: "base",
                    name: "Base",
                    objective: "Make the weekly structure reliable around your real schedule.",
                    targetSummary: "Hold the core weekly exposures with recovery intact.",
                    targets: TargetEngine.phaseTargets(
                        phaseID: "base",
                        phaseName: "Base",
                        goal: goal,
                        draft: draft,
                        snapshot: snapshot
                    )
                ),
                FitnessStrategyPhase(
                    id: "build",
                    name: "Build",
                    objective: "Increase the goal-specific dose without losing the anchor work.",
                    targetSummary: "Progress the main goal signal while keeping support work alive.",
                    targets: TargetEngine.phaseTargets(
                        phaseID: "build",
                        phaseName: "Build",
                        goal: goal,
                        draft: draft,
                        snapshot: snapshot
                    )
                ),
                FitnessStrategyPhase(
                    id: "review",
                    name: "Review",
                    objective: "Sharpen what is working and decide the next strategy move.",
                    targetSummary: "Confirm whether the goal is on track, achieved, or needs review.",
                    targets: TargetEngine.phaseTargets(
                        phaseID: "review",
                        phaseName: "Review",
                        goal: goal,
                        draft: draft,
                        snapshot: snapshot
                    )
                )
            ]
            : []

        let operatingRhythm = usesPhases ? nil : FitnessStrategyOperatingRhythm(
            summary: "\(frequency.capitalized), one low-friction fallback, and a 28-day review cadence.",
            anchors: [
                "Protect \(frequency)",
                "Use \(draft.floorSummary) before skipping completely",
                "Review the rhythm every 28 days"
            ]
        )

        let targets = TargetEngine.buildTargets(
            intent: intent,
            goal: goal,
            draft: draft,
            blueprint: blueprint,
            snapshot: snapshot,
            usesPhases: usesPhases
        )

        return FitnessStrategyOutput(
            read: read,
            goalTargetContext: goalTargetContext,
            snapshotItems: snapshotItems,
            fitReasons: fitReasons,
            pillars: pillars,
            phases: phases,
            operatingRhythm: operatingRhythm,
            targets: targets
        )
    }

    private static func snapshotItems(
        goal: AthleteBlueprintGoal,
        draft: ConsistencyOnboardingDraft,
        anchor: String,
        usesPhases: Bool
    ) -> [FitnessStrategySnapshotItem] {
        let priorities = preferredTrainingOptions(from: draft)
            .prefix(3)
            .enumerated()
            .map { "\($0.offset + 1). \($0.element.title)" }
            .joined(separator: "\n")

        return [
            FitnessStrategySnapshotItem(
                id: "timeframe",
                systemImage: "calendar",
                value: "\(goal.horizonWeeks)",
                label: "weeks"
            ),
            FitnessStrategySnapshotItem(
                id: "frequency",
                systemImage: "repeat",
                value: "\(TargetEngine.targetWeeklySessions(from: draft.frequency))",
                label: "sessions/week"
            ),
            FitnessStrategySnapshotItem(
                id: "priorities",
                systemImage: "list.number",
                value: priorities.isEmpty ? anchor.replacingOccurrences(of: " and ", with: " + ").capitalized : priorities,
                label: "training priorities"
            )
        ]
    }

    private static func fitReasons(
        goal: AthleteBlueprintGoal,
        draft: ConsistencyOnboardingDraft,
        blueprint: AthleteBlueprintOutput,
        anchor: String
    ) -> [FitnessStrategyFitReason] {
        let timeWindow = draft.sessionLength?.previewDuration ?? "your available session length"
        let preferredOptions = preferredTrainingOptions(from: draft)
        let trainingMix = preferredOptions.prefix(2).map(\.title).joined(separator: " + ")
        let mixSummary = trainingMix.isEmpty
            ? "The strategy starts from the training options you said are realistic."
            : "\(trainingMix) gives HAYF the clearest direction for this strategy."

        return [
            FitnessStrategyFitReason(
                id: "available_window",
                systemImage: "clock",
                title: "Realistic session windows",
                summary: "\(timeWindow) gives HAYF a realistic training constraint."
            ),
            FitnessStrategyFitReason(
                id: "training_access",
                systemImage: preferredOptions.first?.systemImage ?? "checkmark.circle",
                title: "Training that fits your setup",
                summary: mixSummary
            ),
            FitnessStrategyFitReason(
                id: "blueprint_base",
                systemImage: "person.text.rectangle",
                title: blueprint.archetype.label,
                summary: "Your history adds context without overriding your chosen path."
            )
        ]
    }

    private static func dominantAnchor(from blueprint: AthleteBlueprintOutput, draft: ConsistencyOnboardingDraft) -> String {
        let preferredOptions = preferredTrainingOptions(from: draft)
        if !preferredOptions.isEmpty {
            return trainingAnchorLabel(for: preferredOptions)
        }

        let lowercasedLabel = blueprint.archetype.label.lowercased()
        if lowercasedLabel.contains("strength") {
            return "strength"
        }
        if lowercasedLabel.contains("endurance") {
            return "endurance"
        }
        if lowercasedLabel.contains("hybrid") {
            return "hybrid training"
        }
        if let first = draft.trainingOptions.first {
            return first.title.lowercased()
        }
        return "repeatable training"
    }

    private static func preferredTrainingOptions(from draft: ConsistencyOnboardingDraft) -> [TrainingOption] {
        draft.trainingOptions.filter { option in
            !isAvoided(option, draft: draft) && hasAccess(for: option, draft: draft)
        }
    }

    private static func isAvoided(_ option: TrainingOption, draft: ConsistencyOnboardingDraft) -> Bool {
        switch option {
        case .running:
            return draft.goalAvoidances.contains(.running)
        case .strength:
            return draft.goalAvoidances.contains(.heavyLifting) || draft.goalAvoidances.contains(.gymDependence)
        default:
            return false
        }
    }

    private static func hasAccess(for option: TrainingOption, draft: ConsistencyOnboardingDraft) -> Bool {
        let required = option.infrastructureOptions
        guard !required.isEmpty else { return true }
        return !draft.infrastructureAccess.isDisjoint(with: Set(required))
    }

    private static func trainingAnchorLabel(for options: [TrainingOption]) -> String {
        let titles = options.prefix(2).map { $0.title.lowercased() }
        switch titles.count {
        case 0:
            return "chosen training"
        case 1:
            return titles[0]
        default:
            return "\(titles[0]) and \(titles[1])"
        }
    }

    private static func trainingAnchorDisplayTitle(for options: [TrainingOption]) -> String {
        let titles = options.prefix(2).map(\.title)
        switch titles.count {
        case 0:
            return "Chosen training"
        case 1:
            return titles[0]
        default:
            return titles.joined(separator: " + ")
        }
    }

    private enum TargetEngine {
        static func buildTargets(
            intent: OnboardingIntent,
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            blueprint: AthleteBlueprintOutput,
            snapshot: HealthFeatureSnapshot?,
            usesPhases: Bool
        ) -> [FitnessStrategyTarget] {
            if goal.category == .consistency {
                return consistencyTargets(goal: goal, draft: draft, blueprint: blueprint, snapshot: snapshot)
            }

            let goalSignal = bodyCompositionTarget(goal: goal, draft: draft, snapshot: snapshot)
                ?? goalSignalTarget(intent: intent, goal: goal, draft: draft, snapshot: snapshot)

            return [
                goalSignal,
                strategyRhythmTarget(goal: goal, draft: draft, snapshot: snapshot),
                strategyAnchorTarget(goal: goal, draft: draft, blueprint: blueprint)
            ]
        }

        private static func consistencyTargets(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            blueprint: AthleteBlueprintOutput,
            snapshot: HealthFeatureSnapshot?
        ) -> [FitnessStrategyTarget] {
            let weeklySessions = targetWeeklySessions(from: draft.frequency)
            let strongWeeks = targetStrongWeeks(from: weeklySessions, horizonWeeks: goal.horizonWeeks, snapshot: snapshot)
            let primarySummary = "Over the \(goal.horizonWeeks)-week consistency block, HAYF wants at least \(strongWeeks) weeks where you complete \(weeklySessions)+ sessions. That turns consistency into a visible behavior target instead of a vague intention."

            return [
                FitnessStrategyTarget(
                    id: "strong_weeks_12w",
                    scope: .strategy,
                    kind: .supporting,
                    title: "\(strongWeeks) of \(goal.horizonWeeks) strong weeks",
                    summary: primarySummary,
                    metricKey: "weeks_with_min_sessions_strategy",
                    metricCategory: "consistency",
                    direction: .increase,
                    targetValue: Double(strongWeeks),
                    unit: "weeks",
                    displayValueOverride: "\(strongWeeks) of \(goal.horizonWeeks)"
                ),
                FitnessStrategyTarget(
                    id: "weekly_min_sessions",
                    scope: .strategy,
                    kind: .supporting,
                    title: "\(weeklySessions) sessions per week",
                    summary: "The strategy stays honest when a normal week reaches \(weeklySessions) planned training exposures often enough to become the baseline.",
                    metricKey: "planned_sessions_7d",
                    metricCategory: "consistency",
                    direction: .maintain,
                    targetValue: Double(weeklySessions),
                    unit: "sessions"
                ),
                FitnessStrategyTarget(
                    id: "gap_recovery",
                    scope: .strategy,
                    kind: .supporting,
                    title: "No long drop-offs",
                    summary: "If a week slips, the target is to return within 7 days so one miss does not become the pattern HAYF is trying to break.",
                    metricKey: "max_gap_days_12w",
                    metricCategory: "consistency",
                    direction: .decrease,
                    targetValue: 7,
                    unit: "days"
                )
            ]
        }

        private static func bodyCompositionTarget(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?
        ) -> FitnessStrategyTarget? {
            guard goal.category == .bodyComposition || containsBodyCompositionLanguage(goal.displayText) else { return nil }

            let requestedChange = requestedKilogramChange(in: goal.displayText)
            let baseline = draft.bodyMassKilograms
                ?? snapshot?.body.bodyMass28DayAverageKilograms
                ?? snapshot?.body.bodyMassKilograms
            let targetValue: Double?
            let displayValue: String?
            let summary: String
            if let baseline, let requestedChange {
                targetValue = max(25, baseline + requestedChange)
                displayValue = nil
                summary = "By the end of the strategy, move the 28-day body-mass average toward \(String(format: "%.1f", max(25, baseline + requestedChange))) kg without relying on single weigh-ins."
            } else if let baseline {
                targetValue = baseline
                displayValue = "±1 kg"
                summary = "By the end of the strategy, keep the 28-day body-mass average within about 1 kg of \(String(format: "%.1f", baseline)) kg while the training targets move up."
            } else {
                targetValue = 2
                displayValue = "2/week"
                summary = "By the end of the strategy, keep enough body-mass check-ins for HAYF to track the trend alongside training."
            }
            let direction: FitnessStrategyTargetDirection = requestedChange.map { $0 < 0 ? .decrease : .increase } ?? .maintain

            return FitnessStrategyTarget(
                id: "body_mass_trend",
                scope: .strategy,
                kind: .supporting,
                title: requestedChange.map { abs($0) >= 1 ? "Body-mass change" : "Body trend in range" } ?? "Body trend in range",
                summary: summary,
                metricKey: baseline == nil && requestedChange == nil ? "body_mass_samples_7d" : "body_mass_28d_avg_kg",
                metricCategory: "body_composition",
                direction: direction,
                targetValue: targetValue,
                unit: baseline == nil && requestedChange == nil ? "samples" : "kg",
                displayValueOverride: displayValue
            )
        }

        private static func concreteGoalTargets(in goal: AthleteBlueprintGoal) -> [FitnessStrategyAIConcreteTarget] {
            FitnessStrategyAITargetBrief.concreteTargets(in: goal.displayText)
        }

        private static func concreteGoalTarget(in goal: AthleteBlueprintGoal, modality: String) -> FitnessStrategyAIConcreteTarget? {
            concreteGoalTargets(in: goal).first { $0.modality == modality }
        }

        private static func goalSignalTarget(
            intent: OnboardingIntent,
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?
        ) -> FitnessStrategyTarget {
            for option in preferredTrainingOptions(from: draft) {
                switch option {
                case .running:
                    return runningPerformanceTarget(goal: goal, draft: draft, snapshot: snapshot)
                case .swimming:
                    return swimmingPerformanceTarget(goal: goal, draft: draft, snapshot: snapshot)
                case .cycling:
                    return cyclingPerformanceTarget(goal: goal, draft: draft, snapshot: snapshot)
                case .strength:
                    return strengthExposureTarget(goal: goal, draft: draft)
                default:
                    continue
                }
            }

            if goal.displayText.lowercased().contains("swim") {
                return swimmingPerformanceTarget(goal: goal, draft: draft, snapshot: snapshot)
            }

            if goal.displayText.lowercased().contains("run") {
                return runningPerformanceTarget(goal: goal, draft: draft, snapshot: snapshot)
            }

            if goal.displayText.lowercased().contains("cycl") {
                return cyclingPerformanceTarget(goal: goal, draft: draft, snapshot: snapshot)
            }

            if goal.category == .strength && !draft.goalAvoidances.contains(.heavyLifting) && !draft.goalAvoidances.contains(.gymDependence) {
                return strengthExposureTarget(goal: goal, draft: draft)
            }

            let aerobicMinutes = weeklyAerobicMinutes(from: draft)
            return FitnessStrategyTarget(
                id: "aerobic_base_minutes",
                scope: .strategy,
                kind: .supporting,
                title: "\(aerobicMinutes) aerobic minutes",
                summary: "Hold a measurable aerobic dose each week so the strategy has a real fitness signal, even if the goal is broad.",
                metricKey: "aerobic_minutes_7d",
                metricCategory: "endurance",
                direction: .maintain,
                targetValue: Double(aerobicMinutes),
                unit: "min"
            )
        }

        private static func strengthExposureTarget(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft
        ) -> FitnessStrategyTarget {
            let sessions = draft.frequency == .two ? 2 : 3
            return FitnessStrategyTarget(
                id: "strength_exposure",
                scope: .strategy,
                kind: .supporting,
                title: "\(sessions) strength exposures",
                summary: "Protect enough recurring strength work for \(goal.displayText) to become trainable without letting unrelated training crowd it out.",
                metricKey: "strength_sessions_7d",
                metricCategory: "strength",
                direction: .maintain,
                targetValue: Double(sessions),
                unit: "sessions"
            )
        }

        private static func performanceSignalTarget(
            id: String,
            modality: String,
            title: String,
            goal: AthleteBlueprintGoal
        ) -> FitnessStrategyTarget {
            if let concreteTarget = concreteGoalTarget(in: goal, modality: modality) {
                return FitnessStrategyTarget(
                    id: id,
                    scope: .strategy,
                    kind: .supporting,
                    title: concreteTarget.title,
                    summary: "By the end of the strategy, HAYF should be able to track this directly from imported \(modality) performance data.",
                    metricKey: concreteTarget.metric,
                    metricCategory: "\(modality)_performance",
                    direction: concreteTarget.direction == "decrease" ? .decrease : .increase,
                    targetValue: concreteTarget.targetValue,
                    unit: concreteTarget.unit,
                    displayValueOverride: concreteTarget.displayValue
                )
            }

            return FitnessStrategyTarget(
                id: id,
                scope: .strategy,
                kind: .supporting,
                title: "\(modality.capitalized) result captured",
                summary: "By the end of the strategy, HAYF should have one comparable imported \(modality) result.",
                metricKey: "\(modality)_result_count_strategy",
                metricCategory: "\(modality)_speed",
                direction: .increase,
                targetValue: 1,
                unit: "result",
                displayValueOverride: "1 result"
            )
        }

        private static func cyclingPerformanceTarget(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?
        ) -> FitnessStrategyTarget {
            if isSpeedGoal(goal) {
                return performanceSignalTarget(
                    id: "cycling_goal_signal",
                    modality: "cycling",
                    title: "Cycling performance signal reviewed",
                    goal: goal
                )
            }

            let longestRide = longestWorkout(containing: "cycling", snapshot: snapshot)
            let targetDistance = longestRide?.distanceKilometers.map { capstoneDistance(from: $0, completedAt: longestRide?.workoutDate) }
            let fallbackMinutes = weeklyAerobicMinutes(from: draft)

            return FitnessStrategyTarget(
                id: "cycling_goal_signal",
                scope: .strategy,
                kind: .supporting,
                title: targetDistance.map { "Capstone ride: \(Int($0)) km" } ?? "\(fallbackMinutes) cycling minutes",
                summary: targetDistance.map { distance in
                    let history = longestRide.map { " Your longest comparable ride is \(Int(($0.distanceKilometers ?? 0).rounded())) km from \(relativeAgeDescription(for: $0.workoutDate))." } ?? ""
                    return "Use one controlled ride as proof that the strategy is working.\(history) It is one success signal inside the broader build, not the whole strategy."
                } ?? "Use recurring cycling exposure as the first measurable signal before HAYF asks for harder bike work.",
                metricKey: targetDistance == nil ? "cycling_minutes_7d" : "longest_cycling_distance_km",
                metricCategory: "cycling",
                direction: .increase,
                targetValue: targetDistance ?? Double(fallbackMinutes),
                unit: targetDistance == nil ? "min" : "km"
            )
        }

        private static func runningPerformanceTarget(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?
        ) -> FitnessStrategyTarget {
            if isSpeedGoal(goal) {
                let label = goalDistanceLabel(in: goal.displayText).map { "\($0) speed signal reviewed" } ?? "Running speed signal reviewed"
                return performanceSignalTarget(
                    id: "running_goal_signal",
                    modality: "running",
                    title: label,
                    goal: goal
                )
            }

            let longestRun = longestWorkout(containing: "running", snapshot: snapshot)
            let targetDistance = longestRun?.distanceKilometers.map { capstoneDistance(from: $0, completedAt: longestRun?.workoutDate) }
            let fallbackMinutes = weeklyAerobicMinutes(from: draft)

            return FitnessStrategyTarget(
                id: "running_goal_signal",
                scope: .strategy,
                kind: .supporting,
                title: targetDistance.map { "Capstone run: \(Int($0)) km" } ?? "\(fallbackMinutes) running minutes",
                summary: targetDistance.map { distance in
                    let history = longestRun.map { " Your longest comparable run is \(Int(($0.distanceKilometers ?? 0).rounded())) km from \(relativeAgeDescription(for: $0.workoutDate))." } ?? ""
                    return "Use one controlled run as proof that the strategy is working.\(history) It is one success signal inside the broader build, not the whole strategy."
                } ?? "Use recurring run exposure as the first measurable signal before HAYF asks for harder running.",
                metricKey: targetDistance == nil ? "running_minutes_7d" : "longest_running_distance_km",
                metricCategory: "running",
                direction: .increase,
                targetValue: targetDistance ?? Double(fallbackMinutes),
                unit: targetDistance == nil ? "min" : "km"
            )
        }

        private static func swimmingPerformanceTarget(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?
        ) -> FitnessStrategyTarget {
            if isSpeedGoal(goal) {
                return performanceSignalTarget(
                    id: "swimming_goal_signal",
                    modality: "swimming",
                    title: "Swimming performance signal reviewed",
                    goal: goal
                )
            }

            let longestSwim = longestWorkout(containing: "swimming", snapshot: snapshot)
            let targetMinutes = longestSwim.map {
                max(sessionMinutes(from: draft.sessionLength), Int(($0.durationMinutes * 1.1).rounded()))
            } ?? weeklyAerobicMinutes(from: draft)

            return FitnessStrategyTarget(
                id: "swimming_goal_signal",
                scope: .strategy,
                kind: .supporting,
                title: "\(targetMinutes) swimming min",
                summary: "Use a controlled swim duration as one proof signal for \(goal.displayText.lowercased()), sized from your chosen training path and available session length.",
                metricKey: "swimming_minutes_strategy",
                metricCategory: "swimming",
                direction: .increase,
                targetValue: Double(targetMinutes),
                unit: "min"
            )
        }

        private static func strategyRhythmTarget(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?
        ) -> FitnessStrategyTarget {
            let weeklySessions = targetWeeklySessions(from: draft.frequency)
            let strongWeeks = targetStrongWeeks(from: weeklySessions, horizonWeeks: goal.horizonWeeks, snapshot: snapshot)
            return FitnessStrategyTarget(
                id: "strategy_rhythm_held",
                scope: .strategy,
                kind: .supporting,
                title: "\(strongWeeks) of \(goal.horizonWeeks) rhythm weeks",
                summary: "By the end of the strategy, complete \(strongWeeks) of \(goal.horizonWeeks) weeks where the planned \(weeklySessions)-exposure rhythm holds. This keeps progress from depending on one heroic week.",
                metricKey: "weeks_with_min_sessions_strategy",
                metricCategory: "consistency",
                direction: .increase,
                targetValue: Double(strongWeeks),
                unit: "weeks",
                displayValueOverride: "\(strongWeeks) of \(goal.horizonWeeks)"
            )
        }

        private static func strategyAnchorTarget(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            blueprint: AthleteBlueprintOutput
        ) -> FitnessStrategyTarget {
            let preferredOptions = preferredTrainingOptions(from: draft)
            let anchorTitle = trainingAnchorDisplayTitle(for: preferredOptions)
            let requiredModalities = max(1, preferredOptions.prefix(2).count)
            let metricKey = preferredOptions.isEmpty ? "anchor_sessions_7d" : "chosen_training_modalities_present_7d"
            let displayValue = preferredOptions.count > 1 ? "1 each/week" : "1/week"
            let summary = preferredOptions.isEmpty
                ? "By the end of the strategy, keep at least one supporting training exposure visible in normal weeks."
                : "By the end of the strategy, keep at least one \(trainingAnchorLabel(for: preferredOptions)) exposure visible in normal weeks."

            return FitnessStrategyTarget(
                id: "strategy_anchor_preserved",
                scope: .strategy,
                kind: .supporting,
                title: "\(anchorTitle) stays visible",
                summary: summary,
                metricKey: metricKey,
                metricCategory: "training_balance",
                direction: .maintain,
                targetValue: Double(requiredModalities),
                unit: preferredOptions.count > 1 ? "modalities" : "session",
                displayValueOverride: displayValue
            )
        }

        static func phaseTargets(
            phaseID: String,
            phaseName: String,
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?
        ) -> [FitnessStrategyTarget] {
            let weeklySessions = targetWeeklySessions(from: draft.frequency)
            let aerobicMinutes = weeklyAerobicMinutes(from: draft)
            let phaseLabel = phaseName.lowercased()
            let preferredOptions = preferredTrainingOptions(from: draft)
            let supportTitle = preferredOptions.isEmpty ? "Support exposure protected" : "Chosen path protected"
            let supportSummary = preferredOptions.isEmpty
                ? "Finish the phase with at least one supporting exposure still present in normal weeks."
                : "Finish the phase with at least one \(trainingAnchorLabel(for: preferredOptions)) exposure present in normal weeks."
            let supportMetricKey = preferredOptions.isEmpty ? "support_sessions_7d" : "chosen_training_modalities_present_7d"
            let supportDisplayValue = preferredOptions.count > 1 ? "1 each/week" : "1/week"
            let supportTargetValue = Double(max(1, preferredOptions.prefix(2).count))

            switch phaseID {
            case "base":
                return [
                    FitnessStrategyTarget(
                        id: "\(phaseID)_repeatable_weeks",
                        scope: .phase,
                        kind: .supporting,
                        title: "3 repeatable weeks",
                        summary: "The \(phaseLabel) phase proves the weekly structure can hold before HAYF asks for more.",
                        metricKey: "phase_weeks_with_min_sessions",
                        metricCategory: "consistency",
                        direction: .increase,
                        targetValue: 3,
                        unit: "weeks"
                    ),
                    FitnessStrategyTarget(
                        id: "\(phaseID)_weekly_exposures",
                        scope: .phase,
                        kind: .supporting,
                        title: "\(weeklySessions) exposures held",
                        summary: "Keep the minimum training rhythm visible across the phase.",
                        metricKey: "planned_sessions_7d",
                        metricCategory: "consistency",
                        direction: .maintain,
                        targetValue: Double(weeklySessions),
                        unit: "sessions"
                    ),
                    FitnessStrategyTarget(
                        id: "\(phaseID)_floor_used",
                        scope: .phase,
                        kind: .supporting,
                        title: "0 skipped weeks",
                        summary: "Finish the phase without losing a full planned training week.",
                        metricKey: "skipped_weeks_phase",
                        metricCategory: "adherence",
                        direction: .decrease,
                        targetValue: 0,
                        unit: "weeks",
                        displayValueOverride: "0 skips"
                    )
                ]
            case "build":
                return [
                    FitnessStrategyTarget(
                        id: "\(phaseID)_goal_signal_progress",
                        scope: .phase,
                        kind: .supporting,
                        title: phaseGoalSignalTitle(goal: goal, draft: draft, snapshot: snapshot, fallbackMinutes: aerobicMinutes),
                        summary: "Progress the clearest measurable signal for \(goal.displayText.lowercased()) without making every session harder.",
                        metricKey: phaseGoalSignalMetricKey(goal: goal, draft: draft),
                        metricCategory: phaseGoalSignalCategory(goal: goal, draft: draft),
                        direction: .increase,
                        targetValue: phaseGoalSignalValue(goal: goal, draft: draft, snapshot: snapshot, fallbackMinutes: aerobicMinutes),
                        unit: phaseGoalSignalUnit(goal: goal, draft: draft),
                        displayValueOverride: phaseGoalSignalDisplayValue(goal: goal, draft: draft)
                    ),
                    FitnessStrategyTarget(
                        id: "\(phaseID)_anchor_session",
                        scope: .phase,
                        kind: .supporting,
                        title: supportTitle,
                        summary: supportSummary,
                        metricKey: supportMetricKey,
                        metricCategory: "training_balance",
                        direction: .maintain,
                        targetValue: supportTargetValue,
                        unit: preferredOptions.count > 1 ? "modalities" : "session",
                        displayValueOverride: supportDisplayValue
                    ),
                    FitnessStrategyTarget(
                        id: "\(phaseID)_recovery_gap",
                        scope: .phase,
                        kind: .supporting,
                        title: "No long drop-offs",
                        summary: "Keep the gap between useful exposures short enough that momentum does not reset.",
                        metricKey: "max_gap_days_phase",
                        metricCategory: "consistency",
                        direction: .decrease,
                        targetValue: 7,
                        unit: "days"
                    )
                ]
            default:
                return [
                    FitnessStrategyTarget(
                        id: "\(phaseID)_goal_check",
                        scope: .phase,
                        kind: .supporting,
                        title: reviewGoalTargetTitle(goal: goal),
                        summary: "Finish the phase with a measurable imported result tied to the goal.",
                        metricKey: reviewGoalMetricKey(goal: goal),
                        metricCategory: reviewGoalMetricCategory(goal: goal),
                        direction: reviewGoalDirection(goal: goal),
                        targetValue: reviewGoalValue(goal: goal),
                        unit: reviewGoalUnit(goal: goal),
                        displayValueOverride: reviewGoalDisplayValue(goal: goal)
                    ),
                    FitnessStrategyTarget(
                        id: "\(phaseID)_rhythm_preserved",
                        scope: .phase,
                        kind: .supporting,
                        title: "Rhythm preserved",
                        summary: "Finish the phase with the weekly training rhythm still intact.",
                        metricKey: "phase_weeks_with_min_sessions",
                        metricCategory: "consistency",
                        direction: .increase,
                        targetValue: 2,
                        unit: "weeks"
                    ),
                    FitnessStrategyTarget(
                        id: "\(phaseID)_next_move",
                        scope: .phase,
                        kind: .supporting,
                        title: "No late drop-offs",
                        summary: "Keep the final gap between useful exposures short enough that the strategy finishes with momentum.",
                        metricKey: "max_gap_days_phase",
                        metricCategory: "consistency",
                        direction: .decrease,
                        targetValue: 7,
                        unit: "days"
                    )
                ]
            }
        }

        private static func reviewGoalTargetTitle(goal: AthleteBlueprintGoal) -> String {
            if let concreteTarget = concreteGoalTargets(in: goal).first {
                return concreteTarget.title
            }
            return "Goal result captured"
        }

        private static func reviewGoalMetricKey(goal: AthleteBlueprintGoal) -> String {
            concreteGoalTargets(in: goal).first?.metric ?? "goal_result_count_phase"
        }

        private static func reviewGoalMetricCategory(goal: AthleteBlueprintGoal) -> String {
            if let modality = concreteGoalTargets(in: goal).first?.modality {
                return "\(modality)_performance"
            }
            return goal.category.rawValue
        }

        private static func reviewGoalDirection(goal: AthleteBlueprintGoal) -> FitnessStrategyTargetDirection {
            concreteGoalTargets(in: goal).first?.direction == "decrease" ? .decrease : .increase
        }

        private static func reviewGoalValue(goal: AthleteBlueprintGoal) -> Double {
            concreteGoalTargets(in: goal).first?.targetValue ?? 1
        }

        private static func reviewGoalUnit(goal: AthleteBlueprintGoal) -> String {
            concreteGoalTargets(in: goal).first?.unit ?? "result"
        }

        private static func reviewGoalDisplayValue(goal: AthleteBlueprintGoal) -> String {
            concreteGoalTargets(in: goal).first?.displayValue ?? "1 result"
        }

        private static func phaseGoalSignalTitle(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?,
            fallbackMinutes: Int
        ) -> String {
            let preferredOption = preferredTrainingOptions(from: draft).first
            if preferredOption == .running || (preferredOption == nil && goal.displayText.lowercased().contains("run")) {
                if isSpeedGoal(goal) {
                    return concreteGoalTarget(in: goal, modality: "running")?.title ?? "Running result"
                }
                return "\(Int(phaseGoalSignalValue(goal: goal, draft: draft, snapshot: snapshot, fallbackMinutes: fallbackMinutes).rounded())) running min"
            }
            if preferredOption == .swimming || (preferredOption == nil && goal.displayText.lowercased().contains("swim")) {
                if isSpeedGoal(goal) {
                    return concreteGoalTarget(in: goal, modality: "swimming")?.title ?? "Swimming result"
                }
                return "\(Int(phaseGoalSignalValue(goal: goal, draft: draft, snapshot: snapshot, fallbackMinutes: fallbackMinutes).rounded())) swimming min"
            }
            if preferredOption == .cycling || (preferredOption == nil && goal.displayText.lowercased().contains("cycl")) {
                if isSpeedGoal(goal) {
                    return concreteGoalTarget(in: goal, modality: "cycling")?.title ?? "Cycling result"
                }
                return "\(Int(phaseGoalSignalValue(goal: goal, draft: draft, snapshot: snapshot, fallbackMinutes: fallbackMinutes).rounded())) cycling min"
            }
            if preferredOption == .strength || (goal.category == .strength && !draft.goalAvoidances.contains(.heavyLifting) && !draft.goalAvoidances.contains(.gymDependence)) {
                return "Strength progressed"
            }
            if goal.category == .bodyComposition || containsBodyCompositionLanguage(goal.displayText) {
                return "Body trend held"
            }
            return "\(fallbackMinutes) training min"
        }

        private static func phaseGoalSignalMetricKey(goal: AthleteBlueprintGoal, draft: ConsistencyOnboardingDraft) -> String? {
            let preferredOption = preferredTrainingOptions(from: draft).first
            if preferredOption == .running || (preferredOption == nil && goal.displayText.lowercased().contains("run")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "running")?.metric ?? "running_result_count_phase" }
                return "running_minutes_phase"
            }
            if preferredOption == .swimming || (preferredOption == nil && goal.displayText.lowercased().contains("swim")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "swimming")?.metric ?? "swimming_result_count_phase" }
                return "swimming_minutes_phase"
            }
            if preferredOption == .cycling || (preferredOption == nil && goal.displayText.lowercased().contains("cycl")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "cycling")?.metric ?? "cycling_result_count_phase" }
                return "cycling_minutes_phase"
            }
            if preferredOption == .strength || (goal.category == .strength && !draft.goalAvoidances.contains(.heavyLifting) && !draft.goalAvoidances.contains(.gymDependence)) {
                return "strength_result_count_phase"
            }
            if goal.category == .bodyComposition || containsBodyCompositionLanguage(goal.displayText) {
                return "body_mass_28d_avg_kg"
            }
            return "training_minutes_phase"
        }

        private static func phaseGoalSignalCategory(goal: AthleteBlueprintGoal, draft: ConsistencyOnboardingDraft) -> String {
            let preferredOption = preferredTrainingOptions(from: draft).first
            if preferredOption == .running || (preferredOption == nil && goal.displayText.lowercased().contains("run")) {
                if isSpeedGoal(goal) { return "running_speed" }
                return "running"
            }
            if preferredOption == .swimming || (preferredOption == nil && goal.displayText.lowercased().contains("swim")) {
                if isSpeedGoal(goal) { return "swimming_speed" }
                return "swimming"
            }
            if preferredOption == .cycling || (preferredOption == nil && goal.displayText.lowercased().contains("cycl")) {
                if isSpeedGoal(goal) { return "cycling_speed" }
                return "cycling"
            }
            if preferredOption == .strength || (goal.category == .strength && !draft.goalAvoidances.contains(.heavyLifting) && !draft.goalAvoidances.contains(.gymDependence)) {
                return "strength"
            }
            if goal.category == .bodyComposition || containsBodyCompositionLanguage(goal.displayText) {
                return "body_composition"
            }
            return goal.category.rawValue
        }

        private static func phaseGoalSignalValue(
            goal: AthleteBlueprintGoal,
            draft: ConsistencyOnboardingDraft,
            snapshot: HealthFeatureSnapshot?,
            fallbackMinutes: Int
        ) -> Double {
            let preferredOption = preferredTrainingOptions(from: draft).first
            if preferredOption == .running || (preferredOption == nil && goal.displayText.lowercased().contains("run")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "running")?.targetValue ?? 1 }
                return Double(max(fallbackMinutes, Int(Double(fallbackMinutes) * 1.2)))
            }
            if preferredOption == .swimming || (preferredOption == nil && goal.displayText.lowercased().contains("swim")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "swimming")?.targetValue ?? 1 }
                return Double(max(sessionMinutes(from: draft.sessionLength), Int(Double(fallbackMinutes) * 1.1)))
            }
            if preferredOption == .cycling || (preferredOption == nil && goal.displayText.lowercased().contains("cycl")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "cycling")?.targetValue ?? 1 }
                return Double(max(fallbackMinutes, Int(Double(fallbackMinutes) * 1.25)))
            }
            if preferredOption == .strength || (goal.category == .strength && !draft.goalAvoidances.contains(.heavyLifting) && !draft.goalAvoidances.contains(.gymDependence)) {
                return 1
            }
            if goal.category == .bodyComposition || containsBodyCompositionLanguage(goal.displayText) {
                return 1
            }
            return Double(fallbackMinutes)
        }

        private static func phaseGoalSignalUnit(goal: AthleteBlueprintGoal, draft: ConsistencyOnboardingDraft) -> String? {
            let preferredOption = preferredTrainingOptions(from: draft).first
            if preferredOption == .running || (preferredOption == nil && goal.displayText.lowercased().contains("run")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "running")?.unit ?? "result" }
                return "min"
            }
            if preferredOption == .swimming || (preferredOption == nil && goal.displayText.lowercased().contains("swim")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "swimming")?.unit ?? "result" }
                return "min"
            }
            if preferredOption == .cycling || (preferredOption == nil && goal.displayText.lowercased().contains("cycl")) {
                if isSpeedGoal(goal) { return concreteGoalTarget(in: goal, modality: "cycling")?.unit ?? "result" }
                return "min"
            }
            if preferredOption == .strength || (goal.category == .strength && !draft.goalAvoidances.contains(.heavyLifting) && !draft.goalAvoidances.contains(.gymDependence)) {
                return "result"
            }
            if goal.category == .bodyComposition || containsBodyCompositionLanguage(goal.displayText) {
                return nil
            }
            return "min"
        }

        private static func phaseGoalSignalDisplayValue(goal: AthleteBlueprintGoal, draft: ConsistencyOnboardingDraft) -> String? {
            let preferredOption = preferredTrainingOptions(from: draft).first
            if isSpeedGoal(goal), preferredOption == .running {
                return concreteGoalTarget(in: goal, modality: "running")?.displayValue ?? "1 result"
            }
            if isSpeedGoal(goal), preferredOption == .swimming {
                return concreteGoalTarget(in: goal, modality: "swimming")?.displayValue ?? "1 result"
            }
            if isSpeedGoal(goal), preferredOption == .cycling {
                return concreteGoalTarget(in: goal, modality: "cycling")?.displayValue ?? "1 result"
            }
            if preferredOption == .strength || (goal.category == .strength && !draft.goalAvoidances.contains(.heavyLifting) && !draft.goalAvoidances.contains(.gymDependence)) {
                return "1 result"
            }
            if preferredOption == nil && (goal.category == .bodyComposition || containsBodyCompositionLanguage(goal.displayText)) {
                return "±1 kg"
            }
            return nil
        }

        static func targetWeeklySessions(from frequency: TrainingFrequency?) -> Int {
            switch frequency {
            case .two: return 2
            case .three: return 3
            case .four: return 4
            case .fivePlus: return 5
            case .changes, nil: return 3
            }
        }

        private static func targetStrongWeeks(from weeklySessions: Int, horizonWeeks: Int, snapshot: HealthFeatureSnapshot?) -> Int {
            let minimumRatio = weeklySessions >= 5 ? 0.6 : 0.7
            let base = max(1, Int((Double(horizonWeeks) * minimumRatio).rounded()))
            return min(horizonWeeks, base)
        }

        private static func isSpeedGoal(_ goal: AthleteBlueprintGoal) -> Bool {
            let text = goal.displayText.lowercased()
            return text.contains("pace")
                || text.contains("speed")
                || text.contains("faster")
                || text.contains("race pace")
                || text.contains("pr")
                || text.contains("time")
        }

        private static func goalDistanceLabel(in text: String) -> String? {
            let lowercased = text.lowercased()
            if lowercased.contains("5k") { return "5K" }
            if lowercased.contains("10k") { return "10K" }
            if lowercased.contains("half marathon") { return "half marathon" }
            if lowercased.contains("marathon") { return "marathon" }

            let pattern = #"(\d+(?:[\.,]\d+)?)\s*(?:k|km|kilometer|kilometers)\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
                  let range = Range(match.range(at: 1), in: lowercased) else {
                return nil
            }
            let value = lowercased[range].replacingOccurrences(of: ",", with: ".")
            return value.hasSuffix(".0") ? "\(Int(Double(value) ?? 0))K" : "\(value)K"
        }

        private static func weeklyAerobicMinutes(from draft: ConsistencyOnboardingDraft) -> Int {
            let sessions = targetWeeklySessions(from: draft.frequency)
            let minutes = sessionMinutes(from: draft.sessionLength)
            return max(60, sessions * minutes)
        }

        private static func sessionMinutes(from length: SessionLength?) -> Int {
            switch length {
            case .twenty: return 20
            case .thirty: return 30
            case .fortyFive: return 45
            case .sixtyPlus: return 60
            case .varies, nil: return 35
            }
        }

        private static func longestWorkout(containing modality: String, snapshot: HealthFeatureSnapshot?) -> FitnessLongestWorkoutSummary? {
            snapshot?.fitnessHistory.performance.longestWorkoutsByModality.first {
                $0.modality.lowercased().contains(modality)
            }
        }

        private static func capstoneDistance(from longestDistance: Double, completedAt date: Date?) -> Double {
            let ageDays = date.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 999
            let multiplier: Double
            switch ageDays {
            case ..<180:
                multiplier = 1.15
            case ..<365:
                multiplier = 1.10
            default:
                multiplier = 1.05
            }

            let rawTarget = longestDistance * multiplier
            let roundedToFive = (rawTarget / 5).rounded() * 5
            return max(longestDistance.rounded(), roundedToFive)
        }

        private static func relativeAgeDescription(for date: Date) -> String {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            if days < 60 {
                return "the last two months"
            }
            if days < 365 {
                return "\(max(2, Int((Double(days) / 30).rounded()))) months ago"
            }
            return "\(max(1, Int((Double(days) / 365).rounded()))) years ago"
        }

        private static func requestedKilogramChange(in text: String) -> Double? {
            let lowercased = text.lowercased()
            guard containsBodyCompositionLanguage(lowercased) else { return nil }
            let pattern = #"(\d+(?:[\.,]\d+)?)\s*(?:kg|kgs|kilogram|kilograms)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
                  let range = Range(match.range(at: 1), in: lowercased) else {
                return nil
            }

            let value = Double(lowercased[range].replacingOccurrences(of: ",", with: ".")) ?? 0
            let wantsGain = lowercased.contains("gain") || lowercased.contains("add") || lowercased.contains("build")
            return wantsGain ? value : -value
        }

        private static func containsBodyCompositionLanguage(_ text: String) -> Bool {
            let lowercased = text.lowercased()
            if ["body fat", "body composition", "weight", "kg", "kilogram", "lean mass", "gain mass"].contains(where: { lowercased.contains($0) }) {
                return true
            }
            let bodyContext = lowercased.contains("body") || lowercased.contains("fat") || lowercased.contains("mass") || lowercased.contains("weight")
            let changeLanguage = lowercased.contains("drop") || lowercased.contains("lose") || lowercased.contains("loss") || lowercased.contains("cut")
            return bodyContext && changeLanguage
        }

        private static func deduplicated(_ targets: [FitnessStrategyTarget]) -> [FitnessStrategyTarget] {
            var seen = Set<String>()
            return targets.filter { target in
                guard !seen.contains(target.id) else { return false }
                seen.insert(target.id)
                return true
            }
        }
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}

private struct AthleteBlueprintOutput {
    let coachRead: AthleteBlueprintCoachRead
    let archetype: AthleteBlueprintArchetype
    let currentTrainingState: AthleteBlueprintCurrentState
    let physicalBaseline: AthleteBlueprintPhysicalBaseline
    let historyFindings: [AthleteBlueprintFinding]
    let goalFit: AthleteBlueprintGoalFit
}

private struct AthleteBlueprintCoachRead {
    let preview: String
    let text: String
    let detail: AthleteBlueprintDetail
}

private struct AthleteBlueprintArchetype {
    let label: String
    let explanation: String
    let detail: AthleteBlueprintDetail
}

private struct AthleteBlueprintCurrentState {
    let label: String
    let summary: String
    let detail: AthleteBlueprintDetail
}

private struct AthleteBlueprintPhysicalBaseline {
    let label: String
    let summary: String
    let detail: AthleteBlueprintDetail
}

private struct AthleteBlueprintFinding: Identifiable {
    let id: String
    let title: String
    let summary: String
    let detail: AthleteBlueprintDetail
}

private struct AthleteBlueprintGoalFit {
    let headline: String
    let summary: String
    let supports: [String]
    let gaps: [String]
    let detail: AthleteBlueprintDetail
}

private struct AthleteBlueprintDetail: Identifiable {
    let id: String
    let title: String
    let summary: String
    let body: String?
    let confidence: String
    let observationWindow: String
    let evidence: [String]
    let caveat: String?

    init(
        id: String,
        title: String,
        summary: String,
        body: String? = nil,
        confidence: String,
        observationWindow: String,
        evidence: [String],
        caveat: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.body = body
        self.confidence = confidence
        self.observationWindow = observationWindow
        self.evidence = evidence
        self.caveat = caveat
    }
}

private extension AthleteBlueprintDetail {
    func withBody(_ body: String) -> AthleteBlueprintDetail {
        AthleteBlueprintDetail(
            id: id,
            title: title,
            summary: summary,
            body: body.trimmed.nilIfEmpty,
            confidence: confidence,
            observationWindow: observationWindow,
            evidence: evidence,
            caveat: caveat
        )
    }

    var rankedEvidence: [String] {
        evidence
            .enumerated()
            .sorted { lhs, rhs in
                let lhsScore = evidencePriority(lhs.element)
                let rhsScore = evidencePriority(rhs.element)
                return lhsScore == rhsScore ? lhs.offset < rhs.offset : lhsScore < rhsScore
            }
            .prefix(3)
            .map(\.element)
    }

    func evidencePriority(_ item: String) -> Int {
        let lowercased = item.lowercased()

        switch id {
        case "coach_read":
            if lowercased.contains("dominant modalities") { return 0 }
            if lowercased.contains("last 7 days") || lowercased.contains("typical recent week") { return 1 }
            if lowercased.contains("selected") || lowercased.contains("goal horizon") { return 2 }
        case "athlete_archetype":
            if lowercased.contains("dominant modalities") { return 0 }
            if lowercased.contains("imported workouts") { return 1 }
            if lowercased.contains("body-mass change") { return 2 }
        case "current_training_state":
            if lowercased.contains("last 7 days") { return 0 }
            if lowercased.contains("typical recent week") || lowercased.contains("last 90 days") { return 1 }
        case "physical_baseline":
            if lowercased.contains("body mass") || lowercased.contains("weight") { return 0 }
            if lowercased.contains("height") { return 1 }
            if lowercased.contains("body-fat") || lowercased.contains("body fat") { return 2 }
        case "body_mass_trend":
            if lowercased.contains("change") { return 0 }
            if lowercased.contains("window") { return 1 }
            if lowercased.contains("samples") { return 2 }
        case "goal_fit":
            if lowercased.contains("selected") { return 0 }
            if lowercased.contains("goal horizon") { return 1 }
            if lowercased.contains("does not") || lowercased.contains("no selected") { return 2 }
        default:
            break
        }

        return 10
    }
}

private enum AthleteBlueprintBuilder {
    static func build(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        snapshot: HealthFeatureSnapshot?
    ) -> AthleteBlueprintOutput {
        let evidence = AthleteBlueprintEvidence(snapshot: snapshot)
        let goal = normalizedGoal(intent: intent, draft: draft)
        let archetype = buildArchetype(intent: intent, draft: draft, evidence: evidence)
        let currentState = buildCurrentState(evidence: evidence)
        let physicalBaseline = buildPhysicalBaseline(draft: draft, evidence: evidence)
        let historyFindings = buildHistoryFindings(evidence: evidence)
        let goalFit = buildGoalFit(goal: goal, draft: draft, evidence: evidence)
        let coachRead = buildCoachRead(
            archetype: archetype,
            currentState: currentState,
            physicalBaseline: physicalBaseline,
            goalFit: goalFit,
            evidence: evidence
        )

        return AthleteBlueprintOutput(
            coachRead: coachRead,
            archetype: archetype,
            currentTrainingState: currentState,
            physicalBaseline: physicalBaseline,
            historyFindings: historyFindings,
            goalFit: goalFit
        )
    }

    static func normalizedGoal(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) -> AthleteBlueprintGoal {
        switch intent {
        case .stayConsistent:
            return AthleteBlueprintGoal(
                displayText: "build a consistent training rhythm",
                horizonWeeks: 12,
                category: .consistency
            )
        case .concreteGoal:
            return AthleteBlueprintGoal(
                displayText: normalizedGoalDisplayText(from: draft.goalSummary),
                horizonWeeks: goalHorizonWeeks(from: draft.goalTimeline, goalDate: draft.goalDate),
                category: category(for: draft.goalSummary)
            )
        case .findGoal:
            return AthleteBlueprintGoal(
                displayText: normalizedGoalDisplayText(from: draft.goalSummary),
                horizonWeeks: draft.chosenGoal?.timeline.weeks ?? goalHorizonWeeks(from: draft.goalTimeline, goalDate: draft.goalDate),
                category: category(for: draft.goalSummary)
            )
        }
    }

    private static func buildCoachRead(
        archetype: AthleteBlueprintArchetype,
        currentState: AthleteBlueprintCurrentState,
        physicalBaseline: AthleteBlueprintPhysicalBaseline,
        goalFit: AthleteBlueprintGoalFit,
        evidence: AthleteBlueprintEvidence
    ) -> AthleteBlueprintCoachRead {
        let text: String
        let preview: String
        let headline: String
        if evidence.hasWorkoutHistory {
            var lines = [
                archetype.explanation,
                currentState.summary
            ]
            if let bodyLine = evidence.bodyMemoryCoachLine,
               !archetype.explanation.contains(bodyLine) {
                lines.append(bodyLine)
            } else if evidence.bodyMemoryCoachLine == nil {
                lines.append(physicalBaseline.summary)
            }
            lines.append(goalFit.summary)
            let sentences = uniqueSentences(from: lines)
            text = sentences.joined(separator: " ")
            preview = sentences
                .prefixArray(2)
                .joined(separator: " ")
                .limitedSentences(maxSentences: 2, maxCharacters: 190)
            headline = "You have a steady base to build from."
        } else {
            text = "HAYF has a clear picture of what you want from training, but not enough Apple Health history yet to make strong claims about your past patterns. For now, the read leans on what you told us and will sharpen as you train."
            preview = "HAYF has enough from your answers to build a first strategy. The read will sharpen as you train."
            headline = "We have enough to start."
        }

        return AthleteBlueprintCoachRead(
            preview: preview,
            text: text,
                detail: AthleteBlueprintDetail(
                    id: "coach_read",
                    title: "Coach's read",
                    summary: headline,
                    body: text,
                    confidence: evidence.hasWorkoutHistory ? "High" : "Provisional",
                    observationWindow: evidence.hasWorkoutHistory ? "Onboarding + imported workout history" : "Onboarding only",
                    evidence: evidence.hasWorkoutHistory
                    ? archetype.detail.evidence
                        + currentState.detail.evidence
                        + goalFit.supports
                    : [
                        "You completed the onboarding profile.",
                        "Apple Health history was not available in enough depth for a stronger read yet."
                    ],
                caveat: evidence.hasWorkoutHistory ? nil : "HAYF will refine this after it has more real training evidence."
            )
        )
    }

    private static func buildArchetype(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        evidence: AthleteBlueprintEvidence
    ) -> AthleteBlueprintArchetype {
        if let label = evidence.trainingIdentityLabel, !evidence.dominantModalities.isEmpty {
            let baseLabel: String
            switch label {
            case "Hybrid athlete":
                baseLabel = "Hybrid Athlete"
            case "Strength-led":
                baseLabel = "Strength-Led Athlete"
            case "Endurance-led":
                baseLabel = "Endurance-Led Athlete"
            default:
                baseLabel = titleCase(label)
            }

            let friendlyLabel = evidence.bodyMemoryArchetypePrefix.map { "\($0) \(baseLabel)" } ?? baseLabel
            let explanation = "Your history is led by \(joinedList(evidence.dominantModalities)), which makes you a \(baseLabel.lowercased())."
            return AthleteBlueprintArchetype(
                label: friendlyLabel,
                explanation: explanation,
                detail: AthleteBlueprintDetail(
                    id: "athlete_archetype",
                    title: "Athlete type",
                    summary: "Your repeated training mix points to this athlete type.",
                    body: explanation,
                    confidence: evidence.dominantModalities.count >= 2 ? "High" : "Medium",
                    observationWindow: "6 years of imported workouts",
                    evidence: [
                        "Dominant modalities: \(joinedList(evidence.dominantModalities)).",
                        "\(evidence.totalWorkouts) imported workouts were available for this read."
                    ] + evidence.bodyMemoryEvidenceLines,
                    caveat: evidence.bodyMemoryArchetypeClause == nil ? nil : "Body-change modifiers appear only when repeated measurements clear the trend threshold."
                )
            )
        }

        let fallbackLabel: String
        if intent == .stayConsistent {
            fallbackLabel = "Consistency Seeker"
        } else if draft.trainingOptions.contains(.strength) && draft.trainingOptions.contains(where: { [.running, .cycling, .swimming].contains($0) }) {
            fallbackLabel = "Hybrid Intent"
        } else {
            fallbackLabel = "Emerging Athlete"
        }

        return AthleteBlueprintArchetype(
            label: fallbackLabel,
            explanation: "Your self-reported preferences point toward \(fallbackLabel.lowercased()), but HAYF needs more tracked history before it treats that as a durable pattern.",
                detail: AthleteBlueprintDetail(
                    id: "athlete_archetype",
                    title: "Athlete type",
                    summary: "Your onboarding choices are the strongest signal so far.",
                body: "This is an early label based on what you told HAYF, not a durable training pattern yet.",
                confidence: "Provisional",
                observationWindow: "Onboarding only",
                evidence: [
                    "Feasible training options: \(joinedList(draft.trainingOptions.map(\.title))).",
                    "No rich HealthKit workout history was available for a stronger identity read."
                ],
                caveat: "This label should sharpen once HAYF has enough repeated training behavior to observe."
            )
        )
    }

    private static func buildCurrentState(evidence: AthleteBlueprintEvidence) -> AthleteBlueprintCurrentState {
        guard evidence.hasWorkoutHistory else {
            return AthleteBlueprintCurrentState(
                label: "Still learning your baseline",
                summary: "HAYF does not yet have enough tracked history to say where you are right now with confidence.",
                detail: AthleteBlueprintDetail(
                    id: "current_training_state",
                    title: "Current state",
                    summary: "There is not enough recent HealthKit evidence yet for a strong present-state call.",
                    confidence: "Provisional",
                    observationWindow: "Recent training evidence unavailable",
                    evidence: ["Current-state claims are withheld when recent evidence is sparse."],
                    caveat: "This protects against treating old or thin data as your current state."
                )
            )
        }

        let sevenDayMinutes = evidence.windowMinutes("7d")
        let twentyEightDayMinutes = evidence.windowMinutes("28d")
        let ninetyDayMinutes = evidence.windowMinutes("90d")
        let weeklyAverage28 = twentyEightDayMinutes / 4
        let recentVsBaseline = weeklyAverage28 > 0 ? sevenDayMinutes / weeklyAverage28 : 1
        let label: String
        let summary: String
        let detailBody: String
        let evidenceLines: [String]

        if sevenDayMinutes == 0, ninetyDayMinutes > 0 {
            label = "Rebuilding after a lull"
            summary = "Last 7 days: no tracked training. Last 90 days: \(Int(ninetyDayMinutes.rounded())) tracked training minutes."
            detailBody = "Your history shows a usable base, but the last week has gone quiet. HAYF should treat this as re-entry rather than a blank slate."
            evidenceLines = [
                "Last 7 days: no tracked training minutes.",
                "Last 90 days: \(Int(ninetyDayMinutes.rounded())) tracked training minutes."
            ]
        } else if recentVsBaseline < 0.65, twentyEightDayMinutes > 0 {
            label = "Recent rhythm has dipped"
            summary = "Last 7 days: \(Int(sevenDayMinutes.rounded())) training minutes. Recent typical week: about \(Int(weeklyAverage28.rounded())) minutes."
            detailBody = "Your current week is lighter than your recent baseline, which suggests HAYF should protect momentum before it adds ambition."
            evidenceLines = [
                "Last 7 days: \(Int(sevenDayMinutes.rounded())) minutes.",
                "Typical recent week from the last 28 days: about \(Int(weeklyAverage28.rounded())) minutes."
            ]
        } else if recentVsBaseline > 1.35, weeklyAverage28 > 0 {
            label = "Building momentum"
            summary = "Last 7 days: \(Int(sevenDayMinutes.rounded())) training minutes. Recent typical week: about \(Int(weeklyAverage28.rounded())) minutes."
            detailBody = "Your most recent week is running above your recent baseline, which suggests real momentum but also a reason to keep the first strategy controlled."
            evidenceLines = [
                "Last 7 days: \(Int(sevenDayMinutes.rounded())) minutes.",
                "Typical recent week from the last 28 days: about \(Int(weeklyAverage28.rounded())) minutes."
            ]
        } else {
            label = "Stable recent rhythm"
            summary = "Last 7 days: \(Int(sevenDayMinutes.rounded())) training minutes. Recent typical week: about \(Int(weeklyAverage28.rounded())) minutes."
            detailBody = "Your recent training load is close to your recent baseline, so HAYF can start from continuity rather than repair."
            evidenceLines = [
                "Last 7 days: \(Int(sevenDayMinutes.rounded())) minutes.",
                "Typical recent week from the last 28 days: about \(Int(weeklyAverage28.rounded())) minutes."
            ]
        }

        return AthleteBlueprintCurrentState(
            label: label,
            summary: summary,
            detail: AthleteBlueprintDetail(
                    id: "current_training_state",
                    title: "Current state",
                    summary: "Your recent load says where you are starting from now.",
                body: detailBody,
                confidence: twentyEightDayMinutes > 0 ? "High" : "Medium",
                observationWindow: "Last 7 days vs prior 28-day baseline",
                evidence: evidenceLines,
                caveat: nil
            )
        )
    }

    private static func buildPhysicalBaseline(
        draft: ConsistencyOnboardingDraft,
        evidence: AthleteBlueprintEvidence
    ) -> AthleteBlueprintPhysicalBaseline {
        guard let bodyMassKilograms = draft.bodyMassKilograms,
              let heightCentimeters = draft.heightCentimeters,
              let bodyFatBand = draft.bodyFatBand else {
            return AthleteBlueprintPhysicalBaseline(
                label: "Baseline not set",
                summary: "HAYF is missing a current body baseline from onboarding.",
                detail: AthleteBlueprintDetail(
                    id: "physical_baseline",
                    title: "Physical baseline",
                    summary: "A current self-reported baseline was not available.",
                    confidence: "Missing",
                    observationWindow: "Onboarding",
                    evidence: ["No complete self-reported baseline was captured."],
                    caveat: "This should be collected before planning body-composition-sensitive goals."
                )
            )
        }

        var evidenceLines = [
            "Current self-reported body mass: \(String(format: "%.1f", bodyMassKilograms)) kg.",
            "Current self-reported height: \(Int(heightCentimeters.rounded())) cm.",
            "Estimated body-fat band: \(bodyFatBand.title)."
        ]
        if evidence.hasRecentBodyTrend {
            evidenceLines.append("Recent HealthKit body trend data is available as supporting context.")
        }
        evidenceLines.append(contentsOf: evidence.bodyMemoryEvidenceLines)

        let bodyMassText = String(format: "%.1f", bodyMassKilograms)
        let currentBaselineSummary = "You reported \(bodyMassText) kg, \(Int(heightCentimeters.rounded())) cm, and \(bodyFatBand.title) body fat today."

        return AthleteBlueprintPhysicalBaseline(
            label: "\(bodyMassText) kg, \(bodyFatBand.title) body fat",
            summary: currentBaselineSummary,
            detail: AthleteBlueprintDetail(
                    id: "physical_baseline",
                    title: "Physical baseline",
                    summary: "Today’s self-report is the current body baseline.",
                body: currentBaselineSummary,
                confidence: "Current self-report",
                observationWindow: "Onboarding today",
                evidence: evidenceLines,
                caveat: evidence.hasRecentBodyTrend ? "Imported body trends can add context, but do not replace the baseline you gave today." : nil
            )
        )
    }

    private static func buildHistoryFindings(evidence: AthleteBlueprintEvidence) -> [AthleteBlueprintFinding] {
        guard evidence.hasWorkoutHistory else {
            return [
                AthleteBlueprintFinding(
                    id: "history_not_enough_yet",
                    title: "Not enough training history yet",
                    summary: "HAYF will add sharper findings once it has enough repeated behavior to trust.",
                    detail: AthleteBlueprintDetail(
                        id: "history_not_enough_yet",
                        title: "What your history shows",
                        summary: "The current data is too thin for strong historical claims.",
                        confidence: "Provisional",
                        observationWindow: "Available imported workouts",
                        evidence: ["No repeated workout pattern cleared the confidence bar yet."],
                        caveat: "Weak evidence is intentionally omitted instead of padded into a false read."
                    )
                )
            ]
        }

        var findings: [AthleteBlueprintFinding] = []

        if let bodyFinding = buildBodyMemoryFinding(evidence: evidence) {
            findings.append(bodyFinding)
        }

        if evidence.strengthWorkouts90Days > 0 {
            findings.append(
                AthleteBlueprintFinding(
                    id: "strength_anchor",
                    title: "Strength is a real anchor",
                    summary: "\(evidence.strengthWorkouts90Days) tracked strength sessions totaling \(Int(evidence.strengthMinutes90Days.rounded())) minutes in the last 90 days.",
                    detail: AthleteBlueprintDetail(
                        id: "strength_anchor",
                        title: "Strength is a real anchor",
                        summary: "Repeated strength work is one of the clearest durable patterns in your recent history.",
                        confidence: "High",
                        observationWindow: "Last 90 days",
                        evidence: [
                            "\(evidence.strengthWorkouts90Days) tracked strength sessions.",
                            "\(Int(evidence.strengthMinutes90Days.rounded())) tracked strength minutes."
                        ],
                        caveat: nil
                    )
                )
            )
        }

        if evidence.longestActiveWeekStreak >= 4 {
            findings.append(
                AthleteBlueprintFinding(
                    id: "consistency_streak",
                    title: "You have proved you can hold a rhythm",
                    summary: "Longest active-week streak: \(evidence.longestActiveWeekStreak) weeks. Active weeks observed: \(evidence.activeWeeks).",
                    detail: AthleteBlueprintDetail(
                        id: "consistency_streak",
                        title: "You have proved you can hold a rhythm",
                        summary: "HAYF treats past sustained behavior as evidence that consistency is available to rebuild, not something you lack entirely.",
                        confidence: "High",
                        observationWindow: "6 years of imported workouts",
                        evidence: [
                            "Longest active-week streak: \(evidence.longestActiveWeekStreak) weeks.",
                            "Active weeks observed: \(evidence.activeWeeks)."
                        ],
                        caveat: nil
                    )
                )
            )
        }

        if let longest = evidence.longestWorkout {
            let distanceText = longest.distanceKilometers.map { " covering \(String(format: "%.1f", $0)) km" } ?? ""
            findings.append(
                AthleteBlueprintFinding(
                    id: "long_session_tolerance",
                    title: "You can handle one longer session",
                    summary: "Longest recorded \(longest.modality) session: \(Int(longest.durationMinutes.rounded())) minutes\(distanceText).",
                    detail: AthleteBlueprintDetail(
                        id: "long_session_tolerance",
                        title: "You can handle one longer session",
                        summary: "The longest repeated-capacity clue in your history gives HAYF room to use one bigger weekly anchor when the goal calls for it.",
                        confidence: "High",
                        observationWindow: "6 years of imported workouts",
                        evidence: [
                            "Longest recorded \(longest.modality) session: \(Int(longest.durationMinutes.rounded())) minutes.",
                            longest.distanceKilometers.map { "Distance in that session: \(String(format: "%.1f", $0)) km." } ?? "Distance was not recorded for that session."
                        ],
                        caveat: nil
                    )
                )
            )
        }

        if let strongestMonth = evidence.strongestMonth {
            findings.append(
                AthleteBlueprintFinding(
                    id: "strongest_month",
                    title: "\(strongestMonth.label) is your strongest month",
                    summary: "\(strongestMonth.label) has your highest imported monthly volume: \(Int(strongestMonth.totalMinutes.rounded())) tracked minutes.",
                    detail: AthleteBlueprintDetail(
                        id: "strongest_month",
                        title: "\(strongestMonth.label) is your strongest month",
                        summary: "Seasonality matters because some athletes reliably train better in certain parts of the year.",
                        confidence: "Medium",
                        observationWindow: "6 years of imported workouts",
                        evidence: [
                            "\(strongestMonth.label): \(Int(strongestMonth.totalMinutes.rounded())) total tracked minutes.",
                            "\(strongestMonth.workouts) tracked workouts in that month across imported history."
                        ],
                        caveat: nil
                    )
                )
            )
        }

        if findings.isEmpty, let firstModality = evidence.dominantModalities.first {
            findings.append(
                AthleteBlueprintFinding(
                    id: "dominant_modality",
                    title: "\(titleCase(firstModality)) leads your history",
                    summary: "\(titleCase(firstModality)) is the clearest repeated modality in your imported record.",
                    detail: AthleteBlueprintDetail(
                        id: "dominant_modality",
                        title: "\(titleCase(firstModality)) leads your history",
                        summary: "HAYF uses repeated behavior before it trusts self-description alone.",
                        confidence: "Medium",
                        observationWindow: "6 years of imported workouts",
                        evidence: ["Dominant modality: \(titleCase(firstModality))."],
                        caveat: nil
                    )
                )
            )
        }

        return Array(findings.prefix(4))
    }

    private static func buildBodyMemoryFinding(evidence: AthleteBlueprintEvidence) -> AthleteBlueprintFinding? {
        guard let direction = evidence.bodyMassTrendDirection,
              let change = evidence.bodyMassTrendChange,
              let days = evidence.bodyMassTrendDaysCovered else {
            return nil
        }

        let title: String
        let summary: String
        switch direction {
        case .falling:
            title = "Your weight has been trending down"
            summary = "Tracked weight is down \(String(format: "%.1f", abs(change))) kg across \(days) days."
        case .rising:
            title = "Your weight has been trending up"
            summary = "Tracked weight is up \(String(format: "%.1f", abs(change))) kg across \(days) days."
        case .stable:
            title = "Your weight has been steady"
            summary = "Tracked weight has stayed broadly stable across \(days) days."
        case .insufficient:
            return nil
        }

        return AthleteBlueprintFinding(
            id: "body_mass_trend",
            title: title,
            summary: summary,
            detail: AthleteBlueprintDetail(
                id: "body_mass_trend",
                title: title,
                summary: "A repeated measurement trend, not one imported reading.",
                body: summary,
                confidence: evidence.bodyMassTrendConfidence.capitalized,
                observationWindow: "Last \(days) days of tracked weight",
                evidence: evidence.bodyMemoryEvidenceLines,
                caveat: evidence.bodyFatTrendDirection == nil ? "Body-fat history is not dense enough to confirm whether the change is fat mass, lean mass, or both." : nil
            )
        )
    }

    private static func buildGoalFit(
        goal: AthleteBlueprintGoal,
        draft: ConsistencyOnboardingDraft,
        evidence: AthleteBlueprintEvidence
    ) -> AthleteBlueprintGoalFit {
        let result: (headline: String, summary: String, supports: [String], gaps: [String], detailEvidence: [String])

        switch goal.category {
        case .consistency:
            let hasProof = evidence.longestActiveWeekStreak >= 4 || evidence.windowWorkouts("90d") >= 8
            result = hasProof
                ? (
                    "A very natural fit",
                    "Consistency is not a vague aspiration for you; your history already shows periods where a rhythm holds. The work is making that rhythm easier to repeat over the next 12 weeks.",
                    [
                        evidence.longestActiveWeekStreak >= 4
                            ? "You have already sustained a \(evidence.longestActiveWeekStreak)-week active streak."
                            : "You trained repeatedly across the last 90 days."
                    ],
                    evidence.longestGapDays.map { ["Your history still includes a gap of \($0) days, so durability matters more than intensity."] } ?? [],
                    [
                        "Assessment horizon: 12 weeks.",
                        "Consistency is treated as a real goal, not a placeholder."
                    ]
                )
                : (
                    "A coherent first target",
                    "A 12-week consistency goal fits because the most important first adaptation is proving that training can repeat before the plan asks for more.",
                    ["Your onboarding answers explicitly prioritized a sustainable rhythm."],
                    ["HealthKit does not yet show a long enough repeated pattern to call this natural fit with high confidence."],
                    ["Assessment horizon: 12 weeks."]
                )
        case .endurance:
            let selectedEnduranceOptions = draft.trainingOptions.filter { [.running, .cycling, .swimming].contains($0) }
            let hasSelectedEndurancePath = !selectedEnduranceOptions.isEmpty
            result = hasSelectedEndurancePath
                ? (
                    "Coherent with your chosen path",
                    "Your goal to \(goal.displayText) is coherent with the training menu you chose, because \(joinedList(selectedEnduranceOptions.map(\.title))) can directly support that adaptation.",
                    ["You selected \(joinedList(selectedEnduranceOptions.map(\.title))) as feasible training options for this goal."],
                    evidence.dominantModalities.contains(where: { ["running", "cycling", "swimming"].contains($0) })
                        ? []
                        : ["Your recent history does not yet show endurance work as the dominant pattern, so the first block should build the bridge deliberately."],
                    ["Goal horizon: \(goal.horizonWeeks) weeks."]
                )
                : (
                    "Coherent, but under-specified",
                    "Your goal to \(goal.displayText) is valid, but your selected training menu does not yet name a clear endurance vehicle for it.",
                    ["You explicitly chose the goal."],
                    ["No selected feasible training option directly maps to endurance development yet."],
                    ["Goal horizon: \(goal.horizonWeeks) weeks."]
                )
        case .strength:
            let selectedStrengthPath = draft.trainingOptions.contains(.strength)
            result = selectedStrengthPath
                ? (
                    "Coherent with your chosen path",
                    "Your goal to \(goal.displayText) is coherent with the training menu you chose, because strength work is already part of the path you said is feasible.",
                    ["You selected Strength as a feasible training option for this goal."],
                    evidence.dominantModalities.contains("strength") ? [] : ["Strength is not yet one of the clearest tracked patterns in your history."],
                    ["Goal horizon: \(goal.horizonWeeks) weeks."]
                )
                : (
                    "Coherent, but under-specified",
                    "Your goal to \(goal.displayText) is valid, but your selected training menu does not yet name a direct strength path for it.",
                    ["You explicitly chose the goal."],
                    ["No selected feasible training option directly maps to strength development yet."],
                    ["Goal horizon: \(goal.horizonWeeks) weeks."]
                )
        case .bodyComposition:
            let selectedOptions = draft.trainingOptions.map(\.title)
            let support = evidence.bodyCompositionGoalSupport
            result = (
                support.headline,
                support.summary(goal: goal.displayText, selectedOptions: selectedOptions),
                support.supports + (selectedOptions.isEmpty ? [] : ["You selected \(joinedList(selectedOptions)) as feasible training options for this goal."]),
                support.gaps,
                ["Goal horizon: \(goal.horizonWeeks) weeks."]
            )
        case .sportPerformance, .generalFitness, .custom:
            let selectedOptions = draft.trainingOptions.map(\.title)
            result = (
                selectedOptions.isEmpty ? "Coherent with what you asked for" : "Coherent with your chosen path",
                selectedOptions.isEmpty
                    ? "Your goal to \(goal.displayText) is a reasonable direction from the information you gave HAYF. The first strategy should be judged by whether it matches your real training behavior once it is underway."
                    : "Your goal to \(goal.displayText) is coherent with the training path you chose: \(joinedList(selectedOptions)). Historical strengths are useful context, but they do not override the sports you said you want to use now.",
                selectedOptions.isEmpty
                    ? ["The goal came directly from your onboarding choices."]
                    : ["You selected \(joinedList(selectedOptions)) as feasible training options for this goal."],
                evidence.hasWorkoutHistory ? [] : ["There is not yet enough tracked history to assess fit more sharply."],
                ["Goal horizon: \(goal.horizonWeeks) weeks."]
            )
        }

        return AthleteBlueprintGoalFit(
            headline: result.headline,
            summary: result.summary,
            supports: result.supports,
            gaps: result.gaps,
            detail: AthleteBlueprintDetail(
                id: "goal_fit",
                title: "Goal fit",
                summary: result.headline,
                body: result.summary,
                confidence: evidence.hasWorkoutHistory ? "High" : "Medium",
                observationWindow: "Goal + onboarding + available athlete evidence",
                evidence: result.supports + result.gaps + result.detailEvidence,
                caveat: nil
            )
        )
    }

    private static func goalHorizonWeeks(from timeline: GoalTimeline?, goalDate: Date) -> Int {
        guard timeline == .specificDate else { return timeline?.weeks ?? 12 }

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: goalDate)
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 84)
        return max(1, Int(ceil(Double(days) / 7.0)))
    }

    private static func normalizedGoalDisplayText(from value: String) -> String {
        var text = value.trimmed
        let lowercase = text.lowercased()
        let prefixes = [
            "i want to ",
            "i'd like to ",
            "i would like to ",
            "my goal is to "
        ]

        if let prefix = prefixes.first(where: { lowercase.hasPrefix($0) }) {
            text = String(text.dropFirst(prefix.count))
        }

        guard let first = text.first else { return "make progress" }
        return first.lowercased() + text.dropFirst()
    }

    private static func category(for text: String) -> AthleteBlueprintGoalCategory {
        let normalized = text.lowercased()
        if normalized.contains("run") || normalized.contains("marathon") || normalized.contains("10k") || normalized.contains("5k") || normalized.contains("endurance") {
            return .endurance
        }
        if normalized.contains("strength") || normalized.contains("lift") || normalized.contains("gym") {
            return .strength
        }
        if normalized.contains("body fat")
            || normalized.contains("lean")
            || normalized.contains("weight")
            || normalized.contains("composition")
            || normalized.contains("kg")
            || normalized.contains("lose ")
            || normalized.contains("drop ") {
            return .bodyComposition
        }
        if normalized.contains("tennis") || normalized.contains("football") || normalized.contains("basketball") || normalized.contains("sport") {
            return .sportPerformance
        }
        return .generalFitness
    }

    private static func titleCase(_ value: String) -> String {
        value
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func joinedList(_ values: [String]) -> String {
        let clean = values.map(titleCase)
        switch clean.count {
        case 0:
            return "your recent training"
        case 1:
            return clean[0]
        case 2:
            return "\(clean[0]) and \(clean[1])"
        default:
            return "\(clean.dropLast().joined(separator: ", ")), and \(clean.last ?? "")"
        }
    }

    private static func uniqueSentences(from lines: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []

        for line in lines {
            let normalized = line
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            unique.append(line)
        }

        return unique
    }
}

private struct AthleteBlueprintGoal {
    let displayText: String
    let horizonWeeks: Int
    let category: AthleteBlueprintGoalCategory
}

private enum AthleteBlueprintGoalCategory: String {
    case consistency
    case endurance
    case strength
    case bodyComposition
    case sportPerformance
    case generalFitness
    case custom
}

private struct AthleteBlueprintEvidence {
    let snapshot: HealthFeatureSnapshot?

    var hasWorkoutHistory: Bool {
        totalWorkouts > 0
    }

    var totalWorkouts: Int {
        snapshot?.workoutLedger.totalWorkouts ?? 0
    }

    var trainingIdentityLabel: String? {
        snapshot?.fitnessHistory.trainingIdentity.label
    }

    var dominantModalities: [String] {
        snapshot?.fitnessHistory.trainingIdentity.dominantModalities ?? []
    }

    var longestActiveWeekStreak: Int {
        snapshot?.fitnessHistory.consistency.longestActiveWeekStreak ?? 0
    }

    var activeWeeks: Int {
        snapshot?.fitnessHistory.consistency.activeWeeks ?? 0
    }

    var longestGapDays: Int? {
        snapshot?.fitnessHistory.consistency.longestGapDays
    }

    var strengthWorkouts90Days: Int {
        snapshot?.fitnessHistory.strengthContinuity.strengthWorkouts90Days ?? 0
    }

    var strengthMinutes90Days: Double {
        snapshot?.fitnessHistory.strengthContinuity.strengthMinutes90Days ?? 0
    }

    var longestWorkout: FitnessLongestWorkoutSummary? {
        snapshot?.fitnessHistory.performance.longestWorkoutsByModality.first
    }

    var strongestMonth: FitnessMonthlyActivitySummary? {
        snapshot?.fitnessHistory.seasonality.strongestMonth
    }

    var hasRecentBodyTrend: Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantFuture
        return [
            snapshot?.body.bodyMassLatestSampleDate,
            snapshot?.body.bodyFatLatestSampleDate
        ]
        .compactMap { $0 }
        .contains { $0 >= cutoff }
    }

    var bodyMassTrend: BodyMetricTrendSummary? {
        let trend = snapshot?.body.bodyMassHistory
        return trend?.trend == .insufficient ? nil : trend
    }

    var bodyFatTrend: BodyMetricTrendSummary? {
        let trend = snapshot?.body.bodyFatHistory
        return trend?.trend == .insufficient ? nil : trend
    }

    var bodyMassTrendDirection: BodyMetricTrendDirection? {
        bodyMassTrend?.trend
    }

    var bodyFatTrendDirection: BodyMetricTrendDirection? {
        bodyFatTrend?.trend
    }

    var bodyMassTrendChange: Double? {
        bodyMassTrend?.change
    }

    var bodyMassTrendDaysCovered: Int? {
        bodyMassTrend?.daysCovered
    }

    var bodyMassTrendConfidence: String {
        bodyMassTrend?.confidence ?? "insufficient"
    }

    var bodyMemoryArchetypePrefix: String? {
        switch bodyMassTrendDirection {
        case .falling:
            return "Leaning"
        case .rising:
            return [.falling, .stable].contains(bodyFatTrendDirection) ? "Building" : nil
        case .stable:
            return "Steady"
        case .insufficient, .none:
            return nil
        }
    }

    var bodyMemoryArchetypeClause: String? {
        guard let change = bodyMassTrendChange,
              let days = bodyMassTrendDaysCovered else {
            return nil
        }

        switch bodyMassTrendDirection {
        case .falling:
            return "Repeated weight entries show you have been leaning out: down \(String(format: "%.1f", abs(change))) kg across \(days) days."
        case .rising:
            if [.falling, .stable].contains(bodyFatTrendDirection) {
                return "Repeated weight entries show a likely building phase: up \(String(format: "%.1f", abs(change))) kg across \(days) days without body-fat moving upward."
            }
            return "Repeated weight entries show body mass rising by \(String(format: "%.1f", abs(change))) kg across \(days) days."
        case .stable:
            return "Repeated weight entries show a steady body baseline across \(days) days."
        case .insufficient, .none:
            return nil
        }
    }

    var bodyMemoryCoachLine: String? {
        guard let clause = bodyMemoryArchetypeClause else { return nil }
        return clause
    }

    var bodyMemoryEvidenceLines: [String] {
        guard let bodyMassTrend else { return [] }
        var lines = [
            "Tracked body-mass samples: \(bodyMassTrend.sampleCount).",
            "Body-mass trend window: \(bodyMassTrend.daysCovered) days.",
            "Body-mass change across window: \(String(format: "%.1f", bodyMassTrend.change ?? 0)) kg."
        ]
        if let bodyFatTrend {
            lines.append("Tracked body-fat samples: \(bodyFatTrend.sampleCount); trend: \(bodyFatTrend.trend.rawValue).")
        }
        return lines
    }

    var bodyCompositionGoalSupport: BodyCompositionGoalSupport {
        switch bodyMassTrendDirection {
        case .falling:
            return BodyCompositionGoalSupport(
                headline: "Already moving that way",
                summaryStem: "Your goal to %@ is already aligned with a measurable downward weight trend.",
                supports: bodyMemoryEvidenceLines,
                gaps: bodyFatTrendDirection == nil ? ["Body-fat history is not dense enough yet to confirm composition change directly."] : []
            )
        case .rising:
            return BodyCompositionGoalSupport(
                headline: "Clear change in direction",
                summaryStem: "Your goal to %@ is coherent, but it asks HAYF to reverse the body-mass direction seen in recent measurements.",
                supports: bodyMemoryEvidenceLines,
                gaps: ["Recent tracked weight has been rising, so the plan must create a real change in trajectory."]
            )
        case .stable:
            return BodyCompositionGoalSupport(
                headline: "Coherent, but not underway",
                summaryStem: "Your goal to %@ is coherent, but recent tracked weight has been broadly stable rather than already moving toward it.",
                supports: bodyMemoryEvidenceLines,
                gaps: ["The body-composition goal requires a new trend, not just continuation."]
            )
        case .insufficient, .none:
            return BodyCompositionGoalSupport(
                headline: "Coherent with limited history",
                summaryStem: "Your goal to %@ is coherent, but HAYF has too little repeated body-history data to judge whether it continues or changes your current trajectory.",
                supports: [],
                gaps: ["Repeated body-composition history is not yet strong enough for a trend call."]
            )
        }
    }

    func windowMinutes(_ label: String) -> Double {
        snapshot?.workoutLedger.windows.first { $0.window == label }?.totalMinutes ?? 0
    }

    func windowWorkouts(_ label: String) -> Int {
        snapshot?.workoutLedger.windows.first { $0.window == label }?.workouts ?? 0
    }
}

private struct BodyCompositionGoalSupport {
    let headline: String
    let summaryStem: String
    let supports: [String]
    let gaps: [String]

    func summary(goal: String, selectedOptions: [String]) -> String {
        let body = String(format: summaryStem, goal)
        guard !selectedOptions.isEmpty else { return body }
        return "\(body) The training path you chose is \(joinedList(selectedOptions))."
    }

    private func joinedList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return "your selected training"
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? "")"
        }
    }
}

private struct AthleteBlueprintSummaryRow: View {
    let systemImage: String
    let eyebrow: String
    let title: String
    let summary: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            HAYFIcon(systemImage: systemImage, isSelected: true, size: 36, iconSize: 18)

            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .medium))
                    .kerning(1.2)
                    .foregroundStyle(HAYFColor.secondary)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text(summary)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct FitnessStrategySnapshotGrid: View {
    let items: [FitnessStrategySnapshotItem]
    private let tileHeight: CGFloat = 104

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(items) { item in
                VStack(spacing: item.id == "priorities" ? 6 : 7) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HAYFColor.orange)
                        .frame(height: 18)

                    VStack(spacing: 2) {
                        Text(item.value)
                            .font(.system(size: item.id == "priorities" ? 12 : 13, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(item.id == "priorities" ? 3 : 1)
                            .minimumScaleFactor(item.id == "priorities" ? 0.78 : 0.75)

                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(HAYFColor.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
                .frame(maxWidth: item.id == "priorities" ? .infinity : 82)
                .frame(height: tileHeight)
                .background(HAYFColor.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct FitnessStrategyReadCard: View {
    let read: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COACH VERDICT")
                .font(.system(size: 10, weight: .medium))
                .kerning(1.2)
                .foregroundStyle(HAYFColor.secondary)

            Text(read)
                .font(.system(size: 18, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(HAYFColor.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct FitnessStrategyGoalContextCard: View {
    let context: FitnessStrategyGoalTargetContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GOAL CONTEXT")
                .font(.system(size: 10, weight: .medium))
                .kerning(1.2)
                .foregroundStyle(HAYFColor.secondary)

            Text(context.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            Text(context.summary)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct FitnessStrategyFitReasonRow: View {
    let reason: FitnessStrategyFitReason

    var body: some View {
        FitnessStrategyIconRow(
            systemImage: reason.systemImage,
            title: reason.title,
            summary: reason.summary
        )
    }
}

private struct FitnessStrategyPillarRow: View {
    let pillar: FitnessStrategyPillar

    var body: some View {
        FitnessStrategyIconRow(
            systemImage: "arrow.up.right",
            title: pillar.title,
            summary: pillar.summary
        )
    }
}

private struct FitnessStrategyIconRow: View {
    let systemImage: String
    let title: String
    let summary: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(HAYFColor.orange.opacity(0.18))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HAYFColor.orange)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text(summary)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct FitnessStrategyPhaseRow: View {
    let phase: FitnessStrategyPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(phase.name.uppercased())
                .font(.system(size: 10, weight: .medium))
                .kerning(1.2)
                .foregroundStyle(HAYFColor.secondary)

            Text(phase.objective)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                ForEach(phase.targets) { target in
                    FitnessStrategyPhaseTargetRow(target: target)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct FitnessStrategyPhaseTargetRow: View {
    let target: FitnessStrategyTarget

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "smallcircle.filled.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 16, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(target.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 6)

                    if let value = target.displayValue {
                        Text(value)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(HAYFColor.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(target.summary)
                    .font(.system(size: 13, weight: .regular))
                    .lineSpacing(2)
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(HAYFColor.neutral)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct FitnessStrategyOperatingRhythmCard: View {
    let rhythm: FitnessStrategyOperatingRhythm

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(rhythm.summary)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(rhythm.anchors, id: \.self) { anchor in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(HAYFColor.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(anchor)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HAYFColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct FitnessStrategyTargetRow: View {
    let target: FitnessStrategyTarget
    let label: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(target.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 6)

                    if let value = target.displayValue {
                        Text(value)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HAYFColor.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(target.summary)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct FitnessStrategyPlanBridgeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEEKLY TARGETS COME NEXT")
                .font(.system(size: 10, weight: .medium))
                .kerning(1.2)
                .foregroundStyle(HAYFColor.secondary)

            Text("After you accept, HAYF turns this strategy into your first two visible weeks.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Current week committed · next week draft · weekly targets attached to each week")
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(2)
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.orange.opacity(0.22), lineWidth: 1)
        }
    }
}

private extension FitnessStrategyTarget {
    var metricCategoryDisplay: String {
        metricCategory
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

private struct AthleteBlueprintFindingRow: View {
    let finding: AthleteBlueprintFinding

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(HAYFColor.orange)
                .frame(width: 8, height: 8)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 5) {
                Text(finding.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text(finding.summary)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct AthleteBlueprintGoalFitCard: View {
    let goalFit: AthleteBlueprintGoalFit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(goalFit.headline)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            Text(goalFit.summary)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct AthleteBlueprintDetailSheet: View {
    let detail: AthleteBlueprintDetail

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Capsule()
                    .fill(HAYFColor.borderStrong)
                    .frame(width: 46, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)

                VStack(alignment: .leading, spacing: 10) {
                    Text(detail.title.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .kerning(1.2)
                        .foregroundStyle(HAYFColor.secondary)

                    Text(detail.summary)
                        .font(.system(size: 20, weight: .semibold))
                        .lineSpacing(4)
                        .foregroundStyle(HAYFColor.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let body = detail.body {
                        Text(body)
                            .font(.system(size: 15, weight: .regular))
                            .lineSpacing(4)
                            .foregroundStyle(HAYFColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }

                HStack(spacing: 10) {
                    BlueprintMetaPill(label: "Confidence", value: detail.confidence)
                    BlueprintMetaPill(label: "Window", value: detail.observationWindow)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(detail.rankedEvidence, id: \.self) { item in
                        BlueprintEvidenceRow(text: item)
                    }
                }

                if let caveat = detail.caveat {
                    Text(caveat)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(HAYFColor.muted)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HAYFColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(HAYFColor.border, lineWidth: 1)
                        }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(HAYFColor.neutral.ignoresSafeArea())
    }
}

private struct BlueprintEvidenceRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(HAYFColor.orange)
                .frame(width: 7, height: 7)
                .padding(.top, 8)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct BlueprintMetaPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .kerning(1.0)
                .foregroundStyle(HAYFColor.muted)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 72, alignment: .center)
        .padding(.horizontal, 12)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct HAYFIcon: View {
    let systemImage: String
    var isSelected: Bool
    var size: CGFloat = 44
    var iconSize: CGFloat = 22

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .regular))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(isSelected ? HAYFColor.orange : HAYFColor.primary)
            .frame(width: size, height: size)
    }
}

private struct RadioDot: View {
    let isSelected: Bool

    var body: some View {
        Circle()
            .stroke(isSelected ? HAYFColor.orange : HAYFColor.borderStrong, lineWidth: 1.5)
            .frame(width: 20, height: 20)
            .overlay {
                if isSelected {
                    Circle()
                        .fill(HAYFColor.orange)
                        .frame(width: 10, height: 10)
                }
            }
    }
}

private struct CheckmarkBox: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isSelected ? HAYFColor.orange : Color.clear)
            .frame(width: 22, height: 22)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(isSelected ? HAYFColor.orange : HAYFColor.borderStrong, lineWidth: 1.4)
            }
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}

private struct OnboardingPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isEnabled ? .white : HAYFColor.muted)
                        .frame(maxWidth: .infinity)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isEnabled ? .white : HAYFColor.muted)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(isEnabled ? HAYFColor.primary : HAYFColor.surfaceDisabled)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

struct StoredOnboardingProfile: Decodable, Identifiable {
    let id: UUID
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case completedAt = "completed_at"
    }
}

private struct CompletedOnboardingProfileRequest: Encodable {
    let id: UUID
    let intent: String
    let selectedAnswers: OnboardingAICompactContext
    let generatedSummary: OnboardingAISummaryPayload
    let healthPermissionState: String
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case intent
        case selectedAnswers = "selected_answers"
        case generatedSummary = "generated_summary"
        case healthPermissionState = "health_permission_state"
        case completedAt = "completed_at"
    }
}

private struct BodyMeasurementInsertRequest: Encodable {
    let userID: UUID
    let measuredAt: String
    let source: String
    let heightCentimeters: Double
    let bodyMassKilograms: Double
    let bodyFatBand: String
    let bodyFatEstimateMidpoint: Double
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case measuredAt = "measured_at"
        case source
        case heightCentimeters = "height_centimeters"
        case bodyMassKilograms = "body_mass_kilograms"
        case bodyFatBand = "body_fat_band"
        case bodyFatEstimateMidpoint = "body_fat_estimate_midpoint"
        case confidence
    }
}

@MainActor
final class OnboardingProfileStore: ObservableObject {
    @Published private(set) var profile: StoredOnboardingProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClientProvider.shared
    private let completedAtFormatter = ISO8601DateFormatter()

    func loadCurrentUserOnboardingProfile() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            profile = try await fetchCurrentUserOnboardingProfile()
        } catch {
            errorMessage = error.localizedDescription
            profile = nil
        }
    }

    fileprivate func completeCurrentUserOnboarding(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        summary: OnboardingSummaryOutput,
        healthRequestState: HealthRequestState
    ) async throws -> StoredOnboardingProfile {
        let user = try await supabase.auth.session.user
        let request = CompletedOnboardingProfileRequest(
            id: user.id,
            intent: intent.rawValue,
            selectedAnswers: OnboardingAICompactContext(intent: intent, draft: draft),
            generatedSummary: OnboardingAISummaryPayload(summary: summary),
            healthPermissionState: healthRequestState.storageValue,
            completedAt: completedAtFormatter.string(from: Date())
        )

        let completedProfile: StoredOnboardingProfile = try await supabase
            .from("onboarding_profiles")
            .upsert(request, onConflict: "id")
            .select("id, completed_at")
            .single()
            .execute()
            .value

        if let heightCentimeters = draft.heightCentimeters,
           let bodyMassKilograms = draft.bodyMassKilograms,
           let bodyFatBand = draft.bodyFatBand {
            let baseline = BodyMeasurementInsertRequest(
                userID: user.id,
                measuredAt: request.completedAt,
                source: "onboarding_self_report",
                heightCentimeters: heightCentimeters,
                bodyMassKilograms: bodyMassKilograms,
                bodyFatBand: bodyFatBand.rawValue,
                bodyFatEstimateMidpoint: bodyFatBand.midpointEstimate,
                confidence: "estimated_band"
            )

            try await supabase
                .from("body_measurements")
                .insert(baseline)
                .execute()
        }

        errorMessage = nil
        return completedProfile
    }

    fileprivate func useProfile(_ completedProfile: StoredOnboardingProfile) {
        profile = completedProfile
        errorMessage = nil
    }

    func clearCurrentUserOnboardingProfile() async throws {
        let user = try await supabase.auth.session.user

        try await supabase
            .from("onboarding_profiles")
            .delete()
            .eq("id", value: user.id)
            .execute()

        profile = nil
        errorMessage = nil
    }

    func reset() {
        profile = nil
        errorMessage = nil
        isLoading = false
    }

    private func fetchCurrentUserOnboardingProfile() async throws -> StoredOnboardingProfile? {
        let user = try await supabase.auth.session.user

        do {
            let profile: StoredOnboardingProfile = try await supabase
                .from("onboarding_profiles")
                .select("id, completed_at")
                .eq("id", value: user.id)
                .single()
                .execute()
                .value

            return profile
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }
}

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func limitedSentences(maxSentences: Int, maxCharacters: Int) -> String {
        let sentenceParts = split(separator: ".", omittingEmptySubsequences: true)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }

        let sentenceLimited = sentenceParts
            .prefix(maxSentences)
            .map { $0.hasSuffix(".") ? $0 : "\($0)." }
            .joined(separator: " ")

        return sentenceLimited.isEmpty ? self.trimmed : sentenceLimited
    }

    func goalCardTitle(timeline: GoalTimeline) -> String {
        let weeks = timeline.weeks
        var result = self
            .replacingOccurrences(of: "—", with: ". ")
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
            .replacingOccurrences(
                of: "^[\\s:;,.\\-]+",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\s{2,}",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\s+\\.",
                with: ".",
                options: .regularExpression
            )
            .trimmed

        if result.isEmpty {
            result = self.trimmed
        }

        return result.capitalizingSentenceStarts()
    }

    func removingGoalTimeline(_ timeline: GoalTimeline) -> String {
        goalCardTitle(timeline: timeline)
    }

    func goalCardRationale() -> String {
        replacingOccurrences(of: ";", with: ".")
            .replacingOccurrences(of: "—", with: ". ")
            .replacingOccurrences(of: "–", with: ". ")
            .replacingOccurrences(
                of: "Primary priority ([^,]+), athlete wants measurable numeric targets and to be more athletic\\.?",
                with: "Your $1 priority and your preference for measurable targets give us a clear starting point.",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "Primary priority ([^,]+), athlete wants ([^.]+)\\.?",
                with: "Your $1 priority matters here, and you want $2.",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "Primary interest in ([^+.]+) \\+ access to ([^.]+)\\.",
                with: "Your $1 priority and access to $2 give us a clear starting point.",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bmeasurable numeric target suits\\b",
                with: "We will use a measurable target that fits",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bStrength is secondary but supports\\b",
                with: "Strength is a secondary priority, but it will support your",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bAn objective 1RM target fits the your preference for numbers\\.",
                with: "You prefer numbers, so an objective 1RM target gives you a clear project.",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bThe athlete wants\\b",
                with: "You want",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bAthlete wants\\b",
                with: "You want",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bthe athlete's\\b",
                with: "your",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bathlete\\b",
                with: "you",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bthe user's\\b",
                with: "your",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\buser's\\b",
                with: "your",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bthe user\\b",
                with: "you",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\buser\\b",
                with: "you",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: "\\bthe your\\b",
                with: "your",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(of: "/", with: " or ")
            .replacingOccurrences(of: " + ", with: " and ")
            .replacingOccurrences(of: "Primary interest in ", with: "Your priority is ")
            .replacingOccurrences(of: "athlete's preference", with: "your preference")
            .replacingOccurrences(of: "Athlete's preference", with: "Your preference")
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmed
            .capitalizingSentenceStarts()
    }

    private func capitalizingSentenceStarts() -> String {
        split(separator: ".", omittingEmptySubsequences: false)
            .map { part in
                let string = String(part)
                let leadingSpaces = string.prefix { $0 == " " }
                let trimmedPart = string.drop { $0 == " " }
                guard let first = trimmedPart.first else {
                    return string
                }
                return String(leadingSpaces) + first.uppercased() + String(trimmedPart.dropFirst())
            }
            .joined(separator: ".")
    }
}

private extension HealthRequestState {
    var storageValue: String {
        switch self {
        case .idle:
            return "not_requested"
        case .requesting:
            return "requesting"
        case .connected:
            return "connected"
        case .unavailable:
            return "unavailable"
        case .failed:
            return "failed"
        }
    }
}

#Preview {
    OnboardingFlowView(physiologyReference: .male, onboardingProfileStore: OnboardingProfileStore()) {}
}
