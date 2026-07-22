import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { dimensionOrder, interpolate, rubricCurves, scoreAthleteProfile, type ProfileScoringRequest } from "../src/scoring.js";

const now = "2026-05-19T12:00:00.000Z";

function richRequest(overrides: Partial<ProfileScoringRequest> = {}): ProfileScoringRequest {
  const base: ProfileScoringRequest = {
    schemaVersion: "athlete-profile-scoring-input.v1",
    evaluatedAt: now,
    intent: "concreteGoal",
    normalizedGoal: { category: "endurance", horizonWeeks: 12 },
    availability: { targetSessionsPerWeek: 3, availableDaysCount: 4, ultraFlexible: false },
    feasibleModalities: ["running", "strength"],
    evidence: {
      snapshotGeneratedAt: "2026-05-19T11:00:00.000Z",
      totalWorkouts: 837,
      lastWorkoutAt: "2026-05-19T06:19:24.000Z",
      windows: {
        days7: { workouts: 5, totalMinutes: 458 },
        days28: { workouts: 22, totalMinutes: 2178 },
      },
      consistency: { weeksAnalyzed: 313, activeWeeks: 231, longestActiveWeekStreak: 44 },
      modalityMix: [
        { modality: "cycling", workouts: 249, shareOfMinutes: 0.54, lastWorkoutAt: "2026-05-19T06:00:00.000Z" },
        { modality: "strength", workouts: 307, shareOfMinutes: 0.25, lastWorkoutAt: "2026-05-19T06:19:24.000Z" },
        { modality: "running", workouts: 150, shareOfMinutes: 0.08, lastWorkoutAt: "2026-05-18T06:00:00.000Z" },
      ],
      strengthContinuity: { strengthWorkouts90Days: 17, daysSinceLastStrength: 0 },
      longestWorkouts: [
        { modality: "cycling", durationMinutes: 1190 },
        { modality: "running", durationMinutes: 117 },
      ],
      bestDistanceEfforts: [{ modality: "cycling" }, { modality: "running" }],
    },
  };
  return { ...base, ...overrides };
}

test("interpolates, clamps, and preserves curve endpoints", () => {
  const curve: Array<readonly [number, number]> = [[0, 0], [10, 100]];
  assert.equal(interpolate(-2, curve), 0);
  assert.equal(interpolate(5, curve), 50);
  assert.equal(interpolate(20, curve), 100);
});

test("preserves every published rubric boundary", () => {
  for (const [curveName, points] of Object.entries(rubricCurves)) {
    for (const [input, expected] of points) {
      assert.equal(interpolate(input, [...points]), expected, `${curveName} at ${input}`);
    }
  }
});

test("returns stable dimension order and bounded integer scores for a rich hybrid", () => {
  const result = scoreAthleteProfile(richRequest());
  assert.deepEqual(result.dimensions.map((item) => item.key), dimensionOrder);
  assert.equal(result.scoreVersion, "profile-radar-v1.2.0");
  assert.equal(result.sourceSummary.importedWorkoutCount, 837);
  for (const item of result.dimensions) {
    assert.equal(item.status, "available");
    assert.equal(Number.isInteger(item.score), true);
    assert.ok((item.score ?? -1) >= 0 && (item.score ?? 101) <= 100);
  }
});

test("scores trustworthy absence of strength as zero rather than missing", () => {
  const request = richRequest();
  request.normalizedGoal.category = "endurance";
  request.feasibleModalities = ["running"];
  request.evidence!.modalityMix = [{ modality: "running", workouts: 80, shareOfMinutes: 1 }];
  request.evidence!.strengthContinuity = { strengthWorkouts90Days: 0, daysSinceLastStrength: null };
  const strength = scoreAthleteProfile(request).dimensions.find((item) => item.key === "strength")!;
  assert.equal(strength.status, "available");
  assert.equal(strength.score, 0);
});

test("scores strength-led evidence independently from endurance", () => {
  const request = richRequest();
  request.normalizedGoal.category = "strength";
  request.feasibleModalities = ["strength"];
  request.evidence!.modalityMix = [{ modality: "strength", workouts: 180, shareOfMinutes: 1 }];
  request.evidence!.longestWorkouts = [];
  request.evidence!.bestDistanceEfforts = [];
  const result = scoreAthleteProfile(request);
  const strength = result.dimensions.find((item) => item.key === "strength")!;
  const endurance = result.dimensions.find((item) => item.key === "endurance")!;
  assert.ok((strength.score ?? 0) > (endurance.score ?? 100));
});

test("stale relative windows retain absolute recency and historical modality identity", () => {
  const request = richRequest();
  request.evidence!.snapshotGeneratedAt = "2026-05-10T00:00:00.000Z";
  const result = scoreAthleteProfile(request);
  assert.equal(result.dimensions.find((item) => item.key === "momentum")!.status, "available");
  assert.equal(result.dimensions.find((item) => item.key === "strength")!.status, "available");
  assert.equal(result.dimensions.find((item) => item.key === "endurance")!.status, "available");
});

test("sparse and no-HealthKit inputs remain unavailable rather than neutral", () => {
  const noHealth = richRequest({ evidence: null });
  assert.equal(scoreAthleteProfile(noHealth).dimensions.every((item) => item.status === "unavailable"), true);

  const sparse = richRequest();
  sparse.evidence!.totalWorkouts = 2;
  sparse.evidence!.consistency = { weeksAnalyzed: 2, activeWeeks: 2, longestActiveWeekStreak: 2 };
  sparse.evidence!.modalityMix = [];
  assert.equal(scoreAthleteProfile(sparse).dimensions.filter((item) => item.status === "available").length < 3, true);
});

