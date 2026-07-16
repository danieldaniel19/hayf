import SwiftUI

enum TodayDayState: String, Decodable {
    case rest
    case planned
    case mixed
    case completed
}

enum TodaySessionState: String, Decodable {
    case planned
    case ready
    case completed
    case skipped
    case missed
}

enum TodayWorkoutAction: String, Codable, CaseIterable, Identifiable {
    case skip
    case swap
    case move
    case adjust

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skip: return "Skip"
        case .swap: return "Swap"
        case .move: return "Move"
        case .adjust: return "Adjust"
        }
    }

    var icon: String {
        switch self {
        case .skip: return "forward.end"
        case .swap: return "arrow.triangle.2.circlepath"
        case .move: return "calendar.badge.clock"
        case .adjust: return "slider.horizontal.3"
        }
    }
}

private enum TodayConditionDetail: String, Identifiable {
    case weather
    case fatigue

    var id: String { rawValue }
}

struct TodayBriefingOutput: Decodable {
    let userID: UUID
    let model: String
    let date: String
    let timezone: String
    let state: TodayDayState
    let cacheHit: Bool
    let generation: JSONValue
    let strategy: TodayStrategyContext
    let phase: TodayPhaseContext?
    let week: TodayWeekContext?
    let headline: String
    let strategyFit: String
    let importance: String
    let conditions: TodayConditions
    let sessions: [TodaySession]
    let tomorrowPreview: TodayWorkout?
    let replanReview: TodayReplanReview

    var orderedSessions: [TodaySession] {
        sessions.sorted {
            if $0.workout.sequenceOrder == $1.workout.sequenceOrder {
                return $0.workout.id.uuidString < $1.workout.id.uuidString
            }
            return $0.workout.sequenceOrder < $1.workout.sequenceOrder
        }
    }

    var usesDeterministicFallback: Bool {
        guard case let .object(values) = generation,
              case let .string(status) = values["status"] else { return false }
        return status == "fallback"
    }
}

struct TodayStrategyContext: Decodable {
    let id: UUID
    let title: String
    let summary: String?
    let rationale: String?
}

struct TodayPhaseContext: Decodable {
    let id: UUID
    let name: String
    let objective: String?
}

struct TodayWeekContext: Decodable {
    let id: UUID
    let objective: String?
    let status: String
    let context: JSONValue
}

struct TodayConditions: Decodable {
    let weather: TodayWeatherCondition?
    let fatigue: TodayFatigueEstimate
}

struct TodayWeatherCondition: Decodable {
    let source: String
    let fetchedAt: String?
    let forecastDate: String?
    let locationLabel: String?
    let conditionLabel: String?
    let conditionEmoji: String
    let temperatureCelsius: Double?
    let precipitationProbability: Double?
    let rainStartTime: String?
    let rainEndTime: String?
    let peakRainProbability: Double?
    let windKph: Double?
    let outdoorRisk: String
    let influence: String
}

struct TodayFatigueEstimate: Decodable {
    let level: String
    let confidence: String
    let freshness: String
    let factors: [String]
    let evidenceAt: String?
    let adjustmentSuggested: Bool?
    let influence: String
}

struct TodaySession: Decodable, Identifiable {
    let workout: TodayWorkout
    let actualWorkout: TodayActualWorkout?
    let state: TodaySessionState
    let deviation: TodayDeviation?
    let feedback: TodayStoredFeedback?
    let debriefRequest: TodayDebriefRequest?
    let briefing: TodaySessionBriefing

    var id: UUID { workout.id }
}

struct TodayWorkout: Decodable {
    let id: UUID
    let scheduledDate: String
    let sequenceOrder: Int
    let activityType: String
    let title: String
    let durationMinutes: Int
    let estimatedDistanceKilometers: Double?
    let estimatedElevationMeters: Double?
    let intensityLabel: String
    let purpose: String
    let status: PlanWorkoutStatus
    let source: String
    let fuelingSummary: String?
    let prescription: JSONValue
    let plannedLocationLabel: String?
    let weatherForecast: JSONValue

    var planWorkout: PlanWorkout {
        PlanWorkout(
            id: id,
            activeBlockID: nil,
            weeklyRhythmID: nil,
            weeklyPlanID: nil,
            scheduledDate: scheduledDate,
            sequenceOrder: sequenceOrder,
            activityType: activityType,
            title: title,
            durationMinutes: durationMinutes,
            estimatedDistanceKilometers: estimatedDistanceKilometers,
            estimatedElevationMeters: estimatedElevationMeters,
            intensityLabel: intensityLabel,
            purpose: purpose,
            status: status,
            source: source,
            fuelingSummary: fuelingSummary,
            prescription: prescription,
            plannedLocationLabel: plannedLocationLabel,
            weatherForecast: weatherForecast
        )
    }
}

struct TodayActualWorkout: Decodable {
    let id: UUID
    let startDate: String
    let activityType: String
    let durationMinutes: Int
    let distanceKilometers: Double?
    let energyKilocalories: Double?
    let loadValue: Double?
    let averageHeartRateBPM: Double?
    let maxHeartRateBPM: Double?
}

struct TodayDeviation: Decodable {
    let needsReview: Bool?
    let unexpected: Bool?
    let duration: JSONValue?
    let intensity: JSONValue?

    init(needsReview: Bool?, unexpected: Bool? = nil, duration: JSONValue?, intensity: JSONValue?) {
        self.needsReview = needsReview
        self.unexpected = unexpected
        self.duration = duration
        self.intensity = intensity
    }
}

struct TodaySessionBriefing: Decodable {
    let workoutID: UUID
    let preBrief: String
    let postBrief: String
    let weeklyImpact: String
}

struct TodayReplanReview: Decodable {
    let status: String
    let proposalID: UUID?
    let reason: String?
    let summary: String?
    let mutationCount: Int
    let mutations: JSONValue?

    init(status: String, proposalID: UUID?, reason: String?, summary: String?, mutationCount: Int, mutations: JSONValue? = nil) {
        self.status = status
        self.proposalID = proposalID
        self.reason = reason
        self.summary = summary
        self.mutationCount = mutationCount
        self.mutations = mutations
    }
}

struct TodayDebriefRequest: Decodable {
    let id: UUID?
    let status: String?
    let promptReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case promptReason = "prompt_reason"
    }
}

