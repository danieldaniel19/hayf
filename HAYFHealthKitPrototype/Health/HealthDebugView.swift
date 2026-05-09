import SwiftUI
import UIKit

@MainActor
final class HealthDebugViewModel: ObservableObject {
    @Published var availabilityText = "Checking..."
    @Published var authorizationText = "Checking..."
    @Published var statusText = "No import yet"
    @Published var featureSnapshot: HealthFeatureSnapshot?
    @Published var debugJSON = ""
    @Published var isLoading = false

    private let healthKitManager = HealthKitManager()
    private let healthSyncService = HealthSyncService()
    private let planningAIProvider = PlanningAIProvider()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func load() async {
        availabilityText = healthKitManager.isHealthDataAvailable ? "Available" : "Unavailable"
        await refreshAuthorization()
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
            let snapshot = try await healthKitManager.fetchFeatureSnapshot()
            featureSnapshot = snapshot
            debugJSON = String(data: try encoder.encode(snapshot), encoding: .utf8) ?? ""
        }
    }

    func syncPlanning() async {
        await run("Planning sync completed") {
            let payload = try await healthSyncService.buildSyncPayload(daysBack: 28)
            _ = try await planningAIProvider.syncHealthKitAndReconcile(payload: payload)
            _ = try await planningAIProvider.refreshPlanWindow()
        }
    }

    func copyDebugJSON() {
        UIPasteboard.general.string = debugJSON
        statusText = debugJSON.isEmpty ? "No JSON to copy yet" : "Copied feature JSON"
    }

    private func run(_ successMessage: String, operation: () async throws -> Void) async {
        isLoading = true
        statusText = "Working..."
        defer { isLoading = false }

        do {
            try await operation()
            statusText = successMessage
        } catch {
            statusText = error.localizedDescription
        }
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
