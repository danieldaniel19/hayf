import SwiftUI
import Supabase
import UIKit

@MainActor
final class HealthDebugViewModel: ObservableObject {
    @Published var availabilityText = "Checking..."
    @Published var authorizationText = "Checking..."
    @Published var statusText = "No import yet"
    @Published var featureSnapshot: HealthFeatureSnapshot?
    @Published var remoteDiagnostics: HealthRemoteDiagnostics?
    @Published var debugJSON = ""
    @Published var isLoading = false

    private let healthKitManager = HealthKitManager()
    private let healthSyncService = HealthSyncService()
    private let planningAIProvider = PlanningAIProvider()
    private let supabase = SupabaseClientProvider.shared
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func load() async {
        availabilityText = healthKitManager.isHealthDataAvailable ? "Available" : "Unavailable"
        await refreshAuthorization()
        await refreshRemoteDiagnostics()
    }

    func refreshAuthorization() async {
        authorizationText = (await healthKitManager.requestStatus()).rawValue
    }

    func requestFullAccess() async {
        await run("Health access request completed") {
            try await healthKitManager.requestReadAuthorization()
            await refreshAuthorization()
        }
    }

    func runImport() async {
        await run("Feature snapshot rebuilt") {
            try await healthKitManager.requestReadAuthorization()
            await refreshAuthorization()
            let snapshot = try await healthKitManager.fetchFeatureSnapshot()
            updateDebugSnapshot(snapshot)
        }
    }

    func syncPlanning() async {
        await run {
            try await healthKitManager.requestReadAuthorization()
            await refreshAuthorization()
            let payload = try await healthSyncService.buildSyncPayload(daysBack: 28)
            updateDebugSnapshot(payload.healthSnapshot)
            _ = try await planningAIProvider.syncHealthKitAndReconcile(payload: payload)
            _ = try await planningAIProvider.refreshPlanWindow()
            remoteDiagnostics = try await fetchRemoteDiagnostics()

            let totalWorkouts = payload.healthSnapshot?.workoutLedger.totalWorkouts ?? 0
            let insights = payload.healthSnapshot?.fitnessHistory.insightCandidates.count ?? 0
            let remoteSummary = remoteDiagnostics.map { " Remote: \($0.snapshotRows.count) snapshots, \($0.insights.count) insights, \($0.targets.count) targets." } ?? ""
            return "Synced \(payload.actualWorkouts.count) recent workouts. Snapshot: \(totalWorkouts) total workouts, \(insights) insights.\(remoteSummary)"
        }
    }

    func copyDebugJSON() {
        UIPasteboard.general.string = debugJSON
        statusText = debugJSON.isEmpty ? "No JSON to copy yet" : "Copied feature JSON"
    }

    func refreshRemoteDiagnostics() async {
        await run {
            remoteDiagnostics = try await fetchRemoteDiagnostics()
            guard let remoteDiagnostics else {
                return "Remote status unavailable"
            }

            return "Remote: \(remoteDiagnostics.snapshotRows.count) snapshots, \(remoteDiagnostics.insights.count) insights, \(remoteDiagnostics.targets.count) targets."
        }
    }

    private func updateDebugSnapshot(_ snapshot: HealthFeatureSnapshot?) {
        featureSnapshot = snapshot
        if let snapshot {
            debugJSON = String(data: (try? encoder.encode(snapshot)) ?? Data(), encoding: .utf8) ?? ""
        } else {
            debugJSON = ""
        }
    }

    private func run(_ successMessage: String, operation: () async throws -> Void) async {
        await run {
            try await operation()
            return successMessage
        }
    }

    private func run(operation: () async throws -> String) async {
        isLoading = true
        statusText = "Working..."
        defer { isLoading = false }

        do {
            statusText = try await operation()
        } catch {
            statusText = error.localizedDescription
        }
    }

    private func fetchRemoteDiagnostics() async throws -> HealthRemoteDiagnostics {
        async let activeBlocks: [HealthRemoteActiveBlockRow] = supabase
            .from("active_fitness_blocks")
            .select("id, title, goal_text, status, updated_at")
            .eq("status", value: "active")
            .limit(1)
            .execute()
            .value

        async let snapshots: [HealthRemoteSnapshotRow] = supabase
            .from("health_feature_snapshots")
            .select("id, generated_at, created_at")
            .order("generated_at", ascending: false)
            .limit(5)
            .execute()
            .value

        async let insights: [HealthRemoteInsightRow] = supabase
            .from("fitness_history_insights")
            .select("id, title, updated_at")
            .order("updated_at", ascending: false)
            .limit(10)
            .execute()
            .value

        async let targets: [HealthRemoteTargetRow] = supabase
            .from("fitness_goal_targets")
            .select("id, title, status, updated_at")
            .order("updated_at", ascending: false)
            .limit(10)
            .execute()
            .value

        async let traces: [HealthRemoteTraceRow] = supabase
            .from("planning_ai_generations")
            .select("id, task, status, error_message, created_at")
            .order("created_at", ascending: false)
            .limit(8)
            .execute()
            .value

        return try await HealthRemoteDiagnostics(
            activeBlock: activeBlocks.first,
            snapshotRows: snapshots,
            insights: insights,
            targets: targets,
            traces: traces
        )
    }
}

