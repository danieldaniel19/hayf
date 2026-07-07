import { Annotation, END, START, StateGraph } from "@langchain/langgraph";
import {
  type FitnessStrategyArtifact,
  type GraphResult,
  type GraphTraceNode,
  type PlanningPacket,
  type TrainingArchitecture,
  type TwoWeekPlanArtifact,
} from "../contracts.js";

type TwoWeekPlanState = {
  packet: PlanningPacket;
  training_architecture: TrainingArchitecture;
  fitness_strategy: FitnessStrategyArtifact;
  artifact?: TwoWeekPlanArtifact;
  nodes: GraphTraceNode[];
};

const State = Annotation.Root({
  packet: Annotation<PlanningPacket>(),
  training_architecture: Annotation<TrainingArchitecture>(),
  fitness_strategy: Annotation<FitnessStrategyArtifact>(),
  artifact: Annotation<TwoWeekPlanArtifact>(),
  nodes: Annotation<GraphTraceNode[]>({
    reducer: (left, right) => [...left, ...right],
    default: () => [],
  }),
});

function generatePlan(state: TwoWeekPlanState) {
  const packet = state.packet;
  const architecture = state.training_architecture;
  const start = parseDate(packet.planning_constraints.start_date);
  const firstWeek = weekRhythm(start, "committed", architecture, packet, 0);
  const secondWeek = weekRhythm(addDays(start, 7), "draft", architecture, packet, 1);
  const artifact: TwoWeekPlanArtifact = {
    block: {
      kind: packet.goal_context.goal_kind,
      title: state.fitness_strategy.snapshotItems.find((item) => item.id === "priority")?.value ?? "Training Strategy",
      goalText: String(packet.goal_context.normalized_goal.title ?? "Active goal"),
      startDate: isoDate(start),
      targetDate: packet.goal_context.timeframe_weeks
        ? isoDate(addDays(start, packet.goal_context.timeframe_weeks * 7 - 1))
        : null,
      reviewCadenceDays: packet.goal_context.goal_kind === "consistency" ? 28 : Math.max(28, (packet.goal_context.timeframe_weeks ?? 8) * 7),
      context: {
        trainingArchitecture: architecture,
        planningRationale: architecture.goal_read.summary,
        dataFreshness: packet.approved_evidence_summary.confidence,
      },
    },
    phases: architecture.phase_logic.phases.map((phase) => ({
      name: phase.name,
      startDate: null,
      endDate: null,
      objective: phase.objective,
      focus: [phase.objective],
      risk: architecture.conflict_assessment.required_tradeoffs,
    })),
    rhythms: [firstWeek, secondWeek],
  };

  return {
    artifact,
    nodes: [{
      node_name: "generate_two_week_plan",
      input_summary: {},
      output: { weekCount: artifact.rhythms.length },
      validation: { valid: true },
      status: "succeeded",
    } satisfies GraphTraceNode],
  };
}

export const twoWeekPlanGraph = new StateGraph(State)
  .addNode("generate_plan", generatePlan)
  .addEdge(START, "generate_plan")
  .addEdge("generate_plan", END)
  .compile();

export async function invokeTwoWeekPlanGraph(
  packet: PlanningPacket,
  training_architecture: TrainingArchitecture,
  fitness_strategy: FitnessStrategyArtifact,
): Promise<GraphResult<TwoWeekPlanArtifact>> {
  const state = await twoWeekPlanGraph.invoke({ packet, training_architecture, fitness_strategy });
  if (!state.artifact) {
    throw new Error("Two-Week Plan graph completed without an artifact.");
  }
  return {
    artifact: state.artifact,
    nodes: state.nodes,
    tool_calls: [],
  };
}

function weekRhythm(
  weekStart: Date,
  _status: "committed" | "draft",
  architecture: TrainingArchitecture,
  packet: PlanningPacket,
  weekIndex: number,
): TwoWeekPlanArtifact["rhythms"][number] {
  const sessions = Math.max(architecture.weekly_budget.minimum_viable_sessions, Math.min(architecture.weekly_budget.target_sessions, 4));
  const priority = architecture.priority_order;
  return {
    weekStartDate: isoDate(weekStart),
    weekEndDate: isoDate(addDays(weekStart, 6)),
    objective: weekIndex === 0 ? "Commit the minimum effective week." : "Draft the next visible week around known constraints.",
    priorityOrder: priority,
    hardEasyDistribution: {
      hard: architecture.weekly_budget.hard_sessions,
      moderate: Math.max(0, sessions - architecture.weekly_budget.hard_sessions - 1),
      easy: 1,
    },
    badDayFloor: packet.planning_constraints.bad_day_floor ?? "Do the shortest useful version and preserve the habit.",
    swapRules: architecture.planner_constraints.weekly_plan_rules,
    workouts: Array.from({ length: sessions }, (_, index) => {
      const modality = priority[index % priority.length] ?? "training";
      const date = addDays(weekStart, index * 2);
      return {
        scheduledDate: isoDate(date),
        sequenceOrder: 1,
        activityType: titleCase(modality),
        title: index === 0 ? `${titleCase(modality)} Quality` : `${titleCase(modality)} Support`,
        durationMinutes: index === 0 ? 45 : 35,
        intensityLabel: index === 0 ? "Moderate" : "Easy",
        purpose: index === 0 ? "Protect the primary training signal." : "Support the strategy without crowding recovery.",
        prescription: {
          warmup: "Start easy and check readiness.",
          main: ["Complete the planned dose with clean form and controlled effort."],
          cooldown: "Finish easy and note any recovery flags.",
          successCriteria: "The session supports the week without compromising the next planned workout.",
        },
        fuelingSummary: index === 0 ? "Eat normally and hydrate before training." : "No special fueling needed unless hungry.",
      };
    }),
  };
}

function parseDate(value: string) {
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isNaN(date.getTime()) ? new Date() : date;
}

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

function isoDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

function titleCase(value: string) {
  return value
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}
