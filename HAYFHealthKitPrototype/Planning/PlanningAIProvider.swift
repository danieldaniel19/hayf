import Foundation
import Supabase

struct PlanningAIProvider {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = SupabaseClientProvider.shared) {
        self.supabase = supabase
    }

    func bootstrapAfterOnboarding(
        healthSnapshot: HealthFeatureSnapshot?,
        deviceTimezone: String = TimeZone.current.identifier,
        startDate: Date = Date()
    ) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .bootstrapAfterOnboarding,
                healthSnapshot: healthSnapshot,
                deviceTimezone: deviceTimezone,
                startDate: Self.dateOnlyFormatter.string(from: startDate)
            )
        )
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
        try await invoke(
            PlanningFunctionRequest(
                task: .refreshPlanWindow,
                windowStart: windowStart.map(Self.dateOnlyFormatter.string(from:))
            )
        )
    }

    func recordPlanEdit(_ edit: PlanningPlanEdit) async throws -> PlanningFunctionResponse {
        try await invoke(
            PlanningFunctionRequest(
                task: .recordPlanEdit,
                edit: edit
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
        try await supabase.functions.invoke(
            "planning-ai",
            options: FunctionInvokeOptions(body: request)
        )
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
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

enum PlanningProposalDecision: String, Codable {
    case accepted
    case rejected
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

enum PlanningAITask: String, Codable {
    case bootstrapAfterOnboarding = "bootstrap_after_onboarding"
    case syncHealthKitAndReconcile = "sync_healthkit_and_reconcile"
    case refreshPlanWindow = "refresh_plan_window"
    case recordPlanEdit = "record_plan_edit"
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
    let edit: PlanningPlanEdit?
    let proposalID: UUID?
    let decision: PlanningProposalDecision?
    let plannedWorkoutID: UUID?
    let mood: PlanningMoodInput?
    let textContext: String?
    let currentDerivedSnapshot: HealthFeatureSnapshot?

    init(
        task: PlanningAITask,
        healthSnapshot: HealthFeatureSnapshot? = nil,
        actualWorkouts: [HealthActualWorkoutSummary]? = nil,
        syncWindow: PlanningSyncWindow? = nil,
        deviceTimezone: String? = nil,
        startDate: String? = nil,
        windowStart: String? = nil,
        edit: PlanningPlanEdit? = nil,
        proposalID: UUID? = nil,
        decision: PlanningProposalDecision? = nil,
        plannedWorkoutID: UUID? = nil,
        mood: PlanningMoodInput? = nil,
        textContext: String? = nil,
        currentDerivedSnapshot: HealthFeatureSnapshot? = nil
    ) {
        self.task = task
        self.healthSnapshot = healthSnapshot
        self.actualWorkouts = actualWorkouts
        self.syncWindow = syncWindow
        self.deviceTimezone = deviceTimezone
        self.startDate = startDate
        self.windowStart = windowStart
        self.edit = edit
        self.proposalID = proposalID
        self.decision = decision
        self.plannedWorkoutID = plannedWorkoutID
        self.mood = mood
        self.textContext = textContext
        self.currentDerivedSnapshot = currentDerivedSnapshot
    }

    enum CodingKeys: String, CodingKey {
        case task
        case healthSnapshot
        case actualWorkouts
        case syncWindow
        case deviceTimezone
        case startDate
        case windowStart
        case edit
        case proposalID = "proposal_id"
        case decision
        case plannedWorkoutID = "planned_workout_id"
        case mood
        case textContext
        case currentDerivedSnapshot = "current_derived_snapshot"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(task, forKey: .task)
        try container.encodeIfPresent(healthSnapshot, forKey: .healthSnapshot)
        try container.encodeIfPresent(actualWorkouts, forKey: .actualWorkouts)
        try container.encodeIfPresent(syncWindow, forKey: .syncWindow)
        try container.encodeIfPresent(deviceTimezone, forKey: .deviceTimezone)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(windowStart, forKey: .windowStart)
        try container.encodeIfPresent(edit, forKey: .edit)
        try container.encodeIfPresent(proposalID?.uuidString.lowercased(), forKey: .proposalID)
        try container.encodeIfPresent(decision, forKey: .decision)
        try container.encodeIfPresent(plannedWorkoutID?.uuidString.lowercased(), forKey: .plannedWorkoutID)
        try container.encodeIfPresent(mood, forKey: .mood)
        let trimmedTextContext = textContext?.trimmingCharacters(in: .whitespacesAndNewlines)
        try container.encodeIfPresent(trimmedTextContext?.isEmpty == false ? trimmedTextContext : nil, forKey: .textContext)
        try container.encodeIfPresent(currentDerivedSnapshot, forKey: .currentDerivedSnapshot)
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
