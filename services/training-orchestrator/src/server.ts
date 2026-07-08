import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { pathToFileURL } from "node:url";
import {
  type FitnessStrategyArtifact,
  type GraphResult,
  type GraphTraceNode,
  normalizeModality,
  type PlanningPacket,
  type TrainingArchitecture,
  type TwoWeekPlanArtifact,
} from "./contracts.js";
import { invokeFitnessStrategyGraph } from "./graphs/fitness-strategy.js";
import { invokeTrainingArchitectureGraph } from "./graphs/training-architecture.js";
import { invokeTwoWeekPlanGraph } from "./graphs/two-week-plan.js";

type JsonRecord = Record<string, unknown>;

type EdgeGraphNodeTrace = {
  nodeName: string;
  subgraphName?: string | null;
  inputSummary?: JsonRecord;
  output?: JsonRecord;
  validation?: JsonRecord;
  status?: "succeeded" | "failed" | "skipped";
  retryCount?: number;
  errorMessage?: string | null;
};

type EdgeToolCallTrace = {
  toolName: string;
  toolVersion?: string;
  input?: JsonRecord;
  output?: JsonRecord | null;
  status?: "succeeded" | "failed" | "skipped";
  errorMessage?: string | null;
  latencyMS?: number | null;
};

const serviceVersion = "training-architect-consultants-v1";
const maxRequestBytes = 1_000_000;

export function createTrainingOrchestratorServer() {
  return createServer(async (request, response) => {
    try {
      await route(request, response);
    } catch (error) {
      writeJSON(response, statusForError(error), {
        error: error instanceof Error ? error.message : "Unknown training orchestrator error",
      });
    }
  });
}

async function route(request: IncomingMessage, response: ServerResponse) {
  if (request.method === "GET" && request.url === "/health") {
    writeJSON(response, 200, { ok: true, service: "@hayf/training-orchestrator", version: serviceVersion });
    return;
  }

  if (!authorize(request)) {
    writeJSON(response, 401, { error: "Unauthorized" });
    return;
  }

  if (request.method === "POST" && request.url === "/planning/prepare-initial-strategy") {
    const body = await readJSON(request);
    const planningPacket = body.planningPacket as PlanningPacket | undefined;
    if (!planningPacket) throw new Error("Request requires planningPacket.");

    const architectureResult = await invokeTrainingArchitectureGraph(planningPacket);
    const strategyResult = await invokeFitnessStrategyGraph(planningPacket, architectureResult.artifact);

    writeJSON(response, 200, {
      trainingArchitecture: architectureResult.artifact,
      fitnessStrategy: strategyResult.artifact,
      validation: {
        valid: true,
        source: "training_orchestrator_service",
        graphVersion: serviceVersion,
      },
      nodes: [
        ...edgeNodes(architectureResult.nodes),
        ...edgeNodes(strategyResult.nodes),
      ],
      toolCalls: [
        ...edgeToolCalls(architectureResult),
        ...edgeToolCalls(strategyResult),
      ],
      model: modelMetadata(),
    });
    return;
  }

  if (request.method === "POST" && request.url === "/planning/two-week-plan") {
    const body = await readJSON(request);
    const context = objectAt(body, "context");
    if (!context) throw new Error("Request requires context.");

    const architecture = objectAt(context, "trainingArchitecture") as TrainingArchitecture | null;
    if (!architecture) throw new Error("Two-week plan context requires trainingArchitecture.");

    const packet = planningPacketFromPlanContext(context, architecture);
    const strategy = fitnessStrategyFromPlanContext(context, architecture);
    const planResult = await invokeTwoWeekPlanGraph(packet, architecture, strategy);

    writeJSON(response, 200, {
      plan: planResult.artifact,
      validation: {
        valid: true,
        source: "training_orchestrator_service",
        graphVersion: serviceVersion,
      },
      nodes: edgeNodes(planResult.nodes),
      toolCalls: edgeToolCalls(planResult),
      model: modelMetadata(),
    });
    return;
  }

  writeJSON(response, 404, { error: "Not found" });
}