test("interrupted and returning athletes lose momentum through recency", () => {
  const active = richRequest();
  const interrupted = richRequest();
  interrupted.evidence!.lastWorkoutAt = "2026-05-01T12:00:00.000Z";
  interrupted.evidence!.windows.days7 = { workouts: 0, totalMinutes: 0 };
  const returning = richRequest();
  returning.evidence!.lastWorkoutAt = "2026-03-01T12:00:00.000Z";
  returning.evidence!.windows.days7 = { workouts: 0, totalMinutes: 0 };
  const momentum = (request: ProfileScoringRequest) => scoreAthleteProfile(request).dimensions.find((item) => item.key === "momentum")!.score ?? 0;
  assert.ok(momentum(active) > momentum(interrupted));
  assert.ok(momentum(interrupted) > momentum(returning));
});

test("keeps training base stable across onboarding intents and goal categories", () => {
  const consistency = richRequest({ intent: "stayConsistent", normalizedGoal: { category: "consistency", horizonWeeks: 12 } });
  const concrete = richRequest({ intent: "concreteGoal", normalizedGoal: { category: "strength", horizonWeeks: 12 } });
  const discovery = richRequest({ intent: "findGoal", normalizedGoal: { category: "generalFitness", horizonWeeks: 8 } });
  const baseScores = [consistency, concrete, discovery].map((request) =>
    scoreAthleteProfile(request).dimensions.find((item) => item.key === "training_base")!.score
  );
  assert.deepEqual(baseScores, [baseScores[0], baseScores[0], baseScores[0]]);
});

test("keeps exactly 70 percent trustworthy coverage and rejects less", () => {
  const exactlySeventy = richRequest();
  exactlySeventy.evidence!.windows.days7 = null;
  exactlySeventy.evidence!.windows.days28 = null;
  const exactMomentum = scoreAthleteProfile(exactlySeventy).dimensions.find((item) => item.key === "momentum")!;
  assert.equal(exactMomentum.status, "available");
  assert.equal(exactMomentum.confidence, "low");

  const sixty = richRequest();
  sixty.evidence!.lastWorkoutAt = null;
  const lowCoverageMomentum = scoreAthleteProfile(sixty).dimensions.find((item) => item.key === "momentum")!;
  assert.equal(lowCoverageMomentum.status, "unavailable");
  assert.equal(lowCoverageMomentum.score, null);
});

test("re-entry profile separates durable history from current inactivity", () => {
  const request = richRequest({ evaluatedAt: "2026-07-22T20:00:00.000Z" });
  request.evidence!.snapshotGeneratedAt = "2026-05-19T20:17:36.000Z";
  request.evidence!.lastWorkoutAt = "2026-05-19T06:19:24.000Z";
  request.evidence!.modalityMix = [
    { modality: "cycling", workouts: 249, shareOfMinutes: 0.5414, lastWorkoutAt: "2026-05-17T09:18:14.000Z" },
    { modality: "strength", workouts: 307, shareOfMinutes: 0.2506, lastWorkoutAt: "2026-05-19T06:19:24.000Z" },
    { modality: "running", workouts: 150, shareOfMinutes: 0.0798, lastWorkoutAt: "2026-04-28T15:50:03.000Z" },
  ];
  const result = scoreAthleteProfile(request);
  const scores = Object.fromEntries(result.dimensions.map((dimension) => [dimension.key, dimension.score]));
  assert.deepEqual(scores, {
    consistency: 62,
    momentum: 0,
    strength: 57,
    training_base: 53,
    endurance: 73,
  });
});

test("runs the required profile fixtures through stable expected states", () => {
  const fixtures = JSON.parse(readFileSync(new URL("./fixtures/profiles.json", import.meta.url), "utf8")) as Array<{
    name: string;
    kind: string;
    expectedAvailable: string[];
  }>;
  for (const fixture of fixtures) {
    const request = requestForFixture(fixture.kind);
    const available = scoreAthleteProfile(request).dimensions.filter((item) => item.status === "available").map((item) => item.key);
    assert.deepEqual(available, fixture.expectedAvailable, fixture.name);
  }
});

function requestForFixture(kind: string): ProfileScoringRequest {
  const request = richRequest();
  if (kind === "richHybrid") return request;
  if (kind === "strengthOnly") {
    request.normalizedGoal.category = "strength";
    request.feasibleModalities = ["strength"];
    request.evidence!.modalityMix = [{ modality: "strength", workouts: 180, shareOfMinutes: 1 }];
    request.evidence!.longestWorkouts = [];
    request.evidence!.bestDistanceEfforts = [];
    return request;
  }
  if (kind === "enduranceOnly") {
    request.feasibleModalities = ["running"];
    request.evidence!.modalityMix = [{ modality: "running", workouts: 180, shareOfMinutes: 1 }];
    request.evidence!.strengthContinuity = { strengthWorkouts90Days: 0, daysSinceLastStrength: null };
    return request;
  }
  if (kind === "stale") request.evidence!.snapshotGeneratedAt = "2026-05-01T00:00:00.000Z";
  if (kind === "sparse") {
    request.evidence!.totalWorkouts = 2;
    request.evidence!.consistency = { weeksAnalyzed: 2, activeWeeks: 2, longestActiveWeekStreak: 2 };
    request.evidence!.modalityMix = [];
  }
  if (kind === "noHealthKit") request.evidence = null;
  if (kind === "interrupted") {
    request.evidence!.lastWorkoutAt = "2026-05-01T12:00:00.000Z";
    request.evidence!.windows.days7 = { workouts: 0, totalMinutes: 0 };
  }
  if (kind === "returningAthlete") {
    request.evidence!.lastWorkoutAt = "2026-03-01T12:00:00.000Z";
    request.evidence!.windows.days7 = { workouts: 0, totalMinutes: 0 };
  }
  return request;
}
