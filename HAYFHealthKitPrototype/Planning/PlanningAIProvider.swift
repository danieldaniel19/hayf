import Foundation
import Supabase

private actor PlanningRefreshCoordinator {
    static let shared = PlanningRefreshCoordinator()

    private var isRefreshing = false

    func begin() -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        return true
    }

    func finish() {
        isRefreshing = false
    }
}

struct PlanningAIProvider {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = SupabaseClientProvider.shared) {
        self.supabase = supabase
    }

    @available(*, unavailable, message: "Use prepareInitialStrategyAfterBlueprint followed by acceptPreparedStrategyAndCreateInitialPlan.")
    func acceptStrategyAndCreateInitialPlan(
        healthSnapshot: HealthFeatureSnapshot?,
        actualWorkouts: [HealthActualWorkoutSummary] = [],
        acceptedBlueprint: JSONValue,
        acceptedStrategy: JSONValue,
        deviceTimezone: String = TimeZone.current.identifier,
        acceptedAt: Date = Date()
    ) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .acceptStrategyAndCreateInitialPlan,
                healthSnapshot: healthSnapshot,
                actualWorkouts: actualWorkouts,
                deviceTimezone: deviceTimezone,
                acceptedBlueprint: acceptedBlueprint,
                acceptedStrategy: acceptedStrategy,
                acceptedAt: Self.isoDateTimeFormatter.string(from: acceptedAt)
            )
        )
    }

    func prepareInitialStrategyAfterBlueprint(
        healthSnapshot: HealthFeatureSnapshot?,
        acceptedBlueprint: JSONValue,
        onboardingContext: JSONValue,
        deviceTimezone: String = TimeZone.current.identifier,
        acceptedAt: Date = Date()
    ) async throws -> PlanningPreparedStrategyOutput {
        let response: PlanningPreparedStrategyFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .prepareInitialStrategyAfterBlueprint,
                healthSnapshot: healthSnapshot,
                deviceTimezone: deviceTimezone,
                acceptedBlueprint: acceptedBlueprint,
                onboardingContext: onboardingContext,
                acceptedAt: Self.isoDateTimeFormatter.string(from: acceptedAt)
            )
        )

        return response.output
    }

    func startPrepareInitialStrategyAfterBlueprint(
        healthSnapshot: HealthFeatureSnapshot?,
        acceptedBlueprint: JSONValue,
        onboardingContext: JSONValue,
        deviceTimezone: String = TimeZone.current.identifier,
        acceptedAt: Date = Date()
    ) async throws -> PlanningStartedStrategyOutput {
        let response: PlanningStartedStrategyFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .startPrepareInitialStrategyAfterBlueprint,
                healthSnapshot: healthSnapshot,
                deviceTimezone: deviceTimezone,
                acceptedBlueprint: acceptedBlueprint,
                onboardingContext: onboardingContext,
                acceptedAt: Self.isoDateTimeFormatter.string(from: acceptedAt)
            )
        )

        return response.output
    }

    func prepareInitialStrategyAfterBlueprintAsync(
        healthSnapshot: HealthFeatureSnapshot?,
        acceptedBlueprint: JSONValue,
        onboardingContext: JSONValue,
        deviceTimezone: String = TimeZone.current.identifier,
        acceptedAt: Date = Date()
    ) async throws -> PlanningPreparedStrategyOutput {
        let started = try await startPrepareInitialStrategyAfterBlueprint(
            healthSnapshot: healthSnapshot,
            acceptedBlueprint: acceptedBlueprint,
            onboardingContext: onboardingContext,
            deviceTimezone: deviceTimezone,
            acceptedAt: acceptedAt
        )

        return try await waitForPreparedStrategy(graphRunID: started.graphRunID)
    }

    func acceptPreparedStrategyAndCreateInitialPlan(
        preparedStrategyID: UUID,
        healthSnapshot: HealthFeatureSnapshot?,
        actualWorkouts: [HealthActualWorkoutSummary] = [],
        deviceTimezone: String = TimeZone.current.identifier,
        acceptedAt: Date = Date()
    ) async throws {
        if await preparedStrategyIsReady(preparedStrategyID) {
            return
        }

        let acceptanceStartedAt = Date()
        let _: PlanningStartedPlanFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .startAcceptPreparedStrategyAndCreateInitialPlan,
                healthSnapshot: healthSnapshot,
                actualWorkouts: actualWorkouts,
                deviceTimezone: deviceTimezone,
                preparedStrategyID: preparedStrategyID,
                acceptedAt: Self.isoDateTimeFormatter.string(from: acceptedAt)
            )
        )

        try await waitForPreparedStrategyActivation(
            preparedStrategyID,
            startedAt: acceptanceStartedAt.addingTimeInterval(-2)
        )
    }

    func preparedStrategyIsActive(_ preparedStrategyID: UUID) async -> Bool {
        do {
            let row: PlanningStrategyStatusRow = try await supabase
                .from("fitness_strategies")
                .select("id, status")
                .eq("id", value: preparedStrategyID.uuidString.lowercased())
                .single()
                .execute()
                .value
            return row.status == "active"
        } catch {
            return false
        }
    }

    private func preparedStrategyIsReady(_ preparedStrategyID: UUID) async -> Bool {
        guard await preparedStrategyIsActive(preparedStrategyID) else { return false }

        do {
            let rows: [PlanningWeeklyPlanStatusRow] = try await supabase
                .from("weekly_plans")
                .select("id, status")
                .eq("fitness_strategy_id", value: preparedStrategyID.uuidString.lowercased())
                .execute()
                .value
            return rows.contains { $0.status == "committed" || $0.status == "draft" }
        } catch {
            return false
        }
    }

    private func waitForPreparedStrategyActivation(
        _ preparedStrategyID: UUID,
        startedAt: Date
    ) async throws {
        let deadline = Date().addingTimeInterval(360)
        while Date() < deadline {
            try Task.checkCancellation()
            if await preparedStrategyIsReady(preparedStrategyID) {
                return
            }
            if let run = await latestInitialPlanRun(for: preparedStrategyID, startedAt: startedAt),
               run.status == "failed" || run.status == "cancelled" {
                throw PlanningGraphRunError.failed(
                    run.errorSummary ?? "Initial plan generation failed."
                )
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        throw PlanningGraphRunError.timedOut
    }

    private func latestInitialPlanRun(
        for preparedStrategyID: UUID,
        startedAt: Date
    ) async -> PlanningInitialPlanRunRow? {
        do {
            let rows: [PlanningInitialPlanRunRow] = try await supabase
                .from("ai_graph_runs")
                .select("status, error_summary")
                .eq("graph_name", value: "two_week_plan")
                .eq("source_fitness_strategy_id", value: preparedStrategyID.uuidString.lowercased())
                .gte("created_at", value: Self.isoDateTimeFormatter.string(from: startedAt))
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            return nil
        }
    }

    func planningGraphRunStatus(graphRunID: UUID) async throws -> PlanningGraphRunStatusOutput {
        let response: PlanningGraphRunStatusFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .getPlanningGraphRunStatus,
                graphRunID: graphRunID
            )
        )

        return response.output
    }

    func waitForPreparedStrategy(graphRunID: UUID) async throws -> PlanningPreparedStrategyOutput {
        let deadline = Date().addingTimeInterval(300)
        var pollDelay: UInt64 = 1_500_000_000

        while Date() < deadline {
            let status = try await planningGraphRunStatus(graphRunID: graphRunID)
            if status.status == "succeeded" {
                guard
                    let userGoalID = status.userGoalID,
                    let fitnessStrategyID = status.fitnessStrategyID,
                    let blueprintRevisionID = status.blueprintRevisionID,
                    let trainingArchitectureID = status.trainingArchitectureID,
                    let strategy = status.strategy,
                    let trainingArchitecture = status.trainingArchitecture
                else {
                    throw PlanningGraphRunError.missingPreparedStrategy
                }

                return PlanningPreparedStrategyOutput(
                    status: "completed",
                    graphRunID: status.graphRunID,
                    userGoalID: userGoalID,
                    fitnessStrategyID: fitnessStrategyID,
                    blueprintRevisionID: blueprintRevisionID,
                    trainingArchitectureID: trainingArchitectureID,
                    eventID: status.eventID,
                    strategy: strategy,
                    trainingArchitecture: trainingArchitecture
                )
            }

            if status.status == "failed" || status.status == "cancelled" {
                throw PlanningGraphRunError.failed(status.errorSummary ?? "Planning graph run failed.")
            }

            try await Task.sleep(nanoseconds: pollDelay)
            pollDelay = min(pollDelay + 500_000_000, 5_000_000_000)
        }

        throw PlanningGraphRunError.timedOut
    }

    func syncHealthKitAndReconcile(
        payload: PlanningHealthSyncPayload,
        deviceTimezone: String = TimeZone.current.identifier
    ) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .syncHealthKitAndReconcile,
                healthSnapshot: payload.healthSnapshot,
                actualWorkouts: payload.actualWorkouts,
                syncWindow: payload.syncWindow,
                deviceTimezone: deviceTimezone
            )
        )
    }

    func refreshPlanWindow(windowStart: Date? = nil) async throws -> PlanningFunctionResponse {
        guard await PlanningRefreshCoordinator.shared.begin() else {
            throw CancellationError()
        }
        do {
            let response = try await invoke(
                PlanningFunctionRequest(
                    task: .refreshPlanWindow,
                    deviceTimezone: TimeZone.current.identifier,
                    windowStart: windowStart.map(Self.dateOnlyFormatter.string(from:))
                )
            )
            await PlanningRefreshCoordinator.shared.finish()
            return response
        } catch {
            await PlanningRefreshCoordinator.shared.finish()
            throw error
        }
    }

    func refreshWorkoutWeatherForecasts(windowStart: Date? = nil) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .refreshWorkoutWeatherForecasts,
                deviceTimezone: TimeZone.current.identifier,
                windowStart: windowStart.map(Self.dateOnlyFormatter.string(from:))
            )
        )
    }

    func generateWeeklyPlanTargets(windowStart: Date? = nil) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .generateWeeklyPlanTargets,
                deviceTimezone: TimeZone.current.identifier,
                windowStart: windowStart.map(Self.dateOnlyFormatter.string(from:))
            )
        )
    }

    func recordPlanEdit(
        _ edit: PlanningPlanEdit,
        repairPolicy: PlanningRepairPolicy = .immediate
    ) async throws -> PlanningEditOutcome {
        let response: PlanningEditOutcomeFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .recordPlanEdit,
                deviceTimezone: TimeZone.current.identifier,
                edit: edit,
                repairPolicy: repairPolicy
            )
        )

        return response.output
    }

    func recommendWorkoutReplacements(
        plannedWorkoutID: UUID,
        textContext: String? = nil
    ) async throws -> PlanningReplacementOutput {
        let response: PlanningReplacementFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .recommendWorkoutReplacements,
                plannedWorkoutID: plannedWorkoutID,
                textContext: textContext
            )
        )

        return response.output
    }

    func recommendWorkoutAdditions(
        scheduledDate: Date,
        textContext: String? = nil
    ) async throws -> PlanningWorkoutAdditionOutput {
        let response: PlanningWorkoutAdditionFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .recommendWorkoutAdditions,
                scheduledDate: Self.dateOnlyFormatter.string(from: scheduledDate),
                textContext: textContext
            )
        )

        return response.output
    }

    func interpretWorkoutDescription(
        textContext: String,
        plannedWorkoutID: UUID? = nil,
        scheduledDate: Date? = nil
    ) async throws -> PlanningWorkoutInterpretationOutput {
        let response: PlanningWorkoutInterpretationFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .interpretWorkoutDescription,
                plannedWorkoutID: plannedWorkoutID,
                scheduledDate: scheduledDate.map(Self.dateOnlyFormatter.string(from:)),
                textContext: textContext
            )
        )

        return response.output
    }

    func replaceWorkout(
        plannedWorkoutID: UUID,
        candidate: PlanningWorkoutCandidate,
        repairPolicy: PlanningRepairPolicy = .immediate
    ) async throws -> PlanningEditOutcome {
        let response: PlanningEditOutcomeFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .replaceWorkout,
                deviceTimezone: TimeZone.current.identifier,
                plannedWorkoutID: plannedWorkoutID,
                replacementCandidate: candidate,
                repairPolicy: repairPolicy
            )
        )

        return response.output
    }

    func addWorkout(
        scheduledDate: Date,
        sequenceOrder: Int?,
        candidate: PlanningWorkoutCandidate,
        repairPolicy: PlanningRepairPolicy = .immediate
    ) async throws -> PlanningEditOutcome {
        let response: PlanningEditOutcomeFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .addWorkout,
                deviceTimezone: TimeZone.current.identifier,
                scheduledDate: Self.dateOnlyFormatter.string(from: scheduledDate),
                sequenceOrder: sequenceOrder,
                workoutCandidate: candidate,
                repairPolicy: repairPolicy
            )
        )

        return response.output
    }

    func createRepairProposal(for eventID: UUID) async throws -> PlanningEditOutcome {
        let response: PlanningEditOutcomeFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .createRepairProposalForRecentEdit,
                eventID: eventID,
                repairPolicy: .immediate
            )
        )

        return response.output
    }

    func createRepairProposalForPendingEdits(windowStart: Date? = nil) async throws -> PlanningEditOutcome {
        let response: PlanningEditOutcomeFunctionResponse = try await invokeTyped(
            PlanningFunctionRequest(
                task: .createRepairProposalForPendingEdits,
                deviceTimezone: TimeZone.current.identifier,
                windowStart: windowStart.map(Self.dateOnlyFormatter.string(from:))
            )
        )

        return response.output
    }

    func recordWeeklyPlanConstraint(
        weeklyPlanID: UUID,
        scheduledDate: Date,
        kind: PlanningWeeklyPlanConstraintKind,
        note: String?
    ) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .recordWeeklyPlanConstraint,
                weeklyPlanConstraint: PlanningWeeklyPlanConstraintInput(
                    weeklyPlanID: weeklyPlanID,
                    scheduledDate: Self.dateOnlyFormatter.string(from: scheduledDate),
                    kind: kind,
                    note: note
                )
            )
        )
    }

    func applyReplanProposal(
        proposalID: UUID,
        decision: PlanningProposalDecision
    ) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .applyReplanProposal,
                proposalID: proposalID,
                decision: decision
            )
        )
    }

    func checkInToWorkout(
        plannedWorkoutID: UUID,
        mood: PlanningMoodInput? = nil,
        textContext: String? = nil,
        currentDerivedSnapshot: HealthFeatureSnapshot? = nil
    ) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .checkInToWorkout,
                plannedWorkoutID: plannedWorkoutID,
                mood: mood,
                textContext: textContext,
                currentDerivedSnapshot: currentDerivedSnapshot
            )
        )
    }

    private func invoke(_ request: PlanningFunctionRequest) async throws -> PlanningFunctionResponse {
        do {
            return try await supabase.functions.invoke(
                "planning-ai",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            throw Self.readableFunctionError(error)
        }
    }

    private func invokeTyped<Response: Decodable>(_ request: PlanningFunctionRequest) async throws -> Response {
        do {
            return try await supabase.functions.invoke(
                "planning-ai",
                options: FunctionInvokeOptions(body: request)
            )
        } catch {
            throw Self.readableFunctionError(error)
        }
    }

    private static func readableFunctionError(_ error: Error) -> Error {
        guard case let FunctionsError.httpError(code, data) = error else {
            return error
        }

        let message: String
        if
            let payload = try? JSONDecoder().decode(PlanningFunctionErrorPayload.self, from: data),
            let errorMessage = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines),
            !errorMessage.isEmpty
        {
            message = errorMessage
        } else if
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !body.isEmpty
        {
            message = body
        } else {
            message = "Edge Function returned a non-2xx status code: \(code)"
        }

        return PlanningFunctionError(statusCode: code, message: message)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct PlanningHealthSyncPayload {
    let healthSnapshot: HealthFeatureSnapshot?
    let actualWorkouts: [HealthActualWorkoutSummary]
    let syncWindow: PlanningSyncWindow
}

struct PlanningSyncWindow: Codable {
    let startDate: String
    let endDate: String
}

struct PlanningMoodInput: Codable {
    let energy: Double?
    let mood: Double?
}

struct PlanningReplacementOutput: Decodable {
    let workoutID: UUID
    let candidates: [PlanningWorkoutCandidate]

    enum CodingKeys: String, CodingKey {
        case workoutID = "workoutID"
        case candidates
    }
}

struct PlanningWorkoutAdditionOutput: Decodable {
    let scheduledDate: String
    let candidates: [PlanningWorkoutCandidate]
}

struct PlanningWorkoutInterpretationOutput: Decodable {
    let scheduledDate: String?
    let workoutID: UUID?
    let candidate: PlanningWorkoutCandidate

    enum CodingKeys: String, CodingKey {
        case scheduledDate
        case workoutID
        case candidate
    }
}

struct PlanningWorkoutCandidate: Codable, Identifiable {
    let id: String
    let archetypeId: String?
    let title: String
    let activityType: String
    let durationMinutes: Int
    let estimatedDistanceKilometers: Double?
    let estimatedElevationMeters: Double?
    let plannedLocationLabel: String?
    let intensityLabel: String
    let purpose: String
    let prescription: JSONValue
    let fuelingSummary: String
    let rationale: String
    let weeklyImpact: String

    enum CodingKeys: String, CodingKey {
        case id
        case archetypeId
        case title
        case activityType
        case durationMinutes
        case estimatedDistanceKilometers
        case estimatedElevationMeters
        case plannedLocationLabel
        case intensityLabel
        case purpose
        case prescription
        case fuelingSummary
        case rationale
        case weeklyImpact
    }
}

typealias PlanningReplacementCandidate = PlanningWorkoutCandidate

enum PlanningProposalDecision: String, Codable {
    case accepted
    case rejected
}

enum PlanningRepairPolicy: String, Codable {
    case immediate
    case deferred
}

enum PlanningWeeklyPlanConstraintKind: String, Codable, CaseIterable, Identifiable {
    case available
    case limited
    case unavailable

    var id: String { rawValue }
}

struct PlanningWeeklyPlanConstraintInput: Encodable {
    let weeklyPlanID: UUID
    let scheduledDate: String
    let kind: PlanningWeeklyPlanConstraintKind
    let note: String?

    enum CodingKeys: String, CodingKey {
        case weeklyPlanID = "weekly_plan_id"
        case scheduledDate = "scheduled_date"
        case kind
        case note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weeklyPlanID.uuidString.lowercased(), forKey: .weeklyPlanID)
        try container.encode(scheduledDate, forKey: .scheduledDate)
        try container.encode(kind, forKey: .kind)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        try container.encodeIfPresent(trimmedNote?.isEmpty == false ? trimmedNote : nil, forKey: .note)
    }
}

