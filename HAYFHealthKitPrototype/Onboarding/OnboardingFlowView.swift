import SwiftUI
import Supabase
import OSLog

struct OnboardingFlowView: View {
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
    @State private var pendingHealthSnapshot: HealthFeatureSnapshot?
    @State private var selectedBlueprintDetail: AthleteBlueprintDetail?
    @State private var completionErrorMessage: String?
    @State private var isCompleting = false

    private let healthKitManager = HealthKitManager()
    private let aiProvider: any OnboardingAIProvider = RemoteOnboardingAIProvider()
    private let planningAIProvider = PlanningAIProvider()
    private let onboardingProfileStore: OnboardingProfileStore

    init(onboardingProfileStore: OnboardingProfileStore, onComplete: @escaping () -> Void) {
        self.onboardingProfileStore = onboardingProfileStore
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

                bottomAction
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: 480)
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .sheet(item: $selectedBlueprintDetail) { detail in
            AthleteBlueprintDetailSheet(detail: detail)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task(id: step) {
            switch step {
            case .health:
                await refreshHealthState()
            case .generatingBlueprint:
                await generateAthleteBlueprint()
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

                if step.showsBackButton {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "arrow.left")
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
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
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
        case .goalClarification:
            concreteGoalClarificationScreen
        case .options:
            trainingOptionsScreen
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
        case .rhythm:
            rhythmScreen
        case .friction:
            frictionScreen
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

            Text("The number shows priority. Tap again to remove an option.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
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

    private var concreteGoalClarificationScreen: some View {
        VStack(alignment: .leading, spacing: 28) {
            OnboardingIntro(
                title: "Let's make that\ncoachable.",
                copy: "HAYF will read your workout history from Apple Health later. Here, add the experience and constraints only you can tell us."
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

            Text("Apple Health will help HAYF estimate your recent training load. Your answer here takes priority if your tracked history is sparse or incomplete.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
                .fixedSize(horizontal: false, vertical: true)

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

            OnboardingTextArea(
                title: "Any injuries or discomforts?",
                placeholder: "Knee pain on descents, shoulder discomfort overhead, returning from an ankle issue, or anything HAYF should plan around...",
                text: $draft.injuryNotes,
                characterLimit: 220
            )
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

            OnboardingTextArea(
                title: "Any injuries or discomforts?",
                placeholder: "Knee pain on descents, shoulder discomfort overhead, returning from an ankle issue, or anything HAYF should avoid building around...",
                text: $draft.injuryNotes,
                characterLimit: 220
            )
        }
    }

    private var goalCandidatesScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Which goal feels\nmost like you?",
                copy: "HAYF mocked up three directions from what you chose. Pick one, edit it, or blend two."
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
                eyebrow: "HAYF IS THINKING",
                title: title,
                copy: copy
            )

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

    private var rhythmScreen: some View {
        VStack(alignment: .leading, spacing: 28) {
            OnboardingIntro(
                title: currentIntent == .concreteGoal ? "How many days can\nyou train?" : "What feels realistic\nmost weeks?",
                copy: currentIntent == .concreteGoal ? "This is your total weekly exercise budget: goal sessions plus support work." : "This helps HAYF protect consistency before ambition."
            )

            OptionGroup(title: currentIntent == .concreteGoal ? "Total training days per week" : "Days per week") {
                HStack(spacing: 10) {
                    ForEach(TrainingFrequency.allCases) { frequency in
                        CompactChoiceButton(
                            title: frequency.title,
                            isSelected: draft.frequency == frequency
                        ) {
                            draft.frequency = frequency
                        }
                    }
                }
            }

            Divider()
                .background(HAYFColor.border)

            OptionGroup(title: "Typical session length") {
                HStack(spacing: 10) {
                    ForEach(SessionLength.allCases) { length in
                        CompactChoiceButton(
                            title: length.title,
                            isSelected: draft.sessionLength == length
                        ) {
                            draft.sessionLength = length
                        }
                    }
                }
            }
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
                SummaryItem(systemImage: "bolt.heart", label: "Anchor", value: draft.motivationInputSummary),
                SummaryItem(systemImage: "timer", label: "Rhythm", value: draft.rhythmSummary),
                SummaryItem(systemImage: "exclamationmark.triangle", label: "Risks", value: draft.blockerInputSummary),
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
                SummaryItem(systemImage: "timer", label: "Rhythm", value: draft.rhythmSummary),
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
                SummaryItem(systemImage: "timer", label: "Rhythm", value: draft.rhythmSummary),
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
                title: "Here's HAYF's\nread on you.",
                copy: "This is the athlete HAYF believes it is coaching before it builds the strategy."
            )

            Button {
                selectedBlueprintDetail = blueprint.coachRead.detail
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    Text("COACH'S READ")
                        .font(.system(size: 10, weight: .medium))
                        .kerning(1.2)
                        .foregroundStyle(HAYFColor.secondary)

                    Text(blueprint.coachRead.text)
                        .font(.system(size: 18, weight: .regular))
                        .lineSpacing(5)
                        .foregroundStyle(HAYFColor.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    BlueprintEvidenceHint()
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
            .buttonStyle(.plain)

            VStack(spacing: 12) {
                AthleteBlueprintSummaryRow(
                    systemImage: "person.text.rectangle",
                    eyebrow: "ATHLETE TYPE",
                    title: blueprint.archetype.label,
                    summary: blueprint.archetype.explanation
                ) {
                    selectedBlueprintDetail = blueprint.archetype.detail
                }

                AthleteBlueprintSummaryRow(
                    systemImage: "waveform.path.ecg",
                    eyebrow: "CURRENT STATE",
                    title: blueprint.currentTrainingState.label,
                    summary: blueprint.currentTrainingState.summary
                ) {
                    selectedBlueprintDetail = blueprint.currentTrainingState.detail
                }
            }

            SummarySection(title: "What your history shows") {
                VStack(spacing: 10) {
                    ForEach(blueprint.historyFindings) { finding in
                        AthleteBlueprintFindingRow(finding: finding) {
                            selectedBlueprintDetail = finding.detail
                        }
                    }
                }
            }

            SummarySection(title: "Goal fit") {
                AthleteBlueprintGoalFitCard(goalFit: blueprint.goalFit) {
                    selectedBlueprintDetail = blueprint.goalFit.detail
                }
            }
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
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingBlueprint:
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
        case .goalClarification:
            return draft.goalExperience != nil && draft.goalTimeline != nil && draft.goalPriority != nil
        case .options:
            return !draft.trainingOptions.isEmpty
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
        case .rhythm:
            return draft.frequency != nil && draft.sessionLength != nil
        case .friction:
            return !draft.blockers.isEmpty
        case .support:
            return draft.supportStyle != nil
        case .floor:
            return draft.badDayFloor != nil
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingBlueprint:
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
            step = .goalClarification
        case .goalClarification:
            step = .options
        case .options:
            if selectedIntent == .findGoal {
                step = .findDirection
            } else if selectedIntent == .concreteGoal {
                step = .rhythm
            } else {
                step = .anchor
            }
        case .anchor:
            step = .rhythm
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
            step = .rhythm
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
            step = .rhythm
        case .blendCandidates:
            step = .generatingBlend
        case .blendPreview:
            draft.chosenGoal = blendedCandidate
            draft.goalTimeline = blendedCandidate?.timeline
            step = .rhythm
        case .rhythm:
            step = .friction
        case .friction:
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
            if healthRequestState == .connected || healthRequestState == .unavailable {
                prepareAthleteBlueprint()
            } else {
                requestHealthAccess()
            }
        case .athleteBlueprint:
            completeOnboarding()
        case .generatingCandidates, .generatingBlend, .generatingBlueprint:
            break
        }
    }

    private func goBack() {
        switch step {
        case .intent:
            break
        case .goalBrief:
            step = .intent
        case .goalClarification:
            step = .goalBrief
        case .options:
            step = selectedIntent == .concreteGoal ? .goalClarification : .intent
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
        case .rhythm:
            if selectedIntent == .stayConsistent {
                step = .anchor
            } else if selectedIntent == .findGoal {
                step = .goalCandidates
            } else {
                step = .options
            }
        case .friction:
            step = .rhythm
        case .support:
            step = .friction
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
        let output = await aiProvider.generateSummary(intent: currentIntent, draft: draft)
        summaryOutput = output.isValid ? output : MockOnboardingAIProvider.fallbackSummary(intent: currentIntent, draft: draft)
        step = .summary
    }

    private func generateGoalCandidates() async {
        let candidates = await aiProvider.generateGoalCandidates(draft: draft)
        goalCandidates = candidates.count == 3 ? candidates : MockOnboardingAIProvider.fallbackGoalCandidates(for: draft)
        selectedGoalCandidateID = nil
        step = .goalCandidates
    }

    private func generateBlendedCandidate() async {
        let candidates = displayGoalCandidates.filter { blendCandidateIDs.contains($0.id) }
        blendedCandidate = await aiProvider.generateBlendedCandidate(from: candidates, draft: draft)
        if blendedCandidate == nil {
            blendedCandidate = MockOnboardingAIProvider.blend(candidates: candidates, draft: draft)
        }
        step = .blendPreview
    }

    private func refreshHealthState() async {
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
        let snapshot = await planningHealthSnapshot()
        pendingHealthSnapshot = snapshot
        let fallback = AthleteBlueprintBuilder.build(
            intent: currentIntent,
            draft: draft,
            snapshot: snapshot
        )
        athleteBlueprint = await aiProvider.generateAthleteBlueprint(
            intent: currentIntent,
            draft: draft,
            snapshot: snapshot,
            fallback: fallback
        )
        step = .athleteBlueprint
    }

    private func completeOnboarding() {
        guard !isCompleting else { return }

        Task {
            isCompleting = true
            completionErrorMessage = nil
            defer { isCompleting = false }

            do {
                let healthSnapshot: HealthFeatureSnapshot?
                if let pendingHealthSnapshot {
                    healthSnapshot = pendingHealthSnapshot
                } else {
                    healthSnapshot = await planningHealthSnapshot()
                }
                let completedProfile = try await onboardingProfileStore.completeCurrentUserOnboarding(
                    intent: currentIntent,
                    draft: draft,
                    summary: currentSummary,
                    healthRequestState: healthRequestState
                )
                _ = try await planningAIProvider.bootstrapAfterOnboarding(
                    healthSnapshot: healthSnapshot,
                    deviceTimezone: TimeZone.current.identifier
                )
                onboardingProfileStore.useProfile(completedProfile)
                onComplete()
            } catch {
                completionErrorMessage = "Could not finish onboarding yet: \(error.localizedDescription)"
            }
        }
    }

    private func compactHealthSnapshot() async -> OnboardingAIHealthSnapshot? {
        guard let snapshot = await planningHealthSnapshot() else { return nil }
        return OnboardingAIHealthSnapshot(snapshot: snapshot)
    }

    private func planningHealthSnapshot() async -> HealthFeatureSnapshot? {
        guard healthRequestState == .connected else { return nil }

        do {
            return try await healthKitManager.fetchFeatureSnapshot()
        } catch {
            return nil
        }
    }
}

private enum OnboardingStep: Equatable {
    case intent
    case goalBrief
    case goalClarification
    case options
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
    case rhythm
    case friction
    case support
    case floor
    case generatingSummary
    case summary
    case health
    case generatingBlueprint
    case athleteBlueprint

    var isGenerating: Bool {
        switch self {
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingBlueprint:
            return true
        default:
            return false
        }
    }

    static func totalSegments(for intent: OnboardingIntent) -> Int {
        switch intent {
        case .stayConsistent:
            return 10
        case .concreteGoal:
            return 11
        case .findGoal:
            return 13
        }
    }

    func activeSegments(for intent: OnboardingIntent) -> Int {
        switch intent {
        case .stayConsistent:
            switch self {
            case .intent: return 1
            case .options: return 2
            case .anchor: return 3
            case .rhythm: return 4
            case .friction: return 5
            case .support: return 6
            case .floor, .generatingSummary: return 7
            case .summary: return 8
            case .health, .generatingBlueprint: return 9
            case .athleteBlueprint: return 10
            default: return 1
            }
        case .concreteGoal:
            switch self {
            case .intent: return 1
            case .goalBrief: return 2
            case .goalClarification: return 3
            case .options: return 4
            case .rhythm: return 5
            case .friction: return 6
            case .support: return 7
            case .floor, .generatingSummary: return 8
            case .summary: return 9
            case .health, .generatingBlueprint: return 10
            case .athleteBlueprint: return 11
            default: return 1
            }
        case .findGoal:
            switch self {
            case .intent: return 1
            case .options: return 2
            case .findDirection: return 3
            case .findChallenge: return 4
            case .findAvoids, .generatingCandidates: return 5
            case .goalCandidates, .editCandidate, .blendCandidates, .generatingBlend, .blendPreview: return 6
            case .rhythm: return 7
            case .friction: return 8
            case .support: return 9
            case .floor, .generatingSummary: return 10
            case .summary: return 11
            case .health, .generatingBlueprint: return 12
            case .athleteBlueprint: return 13
            default: return 1
            }
        }
    }

    var showsBackButton: Bool {
        self != .intent
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
    var blockers: Set<ConsistencyBlocker> = []
    var blockerNote = ""
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
    func generateSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) async -> OnboardingSummaryOutput
    func generateGoalCandidates(draft: ConsistencyOnboardingDraft) async -> [GoalCandidate]
    func generateBlendedCandidate(from candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) async -> GoalCandidate?
    func generateAthleteBlueprint(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        snapshot: HealthFeatureSnapshot?,
        fallback: AthleteBlueprintOutput
    ) async -> AthleteBlueprintOutput
}

private enum OnboardingAITask: String, Codable {
    case generateSummary = "generate_summary"
    case generateGoalCandidates = "generate_goal_candidates"
    case generateBlendedCandidate = "generate_blended_candidate"
    case generateAthleteBlueprint = "generate_athlete_blueprint"
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
    let blockers: [String]
    let blockerNote: String
    let supportStyle: String
    let badDayFloor: String
    let healthSnapshot: OnboardingAIHealthSnapshot?

    init(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft, healthSnapshot: OnboardingAIHealthSnapshot? = nil) {
        self.intent = intent.rawValue
        intentTitle = intent.title
        trainingOptions = draft.trainingOptions.enumerated().map { index, option in
            RankedTrainingOptionPayload(option: option, priority: index + 1)
        }
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
        blockers = draft.blockers.map(\.title).sorted()
        blockerNote = draft.blockerNote.trimmed
        supportStyle = draft.supportSummary
        badDayFloor = draft.floorSummary
        self.healthSnapshot = healthSnapshot
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
            blockers: draft.blockers.map(\.title).sorted(),
            blockerNote: draft.blockerNote.trimmed,
            supportStyle: draft.supportSummary,
            badDayFloor: draft.floorSummary,
            injuryNotes: draft.injuryNotes.trimmed
        )
        evidenceSummary = AthleteBlueprintAIEvidenceSummary(evidence: evidence)
        sectionSeeds = AthleteBlueprintAISectionSeeds(output: fallback)
        doNotClaim = [
            "Do not treat body composition, VO2 max, or recovery metrics as current truth unless a section seed explicitly includes them.",
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
    let blockers: [String]
    let blockerNote: String
    let supportStyle: String
    let badDayFloor: String
    let injuryNotes: String
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
    let historyFindings: [AthleteBlueprintAIHistoryFindingPayload]
    let goalFit: AthleteBlueprintAIGoalFitPayload

    func merged(with fallback: AthleteBlueprintOutput) -> AthleteBlueprintOutput {
        let findingCopy = Dictionary(uniqueKeysWithValues: historyFindings.map { ($0.id, $0) })

        return AthleteBlueprintOutput(
            coachRead: AthleteBlueprintCoachRead(
                text: coachRead.trimmed.isEmpty ? fallback.coachRead.text : coachRead.trimmed,
                detail: fallback.coachRead.detail
            ),
            archetype: AthleteBlueprintArchetype(
                label: athleteArchetype.label.trimmed.isEmpty ? fallback.archetype.label : athleteArchetype.label.trimmed,
                explanation: athleteArchetype.summary.trimmed.isEmpty ? fallback.archetype.explanation : athleteArchetype.summary.trimmed,
                detail: fallback.archetype.detail
            ),
            currentTrainingState: AthleteBlueprintCurrentState(
                label: currentTrainingState.label.trimmed.isEmpty ? fallback.currentTrainingState.label : currentTrainingState.label.trimmed,
                summary: currentTrainingState.summary.trimmed.isEmpty ? fallback.currentTrainingState.summary : currentTrainingState.summary.trimmed,
                detail: fallback.currentTrainingState.detail
            ),
            historyFindings: fallback.historyFindings.map { finding in
                guard let aiFinding = findingCopy[finding.id] else { return finding }
                return AthleteBlueprintFinding(
                    id: finding.id,
                    title: aiFinding.title.trimmed.isEmpty ? finding.title : aiFinding.title.trimmed,
                    summary: aiFinding.summary.trimmed.isEmpty ? finding.summary : aiFinding.summary.trimmed,
                    detail: finding.detail
                )
            },
            goalFit: AthleteBlueprintGoalFit(
                headline: goalFit.headline.trimmed.isEmpty ? fallback.goalFit.headline : goalFit.headline.trimmed,
                summary: goalFit.summary.trimmed.isEmpty ? fallback.goalFit.summary : goalFit.summary.trimmed,
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

    func generateSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) async -> OnboardingSummaryOutput {
        do {
            let request = OnboardingAIFunctionRequest(
                task: .generateSummary,
                context: OnboardingAICompactContext(intent: intent, draft: draft),
                candidates: nil
            )
            let response: OnboardingAISummaryFunctionResponse = try await invoke(request)
            return response.output.summaryOutput()
        } catch {
            return MockOnboardingAIProvider.fallbackSummary(intent: intent, draft: draft)
        }
    }

    func generateGoalCandidates(draft: ConsistencyOnboardingDraft) async -> [GoalCandidate] {
        do {
            let request = OnboardingAIFunctionRequest(
                task: .generateGoalCandidates,
                context: OnboardingAICompactContext(intent: .findGoal, draft: draft),
                candidates: nil
            )
            let response: OnboardingAIGoalCandidatesFunctionResponse = try await invoke(request)
            return response.output.candidates.map { $0.goalCandidate() }
        } catch {
            return MockOnboardingAIProvider.fallbackGoalCandidates(for: draft)
        }
    }

    func generateBlendedCandidate(from candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) async -> GoalCandidate? {
        do {
            let request = OnboardingAIFunctionRequest(
                task: .generateBlendedCandidate,
                context: OnboardingAICompactContext(intent: .findGoal, draft: draft),
                candidates: candidates.map(GoalCandidatePayload.init(candidate:))
            )
            let response: OnboardingAIBlendedCandidateFunctionResponse = try await invoke(request)
            return response.output.goalCandidate()
        } catch {
            return MockOnboardingAIProvider.blend(candidates: candidates, draft: draft)
        }
    }

    func generateAthleteBlueprint(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        snapshot: HealthFeatureSnapshot?,
        fallback: AthleteBlueprintOutput
    ) async -> AthleteBlueprintOutput {
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
            return fallback
        }
    }

    private func invoke<Response: Decodable>(_ request: OnboardingAIFunctionRequest) async throws -> Response {
        try await supabase.functions.invoke(
            "onboarding-ai",
            options: FunctionInvokeOptions(body: request)
        )
    }

    private func invoke<Response: Decodable>(_ request: AthleteBlueprintAIFunctionRequest) async throws -> Response {
        try await supabase.functions.invoke(
            "onboarding-ai",
            options: FunctionInvokeOptions(body: request)
        )
    }
}

private struct MockOnboardingAIProvider: OnboardingAIProvider {
    func generateSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) async -> OnboardingSummaryOutput {
        await mockDelay()
        return Self.fallbackSummary(intent: intent, draft: draft)
    }

    func generateGoalCandidates(draft: ConsistencyOnboardingDraft) async -> [GoalCandidate] {
        await mockDelay()
        return Self.fallbackGoalCandidates(for: draft)
    }

    func generateBlendedCandidate(from candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) async -> GoalCandidate? {
        await mockDelay()
        return Self.blend(candidates: candidates, draft: draft)
    }

    func generateAthleteBlueprint(
        intent: OnboardingIntent,
        draft: ConsistencyOnboardingDraft,
        snapshot: HealthFeatureSnapshot?,
        fallback: AthleteBlueprintOutput
    ) async -> AthleteBlueprintOutput {
        await mockDelay()
        return fallback
    }

    private func mockDelay() async {
        try? await Task.sleep(nanoseconds: 550_000_000)
    }

    static func fallbackSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) -> OnboardingSummaryOutput {
        switch intent {
        case .stayConsistent:
            return OnboardingSummaryOutput(
                readback: "You want a consistency-first rhythm that still feels realistic when life gets messy."
            )
        case .concreteGoal:
            return OnboardingSummaryOutput(
                readback: "You have a concrete target and want your training shaped around making steady progress toward it."
            )
        case .findGoal:
            return OnboardingSummaryOutput(
                readback: "You chose a goal direction that fits the kind of training you enjoy and the constraints you want respected."
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
                title: "8-week balanced athlete rhythm",
                rationale: "Build consistency with strength, low-impact cardio, and mobility without relying on running.",
                tracking: "Sessions completed, strength exposure, cardio exposure, recovery trend.",
                timeline: .eightWeeks,
                systemImage: "circle.lefthalf.filled"
            )
            : GoalCandidate(
                id: "endurance-base",
                title: wantsEndurance ? "Improve 10K readiness in 12 weeks" : "Build an 8-week aerobic base",
                rationale: "Give your week a clear endurance direction while keeping the plan light enough to repeat.",
                tracking: "Easy minutes, long-session confidence, consistency, recovery.",
                timeline: wantsEndurance ? .twelveWeeks : .eightWeeks,
                systemImage: "figure.run"
            )

        let second = wantsStrength
            ? GoalCandidate(
                id: "strength-base",
                title: "Build strength with one cardio anchor in 12 weeks",
                rationale: avoidsGym ? "Use simple strength sessions and one conditioning day without depending on a gym." : "Improve strength exposure while keeping enough cardio to feel athletic.",
                tracking: "Strength sessions, movement quality, conditioning touchpoint, soreness.",
                timeline: .twelveWeeks,
                systemImage: "figure.strengthtraining.traditional"
            )
            : GoalCandidate(
                id: "consistency-reset",
                title: "4-week consistency reset",
                rationale: "Make the win repeatable: never miss twice, keep one fallback, and reduce planning friction.",
                tracking: "Weekly sessions, bad-day floor used, skipped-week recovery.",
                timeline: .fourWeeks,
                systemImage: "arrow.triangle.2.circlepath"
            )

        let third = sportReady
            ? GoalCandidate(
                id: "sport-ready",
                title: "Build sport-ready conditioning in 8 weeks",
                rationale: "Build the engine, mobility, and strength base that make court or field sessions feel better.",
                tracking: "Conditioning, mobility, strength support, sport-session readiness.",
                timeline: .eightWeeks,
                systemImage: "sportscourt"
            )
            : GoalCandidate(
                id: "balanced-energy",
                title: "Feel-fit 8-week build",
                rationale: "Aim for more energy and capability without a hard event or all-or-nothing target.",
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
                title: "Balanced 8-week goal",
                rationale: "Blend consistency, strength, and easy cardio into a repeatable rhythm.",
                tracking: "Sessions, recovery, strength exposure, cardio exposure.",
                timeline: .eightWeeks,
                systemImage: "point.topleft.down.curvedto.point.bottomright.up"
            )
        }

        return GoalCandidate(
            id: "blended-\(candidates.map(\.id).joined(separator: "-"))",
            title: "Blended goal: \(candidates[0].title) + \(candidates[1].title)",
            rationale: "Keep the clearest target from \(candidates[0].title.lowercased()) while borrowing the support structure from \(candidates[1].title.lowercased()).",
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
        VStack(alignment: .leading, spacing: 12) {
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
            HStack(alignment: .top, spacing: 15) {
                HAYFIcon(systemImage: candidate.systemImage, isSelected: isSelected, size: 42, iconSize: 22)

                VStack(alignment: .leading, spacing: 8) {
                    Text(candidate.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(candidate.rationale)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(HAYFColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Tracks: \(candidate.tracking)")
                        .font(.system(size: 12, weight: .medium))
                        .lineSpacing(3)
                        .foregroundStyle(HAYFColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                switch selectionStyle {
                case .single:
                    RadioDot(isSelected: isSelected)
                case .multiple:
                    CheckmarkBox(isSelected: isSelected)
                }
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

private struct AthleteBlueprintOutput {
    let coachRead: AthleteBlueprintCoachRead
    let archetype: AthleteBlueprintArchetype
    let currentTrainingState: AthleteBlueprintCurrentState
    let historyFindings: [AthleteBlueprintFinding]
    let goalFit: AthleteBlueprintGoalFit
}

private struct AthleteBlueprintCoachRead {
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
    let confidence: String
    let observationWindow: String
    let evidence: [String]
    let caveat: String?
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
        let historyFindings = buildHistoryFindings(evidence: evidence)
        let goalFit = buildGoalFit(goal: goal, draft: draft, evidence: evidence)
        let coachRead = buildCoachRead(
            archetype: archetype,
            currentState: currentState,
            goalFit: goalFit,
            evidence: evidence
        )

        return AthleteBlueprintOutput(
            coachRead: coachRead,
            archetype: archetype,
            currentTrainingState: currentState,
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
                horizonWeeks: goalHorizonWeeks(from: draft.goalTimeline),
                category: category(for: draft.goalSummary)
            )
        case .findGoal:
            return AthleteBlueprintGoal(
                displayText: normalizedGoalDisplayText(from: draft.goalSummary),
                horizonWeeks: draft.chosenGoal?.timeline.weeks ?? goalHorizonWeeks(from: draft.goalTimeline),
                category: category(for: draft.goalSummary)
            )
        }
    }

    private static func buildCoachRead(
        archetype: AthleteBlueprintArchetype,
        currentState: AthleteBlueprintCurrentState,
        goalFit: AthleteBlueprintGoalFit,
        evidence: AthleteBlueprintEvidence
    ) -> AthleteBlueprintCoachRead {
        let text: String
        if evidence.hasWorkoutHistory {
            text = "\(archetype.explanation) \(currentState.summary) \(goalFit.summary)"
        } else {
            text = "HAYF has a clear picture of what you want from training, but not enough Apple Health history yet to make strong claims about your past patterns. For now, the read leans on what you told us and will sharpen as you train."
        }

        return AthleteBlueprintCoachRead(
            text: text,
            detail: AthleteBlueprintDetail(
                id: "coach_read",
                title: "Coach's read",
                summary: "This is the synthesis HAYF uses before it creates the strategy.",
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
            let friendlyLabel: String
            switch label {
            case "Hybrid athlete":
                friendlyLabel = "Hybrid Athlete"
            case "Strength-led":
                friendlyLabel = "Strength-Led Athlete"
            case "Endurance-led":
                friendlyLabel = "Endurance-Led Athlete"
            default:
                friendlyLabel = titleCase(label)
            }

            let explanation = "Your history is led by \(joinedList(evidence.dominantModalities)), which makes you a \(friendlyLabel.lowercased())."
            return AthleteBlueprintArchetype(
                label: friendlyLabel,
                explanation: explanation,
                detail: AthleteBlueprintDetail(
                    id: "athlete_archetype",
                    title: "Athlete type",
                    summary: "This label is based on repeated tracked behavior, not on the goal you selected today.",
                    confidence: evidence.dominantModalities.count >= 2 ? "High" : "Medium",
                    observationWindow: "6 years of imported workouts",
                    evidence: [
                        "Dominant modalities: \(joinedList(evidence.dominantModalities)).",
                        "\(evidence.totalWorkouts) imported workouts were available for this read."
                    ],
                    caveat: nil
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
                summary: "This label currently comes from what you selected in onboarding, not from a repeated tracked pattern yet.",
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
        let evidenceLines: [String]

        if sevenDayMinutes == 0, ninetyDayMinutes > 0 {
            label = "Rebuilding after a lull"
            summary = "Your history shows a usable base, but the last week has gone quiet. HAYF should treat this as re-entry rather than a blank slate."
            evidenceLines = [
                "Last 7 days: no tracked training minutes.",
                "Last 90 days: \(Int(ninetyDayMinutes.rounded())) tracked training minutes."
            ]
        } else if recentVsBaseline < 0.65, twentyEightDayMinutes > 0 {
            label = "Recent rhythm has dipped"
            summary = "Your current week is lighter than your recent baseline, which suggests HAYF should protect momentum before it adds ambition."
            evidenceLines = [
                "Last 7 days: \(Int(sevenDayMinutes.rounded())) minutes.",
                "Typical recent week from the last 28 days: about \(Int(weeklyAverage28.rounded())) minutes."
            ]
        } else if recentVsBaseline > 1.35, weeklyAverage28 > 0 {
            label = "Building momentum"
            summary = "Your most recent week is running above your recent baseline, which suggests real momentum but also a reason to keep the first strategy controlled."
            evidenceLines = [
                "Last 7 days: \(Int(sevenDayMinutes.rounded())) minutes.",
                "Typical recent week from the last 28 days: about \(Int(weeklyAverage28.rounded())) minutes."
            ]
        } else {
            label = "Stable recent rhythm"
            summary = "Your recent training load is close to your recent baseline, so HAYF can start from continuity rather than repair."
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
                summary: "This is a present-state read built from recent load, not from your all-time history.",
                confidence: twentyEightDayMinutes > 0 ? "High" : "Medium",
                observationWindow: "Last 7 days vs prior 28-day baseline",
                evidence: evidenceLines,
                caveat: nil
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

        if evidence.strengthWorkouts90Days > 0 {
            findings.append(
                AthleteBlueprintFinding(
                    id: "strength_anchor",
                    title: "Strength is a real anchor",
                    summary: "You logged \(evidence.strengthWorkouts90Days) strength sessions in the last 90 days.",
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
                    summary: "Your longest active streak is \(evidence.longestActiveWeekStreak) weeks.",
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
            findings.append(
                AthleteBlueprintFinding(
                    id: "long_session_tolerance",
                    title: "You can handle one longer session",
                    summary: "Your history includes a \(Int(longest.durationMinutes.rounded()))-minute \(longest.modality) session.",
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
                    summary: "Historically, \(strongestMonth.label) carries your highest training volume.",
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
        case .bodyComposition, .sportPerformance, .generalFitness, .custom:
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
                summary: "This checks whether the goal and the training path you chose make sense together; it does not require your past history to already look like the goal.",
                confidence: evidence.hasWorkoutHistory ? "High" : "Medium",
                observationWindow: "Goal + onboarding + available athlete evidence",
                evidence: result.supports + result.gaps + result.detailEvidence,
                caveat: nil
            )
        )
    }

    private static func goalHorizonWeeks(from timeline: GoalTimeline?) -> Int {
        timeline?.weeks ?? 12
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
        if normalized.contains("body fat") || normalized.contains("lean") || normalized.contains("weight") || normalized.contains("composition") {
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

    func windowMinutes(_ label: String) -> Double {
        snapshot?.workoutLedger.windows.first { $0.window == label }?.totalMinutes ?? 0
    }

    func windowWorkouts(_ label: String) -> Int {
        snapshot?.workoutLedger.windows.first { $0.window == label }?.workouts ?? 0
    }
}

private struct AthleteBlueprintSummaryRow: View {
    let systemImage: String
    let eyebrow: String
    let title: String
    let summary: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
                    .padding(.top, 20)
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
        .buttonStyle(.plain)
    }
}

private struct AthleteBlueprintFindingRow: View {
    let finding: AthleteBlueprintFinding
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
                    .padding(.top, 8)
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
        .buttonStyle(.plain)
    }
}

private struct AthleteBlueprintGoalFitCard: View {
    let goalFit: AthleteBlueprintGoalFit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(goalFit.headline)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HAYFColor.muted)
                }

                Text(goalFit.summary)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                BlueprintEvidenceHint()
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
        .buttonStyle(.plain)
    }
}

private struct BlueprintEvidenceHint: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Why HAYF thinks this")
                .font(.system(size: 12, weight: .medium))

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(HAYFColor.muted)
    }
}

private struct AthleteBlueprintDetailSheet: View {
    let detail: AthleteBlueprintDetail

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
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
                }

                HStack(spacing: 10) {
                    BlueprintMetaPill(label: "Confidence", value: detail.confidence)
                    BlueprintMetaPill(label: "Window", value: detail.observationWindow)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(detail.evidence, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(HAYFColor.orange)
                                .frame(width: 7, height: 7)
                                .padding(.top, 7)

                            Text(item)
                                .font(.system(size: 15, weight: .regular))
                                .lineSpacing(4)
                                .foregroundStyle(HAYFColor.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(HAYFColor.primary)
                .frame(width: size, height: size)

            Circle()
                .fill(isSelected ? HAYFColor.orange : HAYFColor.borderStrong)
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: -size * 0.08, y: -size * 0.08)
        }
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
    OnboardingFlowView(onboardingProfileStore: OnboardingProfileStore()) {}
}