struct TodayStoredFeedback: Decodable {
    let perceivedEffort: Int?
    let feltRating: Int?
    let painFlag: Bool?
    let painNotes: String?
    let difficultyLabel: String?
    let freeText: String?

    enum CodingKeys: String, CodingKey {
        case perceivedEffort = "perceived_effort"
        case feltRating = "felt_rating"
        case painFlag = "pain_flag"
        case painNotes = "pain_notes"
        case difficultyLabel = "difficulty_label"
        case freeText = "free_text"
    }
}

struct WorkoutFeedbackDraft: Codable {
    var perceivedEffort: Int?
    var difficultyLabel: String?
    var feltRating: Int?
    var painFlag: Bool?
    var painNotes: String?
    var freeText: String?

    init(
        perceivedEffort: Int? = nil,
        difficultyLabel: String? = nil,
        feltRating: Int? = nil,
        painFlag: Bool? = nil,
        painNotes: String? = nil,
        freeText: String? = nil
    ) {
        self.perceivedEffort = perceivedEffort
        self.difficultyLabel = difficultyLabel
        self.feltRating = feltRating
        self.painFlag = painFlag
        self.painNotes = painNotes
        self.freeText = freeText
    }
}

struct TodayWorkoutActionRecommendation: Decodable {
    let userID: UUID
    let model: String
    let workoutID: UUID
    let action: TodayWorkoutAction
    let coachRead: String
    let weeklyImpact: String
    let moveOptions: [TodayMoveOption]
    let workoutOptions: [PlanningWorkoutCandidate]
    let usedFallback: Bool
}

struct TodayMoveOption: Decodable, Identifiable {
    let date: String
    let rationale: String
    var id: String { date }
}

@MainActor
final class TodayDataStore: ObservableObject {
    @Published private(set) var briefing: TodayBriefingOutput?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var recommendation: TodayWorkoutActionRecommendation?
    @Published private(set) var isLoadingRecommendation = false
    @Published private(set) var isMutating = false
    @Published var errorMessage: String?
    @Published var actionErrorMessage: String?

    private let provider: PlanningAIProvider
    private let healthSyncService: HealthSyncService
    private var hasLoaded = false
    private var lastForegroundRefresh: Date?

    init(
        provider: PlanningAIProvider = PlanningAIProvider(),
        healthSyncService: HealthSyncService = HealthSyncService(),
        previewBriefing: TodayBriefingOutput? = nil,
        previewError: String? = nil
    ) {
        self.provider = provider
        self.healthSyncService = healthSyncService
        briefing = previewBriefing
        errorMessage = previewError
        hasLoaded = previewBriefing != nil || previewError != nil
    }