function authorize(request: IncomingMessage) {
  const apiKey = process.env.TRAINING_ORCHESTRATOR_API_KEY?.trim();
  if (!apiKey) return true;
  const authorization = request.headers.authorization ?? "";
  return authorization === `Bearer ${apiKey}`;
}

async function readJSON(request: IncomingMessage): Promise<JsonRecord> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.byteLength;
    if (size > maxRequestBytes) throw Object.assign(new Error("Request body is too large."), { statusCode: 413 });
    chunks.push(buffer);
  }
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString("utf8")) as JsonRecord;
}

function writeJSON(response: ServerResponse, statusCode: number, payload: unknown) {
  response.writeHead(statusCode, { "Content-Type": "application/json" });
  response.end(JSON.stringify(payload));
}

function statusForError(error: unknown) {
  if (typeof error === "object" && error && "statusCode" in error) {
    const statusCode = Number((error as { statusCode?: unknown }).statusCode);
    if (Number.isInteger(statusCode) && statusCode >= 400 && statusCode < 600) return statusCode;
  }
  return 400;
}

function edgeNodes(nodes: GraphTraceNode[]): EdgeGraphNodeTrace[] {
  return nodes.map((node) => ({
    nodeName: node.node_name,
    subgraphName: node.subgraph_name ?? null,
    inputSummary: node.input_summary,
    output: node.output,
    validation: node.validation,
    status: node.status,
  }));
}

function edgeToolCalls(result: GraphResult<unknown>): EdgeToolCallTrace[] {
  return result.tool_calls.map((toolCall) => ({
    toolName: toolCall.tool_name,
    toolVersion: toolCall.tool_version,
    input: toolCall.input,
    output: toolCall.output,
    status: toolCall.status,
    errorMessage: toolCall.error_message ?? null,
    latencyMS: toolCall.latency_ms ?? null,
  }));
}

function modelMetadata() {
  return {
    provider: "hayf-training-orchestrator",
    graphVersion: serviceVersion,
    runtime: "node",
  };
}

function planningPacketFromPlanContext(context: JsonRecord, architecture: TrainingArchitecture): PlanningPacket {
  const goal = objectAt(context, "goal") ?? {};
  const strategy = objectAt(context, "strategy") ?? {};
  const policy = objectAt(context, "planGenerationPolicy") ?? {};
  const selectedModalities = normalizedModalities([
    ...stringArrayAt(architecture, "priority_order"),
    ...stringArrayAt(policy, "allowedModalities"),
  ]);
  const startDate = stringAt(context, "startDate")
    ?? firstWeekStartDate(context)
    ?? new Date().toISOString().slice(0, 10);
  const timezone = stringAt(context, "deviceTimezone") ?? "UTC";
  const targetSessions = architecture.weekly_budget?.target_sessions ?? 3;
  const goalKind = stringAt(goal, "goal_kind") ?? architecture.goal_read?.goal_kind ?? "specific_goal";
  return {
    athlete_context: {
      blueprint_revision_id: architecture.source_ids?.blueprint_revision_id ?? stringAt(strategy, "source_blueprint_revision_id") ?? "unknown",
      coach_read: "",
      athlete_archetype: {},
      current_training_state: {},
      history_findings: [],
      goal_fit: {},
      hidden_inputs: {},
    },
    goal_context: {
      user_goal_id: architecture.source_ids?.user_goal_id ?? stringAt(goal, "id") ?? undefined,
      normalized_goal: objectAt(goal, "normalized_goal_json") ?? {
        title: stringAt(goal, "title") ?? architecture.goal_read?.summary ?? "Active goal",
      },
      goal_kind: isGoalKind(goalKind) ? goalKind : "specific_goal",
      timeframe_weeks: numberAt(goal, "timeframe_weeks"),
      success_definition: stringAt(architecture.goal_read, "success_definition"),
      selected_modality_order: selectedModalities.length ? selectedModalities : architecture.priority_order,
      body_composition_intent: null,
    },
    planning_constraints: {
      feasible_modalities: selectedModalities.length ? selectedModalities : architecture.priority_order,
      frequency: `${targetSessions} days per week`,
      session_length: null,
      injuries: null,
      equipment_access: [],
      avoidances: [],
      bad_day_floor: architecture.recovery_envelope?.bad_day_floor ?? null,
      timezone,
      start_date: startDate,
    },
    approved_evidence_summary: {
      recent_training_load: {},
      consistency: {},
      modality_mix: {},
      body_recovery_context: {},
      confidence: "medium",
      caveats: ["Two-week plan context was provided by Supabase Edge."],
    },
    generation_policy: {
      visible_horizon_weeks: 2,
      committed_horizon_weeks: 1,
      allowed_claims: ["Use validated Training Architecture and approved archetypes."],
      ai_first_plan_generation: true,
    },
  };
}

