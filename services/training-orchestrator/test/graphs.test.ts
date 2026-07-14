import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { assertPlanningPacket, normalizeModality, type PlanningPacket } from "../src/contracts.js";
import { invokeFitnessStrategyGraph } from "../src/graphs/fitness-strategy.js";
import { invokeTrainingArchitectureGraph } from "../src/graphs/training-architecture.js";
import { buildPlannerInputContract, invokeTwoWeekPlanGraph } from "../src/graphs/two-week-plan.js";

process.env.HAYF_ALLOW_AI_STUB = "true";

describe("planning packet contract", () => {
  it("accepts compact planning packets", () => {
    assert.doesNotThrow(() => assertPlanningPacket(basePacket()));
  });

  it("normalizes common workout aliases returned by the planner", () => {
    assert.equal(normalizeModality("Bike"), "cycling");
    assert.equal(normalizeModality("Tempo Ride"), "cycling");
    assert.equal(normalizeModality("Full Body A"), "strength");
    assert.equal(normalizeModality("Jog"), "running");
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
  it("routes cycling, strength, and running weight-loss goals through the Architect and bounded consultants", async () => {
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
    assert.equal(result.artifact.specialist_consultations.length, 3);
    assert.ok(result.artifact.approved_archetypes.length > 0);
    assert.ok(result.artifact.source_knowledge_refs.some((ref) => ref.id === "core.training_doctrine"));
    assert.ok(result.nodes.some((node) => node.node_name === "architect_synthesis"));
    assert.ok(result.nodes.some((node) => node.node_name === "specialist_consultations"));
    assert.ok(result.tool_calls.some((tool) => tool.tool_name === "consult_cycling_specialist"));
    assert.ok(result.tool_calls.some((tool) => tool.tool_name === "consult_strength_specialist"));
    assert.ok(result.tool_calls.some((tool) => tool.tool_name === "consult_running_specialist"));
    assert.ok(result.tool_calls.some((tool) => tool.tool_name === "synthesize_training_architecture"));
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

  it("uses exactly two phases for a four-week time-bound goal", async () => {
    const result = await invokeTrainingArchitectureGraph(basePacket({
      goal_kind: "specific_goal",
      timeframe_weeks: 4,
      selected_modality_order: ["Cycling", "Strength"],
      normalized_goal: { title: "Build cycling fitness", desiredOutcome: "ride more strongly" },
    }));

    assert.deepEqual(
      result.artifact.phase_logic.phases.map(({ start_week, end_week }) => [start_week, end_week]),
      [[1, 2], [3, 4]],
    );
  });

  it("keeps specialist consultations archetype-only with no dated workouts", async () => {
    const result = await invokeTrainingArchitectureGraph(basePacket({
      selected_modality_order: ["Cycling", "Strength", "Running"],
    }));

    for (const consultation of result.artifact.specialist_consultations) {
      assert.ok(consultation.archetype_proposals.length > 0);
      assert.equal(JSON.stringify(consultation.archetype_proposals).includes("scheduledDate"), false);
      assert.equal(JSON.stringify(consultation.archetype_proposals).includes("weekStartDate"), false);
    }
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
    assert.ok(result.artifact.conflict_decisions.every((decision) => decision.knowledge_refs.length > 0));
  });

  it("still produces a conservative architecture when HealthKit evidence is missing", async () => {
    const packet = basePacket();
    packet.approved_evidence_summary = {
      recent_training_load: {},
      continuity_state: {
        state: "insufficient_history",
        reentry_stage: "none",
        days_since_last_workout: null,
        last_workout_at: null,
        historical_base: "none",
        total_imported_workouts: 0,
      },
      consistency: {},
      modality_mix: {},
      body_recovery_context: {},
      confidence: "missing",
      caveats: ["HealthKit evidence unavailable."],
    };

    const result = await invokeTrainingArchitectureGraph(packet);

    assert.equal(result.artifact.weekly_budget.minimum_viable_sessions >= 1, true);
    assert.equal(result.artifact.source_ids.blueprint_revision_id, packet.athlete_context.blueprint_revision_id);
    assert.ok(result.artifact.approved_archetypes.every((archetype) => archetype.fatigue_cost !== "high"));
  });

  it("defers high-fatigue cycling work instead of rejecting it for the initial two-week plan", async () => {
    const packet = basePacket({
      selected_modality_order: ["Cycling", "Strength"],
      normalized_goal: {
        title: "Improve cycling stamina",
        desiredOutcome: "ride longer and handle sustained efforts",
      },
    });

    const result = await invokeTrainingArchitectureGraph(packet);

    assert.ok(result.artifact.approved_archetypes.every((archetype) => archetype.id !== "cycling_vo2_intervals"));
    assert.ok(result.artifact.deferred_specialist_recommendations.some((recommendation) => (
      recommendation.archetype_id === "cycling_vo2_intervals" && recommendation.phase_hint === "build"
    )));
    assert.equal(result.artifact.rejected_specialist_recommendations.some((recommendation) => (
      recommendation.archetype_id === "cycling_vo2_intervals"
    )), false);
  });

  it("routes unsupported tennis and swimming through the generic consultant without losing roles", async () => {
    const result = await invokeTrainingArchitectureGraph(basePacket({
      selected_modality_order: ["Tennis", "Swimming"],
    }));

    assert.deepEqual(result.artifact.priority_order, ["tennis", "swimming"]);
    assert.deepEqual(result.artifact.modality_roles.map((role) => role.modality), ["tennis", "swimming"]);
    assert.ok(result.artifact.specialist_consultations.every((consultation) => (
      consultation.knowledge_refs.some((ref) => ref.id === "modality.generic")
    )));
    assert.ok(result.artifact.approved_archetypes.every((archetype) => ["tennis", "swimming"].includes(archetype.modality)));
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
    const plannerInput = buildPlannerInputContract(packet, architecture, strategy.artifact);
    const plan = await invokeTwoWeekPlanGraph(packet, architecture, strategy.artifact);

    assert.deepEqual(plannerInput.allowed_modalities, architecture.modality_roles.map((role) => role.modality));
    assert.deepEqual(plannerInput.approved_archetypes, architecture.approved_archetypes);
    assert.ok(strategy.artifact.targets.some((target) => target.metricKey === "hard_sessions_per_week"));
    assert.equal(plan.artifact.rhythms.length, 2);
    assert.equal(plan.artifact.rhythms[0]?.weekStartDate, packet.planning_constraints.start_date);
    assert.equal(plan.artifact.rhythms[0]?.workouts.length, architecture.weekly_budget.target_sessions);
    assert.ok(plan.artifact.rhythms.every((rhythm) => (
      new Set(rhythm.workouts.map((workout) => workout.scheduledDate)).size === rhythm.workouts.length
    )));
    assert.ok(plan.artifact.rhythms.every((rhythm) => (
      rhythm.workouts.every((workout) => (
        workout.scheduledDate >= rhythm.weekStartDate && workout.scheduledDate <= rhythm.weekEndDate
      ))
    )));
    assert.ok(plan.nodes.some((node) => node.node_name === "enrich_prescriptions"));
    assert.ok(plan.tool_calls.some((tool) => tool.tool_name === "enrich_workout_prescriptions"));
    assert.ok(plan.artifact.rhythms.every((rhythm) => (
      rhythm.workouts.every((workout) => architecture.priority_order.includes(workout.activityType.toLowerCase()))
    )));
    const workouts = plan.artifact.rhythms.flatMap((rhythm) => rhythm.workouts);
    assert.ok(workouts.every((workout) => workout.prescription.schemaVersion === 2));
    assert.ok(workouts.every((workout) => workout.prescription.warmup.steps.length > 0));
    assert.ok(workouts.every((workout) => workout.prescription.main.blocks.length > 0));
    const strength = workouts.find((workout) => workout.activityType === "strength");
    assert.ok(strength);
    const strengthBlocks = strength.prescription.main.blocks.filter((block) => block.kind === "strengthExercise");
    assert.ok(strengthBlocks.length > 0);
    assert.ok(strengthBlocks.every((block) => block.alternatives.length > 0));
    const optionalModalities = new Set(architecture.modality_dose
      .filter((dose) => dose.role === "optional_filler")
      .map((dose) => dose.modality));
    assert.ok(workouts.every((workout) => !optionalModalities.has(workout.activityType)));
  });

  it("turns a 55-day interruption into a visible, dose-limited re-entry block", async () => {
    const packet = basePacket({
      selected_modality_order: ["Cycling", "Strength", "Running"],
      normalized_goal: {
        title: "Rebuild a consistent mixed training rhythm",
        desiredOutcome: "return to cycling, strength, and running safely",
      },
    });
    packet.approved_evidence_summary.continuity_state = {
      state: "reentry",
      reentry_stage: "extended_gap",
      days_since_last_workout: 55,
      last_workout_at: "2026-05-19T06:19:24Z",
      historical_base: "established",
      total_imported_workouts: 837,
    };
    packet.approved_evidence_summary.confidence = "historical";

    const architecture = (await invokeTrainingArchitectureGraph(packet)).artifact;
    const strategy = (await invokeFitnessStrategyGraph(packet, architecture)).artifact;
    const plan = (await invokeTwoWeekPlanGraph(packet, architecture, strategy)).artifact;

    assert.equal(architecture.reentry.active, true);
    assert.equal(architecture.reentry.stage, "extended_gap");
    assert.equal(architecture.reentry.gap_days, 55);
    assert.equal(architecture.weekly_budget.hard_sessions, 0);
    assert.equal(architecture.weekly_budget.committed_week_sessions, architecture.weekly_budget.minimum_viable_sessions);
    assert.ok(architecture.approved_archetypes.every((archetype) => archetype.fatigue_cost !== "high"));
    assert.match(strategy.read, /re-entry/i);
    assert.equal(plan.rhythms[0]?.workouts.length, architecture.weekly_budget.committed_week_sessions);
    assert.equal(plan.rhythms[1]?.workouts.length, architecture.weekly_budget.draft_week_sessions);
    assert.match(plan.rhythms[0]?.objective ?? "", /re-enter|rebuild/i);
    const workouts = plan.rhythms.flatMap((rhythm) => rhythm.workouts);
    const planText = workouts.map((workout) => `${workout.title} ${workout.intensityLabel} ${workout.purpose}`).join(" ");
    assert.doesNotMatch(planText, /\b(vo2|maximal|all-out|threshold|sprint|intervals|race effort|hard)\b/i);
    assert.ok(workouts.every((workout) => workout.prescription.main.blocks.every((block) => block.kind !== "interval")));
  });

  it("keeps a midweek 12-week cycling re-entry plan coherent from launch through Week 2", async () => {
    const packet = basePacket({
      goal_kind: "specific_goal",
      timeframe_weeks: 12,
      selected_modality_order: ["Cycling", "Strength", "Running"],
      body_composition_intent: "fat_loss",
      normalized_goal: {
        title: "Lose 3 kg, improve VO2 max for cycling climbs, and keep defined muscle",
        desiredOutcome: "lean out while improving cycling and preserving an athletic look",
      },
      success_definition: "Lose 3 kg while climbing better and maintaining muscle.",
    });
    packet.athlete_context.hidden_inputs = {
      ...packet.athlete_context.hidden_inputs,
      planOwnerStartDate: "2026-07-14",
    };
    packet.planning_constraints.frequency = "5+ days per week";
    packet.planning_constraints.available_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
    packet.planning_constraints.available_day_parts = ["Morning", "Afternoon"];
    packet.planning_constraints.bad_day_floor = "10-minute walk or mobility";
    packet.approved_evidence_summary.continuity_state = {
      state: "reentry",
      reentry_stage: "extended_gap",
      days_since_last_workout: 55,
      last_workout_at: "2026-05-19T06:19:24Z",
      historical_base: "established",
      total_imported_workouts: 837,
    };

    const architecture = (await invokeTrainingArchitectureGraph(packet)).artifact;
    const strategy = (await invokeFitnessStrategyGraph(packet, architecture)).artifact;
    const plan = (await invokeTwoWeekPlanGraph(packet, architecture, strategy)).artifact;

    assert.deepEqual(
      architecture.phase_logic.phases.map(({ start_week, end_week }) => [start_week, end_week]),
      [[1, 2], [3, 10], [11, 12]],
    );
    assert.equal(strategy.phases.length, 3);
    assertCompactStrategyCopy(strategy);

    const cyclingDose = architecture.modality_dose.find((dose) => dose.modality === "cycling");
    const strengthDose = architecture.modality_dose.find((dose) => dose.modality === "strength");
    const runningDose = architecture.modality_dose.find((dose) => dose.modality === "running");
    assert.equal(cyclingDose?.target_sessions, 3);
    assert.equal(strengthDose?.target_sessions, 2);
    assert.equal(runningDose?.minimum_sessions, 0);

    assert.equal(plan.block.startDate, "2026-07-20");
    assert.equal(plan.block.targetDate, "2026-10-11");
    assert.deepEqual(plan.rhythms.map((rhythm) => rhythm.programStage), ["launch", "program", "program"]);
    assert.deepEqual(plan.rhythms.map((rhythm) => rhythm.programWeekNumber), [null, 1, 2]);
    assert.deepEqual(plan.rhythms.map((rhythm) => rhythm.workouts.length), [2, 4, 5]);
    assert.deepEqual(plan.rhythms[0]?.workouts.map((workout) => workout.activityType), ["cycling", "strength"]);
    assert.deepEqual(workoutModalityCounts(plan.rhythms[1]?.workouts ?? []), { cycling: 2, strength: 2 });
    assert.deepEqual(workoutModalityCounts(plan.rhythms[2]?.workouts ?? []), { cycling: 3, strength: 2 });

    const workouts = plan.rhythms.flatMap((rhythm) => rhythm.workouts);
    assert.ok(workouts.every((workout) => [1, 2, 3, 4, 5].includes(utcWeekday(workout.scheduledDate))));
    assert.ok(workouts.every((workout) => workout.activityType !== "running"));
    assert.ok(workouts.every((workout) => !/recovery/i.test(workout.title)));
    assert.ok(workouts.every((workout) => workout.archetypeId));
    assert.ok(workouts.every((workout) => workout.prescription.schemaVersion === 2));
    assert.ok(workouts.every((workout) => /\b(?:Launch|Week [12])\b/.test(workout.prescription.whyToday ?? "")));
    assert.ok(workouts.every((workout) => workout.fuelingSummary.length <= 20));
    assert.ok(workouts.every((workout) => workout.fuelingSummary.trim().split(/\s+/).length <= 3));
    assert.ok(workouts.every((workout) => workout.title.length <= 32));
    assert.doesNotMatch(workouts.map((workout) => workout.title).join(" "), /[—–]/);

    for (const workout of workouts) {
      assert.doesNotMatch(
        [workout.title, workout.intensityLabel, workout.purpose, workout.fuelingSummary].join(" "),
        /[—–]|\b(?:RIR|RPE|approvedArchetype|archetypeId|badDayFloor)\b|[a-z]+_[a-z_]+/i,
      );
      const { constraintsApplied: _, ...visiblePrescription } = workout.prescription;
      assert.doesNotMatch(JSON.stringify(visiblePrescription), /[—–]|\b(?:RIR|RPE)\b|[a-z]+_[a-z_]+/i);
    }
  });

  it("uses one remaining slot for cycling and omits an empty launch bridge", async () => {
    const planForOwnerDate = async (planOwnerStartDate: string) => {
      const packet = basePacket({
        timeframe_weeks: 12,
        selected_modality_order: ["Cycling", "Strength"],
        normalized_goal: { title: "Improve cycling fitness", desiredOutcome: "ride and climb better" },
      });
      packet.athlete_context.hidden_inputs = { ...packet.athlete_context.hidden_inputs, planOwnerStartDate };
      packet.planning_constraints.frequency = "5+ days per week";
      packet.approved_evidence_summary.continuity_state = {
        state: "reentry",
        reentry_stage: "extended_gap",
        days_since_last_workout: 55,
        last_workout_at: "2026-05-19T06:19:24Z",
        historical_base: "established",
        total_imported_workouts: 837,
      };
      const architecture = (await invokeTrainingArchitectureGraph(packet)).artifact;
      const strategy = (await invokeFitnessStrategyGraph(packet, architecture)).artifact;
      return (await invokeTwoWeekPlanGraph(packet, architecture, strategy)).artifact;
    };

    const fridayPlan = await planForOwnerDate("2026-07-17");
    assert.deepEqual(fridayPlan.rhythms.map((rhythm) => rhythm.programStage), ["launch", "program", "program"]);
    assert.equal(fridayPlan.rhythms[0]?.workouts.length, 1);
    assert.equal(fridayPlan.rhythms[0]?.workouts[0]?.activityType, "cycling");

    const saturdayPlan = await planForOwnerDate("2026-07-18");
    assert.deepEqual(saturdayPlan.rhythms.map((rhythm) => rhythm.programStage), ["program", "program"]);
    assert.deepEqual(saturdayPlan.rhythms.map((rhythm) => rhythm.weekStartDate), ["2026-07-20", "2026-07-27"]);
  });

  it("preserves a re-entry walk-run as explicit alternating durations without distance", async () => {
    const packet = basePacket({
      timeframe_weeks: 8,
      selected_modality_order: ["Running"],
      normalized_goal: {
        title: "Return to running consistently",
        desiredOutcome: "rebuild running tolerance",
      },
    });
    packet.planning_constraints.feasible_modalities = ["Running"];
    packet.approved_evidence_summary.continuity_state = {
      state: "reentry",
      reentry_stage: "extended_gap",
      days_since_last_workout: 55,
      last_workout_at: "2026-05-19T06:19:24Z",
      historical_base: "established",
      total_imported_workouts: 100,
    };

    const architecture = (await invokeTrainingArchitectureGraph(packet)).artifact;
    const strategy = (await invokeFitnessStrategyGraph(packet, architecture)).artifact;
    const plan = (await invokeTwoWeekPlanGraph(packet, architecture, strategy)).artifact;
    const runningWorkouts = plan.rhythms.flatMap((rhythm) => rhythm.workouts)
      .filter((workout) => workout.activityType === "running");

    assert.ok(runningWorkouts.length > 0);
    assert.ok(runningWorkouts.every((workout) => (
      workout.prescription.main.blocks.some((block) => (
        block.kind === "walkRun" && block.repeats > 0 && block.runDurationMinutes > 0 && block.walkDurationMinutes > 0
      ))
    )));
    assert.ok(runningWorkouts.every((workout) => (
      workout.prescription.main.blocks.every((block) => block.kind !== "steady" || block.distanceKilometers === null)
    )));
  });
});

function assertCompactStrategyCopy(strategy: Awaited<ReturnType<typeof invokeFitnessStrategyGraph>>["artifact"]) {
  const sentences = strategy.read.split(/[.!?]+/).map((value) => value.trim()).filter(Boolean);
  assert.ok(strategy.read.length <= 240);
  assert.ok(strategy.read.trim().split(/\s+/).length <= 40);
  assert.ok(sentences.length >= 1 && sentences.length <= 2);
  assert.doesNotMatch(strategy.read, /[—–]|plan summary|please review|review the/i);
  for (const item of [...strategy.fitReasons, ...strategy.pillars]) {
    assert.ok(item.title.length <= 42, `${item.title} exceeds compact title budget`);
    assert.ok(item.title.trim().split(/\s+/).length <= 6);
    assert.ok(item.summary.length <= 72, `${item.summary} exceeds compact summary budget`);
    assert.ok(item.summary.trim().split(/\s+/).length <= 12);
  }
  const compactTargets = [
    strategy.goalTargetContext,
    ...strategy.targets,
    ...strategy.phases.flatMap((phase) => [
      { title: phase.name, summary: phase.targetSummary },
      ...phase.targets,
    ]),
  ];
  for (const item of compactTargets) {
    assert.ok(item.title.length <= 42, `${item.title} exceeds compact title budget`);
    assert.ok(item.title.trim().split(/\s+/).length <= 6);
    assert.ok(item.summary.length <= 72, `${item.summary} exceeds compact summary budget`);
    assert.ok(item.summary.trim().split(/\s+/).length <= 12);
  }
  if (strategy.operatingRhythm) {
    assert.ok(strategy.operatingRhythm.summary.length <= 72);
    assert.ok(strategy.operatingRhythm.summary.trim().split(/\s+/).length <= 12);
  }
  assert.ok(strategy.phases.every((phase) => phase.objective.length <= 80));
}

function workoutModalityCounts(workouts: Array<{ activityType: string }>) {
  return workouts.reduce<Record<string, number>>((counts, workout) => {
    counts[workout.activityType] = (counts[workout.activityType] ?? 0) + 1;
    return counts;
  }, {});
}

function utcWeekday(date: string) {
  return new Date(`${date}T12:00:00Z`).getUTCDay();
}

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
      available_days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
      available_day_parts: ["Morning", "Afternoon"],
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
      continuity_state: {
        state: "active",
        reentry_stage: "none",
        days_since_last_workout: 2,
        last_workout_at: "2026-07-11T08:00:00Z",
        historical_base: "established",
        total_imported_workouts: 120,
      },
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