enum PlanningPlanEdit: Encodable {
    case moveWorkout(plannedWorkoutID: UUID, scheduledDate: Date, sequenceOrder: Int?)
    case deleteWorkout(plannedWorkoutID: UUID)

    enum CodingKeys: String, CodingKey {
        case type
        case plannedWorkoutID = "planned_workout_id"
        case scheduledDate = "scheduled_date"
        case sequenceOrder = "sequence_order"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .moveWorkout(plannedWorkoutID, scheduledDate, sequenceOrder):
            try container.encode("move_workout", forKey: .type)
            try container.encode(plannedWorkoutID.uuidString.lowercased(), forKey: .plannedWorkoutID)
            try container.encode(Self.dateOnlyFormatter.string(from: scheduledDate), forKey: .scheduledDate)
            try container.encodeIfPresent(sequenceOrder, forKey: .sequenceOrder)
        case let .deleteWorkout(plannedWorkoutID):
            try container.encode("delete_workout", forKey: .type)
            try container.encode(plannedWorkoutID.uuidString.lowercased(), forKey: .plannedWorkoutID)
        }
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct PlanningFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: JSONValue
}

struct PlanningPreparedStrategyOutput: Decodable {
    let status: String
    let graphRunID: UUID
    let userGoalID: UUID
    let fitnessStrategyID: UUID
    let blueprintRevisionID: UUID
    let trainingArchitectureID: UUID
    let eventID: UUID?
    let strategy: JSONValue
    let trainingArchitecture: JSONValue
}

