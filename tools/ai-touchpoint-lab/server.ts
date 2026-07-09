import {
  AI_TOUCHPOINT_CATALOG,
  type AITouchpointCatalog,
  type AITouchpointGroup,
  DEFAULT_AI_MODEL,
  type EditableAITouchpointConfig,
  type ReasoningEffort,
  type TextVerbosity,
} from "../../supabase/functions/_shared/ai-touchpoint-catalog.ts";
import { MOCK_TOUCHPOINT_FIXTURES } from "./mock-fixtures.ts";

const LAB_DIR = new URL("./", import.meta.url);
const REPO_ROOT = new URL("../../", import.meta.url);
const STATIC_DIR = new URL("./static/", import.meta.url);
const FIXTURE_DIR = new URL("./fixtures/", import.meta.url);
const CATALOG_PATH = new URL(
  "../../supabase/functions/_shared/ai-touchpoint-catalog.ts",
  import.meta.url,
);
const ENV_FILE_CANDIDATES = [
  new URL("./.env.local", LAB_DIR),
  new URL("../../supabase/.env.local-langgraph", import.meta.url),
  new URL("../../supabase/.env.local", import.meta.url),
  new URL("../../supabase/functions/.env.local", import.meta.url),
  new URL("../../.env.local", import.meta.url),
  new URL("../../.env", import.meta.url),
];

const GROUPS: AITouchpointGroup[] = ["onboarding", "planning"];
const REASONING_EFFORTS: ReasoningEffort[] = [
  "minimal",
  "low",
  "medium",
  "high",
];
const TEXT_VERBOSITIES: TextVerbosity[] = ["low", "medium", "high"];

let catalogState = cloneCatalog(AI_TOUCHPOINT_CATALOG);
const localEnv = await loadLocalEnv();

type SaveRequest = {
  group: AITouchpointGroup;
  id: string;
  config: Record<string, unknown>;
};

type TestRequest = {
  group: AITouchpointGroup;
  id: string;
  config: Record<string, unknown>;
  fixture?: unknown;
};

type GraphFixtureSaveRequest = {
  graphName?: string;
  name?: string;
  fixture?: unknown;
};

type GraphName = "training_architecture" | "fitness_strategy" | "two_week_plan" | "prepare_initial_strategy";

export function cloneCatalog(
  catalog: AITouchpointCatalog,
): AITouchpointCatalog {
  return structuredClone(catalog);
}

export function updateCatalogEntry(
  catalog: AITouchpointCatalog,
  request: SaveRequest,
): AITouchpointCatalog {
  const current = catalog[request.group]?.[request.id];
  if (!current) {
    throw new Error(`Unknown touchpoint: ${request.group}/${request.id}`);
  }

  const nextEntry = validateTouchpointDraft(
    request.group,
    request.id,
    request.config,
    current,
  );
  const nextCatalog = cloneCatalog(catalog);
  nextCatalog[request.group][request.id] = nextEntry;
  return nextCatalog;
}

export function validateTouchpointDraft(
  group: AITouchpointGroup,
  id: string,
  value: Record<string, unknown>,
  current: EditableAITouchpointConfig,
): EditableAITouchpointConfig {
  if (!GROUPS.includes(group)) {
    throw new Error("Invalid touchpoint group");
  }
  if (!isRecord(value)) {
    throw new Error("Config must be a JSON object");
  }

  const label = stringOrCurrent(value.label, current.label).trim();
  const model = stringOrCurrent(value.model, current.model ?? DEFAULT_AI_MODEL)
    .trim();
  const systemPrompt = stringOrCurrent(value.systemPrompt, current.systemPrompt)
    .trim();
  const userRulesValue = value.userRules;
  const userRules = typeof userRulesValue === "string"
    ? userRulesValue.trim()
    : current.userRules;

  if (!label) throw new Error("Label is required");
  if (!model) throw new Error("Model is required");
  if (!systemPrompt) throw new Error("System prompt is required");

  const parameters = optionalRecord(value.parameters, "parameters");
  const reasoning = optionalReasoning(value.reasoning);
  const text = optionalText(value.text);

  return stripUndefined({
    id,
    group,
    label,
    model: model === DEFAULT_AI_MODEL ? undefined : model,
    parameters,
    reasoning,
    text,
    systemPrompt,
    userRules,
  });
}

