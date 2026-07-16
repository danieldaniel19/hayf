import { touchpointResponseMetadata } from "./ai-touchpoint-schemas.ts";
import { AI_TOUCHPOINT_CATALOG } from "./ai-touchpoint-catalog.ts";
import {
  deriveTodayFatigueEstimate,
  explanatoryStrategyTitle,
  isTodayBriefingCacheHit,
  todayDayState,
  todayInputFingerprint,
  workoutsForTodayPlan,
} from "./today-briefing.ts";

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

Deno.test("Today state reduction covers rest, planned, mixed, and completed agendas", () => {
  assert(todayDayState([]) === "rest", "empty agenda should be rest");
  assert(
    todayDayState([{ state: "planned" }]) === "planned",
    "open session should be planned",
  );
  assert(
    todayDayState([{ state: "completed" }, { state: "planned" }]) === "mixed",
    "partial agenda should be mixed",
  );
  assert(
    todayDayState([{ state: "completed" }, { state: "skipped" }]) ===
      "completed",
    "resolved agenda should be completed",
  );
});

Deno.test("Today keeps only the visible weekly plan and preserves canonical workout titles", () => {
  const workouts = [
    { id: "current", weekly_plan_id: "visible", title: "Easy Run" },
    { id: "old-1", weekly_plan_id: "obsolete-a", title: "Tempo Ride" },
    { id: "old-2", weekly_plan_id: "obsolete-b", title: "Full Body A" },
  ];
  const result = workoutsForTodayPlan(workouts, "visible");
  assert(
    result.length === 1,
    "obsolete weekly-plan workouts must not appear in Today",
  );
  assert(
    result[0].id === "current",
    "Today should retain the workout from the visible plan",
  );
  assert(
    result[0].title === "Easy Run",
    "Today must preserve the canonical planned-workout title",
  );
  assert(
    workoutsForTodayPlan(workouts, null).length === 0,
    "a date without a visible plan must be an open day",
  );
});

Deno.test("Strategy titles prefer explanatory goal context over generic fallbacks", () => {
  assert(
    explanatoryStrategyTitle(
      "Goal Build Strategy",
      "Cycling fitness and lean muscle",
      "Active strategy",
    ) ===
      "Cycling fitness and lean muscle",
    "generic strategy titles should use the accepted goal label",
  );
  assert(
    explanatoryStrategyTitle(
      "My Alpine Build",
      "Cycling fitness",
      "Active strategy",
    ) === "My Alpine Build",
    "explicit strategy names must remain authoritative",
  );
});

Deno.test("Today fatigue is explicitly unknown for missing or stale evidence", () => {
  const missing = deriveTodayFatigueEstimate({
    freshness: "missing",
    evidenceAt: null,
    sleepHoursLastNight: null,
    averageSleepHours14Days: null,
    currentVsNinetyDayMinutesRatio: null,
    hasHRVBaseline: false,
    hasRestingHeartRateBaseline: false,
    hardSessionToday: true,
  });
  const stale = deriveTodayFatigueEstimate({
    freshness: "stale",
    evidenceAt: "2026-06-01T00:00:00Z",
    sleepHoursLastNight: 4,
    averageSleepHours14Days: 8,
    currentVsNinetyDayMinutesRatio: 2,
    hasHRVBaseline: true,
    hasRestingHeartRateBaseline: true,
    hardSessionToday: true,
  });
  assert(
    missing.level === "unknown" && missing.confidence === "low",
    "missing evidence must remain unknown",
  );
  assert(
    stale.level === "unknown" && stale.adjustmentSuggested === false,
    "stale evidence must not recommend an adjustment",
  );
});

Deno.test("Today fatigue uses deterministic normalized evidence without a readiness score", () => {
  const result = deriveTodayFatigueEstimate({
    freshness: "fresh",
    evidenceAt: "2026-07-15T06:00:00Z",
    sleepHoursLastNight: 5.5,
    averageSleepHours14Days: 7.5,
    currentVsNinetyDayMinutesRatio: 1.4,
    hasHRVBaseline: true,
    hasRestingHeartRateBaseline: true,
    hardSessionToday: true,
  });
  assert(
    result.level === "high",
    "combined strain signals should classify high fatigue",
  );
  assert(
    result.adjustmentSuggested === true,
    "high fatigue plus a hard session should suggest review",
  );
  assert(
    !("score" in result),
    "fatigue output must not fabricate a readiness score",
  );
});

Deno.test("Today briefing fingerprint is stable and invalidates when canonical evidence changes", async () => {
  const baseline = {
    date: "2026-07-15",
    workout: { id: "w1", status: "planned" },
    weather: { temperatureCelsius: 19 },
  };
  const first = await todayInputFingerprint(baseline);
  const second = await todayInputFingerprint(baseline);
  const changed = await todayInputFingerprint({
    ...baseline,
    workout: { id: "w1", status: "done" },
  });
  assert(first === second, "same evidence should have the same fingerprint");
  assert(first !== changed, "completion should invalidate the fingerprint");
  assert(
    isTodayBriefingCacheHit({
      input_fingerprint: first,
      briefing_json: { authored: { headline: "Ready" } },
    }, first),
    "valid authored cache should hit",
  );
  assert(
    !isTodayBriefingCacheHit(
      { input_fingerprint: first, briefing_json: {} },
      first,
    ),
    "cache without authored output should miss",
  );
  assert(
    !isTodayBriefingCacheHit({
      input_fingerprint: first,
      briefing_json: { authored: {} },
      generation_json: { status: "fallback" },
    }, first),
    "fallback cache should retry generation",
  );
});

Deno.test("Today AI contracts are strict, bounded, and ban raw HealthKit samples", () => {
  for (const id of ["today_briefing", "today_workout_action"]) {
    const metadata = touchpointResponseMetadata("planning", id);
    assert(metadata != null, `${id} response schema should exist`);
    assert(
      metadata?.schema.additionalProperties === false,
      `${id} schema should reject extra properties`,
    );
    const prompt = AI_TOUCHPOINT_CATALOG.planning[id].systemPrompt;
    assert(prompt.includes("strict JSON"), `${id} should require strict JSON`);
  }
  const prompt = AI_TOUCHPOINT_CATALOG.planning.today_briefing.systemPrompt;
  assert(
    prompt.includes("never invent a readiness score"),
    "briefing must prohibit readiness scores",
  );
  assert(
    !prompt.includes("raw heart-rate samples"),
    "the AI prompt must not request raw samples",
  );
});
