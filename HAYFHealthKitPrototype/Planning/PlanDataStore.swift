import Foundation
import Supabase

@MainActor
final class PlanDataStore: ObservableObject {
    @Published private(set) var activeBlock: PlanActiveFitnessBlock?
    @Published private(set) var phases: [PlanFitnessBlockPhase] = []
    @Published private(set) var weeklyRhythms: [PlanWeeklyRhythm] = []
    @Published private(set) var workouts: [PlanWorkout] = []
    @Published private(set) var goalTargets: [PlanGoalTarget] = []
    @Published private(set) var goalEvaluations: [PlanGoalEvaluation] = []
    @Published private(set) var historyInsights: [FitnessHistoryInsight] = []
    @Published private(set) var debriefRequests: [WorkoutDebriefRequest] = []
    @Published private(set) var pendingReplanProposals: [PlanReplanProposal] = []
    @Published private(set) var homeLocationLabel: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let supabase: SupabaseClient
    private let calendar: Calendar

    init(
        supabase: SupabaseClient = SupabaseClientProvider.shared,
        calendar: Calendar = PlanCalendar.iso
    ) {
        self.supabase = supabase
        self.calendar = calendar
    }

    func loadVisiblePlan() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let block = try await fetchActiveBlock() else {
                activeBlock = nil
                phases = []
                weeklyRhythms = []
                workouts = []
                goalTargets = []
                goalEvaluations = []
                historyInsights = []
                debriefRequests = []
                pendingReplanProposals = []
                homeLocationLabel = nil
                return
            }

            async let phases = fetchPhases(for: block.id)
            async let weeklyRhythms = fetchWeeklyRhythms(for: block.id)
            async let workouts = fetchWorkouts(for: block.id)
            async let homeLocationLabel = fetchHomeLocationLabel()
            async let goalEvaluations = fetchGoalEvaluations(for: block.id)
            async let historyInsights = fetchHistoryInsights(for: block.id)
            async let debriefRequests = fetchDebriefRequests(for: block.id)
            async let pendingReplanProposals = fetchPendingReplanProposals(for: block.id)

            let loadedWeeklyRhythms = try await weeklyRhythms
            let loadedTargets = try await fetchPlanningTargets(
                for: block.id,
                weeklyPlanIDs: loadedWeeklyRhythms.map(\.id)
            )

