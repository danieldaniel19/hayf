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

const compactTitleBudget = { maxCharacters: 42, maxWords: 6 };
const compactSummaryBudget = { maxCharacters: 72, maxWords: 12 };
const targetSummaryBudget = compactSummaryBudget;

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
      "Target titles may use at most 6 words or 42 characters; target and phase summaries may use at most 12 words or 72 characters.",
      "Never use em dashes, en dashes, ellipses, raw internal labels, or navigation instructions in user-facing copy.",
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
      "The coach verdict must explain how the athlete will win in one or two sentences, at most 40 words and 240 characters.",
      "The verdict must name the primary path, explain progression, and show how support work or recovery protects the goal.",
      "When training_architecture.reentry.active is true, explain that the opening two weeks rebuild rhythm before focused work is added.",
      "Fit-reason and pillar titles may use at most 6 words or 42 characters; summaries may use at most 12 words or 72 characters.",
      "Never use em dashes, en dashes, ellipses, internal labels, or instructions to review another section.",
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
    testOutput: () => testStrategyOutput(state.packet, architecture, primary),
  });
  const artifact: FitnessStrategyArtifact = {
    read: normalizeStrategyRead(strategyAI.data.read, state.packet, architecture),
    goalTargetContext: {
      title: compactGoalContextTitle(state.packet.goal_context.normalized_goal.title, architecture),
      summary: compactVisibleCopy(
        strategyAI.data.goalTargetContextSummary,
        "This goal sets the direction for the training strategy.",
        targetSummaryBudget,
      ),
    },
    snapshotItems: [
      { id: "priority", systemImage: "target", value: titleCase(primary), label: "Primary driver" },
      { id: "budget", systemImage: "calendar", value: `${architecture.weekly_budget.target_sessions}/wk`, label: "Training budget" },
      { id: "horizon", systemImage: "clock", value: state.packet.goal_context.timeframe_weeks ? `${state.packet.goal_context.timeframe_weeks} wks` : "Rolling", label: "Strategy horizon" },
      architecture.reentry?.active
        ? { id: "reentry", systemImage: "arrow.counterclockwise", value: "Re-entry", label: `${architecture.reentry.gap_days ?? "21+"}-day gap` }
        : { id: "tradeoff", systemImage: "arrow.triangle.branch", value: tradeoffLabel(architecture), label: "Tradeoff read" },
    ],
    fitReasons: mergeFitReasons(strategyAI.data.fitReasons),
    pillars: mergePillars(strategyAI.data.pillars, primary),
    phases: requiresPhases
      ? architecture.phase_logic.phases.map((phase) => ({
        id: phase.id,
        name: phase.name,
        objective: phase.objective,
        startWeek: phase.start_week,
        endWeek: phase.end_week,
        targetSummary: compactVisibleCopy(
          phaseTargetSummaries.get(phase.id),
          "Show progress while keeping recovery intact.",
          targetSummaryBudget,
        ),
        targets: targets.map((target) => ({
          ...target,
          id: `${phase.id}_${target.id}`,
          scope: "phase",
        })),
      }))
      : [],
    operatingRhythm: requiresPhases ? null : {
      summary: compactVisibleCopy(
        strategyAI.data.operatingRhythmSummary,
        "Use the smallest useful week that can repeat consistently.",
        targetSummaryBudget,
      ),
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
    title: { type: "string", maxLength: 42 },
    summary: { type: "string", maxLength: 72 },
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
          targetSummary: { type: "string", maxLength: 72 },
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
    title: { type: "string", maxLength: 42 },
    summary: { type: "string", maxLength: 72 },
  },
};

const fitnessStrategyCopySchema = {
  type: "object",
  additionalProperties: false,
  required: ["read", "goalTargetContextSummary", "fitReasons", "pillars", "operatingRhythmSummary"],
  properties: {
    read: { type: "string", maxLength: 240 },
    goalTargetContextSummary: { type: "string", maxLength: 72 },
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
    operatingRhythmSummary: { type: ["string", "null"], maxLength: 72 },
  },
};

