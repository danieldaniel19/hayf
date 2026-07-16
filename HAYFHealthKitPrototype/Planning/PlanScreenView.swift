import SwiftUI

struct PlanScreenView: View {
    @StateObject private var store = PlanDataStore()
    @State private var didLoad = false
    @State private var didPresentInitialBlockDetail = false
    @State private var selectedDetail: PlanDetailSheet?
    @State private var workoutPlanningContext: WorkoutPlanningContext?
    @State private var workoutCandidates: [PlanningWorkoutCandidate] = []
    @State private var isLoadingWorkoutCandidates = false
    @State private var didFinishLoadingWorkoutCandidates = false
    @State private var workoutPlanningErrorMessage: String?
    @State private var pendingWorkoutReview: WorkoutChangeReview?
    @State private var selectedReplanProposal: PlanReplanProposal?
    @State private var isApplyingReplanProposal = false
    @State private var isReviewingPlanChanges = false
    @State private var pendingPlanReview: PlanPendingReview?
    @State private var planReviewConfirmationMessage: String?
    @State private var movingWorkout: PlanWorkout?
    @State private var selectedWorkoutDetail: PlanWorkout?
    @State private var activeEditAnalysis: PlanEditAnalysis?
    @State private var workoutCandidateLoadID: UUID?
    @State private var selectedDayAction: PlanDayActionContext?
    @State private var selectedConstraintDay: PlanConstraintEditingContext?
    @State private var isSavingConstraint = false
    @State private var didAttemptWeeklyTargetBackfill = false
    @State private var observedCommittedWeekStart = PlanCalendar.currentCommittedWeekStart()

    private let planningAIProvider = PlanningAIProvider()

    let userName: String?
    let presentActiveBlockOnFirstLoad: Bool
    let onDidPresentActiveBlockOnFirstLoad: () -> Void

