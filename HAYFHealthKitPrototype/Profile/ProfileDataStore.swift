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
