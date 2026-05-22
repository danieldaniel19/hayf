import Foundation
import Supabase

@MainActor
final class ProfileDataStore: ObservableObject {
    @Published private(set) var activeBlock: PlanActiveFitnessBlock?
    @Published private(set) var phases: [PlanFitnessBlockPhase] = []
    @Published private(set) var goalTargets: [PlanGoalTarget] = []
    @Published private(set) var goalEvaluations: [PlanGoalEvaluation] = []
    @Published private(set) var athleteBlueprint: ProfileAthleteBlueprint?
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
            guard let context = try await fetchActiveProfileContext() else {
                activeBlock = nil
                phases = []
                goalTargets = []
                goalEvaluations = []
                athleteBlueprint = nil
                return
            }

            async let phasesLoad = fetchPhases(for: context.block.id)
            async let goalTargetsLoad = fetchGoalTargets(for: context.userGoalID)
            async let strategyTargetsLoad = fetchStrategyTargets(for: context.block.id)
            async let blueprintLoad = fetchBlueprintRevision(sourceID: context.sourceBlueprintRevisionID)

            let loadedPhases = try await phasesLoad
            let loadedGoalTargets = try await goalTargetsLoad
            let loadedStrategyTargets = try await strategyTargetsLoad
            let loadedPhaseTargets = try await fetchPhaseTargets(for: loadedPhases.map(\.id))
            let loadedTargets = loadedGoalTargets + loadedStrategyTargets + loadedPhaseTargets
            let loadedBlueprint = try await blueprintLoad

