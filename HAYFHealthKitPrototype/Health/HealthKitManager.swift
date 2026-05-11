import Foundation
import HealthKit
import OSLog

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

struct HealthFeatureSnapshot: Codable {
    let generatedAt: Date
    let importWindow: String
    let workoutLedger: WorkoutLedgerSummary
    let fitnessHistory: FitnessHistoryProfile
    let activity: ActivityFeatureSummary
    let recovery: RecoveryFeatureSummary
    let body: BodyFeatureSummary
    let nutrition: NutritionFeatureSummary
    let notes: [String]
}

struct WorkoutLedgerSummary: Codable {
    let totalWorkouts: Int
    let daysSinceLastWorkout: Int?
    let lastWorkout: WorkoutSummary?
    let windows: [WorkoutWindowSummary]
    let byActivity: [WorkoutActivitySummary]
    let longestCyclingDistanceKilometers: Double?
    let longestRunningDistanceKilometers: Double?
}

struct WorkoutSummary: Codable {
    let type: String
    let startDate: Date
    let durationMinutes: Double
    let distanceKilometers: Double?
    let energyKilocalories: Double?
}

struct HealthActualWorkoutSummary: Codable {
    let healthkitUUID: String
    let startDate: Date
    let activityType: String
    let durationMinutes: Int
    let distanceKilometers: Double?
    let energyKilocalories: Double?
    let loadValue: Double?

    enum CodingKeys: String, CodingKey {
        case healthkitUUID = "healthkit_uuid"
        case startDate = "start_date"
        case activityType = "activity_type"
        case durationMinutes = "duration_minutes"
        case distanceKilometers = "distance_kilometers"
        case energyKilocalories = "energy_kilocalories"
        case loadValue = "load_value"
    }

    init(
        healthkitUUID: String,
        startDate: Date,
        activityType: String,
        durationMinutes: Int,
        distanceKilometers: Double?,
        energyKilocalories: Double?,
        loadValue: Double? = nil
    ) {
        self.healthkitUUID = healthkitUUID
        self.startDate = startDate
        self.activityType = activityType
        self.durationMinutes = durationMinutes
        self.distanceKilometers = distanceKilometers
        self.energyKilocalories = energyKilocalories
        self.loadValue = loadValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        healthkitUUID = try container.decode(String.self, forKey: .healthkitUUID)
        activityType = try container.decode(String.self, forKey: .activityType)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        distanceKilometers = try container.decodeIfPresent(Double.self, forKey: .distanceKilometers)
        energyKilocalories = try container.decodeIfPresent(Double.self, forKey: .energyKilocalories)
        loadValue = try container.decodeIfPresent(Double.self, forKey: .loadValue)

        let startDateValue = try container.decode(String.self, forKey: .startDate)
        guard let parsedDate = Self.isoFormatter.date(from: startDateValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .startDate,
                in: container,
                debugDescription: "Expected ISO8601 start_date"
            )
        }
        startDate = parsedDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(healthkitUUID, forKey: .healthkitUUID)
        try container.encode(Self.isoFormatter.string(from: startDate), forKey: .startDate)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encodeIfPresent(distanceKilometers, forKey: .distanceKilometers)
        try container.encodeIfPresent(energyKilocalories, forKey: .energyKilocalories)
        try container.encodeIfPresent(loadValue, forKey: .loadValue)
    }

    private static let isoFormatter = ISO8601DateFormatter()
}

struct WorkoutWindowSummary: Codable, Identifiable {
    var id: String { window }
    let window: String
    let workouts: Int
    let totalMinutes: Double
    let totalDistanceKilometers: Double?
    let totalEnergyKilocalories: Double?
    let activityTypes: [String]
}

struct WorkoutActivitySummary: Codable, Identifiable {
    var id: String { type }
    let type: String
    let workouts: Int
    let totalMinutes: Double
    let totalDistanceKilometers: Double?
    let lastWorkoutDate: Date?
    let daysSinceLastWorkout: Int?
}

struct ActivityFeatureSummary: Codable {
    let averageSteps7Days: Double?
    let averageSteps28Days: Double?
    let activeEnergy7DaysKilocalories: Double?
    let exerciseMinutes7Days: Double?
    let walkingRunningDistance28DaysKilometers: Double?
    let cyclingDistance90DaysKilometers: Double?
}

struct RecoveryFeatureSummary: Codable {
    let sleepHoursLastNight: Double?
    let averageSleepHours14Days: Double?
    let restingHeartRate14DayAverageBPM: Double?
    let hrv14DayAverageMS: Double?
    let respiratoryRate14DayAverageBreathsPerMinute: Double?
    let vo2MaxLatest: Double?
    let oxygenSaturationLatestPercent: Double?
}

struct BodyFeatureSummary: Codable {
    let heightCentimeters: Double?
    let bodyMassKilograms: Double?
    let bodyMass28DayAverageKilograms: Double?
    let bodyFatPercentage: Double?
    let bodyFat28DayAveragePercentage: Double?
    let leanBodyMassKilograms: Double?
    let waistCircumferenceCentimeters: Double?
}

struct NutritionFeatureSummary: Codable {
    let lastLoggedAt: Date?
    let daysWithEnergyLogged28Days: Int
    let averageEnergy28DaysKilocalories: Double?
    let averageProtein28DaysGrams: Double?
    let averageCarbohydrates28DaysGrams: Double?
    let averageFat28DaysGrams: Double?
    let averageSugar28DaysGrams: Double?
    let averageFiber28DaysGrams: Double?
    let averageWater28DaysLiters: Double?
}

struct FitnessHistoryProfile: Codable {
    let lookbackYears: Int
    let totalWorkouts: Int
    let trainingIdentity: FitnessTrainingIdentitySummary
    let consistency: FitnessConsistencySummary
    let seasonality: FitnessSeasonalitySummary
    let load: FitnessLoadSummary
    let performance: FitnessPerformanceProfile
    let strengthContinuity: FitnessStrengthContinuitySummary
    let recoveryContext: FitnessRecoveryContextSummary
    let bodyTrend: FitnessBodyTrendSummary
    let activityFloor: FitnessActivityFloorSummary
    let insightCandidates: [FitnessHistoryInsightCandidate]
}

struct FitnessTrainingIdentitySummary: Codable {
    let label: String
    let modalityMix: [FitnessModalityMixSummary]
    let dominantModalities: [String]
}

struct FitnessModalityMixSummary: Codable, Identifiable {
    var id: String { modality }
    let modality: String
    let workouts: Int
    let totalMinutes: Double
    let totalDistanceKilometers: Double?
    let shareOfMinutes: Double
    let lastWorkoutDate: Date?
}