    func load(includeHealthSync: Bool = true) async {
        guard !isLoading, !isRefreshing else { return }
        let initial = !hasLoaded
        if initial { isLoading = true } else { isRefreshing = true }
        errorMessage = nil
        defer {
            isLoading = false
            isRefreshing = false
        }

        if includeHealthSync, let payload = try? await healthSyncService.buildSyncPayload(daysBack: 14) {
            _ = try? await provider.syncHealthKitAndReconcile(payload: payload)
        }
        _ = try? await provider.refreshPlanWindow()
        _ = try? await provider.refreshWorkoutWeatherForecasts()

        do {
            briefing = try await provider.refreshTodayBriefing()
            hasLoaded = true
            lastForegroundRefresh = Date()
        } catch is CancellationError {
            // A newer refresh owns the visible result.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshOnForeground() async {
        if let lastForegroundRefresh, Date().timeIntervalSince(lastForegroundRefresh) < 120 { return }
        await load()
    }

    func recommend(_ action: TodayWorkoutAction, for workoutID: UUID, context: String? = nil) async {
        recommendation = nil
        actionErrorMessage = nil
        isLoadingRecommendation = true
        defer { isLoadingRecommendation = false }
        do {
            recommendation = try await provider.recommendTodayWorkoutAction(
                plannedWorkoutID: workoutID,
                action: action,
                textContext: context
            )
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func apply(
        _ action: TodayWorkoutAction,
        to workout: TodayWorkout,
        candidate: PlanningWorkoutCandidate? = nil,
        moveDate: String? = nil,
        context: String? = nil
    ) async -> Bool {
        actionErrorMessage = nil
        isMutating = true
        defer { isMutating = false }
        do {
            switch action {
            case .skip:
                try await provider.skipWorkout(plannedWorkoutID: workout.id, textContext: context)
            case .swap:
                guard let candidate else { return false }
                _ = try await provider.replaceWorkout(plannedWorkoutID: workout.id, candidate: candidate)
            case .move:
                guard let moveDate, let date = TodayDate.date(from: moveDate) else { return false }
                _ = try await provider.recordPlanEdit(
                    .moveWorkout(plannedWorkoutID: workout.id, scheduledDate: date, sequenceOrder: workout.sequenceOrder)
                )
            case .adjust:
                guard let candidate else { return false }
                try await provider.adjustWorkout(plannedWorkoutID: workout.id, candidate: candidate)
            }
            recommendation = nil
            await load(includeHealthSync: false)
            return true
        } catch {
            actionErrorMessage = error.localizedDescription
            return false
        }
    }

    func markDone(_ workoutID: UUID) async {
        isMutating = true
        actionErrorMessage = nil
        defer { isMutating = false }
        do {
            try await provider.markWorkoutComplete(plannedWorkoutID: workoutID)
            await load(includeHealthSync: false)
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func saveFeedback(_ draft: WorkoutFeedbackDraft, for session: TodaySession) async {
        do {
            try await provider.recordWorkoutFeedback(
                plannedWorkoutID: session.deviation?.unexpected == true ? nil : session.workout.id,
                actualWorkoutID: session.deviation?.unexpected == true ? session.actualWorkout?.id : nil,
                feedback: draft
            )
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func decideReplan(_ decision: PlanningProposalDecision) async {
        guard let proposalID = briefing?.replanReview.proposalID else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await provider.applyReplanProposal(proposalID: proposalID, decision: decision)
            await load(includeHealthSync: false)
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
}

struct TodayScreenView: View {
    let userName: String

    @StateObject private var store: TodayDataStore
    private let loadsRemoteData: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var detailWorkout: PlanWorkout?
    @State private var actionContext: TodayActionContext?
    @State private var showReplanReview = false
    @State private var conditionDetail: TodayConditionDetail?

    init(userName: String) {
        self.userName = userName
        _store = StateObject(wrappedValue: TodayDataStore())
        loadsRemoteData = true
    }

    fileprivate init(userName: String, preview: TodayPreviewKind) {
        self.userName = userName
        _store = StateObject(
            wrappedValue: TodayDataStore(
                previewBriefing: TodayPreviewFixtures.briefing(for: preview),
                previewError: preview == .error ? "Today's coaching is temporarily unavailable." : nil
            )
        )
        loadsRemoteData = false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HAYFColor.neutral.ignoresSafeArea()

                if store.isLoading, store.briefing == nil {
                    TodayLoadingView()
                } else if let briefing = store.briefing {
                    briefingScroll(briefing)
                } else {
                    TodayUnavailableView(
                        message: unavailableMessage,
                        retry: { Task { await store.load() } }
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            guard loadsRemoteData else { return }
            await store.load()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.refreshOnForeground() }
        }
        .fullScreenCover(item: $detailWorkout) { workout in
            WorkoutDetailScreen(
                workout: workout,
                fallbackLocationLabel: workout.plannedLocationLabel,
                dismiss: { detailWorkout = nil }
            )
        }
        .sheet(item: $actionContext) { context in
            TodayWorkoutActionSheet(context: context, store: store)
        }
        .sheet(isPresented: $showReplanReview) {
            if let review = store.briefing?.replanReview {
                TodayReplanReviewSheet(review: review, store: store)
            }
        }
        .sheet(item: $conditionDetail) { detail in
            if let conditions = store.briefing?.conditions {
                TodayConditionDetailSheet(detail: detail, conditions: conditions)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func briefingScroll(_ briefing: TodayBriefingOutput) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                TodayHeader(userName: userName, date: briefing.date)
                TodayStrategyCard(briefing: briefing)
                TodayCoachBriefingCard(briefing: briefing)
                TodayConditionsView(
                    conditions: briefing.conditions,
                    showWeather: { conditionDetail = .weather },
                    showFatigue: { conditionDetail = .fatigue }
                )

                if briefing.orderedSessions.isEmpty {
                    TodayRestDayCard(briefing: briefing)
                } else {
                    Text(briefing.orderedSessions.count == 1 ? "TODAY'S SESSION" : "TODAY'S AGENDA")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(HAYFColor.muted)

                    ForEach(Array(briefing.orderedSessions.enumerated()), id: \.element.id) { index, session in
                        TodaySessionCard(
                            session: session,
                            isNext: isNextActionable(session, index: index, sessions: briefing.orderedSessions),
                            openDirections: { detailWorkout = session.workout.planWorkout },
                            manage: { actionContext = TodayActionContext(action: $0, session: session) },
                            markDone: { Task { await store.markDone(session.id) } },
                            saveFeedback: { draft in Task { await store.saveFeedback(draft, for: session) } }
                        )
                    }
                }

                if briefing.replanReview.status != "none" {
                    TodayReplanReviewCard(review: briefing.replanReview) {
                        showReplanReview = true
                    }
                }

                if let error = store.actionErrorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(HAYFColor.error)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 36)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await store.load() }
    }

    private var unavailableMessage: String {
        guard let message = store.errorMessage else { return "Today's coaching is temporarily unavailable." }
        if message.localizedCaseInsensitiveContains("active fitness strategy") {
            return "Create an active strategy to unlock your daily coaching briefing."
        }
        return message
    }

    private func isNextActionable(_ session: TodaySession, index: Int, sessions: [TodaySession]) -> Bool {
        guard session.state == .planned || session.state == .ready else { return false }
        return sessions.prefix(index).allSatisfy { $0.state == .completed || $0.state == .skipped || $0.state == .missed }
    }
}

private struct TodayHeader: View {
    let userName: String
    let date: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HAYFLogo(markSize: 30, textSize: 26, spacing: 8)
                Text("Good \(TodayDate.partOfDay), \(userName)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(HAYFColor.primary)
                    .minimumScaleFactor(0.8)
                Text(TodayDate.longLabel(date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HAYFColor.muted)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 42, height: 42)
                .background(HAYFColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel("HAYF coach briefing")
        }
    }
}

private struct TodayStrategyCard: View {
    let briefing: TodayBriefingOutput

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("CURRENT STRATEGY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(HAYFColor.orange)
            Text(briefing.strategy.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
            HStack(spacing: 7) {
                if let phase = briefing.phase?.name { TodayPill(text: phase, color: HAYFColor.orange) }
                if let objective = briefing.week?.objective, !objective.isEmpty {
                    TodayPill(text: TodayCopy.compactWeekLabel(objective), color: HAYFColor.info)
                }
            }
        }
        .todayCard()
    }
}

private struct TodayCoachBriefingCard: View {
    let briefing: TodayBriefingOutput

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("COACH BRIEFING")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(HAYFColor.orange)
                Spacer()
                if briefing.cacheHit || briefing.usesDeterministicFallback {
                    Text(briefing.usesDeterministicFallback ? "PULL TO RETRY" : "UP TO DATE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(briefing.usesDeterministicFallback ? HAYFColor.warning : HAYFColor.muted)
                }
            }
            Text(briefing.headline)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(HAYFColor.primary)
            TodayBriefingLine(icon: "scope", title: "Long-term fit", text: briefing.strategyFit)
            TodayBriefingLine(icon: "exclamationmark.circle", title: "Why it matters", text: briefing.importance)
        }
        .todayCard(border: HAYFColor.orange.opacity(0.4))
    }
}

private struct TodayBriefingLine: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TodayConditionsView: View {
    let conditions: TodayConditions
    let showWeather: () -> Void
    let showFatigue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONDITIONS")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(HAYFColor.muted)
            HStack(alignment: .top, spacing: 10) {
                TodayConditionTile(
                    icon: conditions.weather?.conditionEmoji ?? "☁️",
                    label: "Weather",
                    headline: conditions.weather?.compactHeadline ?? "Unavailable",
                    detail: conditions.weather?.compactRainLabel ?? "No forecast",
                    color: conditions.weather?.outdoorRisk == "miserable" ? HAYFColor.warning : HAYFColor.info,
                    action: showWeather
                )
                TodayConditionTile(
                    icon: "◒",
                    label: "Fatigue",
                    headline: conditions.fatigue.compactHeadline,
                    detail: conditions.fatigue.compactConfidence,
                    color: conditions.fatigue.level == "high" ? HAYFColor.warning : HAYFColor.success,
                    action: showFatigue
                )
            }
        }
    }
}

private struct TodayConditionTile: View {
    let icon: String
    let label: String
    let headline: String
    let detail: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(icon)
                        .font(.system(size: 22))
                        .frame(width: 38, height: 38)
                        .background(color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(HAYFColor.muted)
                }
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(HAYFColor.muted)
                Text(headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(2)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .todayCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens details")
    }
}

private struct TodayConditionDetailSheet: View {
    let detail: TodayConditionDetail
    let conditions: TodayConditions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch detail {
                    case .weather:
                        weatherDetail
                    case .fatigue:
                        fatigueDetail
                    }
                }
                .padding(20)
            }
            .background(HAYFColor.neutral)
            .navigationTitle(detail == .weather ? "Weather" : "Fatigue estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var weatherDetail: some View {
        if let weather = conditions.weather {
            HStack(spacing: 14) {
                Text(weather.conditionEmoji)
                    .font(.system(size: 34))
                    .frame(width: 58, height: 58)
                    .background(HAYFColor.info.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(weather.compactHeadline)
                        .font(.system(size: 23, weight: .bold))
                    Text(weather.locationLabel ?? "Workout location")
                        .font(.system(size: 13))
                        .foregroundStyle(HAYFColor.muted)
                }
            }

            TodayDetailSection(title: "Rain timing", icon: "cloud.rain") {
                Text(weather.rainWindowLabel)
                if let peak = weather.peakRainProbability {
                    Text("Peak probability: \(Int(peak.rounded()))%")
                        .foregroundStyle(HAYFColor.muted)
                }
            }

            TodayDetailSection(title: "Workout impact", icon: "figure.run") {
                Text(weather.influence)
            }

            TodayDetailSection(title: "More detail", icon: "wind") {
                if let wind = weather.windKph { Text("Wind up to \(Int(wind.rounded())) km/h") }
                Text(TodayDate.freshnessLabel(weather.fetchedAt, confidence: weather.source))
                    .foregroundStyle(HAYFColor.muted)
            }
        } else {
            TodayDetailSection(title: "No forecast", icon: "cloud") {
                Text("HAYF does not have reliable weather for this session yet. Use current local conditions.")
            }
        }
    }

    private var fatigueDetail: some View {
        let fatigue = conditions.fatigue
        return Group {
            HStack(spacing: 14) {
                Text("◒")
                    .font(.system(size: 30))
                    .frame(width: 58, height: 58)
                    .background(HAYFColor.success.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(fatigue.compactHeadline)
                        .font(.system(size: 23, weight: .bold))
                    Text(fatigue.compactConfidence)
                        .font(.system(size: 13))
                        .foregroundStyle(HAYFColor.muted)
                }
            }

            TodayDetailSection(title: "Session influence", icon: "slider.horizontal.3") {
                Text(fatigue.influence)
            }

            TodayDetailSection(title: "Evidence", icon: "waveform.path.ecg") {
                ForEach(fatigue.factors, id: \.self) { factor in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(HAYFColor.orange).frame(width: 5, height: 5).padding(.top, 7)
                        Text(factor)
                    }
                }
                if fatigue.factors.isEmpty { Text("No recent recovery evidence is available.") }
            }

            Text("This is a coaching estimate, not a medical or readiness score.")
                .font(.system(size: 12))
                .foregroundStyle(HAYFColor.muted)
        }
    }
}

private struct TodayDetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
            VStack(alignment: .leading, spacing: 7) {
                content
            }
            .font(.system(size: 15))
            .foregroundStyle(HAYFColor.secondary)
        }
        .todayCard()
    }
}