    init(
        userName: String? = nil,
        presentActiveBlockOnFirstLoad: Bool = false,
        onDidPresentActiveBlockOnFirstLoad: @escaping () -> Void = {}
    ) {
        self.userName = userName
        self.presentActiveBlockOnFirstLoad = presentActiveBlockOnFirstLoad
        self.onDidPresentActiveBlockOnFirstLoad = onDidPresentActiveBlockOnFirstLoad
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HAYFColor.neutral
                    .ignoresSafeArea()

                Group {
                    if store.isLoading && !didLoad {
                        PlanLoadingView()
                    } else if store.activeBlock != nil {
                        PlanContentView(
                            userName: userName,
                            phases: store.phases,
                            weeklyRhythms: store.weeklyRhythms,
                            workouts: store.workouts,
                            homeLocationLabel: store.homeLocationLabel,
                            goalTargets: store.goalTargets,
                            goalEvaluations: store.goalEvaluations,
                            pendingReview: pendingPlanReview,
                            pendingProposal: store.pendingReplanProposals.first,
                            errorMessage: store.errorMessage,
                            reviewConfirmationMessage: planReviewConfirmationMessage,
                            movingWorkout: movingWorkout,
                            isAnalyzingEdit: activeEditAnalysis != nil,
                            isReviewingPlanChanges: isReviewingPlanChanges,
                            showTargetDetail: { target in
                                selectedDetail = .target(target)
                            },
                            reviewPlanChanges: {
                                Task { await reviewPlanChanges() }
                            },
                            moveWorkout: { workout, date, sequenceOrder in
                                Task { await moveWorkout(workout, to: date, sequenceOrder: sequenceOrder) }
                            },
                            beginMoveWorkout: { workout in
                                beginMoveWorkout(workout)
                            },
                            cancelMoveWorkout: {
                                movingWorkout = nil
                            },
                            deleteWorkout: { workout in
                                Task { await deleteWorkout(workout) }
                            },
                            replaceWorkout: { workout in
                                showWorkoutPlanning(WorkoutPlanningContext(mode: .replace(workout: workout)))
                            },
                            showWorkoutDetail: { workout in
                                selectedWorkoutDetail = workout
                            },
                            showDayActions: { group in
                                selectedDayAction = PlanDayActionContext(group: group)
                            },
                            reload: {
                                await loadPlan(allowWeeklyTargetBackfill: true, forceWeeklyTargetBackfill: true)
                            }
                        )
                    } else {
                        PlanEmptyView(
                            errorMessage: store.errorMessage,
                            reload: {
                                await loadPlan(allowWeeklyTargetBackfill: true, forceWeeklyTargetBackfill: true)
                            }
                        )
                    }
                }
                .disabled(activeEditAnalysis != nil)

                if let activeEditAnalysis {
                    PlanEditAnalysisOverlay(message: activeEditAnalysis.message)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            guard !didLoad else { return }
            await loadPlan(allowWeeklyTargetBackfill: true)
            if presentActiveBlockOnFirstLoad, store.activeBlock == nil {
                await loadPlan(allowWeeklyTargetBackfill: true)
            }
            presentInitialBlockDetailIfNeeded()
        }
        .onAppear {
            refreshVisiblePlanIfNeeded(force: didLoad)
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now in
            refreshVisiblePlanIfNeeded(now: now)
        }
        .onChange(of: store.activeBlock?.id) { _, _ in
            presentInitialBlockDetailIfNeeded()
        }
        .sheet(item: $selectedDetail) { detail in
            PlanDetailSheetView(
                detail: detail,
                block: store.activeBlock,
                phases: store.phases,
                weeklyRhythms: store.weeklyRhythms,
                workouts: store.workouts,
                goalEvaluations: store.goalEvaluations
            )
            .presentationDetents(detail.detents)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $workoutPlanningContext) { context in
            WorkoutPlanningSheet(
                context: context,
                candidates: workoutCandidates,
                fallbackLocationLabel: store.homeLocationLabel,
                isLoading: isLoadingWorkoutCandidates,
                didFinishLoading: didFinishLoadingWorkoutCandidates,
                errorMessage: workoutPlanningErrorMessage,
                retry: {
                    loadWorkoutCandidates(for: context)
                },
                interpretManualWorkout: { text in
                    try await interpretManualWorkout(text, context: context)
                },
                reviewCandidate: { candidate in
                    presentWorkoutReview(candidate, context: context)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $pendingWorkoutReview) { review in
            WorkoutChangeReviewSheet(
                review: review,
                workouts: store.workouts,
                fallbackLocationLabel: store.homeLocationLabel,
                isApplying: activeEditAnalysis != nil,
                accept: {
                    Task { await acceptWorkoutReview(review) }
                },
                cancel: {
                    cancelWorkoutReview(review)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedDayAction) { context in
            PlanDayActionSheet(
                context: context,
                addWorkout: {
                    selectedDayAction = nil
                    DispatchQueue.main.async {
                        showWorkoutPlanning(WorkoutPlanningContext(mode: .add(date: context.date, sequenceOrder: context.nextSequenceOrder)))
                    }
                },
                editAvailability: {
                    selectedDayAction = nil
                    DispatchQueue.main.async {
                        showConstraintEditor(for: context.group)
                    }
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedReplanProposal) { proposal in
            ReplanProposalSheet(
                proposal: proposal,
                isApplying: isApplyingReplanProposal,
                apply: {
                    Task { await applyReplanProposal(proposal, decision: .accepted) }
                },
                keepChange: {
                    Task { await applyReplanProposal(proposal, decision: .rejected) }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedConstraintDay) { context in
            WeeklyPlanConstraintSheet(
                context: context,
                isSaving: isSavingConstraint,
                save: { kind, note in
                    Task { await saveConstraint(context: context, kind: kind, note: note) }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $selectedWorkoutDetail) { workout in
            WorkoutDetailScreen(
                workout: workout,
                fallbackLocationLabel: store.homeLocationLabel,
                dismiss: { selectedWorkoutDetail = nil }
            )
        }
    }

    private func presentInitialBlockDetailIfNeeded() {
        guard presentActiveBlockOnFirstLoad,
              !didPresentInitialBlockDetail,
              store.activeBlock != nil else {
            return
        }

        didPresentInitialBlockDetail = true
        onDidPresentActiveBlockOnFirstLoad()
    }

    private func loadPlan(
        allowWeeklyTargetBackfill: Bool,
        forceWeeklyTargetBackfill: Bool = false
    ) async {
        await refreshPlanWindowIfPossible()
        await store.loadVisiblePlan()
        if store.activeBlock != nil {
            await refreshWorkoutWeatherForecastsIfPossible()
            await store.loadVisiblePlan()
        }
        didLoad = true

        guard allowWeeklyTargetBackfill,
              shouldBackfillWeeklyTargets(force: forceWeeklyTargetBackfill) else {
            return
        }

        didAttemptWeeklyTargetBackfill = true
        do {
            _ = try await planningAIProvider.generateWeeklyPlanTargets()
            await store.loadVisiblePlan()
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
            print("Weekly target backfill failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func refreshVisiblePlanIfNeeded(force: Bool = false, now: Date = Date()) {
        let currentCommittedWeekStart = PlanCalendar.currentCommittedWeekStart(now: now)
        guard force || currentCommittedWeekStart != observedCommittedWeekStart else { return }
        observedCommittedWeekStart = currentCommittedWeekStart
        guard didLoad else { return }

        Task {
            await loadPlan(allowWeeklyTargetBackfill: false)
        }
    }

    private func refreshWorkoutWeatherForecastsIfPossible() async {
        do {
            _ = try await planningAIProvider.refreshWorkoutWeatherForecasts()
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
            print("Weather forecast refresh failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func refreshPlanWindowIfPossible() async {
        do {
            _ = try await planningAIProvider.refreshPlanWindow()
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
            print("Plan window refresh failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func shouldBackfillWeeklyTargets(force: Bool) -> Bool {
        guard (force || !didAttemptWeeklyTargetBackfill),
              store.activeBlock != nil else {
            return false
        }

        let visibleWeekIDs = Set(store.weeklyRhythms
            .filter { $0.status == "committed" || $0.status == "draft" }
            .map(\.id))
        guard !visibleWeekIDs.isEmpty else { return false }

        let coveredWeekIDs = Set(store.goalTargets.compactMap { target -> UUID? in
            guard target.targetScope == .week,
                  let weeklyPlanID = target.weeklyPlanID,
                  visibleWeekIDs.contains(weeklyPlanID) else {
                return nil
            }
            return weeklyPlanID
        })

        return !visibleWeekIDs.isSubset(of: coveredWeekIDs)
    }

    private func moveWorkout(_ workout: PlanWorkout, to date: String, sequenceOrder: Int?) async {
        guard let scheduledDate = PlanDate.date(from: date) else { return }

        planReviewConfirmationMessage = nil
        activeEditAnalysis = .move
        do {
            let outcome = try await planningAIProvider.recordPlanEdit(
                .moveWorkout(
                    plannedWorkoutID: workout.id,
                    scheduledDate: scheduledDate,
                    sequenceOrder: sequenceOrder
                ),
                repairPolicy: .deferred
            )
            await loadPlan(allowWeeklyTargetBackfill: false)
            movingWorkout = nil
            activeEditAnalysis = nil
            _ = outcome
            markPlanReviewPending()
        } catch {
            activeEditAnalysis = nil
            store.errorMessage = error.localizedDescription
        }
    }

    private func beginMoveWorkout(_ workout: PlanWorkout) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            if movingWorkout?.id == workout.id {
                movingWorkout = nil
            } else {
                movingWorkout = workout
            }
        }
    }

    private func deleteWorkout(_ workout: PlanWorkout) async {
        planReviewConfirmationMessage = nil
        activeEditAnalysis = .delete
        do {
            let outcome = try await planningAIProvider.recordPlanEdit(
                .deleteWorkout(plannedWorkoutID: workout.id),
                repairPolicy: .deferred
            )
            await loadPlan(allowWeeklyTargetBackfill: false)
            activeEditAnalysis = nil
            if movingWorkout?.id == workout.id {
                movingWorkout = nil
            }
            _ = outcome
            markPlanReviewPending()
        } catch {
            activeEditAnalysis = nil
            store.errorMessage = error.localizedDescription
        }
    }

    private func showWorkoutPlanning(_ context: WorkoutPlanningContext) {
        workoutCandidates = []
        workoutPlanningErrorMessage = nil
        isLoadingWorkoutCandidates = true
        didFinishLoadingWorkoutCandidates = false
        workoutPlanningContext = context
        loadWorkoutCandidates(for: context)
    }

    private func loadWorkoutCandidates(for context: WorkoutPlanningContext) {
        let loadID = UUID()
        workoutCandidateLoadID = loadID
        workoutCandidates = []
        workoutPlanningErrorMessage = nil
        isLoadingWorkoutCandidates = true
        didFinishLoadingWorkoutCandidates = false

        Task {
            do {
                let loadedCandidates: [PlanningWorkoutCandidate]
                switch context.mode {
                case let .replace(workout):
                    let output = try await planningAIProvider.recommendWorkoutReplacements(
                        plannedWorkoutID: workout.id,
                        textContext: "I do not want to do this workout in this slot."
                    )
                    loadedCandidates = output.candidates
                case let .add(date, _):
                    guard let scheduledDate = PlanDate.date(from: date) else {
                        guard workoutCandidateLoadID == loadID else { return }
                        workoutPlanningErrorMessage = "Could not read the selected date."
                        isLoadingWorkoutCandidates = false
                        return
                    }
                    let output = try await planningAIProvider.recommendWorkoutAdditions(
                        scheduledDate: scheduledDate,
                        textContext: "I feel like working out on this day, but I want HAYF to pick something that fits the plan."
                    )
                    loadedCandidates = output.candidates
                }
                guard workoutCandidateLoadID == loadID, workoutPlanningContext?.id == context.id else { return }
                workoutCandidates = loadedCandidates
                isLoadingWorkoutCandidates = false
                didFinishLoadingWorkoutCandidates = true
            } catch {
                guard workoutCandidateLoadID == loadID, workoutPlanningContext?.id == context.id else { return }
                workoutPlanningErrorMessage = error.localizedDescription
                isLoadingWorkoutCandidates = false
                didFinishLoadingWorkoutCandidates = true
            }
        }
    }

    private func interpretManualWorkout(_ text: String, context: WorkoutPlanningContext) async throws -> PlanningWorkoutCandidate {
        switch context.mode {
        case let .replace(workout):
            return try await planningAIProvider.interpretWorkoutDescription(
                textContext: text,
                plannedWorkoutID: workout.id
            ).candidate
        case let .add(date, _):
            guard let scheduledDate = PlanDate.date(from: date) else {
                throw PlanningFunctionError(statusCode: 0, message: "Could not read the selected date.")
            }
            return try await planningAIProvider.interpretWorkoutDescription(
                textContext: text,
                scheduledDate: scheduledDate
            ).candidate
        }
    }

    private func presentWorkoutReview(_ candidate: PlanningWorkoutCandidate, context: WorkoutPlanningContext) {
        workoutPlanningContext = nil
        pendingWorkoutReview = WorkoutChangeReview(context: context, candidate: candidate)
    }

    private func cancelWorkoutReview(_ review: WorkoutChangeReview) {
        pendingWorkoutReview = nil
        workoutPlanningContext = review.context
    }

    private func acceptWorkoutReview(_ review: WorkoutChangeReview) async {
        pendingWorkoutReview = nil
        await applyWorkoutCandidate(review.candidate, context: review.context)
    }

    private func applyWorkoutCandidate(_ candidate: PlanningWorkoutCandidate, context: WorkoutPlanningContext) async {
        workoutPlanningContext = nil
        workoutCandidates = []
        workoutPlanningErrorMessage = nil
        didFinishLoadingWorkoutCandidates = false

        switch context.mode {
        case let .replace(workout):
            planReviewConfirmationMessage = nil
            activeEditAnalysis = .replace
            do {
                let outcome = try await planningAIProvider.replaceWorkout(
                    plannedWorkoutID: workout.id,
                    candidate: candidate,
                    repairPolicy: .deferred
                )
                await loadPlan(allowWeeklyTargetBackfill: false)
                activeEditAnalysis = nil
                if movingWorkout?.id == workout.id {
                    movingWorkout = nil
                }
                _ = outcome
                markPlanReviewPending()
            } catch {
                activeEditAnalysis = nil
                workoutPlanningErrorMessage = error.localizedDescription
                workoutPlanningContext = context
            }
        case let .add(date, sequenceOrder):
            guard let scheduledDate = PlanDate.date(from: date) else {
                workoutPlanningErrorMessage = "Could not read the selected date."
                workoutPlanningContext = context
                return
            }
            planReviewConfirmationMessage = nil
            activeEditAnalysis = .add
            do {
                let outcome = try await planningAIProvider.addWorkout(
                    scheduledDate: scheduledDate,
                    sequenceOrder: sequenceOrder,
                    candidate: candidate,
                    repairPolicy: .deferred
                )
                await loadPlan(allowWeeklyTargetBackfill: false)
                activeEditAnalysis = nil
                _ = outcome
                markPlanReviewPending()
            } catch {
                activeEditAnalysis = nil
                workoutPlanningErrorMessage = error.localizedDescription
                workoutPlanningContext = context
            }
        }
    }

    private func reviewPlanChanges() async {
        if let proposal = store.pendingReplanProposals.first {
            selectedReplanProposal = proposal
            return
        }

        guard pendingPlanReview != nil else { return }

        isReviewingPlanChanges = true
        planReviewConfirmationMessage = nil
        defer { isReviewingPlanChanges = false }

        do {
            let outcome = try await planningAIProvider.createRepairProposalForPendingEdits()
            await loadPlan(allowWeeklyTargetBackfill: false)
            if let proposal = outcome.proposal, proposal.mutationCount > 0 {
                selectedReplanProposal = proposal
            } else if let proposal = store.pendingReplanProposals.first {
                selectedReplanProposal = proposal
            } else {
                pendingPlanReview = nil
                planReviewConfirmationMessage = "HAYF reviewed your changes. No adjustment needed."
            }
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func presentReplanProposal(from outcome: PlanningEditOutcome) {
        if let proposalID = outcome.proposalID,
           let proposal = store.pendingReplanProposals.first(where: { $0.id == proposalID }) {
            selectedReplanProposal = proposal
            return
        }

        if let proposal = outcome.proposal, proposal.mutationCount > 0 {
            selectedReplanProposal = proposal
            return
        }
    }

    private func applyReplanProposal(_ proposal: PlanReplanProposal, decision: PlanningProposalDecision) async {
        isApplyingReplanProposal = true
        defer { isApplyingReplanProposal = false }

        do {
            _ = try await planningAIProvider.applyReplanProposal(proposalID: proposal.id, decision: decision)
            selectedReplanProposal = nil
            pendingPlanReview = nil
            planReviewConfirmationMessage = nil
            await loadPlan(allowWeeklyTargetBackfill: false)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func showConstraintEditor(for group: PlanWorkoutDayGroup) {
        guard let weeklyPlanID = group.weeklyPlanID else {
            store.errorMessage = "This day is not attached to a visible weekly plan yet."
            return
        }

        selectedConstraintDay = PlanConstraintEditingContext(
            weeklyPlanID: weeklyPlanID,
            date: group.date,
            constraint: group.constraint
        )
    }

    private func saveConstraint(
        context: PlanConstraintEditingContext,
        kind: PlanningWeeklyPlanConstraintKind,
        note: String?
    ) async {
        guard let scheduledDate = PlanDate.date(from: context.date) else {
            store.errorMessage = "Could not read the selected date."
            return
        }

        isSavingConstraint = true
        planReviewConfirmationMessage = nil
        defer { isSavingConstraint = false }

        do {
            _ = try await planningAIProvider.recordWeeklyPlanConstraint(
                weeklyPlanID: context.weeklyPlanID,
                scheduledDate: scheduledDate,
                kind: kind,
                note: note
            )
            selectedConstraintDay = nil
            await loadPlan(allowWeeklyTargetBackfill: false)
            markPlanReviewPending()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func markPlanReviewPending() {
        let nextCount = (pendingPlanReview?.editCount ?? 0) + 1
        pendingPlanReview = PlanPendingReview(editCount: nextCount)
    }
}

private enum PlanEditAnalysis: Identifiable {
    case move
    case delete
    case replace
    case add

    var id: String {
        switch self {
        case .move:
            return "move"
        case .delete:
            return "delete"
        case .replace:
            return "replace"
        case .add:
            return "add"
        }
    }

    var message: String {
        switch self {
        case .move:
            return "Saving the new slot"
        case .delete:
            return "Saving the change"
        case .replace:
            return "Saving the swap"
        case .add:
            return "Saving the added workout"
        }
    }
}

private struct WorkoutPlanningContext: Identifiable {
    enum Mode {
        case replace(workout: PlanWorkout)
        case add(date: String, sequenceOrder: Int)
    }

    let mode: Mode

    var id: String {
        switch mode {
        case let .replace(workout):
            return "replace-\(workout.id.uuidString)"
        case let .add(date, sequenceOrder):
            return "add-\(date)-\(sequenceOrder)"
        }
    }

    var overline: String {
        switch mode {
        case .replace:
            return "REPLACE WORKOUT"
        case .add:
            return "ADD WORKOUT"
        }
    }

    var title: String {
        switch mode {
        case let .replace(workout):
            return workout.title
        case let .add(date, _):
            return PlanDate.longLabel(date)
        }
    }

    var description: String {
        switch mode {
        case .replace:
            return "Pick a second-best option for this slot, or describe the workout you want instead. You will review the week before HAYF changes the plan."
        case .add:
            return "Add a workout to this day, or let HAYF suggest one that fits the surrounding week. You will review the result before it is saved."
        }
    }

    var scheduledDate: String {
        switch mode {
        case let .replace(workout):
            return workout.scheduledDate
        case let .add(date, _):
            return date
        }
    }

    var sequenceOrder: Int {
        switch mode {
        case let .replace(workout):
            return workout.sequenceOrder
        case let .add(_, sequenceOrder):
            return sequenceOrder
        }
    }

    var originalWorkout: PlanWorkout? {
        switch mode {
        case let .replace(workout):
            return workout
        case .add:
            return nil
        }
    }

    var loadingMessages: [String] {
        switch mode {
        case .replace:
            return [
                "Checking what this workout was supposed to do.",
                "Preserving the useful training purpose with less friction.",
                "Scanning nearby hard days so the swap does not crowd recovery.",
                "Estimating how the second-best option changes the week."
            ]
        case .add:
            return [
                "Checking the week before adding more load.",
                "Finding a workout that fits this date.",
                "Matching the idea to the active strategy targets.",
                "Estimating whether nearby sessions need more space."
            ]
        }
    }
}

private struct PlanConstraintEditingContext: Identifiable {
    let weeklyPlanID: UUID
    let date: String
    let constraint: PlanDayConstraint?

    var id: String {
        "\(weeklyPlanID.uuidString)-\(date)"
    }

    var initialKind: PlanningWeeklyPlanConstraintKind {
        constraint?.kind ?? .available
    }

    var initialNote: String {
        constraint?.note ?? ""
    }
}

private struct PlanDayActionContext: Identifiable {
    let group: PlanWorkoutDayGroup

    var id: String {
        group.id
    }

    var date: String {
        group.date
    }

    var nextSequenceOrder: Int {
        (group.workouts.map(\.sequenceOrder).max() ?? 0) + 1
    }

    var isUnavailable: Bool {
        group.constraint?.kind == .unavailable
    }
}

private struct PlanDayActionSheet: View {
    let context: PlanDayActionContext
    let addWorkout: () -> Void
    let editAvailability: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(
                    overline: "DAY SLOT",
                    title: PlanDate.longLabel(context.date),
                    dismiss: { dismiss() }
                )

                VStack(spacing: 10) {
                    PlanDayActionSheetRow(
                        iconName: "plus",
                        title: "Add workout",
                        subtitle: context.isUnavailable ? "Make this day available first." : "Plan-aware suggestions or manual entry.",
                        isDisabled: context.isUnavailable,
                        action: addWorkout
                    )

                    PlanDayActionSheetRow(
                        iconName: "slider.horizontal.3",
                        title: "Availability",
                        subtitle: "Limited, unavailable, or note for HAYF.",
                        isDisabled: false,
                        action: editAvailability
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)
        }
    }
}

private struct PlanDayActionSheetRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDisabled ? HAYFColor.muted : HAYFColor.orange)
                    .frame(width: 34, height: 34)
                    .background((isDisabled ? HAYFColor.surfaceDisabled : HAYFColor.orange.opacity(0.08)))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDisabled ? HAYFColor.muted : HAYFColor.primary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

private struct PlanEditAnalysisOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(HAYFColor.orange)

                Text(message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: 300)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

private struct PlanContentView: View {
    let userName: String?
    let phases: [PlanFitnessBlockPhase]
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]
    let homeLocationLabel: String?
    let goalTargets: [PlanGoalTarget]
    let goalEvaluations: [PlanGoalEvaluation]
    let pendingReview: PlanPendingReview?
    let pendingProposal: PlanReplanProposal?
    let errorMessage: String?
    let reviewConfirmationMessage: String?
    let movingWorkout: PlanWorkout?
    let isAnalyzingEdit: Bool
    let isReviewingPlanChanges: Bool
    let showTargetDetail: (PlanGoalTarget) -> Void
    let reviewPlanChanges: () -> Void
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let beginMoveWorkout: (PlanWorkout) -> Void
    let cancelMoveWorkout: () -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void
    let showWorkoutDetail: (PlanWorkout) -> Void
    let showDayActions: (PlanWorkoutDayGroup) -> Void
    let reload: () async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PlanWorkoutsPanel(
                    userName: userName,
                    phases: phases,
                    weeklyRhythms: weeklyRhythms,
                    workouts: workouts,
                    homeLocationLabel: homeLocationLabel,
                    targets: goalTargets,
                    evaluations: goalEvaluations,
                    pendingReview: pendingReview,
                    pendingProposal: pendingProposal,
                    reviewConfirmationMessage: reviewConfirmationMessage,
                    movingWorkout: movingWorkout,
                    isAnalyzingEdit: isAnalyzingEdit,
                    isReviewingPlanChanges: isReviewingPlanChanges,
                    showTargetDetail: showTargetDetail,
                    reviewPlanChanges: reviewPlanChanges,
                    moveWorkout: moveWorkout,
                    beginMoveWorkout: beginMoveWorkout,
                    cancelMoveWorkout: cancelMoveWorkout,
                    deleteWorkout: deleteWorkout,
                    replaceWorkout: replaceWorkout,
                    showWorkoutDetail: showWorkoutDetail,
                    showDayActions: showDayActions
                )
                if showsOpenMeteoAttribution {
                    Link("Weather by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(HAYFColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await reload()
        }
        .overlay(alignment: .top) {
            if let errorMessage {
                PlanErrorBanner(message: errorMessage)
                    .padding(.top, 10)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var showsOpenMeteoAttribution: Bool {
        workouts.contains { workout in
            workout.weatherForecast?.planObjectValue["source"]?.planStringValue == "open-meteo"
        }
    }
}

private struct PlanHeader: View {
    var body: some View {
        HStack(alignment: .center) {
            HAYFLogo(markSize: 34, textSize: 30, spacing: 10)

            Spacer()

            Button(action: {}) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(HAYFColor.primary)
                        .frame(width: 54, height: 54)
                        .background(HAYFColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(HAYFColor.borderStrong, lineWidth: 1)
                        }

                    Circle()
                        .fill(HAYFColor.orange)
                        .frame(width: 10, height: 10)
                        .offset(x: 2, y: -2)
                }
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Coach chat coming soon")
        }
    }
}

private struct PlanBlockCard: View {
    let block: PlanActiveFitnessBlock
    let phases: [PlanFitnessBlockPhase]
    let workouts: [PlanWorkout]
    let showActiveBlockDetail: () -> Void
    let showPhaseDetail: (PlanRoadmapItem) -> Void

    private var summary: PlanRoadmapSummary {
        PlanRoadmapSummary(block: block, phases: phases)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 16) {
                Button(action: showActiveBlockDetail) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("STRATEGY")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(HAYFColor.muted)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(PlanDisplay.title(for: block, workouts: workouts))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(HAYFColor.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HAYFColor.muted)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open strategy details")

                Spacer(minLength: 16)

                Text(summary.weekLabel)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize()
            }

            PlanRoadmap(
                items: summary.items,
                activeIndex: summary.activeIndex,
                showPhaseDetail: showPhaseDetail
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct PlanRoadmap: View {
    let items: [PlanRoadmapItem]
    let activeIndex: Int
    let showPhaseDetail: (PlanRoadmapItem) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    Rectangle()
                        .fill(index <= activeIndex ? HAYFColor.orange : HAYFColor.borderStrong)
                        .frame(height: 2)
                        .overlay(alignment: .trailing) {
                            Button {
                                showPhaseDetail(items[index])
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 44, height: 44)

                                    Circle()
                                        .fill(index == activeIndex ? HAYFColor.surface : (index < activeIndex ? HAYFColor.orange : HAYFColor.surface))
                                        .frame(width: index <= activeIndex ? 20 : 18, height: index <= activeIndex ? 20 : 18)
                                        .overlay {
                                            Circle()
                                                .stroke(index <= activeIndex ? HAYFColor.orange : HAYFColor.borderStrong, lineWidth: 2)
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(items[index].label) phase details")
                        }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 20)

            HStack(alignment: .top, spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    Text(items[index].label)
                        .font(.system(size: 15, weight: index == activeIndex ? .semibold : .regular))
                        .foregroundStyle(index == activeIndex ? HAYFColor.primary : HAYFColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct PlanTrainingTargetsCard: View {
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let showTargetDetail: (PlanGoalTarget) -> Void

    private var visibleTargets: [PlanGoalTarget] {
        let weekly = targets.filter(PlanTargetDisplay.isWeeklyTarget)
        return Array(weekly.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Training targets")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text("North stars for the week you're shaping.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
            }

            if visibleTargets.isEmpty {
                PlanTargetsEmptyView()
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleTargets) { target in
                        PlanTrainingTargetRow(
                            target: target,
                            evaluation: PlanTargetDisplay.latestEvaluation(for: target, in: evaluations),
                            openDetail: { showTargetDetail(target) }
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct PlanTargetsEmptyView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text("Targets will appear after the next sync.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text("HAYF needs the latest plan and health evidence before it can show useful weekly targets.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PlanCoachReviewCard: View {
    let proposal: PlanReplanProposal
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HAYFColor.orange)
                    .frame(width: 32, height: 32)
                    .background(HAYFColor.orange.opacity(0.08))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text("Coach review")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)

                    Text(proposal.reason)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
                    .padding(.top, 7)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.orange.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open coach review")
    }
}

private struct PlanTrainingTargetRow: View {
    let target: PlanGoalTarget
    let evaluation: PlanGoalEvaluation?
    let openDetail: () -> Void

    private var status: PlanGoalStatus {
        PlanTargetDisplay.status(for: target, evaluation: evaluation)
    }

    var body: some View {
        Button(action: openDetail) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: status == .achieved ? "checkmark" : PlanTargetDisplay.iconName(for: target))
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
                    .frame(width: 38, height: 44)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(target.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Spacer(minLength: 8)

                        Text(status.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PlanTargetDisplay.statusColor(for: status))
                            .lineLimit(1)
                    }

                    HStack(alignment: .center, spacing: 10) {
                        PlanTargetProgressBar(progress: PlanTargetDisplay.progress(for: target, evaluation: evaluation))

                        Text(PlanTargetDisplay.valueLine(for: target, evaluation: evaluation))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(HAYFColor.neutral)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(target.title) target details")
    }
}

private struct PlanTargetProgressBar: View {
    let progress: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(HAYFColor.borderStrong)

                Capsule()
                    .fill(HAYFColor.orange)
                    .frame(width: proxy.size.width * CGFloat(min(max(progress ?? 0, 0), 1)))
                    .opacity(progress == nil ? 0 : 1)
            }
        }
        .frame(height: 3)
        .frame(maxWidth: .infinity)
    }
}

private struct PlanMoveCue: View {
    let workout: PlanWorkout
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 28, height: 28)
                .background(HAYFColor.orange.opacity(0.1))
                .clipShape(Circle())

            Text("Move \"\(workout.title)\" to...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HAYFColor.muted)
                    .frame(width: 32, height: 32)
                    .background(HAYFColor.surface)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(HAYFColor.borderStrong, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel move")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(HAYFColor.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.orange.opacity(0.3), lineWidth: 1)
        }
    }
}

private struct PlanWorkoutsPanel: View {
    @State private var selectedWeek: PlanWeekBucket = .current
    @State private var selectedWeekContext: PlanWeekContextPresentation?

    let userName: String?
    let phases: [PlanFitnessBlockPhase]
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]
    let homeLocationLabel: String?
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let pendingReview: PlanPendingReview?
    let pendingProposal: PlanReplanProposal?
    let reviewConfirmationMessage: String?
    let movingWorkout: PlanWorkout?
    let isAnalyzingEdit: Bool
    let isReviewingPlanChanges: Bool
    let showTargetDetail: (PlanGoalTarget) -> Void
    let reviewPlanChanges: () -> Void
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let beginMoveWorkout: (PlanWorkout) -> Void
    let cancelMoveWorkout: () -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void
    let showWorkoutDetail: (PlanWorkout) -> Void
    let showDayActions: (PlanWorkoutDayGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                PlanWeekSwitcher(
                    selectedWeek: selectedWeek,
                    selectWeek: { selectedWeek = $0 }
                )
                .padding(.bottom, 16)

                if pendingProposal != nil || pendingReview != nil {
                    PlanReviewChangesCTA(
                        pendingReview: pendingReview,
                        pendingProposal: pendingProposal,
                        isReviewing: isReviewingPlanChanges,
                        review: reviewPlanChanges
                    )
                    .padding(.bottom, 14)
                } else if let reviewConfirmationMessage {
                    PlanReviewConfirmationRow(message: reviewConfirmationMessage)
                        .padding(.bottom, 14)
                }

                if let movingWorkout {
                    PlanMoveCue(workout: movingWorkout, cancel: cancelMoveWorkout)
                        .padding(.bottom, 14)
                }

                PlanWeekSection(
                    title: title(for: selectedWeek),
                    rhythm: rhythm(for: selectedWeek),
                    groups: groups(for: selectedWeek),
                    homeLocationLabel: homeLocationLabel,
                    targets: weekTargets(for: selectedWeek),
                    evaluations: evaluations,
                    movingWorkout: movingWorkout,
                    isAnalyzingEdit: isAnalyzingEdit,
                    showWeekContext: {
                        guard let rhythm = rhythm(for: selectedWeek) else { return }
                        selectedWeekContext = PlanWeekContextPresentation(
                            rhythm: rhythm,
                            phases: phases,
                            workouts: groups(for: selectedWeek).flatMap(\.workouts),
                            userName: userName
                        )
                    },
                    showTargetDetail: showTargetDetail,
                    moveWorkout: moveWorkout,
                    beginMoveWorkout: beginMoveWorkout,
                    deleteWorkout: deleteWorkout,
                    replaceWorkout: replaceWorkout,
                    showWorkoutDetail: showWorkoutDetail,
                    showDayActions: showDayActions
                )
            }
            .padding(18)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
            }
        }
        .sheet(item: $selectedWeekContext) { context in
            PlanWeekContextSheet(context: context)
                .presentationDetents([.height(380), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(HAYFColor.neutral)
        }
    }

    private func title(for week: PlanWeekBucket) -> String {
        switch week {
        case .current:
            return "This week"
        case .next:
            return "Next week"
        case .outside:
            return "Week"
        }
    }

    private func rhythm(for week: PlanWeekBucket) -> PlanWeeklyRhythm? {
        weeklyRhythms.first { PlanDate.bucket(for: $0.weekStartDate) == week }
    }

    private func weekTargets(for week: PlanWeekBucket) -> [PlanGoalTarget] {
        guard let weekPlanID = rhythm(for: week)?.id else { return [] }
        return targets.filter { $0.targetScope == .week && $0.weeklyPlanID == weekPlanID }
    }

    private func groups(for week: PlanWeekBucket) -> [PlanWorkoutDayGroup] {
        let weekRhythm = rhythm(for: week)
        let filtered = workouts.filter { PlanDate.bucket(for: $0.scheduledDate) == week }
        let grouped = Dictionary(grouping: filtered, by: \.scheduledDate)

        return PlanDate.weekDates(for: week).map { date in
            PlanWorkoutDayGroup(
                date: date,
                workouts: grouped[date] ?? [],
                weeklyPlanID: weekRhythm?.id,
                weekStatus: weekRhythm?.status,
                constraint: weekRhythm?.constraint(for: date)
            )
        }
    }
}

private struct PlanReviewChangesCTA: View {
    let pendingReview: PlanPendingReview?
    let pendingProposal: PlanReplanProposal?
    let isReviewing: Bool
    let review: () -> Void

    var body: some View {
        Button(action: review) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(HAYFColor.orange.opacity(0.12))

                    if isReviewing {
                        ProgressView()
                            .scaleEffect(0.72)
                            .tint(HAYFColor.orange)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HAYFColor.orange)
                    }
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.neutral)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.orange.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isReviewing)
        .accessibilityLabel(title)
    }

    private var title: String {
        if pendingProposal != nil {
            return "Review proposed adjustment"
        }

        return "Review changes"
    }

    private var subtitle: String {
        if let pendingProposal {
            return pendingProposal.reason
        }

        let count = pendingReview?.editCount ?? 0
        if count == 1 {
            return "Ask HAYF to check this edit against the strategy."
        }

        return "Ask HAYF to check \(count) edits against the strategy."
    }
}

private struct PlanReviewConfirmationRow: View {
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 32, height: 32)

            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.neutral)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct PlanWeekSwitcher: View {
    let selectedWeek: PlanWeekBucket
    let selectWeek: (PlanWeekBucket) -> Void

    var body: some View {
        HStack(spacing: 4) {
            switcherButton(title: "This week", week: .current)
            switcherButton(title: "Next week", week: .next)
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(HAYFColor.neutral)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func switcherButton(title: String, week: PlanWeekBucket) -> some View {
        Button(action: { selectWeek(week) }) {
            Text(title)
                .font(.system(size: 14, weight: selectedWeek == week ? .semibold : .medium))
                .foregroundStyle(selectedWeek == week ? HAYFColor.primary : HAYFColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if selectedWeek == week {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(HAYFColor.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selectedWeek == week ? "Selected" : "")
    }
}

private struct PlanWeekSection: View {
    let title: String
    let rhythm: PlanWeeklyRhythm?
    let groups: [PlanWorkoutDayGroup]
    let homeLocationLabel: String?
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let movingWorkout: PlanWorkout?
    let isAnalyzingEdit: Bool
    let showWeekContext: () -> Void
    let showTargetDetail: (PlanGoalTarget) -> Void
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let beginMoveWorkout: (PlanWorkout) -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void
    let showWorkoutDetail: (PlanWorkout) -> Void
    let showDayActions: (PlanWorkoutDayGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)

                    if let rhythm {
                        PlanWeekStatusChip(
                            status: rhythm.status,
                            open: showWeekContext
                        )
                    }

                    Spacer(minLength: 8)
                }
            }

            if !targets.isEmpty {
                PlanWeeklyTargetsView(
                    targets: targets,
                    evaluations: evaluations,
                    workouts: groups.flatMap(\.workouts)
                )
            }

            VStack(spacing: 8) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    VStack(spacing: 8) {
                        PlanWorkoutDayRow(
                            group: group,
                            homeLocationLabel: homeLocationLabel,
                            movingWorkout: movingWorkout,
                            isAnalyzingEdit: isAnalyzingEdit,
                            moveWorkout: moveWorkout,
                            beginMoveWorkout: beginMoveWorkout,
                            deleteWorkout: deleteWorkout,
                            replaceWorkout: replaceWorkout,
                            showWorkoutDetail: showWorkoutDetail,
                            showDayActions: showDayActions
                        )

                        if index < groups.count - 1 {
                            PlanWorkoutDayDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct PlanWeekContextPresentation: Identifiable {
    private struct PhaseDetails {
        let sequence: Int
        let name: String
        let week: Int
        let totalWeeks: Int
    }

    let id: UUID
    let headerTitle: String
    let metadataLabels: [String]
    let provenanceLabel: String
    let isDraft: Bool
    let statusExplanation: String
    let coachMessage: String
    let adaptationMessage: String?

    init(
        rhythm: PlanWeeklyRhythm,
        phases: [PlanFitnessBlockPhase],
        workouts: [PlanWorkout],
        userName: String?
    ) {
        id = rhythm.id
        let phase = Self.phaseDetails(for: rhythm, phases: phases)
        headerTitle = Self.dashless(Self.headerTitle(for: rhythm, phases: phases, phase: phase))
        metadataLabels = Self.metadataLabels(for: rhythm, phase: phase).map(Self.dashless)
        provenanceLabel = Self.provenanceLabel(for: rhythm.context?.provenance ?? .hayfOriginal)
        isDraft = rhythm.status == "draft"
        statusExplanation = isDraft
            ? "This is still a draft. HAYF will finalize it Sunday at 9 p.m., so there is still time for your changes."
            : "This week is committed. You have accepted these sessions, and they are ready to follow."

        let strategyRationale = Self.sentence(
            rhythm.context?.strategyExplanation,
            fallback: rhythm.objective.isEmpty
                ? "This week supports the current strategy while keeping training repeatable."
                : rhythm.objective
        )
        coachMessage = Self.coachMessage(
            for: rhythm,
            workouts: workouts,
            firstName: Self.firstName(from: userName),
            strategyRationale: strategyRationale
        )
        adaptationMessage = Self.adaptationSentence(for: rhythm.context)
    }

    private static func weekLabel(for rhythm: PlanWeeklyRhythm) -> String {
        if rhythm.programStage == "launch" {
            return "Launch"
        }
        if let week = rhythm.programWeekNumber {
            return "Week \(week)"
        }
        return "Why this week"
    }

    private static func headerTitle(
        for rhythm: PlanWeeklyRhythm,
        phases: [PlanFitnessBlockPhase],
        phase: PhaseDetails?
    ) -> String {
        if rhythm.programStage == "launch" {
            return "Launch week"
        }

        guard let weekNumber = rhythm.programWeekNumber else {
            return "Why this week"
        }

        guard let phase else {
            return phases.isEmpty
                ? (weekNumber == 1 ? "First week of your rhythm" : "Week \(weekNumber) of your rhythm")
                : "Program week \(weekNumber)"
        }

        if phase.totalWeeks == 1 {
            return "\(phase.name) focus week"
        }
        if phase.week == 1 {
            return "First week of \(phase.name)"
        }
        if phase.week >= phase.totalWeeks {
            return "Final week of \(phase.name)"
        }
        return "Week \(phase.week) of \(phase.name)"
    }

    private static func phaseDetails(
        for rhythm: PlanWeeklyRhythm,
        phases: [PlanFitnessBlockPhase]
    ) -> PhaseDetails? {
        guard let weekStart = PlanDate.date(from: rhythm.weekStartDate),
              let phaseMatch = phases.enumerated().first(where: { _, phase in
                  guard let start = PlanDate.date(from: phase.startDate),
                        let end = PlanDate.date(from: phase.endDate) else {
                      return false
                  }
                  return weekStart >= start && weekStart <= end
              }),
              let phaseStart = PlanDate.date(from: phaseMatch.element.startDate),
              let phaseEnd = PlanDate.date(from: phaseMatch.element.endDate) else {
            return nil
        }

        let calendar = PlanCalendar.iso
        let elapsedDays = max(0, calendar.dateComponents([.day], from: phaseStart, to: weekStart).day ?? 0)
        let totalDays = max(0, calendar.dateComponents([.day], from: phaseStart, to: phaseEnd).day ?? 0)
        return PhaseDetails(
            sequence: phaseMatch.offset + 1,
            name: phaseMatch.element.name,
            week: (elapsedDays / 7) + 1,
            totalWeeks: (totalDays / 7) + 1
        )
    }

    private static func metadataLabels(
        for rhythm: PlanWeeklyRhythm,
        phase: PhaseDetails?
    ) -> [String] {
        var labels = [weekLabel(for: rhythm)]
        if let phase {
            labels.append("Phase \(phase.sequence)")
            labels.append(phase.name)
        }
        return labels
    }

    private static func coachMessage(
        for rhythm: PlanWeeklyRhythm,
        workouts: [PlanWorkout],
        firstName: String?,
        strategyRationale: String
    ) -> String {
        let hello = firstName.map { "Hey, \($0)," } ?? "Hey,"
        let opening: String
        let rationale: String
        let close: String

        if rhythm.programStage == "launch" {
            opening = "\(hello) this is your launch week, so we are keeping it light."
            rationale = "The ride wakes your aerobic system up without much fatigue, while strength reintroduces load safely."
            close = "You should finish fresh for Week 1."
        } else if rhythm.status == "draft" {
            opening = "\(hello) here is next week's draft."
            rationale = warmRationale(strategyRationale)
            close = "We can still adapt it before it is committed."
        } else {
            opening = "\(hello) here is this week's plan."
            rationale = warmRationale(strategyRationale)
            close = "Keep the easy work easy; the spacing matters too."
        }

        return [opening, sessionOverview(for: rhythm, workouts: workouts), rationale, close]
            .joined(separator: " ")
    }

    private static func firstName(from fullName: String?) -> String? {
        fullName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)
    }

    private static func warmRationale(_ rationale: String) -> String {
        let body = dashless(rationale).trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutStop = body.last.map { ".!?".contains($0) } == true ? String(body.dropLast()) : body
        let lowercasedLead = withoutStop.prefix(1).lowercased() + String(withoutStop.dropFirst())
        let imperativeLeads = ["rebuild ", "maintain ", "preserve ", "develop ", "restore ", "progress ", "build ", "keep ", "use "]
        if imperativeLeads.contains(where: { lowercasedLead.hasPrefix($0) }) {
            return "That mix is designed to \(lowercasedLead)."
        }
        return body.last.map { ".!?".contains($0) } == true ? body : "\(body)."
    }

    private static func sessionOverview(for rhythm: PlanWeeklyRhythm, workouts: [PlanWorkout]) -> String {
        guard !workouts.isEmpty else {
            return "I have kept this week open so we can place the right sessions around your availability."
        }

        let mix = sessionMix(for: workouts)
        if rhythm.programStage == "launch" {
            return "We are starting with \(countLabel(workouts.count, noun: "session")): \(mix)."
        }
        if rhythm.status == "draft" {
            return "The draft includes \(countLabel(workouts.count, noun: "session")): \(mix)."
        }
        return "We have \(countLabel(workouts.count, noun: "session")) this week: \(mix)."
    }

    private static func sessionMix(for workouts: [PlanWorkout]) -> String {
        let grouped = Dictionary(grouping: workouts) { workout -> String in
            let activity = workout.activityType.lowercased()
            let intensity = workout.intensityLabel.lowercased()
            if activity.contains("strength") {
                return "strength support session"
            }
            if activity.contains("ride") || activity.contains("cycl") || activity.contains("bike") {
                if intensity.contains("hard") || intensity.contains("threshold") || intensity.contains("high") {
                    return "focused hard ride"
                }
                if intensity.contains("recover") || intensity.contains("very easy") {
                    return "recovery ride"
                }
                return "easy endurance ride"
            }
            if activity.contains("run") {
                return "easy run"
            }
            return "\(activity) session"
        }

        let order = ["easy endurance ride", "focused hard ride", "recovery ride", "strength support session", "easy run"]
        let descriptions = grouped.keys.sorted { lhs, rhs in
            (order.firstIndex(of: lhs) ?? order.count) < (order.firstIndex(of: rhs) ?? order.count)
        }.map { descriptor in
            countLabel(grouped[descriptor]?.count ?? 0, noun: descriptor)
        }
        return joinedList(descriptions)
    }

    private static func countLabel(_ count: Int, noun: String) -> String {
        let number = [1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six"][count] ?? "\(count)"
        return "\(number) \(noun)\(count == 1 ? "" : "s")"
    }

    private static func joinedList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return "a deliberately light session mix"
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? "")"
        }
    }

    private static func provenanceLabel(for provenance: PlanWeeklyPlanProvenance) -> String {
        switch provenance {
        case .hayfOriginal:
            return "Original HAYF plan"
        case .userChangedPending:
            return "Changes need review"
        case .reviewedNoAdjustment:
            return "Changes reviewed by HAYF"
        case .hayfAdapted:
            return "Adapted by HAYF"
        case .userChangesKept:
            return "Your changes kept"
        }
    }

    private static func adaptationSentence(for context: PlanWeeklyContext?) -> String? {
        guard let provenance = context?.provenance, provenance != .hayfOriginal else {
            return nil
        }
        let fallback: String
        switch provenance {
        case .hayfOriginal:
            return nil
        case .userChangedPending:
            fallback = "You changed this week, and HAYF has not reviewed the surrounding sessions yet."
        case .reviewedNoAdjustment:
            fallback = "HAYF reviewed your changes and the surrounding sessions still support the strategy."
        case .hayfAdapted:
            fallback = "HAYF adjusted the surrounding sessions to keep your changes aligned with the strategy."
        case .userChangesKept:
            fallback = "Your changes remain, and HAYF's suggested surrounding adjustments were not applied."
        }
        return sentence(context?.adaptationExplanation, fallback: fallback)
    }

    private static func sentence(_ value: String?, fallback: String) -> String {
        var cleaned = dashless(value ?? fallback)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return fallback }
        if let firstSentence = cleaned.range(
            of: #"^.*?[.!?](?=\s|$)"#,
            options: .regularExpression
        ) {
            cleaned = String(cleaned[firstSentence])
        }
        return cleaned.last.map { ".!?".contains($0) } == true ? cleaned : "\(cleaned)."
    }

    private static func dashless(_ value: String) -> String {
        value
            .replacingOccurrences(of: "—", with: ",")
            .replacingOccurrences(of: "–", with: ",")
            .replacingOccurrences(of: #"\s*,\s*"#, with: ", ", options: .regularExpression)
    }
}

private struct PlanWeekContextSheet: View {
    let context: PlanWeekContextPresentation

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("YOUR COACH'S PLAN")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(HAYFColor.muted)

                Text(context.headerTitle)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(HAYFColor.primary)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(context.metadataLabels + [context.provenanceLabel], id: \.self) { label in
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(HAYFColor.secondary)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(HAYFColor.surfaceRaised)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(HAYFColor.borderStrong, lineWidth: 1)
                                }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: context.isDraft ? "clock" : "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(context.isDraft ? HAYFColor.orange : HAYFColor.secondary)
                        .frame(width: 18, height: 20)

                    Text(context.statusExplanation)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HAYFColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HAYFColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(context.coachMessage)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let adaptationMessage = context.adaptationMessage {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PLAN UPDATE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.9)
                            .foregroundStyle(HAYFColor.muted)

                        Text(adaptationMessage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HAYFColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct PlanWorkoutDayDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: 38)

            Color.clear
                .frame(width: 12)

            Rectangle()
                .fill(HAYFColor.border.opacity(0.72))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

private struct PlanWeeklyTargetsView: View {
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let workouts: [PlanWorkout]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(targets.prefix(3)) { target in
                PlanWeeklyTargetCard(
                    target: target,
                    evaluation: PlanTargetDisplay.latestEvaluation(for: target, in: evaluations),
                    workouts: workouts
                )
            }
        }
    }
}

private struct PlanWeeklyTargetCard: View {
    let target: PlanGoalTarget
    let evaluation: PlanGoalEvaluation?
    let workouts: [PlanWorkout]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: PlanTargetDisplay.weeklyCardIconName(for: target, evaluation: evaluation))
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(HAYFColor.primary)
                .frame(width: 26, height: 24, alignment: .leading)

            Text(PlanTargetDisplay.weeklyCardValue(for: target, evaluation: evaluation))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            PlanTargetProgressBar(progress: PlanTargetDisplay.weeklyCardProgress(for: target, evaluation: evaluation, workouts: workouts))
                .frame(height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlanWeekStatusChip: View {
    let status: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(status == "draft" ? HAYFColor.orange : HAYFColor.primary)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background((status == "draft" ? HAYFColor.orange : HAYFColor.primary).opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Open context for \(label.lowercased()) week")
        .accessibilityHint("Shows the sessions and why your coach planned them")
    }

    private var label: String {
        status == "draft" ? "Draft" : "Committed"
    }
}

private struct PlanWorkoutDayRow: View {
    let group: PlanWorkoutDayGroup
    let homeLocationLabel: String?
    let movingWorkout: PlanWorkout?
    let isAnalyzingEdit: Bool
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let beginMoveWorkout: (PlanWorkout) -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void
    let showWorkoutDetail: (PlanWorkout) -> Void
    let showDayActions: (PlanWorkoutDayGroup) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlanDate.weekdayLabel(group.date))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)

                Text(PlanDate.dayLabel(group.date))
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
            }
            .frame(width: 38, alignment: .leading)
            .padding(.top, 10)

            PlanTimelineMarker(availabilityKind: group.constraint?.kind)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 8) {
                if isMoveTarget && group.workouts.isEmpty {
                    PlanEmptyDayDropZone(isMoveTarget: true)
                } else {
                    if canShowDayActions {
                        PlanDaySlotActionControl(
                            open: { showDayActions(group) }
                        )
                    }

                    if group.workouts.isEmpty {
                        if !canShowDayActions && PlanDate.isPast(group.date) {
                            PlanHistoryEmptyRow()
                        }
                    } else {
                        ForEach(group.workouts) { workout in
                            PlanWorkoutCard(
                                workout: workout,
                                fallbackLocationLabel: homeLocationLabel,
                                isDisabled: isAnalyzingEdit || isMoveTarget,
                                moveWorkout: { beginMoveWorkout(workout) },
                                deleteWorkout: { deleteWorkout(workout) },
                                replaceWorkout: { replaceWorkout(workout) },
                                showWorkoutDetail: { showWorkoutDetail(workout) }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: dayContentMinHeight, alignment: .topLeading)
        }
        .padding(.vertical, isMoveTarget ? 4 : 0)
        .padding(.horizontal, isMoveTarget ? 6 : 0)
        .contentShape(Rectangle())
        .background {
            if isMoveTarget {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HAYFColor.orange.opacity(0.06))
            }
        }
        .overlay {
            if isMoveTarget {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HAYFColor.orange.opacity(0.45), lineWidth: 1)
            }
        }
        .onTapGesture {
            guard let movingWorkout, !isAnalyzingEdit else { return }
            moveWorkout(movingWorkout, group.date, group.workouts.count + 1)
        }
        .accessibilityAddTraits(isMoveTarget ? .isButton : [])
    }

    private var isMoveTarget: Bool {
        movingWorkout != nil
    }

    private var canShowDayActions: Bool {
        !isAnalyzingEdit && !isMoveTarget && PlanDate.isTodayOrFuture(group.date) && group.weeklyPlanID != nil
    }

    private var dayContentMinHeight: CGFloat? {
        guard group.workouts.isEmpty,
              canShowDayActions else {
            return nil
        }

        return 44
    }
}

private struct PlanHistoryEmptyRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
                .frame(width: 24, height: 24)

            Text("No imported workout")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(HAYFColor.muted)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface.opacity(0.56))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct PlanDaySlotActionControl: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.orange)
                    .frame(width: 22, height: 22)

                Text("Add Workout/Availability")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 44, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add workout or availability")
    }
}

private struct PlanTimelineMarker: View {
    let availabilityKind: PlanningWeeklyPlanConstraintKind?

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(HAYFColor.borderStrong.opacity(0.62))
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            marker
                .padding(.top, markerTopPadding)
        }
    }

    @ViewBuilder
    private var marker: some View {
        switch availabilityKind {
        case .limited:
            ZStack {
                Circle()
                    .fill(HAYFColor.orange.opacity(0.12))
                    .overlay {
                        Circle()
                            .stroke(HAYFColor.orange.opacity(0.22), lineWidth: 1)
                    }

                Image(systemName: "exclamationmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HAYFColor.orange)
            }
            .frame(width: 18, height: 18)
            .accessibilityLabel("Limited availability")
        case .unavailable:
            ZStack {
                Circle()
                    .fill(HAYFColor.error.opacity(0.11))
                    .overlay {
                        Circle()
                            .stroke(HAYFColor.error.opacity(0.2), lineWidth: 1)
                    }

                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(HAYFColor.error)
            }
            .frame(width: 18, height: 18)
            .accessibilityLabel("Unavailable")
        case .available, .none:
            Circle()
                .fill(HAYFColor.borderStrong)
                .frame(width: 7, height: 7)
        }
    }

    private var markerTopPadding: CGFloat {
        switch availabilityKind {
        case .limited, .unavailable:
            return 14
        case .available, .none:
            return 20
        }
    }
}

private struct PlanEmptyDayDropZone: View {
    let isMoveTarget: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isMoveTarget {
                Text("Move here")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HAYFColor.orange)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .background(isMoveTarget ? HAYFColor.orange.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isMoveTarget {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.orange.opacity(0.45), lineWidth: 1)
            }
        }
    }
}

private struct PlanWorkoutCard: View {
    let workout: PlanWorkout
    let fallbackLocationLabel: String?
    let isDisabled: Bool
    let moveWorkout: () -> Void
    let deleteWorkout: () -> Void
    let replaceWorkout: () -> Void
    let showWorkoutDetail: () -> Void

    @State private var horizontalOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false
    private let actionWidth: CGFloat = 132
    private let actionSpacing: CGFloat = 4

    private var display: WorkoutCardDisplayModel {
        WorkoutCardDisplayModel(workout: workout, fallbackLocationLabel: fallbackLocationLabel)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionButtons
                .opacity(actionOpacity)
                .allowsHitTesting(horizontalOffset < -20)

            cardContent
                .offset(x: horizontalOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if !isDragging {
                        dragStartOffset = horizontalOffset
                        isDragging = true
                    }
                    horizontalOffset = min(0, max(-actionWidth, dragStartOffset + value.translation.width))
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let shouldOpen = horizontalOffset < -actionWidth / 2 || value.predictedEndTranslation.width < -actionWidth
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        horizontalOffset = shouldOpen ? -actionWidth : 0
                    }
                    dragStartOffset = 0
                    isDragging = false
                }
        )
        .contextMenu {
            Button {
                closeActions()
                replaceWorkout()
            } label: {
                Label("Replace workout", systemImage: "arrow.triangle.2.circlepath")
            }

            Button {
                closeActions()
                moveWorkout()
            } label: {
                Label("Move workout", systemImage: "calendar.badge.clock")
            }

            Button(role: .destructive) {
                closeActions()
                deleteWorkout()
            } label: {
                Label("Delete workout", systemImage: "trash")
            }
        }
        .onTapGesture {
            guard canOpenDetail else { return }
            showWorkoutDetail()
        }
        .allowsHitTesting(!isDisabled)
        .opacity(isDisabled ? 0.82 : 1)
    }

    private var actionButtons: some View {
        HStack(spacing: actionSpacing) {
            Button(action: {
                closeActions()
                replaceWorkout()
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: actionButtonWidth)
                    .frame(maxHeight: .infinity)
                    .background(HAYFColor.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Replace workout")

            Button(action: {
                closeActions()
                moveWorkout()
            }) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: actionButtonWidth)
                    .frame(maxHeight: .infinity)
                    .background(HAYFColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Move workout")

            Button(role: .destructive, action: {
                closeActions()
                deleteWorkout()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: actionButtonWidth)
                    .frame(maxHeight: .infinity)
                    .background(HAYFColor.error)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete workout")
        }
        .frame(width: actionWidth, alignment: .trailing)
        .frame(minHeight: cardMinHeight)
    }

    private var actionButtonWidth: CGFloat {
        (actionWidth - (actionSpacing * 2)) / 3
    }

    private var actionOpacity: Double {
        min(1, max(0, Double(abs(horizontalOffset) / 20)))
    }

    private var canOpenDetail: Bool {
        !isDisabled && !isDragging && horizontalOffset == 0 && ![.deleted, .superseded].contains(workout.status)
    }

    private var cardMinHeight: CGFloat {
        workout.status == .current ? 138 : 130
    }

    private func closeActions() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            horizontalOffset = 0
        }
    }

    private var cardContent: some View {
        WorkoutCardBody(
            display: display,
            minHeight: cardMinHeight,
            titleSize: titleSize,
            titleWeight: titleWeight
        ) {
            PlanWorkoutStateMark(display: display, markSize: titleSize)
        }
    }

    private var titleSize: CGFloat {
        switch workout.status {
        case .current:
            return 19
        case .planned, .checkedIn, .adjusted:
            return 18
        case .done, .missed, .skipped:
            return 18
        case .deleted, .superseded:
            return 17
        }
    }

    private var titleWeight: Font.Weight {
        switch workout.status {
        case .current:
            return .bold
        case .planned, .checkedIn, .adjusted:
            return .medium
        case .done, .missed, .skipped:
            return .regular
        case .deleted, .superseded:
            return .regular
        }
    }

}

private struct PlanWorkoutStateMark: View {
    let display: WorkoutCardDisplayModel
    let markSize: CGFloat

    var body: some View {
        if let stateEmoji = display.stateEmoji {
            Text(stateEmoji)
                .font(.system(size: markSize))
                .frame(width: markSize + 4, height: markSize + 4)
        } else {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(display.stateColor)
                .frame(width: 2, height: markSize + 4)
                .overlay(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(display.stateColor)
                        .frame(width: 2, height: markSize + 4)
                        .offset(x: 8)
                }
                .frame(width: 18, height: markSize + 4)
        }
    }
}

private struct WorkoutCardBody<Accessory: View>: View {
    let display: WorkoutCardDisplayModel
    let minHeight: CGFloat
    let titleSize: CGFloat
    let titleWeight: Font.Weight
    var borderColor: Color? = nil
    var borderWidth: CGFloat? = nil
    var backgroundTintColor: Color? = nil
    var backgroundTintOpacity: Double? = nil
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(display.modalityEmoji)
                    .font(.system(size: titleSize))
                    .frame(width: titleSize + 8, alignment: .leading)

                Text(display.title)
                    .font(.system(size: titleSize, weight: titleWeight))
                    .foregroundStyle(display.stateColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                accessory
            }

            WorkoutPillFlow(spacing: 7, rowSpacing: 6) {
                ForEach(display.metricPills) { pill in
                    PlanWorkoutCardPill(pill: pill, style: .metric)
                }
            }

            Rectangle()
                .fill(HAYFColor.borderStrong)
                .frame(height: 1)
                .padding(.trailing, 8)

            WorkoutPillFlow(spacing: 7, rowSpacing: 6) {
                ForEach(display.contextPills) { pill in
                    PlanWorkoutCardPill(pill: pill, style: .context)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor ?? display.borderColor, lineWidth: borderWidth ?? display.borderWidth)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var cardBackground: some View {
        HAYFColor.surface

        if (backgroundTintOpacity ?? display.backgroundTintOpacity) > 0 {
            (backgroundTintColor ?? display.stateColor).opacity(backgroundTintOpacity ?? display.backgroundTintOpacity)
        }
    }
}

private struct PlanWorkoutCardPill: View {
    enum Style {
        case metric
        case context
    }

    let pill: PlanWorkoutCardPillModel
    let style: Style

    var body: some View {
        Text("\(pill.emoji) \(pill.text)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(HAYFColor.primary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(style == .metric ? HAYFColor.orange.opacity(0.16) : HAYFColor.surfaceRaised)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(style == .metric ? HAYFColor.orange.opacity(0.18) : HAYFColor.border, lineWidth: 1)
            }
    }
}

private enum WorkoutVisibleCopy {
    static func sanitize(_ value: String) -> String {
        let dashNormalized = value
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")

        if let range = dashNormalized.range(of: #"(?i)^\s*RPE\s*(\d+)(?:\s*-\s*(\d+))?\s*$"#, options: .regularExpression) {
            let digits = dashNormalized[range].split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            let effort = digits.max() ?? 5
            if effort >= 8 { return "Hard, controlled effort" }
            if effort >= 6 { return "Challenging effort" }
            return "Easy effort"
        }

        var result = dashNormalized
            .replacingOccurrences(
                of: #"(?i)\b(?:approvedArchetype|archetypeId|bad[_ ]day[_ ]floor)\s*:\s*"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)(?:~\s*)?(\d+)\s*-\s*(\d+)\s*RIR(?:\s*\([^)]*\))?"#,
                with: "$1-$2 reps left",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)(?:~\s*)?(\d+)\s*RIR(?:\s*\([^)]*\))?"#,
                with: "$1 reps left",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\s*/?\s*RPE\s*\d+(?:\s*-\s*\d+)?"#,
                with: "",
                options: .regularExpression
            )

        let friendlyTerms = [
            "strength_mobility_preparation": "light strength and mobility",
            "strength_maintenance_minimum": "short strength session",
            "cycling_recovery_spin": "short easy ride",
            "submaximal_loads_phase1": "controlled opening loads",
            "submaximal": "controlled"
        ]
        for (internalTerm, friendlyTerm) in friendlyTerms {
            result = result.replacingOccurrences(
                of: internalTerm,
                with: friendlyTerm,
                options: [.caseInsensitive]
            )
        }

        return result
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,.;:])"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WorkoutDetailScreen: View {
    let workout: PlanWorkout
    let fallbackLocationLabel: String?
    let dismiss: () -> Void

    private var display: WorkoutCardDisplayModel {
        WorkoutCardDisplayModel(workout: workout, fallbackLocationLabel: fallbackLocationLabel)
    }

    private var prescription: WorkoutPrescriptionDisplayModel {
        WorkoutPrescriptionDisplayModel(workout: workout)
    }

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .background(HAYFColor.neutral)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        metricGrid

                        WorkoutDetailTextSection(
                            title: "Why today",
                            text: prescription.whyToday
                        )

                        WorkoutDetailStepsSection(title: "Warm up", group: prescription.warmup)

                        WorkoutDetailMainSection(blocks: prescription.blocks)

                        WorkoutDetailStepsSection(title: "Cool down", group: prescription.cooldown)

                        WorkoutDetailTextSection(title: "Success", text: prescription.successCriteria)

                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button(action: dismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)
                        .frame(width: 38, height: 38)
                        .background(HAYFColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(HAYFColor.borderStrong, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close workout detail")

                Text("HAYF")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HAYFColor.primary)

                Spacer(minLength: 8)

                WorkoutDetailStatusPill(status: workout.status)
            }

            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(display.modalityEmoji)
                    .font(.system(size: 25))
                    .frame(width: 30, alignment: .leading)

                Text(display.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    private var metricGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            WorkoutDetailMetricChip(icon: "calendar", label: PlanDate.weekdayLabel(workout.scheduledDate), value: PlanDate.dayLabel(workout.scheduledDate))
            WorkoutDetailMetricChip(icon: "clock", label: "Duration", value: WorkoutDetailFormatting.duration(workout.durationMinutes))
            WorkoutDetailMetricChip(icon: "flame", label: "Intensity", value: display.metricPills.last(where: { $0.emoji == "🔥" })?.text.capitalized ?? workout.intensityLabel)
            WorkoutDetailMetricChip(icon: "target", label: "Target", value: display.metricPills.last(where: { $0.emoji == "🎯" })?.text ?? "Support")
            if let distanceText = display.distanceText {
                WorkoutDetailMetricChip(icon: "point.topleft.down.curvedto.point.bottomright.up", label: "Distance", value: distanceText)
            }
            if let elevationText = display.elevationText {
                WorkoutDetailMetricChip(icon: "mountain.2", label: "Elevation", value: elevationText)
            }
            WorkoutDetailMetricChip(icon: "mappin.and.ellipse", label: "Location", value: WorkoutDetailFormatting.location(workout.plannedLocationLabel ?? fallbackLocationLabel))
            WorkoutDetailMetricChip(icon: "fork.knife", label: "Fuel", value: WorkoutDetailFormatting.shortFuel(workout.fuelingSummary))
        }
    }
}

private struct WorkoutDetailStatusPill: View {
    let status: PlanWorkoutStatus

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(color.opacity(0.09))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.14), lineWidth: 1)
            }
    }

