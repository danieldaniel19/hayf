import {
  type FitnessStrategyArtifact,
  type GraphResult,
  type GraphToolCall,
  type JsonObject,
  type PlanningPacket,
  type TrainingArchitecture,
  type TwoWeekPlanArtifact,
} from "./contracts.js";
import { invokeFitnessStrategyGraph } from "./graphs/fitness-strategy.js";
import { invokeTrainingArchitectureGraph } from "./graphs/training-architecture.js";
import { invokeTwoWeekPlanGraph } from "./graphs/two-week-plan.js";
import { loadKnowledgeManifest, sourceRefs } from "./knowledge/manifest.js";

type GraphName = "training_architecture" | "fitness_strategy" | "two_week_plan" | "prepare_initial_strategy";

type ObservabilityNode = {
  id: string;
  label: string;
  kind: "deterministic" | "model" | "fanout" | "composite";
  purpose: string;
  toolCalls: string[];
  inputContract: string;
  outputContract: string;
  knowledgeRefs: string[];
};

type ObservabilityGraph = {
  name: GraphName;
  label: string;
  purpose: string;
  nodes: ObservabilityNode[];
  edges: Array<{ from: string; to: string }>;
};

type ObservabilityRunResult = {
  graphName: GraphName;
  artifact?: unknown;
  artifacts?: Record<string, unknown>;
  nodes: unknown[];
  toolCalls: GraphToolCall[];
};

const sharedKnowledgeRefs = [
  "core.training_doctrine",
  "policy.hayf_planning",
  "goal.consistency",
  "goal.body_composition",
  "goal.performance",
  "modality.cycling",
  "modality.strength",
  "modality.running",
  "modality.generic",
];

export const OBSERVABILITY_GRAPHS: ObservabilityGraph[] = [
  {
    name: "training_architecture",
    label: "Training Architecture",
    purpose: "Validate a compact planning packet, consult modality specialists, synthesize the architecture, and author a reasoning trace.",
    nodes: [
      node("validate_packet", "Validate Packet", "deterministic", "Reject raw evidence and confirm the compact packet contract.", [], "PlanningPacket", "packet summary", []),
      node("load_knowledge_manifest", "Load Knowledge", "deterministic", "Load static HAYF training doctrine, policy, goal, and modality packs.", [], "none", "KnowledgePack[]", sharedKnowledgeRefs),
      node("architect_frame", "Architect Frame", "deterministic", "Build the shared frame, selected modalities, budget hypotheses, specialist briefs, and knowledge refs.", [], "PlanningPacket + KnowledgePack[]", "TrainingArchitectFrame", sharedKnowledgeRefs),
      node("specialist_consultations", "Specialists", "fanout", "Run selected modality consultants in parallel and collect reusable archetype proposals.", [
        "consult_cycling_specialist",
        "consult_strength_specialist",
        "consult_running_specialist",
        "consult_<modality>_generic_specialist",
      ], "TrainingArchitectFrame + PlanningPacket", "SpecialistConsultation[]", sharedKnowledgeRefs),
      node("architect_synthesis", "Architect Synthesis", "model", "Consolidate specialists into final roles, priority order, budget, conflict handling, and planner constraints.", ["synthesize_training_architecture"], "TrainingArchitectFrame + SpecialistConsultation[]", "TrainingArchitecture", sharedKnowledgeRefs),
      node("deterministic_validation", "Deterministic Validation", "deterministic", "Assert final architecture invariants before it can reach product storage.", [], "TrainingArchitecture", "validation summary", []),
      node("author_training_architecture_reasoning", "Reasoning Trace", "model", "Explain why the validated architecture is coherent without changing it.", ["author_training_architecture_reasoning"], "TrainingArchitecture", "ArchitectureReasoningOutput", sharedKnowledgeRefs),
    ],
    edges: [
      edge("__start__", "validate_packet"),
      edge("validate_packet", "load_knowledge_manifest"),
      edge("load_knowledge_manifest", "architect_frame"),
      edge("architect_frame", "specialist_consultations"),
      edge("specialist_consultations", "architect_synthesis"),
      edge("architect_synthesis", "deterministic_validation"),
      edge("deterministic_validation", "author_training_architecture_reasoning"),
      edge("author_training_architecture_reasoning", "__end__"),
    ],
  },
  {
    name: "fitness_strategy",
    label: "Fitness Strategy",
    purpose: "Turn a validated Training Architecture into strategy targets and user-facing strategy copy.",
    nodes: [
      node("generate_strategy", "Generate Strategy", "model", "Generate measurable targets and concise strategy copy from the architecture.", [
        "generate_fitness_strategy_targets",
        "generate_fitness_strategy",
      ], "PlanningPacket + TrainingArchitecture", "FitnessStrategyArtifact", sharedKnowledgeRefs),
    ],
    edges: [edge("__start__", "generate_strategy"), edge("generate_strategy", "__end__")],
  },
  {
    name: "two_week_plan",
    label: "Two-Week Plan",
    purpose: "Compile two visible planning weeks from the validated architecture and accepted strategy.",
    nodes: [
      node("generate_plan", "Generate Plan", "model", "Build the planner input contract and compile one committed week plus one draft week.", ["compile_two_week_plan"], "PlanningPacket + TrainingArchitecture + FitnessStrategyArtifact", "TwoWeekPlanArtifact", sharedKnowledgeRefs),
    ],
    edges: [edge("__start__", "generate_plan"), edge("generate_plan", "__end__")],
  },
  {
    name: "prepare_initial_strategy",
    label: "Prepare Initial Strategy",
    purpose: "Composite local pipeline that prepares both Training Architecture and Fitness Strategy.",
    nodes: [
      node("training_architecture", "Training Architecture", "composite", "Run the Training Architecture graph.", [], "PlanningPacket", "TrainingArchitecture", sharedKnowledgeRefs),
      node("fitness_strategy", "Fitness Strategy", "composite", "Run the Fitness Strategy graph using the architecture artifact.", [], "PlanningPacket + TrainingArchitecture", "FitnessStrategyArtifact", sharedKnowledgeRefs),
    ],
    edges: [edge("__start__", "training_architecture"), edge("training_architecture", "fitness_strategy"), edge("fitness_strategy", "__end__")],
  },
];

