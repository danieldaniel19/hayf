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
    @State private var activeEditAnalysis: PlanEditAnalysis?
    @State private var workoutCandidateLoadID: UUID?
    @State private var selectedConstraintDay: PlanConstraintEditingContext?
    @State private var isSavingConstraint = false
    @State private var didAttemptWeeklyTargetBackfill = false

    private let planningAIProvider = PlanningAIProvider()
    private let healthSyncService = HealthSyncService()

    let presentActiveBlockOnFirstLoad: Bool
    let onDidPresentActiveBlockOnFirstLoad: () -> Void

    init(
        presentActiveBlockOnFirstLoad: Bool = false,
        onDidPresentActiveBlockOnFirstLoad: @escaping () -> Void = {}
    ) {
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
                            weeklyRhythms: store.weeklyRhythms,
                            workouts: store.workouts,
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
                            addWorkout: { date, sequenceOrder in
                                showWorkoutPlanning(WorkoutPlanningContext(mode: .add(date: date, sequenceOrder: sequenceOrder)))
                            },
                            editConstraint: { group in
                                showConstraintEditor(for: group)
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
            presentInitialBlockDetailIfNeeded()
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
        await syncImportedWorkoutsIntoPlan()
        await store.loadVisiblePlan()
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

    private func syncImportedWorkoutsIntoPlan() async {
        guard let payload = try? await healthSyncService.buildSyncPayload(daysBack: 14) else {
            return
        }

        _ = try? await planningAIProvider.syncHealthKitAndReconcile(payload: payload)
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
            await store.loadVisiblePlan()
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
            await store.loadVisiblePlan()
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
                await store.loadVisiblePlan()
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
                await store.loadVisiblePlan()
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
            await store.loadVisiblePlan()
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
            await store.loadVisiblePlan()
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
            await store.loadVisiblePlan()
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
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]
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
    let addWorkout: (String, Int) -> Void
    let editConstraint: (PlanWorkoutDayGroup) -> Void
    let reload: () async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PlanWorkoutsPanel(
                    weeklyRhythms: weeklyRhythms,
                    workouts: workouts,
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
                    addWorkout: addWorkout,
                    editConstraint: editConstraint
                )
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
        evaluation?.status ?? target.status
    }

    var body: some View {
        Button(action: openDetail) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: PlanTargetDisplay.iconName(for: target))
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
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]
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
    let addWorkout: (String, Int) -> Void
    let editConstraint: (PlanWorkoutDayGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
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
                    title: "This week",
                    rhythm: rhythm(for: .current),
                    groups: groups(for: .current),
                    targets: weekTargets(for: .current),
                    evaluations: evaluations,
                    movingWorkout: movingWorkout,
                    isAnalyzingEdit: isAnalyzingEdit,
                    showTargetDetail: showTargetDetail,
                    moveWorkout: moveWorkout,
                    beginMoveWorkout: beginMoveWorkout,
                    deleteWorkout: deleteWorkout,
                    replaceWorkout: replaceWorkout,
                    addWorkout: addWorkout,
                    editConstraint: editConstraint
                )

                Divider()
                    .background(HAYFColor.borderStrong)
                    .padding(.vertical, 14)

                PlanWeekSection(
                    title: "Next week",
                    rhythm: rhythm(for: .next),
                    groups: groups(for: .next),
                    targets: weekTargets(for: .next),
                    evaluations: evaluations,
                    movingWorkout: movingWorkout,
                    isAnalyzingEdit: isAnalyzingEdit,
                    showTargetDetail: showTargetDetail,
                    moveWorkout: moveWorkout,
                    beginMoveWorkout: beginMoveWorkout,
                    deleteWorkout: deleteWorkout,
                    replaceWorkout: replaceWorkout,
                    addWorkout: addWorkout,
                    editConstraint: editConstraint
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

private struct PlanWeekSection: View {
    let title: String
    let rhythm: PlanWeeklyRhythm?
    let groups: [PlanWorkoutDayGroup]
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let movingWorkout: PlanWorkout?
    let isAnalyzingEdit: Bool
    let showTargetDetail: (PlanGoalTarget) -> Void
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let beginMoveWorkout: (PlanWorkout) -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void
    let addWorkout: (String, Int) -> Void
    let editConstraint: (PlanWorkoutDayGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)

                    if let rhythm {
                        PlanWeekStatusChip(status: rhythm.status)
                    }

                    Spacer(minLength: 8)
                }

                if let objective = rhythm?.objective,
                   !objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(objective)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                        .lineLimit(2)
                }

                if rhythm?.status == "draft" {
                    Text("Finalizes Sunday 9pm")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HAYFColor.orange)
                }
            }

            if !targets.isEmpty {
                PlanWeeklyTargetsView(
                    targets: targets,
                    evaluations: evaluations,
                    showTargetDetail: showTargetDetail
                )
            }

            VStack(spacing: 8) {
                ForEach(groups) { group in
                    PlanWorkoutDayRow(
                        group: group,
                        movingWorkout: movingWorkout,
                        isAnalyzingEdit: isAnalyzingEdit,
                        moveWorkout: moveWorkout,
                        beginMoveWorkout: beginMoveWorkout,
                        deleteWorkout: deleteWorkout,
                        replaceWorkout: replaceWorkout,
                        addWorkout: addWorkout,
                        editConstraint: editConstraint
                    )
                }
            }
        }
    }
}

