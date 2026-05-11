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
                return
            }

            async let phases = fetchPhases(for: block.id)
            async let weeklyRhythms = fetchWeeklyRhythms(for: block.id)
            async let workouts = fetchWorkouts(for: block.id)
            async let goalTargets = fetchGoalTargets(for: block.id)
            async let goalEvaluations = fetchGoalEvaluations(for: block.id)
            async let historyInsights = fetchHistoryInsights(for: block.id)
            async let debriefRequests = fetchDebriefRequests(for: block.id)
            async let pendingReplanProposals = fetchPendingReplanProposals(for: block.id)

            activeBlock = block
            self.phases = try await phases
            self.weeklyRhythms = try await weeklyRhythms
            self.workouts = try await workouts
            self.goalTargets = try await goalTargets
            self.goalEvaluations = try await goalEvaluations
            self.historyInsights = try await historyInsights
            self.debriefRequests = try await debriefRequests
            self.pendingReplanProposals = try await pendingReplanProposals
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchActiveBlock() async throws -> PlanActiveFitnessBlock? {
        do {
            let block: PlanActiveFitnessBlock = try await supabase
                .from("active_fitness_blocks")
                .select("id, kind, title, goal_text, status, start_date, target_date, review_cadence_days, timezone, context_json")
                .eq("status", value: "active")
                .single()
                .execute()
                .value

            return block
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    private func fetchPhases(for blockID: UUID) async throws -> [PlanFitnessBlockPhase] {
        try await supabase
            .from("fitness_block_phases")
            .select("id, active_block_id, name, start_date, end_date, objective, focus_json, risk_json")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .order("start_date", ascending: true)
            .execute()
            .value
    }

    private func fetchWeeklyRhythms(for blockID: UUID) async throws -> [PlanWeeklyRhythm] {
        let window = visibleWindow()

        return try await supabase
            .from("weekly_rhythms")
            .select("id, active_block_id, week_start_date, week_end_date, objective, bad_day_floor, status")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .eq("status", value: "active")
            .gte("week_start_date", value: PlanCalendar.dateFormatter.string(from: window.start))
            .lte("week_start_date", value: PlanCalendar.dateFormatter.string(from: window.end))
            .order("week_start_date", ascending: true)
            .execute()
            .value
    }

    private func fetchWorkouts(for blockID: UUID) async throws -> [PlanWorkout] {
        let window = visibleWindow()

        return try await supabase
            .from("planned_workouts")
            .select("id, active_block_id, weekly_rhythm_id, scheduled_date, sequence_order, activity_type, title, duration_minutes, intensity_label, purpose, status, source, fueling_summary")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .gte("scheduled_date", value: PlanCalendar.dateFormatter.string(from: window.start))
            .lte("scheduled_date", value: PlanCalendar.dateFormatter.string(from: window.end))
            .not("status", operator: .in, value: "(deleted,superseded)")
            .order("scheduled_date", ascending: true)
            .order("sequence_order", ascending: true)
            .execute()
            .value
    }

    private func fetchGoalTargets(for blockID: UUID) async throws -> [PlanGoalTarget] {
        try await supabase
            .from("fitness_goal_targets")
            .select("id, active_block_id, parent_goal_target_id, target_kind, title, description, metric_key, metric_category, direction, baseline_value, target_value, unit, start_date, target_date, evaluation_rule_json, source, status")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .order("target_kind", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    private func fetchGoalEvaluations(for blockID: UUID) async throws -> [PlanGoalEvaluation] {
        try await supabase
            .from("fitness_goal_evaluations")
            .select("id, active_block_id, goal_target_id, status, current_value, target_value, unit, progress_ratio, evaluated_at, evidence_json, message, confidence")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .order("evaluated_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    private func fetchHistoryInsights(for blockID: UUID) async throws -> [FitnessHistoryInsight] {
        try await supabase
            .from("fitness_history_insights")
            .select("id, active_block_id, insight_key, category, title, summary, evidence_json, source, confidence, valid_from, valid_until, updated_at")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .order("updated_at", ascending: false)
            .limit(12)
            .execute()
            .value
    }

    private func fetchDebriefRequests(for blockID: UUID) async throws -> [WorkoutDebriefRequest] {
        try await supabase
            .from("workout_debrief_requests")
            .select("id, active_block_id, planned_workout_id, actual_workout_id, status, prompt_reason, created_at")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .eq("status", value: "needed")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func fetchPendingReplanProposals(for blockID: UUID) async throws -> [PlanReplanProposal] {
        let proposals: [PlanReplanProposal] = try await supabase
            .from("replan_proposals")
            .select("id, active_block_id, trigger_event_id, reason, proposed_mutations_json, status, created_at, updated_at")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value

        return Array(proposals.filter { $0.mutationCount > 0 }.prefix(1))
    }

    private func visibleWindow() -> DateInterval {
        let now = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? now
        let nextWeekEnd = calendar.date(byAdding: .day, value: 6, to: nextWeekStart) ?? nextWeekStart
        return DateInterval(start: currentWeekStart, end: nextWeekEnd)
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
}

struct PlanActiveFitnessBlock: Decodable, Identifiable {
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

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case goalText = "goal_text"
        case status
        case startDate = "start_date"
        case targetDate = "target_date"
        case reviewCadenceDays = "review_cadence_days"
        case timezone
        case context = "context_json"
    }
}

struct PlanBlockContext: Decodable {
    let onboardingIntent: String?
    let planningRationale: String?
    let dataFreshness: String?
    let timezone: String?
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
        case activeBlockID = "active_block_id"
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

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case weekStartDate = "week_start_date"
        case weekEndDate = "week_end_date"
        case objective
        case badDayFloor = "bad_day_floor"
        case status
    }
}

struct PlanWorkout: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID
    let weeklyRhythmID: UUID?
    let scheduledDate: String
    let sequenceOrder: Int
    let activityType: String
    let title: String
    let durationMinutes: Int
    let intensityLabel: String
    let purpose: String
    let status: PlanWorkoutStatus
    let source: String
    let fuelingSummary: String?

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case weeklyRhythmID = "weekly_rhythm_id"
        case scheduledDate = "scheduled_date"
        case sequenceOrder = "sequence_order"
        case activityType = "activity_type"
        case title
        case durationMinutes = "duration_minutes"
        case intensityLabel = "intensity_label"
        case purpose
        case status
        case source
        case fuelingSummary = "fueling_summary"
    }
}

struct PlanGoalTarget: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID
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
        case activeBlockID = "active_block_id"
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
    case subGoal = "sub_goal"
}

enum PlanGoalStatus: String, Decodable {
    case onTrack = "on_track"
    case lagging
    case achieved
    case needsReview = "needs_review"

    var displayName: String {
        switch self {
        case .onTrack:
            return "On track"
        case .lagging:
            return "Lagging"
        case .achieved:
            return "Achieved"
        case .needsReview:
            return "Needs review"
        }
    }
}

struct PlanGoalEvaluation: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID
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
        case goalTargetID = "goal_target_id"
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
    let triggerEventID: UUID?
    let reason: String
    let proposedMutations: JSONValue
    let status: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case triggerEventID = "trigger_event_id"
        case reason
        case proposedMutations = "proposed_mutations_json"
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