            activeBlock = block
            self.phases = try await phases
            self.weeklyRhythms = loadedWeeklyRhythms
            self.workouts = try await workouts
            self.homeLocationLabel = try await homeLocationLabel
            self.goalTargets = loadedTargets
            self.goalEvaluations = try await goalEvaluations
            self.historyInsights = try await historyInsights
            self.debriefRequests = try await debriefRequests
            self.pendingReplanProposals = try await pendingReplanProposals
        } catch is CancellationError {
            // SwiftUI can cancel an in-flight refresh when a newer load starts. Keep the current plan visible.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchActiveBlock() async throws -> PlanActiveFitnessBlock? {
        do {
            let strategy: PlanRawFitnessStrategy = try await supabase
                .from("fitness_strategies")
                .select("id, user_goal_id, status, title, summary, rationale, review_cadence_days, start_date, target_date, requires_phases, context_json")
                .eq("status", value: "active")
                .single()
                .execute()
                .value

            let goal: PlanRawUserGoal = try await supabase
                .from("user_goals")
                .select("id, goal_kind, title, status, start_date, target_date, timeframe_weeks, requires_phases, normalized_goal_json")
                .eq("id", value: strategy.userGoalID.uuidString.lowercased())
                .single()
                .execute()
                .value

            return PlanActiveFitnessBlock(strategy: strategy, goal: goal)
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    private func fetchPhases(for strategyID: UUID) async throws -> [PlanFitnessBlockPhase] {
        try await supabase
            .from("fitness_strategy_phases")
            .select("id, fitness_strategy_id, name, start_date, end_date, objective, focus_json, risk_json")
            .eq("fitness_strategy_id", value: strategyID.uuidString.lowercased())
            .order("sequence_order", ascending: true)
            .execute()
            .value
    }

    private func fetchWeeklyRhythms(for strategyID: UUID) async throws -> [PlanWeeklyRhythm] {
        let window = visibleWindow()

        let plans: [PlanWeeklyRhythm] = try await supabase
            .from("weekly_plans")
            .select("id, fitness_strategy_id, week_start_date, week_end_date, objective, status, rhythm_json, constraints_json")
            .eq("fitness_strategy_id", value: strategyID.uuidString.lowercased())
            .gte("week_start_date", value: PlanCalendar.dateFormatter.string(from: window.start))
            .lte("week_start_date", value: PlanCalendar.dateFormatter.string(from: window.end))
            .order("week_start_date", ascending: true)
            .execute()
            .value

        return plans.filter { $0.status == "committed" || $0.status == "draft" }
    }

    private func fetchWorkouts(for strategyID: UUID) async throws -> [PlanWorkout] {
        let window = visibleWindow()
        let planIDs = try await fetchWeeklyPlanIDs(for: strategyID, window: window)

        let workouts: [PlanWorkout]
        do {
            workouts = try await fetchWorkouts(
                from: window,
                selectColumns: PlanWorkout.enrichedSelectColumns
            )
        } catch let error as PostgrestError where error.isMissingWorkoutCardColumn {
            workouts = try await fetchWorkouts(
                from: window,
                selectColumns: PlanWorkout.legacySelectColumns
            )
        }

        let visibleWorkouts = workouts.filter { workout in
            guard let weeklyPlanID = workout.weeklyPlanID else { return false }
            return planIDs.contains(weeklyPlanID)
        }

        return deduplicatedGeneratedWorkouts(visibleWorkouts)
    }

    private func fetchWorkouts(
        from window: DateInterval,
        selectColumns: String
    ) async throws -> [PlanWorkout] {
        try await supabase
            .from("planned_workouts")
            .select(selectColumns)
            .gte("scheduled_date", value: PlanCalendar.dateFormatter.string(from: window.start))
            .lte("scheduled_date", value: PlanCalendar.dateFormatter.string(from: window.end))
            .not("status", operator: .in, value: "(deleted,superseded)")
            .order("scheduled_date", ascending: true)
            .order("sequence_order", ascending: true)
            .execute()
            .value
    }

    private func fetchHomeLocationLabel() async throws -> String? {
        do {
            let row: PlanProfileLocationRow = try await supabase
                .from("profiles")
                .select("main_city")
                .single()
                .execute()
                .value
            return row.mainCity.planNilIfEmpty
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    private func fetchPlanningTargets(for strategyID: UUID, weeklyPlanIDs: [UUID]) async throws -> [PlanGoalTarget] {
        async let strategyTargets = fetchStrategyTargets(for: strategyID)
        async let weeklyTargets = fetchWeeklyTargets(for: weeklyPlanIDs)
        let loadedStrategyTargets = try await strategyTargets
        let loadedWeeklyTargets = try await weeklyTargets
        return loadedStrategyTargets + loadedWeeklyTargets
    }

    private func fetchStrategyTargets(for strategyID: UUID) async throws -> [PlanGoalTarget] {
        try await supabase
            .from("planning_targets")
            .select(PlanGoalTarget.selectColumns)
            .eq("fitness_strategy_id", value: strategyID.uuidString.lowercased())
            .order("target_kind", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    private func fetchWeeklyTargets(for weeklyPlanIDs: [UUID]) async throws -> [PlanGoalTarget] {
        var targets: [PlanGoalTarget] = []
        for weeklyPlanID in weeklyPlanIDs {
            let weekTargets: [PlanGoalTarget] = try await supabase
                .from("planning_targets")
                .select(PlanGoalTarget.selectColumns)
                .eq("weekly_plan_id", value: weeklyPlanID.uuidString.lowercased())
                .eq("target_scope", value: "week")
                .order("target_kind", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value
            targets.append(contentsOf: weekTargets)
        }
        return targets
    }

    private func fetchGoalEvaluations(for strategyID: UUID) async throws -> [PlanGoalEvaluation] {
        try await supabase
            .from("planning_target_evaluations")
            .select("id, planning_target_id, status, current_value, target_value, unit, progress_ratio, evaluated_at, evidence_json, message, confidence")
            .order("evaluated_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    private func fetchHistoryInsights(for strategyID: UUID) async throws -> [FitnessHistoryInsight] {
        try await supabase
            .from("fitness_history_insights")
            .select("id, active_block_id, insight_key, category, title, summary, evidence_json, source, confidence, valid_from, valid_until, updated_at")
            .order("updated_at", ascending: false)
            .limit(12)
            .execute()
            .value
    }

    private func fetchDebriefRequests(for strategyID: UUID) async throws -> [WorkoutDebriefRequest] {
        try await supabase
            .from("workout_debrief_requests")
            .select("id, active_block_id, planned_workout_id, actual_workout_id, status, prompt_reason, created_at")
            .eq("status", value: "needed")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func fetchPendingReplanProposals(for strategyID: UUID) async throws -> [PlanReplanProposal] {
        let proposals: [PlanReplanProposal] = try await supabase
            .from("replan_proposals")
            .select("id, active_block_id, user_goal_id, fitness_strategy_id, weekly_plan_id, trigger_event_id, reason, proposed_mutations_json, status, created_at, updated_at")
            .eq("fitness_strategy_id", value: strategyID.uuidString.lowercased())
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value

        return Array(proposals.filter { $0.mutationCount > 0 }.prefix(1))
    }

    private func visibleWindow() -> DateInterval {
        PlanCalendar.visibleWindow(calendar: calendar)
    }

    private func fetchWeeklyPlanIDs(for strategyID: UUID, window: DateInterval) async throws -> Set<UUID> {
        let plans: [PlanWeeklyPlanIDRow] = try await supabase
            .from("weekly_plans")
            .select("id, status")
            .eq("fitness_strategy_id", value: strategyID.uuidString.lowercased())
            .gte("week_start_date", value: PlanCalendar.dateFormatter.string(from: window.start))
            .lte("week_start_date", value: PlanCalendar.dateFormatter.string(from: window.end))
            .execute()
            .value

        return Set(plans.filter { $0.status == "committed" || $0.status == "draft" }.map(\.id))
    }

    private func deduplicatedGeneratedWorkouts(_ workouts: [PlanWorkout]) -> [PlanWorkout] {
        var seenGeneratedKeys = Set<String>()

        return workouts.filter { workout in
            guard isGeneratedPlanWorkout(workout) else {
                return true
            }

            let key = generatedWorkoutKey(workout)
            return seenGeneratedKeys.insert(key).inserted
        }
    }

    private func isGeneratedPlanWorkout(_ workout: PlanWorkout) -> Bool {
        (workout.source == "generated" || workout.source == "replanned")
            && (workout.status == .planned || workout.status == .current)
    }

    private func generatedWorkoutKey(_ workout: PlanWorkout) -> String {
        [
            workout.weeklyPlanID?.uuidString.lowercased() ?? "",
            workout.scheduledDate,
            String(workout.sequenceOrder),
            normalizedGeneratedWorkoutText(workout.activityType),
            normalizedGeneratedWorkoutText(workout.title),
            String(workout.durationMinutes),
            normalizedGeneratedWorkoutText(workout.intensityLabel),
            normalizedGeneratedWorkoutText(workout.purpose)
        ].joined(separator: "|")
    }

    private func normalizedGeneratedWorkoutText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

enum PlanCalendar {
    static var iso: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }()

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func currentCommittedWeekStart(calendar: Calendar = iso, now: Date = Date()) -> Date {
        let currentStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.weekday, .hour], from: now)
        if components.weekday == 1, (components.hour ?? 0) >= 21 {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: currentStart) ?? currentStart
        }

        return currentStart
    }

    static func visibleWindow(calendar: Calendar = iso, now: Date = Date()) -> DateInterval {
        let start = currentCommittedWeekStart(calendar: calendar, now: now)
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        let nextWeekEnd = calendar.date(byAdding: .day, value: 6, to: nextWeekStart) ?? nextWeekStart
        return DateInterval(start: start, end: nextWeekEnd)
    }
}

private struct PlanRawFitnessStrategy: Decodable {
    let id: UUID
    let userGoalID: UUID
    let status: String
    let title: String
    let summary: String
    let rationale: String
    let reviewCadenceDays: Int
    let startDate: String
    let targetDate: String?
    let requiresPhases: Bool
    let context: PlanBlockContext

    enum CodingKeys: String, CodingKey {
        case id
        case userGoalID = "user_goal_id"
        case status
        case title
        case summary
        case rationale
        case reviewCadenceDays = "review_cadence_days"
        case startDate = "start_date"
        case targetDate = "target_date"
        case requiresPhases = "requires_phases"
        case context = "context_json"
    }
}

private struct PlanRawUserGoal: Decodable {
    let id: UUID
    let goalKind: String
    let title: String
    let status: String
    let startDate: String
    let targetDate: String?
    let timeframeWeeks: Int?
    let requiresPhases: Bool
    let normalizedGoal: JSONValue

    enum CodingKeys: String, CodingKey {
        case id
        case goalKind = "goal_kind"
        case title
        case status
        case startDate = "start_date"
        case targetDate = "target_date"
        case timeframeWeeks = "timeframe_weeks"
        case requiresPhases = "requires_phases"
        case normalizedGoal = "normalized_goal_json"
    }
}

private struct PlanWeeklyPlanIDRow: Decodable {
    let id: UUID
    let status: String
}

private struct PlanProfileLocationRow: Decodable {
    let mainCity: String

    enum CodingKeys: String, CodingKey {
        case mainCity = "main_city"
    }
}

struct PlanActiveFitnessBlock: Identifiable {
    let id: UUID
    let kind: String
    let title: String
    let goalText: String?
    let status: String
    let startDate: String
    let targetDate: String?
    let reviewCadenceDays: Int
    let timezone: String
    let context: PlanBlockContext

    init(
        id: UUID,
        kind: String,
        title: String,
        goalText: String?,
        status: String,
        startDate: String,
        targetDate: String?,
        reviewCadenceDays: Int,
        timezone: String,
        context: PlanBlockContext
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.goalText = goalText
        self.status = status
        self.startDate = startDate
        self.targetDate = targetDate
        self.reviewCadenceDays = reviewCadenceDays
        self.timezone = timezone
        self.context = context
    }

    fileprivate init(strategy: PlanRawFitnessStrategy, goal: PlanRawUserGoal) {
        self.init(
            id: strategy.id,
            kind: goal.goalKind,
            title: strategy.title,
            goalText: goal.title,
            status: strategy.status,
            startDate: strategy.startDate,
            targetDate: strategy.targetDate ?? goal.targetDate,
            reviewCadenceDays: strategy.reviewCadenceDays,
            timezone: strategy.context.timezone ?? TimeZone.current.identifier,
            context: PlanBlockContext(
            onboardingIntent: goal.goalKind,
            planningRationale: strategy.rationale.planNilIfEmpty ?? strategy.summary.planNilIfEmpty,
            dataFreshness: nil,
            timezone: strategy.context.timezone ?? TimeZone.current.identifier,
            acceptedAt: strategy.context.acceptedAt,
            planOwnerStartDate: strategy.context.planOwnerStartDate,
            acceptedStrategy: strategy.context.acceptedStrategy
            )
        )
    }
}

private extension String {
    var planNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct PlanBlockContext: Decodable {
    let onboardingIntent: String?
    let planningRationale: String?
    let dataFreshness: String?
    let timezone: String?
    let acceptedAt: String?
    let planOwnerStartDate: String?
    let acceptedStrategy: JSONValue?
}

struct PlanFitnessBlockPhase: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID
    let name: String
    let startDate: String?
    let endDate: String?
    let objective: String
    let focus: [String]
    let risk: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "fitness_strategy_id"
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case objective
        case focus = "focus_json"
        case risk = "risk_json"
    }
}

struct PlanWeeklyRhythm: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID
    let weekStartDate: String
    let weekEndDate: String
    let objective: String
    let badDayFloor: String?
    let status: String
    let rhythm: JSONValue?
    let constraints: JSONValue?

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "fitness_strategy_id"
        case weekStartDate = "week_start_date"
        case weekEndDate = "week_end_date"
        case objective
        case badDayFloor = "bad_day_floor"
        case status
        case rhythm = "rhythm_json"
        case constraints = "constraints_json"
    }

    func constraint(for date: String) -> PlanDayConstraint? {
        guard case let .object(root)? = constraints,
              case let .object(days)? = root["days"],
              case let .object(day)? = days[date],
              case let .string(kindValue)? = day["kind"],
              let kind = PlanningWeeklyPlanConstraintKind(rawValue: kindValue),
              kind != .available else {
            return nil
        }

        let note: String?
        if case let .string(value)? = day["note"] {
            note = value
        } else {
            note = nil
        }

        let updatedAt: String?
        if case let .string(value)? = day["updatedAt"] {
            updatedAt = value
        } else {
            updatedAt = nil
        }

        return PlanDayConstraint(date: date, kind: kind, note: note, updatedAt: updatedAt)
    }
}

struct PlanDayConstraint: Equatable {
    let date: String
    let kind: PlanningWeeklyPlanConstraintKind
    let note: String?
    let updatedAt: String?
}

struct PlanWorkout: Decodable, Identifiable {
    static let legacySelectColumns = "id, active_block_id, weekly_rhythm_id, weekly_plan_id, scheduled_date, sequence_order, activity_type, title, duration_minutes, intensity_label, purpose, status, source, fueling_summary"
    static let enrichedSelectColumns = "\(legacySelectColumns), estimated_distance_kilometers, estimated_elevation_meters, planned_location_label, weather_forecast_json"

    let id: UUID
    let activeBlockID: UUID?
    let weeklyRhythmID: UUID?
    let weeklyPlanID: UUID?
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
    let plannedLocationLabel: String?
    let weatherForecast: JSONValue?

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case weeklyRhythmID = "weekly_rhythm_id"
        case weeklyPlanID = "weekly_plan_id"
        case scheduledDate = "scheduled_date"
        case sequenceOrder = "sequence_order"
        case activityType = "activity_type"
        case title
        case durationMinutes = "duration_minutes"
        case estimatedDistanceKilometers = "estimated_distance_kilometers"
        case estimatedElevationMeters = "estimated_elevation_meters"
        case intensityLabel = "intensity_label"
        case purpose
        case status
        case source
        case fuelingSummary = "fueling_summary"
        case plannedLocationLabel = "planned_location_label"
        case weatherForecast = "weather_forecast_json"
    }
}

struct PlanGoalTarget: Decodable, Identifiable {
    static let selectColumns = "id, user_goal_id, fitness_strategy_id, fitness_strategy_phase_id, weekly_plan_id, target_scope, target_kind, title, description, metric_key, metric_category, direction, baseline_value, target_value, unit, start_date, target_date, evaluation_rule_json, source, status, created_at"

    let id: UUID
    let activeGoalID: UUID?
    let activeBlockID: UUID?
    let activePhaseID: UUID?
    let weeklyPlanID: UUID?
    let targetScope: PlanTargetScope?
    let parentGoalTargetID: UUID?
    let targetKind: PlanGoalTargetKind
    let title: String
    let description: String?
    let metricKey: String?
    let metricCategory: String?
    let direction: String
    let baselineValue: Double?
    let targetValue: Double?
    let unit: String?
    let startDate: String
    let targetDate: String?
    let evaluationRule: JSONValue
    let source: String
    let status: PlanGoalStatus

    enum CodingKeys: String, CodingKey {
        case id
        case activeGoalID = "user_goal_id"
        case activeBlockID = "fitness_strategy_id"
        case activePhaseID = "fitness_strategy_phase_id"
        case weeklyPlanID = "weekly_plan_id"
        case targetScope = "target_scope"
        case parentGoalTargetID = "parent_goal_target_id"
        case targetKind = "target_kind"
        case title
        case description
        case metricKey = "metric_key"
        case metricCategory = "metric_category"
        case direction
        case baselineValue = "baseline_value"
        case targetValue = "target_value"
        case unit
        case startDate = "start_date"
        case targetDate = "target_date"
        case evaluationRule = "evaluation_rule_json"
        case source
        case status
    }
}

enum PlanGoalTargetKind: String, Decodable {
    case primary
    case supporting
    case subGoal = "sub_goal"
}

enum PlanTargetScope: String, Decodable {
    case goal
    case strategy
    case phase
    case week
    case session
}

enum PlanGoalStatus: String, Decodable {
    case onTrack = "on_track"
    case lagging
    case achieved
    case notStarted = "not_started"
    case needsReview = "needs_review"

    var displayName: String {
        switch self {
        case .onTrack:
            return "On track"
        case .lagging:
            return "Lagging"
        case .achieved:
            return "Achieved"
        case .notStarted:
            return "Not started"
        case .needsReview:
            return "Needs review"
        }
    }
}

struct PlanGoalEvaluation: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID?
    let goalTargetID: UUID
    let status: PlanGoalStatus
    let currentValue: Double?
    let targetValue: Double?
    let unit: String?
    let progressRatio: Double?
    let evaluatedAt: String
    let evidence: JSONValue
    let message: String
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case goalTargetID = "planning_target_id"
        case status
        case currentValue = "current_value"
        case targetValue = "target_value"
        case unit
        case progressRatio = "progress_ratio"
        case evaluatedAt = "evaluated_at"
        case evidence = "evidence_json"
        case message
        case confidence
    }
}

