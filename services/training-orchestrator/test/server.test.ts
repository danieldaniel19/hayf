import assert from "node:assert/strict";
import { after, before, describe, it } from "node:test";
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import type { PlanningPacket } from "../src/contracts.js";
import { createTrainingOrchestratorServer } from "../src/server.js";

process.env.HAYF_ALLOW_AI_STUB = "true";

describe("training orchestrator HTTP adapter", () => {
  let server: Server;
  let baseURL: string;

  before(async () => {
    server = createTrainingOrchestratorServer();
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const address = server.address() as AddressInfo;
    baseURL = `http://127.0.0.1:${address.port}`;
  });

  after(async () => {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  });

  it("serves health checks", async () => {
    const response = await fetch(`${baseURL}/health`);
    const body = await response.json() as Record<string, unknown>;

    assert.equal(response.status, 200);
    assert.equal(body.ok, true);
  });

  it("prepares initial strategy through Training Architect graph contract", async () => {
    const response = await post("/planning/prepare-initial-strategy", { planningPacket: basePacket() });
    const body = await response.json() as Record<string, any>;

    assert.equal(response.status, 200);
    assert.ok(body.trainingArchitecture.approved_archetypes.length > 0);
    assert.ok(body.fitnessStrategy.read.length > 0);
    assert.equal(body.validation.source, "training_orchestrator_service");
    assert.ok(body.nodes.some((node: Record<string, unknown>) => node.nodeName === "architect_frame"));
    assert.ok(body.nodes.some((node: Record<string, unknown>) => node.nodeName === "generate_fitness_strategy"));
  });

  it("compiles two-week plans from the accepted architecture and strategy", async () => {
    const prepared = await postJSON("/planning/prepare-initial-strategy", { planningPacket: basePacket() });
    const response = await post("/planning/two-week-plan", {
      context: {
        goal: {
          id: "22222222-2222-2222-2222-222222222222",
          goal_kind: "consistency",
          title: "Train consistently three times per week",
          normalized_goal_json: { title: "Train consistently three times per week" },
          timeframe_weeks: null,
        },
        strategy: { id: "33333333-3333-3333-3333-333333333333" },
        acceptedStrategy: prepared.fitnessStrategy,
        trainingArchitecture: prepared.trainingArchitecture,
        planGenerationPolicy: { allowedModalities: ["cycling", "strength"] },
        deviceTimezone: "Europe/Berlin",
        startDate: "2026-07-13",
        weeklyPlanStatuses: [
          { weekStartDate: "2026-07-13", status: "committed" },
          { weekStartDate: "2026-07-20", status: "draft" },
        ],
      },
    });
    const body = await response.json() as Record<string, any>;

    assert.equal(response.status, 200);
    assert.equal(body.plan.rhythms.length, 2);
    assert.ok(body.plan.rhythms.every((rhythm: Record<string, any>) => (
      rhythm.workouts.every((workout: Record<string, string>) => ["cycling", "strength"].includes(workout.activityType.toLowerCase()))
    )));
    const workouts = body.plan.rhythms.flatMap((rhythm: Record<string, any>) => rhythm.workouts);
    assert.ok(workouts.every((workout: Record<string, any>) => workout.prescription?.schemaVersion === 2));
    assert.ok(workouts.some((workout: Record<string, any>) => (
      workout.activityType === "strength" &&
      workout.prescription.main.blocks.some((block: Record<string, any>) => block.kind === "strengthExercise" && block.alternatives.length > 0)
    )));
  });

  it("serves explicit graph metadata for the inspector", async () => {
    const response = await fetch(`${baseURL}/observability/graphs`);
    const body = await response.json() as Record<string, any>;

    assert.equal(response.status, 200);
    const training = body.graphs.find((graph: Record<string, unknown>) => graph.name === "training_architecture");
    assert.ok(training);
    assert.ok(training.nodes.some((node: Record<string, unknown>) => node.id === "architect_synthesis"));
    assert.ok(training.edges.some((edge: Record<string, unknown>) => edge.from === "architect_frame" && edge.to === "specialist_consultations"));
  });

  it("keeps observability traces compact by default", async () => {
    delete process.env.HAYF_OBSERVABILITY_TRACE_LEVEL;
    const body = await postJSON("/observability/run", {
      graphName: "training_architecture",
      fixture: { planningPacket: basePacket() },
    });
    const tool = body.toolCalls.find((call: Record<string, unknown>) => call.tool_name === "synthesize_training_architecture");

    assert.ok(tool);
    assert.equal(tool.input.systemPrompt, undefined);
    assert.equal(tool.system_prompt, undefined);
  });

  it("includes full prompt, input, schema, and knowledge refs when full trace is enabled", async () => {
    process.env.HAYF_OBSERVABILITY_TRACE_LEVEL = "full";
    try {
      const body = await postJSON("/observability/run", {
        graphName: "training_architecture",
        fixture: { planningPacket: basePacket() },
      });
      const tool = body.toolCalls.find((call: Record<string, unknown>) => call.tool_name === "synthesize_training_architecture");

      assert.ok(tool);
      assert.ok(tool.input.systemPrompt.includes("master Training Architect"));
      assert.ok(tool.input.input.goal_context);
      assert.ok(tool.input.schema.properties);
      assert.ok(tool.knowledge_refs.length > 0);
    } finally {
      delete process.env.HAYF_OBSERVABILITY_TRACE_LEVEL;
    }
  });

  it("tests a single model-backed tool call from the inspector endpoint", async () => {
    process.env.HAYF_OBSERVABILITY_TRACE_LEVEL = "full";
    try {
      const body = await postJSON("/observability/tool-test", {
        toolName: "compile_two_week_plan",
        fixture: { planningPacket: basePacket() },
      });

      assert.equal(body.ok, true);
      assert.equal(body.toolName, "compile_two_week_plan");
      assert.equal(body.status, "succeeded");
      assert.equal(typeof body.latencyMS, "number");
      assert.ok(body.request.input);
      assert.ok(body.output.rhythms.length === 2);
    } finally {
      delete process.env.HAYF_OBSERVABILITY_TRACE_LEVEL;
    }
  });

  it("applies observability prompt and model overrides to model-backed tool calls", async () => {
    process.env.HAYF_OBSERVABILITY_TRACE_LEVEL = "full";
    try {
      const body = await postJSON("/observability/tool-test", {
        toolName: "synthesize_training_architecture",
        fixture: { planningPacket: basePacket() },
        toolOverrides: {
          synthesize_training_architecture: {
            model: "gpt-override",
            systemPrompt: "Override Training Architect prompt for local eval.",
          },
        },
      });

      assert.equal(body.ok, true);
      assert.equal(body.request.model, "gpt-override");
      assert.equal(body.raw.system_prompt, "Override Training Architect prompt for local eval.");
      assert.ok(body.request.input[0].content.includes("Override Training Architect"));
    } finally {
      delete process.env.HAYF_OBSERVABILITY_TRACE_LEVEL;
    }
  });

  async function post(path: string, payload: unknown) {
    return fetch(`${baseURL}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
  }

  async function postJSON(path: string, payload: unknown) {
    const response = await post(path, payload);
    assert.equal(response.status, 200);
    return response.json() as Promise<Record<string, any>>;
  }
});

function basePacket(): PlanningPacket {
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
        title: "Train consistently three times per week",
        desiredOutcome: "be consistent with cycling and strength",
      },
      goal_kind: "consistency",
      timeframe_weeks: null,
      success_definition: "Complete the minimum viable week most weeks.",
      selected_modality_order: ["Cycling", "Strength"],
      body_composition_intent: null,
    },
    planning_constraints: {
      feasible_modalities: ["Cycling", "Strength"],
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
      modality_mix: { strength: 5, cycling: 3 },
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