export function serializeCatalog(catalog: AITouchpointCatalog) {
  const orderedCatalog: AITouchpointCatalog = {
    onboarding: orderedEntries(catalog.onboarding),
    planning: orderedEntries(catalog.planning),
  };

  return [
    'export type ReasoningEffort = "minimal" | "low" | "medium" | "high";',
    'export type TextVerbosity = "low" | "medium" | "high";',
    'export type AITouchpointGroup = "onboarding" | "planning";',
    "",
    "export type EditableAITouchpointConfig = {",
    "  id: string;",
    "  group: AITouchpointGroup;",
    "  label: string;",
    "  model?: string;",
    "  parameters?: Record<string, unknown>;",
    "  reasoning?: { effort: ReasoningEffort };",
    "  text?: { verbosity?: TextVerbosity };",
    "  systemPrompt: string;",
    "  userRules?: string;",
    "};",
    "",
    "export type AITouchpointCatalog = Record<AITouchpointGroup, Record<string, EditableAITouchpointConfig>>;",
    "",
    `export const DEFAULT_AI_MODEL = ${JSON.stringify(DEFAULT_AI_MODEL)};`,
    "",
    `export const AI_TOUCHPOINT_CATALOG: AITouchpointCatalog = ${
      JSON.stringify(orderedCatalog, null, 2)
    };`,
    "",
  ].join("\n");
}

export function buildOpenAIRequestBody(
  entry: EditableAITouchpointConfig,
  fixture: unknown,
) {
  const context = isRecord(fixture) && "context" in fixture
    ? fixture.context
    : fixture ?? {};
  const candidates = isRecord(fixture) && Array.isArray(fixture.candidates)
    ? fixture.candidates
    : [];
  const task = isRecord(fixture) && typeof fixture.task === "string"
    ? fixture.task
    : entry.id;
  const payload: Record<string, unknown> = {
    ...(entry.parameters ?? {}),
    model: entry.model ?? DEFAULT_AI_MODEL,
    input: [
      {
        role: "system",
        content: entry.systemPrompt,
      },
      {
        role: "user",
        content: JSON.stringify({
          task,
          context,
          candidates,
          rules: entry.userRules,
        }),
      },
    ],
  };

  if (entry.text && Object.keys(entry.text).length > 0) {
    payload.text = entry.text;
  }
  if (entry.reasoning) {
    payload.reasoning = entry.reasoning;
  }

  return payload;
}

export function validateGraphRunRequest(value: unknown) {
  if (!isRecord(value)) throw new Error("Graph run request must be a JSON object");
  const graphName = validateGraphName(value.graphName ?? value.graph_name);
  const fixture = isRecord(value.fixture) ? value.fixture : {};
  return { graphName, fixture };
}

export function validateGraphFixtureDraft(value: unknown) {
  if (!isRecord(value)) throw new Error("Graph fixture save body must be an object");
  const graphName = validateGraphName(value.graphName);
  const name = typeof value.name === "string" ? value.name : "";
  const safeName = name.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
  if (!safeName) throw new Error("Fixture name is required");
  return {
    graphName,
    safeName,
    filename: `graph-${graphName}-${safeName}.json`,
    fixture: value.fixture ?? {},
  };
}