function mergeTargets(seedTargets: StrategyTarget[], aiTargets: TargetAIOutput["strategyTargets"]): StrategyTarget[] {
  const byID = new Map(aiTargets.map((target) => [target.id, target]));
  return seedTargets.map((seed) => {
    const ai = byID.get(seed.id);
    return {
      ...seed,
      title: compactVisibleCopy(ai?.title, seed.title, compactTitleBudget),
      summary: compactVisibleCopy(ai?.summary, seed.summary, targetSummaryBudget),
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
    title: compactVisibleCopy(items[index]?.title, fallback.title, compactTitleBudget),
    summary: compactVisibleCopy(items[index]?.summary, fallback.summary, compactSummaryBudget),
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
    title: compactVisibleCopy(items[index]?.title, fallback.title, compactTitleBudget),
    summary: compactVisibleCopy(items[index]?.summary, fallback.summary, compactSummaryBudget),
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

function testStrategyOutput(packet: PlanningPacket, architecture: TrainingArchitecture, primary: string): StrategyAIOutput {
  return {
    read: deterministicStrategyRead(packet, architecture),
    goalTargetContextSummary: "This goal sets the direction for the training strategy.",
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

function normalizeStrategyRead(
  value: unknown,
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
) {
  const candidate = cleanString(value)?.replace(/\s+/g, " ") ?? "";
  const primary = architecture.priority_order[0] ?? "training";
  const support = architecture.modality_dose.find((dose) => (
    dose.modality !== primary
    && dose.target_sessions > 0
    && dose.role !== "optional_filler"
    && dose.role !== "currently_inappropriate"
  ))?.modality;
  const sentences = candidate.match(/[^.!?]+[.!?]?/g)?.filter((sentence) => sentence.trim()).length ?? 0;
  const includesPrimary = modalityTerms(primary).some((term) => candidate.toLowerCase().includes(term));
  const includesSupport = !support || modalityTerms(support).some((term) => candidate.toLowerCase().includes(term));
  const explainsProgression = /\b(?:add|build|first|increase|progress|progressing|rebuild|then|before|once)\b/i.test(candidate);
  const explainsReentry = !architecture.reentry.active || /\b(?:first two weeks|opening two weeks|rebuild|re-entry|return)\b/i.test(candidate);
  if (
    validVisibleCopy(candidate, { maxCharacters: 240, maxWords: 40 })
    && sentences >= 1
    && sentences <= 2
    && includesPrimary
    && includesSupport
    && explainsProgression
    && explainsReentry
  ) {
    return candidate;
  }
  return deterministicStrategyRead(packet, architecture);
}

function deterministicStrategyRead(packet: PlanningPacket, architecture: TrainingArchitecture) {
  const primary = architecture.priority_order[0] ?? "training";
  const primaryLabel = titleCase(primary).toLowerCase();
  const goalText = [
    JSON.stringify(packet.goal_context.normalized_goal),
    packet.goal_context.success_definition,
    packet.goal_context.body_composition_intent,
  ].filter(Boolean).join(" ").toLowerCase();
  const cyclingPerformanceGoal = primary === "cycling" && /\b(?:vo2|max|climb|climbing|hill)\b/i.test(goalText);
  const firstSentence = architecture.reentry.active
    ? cyclingPerformanceGoal
      ? "We’ll use a two-week re-entry to rebuild cycling rhythm, then add focused work for VO2 max and climbing."
      : `We’ll use a two-week re-entry to rebuild your ${primaryLabel} rhythm before progressing goal-specific work.`
    : cyclingPerformanceGoal
      ? "We’ll build the week around cycling, then progress focused VO2 max and climbing work as recovery holds."
      : `We’ll build the week around ${primaryLabel}, then progress goal-specific work as recovery holds.`;
  const support = architecture.modality_dose.find((dose) => (
    dose.modality !== primary
    && dose.target_sessions > 0
    && dose.role !== "optional_filler"
    && dose.role !== "currently_inappropriate"
  ));
  if (!support) {
    return `${firstSentence} We’ll add load only when consistency and recovery are holding.`;
  }
  if (support.modality === "strength" && /\b(?:fat|lean|muscle|weight|composition)\b/i.test(goalText)) {
    const strengthSubject = support.target_sessions === 2 ? "Two weekly strength sessions" : "Strength sessions";
    return `${firstSentence} ${strengthSubject} will protect muscle while you lean out.`;
  }
  return `${firstSentence} ${titleCase(support.modality)} will support the goal without crowding recovery.`;
}

function compactGoalContextTitle(value: unknown, architecture: TrainingArchitecture) {
  const candidate = visiblePunctuation(String(value ?? "Active goal")).replace(/\s+/g, " ").trim();
  if (validVisibleCopy(candidate, compactTitleBudget)) return candidate;

  const primary = architecture.priority_order[0] ?? "training";
  const lower = candidate.toLowerCase();
  const bodyComposition = /\b(?:lean|muscle|weight|fat|composition|defined)\b/.test(lower);
  if (primary === "cycling") return bodyComposition ? "Cycling fitness and lean muscle" : "Cycling performance goal";
  if (primary === "running") return bodyComposition ? "Running fitness and lean muscle" : "Running performance goal";
  if (primary === "strength") return bodyComposition ? "Strength and body composition" : "Strength goal";
  return `${titleCase(primary)} goal`;
}

function modalityTerms(modality: string) {
  if (modality === "cycling") return ["cycling", "bike", "ride"];
  if (modality === "strength") return ["strength", "gym", "muscle"];
  if (modality === "running") return ["running", "run"];
  return [modality.toLowerCase()];
}

function compactVisibleCopy(
  value: unknown,
  fallback: string,
  budget: { maxCharacters: number; maxWords: number },
) {
  const candidate = cleanString(value)?.replace(/\s+/g, " ") ?? "";
  return validVisibleCopy(candidate, budget) ? candidate : fallback;
}

function validVisibleCopy(
  value: string,
  budget: { maxCharacters: number; maxWords: number },
) {
  const words = value.split(/\s+/).filter(Boolean);
  const forbidden = /[\u2013\u2014\u2026]|\.{3}|\b[a-z][a-z0-9]*_[a-z0-9_]+\b|\b(?:please\s+review|review|plan\s+summary|see\s+(?:above|below)|refer\s+to)\b/i;
  return value.length > 0
    && value.length <= budget.maxCharacters
    && words.length <= budget.maxWords
    && !forbidden.test(value);
}

function visiblePunctuation(value: string) {
  return value
    .replace(/\s*[\u2013\u2014]\s*/g, ": ")
    .replace(/\u2026|\.{3}/g, ".")
    .replace(/_/g, " ")
    .replace(/\s+/g, " ")
    .trim();
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
