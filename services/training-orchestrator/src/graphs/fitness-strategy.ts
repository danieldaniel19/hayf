import { Annotation, END, START, StateGraph } from "@langchain/langgraph";
import {
  type FitnessStrategyArtifact,
  type GraphResult,
  type GraphTraceNode,
  type GraphToolCall,
  type PlanningPacket,
  type StrategyTarget,
  type TrainingArchitecture,
} from "../contracts.js";
import { runStructuredJSON } from "../ai/openai.js";

type FitnessStrategyState = {
  packet: PlanningPacket;
  training_architecture: TrainingArchitecture;
  artifact?: FitnessStrategyArtifact;
  nodes: GraphTraceNode[];
  tool_calls: GraphToolCall[];
};

const State = Annotation.Root({
  packet: Annotation<PlanningPacket>(),
  training_architecture: Annotation<TrainingArchitecture>(),
  artifact: Annotation<FitnessStrategyArtifact>(),
  nodes: Annotation<GraphTraceNode[]>({
    reducer: (left, right) => [...left, ...right],
    default: () => [],
  }),
  tool_calls: Annotation<GraphToolCall[]>({
    reducer: (left, right) => [...left, ...right],
    default: () => [],
  }),
});

function trace(node_name: string, output: Record<string, unknown>): GraphTraceNode[] {
  return [{
    node_name,
    input_summary: {},
    output,
    validation: { valid: true },
    status: "succeeded",
  }];
}

type TargetAIOutput = {
  strategyTargets: Array<{
    id: string;
    title: string;
    summary: string;
    direction: StrategyTarget["direction"];
    targetValue: number | null;
    unit: string | null;
    displayValue: string | null;
  }>;
  phaseTargetSummaries: Array<{
    phaseID: string;
    targetSummary: string;
  }>;
};

type StrategyAIOutput = {
  read: string;
  goalTargetContextSummary: string;
  fitReasons: Array<{
    id: string;
    title: string;
    summary: string;
  }>;
  pillars: Array<{
    id: string;
    title: string;
    summary: string;
  }>;
  operatingRhythmSummary: string | null;
};

