import { Annotation, END, START, StateGraph } from "@langchain/langgraph";
import {
  type FitnessStrategyArtifact,
  type GraphResult,
  type GraphTraceNode,
  type GraphToolCall,
  normalizeModality,
  type PlannerInputContract,
  type PlanningPacket,
  type TrainingArchitecture,
  type TwoWeekPlanArtifact,
  type WorkoutArchetypeRecommendation,
} from "../contracts.js";
import { runStructuredJSON } from "../ai/openai.js";

type TwoWeekPlanState = {
  packet: PlanningPacket;
  training_architecture: TrainingArchitecture;
  fitness_strategy: FitnessStrategyArtifact;
  artifact?: TwoWeekPlanArtifact;
  nodes: GraphTraceNode[];
  tool_calls: GraphToolCall[];
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
  tool_calls: Annotation<GraphToolCall[]>({
    reducer: (left, right) => [...left, ...right],
    default: () => [],
  }),
});

async function generatePlan(state: TwoWeekPlanState) {
  const packet = state.packet;
  const architecture = state.training_architecture;
  const start = parseDate(packet.planning_constraints.start_date);
  const plannerInput = buildPlannerInputContract(packet, architecture, state.fitness_strategy, {
    visible_horizon_weeks: packet.generation_policy.visible_horizon_weeks,
    committed_week_start: isoDate(start),
    draft_week_start: isoDate(addDays(start, 7)),
  });
  const planAI = await runStructuredJSON<TwoWeekPlanArtifact>({
    toolName: "compile_two_week_plan",
    graphNodeName: "generate_plan",
    system: [
      "You are HAYF's two-week plan compiler.",
      "Generate exactly two rhythms: the first committed week and the next draft week.",
      "Use only allowed modalities and approved workout archetypes from the planner input.",
      "Respect the validated Training Architecture, Fitness Strategy, recovery envelope, hard-day cap, bad-day floor, and weekly plan rules.",
      "Do not emit deterministic fallback markers or generic templates. If the constraints conflict, still return the safest valid plan inside the provided architecture.",
      "Set block.context to an empty object; Supabase will add persisted context after validation.",
    ].join(" "),
    input: {
      planner_input: plannerInput,
      required_week_starts: [isoDate(start), isoDate(addDays(start, 7))],
      output_rules: {
        rhythm_count: 2,
        first_week_status: "committed",
        second_week_status: "draft",
        workout_count: architecture.weekly_budget.target_sessions,
        duration_source: "approved_archetypes_typical_duration_minutes_and_user_session_length",
      },
    },
    inputSummary: {
      startDate: isoDate(start),
      priorityOrder: architecture.priority_order,
      allowedModalities: plannerInput.allowed_modalities,
      approvedArchetypeCount: plannerInput.approved_archetypes.length,
      weeklyBudget: architecture.weekly_budget,
    },
    schema: twoWeekPlanSchema,
    knowledgeRefs: architecture.source_knowledge_refs,
    testOutput: () => deterministicTestPlan(packet, architecture, state.fitness_strategy),
  });
  const artifact = validatePlanArtifact(planAI.data, plannerInput, isoDate(start));

  return {
    artifact,
    nodes: [{
      node_name: "compile_two_week_plan",
      input_summary: {
        startDate: isoDate(start),
        allowedModalities: plannerInput.allowed_modalities,
        approvedArchetypeCount: plannerInput.approved_archetypes.length,
      },
      output: {
        weekCount: artifact.rhythms.length,
        workoutCount: artifact.rhythms.reduce((count, rhythm) => count + rhythm.workouts.length, 0),
      },
      validation: { valid: true },
      status: "succeeded",
    } satisfies GraphTraceNode],
    tool_calls: [planAI.toolCall],
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
    tool_calls: state.tool_calls,
  };
}

export function buildPlannerInputContract(
  packet: PlanningPacket,
  training_architecture: TrainingArchitecture,
  fitness_strategy: FitnessStrategyArtifact,
  draft_inputs: Record<string, unknown> = {},
): PlannerInputContract {
  return {
    validated_architecture: training_architecture,
    approved_archetypes: training_architecture.approved_archetypes,
    strategy: fitness_strategy,
    constraints: packet.planning_constraints,
    actuals_summary: { approved_evidence_summary: packet.approved_evidence_summary },
    draft_inputs,
    allowed_modalities: training_architecture.modality_roles
      .filter((role) => role.role !== "currently_inappropriate")
      .map((role) => role.modality),
  };
}

const workoutSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "scheduledDate",
    "sequenceOrder",
    "activityType",
    "title",
    "durationMinutes",
    "intensityLabel",
    "purpose",
    "prescription",
    "fuelingSummary",
  ],
  properties: {
    scheduledDate: { type: "string" },
    sequenceOrder: { type: "number" },
    activityType: { type: "string" },
    title: { type: "string" },
    durationMinutes: { type: "number" },
    intensityLabel: { type: "string" },
    purpose: { type: "string" },
    prescription: {
      type: "object",
      additionalProperties: false,
      required: ["warmup", "main", "cooldown", "successCriteria"],
      properties: {
        warmup: { type: "string" },
        main: { type: "array", minItems: 1, items: { type: "string" } },
        cooldown: { type: "string" },
        successCriteria: { type: "string" },
      },
    },
    fuelingSummary: { type: "string" },
  },
};

const rhythmSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "weekStartDate",
    "weekEndDate",
    "objective",
    "priorityOrder",
    "hardEasyDistribution",
    "badDayFloor",
    "swapRules",
    "workouts",
  ],
  properties: {
    weekStartDate: { type: "string" },
    weekEndDate: { type: "string" },
    objective: { type: "string" },
    priorityOrder: { type: "array", items: { type: "string" } },
    hardEasyDistribution: {
      type: "object",
      additionalProperties: false,
      required: ["hard", "moderate", "easy"],
      properties: {
        hard: { type: "number" },
        moderate: { type: "number" },
        easy: { type: "number" },
      },
    },
    badDayFloor: { type: "string" },
    swapRules: { type: "array", items: { type: "string" } },
    workouts: { type: "array", minItems: 1, items: workoutSchema },
  },
};

const twoWeekPlanSchema = {
  type: "object",
  additionalProperties: false,
  required: ["block", "phases", "rhythms"],
  properties: {
    block: {
      type: "object",
      additionalProperties: false,
      required: ["kind", "title", "goalText", "startDate", "targetDate", "reviewCadenceDays", "context"],
      properties: {
        kind: { type: "string", enum: ["consistency", "specific_goal", "goal_discovery_chosen"] },
        title: { type: "string" },
        goalText: { type: "string" },
        startDate: { type: "string" },
        targetDate: { type: ["string", "null"] },
        reviewCadenceDays: { type: "number" },
        context: {
          type: "object",
          additionalProperties: false,
          properties: {},
        },
      },
    },
    phases: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "startDate", "endDate", "objective", "focus", "risk"],
        properties: {
          name: { type: "string" },
          startDate: { type: ["string", "null"] },
          endDate: { type: ["string", "null"] },
          objective: { type: "string" },
          focus: { type: "array", items: { type: "string" } },
          risk: { type: "array", items: { type: "string" } },
        },
      },
    },
    rhythms: {
      type: "array",
      minItems: 2,
      maxItems: 2,
      items: rhythmSchema,
    },
  },
};

function validatePlanArtifact(
  artifact: TwoWeekPlanArtifact,
  plannerInput: PlannerInputContract,
  expectedStartDate: string,
): TwoWeekPlanArtifact {
  if (artifact.rhythms.length !== 2) {
    throw new Error(`Two-week plan compiler returned ${artifact.rhythms.length} rhythms instead of 2.`);
  }
  if (artifact.rhythms[0]?.weekStartDate !== expectedStartDate) {
    throw new Error("Two-week plan compiler returned an unexpected committed week start.");
  }
  const allowed = new Set(plannerInput.allowed_modalities.map(normalizeModality));
  for (const rhythm of artifact.rhythms) {
    if (rhythm.workouts.length === 0) {
      throw new Error(`Two-week plan compiler returned no workouts for ${rhythm.weekStartDate}.`);
    }
    for (const workout of rhythm.workouts) {
      const resolvedModality = resolveWorkoutModality(workout, plannerInput);
      if (!resolvedModality || !allowed.has(resolvedModality)) {
        throw new Error(`Two-week plan compiler returned disallowed modality: ${workout.activityType}.`);
      }
      workout.activityType = resolvedModality;
      if (!Number.isFinite(workout.durationMinutes) || workout.durationMinutes <= 0) {
        throw new Error(`Two-week plan compiler returned invalid duration for ${workout.title}.`);
      }
    }
  }
  return artifact;
}