export async function handleRequest(req: Request): Promise<Response> {
  if (!isLocalhostRequest(req)) {
    return json(
      { error: "AI Touchpoint Lab only accepts localhost requests." },
      403,
    );
  }

  const url = new URL(req.url);
  try {
    if (req.method === "GET" && url.pathname === "/") {
      return fileResponse(new URL("./index.html", STATIC_DIR));
    }
    if (req.method === "GET" && url.pathname.startsWith("/static/")) {
      return fileResponse(
        new URL(`.${url.pathname.replace("/static", "")}`, STATIC_DIR),
      );
    }
    if (req.method === "GET" && url.pathname === "/api/touchpoints") {
      return json({
        catalog: catalogForClient(catalogState),
        defaultModel: DEFAULT_AI_MODEL,
      });
    }
    if (req.method === "GET" && url.pathname === "/api/mock-fixtures") {
      return json({ fixtures: MOCK_TOUCHPOINT_FIXTURES });
    }
    if (req.method === "GET" && url.pathname === "/api/diff") {
      return json({ diff: await gitDiff() });
    }
    if (req.method === "GET" && url.pathname === "/api/fixtures") {
      return json({ fixtures: await listFixtures() });
    }
    if (req.method === "GET" && url.pathname === "/api/graphs") {
      return json(await orchestratorJSON("/observability/graphs"));
    }
    if (req.method === "GET" && url.pathname === "/api/graph-fixtures") {
      return json({ fixtures: await listGraphFixtures() });
    }
    if (req.method === "POST" && url.pathname === "/api/save") {
      const body = await req.json() as SaveRequest;
      const nextCatalog = updateCatalogEntry(catalogState, body);
      await Deno.writeTextFile(CATALOG_PATH, serializeCatalog(nextCatalog));
      catalogState = nextCatalog;
      const check = await denoCheck();
      return json({
        ok: check.ok,
        check,
        diff: await gitDiff(),
        catalog: catalogForClient(catalogState),
      }, check.ok ? 200 : 422);
    }
    if (req.method === "POST" && url.pathname === "/api/fixtures") {
      const body = await req.json();
      const saved = await saveFixture(body);
      return json({ ok: true, fixture: saved, fixtures: await listFixtures() });
    }
    if (req.method === "POST" && url.pathname === "/api/test") {
      const body = await req.json() as TestRequest;
      return json(await runOpenAITest(body));
    }
    if (req.method === "POST" && url.pathname === "/api/graph-run") {
      const body = await req.json();
      return json(await orchestratorJSON("/observability/run", validateGraphRunRequest(body)));
    }
    if (req.method === "POST" && url.pathname === "/api/graph-tool-test") {
      const body = await req.json();
      return json(await orchestratorJSON("/observability/tool-test", body));
    }
    if (req.method === "POST" && url.pathname === "/api/graph-fixtures") {
      const body = await req.json() as GraphFixtureSaveRequest;
      const saved = await saveGraphFixture(body);
      return json({ ok: true, fixture: saved, fixtures: await listGraphFixtures() });
    }
    if (req.method === "POST" && url.pathname === "/api/graph-run-status") {
      const body = await req.json();
      return json(await planningGraphRunStatus(body));
    }

    return json({ error: "Not found" }, 404);
  } catch (error) {
    return json({ error: errorMessage(error) }, 400);
  }
}

async function runOpenAITest(body: TestRequest) {
  const current = catalogState[body.group]?.[body.id];
  if (!current) {
    throw new Error(`Unknown touchpoint: ${body.group}/${body.id}`);
  }
  const entry = validateTouchpointDraft(
    body.group,
    body.id,
    body.config,
    current,
  );
  const apiKey = envValue("OPENAI_API_KEY");
  if (!apiKey) {
    throw new Error(
      "Missing OPENAI_API_KEY. Export it before starting the lab or add it to supabase/.env.local.",
    );
  }

  const requestBody = buildOpenAIRequestBody(entry, body.fixture);
  const startedAt = Date.now();
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(requestBody),
  });

  const payload = await response.json();
  const latencyMS = Date.now() - startedAt;
  if (!response.ok) {
    return {
      ok: false,
      status: response.status,
      latencyMS,
      request: redactRequest(requestBody),
      error: payload?.error?.message ?? "OpenAI request failed",
      raw: payload,
    };
  }

  return {
    ok: true,
    status: response.status,
    latencyMS,
    request: redactRequest(requestBody),
    outputText: extractOutputText(payload),
    raw: payload,
  };
}

export function parseEnvFile(source: string) {
  const values: Record<string, string> = {};
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;

    const match = /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line);
    if (!match) continue;

    const [, key, rawValue] = match;
    values[key] = unquoteEnvValue(rawValue.trim());
  }
  return values;
}