async function generateStrategy(state: FitnessStrategyState) {
  const architecture = state.training_architecture;
  const primary = architecture.priority_order[0] ?? "training";
  const requiresPhases = architecture.phase_logic.requires_phases;
  const seedTargets = strategyTargets(architecture);
  const targetAI = await runStructuredJSON<TargetAIOutput>({
    toolName: "generate_fitness_strategy_targets",
    graphNodeName: "generate_strategy",
    system: [
      "You are HAYF's Fitness Strategy target writer.",
      "Use only the validated Training Architecture and compact planning packet.",
      "Return measurable strategy targets that are coherent with the weekly budget, recovery envelope, and goal kind.",
      "Do not invent raw workout evidence or medical claims.",
    ].join(" "),
    input: {
      goal_context: state.packet.goal_context,
      planning_constraints: state.packet.planning_constraints,
      training_architecture: architecture,
      seed_targets: seedTargets,
    },
    inputSummary: {
      goalKind: state.packet.goal_context.goal_kind,
      priorityOrder: architecture.priority_order,
      weeklyBudget: architecture.weekly_budget,
      seedTargetIDs: seedTargets.map((target) => target.id),
    },
    schema: fitnessStrategyTargetsSchema,
    knowledgeRefs: architecture.source_knowledge_refs,
    testOutput: () => testTargetOutput(seedTargets, architecture),
  });
  const targets = mergeTargets(seedTargets, targetAI.data.strategyTargets);
  const phaseTargetSummaries = new Map(targetAI.data.phaseTargetSummaries.map((phase) => [phase.phaseID, phase.targetSummary]));
  const strategyAI = await runStructuredJSON<StrategyAIOutput>({
    toolName: "generate_fitness_strategy",
    graphNodeName: "generate_strategy",
    system: [
      "You are HAYF's Fitness Strategy writer.",
      "Write concise coaching copy for the reveal screen using the validated Training Architecture and generated targets.",
      "Be specific to the goal, modalities, weekly budget, and tradeoffs. Avoid generic motivational filler.",
    ].join(" "),
    input: {
      goal_context: state.packet.goal_context,
      training_architecture: architecture,
      targets,
    },
    inputSummary: {
      goalKind: state.packet.goal_context.goal_kind,
      primary,
      targetCount: targets.length,
      conflictStatus: architecture.conflict_assessment.status,
    },
    schema: fitnessStrategyCopySchema,
    knowledgeRefs: architecture.source_knowledge_refs,
    testOutput: () => testStrategyOutput(architecture, primary),
  });
  const artifact: FitnessStrategyArtifact = {
    read: strategyAI.data.read,
    goalTargetContext: {
      title: String(state.packet.goal_context.normalized_goal.title ?? "Active goal"),
      summary: strategyAI.data.goalTargetContextSummary,
    },
    snapshotItems: [
      { id: "priority", systemImage: "target", value: titleCase(primary), label: "Primary driver" },
      { id: "budget", systemImage: "calendar", value: `${architecture.weekly_budget.target_sessions}/wk`, label: "Training budget" },
      { id: "horizon", systemImage: "clock", value: state.packet.goal_context.timeframe_weeks ? `${state.packet.goal_context.timeframe_weeks} wks` : "Rolling", label: "Strategy horizon" },
      { id: "tradeoff", systemImage: "arrow.triangle.branch", value: tradeoffLabel(architecture), label: "Tradeoff read" },
    ],
    fitReasons: mergeFitReasons(strategyAI.data.fitReasons),
    pillars: mergePillars(strategyAI.data.pillars, primary),
    phases: requiresPhases
      ? architecture.phase_logic.phases.map((phase) => ({
        ...phase,
        targetSummary: phaseTargetSummaries.get(phase.id) ?? "This phase should prove the strategy is moving without breaking recovery.",
        targets: targets.map((target) => ({
          ...target,
          id: `${phase.id}_${target.id}`,
          scope: "phase",
        })),
      }))
      : [],
    operatingRhythm: requiresPhases ? null : {
      summary: strategyAI.data.operatingRhythmSummary ?? "HAYF will treat consistency as the result, using the smallest useful week that can repeat.",
      anchors: architecture.priority_order.slice(0, 3).map(titleCase),
    },
    targets,
  };

  return {
    artifact,
    nodes: [
      ...trace("generate_fitness_strategy_targets", {
        targetCount: artifact.targets.length,
        phaseTargetSummaryCount: phaseTargetSummaries.size,
      }),
      ...trace("generate_fitness_strategy", {
        targetCount: artifact.targets.length,
        phaseCount: artifact.phases.length,
        fitReasonCount: artifact.fitReasons.length,
        pillarCount: artifact.pillars.length,
      }),
    ],
    tool_calls: [targetAI.toolCall, strategyAI.toolCall],
  };
}

export const fitnessStrategyGraph = new StateGraph(State)
  .addNode("generate_strategy", generateStrategy)
  .addEdge(START, "generate_strategy")
  .addEdge("generate_strategy", END)
  .compile();

export async function invokeFitnessStrategyGraph(
  packet: PlanningPacket,
  training_architecture: TrainingArchitecture,
): Promise<GraphResult<FitnessStrategyArtifact>> {
  const state = await fitnessStrategyGraph.invoke({ packet, training_architecture });
  if (!state.artifact) {
    throw new Error("Fitness Strategy graph completed without an artifact.");
  }
  return {
    artifact: state.artifact,
    nodes: state.nodes,
    tool_calls: state.tool_calls,
  };
}

const targetShape = {
  type: "object",
  additionalProperties: false,
  required: ["id", "title", "summary", "direction", "targetValue", "unit", "displayValue"],
  properties: {
    id: { type: "string" },
    title: { type: "string" },
    summary: { type: "string" },
    direction: { type: "string", enum: ["increase", "decrease", "maintain", "complete", "review"] },
    targetValue: { type: ["number", "null"] },
    unit: { type: ["string", "null"] },
    displayValue: { type: ["string", "null"] },
  },
};

