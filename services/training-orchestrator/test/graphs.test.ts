import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { assertPlanningPacket, type PlanningPacket } from "../src/contracts.js";
import { invokeFitnessStrategyGraph } from "../src/graphs/fitness-strategy.js";
import { invokeTrainingArchitectureGraph } from "../src/graphs/training-architecture.js";
import { invokeTwoWeekPlanGraph } from "../src/graphs/two-week-plan.js";

describe("planning packet contract", () => {
  it("accepts compact planning packets", () => {
    assert.doesNotThrow(() => assertPlanningPacket(basePacket()));
  });

  it("rejects raw HealthKit workout ledgers", () => {
    const packet = {
      ...basePacket(),
      approved_evidence_summary: {
        ...basePacket().approved_evidence_summary,
        workoutLedger: [{ source: "HealthKit", samples: [] }],
      },
    };

    assert.throws(() => assertPlanningPacket(packet), /raw HealthKit workout ledgers/);
  });
});

describe("trainingArchitectureGraph", () => {
  it("routes cycling, strength, and running weight-loss goals through bounded specialists", async () => {
    const result = await invokeTrainingArchitectureGraph(basePacket({
      goal_kind: "specific_goal",
      selected_modality_order: ["Cycling", "Strength", "Running"],
      body_composition_intent: "fat_loss",
      normalized_goal: {
        title: "Lose weight while getting stronger and keeping cycling fitness",
        desiredOutcome: "lose weight, build strength, keep running and cycling",
      },
    }));

    assert.equal(result.artifact.priority_order[0], "cycling");
    assert.deepEqual(result.artifact.priority_order, ["cycling", "strength", "running"]);
    assert.equal(result.artifact.phase_logic.requires_phases, true);
    assert.equal(result.artifact.specialist_recommendations.length, 3);
    assert.ok(result.nodes.some((node) => node.node_name === "master_coach_synthesis"));
  });

  it("keeps consistency goals phase-free", async () => {
    const result = await invokeTrainingArchitectureGraph(basePacket({
      goal_kind: "consistency",
      selected_modality_order: ["Strength"],
      normalized_goal: {
        title: "Train consistently three times per week",
        desiredOutcome: "be consistent",
      },
    }));

    assert.equal(result.artifact.phase_logic.requires_phases, false);
    assert.equal(result.artifact.phase_logic.phases.length, 0);
  });

  it("flags impossible conflicting goals for explicit tradeoff handling", async () => {
    const result = await invokeTrainingArchitectureGraph(basePacket({
      selected_modality_order: ["Cycling", "Strength"],
      normalized_goal: {
        title: "Become a bodybuilder and win the Tour de France",
        desiredOutcome: "bodybuilder Tour de France",
      },
    }));

    assert.equal(result.artifact.conflict_assessment.status, "conflicting");
    assert.ok(result.artifact.conflict_assessment.required_tradeoffs.includes("maximal_hypertrophy_vs_grand_tour_endurance"));
  });

  it("still produces a conservative architecture when HealthKit evidence is missing", async () => {
    const packet = basePacket();
    packet.approved_evidence_summary = {
      recent_training_load: {},
      consistency: {},
      modality_mix: {},
      body_recovery_context: {},
      confidence: "missing",
      caveats: ["HealthKit evidence unavailable."],
    };

    const result = await invokeTrainingArchitectureGraph(packet);

    assert.equal(result.artifact.weekly_budget.minimum_viable_sessions >= 1, true);
    assert.equal(result.artifact.source_ids.blueprint_revision_id, packet.athlete_context.blueprint_revision_id);
  });
});

describe("fitnessStrategyGraph and twoWeekPlanGraph", () => {
  it("maps body-composition-sensitive architecture into strategy targets and two visible weeks", async () => {
    const packet = basePacket({
      body_composition_intent: "fat_loss",
      normalized_goal: {
        title: "Lose 5 kg while preserving strength",
        desiredOutcome: "fat loss and strength retention",
      },
    });
    const architecture = (await invokeTrainingArchitectureGraph(packet)).artifact;
    const strategy = await invokeFitnessStrategyGraph(packet, architecture);
    const plan = await invokeTwoWeekPlanGraph(packet, architecture, strategy.artifact);

    assert.ok(strategy.artifact.targets.some((target) => target.metricKey === "hard_sessions_per_week"));
    assert.equal(plan.artifact.rhythms.length, 2);
    assert.equal(plan.artifact.rhythms[0]?.weekStartDate, packet.planning_constraints.start_date);
    assert.equal(plan.artifact.rhythms[0]?.workouts.length, architecture.weekly_budget.target_sessions);
  });
});

function basePacket(overrides: Partial<PlanningPacket["goal_context"]> = {}): PlanningPacket {
  return {
    athlete_context: {
      blueprint_revision_id: "11111111-1111-1111-1111-111111111111",
      coach_read: "Durable recreational athlete with mixed training history.",
      athlete_archetype: { label: "durable_generalist" },
      current_training_state: { recentPattern: "two to four sessions weekly" },
      history_findings: [{ label: "training_history", summary: "Moderate exposure across modalities." }],
      goal_fit: { confidence: "medium" },
      hidden_inputs: { motivation: "health and capability" },
    },
    goal_context: {
      user_goal_id: "22222222-2222-2222-2222-222222222222",
      normalized_goal: {
        title: "Build a reliable training rhythm",
        desiredOutcome: "more consistent training",
      },
      goal_kind: "specific_goal",
      timeframe_weeks: 8,
      success_definition: "Complete the minimum viable week most weeks.",
      selected_modality_order: ["Strength", "Running"],
      body_composition_intent: null,
      ...overrides,
    },
    planning_constraints: {
      feasible_modalities: ["Strength", "Running", "Cycling"],
      frequency: "3 days per week",
      session_length: "30-45 minutes",
      injuries: null,
      equipment_access: ["Gym", "Bike"],
      avoidances: ["Late night sessions"],
      bad_day_floor: "10 minutes easy movement",
      timezone: "Europe/Berlin",
      start_date: "2026-07-13",
    },
    approved_evidence_summary: {
      recent_training_load: { sessions28d: 9 },
      consistency: { activeWeeks8w: 6 },
      modality_mix: { strength: 5, running: 3, cycling: 1 },
      body_recovery_context: { sleep: "unknown", bodyMassTrend: "stable" },
      confidence: "medium",
      caveats: ["No raw HealthKit samples included."],
    },
    generation_policy: {
      visible_horizon_weeks: 2,
      committed_horizon_weeks: 1,
      allowed_claims: ["bounded planning", "evidence summaries only"],
      ai_first_plan_generation: true,
    },
  };
}