struct FitnessConsistencySummary: Codable {
    let weeksAnalyzed: Int
    let activeWeeks: Int
    let averageWorkoutsPerActiveWeek: Double?
    let averageMinutesPerActiveWeek: Double?
    let longestActiveWeekStreak: Int
    let longestGapDays: Int?
}

struct FitnessSeasonalitySummary: Codable {
    let strongestMonth: FitnessMonthlyActivitySummary?
    let strongestSeason: FitnessSeasonActivitySummary?
    let summerVsWinterMinutesRatio: Double?
    let monthlyActivity: [FitnessMonthlyActivitySummary]
    let seasonalActivity: [FitnessSeasonActivitySummary]
}

struct FitnessMonthlyActivitySummary: Codable, Identifiable {
    var id: Int { month }
    let month: Int
    let label: String
    let workouts: Int
    let totalMinutes: Double
    let totalDistanceKilometers: Double?
}

struct FitnessSeasonActivitySummary: Codable, Identifiable {
    var id: String { season }
    let season: String
    let workouts: Int
    let totalMinutes: Double
    let totalDistanceKilometers: Double?
}

struct FitnessLoadSummary: Codable {
    let windows: [WorkoutWindowSummary]
    let currentVsNinetyDayMinutesRatio: Double?
    let currentVsAllTimeMinutesRatio: Double?
}

struct FitnessPerformanceProfile: Codable {
    let bestDistanceEfforts: [FitnessBestDistanceEffort]
    let longestWorkoutsByModality: [FitnessLongestWorkoutSummary]
}

struct FitnessBestDistanceEffort: Codable, Identifiable {
    var id: String { "\(modality)-\(distanceBucketKilometers)" }
    let modality: String
    let distanceBucketKilometers: Double
    let workoutDate: Date
    let workoutDistanceKilometers: Double
    let averageSpeedKilometersPerHour: Double
    let paceSecondsPerKilometer: Double
}

struct FitnessLongestWorkoutSummary: Codable, Identifiable {
    var id: String { modality }
    let modality: String
    let workoutDate: Date
    let durationMinutes: Double
    let distanceKilometers: Double?
}

struct FitnessStrengthContinuitySummary: Codable {
    let strengthWorkouts28Days: Int
    let strengthWorkouts90Days: Int
    let strengthMinutes90Days: Double
    let daysSinceLastStrength: Int?
    let strengthShareOfMinutes90Days: Double?
}

struct FitnessRecoveryContextSummary: Codable {
    let sleepHoursLastNight: Double?
    let averageSleepHours14Days: Double?
    let restingHeartRate14DayAverageBPM: Double?
    let hrv14DayAverageMS: Double?
    let vo2MaxLatest: Double?
}

struct FitnessBodyTrendSummary: Codable {
    let bodyMassLatestKilograms: Double?
    let bodyMass28DayAverageKilograms: Double?
    let bodyFatLatestPercentage: Double?
    let bodyFat28DayAveragePercentage: Double?
    let waistCircumferenceCentimeters: Double?
}

struct FitnessActivityFloorSummary: Codable {
    let averageSteps7Days: Double?
    let averageSteps28Days: Double?
    let activeEnergy7DaysKilocalories: Double?
    let exerciseMinutes7Days: Double?
    let walkingRunningDistance28DaysKilometers: Double?
}

struct FitnessHistoryInsightCandidate: Codable, Identifiable {
    var id: String { key }
    let key: String
    let category: String
    let title: String
    let summary: String
    let confidence: String
    let evidence: [String: String]
}

final class HealthKitManager {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HAYF", category: "health.features")
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        [
            HKCategoryTypeIdentifier.sleepAnalysis,
            .mindfulSession,
            .appleStandHour,
            .lowCardioFitnessEvent,
            .highHeartRateEvent,
            .lowHeartRateEvent,
            .irregularHeartRhythmEvent,
            .environmentalAudioExposureEvent,
            .toothbrushingEvent
        ].compactMap { HKObjectType.categoryType(forIdentifier: $0) }.forEach { types.insert($0) }

