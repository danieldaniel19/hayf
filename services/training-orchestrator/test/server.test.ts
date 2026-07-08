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