struct FitnessHistoryInsight: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID?
    let insightKey: String
    let category: String
    let title: String
    let summary: String
    let evidence: JSONValue
    let source: String
    let confidence: String
    let validFrom: String?
    let validUntil: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case insightKey = "insight_key"
        case category
        case title
        case summary
        case evidence = "evidence_json"
        case source
        case confidence
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case updatedAt = "updated_at"
    }
}

struct WorkoutDebriefRequest: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID?
    let plannedWorkoutID: UUID?
    let actualWorkoutID: UUID?
    let status: String
    let promptReason: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case plannedWorkoutID = "planned_workout_id"
        case actualWorkoutID = "actual_workout_id"
        case status
        case promptReason = "prompt_reason"
        case createdAt = "created_at"
    }
}

struct PlanReplanProposal: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID?
    let userGoalID: UUID?
    let fitnessStrategyID: UUID?
    let weeklyPlanID: UUID?
    let triggerEventID: UUID?
    let reason: String
    let proposedMutations: JSONValue
    let metadata: JSONValue?
    let status: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case userGoalID = "user_goal_id"
        case fitnessStrategyID = "fitness_strategy_id"
        case weeklyPlanID = "weekly_plan_id"
        case triggerEventID = "trigger_event_id"
        case reason
        case proposedMutations = "proposed_mutations_json"
        case metadata = "metadata_json"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var mutationCount: Int {
        if case let .array(values) = proposedMutations {
            return values.count
        }

        return 0
    }
}

struct PlanPendingReview: Equatable {
    let editCount: Int
}

enum PlanWorkoutStatus: String, Decodable {
    case planned
    case current
    case checkedIn = "checked_in"
    case adjusted
    case done
    case missed
    case deleted
    case superseded

    var displayName: String {
        switch self {
        case .planned:
            return "Open"
        case .current:
            return "Current"
        case .checkedIn:
            return "Checked in"
        case .adjusted:
            return "Adjusted"
        case .done:
            return "Done"
        case .missed:
            return "Missed"
        case .deleted:
            return "Deleted"
        case .superseded:
            return "Superseded"
        }
    }
}

private extension PostgrestError {
    var isMissingWorkoutCardColumn: Bool {
        let text = "\(code ?? "") \(message) \(hint ?? "") \(localizedDescription) \(String(describing: self))"
            .lowercased()
        return text.contains("estimated_distance_kilometers")
            || text.contains("estimated_elevation_meters")
            || text.contains("planned_location_label")
            || text.contains("weather_forecast_json")
    }
}
