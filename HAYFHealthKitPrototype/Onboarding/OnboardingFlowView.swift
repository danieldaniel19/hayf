import SwiftUI
import Supabase

struct OnboardingFlowView: View {
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .intent
    @State private var draft = ConsistencyOnboardingDraft()
    @State private var selectedIntent: OnboardingIntent?
    @State private var summaryOutput: OnboardingSummaryOutput?
    @State private var rhythmOutput: OnboardingRhythmOutput?
    @State private var goalCandidates: [GoalCandidate] = []
    @State private var selectedGoalCandidateID: String?
    @State private var editingGoalText = ""
    @State private var blendCandidateIDs: Set<String> = []
    @State private var blendedCandidate: GoalCandidate?
    @State private var healthRequestState: HealthRequestState = .idle
    @State private var completionErrorMessage: String?
    @State private var isCompleting = false

    private let healthKitManager = HealthKitManager()
    private let aiProvider: any OnboardingAIProvider = RemoteOnboardingAIProvider()
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
        .task(id: step) {
            switch step {
            case .health:
                await refreshHealthState()
            case .generatingSummary:
                await generateSummary()
            case .generatingRhythm:
                await generateFirstRhythm()
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
        case .generatingRhythm:
            loadingScreen(title: "Building your first rhythm.", copy: "HAYF is matching the plan to your goal, constraints, and bad-day floor.")
        case .firstRhythm:
            firstRhythmScreen
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
                copy: selectedIntent == .concreteGoal ? "Pick the training options that can support your goal without crowding it out." : "Choose what fits your life, not just what you like."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TrainingOption.allCases) { option in
                    SelectableTile(
                        title: option.title,
                        systemImage: option.systemImage,
                        isSelected: draft.trainingOptions.contains(option)
                    ) {
                        draft.trainingOptions.toggle(option)
                    }
                }
            }