            activeBlock = context.block
            phases = loadedPhases
            goalTargets = loadedTargets
            goalEvaluations = try await fetchLatestEvaluations(for: loadedTargets.map(\.id))
            athleteBlueprint = loadedBlueprint.map(ProfileAthleteBlueprint.init(raw:))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchActiveProfileContext() async throws -> ProfileActiveContext? {
        do {
            let strategy: ProfileRawFitnessStrategy = try await supabase
                .from("fitness_strategies")
                .select("id, user_goal_id, source_blueprint_revision_id, status, title, summary, rationale, review_cadence_days, start_date, target_date, requires_phases, context_json")
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
            let block = PlanActiveFitnessBlock(
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
                    planOwnerStartDate: strategy.context.planOwnerStartDate,
                    acceptedStrategy: strategy.context.acceptedStrategy
                )
            )

            return ProfileActiveContext(
                block: block,
                userGoalID: strategy.userGoalID,
                sourceBlueprintRevisionID: strategy.sourceBlueprintRevisionID
            )
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    private func fetchPhases(for strategyID: UUID) async throws -> [PlanFitnessBlockPhase] {
        try await supabase
            .from("fitness_strategy_phases")
            .select("id, fitness_strategy_id, name, start_date, end_date, objective, focus_json, risk_json")
            .eq("fitness_strategy_id", value: strategyID.uuidString.lowercased())
            .order("start_date", ascending: true)
            .execute()
            .value
    }

    private func fetchGoalTargets(for goalID: UUID) async throws -> [PlanGoalTarget] {
        try await supabase
            .from("planning_targets")
            .select(PlanGoalTarget.selectColumns)
            .eq("user_goal_id", value: goalID.uuidString.lowercased())
            .order("target_kind", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
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

    private func fetchPhaseTargets(for phaseIDs: [UUID]) async throws -> [PlanGoalTarget] {
        var targets: [PlanGoalTarget] = []
        for phaseID in phaseIDs {
            let phaseTargets: [PlanGoalTarget] = try await supabase
                .from("planning_targets")
                .select(PlanGoalTarget.selectColumns)
                .eq("fitness_strategy_phase_id", value: phaseID.uuidString.lowercased())
                .order("target_kind", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value
            targets.append(contentsOf: phaseTargets)
        }
        return targets
    }

    private func fetchLatestEvaluations(for targetIDs: [UUID]) async throws -> [PlanGoalEvaluation] {
        var evaluations: [PlanGoalEvaluation] = []
        for targetID in targetIDs {
            let rows: [PlanGoalEvaluation] = try await supabase
                .from("planning_target_evaluations")
                .select("id, planning_target_id, status, current_value, target_value, unit, progress_ratio, evaluated_at, evidence_json, message, confidence")
                .eq("planning_target_id", value: targetID.uuidString.lowercased())
                .order("evaluated_at", ascending: false)
                .limit(1)
                .execute()
                .value
            evaluations.append(contentsOf: rows)
        }
        return evaluations
    }

    private func fetchBlueprintRevision(sourceID: UUID?) async throws -> ProfileRawBlueprintRevision? {
        if let sourceID, let revision = try await fetchBlueprintRevision(id: sourceID) {
            return revision
        }

        guard let currentID = try await fetchCurrentBlueprintRevisionID() else {
            return nil
        }

        return try await fetchBlueprintRevision(id: currentID)
    }

    private func fetchBlueprintRevision(id: UUID) async throws -> ProfileRawBlueprintRevision? {
        do {
            return try await supabase
                .from("athlete_blueprint_revisions")
                .select("id, revision_number, generation_reason, coach_read, athlete_archetype_json, current_training_state_json, history_findings_json, goal_fit_json, planning_inputs_json, generated_at, accepted_at")
                .eq("id", value: id.uuidString.lowercased())
                .single()
                .execute()
                .value
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    private func fetchCurrentBlueprintRevisionID() async throws -> UUID? {
        do {
            let profile: ProfileRawAthleteProfile = try await supabase
                .from("athlete_profiles")
                .select("current_blueprint_revision_id")
                .single()
                .execute()
                .value
            return profile.currentBlueprintRevisionID
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }
}

struct ProfileAthleteBlueprint: Identifiable {
    let id: UUID
    let revisionNumber: Int
    let generatedAt: String
    let coachRead: ProfileBlueprintSection
    let archetype: ProfileBlueprintSection
    let currentTrainingState: ProfileBlueprintSection
    let physicalBaseline: ProfileBlueprintSection?
    let historyFindings: [ProfileBlueprintSection]
    let goalFit: ProfileBlueprintSection

    init(raw: ProfileRawBlueprintRevision) {
        let acceptedBlueprint = raw.planningInputs.profileValue("acceptedBlueprint")
        let coachReadObject = acceptedBlueprint.profileValue("coachRead")
        let archetypeObject = acceptedBlueprint.profileValue("archetype").profileIsEmpty ? raw.athleteArchetype : acceptedBlueprint.profileValue("archetype")
        let currentStateObject = acceptedBlueprint.profileValue("currentTrainingState").profileIsEmpty ? raw.currentTrainingState : acceptedBlueprint.profileValue("currentTrainingState")
        let physicalBaselineObject = acceptedBlueprint.profileValue("physicalBaseline")
        let goalFitObject = acceptedBlueprint.profileValue("goalFit").profileIsEmpty ? raw.goalFit : acceptedBlueprint.profileValue("goalFit")
        let historyObjects = acceptedBlueprint.profileArray("historyFindings").isEmpty
            ? raw.historyFindings.profileArrayValue
            : acceptedBlueprint.profileArray("historyFindings")

        id = raw.id
        revisionNumber = raw.revisionNumber
        generatedAt = raw.generatedAt
        coachRead = ProfileBlueprintSection(
            id: "coach_read",
            fallbackTitle: "Coach read",
            fallbackSummary: raw.coachRead,
            json: coachReadObject
        )
        archetype = ProfileBlueprintSection(
            id: "athlete_archetype",
            fallbackTitle: "Athlete type",
            fallbackSummary: archetypeObject.profileString("explanation"),
            json: archetypeObject
        )
        currentTrainingState = ProfileBlueprintSection(
            id: "current_training_state",
            fallbackTitle: "Current state",
            fallbackSummary: currentStateObject.profileString("summary"),
            json: currentStateObject
        )
        physicalBaseline = physicalBaselineObject.profileIsEmpty
            ? nil
            : ProfileBlueprintSection(
                id: "physical_baseline",
                fallbackTitle: "Physical baseline",
                fallbackSummary: physicalBaselineObject.profileString("summary"),
                json: physicalBaselineObject
            )
        historyFindings = historyObjects.enumerated().map { index, item in
            ProfileBlueprintSection(
                id: item.profileString("id").profileNilIfEmpty ?? "history_\(index)",
                fallbackTitle: item.profileString("title").profileNilIfEmpty ?? "History finding",
                fallbackSummary: item.profileString("summary"),
                json: item
            )
        }
        goalFit = ProfileBlueprintSection(
            id: "goal_fit",
            fallbackTitle: "Goal fit",
            fallbackSummary: goalFitObject.profileString("summary"),
            json: goalFitObject
        )
    }

    var previewSections: [ProfileBlueprintSection] {
        [archetype, currentTrainingState, goalFit].filter { !$0.summary.isEmpty }
    }

    var detailSections: [ProfileBlueprintSection] {
        [coachRead, archetype, currentTrainingState] +
        [physicalBaseline].compactMap { $0 } +
        historyFindings +
        [goalFit]
    }
}

struct ProfileBlueprintSection: Identifiable {
    let id: String
    let title: String
    let summary: String
    let body: String?
    let confidence: String?
    let observationWindow: String?
    let evidence: [String]
    let caveat: String?

    init(id: String, fallbackTitle: String, fallbackSummary: String, json: JSONValue) {
        let detail = json.profileValue("detail")
        let title = detail.profileString("title").profileNilIfEmpty ??
            json.profileString("title").profileNilIfEmpty ??
            json.profileString("label").profileNilIfEmpty ??
            json.profileString("headline").profileNilIfEmpty ??
            fallbackTitle
        let summary = detail.profileString("summary").profileNilIfEmpty ??
            json.profileString("summary").profileNilIfEmpty ??
            json.profileString("explanation").profileNilIfEmpty ??
            json.profileString("text").profileNilIfEmpty ??
            fallbackSummary
        let supports = json.profileArray("supports").compactMap(\.profileStringValue)
        let gaps = json.profileArray("gaps").compactMap(\.profileStringValue)

        self.id = id
        self.title = title
        self.summary = summary
        body = detail.profileString("body").profileNilIfEmpty ?? json.profileString("text").profileNilIfEmpty
        confidence = detail.profileString("confidence").profileNilIfEmpty ?? json.profileString("confidence").profileNilIfEmpty
        observationWindow = detail.profileString("observationWindow").profileNilIfEmpty
        evidence = detail.profileArray("evidence").compactMap(\.profileStringValue) + supports + gaps
        caveat = detail.profileString("caveat").profileNilIfEmpty
    }
}

private struct ProfileActiveContext {
    let block: PlanActiveFitnessBlock
    let userGoalID: UUID
    let sourceBlueprintRevisionID: UUID?
}

private struct ProfileRawFitnessStrategy: Decodable {
    let id: UUID
    let userGoalID: UUID
    let sourceBlueprintRevisionID: UUID?
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
        case sourceBlueprintRevisionID = "source_blueprint_revision_id"
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

private struct ProfileRawAthleteProfile: Decodable {
    let currentBlueprintRevisionID: UUID?

    enum CodingKeys: String, CodingKey {
        case currentBlueprintRevisionID = "current_blueprint_revision_id"
    }
}

struct ProfileRawBlueprintRevision: Decodable {
    let id: UUID
    let revisionNumber: Int
    let generationReason: String
    let coachRead: String
    let athleteArchetype: JSONValue
    let currentTrainingState: JSONValue
    let historyFindings: JSONValue
    let goalFit: JSONValue
    let planningInputs: JSONValue
    let generatedAt: String
    let acceptedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case revisionNumber = "revision_number"
        case generationReason = "generation_reason"
        case coachRead = "coach_read"
        case athleteArchetype = "athlete_archetype_json"
        case currentTrainingState = "current_training_state_json"
        case historyFindings = "history_findings_json"
        case goalFit = "goal_fit_json"
        case planningInputs = "planning_inputs_json"
        case generatedAt = "generated_at"
        case acceptedAt = "accepted_at"
    }
}

extension JSONValue {
    var profileStringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    var profileArrayValue: [JSONValue] {
        if case let .array(value) = self {
            return value
        }
        return []
    }

    var profileObjectValue: [String: JSONValue] {
        if case let .object(value) = self {
            return value
        }
        return [:]
    }

    var profileIsEmpty: Bool {
        switch self {
        case .null:
            return true
        case let .object(value):
            return value.isEmpty
        case let .array(value):
            return value.isEmpty
        case let .string(value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    func profileValue(_ key: String) -> JSONValue {
        profileObjectValue[key] ?? .null
    }

    func profileString(_ key: String) -> String {
        profileValue(key).profileStringValue ?? ""
    }

    func profileArray(_ key: String) -> [JSONValue] {
        profileValue(key).profileArrayValue
    }
}

extension String {
    var profileNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