function resolveWorkoutModality(
  workout: TwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  plannerInput: PlannerInputContract,
) {
  const allowed = new Set(plannerInput.allowed_modalities.map(normalizeModality));
  const candidates = [
    workout.activityType,
    workout.title,
    workout.purpose,
    workout.prescription?.warmup,
    workout.prescription?.cooldown,
    workout.prescription?.successCriteria,
    ...(Array.isArray(workout.prescription?.main) ? workout.prescription.main : []),
  ];

  for (const candidate of candidates) {
    const normalized = normalizeModality(String(candidate ?? ""));
    if (allowed.has(normalized)) return normalized;
  }

  const normalizedTitle = normalizeLoose(workout.title);
  for (const archetype of plannerInput.approved_archetypes) {
    const archetypeTitle = normalizeLoose(titleFromArchetype(archetype));
    const archetypeID = normalizeLoose(archetype.id);
    if (
      normalizedTitle &&
      (normalizedTitle.includes(archetypeTitle) ||
        archetypeTitle.includes(normalizedTitle) ||
        normalizedTitle.includes(archetypeID) ||
        archetypeID.includes(normalizedTitle))
    ) {
      const normalized = normalizeModality(archetype.modality);
      if (allowed.has(normalized)) return normalized;
    }
  }

  return null;
}

function normalizeLoose(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function deterministicTestPlan(
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
  fitnessStrategy: FitnessStrategyArtifact,
): TwoWeekPlanArtifact {
  const start = parseDate(packet.planning_constraints.start_date);
  return {
    block: {
      kind: packet.goal_context.goal_kind,
      title: fitnessStrategy.snapshotItems.find((item) => item.id === "priority")?.value ?? "Training Strategy",
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
    rhythms: [
      weekRhythm(start, architecture, packet, 0),
      weekRhythm(addDays(start, 7), architecture, packet, 1),
    ],
  };
}

function weekRhythm(
  weekStart: Date,
  architecture: TrainingArchitecture,
  packet: PlanningPacket,
  weekIndex: number,
): TwoWeekPlanArtifact["rhythms"][number] {
  const sessions = Math.max(architecture.weekly_budget.minimum_viable_sessions, Math.min(architecture.weekly_budget.target_sessions, 4));
  const priority = architecture.priority_order;
  const approvedArchetypes = architecture.approved_archetypes;
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
      const archetype = pickArchetype(approvedArchetypes, modality, index);
      const date = addDays(weekStart, index * 2);
      return {
        scheduledDate: isoDate(date),
        sequenceOrder: index + 1,
        activityType: titleCase(modality),
        title: archetype ? titleFromArchetype(archetype) : `${titleCase(modality)} Support`,
        durationMinutes: archetype ? typicalDuration(archetype) : 35,
        intensityLabel: archetype ? intensityLabel(archetype.intensity_domain) : "Easy",
        purpose: archetype?.purpose ?? "Support the strategy without crowding recovery.",
        prescription: {
          warmup: "Start easy and check readiness.",
          main: [
            archetype
              ? `Complete the session as ${archetype.intensity_domain} work for ${archetype.target_adaptation}.`
              : "Complete the planned dose with clean form and controlled effort.",
          ],
          cooldown: "Finish easy and note any recovery flags.",
          successCriteria: archetype?.planner_constraints[0] ?? "The session supports the week without compromising the next planned workout.",
        },
        fuelingSummary: archetype?.fatigue_cost === "high" ? "Eat normally and hydrate before training." : "No special fueling needed unless hungry.",
      };
    }),
  };
}

function pickArchetype(archetypes: WorkoutArchetypeRecommendation[], modality: string, index: number) {
  const matches = archetypes.filter((archetype) => archetype.modality === modality);
  if (!matches.length) return null;
  return matches[index % matches.length] ?? matches[0];
}

function titleFromArchetype(archetype: WorkoutArchetypeRecommendation) {
  return titleCase(archetype.id.replace(new RegExp(`^${archetype.modality}_`), ""));
}

function typicalDuration(archetype: WorkoutArchetypeRecommendation) {
  return Math.round((archetype.typical_duration_minutes.min + archetype.typical_duration_minutes.max) / 2 / 5) * 5;
}

function intensityLabel(domain: string) {
  if (/vo2|threshold|tempo|hard/i.test(domain)) return "Moderate";
  if (/easy|skill|recovery/i.test(domain)) return "Easy";
  return "Moderate";
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
