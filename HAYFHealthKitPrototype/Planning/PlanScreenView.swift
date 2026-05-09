import SwiftUI

struct PlanScreenView: View {
    @StateObject private var store = PlanDataStore()
    @State private var didLoad = false
    @State private var didPresentInitialBlockDetail = false
    @State private var selectedDetail: PlanDetailSheet?
    @State private var replacementWorkout: PlanWorkout?
    @State private var replacementCandidates: [PlanningReplacementCandidate] = []
    @State private var isLoadingReplacements = false
    @State private var replacementErrorMessage: String?

    private let planningAIProvider = PlanningAIProvider()

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
                    } else if let block = store.activeBlock {
                        PlanContentView(
                            block: block,
                            phases: store.phases,
                            weeklyRhythms: store.weeklyRhythms,
                            workouts: store.workouts,
                            errorMessage: store.errorMessage,
                            showActiveBlockDetail: {
                                selectedDetail = .activeBlock
                            },
                            showPhaseDetail: { item in
                                selectedDetail = .phase(item)
                            },
                            moveWorkout: { workout, date, sequenceOrder in
                                Task { await moveWorkout(workout, to: date, sequenceOrder: sequenceOrder) }
                            },
                            deleteWorkout: { workout in
                                Task { await deleteWorkout(workout) }
                            },
                            replaceWorkout: { workout in
                                showReplacementCandidates(for: workout)
                            },
                            reload: {
                                await store.loadVisiblePlan()
                                didLoad = true
                            }
                        )
                    } else {
                        PlanEmptyView(
                            errorMessage: store.errorMessage,
                            reload: {
                                await store.loadVisiblePlan()
                                didLoad = true
                            }
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            guard !didLoad else { return }
            await store.loadVisiblePlan()
            didLoad = true
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
                workouts: store.workouts
            )
            .presentationDetents(detail.detents)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $replacementWorkout) { workout in
            ReplacementCandidateSheet(
                workout: workout,
                candidates: replacementCandidates,
                isLoading: isLoadingReplacements,
                errorMessage: replacementErrorMessage,
                applyCandidate: { candidate in
                    Task { await applyReplacement(candidate, for: workout) }
                },
                retry: {
                    showReplacementCandidates(for: workout)
                }
            )
            .presentationDetents([.medium, .large])
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
        selectedDetail = .activeBlock
        onDidPresentActiveBlockOnFirstLoad()
    }

    private func moveWorkout(_ workout: PlanWorkout, to date: String, sequenceOrder: Int?) async {
        guard let scheduledDate = PlanDate.date(from: date) else { return }

        do {
            _ = try await planningAIProvider.recordPlanEdit(
                .moveWorkout(
                    plannedWorkoutID: workout.id,
                    scheduledDate: scheduledDate,
                    sequenceOrder: sequenceOrder
                )
            )
            await store.loadVisiblePlan()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func deleteWorkout(_ workout: PlanWorkout) async {
        do {
            _ = try await planningAIProvider.recordPlanEdit(.deleteWorkout(plannedWorkoutID: workout.id))
            await store.loadVisiblePlan()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func showReplacementCandidates(for workout: PlanWorkout) {
        replacementWorkout = workout
        replacementCandidates = []
        replacementErrorMessage = nil
        isLoadingReplacements = true

        Task {
            do {
                let output = try await planningAIProvider.recommendWorkoutReplacements(
                    plannedWorkoutID: workout.id,
                    textContext: "I do not want to do this workout in this slot."
                )
                replacementCandidates = output.candidates
                isLoadingReplacements = false
            } catch {
                replacementErrorMessage = error.localizedDescription
                isLoadingReplacements = false
            }
        }
    }

    private func applyReplacement(_ candidate: PlanningReplacementCandidate, for workout: PlanWorkout) async {
        do {
            _ = try await planningAIProvider.replaceWorkout(plannedWorkoutID: workout.id, candidate: candidate)
            replacementWorkout = nil
            replacementCandidates = []
            await store.loadVisiblePlan()
        } catch {
            replacementErrorMessage = error.localizedDescription
        }
    }
}
private struct PlanContentView: View {
    let block: PlanActiveFitnessBlock
    let phases: [PlanFitnessBlockPhase]
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]
    let errorMessage: String?
    let showActiveBlockDetail: () -> Void
    let showPhaseDetail: (PlanRoadmapItem) -> Void
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void
    let reload: () async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PlanHeader()

                VStack(alignment: .leading, spacing: 22) {
                    Text("Plan")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(HAYFColor.primary)

                    PlanBlockCard(
                        block: block,
                        phases: phases,
                        workouts: workouts,
                        showActiveBlockDetail: showActiveBlockDetail,
                        showPhaseDetail: showPhaseDetail
                    )

                    PlanCoachNote(text: coachNote)

                    PlanWorkoutsPanel(
                        weeklyRhythms: weeklyRhythms,
                        workouts: workouts,
                        moveWorkout: moveWorkout,
                        deleteWorkout: deleteWorkout,
                        replaceWorkout: replaceWorkout
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
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

    private var coachNote: String {
        if let currentObjective = weeklyRhythms.first(where: { PlanDate.isCurrentWeek($0.weekStartDate) })?.objective,
           !currentObjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return currentObjective
        }

        if let nextObjective = weeklyRhythms.first?.objective,
           !nextObjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nextObjective
        }

        return "Next two weeks keep the plan steady."
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
                        Text("ACTIVE BLOCK")
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
                .accessibilityLabel("Open active block details")

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

private struct PlanCoachNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(HAYFColor.orange)

            Text(text)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PlanWorkoutsPanel: View {
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Current + next week")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            VStack(alignment: .leading, spacing: 0) {
                if workouts.isEmpty {
                    PlanNoWorkoutsView()
                } else {
                    PlanWeekSection(
                        title: "THIS WEEK",
                        rhythm: rhythm(for: .current),
                        groups: groups(for: .current),
                        allWorkouts: workouts,
                        moveWorkout: moveWorkout,
                        deleteWorkout: deleteWorkout,
                        replaceWorkout: replaceWorkout
                    )

                    Divider()
                        .background(HAYFColor.borderStrong)
                        .padding(.vertical, 14)

                    PlanWeekSection(
                        title: "NEXT WEEK",
                        rhythm: rhythm(for: .next),
                        groups: groups(for: .next),
                        allWorkouts: workouts,
                        moveWorkout: moveWorkout,
                        deleteWorkout: deleteWorkout,
                        replaceWorkout: replaceWorkout
                    )

                    PlanLegend()
                        .padding(.top, 18)
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

    private func rhythm(for week: PlanWeekBucket) -> PlanWeeklyRhythm? {
        weeklyRhythms.first { PlanDate.bucket(for: $0.weekStartDate) == week }
    }

    private func groups(for week: PlanWeekBucket) -> [PlanWorkoutDayGroup] {
        let filtered = workouts.filter { PlanDate.bucket(for: $0.scheduledDate) == week }
        let grouped = Dictionary(grouping: filtered, by: \.scheduledDate)

        return grouped.keys.sorted().map { date in
            PlanWorkoutDayGroup(date: date, workouts: grouped[date] ?? [])
        }
    }
}

private struct PlanWeekSection: View {
    let title: String
    let rhythm: PlanWeeklyRhythm?
    let groups: [PlanWorkoutDayGroup]
    let allWorkouts: [PlanWorkout]
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(HAYFColor.muted)

                if let objective = rhythm?.objective,
                   !objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(objective)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                        .lineLimit(2)
                }
            }

            if groups.isEmpty {
                Text("No sessions planned.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(groups) { group in
                        PlanWorkoutDayRow(
                            group: group,
                            allWorkouts: allWorkouts,
                            moveWorkout: moveWorkout,
                            deleteWorkout: deleteWorkout,
                            replaceWorkout: replaceWorkout
                        )
                    }
                }
            }
        }
    }
}