struct HealthRemoteDiagnostics {
    let activeBlock: HealthRemoteActiveBlockRow?
    let snapshotRows: [HealthRemoteSnapshotRow]
    let insights: [HealthRemoteInsightRow]
    let targets: [HealthRemoteTargetRow]
    let traces: [HealthRemoteTraceRow]
}

struct HealthRemoteActiveBlockRow: Decodable, Identifiable {
    let id: UUID
    let title: String
    let goalText: String?
    let status: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case goalText = "goal_text"
        case status
        case updatedAt = "updated_at"
    }
}

struct HealthRemoteSnapshotRow: Decodable, Identifiable {
    let id: UUID
    let generatedAt: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case generatedAt = "generated_at"
        case createdAt = "created_at"
    }
}

struct HealthRemoteInsightRow: Decodable, Identifiable {
    let id: UUID
    let title: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case updatedAt = "updated_at"
    }
}

struct HealthRemoteTargetRow: Decodable, Identifiable {
    let id: UUID
    let title: String
    let status: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case updatedAt = "updated_at"
    }
}

struct HealthRemoteTraceRow: Decodable, Identifiable {
    let id: UUID
    let task: String
    let status: String
    let errorMessage: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case task
        case status
        case errorMessage = "error_message"
        case createdAt = "created_at"
    }
}

