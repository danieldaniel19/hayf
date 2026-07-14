import assert from "node:assert/strict";
import { currentBodyMetricContext, healthSnapshotFreshness, workoutContinuityEvidence } from "./health-evidence.ts";

const now = new Date("2026-07-13T12:00:00Z");
const fixtureURL = new URL("../../../HAYFHealthKitPrototype/Health/Fixtures/daniel-health-snapshot.json", import.meta.url);
const fixture = JSON.parse(await Deno.readTextFile(fixtureURL));

Deno.test("historical Daniel fixture resolves to extended re-entry from its absolute workout date", () => {
  assert.equal(healthSnapshotFreshness(fixture, now).status, "stale");
  const continuity = workoutContinuityEvidence(fixture, now);
  assert.equal(continuity.days_since_last_workout, 55);
  assert.equal(continuity.state, "reentry");
  assert.equal(continuity.reentry_stage, "extended_gap");
  assert.equal(continuity.historical_base, "established");
});

Deno.test("stale year-long weight change remains historical instead of becoming a current leaning claim", () => {
  const context = currentBodyMetricContext(fixture.body.bodyMassHistory, fixture.body.bodyMassLatestSampleDate, 0.8, now);
  assert.equal(context.current, false);
  assert.equal(context.sampleAgeDays, 77);
  assert.equal(context.historical?.direction, "falling");
  assert.equal(context.historical?.change, -1.5);
});

Deno.test("recent dense body evidence can produce a current trajectory", () => {
  const context = currentBodyMetricContext({
    sampleCount: 8,
    trend: "falling",
    change: -2,
    daysCovered: 70,
    currentTrend: "falling",
    currentChange: -1.2,
    currentDaysCovered: 56,
    currentSampleCount: 6,
    currentConfidence: "high",
  }, "2026-07-10T07:00:00Z", 0.8, now);
  assert.equal(context.current, true);
  assert.equal(context.direction, "falling");
  assert.equal(context.change, -1.2);
  assert.equal(context.confidence, "high");
});
