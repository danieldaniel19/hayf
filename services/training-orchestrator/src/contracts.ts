export type JsonObject = Record<string, unknown>;

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

export type SpecialistRecommendation = {
  coach: string;
  modality: string;
  role: ModalityRole;
  development_path: string;
  weekly_dose: string;
  key_risks: string[];
  planning_rules: string[];
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
  planner_constraints: {
    weekly_plan_rules: string[];
    workout_generation_rules: string[];
    target_generation_rules: string[];
  };
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
      prescription: {
        warmup: string;
        main: string[];
        cooldown: string;
        successCriteria: string;
      };
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

export type GraphResult<T> = {
  artifact: T;
  nodes: GraphTraceNode[];
  tool_calls: Array<{
    tool_name: string;
    tool_version: string;
    input: JsonObject;
    output: JsonObject | null;
    status: "succeeded" | "failed" | "skipped";
  }>;
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
  if (JSON.stringify(packet).includes("workoutLedger")) {
    throw new Error("Planning packet must not include raw HealthKit workout ledgers.");
  }
}

export function normalizeModality(value: string) {
  const normalized = value.trim().toLowerCase();
  if (normalized.includes("cycl")) return "cycling";
  if (normalized.includes("run")) return "running";
  if (normalized.includes("strength") || normalized.includes("gym") || normalized.includes("lift")) return "strength";
  if (normalized.includes("walk")) return "walking";
  return normalized.replace(/\s+/g, "_") || "general";
}