const fitnessStrategyTargetsSchema = {
  type: "object",
  additionalProperties: false,
  required: ["strategyTargets", "phaseTargetSummaries"],
  properties: {
    strategyTargets: {
      type: "array",
      minItems: 3,
      maxItems: 5,
      items: targetShape,
    },
    phaseTargetSummaries: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["phaseID", "targetSummary"],
        properties: {
          phaseID: { type: "string" },
          targetSummary: { type: "string" },
        },
      },
    },
  },
};

const copyItemShape = {
  type: "object",
  additionalProperties: false,
  required: ["id", "title", "summary"],
  properties: {
    id: { type: "string" },
    title: { type: "string" },
    summary: { type: "string" },
  },
};

const fitnessStrategyCopySchema = {
  type: "object",
  additionalProperties: false,
  required: ["read", "goalTargetContextSummary", "fitReasons", "pillars", "operatingRhythmSummary"],
  properties: {
    read: { type: "string" },
    goalTargetContextSummary: { type: "string" },
    fitReasons: {
      type: "array",
      minItems: 3,
      maxItems: 3,
      items: copyItemShape,
    },
    pillars: {
      type: "array",
      minItems: 3,
      maxItems: 3,
      items: copyItemShape,
    },
    operatingRhythmSummary: { type: ["string", "null"] },
  },
};

function mergeTargets(seedTargets: StrategyTarget[], aiTargets: TargetAIOutput["strategyTargets"]): StrategyTarget[] {
  const byID = new Map(aiTargets.map((target) => [target.id, target]));
  return seedTargets.map((seed) => {
    const ai = byID.get(seed.id);
    return {
      ...seed,
      title: cleanString(ai?.title) ?? seed.title,
      summary: cleanString(ai?.summary) ?? seed.summary,
      direction: ai?.direction ?? seed.direction,
      targetValue: typeof ai?.targetValue === "number" ? ai.targetValue : seed.targetValue,
      unit: ai?.unit ?? seed.unit,
      displayValue: ai?.displayValue ?? seed.displayValue,
    };
  });
}

function mergeFitReasons(items: StrategyAIOutput["fitReasons"]) {
  const defaults = [
    { id: "blueprint_fit", systemImage: "person.text.rectangle", title: "Blueprint-led", summary: "The strategy starts from the accepted athlete read." },
    { id: "modality_fit", systemImage: "figure.run", title: "Priority-aware", summary: "Support work stays bounded around the primary driver." },
    { id: "recovery_fit", systemImage: "heart", title: "Recovery-aware", summary: "Hard work is capped by the recovery envelope." },
  ];
  return defaults.map((fallback, index) => ({
    ...fallback,
    id: cleanString(items[index]?.id) ?? fallback.id,
    title: cleanString(items[index]?.title) ?? fallback.title,
    summary: cleanString(items[index]?.summary) ?? fallback.summary,
  }));
}

function mergePillars(items: StrategyAIOutput["pillars"], primary: string) {
  const defaults = [
    { id: "protect_primary", title: `Protect ${titleCase(primary)}`, summary: "Keep the main goal signal visible every week." },
    { id: "bound_support", title: "Bound support work", summary: "Use secondary modalities without stealing recovery." },
    { id: "earn_progression", title: "Earn progression", summary: "Increase load only when the week is holding." },
  ];
  return defaults.map((fallback, index) => ({
    ...fallback,
    id: cleanString(items[index]?.id) ?? fallback.id,
    title: cleanString(items[index]?.title) ?? fallback.title,
    summary: cleanString(items[index]?.summary) ?? fallback.summary,
  }));
}

