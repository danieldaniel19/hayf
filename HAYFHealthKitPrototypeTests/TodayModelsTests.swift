import XCTest
@testable import HAYF

final class TodayModelsTests: XCTestCase {
    func testBriefingOrdersSessionsBySequenceOrder() throws {
        let briefing = try decode(TodayBriefingOutput.self, json: briefingJSON(sessionOrders: [3, 1, 2]))
        XCTAssertEqual(briefing.orderedSessions.map(\.workout.sequenceOrder), [1, 2, 3])
        XCTAssertEqual(briefing.state, .planned)
    }

    func testActualWorkoutKeepsUnavailableMetricsNil() throws {
        let actual = try decode(TodayActualWorkout.self, json: """
        {
          "id":"10000000-0000-0000-0000-000000000001",
          "startDate":"2026-07-15T07:00:00Z",
          "activityType":"cycling",
          "durationMinutes":45,
          "distanceKilometers":null,
          "energyKilocalories":null,
          "loadValue":null,
          "averageHeartRateBPM":null,
          "maxHeartRateBPM":null
        }
        """)
        XCTAssertEqual(actual.durationMinutes, 45)
        XCTAssertNil(actual.distanceKilometers)
        XCTAssertNil(actual.averageHeartRateBPM)
    }

    func testFatigueDecodesUnknownLowConfidenceEvidence() throws {
        let fatigue = try decode(TodayFatigueEstimate.self, json: """
        {
          "level":"unknown",
          "confidence":"low",
          "freshness":"stale",
          "factors":["Recovery evidence is not recent enough"],
          "evidenceAt":"2026-07-10T07:00:00Z",
          "adjustmentSuggested":false,
          "influence":"HAYF does not have enough fresh evidence to estimate fatigue confidently."
        }
        """)
        XCTAssertEqual(fatigue.level, "unknown")
        XCTAssertEqual(fatigue.confidence, "low")
        XCTAssertFalse(fatigue.adjustmentSuggested ?? true)
    }

    func testActionRecommendationDecodesMoveOptions() throws {
        let output = try decode(TodayWorkoutActionRecommendation.self, json: """
        {
          "userID":"10000000-0000-0000-0000-000000000001",
          "model":"deterministic",
          "workoutID":"20000000-0000-0000-0000-000000000001",
          "action":"move",
          "coachRead":"A later slot preserves the session.",
          "weeklyImpact":"Recovery spacing remains workable.",
          "moveOptions":[{"date":"2026-07-17","rationale":"The next open slot."}],
          "workoutOptions":[],
          "usedFallback":true
        }
        """)
        XCTAssertEqual(output.action, .move)
        XCTAssertEqual(output.moveOptions.first?.date, "2026-07-17")
        XCTAssertTrue(output.usedFallback)
    }

    func testCompletedSessionDecodesDeviationAndFeedback() throws {
        let session = try decode(TodaySession.self, json: sessionJSON(order: 1, state: "completed", completed: true))
        XCTAssertEqual(session.state, .completed)
        XCTAssertEqual(session.actualWorkout?.durationMinutes, 52)
        XCTAssertTrue(session.deviation?.needsReview ?? false)
        XCTAssertEqual(session.feedback?.perceivedEffort, 8)
    }

    func testTodayCopyCompactsWeekPillWithoutClipping() {
        XCTAssertEqual(
            TodayCopy.compactWeekLabel("Use two familiar sessions to bridge into Program Week 1."),
            "two familiar sessions"
        )
        XCTAssertLessThanOrEqual(TodayCopy.compactWeekLabel("Build a deliberately very long weekly objective").count, 26)
    }

