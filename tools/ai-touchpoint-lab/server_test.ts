import { AI_TOUCHPOINT_CATALOG } from "../../supabase/functions/_shared/ai-touchpoint-catalog.ts";
import { touchpointResponseMetadata } from "../../supabase/functions/_shared/ai-touchpoint-schemas.ts";
import { MOCK_TOUCHPOINT_FIXTURES } from "./mock-fixtures.ts";
import {
  buildOpenAIRequestBody,
  cloneCatalog,
  listEvalRecords,
  normalizeGraphRunSummary,
  parseEnvFile,
  saveEvalRecord,
  serializeCatalog,
  summarizeFixtureForClient,
  updateCatalogEntry,
  validateGraphFixtureDraft,
  validateGraphRunRequest,
  validateTouchpointDraft,
} from "./server.ts";

Deno.test("validateTouchpointDraft rejects malformed parameter JSON", () => {
  const current = AI_TOUCHPOINT_CATALOG.onboarding.generate_summary;

  assertThrows(() =>
    validateTouchpointDraft("onboarding", "generate_summary", {
      ...current,
      parameters: [],
    }, current)
  );
});

Deno.test("updateCatalogEntry rejects unknown touchpoint ids", () => {
  assertThrows(() =>
    updateCatalogEntry(cloneCatalog(AI_TOUCHPOINT_CATALOG), {
      group: "planning",
      id: "missing_touchpoint",
      config: {
        label: "Missing",
        model: "gpt-5-mini",
        systemPrompt: "Return strict JSON.",
      },
    })
  );
});

Deno.test("updateCatalogEntry updates one touchpoint without changing unrelated configs", () => {
  const original = cloneCatalog(AI_TOUCHPOINT_CATALOG);
  const next = updateCatalogEntry(original, {
    group: "onboarding",
    id: "generate_summary",
    config: {
      ...original.onboarding.generate_summary,
      model: "gpt-5-mini",
      systemPrompt:
        `${original.onboarding.generate_summary.systemPrompt} Test suffix.`,
    },
  });

  assert(
    next.onboarding.generate_summary.systemPrompt.endsWith("Test suffix."),
  );
  assertEquals(
    next.onboarding.generate_goal_candidates,
    original.onboarding.generate_goal_candidates,
  );
  assertEquals(next.planning, original.planning);
});

Deno.test("serializeCatalog writes importable TypeScript catalog source", () => {
  const source = serializeCatalog(cloneCatalog(AI_TOUCHPOINT_CATALOG));
  assert(source.includes("export const DEFAULT_AI_MODEL"));
  assert(source.includes("export const AI_TOUCHPOINT_CATALOG"));
  assert(source.includes('"generate_summary"'));
});

Deno.test("mock fixtures cover every editable touchpoint", () => {
  for (const [group, entries] of Object.entries(AI_TOUCHPOINT_CATALOG)) {
    for (const id of Object.keys(entries)) {
      assert(
        MOCK_TOUCHPOINT_FIXTURES.some((fixture) =>
          fixture.group === group && fixture.id === id
        ),
        `Missing mock fixture for ${group}/${id}`,
      );
    }
  }
});

Deno.test("buildOpenAIRequestBody uses fixture task when present", () => {
  const entry = AI_TOUCHPOINT_CATALOG.planning.workout_replacements;
  const body = buildOpenAIRequestBody(entry, {
    task: "recommend_workout_replacements",
    context: { workoutToReplace: { id: "workout-1" } },
  });
  const input = body.input as Array<{ role: string; content: string }>;
  const userContent = JSON.parse(input[1].content);
  assertEquals(userContent.task, "recommend_workout_replacements");
});

Deno.test("buildOpenAIRequestBody includes structured output schema metadata", () => {
  const entry = AI_TOUCHPOINT_CATALOG.onboarding.generate_summary;
  const body = buildOpenAIRequestBody(entry, {
    task: "generate_summary",
    context: { goalDirection: "train consistently" },
  });
  const text = body.text as Record<string, any>;
  assertEquals(text.format.name, "generate_summary");
  assertEquals(text.format.strict, true);
  assert(text.format.schema.properties.readback);
});

