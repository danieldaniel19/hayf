import { AI_TOUCHPOINT_CATALOG } from "../../supabase/functions/_shared/ai-touchpoint-catalog.ts";
import { MOCK_TOUCHPOINT_FIXTURES } from "./mock-fixtures.ts";
import {
  buildOpenAIRequestBody,
  cloneCatalog,
  parseEnvFile,
  serializeCatalog,
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
  assertEquals(validateGraphRunRequest({
    graphName: "prepare_initial_strategy",
    fixture: { planningPacket: { goal_context: { goal_kind: "consistency" } } },
  }), {
    graphName: "prepare_initial_strategy",
    fixture: { planningPacket: { goal_context: { goal_kind: "consistency" } } },
  });
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
  assertEquals(validateGraphFixtureDraft({
    graphName: "two_week_plan",
    name: "Happy Path",
    fixture: { planningPacket: {} },
  }), {
    graphName: "two_week_plan",
    safeName: "happy-path",
    filename: "graph-two_week_plan-happy-path.json",
    fixture: { planningPacket: {} },
  });
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