private struct PlanWeeklyTargetsView: View {
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let showTargetDetail: (PlanGoalTarget) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(targets.prefix(3)) { target in
                PlanTrainingTargetRow(
                    target: target,
                    evaluation: PlanTargetDisplay.latestEvaluation(for: target, in: evaluations),
                    openDetail: { showTargetDetail(target) }
                )
            }
        }
    }
}

private struct PlanWeekStatusChip: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(status == "draft" ? HAYFColor.orange : HAYFColor.primary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background((status == "draft" ? HAYFColor.orange : HAYFColor.primary).opacity(0.08))
            .clipShape(Capsule())
    }

    private var label: String {
        status == "draft" ? "Draft" : "Committed"
    }
}

private struct PlanWorkoutDayRow: View {
    let group: PlanWorkoutDayGroup
    let movingWorkout: PlanWorkout?
    let isAnalyzingEdit: Bool
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let beginMoveWorkout: (PlanWorkout) -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void
    let addWorkout: (String, Int) -> Void
    let editConstraint: (PlanWorkoutDayGroup) -> Void

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

            PlanTimelineMarker()
                .frame(width: 12)

            VStack(spacing: 8) {
                if group.workouts.isEmpty {
                    if isMoveTarget {
                        PlanEmptyDayDropZone(isMoveTarget: true)
                    } else if group.constraint?.kind == .unavailable {
                        PlanConstraintStatusRow(constraint: group.constraint)
                    } else if canAddWorkout {
                        PlanAddWorkoutRow(
                            add: { addWorkout(group.date, nextSequenceOrder) }
                        )
                    } else {
                        PlanHistoryEmptyRow()
                    }
                } else {
                    if let constraint = group.constraint {
                        PlanConstraintStatusRow(constraint: constraint)
                    }

                    ForEach(group.workouts) { workout in
                        PlanWorkoutCard(
                            workout: workout,
                            isDisabled: isAnalyzingEdit || isMoveTarget,
                            moveWorkout: { beginMoveWorkout(workout) },
                            deleteWorkout: { deleteWorkout(workout) },
                            replaceWorkout: { replaceWorkout(workout) }
                        )
                    }

                    if canAddWorkout && !isMoveTarget && !isAnalyzingEdit {
                        PlanAddWorkoutRow(
                            add: { addWorkout(group.date, nextSequenceOrder) }
                        )
                    }
                }

                if canEditConstraint {
                    PlanAvailabilityButton(
                        constraint: group.constraint,
                        open: { editConstraint(group) }
                    )
                }
            }
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

    private var canAddWorkout: Bool {
        !isAnalyzingEdit && PlanDate.isTodayOrFuture(group.date) && group.constraint?.kind != .unavailable
    }

    private var canEditConstraint: Bool {
        !isAnalyzingEdit && !isMoveTarget && PlanDate.isTodayOrFuture(group.date) && group.weeklyPlanID != nil
    }

    private var nextSequenceOrder: Int {
        (group.workouts.map(\.sequenceOrder).max() ?? 0) + 1
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

private struct PlanConstraintStatusRow: View {
    let constraint: PlanDayConstraint?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                if let note = constraint?.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !note.isEmpty {
                    Text(note)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }

    private var title: String {
        switch constraint?.kind {
        case .limited:
            return "Limited day"
        case .unavailable:
            return "Unavailable"
        default:
            return "Available"
        }
    }

    private var tint: Color {
        switch constraint?.kind {
        case .limited:
            return HAYFColor.orange
        case .unavailable:
            return HAYFColor.error
        default:
            return HAYFColor.muted
        }
    }

    private var iconName: String {
        switch constraint?.kind {
        case .limited:
            return "speedometer"
        case .unavailable:
            return "nosign"
        default:
            return "checkmark.circle"
        }
    }
}

private struct PlanAvailabilityButton: View {
    let constraint: PlanDayConstraint?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.neutral)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit day availability")
    }

    private var label: String {
        switch constraint?.kind {
        case .limited:
            return "Limited"
        case .unavailable:
            return "Unavailable"
        default:
            return "Available"
        }
    }

    private var tint: Color {
        switch constraint?.kind {
        case .limited:
            return HAYFColor.orange
        case .unavailable:
            return HAYFColor.error
        default:
            return HAYFColor.muted
        }
    }
}

private struct PlanTimelineMarker: View {
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(HAYFColor.borderStrong.opacity(0.62))
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            Circle()
                .fill(HAYFColor.borderStrong)
                .frame(width: 7, height: 7)
                .padding(.top, 20)
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

private struct PlanAddWorkoutRow: View {
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HAYFColor.orange)
                    .frame(width: 24, height: 24)