    private var label: String {
        switch status {
        case .current: return "Current"
        case .planned: return "Planned"
        case .checkedIn: return "Checked in"
        case .adjusted: return "Adjusted"
        case .done: return "Done"
        case .missed: return "Missed"
        case .skipped: return "Skipped"
        case .deleted: return "Deleted"
        case .superseded: return "Updated"
        }
    }

    private var color: Color {
        switch status {
        case .current:
            return HAYFColor.orange
        case .missed, .skipped, .deleted:
            return HAYFColor.error
        default:
            return HAYFColor.primary
        }
    }
}

private struct WorkoutDetailMetricChip: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 18, height: 18, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HAYFColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .topLeading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct WorkoutDetailTextSection: View {
    let title: String
    let text: String

    var body: some View {
        WorkoutDetailSectionContainer(title: title) {
            Text(WorkoutVisibleCopy.sanitize(text.isEmpty ? "Complete the session as planned." : text))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WorkoutDetailStepsSection: View {
    let title: String
    let group: WorkoutPrescriptionDisplayModel.StepGroup

    var body: some View {
        WorkoutDetailSectionContainer(title: title) {
            VStack(alignment: .leading, spacing: 9) {
                Text(group.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(group.steps.enumerated()), id: \.offset) { _, step in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(HAYFColor.orange)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)

                        Text(step)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(HAYFColor.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct WorkoutDetailMainSection: View {
    let blocks: [WorkoutPrescriptionDisplayModel.MainBlock]

    var body: some View {
        WorkoutDetailSectionContainer(title: "Main work") {
            VStack(spacing: 10) {
                ForEach(blocks) { block in
                    switch block.kind {
                    case let .strength(exercise):
                        WorkoutStrengthExerciseRow(exercise: exercise)
                    case let .interval(interval):
                        WorkoutIntervalBlockRow(interval: interval)
                    case let .steady(steady):
                        WorkoutSteadyBlockRow(steady: steady)
                    case let .mobility(mobility):
                        WorkoutMobilityBlockRow(mobility: mobility)
                    case let .walkRun(walkRun):
                        WorkoutWalkRunBlockRow(walkRun: walkRun)
                    case let .text(text):
                        Text(text)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(HAYFColor.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct WorkoutStrengthExerciseRow: View {
    let exercise: WorkoutPrescriptionDisplayModel.StrengthExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(exercise.exerciseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(exercise.setsReps)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(1)
            }

            WorkoutPillFlow(spacing: 7, rowSpacing: 6) {
                WorkoutDetailMiniPill(text: exercise.machineOrEquipment)
                WorkoutDetailMiniPill(text: exercise.restText)
                WorkoutDetailMiniPill(text: exercise.effortTarget)
            }

            if !exercise.coachingCue.isEmpty {
                Text(exercise.coachingCue)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let alternative = exercise.alternatives.first {
                Text("Alt: \(alternative.exerciseName)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct WorkoutIntervalBlockRow: View {
    let interval: WorkoutPrescriptionDisplayModel.IntervalBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(interval.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Spacer(minLength: 8)

                Text("\(interval.repeats)x")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(HAYFColor.orange)
            }

            HStack(spacing: 8) {
                WorkoutDetailIntervalCell(label: "Work", value: interval.workDuration)
                WorkoutDetailIntervalCell(label: "Recover", value: interval.recoveryDuration)
                WorkoutDetailIntervalCell(label: "Target", value: interval.target)
            }

            if !interval.notes.isEmpty {
                Text(interval.notes)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct WorkoutDetailIntervalCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(HAYFColor.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HAYFColor.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(HAYFColor.neutral)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct WorkoutSteadyBlockRow: View {
    let steady: WorkoutPrescriptionDisplayModel.SteadyBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(steady.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            HStack(spacing: 8) {
                if let duration = steady.durationMinutes {
                    WorkoutDetailIntervalCell(label: "Time", value: "\(duration) min")
                }
                if let distance = steady.distanceKilometers {
                    WorkoutDetailIntervalCell(label: "Distance", value: "\(max(1, Int(distance.rounded()))) km")
                }
                if let elevation = steady.elevationMeters {
                    WorkoutDetailIntervalCell(label: "Elevation", value: "\(max(1, Int(elevation.rounded()))) m")
                }
            }

            Text(steady.target)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            if let terrainNotes = steady.terrainNotes, !terrainNotes.isEmpty {
                Text(terrainNotes)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
            }
        }
        .padding(12)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct WorkoutWalkRunBlockRow: View {
    let walkRun: WorkoutPrescriptionDisplayModel.WalkRunBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(walkRun.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text("\(walkRun.repeats)x")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(HAYFColor.orange)
            }

            HStack(spacing: 8) {
                WorkoutDetailIntervalCell(label: "Run", value: walkRun.runDuration)
                WorkoutDetailIntervalCell(label: "Walk", value: walkRun.walkDuration)
            }

            Text(walkRun.target)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !walkRun.notes.isEmpty {
                Text(walkRun.notes)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct WorkoutMobilityBlockRow: View {
    let mobility: WorkoutPrescriptionDisplayModel.MobilityBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mobility.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            Text("\(mobility.durationMinutes) min · \(mobility.movementFocus)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HAYFColor.secondary)

            ForEach(Array(mobility.steps.enumerated()), id: \.offset) { _, step in
                Text(step)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct WorkoutDetailTagSection: View {
    let title: String
    let tags: [String]

    var body: some View {
        WorkoutDetailSectionContainer(title: title) {
            WorkoutPillFlow(spacing: 7, rowSpacing: 7) {
                ForEach(tags.prefix(6), id: \.self) { tag in
                    WorkoutDetailMiniPill(text: tag)
                }
            }
        }
    }
}

private struct WorkoutDetailMiniPill: View {
    let text: String

    var body: some View {
        Text(WorkoutVisibleCopy.sanitize(text))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(HAYFColor.primary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minHeight: 24)
            .background(HAYFColor.neutral)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
    }
}

private struct WorkoutDetailSectionContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HAYFColor.surface.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private struct WorkoutPillFlow: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8
    var fallbackWidth: CGFloat = 240

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposedWidth(proposal.width), subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for item in result.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
            )
        }
    }

    private func layout(in availableWidth: CGFloat, subviews: Subviews) -> (size: CGSize, items: [(index: Int, origin: CGPoint, size: CGSize)]) {
        let maxWidth = availableWidth.isFinite ? max(availableWidth, 1) : fallbackWidth
        var items: [(index: Int, origin: CGPoint, size: CGSize)] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for index in subviews.indices {
            let intrinsicSize = subviews[index].sizeThatFits(.unspecified)
            let measuredSize = intrinsicSize.width > maxWidth
                ? subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                : intrinsicSize
            let size = CGSize(width: min(measuredSize.width, maxWidth), height: measuredSize.height)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + rowSpacing
                x = 0
                rowHeight = 0
            }

            items.append((index, CGPoint(x: x, y: y), size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, min(maxWidth, x - spacing))
        }

        return (CGSize(width: usedWidth, height: y + rowHeight), items)
    }

    private func proposedWidth(_ width: CGFloat?) -> CGFloat {
        guard let width, width.isFinite, width > 0 else {
            return fallbackWidth
        }
        return width
    }
}

private struct WorkoutCardDisplayModel {
    let title: String
    let modalityEmoji: String
    let stateEmoji: String?
    let stateColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let backgroundTintOpacity: Double
    let metricPills: [PlanWorkoutCardPillModel]
    let contextPills: [PlanWorkoutCardPillModel]
    let distanceText: String?
    let elevationText: String?

    init(workout: PlanWorkout, fallbackLocationLabel: String?) {
        let source = WorkoutCardDisplaySource(
            activityType: workout.activityType,
            title: workout.title,
            durationMinutes: workout.durationMinutes,
            intensityLabel: workout.intensityLabel,
            purpose: workout.purpose,
            status: workout.status,
            source: workout.source,
            estimatedDistanceKilometers: workout.estimatedDistanceKilometers,
            estimatedElevationMeters: workout.estimatedElevationMeters,
            scheduledDate: workout.scheduledDate,
            plannedLocationLabel: workout.plannedLocationLabel,
            weatherForecast: workout.weatherForecast,
            fallbackLocationLabel: fallbackLocationLabel,
            prescription: workout.prescription
        )
        self.init(source: source)
    }

    init(candidate: PlanningWorkoutCandidate, scheduledDate: String, fallbackLocationLabel: String?) {
        let source = WorkoutCardDisplaySource(
            activityType: candidate.activityType,
            title: candidate.title,
            durationMinutes: candidate.durationMinutes,
            intensityLabel: candidate.intensityLabel,
            purpose: candidate.purpose,
            status: nil,
            source: "candidate",
            estimatedDistanceKilometers: candidate.estimatedDistanceKilometers,
            estimatedElevationMeters: candidate.estimatedElevationMeters,
            scheduledDate: scheduledDate,
            plannedLocationLabel: candidate.plannedLocationLabel,
            weatherForecast: nil,
            fallbackLocationLabel: fallbackLocationLabel,
            prescription: nil
        )
        self.init(source: source)
    }

    private init(source: WorkoutCardDisplaySource) {
        let titleBuilder = WorkoutCardTaxonomy(source: source)
        title = titleBuilder.title
        modalityEmoji = titleBuilder.modalityEmoji

        switch (source.status, source.source) {
        case (.done, _), (_, "healthkit_detected"):
            stateEmoji = "✅"
            stateColor = HAYFColor.primary
            borderColor = HAYFColor.primary.opacity(0.74)
            borderWidth = 1
            backgroundTintOpacity = 0
        case (.missed, _):
            stateEmoji = "❌"
            stateColor = HAYFColor.primary
            borderColor = HAYFColor.primary.opacity(0.74)
            borderWidth = 1
            backgroundTintOpacity = 0
        case (.current, _):
            stateEmoji = nil
            stateColor = HAYFColor.orange
            borderColor = HAYFColor.orange
            borderWidth = 1
            backgroundTintOpacity = 0.035
        default:
            stateEmoji = nil
            stateColor = HAYFColor.primary
            borderColor = HAYFColor.primary.opacity(0.74)
            borderWidth = 1
            backgroundTintOpacity = 0
        }

        var metrics: [PlanWorkoutCardPillModel] = [
            PlanWorkoutCardPillModel(emoji: "⌚", text: Self.durationText(source.durationMinutes))
        ]
        distanceText = titleBuilder.distanceText
        elevationText = titleBuilder.elevationText

        if let distanceText {
            metrics.append(PlanWorkoutCardPillModel(emoji: "🛣️", text: distanceText))
        }
        if let elevationText {
            metrics.append(PlanWorkoutCardPillModel(emoji: "⛰️", text: elevationText))
        }
        metrics.append(PlanWorkoutCardPillModel(emoji: "🔥", text: titleBuilder.intensityText))
        metrics.append(PlanWorkoutCardPillModel(emoji: "🎯", text: titleBuilder.targetText))
        metricPills = metrics

        let plannedLocation = Self.resolvedPlannedLocationLabel(source: source)
        let location = plannedLocation ?? Self.compactOptionalString(source.fallbackLocationLabel)
        let forecast = PlanWorkoutForecastDisplay(
            storedForecast: source.weatherForecast,
            scheduledDate: source.scheduledDate
        )
        contextPills = [
            PlanWorkoutCardPillModel(emoji: forecast.emoji, text: forecast.temperatureText),
            PlanWorkoutCardPillModel(emoji: Self.locationEmoji(for: plannedLocation, fallbackLocationLabel: source.fallbackLocationLabel), text: Self.shortLocation(location))
        ]
    }

    private static func durationText(_ minutes: Int) -> String {
        if minutes >= 180, minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }
        return "\(minutes) min"
    }

    private static func locationEmoji(for plannedLocationLabel: String?, fallbackLocationLabel: String?) -> String {
        guard let plannedLocation = compactOptionalString(plannedLocationLabel),
              let fallbackLocation = compactOptionalString(fallbackLocationLabel),
              normalizedLocation(plannedLocation) != normalizedLocation(fallbackLocation) else {
            return "🏠"
        }
        return "✈️"
    }

    private static func shortLocation(_ location: String?) -> String {
        guard let location = compactOptionalString(location) else { return "Home" }
        return compactOptionalString(location.components(separatedBy: ",").first) ?? location
    }

    private static func compactOptionalString(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func resolvedPlannedLocationLabel(source: WorkoutCardDisplaySource) -> String? {
        compactOptionalString(source.plannedLocationLabel)
    }

    private static func normalizedLocation(_ value: String) -> String {
        let primaryLabel = value.components(separatedBy: ",").first ?? value
        return primaryLabel
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .lowercased()
    }
}

private struct WorkoutCardDisplaySource {
    let activityType: String
    let title: String
    let durationMinutes: Int
    let intensityLabel: String
    let purpose: String
    let status: PlanWorkoutStatus?
    let source: String
    let estimatedDistanceKilometers: Double?
    let estimatedElevationMeters: Double?
    let scheduledDate: String
    let plannedLocationLabel: String?
    let weatherForecast: JSONValue?
    let fallbackLocationLabel: String?
    let prescription: JSONValue?
}

private struct PlanWorkoutCardPillModel: Identifiable {
    let id = UUID()
    let emoji: String
    let text: String
}

private struct PlanWorkoutForecastDisplay {
    let emoji: String
    let temperatureText: String

    init(storedForecast: JSONValue?, scheduledDate: String) {
        let object = storedForecast?.planObjectValue ?? [:]
        guard
            object["forecastDate"]?.planStringValue == scheduledDate,
            let storedEmoji = object["conditionEmoji"]?.planStringValue,
            let temperature = object["temperatureCelsius"]?.planNumberValue
        else {
            emoji = "🌡"
            temperatureText = "Pending"
            return
        }

        emoji = storedEmoji
        temperatureText = "\(Int(temperature.rounded()))C"
    }
}

private struct WorkoutCardTaxonomy {
    enum Modality {
        case ride
        case run
        case swim
        case row
        case hike
        case walk
        case strength
        case mobility
        case recovery
        case other
    }

    let source: WorkoutCardDisplaySource

    var title: String {
        if preservesCustomUserTitle {
            return compactTitle(source.title, maxWords: 4)
        }
        if preservesPlannerDescriptiveTitle {
            return compactTitle(source.title, maxWords: 6)
        }

        switch modality {
        case .ride:
            if contains("interval") || contains("vo2") || contains("zone 4") || contains("z4") || contains("zone 5") || contains("z5") {
                return "Cycling intervals"
            }
            if contains("recover") || contains("easy spin") {
                return "Easy ride"
            }
            if source.durationMinutes >= 90 || contains("long") {
                return "Long ride"
            }
            if contains("tempo") || contains("threshold") || contains("steady") {
                return "Tempo ride"
            }
            return "Easy ride"
        case .hike:
            if contains("hard") || contains("high") || contains("mountain") {
                return "Hard Hike"
            }
            if source.durationMinutes >= 180 || contains("long") || contains("route") || contains("elevation") || contains("vert") {
                return "Long Hike"
            }
            return "Easy Hike"
        case .strength:
            if isHealthKitOnlyDetected {
                return "Strength"
            }
            if contains("maintain") || contains("maintenance") {
                return "Strength maintenance"
            }
            if contains("build") || contains("heavy") || contains("progress") || contains("hypertrophy") {
                return "Strength build"
            }
            return "Strength support"
        case .run:
            if contains("tempo") || contains("threshold") { return "Tempo run" }
            if contains("interval") || contains("vo2") { return "Run intervals" }
            if contains("recover") { return "Easy run" }
            return source.durationMinutes >= 70 || contains("long") ? "Long run" : "Easy run"
        case .swim:
            if contains("interval") || contains("vo2") { return "Intervals Swim" }
            if contains("recover") { return "Recovery Swim" }
            return "Base Swim"
        case .mobility:
            return "Mobility"
        case .recovery:
            return "Recovery"
        case .walk:
            return contains("recover") || contains("easy") ? "Recovery Walk" : "Walk"
        case .row:
            if contains("interval") || contains("vo2") { return "Intervals Row" }
            return "Base Row"
        case .other:
            return compactTitle(source.title, maxWords: 3)
        }
    }

    var modalityEmoji: String {
        switch modality {
        case .ride: return "🚴‍♂️"
        case .run: return "🏃🏻‍♂️‍➡️"
        case .swim: return "🏊"
        case .row: return "🚣"
        case .hike: return "🥾"
        case .walk: return "🚶"
        case .strength: return "🏋️‍♂️"
        case .mobility: return "🧘"
        case .recovery: return "🛌"
        case .other: return "🏃🏻‍♂️‍➡️"
        }
    }

    var distanceText: String? {
        guard isDistanceEligible else { return nil }
        let distance = distanceKilometers
        guard let distance else { return nil }
        return "\(max(1, Int(distance.rounded()))) km"
    }

    var elevationText: String? {
        guard isElevationEligible else { return nil }
        let elevation = elevationMeters
        guard let elevation, elevation > 0 else { return nil }
        return "\(max(1, Int(elevation.rounded())))m"
    }

    var intensityText: String {
        let textualIntensity = textualIntensityText
        if textualIntensity == "high" {
            return "high"
        }
        if objectiveLoadIntensity == "high" {
            return "high"
        }
        if textualIntensity == "mid" {
            return "mid"
        }
        if objectiveLoadIntensity == "mid" {
            return "mid"
        }
        return "low"
    }

    var targetText: String {
        if contains("threshold") || title.contains("Tempo") { return "Threshold" }
        if contains("vo2") { return "VO2Max" }
        if title.lowercased().contains("interval") { return "VO2Max" }
        if title.contains("Recovery") || contains("recover") || modality == .recovery { return "Recovery" }
        if modality == .strength { return "Strength" }
        if modality == .mobility { return "Mobility" }
        if ["Easy ride", "Long ride", "Easy run", "Long run", "Easy Hike", "Long Hike", "Base Swim"].contains(title) {
            return "Endurance"
        }
        if contains("endurance") || contains("aerobic") || contains("base") { return "Endurance" }
        if contains("power") { return "Power" }
        if contains("support") || contains("maintenance") { return "Support" }
        return "Support"
    }

    private var estimatedDistanceKilometers: Double? {
        guard !isWalkRunPrescription else { return nil }
        let minutes = Double(source.durationMinutes)
        guard minutes > 0 else { return nil }
        let textualIntensity = textualIntensityText
        let speed: Double?
        switch modality {
        case .ride:
            speed = textualIntensity == "high" ? 28 : textualIntensity == "mid" ? 24 : 22
        case .run:
            speed = textualIntensity == "high" ? 11 : textualIntensity == "mid" ? 10 : 9
        case .walk:
            speed = 5
        case .hike:
            speed = 4.5
        case .row:
            speed = 8
        case .swim:
            speed = 2
        default:
            speed = nil
        }
        guard let speed else { return nil }
        return max(1, (minutes / 60) * speed).rounded()
    }

    private var distanceKilometers: Double? {
        guard !isWalkRunPrescription else { return nil }
        return explicitRouteDistanceKilometers ?? estimatedDistanceKilometers
    }

    private var isWalkRunPrescription: Bool {
        let object = source.prescription?.planObjectValue ?? [:]
        let main = object["main"]?.planObjectValue ?? [:]
        return (main["blocks"]?.planArrayValue ?? []).contains { block in
            let kind = block.planObjectValue["kind"]?.planStringValue
            return kind == "walkRun" || kind == "walk_run"
        }
    }

    private var elevationMeters: Double? {
        source.estimatedElevationMeters ?? parsedElevationMeters
    }

    private var objectiveLoadIntensity: String? {
        let distance = explicitRouteDistanceKilometers ?? 0
        let elevation = elevationMeters ?? 0
        switch modality {
        case .hike:
            if distance >= 20 || elevation >= 1_000 || (distance >= 15 && elevation >= 700) {
                return "high"
            }
            if distance >= 10 || elevation >= 400 || (distance >= 8 && elevation >= 250) {
                return "mid"
            }
        case .ride:
            if distance >= 100 || elevation >= 1_200 || (distance >= 80 && elevation >= 800) || source.durationMinutes >= 240 {
                return "high"
            }
            if distance >= 60 || elevation >= 500 || (distance >= 45 && elevation >= 300) || source.durationMinutes >= 120 {
                return "mid"
            }
        default:
            break
        }
        return nil
    }

    private var explicitRouteDistanceKilometers: Double? {
        source.estimatedDistanceKilometers ?? parsedDistanceKilometers
    }

    private var textualIntensityText: String {
        if contains("high") || contains("hard") || contains("threshold") || contains("vo2") || contains("interval") || contains("zone 4") || contains("z4") || contains("zone 5") || contains("z5") || contains("race") {
            return "high"
        }
        if contains("moderate") || contains("mid") || contains("steady") || contains("tempo") || contains("zone 3") || contains("z3") {
            return "mid"
        }
        return "low"
    }

    private var modality: Modality {
        if let prescriptionModality {
            return prescriptionModality
        }
        if let titleModality = storedTitleModality, [.strength, .mobility, .recovery].contains(titleModality) {
            return titleModality
        }
        if activityTypeContains("strength") || activityTypeContains("traditional") { return .strength }
        if activityTypeContains("mobility") || activityTypeContains("yoga") || activityTypeContains("pilates") { return .mobility }
        if activityTypeContains("run") { return .run }
        if activityTypeContains("cycl") || activityTypeContains("bike") || activityTypeContains("ride") { return .ride }
        if activityTypeContains("swim") { return .swim }
        if activityTypeContains("row") { return .row }
        if activityTypeContains("walk") { return .walk }
        if activityTypeContains("hike") || activityTypeContains("hik") { return .hike }
        if contains("ride") || contains("cycl") || contains("bike") { return .ride }
        if contains("run") { return .run }
        if contains("swim") { return .swim }
        if containsWord("row") || containsWord("rows") || containsWord("rowing") || containsWord("rower") { return .row }
        if contains("walk") { return .walk }
        if contains("hike") || contains("hik") { return .hike }
        if contains("strength") || contains("gym") || contains("lift") || contains("weights") || contains("body") || contains("upper") || contains("lower") { return .strength }
        if contains("mobility") || contains("yoga") || contains("pilates") || contains("stretch") || contains("core") || contains("prehab") { return .mobility }
        if contains("recover") || contains("restorative") || contains("rest") { return .recovery }
        return .other
    }

    private var prescriptionModality: Modality? {
        let object = source.prescription?.planObjectValue ?? [:]
        guard let schemaVersion = object["schemaVersion"]?.planNumberValue,
              (1...2).contains(schemaVersion) else { return nil }
        let main = object["main"]?.planObjectValue ?? [:]
        let blocks = main["blocks"]?.planArrayValue ?? []
        let kinds = Set(blocks.compactMap { block -> String? in
            block.planObjectValue["kind"]?.planStringValue
        })
        if kinds.contains("strengthExercise") { return .strength }
        if kinds.contains("mobilityRecovery") { return .mobility }
        if kinds.contains("walkRun") || kinds.contains("walk_run") { return .run }
        return nil
    }

    private var isDistanceEligible: Bool {
        [.ride, .run, .hike, .walk, .swim, .row].contains(modality)
    }

    private var isElevationEligible: Bool {
        [.ride, .hike].contains(modality)
    }

    private var parsedDistanceKilometers: Double? {
        let pattern = #"(\d+(?:[,.]\d+)?)\s*(?:km|kilometer|kilometers|kilometre|kilometres)\b"#
        guard let range = normalized.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(normalized[range])
        let number = match.replacingOccurrences(of: #"[^0-9,.]"#, with: "", options: .regularExpression)
        return parsedDecimal(number)
    }

    private var parsedElevationMeters: Double? {
        let patterns = [
            #"(\d+(?:[,.]\d+)?)\s*k\s*m\s*(?:elev|elevation|gain|climb|climbing|vert|vertical|ascent)\b"#,
            #"(\d+(?:[,.]\d+)?)\s*(?:m|meter|meters|metre|metres)\s*(?:elev|elevation|gain|climb|climbing|vert|vertical|ascent)\b"#,
            #"(?:elev|elevation|gain|climb|climbing|vert|vertical|ascent)\s*(?:of\s*)?(\d+(?:[,.]\d+)?)\s*k?\s*m\b"#,
            #"\b(\d{3,5})\s*m\b"#
        ]
        for pattern in patterns {
            guard let range = normalized.range(of: pattern, options: .regularExpression) else { continue }
            let match = String(normalized[range])
            let isThousands = match.range(of: #"\d+(?:[,.]\d+)?\s*k\s*m"#, options: .regularExpression) != nil
            let number = match.replacingOccurrences(of: #"[^0-9,.]"#, with: "", options: .regularExpression)
            guard let value = parsedDecimal(number) else { continue }
            return isThousands ? value * 1_000 : value
        }
        return nil
    }

    private func parsedDecimal(_ value: String) -> Double? {
        if value.contains(","),
           let suffix = value.split(separator: ",").last,
           suffix.count == 3 {
            return Double(value.replacingOccurrences(of: ",", with: ""))
        }
        return Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private var isHealthKitOnlyDetected: Bool {
        source.source == "healthkit_detected"
    }

    private var preservesCustomUserTitle: Bool {
        guard source.source.contains("user") || source.source == "candidate" else { return false }
        let title = source.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = title.lowercased()
        guard !title.isEmpty else { return false }
        if lower.range(of: #"day\s*\d+"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"stage\s*\d+"#, options: .regularExpression) != nil { return true }
        if contains("event") || contains("race") || contains("route") { return true }
        return false
    }

    private var preservesPlannerDescriptiveTitle: Bool {
        guard ["generated", "replanned", "candidate"].contains(source.source) else { return false }
        let title = source.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = title.lowercased()
        guard !title.isEmpty else { return false }
        if let prescriptionModality,
           let storedTitleModality,
           prescriptionModality != storedTitleModality {
            return false
        }
        if ["full body a", "base ride", "long ride", "base run", "long run"].contains(lower) { return false }
        if lower.range(of: #"\b(full|upper|lower)\s+body\s+[a-e]\b"#, options: .regularExpression) != nil { return false }
        return lower.range(
            of: #"\b(support|maintenance|build|aerobic|endurance|tempo|interval|strength|ride|run|mobility|recovery)\b"#,
            options: .regularExpression
        ) != nil
    }

    private var storedTitleModality: Modality? {
        let title = source.title.lowercased()
        if title.range(of: #"\b(strength|lift|gym|weights|full body|upper body|lower body|upper|lower)\b"#, options: .regularExpression) != nil { return .strength }
        if title.range(of: #"\b(mobility|yoga|pilates|stretch|core|prehab)\b"#, options: .regularExpression) != nil { return .mobility }
        if title.range(of: #"\b(ride|cycling|bike)\b"#, options: .regularExpression) != nil { return .ride }
        if title.range(of: #"\b(run|running|jog)\b"#, options: .regularExpression) != nil { return .run }
        if title.range(of: #"\b(swim|swimming)\b"#, options: .regularExpression) != nil { return .swim }
        if title.range(of: #"\b(row|rowing|rower)\b"#, options: .regularExpression) != nil { return .row }
        if title.range(of: #"\b(walk|walking)\b"#, options: .regularExpression) != nil { return .walk }
        if title.range(of: #"\b(hike|hiking)\b"#, options: .regularExpression) != nil { return .hike }
        if title.range(of: #"\b(recovery|recover)\b"#, options: .regularExpression) != nil { return .recovery }
        return nil
    }

    private var normalized: String {
        "\(source.activityType) \(source.title) \(source.intensityLabel) \(source.purpose)"
            .lowercased()
    }

    private func contains(_ value: String) -> Bool {
        normalized.contains(value)
    }

    private func containsWord(_ value: String) -> Bool {
        normalized.range(
            of: "\\b\(NSRegularExpression.escapedPattern(for: value))\\b",
            options: .regularExpression
        ) != nil
    }

    private func activityTypeContains(_ value: String) -> Bool {
        source.activityType.lowercased().contains(value)
    }

    private func compactTitle(_ value: String, maxWords: Int) -> String {
        let cleaned = WorkoutVisibleCopy.sanitize(value)
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+-\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s*[-:|]+\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "Workout" }
        var compact = cleaned.split(separator: " ").prefix(min(maxWords, 4)).joined(separator: " ")
        while compact.count > 32, compact.contains(" ") {
            compact = compact.split(separator: " ").dropLast().joined(separator: " ")
        }
        return compact.isEmpty ? "Workout" : compact
    }
}

private extension JSONValue {
    var planStringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    var planNumberValue: Double? {
        if case let .number(value) = self {
            return value
        }
        return nil
    }

    var planArrayValue: [JSONValue] {
        if case let .array(value) = self {
            return value
        }
        return []
    }

    var planObjectValue: [String: JSONValue] {
        if case let .object(value) = self {
            return value
        }
        return [:]
    }
}

private struct WorkoutPrescriptionDisplayModel {
    struct StepGroup {
        let title: String
        let description: String
        let durationMinutes: Int?
        let steps: [String]
    }

    struct StrengthExercise {
        struct Alternative {
            let exerciseName: String
            let equipment: String
            let notes: String
        }

        let exerciseName: String
        let machineOrEquipment: String
        let sets: Int?
        let reps: String
        let restSeconds: Int?
        let effortTarget: String
        let coachingCue: String
        let alternatives: [Alternative]

        var setsReps: String {
            if let sets {
                return "\(sets) x \(reps)"
            }
            return reps
        }

        var restText: String {
            guard let restSeconds else { return "Rest as needed" }
            return "\(restSeconds) sec"
        }
    }

    struct IntervalBlock {
        let title: String
        let repeats: Int
        let workDuration: String
        let recoveryDuration: String
        let target: String
        let notes: String
    }

    struct SteadyBlock {
        let title: String
        let durationMinutes: Int?
        let distanceKilometers: Double?
        let elevationMeters: Double?
        let target: String
        let terrainNotes: String?
    }

    struct MobilityBlock {
        let title: String
        let durationMinutes: Int
        let movementFocus: String
        let steps: [String]
    }

    struct WalkRunBlock {
        let title: String
        let repeats: Int
        let runDuration: String
        let walkDuration: String
        let target: String
        let notes: String
    }

    struct MainBlock: Identifiable {
        enum Kind {
            case strength(StrengthExercise)
            case interval(IntervalBlock)
            case steady(SteadyBlock)
            case mobility(MobilityBlock)
            case walkRun(WalkRunBlock)
            case text(String)
        }

        let id = UUID()
        let kind: Kind
    }

    let summary: String
    let whyToday: String
    let warmup: StepGroup
    let blocks: [MainBlock]
    let cooldown: StepGroup
    let successCriteria: String
    let equipment: [String]
    let constraintsApplied: [String]

    init(workout: PlanWorkout) {
        let object = workout.prescription?.planObjectValue ?? [:]
        let schemaVersion = object["schemaVersion"]?.planNumberValue
        if let schemaVersion, (1...2).contains(schemaVersion) {
            summary = Self.stringValue(object["summary"]) ?? WorkoutVisibleCopy.sanitize(workout.purpose)
            whyToday = Self.stringValue(object["whyToday"])
                ?? Self.stringValue(object["why_today"])
                ?? summary
            warmup = Self.stepGroup(from: object["warmup"], fallbackTitle: "Warm up", fallbackText: "Start easy and prepare for the main work.")
            blocks = Self.mainBlocks(from: object["main"])
            cooldown = Self.stepGroup(from: object["cooldown"], fallbackTitle: "Cool down", fallbackText: "Finish easy and note any recovery flags.")
            successCriteria = Self.stringValue(object["successCriteria"]) ?? "Complete the planned dose with clean form and controlled effort."
            equipment = Self.stringArray(object["equipment"])
            constraintsApplied = Self.stringArray(object["constraintsApplied"])
            return
        }

        let warmupText = Self.stringValue(object["warmup"]) ?? "Start easy and check readiness."
        let mainTexts = Self.stringArray(object["main"])
        let cooldownText = Self.stringValue(object["cooldown"]) ?? "Finish easy."
        summary = WorkoutVisibleCopy.sanitize(workout.purpose)
        whyToday = summary
        warmup = StepGroup(title: "Warm up", description: warmupText, durationMinutes: nil, steps: [warmupText])
        blocks = (mainTexts.isEmpty ? [workout.purpose] : mainTexts).map { MainBlock(kind: .text($0)) }
        cooldown = StepGroup(title: "Cool down", description: cooldownText, durationMinutes: nil, steps: [cooldownText])
        successCriteria = Self.stringValue(object["successCriteria"]) ?? "Complete the planned dose with control."
        equipment = []
        constraintsApplied = []
    }

    private static func stepGroup(from value: JSONValue?, fallbackTitle: String, fallbackText: String) -> StepGroup {
        let object = value?.planObjectValue ?? [:]
        let text = stringValue(value) ?? stringValue(object["description"]) ?? fallbackText
        return StepGroup(
            title: stringValue(object["title"]) ?? fallbackTitle,
            description: text,
            durationMinutes: intValue(object["durationMinutes"]),
            steps: nonEmptyStrings(stringArray(object["steps"]), fallback: [text])
        )
    }

    private static func mainBlocks(from value: JSONValue?) -> [MainBlock] {
        let mainObject = value?.planObjectValue ?? [:]
        let blockValues = mainObject["blocks"]?.planArrayValue ?? value?.planArrayValue ?? []
        let blocks = blockValues.compactMap(block(from:))
        if !blocks.isEmpty { return blocks }
        if let text = stringValue(value) ?? stringValue(mainObject["description"]) {
            return [MainBlock(kind: .text(text))]
        }
        return [MainBlock(kind: .text("Complete the planned main work with control."))]
    }

    private static func block(from value: JSONValue) -> MainBlock? {
        let object = value.planObjectValue
        switch rawStringValue(object["kind"]) {
        case "strengthExercise":
            let alternatives = (object["alternatives"]?.planArrayValue ?? []).map { alternative -> StrengthExercise.Alternative in
                let alt = alternative.planObjectValue
                return StrengthExercise.Alternative(
                    exerciseName: stringValue(alt["exerciseName"]) ?? "Alternative",
                    equipment: stringValue(alt["equipment"]) ?? "Available equipment",
                    notes: stringValue(alt["notes"]) ?? ""
                )
            }
            return MainBlock(kind: .strength(StrengthExercise(
                exerciseName: stringValue(object["exerciseName"]) ?? stringValue(object["title"]) ?? "Strength exercise",
                machineOrEquipment: stringValue(object["machineOrEquipment"]) ?? "Available equipment",
                sets: intValue(object["sets"]),
                reps: stringValue(object["reps"]) ?? "8-10",
                restSeconds: intValue(object["restSeconds"]),
                effortTarget: stringValue(object["effortTarget"]) ?? "Controlled effort",
                coachingCue: stringValue(object["coachingCue"]) ?? "",
                alternatives: alternatives
            )))
        case "interval":
            return MainBlock(kind: .interval(IntervalBlock(
                title: stringValue(object["title"]) ?? "Intervals",
                repeats: intValue(object["repeats"]) ?? 1,
                workDuration: stringValue(object["workDuration"]) ?? "Work",
                recoveryDuration: stringValue(object["recoveryDuration"]) ?? "Recover",
                target: stringValue(object["target"]) ?? "Controlled hard",
                notes: stringValue(object["notes"]) ?? ""
            )))
        case "steady":
            return MainBlock(kind: .steady(SteadyBlock(
                title: stringValue(object["title"]) ?? "Steady work",
                durationMinutes: intValue(object["durationMinutes"]),
                distanceKilometers: object["distanceKilometers"]?.planNumberValue,
                elevationMeters: object["elevationMeters"]?.planNumberValue,
                target: stringValue(object["target"]) ?? "Controlled effort",
                terrainNotes: stringValue(object["terrainNotes"])
            )))
        case "mobilityRecovery":
            return MainBlock(kind: .mobility(MobilityBlock(
                title: stringValue(object["title"]) ?? "Mobility",
                durationMinutes: intValue(object["durationMinutes"]) ?? 10,
                movementFocus: stringValue(object["movementFocus"]) ?? "easy movement",
                steps: nonEmptyStrings(stringArray(object["steps"]), fallback: [stringValue(object["description"]) ?? "Move easily"])
            )))
        case "walkRun", "walk_run":
            return MainBlock(kind: .walkRun(WalkRunBlock(
                title: stringValue(object["title"]) ?? "Walk-run intervals",
                repeats: max(1, intValue(object["repeats"]) ?? 1),
                runDuration: durationText(
                    stringValue(object["runDuration"]),
                    minutes: intValue(object["runDurationMinutes"])
                ),
                walkDuration: durationText(
                    stringValue(object["walkDuration"]),
                    minutes: intValue(object["walkDurationMinutes"])
                ),
                target: stringValue(object["target"]) ?? "Easy, conversational running",
                notes: stringValue(object["notes"]) ?? ""
            )))
        default:
            return stringValue(value).map { MainBlock(kind: .text($0)) }
        }
    }

    private static func stringArray(_ value: JSONValue?) -> [String] {
        if let string = stringValue(value) {
            return [string]
        }
        return value?.planArrayValue.compactMap(stringValue) ?? []
    }

    private static func nonEmptyStrings(_ values: [String], fallback: [String]) -> [String] {
        let compact = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return compact.isEmpty ? fallback : compact
    }

    private static func stringValue(_ value: JSONValue?) -> String? {
        guard let string = rawStringValue(value),
              !string.isEmpty else {
            return nil
        }
        let sanitized = WorkoutVisibleCopy.sanitize(string)
        return sanitized.isEmpty ? nil : sanitized
    }

    private static func rawStringValue(_ value: JSONValue?) -> String? {
        guard let string = value?.planStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else {
            return nil
        }
        return string
    }

    private static func durationText(_ text: String?, minutes: Int?) -> String {
        if let text, !text.isEmpty { return text }
        guard let minutes else { return "1 min" }
        return "\(max(1, minutes)) min"
    }

    private static func intValue(_ value: JSONValue?) -> Int? {
        guard let number = value?.planNumberValue, number.isFinite else { return nil }
        return Int(number.rounded())
    }
}

private enum WorkoutDetailFormatting {
    static func duration(_ minutes: Int) -> String {
        if minutes >= 120, minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }
        return "\(minutes) min"
    }

    static func location(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "Home" }
        return trimmed.components(separatedBy: ",").first ?? trimmed
    }

    static func shortFuel(_ value: String?) -> String {
        let trimmed = WorkoutVisibleCopy.sanitize(value ?? "")
        let lowercased = trimmed.lowercased()
        guard !trimmed.isEmpty else { return "Normal meals" }
        if lowercased.contains("protein") && (lowercased.contains("carb") || lowercased.contains("fruit")) {
            return "Protein + carbs"
        }
        if lowercased.contains("protein") { return "Protein snack" }
        if lowercased.contains("carb") { return "Carbs + water" }
        if lowercased.contains("hydrat") || lowercased.contains("water") { return "Hydrate" }
        if lowercased.contains("meal") || lowercased.contains("normal") || lowercased.contains("usual") {
            return "Normal meals"
        }
        let words = trimmed.split(separator: " ").prefix(3).joined(separator: " ")
        return words.count <= 20 && !words.isEmpty ? words : "Normal meals"
    }
}

private struct PlanLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            PlanLegendItem(kind: .done, label: "Done")
            PlanLegendItem(kind: .planned, label: "Planned")
            PlanLegendItem(kind: .current, label: "Current")
            PlanLegendItem(kind: .adjusted, label: "Adjusted")
            PlanLegendItem(kind: .missed, label: "Missed")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct PlanLegendItem: View {
    let kind: PlanWorkoutStatus
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            PlanLegendDot(kind: kind)

            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct PlanLegendDot: View {
    let kind: PlanWorkoutStatus

    var body: some View {
        switch kind {
        case .done:
            Circle()
                .fill(HAYFColor.primary)
                .frame(width: 12, height: 12)
        case .current:
            Circle()
                .fill(HAYFColor.orange)
                .frame(width: 12, height: 12)
        case .adjusted:
            Circle()
                .stroke(HAYFColor.orange, lineWidth: 2)
                .frame(width: 12, height: 12)
        case .missed:
            Circle()
                .stroke(HAYFColor.error, lineWidth: 2)
                .frame(width: 12, height: 12)
        default:
            Circle()
                .stroke(HAYFColor.muted, lineWidth: 1.5)
                .frame(width: 12, height: 12)
        }
    }
}

private struct PlanNoWorkoutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No visible sessions yet.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            Text("Pull to refresh after the planning engine finishes bootstrapping.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
        }
        .padding(.vertical, 10)
    }
}

private struct PlanEmptyView: View {
    let errorMessage: String?
    let reload: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HAYFLogo(markSize: 34, textSize: 30, spacing: 10)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Plan")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(HAYFColor.primary)

                Text(errorMessage ?? "No active plan found yet.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await reload() }
            } label: {
                Text("Refresh")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HAYFColor.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

private struct PlanLoadingView: View {
    var body: some View {
        VStack(spacing: 18) {
            HAYFLogo(markSize: 28, textSize: 24, spacing: 8)

            ProgressView()
                .tint(HAYFColor.orange)
        }
    }
}

private struct PlanErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(HAYFColor.primary)
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 520, alignment: .leading)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.error.opacity(0.35), lineWidth: 1)
            }
    }
}

private struct WeeklyPlanConstraintSheet: View {
    let context: PlanConstraintEditingContext
    let isSaving: Bool
    let save: (PlanningWeeklyPlanConstraintKind, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: PlanningWeeklyPlanConstraintKind
    @State private var note: String

    init(
        context: PlanConstraintEditingContext,
        isSaving: Bool,
        save: @escaping (PlanningWeeklyPlanConstraintKind, String?) -> Void
    ) {
        self.context = context
        self.isSaving = isSaving
        self.save = save
        _kind = State(initialValue: context.initialKind)
        _note = State(initialValue: context.initialNote)
    }

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(
                    overline: "DAY AVAILABILITY",
                    title: PlanDate.longLabel(context.date),
                    dismiss: { dismiss() }
                )

                Picker("Availability", selection: $kind) {
                    ForEach(PlanningWeeklyPlanConstraintKind.allCases) { option in
                        Text(option.planLabel)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HAYFColor.secondary)

                    TextField("Optional", text: $note, axis: .vertical)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(HAYFColor.primary)
                        .lineLimit(3...5)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(HAYFColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(HAYFColor.borderStrong, lineWidth: 1)
                        }
                }

                Spacer(minLength: 0)

                Button {
                    save(kind, note)
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }

                        Text("Save")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HAYFColor.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
    }
}

private extension PlanningWeeklyPlanConstraintKind {
    var planLabel: String {
        switch self {
        case .available:
            return "Available"
        case .limited:
            return "Limited"
        case .unavailable:
            return "Unavailable"
        }
    }
}

private struct WorkoutPlanningSheet: View {
    let context: WorkoutPlanningContext
    let candidates: [PlanningWorkoutCandidate]
    let fallbackLocationLabel: String?
    let isLoading: Bool
    let didFinishLoading: Bool
    let errorMessage: String?
    let retry: () -> Void
    let interpretManualWorkout: (String) async throws -> PlanningWorkoutCandidate
    let reviewCandidate: (PlanningWorkoutCandidate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(
                    overline: context.overline,
                    title: context.title,
                    dismiss: { dismiss() }
                )

                Text(context.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                ManualWorkoutComposer(
                    context: context,
                    fallbackLocationLabel: fallbackLocationLabel,
                    interpret: interpretManualWorkout,
                    reviewCandidate: reviewCandidate
                )

                if isLoading || (!didFinishLoading && candidates.isEmpty && errorMessage == nil) {
                    WorkoutPlanningLoadingView(messages: context.loadingMessages)
                } else if let errorMessage {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(errorMessage)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: retry) {
                            Text("Try again")
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
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            if candidates.isEmpty {
                                Text("No suggestions yet.")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(HAYFColor.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(candidates) { candidate in
                                    WorkoutCandidateCard(
                                        candidate: candidate,
                                        scheduledDate: context.scheduledDate,
                                        fallbackLocationLabel: fallbackLocationLabel,
                                        apply: { reviewCandidate(candidate) }
                                    )
                                }
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
    }
}

private struct ManualWorkoutComposer: View {
    let context: WorkoutPlanningContext
    let fallbackLocationLabel: String?
    let interpret: (String) async throws -> PlanningWorkoutCandidate
    let reviewCandidate: (PlanningWorkoutCandidate) -> Void

    @State private var text = ""
    @State private var previewCandidate: PlanningWorkoutCandidate?
    @State private var isInterpreting = false
    @State private var errorMessage: String?

    private let placeholder = "Describe the workout with type, size, and intensity. Example: \"Hike 25 km, 1,300 m elevation, steady effort\" or \"Long hike with elevation\"."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(3...5)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)

                HStack(spacing: 10) {
                    Button(action: {
                        Task { await previewManualWorkout() }
                    }) {
                        HStack(spacing: 8) {
                            if isInterpreting {
                                ProgressView()
                                    .tint(HAYFColor.primary)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13, weight: .semibold))
                            }

                            Text(isInterpreting ? "Reading workout" : "Preview workout")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(HAYFColor.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(HAYFColor.surface)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(HAYFColor.borderStrong, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isInterpreting)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                }
            }
            .padding(14)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.error)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let previewCandidate {
                WorkoutCandidateCard(
                    candidate: previewCandidate,
                    scheduledDate: context.scheduledDate,
                    fallbackLocationLabel: fallbackLocationLabel,
                    style: .manualPreview,
                    apply: { reviewCandidate(previewCandidate) }
                )
            }
        }
        .onChange(of: text) { _, _ in
            previewCandidate = nil
            errorMessage = nil
        }
    }

    private func previewManualWorkout() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isInterpreting = true
        errorMessage = nil
        defer { isInterpreting = false }

        do {
            previewCandidate = try await interpret(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WorkoutPlanningLoadingView: View {
    let messages: [String]

    @State private var messageIndex = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProgressView()
                .tint(HAYFColor.orange)
                .padding(.top, 2)

            Text(messages[safe: messageIndex] ?? "Finding a useful workout")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
                .fixedSize(horizontal: false, vertical: true)
                .id(messageIndex)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard !Task.isCancelled, !messages.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }
}

private struct WorkoutCandidateCard: View {
    enum Style {
        case suggestion
        case manualPreview
    }

    let candidate: PlanningWorkoutCandidate
    let scheduledDate: String
    let fallbackLocationLabel: String?
    var style: Style = .suggestion
    let apply: () -> Void

    private var display: WorkoutCardDisplayModel {
        WorkoutCardDisplayModel(
            candidate: candidate,
            scheduledDate: scheduledDate,
            fallbackLocationLabel: fallbackLocationLabel
        )
    }

    var body: some View {
        Button(action: apply) {
            WorkoutCardBody(
                display: display,
                minHeight: 130,
                titleSize: 18,
                titleWeight: .medium,
                borderColor: style == .manualPreview ? HAYFColor.orange : display.borderColor,
                borderWidth: style == .manualPreview ? 1.4 : display.borderWidth,
                backgroundTintColor: style == .manualPreview ? HAYFColor.orange : nil,
                backgroundTintOpacity: style == .manualPreview ? 0.055 : display.backgroundTintOpacity
            ) {
                if style == .manualPreview {
                    Text("Yours")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(HAYFColor.orange)
                        .clipShape(Capsule())
                } else {
                    PlanWorkoutStateMark(display: display, markSize: 18)
                }
            }
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct WorkoutChangeReview: Identifiable {
    let id = UUID()
    let context: WorkoutPlanningContext
    let candidate: PlanningWorkoutCandidate
}

private struct WorkoutChangeReviewSheet: View {
    let review: WorkoutChangeReview
    let workouts: [PlanWorkout]
    let fallbackLocationLabel: String?
    let isApplying: Bool
    let accept: () -> Void
    let cancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        SheetHeader(
                            overline: "PLAN CHANGE",
                            title: "Review this change",
                            dismiss: { dismiss() }
                        )

                        Text(introCopy)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        if let original = review.context.originalWorkout {
                            WorkoutReviewSection(title: "Current slot") {
                                WorkoutReviewWeekRow(
                                    title: original.title,
                                    metadata: "\(original.durationMinutes) min / \(original.intensityLabel) / \(original.purpose)",
                                    dateLabel: PlanDate.longLabel(original.scheduledDate),
                                    isProposed: false
                                )
                            }
                        }

                        WorkoutReviewSection(title: "Result") {
                            WorkoutCandidatePreviewCard(
                                candidate: review.candidate,
                                scheduledDate: review.context.scheduledDate,
                                fallbackLocationLabel: fallbackLocationLabel
                            )
                        }

                        WorkoutReviewSection(title: "Resulting week") {
                            VStack(spacing: 8) {
                                ForEach(previewItems) { item in
                                    WorkoutReviewWeekRow(
                                        title: item.title,
                                        metadata: item.metadata,
                                        dateLabel: item.dateLabel,
                                        isProposed: item.isProposed
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }

                VStack(spacing: 10) {
                    Button(action: accept) {
                        HStack(spacing: 10) {
                            if isApplying {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text("Accept change")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(HAYFColor.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isApplying)

                    Button(action: cancel) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(HAYFColor.surface)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isApplying)

                    Button(action: {}) {
                        Text("Follow up with coach")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(HAYFColor.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(HAYFColor.surface.opacity(0.72))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(HAYFColor.borderStrong.opacity(0.7), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 20)
        }
    }

    private var introCopy: String {
        switch review.context.mode {
        case .replace:
            return "HAYF will swap this workout only after you accept. If the surrounding week needs repair, you will review that proposal next."
        case .add:
            return "HAYF will add this workout only after you accept. If the surrounding week needs repair, you will review that proposal next."
        }
    }

    private var previewItems: [WorkoutReviewPreviewItem] {
        let bucket = PlanDate.bucket(for: review.context.scheduledDate)
        let weekDates = PlanDate.weekDates(for: bucket)
        let weekDateSet = Set(weekDates.isEmpty ? [review.context.scheduledDate] : weekDates)
        let originalID = review.context.originalWorkout?.id
        var items = workouts
            .filter { weekDateSet.contains($0.scheduledDate) && $0.id != originalID }
            .map { workout in
                WorkoutReviewPreviewItem(
                    id: workout.id.uuidString,
                    date: workout.scheduledDate,
                    sequenceOrder: workout.sequenceOrder,
                    title: workout.title,
                    metadata: "\(workout.durationMinutes) min / \(workout.intensityLabel)",
                    isProposed: false
                )
            }

        items.append(
            WorkoutReviewPreviewItem(
                id: "proposed-\(review.id.uuidString)",
                date: review.context.scheduledDate,
                sequenceOrder: review.context.sequenceOrder,
                title: review.candidate.title,
                metadata: "\(review.candidate.durationMinutes) min / \(review.candidate.intensityLabel)",
                isProposed: true
            )
        )

        return items.sorted {
            if $0.date == $1.date {
                return $0.sequenceOrder < $1.sequenceOrder
            }

            return $0.date < $1.date
        }
    }
}

private struct WorkoutReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(HAYFColor.secondary)
                .tracking(1.4)

            content
        }
    }
}

private struct WorkoutCandidatePreviewCard: View {
    let candidate: PlanningWorkoutCandidate
    let scheduledDate: String
    let fallbackLocationLabel: String?

    private var display: WorkoutCardDisplayModel {
        WorkoutCardDisplayModel(
            candidate: candidate,
            scheduledDate: scheduledDate,
            fallbackLocationLabel: fallbackLocationLabel
        )
    }

    var body: some View {
        WorkoutCardBody(
            display: display,
            minHeight: 130,
            titleSize: 18,
            titleWeight: .medium
        ) {
                Text("New")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(HAYFColor.orange)
                    .clipShape(Capsule())
        }
    }
}

private struct WorkoutReviewPreviewItem: Identifiable {
    let id: String
    let date: String
    let sequenceOrder: Int
    let title: String
    let metadata: String
    let isProposed: Bool

    var dateLabel: String {
        "\(PlanDate.weekdayLabel(date)) \(PlanDate.dayLabel(date))"
    }
}

private struct WorkoutReviewWeekRow: View {
    let title: String
    let metadata: String
    let dateLabel: String
    let isProposed: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(dateLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isProposed ? HAYFColor.orange : HAYFColor.muted)
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(metadata)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            if isProposed {
                Text("Proposed")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(HAYFColor.orange)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(HAYFColor.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isProposed ? HAYFColor.orange.opacity(0.06) : HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isProposed ? HAYFColor.orange.opacity(0.35) : HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct ReplanProposalSheet: View {
    let proposal: PlanReplanProposal
    let isApplying: Bool
    let apply: () -> Void
    let keepChange: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        SheetHeader(
                            overline: "COACH REVIEW",
                            title: "Review proposed adjustment",
                            dismiss: { dismiss() }
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text(proposal.reason)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(HAYFColor.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("HAYF is proposing a repair around your change. Review it before applying the adjustment.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(HAYFColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ReplanMutationSummary(proposal: proposal)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }

                VStack(spacing: 10) {
                    Button(action: apply) {
                        HStack(spacing: 10) {
                            if isApplying {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text("Accept adjustment")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(HAYFColor.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isApplying)

                    Button(action: {
                        dismiss()
                        keepChange()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(HAYFColor.surface)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isApplying)

                    Button(action: {}) {
                        Text("Follow up with coach")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(HAYFColor.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(HAYFColor.surface.opacity(0.72))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(HAYFColor.borderStrong.opacity(0.7), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 20)
        }
    }
}

private struct ReplanMutationSummary: View {
    let proposal: PlanReplanProposal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested repair")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text(summary)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(mutationSummaries, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(HAYFColor.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(item)
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }

    private var summary: String {
        if proposal.mutationCount == 1 {
            return "HAYF will make one small change around your edit, then reload the week."
        }

        return "HAYF will make \(proposal.mutationCount) small changes around your edit, then reload the week."
    }

    private var mutationSummaries: [String] {
        guard case let .array(mutations) = proposal.proposedMutations else {
            return []
        }

        return mutations.compactMap(summary(for:)).prefix(3).map { $0 }
    }

    private func summary(for value: JSONValue) -> String? {
        guard case let .object(object) = value,
              case let .string(type)? = object["type"] else {
            return nil
        }

        switch type {
        case "create_workout":
            let fields = object.objectValue("fields")
            let title = fields?.stringValue("title") ?? "a support workout"
            let date = fields?.stringValue("scheduled_date")
            let sourceTitle = object.stringValue("source_workout_title")
            let sourceDate = object.stringValue("source_scheduled_date")
            if let date {
                if let sourceTitle, let sourceDate {
                    return "Add \(title) on \(PlanDate.longLabel(date)) to cover the gap from \(sourceTitle) on \(PlanDate.longLabel(sourceDate))."
                }
                return "Add \(title) on \(PlanDate.longLabel(date))."
            }
            return "Add \(title) to restore the week."
        case "update_workout":
            let fields = object.objectValue("fields")
            let title = object.stringValue("workout_title") ?? "a surrounding workout"
            let fromDate = object.stringValue("from_scheduled_date")
            if let date = fields?.stringValue("scheduled_date") {
                if let fromDate, fromDate != date {
                    return "Move \(title) from \(PlanDate.longLabel(fromDate)) to \(PlanDate.longLabel(date)) for better spacing."
                }
                return "Move \(title) to \(PlanDate.longLabel(date)) for better spacing."
            }
            if let duration = fields?.intValue("duration_minutes") {
                if let fromDate {
                    return "Lower \(title) on \(PlanDate.longLabel(fromDate)) to \(duration) minutes."
                }
                return "Lower \(title) to \(duration) minutes."
            }
            if let intensity = fields?.stringValue("intensity_label") {
                if let fromDate {
                    return "Lower \(title) on \(PlanDate.longLabel(fromDate)) to \(intensity) intensity."
                }
                return "Lower \(title) to \(intensity) intensity."
            }
            return "Adjust \(title) so the week stays recoverable."
        case "delete_workout":
            let title = object.stringValue("workout_title") ?? "one surrounding workout"
            if let fromDate = object.stringValue("from_scheduled_date") {
                return "Remove \(title) on \(PlanDate.longLabel(fromDate)) from the week."
            }
            return "Remove \(title) from the week."
        default:
            return nil
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func stringValue(_ key: String) -> String? {
        guard case let .string(value)? = self[key] else {
            return nil
        }

        return value
    }

    func intValue(_ key: String) -> Int? {
        guard case let .number(value)? = self[key] else {
            return nil
        }

        return Int(value)
    }

    func objectValue(_ key: String) -> [String: JSONValue]? {
        guard case let .object(value)? = self[key] else {
            return nil
        }

        return value
    }
}

private enum PlanDetailSheet: Identifiable {
    case activeBlock
    case phase(PlanRoadmapItem)
    case target(PlanGoalTarget)

    var id: String {
        switch self {
        case .activeBlock:
            return "active-block"
        case let .phase(item):
            return "phase-\(item.id)"
        case let .target(target):
            return "target-\(target.id.uuidString)"
        }
    }

    var detents: Set<PresentationDetent> {
        switch self {
        case .activeBlock:
            return [.medium, .large]
        case .phase:
            return [.medium]
        case .target:
            return [.large]
        }
    }
}

private struct PlanDetailSheetView: View {
    let detail: PlanDetailSheet
    let block: PlanActiveFitnessBlock?
    let phases: [PlanFitnessBlockPhase]
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]
    let goalEvaluations: [PlanGoalEvaluation]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            switch detail {
            case .activeBlock:
                if let block {
                    ActiveBlockDetailSheet(
                        block: block,
                        phases: phases,
                        weeklyRhythms: weeklyRhythms,
                        workouts: workouts,
                        dismiss: { dismiss() }
                    )
                }
            case let .phase(item):
                if let block {
                    PhaseDetailSheet(
                        item: item,
                        items: PlanRoadmapSummary(block: block, phases: phases).items,
                        dismiss: { dismiss() }
                    )
                }
            case let .target(target):
                TargetDetailSheet(
                    target: target,
                    evaluation: PlanTargetDisplay.latestEvaluation(for: target, in: goalEvaluations),
                    dismiss: { dismiss() }
                )
            }
        }
    }
}

private struct ActiveBlockDetailSheet: View {
    let block: PlanActiveFitnessBlock
    let phases: [PlanFitnessBlockPhase]
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SheetHeader(
                overline: "STRATEGY",
                title: PlanDisplay.title(for: block, workouts: workouts),
                dismiss: dismiss
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DetailChip(text: PlanDisplay.focus(for: block, phases: phases, workouts: workouts))
                    DetailChip(text: PlanDisplay.strengthFrequency(from: workouts))
                    DetailChip(text: PlanDisplay.reviewCadence(for: block))
                }
            }

            VStack(alignment: .leading, spacing: 18) {
                DetailSection(
                    title: "Why this strategy",
                    text: PlanDisplay.whyThisPlan(for: block, phases: phases, workouts: workouts)
                )

                DetailSection(
                    title: "What changes first",
                    text: PlanDisplay.firstChange(for: block, workouts: workouts)
                )

                DetailSection(
                    title: "What to expect",
                    text: PlanDisplay.whatToExpect(for: block, weeklyRhythms: weeklyRhythms)
                )
            }

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Text("Got it")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HAYFColor.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

private struct PhaseDetailSheet: View {
    let item: PlanRoadmapItem
    let items: [PlanRoadmapItem]
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SheetHeader(
                overline: "PHASE \(item.index + 1) OF \(max(items.count, 1))",
                title: item.label,
                dismiss: dismiss
            )

            VStack(alignment: .leading, spacing: 18) {
                DetailSection(
                    title: "Role in the strategy",
                    text: item.objective
                )

                DetailSection(
                    title: "How it shapes this week",
                    text: item.focusText
                )

                DetailSection(
                    title: "Watch for",
                    text: item.riskText
                )
            }

            PlanPhaseContextRow(items: items, selectedItem: item)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

private struct TargetDetailSheet: View {
    let target: PlanGoalTarget
    let evaluation: PlanGoalEvaluation?
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SheetHeader(
                        overline: "TRAINING TARGET",
                        title: target.title,
                        dismiss: dismiss
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            DetailChip(text: PlanTargetDisplay.kindLabel(for: target))
                            DetailChip(text: PlanTargetDisplay.status(for: target, evaluation: evaluation).displayName)
                            DetailChip(text: PlanTargetDisplay.categoryLabel(for: target))
                        }
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        DetailSection(
                            title: "Current status",
                            text: PlanTargetDisplay.statusText(for: target, evaluation: evaluation)
                        )

                        DetailSection(
                            title: "Why HAYF is watching it",
                            text: PlanTargetDisplay.whyWatchedText(for: target)
                        )

                        DetailSection(
                            title: "How it affects the plan",
                            text: PlanTargetDisplay.planImpactText(for: target)
                        )

                        DetailSection(
                            title: "Evidence",
                            text: PlanTargetDisplay.evidenceText(for: evaluation)
                        )
                    }
                }
                .padding(.top, 2)
            }

            Button(action: {}) {
                Text("Ask coach about this")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HAYFColor.primary.opacity(0.55))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Ask coach about this coming soon")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

private struct SheetHeader: View {
    let overline: String
    let title: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(overline)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(HAYFColor.muted)

                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .frame(width: 36, height: 36)
                    .background(HAYFColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HAYFColor.borderStrong, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}

private struct DetailSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DetailChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(HAYFColor.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
            }
    }
}

private struct PlanPhaseContextRow: View {
    let items: [PlanRoadmapItem]
    let selectedItem: PlanRoadmapItem

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(dotFill(for: item))
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .stroke(dotStroke(for: item), lineWidth: 1.5)
                        }

                    Text(item.label)
                        .font(.system(size: 12, weight: item.id == selectedItem.id ? .semibold : .regular))
                        .foregroundStyle(item.id == selectedItem.id ? HAYFColor.primary : HAYFColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }

    private func dotFill(for item: PlanRoadmapItem) -> Color {
        if item.id == selectedItem.id {
            return HAYFColor.orange
        }

        return item.index < selectedItem.index ? HAYFColor.primary : HAYFColor.surface
    }

    private func dotStroke(for item: PlanRoadmapItem) -> Color {
        if item.id == selectedItem.id || item.index < selectedItem.index {
            return item.id == selectedItem.id ? HAYFColor.orange : HAYFColor.primary
        }

        return HAYFColor.borderStrong
    }
}

private struct PlanWorkoutDayGroup: Identifiable {
    let date: String
    let workouts: [PlanWorkout]
    let weeklyPlanID: UUID?
    let weekStatus: String?
    let constraint: PlanDayConstraint?

    var id: String { date }
}

private enum PlanWeekBucket: Equatable {
    case current
    case next
    case outside
}

private struct PlanRoadmapItem: Identifiable {
    let id: String
    let label: String
    let index: Int
    let objective: String
    let focus: [String]
    let risk: [String]

    var focusText: String {
        guard !focus.isEmpty else {
            return "This phase sets the emphasis for session types, weekly intensity, and recovery spacing."
        }

        return focus.joined(separator: " ")
    }

    var riskText: String {
        guard !risk.isEmpty else {
            return "If recovery or adherence slips, HAYF should hold the week steady before adding pressure."
        }

        return risk.joined(separator: " ")
    }
}

private struct PlanRoadmapSummary {
    let items: [PlanRoadmapItem]
    let activeIndex: Int
    let weekLabel: String

    init(block: PlanActiveFitnessBlock, phases: [PlanFitnessBlockPhase]) {
        let today = Date()

        if !phases.isEmpty {
            let items = phases.enumerated().map { index, phase in
                PlanRoadmapItem(
                    id: phase.id.uuidString,
                    label: phase.name.capitalized,
                    index: index,
                    objective: phase.objective,
                    focus: phase.focus,
                    risk: phase.risk
                )
            }
            let activeIndex = phases.firstIndex { phase in
                guard let start = PlanDate.date(from: phase.startDate),
                      let end = PlanDate.date(from: phase.endDate) else {
                    return false
                }

                return today >= start && today <= end
            } ?? min(1, max(0, items.count - 1))

            self.items = items
            self.activeIndex = activeIndex
            self.weekLabel = Self.weekLabel(block: block)
        } else {
            let cadenceWeeks = max(1, Int(ceil(Double(block.reviewCadenceDays) / 7.0)))
            let labels = ["Start", "Build", "Steady", "Review"]
            let itemCount = min(max(cadenceWeeks, 2), labels.count)
            let items = labels.prefix(itemCount).enumerated().map { index, label in
                PlanRoadmapItem(
                    id: "cadence-\(index)-\(label)",
                    label: String(label),
                    index: index,
                    objective: Self.fallbackObjective(for: String(label)),
                    focus: Self.fallbackFocus(for: String(label)),
                    risk: Self.fallbackRisk(for: String(label))
                )
            }
            let startDate = PlanDate.date(from: block.startDate) ?? today
            let elapsedDays = max(0, PlanCalendar.iso.dateComponents([.day], from: startDate, to: today).day ?? 0)
            let weekIndex = min(items.count - 1, elapsedDays / 7)

            self.items = items
            self.activeIndex = weekIndex
            self.weekLabel = "Week \(min(weekIndex + 1, cadenceWeeks))/\(cadenceWeeks)"
        }
    }

    private static func weekLabel(block: PlanActiveFitnessBlock) -> String {
        let today = Date()
        let startDate = PlanDate.date(from: block.startDate) ?? today
        let elapsedDays = max(0, PlanCalendar.iso.dateComponents([.day], from: startDate, to: today).day ?? 0)
        let currentWeek = elapsedDays / 7 + 1

        if let targetDate = PlanDate.date(from: block.targetDate) {
            let totalDays = max(1, PlanCalendar.iso.dateComponents([.day], from: startDate, to: targetDate).day ?? 1)
            let totalWeeks = max(1, Int(ceil(Double(totalDays) / 7.0)))
            return "Week \(min(currentWeek, totalWeeks))/\(totalWeeks)"
        }

        let cadenceWeeks = max(1, Int(ceil(Double(block.reviewCadenceDays) / 7.0)))
        return "Week \(min(currentWeek, cadenceWeeks))/\(cadenceWeeks)"
    }

    private static func fallbackObjective(for label: String) -> String {
        switch label {
        case "Start":
            return "Establish the rhythm without making the week feel brittle."
        case "Build":
            return "Keep the repeatable base while adding only the pressure the week can absorb."
        case "Steady":
            return "Hold the pattern long enough for consistency and recovery signals to become useful."
        default:
            return "Reduce friction, review what held, and decide how the strategy should continue."
        }
    }

    private static func fallbackFocus(for label: String) -> [String] {
        switch label {
        case "Start":
            return ["Session timing and minimum effective dose come first.", "Training should feel easy to resume."]
        case "Build":
            return ["The weekly rhythm can become more specific.", "Strength, cardio, and recovery stay balanced."]
        case "Steady":
            return ["The plan favors repeatable exposure over novelty.", "Missed sessions should repair the week, not reset it."]
        default:
            return ["The review checks adherence, recovery, and what should change next."]
        }
    }

    private static func fallbackRisk(for label: String) -> [String] {
        switch label {
        case "Start":
            return ["Doing too much too soon is the main risk."]
        case "Build":
            return ["If sleep, soreness, or missed sessions stack up, HAYF should hold steady."]
        case "Steady":
            return ["Drift is more important to catch than one imperfect session."]
        default:
            return ["Chasing extra work can obscure what actually helped."]
        }
    }
}

private enum PlanDisplay {
    static func title(for block: PlanActiveFitnessBlock, workouts: [PlanWorkout]) -> String {
        let trimmed = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 30,
           !trimmed.lowercased().contains("x "),
           !trimmed.lowercased().contains("sessions") {
            return trimmed
        }

        let types = Set(workouts.map { $0.activityType.lowercased() })
        let purposes = workouts.map { $0.purpose.lowercased() }.joined(separator: " ")
        let hasStrength = types.contains(where: { $0.contains("strength") }) || purposes.contains("strength")
        let hasAerobic = types.contains(where: { $0.contains("ride") || $0.contains("run") || $0.contains("cycle") || $0.contains("bike") }) || purposes.contains("aerobic")

        if hasAerobic && hasStrength {
            return "Aerobic Base + Strength"
        } else if hasAerobic {
            return "Aerobic Base"
        } else if hasStrength {
            return "Strength Rhythm"
        } else if block.kind == "consistency" {
            return "Consistency Rhythm"
        } else {
            return "Fitness Strategy"
        }
    }

    static func focus(for block: PlanActiveFitnessBlock, phases: [PlanFitnessBlockPhase], workouts: [PlanWorkout]) -> String {
        if let currentPhase = currentPhase(from: phases),
           let focus = currentPhase.focus.first {
            return "Focus: \(focus.lowercased())"
        }

        let purposes = workouts.map(\.purpose).filter { !$0.isEmpty }
        if let aerobic = purposes.first(where: { $0.localizedCaseInsensitiveContains("aerobic") }) {
            return "Focus: \(aerobic.lowercased())"
        }

        if block.kind == "consistency" {
            return "Focus: consistency"
        }

        return "Focus: strategy"
    }

    static func strengthFrequency(from workouts: [PlanWorkout]) -> String {
        let currentWeekStrength = workouts.filter {
            PlanDate.bucket(for: $0.scheduledDate) == .current &&
            ($0.activityType.localizedCaseInsensitiveContains("strength") || $0.title.localizedCaseInsensitiveContains("strength"))
        }.count

        if currentWeekStrength > 0 {
            return "Strength: \(currentWeekStrength)x/week"
        }

        return "Strength: anchor"
    }

    static func reviewCadence(for block: PlanActiveFitnessBlock) -> String {
        let weeks = max(1, Int(ceil(Double(block.reviewCadenceDays) / 7.0)))
        return "Review: \(weeks) weeks"
    }

    static func whyThisPlan(for block: PlanActiveFitnessBlock, phases: [PlanFitnessBlockPhase], workouts: [PlanWorkout]) -> String {
        if let rationale = block.context.planningRationale,
           !rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rationale
        }

        let title = title(for: block, workouts: workouts).lowercased()
        if title.contains("aerobic") && title.contains("strength") {
            return "You are building cycling or running capacity while keeping strength as an anchor. The first weeks protect consistency and aerobic volume before intensity rises."
        }

        if let phase = currentPhase(from: phases) {
            return phase.objective
        }

        return "This strategy turns onboarding into a repeatable training rhythm, then adapts it as recovery, adherence, and real workouts come in."
    }

    static func firstChange(for block: PlanActiveFitnessBlock, workouts: [PlanWorkout]) -> String {
        let title = title(for: block, workouts: workouts).lowercased()
        if title.contains("aerobic") && title.contains("strength") {
            return "Easy aerobic work becomes the main signal. Strength stays moderate so it supports the strategy instead of competing with it."
        }

        if block.kind == "consistency" {
            return "The first change is reducing decision friction: fewer brittle choices, clearer minimums, and a rhythm you can repeat."
        }

        return "The weekly rhythm becomes more specific first; harder work only earns its place after the base week is holding."
    }

    static func whatToExpect(for block: PlanActiveFitnessBlock, weeklyRhythms: [PlanWeeklyRhythm]) -> String {
        if let objective = weeklyRhythms.first(where: { PlanDate.bucket(for: $0.weekStartDate) == .current })?.objective,
           !objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "This week: \(objective)"
        }

        if block.kind == "consistency" {
            return "Most weeks should feel repeatable. HAYF should repair the week around real life before adding more pressure."
        }

        return "Most weeks should feel repeatable. Harder work appears only after the base is steady and recovery is holding."
    }

    private static func currentPhase(from phases: [PlanFitnessBlockPhase]) -> PlanFitnessBlockPhase? {
        let today = Date()
        return phases.first { phase in
            guard let start = PlanDate.date(from: phase.startDate),
                  let end = PlanDate.date(from: phase.endDate) else {
                return false
            }

            return today >= start && today <= end
        } ?? phases.first
    }
}

private extension String {
    func planContainsWord(_ value: String) -> Bool {
        range(
            of: "\\b\(NSRegularExpression.escapedPattern(for: value))\\b",
            options: .regularExpression
        ) != nil
    }
}

private enum PlanTargetDisplay {
    static func isWeeklyTarget(_ target: PlanGoalTarget) -> Bool {
        if target.targetScope == .week {
            return true
        }
        let category = target.metricCategory ?? ""
        return category.hasPrefix("weekly_")
    }

    static func latestEvaluation(
        for target: PlanGoalTarget,
        in evaluations: [PlanGoalEvaluation]
    ) -> PlanGoalEvaluation? {
        evaluations.first { $0.goalTargetID == target.id }
    }

    static func status(for target: PlanGoalTarget, evaluation: PlanGoalEvaluation?) -> PlanGoalStatus {
        if isFutureWeekTarget(target) {
            return .notStarted
        }

        return evaluation?.status ?? target.status
    }

    static func statusColor(for status: PlanGoalStatus) -> Color {
        switch status {
        case .onTrack, .achieved, .notStarted:
            return HAYFColor.primary
        case .lagging:
            return HAYFColor.error
        case .needsReview:
            return HAYFColor.orange
        }
    }

    static func weeklyCardIconName(for target: PlanGoalTarget, evaluation: PlanGoalEvaluation?) -> String {
        if let modality = weeklyTargetModality(for: target) {
            return modalityIconName(for: modality)
        }

        switch weeklyTargetFamily(for: target) {
        case "planned_session_completion":
            return "scope"
        case "active_days":
            return "figure.walk.motion"
        case "max_gap_guardrail":
            return "calendar.badge.clock"
        case "minimum_viable_week":
            return "flag"
        case "body_weight_logging":
            return "scalemass"
        case "running_pace", "cycling_pace":
            return "speedometer"
        default:
            return iconName(for: target)
        }
    }

    static func weeklyCardValue(for target: PlanGoalTarget, evaluation: PlanGoalEvaluation?) -> String {
        let family = weeklyTargetFamily(for: target)
        let modality = weeklyTargetModality(for: target)
        let targetValue = evaluation?.targetValue ?? target.targetValue

        guard let targetValue else {
            return weeklyRuleDisplayValue(for: target) ?? compactTitle(target.title)
        }

        switch family {
        case "planned_session_completion":
            return "Complete \(formatted(targetValue))"
        case "modality_session_count", "support_modality_presence":
            return "\(formatted(targetValue)) \(modalityCountLabel(for: modality))"
        case "modality_minutes":
            return "\(formatted(targetValue)) min"
        case "modality_distance":
            return "\(formatted(targetValue))\(unitSuffix(compactDistanceUnit(target.unit)))"
        case "active_days":
            return "\(formatted(targetValue)) active days"
        case "max_gap_guardrail":
            return "≤\(formatted(targetValue)) day gap"
        case "minimum_viable_week":
            return "\(formatted(targetValue)) minimum"
        case "body_weight_logging":
            return "\(formatted(targetValue)) weigh-ins"
        case "running_pace", "cycling_pace":
            if let displayValue = weeklyRuleDisplayValue(for: target) {
                return displayValue
            }
            return "\(formatted(targetValue))\(unitSuffix(target.unit ?? ""))"
        default:
            if let unit = target.unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(formatted(targetValue))\(unitSuffix(unit))"
            }
            return weeklyRuleDisplayValue(for: target) ?? compactTitle(target.title)
        }
    }

    static func weeklyCardProgress(
        for target: PlanGoalTarget,
        evaluation: PlanGoalEvaluation?,
        workouts: [PlanWorkout]
    ) -> Double? {
        if isFutureWeekTarget(target) {
            return nil
        }

        let family = weeklyTargetFamily(for: target)
        let targetValue = evaluation?.targetValue ?? target.targetValue
        guard let targetValue, targetValue > 0 else {
            return progress(for: target, evaluation: evaluation)
        }

        let completed = workouts.filter { $0.status == .done }
        let currentValue: Double?
        switch family {
        case "planned_session_completion", "minimum_viable_week":
            currentValue = Double(completed.count)
        case "modality_session_count", "support_modality_presence":
            guard let modality = weeklyTargetModality(for: target) else { return progress(for: target, evaluation: evaluation) }
            currentValue = Double(completed.filter { workoutModality(for: $0) == modality }.count)
        case "active_days":
            currentValue = Double(Set(completed.map(\.scheduledDate)).count)
        case "max_gap_guardrail":
            currentValue = nil
        default:
            return progress(for: target, evaluation: evaluation)
        }

        guard let currentValue else { return nil }
        return min(max(currentValue / targetValue, 0), 1)
    }

    static func iconName(for target: PlanGoalTarget) -> String {
        let text = "\(target.metricKey ?? "") \(target.metricCategory ?? "") \(target.title)".lowercased()

        if text.contains("body") || text.contains("weight") || text.contains("fat") {
            return "scalemass"
        } else if text.contains("run") {
            return "figure.run"
        } else if text.contains("cycle") || text.contains("cycling") || text.contains("bike") {
            return "bicycle"
        } else if text.contains("strength") || text.contains("upper") {
            return "dumbbell"
        } else if text.contains("recovery") || text.contains("mobility") || text.contains("rest") {
            return "figure.cooldown"
        } else if text.contains("step") || text.contains("activity") {
            return "figure.walk"
        } else if text.contains("consistency") || text.contains("workout") {
            return "calendar"
        } else {
            return "target"
        }
    }

    private static func weeklyTargetFamily(for target: PlanGoalTarget) -> String {
        if let family = weeklyRuleString(for: target, key: "family") {
            return family
        }

        if let category = target.metricCategory?.lowercased(),
           category.hasPrefix("weekly_") {
            return String(category.dropFirst("weekly_".count))
        }

        let metricKey = target.metricKey?.lowercased() ?? ""
        for family in [
            "planned_session_completion",
            "modality_session_count",
            "modality_minutes",
            "modality_distance",
            "active_days",
            "support_modality_presence",
            "max_gap_guardrail",
            "minimum_viable_week",
            "body_weight_logging",
            "running_pace",
            "cycling_pace"
        ] where metricKey.contains(family) {
            return family
        }

        return ""
    }

    private static func weeklyTargetModality(for target: PlanGoalTarget) -> String? {
        if let modality = weeklyRuleString(for: target, key: "modality"),
           !modality.isEmpty {
            return modality
        }

        let text = "\(target.metricKey ?? "") \(target.metricCategory ?? "") \(target.title)".lowercased()
        if text.contains("cycling") || text.contains("cycle") || text.contains("bike") || text.contains("ride") {
            return "ride"
        } else if text.contains("running") || text.contains("run") {
            return "run"
        } else if text.contains("swim") {
            return "swim"
        } else if text.planContainsWord("row") || text.planContainsWord("rows") || text.planContainsWord("rowing") || text.planContainsWord("rower") {
            return "row"
        } else if text.contains("hike") {
            return "hike"
        } else if text.contains("climb") || text.contains("boulder") {
            return "climb"
        } else if text.contains("strength") || text.contains("lift") {
            return "strength"
        } else if text.contains("mobility") {
            return "mobility"
        } else if text.contains("recovery") {
            return "recovery"
        } else if text.contains("walk") {
            return "walk"
        }

        return nil
    }

    private static func workoutModality(for workout: PlanWorkout) -> String {
        let activityType = workout.activityType.lowercased()
        let text = "\(workout.activityType) \(workout.title) \(workout.purpose)".lowercased()
        if activityType.planContainsWord("strength") || activityType.planContainsWord("traditional") || text.planContainsWord("lift") || text.planContainsWord("gym") {
            return "strength"
        } else if text.contains("cycling") || text.contains("cycle") || text.contains("bike") || text.contains("ride") {
            return "ride"
        } else if text.planContainsWord("run") || text.planContainsWord("running") {
            return "run"
        } else if text.planContainsWord("swim") || text.planContainsWord("swimming") {
            return "swim"
        } else if text.planContainsWord("walk") || text.planContainsWord("walking") {
            return "walk"
        } else if text.planContainsWord("hike") || text.planContainsWord("hiking") {
            return "hike"
        } else if text.planContainsWord("climb") || text.planContainsWord("boulder") {
            return "climb"
        } else if text.planContainsWord("mobility") || text.planContainsWord("yoga") || text.planContainsWord("stretch") {
            return "mobility"
        } else if text.planContainsWord("recovery") || text.planContainsWord("recover") {
            return "recovery"
        } else if text.planContainsWord("row") || text.planContainsWord("rows") || text.planContainsWord("rowing") || text.planContainsWord("rower") {
            return "row"
        }
        return ""
    }

    private static func weeklyRuleString(for target: PlanGoalTarget, key: String) -> String? {
        guard case let .object(object) = target.evaluationRule,
              case let .string(value)? = object[key] else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    private static func weeklyRuleDisplayValue(for target: PlanGoalTarget) -> String? {
        guard case let .object(object) = target.evaluationRule,
              case let .string(value)? = object["displayValue"] else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func modalityIconName(for modality: String) -> String {
        switch modality {
        case "cycling", "ride":
            return "bicycle"
        case "running", "run":
            return "figure.run"
        case "swimming", "swim":
            return "figure.pool.swim"
        case "rowing", "row":
            return "figure.rower"
        case "hiking", "hike":
            return "figure.hiking"
        case "climbing", "climb":
            return "figure.climbing"
        case "strength":
            return "dumbbell"
        case "mobility":
            return "figure.flexibility"
        case "recovery":
            return "figure.cooldown"
        case "walking", "walk":
            return "figure.walk"
        default:
            return "target"
        }
    }

    private static func modalityCountLabel(for modality: String?) -> String {
        switch modality {
        case "cycling", "ride":
            return "rides"
        case "running", "run":
            return "runs"
        case "swimming", "swim":
            return "swims"
        case "rowing", "row":
            return "rows"
        case "hiking", "hike":
            return "hikes"
        case "climbing", "climb":
            return "climbs"
        case "strength":
            return "strength"
        case "mobility":
            return "mobility"
        case "recovery":
            return "recovery"
        case "walking", "walk":
            return "walks"
        default:
            return "sessions"
        }
    }

    private static func compactTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "Complete ", with: "")
            .replacingOccurrences(of: "Planned ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func compactDistanceUnit(_ unit: String?) -> String {
        let trimmed = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "km" : trimmed
    }

    private static func isFutureWeekTarget(_ target: PlanGoalTarget) -> Bool {
        guard isWeeklyTarget(target),
              let start = PlanDate.date(from: target.startDate) else {
            return false
        }

        let calendar = Calendar.current
        return calendar.startOfDay(for: start) > calendar.startOfDay(for: Date())
    }

    static func progress(for target: PlanGoalTarget, evaluation: PlanGoalEvaluation?) -> Double? {
        if let progress = evaluation?.progressRatio {
            return min(max(progress, 0), 1)
        }

        guard let current = evaluation?.currentValue,
              let targetValue = target.targetValue else {
            return nil
        }

        if target.direction == "decrease",
           let baseline = target.baselineValue {
            let denominator = abs(targetValue - baseline)
            guard denominator > 0 else { return nil }
            return min(max((baseline - current) / denominator, 0), 1)
        }

        guard targetValue > 0 else { return nil }
        return min(max(current / targetValue, 0), 1)
    }

    static func valueLine(for target: PlanGoalTarget, evaluation: PlanGoalEvaluation?) -> String {
        let unit = target.unit ?? evaluation?.unit ?? ""
        let current = evaluation?.currentValue
        let targetValue = evaluation?.targetValue ?? target.targetValue

        if let current, let targetValue {
            if target.direction == "decrease" {
                return "\(formatted(current)) → \(formatted(targetValue))\(unitSuffix(unit))"
            }

            return "\(formatted(current)) / \(formatted(targetValue))\(unitSuffix(unit))"
        }

        if let baseline = target.baselineValue, let targetValue {
            return "\(formatted(baseline)) → \(formatted(targetValue))\(unitSuffix(unit))"
        }

        if let targetValue {
            return "Target \(formatted(targetValue))\(unitSuffix(unit))"
        }

        return "Needs more data"
    }

    static func statusText(for target: PlanGoalTarget, evaluation: PlanGoalEvaluation?) -> String {
        let value = valueLine(for: target, evaluation: evaluation)

        if status(for: target, evaluation: evaluation) == .notStarted {
            return "This target starts with the draft week. Current target: \(value)."
        }

        guard let evaluation else {
            return "HAYF has created this target and will evaluate it after the next sync. Current target: \(value)."
        }

        if evaluation.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Latest check: \(value)."
        }

        return "\(evaluation.message) Latest check: \(value)."
    }

    static func whyWatchedText(for target: PlanGoalTarget) -> String {
        if let description = target.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return description
        }

        switch target.metricCategory {
        case "weekly_volume":
            return "This is the total weekly training dose you can adjust by moving, adding, or shrinking sessions."
        case "weekly_cycling":
            return "This keeps the cycling work concrete for the week, instead of leaving the strategy goal abstract."
        case "weekly_running":
            return "This keeps the running work concrete for the week, so run volume can move with the plan."
        case "weekly_strength":
            return "This protects the strength or gym anchors that support the broader strategy."
        case "weekly_recovery":
            return "This keeps recovery visible as something to plan, not just something left over."
        case "body":
            return "This is tied to the body-composition outcome for the current strategy."
        case "volume":
            return "This keeps training exposure high enough to move the strategy without guessing from workouts alone."
        case "balance":
            return "This protects the support work that keeps the strategy from becoming one-dimensional."
        case "activity_floor":
            return "This helps HAYF notice whether movement outside workouts is supporting the plan."
        case "consistency":
            return "This keeps the strategy focused on repeatable training, not one perfect week."
        default:
            return "This target gives HAYF a measurable signal for the current strategy."
        }
    }

    static func planImpactText(for target: PlanGoalTarget) -> String {
        switch target.metricCategory {
        case "weekly_volume":
            return "If this slips, HAYF should rebalance the week before changing the whole strategy."
        case "weekly_cycling", "weekly_running":
            return "If this slips, HAYF should protect the most important sport-specific session first."
        case "weekly_strength":
            return "If this slips, HAYF should keep at least one useful strength exposure alive."
        case "weekly_recovery":
            return "If this slips, HAYF should make room for lower-load work before adding more intensity."
        case "body":
            return "HAYF should keep the plan steady and use this trend cautiously, alongside training, recovery, and feedback."
        case "volume":
            return "If this slips, HAYF may protect easy aerobic work or reduce lower-priority sessions before changing the whole strategy."
        case "balance":
            return "If this slips, HAYF should keep strength exposure alive even when the week gets compressed."
        case "activity_floor":
            return "If this drops, HAYF may bias toward low-friction movement before adding intensity."
        case "consistency":
            return "If this slips, HAYF should repair the week around a smaller minimum rather than restart the plan."
        default:
            return "This target helps HAYF decide whether the weekly rhythm should hold, soften, or adjust."
        }
    }

    static func evidenceText(for evaluation: PlanGoalEvaluation?) -> String {
        guard let evaluation else {
            return "No evaluation has been recorded yet."
        }

        let date = displayDate(from: evaluation.evaluatedAt)
        return "Last checked \(date). Confidence: \(evaluation.confidence)."
    }

    static func kindLabel(for target: PlanGoalTarget) -> String {
        switch target.targetKind {
        case .primary:
            return "Primary"
        case .supporting:
            return "Support"
        case .subGoal:
            return "Support"
        }
    }

    static func categoryLabel(for target: PlanGoalTarget) -> String {
        guard let category = target.metricCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty else {
            return "Target"
        }

        return category
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func formatted(_ value: Double) -> String {
        if abs(value) >= 100 {
            return "\(Int(value.rounded()))"
        }

        if value.rounded() == value {
            return "\(Int(value))"
        }

        return String(format: "%.1f", value)
    }

    private static func unitSuffix(_ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed == "%" {
            return "%"
        }

        return " \(trimmed)"
    }

    private static func displayDate(from value: String) -> String {
        if let date = isoDateFormatter.date(from: value) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }

        if value.count >= 10 {
            return String(value.prefix(10))
        }

        return "recently"
    }

    private static let isoDateFormatter = ISO8601DateFormatter()
}

private enum PlanDate {
    static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return PlanCalendar.dateFormatter.date(from: string)
    }

    static func isCurrentWeek(_ dateString: String) -> Bool {
        bucket(for: dateString) == .current
    }

    static func bucket(for dateString: String) -> PlanWeekBucket {
        guard let date = date(from: dateString) else { return .outside }

        let calendar = PlanCalendar.iso
        let currentStart = PlanCalendar.currentCommittedWeekStart(calendar: calendar)
        let nextStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentStart) ?? currentStart
        let afterNextStart = calendar.date(byAdding: .weekOfYear, value: 2, to: currentStart) ?? nextStart

        if date >= currentStart && date < nextStart {
            return .current
        } else if date >= nextStart && date < afterNextStart {
            return .next
        } else {
            return .outside
        }
    }

    static func weekDates(for bucket: PlanWeekBucket) -> [String] {
        let calendar = PlanCalendar.iso
        let currentStart = PlanCalendar.currentCommittedWeekStart(calendar: calendar)

        let weekStart: Date
        switch bucket {
        case .current:
            weekStart = currentStart
        case .next:
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentStart) ?? currentStart
        case .outside:
            return []
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }

            return PlanCalendar.dateFormatter.string(from: date)
        }
    }

    static func weekdayLabel(_ dateString: String) -> String {
        guard let date = date(from: dateString) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func dayLabel(_ dateString: String) -> String {
        guard let date = date(from: dateString) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    static func longLabel(_ dateString: String) -> String {
        guard let date = date(from: dateString) else { return "Selected day" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    static func isTodayOrFuture(_ dateString: String) -> Bool {
        guard let date = date(from: dateString) else { return false }
        let calendar = PlanCalendar.iso
        let today = calendar.startOfDay(for: Date())
        return date >= today
    }

    static func isPast(_ dateString: String) -> Bool {
        guard let date = date(from: dateString) else { return false }
        let calendar = PlanCalendar.iso
        let today = calendar.startOfDay(for: Date())
        return date < today
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private enum PlanWorkoutCardPreviewFixtures {
    static func workout(
        title: String,
        activityType: String,
        durationMinutes: Int,
        distance: Double?,
        elevation: Double? = nil,
        intensity: String,
        purpose: String,
        status: PlanWorkoutStatus,
        source: String = "generated",
        location: String = "Munich",
        prescription: JSONValue? = nil,
        fuelingSummary: String? = nil
    ) -> PlanWorkout {
        PlanWorkout(
            id: UUID(),
            activeBlockID: nil,
            weeklyRhythmID: nil,
            weeklyPlanID: UUID(),
            scheduledDate: "2026-06-01",
            sequenceOrder: 1,
            activityType: activityType,
            title: title,
            durationMinutes: durationMinutes,
            estimatedDistanceKilometers: distance,
            estimatedElevationMeters: elevation,
            intensityLabel: intensity,
            purpose: purpose,
            status: status,
            source: source,
            fuelingSummary: fuelingSummary,
            prescription: prescription ?? legacyPrescription,
            plannedLocationLabel: location,
            weatherForecast: .object([
                "temperatureCelsius": .number(19),
                "conditionEmoji": .string("🌤"),
                "conditionLabel": .string("Partly cloudy")
            ])
        )
    }

    static var legacyPrescription: JSONValue {
        .object([
            "warmup": .string("Start easy and check readiness."),
            "main": .array([.string("Complete the planned dose with control.")]),
            "cooldown": .string("Finish easy."),
            "successCriteria": .string("Leave feeling ready for the next session.")
        ])
    }

    static var strengthPrescription: JSONValue {
        .object([
            "schemaVersion": .number(2),
            "summary": .string("Controlled full-body strength that supports the week without compromising endurance."),
            "whyToday": .string("Week 1 strength protects muscle while you rebuild cycling rhythm."),
            "warmup": .object([
                "title": .string("Warm up"),
                "description": .string("Prepare joints and movement patterns before loading."),
                "durationMinutes": .number(8),
                "steps": .array([.string("5 min easy bike"), .string("Two light ramp-up sets for the first lift")])
            ]),
            "main": .object([
                "title": .string("Strength work"),
                "description": .string("Use repeatable lifts with clean reps and bounded fatigue."),
                "blocks": .array([
                    strengthExercise("Leg press", equipment: "Leg press machine", sets: 3, reps: "8-10", alternative: "Goblet squat"),
                    strengthExercise("Seated row", equipment: "Seated row machine", sets: 3, reps: "8-10", alternative: "Dumbbell row"),
                    strengthExercise("Chest press", equipment: "Chest press machine", sets: 2, reps: "8-10", alternative: "Push-up"),
                    strengthExercise("Pallof press", equipment: "Cable stack", sets: 2, reps: "10 each side", alternative: "Band press")
                ])
            ]),
            "cooldown": .object([
                "title": .string("Cool down"),
                "description": .string("Bring effort down and check recovery signals."),
                "durationMinutes": .number(5),
                "steps": .array([.string("Easy walk"), .string("Light hips and upper-back mobility")])
            ]),
            "successCriteria": .string("Finish with 1-2 reps in reserve and no form breakdown."),
            "equipment": .array([.string("Leg press machine"), .string("Seated row machine"), .string("Cable stack")]),
            "constraintsApplied": .array([.string("Controlled lower-body load"), .string("No grinding reps")])
        ])
    }

    static var cyclingIntervalPrescription: JSONValue {
        .object([
            "schemaVersion": .number(1),
            "summary": .string("Develop high-end aerobic power while staying spaced from strength work."),
            "warmup": .object([
                "title": .string("Warm up"),
                "description": .string("Ease into the ride before the main work."),
                "durationMinutes": .number(10),
                "steps": .array([.string("Ride easy"), .string("Add 2 short cadence pickups")])
            ]),
            "main": .object([
                "title": .string("Ride intervals"),
                "description": .string("Keep the hard blocks controlled, not maximal."),
                "blocks": .array([
                    .object([
                        "kind": .string("interval"),
                        "title": .string("Main intervals"),
                        "description": .string("Alternate focused work with easy recovery."),
                        "repeats": .number(4),
                        "workDuration": .string("4 min"),
                        "recoveryDuration": .string("3 min easy"),
                        "target": .string("RPE 8"),
                        "notes": .string("Keep cadence smooth.")
                    ])
                ])
            ]),
            "cooldown": .object([
                "title": .string("Cool down"),
                "description": .string("Finish easy enough to protect the next session."),
                "durationMinutes": .number(8),
                "steps": .array([.string("Easy spin"), .string("Note heavy legs or unusual fatigue")])
            ]),
            "successCriteria": .string("Complete all intervals without sprinting the final rep."),
            "equipment": .array([.string("Bike")]),
            "constraintsApplied": .array([.string("Hard day spacing"), .string("Smooth cadence")])
        ])
    }

    static var steadyRunPrescription: JSONValue {
        .object([
            "schemaVersion": .number(1),
            "summary": .string("Extend aerobic time without adding speed."),
            "warmup": .object([
                "title": .string("Warm up"),
                "description": .string("Start gently before the steady block."),
                "durationMinutes": .number(10),
                "steps": .array([.string("Easy jog"), .string("Dynamic calves and hips")])
            ]),
            "main": .object([
                "title": .string("Steady run"),
                "description": .string("Stay conversational and smooth."),
                "blocks": .array([
                    .object([
                        "kind": .string("steady"),
                        "title": .string("Aerobic block"),
                        "description": .string("Hold a steady aerobic effort."),
                        "durationMinutes": .number(55),
                        "distanceKilometers": .number(9),
                        "elevationMeters": .null,
                        "target": .string("Easy pace / RPE 3-4"),
                        "terrainNotes": .string("Flat or gentle route.")
                    ])
                ])
            ]),
            "cooldown": .object([
                "title": .string("Cool down"),
                "description": .string("Reduce impact and check for irritation."),
                "durationMinutes": .number(5),
                "steps": .array([.string("Easy walk or jog"), .string("Light calves and hips mobility")])
            ]),
            "successCriteria": .string("Keep gait smooth and finish controlled."),
            "equipment": .array([.string("Running shoes")]),
            "constraintsApplied": .array([.string("Impact controlled"), .string("Strength spacing protected")])
        ])
    }

    static var walkRunPrescription: JSONValue {
        .object([
            "schemaVersion": .number(2),
            "summary": .string("Use short run and walk intervals to reintroduce impact gradually."),
            "whyToday": .string("Week 2 adds optional impact only after the core cycling and strength work."),
            "warmup": .object([
                "description": .string("Start with an easy walk and relaxed mobility."),
                "steps": .array([.string("Walk for 5 min"), .string("Mobilize calves and hips")])
            ]),
            "main": .object([
                "blocks": .array([
                    .object([
                        "kind": .string("walkRun"),
                        "title": .string("Walk-run set"),
                        "repeats": .number(6),
                        "runDurationMinutes": .number(2),
                        "walkDurationMinutes": .number(1),
                        "target": .string("Easy conversational running"),
                        "notes": .string("Stay relaxed and stop if impact feels uncomfortable.")
                    ])
                ])
            ]),
            "cooldown": .object([
                "description": .string("Finish with an easy walk."),
                "steps": .array([.string("Walk for 5 min")])
            ]),
            "successCriteria": .string("Finish feeling able to repeat the session next week."),
            "equipment": .array([.string("Running shoes")]),
            "constraintsApplied": .array([.string("walk_run_reentry_only")])
        ])
    }

    private static func strengthExercise(_ name: String, equipment: String, sets: Double, reps: String, alternative: String) -> JSONValue {
        .object([
            "kind": .string("strengthExercise"),
            "title": .string(name),
            "description": .string("Perform \(name) with clean repeatable reps."),
            "exerciseName": .string(name),
            "machineOrEquipment": .string(equipment),
            "sets": .number(sets),
            "reps": .string(reps),
            "restSeconds": .number(90),
            "effortTarget": .string("Stop with ~2-3 RIR (submaximal)"),
            "coachingCue": .string("Stop each set with clean reps in reserve."),
            "alternatives": .array([
                .object([
                    "exerciseName": .string(alternative),
                    "equipment": .string("Dumbbells or bodyweight"),
                    "notes": .string("Use if the main station is busy.")
                ])
            ])
        ])
    }
}

#Preview("Workout Cards") {
    ScrollView {
        VStack(spacing: 12) {
            PlanWorkoutCard(
                workout: PlanWorkoutCardPreviewFixtures.workout(
                    title: "Cycling intervals",
                    activityType: "cycling",
                    durationMinutes: 75,
                    distance: 35,
                    intensity: "High",
                    purpose: "VO2Max power",
                    status: .current,
                    prescription: PlanWorkoutCardPreviewFixtures.cyclingIntervalPrescription,
                    fuelingSummary: "Carbs + water before riding."
                ),
                fallbackLocationLabel: "Munich",
                isDisabled: false,
                moveWorkout: {},
                deleteWorkout: {},
                replaceWorkout: {},
                showWorkoutDetail: {}
            )

            PlanWorkoutCard(
                workout: PlanWorkoutCardPreviewFixtures.workout(
                    title: "Easy ride",
                    activityType: "cycling",
                    durationMinutes: 60,
                    distance: 22,
                    intensity: "Zone 2",
                    purpose: "Aerobic endurance base",
                    status: .planned,
                    location: "Lisbon"
                ),
                fallbackLocationLabel: "Munich",
                isDisabled: false,
                moveWorkout: {},
                deleteWorkout: {},
                replaceWorkout: {},
                showWorkoutDetail: {}
            )

            PlanWorkoutCard(
                workout: PlanWorkoutCardPreviewFixtures.workout(
                    title: "Strength support",
                    activityType: "strength",
                    durationMinutes: 45,
                    distance: nil,
                    intensity: "Moderate",
                    purpose: "Strength",
                    status: .missed,
                    prescription: PlanWorkoutCardPreviewFixtures.strengthPrescription,
                    fuelingSummary: "Protein + carbs."
                ),
                fallbackLocationLabel: "Munich",
                isDisabled: false,
                moveWorkout: {},
                deleteWorkout: {},
                replaceWorkout: {},
                showWorkoutDetail: {}
            )

            PlanWorkoutCard(
                workout: PlanWorkoutCardPreviewFixtures.workout(
                    title: "Long Ride",
                    activityType: "cycling",
                    durationMinutes: 240,
                    distance: 88,
                    intensity: "Low",
                    purpose: "Endurance",
                    status: .done,
                    source: "healthkit_detected"
                ),
                fallbackLocationLabel: "Munich",
                isDisabled: false,
                moveWorkout: {},
                deleteWorkout: {},
                replaceWorkout: {},
                showWorkoutDetail: {}
            )
        }
        .padding(24)
    }
    .frame(width: 390)
    .background(HAYFColor.neutral)
}

#Preview("Workout Detail Strength") {
    WorkoutDetailScreen(
        workout: PlanWorkoutCardPreviewFixtures.workout(
            title: "Strength support",
            activityType: "strength",
            durationMinutes: 45,
            distance: nil,
            intensity: "Moderate",
            purpose: "Strength",
            status: .planned,
            prescription: PlanWorkoutCardPreviewFixtures.strengthPrescription,
            fuelingSummary: "Protein + carbs."
        ),
        fallbackLocationLabel: "Munich",
        dismiss: {}
    )
}

#Preview("Workout Detail Ride") {
    WorkoutDetailScreen(
        workout: PlanWorkoutCardPreviewFixtures.workout(
            title: "Cycling intervals",
            activityType: "cycling",
            durationMinutes: 50,
            distance: 24,
            intensity: "High",
            purpose: "VO2Max power",
            status: .planned,
            prescription: PlanWorkoutCardPreviewFixtures.cyclingIntervalPrescription,
            fuelingSummary: "Carbs + water before riding."
        ),
        fallbackLocationLabel: "Munich",
        dismiss: {}
    )
}

#Preview("Workout Detail Run") {
    WorkoutDetailScreen(
        workout: PlanWorkoutCardPreviewFixtures.workout(
            title: "Long aerobic run",
            activityType: "running",
            durationMinutes: 70,
            distance: 10,
            intensity: "Low",
            purpose: "Aerobic endurance",
            status: .planned,
            prescription: PlanWorkoutCardPreviewFixtures.steadyRunPrescription,
            fuelingSummary: "Normal meal timing."
        ),
        fallbackLocationLabel: "Munich",
        dismiss: {}
    )
}

#Preview("Workout Detail Walk Run") {
    WorkoutDetailScreen(
        workout: PlanWorkoutCardPreviewFixtures.workout(
            title: "Walk-run easy",
            activityType: "running",
            durationMinutes: 30,
            distance: nil,
            intensity: "Low",
            purpose: "Careful return to impact",
            status: .planned,
            prescription: PlanWorkoutCardPreviewFixtures.walkRunPrescription,
            fuelingSummary: "Light protein-containing snack after training"
        ),
        fallbackLocationLabel: "Munich",
        dismiss: {}
    )
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview {
    PlanScreenView()
}