            Text("You can change this anytime.")
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
                copy: "A few details help HAYF layer the goal onto a rhythm you can actually sustain."
            )

            OptionGroup(title: "Where are you starting from?") {
                VStack(spacing: 10) {
                    ForEach(GoalBaseline.allCases) { baseline in
                        DetailedSelectableRow(
                            title: baseline.title,
                            subtitle: baseline.subtitle,
                            systemImage: baseline.systemImage,
                            isSelected: draft.goalBaseline == baseline
                        ) {
                            draft.goalBaseline = baseline
                        }
                    }
                }
            }

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
                title: "Any useful marker?",
                placeholder: "Current long run, recent race time, current lift, weekly mileage, or anything HAYF should know...",
                text: $draft.goalMarker,
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
                placeholder: "Build an 8-week balanced athlete goal with 3 sessions per week...",
                text: $editingGoalText,
                characterLimit: 320
            )
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
                copy: "Edit anything that feels off."
            )

            VStack(spacing: 10) {
                ForEach(currentSummary.rows) { row in
                    SummaryRow(systemImage: row.systemImage, label: row.label, value: row.value)
                }
            }

            if let realismNote = currentSummary.realismNote {
                CoachNote(systemImage: "exclamationmark.triangle", text: realismNote)
            }

            if let coachNote = currentSummary.coachNote {
                CoachNote(text: coachNote)
            }

            PersonalizationNote()
        }
    }

    private var healthScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                title: "Connect\nApple Health.",
                copy: "HAYF uses recent activity, workouts, sleep, recovery signals, and basic body metrics to coach around how ready you are today."
            )

            VStack(alignment: .leading, spacing: 0) {
                Text("WHAT HAYF USES")
                    .font(.system(size: 10, weight: .medium))
                    .kerning(1.2)
                    .foregroundStyle(HAYFColor.secondary)
                    .padding(.bottom, 14)

                HealthUseRow(systemImage: "figure.strengthtraining.traditional", title: "Recent workouts", subtitle: "Workout types, duration, and training consistency.")
                HealthUseRow(systemImage: "figure.walk", title: "Daily movement", subtitle: "Steps, active energy, exercise minutes, and distance.")
                HealthUseRow(systemImage: "moon", title: "Sleep and recovery", subtitle: "Sleep timing, resting heart rate, HRV, and heart-rate trends.")
                HealthUseRow(systemImage: "heart", title: "Cardio and body context", subtitle: "Cardio fitness, height, and body mass.", showsDivider: false)
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
                    Text("Used to personalize recommendations.")
                    Text("You stay in control of Health permissions.")
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
        }
    }

    private var firstRhythmScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingIntro(
                eyebrow: "SETUP COMPLETE",
                title: "Your first rhythm\nis ready.",
                copy: currentRhythm.copy
            )

            VStack(spacing: 10) {
                SummaryRow(systemImage: "target", label: currentRhythm.focusLabel, value: currentRhythm.focusValue)
                SummaryRow(systemImage: "bolt.heart", label: "Reason", value: currentRhythm.reasonValue)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("WEEKLY RHYTHM PREVIEW")
                    .font(.system(size: 10, weight: .medium))
                    .kerning(1.2)
                    .foregroundStyle(HAYFColor.secondary)

                ForEach(currentRhythm.rows) { row in
                    RhythmPreviewRow(day: row.day, workout: row.workout, duration: row.duration)
                }
            }
            .padding(18)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }

            CoachNote(text: currentRhythm.coachNote)

            if let completionErrorMessage {
                Text(completionErrorMessage)
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(HAYFColor.error)
                    .fixedSize(horizontal: false, vertical: true)
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
                Button("Adjust answers") {
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
            } else if step == .health {
                Button("Set up later") {
                    step = .generatingRhythm
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.secondary)
                .buttonStyle(.plain)
            } else if step == .firstRhythm {
                Button("Edit setup") {
                    step = .summary
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingRhythm:
            return "Working"
        case .summary:
            return "Looks right"
        case .health:
            if healthRequestState == .connected || healthRequestState == .unavailable {
                return "Continue"
            }
            return "Connect Apple Health"
        case .firstRhythm:
            return "Start with this rhythm"
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
            return draft.goalBaseline != nil && draft.goalTimeline != nil && draft.goalPriority != nil
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
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingRhythm:
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
            }
            step = .rhythm
        case .editCandidate:
            draft.chosenGoal = GoalCandidate(
                id: "edited-goal",
                title: editingGoalText.trimmed,
                rationale: "Edited by you from HAYF's suggested direction.",
                tracking: "HAYF will track consistency, recovery, and the goal markers you choose.",
                systemImage: "pencil"
            )
            step = .rhythm
        case .blendCandidates:
            step = .generatingBlend
        case .blendPreview:
            draft.chosenGoal = blendedCandidate
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
                step = .generatingRhythm
            } else {
                requestHealthAccess()
            }
        case .generatingCandidates, .generatingBlend, .generatingRhythm:
            break
        case .firstRhythm:
            completeOnboarding()
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
        case .generatingRhythm:
            step = .health
        case .firstRhythm:
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
        if step == .firstRhythm {
            return "Ready"
        }

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

    private var currentRhythm: OnboardingRhythmOutput {
        rhythmOutput ?? MockOnboardingAIProvider.fallbackRhythm(intent: currentIntent, draft: draft)
    }

    private var summaryEditStep: OnboardingStep {
        switch currentIntent {
        case .stayConsistent:
            return .anchor
        case .concreteGoal:
            return .goalBrief
        case .findGoal:
            return .goalCandidates
        }
    }

    private func resetGeneratedOutputs() {
        summaryOutput = nil
        rhythmOutput = nil
        goalCandidates = []
        selectedGoalCandidateID = nil
        editingGoalText = ""
        blendCandidateIDs = []
        blendedCandidate = nil
    }

    private func prepareCandidateEdit() {
        guard let selectedCandidate else { return }
        editingGoalText = "\(selectedCandidate.title): \(selectedCandidate.rationale)"
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

    private func generateFirstRhythm() async {
        let output = await aiProvider.generateFirstRhythm(intent: currentIntent, draft: draft, healthSnapshot: await compactHealthSnapshot())
        rhythmOutput = output.isValid ? output : MockOnboardingAIProvider.fallbackRhythm(intent: currentIntent, draft: draft)
        step = .firstRhythm
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
                step = .generatingRhythm
            } catch HealthKitError.healthDataUnavailable {
                healthRequestState = .unavailable
            } catch {
                healthRequestState = .failed(error.localizedDescription)
            }
        }
    }

    private func completeOnboarding() {
        guard !isCompleting else { return }

        Task {
            isCompleting = true
            completionErrorMessage = nil
            defer { isCompleting = false }

            do {
                try await onboardingProfileStore.completeCurrentUserOnboarding(
                    intent: currentIntent,
                    draft: draft,
                    summary: currentSummary,
                    rhythm: currentRhythm,
                    healthRequestState: healthRequestState
                )
                onComplete()
            } catch {
                completionErrorMessage = "Could not save onboarding yet: \(error.localizedDescription)"
            }
        }
    }

    private func compactHealthSnapshot() async -> OnboardingAIHealthSnapshot? {
        guard healthRequestState == .connected else { return nil }

        do {
            let snapshot = try await healthKitManager.fetchSnapshot()
            return OnboardingAIHealthSnapshot(snapshot: snapshot)
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
    case generatingRhythm
    case firstRhythm

    var isGenerating: Bool {
        switch self {
        case .generatingSummary, .generatingCandidates, .generatingBlend, .generatingRhythm:
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
            case .health, .generatingRhythm: return 9
            case .firstRhythm: return 10
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
            case .health, .generatingRhythm: return 10
            case .firstRhythm: return 11
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
            case .health, .generatingRhythm: return 12
            case .firstRhythm: return 13
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
    var trainingOptions: Set<TrainingOption> = []
    var motivationAnchors: Set<MotivationAnchor> = []
    var motivationNote = ""
    var goalBrief = ""
    var goalMarker = ""
    var goalBaseline: GoalBaseline?
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

    var trainingSummary: String {
        summary(for: trainingOptions.map(\.title), fallback: "Not set")
    }

    var rhythmSummary: String {
        guard let frequency, let sessionLength else { return "Not set" }
        return "\(frequency.summary), usually \(sessionLength.title)"
    }

    var blockerSummary: String {
        summary(for: blockers.map(\.title), fallback: "Not set")
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

    var baselineSummary: String {
        goalBaseline?.title ?? "Not set"
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

    var firstRhythmCoachNote: String {
        let blockerText = blockerSummary == "Not set" ? "busy weeks" : blockerSummary.lowercased()
        let floorText = badDayFloor?.shortTitle ?? "fallback"
        return "Because \(blockerText) are your main risks, HAYF will protect your \(floorText) instead of letting the week go all-or-nothing."
    }

    private func summary(for values: [String], fallback: String) -> String {
        let sortedValues = values.sorted()
        guard !sortedValues.isEmpty else { return fallback }
        return sortedValues.prefix(3).joined(separator: ", ") + (sortedValues.count > 3 ? " +" : "")
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
    func generateFirstRhythm(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft, healthSnapshot: OnboardingAIHealthSnapshot?) async -> OnboardingRhythmOutput
    func generateGoalCandidates(draft: ConsistencyOnboardingDraft) async -> [GoalCandidate]
    func generateBlendedCandidate(from candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) async -> GoalCandidate?
}

private enum OnboardingAITask: String, Codable {
    case generateSummary = "generate_summary"
    case generateFirstRhythm = "generate_first_rhythm"
    case generateGoalCandidates = "generate_goal_candidates"
    case generateBlendedCandidate = "generate_blended_candidate"
}

private struct OnboardingAIHealthSnapshot: Codable {
    let sleepHoursLastNight: Double?
    let workoutsLast7Days: Int
    let averageStepsLast7Days: Double?
    let heightCentimeters: Double?
    let bodyMassKilograms: Double?

    init(snapshot: HealthSnapshot) {
        sleepHoursLastNight = snapshot.sleepHoursLastNight
        workoutsLast7Days = snapshot.workoutsLast7Days
        averageStepsLast7Days = snapshot.averageStepsLast7Days
        heightCentimeters = snapshot.heightCentimeters
        bodyMassKilograms = snapshot.bodyMassKilograms
    }
}

private struct OnboardingAICompactContext: Codable {
    let intent: String
    let intentTitle: String
    let trainingOptions: [String]
    let motivationAnchors: [String]
    let motivationNote: String
    let goalBrief: String
    let goalMarker: String
    let goalBaseline: String
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
        trainingOptions = draft.trainingOptions.map(\.title).sorted()
        motivationAnchors = draft.motivationAnchors.map(\.title).sorted()
        motivationNote = draft.motivationNote.trimmed
        goalBrief = draft.goalBrief.trimmed
        goalMarker = draft.goalMarker.trimmed
        goalBaseline = draft.baselineSummary
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
    let systemImage: String

    init(candidate: GoalCandidate) {
        id = candidate.id
        title = candidate.title
        rationale = candidate.rationale
        tracking = candidate.tracking
        systemImage = candidate.systemImage
    }

    func goalCandidate() -> GoalCandidate {
        GoalCandidate(
            id: id,
            title: title,
            rationale: rationale,
            tracking: tracking,
            systemImage: systemImage
        )
    }
}

private struct OnboardingAIFunctionRequest: Codable {
    let task: OnboardingAITask
    let context: OnboardingAICompactContext
    let candidates: [GoalCandidatePayload]?
}

private struct OnboardingAISummaryFunctionResponse: Decodable {
    let output: OnboardingAISummaryPayload
}

private struct OnboardingAIRhythmFunctionResponse: Decodable {
    let output: OnboardingAIRhythmPayload
}

private struct OnboardingAIGoalCandidatesFunctionResponse: Decodable {
    let output: OnboardingAIGoalCandidatesPayload
}

private struct OnboardingAIBlendedCandidateFunctionResponse: Decodable {
    let output: GoalCandidatePayload
}

private struct OnboardingAISummaryPayload: Codable {
    let rows: [SummaryItemPayload]
    let coachNote: String
    let realismNote: String

    init(summary: OnboardingSummaryOutput) {
        rows = summary.rows.map(SummaryItemPayload.init(item:))
        coachNote = summary.coachNote ?? ""
        realismNote = summary.realismNote ?? ""
    }

    func summaryOutput() -> OnboardingSummaryOutput {
        OnboardingSummaryOutput(
            rows: rows.map { $0.summaryItem() },
            coachNote: coachNote.trimmed.nilIfEmpty,
            realismNote: realismNote.trimmed.nilIfEmpty
        )
    }
}

private struct SummaryItemPayload: Codable {
    let systemImage: String
    let label: String
    let value: String

    init(item: SummaryItem) {
        systemImage = item.systemImage
        label = item.label
        value = item.value
    }

    func summaryItem() -> SummaryItem {
        SummaryItem(systemImage: systemImage, label: label, value: value)
    }
}

private struct OnboardingAIRhythmPayload: Codable {
    let copy: String
    let focusLabel: String
    let focusValue: String
    let reasonValue: String
    let rows: [RhythmItemPayload]
    let coachNote: String

    init(rhythm: OnboardingRhythmOutput) {
        copy = rhythm.copy
        focusLabel = rhythm.focusLabel
        focusValue = rhythm.focusValue
        reasonValue = rhythm.reasonValue
        rows = rhythm.rows.map(RhythmItemPayload.init(item:))
        coachNote = rhythm.coachNote
    }

    func rhythmOutput() -> OnboardingRhythmOutput {
        OnboardingRhythmOutput(
            copy: copy,
            focusLabel: focusLabel,
            focusValue: focusValue,
            reasonValue: reasonValue,
            rows: rows.map { $0.rhythmItem() },
            coachNote: coachNote
        )
    }
}

private struct RhythmItemPayload: Codable {
    let day: String
    let workout: String
    let duration: String

    init(item: RhythmItem) {
        day = item.day
        workout = item.workout
        duration = item.duration
    }

    func rhythmItem() -> RhythmItem {
        RhythmItem(day: day, workout: workout, duration: duration)
    }
}

private struct OnboardingAIGoalCandidatesPayload: Codable {
    let candidates: [GoalCandidatePayload]
}

private struct OnboardingSummaryOutput {
    let rows: [SummaryItem]
    let coachNote: String?
    let realismNote: String?

    var isValid: Bool {
        !rows.isEmpty && rows.allSatisfy { !$0.label.trimmed.isEmpty && !$0.value.trimmed.isEmpty }
    }
}

private struct SummaryItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let label: String
    let value: String
}

private struct OnboardingRhythmOutput {
    let copy: String
    let focusLabel: String
    let focusValue: String
    let reasonValue: String
    let rows: [RhythmItem]
    let coachNote: String

    var isValid: Bool {
        !copy.trimmed.isEmpty && !rows.isEmpty && !coachNote.trimmed.isEmpty
    }
}

private struct RhythmItem: Identifiable {
    let id = UUID()
    let day: String
    let workout: String
    let duration: String
}

private struct GoalCandidate: Identifiable, Equatable {
    let id: String
    let title: String
    let rationale: String
    let tracking: String
    let systemImage: String
}

private struct RemoteOnboardingAIProvider: OnboardingAIProvider {
    private let supabase = SupabaseClientProvider.shared

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

    func generateFirstRhythm(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft, healthSnapshot: OnboardingAIHealthSnapshot?) async -> OnboardingRhythmOutput {
        do {
            let request = OnboardingAIFunctionRequest(
                task: .generateFirstRhythm,
                context: OnboardingAICompactContext(intent: intent, draft: draft, healthSnapshot: healthSnapshot),
                candidates: nil
            )
            let response: OnboardingAIRhythmFunctionResponse = try await invoke(request)
            return response.output.rhythmOutput()
        } catch {
            return MockOnboardingAIProvider.fallbackRhythm(intent: intent, draft: draft)
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

    private func invoke<Response: Decodable>(_ request: OnboardingAIFunctionRequest) async throws -> Response {
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

    func generateFirstRhythm(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft, healthSnapshot: OnboardingAIHealthSnapshot?) async -> OnboardingRhythmOutput {
        await mockDelay()
        return Self.fallbackRhythm(intent: intent, draft: draft)
    }

    func generateGoalCandidates(draft: ConsistencyOnboardingDraft) async -> [GoalCandidate] {
        await mockDelay()
        return Self.fallbackGoalCandidates(for: draft)
    }

    func generateBlendedCandidate(from candidates: [GoalCandidate], draft: ConsistencyOnboardingDraft) async -> GoalCandidate? {
        await mockDelay()
        return Self.blend(candidates: candidates, draft: draft)
    }

    private func mockDelay() async {
        try? await Task.sleep(nanoseconds: 550_000_000)
    }

    static func fallbackSummary(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) -> OnboardingSummaryOutput {
        switch intent {
        case .stayConsistent:
            return OnboardingSummaryOutput(
                rows: [
                    SummaryItem(systemImage: "target", label: "Intent", value: "Stay consistent and balanced"),
                    SummaryItem(systemImage: "bolt.heart", label: "Anchor", value: draft.motivationSummary),
                    SummaryItem(systemImage: "figure.strengthtraining.traditional", label: "Training", value: draft.trainingSummary),
                    SummaryItem(systemImage: "timer", label: "Rhythm", value: draft.rhythmSummary),
                    SummaryItem(systemImage: "exclamationmark.triangle", label: "Risks", value: draft.blockerSummary),
                    SummaryItem(systemImage: "figure.cooldown", label: "Support", value: draft.supportSummary),
                    SummaryItem(systemImage: "arrow.down.circle", label: "Floor", value: draft.floorSummary)
                ],
                coachNote: "Your setup points to a consistency-first rhythm: enough structure to remove decisions, with enough flexibility to protect the week when energy or work gets messy.",
                realismNote: nil
            )
        case .concreteGoal:
            return OnboardingSummaryOutput(
                rows: [
                    SummaryItem(systemImage: "flag", label: "Goal", value: concreteGoalTitle(from: draft)),
                    SummaryItem(systemImage: "calendar", label: "Timeline", value: draft.timelineSummary),
                    SummaryItem(systemImage: "chart.line.uptrend.xyaxis", label: "Baseline", value: draft.baselineSummary),
                    SummaryItem(systemImage: "arrow.left.arrow.right", label: "Tradeoff", value: draft.prioritySummary),
                    SummaryItem(systemImage: "figure.strengthtraining.traditional", label: "Support work", value: draft.trainingSummary),
                    SummaryItem(systemImage: "timer", label: "Rhythm", value: draft.rhythmSummary),
                    SummaryItem(systemImage: "arrow.down.circle", label: "Floor", value: draft.floorSummary)
                ],
                coachNote: "HAYF will treat the goal as the spine, then layer strength, mobility, and recovery around it instead of letting every week become a fresh planning problem.",
                realismNote: concreteRealismNote(for: draft)
            )
        case .findGoal:
            return OnboardingSummaryOutput(
                rows: [
                    SummaryItem(systemImage: "target", label: "Chosen goal", value: draft.goalSummary),
                    SummaryItem(systemImage: "sparkle", label: "Direction", value: draft.directionSummary),
                    SummaryItem(systemImage: "flag", label: "Challenge", value: draft.challengeSummary),
                    SummaryItem(systemImage: "nosign", label: "Avoid", value: draft.avoidsSummary),
                    SummaryItem(systemImage: "timer", label: "Rhythm", value: draft.rhythmSummary),
                    SummaryItem(systemImage: "exclamationmark.triangle", label: "Risks", value: draft.blockerSummary),
                    SummaryItem(systemImage: "arrow.down.circle", label: "Floor", value: draft.floorSummary)
                ],
                coachNote: "The selected goal gives HAYF direction without turning the setup into a rigid performance project.",
                realismNote: nil
            )
        }
    }

    static func fallbackRhythm(intent: OnboardingIntent, draft: ConsistencyOnboardingDraft) -> OnboardingRhythmOutput {
        let duration = draft.sessionLength?.previewDuration ?? "45 min"

        switch intent {
        case .stayConsistent:
            return OnboardingRhythmOutput(
                copy: "HAYF will keep this flexible and adapt day by day.",
                focusLabel: "Intent",
                focusValue: "Stay consistent and balanced",
                reasonValue: draft.motivationSummary,
                rows: [
                    RhythmItem(day: "Day 1", workout: "Strength", duration: duration),
                    RhythmItem(day: "Day 2", workout: "Easy cardio or sport", duration: "30-45 min"),
                    RhythmItem(day: "Day 3", workout: "Mobility + conditioning", duration: "20-40 min")
                ],
                coachNote: draft.firstRhythmCoachNote
            )
        case .concreteGoal:
            let isRunningGoal = containsAny(draft.goalBrief, values: ["half", "marathon", "run", "5k", "10k"])
            return OnboardingRhythmOutput(
                copy: "HAYF will keep the goal visible without letting it crowd out recovery.",
                focusLabel: "Goal",
                focusValue: concreteGoalTitle(from: draft),
                reasonValue: draft.prioritySummary,
                rows: isRunningGoal ? [
                    RhythmItem(day: "Day 1", workout: "Goal run: steady aerobic build", duration: duration),
                    RhythmItem(day: "Day 2", workout: "Strength maintenance", duration: "30-45 min"),
                    RhythmItem(day: "Day 3", workout: "Quality run or progression", duration: duration),
                    RhythmItem(day: "Day 4", workout: "Long easy run", duration: "60+ min")
                ] : [
                    RhythmItem(day: "Day 1", workout: "Goal practice", duration: duration),
                    RhythmItem(day: "Day 2", workout: "Support strength", duration: "30-45 min"),
                    RhythmItem(day: "Day 3", workout: "Conditioning + mobility", duration: "30-45 min")
                ],
                coachNote: "If the week compresses, HAYF will protect the goal-specific session and your bad-day floor before adding extra volume."
            )
        case .findGoal:
            return OnboardingRhythmOutput(
                copy: "HAYF will start with a light goal rhythm and adjust once real training data comes in.",
                focusLabel: "Goal",
                focusValue: draft.goalSummary,
                reasonValue: draft.directionSummary,
                rows: [
                    RhythmItem(day: "Day 1", workout: "Goal session", duration: duration),
                    RhythmItem(day: "Day 2", workout: "Strength or skill support", duration: "30-45 min"),
                    RhythmItem(day: "Day 3", workout: "Easy aerobic base", duration: "30-45 min"),
                    RhythmItem(day: "Optional", workout: draft.badDayFloor?.title ?? "Bad-day floor", duration: "10-20 min")
                ],
                coachNote: "This gives you something to work toward without making every week pass/fail."
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
                systemImage: "circle.lefthalf.filled"
            )
            : GoalCandidate(
                id: "endurance-base",
                title: wantsEndurance ? "10K-ready endurance base" : "8-week aerobic base",
                rationale: "Give your week a clear endurance direction while keeping the plan light enough to repeat.",
                tracking: "Easy minutes, long-session confidence, consistency, recovery.",
                systemImage: "figure.run"
            )

        let second = wantsStrength
            ? GoalCandidate(
                id: "strength-base",
                title: "Strength base with one cardio anchor",
                rationale: avoidsGym ? "Use simple strength sessions and one conditioning day without depending on a gym." : "Improve strength exposure while keeping enough cardio to feel athletic.",
                tracking: "Strength sessions, movement quality, conditioning touchpoint, soreness.",
                systemImage: "figure.strengthtraining.traditional"
            )
            : GoalCandidate(
                id: "consistency-reset",
                title: "4-week consistency reset",
                rationale: "Make the win repeatable: never miss twice, keep one fallback, and reduce planning friction.",
                tracking: "Weekly sessions, bad-day floor used, skipped-week recovery.",
                systemImage: "arrow.triangle.2.circlepath"
            )

        let third = sportReady
            ? GoalCandidate(
                id: "sport-ready",
                title: "Sport-ready conditioning block",
                rationale: "Build the engine, mobility, and strength base that make court or field sessions feel better.",
                tracking: "Conditioning, mobility, strength support, sport-session readiness.",
                systemImage: "sportscourt"
            )
            : GoalCandidate(
                id: "balanced-energy",
                title: "Feel-fit 8-week build",
                rationale: "Aim for more energy and capability without a hard event or all-or-nothing target.",
                tracking: "Energy, consistency, cardio exposure, strength exposure.",
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
                systemImage: "point.topleft.down.curvedto.point.bottomright.up"
            )
        }

        return GoalCandidate(
            id: "blended-\(candidates.map(\.id).joined(separator: "-"))",
            title: "Blended goal: \(candidates[0].title) + \(candidates[1].title)",
            rationale: "Keep the clearest target from \(candidates[0].title.lowercased()) while borrowing the support structure from \(candidates[1].title.lowercased()).",
            tracking: "\(candidates[0].tracking) Also watch: \(candidates[1].tracking.lowercased())",
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

    private static func concreteRealismNote(for draft: ConsistencyOnboardingDraft) -> String {
        let goal = draft.goalBrief.lowercased()
        if containsAny(goal, values: ["half", "marathon"]) && draft.goalTimeline == .fourWeeks {
            return "A half marathon push on a 4-week timeline may be tight. HAYF will bias toward finishing healthy and building the next block instead of forcing risky volume."
        }

        if containsAny(goal, values: ["sub 2", "sub-2", "under 2"]) {
            return "Sub-2 is plausible if your baseline supports it, but HAYF should protect easy volume and recovery rather than chase pace every session."
        }

        return "HAYF will treat this as adjustable: ambitious enough to guide the week, flexible enough to protect consistency."
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

private enum GoalBaseline: String, CaseIterable, Identifiable {
    case newToThis
    case returning
    case casual
    case serious

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newToThis: return "New to this"
        case .returning: return "Returning after a break"
        case .casual: return "Training casually"
        case .serious: return "Already training seriously"
        }
    }

    var subtitle: String {
        switch self {
        case .newToThis: return "Start from the ground up."
        case .returning: return "Rebuild without pretending nothing changed."
        case .casual: return "Add direction to what you already do."
        case .serious: return "Shape the week around a real target."
        }
    }

    var systemImage: String {
        switch self {
        case .newToThis: return "leaf"
        case .returning: return "arrow.triangle.2.circlepath"
        case .casual: return "figure.walk.motion"
        case .serious: return "chart.line.uptrend.xyaxis"
        }
    }
}

private enum GoalTimeline: String, CaseIterable, Identifiable {
    case fourWeeks
    case eightWeeks
    case twelveWeeks
    case specificDate
    case noFirmDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fourWeeks: return "4 weeks"
        case .eightWeeks: return "8 weeks"
        case .twelveWeeks: return "12 weeks"
        case .specificDate: return "Date"
        case .noFirmDate: return "No date"
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
            return "Apple Health is connected. HAYF can use this context to adapt recommendations."
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
    let isSelected: Bool
    let action: () -> Void

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
                CheckmarkBox(isSelected: isSelected)
                    .padding(10)
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

private struct RhythmPreviewRow: View {
    let day: String
    let workout: String
    let duration: String

    var body: some View {
        HStack(spacing: 14) {
            Text(day)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .frame(width: 54, alignment: .leading)

            Rectangle()
                .fill(HAYFColor.orange)
                .frame(width: 2, height: 20)

            Text(workout)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)

            Spacer()

            Text(duration)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)
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
    let firstRhythm: OnboardingAIRhythmPayload
    let healthPermissionState: String
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case intent
        case selectedAnswers = "selected_answers"
        case generatedSummary = "generated_summary"
        case firstRhythm = "first_rhythm"
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
        rhythm: OnboardingRhythmOutput,
        healthRequestState: HealthRequestState
    ) async throws {
        let user = try await supabase.auth.session.user
        let request = CompletedOnboardingProfileRequest(
            id: user.id,
            intent: intent.rawValue,
            selectedAnswers: OnboardingAICompactContext(intent: intent, draft: draft),
            generatedSummary: OnboardingAISummaryPayload(summary: summary),
            firstRhythm: OnboardingAIRhythmPayload(rhythm: rhythm),
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