Deno.test("interactive planning schemas satisfy strict structured output object rules", () => {
  for (
    const id of [
      "workout_replacements",
      "workout_additions",
      "workout_interpretation",
      "pending_plan_review",
    ]
  ) {
    const metadata = touchpointResponseMetadata("planning", id);
    if (!metadata) {
      throw new Error(`Missing planning response metadata for ${id}`);
    }
    assertStrictObjectSchemas(metadata.schema, `planning/${id}`);
  }
});

Deno.test("summarizeFixtureForClient extracts human-readable context cues", () => {
  const summary = summarizeFixtureForClient({
    task: "generate_summary",
    context: {
      normalizedGoal: { title: "Run a comfortable 10K" },
      selectedModalities: ["running", "strength"],
      frequency: "4 days per week",
    },
  });

  assertEquals(summary.title, "Run a comfortable 10K");
  assertEquals(summary.selectedModalities, ["running", "strength"]);
  assertEquals(summary.frequency, "4 days per week");
});

Deno.test("planning replan prompts keep replans master-only", () => {
  const repairPrompt =
    AI_TOUCHPOINT_CATALOG.planning.plan_edit_repair.systemPrompt;
  const reviewPrompt =
    AI_TOUCHPOINT_CATALOG.planning.pending_plan_review.systemPrompt;

  assert(repairPrompt.includes("master coach"));
  assert(reviewPrompt.includes("master coach"));
  assert(
    repairPrompt.includes("do not request, simulate, or re-run specialists"),
  );
  assert(
    reviewPrompt.includes("do not request, simulate, or re-run specialists"),
  );
  assert(
    (AI_TOUCHPOINT_CATALOG.planning.pending_plan_review.userRules ?? "")
      .includes(
        "Preserve the current Training Architecture",
      ),
  );
});

Deno.test("planning fixtures include master coach architecture context", () => {
  const pendingReview = MOCK_TOUCHPOINT_FIXTURES.find((fixture) =>
    fixture.group === "planning" && fixture.id === "pending_plan_review"
  );
  const editRepair = MOCK_TOUCHPOINT_FIXTURES.find((fixture) =>
    fixture.group === "planning" && fixture.id === "plan_edit_repair"
  );
  const additions = MOCK_TOUCHPOINT_FIXTURES.find((fixture) =>
    fixture.group === "planning" && fixture.id === "workout_additions"
  );
  const weeklyTargets = MOCK_TOUCHPOINT_FIXTURES.find((fixture) =>
    fixture.group === "planning" && fixture.id === "weekly_targets"
  );

  assert(pendingReview?.fixture.context.masterCoachContext);
  assert(editRepair?.fixture.context.masterCoachContext);
  assert(additions?.fixture.context.masterCoachContext);
  assert(weeklyTargets?.fixture.context.trainingArchitecture);
  assertEquals(
    (pendingReview?.fixture.context.masterCoachContext as Record<
      string,
      unknown
    >).trainingArchitectureAvailable,
    true,
  );
  assertEquals(
    (editRepair?.fixture.context.masterCoachContext as Record<string, unknown>)
      .trainingArchitectureAvailable,
    false,
  );
  assert(
    (AI_TOUCHPOINT_CATALOG.planning.weekly_targets.userRules ?? "").includes(
      "context.trainingArchitecture",
    ),
  );
});

Deno.test("saveEvalRecord persists local eval metadata", async () => {
  const saved = await saveEvalRecord({
    group: "onboarding",
    touchpointID: "generate_summary",
    rating: "good",
    notes: "Clear and direct.",
    fixture: {
      task: "generate_summary",
      context: { normalizedGoal: { title: "Run base" } },
    },
    request: { model: "gpt-5-mini" },
    output: { readback: "You want a steadier run base." },
    latencyMS: 42,
    status: 200,
  });
  const records = await listEvalRecords();

  assertEquals(saved.rating, "good");
  assert(
    records.some((record: Record<string, unknown>) => record.id === saved.id),
  );
});