private struct TodaySessionCard: View {
    let session: TodaySession
    let isNext: Bool
    let openDirections: () -> Void
    let manage: (TodayWorkoutAction) -> Void
    let markDone: () -> Void
    let saveFeedback: (WorkoutFeedbackDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Button(action: openDirections) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                if isNext { TodayPill(text: "NEXT", color: HAYFColor.orange) }
                                TodayPill(text: session.stateLabel, color: session.stateColor)
                            }
                            Text(session.workout.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(HAYFColor.primary)
                            Text("\(session.workout.durationMinutes) min · \(session.workout.intensityLabel) · \(session.workout.activityType.capitalized)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(HAYFColor.muted)
                        }
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: session.activityIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(HAYFColor.orange)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(HAYFColor.muted)
                        }
                    }

                    TodaySessionSummary(
                        text: session.state == .completed ? session.briefing.postBrief : session.briefing.preBrief
                    )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(session.workout.title) details")
            .accessibilityIdentifier("today.session.details.\(session.id.uuidString.lowercased())")

            if session.state == .completed {
                TodayCompletedWorkoutView(session: session, saveFeedback: saveFeedback)
            } else if session.state == .planned || session.state == .ready {
                Divider().overlay(HAYFColor.border)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(TodayWorkoutAction.allCases) { action in
                        Button { manage(action) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: action.icon)
                                Text(action.title)
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(action == .skip ? HAYFColor.muted : HAYFColor.primary)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(HAYFColor.neutral)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(action.title) \(session.workout.title)")
                    }
                }
                Button("Mark as done", action: markDone)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HAYFColor.muted)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint("Use only when HealthKit did not record this session")
            }
        }
        .todayCard(border: isNext ? HAYFColor.orange : HAYFColor.borderStrong)
    }
}

private struct TodaySessionSummary: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(TodayCopy.workoutSummaryLines(text).enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(HAYFColor.orange)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(line)
                        .font(.system(size: 15))
                        .foregroundStyle(HAYFColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct TodayCompletedWorkoutView: View {
    let session: TodaySession
    let saveFeedback: (WorkoutFeedbackDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let actual = session.actualWorkout {
                Text("WORKOUT DATA")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(HAYFColor.muted)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    TodayMetric(label: "Duration", value: "\(actual.durationMinutes) min")
                    if let distance = actual.distanceKilometers { TodayMetric(label: "Distance", value: String(format: "%.1f km", distance)) }
                    if let energy = actual.energyKilocalories { TodayMetric(label: "Energy", value: "\(Int(energy.rounded())) kcal") }
                    if let heartRate = actual.averageHeartRateBPM { TodayMetric(label: "Avg HR", value: "\(Int(heartRate.rounded())) bpm") }
                    if let heartRate = actual.maxHeartRateBPM { TodayMetric(label: "Max HR", value: "\(Int(heartRate.rounded())) bpm") }
                    if let load = actual.loadValue { TodayMetric(label: "Load", value: String(format: "%.0f", load)) }
                }
            } else {
                Text("Marked done manually. HAYF will add metrics if HealthKit imports this workout later.")
                    .font(.system(size: 13))
                    .foregroundStyle(HAYFColor.muted)
            }

            if session.deviation?.needsReview == true {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PLAN DEVIATION")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(HAYFColor.warning)
                    Text(session.briefing.weeklyImpact)
                        .font(.system(size: 14))
                        .foregroundStyle(HAYFColor.secondary)
                }
            }

            TodayFeedbackView(feedback: session.feedback, save: saveFeedback)
        }
    }
}