    func testWorkoutSummaryTurnsDenseCopyIntoReadableLines() {
        let lines = TodayCopy.workoutSummaryLines(
            "Warm up 5,10 min easy spinning; plan 35,40 min conversational pace, hydrate beforehand."
        )
        XCTAssertEqual(lines, [
            "Warm up 5–10 min easy spinning",
            "Plan 35–40 min conversational pace",
            "Hydrate beforehand",
        ])
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func briefingJSON(sessionOrders: [Int]) -> String {
        let sessions = sessionOrders.map { sessionJSON(order: $0, state: "planned", completed: false) }.joined(separator: ",")
        return """
        {
          "userID":"10000000-0000-0000-0000-000000000001",
          "model":"deterministic",
          "date":"2026-07-15",
          "timezone":"Europe/Berlin",
          "state":"planned",
          "cacheHit":false,
          "generation":{},
          "strategy":{"id":"30000000-0000-0000-0000-000000000001","title":"Build durable cycling","summary":"Build capacity","rationale":"Consistency"},
          "phase":null,
          "week":null,
          "headline":"Your full day",
          "strategyFit":"Build useful aerobic work.",
          "importance":"Spacing matters.",
          "conditions":{"weather":null,"fatigue":{"level":"unknown","confidence":"low","freshness":"missing","factors":[],"evidenceAt":null,"adjustmentSuggested":false,"influence":"Evidence is missing."}},
          "sessions":[\(sessions)],
          "tomorrowPreview":null,
          "replanReview":{"status":"none","proposalID":null,"reason":null,"summary":null,"mutationCount":0}
        }
        """
    }

    private func sessionJSON(order: Int, state: String, completed: Bool) -> String {
        let id = String(format: "20000000-0000-0000-0000-%012d", order)
        let actual = completed ? """
        {"id":"40000000-0000-0000-0000-000000000001","startDate":"2026-07-15T07:00:00Z","activityType":"cycling","durationMinutes":52,"distanceKilometers":20.4,"energyKilocalories":430,"loadValue":78,"averageHeartRateBPM":151,"maxHeartRateBPM":181}
        """ : "null"
        let deviation = completed ? "{\"needsReview\":true,\"duration\":{},\"intensity\":{}}" : "null"
        let feedback = completed ? "{\"perceived_effort\":8,\"felt_rating\":3,\"pain_flag\":false,\"pain_notes\":null,\"difficulty_label\":\"too_hard\",\"free_text\":null}" : "null"
        return """
        {
          "workout":{"id":"\(id)","scheduledDate":"2026-07-15","sequenceOrder":\(order),"activityType":"cycling","title":"Session \(order)","durationMinutes":45,"estimatedDistanceKilometers":null,"estimatedElevationMeters":null,"intensityLabel":"Low","purpose":"Aerobic support","status":"\(completed ? "done" : "planned")","source":"generated","fuelingSummary":null,"prescription":{},"plannedLocationLabel":null,"weatherForecast":{}},
          "actualWorkout":\(actual),
          "state":"\(state)",
          "deviation":\(deviation),
          "feedback":\(feedback),
          "debriefRequest":null,
          "briefing":{"workoutID":"\(id)","preBrief":"Support the strategy.","postBrief":"The workout is logged.","weeklyImpact":"Review the week."}
        }
        """
    }
}

final class OnboardingPolicyTests: XCTestCase {
    func testOnlySupportedModalitiesAreEnabled() {
        XCTAssertEqual(
            Set(TrainingOption.allCases.filter(\.isOnboardingEnabled)),
            Set([.cycling, .strength, .running])
        )
        var draft = ConsistencyOnboardingDraft()
        draft.toggleTrainingOption(.swimming)
        XCTAssertTrue(draft.trainingOptions.isEmpty)
    }

    func testUnsureMotivationIsMutuallyExclusive() {
        var draft = ConsistencyOnboardingDraft()
        draft.toggleMotivationAnchor(.dailyEnergy)
        draft.toggleMotivationAnchor(.unsure)
        XCTAssertEqual(draft.motivationAnchors, [.unsure])
        draft.toggleMotivationAnchor(.longTermHealth)
        XCTAssertEqual(draft.motivationAnchors, [.longTermHealth])
    }

    func testUltraFlexibleAvailabilityAndManualOverride() {
        var draft = ConsistencyOnboardingDraft()
        draft.toggleUltraFlexibleAvailability()
        XCTAssertTrue(draft.ultraFlexibleAvailability)
        XCTAssertEqual(draft.availableDays, Set(Weekday.allCases))
        XCTAssertEqual(draft.availableDayParts, Set(DayPart.allCases))

        draft.setAvailableDays([.monday, .wednesday])
        XCTAssertFalse(draft.ultraFlexibleAvailability)
        XCTAssertEqual(draft.availableDays, [.monday, .wednesday])
    }

    func testVariableSessionLengthHasNoNumericFallback() {
        XCTAssertEqual(SessionLength.varies.mode, "varies_by_modality")
        XCTAssertNil(SessionLength.varies.minutes)
        XCTAssertEqual(SessionLength.thirty.minutes, 30)
    }

    func testMergedWeeklyCapacityRequiresFrequencyAndSessionLength() {
        var draft = ConsistencyOnboardingDraft()
        XCTAssertFalse(draft.hasWeeklyCapacity)

        draft.frequency = .changes
        XCTAssertFalse(draft.hasWeeklyCapacity)

        draft.sessionLength = .varies
        XCTAssertTrue(draft.hasWeeklyCapacity)
    }

