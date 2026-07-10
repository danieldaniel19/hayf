export type JsonObject = Record<string, unknown>;

export type KnowledgeSourceRef = {
  id: string;
  title: string;
  version: string;
  path: string;
};

export type PlanningPacket = {
  athlete_context: {
    blueprint_revision_id: string;
    coach_read: string;
    athlete_archetype: JsonObject;
    current_training_state: JsonObject;
    history_findings: unknown[];
    goal_fit: JsonObject;
    hidden_inputs: JsonObject;
  };
  goal_context: {
    user_goal_id?: string;
    normalized_goal: JsonObject;
    goal_kind: "consistency" | "specific_goal" | "goal_discovery_chosen";
    timeframe_weeks: number | null;
    success_definition: string | null;
    selected_modality_order: string[];
    body_composition_intent: string | null;
  };
  planning_constraints: {
    feasible_modalities: string[];
    frequency: string | null;
    session_length: string | null;
    injuries: string | null;
    equipment_access: string[];
    avoidances: string[];
    bad_day_floor: string | null;
    timezone: string;
    start_date: string;
  };
  approved_evidence_summary: {
    recent_training_load: JsonObject;
    consistency: JsonObject;
    modality_mix: JsonObject;
    body_recovery_context: JsonObject;
    confidence: string;
    caveats: string[];
  };
  generation_policy: {
    visible_horizon_weeks: 2;
    committed_horizon_weeks: 1;
    allowed_claims: string[];
    ai_first_plan_generation: boolean;
  };
};

export type ModalityRole =
  | "primary_driver"
  | "secondary_support"
  | "maintenance_exposure"
  | "optional_filler"
  | "currently_inappropriate";

export type TrainingArchitectFrame = {
  goal_read: {
    summary: string;
    priority_basis: string[];
    conflict_questions: string[];
  };
  selected_modalities: string[];
  feasible_modalities: string[];
  priority_hypotheses: string[];
  weekly_budget_range: {
    minimum_sessions: number;
    target_sessions: number;
    maximum_sessions: number;
    hard_day_cap: number;
  };
  recovery_risks: string[];
  specialist_briefs: Array<{
    modality: string;
    pack_id: string;
    requested_role: ModalityRole;
    brief: string;
    questions: string[];
    knowledge_refs: KnowledgeSourceRef[];
  }>;
  knowledge_refs: KnowledgeSourceRef[];
};

export type CoachToolRequest = {
  tool_name: string;
  purpose: string;
  input: JsonObject;
  optional: boolean;
};

export type WorkoutArchetypeRecommendation = {
  id: string;
  modality: string;
  purpose: string;
  target_adaptation: string;
  intensity_domain: string;
  typical_duration_minutes: {
    min: number;
    max: number;
  };
  dose_range: string;
  progression_rule: string;
  fatigue_cost: "low" | "moderate" | "high";
  prerequisites: string[];
  incompatibilities: string[];
  planner_constraints: string[];
  knowledge_refs: KnowledgeSourceRef[];
};

export type SpecialistConsultation = {
  coach: string;
  modality: string;
  recommended_role: ModalityRole;
  rationale: string;
  performance_determinants: string[];
  adaptation_priorities: string[];
  intensity_model: string;
  weekly_dose: {
    minimum: string;
    target: string;
    maximum: string;
    hard_cap: string;
  };
  archetype_proposals: WorkoutArchetypeRecommendation[];
  fatigue_signals: string[];
  interference_rules: string[];
  common_mistakes: string[];
  tool_requests: CoachToolRequest[];
  knowledge_refs: KnowledgeSourceRef[];
};

export type SpecialistRecommendation = {
  coach: string;
  modality: string;
  role: ModalityRole;
  development_path: string;
  weekly_dose: string;
  key_risks: string[];
  planning_rules: string[];
};

export type SpecialistRecommendationDisposition = {
  modality: string;
  archetype_id?: string;
  reason: string;
  phase_hint?: string;
  knowledge_refs: KnowledgeSourceRef[];
};