private struct TodayFeedbackView: View {
    let feedback: TodayStoredFeedback?
    let save: (WorkoutFeedbackDraft) -> Void

    @State private var effort: Int?
    @State private var difficulty: String?
    @State private var felt: Int?
    @State private var pain: Bool?
    @State private var painNotes: String
    @State private var freeText: String

    init(feedback: TodayStoredFeedback?, save: @escaping (WorkoutFeedbackDraft) -> Void) {
        self.feedback = feedback
        self.save = save
        _effort = State(initialValue: feedback?.perceivedEffort)
        _difficulty = State(initialValue: feedback?.difficultyLabel)
        _felt = State(initialValue: feedback?.feltRating)
        _pain = State(initialValue: feedback?.painFlag)
        _painNotes = State(initialValue: feedback?.painNotes ?? "")
        _freeText = State(initialValue: feedback?.freeText ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("OPTIONAL COACH FEEDBACK")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(HAYFColor.muted)

            TodayFeedbackQuestion(title: "How hard did it feel?") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(1...10, id: \.self) { value in
                            TodayChoiceChip(text: "\(value)", selected: effort == value) {
                                effort = value
                                save(WorkoutFeedbackDraft(perceivedEffort: value))
                            }
                        }
                    }
                }
            }

            TodayFeedbackQuestion(title: "Was the dose right?") {
                HStack(spacing: 7) {
                    ForEach([("Too easy", "too_easy"), ("Right", "right"), ("Too hard", "too_hard")], id: \.1) { label, value in
                        TodayChoiceChip(text: label, selected: difficulty == value) {
                            difficulty = value
                            save(WorkoutFeedbackDraft(difficultyLabel: value))
                        }
                    }
                }
            }

            TodayFeedbackQuestion(title: "How did you feel?") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Array(["Rough", "Low", "Okay", "Good", "Great"].enumerated()), id: \.offset) { index, label in
                            TodayChoiceChip(text: label, selected: felt == index + 1) {
                                felt = index + 1
                                save(WorkoutFeedbackDraft(feltRating: index + 1))
                            }
                        }
                    }
                }
            }

            TodayFeedbackQuestion(title: "Any pain or discomfort?") {
                HStack(spacing: 7) {
                    TodayChoiceChip(text: "No", selected: pain == false) {
                        pain = false
                        save(WorkoutFeedbackDraft(painFlag: false))
                    }
                    TodayChoiceChip(text: "Yes", selected: pain == true) {
                        pain = true
                        save(WorkoutFeedbackDraft(painFlag: true))
                    }
                }
            }

            if pain == true {
                TodayTextFeedbackField(
                    placeholder: "Where and what did you notice?",
                    text: $painNotes,
                    save: { save(WorkoutFeedbackDraft(painFlag: true, painNotes: painNotes)) }
                )
            }

            TodayTextFeedbackField(
                placeholder: "Anything else your coach should know?",
                text: $freeText,
                save: { save(WorkoutFeedbackDraft(freeText: freeText)) }
            )
        }
        .padding(.top, 4)
    }
}

private struct TodayFeedbackQuestion<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
            content
        }
    }
}

private struct TodayChoiceChip: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? Color.white : HAYFColor.secondary)
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(selected ? HAYFColor.primary : HAYFColor.surfaceRaised)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TodayTextFeedbackField: View {
    let placeholder: String
    @Binding var text: String
    let save: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(1...3)
            Button("Save", action: save)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HAYFColor.orange)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(HAYFColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct TodayRestDayCard: View {
    let briefing: TodayBriefingOutput

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("OPEN DAY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(HAYFColor.success)
            Text("Recovery is part of the strategy")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(HAYFColor.primary)
            Text(briefing.importance)
                .font(.system(size: 16))
                .foregroundStyle(HAYFColor.secondary)
            HStack(spacing: 9) {
                Image(systemName: "sunrise")
                    .foregroundStyle(HAYFColor.orange)
                Text(tomorrowText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HAYFColor.muted)
            }
        }
        .todayCard(border: HAYFColor.success.opacity(0.35))
    }

    private var tomorrowText: String {
        guard let workout = briefing.tomorrowPreview else {
            return "Tomorrow is open too; your next session remains visible in Plan."
        }
        return "Tomorrow: \(workout.title), \(workout.durationMinutes) min."
    }
}

