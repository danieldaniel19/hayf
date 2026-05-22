import Foundation

final class HealthSyncService {
    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager = HealthKitManager()) {
        self.healthKitManager = healthKitManager
    }

    func buildSyncPayload(daysBack: Int = 14) async throws -> PlanningHealthSyncPayload {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate) ?? endDate

        async let featureSnapshot = fetchFeatureSnapshot()
        async let actualWorkouts = fetchRecentActualWorkouts(daysBack: daysBack)
        let loadedSnapshot = try await featureSnapshot
        let loadedActualWorkouts = await actualWorkouts

        return PlanningHealthSyncPayload(
            healthSnapshot: loadedSnapshot,
            actualWorkouts: actualWorkoutsWithFixtureFallback(
                loadedActualWorkouts,
                daysBack: daysBack,
                endDate: endDate
            ),
            syncWindow: PlanningSyncWindow(
                startDate: Self.dateOnlyFormatter.string(from: startDate),
                endDate: Self.dateOnlyFormatter.string(from: endDate)
            )
        )
    }

    private func fetchFeatureSnapshot() async throws -> HealthFeatureSnapshot {
        do {
            return try await healthKitManager.fetchFeatureSnapshot()
        } catch {
            #if DEBUG
            if let fixture = HealthFeatureSnapshotFixtureStore.danielSnapshot() {
                return fixture
            }
            #endif
            throw error
        }
    }

    private func fetchRecentActualWorkouts(daysBack: Int) async -> [HealthActualWorkoutSummary] {
        do {
            return try await healthKitManager.fetchRecentActualWorkouts(daysBack: daysBack)
        } catch {
            return []
        }
    }

    private func actualWorkoutsWithFixtureFallback(
        _ actualWorkouts: [HealthActualWorkoutSummary],
        daysBack: Int,
        endDate: Date
    ) -> [HealthActualWorkoutSummary] {
        guard actualWorkouts.isEmpty else { return actualWorkouts }

        #if DEBUG
        guard let fixture = HealthFeatureSnapshotFixtureStore.danielSnapshot(),
              let lastWorkout = fixture.workoutLedger.lastWorkout,
              lastWorkout.startDate <= endDate,
              let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate),
              lastWorkout.startDate >= startDate else {
            return actualWorkouts
        }

        return [
            HealthActualWorkoutSummary(
                healthkitUUID: "fixture-\(Self.fixtureIDFormatter.string(from: lastWorkout.startDate))-\(lastWorkout.type.lowercased().replacingOccurrences(of: " ", with: "-"))",
                startDate: lastWorkout.startDate,
                activityType: lastWorkout.type,
                durationMinutes: max(1, Int(lastWorkout.durationMinutes.rounded())),
                distanceKilometers: lastWorkout.distanceKilometers,
                energyKilocalories: lastWorkout.energyKilocalories
            )
        ]
        #else
        return actualWorkouts
        #endif
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let fixtureIDFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter
    }()
}
