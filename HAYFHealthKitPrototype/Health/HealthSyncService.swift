import Foundation

final class HealthSyncService {
    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager = HealthKitManager()) {
        self.healthKitManager = healthKitManager
    }

    func buildSyncPayload(daysBack: Int = 14) async throws -> PlanningHealthSyncPayload {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate) ?? endDate

        async let featureSnapshot = healthKitManager.fetchFeatureSnapshot()
        async let actualWorkouts = healthKitManager.fetchRecentActualWorkouts(daysBack: daysBack)

        return try await PlanningHealthSyncPayload(
            healthSnapshot: featureSnapshot,
            actualWorkouts: actualWorkouts,
            syncWindow: PlanningSyncWindow(
                startDate: Self.dateOnlyFormatter.string(from: startDate),
                endDate: Self.dateOnlyFormatter.string(from: endDate)
            )
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