struct PlanningStartedStrategyOutput: Decodable {
    let status: String
    let graphRunID: UUID
    let userGoalID: UUID
    let blueprintRevisionID: UUID
}

private struct PlanningStartedPlanOutput: Decodable {
    let status: String
    let fitnessStrategyID: UUID
}

struct PlanningGraphRunStatusOutput: Decodable {
    let graphRunID: UUID
    let graphName: String
    let status: String
    let errorSummary: String?
    let output: JSONValue?
    let trainingArchitectureID: UUID?
    let userGoalID: UUID?
    let fitnessStrategyID: UUID?
    let blueprintRevisionID: UUID?
    let eventID: UUID?
    let strategy: JSONValue?
    let trainingArchitecture: JSONValue?
}

private struct PlanningStrategyStatusRow: Decodable {
    let id: UUID
    let status: String
}

private struct PlanningWeeklyPlanStatusRow: Decodable {
    let id: UUID
    let status: String
}

private struct PlanningInitialPlanRunRow: Decodable {
    let status: String
    let errorSummary: String?

    enum CodingKeys: String, CodingKey {
        case status
        case errorSummary = "error_summary"
    }
}

enum PlanningGraphRunError: LocalizedError {
    case failed(String)
    case missingPreparedStrategy
    case timedOut