        [
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned),
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
            HKQuantityType.quantityType(forIdentifier: .appleStandTime),
            HKQuantityType.quantityType(forIdentifier: .flightsClimbed),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKQuantityType.quantityType(forIdentifier: .distanceCycling),
            HKQuantityType.quantityType(forIdentifier: .distanceSwimming),
            HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage),
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKQuantityType.quantityType(forIdentifier: .vo2Max),
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate),
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation),
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature),
            HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
            HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic),
            HKQuantityType.quantityType(forIdentifier: .bloodGlucose),
            HKQuantityType.quantityType(forIdentifier: .height),
            HKQuantityType.quantityType(forIdentifier: .bodyMass),
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),
            HKQuantityType.quantityType(forIdentifier: .leanBodyMass),
            HKQuantityType.quantityType(forIdentifier: .waistCircumference),
            HKQuantityType.quantityType(forIdentifier: .bodyMassIndex),
            HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
            HKQuantityType.quantityType(forIdentifier: .dietarySugar),
            HKQuantityType.quantityType(forIdentifier: .dietaryFiber),
            HKQuantityType.quantityType(forIdentifier: .dietaryWater),
            HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine),
            HKQuantityType.quantityType(forIdentifier: .dietarySodium),
            HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol),
            HKQuantityType.quantityType(forIdentifier: .dietaryCalcium),
            HKQuantityType.quantityType(forIdentifier: .dietaryIron),
            HKQuantityType.quantityType(forIdentifier: .dietaryPotassium),
            HKQuantityType.quantityType(forIdentifier: .dietaryVitaminD),
            HKQuantityType.quantityType(forIdentifier: .dietaryVitaminB12),
            HKQuantityType.quantityType(forIdentifier: .dietaryVitaminC)
        ].compactMap { $0 }.forEach { types.insert($0) }

        types.insert(HKObjectType.workoutType())
        types.insert(HKSeriesType.workoutRoute())

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

    func fetchFeatureSnapshot() async throws -> HealthFeatureSnapshot {
        Self.logger.info("Starting deterministic HealthKit feature snapshot")

        async let workouts = fetchWorkoutsSince(yearsBack: 6)
        async let sleepLastNight = fetchSleepHoursLastNight()
        async let sleep14 = fetchAverageSleepHours(days: 14)
        async let steps7 = fetchDailyAverage(identifier: .stepCount, unit: .count(), days: 7)
        async let steps28 = fetchDailyAverage(identifier: .stepCount, unit: .count(), days: 28)
        async let activeEnergy7 = fetchCumulativeQuantity(identifier: .activeEnergyBurned, unit: .kilocalorie(), days: 7)
        async let exerciseMinutes7 = fetchCumulativeQuantity(identifier: .appleExerciseTime, unit: .minute(), days: 7)
        async let walkingRunningDistance28 = fetchCumulativeQuantity(identifier: .distanceWalkingRunning, unit: .meter(), days: 28)
        async let cyclingDistance90 = fetchCumulativeQuantity(identifier: .distanceCycling, unit: .meter(), days: 90)
        async let restingHeartRate14 = fetchAverageQuantity(identifier: .restingHeartRate, unit: .count().unitDivided(by: .minute()), days: 14)
        async let hrv14 = fetchAverageQuantity(identifier: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 14)
        async let respiratoryRate14 = fetchAverageQuantity(identifier: .respiratoryRate, unit: .count().unitDivided(by: .minute()), days: 14)
        async let vo2Max = fetchLatestQuantity(identifier: .vo2Max, unit: HKUnit(from: "mL/kg*min"))
        async let oxygenSaturation = fetchLatestQuantity(identifier: .oxygenSaturation, unit: .percent())
        async let height = fetchLatestQuantity(identifier: .height, unit: .meterUnit(with: .centi))
        async let bodyMass = fetchLatestQuantity(identifier: .bodyMass, unit: .gramUnit(with: .kilo))
        async let bodyMass28 = fetchAverageQuantity(identifier: .bodyMass, unit: .gramUnit(with: .kilo), days: 28)
        async let bodyFat = fetchLatestQuantity(identifier: .bodyFatPercentage, unit: .percent())
        async let bodyFat28 = fetchAverageQuantity(identifier: .bodyFatPercentage, unit: .percent(), days: 28)
        async let leanBodyMass = fetchLatestQuantity(identifier: .leanBodyMass, unit: .gramUnit(with: .kilo))
        async let waist = fetchLatestQuantity(identifier: .waistCircumference, unit: .meterUnit(with: .centi))
        async let nutrition = fetchNutritionSummary(days: 28)

        let workoutSamples = try await workouts
        let workoutLedger = buildWorkoutLedger(from: workoutSamples)
        let activity = try await ActivityFeatureSummary(
            averageSteps7Days: steps7,
            averageSteps28Days: steps28,
            activeEnergy7DaysKilocalories: activeEnergy7,
            exerciseMinutes7Days: exerciseMinutes7,
            walkingRunningDistance28DaysKilometers: walkingRunningDistance28.map { $0 / 1000 },
            cyclingDistance90DaysKilometers: cyclingDistance90.map { $0 / 1000 }
        )
        let recovery = try await RecoveryFeatureSummary(
            sleepHoursLastNight: sleepLastNight,
            averageSleepHours14Days: sleep14,
            restingHeartRate14DayAverageBPM: restingHeartRate14,
            hrv14DayAverageMS: hrv14,
            respiratoryRate14DayAverageBreathsPerMinute: respiratoryRate14,
            vo2MaxLatest: vo2Max.flatMap(\.value),
            oxygenSaturationLatestPercent: oxygenSaturation.flatMap(\.value).map { $0 * 100 }
        )
        let body = try await BodyFeatureSummary(
            heightCentimeters: height.flatMap(\.value),
            bodyMassKilograms: bodyMass.flatMap(\.value),
            bodyMass28DayAverageKilograms: bodyMass28,
            bodyFatPercentage: bodyFat.flatMap(\.value).map { $0 * 100 },
            bodyFat28DayAveragePercentage: bodyFat28.map { $0 * 100 },
            leanBodyMassKilograms: leanBodyMass.flatMap(\.value),
            waistCircumferenceCentimeters: waist.flatMap(\.value)
        )
        let nutritionSummary = try await nutrition
        let fitnessHistory = buildFitnessHistoryProfile(
            workouts: workoutSamples,
            workoutLedger: workoutLedger,
            activity: activity,
            recovery: recovery,
            body: body,
            lookbackYears: 6
        )
        let notes = buildSnapshotNotes(
            workouts: workoutSamples,
            nutrition: nutritionSummary,
            sleep14: recovery.averageSleepHours14Days
        )

        Self.logger.info("Built health feature snapshot: workouts=\(workoutLedger.totalWorkouts), types=\(workoutLedger.byActivity.count)")

        return HealthFeatureSnapshot(
            generatedAt: Date(),
            importWindow: "Last 6 years, plus latest available body/recovery/nutrition samples",
            workoutLedger: workoutLedger,
            fitnessHistory: fitnessHistory,
            activity: activity,
            recovery: recovery,
            body: body,
            nutrition: nutritionSummary,
            notes: notes
        )
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

    func fetchRecentActualWorkouts(daysBack: Int = 14) async throws -> [HealthActualWorkoutSummary] {
        guard daysBack > 0 else { return [] }

        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let workouts: [HKWorkout] = try await fetchSamples(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            sortDescriptors: [sortDescriptor]
        )

        return workouts.map(actualWorkoutSummary)
    }

    private func fetchWorkoutsSince(yearsBack: Int) async throws -> [HKWorkout] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -yearsBack, to: endDate)
        let predicate = startDate.map { HKQuery.predicateForSamples(withStart: $0, end: endDate) }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }

                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func buildWorkoutLedger(from workouts: [HKWorkout]) -> WorkoutLedgerSummary {
        let calendar = Calendar.current
        let now = Date()
        let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }
        let lastWorkout = sortedWorkouts.first.map(workoutSummary)
        let byActivity = Dictionary(grouping: workouts, by: { $0.workoutActivityType.displayName })
            .map { type, workouts in
                let sorted = workouts.sorted { $0.startDate > $1.startDate }
                let totalDistance = workouts.compactMap(distanceKilometers).reduce(0, +)
                let lastDate = sorted.first?.startDate
                return WorkoutActivitySummary(
                    type: type,
                    workouts: workouts.count,
                    totalMinutes: workouts.reduce(0) { $0 + $1.duration / 60 },
                    totalDistanceKilometers: totalDistance > 0 ? totalDistance : nil,
                    lastWorkoutDate: lastDate,
                    daysSinceLastWorkout: lastDate.map { calendar.dateComponents([.day], from: $0, to: now).day ?? 0 }
                )
            }
            .sorted { $0.totalMinutes > $1.totalMinutes }

        let windows = [
            workoutWindowSummary(label: "7d", days: 7, workouts: workouts),
            workoutWindowSummary(label: "28d", days: 28, workouts: workouts),
            workoutWindowSummary(label: "90d", days: 90, workouts: workouts),
            workoutWindowSummary(label: "365d", days: 365, workouts: workouts),
            workoutWindowSummary(label: "all", days: nil, workouts: workouts)
        ]

        let lastWorkoutDate = sortedWorkouts.first?.startDate
        let cyclingDistances = workouts
            .filter { $0.workoutActivityType.isCycling }
            .compactMap(distanceKilometers)
        let runningDistances = workouts
            .filter { $0.workoutActivityType.isRunning }
            .compactMap(distanceKilometers)

        return WorkoutLedgerSummary(
            totalWorkouts: workouts.count,
            daysSinceLastWorkout: lastWorkoutDate.map { calendar.dateComponents([.day], from: $0, to: now).day ?? 0 },
            lastWorkout: lastWorkout,
            windows: windows,
            byActivity: byActivity,
            longestCyclingDistanceKilometers: cyclingDistances.max(),
            longestRunningDistanceKilometers: runningDistances.max()
        )
    }

    private func buildFitnessHistoryProfile(
        workouts: [HKWorkout],
        workoutLedger: WorkoutLedgerSummary,
        activity: ActivityFeatureSummary,
        recovery: RecoveryFeatureSummary,
        body: BodyFeatureSummary,
        lookbackYears: Int
    ) -> FitnessHistoryProfile {
        let trainingIdentity = buildTrainingIdentity(from: workouts)
        let consistency = buildConsistencySummary(from: workouts, lookbackYears: lookbackYears)
        let seasonality = buildSeasonalitySummary(from: workouts)
        let load = buildLoadSummary(from: workoutLedger)
        let performance = buildPerformanceProfile(from: workouts)
        let strengthContinuity = buildStrengthContinuity(from: workouts)
        let recoveryContext = FitnessRecoveryContextSummary(
            sleepHoursLastNight: recovery.sleepHoursLastNight,
            averageSleepHours14Days: recovery.averageSleepHours14Days,
            restingHeartRate14DayAverageBPM: recovery.restingHeartRate14DayAverageBPM,
            hrv14DayAverageMS: recovery.hrv14DayAverageMS,
            vo2MaxLatest: recovery.vo2MaxLatest
        )
        let bodyTrend = FitnessBodyTrendSummary(
            bodyMassLatestKilograms: body.bodyMassKilograms,
            bodyMass28DayAverageKilograms: body.bodyMass28DayAverageKilograms,
            bodyFatLatestPercentage: body.bodyFatPercentage,
            bodyFat28DayAveragePercentage: body.bodyFat28DayAveragePercentage,
            waistCircumferenceCentimeters: body.waistCircumferenceCentimeters
        )
        let activityFloor = FitnessActivityFloorSummary(
            averageSteps7Days: activity.averageSteps7Days,
            averageSteps28Days: activity.averageSteps28Days,
            activeEnergy7DaysKilocalories: activity.activeEnergy7DaysKilocalories,
            exerciseMinutes7Days: activity.exerciseMinutes7Days,
            walkingRunningDistance28DaysKilometers: activity.walkingRunningDistance28DaysKilometers
        )
        let insights = buildInsightCandidates(
            trainingIdentity: trainingIdentity,
            consistency: consistency,
            seasonality: seasonality,
            performance: performance,
            strengthContinuity: strengthContinuity,
            bodyTrend: bodyTrend
        )

        return FitnessHistoryProfile(
            lookbackYears: lookbackYears,
            totalWorkouts: workouts.count,
            trainingIdentity: trainingIdentity,
            consistency: consistency,
            seasonality: seasonality,
            load: load,
            performance: performance,
            strengthContinuity: strengthContinuity,
            recoveryContext: recoveryContext,
            bodyTrend: bodyTrend,
            activityFloor: activityFloor,
            insightCandidates: insights
        )
    }

    private func buildTrainingIdentity(from workouts: [HKWorkout]) -> FitnessTrainingIdentitySummary {
        let totalMinutes = workouts.reduce(0) { $0 + $1.duration / 60 }
        let modalityMix = Dictionary(grouping: workouts, by: { normalizedModality(for: $0) })
            .map { modality, workouts in
                let sorted = workouts.sorted { $0.startDate > $1.startDate }
                let minutes = workouts.reduce(0) { $0 + $1.duration / 60 }
                let distance = workouts.compactMap(distanceKilometers).reduce(0, +)
                return FitnessModalityMixSummary(
                    modality: modality,
                    workouts: workouts.count,
                    totalMinutes: minutes,
                    totalDistanceKilometers: distance > 0 ? distance : nil,
                    shareOfMinutes: totalMinutes > 0 ? minutes / totalMinutes : 0,
                    lastWorkoutDate: sorted.first?.startDate
                )
            }
            .sorted { $0.totalMinutes > $1.totalMinutes }

        let dominant = modalityMix.prefix(3).map(\.modality)
        let label: String
        if dominant.contains("strength") && dominant.contains(where: { ["cycling", "running", "walking", "hiit"].contains($0) }) {
            label = "Hybrid athlete"
        } else if dominant.first == "strength" {
            label = "Strength-led"
        } else if dominant.first == "cycling" || dominant.first == "running" {
            label = "Endurance-led"
        } else if workouts.isEmpty {
            label = "Not enough workout history"
        } else {
            label = "Mixed training"
        }

        return FitnessTrainingIdentitySummary(
            label: label,
            modalityMix: modalityMix,
            dominantModalities: dominant
        )
    }

    private func buildConsistencySummary(from workouts: [HKWorkout], lookbackYears: Int) -> FitnessConsistencySummary {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .year, value: -lookbackYears, to: now) ?? now
        let weeksAnalyzed = max(1, calendar.dateComponents([.weekOfYear], from: start, to: now).weekOfYear ?? lookbackYears * 52)
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.dateInterval(of: .weekOfYear, for: workout.startDate)?.start ?? workout.startDate
        }
        let activeWeeks = grouped.count
        let activeWeekWorkoutCounts = grouped.values.map(\.count)
        let activeWeekMinutes = grouped.values.map { weekWorkouts in
            weekWorkouts.reduce(0) { $0 + $1.duration / 60 }
        }
        let sortedWeeks = grouped.keys.sorted()
        var longestStreak = sortedWeeks.isEmpty ? 0 : 1
        var currentStreak = sortedWeeks.isEmpty ? 0 : 1
        for index in sortedWeeks.indices.dropFirst() {
            let previous = sortedWeeks[sortedWeeks.index(before: index)]
            let current = sortedWeeks[index]
            let days = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
            if days <= 8 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }

        let sortedDates = workouts.map(\.startDate).sorted()
        let gaps = zip(sortedDates, sortedDates.dropFirst()).map { previous, next in
            calendar.dateComponents([.day], from: previous, to: next).day ?? 0
        }

        return FitnessConsistencySummary(
            weeksAnalyzed: weeksAnalyzed,
            activeWeeks: activeWeeks,
            averageWorkoutsPerActiveWeek: activeWeekWorkoutCounts.isEmpty ? nil : Double(activeWeekWorkoutCounts.reduce(0, +)) / Double(activeWeekWorkoutCounts.count),
            averageMinutesPerActiveWeek: activeWeekMinutes.isEmpty ? nil : activeWeekMinutes.reduce(0, +) / Double(activeWeekMinutes.count),
            longestActiveWeekStreak: longestStreak,
            longestGapDays: gaps.max()
        )
    }

    private func buildSeasonalitySummary(from workouts: [HKWorkout]) -> FitnessSeasonalitySummary {
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMM"

        let monthly = Dictionary(grouping: workouts) { calendar.component(.month, from: $0.startDate) }
            .map { month, workouts in
                let date = calendar.date(from: DateComponents(month: month, day: 1)) ?? Date()
                let distance = workouts.compactMap(distanceKilometers).reduce(0, +)
                return FitnessMonthlyActivitySummary(
                    month: month,
                    label: monthFormatter.string(from: date),
                    workouts: workouts.count,
                    totalMinutes: workouts.reduce(0) { $0 + $1.duration / 60 },
                    totalDistanceKilometers: distance > 0 ? distance : nil
                )
            }
            .sorted { $0.month < $1.month }

        let seasonal = Dictionary(grouping: workouts) { seasonLabel(for: calendar.component(.month, from: $0.startDate)) }
            .map { season, workouts in
                let distance = workouts.compactMap(distanceKilometers).reduce(0, +)
                return FitnessSeasonActivitySummary(
                    season: season,
                    workouts: workouts.count,
                    totalMinutes: workouts.reduce(0) { $0 + $1.duration / 60 },
                    totalDistanceKilometers: distance > 0 ? distance : nil
                )
            }
            .sorted { $0.totalMinutes > $1.totalMinutes }

        let summerMinutes = seasonal.first { $0.season == "summer" }?.totalMinutes
        let winterMinutes = seasonal.first { $0.season == "winter" }?.totalMinutes
        let ratio: Double?
        if let summerMinutes, let winterMinutes, winterMinutes > 0 {
            ratio = summerMinutes / winterMinutes
        } else {
            ratio = nil
        }

        return FitnessSeasonalitySummary(
            strongestMonth: monthly.max { $0.totalMinutes < $1.totalMinutes },
            strongestSeason: seasonal.max { $0.totalMinutes < $1.totalMinutes },
            summerVsWinterMinutesRatio: ratio,
            monthlyActivity: monthly,
            seasonalActivity: seasonal
        )
    }

    private func buildLoadSummary(from workoutLedger: WorkoutLedgerSummary) -> FitnessLoadSummary {
        let sevenDayMinutes = workoutLedger.windows.first { $0.window == "7d" }?.totalMinutes
        let ninetyDayMinutes = workoutLedger.windows.first { $0.window == "90d" }?.totalMinutes
        let allMinutes = workoutLedger.windows.first { $0.window == "all" }?.totalMinutes

        return FitnessLoadSummary(
            windows: workoutLedger.windows,
            currentVsNinetyDayMinutesRatio: ratio(sevenDayMinutes.map { $0 * 90 / 7 }, ninetyDayMinutes),
            currentVsAllTimeMinutesRatio: ratio(sevenDayMinutes, allMinutes)
        )
    }

    private func buildPerformanceProfile(from workouts: [HKWorkout]) -> FitnessPerformanceProfile {
        let distanceBuckets = [5.0, 10.0, 20.0, 40.0, 80.0]
        var bestEfforts: [FitnessBestDistanceEffort] = []
        let distanceWorkouts = workouts.compactMap { workout -> (workout: HKWorkout, modality: String, distance: Double)? in
            guard let distance = distanceKilometers(for: workout), distance > 0 else { return nil }
            return (workout, normalizedModality(for: workout), distance)
        }

        let grouped = Dictionary(grouping: distanceWorkouts, by: { $0.modality })
        for (modality, rows) in grouped {
            for bucket in distanceBuckets {
                let candidates = rows.filter { $0.distance >= bucket && $0.workout.duration > 0 }
                guard let best = candidates.max(by: { lhs, rhs in
                    (lhs.distance / (lhs.workout.duration / 3600)) < (rhs.distance / (rhs.workout.duration / 3600))
                }) else {
                    continue
                }

                let speed = best.distance / (best.workout.duration / 3600)
                bestEfforts.append(
                    FitnessBestDistanceEffort(
                        modality: modality,
                        distanceBucketKilometers: bucket,
                        workoutDate: best.workout.startDate,
                        workoutDistanceKilometers: best.distance,
                        averageSpeedKilometersPerHour: speed,
                        paceSecondsPerKilometer: best.workout.duration / max(best.distance, 0.1)
                    )
                )
            }
        }

        let longest = grouped.compactMap { modality, rows -> FitnessLongestWorkoutSummary? in
            guard let longest = rows.max(by: { $0.workout.duration < $1.workout.duration }) else { return nil }
            return FitnessLongestWorkoutSummary(
                modality: modality,
                workoutDate: longest.workout.startDate,
                durationMinutes: longest.workout.duration / 60,
                distanceKilometers: longest.distance
            )
        }
        .sorted { $0.durationMinutes > $1.durationMinutes }

        return FitnessPerformanceProfile(
            bestDistanceEfforts: bestEfforts.sorted {
                if $0.modality == $1.modality {
                    return $0.distanceBucketKilometers < $1.distanceBucketKilometers
                }
                return $0.modality < $1.modality
            },
            longestWorkoutsByModality: longest
        )
    }

    private func buildStrengthContinuity(from workouts: [HKWorkout]) -> FitnessStrengthContinuitySummary {
        let now = Date()
        let calendar = Calendar.current
        let strengthWorkouts = workouts.filter { normalizedModality(for: $0) == "strength" }
        let ninetyDayWorkouts = workouts.filter { workout in
            guard let start = calendar.date(byAdding: .day, value: -90, to: now) else { return false }
            return workout.startDate >= start
        }
        let strength90 = ninetyDayWorkouts.filter { normalizedModality(for: $0) == "strength" }
        let total90Minutes = ninetyDayWorkouts.reduce(0) { $0 + $1.duration / 60 }
        let strength90Minutes = strength90.reduce(0) { $0 + $1.duration / 60 }
        let lastStrength = strengthWorkouts.map(\.startDate).max()

        return FitnessStrengthContinuitySummary(
            strengthWorkouts28Days: workoutsInLast(days: 28, workouts: strengthWorkouts),
            strengthWorkouts90Days: strength90.count,
            strengthMinutes90Days: strength90Minutes,
            daysSinceLastStrength: lastStrength.map { calendar.dateComponents([.day], from: $0, to: now).day ?? 0 },
            strengthShareOfMinutes90Days: total90Minutes > 0 ? strength90Minutes / total90Minutes : nil
        )
    }

    private func buildInsightCandidates(
        trainingIdentity: FitnessTrainingIdentitySummary,
        consistency: FitnessConsistencySummary,
        seasonality: FitnessSeasonalitySummary,
        performance: FitnessPerformanceProfile,
        strengthContinuity: FitnessStrengthContinuitySummary,
        bodyTrend: FitnessBodyTrendSummary
    ) -> [FitnessHistoryInsightCandidate] {
        var insights: [FitnessHistoryInsightCandidate] = []

        if !trainingIdentity.dominantModalities.isEmpty {
            insights.append(
                FitnessHistoryInsightCandidate(
                    key: "training_identity",
                    category: "identity",
                    title: trainingIdentity.label,
                    summary: "Your history is led by \(trainingIdentity.dominantModalities.prefix(3).joined(separator: ", ")).",
                    confidence: trainingIdentity.modalityMix.count >= 2 ? "high" : "medium",
                    evidence: ["dominantModalities": trainingIdentity.dominantModalities.joined(separator: ", ")]
                )
            )
        }

        if consistency.longestActiveWeekStreak >= 4 {
            insights.append(
                FitnessHistoryInsightCandidate(
                    key: "best_consistency_streak",
                    category: "consistency",
                    title: "Best consistency block",
                    summary: "Your longest active training streak is \(consistency.longestActiveWeekStreak) weeks.",
                    confidence: "high",
                    evidence: ["longestActiveWeekStreak": "\(consistency.longestActiveWeekStreak)"]
                )
            )
        }

        if let ratio = seasonality.summerVsWinterMinutesRatio, ratio >= 1.2 {
            let percent = Int(((ratio - 1) * 100).rounded())
            insights.append(
                FitnessHistoryInsightCandidate(
                    key: "summer_activity_pattern",
                    category: "seasonality",
                    title: "Summer activity lift",
                    summary: "Your summer training minutes are about \(percent)% higher than winter.",
                    confidence: "medium",
                    evidence: ["summerVsWinterMinutesRatio": String(format: "%.2f", ratio)]
                )
            )
        }

        if let strongestMonth = seasonality.strongestMonth, strongestMonth.totalMinutes > 0 {
            insights.append(
                FitnessHistoryInsightCandidate(
                    key: "strongest_month",
                    category: "seasonality",
                    title: "Strongest month pattern",
                    summary: "\(strongestMonth.label) is your strongest historical training month by minutes.",
                    confidence: "medium",
                    evidence: ["month": strongestMonth.label, "totalMinutes": String(format: "%.0f", strongestMonth.totalMinutes)]
                )
            )
        }

        if let longest = performance.longestWorkoutsByModality.first {
            insights.append(
                FitnessHistoryInsightCandidate(
                    key: "longest_workout",
                    category: "performance",
                    title: "Longest session marker",
                    summary: "Your longest \(longest.modality) session is \(Int(longest.durationMinutes.rounded())) minutes.",
                    confidence: "high",
                    evidence: ["modality": longest.modality, "durationMinutes": String(format: "%.0f", longest.durationMinutes)]
                )
            )
        }

        if strengthContinuity.strengthWorkouts90Days > 0 {
            insights.append(
                FitnessHistoryInsightCandidate(
                    key: "strength_anchor",
                    category: "balance",
                    title: "Strength anchor",
                    summary: "You logged \(strengthContinuity.strengthWorkouts90Days) strength sessions in the last 90 days.",
                    confidence: "high",
                    evidence: ["strengthWorkouts90Days": "\(strengthContinuity.strengthWorkouts90Days)"]
                )
            )
        }

        if bodyTrend.bodyMassLatestKilograms != nil || bodyTrend.bodyFatLatestPercentage != nil {
            insights.append(
                FitnessHistoryInsightCandidate(
                    key: "body_metrics_available",
                    category: "body",
                    title: "Body trend available",
                    summary: "HealthKit has body metrics HAYF can use cautiously for body-composition goals.",
                    confidence: "medium",
                    evidence: ["hasBodyMass": "\(bodyTrend.bodyMassLatestKilograms != nil)", "hasBodyFat": "\(bodyTrend.bodyFatLatestPercentage != nil)"]
                )
            )
        }

        return insights
    }

    private func workoutWindowSummary(label: String, days: Int?, workouts: [HKWorkout]) -> WorkoutWindowSummary {
        let now = Date()
        let filtered: [HKWorkout]
        if let days, let startDate = Calendar.current.date(byAdding: .day, value: -days, to: now) {
            filtered = workouts.filter { $0.startDate >= startDate }
        } else {
            filtered = workouts
        }

        let totalDistance = filtered.compactMap(distanceKilometers).reduce(0, +)
        let totalEnergy = filtered.compactMap(energyKilocalories).reduce(0, +)
        let activityTypes = Array(Set(filtered.map { $0.workoutActivityType.displayName })).sorted()

        return WorkoutWindowSummary(
            window: label,
            workouts: filtered.count,
            totalMinutes: filtered.reduce(0) { $0 + $1.duration / 60 },
            totalDistanceKilometers: totalDistance > 0 ? totalDistance : nil,
            totalEnergyKilocalories: totalEnergy > 0 ? totalEnergy : nil,
            activityTypes: activityTypes
        )
    }

    private func workoutSummary(_ workout: HKWorkout) -> WorkoutSummary {
        WorkoutSummary(
            type: workout.workoutActivityType.displayName,
            startDate: workout.startDate,
            durationMinutes: workout.duration / 60,
            distanceKilometers: distanceKilometers(for: workout),
            energyKilocalories: energyKilocalories(for: workout)
        )
    }

    private func actualWorkoutSummary(_ workout: HKWorkout) -> HealthActualWorkoutSummary {
        HealthActualWorkoutSummary(
            healthkitUUID: workout.uuid.uuidString.lowercased(),
            startDate: workout.startDate,
            activityType: workout.workoutActivityType.displayName,
            durationMinutes: max(1, Int((workout.duration / 60).rounded())),
            distanceKilometers: distanceKilometers(for: workout),
            energyKilocalories: energyKilocalories(for: workout)
        )
    }

    private func distanceKilometers(for workout: HKWorkout) -> Double? {
        workout.totalDistance?.doubleValue(for: .meter()).nonZero.map { $0 / 1000 }
    }

    private func energyKilocalories(for workout: HKWorkout) -> Double? {
        workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()).nonZero
    }

    private func normalizedModality(for workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .cycling, .handCycling:
            return "cycling"
        case .running:
            return "running"
        case .walking, .hiking:
            return "walking"
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return "strength"
        case .highIntensityIntervalTraining, .mixedMetabolicCardioTraining, .mixedCardio, .crossTraining:
            return "hiit"
        case .yoga, .pilates, .flexibility, .preparationAndRecovery:
            return "mobility"
        case .swimming:
            return "swimming"
        case .tennis, .soccer, .basketball, .pickleball, .squash, .racquetball:
            return "sport"
        default:
            return workout.workoutActivityType.displayName.lowercased().replacingOccurrences(of: " ", with: "_")
        }
    }

    private func seasonLabel(for month: Int) -> String {
        switch month {
        case 12, 1, 2:
            return "winter"
        case 3, 4, 5:
            return "spring"
        case 6, 7, 8:
            return "summer"
        default:
            return "autumn"
        }
    }

    private func ratio(_ numerator: Double?, _ denominator: Double?) -> Double? {
        guard let numerator, let denominator, denominator > 0 else { return nil }
        return numerator / denominator
    }

    private func workoutsInLast(days: Int, workouts: [HKWorkout]) -> Int {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return 0
        }

        return workouts.filter { $0.startDate >= start }.count
    }

    private func fetchSleepHoursLastNight() async throws -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfToday = calendar.dateInterval(of: .day, for: now)?.start,
              let previousEvening = calendar.date(byAdding: .hour, value: -6, to: startOfToday),
              let noonToday = calendar.date(byAdding: .hour, value: 12, to: startOfToday) else {
            return nil
        }

        let endDate = min(now, noonToday)
        let predicate = HKQuery.predicateForSamples(withStart: previousEvening, end: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }

                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }

            healthStore.execute(query)
        }

        let seconds = mergedAsleepDuration(samples: samples, windowStart: previousEvening, windowEnd: endDate)

        guard seconds > 0 else {
            return nil
        }

        return seconds / 3600
    }

    private func fetchAverageSleepHours(days: Int) async throws -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let startDate = Calendar.current.date(byAdding: .day, value: -days - 1, to: Date()) else {
            return nil
        }

        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now)
        let samples: [HKCategorySample] = try await fetchSamples(sampleType: sleepType, predicate: predicate)

        let calendar = Calendar.current
        guard let startOfToday = calendar.dateInterval(of: .day, for: now)?.start else {
            return nil
        }

        let nightlyHours = (0..<days).compactMap { offset -> Double? in
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: startOfToday),
                  let windowStart = calendar.date(byAdding: .hour, value: -6, to: dayStart),
                  let windowEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart) else {
                return nil
            }

            let seconds = mergedAsleepDuration(samples: samples, windowStart: windowStart, windowEnd: min(windowEnd, now))
            return seconds > 0 ? seconds / 3600 : nil
        }

        guard !nightlyHours.isEmpty else {
            return nil
        }

        return nightlyHours.reduce(0, +) / Double(nightlyHours.count)
    }

    private var asleepSampleValues: Set<Int> {
        [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
    }

    private func mergedAsleepDuration(samples: [HKCategorySample], windowStart: Date, windowEnd: Date) -> TimeInterval {
        let intervals = samples
            .filter { asleepSampleValues.contains($0.value) }
            .compactMap { sample -> DateInterval? in
                let start = max(sample.startDate, windowStart)
                let end = min(sample.endDate, windowEnd)
                guard end > start else { return nil }
                return DateInterval(start: start, end: end)
            }
            .sorted { $0.start < $1.start }

        var merged: [DateInterval] = []
        for interval in intervals {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }

            if interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }

        return merged.reduce(0) { $0 + $1.duration }
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
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: 0)
                        return
                    }

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
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }

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

    private func fetchDailyAverage(identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async throws -> Double? {
        guard let total = try await fetchCumulativeQuantity(identifier: identifier, unit: unit, days: days) else {
            return nil
        }

        return total / Double(days)
    }

    private func fetchCumulativeQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async throws -> Double? {
        try await fetchStatisticsQuantity(identifier: identifier, unit: unit, days: days, options: .cumulativeSum)
    }

    private func fetchAverageQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async throws -> Double? {
        try await fetchStatisticsQuantity(identifier: identifier, unit: unit, days: days, options: .discreteAverage)
    }

    private func fetchStatisticsQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, options: HKStatisticsOptions) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier),
              let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options) { _, statistics, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }

                    continuation.resume(throwing: error)
                    return
                }

                let quantity: HKQuantity?
                if options.contains(.cumulativeSum) {
                    quantity = statistics?.sumQuantity()
                } else {
                    quantity = statistics?.averageQuantity()
                }

                continuation.resume(returning: quantity?.doubleValue(for: unit).nonZero)
            }

            healthStore.execute(query)
        }
    }

    private func fetchLatestQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> (value: Double?, date: Date?)? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let samples: [HKQuantitySample] = try await fetchSamples(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor])
        guard let sample = samples.first else {
            return nil
        }

        return (sample.quantity.doubleValue(for: unit), sample.endDate)
    }

    private func fetchNutritionSummary(days: Int) async throws -> NutritionFeatureSummary {
        async let energy = fetchNutritionDailyAverageAndDays(identifier: .dietaryEnergyConsumed, unit: .kilocalorie(), days: days)
        async let protein = fetchNutritionDailyAverageAndDays(identifier: .dietaryProtein, unit: .gram(), days: days)
        async let carbs = fetchNutritionDailyAverageAndDays(identifier: .dietaryCarbohydrates, unit: .gram(), days: days)
        async let fat = fetchNutritionDailyAverageAndDays(identifier: .dietaryFatTotal, unit: .gram(), days: days)
        async let sugar = fetchNutritionDailyAverageAndDays(identifier: .dietarySugar, unit: .gram(), days: days)
        async let fiber = fetchNutritionDailyAverageAndDays(identifier: .dietaryFiber, unit: .gram(), days: days)
        async let water = fetchNutritionDailyAverageAndDays(identifier: .dietaryWater, unit: .liter(), days: days)
        async let latestEnergy = fetchLatestQuantity(identifier: .dietaryEnergyConsumed, unit: .kilocalorie())

        let energyResult = try await energy
        let proteinResult = try await protein
        let carbsResult = try await carbs
        let fatResult = try await fat
        let sugarResult = try await sugar
        let fiberResult = try await fiber
        let waterResult = try await water

        return try await NutritionFeatureSummary(
            lastLoggedAt: latestEnergy?.date,
            daysWithEnergyLogged28Days: energyResult.daysWithData,
            averageEnergy28DaysKilocalories: energyResult.average,
            averageProtein28DaysGrams: proteinResult.average,
            averageCarbohydrates28DaysGrams: carbsResult.average,
            averageFat28DaysGrams: fatResult.average,
            averageSugar28DaysGrams: sugarResult.average,
            averageFiber28DaysGrams: fiberResult.average,
            averageWater28DaysLiters: waterResult.average
        )
    }

    private func fetchNutritionDailyAverageAndDays(identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async throws -> (average: Double?, daysWithData: Int) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier),
              let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()),
              let anchorDate = Calendar.current.dateInterval(of: .day, for: Date())?.start else {
            return (nil, 0)
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let interval = DateComponents(day: 1)

        let totals: [Double] = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }

                    continuation.resume(throwing: error)
                    return
                }

                var values: [Double] = []
                results?.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    values.append(statistics.sumQuantity()?.doubleValue(for: unit) ?? 0)
                }
                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }

        let nonZeroTotals = totals.filter { $0 > 0 }
        guard !nonZeroTotals.isEmpty else {
            return (nil, 0)
        }

        return (nonZeroTotals.reduce(0, +) / Double(nonZeroTotals.count), nonZeroTotals.count)
    }

    private func fetchLatestQuantityValue(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: nil)
                        return
                    }

                    continuation.resume(throwing: error)
                    return
                }

                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func fetchSamples<Sample: HKSample>(
        sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int = HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async throws -> [Sample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors) { _, samples, error in
                if let error {
                    if Self.isNoDataError(error) {
                        continuation.resume(returning: [])
                        return
                    }

                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [Sample]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private static func isNoDataError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == HKErrorDomain && nsError.code == HKError.Code.errorNoData.rawValue
    }

    private func buildSnapshotNotes(workouts: [HKWorkout], nutrition: NutritionFeatureSummary, sleep14: Double?) -> [String] {
        var notes: [String] = []

        if workouts.isEmpty {
            notes.append("No workouts were returned from the import window.")
        }

        if nutrition.daysWithEnergyLogged28Days == 0 {
            notes.append("No recent nutrition energy logs were returned; nutrition features may be absent or stale.")
        }

        if sleep14 == nil {
            notes.append("No usable sleep average was returned for the last 14 days.")
        }

        notes.append("HealthKit remains the source of truth. HAYF computed deterministic features locally before any AI call.")
        return notes
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

private extension Double {
    var nonZero: Double? {
        self > 0 ? self : nil
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .americanFootball: return "American football"
        case .archery: return "Archery"
        case .australianFootball: return "Australian football"
        case .badminton: return "Badminton"
        case .baseball: return "Baseball"
        case .basketball: return "Basketball"
        case .bowling: return "Bowling"
        case .boxing: return "Boxing"
        case .climbing: return "Climbing"
        case .cooldown: return "Cooldown"
        case .coreTraining: return "Core training"
        case .cricket: return "Cricket"
        case .crossTraining: return "Cross training"
        case .crossCountrySkiing: return "Cross-country skiing"
        case .curling: return "Curling"
        case .cycling: return "Cycling"
        case .dance: return "Dance"
        case .danceInspiredTraining: return "Dance training"
        case .discSports: return "Disc sports"
        case .downhillSkiing: return "Downhill skiing"
        case .elliptical: return "Elliptical"
        case .equestrianSports: return "Equestrian sports"
        case .fencing: return "Fencing"
        case .fishing: return "Fishing"
        case .fitnessGaming: return "Fitness gaming"
        case .flexibility: return "Flexibility"
        case .functionalStrengthTraining: return "Functional strength"
        case .golf: return "Golf"
        case .gymnastics: return "Gymnastics"
        case .handCycling: return "Hand cycling"
        case .handball: return "Handball"
        case .highIntensityIntervalTraining: return "HIIT"
        case .hiking: return "Hiking"
        case .hockey: return "Hockey"
        case .hunting: return "Hunting"
        case .jumpRope: return "Jump rope"
        case .kickboxing: return "Kickboxing"
        case .lacrosse: return "Lacrosse"
        case .martialArts: return "Martial arts"
        case .mindAndBody: return "Mind and body"
        case .mixedCardio: return "Mixed cardio"
        case .mixedMetabolicCardioTraining: return "Mixed metabolic cardio"
        case .other: return "Other"
        case .paddleSports: return "Paddle sports"
        case .pickleball: return "Pickleball"
        case .pilates: return "Pilates"
        case .play: return "Play"
        case .preparationAndRecovery: return "Preparation and recovery"
        case .racquetball: return "Racquetball"
        case .rowing: return "Rowing"
        case .rugby: return "Rugby"
        case .running: return "Running"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating"
        case .snowboarding: return "Snowboarding"
        case .snowSports: return "Snow sports"
        case .soccer: return "Football"
        case .socialDance: return "Social dance"
        case .softball: return "Softball"
        case .squash: return "Squash"
        case .stairClimbing: return "Stair climbing"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step training"
        case .surfingSports: return "Surfing"
        case .swimming: return "Swimming"
        case .tableTennis: return "Table tennis"
        case .taiChi: return "Tai chi"
        case .tennis: return "Tennis"
        case .trackAndField: return "Track and field"
        case .traditionalStrengthTraining: return "Traditional strength"
        case .transition: return "Transition"
        case .underwaterDiving: return "Underwater diving"
        case .volleyball: return "Volleyball"
        case .walking: return "Walking"
        case .waterFitness: return "Water fitness"
        case .waterPolo: return "Water polo"
        case .waterSports: return "Water sports"
        case .wheelchairRunPace: return "Wheelchair run pace"
        case .wheelchairWalkPace: return "Wheelchair walk pace"
        case .wrestling: return "Wrestling"
        case .yoga: return "Yoga"
        case .barre: return "Barre"
        case .cardioDance: return "Cardio dance"
        case .swimBikeRun: return "Swim bike run"
        @unknown default: return "Unknown"
        }
    }

    var isCycling: Bool {
        self == .cycling || self == .handCycling
    }

    var isRunning: Bool {
        self == .running
    }
}