function testTargetOutput(seedTargets: StrategyTarget[], architecture: TrainingArchitecture): TargetAIOutput {
  return {
    strategyTargets: seedTargets.map((target) => ({
      id: target.id,
      title: target.title,
      summary: target.summary,
      direction: target.direction,
      targetValue: target.targetValue,
      unit: target.unit,
      displayValue: target.displayValue,
    })),
    phaseTargetSummaries: architecture.phase_logic.phases.map((phase) => ({
      phaseID: phase.id,
      targetSummary: `Use ${phase.name} to prove the goal is progressing inside the recovery budget.`,
    })),
  };
}

function testStrategyOutput(architecture: TrainingArchitecture, primary: string): StrategyAIOutput {
  return {
    read: architecture.conflict_assessment.status === "conflicting"
      ? `HAYF will coach this by forcing the tradeoff into the open before the plan gets concrete. ${titleCase(primary)} stays first, support work is capped, and the week must protect recovery.`
      : `HAYF will coach this through a ${titleCase(primary)}-led structure with support work kept useful but bounded by the weekly budget and recovery envelope.`,
    goalTargetContextSummary: "This is the user target HAYF is translating into a coaching strategy.",
    fitReasons: [
      { id: "blueprint_fit", title: "Blueprint-led", summary: "The strategy starts from the accepted athlete read." },
      { id: "modality_fit", title: "Priority-aware", summary: "Support work stays bounded around the primary driver." },
      { id: "recovery_fit", title: "Recovery-aware", summary: "Hard work is capped by the recovery envelope." },
    ],
    pillars: [
      { id: "protect_primary", title: `Protect ${titleCase(primary)}`, summary: "Keep the main goal signal visible every week." },
      { id: "bound_support", title: "Bound support work", summary: "Use secondary modalities without stealing recovery." },
      { id: "earn_progression", title: "Earn progression", summary: "Increase load only when the week is holding." },
    ],
    operatingRhythmSummary: architecture.phase_logic.requires_phases
      ? null
      : "HAYF will treat consistency as the result, using the smallest useful week that can repeat.",
  };
}

function cleanString(value: unknown) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function strategyTargets(architecture: TrainingArchitecture): StrategyTarget[] {
  const primary = architecture.priority_order[0] ?? "training";
  return [
    {
      id: "primary_exposure",
      scope: "strategy",
      kind: "primary",
      title: `${titleCase(primary)} weeks`,
      summary: "Keep the primary training signal present across the strategy.",
      metricKey: "planned_session_completion",
      metricCategory: primary,
      direction: "complete",
      targetValue: architecture.weekly_budget.minimum_viable_sessions,
      unit: "sessions/week",
      displayValue: `${architecture.weekly_budget.minimum_viable_sessions}/wk`,
    },
    {
      id: "weekly_rhythm",
      scope: "strategy",
      kind: "supporting",
      title: "Rhythm weeks",
      summary: "Complete enough sessions for the week to count.",
      metricKey: "training_workouts_7d",
      metricCategory: "consistency",
      direction: "maintain",
      targetValue: architecture.weekly_budget.minimum_viable_sessions,
      unit: "sessions/week",
      displayValue: `${architecture.weekly_budget.minimum_viable_sessions}/wk`,
    },
    {
      id: "hard_day_cap",
      scope: "strategy",
      kind: "supporting",
      title: "Hard day cap",
      summary: "Keep hard training inside the recovery envelope.",
      metricKey: "hard_sessions_per_week",
      metricCategory: "recovery",
      direction: "maintain",
      targetValue: architecture.recovery_envelope.max_hard_days_per_week,
      unit: "sessions/week",
      displayValue: `${architecture.recovery_envelope.max_hard_days_per_week}/wk`,
    },
  ];
}

function tradeoffLabel(architecture: TrainingArchitecture) {
  switch (architecture.conflict_assessment.status) {
    case "conflicting": return "Needs priority";
    case "manageable_tradeoff": return "Managed";
    case "clear": return "Clear";
  }
}

function titleCase(value: string) {
  return value
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}