Deno.test("normalizeGraphRunSummary extracts table fields from ai_graph_runs row", () => {
  const summary = normalizeGraphRunSummary({
    id: "run-1",
    graph_name: "training_architecture",
    triggering_task: "prepare_initial_strategy_after_blueprint",
    status: "succeeded",
    input_json: {
      goal_context: {
        normalized_goal: { title: "Build cycling fitness" },
        selected_modality_order: ["cycling", "strength"],
      },
    },
    output_json: {},
    model_json: { provider: "hayf-training-orchestrator" },
    started_at: "2026-07-09T10:00:00Z",
    finished_at: "2026-07-09T10:00:02Z",
    created_at: "2026-07-09T10:00:00Z",
  });

  assertEquals(summary.goal, "Build cycling fitness");
  assertEquals(summary.selectedModalities, ["cycling", "strength"]);
  assertEquals(summary.durationMS, 2000);
});

Deno.test("parseEnvFile reads project-style env files without exposing comments", () => {
  assertEquals(
    parseEnvFile(`
    # local development
    OPENAI_API_KEY="sk-test"
    export OPENAI_MODEL=gpt-5-mini
    SUPABASE_URL=https://example.supabase.co # trailing comment
  `),
    {
      OPENAI_API_KEY: "sk-test",
      OPENAI_MODEL: "gpt-5-mini",
      SUPABASE_URL: "https://example.supabase.co",
    },
  );
});

Deno.test("validateGraphRunRequest accepts known graph fixtures", () => {
  assertEquals(
    validateGraphRunRequest({
      graphName: "prepare_initial_strategy",
      fixture: {
        planningPacket: { goal_context: { goal_kind: "consistency" } },
      },
    }),
    {
      graphName: "prepare_initial_strategy",
      fixture: {
        planningPacket: { goal_context: { goal_kind: "consistency" } },
      },
      toolOverrides: {},
    },
  );
});

Deno.test("validateGraphRunRequest rejects unknown graphs", () => {
  assertThrows(() =>
    validateGraphRunRequest({
      graphName: "mystery_graph",
      fixture: {},
    })
  );
});

Deno.test("validateGraphFixtureDraft saves graph fixtures with graph prefix", () => {
  assertEquals(
    validateGraphFixtureDraft({
      graphName: "two_week_plan",
      name: "Happy Path",
      fixture: { planningPacket: {} },
    }),
    {
      graphName: "two_week_plan",
      safeName: "happy-path",
      filename: "graph-two_week_plan-happy-path.json",
      fixture: { planningPacket: {} },
    },
  );
});

Deno.test("graphs inspector keeps raw JSON out of the primary viewport", async () => {
  const [html, js] = await Promise.all([
    Deno.readTextFile("tools/ai-touchpoint-lab/static/index.html"),
    Deno.readTextFile("tools/ai-touchpoint-lab/static/app.js"),
  ]);

  assert(
    !html.includes("graphResultOutput"),
    "Graph raw output viewport should not exist",
  );
  for (const label of ["Raw artifact", "Readable Summary", "Raw data"]) {
    assert(
      !js.includes(label),
      `${label} should not be a default Graphs label`,
    );
  }
  assert(
    js.includes("Advanced JSON"),
    "Raw graph payloads should stay available behind Advanced JSON",
  );
});

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

function assertThrows(fn: () => unknown) {
  let didThrow = false;
  try {
    fn();
  } catch {
    didThrow = true;
  }
  if (!didThrow) {
    throw new Error("Expected function to throw");
  }
}

function assertStrictObjectSchemas(value: unknown, path: string) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return;
  const schema = value as Record<string, unknown>;
  const types = Array.isArray(schema.type) ? schema.type : [schema.type];
  if (types.includes("object")) {
    assertEquals(schema.additionalProperties, false);
    const properties = schema.properties as Record<string, unknown> | undefined;
    if (!properties) throw new Error(`Missing properties at ${path}`);
    const required = Array.isArray(schema.required) ? schema.required : [];
    assertEquals([...required].sort(), Object.keys(properties).sort());
  }

  for (const key of ["properties", "items", "anyOf", "oneOf", "allOf"]) {
    const child = schema[key];
    if (Array.isArray(child)) {
      child.forEach((item, index) =>
        assertStrictObjectSchemas(item, `${path}.${key}[${index}]`)
      );
    } else if (child && typeof child === "object") {
      if (key === "properties") {
        for (const [name, propertySchema] of Object.entries(child)) {
          assertStrictObjectSchemas(
            propertySchema,
            `${path}.properties.${name}`,
          );
        }
      } else {
        assertStrictObjectSchemas(child, `${path}.${key}`);
      }
    }
  }
}
