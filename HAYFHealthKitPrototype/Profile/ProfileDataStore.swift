import Foundation
import Supabase

@MainActor
final class ProfileDataStore: ObservableObject {
    @Published private(set) var activeBlock: PlanActiveFitnessBlock?
    @Published private(set) var goalTargets: [PlanGoalTarget] = []
    @Published private(set) var goalEvaluations: [PlanGoalEvaluation] = []
    @Published private(set) var historyInsights: [FitnessHistoryInsight] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = SupabaseClientProvider.shared) {
        self.supabase = supabase
    }

    func loadProfileContext() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let block = try await fetchActiveBlock() else {
                activeBlock = nil
                goalTargets = []
                goalEvaluations = []
                historyInsights = []
                return
            }

            async let targets = fetchGoalTargets(for: block.id)
            async let evaluations = fetchGoalEvaluations(for: block.id)
            async let insights = fetchHistoryInsights()

            activeBlock = block
            goalTargets = try await targets
            goalEvaluations = try await evaluations
            historyInsights = try await insights
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchActiveBlock() async throws -> PlanActiveFitnessBlock? {
        do {
            let strategy: ProfileRawFitnessStrategy = try await supabase
                .from("fitness_strategies")
                .select("id, user_goal_id, status, title, summary, rationale, review_cadence_days, start_date, target_date, context_json")
                .eq("status", value: "active")
                .single()
                .execute()
                .value

            let goal: ProfileRawUserGoal = try await supabase
                .from("user_goals")
                .select("id, goal_kind, title, target_date")
                .eq("id", value: strategy.userGoalID.uuidString.lowercased())
                .single()
                .execute()
                .value

            let timezone = strategy.context.timezone ?? TimeZone.current.identifier
            return PlanActiveFitnessBlock(
                id: strategy.id,
                kind: goal.goalKind,
                title: strategy.title,
                goalText: goal.title,
                status: strategy.status,
                startDate: strategy.startDate,
                targetDate: strategy.targetDate ?? goal.targetDate,
                reviewCadenceDays: strategy.reviewCadenceDays,
                timezone: timezone,
                context: PlanBlockContext(
                    onboardingIntent: goal.goalKind,
                    planningRationale: strategy.rationale.profileNilIfEmpty ?? strategy.summary.profileNilIfEmpty,
                    dataFreshness: nil,
                    timezone: timezone,
                    acceptedAt: strategy.context.acceptedAt,
                    planOwnerStartDate: strategy.context.planOwnerStartDate
                )
            )
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    private func fetchGoalTargets(for strategyID: UUID) async throws -> [PlanGoalTarget] {
        try await supabase
            .from("planning_targets")
            .select("id, fitness_strategy_id, target_kind, title, description, metric_key, metric_category, direction, baseline_value, target_value, unit, start_date, target_date, evaluation_rule_json, source, status, created_at")
            .eq("fitness_strategy_id", value: strategyID.uuidString.lowercased())
            .order("target_kind", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
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

    private func fetchHistoryInsights() async throws -> [FitnessHistoryInsight] {
        try await supabase
            .from("fitness_history_insights")
            .select("id, active_block_id, insight_key, category, title, summary, evidence_json, source, confidence, valid_from, valid_until, updated_at")
            .order("updated_at", ascending: false)
            .limit(12)
            .execute()
            .value
    }
}

private struct ProfileRawFitnessStrategy: Decodable {
    let id: UUID
    let userGoalID: UUID
    let status: String
    let title: String
    let summary: String
    let rationale: String
    let reviewCadenceDays: Int
    let startDate: String
    let targetDate: String?
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
        case context = "context_json"
    }
}

private struct ProfileRawUserGoal: Decodable {
    let id: UUID
    let goalKind: String
    let title: String
    let targetDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case goalKind = "goal_kind"
        case title
        case targetDate = "target_date"
    }
}

private extension String {
    var profileNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