private struct TodayMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(HAYFColor.muted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(HAYFColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TodayPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(height: 25)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

private struct TodayActionContext: Identifiable {
    let action: TodayWorkoutAction
    let session: TodaySession
    var id: String { "\(session.id)-\(action.rawValue)" }
}

private struct TodayWorkoutActionSheet: View {
    let context: TodayActionContext
    @ObservedObject var store: TodayDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var userContext = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(context.action.title + " workout")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(HAYFColor.primary)
                    Text(context.session.workout.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(HAYFColor.muted)

                    if store.isLoadingRecommendation {
                        ProgressView("HAYF is reviewing the week…")
                            .tint(HAYFColor.orange)
                            .frame(maxWidth: .infinity, minHeight: 150)
                    } else if let recommendation = store.recommendation,
                              recommendation.workoutID == context.session.id,
                              recommendation.action == context.action {
                        TodayBriefingLine(icon: "sparkles", title: "Coach's read", text: recommendation.coachRead)
                        TodayBriefingLine(icon: "calendar", title: "Weekly impact", text: recommendation.weeklyImpact)
                        actionOptions(recommendation)
                    } else if let error = store.actionErrorMessage {
                        Text(error).foregroundStyle(HAYFColor.error)
                        Button("Try again") { requestRecommendation() }
                            .buttonStyle(.borderedProminent)
                            .tint(HAYFColor.primary)
                    }

                    TextField("Tell HAYF why (optional)", text: $userContext, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14)
                        .background(HAYFColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(HAYFColor.borderStrong) }

                    Button("Refresh recommendation") { requestRecommendation() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HAYFColor.orange)
                }
                .padding(20)
            }
            .background(HAYFColor.neutral)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { requestRecommendation() }
    }

    @ViewBuilder
    private func actionOptions(_ recommendation: TodayWorkoutActionRecommendation) -> some View {
        switch context.action {
        case .skip:
            TodayPrimaryButton(title: store.isMutating ? "Skipping…" : "Confirm skip", destructive: true) {
                Task {
                    if await store.apply(.skip, to: context.session.workout, context: userContext) { dismiss() }
                }
            }
            .disabled(store.isMutating)
        case .move:
            ForEach(recommendation.moveOptions) { option in
                TodayActionOptionCard(title: TodayDate.moveLabel(option.date), detail: option.rationale, button: "Move here") {
                    Task {
                        if await store.apply(.move, to: context.session.workout, moveDate: option.date, context: userContext) { dismiss() }
                    }
                }
            }
        case .swap, .adjust:
            ForEach(recommendation.workoutOptions) { candidate in
                TodayActionOptionCard(
                    title: candidate.title,
                    detail: "\(candidate.durationMinutes) min · \(candidate.intensityLabel)\n\(candidate.rationale)\n\(candidate.weeklyImpact)",
                    button: context.action == .swap ? "Use this workout" : "Use this adjustment"
                ) {
                    Task {
                        if await store.apply(context.action, to: context.session.workout, candidate: candidate, context: userContext) { dismiss() }
                    }
                }
            }
        }
    }

    private func requestRecommendation() {
        Task { await store.recommend(context.action, for: context.session.id, context: userContext) }
    }
}

private struct TodayActionOptionCard: View {
    let title: String
    let detail: String
    let button: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(HAYFColor.secondary)
            Button(button, action: action)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(HAYFColor.primary)
                .clipShape(Capsule())
        }
        .todayCard()
    }
}

private struct TodayPrimaryButton: View {
    let title: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(destructive ? HAYFColor.error : HAYFColor.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TodayReplanReviewCard: View {
    let review: TodayReplanReview
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(review.status == "no_change" ? "WEEK REVIEWED" : "HAYF PROPOSES A WEEK UPDATE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(review.status == "no_change" ? HAYFColor.success : HAYFColor.orange)
            Text(review.summary ?? "Review how today's result affects the rest of the week.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
            if review.status == "pending" {
                Button("Review \(review.mutationCount) proposed change\(review.mutationCount == 1 ? "" : "s")", action: open)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HAYFColor.orange)
            }
        }
        .todayCard(border: HAYFColor.orange.opacity(0.35))
    }
}

private struct TodayReplanReviewSheet: View {
    let review: TodayReplanReview
    @ObservedObject var store: TodayDataStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Review the rest of the week")
                    .font(.system(size: 28, weight: .bold))
                if let reason = review.reason { Text(reason).font(.system(size: 17, weight: .semibold)) }
                Text(review.summary ?? "HAYF reviewed today's training effect.")
                    .font(.system(size: 16))
                    .foregroundStyle(HAYFColor.secondary)
                Text("\(review.mutationCount) proposed change\(review.mutationCount == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
                ForEach(Array(review.mutationSummaries.enumerated()), id: \.offset) { _, summary in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(HAYFColor.orange)
                        Text(summary)
                            .font(.system(size: 14))
                            .foregroundStyle(HAYFColor.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HAYFColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                Spacer()
                TodayPrimaryButton(title: "Accept HAYF's changes") {
                    Task { await store.decideReplan(.accepted); dismiss() }
                }
                Button("Keep the week unchanged") {
                    Task { await store.decideReplan(.rejected); dismiss() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .padding(24)
            .background(HAYFColor.neutral)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}

private struct TodayLoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(HAYFColor.orange)
            Text("Reconciling today's plan…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HAYFColor.muted)
        }
    }
}

private struct TodayUnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HAYFLogo(markSize: 32, textSize: 28, spacing: 8)
            Spacer()
            Image(systemName: "sun.max")
                .font(.system(size: 28))
                .foregroundStyle(HAYFColor.orange)
            Text("Today")
                .font(.system(size: 36, weight: .bold))
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(HAYFColor.muted)
            TodayPrimaryButton(title: "Try again", action: retry)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 560)
    }
}

private extension TodaySession {
    var stateLabel: String {
        switch state {
        case .planned: return "PLANNED"
        case .ready: return "READY"
        case .completed: return "COMPLETED"
        case .skipped: return "SKIPPED"
        case .missed: return "MISSED"
        }
    }

    var stateColor: Color {
        switch state {
        case .completed: return HAYFColor.success
        case .skipped, .missed: return HAYFColor.muted
        case .ready, .planned: return HAYFColor.orange
        }
    }

    var activityIcon: String {
        let value = workout.activityType.lowercased()
        if value.contains("run") { return "figure.run" }
        if value.contains("ride") || value.contains("cycl") { return "bicycle" }
        if value.contains("strength") { return "dumbbell" }
        if value.contains("swim") { return "figure.pool.swim" }
        return "figure.mixed.cardio"
    }
}

private extension TodayWeatherCondition {
    var summary: String {
        var parts: [String] = []
        if let temperatureCelsius { parts.append("\(Int(temperatureCelsius.rounded()))°C") }
        if let precipitationProbability { parts.append("\(Int(precipitationProbability.rounded()))% rain") }
        if let windKph { parts.append("\(Int(windKph.rounded())) km/h wind") }
        return parts.isEmpty ? "Forecast available" : parts.joined(separator: " · ")
    }
}

private extension TodayReplanReview {
    var mutationSummaries: [String] {
        guard case let .array(values) = mutations else { return [] }
        return values.compactMap { value in
            guard case let .object(object) = value else { return nil }
            let type = object.stringValue("type")?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Plan update"
            let fields: [String: JSONValue]
            if case let .object(value) = object["fields"] { fields = value } else { fields = [:] }
            let title = fields.stringValue("title")
            let date = fields.stringValue("scheduledDate") ?? fields.stringValue("scheduled_date")
            let duration = fields.numberValue("durationMinutes") ?? fields.numberValue("duration_minutes")
            let detail = [title, date, duration.map { "\(Int($0)) min" }].compactMap { $0 }.joined(separator: " · ")
            return detail.isEmpty ? type : "\(type): \(detail)"
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func stringValue(_ key: String) -> String? {
        guard case let .string(value) = self[key] else { return nil }
        return value
    }

    func numberValue(_ key: String) -> Double? {
        guard case let .number(value) = self[key] else { return nil }
        return value
    }
}

private extension View {
    func todayCard(border: Color = HAYFColor.borderStrong) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
    }
}

private extension TodayWeatherCondition {
    var compactHeadline: String {
        let temperature = temperatureCelsius.map { "\(Int($0.rounded()))°" } ?? "—"
        return "\(temperature) · \(conditionLabel ?? "Weather")"
    }