export type TrainingArchitecture = {
  source_ids: {
    blueprint_revision_id: string;
    user_goal_id?: string;
  };
  goal_read: {
    summary: string;
    goal_kind: PlanningPacket["goal_context"]["goal_kind"];
    success_definition: string | null;
  };
  modality_roles: Array<{
    modality: string;
    role: ModalityRole;
    rationale: string;
    knowledge_refs: KnowledgeSourceRef[];
  }>;
  priority_order: string[];
  weekly_budget: {
    target_sessions: number;
    minimum_viable_sessions: number;
    hard_sessions: number;
    recovery_sessions: number;
  };
  recovery_envelope: {
    max_hard_days_per_week: number;
    spacing_rules: string[];
    bad_day_floor: string | null;
  };
  minimum_effective_dose_rules: string[];
  specialist_recommendations: SpecialistRecommendation[];
  architect_frame_summary: TrainingArchitectFrame;
  specialist_consultations: SpecialistConsultation[];
  approved_archetypes: WorkoutArchetypeRecommendation[];
  deferred_specialist_recommendations: SpecialistRecommendationDisposition[];
  rejected_specialist_recommendations: SpecialistRecommendationDisposition[];
  phase_logic: {
    requires_phases: boolean;
    phases: Array<{
      id: string;
      name: string;
      objective: string;
    }>;
  };
  progression_rules: string[];
  interference_rules: string[];
  conflict_assessment: {
    status: "clear" | "manageable_tradeoff" | "conflicting";
    summary: string;
    required_tradeoffs: string[];
  };
  conflict_decisions: Array<{
    id: string;
    decision: string;
    rationale: string;
    knowledge_refs: KnowledgeSourceRef[];
  }>;
  planner_constraints: {
    weekly_plan_rules: string[];
    workout_generation_rules: string[];
    target_generation_rules: string[];
  };
  source_knowledge_refs: KnowledgeSourceRef[];
};

export type FitnessStrategyArtifact = {
  read: string;
  goalTargetContext: {
    title: string;
    summary: string;
  };
  snapshotItems: Array<{
    id: string;
    systemImage: string;
    value: string;
    label: string;
  }>;
  fitReasons: Array<{
    id: string;
    systemImage: string;
    title: string;
    summary: string;
  }>;
  pillars: Array<{
    id: string;
    title: string;
    summary: string;
  }>;
  phases: Array<{
    id: string;
    name: string;
    objective: string;
    targetSummary: string;
    targets: StrategyTarget[];
  }>;
  operatingRhythm: {
    summary: string;
    anchors: string[];
  } | null;
  targets: StrategyTarget[];
};

export type PlannerInputContract = {
  validated_architecture: TrainingArchitecture;
  approved_archetypes: WorkoutArchetypeRecommendation[];
  strategy: FitnessStrategyArtifact;
  constraints: PlanningPacket["planning_constraints"];
  actuals_summary: JsonObject;
  draft_inputs: JsonObject;
  allowed_modalities: string[];
};

export type StrategyTarget = {
  id: string;
  scope: "goal" | "strategy" | "phase" | "week";
  kind: "primary" | "supporting";
  title: string;
  summary: string;
  metricKey: string | null;
  metricCategory: string;
  direction: "increase" | "decrease" | "maintain" | "complete" | "review";
  targetValue: number | null;
  unit: string | null;
  displayValue: string | null;
};

export type SimpleWorkoutPrescription = {
  warmup: string;
  main: string[];
  cooldown: string;
  successCriteria: string;
};

export type WorkoutPrescriptionStepGroup = {
  title: string;
  description: string;
  durationMinutes: number | null;
  steps: string[];
};

export type WorkoutPrescriptionMainBlock =
  | {
      kind: "interval";
      title: string;
      description: string;
      repeats: number;
      workDuration: string;
      recoveryDuration: string;
      target: string;
      notes: string;
    }
  | {
      kind: "steady";
      title: string;
      description: string;
      durationMinutes: number | null;
      distanceKilometers: number | null;
      elevationMeters: number | null;
      target: string;
      terrainNotes: string | null;
    }
  | {
      kind: "strengthExercise";
      title: string;
      description: string;
      exerciseName: string;
      machineOrEquipment: string;
      sets: number;
      reps: string;
      restSeconds: number;
      effortTarget: string;
      coachingCue: string;
      alternatives: Array<{
        exerciseName: string;
        equipment: string;
        notes: string;
      }>;
    }
  | {
      kind: "mobilityRecovery";
      title: string;
      description: string;
      durationMinutes: number;
      movementFocus: string;
      steps: string[];
    };