                Text("Add workout")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.surface.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.border, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add workout")
    }
}

private struct PlanWorkoutCard: View {
    let workout: PlanWorkout
    let isDisabled: Bool
    let moveWorkout: () -> Void
    let deleteWorkout: () -> Void
    let replaceWorkout: () -> Void

    @State private var horizontalOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false
    private let actionWidth: CGFloat = 132
    private let actionSpacing: CGFloat = 4

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
                    .frame(width: actionButtonWidth, height: rowHeight)
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
                    .frame(width: actionButtonWidth, height: rowHeight)
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
                    .frame(width: actionButtonWidth, height: rowHeight)
                    .background(HAYFColor.error)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete workout")
        }
        .frame(width: actionWidth, alignment: .trailing)
    }

    private var actionButtonWidth: CGFloat {
        (actionWidth - (actionSpacing * 2)) / 3
    }

    private var actionOpacity: Double {
        min(1, max(0, Double(abs(horizontalOffset) / 20)))
    }

    private var rowHeight: CGFloat {
        workout.status == .current ? 58 : 54
    }

    private func closeActions() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            horizontalOffset = 0
        }
    }

    private var cardContent: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: workout.status == .current ? 5 : 4) {
                Text(workout.title)
                    .font(titleFont)
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(1)

                Text(metadata)
                    .font(.system(size: workout.status == .current ? 14 : 13, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            PlanWorkoutStatusPill(status: workout.status)
        }
        .padding(.horizontal, 12)
        .frame(height: rowHeight)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(workout.status == .current ? HAYFColor.orange.opacity(0.28) : HAYFColor.border, lineWidth: 1)
        }
    }

    private var metadata: String {
        [duration, workout.intensityLabel, workout.purpose]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "  ·  ")
    }

    private var duration: String {
        "\(workout.durationMinutes) min"
    }

    private var titleFont: Font {
        if workout.status == .current {
            return .system(size: 17, weight: .bold)
        }
        return .system(size: 16, weight: .semibold)
    }

    @ViewBuilder
    private var cardBackground: some View {
        HAYFColor.surface

        if workout.status == .current {
            HAYFColor.orange.opacity(0.035)
        }
    }

}

private struct PlanWorkoutStatusPill: View {
    let status: PlanWorkoutStatus

    var body: some View {
        statusIcon
            .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(HAYFColor.primary)
                .clipShape(Circle())
        case .current:
            Circle()
                .fill(HAYFColor.orange)
                .frame(width: 9, height: 9)
        case .adjusted:
            Circle()
                .stroke(HAYFColor.orange, lineWidth: 2)
                .frame(width: 10, height: 10)
        case .missed:
            Circle()
                .stroke(HAYFColor.error, lineWidth: 2)
                .frame(width: 10, height: 10)
        default:
            Circle()
                .stroke(HAYFColor.muted, lineWidth: 1.5)
                .frame(width: 10, height: 10)
        }
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
    let candidate: PlanningWorkoutCandidate
    let apply: () -> Void

    var body: some View {
        Button(action: apply) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(metadata)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(HAYFColor.primary)
                        .clipShape(Circle())
                }

                Text(compact(candidate.rationale))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(2)

                Text(compact(candidate.weeklyImpact))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .lineLimit(2)
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
        .buttonStyle(.plain)
    }

    private var metadata: String {
        "\(candidate.durationMinutes) min / \(candidate.intensityLabel) / \(compact(candidate.purpose, limit: 28))"
    }

    private func compact(_ value: String, limit: Int = 96) -> String {
        let cleaned = value
            .replacingOccurrences(of: "—", with: ",")
            .replacingOccurrences(of: "–", with: ",")
            .replacingOccurrences(of: #"\\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > limit else { return cleaned }
        let prefix = cleaned.prefix(limit)
        let split = prefix.lastIndex(of: " ") ?? prefix.endIndex
        return String(prefix[..<split]).trimmingCharacters(in: .punctuationCharacters.union(.whitespaces)) + "."
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
                            WorkoutCandidatePreviewCard(candidate: review.candidate)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HAYFColor.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("\(candidate.durationMinutes) min / \(candidate.intensityLabel) / \(candidate.purpose)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8)

                Text("New")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(HAYFColor.orange)
                    .clipShape(Capsule())
            }

            Text(candidate.rationale)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(candidate.weeklyImpact)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
                .fixedSize(horizontal: false, vertical: true)
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

private enum PlanWeekBucket {
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
        evaluation?.status ?? target.status
    }

    static func statusColor(for status: PlanGoalStatus) -> Color {
        switch status {
        case .onTrack, .achieved:
            return HAYFColor.primary
        case .lagging:
            return HAYFColor.error
        case .needsReview:
            return HAYFColor.orange
        }
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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    PlanScreenView()
}