function fitnessStrategyFromPlanContext(context: JsonRecord, architecture: TrainingArchitecture): FitnessStrategyArtifact {
  const acceptedStrategy = objectAt(context, "acceptedStrategy") as FitnessStrategyArtifact | null;
  if (acceptedStrategy?.snapshotItems && acceptedStrategy?.targets) return acceptedStrategy;

  const strategy = objectAt(context, "strategy");
  const contextJSON = objectAt(strategy, "context_json");
  const nestedAcceptedStrategy = objectAt(contextJSON, "acceptedStrategy") as FitnessStrategyArtifact | null;
  if (nestedAcceptedStrategy?.snapshotItems && nestedAcceptedStrategy?.targets) return nestedAcceptedStrategy;

  const primary = architecture.priority_order[0] ?? "training";
  return {
    read: architecture.goal_read.summary,
    goalTargetContext: {
      title: architecture.goal_read.summary,
      summary: "Fallback strategy context reconstructed for plan compilation.",
    },
    snapshotItems: [
      { id: "priority", systemImage: "target", value: titleCase(primary), label: "Primary driver" },
    ],
    fitReasons: [],
    pillars: [],
    phases: [],
    operatingRhythm: null,
    targets: [],
  };
}

function firstWeekStartDate(context: JsonRecord) {
  const statuses = arrayAt(context, "weeklyPlanStatuses");
  const first = statuses[0];
  return stringAt(first, "weekStartDate");
}

function normalizedModalities(values: string[]) {
  return Array.from(new Set(values.map(normalizeModality).filter(Boolean)));
}

function objectAt(value: unknown, key: string): JsonRecord | null {
  if (!value || typeof value !== "object") return null;
  const nested = (value as JsonRecord)[key];
  return nested && typeof nested === "object" && !Array.isArray(nested) ? nested as JsonRecord : null;
}

function arrayAt(value: unknown, key: string): unknown[] {
  if (!value || typeof value !== "object") return [];
  const nested = (value as JsonRecord)[key];
  return Array.isArray(nested) ? nested : [];
}

function stringArrayAt(value: unknown, key: string): string[] {
  return arrayAt(value, key).filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0);
}

function stringAt(value: unknown, key: string): string | null {
  if (!value || typeof value !== "object") return null;
  const nested = (value as JsonRecord)[key];
  return typeof nested === "string" && nested.trim().length > 0 ? nested : null;
}

function numberAt(value: unknown, key: string): number | null {
  if (!value || typeof value !== "object") return null;
  const nested = (value as JsonRecord)[key];
  return typeof nested === "number" && Number.isFinite(nested) ? nested : null;
}

function isGoalKind(value: string): value is PlanningPacket["goal_context"]["goal_kind"] {
  return value === "consistency" || value === "specific_goal" || value === "goal_discovery_chosen";
}

function titleCase(value: string) {
  return value
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

const isMain = process.argv[1] ? import.meta.url === pathToFileURL(process.argv[1]).href : false;

if (isMain) {
  const port = Number(process.env.PORT ?? 8787);
  createTrainingOrchestratorServer().listen(port, () => {
    console.log(`Training orchestrator listening on ${port}`);
  });
}