    var compactRainLabel: String {
        guard let probability = precipitationProbability else { return "Rain unknown" }
        return "\(Int(probability.rounded()))% rain"
    }

    var rainWindowLabel: String {
        guard let start = TodayDate.weatherTime(rainStartTime) else {
            return precipitationProbability.map { "No sustained rain window; daily probability is \(Int($0.rounded()))%." }
                ?? "No reliable rain timing is available."
        }
        if let end = TodayDate.weatherTime(rainEndTime), end != start {
            return "Rain is expected around \(start)–\(end)."
        }
        return "Rain is expected around \(start)."
    }
}

private extension TodayFatigueEstimate {
    var compactHeadline: String {
        level == "unknown" ? "Not enough data" : "\(level.capitalized) fatigue"
    }

    var compactConfidence: String {
        level == "unknown" ? "Check how you feel" : "\(confidence.capitalized) confidence"
    }
}

enum TodayCopy {
    static func compactWeekLabel(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        text = text.replacingOccurrences(
            of: #"^(Use|Keep|Build|Complete|Add)\s+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        if let range = text.range(of: " to ", options: .caseInsensitive) {
            text = String(text[..<range.lowerBound])
        }
        let words = text.split(separator: " ")
        var compact = ""
        for word in words {
            let candidate = compact.isEmpty ? String(word) : "\(compact) \(word)"
            guard candidate.count <= 26 else { break }
            compact = candidate
        }
        return compact.isEmpty ? "This week" : compact
    }

    static func workoutSummaryLines(_ value: String) -> [String] {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.replacingOccurrences(
            of: #"(?<=\d),(?=\d)"#,
            with: "–",
            options: .regularExpression
        )
        for cue in ["hydrate", "fuel", "cool down", "finish with", "then"] {
            normalized = normalized.replacingOccurrences(
                of: #",\s*(?i:\#(cue))"#,
                with: "; \(cue.capitalized)",
                options: .regularExpression
            )
        }
        let chunks = normalized
            .replacingOccurrences(of: "\n", with: ";")
            .split(separator: ";")
            .map { chunk in
                var line = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty else { return line }
                line.replaceSubrange(line.startIndex...line.startIndex, with: line.prefix(1).uppercased())
                return line.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
            .filter { !$0.isEmpty }
        return Array((chunks.isEmpty ? [normalized] : chunks).prefix(4))
    }
}

private enum TodayDate {
    static func date(from value: String) -> Date? { dateFormatter.date(from: value) }

    static func longLabel(_ value: String) -> String {
        guard let date = date(from: value) else { return value }
        return longFormatter.string(from: date)
    }

    static func moveLabel(_ value: String) -> String {
        guard let date = date(from: value) else { return value }
        return moveFormatter.string(from: date)
    }

    static func freshnessLabel(_ value: String?, confidence: String) -> String {
        guard let value, let date = ISO8601DateFormatter().date(from: value) else { return "Freshness unknown · \(confidence)" }
        let hours = max(0, Int(Date().timeIntervalSince(date) / 3600))
        return hours < 1 ? "Updated recently · \(confidence)" : "Updated \(hours)h ago · \(confidence)"
    }

    static func weatherTime(_ value: String?) -> String? {
        guard let value, let date = weatherInputFormatter.date(from: value) else { return nil }
        return weatherOutputFormatter.string(from: date)
    }

    static var partOfDay: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "morning"
        case 12..<18: return "afternoon"
        default: return "evening"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    private static let moveFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter
    }()