    var errorDescription: String? {
        switch self {
        case let .failed(message):
            return message
        case .missingPreparedStrategy:
            return "Planning finished but the prepared strategy was not available yet. Try again in a moment."
        case .timedOut:
            return "Planning is taking longer than expected. Try again in a moment."
        }
    }
}

struct PlanningEditOutcome: Decodable {
    let eventID: UUID?
    let proposalID: UUID?
    let reason: String?
    let summary: String?
    let mutationCount: Int?
    let proposal: PlanReplanProposal?
    let reviewHint: PlanReviewHint?

    enum CodingKeys: String, CodingKey {
        case eventID
        case proposalID
        case reason
        case summary
        case mutationCount
        case proposal
        case reviewHint
    }
}

struct PlanReviewHint: Decodable {
    let reason: String
    let summary: String?
    let affectedWeekStart: String?
    let riskCount: Int?

    enum CodingKeys: String, CodingKey {
        case reason
        case summary
        case affectedWeekStart
        case riskCount
    }
}

private struct PlanningEditOutcomeFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: PlanningEditOutcome
}

private struct PlanningPreparedStrategyFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: PlanningPreparedStrategyOutput
}

private struct PlanningStartedStrategyFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: PlanningStartedStrategyOutput
}

private struct PlanningStartedPlanFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: PlanningStartedPlanOutput
}

private struct PlanningGraphRunStatusFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: PlanningGraphRunStatusOutput
}

struct PlanningFunctionError: LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? {
        if message.localizedCaseInsensitiveContains("Cannot read properties of undefined")
            && message.localizedCaseInsensitiveContains("model") {
            return "Planning engine is updating. Try again in a moment."
        }

        if message.localizedCaseInsensitiveContains("Unsupported planning AI task") {
            return "Planning engine is updating. Try again in a moment."
        }

        return "Planning engine error \(statusCode): \(message)"
    }
}

private struct PlanningFunctionErrorPayload: Decodable {
    let error: String?
}

private struct PlanningReplacementFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: PlanningReplacementOutput
}

private struct PlanningWorkoutAdditionFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: PlanningWorkoutAdditionOutput
}

private struct PlanningWorkoutInterpretationFunctionResponse: Decodable {
    let task: PlanningAITask
    let model: String
    let output: PlanningWorkoutInterpretationOutput
}

enum PlanningAITask: String, Codable {
    case acceptStrategyAndCreateInitialPlan = "accept_strategy_and_create_initial_plan"
    case prepareInitialStrategyAfterBlueprint = "prepare_initial_strategy_after_blueprint"
    case startPrepareInitialStrategyAfterBlueprint = "start_prepare_initial_strategy_after_blueprint"
    case startAcceptPreparedStrategyAndCreateInitialPlan = "start_accept_prepared_strategy_and_create_initial_plan"
    case acceptPreparedStrategyAndCreateInitialPlan = "accept_prepared_strategy_and_create_initial_plan"
    case getPlanningGraphRunStatus = "get_planning_graph_run_status"
    case syncHealthKitAndReconcile = "sync_healthkit_and_reconcile"
    case refreshPlanWindow = "refresh_plan_window"
    case refreshWorkoutWeatherForecasts = "refresh_workout_weather_forecasts"
    case generateWeeklyPlanTargets = "generate_weekly_plan_targets"
    case recordPlanEdit = "record_plan_edit"
    case recordWeeklyPlanConstraint = "record_weekly_plan_constraint"
    case recommendWorkoutReplacements = "recommend_workout_replacements"
    case recommendWorkoutAdditions = "recommend_workout_additions"
    case interpretWorkoutDescription = "interpret_workout_description"
    case replaceWorkout = "replace_workout"
    case addWorkout = "add_workout"
    case createRepairProposalForRecentEdit = "create_repair_proposal_for_recent_edit"
    case createRepairProposalForPendingEdits = "create_repair_proposal_for_pending_edits"
    case applyReplanProposal = "apply_replan_proposal"
    case checkInToWorkout = "check_in_to_workout"
    case scheduledRefreshDueWindows = "scheduled_refresh_due_windows"
}

