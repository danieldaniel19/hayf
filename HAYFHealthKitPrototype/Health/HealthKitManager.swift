import Foundation
import HealthKit

struct HealthSnapshot {
    let sleepHoursLastNight: Double?
    let workoutsLast7Days: Int
    let averageStepsLast7Days: Double?
    let heightCentimeters: Double?
    let bodyMassKilograms: Double?
}

enum HealthAuthorizationState: String {
    case unknown = "Unknown"
    case shouldRequest = "Not Requested"
    case unnecessary = "Already Determined"
    case unavailable = "Unavailable"
}

final class HealthKitManager {
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        [
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKQuantityType.quantityType(forIdentifier: .vo2Max),
            HKQuantityType.quantityType(forIdentifier: .height),
            HKQuantityType.quantityType(forIdentifier: .bodyMass)
        ].compactMap { $0 }.forEach { types.insert($0) }

        types.insert(HKObjectType.workoutType())

        return types
    }

    func requestStatus() async -> HealthAuthorizationState {
        guard isHealthDataAvailable else {
            return .unavailable
        }

        do {
            let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: readTypes)
            switch status {
            case .shouldRequest:
                return .shouldRequest
            case .unnecessary:
                return .unnecessary
            case .unknown:
                return .unknown
            @unknown default:
                return .unknown
            }
        } catch {
            return .unknown
        }
    }

    func requestReadAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.healthDataUnavailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchSnapshot() async throws -> HealthSnapshot {
        async let sleepHours = fetchSleepHoursLastNight()
        async let workouts = fetchWorkoutCountLast7Days()
        async let averageSteps = fetchAverageStepsLast7Days()
        async let height = fetchLatestQuantityValue(identifier: .height, unit: .meterUnit(with: .centi))
        async let bodyMass = fetchLatestQuantityValue(identifier: .bodyMass, unit: .gramUnit(with: .kilo))

        return try await HealthSnapshot(
            sleepHoursLastNight: sleepHours,
            workoutsLast7Days: workouts,
            averageStepsLast7Days: averageSteps,
            heightCentimeters: height,
            bodyMassKilograms: bodyMass
        )
    }

    private func fetchSleepHoursLastNight() async throws -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfToday = calendar.dateInterval(of: .day, for: now)?.start,
              let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }

            healthStore.execute(query)
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]

        let seconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { partialResult, sample in
                partialResult + sample.endDate.timeIntervalSince(sample.startDate)
            }

        guard seconds > 0 else {
            return nil
        }

        return seconds / 3600
    }

    private func fetchWorkoutCountLast7Days() async throws -> Int {
        let workoutType = HKObjectType.workoutType()
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples?.count ?? 0)
            }

            healthStore.execute(query)
        }
    }

    private func fetchAverageStepsLast7Days() async throws -> Double? {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate),
              let anchorDate = calendar.dateInterval(of: .day, for: endDate)?.start else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let interval = DateComponents(day: 1)

        let dailyTotals: [Double] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Double], Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var totals: [Double] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    totals.append(value)
                }

                continuation.resume(returning: totals)
            }

            healthStore.execute(query)
        }

        guard !dailyTotals.isEmpty else {
            return nil
        }

        let average = dailyTotals.reduce(0, +) / Double(dailyTotals.count)
        return average
    }

    private func fetchLatestQuantityValue(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }
}

enum HealthKitError: LocalizedError {
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        }
    }
}
