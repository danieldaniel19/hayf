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

type OpeningRhythmSpec = {
  weekStartDate: string;
  weekEndDate: string;
  programStage: "launch" | "program";
  programWeekNumber: number | null;
  programStartDate: string;
  workoutCount: number;
  modalityTargets: Array<{ modality: string; sessions: number }>;
  allowedDates: string[];
};

type OpeningPlanContext = {
  ownerStartDate: string;
  programStartDate: string;
  rhythms: OpeningRhythmSpec[];
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
  const openingPlan = openingPlanContext(packet, architecture, start);
  const plannerInput = buildPlannerInputContract(packet, architecture, state.fitness_strategy, {
    visible_horizon_weeks: packet.generation_policy.visible_horizon_weeks,
    committed_week_start: openingPlan.rhythms[0].weekStartDate,
    draft_week_start: openingPlan.rhythms[1].weekStartDate,
    program_start_date: openingPlan.programStartDate,
    owner_start_date: openingPlan.ownerStartDate,
  });
  const planAI = await runStructuredJSON<DraftTwoWeekPlanArtifact>({
    toolName: "compile_two_week_plan",
    graphNodeName: "generate_plan",
    system: [
      "You are HAYF's two-week plan compiler.",
      "Generate the exact supplied rhythm list. A normal opening has Program Weeks 1 and 2; a midweek opening has a launch bridge followed by Program Weeks 1 and 2.",
      "Generate exactly the supplied rhythm specifications, modality targets, and allowed weekdays, with at most one workout on each calendar day.",
      "A launch rhythm is a short bridge before Program Week 1. It must contain cycling first and strength second when those are the primary and secondary modalities; optional filler never displaces a core modality.",
      "When reentry.active is true, explicitly describe the opening rhythm as re-entry and keep all sessions easy to moderate with no intervals, threshold, VO2max, sprints, maximal strength, or other high-fatigue work.",
      "Use only allowed modalities and approved workout archetypes from the planner input.",
      "Recovery-labelled workouts require a real preceding hard or long load or an explicit recovery trigger. A first session after a gap is easy, not recovery.",
      "Respect the validated Training Architecture, Fitness Strategy, recovery envelope, hard-day cap, bad-day floor, and weekly plan rules.",
      "Do not emit deterministic fallback markers or generic templates. If the constraints conflict, still return the safest valid plan inside the provided architecture.",
      "Set block.context to an empty object; Supabase will add persisted context after validation.",
    ].join(" "),
    input: {
      planner_input: plannerInput,
      required_rhythms: openingPlan.rhythms,
      output_rules: {
        rhythm_count: openingPlan.rhythms.length,
        first_week_status: "committed",
        second_week_status: "draft",
        available_days: packet.planning_constraints.available_days,
        available_day_parts: packet.planning_constraints.available_day_parts,
        duration_source: "approved_archetypes_typical_duration_minutes_and_user_session_length",
        reentry: architecture.reentry,
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
  const draft = validateDraftPlanArtifact(
    applyPlanContractGuardrails(planAI.data, packet, architecture, openingPlan),
    plannerInput,
    openingPlan,
  );

  return {
    draft_artifact: draft,
    nodes: [{
      node_name: "compile_two_week_plan",
      input_summary: {
        startDate: openingPlan.rhythms[0].weekStartDate,
        programStartDate: openingPlan.programStartDate,
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
  const openingPlan = openingPlanContext(packet, architecture, start);
  const plannerInput = buildPlannerInputContract(packet, architecture, state.fitness_strategy, {
    visible_horizon_weeks: packet.generation_policy.visible_horizon_weeks,
    committed_week_start: openingPlan.rhythms[0].weekStartDate,
    draft_week_start: openingPlan.rhythms[1].weekStartDate,
    program_start_date: openingPlan.programStartDate,
    owner_start_date: openingPlan.ownerStartDate,
  });
  const prescriptionSystem = [
    "You are HAYF's workout prescription detailer.",
    "Enrich the provided opening plan with structured workout-card prescription JSON.",
    "You may improve workout titles and prescription details, but you must not change dates, sequence order, archetype ID, activity type, duration, intensity, purpose, fueling, week count, or workout count.",
    "Every prescription must follow the immutable activityType. A strength workout must contain strengthExercise blocks even when its title or purpose mentions mobility, joint preparation, or support work.",
    "Use the validated Training Architecture, approved archetypes, equipment access, injuries, avoidances, planner constraints, and same-week neighboring workouts.",
    "Respect interference rules. Do not prescribe heavy lower-body strength immediately after long or hard cycling/running sessions.",
    "Strength workouts require exercises with sets, reps, equipment or machines, coaching cues, and at least one alternative per exercise.",
    "Cycling and running interval workouts require interval blocks. Long or endurance workouts require steady distance/time/zone or pace guidance.",
    "Use prescription schema version 2 and include whyToday. It must name Launch, Week 1, or Week 2 and explain how the workout advances the current phase and goal.",
    "During re-entry, an easy running archetype is a structured walk-run with run and walk durations, not a continuous steady run, and it has no estimated distance.",
    "All visible copy must use plain language. Never emit internal identifiers, snake_case, RIR, RPE, em dashes, or en dashes.",
    "Return strict JSON only.",
  ].join(" ");
  const prescriptionInput = {
    draft_plan: draft,
    prescription_context: prescriptionContext(packet, architecture, plannerInput),
    output_rules: {
      prescription_schema_version: 2,
      immutable_workout_fields: ["scheduledDate", "sequenceOrder", "archetypeId", "activityType", "durationMinutes", "intensityLabel", "purpose", "fuelingSummary"],
      title_policy: "Use no more than four words or 32 characters. Use plain descriptive titles with no dash glyphs or dangling separators.",
    },
  };
  const prescriptionAI = await runStructuredJSON<TwoWeekPlanArtifact>({
    toolName: "enrich_workout_prescriptions",
    graphNodeName: "enrich_prescriptions",
    system: prescriptionSystem,
    input: prescriptionInput,
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

  const artifact = validateEnrichedPlanArtifact(
    prescriptionAI.data,
    draft,
    plannerInput,
    openingPlan,
    architecture,
    packet,
  );
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
    "archetypeId",
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
    archetypeId: { type: ["string", "null"] },
    activityType: { type: "string" },
    title: { type: "string", maxLength: 32 },
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
    fuelingSummary: { type: "string", maxLength: 20 },
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
    {
      type: "object",
      additionalProperties: false,
      required: ["kind", "title", "description", "repeats", "runDurationMinutes", "walkDurationMinutes", "target", "notes"],
      properties: {
        kind: { type: "string", enum: ["walkRun"] },
        title: { type: "string" },
        description: { type: "string" },
        repeats: { type: "number" },
        runDurationMinutes: { type: "number" },
        walkDurationMinutes: { type: "number" },
        target: { type: "string" },
        notes: { type: "string" },
      },
    },
  ],
};

const richPrescriptionSchema = {
  type: "object",
  additionalProperties: false,
  required: ["schemaVersion", "summary", "whyToday", "warmup", "main", "cooldown", "successCriteria", "equipment", "constraintsApplied"],
  properties: {
    schemaVersion: { type: "number", enum: [2] },
    summary: { type: "string" },
    whyToday: { type: "string", maxLength: 180 },
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
    "programStage",
    "programWeekNumber",
    "programStartDate",
    "modalityTargets",
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
    programStage: { type: "string", enum: ["launch", "program"] },
    programWeekNumber: { type: ["number", "null"] },
    programStartDate: { type: "string" },
    modalityTargets: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["modality", "sessions"],
        properties: {
          modality: { type: "string" },
          sessions: { type: "number" },
        },
      },
    },
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
      maxItems: 3,
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
      maxItems: 3,
      items: enrichedRhythmSchema,
    },
  },
};

function validateDraftPlanArtifact(
  artifact: DraftTwoWeekPlanArtifact,
  plannerInput: PlannerInputContract,
  openingPlan: OpeningPlanContext,
): DraftTwoWeekPlanArtifact {
  if (artifact.rhythms.length !== openingPlan.rhythms.length) {
    throw new Error(`Two-week plan compiler returned ${artifact.rhythms.length} rhythms instead of ${openingPlan.rhythms.length}.`);
  }
  if (artifact.rhythms[0]?.weekStartDate !== openingPlan.rhythms[0].weekStartDate) {
    throw new Error("Two-week plan compiler returned an unexpected committed week start.");
  }
  const allowed = new Set(plannerInput.allowed_modalities.map(normalizeModality));
  for (const [rhythmIndex, rhythm] of artifact.rhythms.entries()) {
    const expected = openingPlan.rhythms[rhythmIndex];
    if (!expected) throw new Error(`Two-week plan compiler returned an extra rhythm at index ${rhythmIndex}.`);
    if (rhythm.weekStartDate !== expected.weekStartDate || rhythm.weekEndDate !== expected.weekEndDate) {
      throw new Error(`Two-week plan compiler returned unexpected week bounds for rhythm ${rhythmIndex + 1}.`);
    }
    if (
      rhythm.programStage !== expected.programStage ||
      rhythm.programWeekNumber !== expected.programWeekNumber ||
      rhythm.programStartDate !== expected.programStartDate
    ) {
      throw new Error(`Two-week plan compiler returned invalid program metadata for ${rhythm.weekStartDate}.`);
    }
    if (!sameModalityTargets(rhythm.modalityTargets, expected.modalityTargets)) {
      throw new Error(`Two-week plan compiler returned invalid modality targets for ${rhythm.weekStartDate}.`);
    }
    if (rhythm.workouts.length !== expected.workoutCount) {
      throw new Error(`Two-week plan compiler returned ${rhythm.workouts.length} workouts for ${rhythm.weekStartDate}; expected ${expected.workoutCount}.`);
    }
    const scheduledDates = new Set<string>();
    for (const workout of rhythm.workouts) {
      if (!expected.allowedDates.includes(workout.scheduledDate)) {
        throw new Error(`Two-week plan compiler scheduled ${workout.title} outside ${rhythm.weekStartDate}.`);
      }
      if (scheduledDates.has(workout.scheduledDate)) {
        throw new Error(`Two-week plan compiler scheduled more than one workout on ${workout.scheduledDate}.`);
      }
      scheduledDates.add(workout.scheduledDate);
      const resolvedModality = resolveWorkoutModality(workout, plannerInput);
      if (!resolvedModality || !allowed.has(resolvedModality)) {
        throw new Error(`Two-week plan compiler returned disallowed modality: ${workout.activityType}.`);
      }
      workout.activityType = resolvedModality;
      const archetype = workout.archetypeId
        ? plannerInput.approved_archetypes.find((candidate) => candidate.id === workout.archetypeId)
        : null;
      if (workout.archetypeId && (!archetype || normalizeModality(archetype.modality) !== resolvedModality)) {
        throw new Error(`Two-week plan compiler returned an invalid archetype for ${workout.title}.`);
      }
      if (!Number.isFinite(workout.durationMinutes) || workout.durationMinutes <= 0) {
        throw new Error(`Two-week plan compiler returned invalid duration for ${workout.title}.`);
      }
      validateCompactWorkoutCopy(workout);
    }
    validateWorkoutModalityTargets(rhythm, expected.modalityTargets);
    validateRecoveryLabels(rhythm);
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
  openingPlan: OpeningPlanContext,
  architecture: TrainingArchitecture,
  packet: PlanningPacket,
): TwoWeekPlanArtifact {
  if (artifact.rhythms.length !== draft.rhythms.length) {
    throw new Error("Prescription enrichment changed the number of weeks.");
  }
  for (const [rhythmIndex, rhythm] of artifact.rhythms.entries()) {
    const draftRhythm = draft.rhythms[rhythmIndex];
    if (!draftRhythm || rhythm.workouts.length !== draftRhythm.workouts.length) {
      throw new Error(`Prescription enrichment changed workout count for ${rhythm.weekStartDate}.`);
    }
    rhythm.objective = draftRhythm.objective;
    rhythm.hardEasyDistribution = draftRhythm.hardEasyDistribution;
    rhythm.swapRules = draftRhythm.swapRules;
    for (const [workoutIndex, workout] of rhythm.workouts.entries()) {
      const draftWorkout = draftRhythm.workouts[workoutIndex];
      restoreImmutableWorkoutFields(workout, draftWorkout);
    }
  }

  validateDraftPlanArtifact(artifact as unknown as DraftTwoWeekPlanArtifact, plannerInput, openingPlan);
  const disallowedEquipment = new Set(plannerInput.constraints.avoidances.map(normalizeLoose).filter(Boolean));
  for (const [rhythmIndex, rhythm] of artifact.rhythms.entries()) {
    const draftRhythm = draft.rhythms[rhythmIndex];
    for (const [workoutIndex, workout] of rhythm.workouts.entries()) {
      try {
        validateRichPrescription(workout.prescription, workout, disallowedEquipment);
        validateReentryPrescription(workout.prescription, workout, architecture);
        validateInterferencePrescription(workout, rhythm.workouts, architecture);
      } catch {
        const draftWorkout = draftRhythm.workouts[workoutIndex];
        workout.prescription = richPrescriptionForWorkout(
          { ...draftWorkout, title: workout.title },
          draftRhythm.workouts,
          packet,
          architecture,
          draftRhythm,
        );
        validateRichPrescription(workout.prescription, workout, disallowedEquipment);
        validateReentryPrescription(workout.prescription, workout, architecture);
        validateInterferencePrescription(workout, rhythm.workouts, architecture);
      }
    }
  }
  return artifact;
}

function validateReentryPrescription(
  prescription: RichWorkoutPrescription,
  workout: TwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  architecture: TrainingArchitecture,
) {
  if (!architecture.reentry?.active) return;
  const text = `${workout.title} ${workout.intensityLabel} ${workout.purpose} ${JSON.stringify(prescription.main.blocks)}`;
  if (/\b(vo2|max(?:imal)?|all[- ]?out|threshold|sprint|interval|race|hard)\b/i.test(text)) {
    throw new Error(`Re-entry prescription for ${workout.title} contains high-fatigue work.`);
  }
  if (workoutModality(workout) === "running") {
    const hasWalkRun = prescription.main.blocks.some((block) => block.kind === "walkRun");
    const hasEstimatedSteadyDistance = prescription.main.blocks.some((block) => (
      block.kind === "steady" && block.distanceKilometers !== null
    ));
    if (!hasWalkRun || hasEstimatedSteadyDistance) {
      throw new Error(`Re-entry running prescription for ${workout.title} must use walk-run durations without estimated distance.`);
    }
  }
}

function restoreImmutableWorkoutFields(
  workout: TwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  draftWorkout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
) {
  const fields: Array<keyof typeof draftWorkout> = [
    "scheduledDate",
    "sequenceOrder",
    "archetypeId",
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
  if (prescription.schemaVersion !== 2) throw new Error(`Prescription for ${workout.title} has invalid schemaVersion.`);
  if (!nonEmpty(prescription.summary) || !nonEmpty(prescription.whyToday) || !nonEmpty(prescription.successCriteria)) {
    throw new Error(`Prescription for ${workout.title} is missing summary, why-today context, or success criteria.`);
  }
  validateVisiblePrescriptionCopy(prescription, workout.title);
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
  const hasWalkRunBlock = prescription.main.blocks.some((block) => block.kind === "walkRun");
  const strengthBlocks = prescription.main.blocks.filter((block) => block.kind === "strengthExercise");
  if (strengthBlocks.length > 0 && modality !== "strength") {
    throw new Error(`Prescription for ${workout.title} has strength exercises but workout modality is ${modality}.`);
  }
  if (modality === "strength") {
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
    if (!hasSteadyBlock && !(modality === "running" && hasWalkRunBlock)) {
      throw new Error(`Endurance prescription for ${workout.title} has no steady or walk-run block.`);
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

function sameModalityTargets(
  left: Array<{ modality: string; sessions: number }>,
  right: Array<{ modality: string; sessions: number }>,
) {
  const normalized = (values: Array<{ modality: string; sessions: number }>) => values
    .map((value) => `${normalizeModality(value.modality)}:${Math.round(value.sessions)}`)
    .sort()
    .join("|");
  return normalized(left) === normalized(right);
}

function validateWorkoutModalityTargets(
  rhythm: DraftTwoWeekPlanArtifact["rhythms"][number],
  targets: Array<{ modality: string; sessions: number }>,
) {
  const actual = new Map<string, number>();
  for (const workout of rhythm.workouts) {
    const modality = workoutModality(workout);
    actual.set(modality, (actual.get(modality) ?? 0) + 1);
  }
  for (const target of targets) {
    if ((actual.get(normalizeModality(target.modality)) ?? 0) !== target.sessions) {
      throw new Error(`Two-week plan compiler missed the ${target.modality} session target for ${rhythm.weekStartDate}.`);
    }
  }
  if (totalTargetSessions(actual) !== targets.reduce((sum, target) => sum + target.sessions, 0)) {
    throw new Error(`Two-week plan compiler added an optional modality before core targets in ${rhythm.weekStartDate}.`);
  }
}

function validateRecoveryLabels(rhythm: DraftTwoWeekPlanArtifact["rhythms"][number]) {
  const ordered = [...rhythm.workouts].sort((left, right) => left.scheduledDate.localeCompare(right.scheduledDate));
  for (const [index, workout] of ordered.entries()) {
    if (!/recover|restorative/i.test(`${workout.title} ${workout.archetypeId ?? ""}`)) continue;
    const prior = ordered[index - 1];
    if (!prior || daysBetween(prior.scheduledDate, workout.scheduledDate) > 2 || !isLongOrHardDraftEndurance(prior)) {
      throw new Error(`Recovery-labelled workout ${workout.title} has no preceding load to recover from.`);
    }
  }
}

function validateCompactWorkoutCopy(workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number]) {
  if (workout.title.length > 32 || workout.title.trim().split(/\s+/).length > 4) {
    throw new Error(`Workout title is too long: ${workout.title}.`);
  }
  if (workout.fuelingSummary.length > 20 || workout.fuelingSummary.trim().split(/\s+/).length > 3) {
    throw new Error(`Workout fuel summary is too long: ${workout.fuelingSummary}.`);
  }
  for (const value of [workout.title, workout.intensityLabel, workout.purpose, workout.fuelingSummary]) {
    if (/[—–]/.test(value)) throw new Error(`Workout copy contains a prohibited dash glyph: ${workout.title}.`);
    if (/\b(?:RIR|RPE)\b/i.test(value)) throw new Error(`Workout copy contains internal effort shorthand: ${workout.title}.`);
    if (/\b[a-z][a-z0-9]*_[a-z0-9_]+\b/.test(value)) throw new Error(`Workout copy exposes an internal identifier: ${workout.title}.`);
    if (/\b(?:approvedArchetype|archetypeId|badDayFloor)\b/i.test(value)) {
      throw new Error(`Workout copy exposes an internal planning label: ${workout.title}.`);
    }
  }
}

function validateVisiblePrescriptionCopy(prescription: RichWorkoutPrescription, workoutTitle: string) {
  if (!/\b(?:Launch|Week\s+[12])\b/i.test(prescription.whyToday ?? "")) {
    throw new Error(`Prescription for ${workoutTitle} does not explain its program week.`);
  }
  const visit = (value: unknown, path: string) => {
    if (path.endsWith("constraintsApplied")) return;
    if (typeof value === "string") {
      if (/[—–]/.test(value)) throw new Error(`Prescription for ${workoutTitle} contains a prohibited dash glyph.`);
      if (/\b(?:RIR|RPE)\b/i.test(value)) throw new Error(`Prescription for ${workoutTitle} contains internal effort shorthand.`);
      if (/\b[a-z][a-z0-9]*_[a-z0-9_]+\b/.test(value)) throw new Error(`Prescription for ${workoutTitle} exposes an internal identifier.`);
      return;
    }
    if (Array.isArray(value)) {
      value.forEach((entry, index) => visit(entry, `${path}.${index}`));
      return;
    }
    if (value && typeof value === "object") {
      for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
        visit(entry, `${path}.${key}`);
      }
    }
  };
  visit(prescription, "prescription");
}

function compactVisibleTitle(value: string) {
  const words = plainVisibleCopy(value)
    .replace(/^[\s,;:|]+|[\s,;:|]+$/g, "")
    .split(/\s+/)
    .filter(Boolean);
  let title = "";
  for (const word of words.slice(0, 4)) {
    const candidate = title ? `${title} ${word}` : word;
    if (candidate.length > 32) break;
    title = candidate;
  }
  return title || "Training session";
}

function plainVisibleCopy(value: string) {
  return value
    .replace(/[—–]/g, ",")
    .replace(/\bRIR\b/gi, "reps left")
    .replace(/\bRPE\s*\d+(?:\s*-\s*\d+)?\b/gi, "controlled effort")
    .replace(/\s+/g, " ")
    .trim();
}

function plainEffort(value: string) {
  const normalized = plainVisibleCopy(value);
  if (/hard|high|vo2|threshold|tempo/i.test(normalized)) return "Moderate";
  if (/easy|low|recovery|zone 2/i.test(normalized)) return "Easy";
  return normalized || "Moderate";
}

function compactFueling(value: string, modality: string) {
  const normalized = normalizeLoose(value);
  if (/protein|strength/.test(`${normalized} ${modality}`)) return "Protein + carbs";
  if (/carb|long|hard|interval/.test(normalized)) return "Carbs + water";
  if (/hydr|water/.test(normalized)) return "Hydrate";
  return "Normal meals";
}

function openingPlanContext(
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
  visibleWeekStart: Date,
): OpeningPlanContext {
  const visibleStart = isoDate(visibleWeekStart);
  const visibleEnd = isoDate(addDays(visibleWeekStart, 6));
  const ownerCandidate = String(packet.athlete_context.hidden_inputs.planOwnerStartDate ?? "");
  const ownerStartDate = /^\d{4}-\d{2}-\d{2}$/.test(ownerCandidate)
    ? ownerCandidate
    : visibleStart;
  const partialWeek = ownerStartDate > visibleStart && ownerStartDate <= visibleEnd;
  const launchDates = partialWeek
    ? availableDatesForRange(packet, ownerStartDate, visibleEnd)
    : [];
  const launchCount = Math.min(2, launchDates.length);
  const programStart = partialWeek ? addDays(visibleWeekStart, 7) : visibleWeekStart;
  const programStartDate = isoDate(programStart);

  const programSpec = (weekStart: Date, programWeekNumber: number, requestedCount: number): OpeningRhythmSpec => {
    const weekStartDate = isoDate(weekStart);
    const weekEndDate = isoDate(addDays(weekStart, 6));
    const allowedDates = availableDatesForRange(packet, weekStartDate, weekEndDate);
    const workoutCount = Math.min(Math.max(0, requestedCount), allowedDates.length);
    return {
      weekStartDate,
      weekEndDate,
      programStage: "program",
      programWeekNumber,
      programStartDate,
      workoutCount,
      modalityTargets: modalityTargetsForCount(architecture, workoutCount, "program"),
      allowedDates,
    };
  };

  const targets = sessionTargetsForArchitecture(architecture);
  if (partialWeek && launchCount > 0) {
    return {
      ownerStartDate,
      programStartDate,
      rhythms: [{
        weekStartDate: visibleStart,
        weekEndDate: visibleEnd,
        programStage: "launch",
        programWeekNumber: null,
        programStartDate,
        workoutCount: launchCount,
        modalityTargets: modalityTargetsForCount(architecture, launchCount, "launch"),
        allowedDates: launchDates,
      },
      programSpec(programStart, 1, targets[0]),
      programSpec(addDays(programStart, 7), 2, targets[1])],
    };
  }

  const firstProgramStart = partialWeek ? programStart : visibleWeekStart;
  return {
    ownerStartDate,
    programStartDate: isoDate(firstProgramStart),
    rhythms: [
      programSpec(firstProgramStart, 1, targets[0]),
      programSpec(addDays(firstProgramStart, 7), 2, targets[1]),
    ],
  };
}

function availableDatesForRange(packet: PlanningPacket, startDate: string, endDate: string) {
  const allowed = new Set(packet.planning_constraints.available_days.map(normalizeWeekday).filter(Boolean));
  const dates: string[] = [];
  for (let date = parseDate(startDate); isoDate(date) <= endDate; date = addDays(date, 1)) {
    if (allowed.size === 0 || allowed.has(weekdayName(date))) dates.push(isoDate(date));
  }
  return dates;
}

function normalizeWeekday(value: string) {
  const normalized = value.trim().toLowerCase().slice(0, 3);
  const names: Record<string, string> = {
    sun: "sun", mon: "mon", tue: "tue", wed: "wed", thu: "thu", fri: "fri", sat: "sat",
  };
  return names[normalized] ?? "";
}

function weekdayName(date: Date) {
  return ["sun", "mon", "tue", "wed", "thu", "fri", "sat"][date.getUTCDay()] ?? "";
}

function modalityTargetsForCount(
  architecture: TrainingArchitecture,
  count: number,
  stage: "launch" | "program",
) {
  if (count <= 0) return [];
  const normalizedDoses = (architecture.modality_dose ?? [])
    .filter((dose) => dose.role !== "currently_inappropriate")
    .map((dose) => ({ ...dose, modality: normalizeModality(dose.modality) }))
    .filter((dose) => Boolean(dose.modality));
  const roleOrder = new Map(architecture.modality_roles.map((role, index) => [normalizeModality(role.modality), index]));
  const doses = normalizedDoses.length > 0
    ? [...normalizedDoses].sort((left, right) => (roleOrder.get(left.modality) ?? 99) - (roleOrder.get(right.modality) ?? 99))
    : architecture.priority_order.map((modality, index) => ({
      modality: normalizeModality(modality),
      role: index === 0 ? "primary_driver" as const : index === 1 ? "secondary_support" as const : "optional_filler" as const,
      minimum_sessions: index < 2 ? 1 : 0,
      target_sessions: index === 0 ? Math.ceil(count / 2) : index === 1 ? Math.floor(count / 2) : 0,
      maximum_sessions: count,
    }));
  const counts = new Map<string, number>();
  const add = (dose: typeof doses[number]) => counts.set(dose.modality, (counts.get(dose.modality) ?? 0) + 1);
  const core = doses.filter((dose) => dose.role !== "optional_filler");

  if (stage === "launch") {
    const primary = doses.find((dose) => dose.role === "primary_driver") ?? core[0] ?? doses[0];
    const secondary = doses.find((dose) => dose.role === "secondary_support") ?? core.find((dose) => dose !== primary);
    if (primary) add(primary);
    if (count > 1 && secondary) add(secondary);
    while ([...counts.values()].reduce((sum, value) => sum + value, 0) < count && primary) add(primary);
  } else {
    const fillTo = (candidates: typeof doses, key: "minimum_sessions" | "target_sessions" | "maximum_sessions") => {
      for (const dose of candidates) {
        while ((counts.get(dose.modality) ?? 0) < dose[key] && totalTargetSessions(counts) < count) add(dose);
      }
    };
    fillTo(core, "minimum_sessions");
    fillTo(core, "target_sessions");
    fillTo(doses.filter((dose) => dose.role === "optional_filler"), "target_sessions");
    fillTo(core, "maximum_sessions");
    const primary = doses.find((dose) => dose.role === "primary_driver") ?? core[0] ?? doses[0];
    while (totalTargetSessions(counts) < count && primary) add(primary);
  }

  return Array.from(counts, ([modality, sessions]) => ({ modality, sessions })).filter((target) => target.sessions > 0);
}

function totalTargetSessions(counts: Map<string, number>) {
  return [...counts.values()].reduce((sum, value) => sum + value, 0);
}

function applyPlanContractGuardrails(
  artifact: DraftTwoWeekPlanArtifact,
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
  openingPlan: OpeningPlanContext,
) {
  const guarded = applyReentryGuardrails(artifact, architecture);
  guarded.block.startDate = openingPlan.programStartDate;
  guarded.block.targetDate = packet.goal_context.timeframe_weeks
    ? isoDate(addDays(parseDate(openingPlan.programStartDate), packet.goal_context.timeframe_weeks * 7 - 1))
    : null;
  guarded.phases = guarded.phases.map((phase, index) => {
    const architecturePhase = architecture.phase_logic.phases[index];
    if (!architecturePhase) return phase;
    const startWeek = architecturePhase.start_week ?? (index === 0 ? 1 : Math.max(2, index * 4 + 1));
    const endWeek = architecturePhase.end_week ?? Math.max(startWeek, index === architecture.phase_logic.phases.length - 1
      ? packet.goal_context.timeframe_weeks ?? startWeek + 3
      : startWeek + 3);
    return {
      ...phase,
      startDate: isoDate(addDays(parseDate(openingPlan.programStartDate), (startWeek - 1) * 7)),
      endDate: isoDate(addDays(parseDate(openingPlan.programStartDate), endWeek * 7 - 1)),
    };
  });

  guarded.rhythms = openingPlan.rhythms.map((spec, rhythmIndex) => {
    const generatedRhythm = guarded.rhythms[rhythmIndex];
    const desiredModalities = spec.modalityTargets.flatMap((target) => Array.from({ length: target.sessions }, () => target.modality));
    const scheduledDates = spreadDates(spec.allowedDates, spec.workoutCount);
    const unused = [...(generatedRhythm?.workouts ?? [])];
    const selected = desiredModalities.map((modality, workoutIndex) => {
      const matchingIndex = unused.findIndex((workout) => workoutModality(workout) === normalizeModality(modality));
      const candidate = matchingIndex >= 0 ? unused.splice(matchingIndex, 1)[0] : null;
      return normalizeDraftWorkout(
        candidate ?? deterministicDraftWorkout(modality, workoutIndex, architecture),
        modality,
        scheduledDates[workoutIndex],
        workoutIndex,
        architecture,
      );
    });
    return {
      ...(generatedRhythm ?? weekRhythm(parseDate(spec.weekStartDate), architecture, packet, rhythmIndex, spec)),
      weekStartDate: spec.weekStartDate,
      weekEndDate: spec.weekEndDate,
      programStage: spec.programStage,
      programWeekNumber: spec.programWeekNumber,
      programStartDate: spec.programStartDate,
      modalityTargets: spec.modalityTargets,
      objective: spec.programStage === "launch"
        ? "Use two familiar sessions to bridge into Program Week 1."
        : programObjective(spec.programWeekNumber, architecture),
      hardEasyDistribution: architecture.reentry?.active
        ? { hard: 0, moderate: Math.max(0, selected.length - 2), easy: Math.min(2, selected.length) }
        : generatedRhythm?.hardEasyDistribution ?? { hard: 0, moderate: Math.max(0, selected.length - 1), easy: Math.min(1, selected.length) },
      badDayFloor: packet.planning_constraints.bad_day_floor ?? "Do the shortest useful version and preserve the habit.",
      workouts: selected,
    };
  }) as DraftTwoWeekPlanArtifact["rhythms"];
  return guarded;
}

function spreadDates(allowedDates: string[], count: number) {
  if (count <= 0) return [];
  if (count === 1) return allowedDates.slice(0, 1);
  return Array.from({ length: count }, (_, index) => (
    allowedDates[Math.round((index * (allowedDates.length - 1)) / (count - 1))]
  ));
}

function normalizeDraftWorkout(
  workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  modality: string,
  scheduledDate: string,
  index: number,
  architecture: TrainingArchitecture,
) {
  const normalizedModality = normalizeModality(modality);
  const existingArchetype = workout.archetypeId
    ? architecture.approved_archetypes.find((candidate) => candidate.id === workout.archetypeId && normalizeModality(candidate.modality) === normalizedModality)
    : null;
  const archetype = existingArchetype && !isRecoveryArchetype(existingArchetype)
    ? existingArchetype
    : pickArchetype(architecture.approved_archetypes, normalizedModality, index);
  const reentryWalkRun = shouldUseWalkRun(normalizedModality, archetype?.id ?? null, architecture);
  const recoveryCopy = /recover|restorative/i.test(`${workout.title} ${workout.purpose} ${workout.archetypeId ?? ""}`);
  return {
    ...workout,
    scheduledDate,
    sequenceOrder: index + 1,
    archetypeId: archetype?.id ?? null,
    activityType: normalizedModality,
    title: compactVisibleTitle(reentryWalkRun ? "Easy walk-run" : descriptiveDraftTitle(normalizedModality, archetype, workout)),
    durationMinutes: Math.max(10, workout.durationMinutes || (archetype ? typicalDuration(archetype) : 30)),
    intensityLabel: architecture.reentry?.active ? "Easy" : plainEffort(workout.intensityLabel),
    purpose: recoveryCopy
      ? "Build easy aerobic rhythm without adding fatigue."
      : plainVisibleCopy(workout.purpose || archetype?.purpose || "Support this week without crowding fatigue."),
    fuelingSummary: compactFueling(workout.fuelingSummary, normalizedModality),
  };
}

function deterministicDraftWorkout(modality: string, index: number, architecture: TrainingArchitecture) {
  const archetype = pickArchetype(architecture.approved_archetypes, modality, index);
  return {
    scheduledDate: "",
    sequenceOrder: index + 1,
    archetypeId: archetype?.id ?? null,
    activityType: normalizeModality(modality),
    title: archetype ? titleFromArchetype(archetype) : `${titleCase(modality)} support`,
    durationMinutes: archetype ? typicalDuration(archetype) : 30,
    intensityLabel: architecture.reentry?.active ? "Easy" : archetype ? intensityLabel(archetype.intensity_domain) : "Easy",
    purpose: archetype?.purpose ?? "Support the plan without crowding recovery.",
    prescription: {
      warmup: "Start easy and check readiness.",
      main: ["Complete a controlled session and finish with energy in reserve."],
      cooldown: "Finish easy and note any recovery flags.",
      successCriteria: "Finish feeling capable of repeating the session.",
    },
    fuelingSummary: "Normal meals",
  };
}

function descriptiveDraftTitle(
  modality: string,
  archetype: WorkoutArchetypeRecommendation | null,
  workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
) {
  if (modality === "cycling") return "Easy endurance ride";
  if (modality === "strength") return "Strength support";
  if (modality === "running") return "Easy aerobic run";
  return archetype ? titleFromArchetype(archetype) : workout.title;
}

function programObjective(programWeekNumber: number | null, architecture: TrainingArchitecture) {
  if (programWeekNumber === 1 && architecture.reentry?.active) return "Rebuild a repeatable rhythm with easy cycling and controlled strength.";
  if (programWeekNumber === 2 && architecture.reentry?.active) return "Add a small amount of volume only if Week 1 felt manageable.";
  return programWeekNumber === 1 ? "Establish the first repeatable program week." : "Progress the plan without crowding recovery.";
}

function deterministicTestPlan(
  packet: PlanningPacket,
  architecture: TrainingArchitecture,
  fitnessStrategy: FitnessStrategyArtifact,
): DraftTwoWeekPlanArtifact {
  const start = parseDate(packet.planning_constraints.start_date);
  const openingPlan = openingPlanContext(packet, architecture, start);
  return {
    block: {
      kind: packet.goal_context.goal_kind,
      title: fitnessStrategy.snapshotItems.find((item) => item.id === "priority")?.value ?? "Training Strategy",
      goalText: String(packet.goal_context.normalized_goal.title ?? "Active goal"),
      startDate: openingPlan.programStartDate,
      targetDate: packet.goal_context.timeframe_weeks
        ? isoDate(addDays(parseDate(openingPlan.programStartDate), packet.goal_context.timeframe_weeks * 7 - 1))
        : null,
      reviewCadenceDays: packet.goal_context.goal_kind === "consistency" ? 28 : Math.max(28, (packet.goal_context.timeframe_weeks ?? 8) * 7),
      context: {
        trainingArchitecture: architecture,
        planningRationale: architecture.goal_read.summary,
        dataFreshness: packet.approved_evidence_summary.confidence,
      },
    },
    phases: architecture.phase_logic.phases.map((phase, index) => ({
      name: phase.name,
      startDate: isoDate(addDays(parseDate(openingPlan.programStartDate), ((phase.start_week ?? (index === 0 ? 1 : index * 4 + 1)) - 1) * 7)),
      endDate: isoDate(addDays(parseDate(openingPlan.programStartDate), (phase.end_week ?? packet.goal_context.timeframe_weeks ?? (index + 1) * 4) * 7 - 1)),
      objective: phase.objective,
      focus: [phase.objective],
      risk: architecture.conflict_assessment.required_tradeoffs,
    })),
    rhythms: openingPlan.rhythms.map((spec, index) => (
      weekRhythm(parseDate(spec.weekStartDate), architecture, packet, index, spec)
    )),
  };
}

function weekRhythm(
  weekStart: Date,
  architecture: TrainingArchitecture,
  packet: PlanningPacket,
  weekIndex: number,
  spec: OpeningRhythmSpec,
): DraftTwoWeekPlanArtifact["rhythms"][number] {
  const sessions = spec.workoutCount;
  const priority = architecture.priority_order;
  const approvedArchetypes = architecture.approved_archetypes;
  const modalities = spec.modalityTargets.flatMap((target) => Array.from({ length: target.sessions }, () => target.modality));
  return {
    weekStartDate: isoDate(weekStart),
    weekEndDate: isoDate(addDays(weekStart, 6)),
    programStage: spec.programStage,
    programWeekNumber: spec.programWeekNumber,
    programStartDate: spec.programStartDate,
    modalityTargets: spec.modalityTargets,
    objective: spec.programStage === "launch"
      ? "Use two familiar sessions to bridge into Program Week 1."
      : programObjective(spec.programWeekNumber, architecture),
    priorityOrder: priority,
    hardEasyDistribution: {
      hard: architecture.weekly_budget.hard_sessions,
      moderate: Math.max(0, sessions - architecture.weekly_budget.hard_sessions - 1),
      easy: 1,
    },
    badDayFloor: packet.planning_constraints.bad_day_floor ?? "Do the shortest useful version and preserve the habit.",
    swapRules: architecture.planner_constraints.weekly_plan_rules,
    workouts: Array.from({ length: sessions }, (_, index) => {
      const modality = modalities[index] ?? priority[index % priority.length] ?? "training";
      const archetype = pickArchetype(approvedArchetypes, modality, index);
      const date = spec.allowedDates[index] ?? isoDate(weekStart);
      return normalizeDraftWorkout({
        scheduledDate: date,
        sequenceOrder: index + 1,
        archetypeId: archetype?.id ?? null,
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
        fuelingSummary: archetype?.fatigue_cost === "high" ? "Protein + carbs" : "Normal meals",
      }, modality, date, index, architecture);
    }),
  };
}

function sessionTargetsForArchitecture(architecture: TrainingArchitecture): [number, number] {
  const clamp = (value: number) => Math.min(7, Math.max(1, Math.round(value)));
  return [
    clamp(architecture.weekly_budget.committed_week_sessions ?? architecture.weekly_budget.target_sessions),
    clamp(architecture.weekly_budget.draft_week_sessions ?? architecture.weekly_budget.target_sessions),
  ];
}

function applyReentryGuardrails(
  artifact: DraftTwoWeekPlanArtifact,
  architecture: TrainingArchitecture,
): DraftTwoWeekPlanArtifact {
  if (!architecture.reentry?.active) return artifact;
  const unsafeIntensity = /\b(vo2|max(?:imal)?|all[- ]?out|threshold|sprint|interval|race|hard)\b/i;
  for (const [weekIndex, rhythm] of artifact.rhythms.entries()) {
    rhythm.objective = weekIndex === 0
      ? `Re-enter training conservatively after a ${architecture.reentry.gap_days ?? "meaningful"}-day interruption.`
      : "Draft a small progression only if the committed re-entry week holds.";
    rhythm.hardEasyDistribution.hard = 0;
    rhythm.hardEasyDistribution.easy = Math.max(1, rhythm.hardEasyDistribution.easy);
    rhythm.hardEasyDistribution.moderate = Math.max(0, rhythm.workouts.length - rhythm.hardEasyDistribution.easy);
    for (const workout of rhythm.workouts) {
      if (unsafeIntensity.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose} ${workout.prescription.main.join(" ")}`)) {
        workout.title = `${titleCase(normalizeModality(workout.activityType))} Re-entry`;
        workout.intensityLabel = weekIndex === 0 ? "Easy" : "Easy to moderate";
        workout.purpose = weekIndex === 0
          ? "Restore repeatable training tolerance without chasing fatigue."
          : "Build gently on the committed re-entry week if recovery is stable.";
        workout.prescription = {
          warmup: "Start very easy and check for pain, unusual heaviness, or poor coordination.",
          main: ["Complete a controlled conversational-effort session and stop with plenty in reserve."],
          cooldown: "Finish easy and note how the session felt later that day and the next morning.",
          successCriteria: "Finish feeling capable of repeating the session without worsening pain or recovery signals.",
        };
      }
    }
  }
  return artifact;
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
          prescription: richPrescriptionForWorkout({ ...workout, title }, rhythm.workouts, packet, architecture, rhythm),
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
    if (shouldUseWalkRun(modality, workout.archetypeId, architecture)) return "Easy walk-run";
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
  rhythm: Pick<DraftTwoWeekPlanArtifact["rhythms"][number], "programStage" | "programWeekNumber">,
): RichWorkoutPrescription {
  const modality = workoutModality(workout);
  const constraintsApplied = constraintsForWorkout(workout, weekWorkouts, packet, architecture);
  const equipmentAccess = packet.planning_constraints.equipment_access.map((value) => value.toLowerCase());
  const whyToday = whyTodayForWorkout(workout, rhythm, architecture);
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
      schemaVersion: 2,
      summary: "A controlled strength session that supports the plan without chasing soreness.",
      whyToday,
      warmup: stepGroup("Warm up", "Prepare joints and movement patterns before loading.", 8, ["5 min easy bike or treadmill", "Two light ramp-up sets for the first lift"]),
      main: {
        title: "Strength work",
        description: useLegCaution
          ? "Keep lower-body loading light because hard or long endurance work is nearby."
          : "Use repeatable full-body lifts with clean reps and bounded fatigue.",
        blocks: exercises,
      },
      cooldown: stepGroup("Cool down", "Bring effort down and check recovery signals.", 5, ["Easy walk", "Light hips, calves, and upper-back mobility"]),
      successCriteria: "Finish every set with 2-3 good reps left and no form breakdown.",
      equipment: uniqueStrings(exercises.flatMap((block) => block.kind === "strengthExercise" ? [block.machineOrEquipment] : [])),
      constraintsApplied,
    };
  }

  if (modality === "cycling") {
    const interval = /interval|vo2|tempo|threshold/i.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`);
    return {
      schemaVersion: 2,
      summary: interval ? "Structured ride quality with controlled recoveries." : "Aerobic ride built around steady repeatable volume.",
      whyToday,
      warmup: stepGroup("Warm up", "Ease into the ride before the main work.", 10, ["Ride easy", "Add 2 short cadence pickups if legs feel good"]),
      main: {
        title: interval ? "Ride intervals" : "Steady ride",
        description: interval ? "Keep the hard blocks controlled, not maximal." : "Stay mostly aerobic and smooth.",
        blocks: [interval
          ? intervalBlock("Main intervals", workout.durationMinutes >= 50 ? 4 : 3, "4 min", "3 min easy", "Strong but sustainable")
          : steadyBlock("Aerobic block", workout.durationMinutes, estimatedDistance(workout, "cycling"), null, "Easy conversational effort")],
      },
      cooldown: stepGroup("Cool down", "Finish easy enough to protect the next session.", 8, ["Easy spin", "Note heavy legs or unusual fatigue"]),
      successCriteria: "Complete the planned time while keeping the final 10 minutes controlled.",
      equipment: ["Bike"],
      constraintsApplied,
    };
  }

  if (modality === "running") {
    const interval = /interval|stride|vo2|tempo|threshold/i.test(`${workout.title} ${workout.intensityLabel} ${workout.purpose}`);
    const walkRun = shouldUseWalkRun(modality, workout.archetypeId, architecture);
    return {
      schemaVersion: 2,
      summary: walkRun ? "Gentle run and walk repeats that rebuild impact tolerance." : interval ? "Structured run quality with impact kept bounded." : "Easy run volume that supports consistency.",
      whyToday,
      warmup: stepGroup("Warm up", "Start gently before any faster work.", 10, ["Easy jog", "Dynamic calves and hips"]),
      main: {
        title: walkRun ? "Run and walk" : interval ? "Run intervals" : "Steady run",
        description: walkRun ? "Alternate gentle running with walking to control impact." : interval ? "Keep fast work relaxed enough to preserve form." : "Stay easy enough to finish feeling in control.",
        blocks: [walkRun
          ? walkRunBlock(workout.durationMinutes)
          : interval
          ? intervalBlock("Main intervals", workout.durationMinutes >= 45 ? 5 : 4, "2 min", "2 min easy jog", "Fast but relaxed, around 5K-10K effort")
          : steadyBlock("Aerobic block", workout.durationMinutes, estimatedDistance(workout, "running"), null, "Easy conversational pace")],
      },
      cooldown: stepGroup("Cool down", "Reduce impact and check for tendon irritation.", 5, ["Easy walk or jog", "Light calves and hips mobility"]),
      successCriteria: "Keep pace controlled enough that gait stays smooth.",
      equipment: ["Running shoes"],
      constraintsApplied,
    };
  }

  return {
    schemaVersion: 2,
    summary: "Low-load work to keep the week moving.",
    whyToday,
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
    effortTarget: "Finish with 2-3 good reps left",
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

function walkRunBlock(durationMinutes: number) {
  const repeats = Math.max(3, Math.floor(Math.max(12, durationMinutes - 10) / 4));
  return {
    kind: "walkRun" as const,
    title: "Run and walk repeats",
    description: "Alternate relaxed running with brisk walking.",
    repeats,
    runDurationMinutes: 2,
    walkDurationMinutes: 2,
    target: "Easy enough to speak in full sentences",
    notes: "Switch to walking early if impact feels uncomfortable.",
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

function whyTodayForWorkout(
  workout: DraftTwoWeekPlanArtifact["rhythms"][number]["workouts"][number],
  rhythm: Pick<DraftTwoWeekPlanArtifact["rhythms"][number], "programStage" | "programWeekNumber">,
  architecture: TrainingArchitecture,
) {
  const modality = workoutModality(workout);
  const label = rhythm.programStage === "launch" ? "Launch" : `Week ${rhythm.programWeekNumber ?? 1}`;
  if (rhythm.programStage === "launch") {
    if (modality === "cycling") return "Launch starts with an easy ride to restore bike rhythm before Week 1.";
    if (modality === "strength") return "Launch uses familiar strength work to prepare your body for Week 1.";
    return "Launch uses a short familiar session to prepare for Week 1.";
  }
  if (modality === "cycling") {
    return `${label} uses this easy ride to build cycling consistency for later climbing work.`;
  }
  if (modality === "strength") {
    return `${label} uses strength to protect muscle while the cycling plan builds.`;
  }
  if (modality === "running" && architecture.reentry?.active) {
    return `${label} keeps running optional and uses walk breaks to rebuild impact tolerance.`;
  }
  return `${label} uses this session to support the current phase without crowding recovery.`;
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
  if (workout.archetypeId) {
    const exact = architecture.approved_archetypes.find((archetype) => archetype.id === workout.archetypeId);
    if (exact) return exact;
  }
  return architecture.approved_archetypes.find((archetype) => archetype.modality === modality && (
    normalizeLoose(workout.title).includes(normalizeLoose(titleFromArchetype(archetype))) ||
    normalizeLoose(workout.purpose).includes(normalizeLoose(archetype.purpose))
  ));
}

function pickArchetype(archetypes: WorkoutArchetypeRecommendation[], modality: string, index: number) {
  const matches = archetypes.filter((archetype) => normalizeModality(archetype.modality) === normalizeModality(modality) && !isRecoveryArchetype(archetype));
  if (!matches.length) return null;
  return matches[index % matches.length] ?? matches[0];
}

function isRecoveryArchetype(archetype: WorkoutArchetypeRecommendation) {
  return /recovery|recover|restorative/i.test(`${archetype.id} ${archetype.purpose} ${archetype.intensity_domain}`);
}

function shouldUseWalkRun(modality: string, archetypeId: string | null, architecture: TrainingArchitecture) {
  void archetypeId;
  return architecture.reentry?.active && normalizeModality(modality) === "running";
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