export type RichWorkoutPrescription = {
  schemaVersion: 1;
  summary: string;
  warmup: WorkoutPrescriptionStepGroup;
  main: {
    title: string;
    description: string;
    blocks: WorkoutPrescriptionMainBlock[];
  };
  cooldown: WorkoutPrescriptionStepGroup;
  successCriteria: string;
  equipment: string[];
  constraintsApplied: string[];
};

export type DraftTwoWeekPlanArtifact = Omit<TwoWeekPlanArtifact, "rhythms"> & {
  rhythms: Array<Omit<TwoWeekPlanArtifact["rhythms"][number], "workouts"> & {
    workouts: Array<Omit<TwoWeekPlanArtifact["rhythms"][number]["workouts"][number], "prescription"> & {
      prescription: SimpleWorkoutPrescription;
    }>;
  }>;
};

export type TwoWeekPlanArtifact = {
  block: {
    kind: PlanningPacket["goal_context"]["goal_kind"];
    title: string;
    goalText: string;
    startDate: string;
    targetDate: string | null;
    reviewCadenceDays: number;
    context: JsonObject;
  };
  phases: Array<{
    name: string;
    startDate: string | null;
    endDate: string | null;
    objective: string;
    focus: string[];
    risk: string[];
  }>;
  rhythms: Array<{
    weekStartDate: string;
    weekEndDate: string;
    objective: string;
    priorityOrder: string[];
    hardEasyDistribution: {
      hard: number;
      moderate: number;
      easy: number;
    };
    badDayFloor: string;
    swapRules: string[];
    workouts: Array<{
      scheduledDate: string;
      sequenceOrder: number;
      activityType: string;
      title: string;
      durationMinutes: number;
      intensityLabel: string;
      purpose: string;
      prescription: RichWorkoutPrescription;
      fuelingSummary: string;
    }>;
  }>;
};

export type GraphTraceNode = {
  node_name: string;
  subgraph_name?: string;
  input_summary: JsonObject;
  output: JsonObject;
  validation: JsonObject;
  status: "succeeded" | "failed" | "skipped";
};

export type GraphToolCall = {
  tool_name: string;
  tool_version: string;
  graph_node_name?: string;
  input: JsonObject;
  output: JsonObject | null;
  status: "succeeded" | "failed" | "skipped";
  error_message?: string | null;
  latency_ms?: number | null;
  provider?: string;
  model?: string;
  system_prompt?: string;
  request_json?: JsonObject;
  schema_json?: JsonObject;
  knowledge_refs?: KnowledgeSourceRef[];
};

export type GraphResult<T> = {
  artifact: T;
  nodes: GraphTraceNode[];
  tool_calls: GraphToolCall[];
};

export function assertPlanningPacket(value: unknown): asserts value is PlanningPacket {
  const packet = value as Partial<PlanningPacket> | null;
  if (!packet || typeof packet !== "object") {
    throw new Error("Planning packet must be an object.");
  }
  if (!packet.athlete_context?.blueprint_revision_id) {
    throw new Error("Planning packet requires athlete_context.blueprint_revision_id.");
  }
  if (!packet.goal_context?.goal_kind) {
    throw new Error("Planning packet requires goal_context.goal_kind.");
  }
  if (!packet.planning_constraints?.timezone || !packet.planning_constraints.start_date) {
    throw new Error("Planning packet requires timezone and start_date.");
  }
  if (/"(workoutLedger|rawHealthKitSamples|healthKitSamples|samples)"\s*:/.test(JSON.stringify(packet))) {
    throw new Error("Planning packet must not include raw HealthKit workout ledgers or samples.");
  }
}

export function normalizeModality(value: string) {
  const normalized = value.trim().toLowerCase();
  if (normalized.includes("cycl") || normalized.includes("bike") || normalized.includes("biking") || normalized.includes("ride")) return "cycling";
  if (normalized.includes("run") || normalized.includes("jog")) return "running";
  if (
    normalized.includes("strength") ||
    normalized.includes("gym") ||
    normalized.includes("lift") ||
    normalized.includes("full body") ||
    normalized.includes("full_body") ||
    normalized.includes("bodyweight") ||
    normalized.includes("resistance")
  ) return "strength";
  if (normalized.includes("swim")) return "swimming";
  if (normalized.includes("tennis")) return "tennis";
  if (normalized.includes("row")) return "rowing";
  if (normalized.includes("hike")) return "hiking";
  if (normalized.includes("walk")) return "walking";
  return normalized.replace(/\s+/g, "_") || "general";
}
