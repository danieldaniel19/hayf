import {
  availableDayPartsFromPlanningInputs,
  availableDaysFromPlanningInputs,
  badDayFloorFromPlanningInputs,
  filterEnabledOnboardingModalities,
  parseTimeframeWeeks,
  timeframeWeeksFromPlanningInputs,
} from "./planning-inputs.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`);
  }
}

Deno.test("parses human and structured timeframe values", () => {
  assertEquals(parseTimeframeWeeks("12 weeks"), 12);
  assertEquals(parseTimeframeWeeks("8 wks"), 8);
  assertEquals(parseTimeframeWeeks({ weeks: 4 }), 4);
  assertEquals(parseTimeframeWeeks("no deadline"), null);
  assertEquals(parseTimeframeWeeks("September 1, 2026"), null);
});

Deno.test("prefers explicit onboarding timeframe fields", () => {
  assertEquals(timeframeWeeksFromPlanningInputs({}, {
    goalTimeline: "12 weeks",
    goalTimelineWeeks: 12,
    chosenGoal: { timeline: { weeks: 8 } },
  }), 12);
  assertEquals(timeframeWeeksFromPlanningInputs({
    snapshotItems: [{ id: "timeframe", value: "16 weeks" }],
  }, {
    goalTimeline: "12 weeks",
    goalTimelineWeeks: 12,
    chosenGoal: { timeline: { weeks: 8 } },
  }), 12);
});

Deno.test("normalizes exact Swift and legacy availability shapes", () => {
  assertEquals(availableDaysFromPlanningInputs({
    availableDays: ["friday", "Monday", "wed"],
  }), ["monday", "wednesday", "friday"]);
  assertEquals(availableDayPartsFromPlanningInputs({
    availability: { dayParts: ["Evening", "AM", "Afternoons"] },
  }), ["morning", "afternoon", "evening"]);
});

Deno.test("expands explicit ultra-flexible availability", () => {
  assertEquals(availableDaysFromPlanningInputs({ ultraFlexibleAvailability: true }), [
    "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
  ]);
  assertEquals(availableDayPartsFromPlanningInputs({ ultraFlexibleAvailability: true }), [
    "morning", "afternoon", "evening",
  ]);
});

Deno.test("normalizes direct and object bad-day floor values", () => {
  assertEquals(badDayFloorFromPlanningInputs({ badDayFloor: "10-min walk or mobility" }), "10-min walk or mobility");
  assertEquals(badDayFloorFromPlanningInputs({ badDayFloor: { summary: "Do 15 minutes of mobility" } }), "Do 15 minutes of mobility");
});

Deno.test("keeps only onboarding-enabled modalities", () => {
  assertEquals(filterEnabledOnboardingModalities([
    "cycling", "swimming", "strength", "running", "walking", "cycling",
  ]), ["cycling", "strength", "running"]);
});