export function observabilityGraphs() {
  const manifest = loadKnowledgeManifest();
  const knowledge = sourceRefs(manifest).map((ref) => ({
    ...ref,
    summary: manifest.find((pack) => pack.id === ref.id)?.summary ?? "",
  }));
  return {
    graphs: OBSERVABILITY_GRAPHS,
    knowledge,
    traceLevel: process.env.HAYF_OBSERVABILITY_TRACE_LEVEL === "full" ? "full" : "compact",
  };
}

export async function runObservabilityGraph(body: JsonObject): Promise<ObservabilityRunResult> {
  const graphName = graphNameFrom(body.graphName ?? body.graph_name);
  const fixture = recordAt(body, "fixture") ?? body;
  const packet = packetFrom(fixture);

  if (graphName === "training_architecture") {
    const result = await invokeTrainingArchitectureGraph(packet);
    return resultFor(graphName, result);
  }

  if (graphName === "fitness_strategy") {
    const architecture = recordAt(fixture, "trainingArchitecture") as TrainingArchitecture | null
      ?? (await invokeTrainingArchitectureGraph(packet)).artifact;
    const result = await invokeFitnessStrategyGraph(packet, architecture);
    return resultFor(graphName, result);
  }

  if (graphName === "two_week_plan") {
    const architecture = recordAt(fixture, "trainingArchitecture") as TrainingArchitecture | null
      ?? (await invokeTrainingArchitectureGraph(packet)).artifact;
    const strategy = recordAt(fixture, "fitnessStrategy") as FitnessStrategyArtifact | null
      ?? (await invokeFitnessStrategyGraph(packet, architecture)).artifact;
    const result = await invokeTwoWeekPlanGraph(packet, architecture, strategy);
    return resultFor(graphName, result);
  }

  const architecture = await invokeTrainingArchitectureGraph(packet);
  const strategy = await invokeFitnessStrategyGraph(packet, architecture.artifact);
  return {
    graphName,
    artifacts: {
      trainingArchitecture: architecture.artifact,
      fitnessStrategy: strategy.artifact,
    },
    nodes: [...architecture.nodes, ...strategy.nodes],
    toolCalls: [...architecture.tool_calls, ...strategy.tool_calls],
  };
}

export async function runObservabilityToolTest(body: JsonObject) {
  const toolName = stringAt(body, "toolName") ?? stringAt(body, "tool_name");
  if (!toolName) throw new Error("Tool test requires toolName.");
  const result = await runObservabilityGraph({
    graphName: graphForTool(toolName),
    fixture: recordAt(body, "fixture") ?? {},
  });
  const toolCall = result.toolCalls.find((call) => toolMatches(call.tool_name, toolName));
  if (!toolCall) {
    throw new Error(`Tool call ${toolName} did not run for the provided fixture.`);
  }
  return {
    ok: toolCall.status === "succeeded",
    toolName: toolCall.tool_name,
    graphNodeName: toolCall.graph_node_name ?? null,
    status: toolCall.status,
    latencyMS: toolCall.latency_ms ?? null,
    request: toolCall.request_json ?? toolCall.input,
    output: toolCall.output,
    raw: toolCall,
  };
}

function resultFor<T>(graphName: GraphName, result: GraphResult<T>): ObservabilityRunResult {
  return {
    graphName,
    artifact: result.artifact,
    nodes: result.nodes,
    toolCalls: result.tool_calls,
  };
}

function graphForTool(toolName: string): GraphName {
  if (toolName === "compile_two_week_plan") return "two_week_plan";
  if (toolName === "generate_fitness_strategy" || toolName === "generate_fitness_strategy_targets") return "fitness_strategy";
  return "training_architecture";
}

function toolMatches(actual: string, expected: string) {
  if (actual === expected) return true;
  if (expected.includes("<modality>")) {
    const pattern = expected.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace("<modality>", "[a-z_]+");
    return new RegExp(`^${pattern}$`).test(actual);
  }
  return false;
}

function packetFrom(value: JsonObject): PlanningPacket {
  const packet = recordAt(value, "planningPacket") ?? recordAt(value, "planning_packet") ?? value;
  if (!isRecord(packet)) throw new Error("Observability run requires a planningPacket fixture.");
  return packet as PlanningPacket;
}

function graphNameFrom(value: unknown): GraphName {
  if (
    value === "training_architecture" ||
    value === "fitness_strategy" ||
    value === "two_week_plan" ||
    value === "prepare_initial_strategy"
  ) {
    return value;
  }
  throw new Error("Unknown observability graph.");
}

function node(
  id: string,
  label: string,
  kind: ObservabilityNode["kind"],
  purpose: string,
  toolCalls: string[],
  inputContract: string,
  outputContract: string,
  knowledgeRefs: string[],
): ObservabilityNode {
  return { id, label, kind, purpose, toolCalls, inputContract, outputContract, knowledgeRefs };
}

function edge(from: string, to: string) {
  return { from, to };
}

function recordAt(value: JsonObject, key: string): JsonObject | null {
  const entry = value[key];
  return isRecord(entry) ? entry : null;
}

function stringAt(value: JsonObject, key: string) {
  const entry = value[key];
  return typeof entry === "string" ? entry : null;
}

function isRecord(value: unknown): value is JsonObject {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}