private struct PlanWorkoutDayRow: View {
    let group: PlanWorkoutDayGroup
    let allWorkouts: [PlanWorkout]
    let moveWorkout: (PlanWorkout, String, Int?) -> Void
    let deleteWorkout: (PlanWorkout) -> Void
    let replaceWorkout: (PlanWorkout) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlanDate.weekdayLabel(group.date))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)

                Text(PlanDate.dayLabel(group.date))
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
            }
            .frame(width: 42, alignment: .leading)
            .padding(.top, 14)

            VStack(spacing: 8) {
                ForEach(group.workouts) { workout in
                    PlanWorkoutCard(
                        workout: workout,
                        deleteWorkout: { deleteWorkout(workout) },
                        replaceWorkout: { replaceWorkout(workout) }
                    )
                }
            }
            .dropDestination(for: String.self) { items, _ in
                guard let workoutID = items.first,
                      let workout = PlanWorkoutLookup.find(workoutID, in: allWorkouts) else {
                    return false
                }

                moveWorkout(workout, group.date, group.workouts.count + 1)
                return true
            }
        }
    }
}

private struct PlanWorkoutCard: View {
    let workout: PlanWorkout
    let deleteWorkout: () -> Void
    let replaceWorkout: () -> Void

    @State private var horizontalOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                Button(action: {
                    closeActions()
                    replaceWorkout()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 64)
                        .background(HAYFColor.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Replace workout")

                Button(role: .destructive, action: {
                    closeActions()
                    deleteWorkout()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 64)
                        .background(HAYFColor.error)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete workout")
            }

            cardContent
                .offset(x: horizontalOffset)
                .gesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            horizontalOffset = min(0, max(-112, value.translation.width))
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                horizontalOffset = value.translation.width < -56 ? -112 : 0
                            }
                        }
                )
        }
        .clipped()
        .draggable(workout.id.uuidString)
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(HAYFColor.primary)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(workout.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(metadata)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            PlanWorkoutStatusPill(status: workout.status)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(HAYFColor.muted)
                .rotationEffect(.degrees(90))
                .opacity(0.75)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            if workout.status == .current {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(HAYFColor.orange)
                    .frame(width: 4)
                    .padding(.vertical, 2)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }

    private func closeActions() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            horizontalOffset = 0
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

    private var iconName: String {
        switch workout.activityType.lowercased() {
        case let type where type.contains("strength"):
            return "dumbbell"
        case let type where type.contains("ride") || type.contains("bike") || type.contains("cycle") || type.contains("cycling"):
            return "bicycle"
        case let type where type.contains("run"):
            return "figure.run"
        case let type where type.contains("mobility") || type.contains("yoga") || type.contains("stretch"):
            return "figure.flexibility"
        case let type where type.contains("recovery") || type.contains("rest"):
            return "arrow.triangle.2.circlepath"
        default:
            return "figure.strengthtraining.traditional"
        }
    }
}