private struct PlanningFunctionRequest: Encodable {
    let task: PlanningAITask
    let healthSnapshot: HealthFeatureSnapshot?
    let actualWorkouts: [HealthActualWorkoutSummary]?
    let syncWindow: PlanningSyncWindow?
    let deviceTimezone: String?
    let startDate: String?
    let windowStart: String?
    let acceptedBlueprint: JSONValue?
    let acceptedStrategy: JSONValue?
    let onboardingContext: JSONValue?
    let preparedStrategyID: UUID?
    let graphRunID: UUID?
    let acceptedAt: String?
    let edit: PlanningPlanEdit?
    let proposalID: UUID?
    let eventID: UUID?
    let decision: PlanningProposalDecision?
    let plannedWorkoutID: UUID?
    let scheduledDate: String?
    let sequenceOrder: Int?
    let replacementCandidate: PlanningWorkoutCandidate?
    let workoutCandidate: PlanningWorkoutCandidate?
    let mood: PlanningMoodInput?
    let textContext: String?
    let currentDerivedSnapshot: HealthFeatureSnapshot?
    let repairPolicy: PlanningRepairPolicy?
    let weeklyPlanConstraint: PlanningWeeklyPlanConstraintInput?

    init(
        task: PlanningAITask,
        healthSnapshot: HealthFeatureSnapshot? = nil,
        actualWorkouts: [HealthActualWorkoutSummary]? = nil,
        syncWindow: PlanningSyncWindow? = nil,
        deviceTimezone: String? = nil,
        startDate: String? = nil,
        windowStart: String? = nil,
        acceptedBlueprint: JSONValue? = nil,
        acceptedStrategy: JSONValue? = nil,
        onboardingContext: JSONValue? = nil,
        preparedStrategyID: UUID? = nil,
        graphRunID: UUID? = nil,
        acceptedAt: String? = nil,
        edit: PlanningPlanEdit? = nil,
        proposalID: UUID? = nil,
        eventID: UUID? = nil,
        decision: PlanningProposalDecision? = nil,
        plannedWorkoutID: UUID? = nil,
        scheduledDate: String? = nil,
        sequenceOrder: Int? = nil,
        replacementCandidate: PlanningWorkoutCandidate? = nil,
        workoutCandidate: PlanningWorkoutCandidate? = nil,
        mood: PlanningMoodInput? = nil,
        textContext: String? = nil,
        currentDerivedSnapshot: HealthFeatureSnapshot? = nil,
        repairPolicy: PlanningRepairPolicy? = nil,
        weeklyPlanConstraint: PlanningWeeklyPlanConstraintInput? = nil
    ) {
        self.task = task
        self.healthSnapshot = healthSnapshot
        self.actualWorkouts = actualWorkouts
        self.syncWindow = syncWindow
        self.deviceTimezone = deviceTimezone
        self.startDate = startDate
        self.windowStart = windowStart
        self.acceptedBlueprint = acceptedBlueprint
        self.acceptedStrategy = acceptedStrategy
        self.onboardingContext = onboardingContext
        self.preparedStrategyID = preparedStrategyID
        self.graphRunID = graphRunID
        self.acceptedAt = acceptedAt
        self.edit = edit
        self.proposalID = proposalID
        self.eventID = eventID
        self.decision = decision
        self.plannedWorkoutID = plannedWorkoutID
        self.scheduledDate = scheduledDate
        self.sequenceOrder = sequenceOrder
        self.replacementCandidate = replacementCandidate
        self.workoutCandidate = workoutCandidate
        self.mood = mood
        self.textContext = textContext
        self.currentDerivedSnapshot = currentDerivedSnapshot
        self.repairPolicy = repairPolicy
        self.weeklyPlanConstraint = weeklyPlanConstraint
    }

