import { Annotation, END, START, StateGraph } from "@langchain/langgraph";
import {
  assertPlanningPacket,
  type GraphResult,
  type GraphTraceNode,
  normalizeModality,
  type PlanningPacket,
  type SpecialistRecommendation,
  type TrainingArchitecture,
} from "../contracts.js";

type TrainingArchitectureState = {
  packet: PlanningPacket;
  master_frame?: {
    modalities: string[];
    priorityOrder: string[];
    targetSessions: number;
    conflictSignals: string[];
  };
  specialists?: SpecialistRecommendation[];
  artifact?: TrainingArchitecture;
  nodes: GraphTraceNode[];
};

const State = Annotation.Root({
  packet: Annotation<PlanningPacket>(),
  master_frame: Annotation<TrainingArchitectureState["master_frame"]>(),
  specialists: Annotation<SpecialistRecommendation[]>({
    reducer: (_, value) => value ?? [],
    default: () => [],
  }),
  artifact: Annotation<TrainingArchitecture>(),
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

function validatePacket(state: TrainingArchitectureState) {
  assertPlanningPacket(state.packet);
  return {
    nodes: trace("validate_packet", {
      blueprint_revision_id: state.packet.athlete_context.blueprint_revision_id,
      goal_kind: state.packet.goal_context.goal_kind,
    }),
  };
}

function masterCoachFraming(state: TrainingArchitectureState) {
  const selected = state.packet.goal_context.selected_modality_order.map(normalizeModality);
  const feasible = state.packet.planning_constraints.feasible_modalities.map(normalizeModality);
  const modalities = Array.from(new Set((selected.length ? selected : feasible).filter(Boolean)));
  const priorityOrder = modalities.length ? modalities : ["general"];
  const targetSessions = Math.max(2, Math.min(6, parseFrequency(state.packet.planning_constraints.frequency)));
  const goalText = JSON.stringify(state.packet.goal_context.normalized_goal).toLowerCase();
  const conflictSignals = [
    goalText.includes("bodybuilder") && goalText.includes("tour de france") ? "maximal_hypertrophy_vs_grand_tour_endurance" : null,
    goalText.includes("lose") && goalText.includes("power") ? "body_composition_vs_performance_fatigue" : null,
  ].filter(Boolean) as string[];

  return {
    master_frame: { modalities, priorityOrder, targetSessions, conflictSignals },
    nodes: trace("master_coach_framing", { modalities, priorityOrder, targetSessions, conflictSignals }),
  };
}

function specialistSubgraphs(state: TrainingArchitectureState) {
  const frame = state.master_frame;
  const modalities = frame?.modalities.length ? frame.modalities : ["general"];
  const specialists = modalities.map((modality, index): SpecialistRecommendation => {
    const primary = index === 0;
    return {
      coach: `${modality}_coach`,
      modality,
      role: primary ? "primary_driver" : modality === "running" ? "optional_filler" : "secondary_support",
      development_path: developmentPath(modality, state.packet),
      weekly_dose: primary ? "protected recurring exposure" : "dose capped around the primary driver",
      key_risks: keyRisks(modality),
      planning_rules: planningRules(modality, primary),
    };
  });

  return {
    specialists,
    nodes: trace("specialist_subgraphs", { specialistCount: specialists.length, specialists }),
  };
}

function synthesizeArchitecture(state: TrainingArchitectureState) {
  const packet = state.packet;
  const frame = state.master_frame ?? {
    modalities: ["general"],
    priorityOrder: ["general"],
    targetSessions: 3,
    conflictSignals: [],
  };
  const specialists = state.specialists ?? [];
  const requiresPhases = packet.goal_context.goal_kind !== "consistency";
  const conflictStatus = frame.conflictSignals.length > 0 ? "conflicting" : specialists.length > 2 ? "manageable_tradeoff" : "clear";
  const artifact: TrainingArchitecture = {
    source_ids: {
      blueprint_revision_id: packet.athlete_context.blueprint_revision_id,
      user_goal_id: packet.goal_context.user_goal_id,
    },
    goal_read: {
      summary: goalSummary(packet),
      goal_kind: packet.goal_context.goal_kind,
      success_definition: packet.goal_context.success_definition,
    },
    modality_roles: specialists.map((specialist) => ({
      modality: specialist.modality,
      role: specialist.role,
      rationale: specialist.role === "primary_driver"
        ? "This modality best expresses the stated goal and should anchor progression."
        : "This modality supports the goal without being allowed to consume the recovery budget.",
    })),
    priority_order: frame.priorityOrder,
    weekly_budget: {
      target_sessions: frame.targetSessions,
      minimum_viable_sessions: Math.max(1, Math.min(3, frame.targetSessions - 1)),
      hard_sessions: Math.max(1, Math.min(2, Math.floor(frame.targetSessions / 3))),
      recovery_sessions: 1,
    },
    recovery_envelope: {
      max_hard_days_per_week: Math.max(1, Math.min(2, Math.floor(frame.targetSessions / 3))),
      spacing_rules: ["Do not stack hard lower-body strength and hard endurance on adjacent days unless the week has no alternative."],
      bad_day_floor: packet.planning_constraints.bad_day_floor,
    },
    minimum_effective_dose_rules: [
      "Protect the minimum viable week before adding optional work.",
      "Keep the primary modality visible every week unless injury, illness, or travel makes it inappropriate.",
    ],
    specialist_recommendations: specialists,
    phase_logic: {
      requires_phases: requiresPhases,
      phases: requiresPhases
        ? [
          { id: "base", name: "Base", objective: "Make the weekly structure reliable." },
          { id: "build", name: "Build", objective: "Increase goal-specific dose." },
          { id: "review", name: "Review", objective: "Confirm progress and decide the next move." },
        ]
        : [],
    },
    progression_rules: [
      "Progress only when the committed week is mostly completed and recovery caveats are not worsening.",
      "Prefer a small dose increase over adding a new modality when adherence is uncertain.",
    ],
    interference_rules: [
      "Protect quality days for the primary modality.",
      "Use support modalities as reinforcement, not competition for the same fatigue budget.",
    ],
    conflict_assessment: {
      status: conflictStatus,
      summary: conflictStatus === "conflicting"
        ? "The stated goals cannot all be maximized at the same time without prioritization."
        : conflictStatus === "manageable_tradeoff"
          ? "The goal is viable if support modalities stay bounded."
          : "No major conflict is visible in the planning packet.",
      required_tradeoffs: frame.conflictSignals.length ? frame.conflictSignals : ["Recovery and adherence take precedence over optional volume."],
    },
    planner_constraints: {
      weekly_plan_rules: ["Week 1 is committed; week 2 is draft and must preserve user-authored constraints."],
      workout_generation_rules: ["Every workout must have a purpose tied to the Training Architecture."],
      target_generation_rules: ["Targets must be measurable from planned workouts, actual workouts, body entries, or performance observations."],
    },
  };

  return {
    artifact,
    nodes: trace("master_coach_synthesis", {
      priority_order: artifact.priority_order,
      conflict_status: artifact.conflict_assessment.status,
    }),
  };
}

function validateArchitecture(state: TrainingArchitectureState) {
  if (!state.artifact?.priority_order.length) {
    throw new Error("Training Architecture requires a priority order.");
  }
  return {
    nodes: trace("validate_architecture", {
      valid: true,
      modalityCount: state.artifact.modality_roles.length,
    }),
  };
}

export const trainingArchitectureGraph = new StateGraph(State)
  .addNode("validate_packet", validatePacket)
  .addNode("master_coach_framing", masterCoachFraming)
  .addNode("specialist_subgraphs", specialistSubgraphs)
  .addNode("master_coach_synthesis", synthesizeArchitecture)
  .addNode("validate_architecture", validateArchitecture)
  .addEdge(START, "validate_packet")
  .addEdge("validate_packet", "master_coach_framing")
  .addEdge("master_coach_framing", "specialist_subgraphs")
  .addEdge("specialist_subgraphs", "master_coach_synthesis")
  .addEdge("master_coach_synthesis", "validate_architecture")
  .addEdge("validate_architecture", END)
  .compile();

export async function invokeTrainingArchitectureGraph(packet: PlanningPacket): Promise<GraphResult<TrainingArchitecture>> {
  const state = await trainingArchitectureGraph.invoke({ packet });
  if (!state.artifact) {
    throw new Error("Training Architecture graph completed without an artifact.");
  }
  return {
    artifact: state.artifact,
    nodes: state.nodes,
    tool_calls: [],
  };
}

function parseFrequency(value: string | null) {
  const match = value?.match(/\d+/);
  return match ? Number(match[0]) : 3;
}

function developmentPath(modality: string, packet: PlanningPacket) {
  if (modality === "cycling") return "aerobic durability, climbing-specific quality, and fatigue-managed intensity";
  if (modality === "strength") return packet.goal_context.body_composition_intent
    ? "hypertrophy-preserving strength with visible-athletic support"
    : "general strength continuity and movement quality";
  if (modality === "running") return "light aerobic support unless explicitly promoted by the goal";
  return "repeatable general training exposure";
}

function keyRisks(modality: string) {
  if (modality === "cycling") return ["lower-body fatigue can crowd strength quality"];
  if (modality === "strength") return ["soreness can reduce endurance quality"];
  if (modality === "running") return ["extra impact can compete with recovery"];
  return ["too much novelty can reduce adherence"];
}

function planningRules(modality: string, primary: boolean) {
  if (primary) return [`Protect ${modality} quality before optional support work.`];
  return [`Keep ${modality} bounded unless the active goal explicitly promotes it.`];
}

function goalSummary(packet: PlanningPacket) {
  const title = String(packet.goal_context.normalized_goal.title ?? packet.goal_context.success_definition ?? "the active goal");
  return `Build training around ${title}.`;
}
