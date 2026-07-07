import { Annotation, END, START, StateGraph } from "@langchain/langgraph";
import {
  type FitnessStrategyArtifact,
  type GraphResult,
  type GraphTraceNode,
  type PlanningPacket,
  type StrategyTarget,
  type TrainingArchitecture,
} from "../contracts.js";

type FitnessStrategyState = {
  packet: PlanningPacket;
  training_architecture: TrainingArchitecture;
  artifact?: FitnessStrategyArtifact;
  nodes: GraphTraceNode[];
};

const State = Annotation.Root({
  packet: Annotation<PlanningPacket>(),
  training_architecture: Annotation<TrainingArchitecture>(),
  artifact: Annotation<FitnessStrategyArtifact>(),
  nodes: Annotation<GraphTraceNode[]>({
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

function generateStrategy(state: FitnessStrategyState) {
  const architecture = state.training_architecture;
  const primary = architecture.priority_order[0] ?? "training";
  const requiresPhases = architecture.phase_logic.requires_phases;
  const targets = strategyTargets(architecture);
  const artifact: FitnessStrategyArtifact = {
    read: strategyRead(architecture, primary),
    goalTargetContext: {
      title: String(state.packet.goal_context.normalized_goal.title ?? "Active goal"),
      summary: "This is the user target HAYF is translating into a coaching strategy.",
    },
    snapshotItems: [
      { id: "priority", systemImage: "target", value: titleCase(primary), label: "Primary driver" },
      { id: "budget", systemImage: "calendar", value: `${architecture.weekly_budget.target_sessions}/wk`, label: "Training budget" },
      { id: "horizon", systemImage: "clock", value: state.packet.goal_context.timeframe_weeks ? `${state.packet.goal_context.timeframe_weeks} wks` : "Rolling", label: "Strategy horizon" },
      { id: "tradeoff", systemImage: "arrow.triangle.branch", value: tradeoffLabel(architecture), label: "Tradeoff read" },
    ],
    fitReasons: [
      { id: "blueprint_fit", systemImage: "person.text.rectangle", title: "Blueprint-led", summary: "The strategy starts from the accepted athlete read." },
      { id: "modality_fit", systemImage: "figure.run", title: "Priority-aware", summary: "Support work stays bounded around the primary driver." },
      { id: "recovery_fit", systemImage: "heart", title: "Recovery-aware", summary: "Hard work is capped by the recovery envelope." },
    ],
    pillars: [
      { id: "protect_primary", title: `Protect ${titleCase(primary)}`, summary: "Keep the main goal signal visible every week." },
      { id: "bound_support", title: "Bound support work", summary: "Use secondary modalities without stealing recovery." },
      { id: "earn_progression", title: "Earn progression", summary: "Increase load only when the week is holding." },
    ],
    phases: requiresPhases
      ? architecture.phase_logic.phases.map((phase) => ({
        ...phase,
        targetSummary: "This phase should prove the strategy is moving without breaking recovery.",
        targets: targets.map((target) => ({
          ...target,
          id: `${phase.id}_${target.id}`,
          scope: "phase",
        })),
      }))
      : [],
    operatingRhythm: requiresPhases ? null : {
      summary: "HAYF will treat consistency as the result, using the smallest useful week that can repeat.",
      anchors: architecture.priority_order.slice(0, 3).map(titleCase),
    },
    targets,
  };

  return {
    artifact,
    nodes: trace("generate_fitness_strategy", {
      targetCount: artifact.targets.length,
      phaseCount: artifact.phases.length,
    }),
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
    tool_calls: [],
  };
}

function strategyRead(architecture: TrainingArchitecture, primary: string) {
  if (architecture.conflict_assessment.status === "conflicting") {
    return `HAYF will coach this by forcing the tradeoff into the open before the plan gets concrete. ${titleCase(primary)} stays first, support work is capped, and the week must protect recovery instead of pretending every goal can be maximized at once.`;
  }
  return `HAYF will coach this through a ${titleCase(primary)}-led structure with support work kept useful but bounded. The strategy protects the weekly budget, spaces hard work, and lets progression happen only when the committed week is actually holding.`;
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