    private static let weatherInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    private static let weatherOutputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

fileprivate enum TodayPreviewKind {
    case rest
    case planned
    case multiple
    case completedAsPlanned
    case completedWithDeviation
    case missingHealthKit
    case staleBriefing
    case error
}

fileprivate enum TodayPreviewFixtures {
    static func briefing(for kind: TodayPreviewKind) -> TodayBriefingOutput? {
        guard kind != .error else { return nil }
        let sessions: [TodaySession]
        let state: TodayDayState
        switch kind {
        case .rest:
            sessions = []
            state = .rest
        case .multiple:
            sessions = [session(index: 1), session(index: 2, activity: "strength", title: "Lower-body strength", duration: 40)]
            state = .planned
        case .completedAsPlanned:
            sessions = [session(index: 1, completed: true)]
            state = .completed
        case .completedWithDeviation:
            sessions = [session(index: 1, completed: true, deviated: true)]
            state = .completed
        case .missingHealthKit, .planned, .staleBriefing:
            sessions = [session(index: 1)]
            state = .planned
        case .error:
            return nil
        }

        let unknownEvidence = kind == .missingHealthKit || kind == .staleBriefing
        return TodayBriefingOutput(
            userID: id(90),
            model: kind == .staleBriefing ? "deterministic" : "gpt-5-mini",
            date: "2026-07-15",
            timezone: "Europe/Berlin",
            state: state,
            cacheHit: kind == .staleBriefing,
            generation: .object(["status": .string(kind == .staleBriefing ? "fallback" : "succeeded")]),
            strategy: TodayStrategyContext(
                id: id(91),
                title: "Build durable cycling fitness",
                summary: "Build aerobic capacity without sacrificing strength.",
                rationale: "A steady progression keeps the work absorbable."
            ),
            phase: TodayPhaseContext(id: id(92), name: "Foundation", objective: "Build repeatable aerobic work"),
            week: TodayWeekContext(id: id(93), objective: "Aerobic rhythm and strength support", status: "committed", context: .object([:])),
            headline: sessions.isEmpty ? "Recovery supports the plan" : sessions.first?.state == .completed ? "Today's work is logged" : "An honest aerobic dose",
            strategyFit: "Today's work builds the durable aerobic base that the later specific sessions will depend on.",
            importance: sessions.isEmpty ? "An open day protects recovery and makes tomorrow's work easier to absorb." : "The controlled dose matters because it leaves room for the rest of the week's quality.",
            conditions: TodayConditions(
                weather: kind == .missingHealthKit ? nil : TodayWeatherCondition(
                    source: "Open-Meteo",
                    fetchedAt: "2026-07-15T05:45:00Z",
                    forecastDate: "2026-07-15",
                    locationLabel: "Berlin",
                    conditionLabel: "Partly cloudy",
                    conditionEmoji: "⛅️",
                    temperatureCelsius: 19,
                    precipitationProbability: 15,
                    rainStartTime: "2026-07-15T16:00",
                    rainEndTime: "2026-07-15T18:00",
                    peakRainProbability: 45,
                    windKph: 12,
                    outdoorRisk: "ok",
                    influence: "Conditions support an outdoor session; take fluids and keep the easy sections honest."
                ),
                fatigue: TodayFatigueEstimate(
                    level: unknownEvidence ? "unknown" : "low",
                    confidence: unknownEvidence ? "low" : "medium",
                    freshness: kind == .staleBriefing ? "stale" : unknownEvidence ? "missing" : "fresh",
                    factors: unknownEvidence ? ["No recent recovery snapshot"] : ["Sleep is close to your recent norm", "Training volume is within your pattern"],
                    evidenceAt: unknownEvidence ? nil : "2026-07-15T05:30:00Z",
                    adjustmentSuggested: false,
                    influence: unknownEvidence ? "HAYF does not have enough fresh evidence to estimate fatigue confidently." : "The evidence supports the planned dose; use Adjust if your body disagrees."
                )
            ),
            sessions: sessions,
            tomorrowPreview: sessions.isEmpty ? workout(index: 8, title: "Aerobic endurance", duration: 65) : nil,
            replanReview: kind == .completedWithDeviation
                ? TodayReplanReview(status: "pending", proposalID: id(94), reason: "The logged intensity was higher than planned.", summary: "Move Friday's intervals to protect recovery.", mutationCount: 1)
                : TodayReplanReview(status: "none", proposalID: nil, reason: nil, summary: nil, mutationCount: 0)
        )
    }

    private static func session(
        index: Int,
        activity: String = "cycling",
        title: String = "Easy aerobic ride",
        duration: Int = 55,
        completed: Bool = false,
        deviated: Bool = false
    ) -> TodaySession {
        let workout = workout(index: index, activity: activity, title: title, duration: duration, status: completed ? .done : .planned)
        return TodaySession(
            workout: workout,
            actualWorkout: completed ? TodayActualWorkout(
                id: id(index + 30),
                startDate: "2026-07-15T07:00:00Z",
                activityType: activity,
                durationMinutes: deviated ? 68 : duration,
                distanceKilometers: activity == "cycling" ? 28.4 : nil,
                energyKilocalories: 510,
                loadValue: deviated ? 112 : 62,
                averageHeartRateBPM: deviated ? 159 : 132,
                maxHeartRateBPM: deviated ? 188 : 151
            ) : nil,
            state: completed ? .completed : .planned,
            deviation: deviated ? TodayDeviation(needsReview: true, duration: .object([:]), intensity: .object([:])) : nil,
            feedback: completed ? TodayStoredFeedback(perceivedEffort: nil, feltRating: nil, painFlag: nil, painNotes: nil, difficultyLabel: nil, freeText: nil) : nil,
            debriefRequest: completed ? TodayDebriefRequest(id: id(index + 60), status: "needed", promptReason: "post_workout") : nil,
            briefing: TodaySessionBriefing(
                workoutID: workout.id,
                preBrief: "Keep this conversational and smooth; the purpose is aerobic accumulation, not proving fitness today.",
                postBrief: deviated ? "The logged ride was longer and materially harder than the easy Zone 2 role HAYF prescribed." : "The logged work closely matched the planned aerobic role.",
                weeklyImpact: deviated ? "The extra intensity increases recovery cost, so HAYF reviewed the next quality session." : "The week can remain unchanged."
            )
        )
    }

    private static func workout(
        index: Int,
        activity: String = "cycling",
        title: String,
        duration: Int,
        status: PlanWorkoutStatus = .planned
    ) -> TodayWorkout {
        TodayWorkout(
            id: id(index),
            scheduledDate: index == 8 ? "2026-07-16" : "2026-07-15",
            sequenceOrder: index,
            activityType: activity,
            title: title,
            durationMinutes: duration,
            estimatedDistanceKilometers: activity == "cycling" ? 24 : nil,
            estimatedElevationMeters: nil,
            intensityLabel: "Low",
            purpose: "Build aerobic durability while keeping recovery cost controlled.",
            status: status,
            source: "generated",
            fuelingSummary: "Water",
            prescription: .object([
                "whyToday": .string("This supports the Foundation phase."),
                "warmup": .string("10 minutes easy."),
                "main": .string("35 minutes steady Zone 2."),
                "cooldown": .string("10 minutes very easy."),
                "successCriteria": .string("Finish feeling able to continue.")
            ]),
            plannedLocationLabel: "Berlin",
            weatherForecast: .object([:])
        )
    }

    private static func id(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }
}

#Preview("Today · Rest") { TodayScreenView(userName: "Daniel", preview: .rest) }
#Preview("Today · Planned") { TodayScreenView(userName: "Daniel", preview: .planned) }
#Preview("Today · Multiple") { TodayScreenView(userName: "Daniel", preview: .multiple) }
#Preview("Today · Completed") { TodayScreenView(userName: "Daniel", preview: .completedAsPlanned) }
#Preview("Today · Deviation") { TodayScreenView(userName: "Daniel", preview: .completedWithDeviation) }
#Preview("Today · Missing HealthKit") { TodayScreenView(userName: "Daniel", preview: .missingHealthKit) }
#Preview("Today · Stale briefing") { TodayScreenView(userName: "Daniel", preview: .staleBriefing) }
#Preview("Today · Error") { TodayScreenView(userName: "Daniel", preview: .error) }
