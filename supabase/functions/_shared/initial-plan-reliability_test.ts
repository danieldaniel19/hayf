import {
  buildDeterministicInitialPlan,
  type InitialPlan,
  repairInitialPlanPrescriptions,
} from "./initial-plan-reliability.ts";

Deno.test("repairs the draft-style Base Ride that blocked onboarding", () => {
  const plan = planWithPrescription({
    warmup: "10 min easy",
    main: "Ride at a conversational effort",
    cooldown: "5 min easy",
    successCriteria: "Finish in control",
  });

  const repaired = repairInitialPlanPrescriptions(plan);
  const prescription = repaired.plan.rhythms[0].workouts[0].prescription;

  assertEquals(repaired.repairedWorkoutCount, 1);
  assertEquals(prescription.schemaVersion, 2);
  assert(typeof prescription.whyToday === "string");
  assert(String(prescription.whyToday).includes("Program Week 1"));
});

Deno.test("keeps a valid version two prescription intact", () => {
  const original = repairInitialPlanPrescriptions(planWithPrescription({})).plan
    .rhythms[0].workouts[0].prescription;
  const plan = planWithPrescription(original);

  const repaired = repairInitialPlanPrescriptions(plan);

  assertEquals(repaired.repairedWorkoutCount, 0);
  assert(repaired.plan.rhythms[0].workouts[0].prescription === original);
});

Deno.test("deterministic recovery plan honors weekdays and emits complete prescriptions", () => {
  const plan = buildDeterministicInitialPlan({
    kind: "consistency",
    blockTitle: "Consistency Rhythm",
    goalText: "Train four times each week",
    targetDate: null,
    reviewCadenceDays: 28,
    programStartDate: "2026-07-20",
    ownerStartDate: "2026-07-18",
    rhythmSpecs: [
      {
        programStage: "launch",
        programWeekNumber: null,
        weekStartDate: "2026-07-13",
        maximumSessions: 2,
      },
      {
        programStage: "program",
        programWeekNumber: 1,
        weekStartDate: "2026-07-20",
      },
      {
        programStage: "program",
        programWeekNumber: 2,
        weekStartDate: "2026-07-27",
      },
    ],
    availableDays: ["monday", "wednesday", "friday", "saturday"],
    priorityModalities: ["cycling", "strength"],
    sessionsPerProgramWeek: 4,
  });

  assertEquals(plan.rhythms.length, 3);
  assertEquals(plan.rhythms[0].workouts.length, 1);
  assertEquals(plan.rhythms[0].workouts[0].scheduledDate, "2026-07-18");
  assertEquals(plan.rhythms[1].workouts.length, 4);
  assert(
    plan.rhythms.flatMap((rhythm) => rhythm.workouts).every((workout) => (
      workout.prescription.schemaVersion === 2 &&
      Boolean(workout.prescription.whyToday)
    )),
  );
  assert(plan.rhythms.every((rhythm) => (
    rhythm.modalityTargets.reduce((sum, target) => sum + target.sessions, 0) ===
      rhythm.workouts.length
  )));
});

function planWithPrescription(
  prescription: Record<string, unknown>,
): InitialPlan {
  return {
    block: {
      kind: "consistency",
      title: "Consistency Rhythm",
      goalText: "Train consistently",
      startDate: "2026-07-20",
      targetDate: null,
      reviewCadenceDays: 28,
      context: {},
    },
    phases: [],
    rhythms: [{
      weekStartDate: "2026-07-20",
      weekEndDate: "2026-07-26",
      programStage: "program",
      programWeekNumber: 1,
      programStartDate: "2026-07-20",
      weekContext: { strategyExplanation: "Build a repeatable week." },
      modalityTargets: [{ modality: "ride", sessions: 1 }],
      objective: "Build rhythm",
      priorityOrder: ["ride"],
      hardEasyDistribution: { easy: 1 },
      badDayFloor: "10 minutes easy",
      swapRules: [],
      workouts: [{
        scheduledDate: "2026-07-20",
        sequenceOrder: 1,
        archetypeId: "cycling_endurance_ride",
        activityType: "ride",
        title: "Base Ride",
        durationMinutes: 45,
        intensityLabel: "Easy",
        purpose: "Build aerobic rhythm",
        prescription,
        fuelingSummary: "Carbs + water",
      }],
    }],
  };
}

function assert(value: unknown, message = "Expected value to be truthy") {
  if (!value) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Values differ. Actual: ${JSON.stringify(actual)} Expected: ${
        JSON.stringify(expected)
      }`,
    );
  }
}
