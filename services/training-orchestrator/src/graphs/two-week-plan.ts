import { Annotation, END, START, StateGraph } from "@langchain/langgraph";
import {
  type DraftTwoWeekPlanArtifact,
  type FitnessStrategyArtifact,
  type GraphResult,
  type GraphTraceNode,
  type GraphToolCall,
  normalizeModality,
  type PlannerInputContract,
  type PlanningPacket,
  type RichWorkoutPrescription,
  type TrainingArchitecture,
  type TwoWeekPlanArtifact,
  type WorkoutArchetypeRecommendation,
} from "../contracts.js";
import { runStructuredJSON } from "../ai/openai.js";

type TwoWeekPlanState = {
  packet: PlanningPacket;
  training_architecture: TrainingArchitecture;
  fitness_strategy: FitnessStrategyArtifact;
  draft_artifact?: DraftTwoWeekPlanArtifact;
  artifact?: TwoWeekPlanArtifact;
  nodes: GraphTraceNode[];
  tool_calls: GraphToolCall[];
};

const State = Annotation.Root({
  packet: Annotation<PlanningPacket>(),
  training_architecture: Annotation<TrainingArchitecture>(),
  fitness_strategy: Annotation<FitnessStrategyArtifact>(),
  draft_artifact: Annotation<DraftTwoWeekPlanArtifact>(),
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
  const planAI = await runStructuredJSON<DraftTwoWeekPlanArtifact>({
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
    schema: draftTwoWeekPlanSchema,
    knowledgeRefs: architecture.source_knowledge_refs,
    testOutput: () => deterministicTestPlan(packet, architecture, state.fitness_strategy),
  });
  const draft = validateDraftPlanArtifact(planAI.data, plannerInput, isoDate(start));

  return {
    draft_artifact: draft,
    nodes: [{
      node_name: "compile_two_week_plan",
      input_summary: {
        startDate: isoDate(start),
        allowedModalities: plannerInput.allowed_modalities,
        approvedArchetypeCount: plannerInput.approved_archetypes.length,
      },
      output: {
        weekCount: draft.rhythms.length,
        workoutCount: draft.rhythms.reduce((count, rhythm) => count + rhythm.workouts.length, 0),
      },
      validation: { valid: true },
      status: "succeeded",
    } satisfies GraphTraceNode],
    tool_calls: [planAI.toolCall],
  };
}

async function enrichPrescriptions(state: TwoWeekPlanState) {
  const draft = state.draft_artifact;
  if (!draft) throw new Error("Two-Week Plan graph reached enrichment without a draft artifact.");

  const packet = state.packet;
  const architecture = state.training_architecture;
  const start = parseDate(packet.planning_constraints.start_date);
  const plannerInput = buildPlannerInputContract(packet, architecture, state.fitness_strategy, {
    visible_horizon_weeks: packet.generation_policy.visible_horizon_weeks,
    committed_week_start: isoDate(start),
    draft_week_start: isoDate(addDays(start, 7)),
  });
  const prescriptionAI = await runStructuredJSON<TwoWeekPlanArtifact>({
    toolName: "enrich_workout_prescriptions",
    graphNodeName: "enrich_prescriptions",
    system: [
      "You are HAYF's workout prescription detailer.",
      "Enrich the provided two-week plan with structured workout-card prescription JSON.",
      "You may improve workout titles and prescription details, but you must not change dates, sequence order, activity type, duration, intensity, purpose, fueling, week count, or workout count.",
      "Use the validated Training Architecture, approved archetypes, equipment access, injuries, avoidances, planner constraints, and same-week neighboring workouts.",
      "Respect interference rules. Do not prescribe heavy lower-body strength immediately after long or hard cycling/running sessions.",
      "Strength workouts require exercises with sets, reps, equipment or machines, coaching cues, and at least one alternative per exercise.",
      "Cycling and running interval workouts require interval blocks. Long or endurance workouts require steady distance/time/zone or pace guidance.",
      "Return strict JSON only.",
    ].join(" "),
    input: {
      draft_plan: draft,
      prescription_context: prescriptionContext(packet, architecture, plannerInput),
      output_rules: {
        prescription_schema_version: 1,
        immutable_workout_fields: ["scheduledDate", "sequenceOrder", "activityType", "durationMinutes", "intensityLabel", "purpose", "fuelingSummary"],
        title_policy: "Use descriptive human-facing titles. Avoid rigid labels like Full Body A unless the user authored or strategy requires them.",
      },
    },
    inputSummary: {
      weekCount: draft.rhythms.length,
      workoutCount: draft.rhythms.reduce((count, rhythm) => count + rhythm.workouts.length, 0),
      interferenceRuleCount: architecture.interference_rules.length,
      equipmentAccess: packet.planning_constraints.equipment_access,
    },
    schema: enrichedTwoWeekPlanSchema,
    knowledgeRefs: architecture.source_knowledge_refs,
    testOutput: () => deterministicEnrichedPlan(draft, packet, architecture),
  });

  const artifact = validateEnrichedPlanArtifact(prescriptionAI.data, draft, plannerInput, isoDate(start), architecture);
  return {
    artifact,
    nodes: [{
      node_name: "enrich_prescriptions",
      input_summary: {
        weekCount: draft.rhythms.length,
        workoutCount: draft.rhythms.reduce((count, rhythm) => count + rhythm.workouts.length, 0),
      },
      output: {
        enrichedWorkoutCount: artifact.rhythms.reduce((count, rhythm) => count + rhythm.workouts.length, 0),
      },
      validation: { valid: true },
      status: "succeeded",
    } satisfies GraphTraceNode],
    tool_calls: [prescriptionAI.toolCall],
  };
}

export const twoWeekPlanGraph = new StateGraph(State)
  .addNode("generate_plan", generatePlan)
  .addNode("enrich_prescriptions", enrichPrescriptions)
  .addEdge(START, "generate_plan")
  .addEdge("generate_plan", "enrich_prescriptions")
  .addEdge("enrich_prescriptions", END)
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

const richPrescriptionStepGroupSchema = {
  type: "object",
  additionalProperties: false,
  required: ["title", "description", "durationMinutes", "steps"],
  properties: {
    title: { type: "string" },
    description: { type: "string" },
    durationMinutes: { type: ["number", "null"] },
    steps: { type: "array", minItems: 1, items: { type: "string" } },
  },
};

const richPrescriptionBlockSchema = {
  anyOf: [
    {
      type: "object",
      additionalProperties: false,
      required: ["kind", "title", "description", "repeats", "workDuration", "recoveryDuration", "target", "notes"],
      properties: {
        kind: { type: "string", enum: ["interval"] },
        title: { type: "string" },
        description: { type: "string" },
        repeats: { type: "number" },
        workDuration: { type: "string" },
        recoveryDuration: { type: "string" },
        target: { type: "string" },
        notes: { type: "string" },
      },
    },
    {
      type: "object",
      additionalProperties: false,
      required: ["kind", "title", "description", "durationMinutes", "distanceKilometers", "elevationMeters", "target", "terrainNotes"],
      properties: {
        kind: { type: "string", enum: ["steady"] },
        title: { type: "string" },
        description: { type: "string" },
        durationMinutes: { type: ["number", "null"] },
        distanceKilometers: { type: ["number", "null"] },
        elevationMeters: { type: ["number", "null"] },
        target: { type: "string" },
        terrainNotes: { type: ["string", "null"] },
      },
    },
    {
      type: "object",
      additionalProperties: false,
      required: ["kind", "title", "description", "exerciseName", "machineOrEquipment", "sets", "reps", "restSeconds", "effortTarget", "coachingCue", "alternatives"],
      properties: {
        kind: { type: "string", enum: ["strengthExercise"] },
        title: { type: "string" },
        description: { type: "string" },
        exerciseName: { type: "string" },
        machineOrEquipment: { type: "string" },
        sets: { type: "number" },
        reps: { type: "string" },
        restSeconds: { type: "number" },
        effortTarget: { type: "string" },
        coachingCue: { type: "string" },
        alternatives: {
          type: "array",
          minItems: 1,
          items: {
            type: "object",
            additionalProperties: false,
            required: ["exerciseName", "equipment", "notes"],
            properties: {
              exerciseName: { type: "string" },
              equipment: { type: "string" },
              notes: { type: "string" },
            },
          },
        },
      },
    },
    {
      type: "object",
      additionalProperties: false,
      required: ["kind", "title", "description", "durationMinutes", "movementFocus", "steps"],
      properties: {
        kind: { type: "string", enum: ["mobilityRecovery"] },
        title: { type: "string" },
        description: { type: "string" },
        durationMinutes: { type: "number" },
        movementFocus: { type: "string" },
        steps: { type: "array", minItems: 1, items: { type: "string" } },
      },
    },
  ],
};

const richPrescriptionSchema = {
  type: "object",
  additionalProperties: false,
  required: ["schemaVersion", "summary", "warmup", "main", "cooldown", "successCriteria", "equipment", "constraintsApplied"],
  properties: {
    schemaVersion: { type: "number", enum: [1] },
    summary: { type: "string" },
    warmup: richPrescriptionStepGroupSchema,
    main: {
      type: "object",
      additionalProperties: false,
      required: ["title", "description", "blocks"],
      properties: {
        title: { type: "string" },
        description: { type: "string" },
        blocks: { type: "array", minItems: 1, items: richPrescriptionBlockSchema },
      },
    },
    cooldown: richPrescriptionStepGroupSchema,
    successCriteria: { type: "string" },
    equipment: { type: "array", items: { type: "string" } },
    constraintsApplied: { type: "array", items: { type: "string" } },
  },
};

const enrichedWorkoutSchema = {
  ...workoutSchema,
  properties: {
    ...workoutSchema.properties,
    prescription: richPrescriptionSchema,
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

const enrichedRhythmSchema = {
  ...rhythmSchema,
  properties: {
    ...rhythmSchema.properties,
    workouts: { type: "array", minItems: 1, items: enrichedWorkoutSchema },
  },
};

const draftTwoWeekPlanSchema = {
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

const enrichedTwoWeekPlanSchema = {
  ...draftTwoWeekPlanSchema,
  properties: {
    ...draftTwoWeekPlanSchema.properties,
    rhythms: {
      type: "array",
      minItems: 2,
      maxItems: 2,
      items: enrichedRhythmSchema,
    },
  },
};

function validateDraftPlanArtifact(
  artifact: DraftTwoWeekPlanArtifact,
  plannerInput: PlannerInputContract,
  expectedStartDate: string,
): DraftTwoWeekPlanArtifact {
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
  workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number] | TwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  plannerInput: PlannerInputContract,
) {
  const allowed = new Set(plannerInput.allowed_modalities.map(normalizeModality));
  const prescription = workout.prescription as Record<string, unknown> | undefined;
  const main = prescription?.main;
  const mainCandidates = Array.isArray(main)
    ? main
    : main && typeof main === "object"
      ? [
        (main as Record<string, unknown>).title,
        (main as Record<string, unknown>).description,
        ...(((main as Record<string, unknown>).blocks as unknown[] | undefined) ?? []).map((block) => JSON.stringify(block)),
      ]
      : [];
  const candidates = [
    workout.activityType,
    workout.title,
    workout.purpose,
    typeof prescription?.warmup === "string" ? prescription.warmup : JSON.stringify(prescription?.warmup ?? ""),
    typeof prescription?.cooldown === "string" ? prescription.cooldown : JSON.stringify(prescription?.cooldown ?? ""),
    prescription?.successCriteria,
    ...mainCandidates,
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

function validateEnrichedPlanArtifact(
  artifact: TwoWeekPlanArtifact,
  draft: DraftTwoWeekPlanArtifact,
  plannerInput: PlannerInputContract,
  expectedStartDate: string,
  architecture: TrainingArchitecture,
): TwoWeekPlanArtifact {
  validateDraftPlanArtifact(artifact as unknown as DraftTwoWeekPlanArtifact, plannerInput, expectedStartDate);
  if (artifact.rhythms.length !== draft.rhythms.length) {
    throw new Error("Prescription enrichment changed the number of weeks.");
  }
  const disallowedEquipment = new Set(plannerInput.constraints.avoidances.map(normalizeLoose).filter(Boolean));
  for (const [rhythmIndex, rhythm] of artifact.rhythms.entries()) {
    const draftRhythm = draft.rhythms[rhythmIndex];
    if (!draftRhythm || rhythm.workouts.length !== draftRhythm.workouts.length) {
      throw new Error(`Prescription enrichment changed workout count for ${rhythm.weekStartDate}.`);
    }
    for (const [workoutIndex, workout] of rhythm.workouts.entries()) {
      const draftWorkout = draftRhythm.workouts[workoutIndex];
      restoreImmutableWorkoutFields(workout, draftWorkout);
      validateRichPrescription(workout.prescription, workout, disallowedEquipment);
      validateInterferencePrescription(workout, rhythm.workouts, architecture);
    }
  }
  return artifact;
}

function restoreImmutableWorkoutFields(
  workout: TwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  draftWorkout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
) {
  const fields: Array<keyof typeof draftWorkout> = [
    "scheduledDate",
    "sequenceOrder",
    "activityType",
    "durationMinutes",
    "intensityLabel",
    "purpose",
    "fuelingSummary",
  ];
  for (const field of fields) {
    (workout as Record<string, unknown>)[field] = draftWorkout[field];
  }
}

function validateRichPrescription(
  prescription: RichWorkoutPrescription,
  workout: TwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  disallowedEquipment: Set<string>,
) {
  if (prescription.schemaVersion !== 1) throw new Error(`Prescription for ${workout.title} has invalid schemaVersion.`);
  if (!nonEmpty(prescription.summary) || !nonEmpty(prescription.successCriteria)) {
    throw new Error(`Prescription for ${workout.title} is missing summary or success criteria.`);
  }
  validateStepGroup(prescription.warmup, workout.title, "warmup");
  validateStepGroup(prescription.cooldown, workout.title, "cooldown");
  if (!nonEmpty(prescription.main?.title) || !nonEmpty(prescription.main?.description) || !prescription.main.blocks.length) {
    throw new Error(`Prescription for ${workout.title} is missing main blocks.`);
  }
  const normalizedEquipment = [
    ...prescription.equipment,
    ...prescription.main.blocks.flatMap((block) =>
      block.kind === "strengthExercise"
        ? [block.machineOrEquipment, ...block.alternatives.map((alternative) => alternative.equipment)]
        : []
    ),
  ].map(normalizeLoose);
  for (const avoided of disallowedEquipment) {
    if (normalizedEquipment.some((equipment) => equipment.includes(avoided) || avoided.includes(equipment))) {
      throw new Error(`Prescription for ${workout.title} used avoided equipment or context: ${avoided}.`);
    }
  }

  const modality = workoutModality(workout);
  const titleText = normalizeLoose(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`);
  const hasIntervalBlock = prescription.main.blocks.some((block) => block.kind === "interval");
  const hasSteadyBlock = prescription.main.blocks.some((block) => block.kind === "steady");
  if (modality === "strength") {
    const strengthBlocks = prescription.main.blocks.filter((block) => block.kind === "strengthExercise");
    if (strengthBlocks.length === 0) throw new Error(`Strength prescription for ${workout.title} has no exercises.`);
    for (const block of strengthBlocks) {
      if (block.sets < 1 || !nonEmpty(block.reps) || block.restSeconds < 0 || block.alternatives.length === 0) {
        throw new Error(`Strength prescription for ${workout.title} has an incomplete exercise block.`);
      }
    }
  } else if ((modality === "cycling" || modality === "running") && /interval|vo2/.test(titleText)) {
    if (!hasIntervalBlock) {
      throw new Error(`Interval prescription for ${workout.title} has no interval block.`);
    }
  } else if ((modality === "cycling" || modality === "running") && /threshold|tempo/.test(titleText)) {
    if (!hasIntervalBlock && !hasSteadyBlock) {
      throw new Error(`Tempo prescription for ${workout.title} has no interval or steady block.`);
    }
  } else if (modality === "cycling" || modality === "running") {
    if (!hasSteadyBlock) {
      throw new Error(`Endurance prescription for ${workout.title} has no steady block.`);
    }
  }
}

function validateStepGroup(group: RichWorkoutPrescription["warmup"], workoutTitle: string, label: string) {
  if (!nonEmpty(group.title) || !nonEmpty(group.description) || group.steps.length === 0) {
    throw new Error(`Prescription for ${workoutTitle} is missing ${label} detail.`);
  }
}

function validateInterferencePrescription(
  workout: TwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  weekWorkouts: TwoWeekPlanArtifact["rhythms"][number]["workouts"],
  architecture: TrainingArchitecture,
) {
  const modality = workoutModality(workout);
  if (modality !== "strength") return;
  const prior = weekWorkouts.find((candidate) => candidate.scheduledDate < workout.scheduledDate && daysBetween(candidate.scheduledDate, workout.scheduledDate) <= 1);
  if (!prior || !isLongOrHardEndurance(prior)) return;
  const prescriptionText = normalizeLoose(JSON.stringify(workout.prescription));
  if (/\bheavy\b|\bmax\b|\bnear failure\b|\bfailure\b|\b1rm\b/.test(prescriptionText) && /\bleg\b|\bsquat\b|\blunge\b|\bpress\b|\bdeadlift\b/.test(prescriptionText)) {
    throw new Error(`Strength prescription for ${workout.title} violates interference rules after ${prior.title}.`);
  }
  if (architecture.interference_rules.some((rule) => /heavy lower-body|heavy lower body/i.test(rule))) {
    workout.prescription.constraintsApplied = uniqueStrings([
      ...workout.prescription.constraintsApplied,
      `Adjusted lower-body loading because ${prior.title} is nearby.`,
    ]);
  }
}

function isLongOrHardEndurance(workout: TwoWeekPlanArtifact["rhythms"][number]["workouts"][number]) {
  const modality = workoutModality(workout);
  if (modality !== "cycling" && modality !== "running") return false;
  const text = normalizeLoose(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`);
  return workout.durationMinutes >= (modality === "cycling" ? 90 : 70) || /hard|interval|vo2|tempo|threshold|long/.test(text);
}

function daysBetween(left: string, right: string) {
  return Math.round((parseDate(right).getTime() - parseDate(left).getTime()) / 86_400_000);
}

function nonEmpty(value: unknown) {
  return typeof value === "string" && value.trim().length > 0;
}

function normalizeLoose(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function uniqueStrings(values: string[]) {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean)));
}

function deterministicTestPlan(
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
  fitnessStrategy: FitnessStrategyArtifact,
): DraftTwoWeekPlanArtifact {
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
): DraftTwoWeekPlanArtifact["rhythms"][number] {
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

function prescriptionContext(
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
  plannerInput: PlannerInputContract,
) {
  return {
    allowedModalities: plannerInput.allowed_modalities,
    priorityOrder: architecture.priority_order,
    modalityRoles: architecture.modality_roles.map((role) => ({
      modality: role.modality,
      role: role.role,
      rationale: role.rationale,
    })),
    weeklyBudget: architecture.weekly_budget,
    recoveryEnvelope: architecture.recovery_envelope,
    interferenceRules: architecture.interference_rules,
    plannerConstraints: architecture.planner_constraints,
    approvedArchetypes: architecture.approved_archetypes.map((archetype) => ({
      id: archetype.id,
      modality: archetype.modality,
      purpose: archetype.purpose,
      targetAdaptation: archetype.target_adaptation,
      intensityDomain: archetype.intensity_domain,
      doseRange: archetype.dose_range,
      progressionRule: archetype.progression_rule,
      fatigueCost: archetype.fatigue_cost,
      prerequisites: archetype.prerequisites,
      incompatibilities: archetype.incompatibilities,
      plannerConstraints: archetype.planner_constraints,
    })),
    constraints: {
      sessionLength: packet.planning_constraints.session_length,
      injuries: packet.planning_constraints.injuries,
      equipmentAccess: packet.planning_constraints.equipment_access,
      avoidances: packet.planning_constraints.avoidances,
      badDayFloor: packet.planning_constraints.bad_day_floor,
    },
  };
}

function deterministicEnrichedPlan(
  draft: DraftTwoWeekPlanArtifact,
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
): TwoWeekPlanArtifact {
  return {
    ...draft,
    rhythms: draft.rhythms.map((rhythm) => ({
      ...rhythm,
      workouts: rhythm.workouts.map((workout) => {
        const title = descriptiveTitle(workout, architecture);
        return {
          ...workout,
          title,
          prescription: richPrescriptionForWorkout({ ...workout, title }, rhythm.workouts, packet, architecture),
        };
      }),
    })),
  };
}

function descriptiveTitle(
  workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  architecture: TrainingArchitecture,
) {
  const modality = workoutModality(workout);
  const archetype = matchingArchetype(workout, architecture);
  if (modality === "strength") {
    if (archetype?.id.includes("maintenance")) return "Strength maintenance";
    if (archetype?.id.includes("hypertrophy")) return "Strength build";
    return "Strength support";
  }
  if (modality === "cycling") {
    if (/vo2|interval/i.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`)) return "Cycling intervals";
    if (/tempo|threshold/i.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`)) return "Controlled tempo ride";
    if (workout.durationMinutes >= 90) return "Long endurance ride";
    return "Easy aerobic ride";
  }
  if (modality === "running") {
    if (/tempo|threshold/i.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`)) return "Controlled tempo run";
    if (/stride|interval|vo2/i.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`)) return "Run intervals";
    if (workout.durationMinutes >= 70) return "Long aerobic run";
    return "Easy aerobic run";
  }
  return workout.title;
}

function richPrescriptionForWorkout(
  workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  weekWorkouts: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"],
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
): RichWorkoutPrescription {
  const modality = workoutModality(workout);
  const constraintsApplied = constraintsForWorkout(workout, weekWorkouts, packet, architecture);
  const equipmentAccess = packet.planning_constraints.equipment_access.map((value) => value.toLowerCase());
  if (modality === "strength") {
    const gymAccess = equipmentAccess.some((value) => /gym|machine|cable/.test(value));
    const useLegCaution = constraintsApplied.some((value) => /lower-body/i.test(value));
    const exercises = useLegCaution
      ? [
        strengthBlock("Chest-supported row", gymAccess ? "Seated row machine" : "Dumbbells", "3", "8-10", "Keep ribs down and pull elbows toward pockets.", gymAccess),
        strengthBlock("Machine chest press", gymAccess ? "Chest press machine" : "Push-up or dumbbell press", "2", "8-10", "Stop each set with clean reps in reserve.", gymAccess),
        strengthBlock("Pallof press", gymAccess ? "Cable stack" : "Resistance band", "2", "10 each side", "Resist rotation without holding your breath.", gymAccess),
      ]
      : [
        strengthBlock("Leg press", gymAccess ? "Leg press machine" : "Goblet squat", "3", "8-10", "Control the lowering and stop short of grinding.", gymAccess),
        strengthBlock("Seated row", gymAccess ? "Seated row machine" : "Dumbbell row", "3", "8-10", "Pull smoothly and keep shoulders away from ears.", gymAccess),
        strengthBlock("Romanian deadlift", gymAccess ? "Dumbbells or barbell" : "Dumbbells", "2", "8", "Hinge from the hips and keep reps crisp.", gymAccess),
      ];
    return {
      schemaVersion: 1,
      summary: "A controlled strength session that supports the plan without chasing soreness.",
      warmup: stepGroup("Warm up", "Prepare joints and movement patterns before loading.", 8, ["5 min easy bike or treadmill", "Two light ramp-up sets for the first lift"]),
      main: {
        title: "Strength work",
        description: useLegCaution
          ? "Keep lower-body loading light because hard or long endurance work is nearby."
          : "Use repeatable full-body lifts with clean reps and bounded fatigue.",
        blocks: exercises,
      },
      cooldown: stepGroup("Cool down", "Bring effort down and check recovery signals.", 5, ["Easy walk", "Light hips, calves, and upper-back mobility"]),
      successCriteria: "Finish with 1-2 reps in reserve and no form breakdown.",
      equipment: uniqueStrings(exercises.flatMap((block) => block.kind === "strengthExercise" ? [block.machineOrEquipment] : [])),
      constraintsApplied,
    };
  }

  if (modality === "cycling") {
    const interval = /interval|vo2|tempo|threshold/i.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`);
    return {
      schemaVersion: 1,
      summary: interval ? "Structured ride quality with controlled recoveries." : "Aerobic ride built around steady repeatable volume.",
      warmup: stepGroup("Warm up", "Ease into the ride before the main work.", 10, ["Ride easy", "Add 2 short cadence pickups if legs feel good"]),
      main: {
        title: interval ? "Ride intervals" : "Steady ride",
        description: interval ? "Keep the hard blocks controlled, not maximal." : "Stay mostly aerobic and smooth.",
        blocks: [interval
          ? intervalBlock("Main intervals", workout.durationMinutes >= 50 ? 4 : 3, "4 min", "3 min easy", "RPE 8 or strong sustainable power")
          : steadyBlock("Aerobic block", workout.durationMinutes, estimatedDistance(workout, "cycling"), null, "Zone 2 / conversational")],
      },
      cooldown: stepGroup("Cool down", "Finish easy enough to protect the next session.", 8, ["Easy spin", "Note heavy legs or unusual fatigue"]),
      successCriteria: "Complete the planned time while keeping the final 10 minutes controlled.",
      equipment: ["Bike"],
      constraintsApplied,
    };
  }

  if (modality === "running") {
    const interval = /interval|stride|vo2|tempo|threshold/i.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`);
    return {
      schemaVersion: 1,
      summary: interval ? "Structured run quality with impact kept bounded." : "Easy run volume that supports consistency.",
      warmup: stepGroup("Warm up", "Start gently before any faster work.", 10, ["Easy jog", "Dynamic calves and hips"]),
      main: {
        title: interval ? "Run intervals" : "Steady run",
        description: interval ? "Keep fast work relaxed enough to preserve form." : "Stay easy enough to finish feeling in control.",
        blocks: [interval
          ? intervalBlock("Main intervals", workout.durationMinutes >= 45 ? 5 : 4, "2 min", "2 min easy jog", "Fast but relaxed, around 5K-10K effort")
          : steadyBlock("Aerobic block", workout.durationMinutes, estimatedDistance(workout, "running"), null, "Easy pace / RPE 3-4")],
      },
      cooldown: stepGroup("Cool down", "Reduce impact and check for tendon irritation.", 5, ["Easy walk or jog", "Light calves and hips mobility"]),
      successCriteria: "Keep pace controlled enough that gait stays smooth.",
      equipment: ["Running shoes"],
      constraintsApplied,
    };
  }

  return {
    schemaVersion: 1,
    summary: "Low-load work to keep the week moving.",
    warmup: stepGroup("Warm up", "Ease into movement.", 5, ["Start gently"]),
    main: {
      title: "Recovery movement",
      description: "Use this to reduce stiffness without adding training load.",
      blocks: [{
        kind: "mobilityRecovery",
        title: "Mobility flow",
        description: "Move through comfortable ranges.",
        durationMinutes: Math.max(10, workout.durationMinutes - 10),
        movementFocus: "hips, spine, breathing",
        steps: ["Easy mobility flow", "Nasal breathing reset"],
      }],
    },
    cooldown: stepGroup("Cool down", "Finish calm.", 3, ["Easy breathing"]),
    successCriteria: "Finish feeling better than you started.",
    equipment: [],
    constraintsApplied,
  };
}

function constraintsForWorkout(
  workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  weekWorkouts: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"],
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
) {
  const constraints = [
    ...architecture.planner_constraints.workout_generation_rules,
    ...architecture.interference_rules,
    packet.planning_constraints.injuries ? `Injury note: ${packet.planning_constraints.injuries}` : null,
    packet.planning_constraints.avoidances.length ? `Avoidances: ${packet.planning_constraints.avoidances.join(", ")}` : null,
  ].filter(Boolean) as string[];
  const modality = workoutModality(workout);
  if (modality === "strength") {
    const prior = weekWorkouts.find((candidate) => candidate.scheduledDate < workout.scheduledDate && daysBetween(candidate.scheduledDate, workout.scheduledDate) <= 1);
    if (prior && isLongOrHardDraftEndurance(prior)) {
      constraints.push(`Adjusted lower-body loading because ${prior.title} is nearby.`);
    }
  }
  return uniqueStrings(constraints).slice(0, 8);
}

function strengthBlock(
  exerciseName: string,
  machineOrEquipment: string,
  sets: string,
  reps: string,
  coachingCue: string,
  gymAccess: boolean,
): RichWorkoutPrescription["main"]["blocks"][number] {
  return {
    kind: "strengthExercise",
    title: exerciseName,
    description: `Perform ${exerciseName} with clean repeatable reps.`,
    exerciseName,
    machineOrEquipment,
    sets: Number(sets),
    reps,
    restSeconds: 90,
    effortTarget: "RPE 7, 1-2 reps in reserve",
    coachingCue,
    alternatives: [{
      exerciseName: gymAccess ? `${exerciseName} dumbbell variation` : `${exerciseName} bodyweight variation`,
      equipment: gymAccess ? "Dumbbells" : "Bodyweight",
      notes: "Use the alternative if the main station is busy or unavailable.",
    }],
  };
}

function stepGroup(title: string, description: string, durationMinutes: number, steps: string[]) {
  return { title, description, durationMinutes, steps };
}

function intervalBlock(title: string, repeats: number, workDuration: string, recoveryDuration: string, target: string) {
  return {
    kind: "interval" as const,
    title,
    description: "Alternate focused work with easy recovery.",
    repeats,
    workDuration,
    recoveryDuration,
    target,
    notes: "Stop the interval set early if form or cadence falls apart.",
  };
}

function steadyBlock(title: string, durationMinutes: number, distanceKilometers: number | null, elevationMeters: number | null, target: string) {
  return {
    kind: "steady" as const,
    title,
    description: "Hold a steady aerobic effort.",
    durationMinutes,
    distanceKilometers,
    elevationMeters,
    target,
    terrainNotes: null,
  };
}

function estimatedDistance(workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number], modality: "cycling" | "running") {
  const speed = modality === "cycling" ? 22 : 9;
  return Math.max(1, Math.round((workout.durationMinutes / 60) * speed));
}

function workoutModality(workout: Pick<DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number], "activityType" | "title" | "purpose">) {
  const activityModality = normalizeModality(workout.activityType);
  if (activityModality && activityModality !== "general") return activityModality;
  return normalizeModality(`${workout.title} ${workout.purpose}`);
}

function isLongOrHardDraftEndurance(workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number]) {
  const modality = workoutModality(workout);
  if (modality !== "cycling" && modality !== "running") return false;
  const text = normalizeLoose(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`);
  return workout.durationMinutes >= (modality === "cycling" ? 90 : 70) || /hard|interval|vo2|tempo|threshold|long/.test(text);
}

function matchingArchetype(
  workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  architecture: TrainingArchitecture,
) {
  const modality = workoutModality(workout);
  return architecture.approved_archetypes.find((archetype) => archetype.modality === modality && (
    normalizeLoose(workout.title).includes(normalizeLoose(titleFromArchetype(archetype))) ||
    normalizeLoose(workout.purpose).includes(normalizeLoose(archetype.purpose))
  ));
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