    func testMergedCapacityReducesEveryOnboardingStreamByOneStep() {
        XCTAssertEqual(OnboardingStep.totalSegments(for: .stayConsistent), 16)
        XCTAssertEqual(OnboardingStep.totalSegments(for: .concreteGoal), 20)
        XCTAssertEqual(OnboardingStep.totalSegments(for: .findGoal), 20)

        XCTAssertEqual(OnboardingStep.weeklyCapacity.activeSegments(for: .stayConsistent), 5)
        XCTAssertEqual(OnboardingStep.weeklyAvailability.activeSegments(for: .stayConsistent), 6)
        XCTAssertEqual(OnboardingStep.weeklyCapacity.activeSegments(for: .concreteGoal), 8)
        XCTAssertEqual(OnboardingStep.weeklyAvailability.activeSegments(for: .findGoal), 9)
    }

    func testAdultBodyFatEstimateUsesBMIProfileAgeAndPhysiology() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let birthdate = try XCTUnwrap(calendar.date(from: DateComponents(year: 1996, month: 1, day: 1)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let male = try XCTUnwrap(BodyFatEstimator.estimate(
            bodyMassKilograms: 80,
            heightCentimeters: 180,
            birthdate: birthdate,
            physiologyReference: .male,
            now: now,
            calendar: calendar
        ))
        let female = try XCTUnwrap(BodyFatEstimator.estimate(
            bodyMassKilograms: 80,
            heightCentimeters: 180,
            birthdate: birthdate,
            physiologyReference: .female,
            now: now,
            calendar: calendar
        ))
        XCTAssertEqual(male, 20.33, accuracy: 0.02)
        XCTAssertEqual(female - male, 10.8, accuracy: 0.001)
        XCTAssertEqual(BodyFatBand.band(containing: male, for: .male), .maleAbove20)
        XCTAssertEqual(BodyFatBand.band(containing: 24, for: .female), .female21To25)
    }

    func testBodyFatProvenanceDistinguishesManualAndFormulaSelections() throws {
        var draft = ConsistencyOnboardingDraft()
        draft.bodyMassKilogramsInput = "80"
        draft.heightCentimetersInput = "180"
        draft.selectBodyFatBand(.male17To20)
        var payload = try XCTUnwrap(BodyBaselinePayload(draft: draft))
        XCTAssertEqual(payload.source, "self_reported_band")
        XCTAssertEqual(payload.confidence, "estimated_band")

        draft.selectEstimatedBodyFat(20.3, physiologyReference: .male)
        payload = try XCTUnwrap(BodyBaselinePayload(draft: draft))
        XCTAssertEqual(payload.source, "bmi_age_physiology_estimate")
        XCTAssertEqual(payload.confidence, "rough_anthropometric_estimate")
        XCTAssertEqual(payload.bodyFatEstimateMidpoint, 20.3, accuracy: 0.001)
    }

    func testVariableBadDayFloorSerializesAsModelDiscretion() {
        XCTAssertTrue(BadDayFloor.varies.planningValue.hasPrefix("Model discretion:"))
        XCTAssertNotEqual(BadDayFloor.varies.planningValue, BadDayFloor.varies.title)
    }

    func testRemovedBlockersStayUnavailableAndWeatherRemains() {
        let titles = Set(ConsistencyBlocker.allCases.map(\.title))
        XCTAssertTrue(titles.contains("Weather"))
        XCTAssertTrue(titles.contains("Not having a plan"))
        XCTAssertFalse(titles.contains("Gym access"))
        XCTAssertFalse(titles.contains("All-or-nothing weeks"))
    }

    func testSummaryReadbackEnforcesCompactInterpretation() {
        XCTAssertTrue(OnboardingSummaryOutput.isValidReadback(
            "You are looking for a consistent five-day routine that can withstand low energy and travel."
        ))
        XCTAssertFalse(OnboardingSummaryOutput.isValidReadback("Consistent training needs an adaptable rhythm that can withstand low energy and frequent travel."))
        XCTAssertFalse(OnboardingSummaryOutput.isValidReadback("You chose cycling, strength, Monday, Tuesday, a gym, mornings, and a short fallback."))
        XCTAssertFalse(OnboardingSummaryOutput.isValidReadback(String(repeating: "A", count: 121)))
    }
}