struct HealthDebugView: View {
    @StateObject private var viewModel = HealthDebugViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("HealthKit", value: viewModel.availabilityText)
                    LabeledContent("Authorization", value: viewModel.authorizationText)
                    LabeledContent("Last action", value: viewModel.statusText)
                }

                Section("Actions") {
                    Button("Request Full Apple Health Access") {
                        Task { await viewModel.requestFullAccess() }
                    }
                    .disabled(viewModel.isLoading)

                    Button("Run Health Import + Feature Build") {
                        Task { await viewModel.runImport() }
                    }
                    .disabled(viewModel.isLoading)

                    Button("Sync Planning From HealthKit") {
                        Task { await viewModel.syncPlanning() }
                    }
                    .disabled(viewModel.isLoading)

                    Button("Refresh Remote Sync Status") {
                        Task { await viewModel.refreshRemoteDiagnostics() }
                    }
                    .disabled(viewModel.isLoading)

                    Button("Copy Feature JSON") {
                        viewModel.copyDebugJSON()
                    }
                    .disabled(viewModel.debugJSON.isEmpty)
                }

                if let snapshot = viewModel.featureSnapshot {
                    Section("Workout ledger") {
                        LabeledContent("Total workouts", value: "\(snapshot.workoutLedger.totalWorkouts)")
                        LabeledContent("Days since last") {
                            Text(snapshot.workoutLedger.daysSinceLastWorkout.map(String.init) ?? "-")
                        }

                        if let lastWorkout = snapshot.workoutLedger.lastWorkout {
                            LabeledContent("Last workout") {
                                Text("\(lastWorkout.type), \(lastWorkout.durationMinutes.roundedString) min")
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        ForEach(snapshot.workoutLedger.windows) { window in
                            LabeledContent(window.window) {
                                Text("\(window.workouts) workouts, \(window.totalMinutes.roundedString) min")
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }

                    Section("Top activities") {
                        ForEach(snapshot.workoutLedger.byActivity.prefix(8)) { activity in
                            LabeledContent(activity.type) {
                                Text("\(activity.workouts) / \(activity.totalMinutes.roundedString) min")
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }

                    Section("Fitness history") {
                        LabeledContent("Identity", value: snapshot.fitnessHistory.trainingIdentity.label)
                        LabeledContent("Active weeks", value: "\(snapshot.fitnessHistory.consistency.activeWeeks)")
                        LabeledContent("Best streak", value: "\(snapshot.fitnessHistory.consistency.longestActiveWeekStreak) weeks")

                        if let strongestMonth = snapshot.fitnessHistory.seasonality.strongestMonth {
                            LabeledContent("Strongest month", value: strongestMonth.label)
                        }

                        if let ratio = snapshot.fitnessHistory.seasonality.summerVsWinterMinutesRatio {
                            DebugMetricRow("Summer/winter", ratio, suffix: "x")
                        }

                        ForEach(snapshot.fitnessHistory.insightCandidates.prefix(5)) { insight in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.title)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(insight.summary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Activity") {
                        DebugMetricRow("Steps 7d avg", snapshot.activity.averageSteps7Days, suffix: "")
                        DebugMetricRow("Steps 28d avg", snapshot.activity.averageSteps28Days, suffix: "")
                        DebugMetricRow("Active kcal 7d", snapshot.activity.activeEnergy7DaysKilocalories, suffix: "kcal")
                        DebugMetricRow("Exercise 7d", snapshot.activity.exerciseMinutes7Days, suffix: "min")
                        DebugMetricRow("Cycling 90d", snapshot.activity.cyclingDistance90DaysKilometers, suffix: "km")
                    }

                    Section("Recovery + body") {
                        DebugMetricRow("Sleep last night", snapshot.recovery.sleepHoursLastNight, suffix: "h")
                        DebugMetricRow("Sleep 14d avg", snapshot.recovery.averageSleepHours14Days, suffix: "h")
                        DebugMetricRow("RHR 14d avg", snapshot.recovery.restingHeartRate14DayAverageBPM, suffix: "bpm")
                        DebugMetricRow("HRV 14d avg", snapshot.recovery.hrv14DayAverageMS, suffix: "ms")
                        DebugMetricRow("Resp 14d avg", snapshot.recovery.respiratoryRate14DayAverageBreathsPerMinute, suffix: "br/min")
                        DebugMetricRow("VO2 latest", snapshot.recovery.vo2MaxLatest, suffix: "")
                        DebugMetricRow("Body mass", snapshot.body.bodyMassKilograms, suffix: "kg")
                        DebugMetricRow("Body fat", snapshot.body.bodyFatPercentage, suffix: "%")
                    }

                    Section("Nutrition") {
                        LabeledContent("Logged days 28d", value: "\(snapshot.nutrition.daysWithEnergyLogged28Days)")
                        DebugMetricRow("Energy avg", snapshot.nutrition.averageEnergy28DaysKilocalories, suffix: "kcal")
                        DebugMetricRow("Protein avg", snapshot.nutrition.averageProtein28DaysGrams, suffix: "g")
                        DebugMetricRow("Carbs avg", snapshot.nutrition.averageCarbohydrates28DaysGrams, suffix: "g")
                        DebugMetricRow("Fat avg", snapshot.nutrition.averageFat28DaysGrams, suffix: "g")
                        DebugMetricRow("Sugar avg", snapshot.nutrition.averageSugar28DaysGrams, suffix: "g")
                    }

                    Section("Notes") {
                        ForEach(snapshot.notes, id: \.self) { note in
                            Text(note)
                        }
                    }

                    Section("Feature JSON") {
                        Text(viewModel.debugJSON.isEmpty ? "-" : viewModel.debugJSON)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                    }
                } else {
                    Section("Local import") {
                        Text("No local feature snapshot has been built in this debug session.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                if let diagnostics = viewModel.remoteDiagnostics {
                    Section("Remote sync status") {
                        if let block = diagnostics.activeBlock {
                            LabeledContent("Active block", value: block.title)
                            LabeledContent("Block updated", value: DebugDateFormatter.short(block.updatedAt))
                        } else {
                            Text("No active block returned for this user.")
                                .font(.system(size: 14))
                                .foregroundStyle(HAYFColor.error)
                        }

                        LabeledContent("Snapshots", value: "\(diagnostics.snapshotRows.count)")
                        LabeledContent("Profile insights", value: "\(diagnostics.insights.count)")
                        LabeledContent("Goal targets", value: "\(diagnostics.targets.count)")
                    }

                    if !diagnostics.snapshotRows.isEmpty {
                        Section("Remote snapshots") {
                            ForEach(diagnostics.snapshotRows) { row in
                                LabeledContent(DebugDateFormatter.short(row.generatedAt)) {
                                    Text(String(row.id.uuidString.prefix(8)))
                                        .font(.system(size: 12, design: .monospaced))
                                }
                            }
                        }
                    }

                    if !diagnostics.traces.isEmpty {
                        Section("Planning traces") {
                            ForEach(diagnostics.traces) { trace in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(trace.task)
                                            .font(.system(size: 14, weight: .semibold))
                                        Spacer()
                                        Text(trace.status)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(trace.status == "success" ? HAYFColor.secondary : HAYFColor.error)
                                    }

                                    Text(DebugDateFormatter.short(trace.createdAt))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)

                                    if let errorMessage = trace.errorMessage, !errorMessage.isEmpty {
                                        Text(errorMessage)
                                            .font(.system(size: 13))
                                            .foregroundStyle(HAYFColor.error)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Health Debug")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(HAYFColor.orange)
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

private struct DebugMetricRow: View {
    let label: String
    let value: Double?
    let suffix: String

    init(_ label: String, _ value: Double?, suffix: String) {
        self.label = label
        self.value = value
        self.suffix = suffix
    }

    var body: some View {
        LabeledContent(label) {
            Text(value.map { "\($0.roundedString)\(suffix.isEmpty ? "" : " \(suffix)")" } ?? "-")
                .multilineTextAlignment(.trailing)
        }
    }
}

private enum DebugDateFormatter {
    static func short(_ value: String) -> String {
        guard let date = isoFormatter.date(from: value) else {
            return value
        }

        return displayFormatter.string(from: date)
    }

    private static let isoFormatter = ISO8601DateFormatter()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension Double {
    var roundedString: String {
        let absValue = abs(self)
        if absValue >= 100 {
            return String(format: "%.0f", self)
        }

        if absValue >= 10 {
            return String(format: "%.1f", self)
        }

        return String(format: "%.2f", self)
    }
}

#Preview {
    HealthDebugView()
}