function unquoteEnvValue(value: string) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1).replaceAll("\\n", "\n").replaceAll('\\"', '"');
  }
  const commentIndex = value.search(/\s+#/);
  return (commentIndex >= 0 ? value.slice(0, commentIndex) : value).trim();
}

async function loadLocalEnv() {
  const merged: Record<string, string> = {};
  for (const candidate of ENV_FILE_CANDIDATES) {
    try {
      Object.assign(merged, parseEnvFile(await Deno.readTextFile(candidate)));
    } catch (error) {
      if (!isIgnorableEnvReadError(error)) {
        throw error;
      }
    }
  }
  return merged;
}

function isIgnorableEnvReadError(error: unknown) {
  if (error instanceof Deno.errors.NotFound) return true;
  if (error instanceof Deno.errors.PermissionDenied) return true;
  return error instanceof Error && error.name === "NotCapable";
}

function envValue(name: string) {
  try {
    return Deno.env.get(name) ?? localEnv[name];
  } catch (error) {
    if (error instanceof Deno.errors.PermissionDenied || error instanceof Error && error.name === "NotCapable") {
      return localEnv[name];
    }
    throw error;
  }
}

function catalogForClient(catalog: AITouchpointCatalog) {
  return Object.fromEntries(GROUPS.map((group) => [
    group,
    Object.values(catalog[group]).map((entry) => ({
      ...entry,
      effectiveModel: entry.model ?? DEFAULT_AI_MODEL,
    })),
  ]));
}

async function listFixtures() {
  await Deno.mkdir(FIXTURE_DIR, { recursive: true });
  const fixtures = [];
  for await (const entry of Deno.readDir(FIXTURE_DIR)) {
    if (entry.isFile && entry.name.endsWith(".json")) {
      fixtures.push(entry.name);
    }
  }
  return fixtures.sort();
}

async function listGraphFixtures() {
  await Deno.mkdir(FIXTURE_DIR, { recursive: true });
  const fixtures = [];
  for await (const entry of Deno.readDir(FIXTURE_DIR)) {
    if (!entry.isFile || !entry.name.startsWith("graph-") || !entry.name.endsWith(".json")) continue;
    const fixture = JSON.parse(await Deno.readTextFile(new URL(entry.name, FIXTURE_DIR)));
    fixtures.push({
      filename: entry.name,
      graphName: typeof fixture.graphName === "string" ? fixture.graphName : "prepare_initial_strategy",
      name: typeof fixture.name === "string" ? fixture.name : entry.name.replace(/^graph-/, "").replace(/\.json$/, ""),
      fixture: fixture.fixture ?? fixture,
    });
  }
  return fixtures.sort((left, right) => left.filename.localeCompare(right.filename));
}

async function saveFixture(body: unknown) {
  if (!isRecord(body)) throw new Error("Fixture save body must be an object");
  const group = body.group;
  const id = body.id;
  const name = typeof body.name === "string" ? body.name : "";
  if (!isKnownTouchpoint(group, id)) {
    throw new Error("Unknown touchpoint for fixture");
  }

  const safeName = name.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
  if (!safeName) throw new Error("Fixture name is required");

  const filename = `${group}-${id}-${safeName}.json`;
  const fixtureURL = new URL(filename, FIXTURE_DIR);
  await assertAllowedFixturePath(fixtureURL);
  await Deno.mkdir(FIXTURE_DIR, { recursive: true });
  await Deno.writeTextFile(
    fixtureURL,
    `${JSON.stringify(body.fixture ?? {}, null, 2)}\n`,
  );
  return filename;
}

async function saveGraphFixture(body: GraphFixtureSaveRequest) {
  const draft = validateGraphFixtureDraft(body);
  const filename = draft.filename;
  const fixtureURL = new URL(filename, FIXTURE_DIR);
  await assertAllowedFixturePath(fixtureURL);
  await Deno.mkdir(FIXTURE_DIR, { recursive: true });
  await Deno.writeTextFile(
    fixtureURL,
    `${JSON.stringify({ graphName: draft.graphName, name: draft.safeName, fixture: draft.fixture }, null, 2)}\n`,
  );
  return filename;
}

