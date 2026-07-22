import { assertEquals } from "jsr:@std/assert@1";
import {
  compactProfileScoresForTrace,
  enrichBlueprintContext,
  mergeBlueprintProfileScores,
  redactBlueprintScoringInput,
  validAthleteProfileScores,
} from "./athlete-profile-scoring.ts";

const scores = {
  schemaVersion: "athlete-profile-scores.v1",
  scoreVersion: "profile-radar-v1.2.0",
  evaluatedAt: "2026-05-19T12:00:00.000Z",
  dimensions: ["consistency", "momentum", "strength", "training_base", "endurance"].map((key) => ({
    key,
    score: 80,
    status: "available",
    confidence: "high",
    components: [],
    evidenceIds: [],
  })),
  sourceSummary: { importedWorkoutCount: 100 },
};

Deno.test("validates canonical profile score order and rejects malformed service output", () => {
  assertEquals(validAthleteProfileScores(scores), true);
  const legacyScores = {
    ...scores,
    scoreVersion: "profile-radar-v1.1.0",
    dimensions: scores.dimensions.map((dimension) =>
      dimension.key === "training_base" ? { ...dimension, key: "goal_readiness" } : dimension
    ),
  };
  assertEquals(validAthleteProfileScores(legacyScores), true);
  assertEquals(validAthleteProfileScores({ ...scores, scoreVersion: "unknown" }), false);
  assertEquals(validAthleteProfileScores({ ...scores, dimensions: [...scores.dimensions].reverse() }), false);
});

Deno.test("keeps scores out of AI context and merges them after authored output", () => {
  assertEquals(enrichBlueprintContext({ intent: "stayConsistent" }, scores), { intent: "stayConsistent" });
  assertEquals(mergeBlueprintProfileScores({ coachRead: "Copy", profileScores: { scoreVersion: "model-authored" } }, scores), {
    coachRead: "Copy",
    profileScores: scores,
  });
  assertEquals(mergeBlueprintProfileScores({ coachRead: "Fallback" }, null), { coachRead: "Fallback", profileScores: null });
  assertEquals(compactProfileScoresForTrace(scores), {
    scoreVersion: "profile-radar-v1.2.0",
    status: "success",
    unavailableDimensions: [],
  });
});

Deno.test("keeps profile scores out of AI context for all three onboarding intents", () => {
  for (const intent of ["stayConsistent", "concreteGoal", "findGoal"]) {
    const context = enrichBlueprintContext({ intent }, scores);
    assertEquals(context.intent, intent);
    assertEquals("profileScores" in context, false);
  }
});

Deno.test("treats malformed service responses as a null-score fallback", () => {
  const malformed = { ...scores, dimensions: scores.dimensions.slice(0, 4) };
  assertEquals(validAthleteProfileScores(malformed), false);
  assertEquals(mergeBlueprintProfileScores({ coachRead: "Text fallback" }, null), {
    coachRead: "Text fallback",
    profileScores: null,
  });
});

Deno.test("redacts compact HealthKit scoring inputs from traces", () => {
  assertEquals(
    redactBlueprintScoringInput({ intent: "findGoal", scoringInput: { evidence: { totalWorkouts: 42 } } }),
    { intent: "findGoal" },
  );
});