    enum CodingKeys: String, CodingKey {
        case task
        case healthSnapshot
        case actualWorkouts
        case syncWindow
        case deviceTimezone
        case startDate
        case windowStart
        case acceptedBlueprint = "accepted_blueprint"
        case acceptedStrategy = "accepted_strategy"
        case onboardingContext = "onboarding_context"
        case preparedStrategyID = "prepared_strategy_id"
        case graphRunID = "graph_run_id"
        case acceptedAt = "accepted_at"
        case edit
        case proposalID = "proposal_id"
        case eventID = "event_id"
        case decision
        case plannedWorkoutID = "planned_workout_id"
        case scheduledDate
        case sequenceOrder
        case replacementCandidate = "replacement_candidate"
        case workoutCandidate = "workout_candidate"
        case mood
        case textContext
        case currentDerivedSnapshot = "current_derived_snapshot"
        case repairPolicy = "repair_policy"
        case weeklyPlanConstraint = "weekly_plan_constraint"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(task, forKey: .task)
        if let healthSnapshot {
            try container.encode(JSONValue.isoEncoded(healthSnapshot), forKey: .healthSnapshot)
        }
        if let actualWorkouts {
            try container.encode(JSONValue.isoEncoded(actualWorkouts), forKey: .actualWorkouts)
        }
        try container.encodeIfPresent(syncWindow, forKey: .syncWindow)
        try container.encodeIfPresent(deviceTimezone, forKey: .deviceTimezone)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(windowStart, forKey: .windowStart)
        try container.encodeIfPresent(acceptedBlueprint, forKey: .acceptedBlueprint)
        try container.encodeIfPresent(acceptedStrategy, forKey: .acceptedStrategy)
        try container.encodeIfPresent(onboardingContext, forKey: .onboardingContext)
        try container.encodeIfPresent(preparedStrategyID?.uuidString.lowercased(), forKey: .preparedStrategyID)
        try container.encodeIfPresent(graphRunID?.uuidString.lowercased(), forKey: .graphRunID)
        try container.encodeIfPresent(acceptedAt, forKey: .acceptedAt)
        try container.encodeIfPresent(edit, forKey: .edit)
        try container.encodeIfPresent(proposalID?.uuidString.lowercased(), forKey: .proposalID)
        try container.encodeIfPresent(eventID?.uuidString.lowercased(), forKey: .eventID)
        try container.encodeIfPresent(decision, forKey: .decision)
        try container.encodeIfPresent(plannedWorkoutID?.uuidString.lowercased(), forKey: .plannedWorkoutID)
        try container.encodeIfPresent(scheduledDate, forKey: .scheduledDate)
        try container.encodeIfPresent(sequenceOrder, forKey: .sequenceOrder)
        try container.encodeIfPresent(replacementCandidate, forKey: .replacementCandidate)
        try container.encodeIfPresent(workoutCandidate, forKey: .workoutCandidate)
        try container.encodeIfPresent(mood, forKey: .mood)
        let trimmedTextContext = textContext?.trimmingCharacters(in: .whitespacesAndNewlines)
        try container.encodeIfPresent(trimmedTextContext?.isEmpty == false ? trimmedTextContext : nil, forKey: .textContext)
        if let currentDerivedSnapshot {
            try container.encode(JSONValue.isoEncoded(currentDerivedSnapshot), forKey: .currentDerivedSnapshot)
        }
        try container.encodeIfPresent(repairPolicy, forKey: .repairPolicy)
        try container.encodeIfPresent(weeklyPlanConstraint, forKey: .weeklyPlanConstraint)
    }
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

extension JSONValue {
    static func isoEncoded<T: Encodable>(_ value: T) throws -> JSONValue {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}
