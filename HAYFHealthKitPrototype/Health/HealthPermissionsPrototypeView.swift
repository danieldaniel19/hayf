import SwiftUI
import UIKit

@MainActor
final class HealthPermissionsViewModel: ObservableObject {
    @Published var availabilityText = "Checking..."
    @Published var authorizationStateText = "Checking..."
    @Published var lastActionText = "No action yet"
    @Published var sleepSummaryText = "-"
    @Published var workoutSummaryText = "-"
    @Published var stepsSummaryText = "-"
    @Published var heightSummaryText = "-"
    @Published var bodyMassSummaryText = "-"
    @Published var isLoading = false
    @Published var revokeInstructionsPresented = false

    private let healthKitManager = HealthKitManager()

    func load() async {
        availabilityText = healthKitManager.isHealthDataAvailable ? "Available on this device" : "Unavailable on this device"
        await refreshAuthorizationState()
    }

    func refreshAuthorizationState() async {
        authorizationStateText = (await healthKitManager.requestStatus()).rawValue
    }

    func requestAccess() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await healthKitManager.requestReadAuthorization()
            lastActionText = "Authorization request completed"
            await refreshAuthorizationState()
            try await refreshSnapshot()
        } catch {
            lastActionText = error.localizedDescription
        }
    }

    func refreshSnapshot() async throws {
        let snapshot = try await healthKitManager.fetchSnapshot()

        if let sleepHours = snapshot.sleepHoursLastNight {
            sleepSummaryText = String(format: "%.1f hours last night", sleepHours)
        } else {
            sleepSummaryText = "No recent sleep data returned"
        }

        workoutSummaryText = "\(snapshot.workoutsLast7Days) workouts in the last 7 days"

        if let averageSteps = snapshot.averageStepsLast7Days {
            stepsSummaryText = String(format: "%.0f average daily steps over 7 days", averageSteps)
        } else {
            stepsSummaryText = "No recent steps data returned"
        }

        if let heightCentimeters = snapshot.heightCentimeters {
            heightSummaryText = String(format: "%.0f cm", heightCentimeters)
        } else {
            heightSummaryText = "No height data returned"
        }

        if let bodyMassKilograms = snapshot.bodyMassKilograms {
            bodyMassSummaryText = String(format: "%.1f kg", bodyMassKilograms)
        } else {
            bodyMassSummaryText = "No body mass data returned"
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

struct HealthPermissionsPrototypeView: View {
    @StateObject private var viewModel = HealthPermissionsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    Text("This prototype proves that HAYF can request Apple Health permission for workouts, activity, sleep, recovery, cardio fitness, and basic body context.")
                        .font(.subheadline)
                }

                Section("Status") {
                    LabeledContent("HealthKit") {
                        Text(viewModel.availabilityText)
                    }

                    LabeledContent("Authorization") {
                        Text(viewModel.authorizationStateText)
                    }

                    LabeledContent("Last action") {
                        Text(viewModel.lastActionText)
                    }
                }

                Section("Actions") {
                    Button("Grant Health Access") {
                        Task { await viewModel.requestAccess() }
                    }
                    .disabled(viewModel.isLoading)

                    Button("Refresh Imported Data") {
                        Task {
                            do {
                                try await viewModel.refreshSnapshot()
                                viewModel.lastActionText = "Snapshot refreshed"
                            } catch {
                                viewModel.lastActionText = error.localizedDescription
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)

                    Button("How to Revoke Access") {
                        viewModel.revokeInstructionsPresented = true
                    }
                    .disabled(viewModel.isLoading)

                    Button("Open App Settings") {
                        viewModel.openAppSettings()
                    }
                    .disabled(viewModel.isLoading)
                }

                Section("Imported sample data") {
                    LabeledContent("Sleep") {
                        Text(viewModel.sleepSummaryText)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Workouts") {
                        Text(viewModel.workoutSummaryText)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Steps") {
                        Text(viewModel.stepsSummaryText)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Height") {
                        Text(viewModel.heightSummaryText)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Body mass") {
                        Text(viewModel.bodyMassSummaryText)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("HealthKit Prototype")
            .task {
                await viewModel.load()
            }
            .sheet(isPresented: $viewModel.revokeInstructionsPresented) {
                NavigationStack {
                    List {
                        Text("Apple controls Health permission revocation, so apps cannot fully revoke access directly for the user.")
                        Text("To remove access later on iPhone:")
                        Text("1. Open the Health app.")
                        Text("2. Tap your profile picture.")
                        Text("3. Open Apps under Privacy.")
                        Text("4. Select this app.")
                        Text("5. Turn off the data categories you no longer want to share.")
                    }
                    .navigationTitle("Revoke Access")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

#Preview {
    HealthPermissionsPrototypeView()
}
