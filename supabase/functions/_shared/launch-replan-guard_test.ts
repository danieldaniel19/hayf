import {
  guardLaunchReplanMutations,
  launchPlanReviewRules,
} from "./launch-replan-guard.ts";

Deno.test("launch replan keeps only the missing target modality", () => {
  const weeklyPlans = [{
    id: "launch-week",
    rhythm_json: {
      programStage: "launch",
      modalityTargets: [
        { modality: "cycling", sessions: 1 },
        { modality: "strength", sessions: 1 },
      ],
    },
  }];
  const workouts = [
    {
      weekly_plan_id: "launch-week",
      activity_type: "ride",
      status: "missed",
      source: "generated",
    },
    {
      weekly_plan_id: "launch-week",
      activity_type: "run",
      status: "current",
      source: "user_added",
    },
    {
      weekly_plan_id: "launch-week",
      activity_type: "strength",
      status: "deleted",
      source: "user_deleted",
    },
  ];
  const mutations = [
    createWorkout("launch-week", "ride", "Easy Endurance Ride"),
    createWorkout("launch-week", "strength", "Strength Maintenance"),
    createWorkout("launch-week", "ride", "Recovery Ride"),
  ];

  const result = guardLaunchReplanMutations(mutations, weeklyPlans, workouts);

  assertEquals(result.removedCreateCount, 2);
  assertEquals(result.mutations.map((mutation) => mutationTitle(mutation)), [
    "Strength Maintenance",
  ]);
});

Deno.test("launch replan blocks non-target additions and does not change program weeks", () => {
  const launchPlan = {
    id: "launch-week",
    rhythm_json: {
      programStage: "launch",
      modalityTargets: [{ modality: "cycling", sessions: 1 }],
    },
  };
  const programPlan = {
    id: "program-week",
    rhythm_json: {
      programStage: "program",
      modalityTargets: [{ modality: "cycling", sessions: 3 }],
    },
  };
  const launchRun = createWorkout("launch-week", "run", "Extra Run");
  const programRide = createWorkout("program-week", "ride", "Program Ride");

  const result = guardLaunchReplanMutations([launchRun, programRide], [
    launchPlan,
    programPlan,
  ], []);

  assertEquals(result.removedCreateCount, 1);
  assertEquals(result.mutations.map((mutation) => mutationTitle(mutation)), [
    "Program Ride",
  ]);
});

Deno.test("launch review rules make launch precedence explicit", () => {
  const rules = launchPlanReviewRules([{
    id: "launch-week",
    rhythm_json: { programStage: "launch", modalityTargets: [] },
  }]);

  assert(
    rules.some((rule) =>
      rule.includes("override Training Architecture weeklyBudget")
    ),
  );
  assert(rules.some((rule) => rule.includes("must not trigger quota filling")));
});

function createWorkout(
  weeklyPlanID: string,
  activityType: string,
  title: string,
) {
  return {
    type: "create_workout",
    fields: {
      weekly_plan_id: weeklyPlanID,
      activity_type: activityType,
      title,
    },
  };
}

function mutationTitle(mutation: Record<string, unknown>) {
  const fields = mutation.fields as Record<string, unknown>;
  return fields.title;
}

function assert(value: unknown, message = "Expected value to be truthy") {
  if (!value) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  const actualJSON = JSON.stringify(actual);
  const expectedJSON = JSON.stringify(expected);
  if (actualJSON !== expectedJSON) {
    throw new Error(
      `Values differ.\nActual: ${actualJSON}\nExpected: ${expectedJSON}`,
    );
  }
}