function validateGraphName(value: unknown): GraphName {
  if (
    value === "training_architecture" ||
    value === "fitness_strategy" ||
    value === "two_week_plan" ||
    value === "prepare_initial_strategy"
  ) {
    return value;
  }
  throw new Error("Unknown graph");
}

async function orchestratorJSON(path: string, body?: unknown) {
  const baseURL = (envValue("TRAINING_ORCHESTRATOR_URL") || "http://127.0.0.1:8787").replace(/\/$/, "");
  const response = await fetch(`${baseURL}${path}`, {
    method: body === undefined ? "GET" : "POST",
    headers: {
      "Content-Type": "application/json",
      ...(envValue("TRAINING_ORCHESTRATOR_API_KEY")
        ? { Authorization: `Bearer ${envValue("TRAINING_ORCHESTRATOR_API_KEY")}` }
        : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error ?? `Training orchestrator request failed: ${response.status}`);
  }
  return payload;
}

async function planningGraphRunStatus(body: unknown) {
  if (!isRecord(body)) throw new Error("Graph run status body must be an object");
  const graphRunID = typeof body.graphRunID === "string" ? body.graphRunID : typeof body.graph_run_id === "string" ? body.graph_run_id : "";
  if (!graphRunID) throw new Error("graphRunID is required");

  const supabaseURL = envValue("SUPABASE_URL")?.replace(/\/$/, "");
  const anonKey = envValue("SUPABASE_ANON_KEY");
  if (!supabaseURL || !anonKey) {
    throw new Error("SUPABASE_URL and SUPABASE_ANON_KEY are required for durable graph run inspection.");
  }
  const accessToken = typeof body.accessToken === "string"
    ? body.accessToken
    : envValue("SUPABASE_ACCESS_TOKEN") ?? await localSupabaseAccessToken(supabaseURL, anonKey);
  const response = await fetch(`${supabaseURL}/functions/v1/planning-ai`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: anonKey,
      Authorization: `Bearer ${accessToken || anonKey}`,
    },
    body: JSON.stringify({
      task: "get_planning_graph_run_status",
      graphRunID,
      includeTrace: true,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error ?? `Graph run status request failed: ${response.status}`);
  }
  return payload;
}

async function localSupabaseAccessToken(supabaseURL: string, anonKey: string) {
  const email = envValue("HAYF_LOCAL_AUTH_EMAIL");
  const password = envValue("HAYF_LOCAL_AUTH_PASSWORD");
  if (!email || !password) return "";

  const response = await fetch(`${supabaseURL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: anonKey,
    },
    body: JSON.stringify({ email, password }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error_description ?? payload?.error ?? "Could not sign in local Supabase user for graph inspection.");
  }
  return typeof payload.access_token === "string" ? payload.access_token : "";
}

async function assertAllowedFixturePath(url: URL) {
  const fixtureDirPath = await Deno.realPath(new URL("./", FIXTURE_DIR)).catch(
    () => fromFileUrl(FIXTURE_DIR),
  );
  const targetDir = await Deno.realPath(new URL("./", url)).catch(() =>
    fromFileUrl(new URL("./", url))
  );
  if (!targetDir.startsWith(fixtureDirPath)) {
    throw new Error("Fixture path is outside the allowlisted directory");
  }
}

async function denoCheck() {
  const command = new Deno.Command(Deno.execPath(), {
    args: [
      "check",
      "supabase/functions/onboarding-ai/index.ts",
      "supabase/functions/planning-ai/index.ts",
      "tools/ai-touchpoint-lab/server.ts",
    ],
    cwd: fromFileUrl(REPO_ROOT),
    stdout: "piped",
    stderr: "piped",
  });
  const result = await command.output();
  return {
    ok: result.success,
    code: result.code,
    stdout: new TextDecoder().decode(result.stdout),
    stderr: new TextDecoder().decode(result.stderr),
  };
}

async function gitDiff() {
  const command = new Deno.Command("git", {
    args: [
      "diff",
      "--",
      "supabase/functions/_shared/ai-touchpoint-catalog.ts",
      "supabase/functions/_shared/ai-touchpoints.ts",
      "tools/ai-touchpoint-lab",
    ],
    cwd: fromFileUrl(REPO_ROOT),
    stdout: "piped",
    stderr: "piped",
  });
  const result = await command.output();
  if (!result.success) {
    throw new Error(
      new TextDecoder().decode(result.stderr) || "git diff failed",
    );
  }
  return new TextDecoder().decode(result.stdout);
}

async function fileResponse(url: URL) {
  const path = fromFileUrl(url);
  if (!path.startsWith(fromFileUrl(LAB_DIR))) {
    return json({ error: "Forbidden" }, 403);
  }

  try {
    const body = await Deno.readFile(url);
    return new Response(body, {
      headers: {
        "Content-Type": contentType(path),
        "Cache-Control": "no-store",
      },
    });
  } catch {
    return json({ error: "Not found" }, 404);
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function optionalReasoning(value: unknown) {
  if (value == null || value === "") return undefined;
  if (!isRecord(value)) throw new Error("reasoning must be an object");
  const effort = value.effort;
  if (effort == null || effort === "") return undefined;
  if (
    typeof effort !== "string" ||
    !REASONING_EFFORTS.includes(effort as ReasoningEffort)
  ) {
    throw new Error("reasoning.effort is invalid");
  }
  return { effort: effort as ReasoningEffort };
}

function optionalText(value: unknown) {
  if (value == null || value === "") return undefined;
  if (!isRecord(value)) throw new Error("text must be an object");
  const verbosity = value.verbosity;
  if (verbosity == null || verbosity === "") return undefined;
  if (
    typeof verbosity !== "string" ||
    !TEXT_VERBOSITIES.includes(verbosity as TextVerbosity)
  ) {
    throw new Error("text.verbosity is invalid");
  }
  return { verbosity: verbosity as TextVerbosity };
}

function optionalRecord(value: unknown, name: string) {
  if (value == null) return undefined;
  if (!isRecord(value)) throw new Error(`${name} must be a JSON object`);
  return Object.keys(value).length === 0 ? undefined : value;
}

function stringOrCurrent(value: unknown, current: string) {
  if (value == null) return current;
  if (typeof value !== "string") throw new Error("Expected string field");
  return value;
}

function orderedEntries(entries: Record<string, EditableAITouchpointConfig>) {
  return Object.fromEntries(Object.entries(entries));
}

function stripUndefined<T extends Record<string, unknown>>(value: T) {
  return Object.fromEntries(
    Object.entries(value).filter(([, entry]) => entry !== undefined),
  ) as T;
}

function isRecord(value: unknown): value is Record<string, any> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function isKnownTouchpoint(
  group: unknown,
  id: unknown,
): group is AITouchpointGroup {
  return typeof group === "string" &&
    GROUPS.includes(group as AITouchpointGroup) && typeof id === "string" &&
    Boolean(catalogState[group as AITouchpointGroup]?.[id]);
}

function extractOutputText(payload: Record<string, any>) {
  for (const output of payload.output ?? []) {
    for (const content of output.content ?? []) {
      if (content.type === "output_text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }
  return null;
}

function redactRequest(requestBody: Record<string, unknown>) {
  return requestBody;
}

function contentType(path: string) {
  if (path.endsWith(".html")) return "text/html; charset=utf-8";
  if (path.endsWith(".css")) return "text/css; charset=utf-8";
  if (path.endsWith(".js")) return "text/javascript; charset=utf-8";
  if (path.endsWith(".json")) return "application/json; charset=utf-8";
  return "application/octet-stream";
}

function isLocalhostRequest(req: Request) {
  const host = req.headers.get("host")?.split(":")[0]?.toLowerCase();
  return host === "localhost" || host === "127.0.0.1" || host === "[::1]" ||
    host === "::1";
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

function fromFileUrl(url: URL) {
  return decodeURIComponent(url.pathname);
}

if (import.meta.main) {
  const port = Number(Deno.env.get("AI_TOUCHPOINT_LAB_PORT") ?? "8787");
  console.log(`AI Touchpoint Lab running at http://127.0.0.1:${port}`);
  Deno.serve({ hostname: "127.0.0.1", port }, handleRequest);
}