private struct PlanWorkoutStatusPill: View {
    let status: PlanWorkoutStatus

    var body: some View {
        HStack(spacing: 6) {
            statusIcon

            if status != .done {
                Text(status.displayName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: status == .done ? 28 : 78, alignment: .leading)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(HAYFColor.primary)
                .clipShape(Circle())
        case .current:
            Circle()
                .fill(HAYFColor.orange)
                .frame(width: 12, height: 12)
        case .adjusted:
            Circle()
                .stroke(HAYFColor.orange, lineWidth: 2)
                .frame(width: 13, height: 13)
        case .missed:
            Circle()
                .stroke(HAYFColor.error, lineWidth: 2)
                .frame(width: 13, height: 13)
        default:
            Circle()
                .stroke(HAYFColor.muted, lineWidth: 1.5)
                .frame(width: 13, height: 13)
        }
    }

    private var labelColor: Color {
        switch status {
        case .current, .adjusted:
            return HAYFColor.orange
        case .missed:
            return HAYFColor.error
        default:
            return HAYFColor.muted
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

private struct ReplacementCandidateSheet: View {
    let workout: PlanWorkout
    let candidates: [PlanningReplacementCandidate]
    let isLoading: Bool
    let errorMessage: String?
    let applyCandidate: (PlanningReplacementCandidate) -> Void
    let retry: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                SheetHeader(
                    overline: "REPLACE WORKOUT",
                    title: workout.title,
                    dismiss: { dismiss() }
                )

                Text("Pick a second-best option for this slot. HAYF keeps the rest of the week fixed unless the plan needs a repair.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(HAYFColor.orange)

                        Text("Finding useful alternatives")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
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
                            ForEach(candidates) { candidate in
                                ReplacementCandidateCard(
                                    candidate: candidate,
                                    apply: { applyCandidate(candidate) }
                                )
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

private struct ReplacementCandidateCard: View {
    let candidate: PlanningReplacementCandidate
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
        .buttonStyle(.plain)
    }

    private var metadata: String {
        "\(candidate.durationMinutes) min  ·  \(candidate.intensityLabel)  ·  \(candidate.purpose)"
    }
}

private enum PlanDetailSheet: Identifiable {
    case activeBlock
    case phase(PlanRoadmapItem)

    var id: String {
        switch self {
        case .activeBlock:
            return "active-block"
        case let .phase(item):
            return "phase-\(item.id)"
        }
    }

    var detents: Set<PresentationDetent> {
        switch self {
        case .activeBlock:
            return [.medium, .large]
        case .phase:
            return [.medium]
        }
    }
}

private struct PlanDetailSheetView: View {
    let detail: PlanDetailSheet
    let block: PlanActiveFitnessBlock?
    let phases: [PlanFitnessBlockPhase]
    let weeklyRhythms: [PlanWeeklyRhythm]
    let workouts: [PlanWorkout]

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
                overline: "ACTIVE BLOCK",
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
                    title: "Why this plan",
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
                    title: "Role in the block",
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

    var id: String { date }
}

private enum PlanWorkoutLookup {
    static func find(_ id: String, in workouts: [PlanWorkout]) -> PlanWorkout? {
        workouts.first { $0.id.uuidString.caseInsensitiveCompare(id) == .orderedSame }
    }
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
            return "Reduce friction, review what held, and decide how the block should continue."
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
            return "Active Fitness Block"
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

        return "Focus: active block"
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

        return "This block turns onboarding into a repeatable training rhythm, then adapts it as recovery, adherence, and real workouts come in."
    }

    static func firstChange(for block: PlanActiveFitnessBlock, workouts: [PlanWorkout]) -> String {
        let title = title(for: block, workouts: workouts).lowercased()
        if title.contains("aerobic") && title.contains("strength") {
            return "Easy aerobic work becomes the main signal. Strength stays moderate so it supports the block instead of competing with it."
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
        let now = Date()
        let currentStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let nextStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentStart) ?? now
        let afterNextStart = calendar.date(byAdding: .weekOfYear, value: 2, to: currentStart) ?? now

        if date >= currentStart && date < nextStart {
            return .current
        } else if date >= nextStart && date < afterNextStart {
            return .next
        } else {
            return .outside
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
}

#Preview {
    PlanScreenView()
}
