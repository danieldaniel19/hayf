import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  defaultAIModel,
  planningAITouchpoint,
  type AITouchpointConfig,
} from "../_shared/ai-touchpoints.ts";

type SupabaseAdminClient = any;

type PlanningTask =
  | "accept_strategy_and_create_initial_plan"
  | "prepare_initial_strategy_after_blueprint"
  | "accept_prepared_strategy_and_create_initial_plan"
  | "get_planning_graph_run_status"
  | "sync_healthkit_and_reconcile"
  | "refresh_plan_window"
  | "refresh_workout_weather_forecasts"
  | "generate_weekly_plan_targets"
  | "record_plan_edit"
  | "record_weekly_plan_constraint"
  | "recommend_workout_replacements"
  | "recommend_workout_additions"
  | "interpret_workout_description"
  | "replace_workout"
  | "add_workout"
  | "create_repair_proposal_for_recent_edit"
  | "create_repair_proposal_for_pending_edits"
  | "apply_replan_proposal"
  | "check_in_to_workout"
  | "scheduled_refresh_due_windows";

type PlanningAIRequest = {
  task: PlanningTask;
  healthSnapshot?: Record<string, unknown> | null;
  acceptedBlueprint?: Record<string, unknown> | null;
  accepted_blueprint?: Record<string, unknown> | null;
  acceptedStrategy?: Record<string, unknown> | null;
  accepted_strategy?: Record<string, unknown> | null;
  onboardingContext?: Record<string, unknown> | null;
  onboarding_context?: Record<string, unknown> | null;
  preparedStrategyID?: string;
  prepared_strategy_id?: string;
  graphRunID?: string;
  graph_run_id?: string;
  includeTrace?: boolean;
  include_trace?: boolean;
  acceptedAt?: string;
  accepted_at?: string;
  weeklyPlanConstraint?: WeeklyPlanConstraintInput | null;
  weekly_plan_constraint?: WeeklyPlanConstraintInput | null;
  actualWorkouts?: ActualWorkoutInput[];
  syncWindow?: { startDate?: string; endDate?: string };
  deviceTimezone?: string;
  startDate?: string;
  windowStart?: string;
  edit?: PlanEditInput;
  proposalID?: string;
  proposal_id?: string;
  eventID?: string;
  event_id?: string;
  decision?: "accepted" | "rejected";
  plannedWorkoutID?: string;
  planned_workout_id?: string;
  scheduledDate?: string;
  scheduled_date?: string;
  sequenceOrder?: number;
  sequence_order?: number;
  replacementCandidate?: ReplacementCandidateInput;
  replacement_candidate?: ReplacementCandidateInput;
  workoutCandidate?: WorkoutCandidateInput;
  workout_candidate?: WorkoutCandidateInput;
  mood?: { energy?: number; mood?: number };
  textContext?: string;
  currentDerivedSnapshot?: Record<string, unknown> | null;
  current_derived_snapshot?: Record<string, unknown> | null;
  repairPolicy?: "immediate" | "deferred";
  repair_policy?: "immediate" | "deferred";
};

type WeeklyPlanConstraintInput = {
  weekly_plan_id?: string;
  weeklyPlanID?: string;
  scheduled_date?: string;
  scheduledDate?: string;
  kind?: "available" | "limited" | "unavailable";
  note?: string | null;
};

type ActualWorkoutInput = {
  healthkit_uuid: string;
  start_date: string;
  activity_type: string;
  duration_minutes: number;
  distance_kilometers?: number | null;
  energy_kilocalories?: number | null;
  load_value?: number | null;
  average_heart_rate_bpm?: number | null;
  max_heart_rate_bpm?: number | null;
  heart_rate_samples?: Array<{ offset_seconds?: number; bpm?: number }> | null;
};

type WorkoutMatchDisparity = {
  needsReview: boolean;
  reasons: string[];
  duration?: {
    plannedMinutes: number;
    actualMinutes: number;
    ratio: number;
    significant: boolean;
  };
  intensity?: {
    planned: "low" | "moderate" | "high";
    actual: "low" | "moderate" | "high";
    significant: boolean;
  };
};

type PlanEditInput =
  | {
      type: "move_workout";
      planned_workout_id: string;
      scheduled_date: string;
      sequence_order?: number;
    }
  | {
      type: "delete_workout";
      planned_workout_id: string;
    }
  | {
      type: "replace_workout";
      planned_workout_id: string;
      replacement_workout_id: string;
      scheduled_date: string;
    }
  | {
      type: "add_workout";
      added_workout_id: string;
      scheduled_date: string;
    };

type GeneratedPlan = {
  block: {
    kind: "specific_goal" | "goal_discovery_chosen" | "consistency" | "re_entry" | "maintenance";
    title: string;
    goalText: string;
    startDate: string;
    targetDate: string | null;
    reviewCadenceDays: number;
    context: Record<string, unknown>;
  };
  phases: GeneratedPhase[];
  rhythms: GeneratedRhythm[];
};

type GeneratedPhase = {
  name: string;
  startDate: string | null;
  endDate: string | null;
  objective: string;
  focus: string[];
  risk: string[];
};

type GeneratedRhythm = {
  weekStartDate: string;
  weekEndDate: string;
  objective: string;
  priorityOrder: string[];
  hardEasyDistribution: Record<string, unknown>;
  badDayFloor: string;
  swapRules: string[];
  workouts: GeneratedWorkout[];
};

type GeneratedWorkout = {
  scheduledDate: string;
  sequenceOrder: number;
  activityType: string;
  title: string;
  durationMinutes: number;
  intensityLabel: string;
  purpose: string;
  prescription: Record<string, unknown>;
  fuelingSummary: string;
};

type WeeklyTargetFamily =
  | "planned_session_completion"
  | "modality_session_count"
  | "modality_minutes"
  | "modality_distance"
  | "active_days"
  | "support_modality_presence"
  | "max_gap_guardrail"
  | "minimum_viable_week"
  | "body_weight_logging"
  | "running_pace"
  | "cycling_pace";

type WeeklyTargetProposal = {
  slotID: string;
  family: WeeklyTargetFamily;
  modality: string | null;
  title: string;
  summary: string;
  proposedDisplayValue: string | null;
  targetValue: number | null;
  unit: string | null;
  comparator: "at_least" | "at_most" | "between";
  rationale: string;
};

type WeeklyTargetConstraint = {
  id: string;
  weeklyPlanID: string;
  weekStartDate: string;
  weekEndDate: string;
  title: string;
  family: WeeklyTargetFamily;
  modality: string | null;
  targetValue: number;
  unit: string | null;
};

type WeeklyTargetGenerationOutput = {
  weeks: Array<{
    weeklyPlanID: string;
    targets: WeeklyTargetProposal[];
  }>;
};

type GraphNodeTraceInput = {
  nodeName: string;
  subgraphName?: string | null;
  inputSummary?: Record<string, unknown>;
  output?: Record<string, unknown>;
  validation?: Record<string, unknown>;
  status?: "succeeded" | "failed" | "skipped";
  retryCount?: number;
  errorMessage?: string | null;
};

type GraphToolCallInput = {
  toolName: string;
  toolVersion?: string;
  input?: Record<string, unknown>;
  output?: Record<string, unknown> | null;
  status?: "succeeded" | "failed" | "skipped";
  errorMessage?: string | null;
  latencyMS?: number | null;
};

type InitialStrategyOrchestrationOutput = {
  trainingArchitecture: Record<string, any>;
  fitnessStrategy: Record<string, any>;
  validation: Record<string, unknown>;
  nodes: GraphNodeTraceInput[];
  toolCalls: GraphToolCallInput[];
  model: Record<string, unknown>;
};

type TwoWeekPlanOrchestrationOutput = {
  plan: GeneratedPlan;
  validation: Record<string, unknown>;
  nodes: GraphNodeTraceInput[];
  toolCalls: GraphToolCallInput[];
  model: Record<string, unknown>;
};

type WorkoutCandidateInput = {
  title: string;
  activityType: string;
  durationMinutes: number;
  estimatedDistanceKilometers?: number | null;
  estimatedElevationMeters?: number | null;
  plannedLocationLabel?: string | null;
  intensityLabel: string;
  purpose: string;
  prescription: Record<string, unknown>;
  fuelingSummary: string;
  rationale?: string;
  weeklyImpact?: string;
};

type ReplacementCandidateInput = WorkoutCandidateInput;

type WorkoutCandidate = WorkoutCandidateInput & {
  id: string;
  rationale: string;
  weeklyImpact: string;
};

type ReplacementCandidate = WorkoutCandidate;

type TrainingDimension = "neuromuscular" | "endurance" | "recovery" | "skill";
type TrainingLoad = "low" | "moderate" | "high";
type TrainingImpact = "low" | "medium" | "high";

type TrainingProfile = {
  normalizedActivity: string;
  dimensions: TrainingDimension[];
  load: TrainingLoad;
  impact: TrainingImpact;
};

type PlanningScope = {
  goal: Record<string, any>;
  strategy: Record<string, any>;
  timezone: string;
  homeLocationLabel: string | null;
  weatherSensitive: boolean;
  block: Record<string, any>;
};

type OpenMeteoLocation = {
  name: string;
  country?: string;
  admin1?: string;
  latitude: number;
  longitude: number;
};

type OpenMeteoDailyForecast = {
  source: "open-meteo";
  fetchedAt: string;
  forecastDate: string;
  locationLabel: string;
  latitude: number;
  longitude: number;
  temperatureCelsius: number;
  temperatureUnit: "C";
  conditionCode: number;
  conditionLabel: string;
  conditionEmoji: string;
  precipitationProbability: number | null;
  precipitationMm: number | null;
  windKph: number | null;
  outdoorRisk: "ok" | "watch" | "miserable";
};

type EditRiskKind = "compressed_recovery" | "cumulative_load" | "goal_drift" | "weekly_imbalance";

type EditRisk = {
  kind: EditRiskKind;
  severity: "medium" | "high";
  message: string;
  affectedWorkoutIDs: string[];
  dimensions: TrainingDimension[];
  weekStartDate?: string;
  expectedCount?: number;
  actualCount?: number;
  missingCount?: number;
};

type EditRepairPlan = {
  reason: string;
  summary: string;
  risks: EditRisk[];
  mutations: Array<Record<string, unknown>>;
};

type PlanEditRepairDraft = {
  reason: string;
  summary: string;
};

type PendingPlanReviewDraft = {
  reviewNeeded: boolean;
  reason: string | null;
  summary: string | null;
  confidence: "low" | "medium" | "high";
  notes: string | null;
  mutations: Array<Record<string, unknown>>;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const planSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["block", "phases", "rhythms"],
  properties: {
    block: {
      type: "object",
      additionalProperties: false,
      required: ["kind", "title", "goalText", "startDate", "targetDate", "reviewCadenceDays", "context"],
      properties: {
        kind: { type: "string", enum: ["specific_goal", "goal_discovery_chosen", "consistency", "re_entry", "maintenance"] },
        title: { type: "string" },
        goalText: { type: "string" },
        startDate: { type: "string" },
        targetDate: { type: ["string", "null"] },
        reviewCadenceDays: { type: "integer" },
        context: {
          type: "object",
          additionalProperties: false,
          required: ["onboardingIntent", "planningRationale", "dataFreshness"],
          properties: {
            onboardingIntent: { type: "string" },
            planningRationale: { type: "string" },
            dataFreshness: { type: "string" },
          },
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
      items: {
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
              hard: { type: "integer" },
              moderate: { type: "integer" },
              easy: { type: "integer" },
            },
          },
          badDayFloor: { type: "string" },
          swapRules: { type: "array", items: { type: "string" } },
          workouts: {
            type: "array",
            items: {
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
                sequenceOrder: { type: "integer" },
                activityType: { type: "string" },
                title: { type: "string" },
                durationMinutes: { type: "integer" },
                intensityLabel: { type: "string" },
                purpose: { type: "string" },
                prescription: {
                  type: "object",
                  additionalProperties: false,
                  required: ["warmup", "main", "cooldown", "successCriteria"],
                  properties: {
                    warmup: { type: "string" },
                    main: { type: "array", items: { type: "string" } },
                    cooldown: { type: "string" },
                    successCriteria: { type: "string" },
                  },
                },
                fuelingSummary: { type: "string" },
              },
            },
          },
        },
      },
    },
  },
};

const weeklyTargetSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["weeks"],
  properties: {
    weeks: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["weeklyPlanID", "targets"],
        properties: {
          weeklyPlanID: { type: "string" },
          targets: {
            type: "array",
            minItems: 1,
            maxItems: 3,
            items: {
              type: "object",
              additionalProperties: false,
              required: [
                "slotID",
                "family",
                "modality",
                "title",
                "summary",
                "proposedDisplayValue",
                "targetValue",
                "unit",
                "comparator",
                "rationale",
              ],
              properties: {
                slotID: { type: "string" },
                family: {
                  type: "string",
                  enum: [
                    "planned_session_completion",
                    "modality_session_count",
                    "modality_minutes",
                    "modality_distance",
                    "active_days",
                    "support_modality_presence",
                    "max_gap_guardrail",
                    "minimum_viable_week",
                    "body_weight_logging",
                    "running_pace",
                    "cycling_pace",
                  ],
                },
                modality: { type: ["string", "null"] },
                title: { type: "string", maxLength: 48 },
                summary: { type: "string", maxLength: 140 },
                proposedDisplayValue: { type: ["string", "null"], maxLength: 18 },
                targetValue: { type: ["number", "null"] },
                unit: { type: ["string", "null"], maxLength: 18 },
                comparator: { type: "string", enum: ["at_least", "at_most", "between"] },
                rationale: { type: "string", maxLength: 220 },
              },
            },
          },
        },
      },
    },
  },
};

const editRepairSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["reason", "summary"],
  properties: {
    reason: { type: "string" },
    summary: { type: "string" },
  },
};

const pendingPlanReviewSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["reviewNeeded", "reason", "summary", "confidence", "notes", "mutations"],
  properties: {
    reviewNeeded: { type: "boolean" },
    reason: { type: ["string", "null"] },
    summary: { type: ["string", "null"] },
    confidence: { type: "string", enum: ["low", "medium", "high"] },
    notes: { type: ["string", "null"] },
    mutations: {
      type: "array",
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["type", "workout_id", "fields"],
        properties: {
          type: { type: "string", enum: ["create_workout", "update_workout", "delete_workout"] },
          workout_id: { type: ["string", "null"] },
          fields: {
            type: ["object", "null"],
            additionalProperties: false,
            required: [
              "scheduled_date",
              "sequence_order",
              "activity_type",
              "title",
              "duration_minutes",
              "intensity_label",
              "purpose",
              "prescription_json",
              "fueling_summary",
            ],
            properties: {
              scheduled_date: { type: ["string", "null"] },
              sequence_order: { type: ["integer", "null"] },
              activity_type: { type: ["string", "null"] },
              title: { type: ["string", "null"] },
              duration_minutes: { type: ["integer", "null"] },
              intensity_label: { type: ["string", "null"] },
              purpose: { type: ["string", "null"] },
              prescription_json: {
                type: ["object", "null"],
                additionalProperties: false,
                required: ["warmup", "main", "cooldown", "successCriteria"],
                properties: {
                  warmup: { type: ["string", "null"] },
                  main: { type: ["string", "null"] },
                  cooldown: { type: ["string", "null"] },
                  successCriteria: { type: ["string", "null"] },
                },
              },
              fueling_summary: { type: ["string", "null"] },
            },
          },
        },
      },
    },
  },
};

const replacementSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["candidates"],
  properties: {
    candidates: {
      type: "array",
      minItems: 2,
      maxItems: 3,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "title",
          "activityType",
          "durationMinutes",
          "estimatedDistanceKilometers",
          "estimatedElevationMeters",
          "plannedLocationLabel",
          "intensityLabel",
          "purpose",
          "prescription",
          "fuelingSummary",
          "rationale",
          "weeklyImpact",
        ],
        properties: {
          title: { type: "string" },
          activityType: { type: "string" },
          durationMinutes: { type: "integer" },
          estimatedDistanceKilometers: { type: ["number", "null"] },
          estimatedElevationMeters: { type: ["number", "null"] },
          plannedLocationLabel: { type: ["string", "null"] },
          intensityLabel: { type: "string" },
          purpose: { type: "string" },
          prescription: {
            type: "object",
            additionalProperties: false,
            required: ["warmup", "main", "cooldown", "successCriteria"],
            properties: {
              warmup: { type: "string" },
              main: { type: "string" },
              cooldown: { type: "string" },
              successCriteria: { type: "string" },
            },
          },
          fuelingSummary: { type: "string" },
          rationale: { type: "string", maxLength: 96 },
          weeklyImpact: { type: "string", maxLength: 96 },
        },
      },
    },
  },
};

const workoutCandidateSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["candidate"],
  properties: {
    candidate: {
      type: "object",
      additionalProperties: false,
      required: [
        "title",
        "activityType",
        "durationMinutes",
        "estimatedDistanceKilometers",
        "estimatedElevationMeters",
        "plannedLocationLabel",
        "intensityLabel",
        "purpose",
        "prescription",
        "fuelingSummary",
        "rationale",
        "weeklyImpact",
      ],
      properties: {
        title: { type: "string" },
        activityType: { type: "string" },
        durationMinutes: { type: "integer" },
        estimatedDistanceKilometers: { type: ["number", "null"] },
        estimatedElevationMeters: { type: ["number", "null"] },
        plannedLocationLabel: { type: ["string", "null"] },
        intensityLabel: { type: "string" },
        purpose: { type: "string" },
        prescription: {
          type: "object",
          additionalProperties: false,
          required: ["warmup", "main", "cooldown", "successCriteria"],
          properties: {
            warmup: { type: "string" },
            main: { type: "string" },
            cooldown: { type: "string" },
            successCriteria: { type: "string" },
          },
        },
        fuelingSummary: { type: "string" },
        rationale: { type: "string", maxLength: 96 },
        weeklyImpact: { type: "string", maxLength: 96 },
      },
    },
  },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startedAt = Date.now();
  const supabaseUrl = mustGetEnv("SUPABASE_URL");
  const serviceRoleKey = mustGetEnv("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = mustGetEnv("SUPABASE_ANON_KEY");
  const admin: SupabaseAdminClient = createClient(supabaseUrl, serviceRoleKey);
  const model = defaultAIModel();

  let requestBody: PlanningAIRequest | null = null;
  let userID: string | null = null;

  try {
    requestBody = await req.json();
    validateRequest(requestBody);

    const authHeader = req.headers.get("Authorization") ?? "";
    const isServiceRole = authHeader === `Bearer ${serviceRoleKey}`;

    if (requestBody.task === "scheduled_refresh_due_windows") {
      if (!isServiceRole) {
        return jsonResponse({ error: "Scheduled refresh requires service role authorization" }, 401);
      }
    } else {
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data, error } = await userClient.auth.getUser();
      if (error || !data.user) {
        return jsonResponse({ error: "Unauthorized" }, 401);
      }
      userID = data.user.id;
    }

    const output: any = await handleTask({
      admin,
      requestBody,
      userID,
      model,
      startedAt,
    });
    if (!output) {
      throw new Error(`Planning task returned no output: ${requestBody.task}`);
    }

    await insertTrace(admin, {
      userID: userID ?? output.userID ?? null,
      task: requestBody.task,
      model: output.model ?? "deterministic",
      compactRequest: compactTraceRequest(requestBody),
      structuredResponse: output,
      status: "success",
      latencyMS: Date.now() - startedAt,
    });

    return jsonResponse({ task: requestBody.task, model: output.model ?? "deterministic", output });
  } catch (error) {
    if (requestBody?.task) {
      await insertTrace(admin, {
        userID,
        task: requestBody.task,
        model,
        compactRequest: compactTraceRequest(requestBody),
        structuredResponse: null,
        status: "failure",
        latencyMS: Date.now() - startedAt,
        errorMessage: errorMessage(error),
      });
    }

    return jsonResponse({ error: errorMessage(error) }, 400);
  }
});

async function handleTask(args: {
  admin: SupabaseAdminClient;
  requestBody: PlanningAIRequest;
  userID: string | null;
  model: string;
  startedAt: number;
}) {
  const { admin, requestBody, userID } = args;
  const touchpointModel = (id: string) => planningAITouchpoint(id).model;

  switch (requestBody.task) {
    case "accept_strategy_and_create_initial_plan":
      throw new Error(
        "accept_strategy_and_create_initial_plan is deprecated. Use prepare_initial_strategy_after_blueprint, then accept_prepared_strategy_and_create_initial_plan.",
      );
    case "prepare_initial_strategy_after_blueprint":
      return prepareInitialStrategyAfterBlueprint(admin, userID!, requestBody);
    case "accept_prepared_strategy_and_create_initial_plan":
      return acceptPreparedStrategyAndCreateInitialPlan(admin, userID!, requestBody, touchpointModel("plan_generation"));
    case "get_planning_graph_run_status":
      return getPlanningGraphRunStatus(admin, userID!, requestBody);
    case "sync_healthkit_and_reconcile":
      return syncHealthKitAndReconcile(admin, userID!, requestBody, touchpointModel("plan_generation"));
    case "refresh_plan_window":
      return refreshPlanWindow(admin, userID!, requestBody, touchpointModel("plan_generation"), "user");
    case "refresh_workout_weather_forecasts":
      return refreshWorkoutWeatherForecasts(admin, userID!, requestBody);
    case "generate_weekly_plan_targets":
      return generateWeeklyPlanTargetsForVisiblePlan(admin, userID!, requestBody, touchpointModel("weekly_targets"));
    case "record_plan_edit":
      return recordPlanEdit(admin, userID!, requestBody, touchpointModel("plan_edit_repair"));
    case "record_weekly_plan_constraint":
      return recordWeeklyPlanConstraint(admin, userID!, requestBody);
    case "recommend_workout_replacements":
      return recommendWorkoutReplacements(admin, userID!, requestBody, touchpointModel("workout_replacements"));
    case "recommend_workout_additions":
      return recommendWorkoutAdditions(admin, userID!, requestBody, touchpointModel("workout_additions"));
    case "interpret_workout_description":
      return interpretWorkoutDescription(admin, userID!, requestBody, touchpointModel("workout_interpretation"));
    case "replace_workout":
      return replaceWorkout(admin, userID!, requestBody, touchpointModel("plan_edit_repair"));
    case "add_workout":
      return addWorkout(admin, userID!, requestBody, touchpointModel("plan_edit_repair"));
    case "create_repair_proposal_for_recent_edit":
      return createRepairProposalForRecentEdit(admin, userID!, requestBody, touchpointModel("plan_edit_repair"));
    case "create_repair_proposal_for_pending_edits":
      return createRepairProposalForPendingEdits(admin, userID!, requestBody, touchpointModel("pending_plan_review"));
    case "apply_replan_proposal":
      return applyReplanProposal(admin, userID!, requestBody);
    case "check_in_to_workout":
      return checkInToWorkout(admin, userID!, requestBody);
    case "scheduled_refresh_due_windows":
      return scheduledRefreshDueWindows(admin, touchpointModel("plan_generation"));
    default:
      throw new Error(`Unsupported planning AI task: ${requestBody.task}`);
  }
}

async function acceptStrategyAndCreateInitialPlan(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const profile = await maybeSingle(admin.from("profiles").select().eq("id", userID));
  const onboarding = await loadPlanningOnboardingContext(admin, userID, requestBody);

  const timezone = requestBody.deviceTimezone || "UTC";
  const acceptedAt = parseTimestamp(requestBody.acceptedAt ?? requestBody.accepted_at) ?? new Date();
  const acceptedLocalDate = dateOnlyInTimezone(acceptedAt, timezone);
  const committedWeekStart = firstCommittedWeekStart(acceptedAt, timezone);
  const draftWeekStart = addDays(committedWeekStart, 7);
  const ownerStartDate = isoDate(committedWeekStart > acceptedLocalDate ? committedWeekStart : acceptedLocalDate);
  const acceptedBlueprint = requestBody.acceptedBlueprint ?? requestBody.accepted_blueprint ?? {};
  const acceptedStrategy = requestBody.acceptedStrategy ?? requestBody.accepted_strategy ?? {};
  const goalKind = blockKind(String(onboarding.intent ?? ""));
  const timeframeWeeks = acceptedStrategyTimeframeWeeks(acceptedStrategy, onboarding);
  const requiresPhases = acceptedStrategyPhases(acceptedStrategy).length > 0 && goalKind !== "consistency";
  const targetDate = goalKind === "consistency" || !timeframeWeeks
    ? null
    : isoDate(addDays(committedWeekStart, Math.max(1, timeframeWeeks) * 7 - 1));

  await supersedeActivePlanningRows(admin, userID);
  const athleteProfile = await ensureAthleteProfile(admin, userID);
  const blueprintRevision = await createAcceptedBlueprintRevision(admin, userID, athleteProfile, acceptedBlueprint, requestBody.healthSnapshot, acceptedAt);

  const goal = await single(
    admin
      .from("user_goals")
      .insert({
        user_id: userID,
        source_onboarding_profile_id: onboarding.id ?? null,
        source_blueprint_revision_id: blueprintRevision.id,
        goal_kind: goalKind,
        title: acceptedStrategyGoalTitle(acceptedStrategy, onboarding),
        normalized_goal_json: normalizedGoalPayload(acceptedStrategy, onboarding, timeframeWeeks),
        timeframe_weeks: timeframeWeeks,
        status: "active",
        start_date: isoDate(committedWeekStart),
        target_date: targetDate,
        requires_phases: requiresPhases,
      })
      .select()
      .single(),
    "Could not create user goal",
  );

  const strategy = await single(
    admin
      .from("fitness_strategies")
      .insert({
        user_id: userID,
        user_goal_id: goal.id,
        source_blueprint_revision_id: blueprintRevision.id,
        version: 1,
        change_reason: "initial",
        status: "active",
        title: acceptedStrategyTitle(acceptedStrategy, goalKind),
        summary: stringAt(acceptedStrategy, "read") || "",
        rationale: stringAt(acceptedStrategy, "read") || "",
        review_cadence_days: goalKind === "consistency" ? 28 : Math.max(28, (timeframeWeeks ?? 8) * 7),
        start_date: isoDate(committedWeekStart),
        target_date: targetDate,
        requires_phases: requiresPhases,
        context_json: {
          timezone,
          acceptedAt: acceptedAt.toISOString(),
          planOwnerStartDate: ownerStartDate,
          acceptedStrategy,
        },
      })
      .select()
      .single(),
    "Could not create fitness strategy",
  );

  const phaseRows = await insertAcceptedStrategyPhases(admin, userID, strategy.id, acceptedStrategy);
  await insertAcceptedPlanningTargets(admin, userID, goal, strategy, phaseRows, acceptedStrategy, isoDate(committedWeekStart), targetDate);

  const context = {
    profile,
    onboarding,
    acceptedBlueprint,
    acceptedStrategy,
    planGenerationPolicy: planGenerationPolicy(onboarding, null),
    healthSnapshot: requestBody.healthSnapshot ?? null,
    deviceTimezone: timezone,
    startDate: isoDate(committedWeekStart),
    planOwnerStartDate: ownerStartDate,
    weeklyPlanStatuses: [
      { weekStartDate: isoDate(committedWeekStart), status: "committed" },
      { weekStartDate: isoDate(draftWeekStart), status: "draft" },
    ],
  };

  const aiGenerated = await runPlanGeneration("accept_strategy_and_create_initial_plan", context, model);
  const initialActuals = actualWorkoutsForInitialWeek(
    requestBody.actualWorkouts ?? [],
    isoDate(committedWeekStart),
    isoDate(addDays(committedWeekStart, 6)),
    acceptedLocalDate,
    timezone,
  );
  const generated = sanitizeGeneratedPlan(
    applyInitialWeekActualWorkoutContext(
      aiGenerated,
      initialActuals,
      ownerStartDate,
    ),
    onboarding,
    committedWeekStart,
    timezone,
  );

  const weeklyPlans = await insertWeeklyPlansAndWorkouts(admin, {
    userID,
    strategyID: strategy.id,
    rhythms: generated.rhythms,
    source: "generated",
    committedWeekStart: isoDate(committedWeekStart),
    ownerStartDate,
    homeLocationLabel: profile?.main_city ?? null,
  });
  const planningScope: PlanningScope = {
    goal,
    strategy,
    timezone,
    homeLocationLabel: profile?.main_city ?? null,
    weatherSensitive: onboardingHasWeatherBlocker(onboarding),
    block: {
      id: strategy.id,
      kind: goal.goal_kind,
      title: strategy.title,
      goal_text: goal.title,
      start_date: strategy.start_date,
      target_date: strategy.target_date,
      review_cadence_days: strategy.review_cadence_days,
      timezone,
      context_json: strategy.context_json ?? {},
    },
  };
  const initialActualSync = await reconcileActualWorkouts(admin, userID, planningScope, requestBody.actualWorkouts ?? [], {
    createDetectedProposal: false,
    createDisparityProposal: false,
  });
  await generateAndPersistWeeklyTargets(admin, {
    userID,
    goal,
    strategy,
    weeklyPlans,
    healthSnapshot: requestBody.healthSnapshot ?? null,
    acceptedStrategy,
    model,
  });
  await markCurrentWorkoutForStrategy(admin, userID, strategy.id, acceptedLocalDate);

  if (requestBody.healthSnapshot) {
    await persistFitnessEvidence(admin, userID, null, requestBody.healthSnapshot);
    await evaluatePlanningTargets(admin, userID, strategy.id, requestBody.healthSnapshot);
  }

  const event = await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: strategy.id,
    userGoalID: goal.id,
    eventType: "strategy_accepted",
    payload: {
      usedAIInitialPlan: true,
      usedFallback: false,
      goalKind,
      committedWeekStart: isoDate(committedWeekStart),
      draftWeekStart: isoDate(draftWeekStart),
      planOwnerStartDate: ownerStartDate,
      actualSync: initialActualSync,
    },
  });

  return {
    userID,
    model,
    usedFallback: false,
    userGoalID: goal.id,
    fitnessStrategyID: strategy.id,
    blueprintRevisionID: blueprintRevision.id,
    weeklyPlanIDs: weeklyPlans.map((plan) => plan.id),
    eventID: event.id,
    plan: generated,
  };
}

async function prepareInitialStrategyAfterBlueprint(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  const onboarding = await loadPlanningOnboardingContext(admin, userID, requestBody);

  const timezone = requestBody.deviceTimezone || "UTC";
  const acceptedAt = parseTimestamp(requestBody.acceptedAt ?? requestBody.accepted_at) ?? new Date();
  const committedWeekStart = firstCommittedWeekStart(acceptedAt, timezone);
  const acceptedBlueprint = requestBody.acceptedBlueprint ?? requestBody.accepted_blueprint ?? {};
  const goalKind = blockKind(String(onboarding.intent ?? ""));
  const timeframeWeeks = acceptedStrategyTimeframeWeeks({}, onboarding);
  const requiresPhases = goalKind !== "consistency";
  const targetDate = goalKind === "consistency" || !timeframeWeeks
    ? null
    : isoDate(addDays(committedWeekStart, Math.max(1, timeframeWeeks) * 7 - 1));

  const athleteProfile = await ensureAthleteProfile(admin, userID);
  const blueprintRevision = await createAcceptedBlueprintRevision(
    admin,
    userID,
    athleteProfile,
    acceptedBlueprint,
    requestBody.healthSnapshot,
    acceptedAt,
  );

  const goal = await single(
    admin
      .from("user_goals")
      .insert({
        user_id: userID,
        source_onboarding_profile_id: onboarding.id ?? null,
        source_blueprint_revision_id: blueprintRevision.id,
        goal_kind: goalKind,
        title: preparedGoalTitle(onboarding),
        normalized_goal_json: normalizedGoalPayload({}, onboarding, timeframeWeeks),
        timeframe_weeks: timeframeWeeks,
        status: "prepared",
        start_date: isoDate(committedWeekStart),
        target_date: targetDate,
        requires_phases: requiresPhases,
      })
      .select()
      .single(),
    "Could not prepare user goal",
  );

  const planningPacket = buildCompactPlanningPacket({
    blueprintRevision,
    acceptedBlueprint,
    onboarding,
    goal,
    healthSnapshot: requestBody.healthSnapshot ?? null,
    timezone,
    startDate: isoDate(committedWeekStart),
  });

  const graphRun = await createAIGraphRun(admin, {
    userID,
    graphName: "training_architecture",
    triggeringTask: "prepare_initial_strategy_after_blueprint",
    blueprintRevisionID: blueprintRevision.id,
    userGoalID: goal.id,
    input: planningPacket,
  });

  let orchestration: InitialStrategyOrchestrationOutput;
  try {
    orchestration = await runInitialStrategyOrchestration(planningPacket);
    await completeAIGraphRun(admin, graphRun.id, {
      status: "succeeded",
      output: {
        trainingArchitecture: orchestration.trainingArchitecture,
        fitnessStrategy: orchestration.fitnessStrategy,
      },
      model: orchestration.model,
    });
  } catch (error) {
    await completeAIGraphRun(admin, graphRun.id, {
      status: "failed",
      errorSummary: errorMessage(error),
    });
    throw error;
  }

  await insertAIGraphNodeOutputs(admin, graphRun.id, userID, orchestration.nodes);
  await insertAIToolCalls(admin, graphRun.id, userID, orchestration.toolCalls);

  const trainingArchitecture = await single(
    admin
      .from("training_architectures")
      .insert({
        user_id: userID,
        user_goal_id: goal.id,
        source_blueprint_revision_id: blueprintRevision.id,
        ai_graph_run_id: graphRun.id,
        version: 1,
        status: "prepared",
        input_packet_json: planningPacket,
        architecture_json: orchestration.trainingArchitecture,
        conflict_assessment_json: objectAt(orchestration.trainingArchitecture, "conflict_assessment") ?? {},
        validation_json: orchestration.validation,
      })
      .select()
      .single(),
    "Could not persist Training Architecture",
  );

  await throwOnError(
    admin
      .from("ai_graph_runs")
      .update({ source_training_architecture_id: trainingArchitecture.id })
      .eq("id", graphRun.id),
  );

  const acceptedStrategy = orchestration.fitnessStrategy;
  const strategy = await single(
    admin
      .from("fitness_strategies")
      .insert({
        user_id: userID,
        user_goal_id: goal.id,
        source_blueprint_revision_id: blueprintRevision.id,
        training_architecture_id: trainingArchitecture.id,
        version: 1,
        change_reason: "initial",
        status: "prepared",
        title: acceptedStrategyTitle(acceptedStrategy, goalKind),
        summary: stringAt(acceptedStrategy, "read") || "",
        rationale: stringAt(acceptedStrategy, "read") || "",
        review_cadence_days: goalKind === "consistency" ? 28 : Math.max(28, (timeframeWeeks ?? 8) * 7),
        start_date: isoDate(committedWeekStart),
        target_date: targetDate,
        requires_phases: requiresPhases,
        context_json: {
          timezone,
          acceptedAt: acceptedAt.toISOString(),
          planOwnerStartDate: isoDate(committedWeekStart),
          acceptedStrategy,
          trainingArchitectureID: trainingArchitecture.id,
          graphRunID: graphRun.id,
        },
      })
      .select()
      .single(),
    "Could not prepare fitness strategy",
  );

  await throwOnError(
    admin
      .from("ai_graph_runs")
      .update({ source_fitness_strategy_id: strategy.id })
      .eq("id", graphRun.id),
  );

  const phaseRows = await insertAcceptedStrategyPhases(admin, userID, strategy.id, acceptedStrategy);
  await insertAcceptedPlanningTargets(
    admin,
    userID,
    goal,
    strategy,
    phaseRows,
    acceptedStrategy,
    isoDate(committedWeekStart),
    targetDate,
  );

  if (requestBody.healthSnapshot) {
    await persistFitnessEvidence(admin, userID, null, requestBody.healthSnapshot, {
      userGoalID: goal.id,
      fitnessStrategyID: strategy.id,
    });
  }

  await createPlanEvent(admin, {
    userID,
    userGoalID: goal.id,
    fitnessStrategyID: strategy.id,
    eventType: "training_architecture_prepared",
    payload: {
      graphRunID: graphRun.id,
      trainingArchitectureID: trainingArchitecture.id,
      conflictAssessment: trainingArchitecture.conflict_assessment_json ?? null,
    },
  });
  const event = await createPlanEvent(admin, {
    userID,
    userGoalID: goal.id,
    fitnessStrategyID: strategy.id,
    eventType: "strategy_prepared",
    payload: {
      graphRunID: graphRun.id,
      trainingArchitectureID: trainingArchitecture.id,
      fitnessStrategyID: strategy.id,
    },
  });

  return {
    userID,
    model: orchestration.model?.provider ?? "training-orchestrator",
    status: "completed",
    graphRunID: graphRun.id,
    userGoalID: goal.id,
    fitnessStrategyID: strategy.id,
    blueprintRevisionID: blueprintRevision.id,
    trainingArchitectureID: trainingArchitecture.id,
    eventID: event.id,
    strategy: acceptedStrategy,
    trainingArchitecture: orchestration.trainingArchitecture,
  };
}

async function acceptPreparedStrategyAndCreateInitialPlan(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const preparedStrategyID = requestBody.preparedStrategyID ?? requestBody.prepared_strategy_id;
  if (!preparedStrategyID) {
    throw new Error("accept_prepared_strategy_and_create_initial_plan requires preparedStrategyID");
  }

  const strategy = await single(
    admin
      .from("fitness_strategies")
      .select()
      .eq("id", preparedStrategyID)
      .eq("user_id", userID)
      .single(),
    "Prepared fitness strategy not found",
  );
  if (!["prepared", "active"].includes(String(strategy.status))) {
    throw new Error("Fitness strategy is not prepared for acceptance.");
  }

  const goal = await single(
    admin
      .from("user_goals")
      .select()
      .eq("id", strategy.user_goal_id)
      .eq("user_id", userID)
      .single(),
    "Prepared user goal not found",
  );
  const profile = await maybeSingle(admin.from("profiles").select().eq("id", userID));
  const onboarding = await maybeSingle(admin.from("onboarding_profiles").select().eq("id", userID).limit(1));
  const trainingArchitecture = strategy.training_architecture_id
    ? await maybeSingle(
      admin
        .from("training_architectures")
        .select()
        .eq("id", strategy.training_architecture_id)
        .eq("user_id", userID)
        .limit(1),
    )
    : null;

  const timezone = requestBody.deviceTimezone || strategy.context_json?.timezone || "UTC";
  const acceptedAt = parseTimestamp(requestBody.acceptedAt ?? requestBody.accepted_at) ?? new Date();
  const acceptedLocalDate = dateOnlyInTimezone(acceptedAt, timezone);
  const committedWeekStart = firstCommittedWeekStart(acceptedAt, timezone);
  const draftWeekStart = addDays(committedWeekStart, 7);
  const ownerStartDate = isoDate(committedWeekStart > acceptedLocalDate ? committedWeekStart : acceptedLocalDate);
  const acceptedStrategy = objectAt(strategy.context_json ?? {}, "acceptedStrategy") ?? {};

  await supersedeActivePlanningRows(admin, userID);
  await throwOnError(
    admin
      .from("user_goals")
      .update({
        status: "active",
        source_onboarding_profile_id: onboarding?.id ?? goal.source_onboarding_profile_id ?? null,
      })
      .eq("id", goal.id)
      .eq("user_id", userID),
  );
  await throwOnError(
    admin
      .from("fitness_strategies")
      .update({
        status: "active",
        context_json: {
          ...(strategy.context_json ?? {}),
          acceptedAt: acceptedAt.toISOString(),
          planOwnerStartDate: ownerStartDate,
        },
      })
      .eq("id", strategy.id)
      .eq("user_id", userID),
  );
  if (trainingArchitecture?.id) {
    await throwOnError(
      admin
        .from("training_architectures")
        .update({ status: "active" })
        .eq("id", trainingArchitecture.id)
        .eq("user_id", userID),
    );
  }

  const context = {
    profile,
    goal,
    strategy,
    acceptedStrategy,
    trainingArchitecture: trainingArchitecture?.architecture_json ?? null,
    planGenerationPolicy: planGenerationPolicy(onboarding, trainingArchitecture?.architecture_json ?? null),
    healthSnapshot: requestBody.healthSnapshot ?? null,
    deviceTimezone: timezone,
    startDate: isoDate(committedWeekStart),
    planOwnerStartDate: ownerStartDate,
    weeklyPlanStatuses: [
      { weekStartDate: isoDate(committedWeekStart), status: "committed" },
      { weekStartDate: isoDate(draftWeekStart), status: "draft" },
    ],
  };

  const planGraphRun = await createAIGraphRun(admin, {
    userID,
    graphName: "two_week_plan",
    triggeringTask: "accept_prepared_strategy_and_create_initial_plan",
    blueprintRevisionID: trainingArchitecture?.source_blueprint_revision_id ?? goal.source_blueprint_revision_id ?? null,
    userGoalID: goal.id,
    fitnessStrategyID: strategy.id,
    trainingArchitectureID: trainingArchitecture?.id ?? null,
    input: {
      strategyID: strategy.id,
      trainingArchitectureID: trainingArchitecture?.id ?? null,
      committedWeekStart: isoDate(committedWeekStart),
      draftWeekStart: isoDate(draftWeekStart),
      planOwnerStartDate: ownerStartDate,
      timezone,
      context,
    },
  });

  let planOrchestration: TwoWeekPlanOrchestrationOutput;
  try {
    planOrchestration = await runTwoWeekPlanOrchestration(context, model);
    await completeAIGraphRun(admin, planGraphRun.id, {
      status: "succeeded",
      output: {
        plan: planOrchestration.plan,
        validation: planOrchestration.validation,
      },
      model: planOrchestration.model,
    });
    await insertAIGraphNodeOutputs(admin, planGraphRun.id, userID, planOrchestration.nodes);
    await insertAIToolCalls(admin, planGraphRun.id, userID, planOrchestration.toolCalls);
  } catch (error) {
    await completeAIGraphRun(admin, planGraphRun.id, {
      status: "failed",
      errorSummary: errorMessage(error),
      model: {
        provider: Deno.env.get("TRAINING_ORCHESTRATOR_URL")?.trim() ? "hayf-training-orchestrator" : "supabase-planning-ai",
        requestedModel: model,
      },
    });
    throw error;
  }
  const aiGenerated = planOrchestration.plan;
  const initialActuals = actualWorkoutsForInitialWeek(
    requestBody.actualWorkouts ?? [],
    isoDate(committedWeekStart),
    isoDate(addDays(committedWeekStart, 6)),
    acceptedLocalDate,
    timezone,
  );
  const generated = sanitizeGeneratedPlan(
    applyInitialWeekActualWorkoutContext(
      aiGenerated,
      initialActuals,
      ownerStartDate,
    ),
    onboarding,
    committedWeekStart,
    timezone,
  );

  const weeklyPlans = await insertWeeklyPlansAndWorkouts(admin, {
    userID,
    strategyID: strategy.id,
    trainingArchitectureID: trainingArchitecture?.id ?? null,
    rhythms: generated.rhythms,
    source: "generated",
    committedWeekStart: isoDate(committedWeekStart),
    ownerStartDate,
    homeLocationLabel: profile?.main_city ?? null,
  });

  const planningScope: PlanningScope = {
    goal,
    strategy: { ...strategy, status: "active" },
    timezone,
    homeLocationLabel: profile?.main_city ?? null,
    weatherSensitive: onboardingHasWeatherBlocker(onboarding),
    block: {
      id: strategy.id,
      kind: goal.goal_kind,
      title: strategy.title,
      goal_text: goal.title,
      start_date: strategy.start_date,
      target_date: strategy.target_date,
      review_cadence_days: strategy.review_cadence_days,
      timezone,
      context_json: strategy.context_json ?? {},
    },
  };
  const initialActualSync = await reconcileActualWorkouts(admin, userID, planningScope, requestBody.actualWorkouts ?? [], {
    createDetectedProposal: false,
    createDisparityProposal: false,
  });
  await generateAndPersistWeeklyTargets(admin, {
    userID,
    goal,
    strategy,
    weeklyPlans,
    healthSnapshot: requestBody.healthSnapshot ?? null,
    acceptedStrategy,
    model,
  });
  await markCurrentWorkoutForStrategy(admin, userID, strategy.id, acceptedLocalDate);

  if (requestBody.healthSnapshot) {
    await persistFitnessEvidence(admin, userID, null, requestBody.healthSnapshot, {
      userGoalID: goal.id,
      fitnessStrategyID: strategy.id,
    });
    await evaluatePlanningTargets(admin, userID, strategy.id, requestBody.healthSnapshot);
  }

  const event = await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: strategy.id,
    userGoalID: goal.id,
    eventType: "strategy_accepted",
    payload: {
      usedAIInitialPlan: true,
      usedFallback: false,
      usedTrainingArchitecture: Boolean(trainingArchitecture?.id),
      trainingArchitectureID: trainingArchitecture?.id ?? null,
      committedWeekStart: isoDate(committedWeekStart),
      draftWeekStart: isoDate(draftWeekStart),
      planOwnerStartDate: ownerStartDate,
      actualSync: initialActualSync,
    },
  });

  return {
    userID,
    model,
    usedFallback: false,
    userGoalID: goal.id,
    fitnessStrategyID: strategy.id,
    trainingArchitectureID: trainingArchitecture?.id ?? null,
    weeklyPlanIDs: weeklyPlans.map((plan) => plan.id),
    eventID: event.id,
    plan: generated,
  };
}

async function getPlanningGraphRunStatus(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  const graphRunID = requestBody.graphRunID ?? requestBody.graph_run_id;
  if (!graphRunID) {
    throw new Error("get_planning_graph_run_status requires graphRunID");
  }

  const graphRun = await single(
    admin
      .from("ai_graph_runs")
      .select()
      .eq("id", graphRunID)
      .eq("user_id", userID)
      .single(),
    "Planning graph run not found",
  );
  const trainingArchitecture = await maybeSingle(
    admin
      .from("training_architectures")
      .select()
      .eq("ai_graph_run_id", graphRun.id)
      .eq("user_id", userID)
      .limit(1),
  );
  const includeTrace = requestBody.includeTrace === true || requestBody.include_trace === true;
  const nodes = includeTrace
    ? await graphRunNodeOutputs(admin, graphRun.id, userID)
    : undefined;
  const toolCalls = includeTrace
    ? await graphRunToolCalls(admin, graphRun.id, userID)
    : undefined;

  return {
    userID,
    graphRunID: graphRun.id,
    graphName: graphRun.graph_name,
    status: graphRun.status,
    errorSummary: graphRun.error_summary ?? null,
    input: includeTrace ? graphRun.input_json ?? null : undefined,
    output: graphRun.output_json ?? null,
    model: includeTrace ? graphRun.model_json ?? {} : undefined,
    nodes,
    toolCalls,
    trainingArchitectureID: trainingArchitecture?.id ?? null,
  };
}

async function syncHealthKitAndReconcile(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const scope = await loadActivePlanningScope(admin, userID);
  const timezone = requestBody.deviceTimezone || scope.timezone || "UTC";

  if (requestBody.healthSnapshot) {
    await throwOnError(
      admin.from("health_feature_snapshots").insert({
        user_id: userID,
        generated_at: snapshotGeneratedAt(requestBody.healthSnapshot),
        snapshot_json: requestBody.healthSnapshot,
        source_timezone: timezone,
      }),
    );
    await persistFitnessEvidence(admin, userID, null, requestBody.healthSnapshot);
  }

  const actualSync = await reconcileActualWorkouts(admin, userID, scope, requestBody.actualWorkouts ?? [], {
    createDetectedProposal: false,
    createDisparityProposal: true,
  });
  const { synced, matched, detected, dedupedDetected, detectedEvents } = actualSync;
  const missedWorkouts = await markMissedWorkouts(admin, userID, scope.strategy.id, requestBody.syncWindow?.endDate);

  const event = await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: scope.strategy.id,
    eventType: "actual_synced",
    payload: {
      synced,
      matched,
      detected,
      dedupedDetected,
      missed: missedWorkouts.length,
      missedWorkoutIDs: missedWorkouts.map((workout: Record<string, any>) => workout.id),
      syncWindow: requestBody.syncWindow ?? null,
    },
  });

  if (detectedEvents.length > 0) {
    await createReplanProposal(admin, {
      userID,
      fitnessStrategyID: scope.strategy.id,
      triggerEventID: event.id,
      reason: detectedEvents.length === 1
        ? "Unexpected HealthKit workout detected. Review whether the rest of the week should change."
        : `${detectedEvents.length} unexpected HealthKit workouts detected. Review whether the current rhythm should change.`,
      mutations: [],
      metadata: {
        detectedWorkoutEventIDs: detectedEvents.map((detectedEvent) => detectedEvent.eventID),
        detectedPlannedWorkoutIDs: detectedEvents.map((detectedEvent) => detectedEvent.plannedWorkoutID),
      },
    });
  }

  let refreshOutput: Record<string, unknown> | null = null;
  if (missedWorkouts.length > 0) {
    refreshOutput = await refreshPlanWindowForUser(
      admin,
      userID,
      requestBody.syncWindow?.endDate,
      model,
      "user",
      true,
    );
  } else {
    await markCurrentWorkoutForStrategy(admin, userID, scope.strategy.id, dateOnlyInTimezone(new Date(), timezone));
  }

  if (requestBody.healthSnapshot) {
    await evaluatePlanningTargets(admin, userID, scope.strategy.id, requestBody.healthSnapshot);
  }
  const visiblePlans = await visibleWeeklyPlans(
    admin,
    userID,
    scope.strategy.id,
    twoWeekWindow(firstCommittedWeekStart(new Date(), timezone)),
  );
  await evaluateWeeklyTargetsForPlans(admin, userID, visiblePlans.map((plan: Record<string, any>) => plan.id));

  return { userID, eventID: event.id, synced, matched, detected, dedupedDetected, missed: missedWorkouts.length, refreshOutput };
}

async function refreshPlanWindow(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
  trigger: "user" | "scheduled",
) {
  return refreshPlanWindowForUser(admin, userID, requestBody.windowStart, model, trigger);
}

async function refreshWorkoutWeatherForecasts(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  const scope = await loadActivePlanningScope(admin, userID);
  const timezone = requestBody.deviceTimezone || scope.timezone || "UTC";
  const start = parseDateOnly(requestBody.windowStart) ?? firstCommittedWeekStart(new Date(), timezone);
  const window = twoWeekWindow(start);
  const today = isoDate(todayInTimezone(timezone));
  const weeklyPlans = (await visibleWeeklyPlans(admin, userID, scope.strategy.id, window))
    .filter((plan: Record<string, any>) => plan.status === "committed" || plan.status === "draft");
  const weeklyPlanIDs = weeklyPlans.map((plan: Record<string, any>) => plan.id);

  if (weeklyPlanIDs.length === 0) {
    return {
      userID,
      model: "open-meteo",
      fitnessStrategyID: scope.strategy.id,
      window,
      refreshed: 0,
      skipped: 0,
      failed: [],
    };
  }

  const workouts = await list(
    admin
      .from("planned_workouts")
      .select("id,scheduled_date,planned_location_label,weather_forecast_json,status")
      .eq("user_id", userID)
      .in("weekly_plan_id", weeklyPlanIDs)
      .gte("scheduled_date", today)
      .lte("scheduled_date", window.end)
      .not("status", "in", "(deleted,superseded,missed,done)")
      .order("scheduled_date", { ascending: true })
      .order("sequence_order", { ascending: true }),
  );

  const geocodeCache = new Map<string, OpenMeteoLocation | null>();
  const forecastCache = new Map<string, OpenMeteoDailyForecast | null>();
  const refreshed: string[] = [];
  const failed: Array<{ workoutID: string; locationLabel: string; error: string }> = [];
  let skipped = 0;

  for (const workout of workouts) {
    const locationLabel = compactNullableText(workout.planned_location_label) ?? scope.homeLocationLabel;
    if (!locationLabel) {
      skipped += 1;
      continue;
    }

    try {
      const forecast = await fetchOpenMeteoWorkoutForecast(
        locationLabel,
        String(workout.scheduled_date ?? ""),
        geocodeCache,
        forecastCache,
      );
      if (!forecast) {
        skipped += 1;
        continue;
      }

      await throwOnError(
        admin
          .from("planned_workouts")
          .update({ weather_forecast_json: forecast })
          .eq("id", workout.id)
          .eq("user_id", userID),
      );
      refreshed.push(workout.id);
    } catch (error) {
      failed.push({ workoutID: workout.id, locationLabel, error: errorMessage(error) });
    }
  }

  return {
    userID,
    model: "open-meteo",
    fitnessStrategyID: scope.strategy.id,
    window,
    refreshed: refreshed.length,
    refreshedWorkoutIDs: refreshed,
    skipped,
    failed,
  };
}

async function generateWeeklyPlanTargetsForVisiblePlan(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const scope = await loadActivePlanningScope(admin, userID);
  const timezone = requestBody.deviceTimezone || scope.timezone || "UTC";
  const start = parseDateOnly(requestBody.windowStart) ?? firstCommittedWeekStart(new Date(), timezone);
  const window = twoWeekWindow(start);
  const weeklyPlans = await visibleWeeklyPlans(admin, userID, scope.strategy.id, window);
  const latestSnapshot = await maybeSingle(
    admin
      .from("health_feature_snapshots")
      .select()
      .eq("user_id", userID)
      .order("generated_at", { ascending: false })
      .limit(1),
  );
  const rows = await generateAndPersistWeeklyTargets(admin, {
    userID,
    goal: scope.goal,
    strategy: scope.strategy,
    weeklyPlans,
    healthSnapshot: latestSnapshot?.snapshot_json ?? null,
    acceptedStrategy: scope.strategy.context_json?.acceptedStrategy ?? null,
    model,
  });
  const event = await createPlanEvent(admin, {
    userID,
    userGoalID: scope.goal.id,
    fitnessStrategyID: scope.strategy.id,
    eventType: "weekly_targets_generated",
    payload: {
      trigger: "explicit",
      window,
      weeklyPlanIDs: weeklyPlans.map((plan: Record<string, any>) => plan.id),
      targetCount: rows.length,
    },
  });

  return {
    userID,
    model,
    fitnessStrategyID: scope.strategy.id,
    eventID: event.id,
    targetCount: rows.length,
  };
}

async function ensureWeeklyTargetsForPlans(
  admin: SupabaseAdminClient,
  args: {
    userID: string;
    goal: Record<string, any>;
    strategy: Record<string, any>;
    weeklyPlans: Record<string, any>[];
    model: string;
  },
) {
  if (args.weeklyPlans.length === 0) return 0;
  const weeklyPlanIDs = args.weeklyPlans.map((plan: Record<string, any>) => plan.id);
  if (await hasWeeklyTargetsForPlans(admin, args.userID, weeklyPlanIDs)) return 0;

  const latestSnapshot = await maybeSingle(
    admin
      .from("health_feature_snapshots")
      .select()
      .eq("user_id", args.userID)
      .order("generated_at", { ascending: false })
      .limit(1),
  );
  const rows = await generateAndPersistWeeklyTargets(admin, {
    userID: args.userID,
    goal: args.goal,
    strategy: args.strategy,
    weeklyPlans: args.weeklyPlans,
    healthSnapshot: latestSnapshot?.snapshot_json ?? null,
    acceptedStrategy: args.strategy.context_json?.acceptedStrategy ?? null,
    model: args.model,
  });
  return rows.length;
}

async function pendingManualReviewState(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  weeklyPlanIDs: string[],
) {
  const pendingProposal = await maybeSingle(
    admin
      .from("replan_proposals")
      .select("id")
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(1),
  );

  if (weeklyPlanIDs.length === 0) {
    return {
      hasPending: Boolean(pendingProposal),
      pendingEditCount: 0,
      pendingProposalID: pendingProposal?.id ?? null,
    };
  }

  const checkpoint = await latestManualReviewResolutionCheckpoint(admin, userID, strategyID);
  let eventQuery = admin
    .from("plan_events")
    .select("id")
    .eq("user_id", userID)
    .eq("fitness_strategy_id", strategyID)
    .in("weekly_plan_id", weeklyPlanIDs)
    .in("event_type", pendingReviewEditEventTypes())
    .order("created_at", { ascending: false })
    .limit(50);
  if (checkpoint?.created_at) {
    eventQuery = eventQuery.gt("created_at", checkpoint.created_at);
  }

  const pendingEvents = await list(eventQuery);
  return {
    hasPending: Boolean(pendingProposal) || pendingEvents.length > 0,
    pendingEditCount: pendingEvents.length,
    pendingProposalID: pendingProposal?.id ?? null,
  };
}

async function reconcileVisibleWeeklyPlanLifecycle(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  window: { start: string; end: string },
) {
  const currentWeekStart = window.start;
  const nextWeekStart = isoDate(addDays(parseDateOnly(window.start) ?? new Date(), 7));
  const plans = (await visibleWeeklyPlans(admin, userID, strategyID, window))
    .filter((plan: Record<string, any>) => plan.status === "committed" || plan.status === "draft");
  const currentPlan = plans.find((plan: Record<string, any>) => plan.week_start_date === currentWeekStart) ?? null;
  const nextPlan = plans.find((plan: Record<string, any>) => plan.week_start_date === nextWeekStart) ?? null;
  const promotedAt = new Date().toISOString();

  if (currentPlan && currentPlan.status !== "committed") {
    await throwOnError(
      admin
        .from("weekly_plans")
        .update({ status: "committed", promoted_at: currentPlan.promoted_at ?? promotedAt })
        .eq("id", currentPlan.id)
        .eq("user_id", userID),
    );
    currentPlan.status = "committed";
    currentPlan.promoted_at = currentPlan.promoted_at ?? promotedAt;
  }

  if (currentPlan) {
    await throwOnError(
      admin
        .from("weekly_plans")
        .update({ status: "archived" })
        .eq("user_id", userID)
        .eq("fitness_strategy_id", strategyID)
        .eq("status", "committed")
        .neq("id", currentPlan.id),
    );
  }

  if (nextPlan && nextPlan.status !== "draft" && nextPlan.id !== currentPlan?.id) {
    await throwOnError(
      admin
        .from("weekly_plans")
        .update({ status: "draft", promoted_at: null })
        .eq("id", nextPlan.id)
        .eq("user_id", userID),
    );
    nextPlan.status = "draft";
    nextPlan.promoted_at = null;
  }

  return {
    currentWeekStart,
    nextWeekStart,
    currentPlanID: currentPlan?.id ?? null,
    nextPlanID: nextPlan?.id ?? null,
    hasCurrentCommittedPlan: Boolean(currentPlan),
    hasNextDraftPlan: Boolean(nextPlan),
  };
}

async function refreshPlanWindowForUser(
  admin: SupabaseAdminClient,
  userID: string,
  windowStart: string | undefined,
  model: string,
  trigger: "user" | "scheduled",
  force = false,
) {
  const scope = await loadActivePlanningScope(admin, userID);
  const timezone = scope.timezone || "UTC";
  const start = parseDateOnly(windowStart) ?? firstCommittedWeekStart(new Date(), timezone);
  const window = twoWeekWindow(start);
  const lifecycle = await reconcileVisibleWeeklyPlanLifecycle(admin, userID, scope.strategy.id, window);
  const existingWeeklyPlans = (await visibleWeeklyPlans(admin, userID, scope.strategy.id, window))
    .filter((plan: Record<string, any>) => plan.status === "committed" || plan.status === "draft");
  const existingWeeklyPlanIDs = existingWeeklyPlans.map((plan: Record<string, any>) => plan.id);
  const currentWeekPlan = existingWeeklyPlans.find((plan: Record<string, any>) => plan.week_start_date === lifecycle.currentWeekStart) ?? null;
  const nextWeekPlan = existingWeeklyPlans.find((plan: Record<string, any>) => plan.week_start_date === lifecycle.nextWeekStart) ?? null;
  const windowAlreadyExists = Boolean(currentWeekPlan && nextWeekPlan);
  const shouldOnlyGenerateMissingDraft = Boolean(currentWeekPlan && !nextWeekPlan);
  const pendingManualReview = await pendingManualReviewState(
    admin,
    userID,
    scope.strategy.id,
    existingWeeklyPlanIDs,
  );

  if (existingWeeklyPlanIDs.length > 0) {
    await ensureWeeklyTargetsForPlans(admin, {
      userID,
      goal: scope.goal,
      strategy: scope.strategy,
      weeklyPlans: existingWeeklyPlans,
      model,
    });
  }

  if (pendingManualReview.hasPending && windowAlreadyExists) {
    const event = await createPlanEvent(admin, {
      userID,
      fitnessStrategyID: scope.strategy.id,
      eventType: "window_refreshed",
      payload: {
        trigger,
        skipped: true,
        reason: "pending_manual_review",
        window,
        pendingEditCount: pendingManualReview.pendingEditCount,
        pendingProposalID: pendingManualReview.pendingProposalID,
      },
    });

    return {
      userID,
      model: "deterministic",
      skipped: true,
      reason: "pending_manual_review",
      pendingEditCount: pendingManualReview.pendingEditCount,
      pendingProposalID: pendingManualReview.pendingProposalID,
      fitnessStrategyID: scope.strategy.id,
      eventID: event.id,
    };
  }

  if (trigger === "user" && windowAlreadyExists) {
    const duplicateGeneratedWorkouts = await cleanupDuplicateGeneratedPlanWorkouts(admin, userID, scope.strategy.id, window);
    const event = await createPlanEvent(admin, {
      userID,
      fitnessStrategyID: scope.strategy.id,
      eventType: "window_refreshed",
      payload: {
        trigger,
        skipped: true,
        reason: "visible_two_week_window_already_exists",
        window,
        duplicateGeneratedWorkouts,
      },
    });

    return {
      userID,
      model: "deterministic",
      skipped: true,
      reason: "visible_two_week_window_already_exists",
      fitnessStrategyID: scope.strategy.id,
      eventID: event.id,
    };
  }

  const latestSnapshot = await maybeSingle(
    admin
      .from("health_feature_snapshots")
      .select()
      .eq("user_id", userID)
      .order("generated_at", { ascending: false })
      .limit(1),
  );
  const events = await list(
    admin
      .from("plan_events")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .order("created_at", { ascending: false })
      .limit(30),
  );
  const proposals = await list(
    admin
      .from("replan_proposals")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .in("status", ["pending", "accepted"])
      .order("created_at", { ascending: false })
      .limit(10),
  );
  const weeklyPlans = await list(
    admin
      .from("weekly_plans")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .gte("week_start_date", window.start)
      .lte("week_start_date", window.end)
      .order("week_start_date", { ascending: true }),
  );
  const duplicateGeneratedWorkouts = await cleanupDuplicateGeneratedPlanWorkouts(admin, userID, scope.strategy.id, window);
  const weeklyTargetConstraints = await loadWeeklyTargetConstraints(
    admin,
    userID,
    weeklyPlans,
  );
  const context = {
    goal: scope.goal,
    strategy: scope.strategy,
    block: scope.block,
    weeklyPlans,
    latestSnapshot,
    events,
    proposals,
    windowStart: isoDate(start),
    trigger,
    force,
    weeklyTargetConstraints,
  };
  const healthDataFreshness = healthFreshness(latestSnapshot);

  let generated = sanitizeGeneratedPlan(await runPlanGeneration("refresh_plan_window", context, model), null, start, timezone);
  generated = alignGeneratedPlanToWeeklyTargets(generated, weeklyTargetConstraints);
  if (shouldOnlyGenerateMissingDraft) {
    generated = {
      ...generated,
      rhythms: generated.rhythms.filter((rhythm) => rhythm.weekStartDate === lifecycle.nextWeekStart),
    };
    if (generated.rhythms.length === 0) {
      throw new Error("AI plan generation did not return the missing draft week.");
    }
  }

  const plansToReplace = shouldOnlyGenerateMissingDraft
    ? weeklyPlans.filter((plan: Record<string, any>) => plan.week_start_date === lifecycle.nextWeekStart)
    : weeklyPlans;
  const planIDs = plansToReplace.map((plan: Record<string, any>) => plan.id);
  if (planIDs.length > 0) {
    await throwOnError(
      admin
        .from("planned_workouts")
        .update({ status: "superseded", generation_key: null })
        .eq("user_id", userID)
        .in("weekly_plan_id", planIDs)
        .gte("scheduled_date", window.start)
        .lte("scheduled_date", window.end)
        .in("status", ["planned", "current"])
        .in("source", ["generated", "replanned"]),
    );
  }

  let weeklyPlanSupersedeQuery = admin
      .from("weekly_plans")
      .update({ status: "superseded" })
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .gte("week_start_date", window.start)
      .lte("week_start_date", window.end)
      .in("status", ["committed", "draft"]);
  if (shouldOnlyGenerateMissingDraft && currentWeekPlan?.id) {
    weeklyPlanSupersedeQuery = weeklyPlanSupersedeQuery.neq("id", currentWeekPlan.id);
  }
  await throwOnError(weeklyPlanSupersedeQuery);

  const refreshedWeeklyPlans = await insertWeeklyPlansAndWorkouts(admin, {
    userID,
    strategyID: scope.strategy.id,
    rhythms: generated.rhythms,
    source: "replanned",
    committedWeekStart: isoDate(start),
    ownerStartDate: isoDate(dateOnlyInTimezone(new Date(), timezone)),
    homeLocationLabel: scope.homeLocationLabel,
  });
  const duplicateGeneratedWorkoutsAfterInsert = await cleanupDuplicateGeneratedPlanWorkouts(admin, userID, scope.strategy.id, window);
  await generateAndPersistWeeklyTargets(admin, {
    userID,
    goal: scope.goal,
    strategy: scope.strategy,
    weeklyPlans: refreshedWeeklyPlans,
    healthSnapshot: latestSnapshot?.snapshot_json ?? null,
    acceptedStrategy: scope.strategy.context_json?.acceptedStrategy ?? null,
    model,
  });
  await markCurrentWorkoutForStrategy(admin, userID, scope.strategy.id, dateOnlyInTimezone(new Date(), timezone));
  const event = await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: scope.strategy.id,
    eventType: "window_refreshed",
    payload: {
      trigger,
      usedFallback: false,
      window,
      healthDataFreshness,
      duplicateGeneratedWorkouts: duplicateGeneratedWorkouts + duplicateGeneratedWorkoutsAfterInsert,
    },
  });

  return {
    userID,
    model,
    usedFallback: false,
    fitnessStrategyID: scope.strategy.id,
    eventID: event.id,
    plan: generated,
  };
}

async function recordPlanEdit(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  if (!requestBody.edit) {
    throw new Error("record_plan_edit requires edit");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  const edit = requestBody.edit;
  if (edit.type !== "move_workout" && edit.type !== "delete_workout") {
    throw new Error("record_plan_edit only supports move and delete edits");
  }
  const workout = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, edit.planned_workout_id);

  let event: Record<string, any>;
  if (edit.type === "move_workout") {
    const targetPlan = await weeklyPlanForDate(admin, userID, scope.strategy.id, edit.scheduled_date);
    await throwOnError(
      admin
        .from("planned_workouts")
        .update({
          weekly_plan_id: targetPlan?.id ?? workout.weekly_plan_id ?? null,
          generation_key: null,
          scheduled_date: edit.scheduled_date,
          sequence_order: edit.sequence_order ?? workout.sequence_order,
          source: "user_moved",
          version: (workout.version ?? 1) + 1,
        })
        .eq("id", workout.id),
    );
    await updateMutableGeneratedSlotRows(admin, {
      userID,
      weeklyPlanID: workout.weekly_plan_id,
      scheduledDate: workout.scheduled_date,
      sequenceOrder: workout.sequence_order,
      excludeWorkoutID: workout.id,
      fields: { status: "superseded", generation_key: null },
    });
    event = await createPlanEvent(admin, {
      userID,
      fitnessStrategyID: scope.strategy.id,
      weeklyPlanID: targetPlan?.id ?? workout.weekly_plan_id ?? null,
      plannedWorkoutID: workout.id,
      eventType: "workout_moved",
      payload: { from: workout.scheduled_date, to: edit.scheduled_date },
    });
  } else if (edit.type === "delete_workout") {
    await throwOnError(
      admin
        .from("planned_workouts")
        .update({ status: "deleted", source: "user_deleted", generation_key: null, version: (workout.version ?? 1) + 1 })
        .eq("id", workout.id),
    );
    await updateMutableGeneratedSlotRows(admin, {
      userID,
      weeklyPlanID: workout.weekly_plan_id,
      scheduledDate: workout.scheduled_date,
      sequenceOrder: workout.sequence_order,
      excludeWorkoutID: workout.id,
      fields: { status: "deleted", source: "user_deleted", generation_key: null },
    });
    event = await createPlanEvent(admin, {
      userID,
      fitnessStrategyID: scope.strategy.id,
      weeklyPlanID: workout.weekly_plan_id ?? null,
      plannedWorkoutID: workout.id,
      eventType: "workout_deleted",
      payload: { deletedWorkout: workout },
    });
  } else {
    throw new Error("record_plan_edit does not support replacement edits directly");
  }

  const repairPolicy = requestedRepairPolicy(requestBody);
  const repair = repairPolicy === "deferred"
    ? null
    : await buildPlanEditRepair(admin, userID, scope, workout, edit, model, requestBody.deviceTimezone || scope.timezone || "UTC");
  const proposal = repair && repairPolicy === "immediate"
    ? await createPlanEditRepairProposal(admin, userID, scope.strategy.id, event.id, repair)
    : null;
  if (!proposal || repairPolicy === "deferred") {
    await expirePendingReplanProposals(admin, userID, scope.strategy.id);
  }
  await markCurrentWorkoutForStrategy(admin, userID, scope.strategy.id, dateOnlyInTimezone(new Date(), requestBody.deviceTimezone || scope.timezone || "UTC"));
  return {
    userID,
    eventID: event.id,
    proposalID: proposal?.id ?? null,
    reason: repair?.reason ?? null,
    summary: repair?.summary ?? null,
    risks: repair?.risks ?? [],
    mutationCount: repair?.mutations.length ?? 0,
    reviewHint: repair && repairPolicy === "deferred" ? reviewHintFromRepair(repair) : null,
    proposal: proposal
      ? {
        id: proposal.id,
        active_block_id: proposal.active_block_id,
        trigger_event_id: proposal.trigger_event_id,
        reason: proposal.reason,
        proposed_mutations_json: proposal.proposed_mutations_json,
        status: proposal.status,
        created_at: proposal.created_at,
        updated_at: proposal.updated_at,
      }
      : null,
  };
}

async function updateMutableGeneratedSlotRows(
  admin: SupabaseAdminClient,
  args: {
    userID: string;
    weeklyPlanID?: string | null;
    scheduledDate: string;
    sequenceOrder: number;
    excludeWorkoutID: string;
    fields: Record<string, unknown>;
  },
) {
  if (!args.weeklyPlanID) return;

  await throwOnError(
    admin
      .from("planned_workouts")
      .update(args.fields)
      .eq("user_id", args.userID)
      .eq("weekly_plan_id", args.weeklyPlanID)
      .eq("scheduled_date", args.scheduledDate)
      .eq("sequence_order", args.sequenceOrder)
      .neq("id", args.excludeWorkoutID)
      .in("status", ["planned", "current"])
      .in("source", ["generated", "replanned"]),
  );
}

async function recordWeeklyPlanConstraint(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  const input = requestBody.weeklyPlanConstraint ?? requestBody.weekly_plan_constraint;
  const weeklyPlanID = input?.weekly_plan_id ?? input?.weeklyPlanID;
  const scheduledDate = input?.scheduled_date ?? input?.scheduledDate;
  const kind = input?.kind ?? "available";
  const note = input?.note?.trim() || null;
  if (!weeklyPlanID || !scheduledDate) {
    throw new Error("record_weekly_plan_constraint requires weeklyPlanID and scheduledDate");
  }
  if (!["available", "limited", "unavailable"].includes(kind)) {
    throw new Error("Use available, limited, or unavailable for a weekly plan constraint.");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  const weeklyPlan = await single(
    admin
      .from("weekly_plans")
      .select()
      .eq("id", weeklyPlanID)
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .single(),
    "Weekly plan not found",
  );
  if (scheduledDate < weeklyPlan.week_start_date || scheduledDate > weeklyPlan.week_end_date) {
    throw new Error("Constraint date must be inside the selected weekly plan.");
  }

  const existing = weeklyPlan.constraints_json ?? {};
  const days = { ...(existing.days ?? {}) };
  if (kind === "available") {
    delete days[scheduledDate];
  } else {
    days[scheduledDate] = {
      kind,
      note,
      source: "user",
      updatedAt: new Date().toISOString(),
    };
  }
  const constraints = { ...existing, days };

  await throwOnError(
    admin
      .from("weekly_plans")
      .update({ constraints_json: constraints })
      .eq("id", weeklyPlanID)
      .eq("user_id", userID),
  );

  const event = await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: scope.strategy.id,
    weeklyPlanID,
    eventType: "weekly_plan_constraint_recorded",
    payload: { scheduledDate, kind, hasNote: Boolean(note) },
  });

  await expirePendingReplanProposals(admin, userID, scope.strategy.id);

  return {
    userID,
    model: "deterministic",
    weeklyPlanID,
    scheduledDate,
    kind,
    eventID: event.id,
  };
}

async function buildPlanEditRepair(
  admin: SupabaseAdminClient,
  userID: string,
  scope: PlanningScope,
  editedWorkout: Record<string, any>,
  edit: PlanEditInput,
  model: string,
  timezone: string,
): Promise<EditRepairPlan | null> {
  const block = scope.block;
  const affectedDates = [editedWorkout.scheduled_date];
  if (edit.type === "move_workout" || edit.type === "replace_workout" || edit.type === "add_workout") affectedDates.push(edit.scheduled_date);
  const parsedDates = affectedDates.map((date) => parseDateOnly(date)).filter(Boolean) as Date[];
  const today = todayInTimezone(timezone);
  const currentWeekStart = startOfWeek(today);
  const affectedFirstWeek = startOfWeek(new Date(Math.min(...parsedDates.map((date) => date.getTime()))));
  const affectedLastWeek = startOfWeek(new Date(Math.max(...parsedDates.map((date) => date.getTime()))));
  const firstWeek = new Date(Math.min(currentWeekStart.getTime(), affectedFirstWeek.getTime()));
  const lastWeek = new Date(Math.max(currentWeekStart.getTime(), affectedLastWeek.getTime()));
  const window = { start: isoDate(firstWeek), end: isoDate(addDays(lastWeek, 6)) };

  const weeklyPlans = await list(
    admin
      .from("weekly_plans")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .gte("week_start_date", window.start)
      .lte("week_start_date", window.end),
  );
  const planIDs = weeklyPlans.map((plan: Record<string, any>) => plan.id);
  const [workouts, goalTargets] = await Promise.all([
    list(
      admin
        .from("planned_workouts")
        .select()
        .eq("user_id", userID)
        .in("weekly_plan_id", planIDs.length > 0 ? planIDs : ["00000000-0000-0000-0000-000000000000"])
        .gte("scheduled_date", window.start)
        .lte("scheduled_date", window.end)
        .in("status", ["planned", "current", "checked_in", "adjusted", "done"])
        .order("scheduled_date", { ascending: true })
        .order("sequence_order", { ascending: true }),
    ),
    list(
      admin
        .from("planning_targets")
        .select("id,target_kind,title,description,metric_key,metric_category,evaluation_rule_json,status")
        .eq("user_id", userID)
        .eq("fitness_strategy_id", scope.strategy.id)
        .in("status", ["on_track", "lagging", "needs_review"]),
    ),
  ]);
  const rhythms = weeklyPlans.map(weeklyPlanAsRhythm);

  const risks = detectPlanEditRisks({
    block,
    workouts,
    rhythms,
    goalTargets,
    editedWorkout,
    edit,
    today,
  });
  if (risks.length === 0) return null;

  const fallback = fallbackEditRepair({ block, workouts, rhythms, editedWorkout, edit, risks, today });
  if (fallback.mutations.length === 0) return null;

  let draft: PlanEditRepairDraft | null = null;
  try {
    draft = await runEditRepairDraft(
      {
        editedWorkout: compactWorkoutForRepair(editedWorkout),
        edit,
        risks,
        fallback,
        visibleWorkouts: workouts.map(compactWorkoutForRepair),
      },
      model,
    );
  } catch {
    draft = null;
  }

  return {
    ...fallback,
    reason: draft?.reason?.trim() || fallback.reason,
    summary: draft?.summary?.trim() || fallback.summary,
  };
}

async function buildPlanEditReviewHint(
  admin: SupabaseAdminClient,
  userID: string,
  scope: PlanningScope,
  editedWorkout: Record<string, any>,
  edit: PlanEditInput,
  timezone: string,
): Promise<EditRepairPlan | null> {
  const block = scope.block;
  const affectedDates = [editedWorkout.scheduled_date];
  if (edit.type === "move_workout" || edit.type === "replace_workout" || edit.type === "add_workout") affectedDates.push(edit.scheduled_date);
  const parsedDates = affectedDates.map((date) => parseDateOnly(date)).filter(Boolean) as Date[];
  const today = todayInTimezone(timezone);
  const currentWeekStart = startOfWeek(today);
  const affectedFirstWeek = startOfWeek(new Date(Math.min(...parsedDates.map((date) => date.getTime()))));
  const affectedLastWeek = startOfWeek(new Date(Math.max(...parsedDates.map((date) => date.getTime()))));
  const firstWeek = new Date(Math.min(currentWeekStart.getTime(), affectedFirstWeek.getTime()));
  const lastWeek = new Date(Math.max(currentWeekStart.getTime(), affectedLastWeek.getTime()));
  const window = { start: isoDate(firstWeek), end: isoDate(addDays(lastWeek, 6)) };

  const weeklyPlans = await list(
    admin
      .from("weekly_plans")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .gte("week_start_date", window.start)
      .lte("week_start_date", window.end),
  );
  const planIDs = weeklyPlans.map((plan: Record<string, any>) => plan.id);
  const [workouts, goalTargets] = await Promise.all([
    list(
      admin
        .from("planned_workouts")
        .select()
        .eq("user_id", userID)
        .in("weekly_plan_id", planIDs.length > 0 ? planIDs : ["00000000-0000-0000-0000-000000000000"])
        .gte("scheduled_date", window.start)
        .lte("scheduled_date", window.end)
        .in("status", ["planned", "current", "checked_in", "adjusted", "done"])
        .order("scheduled_date", { ascending: true })
        .order("sequence_order", { ascending: true }),
    ),
    list(
      admin
        .from("planning_targets")
        .select("id,target_kind,title,description,metric_key,metric_category,evaluation_rule_json,status")
        .eq("user_id", userID)
        .eq("fitness_strategy_id", scope.strategy.id)
        .in("status", ["on_track", "lagging", "needs_review"]),
    ),
  ]);
  const rhythms = weeklyPlans.map(weeklyPlanAsRhythm);

  const risks = detectPlanEditRisks({
    block,
    workouts,
    rhythms,
    goalTargets,
    editedWorkout,
    edit,
    today,
  });
  if (risks.length === 0) return null;

  const fallback = fallbackEditRepair({ block, workouts, rhythms, editedWorkout, edit, risks, today });
  if (fallback.mutations.length === 0) return null;
  return fallback;
}

function requestedRepairPolicy(requestBody: PlanningAIRequest): "immediate" | "deferred" {
  return requestBody.repairPolicy ?? requestBody.repair_policy ?? "immediate";
}

function reviewHintFromRepair(repair: EditRepairPlan) {
  const affectedWeekStart = repair.risks.find((risk) => risk.weekStartDate)?.weekStartDate ?? null;
  return {
    reason: repair.reason,
    summary: repair.summary,
    affectedWeekStart,
    riskCount: repair.risks.length,
    risks: repair.risks.map((risk) => ({
      kind: risk.kind,
      severity: risk.severity,
      message: risk.message,
      affectedWorkoutIDs: risk.affectedWorkoutIDs,
      dimensions: risk.dimensions,
      weekStartDate: risk.weekStartDate ?? null,
    })),
  };
}

async function createPlanEditRepairProposal(
  admin: SupabaseAdminClient,
  userID: string,
  fitnessStrategyID: string,
  triggerEventID: string,
  repair: EditRepairPlan,
) {
  return createReplanProposal(admin, {
    userID,
    fitnessStrategyID,
    triggerEventID,
    reason: repair.reason,
    mutations: repair.mutations,
    metadata: {
      type: "plan_edit_repair",
      summary: repair.summary,
      risks: repair.risks.map((risk) => ({
        kind: risk.kind,
        severity: risk.severity,
        dimensions: risk.dimensions,
        affectedWorkoutIDs: risk.affectedWorkoutIDs,
      })),
    },
  });
}

function detectPlanEditRisks(args: {
  block: Record<string, any>;
  workouts: Record<string, any>[];
  rhythms: Record<string, any>[];
  goalTargets: Record<string, any>[];
  editedWorkout: Record<string, any>;
  edit: PlanEditInput;
  today: Date;
}): EditRisk[] {
  const { block, workouts, rhythms, goalTargets, editedWorkout, edit, today } = args;
  const auditWorkouts = auditEligibleWorkouts(workouts, today);
  const weekStarts = auditedWeekStarts(auditWorkouts, rhythms, editedWorkout, edit, today);
  const risks: EditRisk[] = [];

  for (const weekStart of weekStarts) {
    const weekWorkouts = workoutsForWeek(auditWorkouts, weekStart);
    const compressed = compressedRecoveryRisk(weekWorkouts);
    if (compressed) {
      compressed.weekStartDate = isoDate(weekStart);
      risks.push(compressed);
    }

    const cumulative = cumulativeLoadRisk(weekWorkouts);
    if (cumulative) {
      cumulative.weekStartDate = isoDate(weekStart);
      risks.push(cumulative);
    }

    const rhythm = rhythms.find((item) => item.week_start_date === isoDate(weekStart));
    const targetCount = weeklyTargetCountRisk(weekWorkouts, rhythm, goalTargets, block, weekStart);
    if (targetCount) risks.push(targetCount);

    const goalDrift = goalDriftRisk(weekWorkouts, rhythm, editedWorkout, edit, weekStart);
    if (goalDrift) risks.push(goalDrift);

    const imbalance = weeklyImbalanceRisk(weekWorkouts, editedWorkout, edit, weekStart);
    if (imbalance) risks.push(imbalance);
  }

  const seen = new Set<string>();
  return risks.filter((risk) => {
    const key = `${risk.kind}:${risk.message}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).sort(compareEditRisks).slice(0, 3);
}

function compareEditRisks(first: EditRisk, second: EditRisk) {
  const severityDelta = riskSeverityScore(second) - riskSeverityScore(first);
  if (severityDelta !== 0) return severityDelta;
  return riskKindScore(second) - riskKindScore(first);
}

function riskSeverityScore(risk: EditRisk) {
  return risk.severity === "high" ? 2 : 1;
}

function riskKindScore(risk: EditRisk) {
  switch (risk.kind) {
    case "weekly_imbalance":
      return 4;
    case "compressed_recovery":
      return 3;
    case "goal_drift":
      return 2;
    case "cumulative_load":
      return 1;
  }
}

function auditedWeekStarts(
  workouts: Record<string, any>[],
  rhythms: Record<string, any>[],
  editedWorkout: Record<string, any>,
  edit: PlanEditInput,
  today: Date,
) {
  const starts = [startOfWeek(today), startOfWeek(addDays(today, 7)), startOfWeek(parseDateOnly(editedWorkout.scheduled_date) ?? today)];
  if (edit.type === "move_workout" || edit.type === "add_workout") {
    const movedStart = startOfWeek(parseDateOnly(edit.scheduled_date) ?? today);
    if (!starts.some((date) => date.getTime() === movedStart.getTime())) starts.push(movedStart);
  }
  for (const workout of workouts) {
    const weekStart = startOfWeek(parseDateOnly(workout.scheduled_date) ?? today);
    if (!starts.some((date) => date.getTime() === weekStart.getTime())) starts.push(weekStart);
  }
  for (const rhythm of rhythms) {
    const weekStart = startOfWeek(parseDateOnly(rhythm.week_start_date) ?? today);
    if (!starts.some((date) => date.getTime() === weekStart.getTime())) starts.push(weekStart);
  }
  return starts;
}

function auditEligibleWorkouts(workouts: Record<string, any>[], today: Date) {
  const todayISO = isoDate(today);
  return workouts.filter((workout) => {
    const scheduledDate = String(workout.scheduled_date ?? "");
    if (!scheduledDate) return false;
    if (scheduledDate < todayISO) {
      return ["done", "checked_in", "adjusted"].includes(String(workout.status ?? ""));
    }
    return ["planned", "current", "checked_in", "adjusted", "done"].includes(String(workout.status ?? ""));
  });
}

function canMutateWorkout(workout: Record<string, any>, today: Date) {
  const scheduledDate = String(workout.scheduled_date ?? "");
  if (!scheduledDate || scheduledDate < isoDate(today)) return false;
  return !["done", "checked_in", "deleted", "superseded"].includes(String(workout.status ?? ""));
}

function compressedRecoveryRisk(workouts: Record<string, any>[]): EditRisk | null {
  const profiled = workouts
    .map((workout) => ({ workout, profile: trainingProfile(workout) }))
    .filter((item) => item.profile.load !== "low" && !item.profile.dimensions.includes("recovery"));

  for (let index = 0; index < profiled.length; index += 1) {
    for (let otherIndex = index + 1; otherIndex < profiled.length; otherIndex += 1) {
      const first = profiled[index];
      const second = profiled[otherIndex];
      const days = absoluteCalendarDaysBetween(parseDateOnly(first.workout.scheduled_date) ?? new Date(), parseDateOnly(second.workout.scheduled_date) ?? new Date());
      const shared = first.profile.dimensions.filter((dimension) => second.profile.dimensions.includes(dimension) && dimension !== "recovery");
      const highPair = first.profile.load === "high" && second.profile.load === "high";
      const impactPair = first.profile.impact === "high" && second.profile.impact === "high";

      if (shared.length > 0 && days <= (highPair ? 2 : 1)) {
        return {
          kind: "compressed_recovery",
          severity: highPair ? "high" : "medium",
          message: `This puts ${first.workout.title} and ${second.workout.title} too close for ${dimensionLabel(shared[0])} recovery.`,
          affectedWorkoutIDs: [first.workout.id, second.workout.id],
          dimensions: shared,
        };
      }

      if (impactPair && days <= 1) {
        return {
          kind: "compressed_recovery",
          severity: "high",
          message: `This clusters two high-impact sessions within 24 hours.`,
          affectedWorkoutIDs: [first.workout.id, second.workout.id],
          dimensions: ["endurance"],
        };
      }
    }
  }
  return null;
}

function cumulativeLoadRisk(workouts: Record<string, any>[]): EditRisk | null {
  const loaded = workouts
    .map((workout) => ({ workout, profile: trainingProfile(workout), date: parseDateOnly(workout.scheduled_date) ?? new Date() }))
    .filter((item) => item.profile.load !== "low" && !item.profile.dimensions.includes("recovery"));

  for (const item of loaded) {
    const clustered = loaded.filter((candidate) => {
      const days = signedCalendarDaysBetween(item.date, candidate.date);
      return days >= 0 && days <= 3;
    });
    const highCount = clustered.filter((candidate) => candidate.profile.load === "high").length;
    if (clustered.length >= 3 && highCount >= 1) {
      const dimensions = Array.from(new Set(clustered.flatMap((candidate) => candidate.profile.dimensions).filter((dimension) => dimension !== "recovery")));
      return {
        kind: "cumulative_load",
        severity: highCount >= 2 ? "high" : "medium",
        message: `This clusters ${clustered.length} meaningful sessions inside four days.`,
        affectedWorkoutIDs: clustered.map((candidate) => candidate.workout.id),
        dimensions: dimensions.length > 0 ? dimensions : ["endurance"],
      };
    }
  }
  return null;
}

function weeklyTargetCountRisk(
  weekWorkouts: Record<string, any>[],
  rhythm: Record<string, any> | undefined,
  goalTargets: Record<string, any>[],
  block: Record<string, any>,
  weekStart: Date,
): EditRisk | null {
  const expected = expectedWeeklyDimensionCounts(rhythm, goalTargets, block);
  if (Object.keys(expected).length === 0) return null;

  const actual = actualWeeklyDimensionCounts(weekWorkouts);
  const deficits = (Object.entries(expected) as Array<[TrainingDimension, number]>)
    .filter(([, count]) => count > 0)
    .map(([dimension, count]) => ({
      dimension,
      expected: count,
      actual: actual[dimension] ?? 0,
    }))
    .filter((item) => item.actual < item.expected);

  if (deficits.length === 0) return null;

  const primary = deficits.sort((a, b) => (b.expected - b.actual) - (a.expected - a.actual))[0];
  return {
    kind: "weekly_imbalance",
    severity: primary.actual === 0 ? "high" : "medium",
    message: `This leaves the week at ${primary.actual}/${primary.expected} ${dimensionLabel(primary.dimension)} sessions.`,
    affectedWorkoutIDs: weekWorkouts
      .filter((workout) => trainingProfile(workout).dimensions.includes(primary.dimension))
      .map((workout) => workout.id),
    dimensions: [primary.dimension],
    weekStartDate: isoDate(weekStart),
    expectedCount: primary.expected,
    actualCount: primary.actual,
    missingCount: primary.expected - primary.actual,
  };
}

function expectedWeeklyDimensionCounts(
  rhythm: Record<string, any> | undefined,
  goalTargets: Record<string, any>[],
  block: Record<string, any>,
): Partial<Record<TrainingDimension, number>> {
  const expected: Partial<Record<TrainingDimension, number>> = {};
  mergeExpectedCounts(expected, dimensionRequirementsFromText(rhythmIntentText(rhythm), true));
  mergeExpectedCounts(expected, dimensionRequirementsFromText(blockIntentText(block), false));
  mergeExpectedCounts(expected, dimensionRequirementsFromText(goalTargetIntentText(goalTargets), true));

  return expected;
}

function mergeExpectedCounts(
  target: Partial<Record<TrainingDimension, number>>,
  source: Partial<Record<TrainingDimension, number>>,
) {
  for (const [dimension, count] of Object.entries(source) as Array<[TrainingDimension, number]>) {
    target[dimension] = Math.max(target[dimension] ?? 0, count);
  }
}

function dimensionRequirementsFromText(text: string, allowExplicitCounts: boolean): Partial<Record<TrainingDimension, number>> {
  const lower = text.toLowerCase();
  const expected: Partial<Record<TrainingDimension, number>> = {};
  const strengthCount = allowExplicitCounts ? countBeforeTerms(lower, ["strength", "strengths", "lift", "lifts", "lifting", "gym", "boulder", "bouldering", "climb", "climbing"]) : 0;
  const enduranceCount = allowExplicitCounts ? countBeforeTerms(lower, ["ride", "rides", "cycling", "run", "runs", "running", "swim", "swims", "swimming", "row", "rows", "hike", "hikes", "endurance", "cardio", "aerobic"]) : 0;
  const recoveryCount = allowExplicitCounts ? countBeforeTerms(lower, ["recovery", "mobility", "yoga", "walk", "walks"]) : 0;

  if (strengthCount || containsAny(lower, ["strength", "lift", "lifting", "gym", "boulder", "bouldering", "climb", "climbing"])) {
    expected.neuromuscular = strengthCount || 1;
  }
  if (enduranceCount || containsAny(lower, ["ride", "cycling", "bike", "run", "swim", "row", "hike", "endurance", "cardio", "aerobic"])) {
    expected.endurance = enduranceCount || 1;
  }
  if (recoveryCount || containsAny(lower, ["recovery", "mobility", "yoga", "easy walk"])) {
    expected.recovery = recoveryCount || 1;
  }

  return expected;
}

function rhythmIntentText(rhythm: Record<string, any> | undefined) {
  if (!rhythm) return "";
  return [
    rhythm.objective,
    Array.isArray(rhythm.priority_order_json) ? rhythm.priority_order_json.join(" ") : "",
    Array.isArray(rhythm.swap_rules_json) ? rhythm.swap_rules_json.join(" ") : "",
  ].join(" ");
}

function blockIntentText(block: Record<string, any>) {
  return [
    block.title,
    block.goal_text,
    block.context_json ? JSON.stringify(block.context_json) : "",
  ].join(" ");
}

function goalTargetIntentText(goalTargets: Record<string, any>[]) {
  return goalTargets.map((target) => [
    target.title,
    target.description,
    target.metric_key,
    target.metric_category,
    target.evaluation_rule_json ? JSON.stringify(target.evaluation_rule_json) : "",
  ].join(" ")).join(" ");
}

function containsAny(text: string, terms: string[]) {
  return terms.some((term) => text.includes(term));
}

function countBeforeTerms(text: string, terms: string[]) {
  const numberWords: Record<string, number> = { one: 1, two: 2, three: 3, four: 4, five: 5, six: 6 };
  let best = 0;

  for (const term of terms) {
    const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const digitMatch = text.match(new RegExp(`(\\d+)\\s+${escaped}\\b`));
    if (digitMatch) best = Math.max(best, Number(digitMatch[1]));

    for (const [word, count] of Object.entries(numberWords)) {
      if (new RegExp(`\\b${word}\\s+${escaped}\\b`).test(text)) {
        best = Math.max(best, count);
      }
    }
  }

  return best;
}

function actualWeeklyDimensionCounts(workouts: Record<string, any>[]): Partial<Record<TrainingDimension, number>> {
  const counts: Partial<Record<TrainingDimension, number>> = {};
  for (const workout of workouts) {
    const profile = trainingProfile(workout);
    for (const dimension of profile.dimensions) {
      counts[dimension] = (counts[dimension] ?? 0) + 1;
    }
  }
  return counts;
}

function goalDriftRisk(
  weekWorkouts: Record<string, any>[],
  rhythm: Record<string, any> | undefined,
  editedWorkout: Record<string, any>,
  edit: PlanEditInput,
  weekStart: Date,
): EditRisk | null {
  const oldWeekStart = startOfWeek(parseDateOnly(editedWorkout.scheduled_date) ?? new Date());
  const affectsOriginalWeek = oldWeekStart.getTime() === weekStart.getTime();
  const movedOut = ((edit.type === "delete_workout" || edit.type === "replace_workout") && affectsOriginalWeek) ||
    (edit.type === "move_workout" && oldWeekStart.getTime() === weekStart.getTime() && startOfWeek(parseDateOnly(edit.scheduled_date) ?? new Date()).getTime() !== weekStart.getTime());
  if (!movedOut) return null;

  const priorities = Array.isArray(rhythm?.priority_order_json) ? rhythm.priority_order_json.map((value: unknown) => String(value).toLowerCase()) : [];
  const expectedCount = priorities.length || 0;
  const activeCount = weekWorkouts.length;
  const editedText = `${editedWorkout.title ?? ""} ${editedWorkout.purpose ?? ""}`.toLowerCase();
  const wasPriority = priorities.some((priority: string) => editedText.includes(priority) || priority.includes(String(editedWorkout.title ?? "").toLowerCase()));
  const wasKeySession = /key|anchor|quality|progress|long|target|priority/.test(editedText);

  if ((expectedCount > 0 && activeCount < Math.max(2, Math.ceil(expectedCount * 0.75))) || wasPriority || wasKeySession) {
    return {
      kind: "goal_drift",
      severity: wasPriority || activeCount < 2 ? "high" : "medium",
      message: `This removes a planned ${editedWorkout.title} exposure from the week.`,
      affectedWorkoutIDs: [editedWorkout.id],
      dimensions: trainingProfile(editedWorkout).dimensions,
    };
  }
  return null;
}

function weeklyImbalanceRisk(
  weekWorkouts: Record<string, any>[],
  editedWorkout: Record<string, any>,
  edit: PlanEditInput,
  weekStart: Date,
): EditRisk | null {
  const oldWeekStart = startOfWeek(parseDateOnly(editedWorkout.scheduled_date) ?? new Date());
  const affectsOriginalWeek = oldWeekStart.getTime() === weekStart.getTime();
  const movedOut = ((edit.type === "delete_workout" || edit.type === "replace_workout") && affectsOriginalWeek) ||
    (edit.type === "move_workout" && oldWeekStart.getTime() === weekStart.getTime() && startOfWeek(parseDateOnly(edit.scheduled_date) ?? new Date()).getTime() !== weekStart.getTime());
  if (!movedOut) return null;

  const editedProfile = trainingProfile(editedWorkout);
  const weekProfiles = weekWorkouts.map(trainingProfile);
  const meaningfulLoadCount = weekProfiles.filter((profile) => profile.load !== "low" && !profile.dimensions.includes("recovery")).length;

  for (const dimension of editedProfile.dimensions) {
    const stillPresent = weekProfiles.some((profile) => profile.dimensions.includes(dimension));
    if (stillPresent) continue;
    if (dimension === "recovery" && meaningfulLoadCount < 2) continue;
    if (dimension === "skill" && editedProfile.load === "low") continue;

    return {
      kind: "weekly_imbalance",
      severity: dimension === "recovery" ? "medium" : "high",
      message: `This leaves the week without ${dimensionLabel(dimension)} support.`,
      affectedWorkoutIDs: [editedWorkout.id],
      dimensions: [dimension],
      weekStartDate: isoDate(weekStart),
      expectedCount: 1,
      actualCount: 0,
      missingCount: 1,
    };
  }
  return null;
}

function fallbackEditRepair(args: {
  block: Record<string, any>;
  workouts: Record<string, any>[];
  rhythms: Record<string, any>[];
  editedWorkout: Record<string, any>;
  edit: PlanEditInput;
  risks: EditRisk[];
  today: Date;
}): EditRepairPlan {
  const { block, workouts, rhythms, editedWorkout, edit, risks, today } = args;
  const mutations = buildRepairMutations(block, workouts, rhythms, editedWorkout, edit, risks, today);
  const reason = risks[0]?.message || "This edit changes the balance of the week.";
  const summary = mutations.length > 0
    ? repairSummaryForMutation(mutations[0])
    : "I recommend keeping the edit visible as a coach review item and watching the next plan refresh.";

  return { reason, summary, risks, mutations };
}

function buildRepairMutations(
  block: Record<string, any>,
  workouts: Record<string, any>[],
  rhythms: Record<string, any>[],
  editedWorkout: Record<string, any>,
  edit: PlanEditInput,
  risks: EditRisk[],
  today: Date,
): Array<Record<string, unknown>> {
  const mutations: Array<Record<string, unknown>> = [];
  const oldWeekStart = startOfWeek(parseDateOnly(editedWorkout.scheduled_date) ?? new Date());
  const createdSupport = new Set<string>();

  for (const risk of risks.filter((item) => item.kind === "weekly_imbalance" && item.weekStartDate)) {
    const weekStart = parseDateOnly(risk.weekStartDate) ?? oldWeekStart;
    const rhythm = rhythms.find((item) => item.week_start_date === isoDate(weekStart));
    const dimension = risk.dimensions[0] ?? trainingProfile(editedWorkout).dimensions[0] ?? "endurance";
    const key = `${isoDate(weekStart)}:${dimension}`;
    if (createdSupport.has(key)) continue;
    createdSupport.add(key);

    const mutableWeekWorkouts = workoutsForWeek(auditEligibleWorkouts(workouts, today), weekStart);
    const neededCount = Math.max(1, Math.min(2, risk.missingCount ?? 1));
    for (let index = 0; index < neededCount; index += 1) {
      const openDate = findRepairDate(weekStart, mutableWeekWorkouts, today);
      if (!openDate) break;

      const mutation = createSupportWorkoutMutation({
        block,
        rhythm,
        weekWorkouts: mutableWeekWorkouts,
        openDate,
        dimension,
        sourceWorkout: editedWorkout,
      });
      mutations.push(mutation);
      mutableWeekWorkouts.push({
        id: `repair-${key}-${index}`,
        ...(mutation.fields as Record<string, unknown>),
      });
    }
  }

  const affectedIDs = new Set(risks.flatMap((risk) => risk.affectedWorkoutIDs));
  const candidate = workouts.find((workout) => affectedIDs.has(workout.id) && workout.id !== editedWorkout.id && canMutateWorkout(workout, today)) ??
    workouts.find((workout) => affectedIDs.has(workout.id) && canMutateWorkout(workout, today));
  if (!candidate) return mutations.slice(0, 3);

  const weekStart = startOfWeek(parseDateOnly(candidate.scheduled_date) ?? oldWeekStart);
  const weekWorkouts = workoutsForWeek(auditEligibleWorkouts(workouts, today), weekStart);
  const openDate = findRepairDate(weekStart, weekWorkouts, today);
  if (openDate) {
    if (!mutations.some((mutation) => mutation.type === "update_workout" && mutation.workout_id === candidate.id)) {
      mutations.push({
        type: "update_workout",
        workout_id: candidate.id,
        workout_title: candidate.title,
        from_scheduled_date: candidate.scheduled_date,
        fields: {
          scheduled_date: openDate,
          sequence_order: nextSequenceOrderForDate(weekWorkouts, openDate),
          source: "replanned",
        },
      });
    }
    return mutations.slice(0, 3);
  }

  if (!mutations.some((mutation) => mutation.type === "update_workout" && mutation.workout_id === candidate.id)) {
    mutations.push({
      type: "update_workout",
      workout_id: candidate.id,
      workout_title: candidate.title,
      from_scheduled_date: candidate.scheduled_date,
      fields: {
        duration_minutes: Math.max(20, Math.round((candidate.duration_minutes ?? 30) * 0.75)),
        intensity_label: "Low",
        purpose: candidate.purpose || "Reduce load while preserving the weekly rhythm",
        source: "replanned",
        prescription_json: {
          ...(candidate.prescription_json ?? {}),
          adjustment: "Lower dose to reduce clustered weekly load after a plan edit.",
        },
      },
    });
  }

  return mutations.slice(0, 3);
}

function createSupportWorkoutMutation(args: {
  block: Record<string, any>;
  rhythm: Record<string, any> | undefined;
  weekWorkouts: Record<string, any>[];
  openDate: string;
  dimension: TrainingDimension;
  sourceWorkout: Record<string, any>;
}) {
  const { block, rhythm, weekWorkouts, openDate, dimension, sourceWorkout } = args;
  const activityType = supportActivityType(dimension, sourceWorkout);
  const title = supportTitle(dimension, sourceWorkout);
  const duration = dimension === "recovery" ? 25 : Math.max(30, Math.min(60, sourceWorkout.duration_minutes ?? 45));
  const intensity = dimension === "recovery" ? "Low" : "Moderate";

  return {
    type: "create_workout",
    source_workout_title: sourceWorkout.title ?? null,
    source_scheduled_date: sourceWorkout.scheduled_date ?? null,
    fields: {
      active_block_id: null,
      weekly_rhythm_id: null,
      weekly_plan_id: rhythm?.weekly_plan_id ?? rhythm?.id ?? sourceWorkout.weekly_plan_id ?? null,
      scheduled_date: openDate,
      sequence_order: nextSequenceOrderForDate(weekWorkouts, openDate),
      activity_type: activityType,
      title,
      duration_minutes: duration,
      intensity_label: intensity,
      purpose: dimension === "recovery" ? "Restore recovery support after the edit" : `Restore ${dimensionLabel(dimension)} exposure for the week`,
      status: "planned",
      source: "replanned",
      fueling_summary: fuelingSummary(activityType, intensity),
      prescription_json: fallbackPrescription(title, activityType, intensity),
    },
  };
}

function supportActivityType(dimension: TrainingDimension, sourceWorkout: Record<string, any>) {
  if (dimension === "neuromuscular") return "strength";
  if (dimension === "endurance") {
    const source = normalizeActivity(`${sourceWorkout.activity_type ?? ""} ${sourceWorkout.title ?? ""}`);
    return ["ride", "run", "swim", "row", "hike"].includes(source) ? source : "ride";
  }
  if (dimension === "recovery") return "mobility";
  return normalizeActivity(`${sourceWorkout.activity_type ?? ""} ${sourceWorkout.title ?? ""}`) || "mobility";
}

function supportTitle(dimension: TrainingDimension, sourceWorkout: Record<string, any>) {
  if (dimension === "neuromuscular") return "Full Body A";
  if (dimension === "endurance") return "Base Ride";
  if (dimension === "recovery") return "Mobility";
  return sourceWorkout.title ? `${sourceWorkout.title} support` : "Skill support";
}

async function runEditRepairDraft(context: Record<string, unknown>, model: string): Promise<PlanEditRepairDraft> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const touchpointConfig = planningAITouchpoint("plan_edit_repair");
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(responsesRequestPayload(
      model,
      touchpointConfig,
      {
        task: "draft_plan_edit_repair",
        context,
        rules: touchpointConfig.userRules,
      },
      {
        type: "json_schema",
        name: "plan_edit_repair",
        strict: true,
        schema: editRepairSchema,
      },
    )),
  });

  const payload = await response.json();
  if (!response.ok) throw new Error(payload?.error?.message ?? "OpenAI request failed");
  const outputText = extractOutputText(payload);
  if (!outputText) throw new Error("OpenAI returned no plan-edit repair output");
  return JSON.parse(outputText) as PlanEditRepairDraft;
}

async function recommendWorkoutReplacements(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const plannedWorkoutID = requestBody.plannedWorkoutID ?? requestBody.planned_workout_id;
  if (!plannedWorkoutID) {
    throw new Error("recommend_workout_replacements requires plannedWorkoutID");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  const workout = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, plannedWorkoutID);
  const window = twoWeekWindow(parseDateOnly(workout.scheduled_date) ?? new Date());
  const weeklyPlans = await visibleWeeklyPlans(admin, userID, scope.strategy.id, window);
  const planIDs = weeklyPlans.map((plan: Record<string, any>) => plan.id);
  const surroundingWorkouts = await list(
    admin
      .from("planned_workouts")
      .select()
      .eq("user_id", userID)
      .in("weekly_plan_id", planIDs.length > 0 ? planIDs : ["00000000-0000-0000-0000-000000000000"])
      .gte("scheduled_date", window.start)
      .lte("scheduled_date", window.end)
      .not("status", "in", "(deleted,superseded)")
      .order("scheduled_date", { ascending: true })
      .order("sequence_order", { ascending: true }),
  );
  const phases = await list(
    admin
      .from("fitness_strategy_phases")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .order("sequence_order", { ascending: true }),
  );

  const context = {
    block: scope.block,
    strategy: scope.strategy,
    workoutToReplace: workout,
    surroundingWorkouts,
    phases,
    weeklyRhythms: weeklyPlans.map(weeklyPlanAsRhythm),
    userIntent: requestBody.textContext || "I do not want to do this workout in this slot.",
    window,
    weatherContext: await planningWeatherContextForDate(scope, workout.scheduled_date, workout.planned_location_label, workout.weather_forecast_json),
  };

  const candidates = sanitizeReplacementCandidates(await runReplacementGeneration(context, model), workout, surroundingWorkouts, context.weatherContext);

  return {
    userID,
    model,
    workoutID: plannedWorkoutID,
    candidates,
  };
}

async function recommendWorkoutAdditions(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const scheduledDate = requestBody.scheduledDate ?? requestBody.scheduled_date;
  if (!scheduledDate) {
    throw new Error("recommend_workout_additions requires scheduledDate");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  throwIfPastPlanningDate(scheduledDate, scope.timezone || "UTC");
  const context = {
    ...await loadWorkoutPlanningContext(admin, userID, scope, scheduledDate),
    userIntent: requestBody.textContext || "I feel like working out on this day, but I want HAYF to pick something that fits the plan.",
  };

  const candidates = sanitizeWorkoutCandidates(
    await runWorkoutAdditionGeneration(
      context,
      model,
    ),
    fallbackAdditionCandidates(context),
  );

  return {
    userID,
    model,
    scheduledDate,
    candidates,
  };
}

async function interpretWorkoutDescription(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const textContext = requestBody.textContext?.trim();
  if (!textContext) {
    throw new Error("Describe the workout you want to add.");
  }
  if (!looksLikeWorkoutDescription(textContext)) {
    throw new Error("Describe a workout with a sport or modality, plus useful size or effort detail.");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  const plannedWorkoutID = requestBody.plannedWorkoutID ?? requestBody.planned_workout_id;
  const scheduledDate = requestBody.scheduledDate ?? requestBody.scheduled_date;
  let workout: Record<string, any> | null = null;
  let contextDate = scheduledDate;

  if (plannedWorkoutID) {
    const loadedWorkout = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, plannedWorkoutID);
    workout = loadedWorkout;
    contextDate = loadedWorkout.scheduled_date;
  }
  if (!contextDate) {
    throw new Error("interpret_workout_description requires plannedWorkoutID or scheduledDate");
  }

  throwIfPastPlanningDate(contextDate, scope.timezone || "UTC");
  const planningContext = await loadWorkoutPlanningContext(admin, userID, scope, contextDate);
  const context = {
    ...planningContext,
    workoutToReplace: workout,
    userIntent: textContext,
  };

  let candidate = sanitizeWorkoutCandidate(
    (await runWorkoutDescriptionInterpretation(context, model)).candidate,
    fallbackManualWorkoutCandidate(textContext, workout ?? undefined, contextDate),
    "candidate-1",
  );
  candidate = withResolvedWorkoutIntent(candidate, textContext, scope.homeLocationLabel);

  return {
    userID,
    model,
    scheduledDate: contextDate,
    workoutID: plannedWorkoutID ?? null,
    candidate,
  };
}

async function replaceWorkout(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const plannedWorkoutID = requestBody.plannedWorkoutID ?? requestBody.planned_workout_id;
  const candidate = requestBody.replacementCandidate ?? requestBody.replacement_candidate;
  if (!plannedWorkoutID || !candidate) {
    throw new Error("replace_workout requires plannedWorkoutID and replacementCandidate");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  const workout = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, plannedWorkoutID);
  const status = workout.status === "current" ? "current" : "planned";
  const candidateLocationLabel = resolvedCandidateLocationLabel(candidate);

  await throwOnError(
    admin
      .from("planned_workouts")
      .update({
        status: "superseded",
        source: workout.source,
        generation_key: null,
        version: (workout.version ?? 1) + 1,
      })
      .eq("id", workout.id),
  );

  const replacement = await single(
    admin
      .from("planned_workouts")
      .insert({
        active_block_id: null,
        weekly_rhythm_id: null,
        weekly_plan_id: workout.weekly_plan_id ?? null,
        generation_key: null,
        user_id: userID,
        scheduled_date: workout.scheduled_date,
        sequence_order: workout.sequence_order,
        activity_type: normalizeActivity(candidate.activityType),
        title: normalizedWorkoutTitle(
          candidate.activityType,
          candidate.title,
          Math.max(10, candidate.durationMinutes || workout.duration_minutes || 30),
          candidate.intensityLabel || workout.intensity_label || "Moderate",
          candidate.purpose || workout.purpose || "Replacement workout",
        ),
        duration_minutes: Math.max(10, candidate.durationMinutes || workout.duration_minutes || 30),
        intensity_label: candidate.intensityLabel || workout.intensity_label || "Moderate",
        purpose: candidate.purpose || workout.purpose || "Replacement workout",
        ...workoutCardFields({
          scheduledDate: workout.scheduled_date,
          activityType: candidate.activityType,
          title: candidate.title,
          durationMinutes: Math.max(10, candidate.durationMinutes || workout.duration_minutes || 30),
          intensityLabel: candidate.intensityLabel || workout.intensity_label || "Moderate",
          purpose: candidate.purpose || workout.purpose || "Replacement workout",
          locationLabel: candidateLocationLabel ?? workout.planned_location_label ?? scope.homeLocationLabel,
          distanceKilometers: candidate.estimatedDistanceKilometers ?? null,
          elevationMeters: candidate.estimatedElevationMeters ?? null,
        }),
        status,
        source: "replanned",
        prescription_json: {
          ...(candidate.prescription ?? {}),
          replacementForWorkoutID: workout.id,
          rationale: candidate.rationale ?? null,
          weeklyImpact: candidate.weeklyImpact ?? null,
          plannedLocationLabel: candidateLocationLabel,
        },
        fueling_summary: candidate.fuelingSummary || workout.fueling_summary,
        original_workout_id: workout.id,
        version: 1,
      })
      .select()
      .single(),
    "Could not insert replacement workout",
  );

  const event = await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: scope.strategy.id,
    weeklyPlanID: workout.weekly_plan_id ?? null,
    plannedWorkoutID: replacement.id,
    eventType: "workout_moved",
    payload: {
      action: "workout_replaced",
      originalWorkoutID: workout.id,
      replacementWorkoutID: replacement.id,
      candidate,
    },
  });

  const edit: PlanEditInput = {
    type: "replace_workout",
    planned_workout_id: workout.id,
    replacement_workout_id: replacement.id,
    scheduled_date: replacement.scheduled_date,
  };
  const repairPolicy = requestedRepairPolicy(requestBody);
  const repair = repairPolicy === "deferred"
    ? null
    : await buildPlanEditRepair(admin, userID, scope, workout, edit, model, requestBody.deviceTimezone || scope.timezone || "UTC");
  const proposal = repair && repairPolicy === "immediate"
    ? await createPlanEditRepairProposal(admin, userID, scope.strategy.id, event.id, repair)
    : null;
  if (!proposal || repairPolicy === "deferred") {
    await expirePendingReplanProposals(admin, userID, scope.strategy.id);
  }
  await markCurrentWorkoutForStrategy(admin, userID, scope.strategy.id, dateOnlyInTimezone(new Date(), requestBody.deviceTimezone || scope.timezone || "UTC"));
  return {
    userID,
    eventID: event.id,
    originalWorkoutID: workout.id,
    replacementWorkout: replacement,
    proposalID: proposal?.id ?? null,
    reason: repair?.reason ?? null,
    summary: repair?.summary ?? null,
    risks: repair?.risks ?? [],
    mutationCount: repair?.mutations.length ?? 0,
    reviewHint: repair && repairPolicy === "deferred" ? reviewHintFromRepair(repair) : null,
    proposal: proposal
      ? {
        id: proposal.id,
        active_block_id: proposal.active_block_id,
        trigger_event_id: proposal.trigger_event_id,
        reason: proposal.reason,
        proposed_mutations_json: proposal.proposed_mutations_json,
        status: proposal.status,
        created_at: proposal.created_at,
        updated_at: proposal.updated_at,
      }
      : null,
  };
}

async function addWorkout(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const scheduledDate = requestBody.scheduledDate ?? requestBody.scheduled_date;
  const rawCandidate = requestBody.workoutCandidate ?? requestBody.workout_candidate ?? requestBody.replacementCandidate ?? requestBody.replacement_candidate;
  if (!scheduledDate || !rawCandidate) {
    throw new Error("add_workout requires scheduledDate and workoutCandidate");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  throwIfPastPlanningDate(scheduledDate, scope.timezone || "UTC");
  const context = await loadWorkoutPlanningContext(admin, userID, scope, scheduledDate);
  const candidate = sanitizeWorkoutCandidate(rawCandidate, fallbackAdditionCandidates(context)[0], "candidate-1");
  const candidateLocationLabel = resolvedCandidateLocationLabel(candidate);
  const sequenceOrder = requestBody.sequenceOrder ?? requestBody.sequence_order ??
    nextSequenceOrderForDate(context.surroundingWorkouts, scheduledDate);

  const addedWorkout = await single(
    admin
      .from("planned_workouts")
      .insert({
        active_block_id: null,
        weekly_rhythm_id: null,
        weekly_plan_id: context.weeklyPlan?.id ?? null,
        generation_key: null,
        user_id: userID,
        scheduled_date: scheduledDate,
        sequence_order: sequenceOrder,
        activity_type: normalizeActivity(candidate.activityType),
        title: normalizedWorkoutTitle(
          candidate.activityType,
          candidate.title,
          Math.max(10, candidate.durationMinutes || 30),
          candidate.intensityLabel || "Moderate",
          candidate.purpose || "User-added workout",
        ),
        duration_minutes: Math.max(10, candidate.durationMinutes || 30),
        intensity_label: candidate.intensityLabel || "Moderate",
        purpose: candidate.purpose || "User-added workout",
        ...workoutCardFields({
          scheduledDate,
          activityType: candidate.activityType,
          title: candidate.title,
          durationMinutes: Math.max(10, candidate.durationMinutes || 30),
          intensityLabel: candidate.intensityLabel || "Moderate",
          purpose: candidate.purpose || "User-added workout",
          locationLabel: candidateLocationLabel ?? scope.homeLocationLabel,
          distanceKilometers: candidate.estimatedDistanceKilometers ?? null,
          elevationMeters: candidate.estimatedElevationMeters ?? null,
        }),
        status: "planned",
        source: "user_added",
        prescription_json: {
          ...(candidate.prescription ?? {}),
          addedFrom: "plan_day_add",
          rationale: candidate.rationale ?? null,
          weeklyImpact: candidate.weeklyImpact ?? null,
          plannedLocationLabel: candidateLocationLabel,
        },
        fueling_summary: candidate.fuelingSummary || fuelingSummary(candidate.activityType, candidate.intensityLabel),
        version: 1,
      })
      .select()
      .single(),
    "Could not insert added workout",
  );

  const event = await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: scope.strategy.id,
    weeklyPlanID: context.weeklyPlan?.id ?? null,
    plannedWorkoutID: addedWorkout.id,
    eventType: "workout_added",
    payload: {
      action: "workout_added",
      addedWorkoutID: addedWorkout.id,
      scheduledDate,
      candidate,
    },
  });

  const edit: PlanEditInput = {
    type: "add_workout",
    added_workout_id: addedWorkout.id,
    scheduled_date: addedWorkout.scheduled_date,
  };
  const repairPolicy = requestedRepairPolicy(requestBody);
  const repair = repairPolicy === "deferred"
    ? null
    : await buildPlanEditRepair(admin, userID, scope, addedWorkout, edit, model, requestBody.deviceTimezone || scope.timezone || "UTC");
  const proposal = repair && repairPolicy === "immediate"
    ? await createPlanEditRepairProposal(admin, userID, scope.strategy.id, event.id, repair)
    : null;
  if (!proposal || repairPolicy === "deferred") {
    await expirePendingReplanProposals(admin, userID, scope.strategy.id);
  }
  await markCurrentWorkoutForStrategy(admin, userID, scope.strategy.id, dateOnlyInTimezone(new Date(), requestBody.deviceTimezone || scope.timezone || "UTC"));

  return {
    userID,
    eventID: event.id,
    addedWorkout,
    proposalID: proposal?.id ?? null,
    reason: repair?.reason ?? null,
    summary: repair?.summary ?? null,
    risks: repair?.risks ?? [],
    mutationCount: repair?.mutations.length ?? 0,
    reviewHint: repair && repairPolicy === "deferred" ? reviewHintFromRepair(repair) : null,
    proposal: proposal
      ? {
        id: proposal.id,
        active_block_id: proposal.active_block_id,
        trigger_event_id: proposal.trigger_event_id,
        reason: proposal.reason,
        proposed_mutations_json: proposal.proposed_mutations_json,
        status: proposal.status,
        created_at: proposal.created_at,
        updated_at: proposal.updated_at,
      }
      : null,
  };
}

async function applyReplanProposal(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  const proposalID = requestBody.proposalID ?? requestBody.proposal_id;
  if (!proposalID || !requestBody.decision) {
    throw new Error("apply_replan_proposal requires proposalID and decision");
  }

  const proposal = await single(
    admin
      .from("replan_proposals")
      .select()
      .eq("id", proposalID)
      .eq("user_id", userID)
      .single(),
    "Replan proposal not found",
  );

  if (proposal.status !== "pending") {
    throw new Error("Only pending proposals can be applied");
  }

  if (requestBody.decision === "accepted") {
    await applyProposalMutations(admin, userID, proposal);
  }

  await throwOnError(
    admin
      .from("replan_proposals")
      .update({ status: requestBody.decision })
      .eq("id", proposal.id),
  );

  await expirePendingReplanProposals(admin, userID, proposal.fitness_strategy_id ?? proposal.active_block_id, proposal.id);

  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: proposal.active_block_id,
    fitnessStrategyID: proposal.fitness_strategy_id ?? null,
    weeklyPlanID: proposal.weekly_plan_id ?? null,
    eventType: requestBody.decision === "accepted" ? "proposal_accepted" : "proposal_rejected",
    payload: { proposalID: proposal.id },
  });

  return { userID, proposalID: proposal.id, decision: requestBody.decision, eventID: event.id };
}

async function createRepairProposalForRecentEdit(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const eventID = requestBody.eventID ?? requestBody.event_id;
  if (!eventID) {
    throw new Error("create_repair_proposal_for_recent_edit requires eventID");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  const event = await single(
    admin
      .from("plan_events")
      .select()
      .eq("id", eventID)
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .single(),
    "Plan edit event not found",
  );

  const payload = event.payload_json ?? {};
  const reconstructed = await reconstructPlanEditFromEvent(admin, userID, scope, event, payload);
  const repair = await buildPlanEditRepair(
    admin,
    userID,
    scope,
    reconstructed.editedWorkout,
    reconstructed.edit,
    model,
    requestBody.deviceTimezone || scope.timezone || "UTC",
  );

  const proposal = repair
    ? await createPlanEditRepairProposal(admin, userID, scope.strategy.id, event.id, repair)
    : null;
  if (!proposal) {
    await expirePendingReplanProposals(admin, userID, scope.strategy.id);
  }

  return {
    userID,
    eventID: event.id,
    proposalID: proposal?.id ?? null,
    reason: repair?.reason ?? null,
    summary: repair?.summary ?? null,
    risks: repair?.risks ?? [],
    mutationCount: repair?.mutations.length ?? 0,
    reviewHint: repair && !proposal ? reviewHintFromRepair(repair) : null,
    proposal: proposal
      ? {
        id: proposal.id,
        active_block_id: proposal.active_block_id,
        trigger_event_id: proposal.trigger_event_id,
        reason: proposal.reason,
        proposed_mutations_json: proposal.proposed_mutations_json,
        status: proposal.status,
        created_at: proposal.created_at,
        updated_at: proposal.updated_at,
      }
      : null,
  };
}

async function createRepairProposalForPendingEdits(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const scope = await loadActivePlanningScope(admin, userID);
  const timezone = requestBody.deviceTimezone || scope.timezone || "UTC";
  const start = parseDateOnly(requestBody.windowStart) ?? firstCommittedWeekStart(new Date(), timezone);
  const window = twoWeekWindow(start);
  const weeklyPlans = (await visibleWeeklyPlans(admin, userID, scope.strategy.id, window))
    .filter((plan: Record<string, any>) => plan.status === "committed" || plan.status === "draft");
  const weeklyPlanIDs = weeklyPlans.map((plan: Record<string, any>) => plan.id);

  if (weeklyPlanIDs.length === 0) {
    return { userID, model: "deterministic", reviewed: false, pendingEditCount: 0, proposalID: null, proposal: null };
  }

  const pendingProposal = await maybeSingle(
    admin
      .from("replan_proposals")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", scope.strategy.id)
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(1),
  );
  if (pendingProposal && Array.isArray(pendingProposal.proposed_mutations_json) && pendingProposal.proposed_mutations_json.length > 0) {
    return {
      userID,
      model: "deterministic",
      reviewed: false,
      pendingEditCount: 0,
      proposalID: pendingProposal.id,
      proposal: proposalResponse(pendingProposal),
    };
  }

  const checkpoint = await latestPlanReviewCheckpoint(admin, userID, scope.strategy.id);
  let eventQuery = admin
    .from("plan_events")
    .select()
    .eq("user_id", userID)
    .eq("fitness_strategy_id", scope.strategy.id)
    .in("weekly_plan_id", weeklyPlanIDs)
    .in("event_type", pendingReviewEditEventTypes())
    .order("created_at", { ascending: true })
    .limit(50);
  if (checkpoint?.created_at) {
    eventQuery = eventQuery.gt("created_at", checkpoint.created_at);
  }
  const pendingEvents = await list(eventQuery);

  if (pendingEvents.length === 0) {
    return { userID, model: "deterministic", reviewed: false, pendingEditCount: 0, proposalID: null, proposal: null };
  }

  const [workouts, goalTargets] = await Promise.all([
    list(
      admin
        .from("planned_workouts")
        .select()
        .eq("user_id", userID)
        .in("weekly_plan_id", weeklyPlanIDs)
        .gte("scheduled_date", window.start)
        .lte("scheduled_date", window.end)
        .in("status", ["planned", "current", "checked_in", "adjusted", "done"])
        .order("scheduled_date", { ascending: true })
        .order("sequence_order", { ascending: true }),
    ),
    list(
      admin
        .from("planning_targets")
        .select("id,target_scope,weekly_plan_id,target_kind,title,description,metric_key,metric_category,evaluation_rule_json,status")
        .eq("user_id", userID)
        .eq("fitness_strategy_id", scope.strategy.id)
        .in("status", ["on_track", "lagging", "needs_review"]),
    ),
  ]);

  const today = todayInTimezone(timezone);
  const reviewContext = {
      strategy: {
        id: scope.strategy.id,
        title: scope.strategy.title,
        summary: scope.strategy.summary,
        rationale: scope.strategy.rationale,
        context: scope.strategy.context_json ?? {},
      },
      goal: scope.goal,
      window,
      today: isoDate(today),
      weeklyPlans: weeklyPlans.map(compactWeeklyPlanForReview),
      workouts: workouts.map(compactWorkoutForReview),
      targets: goalTargets,
      pendingEvents: pendingEvents.map(compactPlanEventForReview),
      rules: [
        "The user's edits are facts. Do not revert moved, deleted, replaced, added, or availability changes.",
        "Only propose small surrounding adjustments needed to keep the committed/draft window aligned with the strategy.",
        "Do not create, update, move, or delete workouts before today. If the best theoretical repair is in the past, choose a today/future repair or return no mutations.",
        "Return no mutations when the edited plan is acceptable.",
        "Use at most four mutations.",
      ],
  };
  let draft = await runPendingPlanReview(reviewContext, model);

  const reviewedEventIDs = pendingEvents.map((event: Record<string, any>) => event.id);
  const protectedWorkoutIDs = protectedWorkoutIDsFromEvents(pendingEvents);
  let mutations: Array<Record<string, unknown>>;
  try {
    mutations = validatePendingPlanReviewMutations({
      draft,
      weeklyPlans,
      workouts,
      protectedWorkoutIDs,
      window,
      timezone,
      homeLocationLabel: scope.homeLocationLabel,
    });
  } catch (error) {
    draft = await runPendingPlanReview(
      {
        ...reviewContext,
        validationError: errorMessage(error),
        correctionRules: [
          "Return a corrected proposal that satisfies the validation error.",
          "Never schedule or mutate workouts before today.",
          "If no valid today/future repair exists, set reviewNeeded false and return no mutations.",
        ],
      },
      model,
    );
    mutations = validatePendingPlanReviewMutations({
      draft,
      weeklyPlans,
      workouts,
      protectedWorkoutIDs,
      window,
      timezone,
      homeLocationLabel: scope.homeLocationLabel,
    });
  }

  if (draft.reviewNeeded && draft.mutations.length > 0 && mutations.length === 0) {
    throw new Error("Plan review proposed an adjustment, but it did not produce an actionable mutation. Try review again.");
  }

  if (!draft.reviewNeeded || mutations.length === 0) {
    const event = await createPlanEvent(admin, {
      userID,
      fitnessStrategyID: scope.strategy.id,
      eventType: "plan_review_completed",
      payload: {
        window,
        reviewedEventIDs,
        editCount: pendingEvents.length,
        reason: draft.reason,
        summary: draft.summary,
        confidence: draft.confidence,
        notes: draft.notes,
        mutationCount: 0,
      },
    });
    return {
      userID,
      model,
      reviewed: true,
      pendingEditCount: pendingEvents.length,
      eventID: event.id,
      proposalID: null,
      proposal: null,
      reason: draft.reason,
      summary: draft.summary,
      mutationCount: 0,
    };
  }

  const proposal = await createReplanProposal(admin, {
    userID,
    fitnessStrategyID: scope.strategy.id,
    triggerEventID: pendingEvents[pendingEvents.length - 1]?.id ?? null,
    reason: draft.reason?.trim() || "HAYF found a few adjustments to keep this plan aligned.",
    mutations,
    metadata: {
      type: "pending_plan_edit_review",
      window,
      reviewedEventIDs,
      editCount: pendingEvents.length,
      summary: draft.summary,
      confidence: draft.confidence,
      notes: draft.notes,
    },
  });

  return {
    userID,
    model,
    reviewed: true,
    pendingEditCount: pendingEvents.length,
    proposalID: proposal.id,
    reason: proposal.reason,
    summary: draft.summary,
    mutationCount: mutations.length,
    proposal: proposalResponse(proposal),
  };
}

async function reconstructPlanEditFromEvent(
  admin: SupabaseAdminClient,
  userID: string,
  scope: PlanningScope,
  event: Record<string, any>,
  payload: Record<string, any>,
): Promise<{ editedWorkout: Record<string, any>; edit: PlanEditInput }> {
  if (payload.action === "workout_replaced") {
    const originalWorkoutID = String(payload.originalWorkoutID ?? payload.original_workout_id ?? "");
    const replacementWorkoutID = String(payload.replacementWorkoutID ?? payload.replacement_workout_id ?? event.planned_workout_id ?? "");
    if (!originalWorkoutID || !replacementWorkoutID) {
      throw new Error("Replacement event is missing workout IDs");
    }
    const original = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, originalWorkoutID);
    const replacement = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, replacementWorkoutID);
    return {
      editedWorkout: original,
      edit: {
        type: "replace_workout",
        planned_workout_id: original.id,
        replacement_workout_id: replacement.id,
        scheduled_date: replacement.scheduled_date,
      },
    };
  }

  if (event.event_type === "workout_added") {
    const addedWorkoutID = String(payload.addedWorkoutID ?? payload.added_workout_id ?? event.planned_workout_id ?? "");
    if (!addedWorkoutID) {
      throw new Error("Add event is missing workout ID");
    }
    const added = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, addedWorkoutID);
    return {
      editedWorkout: added,
      edit: {
        type: "add_workout",
        added_workout_id: added.id,
        scheduled_date: added.scheduled_date,
      },
    };
  }

  if (event.event_type === "workout_deleted") {
    const deletedWorkout = payload.deletedWorkout as Record<string, any> | undefined;
    const workoutID = String(deletedWorkout?.id ?? event.planned_workout_id ?? "");
    const editedWorkout = deletedWorkout ?? await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, workoutID);
    return {
      editedWorkout,
      edit: {
        type: "delete_workout",
        planned_workout_id: String(editedWorkout.id),
      },
    };
  }

  if (event.event_type === "workout_moved") {
    const workoutID = String(event.planned_workout_id ?? "");
    if (!workoutID) {
      throw new Error("Move event is missing workout ID");
    }
    const workout = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, workoutID);
    const from = String(payload.from ?? workout.scheduled_date);
    const to = String(payload.to ?? workout.scheduled_date);
    return {
      editedWorkout: { ...workout, scheduled_date: from },
      edit: {
        type: "move_workout",
        planned_workout_id: workout.id,
        scheduled_date: to,
        sequence_order: workout.sequence_order,
      },
    };
  }

  throw new Error("Only recent workout edit events can create a repair proposal");
}

function pendingReviewEditEventTypes() {
  return ["workout_moved", "workout_deleted", "workout_added", "weekly_plan_constraint_recorded"];
}

async function latestPlanReviewCheckpoint(admin: SupabaseAdminClient, userID: string, strategyID: string) {
  return maybeSingle(
    admin
      .from("plan_events")
      .select("id,event_type,created_at")
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .in("event_type", ["proposal_created", "proposal_accepted", "proposal_rejected", "plan_review_completed"])
      .order("created_at", { ascending: false })
      .limit(1),
  );
}

async function latestManualReviewResolutionCheckpoint(admin: SupabaseAdminClient, userID: string, strategyID: string) {
  return maybeSingle(
    admin
      .from("plan_events")
      .select("id,event_type,created_at")
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .in("event_type", ["proposal_accepted", "proposal_rejected", "plan_review_completed"])
      .order("created_at", { ascending: false })
      .limit(1),
  );
}

function compactWeeklyPlanForReview(plan: Record<string, any>) {
  return {
    id: plan.id,
    weekStartDate: plan.week_start_date,
    weekEndDate: plan.week_end_date,
    status: plan.status,
    objective: plan.objective,
    rhythm: plan.rhythm_json ?? {},
    constraints: plan.constraints_json ?? {},
  };
}

function compactWorkoutForReview(workout: Record<string, any>) {
  return {
    ...compactWorkoutForRepair(workout),
    weeklyPlanID: workout.weekly_plan_id ?? null,
    sequenceOrder: workout.sequence_order ?? null,
    source: workout.source ?? null,
    fuelingSummary: workout.fueling_summary ?? null,
  };
}

function compactPlanEventForReview(event: Record<string, any>) {
  return {
    id: event.id,
    type: event.event_type,
    weeklyPlanID: event.weekly_plan_id ?? null,
    plannedWorkoutID: event.planned_workout_id ?? null,
    createdAt: event.created_at,
    payload: event.payload_json ?? {},
  };
}

function protectedWorkoutIDsFromEvents(events: Record<string, any>[]) {
  const ids = new Set<string>();
  for (const event of events) {
    if (event.planned_workout_id) ids.add(String(event.planned_workout_id));
    const payload = event.payload_json ?? {};
    for (const key of ["originalWorkoutID", "original_workout_id", "replacementWorkoutID", "replacement_workout_id", "addedWorkoutID", "added_workout_id"]) {
      if (payload[key]) ids.add(String(payload[key]));
    }
    const deletedWorkout = payload.deletedWorkout ?? payload.deleted_workout;
    if (deletedWorkout?.id) ids.add(String(deletedWorkout.id));
  }
  return ids;
}

async function runPendingPlanReview(context: Record<string, unknown>, model: string): Promise<PendingPlanReviewDraft> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const touchpointConfig = planningAITouchpoint("pending_plan_review");
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(responsesRequestPayload(
      model,
      touchpointConfig,
      {
        task: "review_pending_plan_edits",
        context,
        mutation_contract: touchpointConfig.userRules,
      },
      {
        type: "json_schema",
        name: "pending_plan_review",
        strict: true,
        schema: pendingPlanReviewSchema,
      },
    )),
  });

  const payload = await response.json();
  if (!response.ok) throw new Error(payload?.error?.message ?? "OpenAI request failed");
  const outputText = extractOutputText(payload);
  if (!outputText) throw new Error("OpenAI returned no pending plan review output");
  return JSON.parse(outputText) as PendingPlanReviewDraft;
}

function validatePendingPlanReviewMutations(args: {
  draft: PendingPlanReviewDraft;
  weeklyPlans: Record<string, any>[];
  workouts: Record<string, any>[];
  protectedWorkoutIDs: Set<string>;
  window: { start: string; end: string };
  timezone: string;
  homeLocationLabel?: string | null;
}) {
  const { draft, weeklyPlans, workouts, protectedWorkoutIDs, window, timezone, homeLocationLabel } = args;
  if (!draft.reviewNeeded) return [];
  if (!Array.isArray(draft.mutations)) {
    throw new Error("Plan review returned invalid mutations.");
  }

  const normalized: Array<Record<string, unknown>> = [];
  for (const mutation of draft.mutations.slice(0, 4)) {
    if (!mutation || typeof mutation !== "object") {
      throw new Error("Plan review returned an invalid mutation.");
    }
    const type = String(mutation.type ?? "");
    if (type === "create_workout") {
      normalized.push(validateCreateWorkoutMutation(mutation, weeklyPlans, workouts, window, timezone, homeLocationLabel));
    } else if (type === "update_workout") {
      const update = validateUpdateWorkoutMutation(mutation, weeklyPlans, workouts, protectedWorkoutIDs, window, timezone);
      if (update) normalized.push(update);
    } else if (type === "delete_workout") {
      normalized.push(validateDeleteWorkoutMutation(mutation, workouts, protectedWorkoutIDs, timezone));
    } else {
      throw new Error(`Plan review returned unsupported mutation type: ${type}`);
    }
  }
  return normalized;
}

function validateCreateWorkoutMutation(
  mutation: Record<string, unknown>,
  weeklyPlans: Record<string, any>[],
  workouts: Record<string, any>[],
  window: { start: string; end: string },
  timezone: string,
  homeLocationLabel?: string | null,
) {
  const fields = plainObject(mutation.fields, "create_workout.fields");
  const scheduledDate = requiredString(fields.scheduled_date, "create_workout scheduled_date");
  const weeklyPlan = weeklyPlanForMutationDate(weeklyPlans, scheduledDate, window, timezone);
  throwIfUnavailableDate(weeklyPlan, scheduledDate);

  const title = requiredString(fields.title, "create_workout title");
  const activityType = normalizeActivity(requiredString(fields.activity_type, "create_workout activity_type"));
  const intensityLabel = requiredString(fields.intensity_label, "create_workout intensity_label");
  const purpose = requiredString(fields.purpose, "create_workout purpose");
  const fuelingSummary = requiredString(fields.fueling_summary, "create_workout fueling_summary");
  const prescription = plainObject(fields.prescription_json, "create_workout prescription_json");
  const sequenceOrder = integerOrDefault(fields.sequence_order, nextSequenceOrderForDate(workouts, scheduledDate));

  return {
    type: "create_workout",
    fields: {
      active_block_id: null,
      weekly_rhythm_id: null,
      weekly_plan_id: weeklyPlan.id,
      generation_key: null,
      scheduled_date: scheduledDate,
      sequence_order: sequenceOrder,
      activity_type: activityType,
      title: normalizedWorkoutTitle(activityType, title, boundedDuration(fields.duration_minutes), intensityLabel, purpose),
      duration_minutes: boundedDuration(fields.duration_minutes),
      intensity_label: intensityLabel,
      purpose,
      ...workoutCardFields({
        scheduledDate,
        activityType,
        title,
        durationMinutes: boundedDuration(fields.duration_minutes),
        intensityLabel,
        purpose,
        locationLabel: homeLocationLabel,
      }),
      status: "planned",
      source: "replanned",
      prescription_json: prescription,
      fueling_summary: fuelingSummary,
    },
  };
}

function validateUpdateWorkoutMutation(
  mutation: Record<string, unknown>,
  weeklyPlans: Record<string, any>[],
  workouts: Record<string, any>[],
  protectedWorkoutIDs: Set<string>,
  window: { start: string; end: string },
  timezone: string,
) {
  const workoutID = requiredString(mutation.workout_id, "update_workout workout_id");
  if (protectedWorkoutIDs.has(workoutID)) {
    throw new Error("Plan review tried to mutate a workout from the user's pending edits.");
  }
  const workout = workouts.find((item) => item.id === workoutID);
  if (!workout) throw new Error("Plan review tried to update a workout outside the review window.");
  if (!canMutateWorkout(workout, todayInTimezone(timezone))) {
    throw new Error("Plan review tried to update a workout that can no longer be changed.");
  }

  const inputFields = plainObject(mutation.fields, "update_workout.fields");
  const fields: Record<string, unknown> = {};
  if (inputFields.scheduled_date !== undefined && inputFields.scheduled_date !== null) {
    const scheduledDate = requiredString(inputFields.scheduled_date, "update_workout scheduled_date");
    const weeklyPlan = weeklyPlanForMutationDate(weeklyPlans, scheduledDate, window, timezone);
    throwIfUnavailableDate(weeklyPlan, scheduledDate);
    fields.scheduled_date = scheduledDate;
    fields.weekly_plan_id = weeklyPlan.id;
    fields.sequence_order = integerOrDefault(inputFields.sequence_order, nextSequenceOrderForDate(workouts, scheduledDate));
  } else if (inputFields.sequence_order !== undefined && inputFields.sequence_order !== null) {
    fields.sequence_order = integerOrDefault(inputFields.sequence_order, workout.sequence_order ?? 1);
  }
  if (inputFields.title !== undefined && inputFields.title !== null) fields.title = requiredString(inputFields.title, "update_workout title");
  if (inputFields.activity_type !== undefined && inputFields.activity_type !== null) fields.activity_type = normalizeActivity(requiredString(inputFields.activity_type, "update_workout activity_type"));
  if (inputFields.duration_minutes !== undefined && inputFields.duration_minutes !== null) fields.duration_minutes = boundedDuration(inputFields.duration_minutes);
  if (inputFields.intensity_label !== undefined && inputFields.intensity_label !== null) fields.intensity_label = requiredString(inputFields.intensity_label, "update_workout intensity_label");
  if (inputFields.purpose !== undefined && inputFields.purpose !== null) fields.purpose = requiredString(inputFields.purpose, "update_workout purpose");
  if (inputFields.estimated_distance_kilometers !== undefined && inputFields.estimated_distance_kilometers !== null) fields.estimated_distance_kilometers = Number(inputFields.estimated_distance_kilometers);
  if (inputFields.estimated_elevation_meters !== undefined && inputFields.estimated_elevation_meters !== null) fields.estimated_elevation_meters = Number(inputFields.estimated_elevation_meters);
  if (inputFields.prescription_json !== undefined && inputFields.prescription_json !== null) fields.prescription_json = plainObject(inputFields.prescription_json, "update_workout prescription_json");
  if (inputFields.fueling_summary !== undefined && inputFields.fueling_summary !== null) fields.fueling_summary = requiredString(inputFields.fueling_summary, "update_workout fueling_summary");

  const mergedWorkout = {
    scheduled_date: fields.scheduled_date ?? workout.scheduled_date,
    activity_type: fields.activity_type ?? workout.activity_type,
    title: fields.title ?? workout.title,
    duration_minutes: fields.duration_minutes ?? workout.duration_minutes,
    intensity_label: fields.intensity_label ?? workout.intensity_label,
    purpose: fields.purpose ?? workout.purpose,
    estimated_distance_kilometers: fields.estimated_distance_kilometers ?? workout.estimated_distance_kilometers ?? null,
    estimated_elevation_meters: fields.estimated_elevation_meters ?? workout.estimated_elevation_meters ?? null,
    planned_location_label: workout.planned_location_label ?? null,
  };
  Object.assign(fields, workoutCardFields({
    scheduledDate: String(mergedWorkout.scheduled_date ?? ""),
    activityType: String(mergedWorkout.activity_type ?? ""),
    title: String(mergedWorkout.title ?? ""),
    durationMinutes: Number(mergedWorkout.duration_minutes ?? 0),
    intensityLabel: String(mergedWorkout.intensity_label ?? ""),
    purpose: String(mergedWorkout.purpose ?? ""),
    locationLabel: mergedWorkout.planned_location_label,
    distanceKilometers: Number(mergedWorkout.estimated_distance_kilometers) || null,
    elevationMeters: Number(mergedWorkout.estimated_elevation_meters) || null,
  }));
  fields.title = normalizedWorkoutTitle(
    String(mergedWorkout.activity_type ?? ""),
    String(mergedWorkout.title ?? ""),
    Number(mergedWorkout.duration_minutes ?? 0),
    String(mergedWorkout.intensity_label ?? ""),
    String(mergedWorkout.purpose ?? ""),
  );

  fields.source = "replanned";
  fields.generation_key = null;
  if (isNoOpWorkoutUpdate(workout, fields)) return null;
  return {
    type: "update_workout",
    workout_id: workoutID,
    workout_title: workout.title ?? null,
    from_scheduled_date: workout.scheduled_date ?? null,
    fields,
  };
}

function validateDeleteWorkoutMutation(
  mutation: Record<string, unknown>,
  workouts: Record<string, any>[],
  protectedWorkoutIDs: Set<string>,
  timezone: string,
) {
  const workoutID = requiredString(mutation.workout_id, "delete_workout workout_id");
  if (protectedWorkoutIDs.has(workoutID)) {
    throw new Error("Plan review tried to delete a workout from the user's pending edits.");
  }
  const workout = workouts.find((item) => item.id === workoutID);
  if (!workout) throw new Error("Plan review tried to delete a workout outside the review window.");
  if (String(workout.source ?? "").startsWith("user_")) {
    throw new Error("Plan review tried to delete a user-created or user-modified workout.");
  }
  if (!canMutateWorkout(workout, todayInTimezone(timezone))) {
    throw new Error("Plan review tried to delete a workout that can no longer be changed.");
  }
  return {
    type: "delete_workout",
    workout_id: workoutID,
    workout_title: workout.title ?? null,
    from_scheduled_date: workout.scheduled_date ?? null,
  };
}

function weeklyPlanForMutationDate(
  weeklyPlans: Record<string, any>[],
  scheduledDate: string,
  window: { start: string; end: string },
  timezone: string,
) {
  throwIfPastPlanningDate(scheduledDate, timezone);
  if (scheduledDate < window.start || scheduledDate > window.end) {
    throw new Error("Plan review tried to schedule outside the visible review window.");
  }
  const weeklyPlan = weeklyPlans.find((plan) => scheduledDate >= plan.week_start_date && scheduledDate <= plan.week_end_date);
  if (!weeklyPlan) throw new Error("Plan review tried to schedule outside a committed or draft week.");
  return weeklyPlan;
}

function throwIfUnavailableDate(weeklyPlan: Record<string, any>, scheduledDate: string) {
  const day = weeklyPlan.constraints_json?.days?.[scheduledDate];
  if (day?.kind === "unavailable") {
    throw new Error("Plan review tried to schedule a workout on an unavailable day.");
  }
}

function plainObject(value: unknown, label: string): Record<string, any> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`Plan review returned invalid ${label}.`);
  }
  return value as Record<string, any>;
}

function requiredString(value: unknown, label: string) {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text) throw new Error(`Plan review returned missing ${label}.`);
  return text;
}

function boundedDuration(value: unknown) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error("Plan review returned invalid duration_minutes.");
  }
  return Math.max(10, Math.min(240, Math.round(value)));
}

function integerOrDefault(value: unknown, fallback: number) {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(1, Math.round(value));
}

function isNoOpWorkoutUpdate(workout: Record<string, any>, fields: Record<string, unknown>) {
  const entries = Object.entries(fields).filter(([key]) => key !== "source" && key !== "generation_key");
  if (entries.length === 0) return true;
  return entries.every(([key, value]) => {
    if (key === "duration_minutes" || key === "sequence_order") return Number(workout[key]) === Number(value);
    if (key === "prescription_json") return JSON.stringify(workout[key] ?? {}) === JSON.stringify(value ?? {});
    return String(workout[key] ?? "") === String(value ?? "");
  });
}

function proposalResponse(proposal: Record<string, any>) {
  return {
    id: proposal.id,
    active_block_id: proposal.active_block_id,
    user_goal_id: proposal.user_goal_id,
    fitness_strategy_id: proposal.fitness_strategy_id,
    weekly_plan_id: proposal.weekly_plan_id,
    trigger_event_id: proposal.trigger_event_id,
    reason: proposal.reason,
    proposed_mutations_json: proposal.proposed_mutations_json,
    status: proposal.status,
    created_at: proposal.created_at,
    updated_at: proposal.updated_at,
    metadata_json: proposal.metadata_json ?? null,
  };
}

function isMissingMetadataJSONColumn(error: unknown) {
  const message = errorMessage(error).toLowerCase();
  return message.includes("metadata_json") && (
    message.includes("does not exist") ||
    message.includes("schema cache") ||
    message.includes("column")
  );
}

async function checkInToWorkout(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  const plannedWorkoutID = requestBody.plannedWorkoutID ?? requestBody.planned_workout_id;
  if (!plannedWorkoutID) {
    throw new Error("check_in_to_workout requires plannedWorkoutID");
  }

  const scope = await loadActivePlanningScope(admin, userID);
  const workout = await loadPlannedWorkoutForActiveStrategy(admin, userID, scope.strategy.id, plannedWorkoutID);

  const shouldAdjust = checkInSuggestsAdjustment(requestBody);
  const event = await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: scope.strategy.id,
    weeklyPlanID: workout.weekly_plan_id ?? null,
    plannedWorkoutID: workout.id,
    eventType: "checkin_recorded",
    payload: {
      mood: requestBody.mood ?? null,
      hasTextContext: Boolean(requestBody.textContext?.trim()),
      currentDerivedSnapshot: summarizeSnapshot(requestBody.currentDerivedSnapshot ?? requestBody.current_derived_snapshot),
      shouldAdjust,
    },
  });

  if (!shouldAdjust) {
    await throwOnError(admin.from("planned_workouts").update({ status: "checked_in" }).eq("id", workout.id));
    return {
      userID,
      eventID: event.id,
      outcome: "confirmed",
      workout,
      prescription: workout.prescription_json,
    };
  }

  const adjustedDuration = Math.max(15, Math.round((workout.duration_minutes ?? 30) * 0.7));
  const proposal = await createReplanProposal(admin, {
    userID,
    fitnessStrategyID: scope.strategy.id,
    weeklyPlanID: workout.weekly_plan_id ?? null,
    triggerEventID: event.id,
    reason: "Check-in suggests lowering today's dose while preserving the training intent.",
    mutations: [
      {
        type: "update_workout",
        workout_id: workout.id,
        fields: {
          status: "adjusted",
          source: "checkin_adjusted",
          duration_minutes: adjustedDuration,
          intensity_label: "Low",
          purpose: workout.purpose || "Keep the rhythm with lower load",
          fueling_summary: workout.fueling_summary,
          prescription_json: {
            ...(workout.prescription_json ?? {}),
            adjustment: "Lower dose after check-in; preserve intent.",
          },
        },
      },
    ],
  });

  return {
    userID,
    eventID: event.id,
    outcome: "adjustment_proposed",
    proposalID: proposal.id,
    reason: proposal.reason,
  };
}

async function scheduledRefreshDueWindows(admin: SupabaseAdminClient, model: string) {
  const strategies = await list(
    admin
      .from("fitness_strategies")
      .select("id,user_id,context_json")
      .eq("status", "active"),
  );

  const dueStrategies = strategies.filter((strategy: Record<string, any>) => isSundayEveningInTimezone(strategy.context_json?.timezone || "UTC"));
  const refreshed: string[] = [];
  const failed: Array<{ userID: string; error: string }> = [];

  for (const strategy of dueStrategies) {
    try {
      await promoteDraftWeeklyPlan(admin, strategy.user_id, strategy.id);
      await refreshPlanWindowForUser(admin, strategy.user_id, undefined, model, "scheduled", true);
      refreshed.push(strategy.user_id);
    } catch (error) {
      failed.push({ userID: strategy.user_id, error: errorMessage(error) });
    }
  }

  return {
    model: "deterministic",
    due: dueStrategies.length,
    refreshed,
    failed,
  };
}

async function createAIGraphRun(
  admin: SupabaseAdminClient,
  args: {
    userID: string;
    graphName: "training_architecture" | "fitness_strategy" | "two_week_plan";
    triggeringTask: PlanningTask;
    blueprintRevisionID?: string | null;
    userGoalID?: string | null;
    fitnessStrategyID?: string | null;
    trainingArchitectureID?: string | null;
    input: Record<string, unknown>;
  },
) {
  return single(
    admin
      .from("ai_graph_runs")
      .insert({
        user_id: args.userID,
        graph_name: args.graphName,
        graph_version: "v1",
        triggering_task: args.triggeringTask,
        source_blueprint_revision_id: args.blueprintRevisionID ?? null,
        source_user_goal_id: args.userGoalID ?? null,
        source_fitness_strategy_id: args.fitnessStrategyID ?? null,
        source_training_architecture_id: args.trainingArchitectureID ?? null,
        status: "running",
        input_json: args.input,
        model_json: {},
      })
      .select()
      .single(),
    "Could not create AI graph run",
  );
}

async function graphRunNodeOutputs(
  admin: SupabaseAdminClient,
  graphRunID: string,
  userID: string,
) {
  const rows = await list(
    admin
      .from("ai_graph_node_outputs")
      .select()
      .eq("graph_run_id", graphRunID)
      .eq("user_id", userID)
      .order("sequence_order", { ascending: true })
      .order("created_at", { ascending: true }),
  );
  return rows.map((row: Record<string, any>) => ({
    id: row.id,
    graphRunID: row.graph_run_id,
    nodeName: row.node_name,
    subgraphName: row.subgraph_name ?? null,
    sequenceOrder: row.sequence_order,
    inputSummary: row.input_summary_json ?? {},
    output: row.structured_output_json ?? {},
    validation: row.validation_json ?? {},
    status: row.status,
    retryCount: row.retry_count ?? 0,
    errorMessage: row.error_message ?? null,
    startedAt: row.started_at ?? null,
    finishedAt: row.finished_at ?? null,
  }));
}

async function graphRunToolCalls(
  admin: SupabaseAdminClient,
  graphRunID: string,
  userID: string,
) {
  const rows = await list(
    admin
      .from("ai_tool_calls")
      .select()
      .eq("graph_run_id", graphRunID)
      .eq("user_id", userID)
      .order("created_at", { ascending: true }),
  );
  return rows.map((row: Record<string, any>) => ({
    id: row.id,
    graphRunID: row.graph_run_id,
    graphNodeOutputID: row.graph_node_output_id ?? null,
    toolName: row.tool_name,
    toolVersion: row.tool_version,
    input: row.input_json ?? {},
    output: row.output_json ?? null,
    status: row.status,
    errorMessage: row.error_message ?? null,
    latencyMS: row.latency_ms ?? null,
    startedAt: row.started_at ?? null,
    finishedAt: row.finished_at ?? null,
  }));
}

async function completeAIGraphRun(
  admin: SupabaseAdminClient,
  graphRunID: string,
  args: {
    status: "succeeded" | "failed" | "cancelled";
    output?: Record<string, unknown>;
    model?: Record<string, unknown>;
    errorSummary?: string;
  },
) {
  await throwOnError(
    admin
      .from("ai_graph_runs")
      .update({
        status: args.status,
        output_json: args.output ?? null,
        model_json: args.model ?? {},
        error_summary: args.errorSummary ?? null,
        finished_at: new Date().toISOString(),
      })
      .eq("id", graphRunID),
  );
}

async function insertAIGraphNodeOutputs(
  admin: SupabaseAdminClient,
  graphRunID: string,
  userID: string,
  nodes: GraphNodeTraceInput[],
) {
  if (nodes.length === 0) return;
  await throwOnError(
    admin.from("ai_graph_node_outputs").insert(nodes.map((node, index) => ({
      graph_run_id: graphRunID,
      user_id: userID,
      node_name: node.nodeName,
      subgraph_name: node.subgraphName ?? null,
      sequence_order: index + 1,
      input_summary_json: node.inputSummary ?? {},
      structured_output_json: node.output ?? {},
      validation_json: node.validation ?? {},
      status: node.status ?? "succeeded",
      retry_count: node.retryCount ?? 0,
      error_message: node.errorMessage ?? null,
      finished_at: new Date().toISOString(),
    }))),
  );
}

async function insertAIToolCalls(
  admin: SupabaseAdminClient,
  graphRunID: string,
  userID: string,
  toolCalls: GraphToolCallInput[],
) {
  if (toolCalls.length === 0) return;
  await throwOnError(
    admin.from("ai_tool_calls").insert(toolCalls.map((toolCall) => ({
      graph_run_id: graphRunID,
      user_id: userID,
      tool_name: toolCall.toolName,
      tool_version: toolCall.toolVersion ?? "v1",
      input_json: toolCall.input ?? {},
      output_json: toolCall.output ?? null,
      status: toolCall.status ?? "succeeded",
      error_message: toolCall.errorMessage ?? null,
      latency_ms: toolCall.latencyMS ?? null,
      finished_at: new Date().toISOString(),
    }))),
  );
}

async function runInitialStrategyOrchestration(
  planningPacket: Record<string, any>,
): Promise<InitialStrategyOrchestrationOutput> {
  const serviceURL = Deno.env.get("TRAINING_ORCHESTRATOR_URL")?.trim();
  if (!serviceURL && trainingOrchestratorRequired()) {
    throw new Error("TRAINING_ORCHESTRATOR_REQUIRED is true but TRAINING_ORCHESTRATOR_URL is not configured.");
  }
  if (serviceURL) {
    const response = await fetch(`${serviceURL.replace(/\/$/, "")}/planning/prepare-initial-strategy`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(Deno.env.get("TRAINING_ORCHESTRATOR_API_KEY")
          ? { Authorization: `Bearer ${Deno.env.get("TRAINING_ORCHESTRATOR_API_KEY")}` }
          : {}),
      },
      body: JSON.stringify({ planningPacket }),
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload?.error ?? "Training orchestrator request failed");
    }
    return payload as InitialStrategyOrchestrationOutput;
  }

  const trainingArchitecture = localTrainingArchitecture(planningPacket);
  const fitnessStrategy = localFitnessStrategy(planningPacket, trainingArchitecture);
  return {
    trainingArchitecture,
    fitnessStrategy,
    validation: {
      valid: true,
      source: "edge_local_contract_bridge",
      note: "Replace with external LangGraph service output when TRAINING_ORCHESTRATOR_URL is configured.",
    },
    nodes: [
      {
        nodeName: "validate_packet",
        output: {
          blueprintRevisionID: planningPacket.athlete_context?.blueprint_revision_id ?? null,
          goalKind: planningPacket.goal_context?.goal_kind ?? null,
        },
      },
      {
        nodeName: "load_knowledge_manifest",
        output: {
          packIDs: compactStringArray(trainingArchitecture.source_knowledge_refs?.map((ref: Record<string, any>) => ref.id) ?? []),
        },
      },
      {
        nodeName: "architect_frame",
        output: {
          selectedModalities: trainingArchitecture.architect_frame_summary?.selected_modalities ?? [],
          priorityHypotheses: trainingArchitecture.architect_frame_summary?.priority_hypotheses ?? [],
        },
      },
      {
        nodeName: "specialist_consultations",
        output: {
          specialists: trainingArchitecture.specialist_consultations ?? [],
        },
      },
      {
        nodeName: "architect_synthesis",
        output: {
          conflictAssessment: trainingArchitecture.conflict_assessment,
          approvedArchetypes: trainingArchitecture.approved_archetypes ?? [],
        },
      },
      {
        nodeName: "deterministic_validation",
        output: {
          valid: true,
        },
      },
      {
        nodeName: "generate_fitness_strategy",
        output: {
          targetCount: arrayAt(fitnessStrategy, "targets").length,
          phaseCount: arrayAt(fitnessStrategy, "phases").length,
        },
      },
    ],
    toolCalls: [],
    model: {
      provider: "edge-local-contract-bridge",
      graphVersion: "v1",
    },
  };
}

async function runTwoWeekPlanOrchestration(
  context: Record<string, unknown>,
  model: string,
): Promise<TwoWeekPlanOrchestrationOutput> {
  const serviceURL = Deno.env.get("TRAINING_ORCHESTRATOR_URL")?.trim();
  if (!serviceURL && trainingOrchestratorRequired()) {
    throw new Error("TRAINING_ORCHESTRATOR_REQUIRED is true but TRAINING_ORCHESTRATOR_URL is not configured.");
  }
  if (serviceURL) {
    const response = await fetch(`${serviceURL.replace(/\/$/, "")}/planning/two-week-plan`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(Deno.env.get("TRAINING_ORCHESTRATOR_API_KEY")
          ? { Authorization: `Bearer ${Deno.env.get("TRAINING_ORCHESTRATOR_API_KEY")}` }
          : {}),
      },
      body: JSON.stringify({ context }),
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload?.error ?? "Two-week plan graph request failed");
    }
    return {
      plan: payload.plan as GeneratedPlan,
      validation: objectAt(payload, "validation") ?? {},
      nodes: Array.isArray(payload.nodes) ? payload.nodes as GraphNodeTraceInput[] : [],
      toolCalls: Array.isArray(payload.toolCalls) ? payload.toolCalls as GraphToolCallInput[] : [],
      model: objectAt(payload, "model") ?? { provider: "hayf-training-orchestrator" },
    };
  }

  return {
    plan: await runPlanGeneration("accept_prepared_strategy_and_create_initial_plan", context, model),
    validation: {
      valid: true,
      source: "supabase_openai_plan_generation",
      note: "Used only because TRAINING_ORCHESTRATOR_URL is not configured and TRAINING_ORCHESTRATOR_REQUIRED is not true.",
    },
    nodes: [],
    toolCalls: [],
    model: {
      provider: "supabase-planning-ai",
      model,
    },
  };
}

function trainingOrchestratorRequired() {
  return ["true", "1", "yes"].includes((Deno.env.get("TRAINING_ORCHESTRATOR_REQUIRED") ?? "").trim().toLowerCase());
}

function localTrainingArchitecture(packet: Record<string, any>) {
  const modalities = compactStringArray(packet.goal_context?.selected_modality_order ?? []);
  const priorityOrder = modalities.length > 0 ? modalities : ["general"];
  const feasibleModalities = compactStringArray(packet.planning_constraints?.feasible_modalities ?? priorityOrder);
  const frequency = String(packet.planning_constraints?.frequency ?? "");
  const parsedFrequency = Number(frequency.match(/\d+/)?.[0] ?? NaN);
  const targetSessions = Number.isFinite(parsedFrequency) ? Math.max(2, Math.min(6, parsedFrequency)) : 3;
  const minimumSessions = Math.max(1, Math.min(3, targetSessions - 1));
  const hardDayCap = Math.max(1, Math.min(2, Math.floor(targetSessions / 3)));
  const requiresPhases = packet.goal_context?.goal_kind !== "consistency";
  const goalText = [
    JSON.stringify(packet.goal_context?.normalized_goal ?? {}),
    packet.goal_context?.success_definition,
    packet.goal_context?.body_composition_intent,
  ].filter(Boolean).join(" ").toLowerCase();
  const conflictSignals = [
    goalText.includes("bodybuilder") && goalText.includes("tour de france")
      ? "maximal_hypertrophy_vs_grand_tour_endurance"
      : null,
    goalText.includes("lose") && goalText.includes("power")
      ? "body_composition_vs_performance_fatigue"
      : null,
  ].filter((signal): signal is string => typeof signal === "string");
  const conflictStatus = conflictSignals.length > 0
    ? "conflicting"
    : priorityOrder.length > 2
    ? "manageable_tradeoff"
    : "clear";
  const sourceRefs = localSourceKnowledgeRefs(priorityOrder, packet);
  const architectFrame = {
    goal_read: {
      summary: `Build training around ${packet.goal_context?.normalized_goal?.title ?? "the active goal"}.`,
      priority_basis: [
        "Use the selected modality order as the first priority signal.",
        "Protect adherence and recovery before optional volume.",
        "Promote body-composition or performance-specific work only when the evidence and budget support it.",
      ],
      conflict_questions: conflictSignals.map(localConflictQuestion),
    },
    selected_modalities: priorityOrder,
    feasible_modalities: feasibleModalities,
    priority_hypotheses: priorityOrder,
    weekly_budget_range: {
      minimum_sessions: minimumSessions,
      target_sessions: targetSessions,
      maximum_sessions: Math.max(targetSessions, Math.min(6, targetSessions + 1)),
      hard_day_cap: hardDayCap,
    },
    recovery_risks: localRecoveryRisks(priorityOrder, packet),
    specialist_briefs: priorityOrder.map((modality, index) => ({
      modality,
      pack_id: localModalityKnowledgeRef(modality).id,
      requested_role: localRoleForModality(modality, index, packet),
      brief: `${titleCase(modality)} is selected for the athlete's plan. Training budget hypothesis: ${targetSessions} sessions per week with ${hardDayCap} hard day(s).`,
      questions: [
        "Which adaptations matter most for this modality in the stated goal?",
        "Which workout archetypes are useful without creating dated workouts?",
        "What fatigue, interference, and common mistake warnings should the Architect consider?",
      ],
      knowledge_refs: localKnowledgeRefsForModality(modality, packet),
    })),
    knowledge_refs: sourceRefs,
  };
  const specialistConsultations = priorityOrder.map((modality, index) => localSpecialistConsultation(modality, index, packet));
  const approvedArchetypes = specialistConsultations.flatMap((consultation) => consultation.archetype_proposals)
    .filter((archetype) => !(archetype.fatigue_cost === "high" && (targetSessions <= 3 || packet.approved_evidence_summary?.confidence === "missing")));
  const rejectedRecommendations = specialistConsultations.flatMap((consultation) => consultation.archetype_proposals)
    .filter((archetype) => !approvedArchetypes.some((approved) => approved.id === archetype.id))
    .map((archetype) => ({
      modality: archetype.modality,
      archetype_id: archetype.id,
      reason: "Rejected by the Training Architect because its fatigue cost does not fit the current budget or evidence confidence.",
      knowledge_refs: archetype.knowledge_refs,
    }));

  return {
    source_ids: {
      blueprint_revision_id: packet.athlete_context?.blueprint_revision_id ?? null,
      user_goal_id: packet.goal_context?.user_goal_id ?? null,
    },
    goal_read: {
      summary: `Build training around ${packet.goal_context?.normalized_goal?.title ?? "the active goal"}.`,
      goal_kind: packet.goal_context?.goal_kind ?? "consistency",
      success_definition: packet.goal_context?.success_definition ?? null,
    },
    modality_roles: priorityOrder.map((modality, index) => ({
      modality,
      role: localRoleForModality(modality, index, packet),
      rationale: index === 0
        ? "This modality best expresses the stated goal and should anchor progression."
        : "This modality supports the goal without consuming the recovery budget.",
      knowledge_refs: localKnowledgeRefsForModality(modality, packet),
    })),
    priority_order: priorityOrder,
    weekly_budget: {
      target_sessions: targetSessions,
      minimum_viable_sessions: minimumSessions,
      hard_sessions: hardDayCap,
      recovery_sessions: Math.max(1, targetSessions - hardDayCap),
    },
    recovery_envelope: {
      max_hard_days_per_week: hardDayCap,
      spacing_rules: [
        "Do not stack hard lower-body strength and hard endurance on adjacent days unless the week has no alternative.",
        "If recovery evidence is missing or worsening, use the minimum viable week before adding intensity.",
      ],
      bad_day_floor: packet.planning_constraints?.bad_day_floor ?? null,
    },
    minimum_effective_dose_rules: [
      "Protect the minimum viable week before adding optional work.",
      "Keep the primary modality visible every week unless injury, illness, or travel makes it inappropriate.",
    ],
    specialist_recommendations: specialistConsultations.map((consultation) => ({
      coach: consultation.coach,
      modality: consultation.modality,
      role: consultation.recommended_role,
      development_path: consultation.adaptation_priorities.join(", "),
      weekly_dose: consultation.weekly_dose.target,
      key_risks: consultation.fatigue_signals,
      planning_rules: consultation.interference_rules,
    })),
    architect_frame_summary: architectFrame,
    specialist_consultations: specialistConsultations,
    approved_archetypes: approvedArchetypes,
    rejected_specialist_recommendations: rejectedRecommendations,
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
      required_tradeoffs: conflictSignals.length > 0
        ? conflictSignals
        : ["Recovery and adherence take precedence over optional volume."],
    },
    conflict_decisions: [
      {
        id: "final_priority_order",
        decision: `Use ${priorityOrder.map(titleCase).join(" > ")} as the final priority order.`,
        rationale: "The selected modality order is the strongest user-authored priority signal.",
        knowledge_refs: sourceRefs,
      },
      {
        id: "specialist_filtering",
        decision: "Only approved archetypes should reach plan generation.",
        rationale: "Specialists provide recommendations, but the Training Architect owns coherence and filters fatigue or interference conflicts.",
        knowledge_refs: sourceRefs,
      },
      ...conflictSignals.map((signal) => ({
        id: String(signal),
        decision: "Require explicit tradeoff handling before progression.",
        rationale: localConflictQuestion(String(signal)),
        knowledge_refs: sourceRefs,
      })),
    ],
    planner_constraints: {
      weekly_plan_rules: [
        "Week 1 is committed; week 2 is draft and must preserve user-authored constraints.",
        "Use the final priority order and role assignments from the Training Architecture.",
      ],
      workout_generation_rules: [
        "Every workout must have a purpose tied to the Training Architecture.",
        `Allowed modalities: ${priorityOrder.join(", ")}.`,
        `Approved archetypes: ${approvedArchetypes.map((archetype) => archetype.id).join(", ")}.`,
        "Do not introduce off-menu modalities.",
      ],
      target_generation_rules: [
        "Targets must be measurable from actual completion, body entries, performance observations, or approved plan structure.",
        "Do not mark completion-based targets done from planned workouts alone.",
      ],
    },
    source_knowledge_refs: sourceRefs,
  };
}

function localSourceKnowledgeRefs(modalities: string[], packet: Record<string, any>) {
  const refs = [
    localKnowledgeRef("core.training_doctrine", "Training Doctrine", "core/training-doctrine.md"),
    localKnowledgeRef("policy.hayf_planning", "HAYF Planning Policy", "policy/hayf-planning-policy.md"),
    packet.goal_context?.goal_kind === "consistency"
      ? localKnowledgeRef("goal.consistency", "Consistency Goal Pack", "goals/consistency.md")
      : localKnowledgeRef("goal.performance", "Performance Goal Pack", "goals/performance.md"),
    packet.goal_context?.body_composition_intent
      ? localKnowledgeRef("goal.body_composition", "Body Composition Goal Pack", "goals/body-composition.md")
      : null,
    ...modalities.map(localModalityKnowledgeRef),
  ].filter(Boolean) as Array<Record<string, string>>;
  return uniqueByID(refs);
}

function localKnowledgeRefsForModality(modality: string, packet: Record<string, any>) {
  return uniqueByID([
    localKnowledgeRef("core.training_doctrine", "Training Doctrine", "core/training-doctrine.md"),
    localKnowledgeRef("policy.hayf_planning", "HAYF Planning Policy", "policy/hayf-planning-policy.md"),
    packet.goal_context?.goal_kind === "consistency"
      ? localKnowledgeRef("goal.consistency", "Consistency Goal Pack", "goals/consistency.md")
      : localKnowledgeRef("goal.performance", "Performance Goal Pack", "goals/performance.md"),
    ...(packet.goal_context?.body_composition_intent
      ? [localKnowledgeRef("goal.body_composition", "Body Composition Goal Pack", "goals/body-composition.md")]
      : []),
    localModalityKnowledgeRef(modality),
  ]);
}

function localKnowledgeRef(id: string, title: string, path: string) {
  return { id, title, version: "2026-07-07", path };
}

function localModalityKnowledgeRef(modality: string) {
  if (["cycling", "strength", "running"].includes(modality)) {
    return localKnowledgeRef(`modality.${modality}`, `${titleCase(modality)} Modality Pack`, `modalities/${modality}.md`);
  }
  return localKnowledgeRef("modality.generic", "Generic Modality Fallback Pack", "modalities/generic.md");
}

function uniqueByID(refs: Array<Record<string, string>>) {
  const seen = new Set<string>();
  return refs.filter((ref) => {
    if (seen.has(ref.id)) return false;
    seen.add(ref.id);
    return true;
  });
}

function localRoleForModality(modality: string, index: number, packet: Record<string, any>) {
  if (index === 0) return "primary_driver";
  if (modality === "running") return "optional_filler";
  if (modality === "strength") return "secondary_support";
  if (!["cycling", "strength", "running"].includes(modality) && index > 1) return "maintenance_exposure";
  if (packet.goal_context?.body_composition_intent && modality === "strength") return "secondary_support";
  return index === 1 ? "secondary_support" : "maintenance_exposure";
}

function localSpecialistConsultation(modality: string, index: number, packet: Record<string, any>) {
  const role = localRoleForModality(modality, index, packet);
  const knowledgeRefs = localKnowledgeRefsForModality(modality, packet);
  const supported = ["cycling", "strength", "running"].includes(modality);
  return {
    coach: supported ? `${modality}_specialist_consultant` : "generic_specialist_consultant",
    modality,
    recommended_role: role,
    rationale: supported
      ? (index === 0
        ? `${titleCase(modality)} best expresses the user's selected priority and anchors progression.`
        : `${titleCase(modality)} supports the primary goal but must stay bounded by recovery.`)
      : `${titleCase(modality)} uses the generic fallback pack, so the role stays conservative until a dedicated specialist pack exists.`,
    performance_determinants: localPerformanceDeterminants(modality),
    adaptation_priorities: localAdaptationPriorities(modality, packet),
    intensity_model: localIntensityModel(modality),
    weekly_dose: localWeeklyDose(role, supported),
    archetype_proposals: localArchetypesFor(modality, role, packet, knowledgeRefs),
    fatigue_signals: localModalityRisks(modality),
    interference_rules: localInterferenceRules(modality, role),
    common_mistakes: localCommonMistakes(modality),
    tool_requests: [
      {
        tool_name: "read_modality_consistency",
        purpose: `Summarize recent consistency for ${modality} when live evidence tools are connected.`,
        input: { modality },
        optional: true,
      },
      {
        tool_name: "read_fatigue_signals",
        purpose: "Summarize cardio, muscular, connective-tissue, and nervous-system fatigue signals.",
        input: { modality, horizon_days: 28 },
        optional: true,
      },
    ],
    knowledge_refs: knowledgeRefs,
  };
}

function localArchetypesFor(modality: string, role: string, packet: Record<string, any>, knowledgeRefs: Array<Record<string, string>>) {
  if (modality === "cycling") {
    const archetypes = [
      localArchetype("cycling_endurance_ride", modality, "Build durable low-intensity aerobic volume.", "aerobic base and durability", "easy aerobic", 45, 120, "low", knowledgeRefs),
      localArchetype("cycling_tempo_ride", modality, "Add controlled sustained work without maximal strain.", "tempo durability", "tempo", 35, 75, "moderate", knowledgeRefs),
    ];
    if (role === "primary_driver" && packet.goal_context?.goal_kind !== "consistency") {
      archetypes.push(localArchetype("cycling_vo2_intervals", modality, "Use short high-output intervals only when performance needs justify them.", "VO2max and high-end aerobic power", "VO2max", 35, 60, "high", knowledgeRefs));
    }
    return archetypes;
  }
  if (modality === "strength") {
    const archetypes = [
      localArchetype("strength_full_body_support", modality, "Maintain full-body strength and tissue capacity.", "force production and movement quality", "moderate strength", 35, 60, "moderate", knowledgeRefs),
      localArchetype("strength_maintenance", modality, "Keep the strength signal alive with low complexity.", "strength retention", "easy-moderate strength", 20, 45, "low", knowledgeRefs),
    ];
    if (packet.goal_context?.body_composition_intent || /muscle|strong|hypertrophy|lean/i.test(JSON.stringify(packet.goal_context?.normalized_goal ?? {}))) {
      archetypes.push(localArchetype("strength_hypertrophy_support", modality, "Protect lean mass with enough mechanical tension.", "hypertrophy support and muscle retention", "moderate strength", 40, 65, "moderate", knowledgeRefs));
    }
    return archetypes;
  }
  if (modality === "running") {
    return [
      localArchetype("running_easy_aerobic", modality, "Build easy aerobic exposure with impact kept controlled.", "aerobic base and tissue tolerance", "easy aerobic", 20, 50, "moderate", knowledgeRefs),
      localArchetype("running_strides", modality, "Use short relaxed strides for mechanics without a full hard session.", "neuromuscular coordination", "neuromuscular", 20, 40, "moderate", knowledgeRefs),
    ];
  }
  return [
    localArchetype(`${modality}_skill_practice`, modality, "Practice repeatable technique at a controlled effort.", "skill economy and adherence", "easy-skill", 20, 45, "low", knowledgeRefs),
    localArchetype(`${modality}_easy_conditioning`, modality, "Use an easy conditioning exposure for general fitness.", "aerobic base and routine", "easy aerobic", 20, 50, "low", knowledgeRefs),
  ];
}

function localArchetype(
  id: string,
  modality: string,
  purpose: string,
  targetAdaptation: string,
  intensityDomain: string,
  minMinutes: number,
  maxMinutes: number,
  fatigueCost: string,
  knowledgeRefs: Array<Record<string, string>>,
) {
  return {
    id,
    modality,
    purpose,
    target_adaptation: targetAdaptation,
    intensity_domain: intensityDomain,
    typical_duration_minutes: { min: minMinutes, max: maxMinutes },
    dose_range: "Use only inside the weekly budget approved by the Training Architect.",
    progression_rule: "Progress only after the committed week is completed and recovery is stable.",
    fatigue_cost: fatigueCost,
    prerequisites: [],
    incompatibilities: ["Do not stack hard lower-body work on adjacent days when avoidable."],
    planner_constraints: ["Use this as an archetype, not as a dated workout."],
    knowledge_refs: knowledgeRefs,
  };
}

function localPerformanceDeterminants(modality: string) {
  if (modality === "cycling") return ["aerobic durability", "sustainable power", "fatigue resistance"];
  if (modality === "strength") return ["movement quality", "force production", "tissue tolerance"];
  if (modality === "running") return ["impact tolerance", "aerobic economy", "durability"];
  return ["repeatability", "skill familiarity", "low-risk conditioning"];
}

function localAdaptationPriorities(modality: string, packet: Record<string, any>) {
  if (modality === "cycling") return ["aerobic base", "durability", packet.goal_context?.goal_kind === "consistency" ? "repeatable habit" : "controlled intensity"];
  if (modality === "strength") return packet.goal_context?.body_composition_intent
    ? ["mechanical tension", "lean mass protection", "joint capacity"]
    : ["movement quality", "general strength", "injury resilience"];
  if (modality === "running") return ["easy aerobic consistency", "impact tolerance", "running economy"];
  return ["skill familiarity", "repeatable exposure", "conservative progression"];
}

function localIntensityModel(modality: string) {
  if (modality === "cycling") return "Power, heart rate, RPE, and talk-test domains: easy, tempo, threshold, VO2max.";
  if (modality === "strength") return "RPE/reps-in-reserve, movement quality, volume, and soreness response.";
  if (modality === "running") return "Pace, heart rate, RPE, and impact tolerance domains: easy, strides, tempo, threshold.";
  return "Use simple easy/moderate/hard language until a dedicated modality intensity model exists.";
}

function localWeeklyDose(role: string, supported: boolean) {
  if (!supported) return { minimum: "0 exposures", target: "1 conservative exposure", maximum: "2 exposures", hard_cap: "0 hard exposures" };
  if (role === "primary_driver") return { minimum: "1 exposure", target: "2 protected exposures", maximum: "3 exposures", hard_cap: "1 hard exposure unless the budget is high" };
  if (role === "secondary_support") return { minimum: "1 exposure", target: "1 to 2 bounded exposures", maximum: "2 exposures", hard_cap: "0 to 1 hard exposure only if it does not conflict" };
  if (role === "maintenance_exposure") return { minimum: "0 exposures", target: "1 exposure", maximum: "1 to 2 exposures", hard_cap: "0 hard exposures" };
  return { minimum: "0 exposures", target: "0 to 1 exposure", maximum: "1 exposure", hard_cap: "0 hard exposures" };
}

function localInterferenceRules(modality: string, role: string) {
  if (modality === "cycling") return ["Do not place cycling VO2 work next to heavy lower-body strength.", "Long rides should not erase the minimum strength dose."];
  if (modality === "strength") return ["Avoid heavy lower-body strength immediately before key endurance intensity.", "Stop support strength short of failure in mixed-goal weeks."];
  if (modality === "running") return role === "primary_driver"
    ? ["Hard running counts as a hard day and needs spacing from strength."]
    : ["Running remains optional if impact soreness threatens the minimum week."];
  return ["Generic modalities cannot displace approved primary or secondary work in V1."];
}

function localCommonMistakes(modality: string) {
  if (modality === "cycling") return ["Turning every ride into tempo.", "Adding intensity before easy volume is repeatable."];
  if (modality === "strength") return ["Chasing soreness as proof of progress.", "Letting support strength impair endurance quality."];
  if (modality === "running") return ["Adding speed before impact tolerance.", "Running easy days too hard."];
  return ["Treating a generic fallback as expert modality prescription.", "Adding complexity before the habit is stable."];
}

function localRecoveryRisks(modalities: string[], packet: Record<string, any>) {
  const risks = [
    modalities.includes("strength") && (modalities.includes("running") || modalities.includes("cycling"))
      ? "Lower-body strength can interfere with endurance quality if hard sessions are stacked."
      : null,
    modalities.includes("running") ? "Running adds impact cost and should be conservative when evidence is thin." : null,
    packet.approved_evidence_summary?.confidence === "missing" ? "Missing evidence requires conservative dose and no fake certainty." : null,
  ].filter(Boolean);
  return risks.length > 0 ? risks : ["No unusual recovery risk is visible beyond normal hard-day spacing."];
}

function localConflictQuestion(signal: string) {
  if (signal === "maximal_hypertrophy_vs_grand_tour_endurance") {
    return "Maximal hypertrophy and grand-tour endurance cannot both be maximized; the plan must select a priority.";
  }
  if (signal === "body_composition_vs_performance_fatigue") {
    return "Fat loss and performance work can coexist only if fueling, recovery, and hard-day caps are explicit.";
  }
  return "A stated goal conflict requires explicit prioritization.";
}

function localFitnessStrategy(packet: Record<string, any>, architecture: Record<string, any>) {
  const primary = String(architecture.priority_order?.[0] ?? "training");
  const requiresPhases = Boolean(architecture.phase_logic?.requires_phases);
  const minSessions = Number(architecture.weekly_budget?.minimum_viable_sessions ?? 2);
  const hardCap = Number(architecture.recovery_envelope?.max_hard_days_per_week ?? 1);
  const targets = [
    strategyTarget("primary_exposure", "strategy", "primary", `${titleCase(primary)} weeks`, "Keep the primary training signal present across the strategy.", "planned_session_completion", primary, "complete", minSessions, "sessions/week", `${minSessions}/wk`),
    strategyTarget("weekly_rhythm", "strategy", "supporting", "Rhythm weeks", "Complete enough sessions for the week to count.", "training_workouts_7d", "consistency", "maintain", minSessions, "sessions/week", `${minSessions}/wk`),
    strategyTarget("hard_day_cap", "strategy", "supporting", "Hard day cap", "Keep hard training inside the recovery envelope.", "hard_sessions_per_week", "recovery", "maintain", hardCap, "sessions/week", `${hardCap}/wk`),
  ];

  return {
    read: architecture.conflict_assessment?.status === "conflicting"
      ? `HAYF will coach this by forcing the tradeoff into the open before the plan gets concrete. ${titleCase(primary)} stays first, support work is capped, and the week must protect recovery instead of pretending every goal can be maximized at once.`
      : `HAYF will coach this through a ${titleCase(primary)}-led structure with support work kept useful but bounded. The strategy protects the weekly budget, spaces hard work, and lets progression happen only when the committed week is actually holding.`,
    goalTargetContext: {
      title: String(packet.goal_context?.normalized_goal?.title ?? "Active goal"),
      summary: "This is the user target HAYF is translating into a coaching strategy.",
    },
    snapshotItems: [
      { id: "priority", systemImage: "target", value: titleCase(primary), label: "Primary driver" },
      { id: "budget", systemImage: "calendar", value: `${architecture.weekly_budget?.target_sessions ?? 3}/wk`, label: "Training budget" },
      { id: "timeframe", systemImage: "clock", value: packet.goal_context?.timeframe_weeks ? `${packet.goal_context.timeframe_weeks} wks` : "Rolling", label: "Strategy horizon" },
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
      ? (architecture.phase_logic?.phases ?? []).map((phase: Record<string, any>) => ({
        id: phase.id,
        name: phase.name,
        objective: phase.objective,
        targetSummary: "This phase should prove the strategy is moving without breaking recovery.",
        targets: targets.map((target) => ({ ...target, id: `${phase.id}_${target.id}`, scope: "phase" })),
      }))
      : [],
    operatingRhythm: requiresPhases ? null : {
      summary: "HAYF will treat consistency as the result, using the smallest useful week that can repeat.",
      anchors: (architecture.priority_order ?? []).slice(0, 3).map(titleCase),
    },
    targets,
  };
}

function strategyTarget(
  id: string,
  scope: string,
  kind: string,
  title: string,
  summary: string,
  metricKey: string,
  metricCategory: string,
  direction: string,
  targetValue: number,
  unit: string,
  displayValue: string,
) {
  return {
    id,
    scope,
    kind,
    title,
    summary,
    metricKey,
    metricCategory,
    direction,
    targetValue,
    unit,
    displayValue,
  };
}

function localDevelopmentPath(modality: string, packet: Record<string, any>) {
  if (modality === "cycling") return "aerobic durability, climbing-specific quality, and fatigue-managed intensity";
  if (modality === "strength") {
    return packet.goal_context?.body_composition_intent
      ? "hypertrophy-preserving strength with visible-athletic support"
      : "general strength continuity and movement quality";
  }
  if (modality === "running") return "light aerobic support unless explicitly promoted by the goal";
  return "repeatable general training exposure";
}

function localModalityRisks(modality: string) {
  if (modality === "cycling") return ["lower-body fatigue can crowd strength quality"];
  if (modality === "strength") return ["soreness can reduce endurance quality"];
  if (modality === "running") return ["extra impact can compete with recovery"];
  return ["too much novelty can reduce adherence"];
}

function tradeoffLabel(architecture: Record<string, any>) {
  switch (architecture.conflict_assessment?.status) {
    case "conflicting":
      return "Needs priority";
    case "manageable_tradeoff":
      return "Managed";
    default:
      return "Clear";
  }
}

async function runPlanGeneration(task: PlanningTask, context: Record<string, unknown>, model: string): Promise<GeneratedPlan> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const touchpointConfig = planningAITouchpoint("plan_generation", { workoutTaxonomyRules });
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(responsesRequestPayload(
      model,
      touchpointConfig,
      {
        task,
        context,
        rules: touchpointConfig.userRules,
      },
      {
        type: "json_schema",
        name: "planning_plan",
        strict: true,
        schema: planSchema,
      },
    )),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? "OpenAI request failed");
  }

  const outputText = extractOutputText(payload);
  if (!outputText) {
    throw new Error("OpenAI returned no structured output text");
  }

  return JSON.parse(outputText) as GeneratedPlan;
}

async function runReplacementGeneration(context: Record<string, unknown>, model: string): Promise<{ candidates: ReplacementCandidateInput[] }> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const touchpointConfig = planningAITouchpoint("workout_replacements", { workoutTaxonomyRules });
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(responsesRequestPayload(
      model,
      touchpointConfig,
      {
        task: "recommend_workout_replacements",
        context,
        rules: touchpointConfig.userRules,
      },
      {
        type: "json_schema",
        name: "replacement_candidates",
        strict: true,
        schema: replacementSchema,
      },
    )),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? "OpenAI request failed");
  }

  const outputText = extractOutputText(payload);
  if (!outputText) {
    throw new Error("OpenAI returned no replacement output");
  }

  return JSON.parse(outputText) as { candidates: ReplacementCandidateInput[] };
}

async function runWorkoutAdditionGeneration(context: Record<string, unknown>, model: string): Promise<{ candidates: WorkoutCandidateInput[] }> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const touchpointConfig = planningAITouchpoint("workout_additions", { workoutTaxonomyRules });
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(responsesRequestPayload(
      model,
      touchpointConfig,
      {
        task: "recommend_workout_additions",
        context,
        rules: touchpointConfig.userRules,
      },
      {
        type: "json_schema",
        name: "workout_addition_candidates",
        strict: true,
        schema: replacementSchema,
      },
    )),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? "OpenAI request failed");
  }

  const outputText = extractOutputText(payload);
  if (!outputText) {
    throw new Error("OpenAI returned no addition output");
  }

  return JSON.parse(outputText) as { candidates: WorkoutCandidateInput[] };
}

async function runWorkoutDescriptionInterpretation(context: Record<string, unknown>, model: string): Promise<{ candidate: WorkoutCandidateInput }> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const touchpointConfig = planningAITouchpoint("workout_interpretation", { workoutTaxonomyRules });
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(responsesRequestPayload(
      model,
      touchpointConfig,
      {
        task: "interpret_workout_description",
        context,
        rules: touchpointConfig.userRules,
      },
      {
        type: "json_schema",
        name: "workout_candidate",
        strict: true,
        schema: workoutCandidateSchema,
      },
    )),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? "OpenAI request failed");
  }

  const outputText = extractOutputText(payload);
  if (!outputText) {
    throw new Error("OpenAI returned no interpreted workout");
  }

  return JSON.parse(outputText) as { candidate: WorkoutCandidateInput };
}

function sanitizeReplacementCandidates(
  generated: { candidates?: ReplacementCandidateInput[] },
  workout: Record<string, any>,
  surroundingWorkouts: Record<string, any>[] = [],
  weatherContext: Record<string, any> | null = null,
): ReplacementCandidate[] {
  const candidates = Array.isArray(generated.candidates) ? generated.candidates : [];
  const fallbacks = fallbackReplacementCandidates(workout, surroundingWorkouts, weatherContext);
  const sanitized = candidates.slice(0, 3).map((candidate, index) =>
    sanitizeWorkoutCandidate(candidate, fallbacks[index] ?? fallbackReplacementCandidate(workout, index), `candidate-${index + 1}`)
  );

  return sanitized.length > 0 ? sanitized : fallbacks;
}

function sanitizeWorkoutCandidates(
  generated: { candidates?: WorkoutCandidateInput[] },
  fallbacks: WorkoutCandidate[],
): WorkoutCandidate[] {
  const candidates = Array.isArray(generated.candidates) ? generated.candidates : [];
  const sanitized = candidates.slice(0, 3).map((candidate, index) =>
    sanitizeWorkoutCandidate(candidate, fallbacks[index] ?? fallbacks[0], `candidate-${index + 1}`)
  );

  return sanitized.length > 0 ? sanitized : fallbacks.slice(0, 3);
}

function sanitizeWorkoutCandidate(
  candidate: WorkoutCandidateInput | null | undefined,
  fallback: WorkoutCandidate,
  id: string,
): WorkoutCandidate {
  const activityType = normalizeActivity(candidate?.activityType || fallback.activityType || "training");
  const intensityLabel = compactWorkoutText(candidate?.intensityLabel || fallback.intensityLabel || "Moderate", 28);
  const title = compactWorkoutTitle(candidate?.title || fallback.title || titleCase(activityType), activityType);
  const purpose = compactWorkoutText(candidate?.purpose || fallback.purpose || "Useful workout", 48);
  const text = `${activityType} ${title} ${intensityLabel} ${purpose} ${JSON.stringify(candidate?.prescription ?? fallback.prescription ?? {})}`.toLowerCase();
  return {
    id,
    title,
    activityType,
    durationMinutes: Math.max(10, candidate?.durationMinutes || fallback.durationMinutes || 30),
    estimatedDistanceKilometers: candidate?.estimatedDistanceKilometers ?? fallback.estimatedDistanceKilometers ?? distanceKilometersFromText(text),
    estimatedElevationMeters: elevationEligibleActivity(activityType, title, purpose)
      ? candidate?.estimatedElevationMeters ?? fallback.estimatedElevationMeters ?? elevationMetersFromText(text)
      : null,
    plannedLocationLabel: compactNullableText(candidate?.plannedLocationLabel) ?? fallback.plannedLocationLabel ?? null,
    intensityLabel,
    purpose,
    prescription: candidate?.prescription ?? fallback.prescription ?? fallbackPrescription(title, activityType, intensityLabel),
    fuelingSummary: candidate?.fuelingSummary?.trim() || fallback.fuelingSummary || fuelingSummary(activityType, intensityLabel),
    rationale: compactWorkoutText(candidate?.rationale || fallback.rationale || "Fits the plan without adding much friction.", 96),
    weeklyImpact: compactWorkoutText(candidate?.weeklyImpact || fallback.weeklyImpact || "Keeps the surrounding week steady.", 96),
  };
}

function compactWorkoutTitle(value: string, fallbackActivity: string) {
  const cleaned = value
    .replace(/[—–-]+/g, ", ")
    .replace(/\s*,\s*/g, ", ")
    .replace(/\s+/g, " ")
    .trim();
  const title = cleaned || titleCase(fallbackActivity);
  return compactWorkoutText(sentenceCase(title), 54);
}

function compactWorkoutText(value: string, maxLength: number) {
  const cleaned = value
    .replace(/[—–]/g, ",")
    .replace(/\s+/g, " ")
    .trim();
  if (cleaned.length <= maxLength) return cleaned;
  const words = cleaned.split(" ");
  let output = "";
  for (const word of words) {
    const next = output ? `${output} ${word}` : word;
    if (next.length > maxLength - 1) break;
    output = next;
  }
  return output ? `${output.replace(/[,.]$/, "")}.` : cleaned.slice(0, maxLength - 1).trim();
}

function sentenceCase(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return trimmed;
  return trimmed.charAt(0).toLowerCase() + trimmed.slice(1);
}

function fallbackReplacementCandidates(
  workout: Record<string, any>,
  surroundingWorkouts: Record<string, any>[],
  weatherContext: Record<string, any> | null = null,
): ReplacementCandidate[] {
  const duration = Math.max(15, Math.round((workout.duration_minutes ?? 30) * 0.7));
  const originalType = normalizeActivity(workout.activity_type ?? "");
  const avoidOutdoor = weatherContext?.shouldAvoidOutdoor === true;
  const hasStrengthNearby = surroundingWorkouts.some((item) =>
    item.id !== workout.id && /strength|lift/.test(`${item.activity_type ?? ""} ${item.title ?? ""}`.toLowerCase())
  );
  const aerobicType = /run/.test(originalType) ? "run" : "ride";
  if (avoidOutdoor && isOutdoorWorkoutActivity(originalType)) {
    return [
      {
        id: "candidate-1",
        title: "Full Body A",
        activityType: "strength",
        durationMinutes: duration,
        intensityLabel: "Moderate",
        purpose: "Indoor strength",
        plannedLocationLabel: null,
        prescription: fallbackPrescription("Full Body A", "strength", "Moderate"),
        fuelingSummary: fuelingSummary("strength", "Moderate"),
        rationale: "Weather makes indoor strength the safer second-best option.",
        weeklyImpact: "Keeps useful load without forcing outdoor conditions.",
      },
      {
        id: "candidate-2",
        title: "Mobility reset",
        activityType: "mobility",
        durationMinutes: Math.min(duration, 30),
        intensityLabel: "Low",
        purpose: "Recovery support",
        plannedLocationLabel: null,
        prescription: fallbackPrescription("Mobility reset", "mobility", "Low"),
        fuelingSummary: fuelingSummary("mobility", "Low"),
        rationale: "This protects consistency without fighting the weather.",
        weeklyImpact: "Low recovery load; the week can usually stay intact.",
      },
    ];
  }
  const candidates: ReplacementCandidate[] = [
    {
      id: "candidate-1",
      title: "Lower dose",
      activityType: originalType || "training",
      durationMinutes: duration,
      intensityLabel: "Low",
      purpose: workout.purpose || "Preserve the session intent with less load",
      plannedLocationLabel: null,
      prescription: fallbackPrescription("Lower dose", originalType || "training", "Low"),
      fuelingSummary: fuelingSummary(originalType || "training", "Low"),
      rationale: "This keeps the original purpose but makes it easier to start today.",
      weeklyImpact: "No broader repair is needed unless this becomes a pattern.",
    },
    {
      id: "candidate-2",
      title: hasStrengthNearby ? "Base Ride" : "Full Body A",
      activityType: hasStrengthNearby ? aerobicType : "strength",
      durationMinutes: hasStrengthNearby ? 30 : duration,
      intensityLabel: hasStrengthNearby ? "Zone 2" : "Moderate",
      purpose: hasStrengthNearby ? "Aerobic base" : "Strength anchor",
      plannedLocationLabel: null,
      prescription: fallbackPrescription(hasStrengthNearby ? "Base Ride" : "Full Body A", hasStrengthNearby ? aerobicType : "strength", hasStrengthNearby ? "Zone 2" : "Moderate"),
      fuelingSummary: fuelingSummary(hasStrengthNearby ? aerobicType : "strength", hasStrengthNearby ? "Zone 2" : "Moderate"),
      rationale: "This is the next-best useful stimulus without overloading the plan.",
      weeklyImpact: "Keep the remaining week unchanged and watch recovery spacing.",
    },
  ];

  return candidates;
}

function fallbackReplacementCandidate(workout: Record<string, any>, index: number): ReplacementCandidate {
  return {
    id: `candidate-${index + 1}`,
    title: fallbackReplacementTitle(workout, index),
    activityType: normalizeActivity(workout.activity_type ?? "training"),
    durationMinutes: Math.max(15, Math.round((workout.duration_minutes ?? 30) * 0.7)),
    intensityLabel: index === 0 ? "Low" : "Moderate",
    purpose: workout.purpose || "Preserve the session intent with less friction",
    plannedLocationLabel: null,
    prescription: fallbackPrescription(fallbackReplacementTitle(workout, index), workout.activity_type ?? "training", index === 0 ? "Low" : "Moderate"),
    fuelingSummary: fuelingSummary(workout.activity_type ?? "training", index === 0 ? "Low" : "Moderate"),
    rationale: "This keeps the training intent while lowering friction for this slot.",
    weeklyImpact: "The surrounding week can stay as planned unless recovery changes.",
  };
}

function fallbackReplacementTitle(workout: Record<string, any>, index: number) {
  if (index === 0) return "Lower dose";
  if (/strength/.test(`${workout.activity_type ?? ""} ${workout.title ?? ""}`.toLowerCase())) return "Base Ride";
  return "Full Body A";
}

async function loadWorkoutPlanningContext(
  admin: SupabaseAdminClient,
  userID: string,
  scope: PlanningScope,
  scheduledDate: string,
) {
  const date = parseDateOnly(scheduledDate) ?? new Date();
  const window = twoWeekWindow(date);
  const weekStart = isoDate(startOfWeek(date));
  const weeklyPlans = await visibleWeeklyPlans(admin, userID, scope.strategy.id, window);
  const planIDs = weeklyPlans.map((plan: Record<string, any>) => plan.id);
  const [surroundingWorkouts, phases] = await Promise.all([
    list(
      admin
        .from("planned_workouts")
        .select()
        .eq("user_id", userID)
        .in("weekly_plan_id", planIDs.length > 0 ? planIDs : ["00000000-0000-0000-0000-000000000000"])
        .gte("scheduled_date", window.start)
        .lte("scheduled_date", window.end)
        .not("status", "in", "(deleted,superseded)")
        .order("scheduled_date", { ascending: true })
        .order("sequence_order", { ascending: true }),
    ),
    list(
      admin
        .from("fitness_strategy_phases")
        .select()
        .eq("user_id", userID)
        .eq("fitness_strategy_id", scope.strategy.id)
        .order("sequence_order", { ascending: true }),
    ),
  ]);
  const weeklyRhythms = weeklyPlans.map(weeklyPlanAsRhythm);
  const weeklyPlan = weeklyPlans.find((plan: Record<string, any>) => plan.week_start_date === weekStart) ?? null;
  const dateForecastWorkout = surroundingWorkouts.find((workout: Record<string, any>) =>
    workout.scheduled_date === scheduledDate && workout.weather_forecast_json && Object.keys(workout.weather_forecast_json).length > 0
  );

  return {
    block: scope.block,
    strategy: scope.strategy,
    homeLocationLabel: scope.homeLocationLabel,
    scheduledDate,
    weekStart,
    weeklyPlan,
    weeklyRhythm: weeklyRhythms.find((rhythm: Record<string, any>) => rhythm.week_start_date === weekStart) ?? null,
    surroundingWorkouts,
    phases,
    weeklyRhythms,
    window,
    weatherContext: await planningWeatherContextForDate(
      scope,
      scheduledDate,
      dateForecastWorkout?.planned_location_label ?? null,
      dateForecastWorkout?.weather_forecast_json ?? null,
    ),
  };
}

function fallbackAdditionCandidates(context: Record<string, any>): WorkoutCandidate[] {
  const scheduledDate = String(context.scheduledDate ?? isoDate(new Date()));
  const weekStart = startOfWeek(parseDateOnly(scheduledDate) ?? new Date());
  const weekWorkouts = workoutsForWeek(context.surroundingWorkouts ?? [], weekStart);
  const dateWorkouts = (context.surroundingWorkouts ?? []).filter((workout: Record<string, any>) => workout.scheduled_date === scheduledDate);
  const avoidOutdoor = context.weatherContext?.shouldAvoidOutdoor === true && !explicitOutdoorIntent(String(context.userIntent ?? ""));
  const hasStrength = weekWorkouts.some((workout: Record<string, any>) => trainingProfile(workout).dimensions.includes("neuromuscular"));
  const hasEndurance = weekWorkouts.some((workout: Record<string, any>) => trainingProfile(workout).dimensions.includes("endurance"));
  const hasHardNearby = weekWorkouts.some((workout: Record<string, any>) => {
    const days = absoluteCalendarDaysBetween(parseDateOnly(workout.scheduled_date) ?? weekStart, parseDateOnly(scheduledDate) ?? weekStart);
    return days <= 1 && trainingProfile(workout).load === "high";
  });

  const candidates: WorkoutCandidate[] = [];
  if (avoidOutdoor) {
    candidates.push(additionCandidate("Full Body A", "strength", 40, "Moderate", "Indoor strength", "Weather makes indoor strength the safer useful option.", "Adds manageable load without relying on outdoor conditions."));
    candidates.push(additionCandidate("Mobility reset", "mobility", 25, "Low", "Recovery support", "This protects consistency without fighting the weather.", "Low recovery load; the rest of the week should usually stay intact."));
    if (hasStrength) {
      candidates.push(additionCandidate("Gym cardio", "indoor_cycling", 30, "Zone 2", "Aerobic base", "This keeps endurance indoors while conditions are poor.", "Adds controlled endurance load without changing the week much."));
    }
    return candidates.slice(0, 3).map((candidate, index) => ({ ...candidate, id: `candidate-${index + 1}` }));
  }
  if (dateWorkouts.length > 0 || hasHardNearby) {
    candidates.push(additionCandidate("Mobility reset", "mobility", 25, "Low", "Recovery support", "This keeps the added day useful without crowding nearby load.", "Low recovery load; the rest of the week should usually stay intact."));
  }
  if (!hasEndurance) {
    candidates.push(additionCandidate("Base Ride", "ride", 35, "Zone 2", "Aerobic base", "This fills an endurance gap without making the day too sharp.", "Adds low-to-moderate endurance work; HAYF will still check spacing after you confirm."));
  }
  if (!hasStrength) {
    candidates.push(additionCandidate("Full Body A", "strength", 40, "Moderate", "Strength", "This gives the week useful strength exposure without chasing maximum load.", "Adds neuromuscular load; HAYF will check nearby hard sessions after you confirm."));
  }
  if (!candidates.some((candidate) => candidate.title === "Base Ride")) {
    candidates.push(additionCandidate("Base Ride", "ride", 35, "Zone 2", "Aerobic base", "This is a useful low-friction endurance option for an open training impulse.", "Adds manageable endurance load; HAYF will check spacing after you confirm."));
  }
  if (!candidates.some((candidate) => candidate.title === "Full Body A")) {
    candidates.push(additionCandidate("Full Body A", "strength", 40, "Moderate", "Strength", "This is a useful strength option if the day can handle more load.", "Adds neuromuscular load; HAYF will check nearby hard sessions after you confirm."));
  }
  candidates.push(additionCandidate("Easy movement", "walk", 30, "Low", "Consistency support", "This preserves the impulse to train while keeping recovery easy.", "Minimal load; useful when the week is already full."));

  return candidates.slice(0, 3).map((candidate, index) => ({ ...candidate, id: `candidate-${index + 1}` }));
}

function additionCandidate(
  title: string,
  activityType: string,
  durationMinutes: number,
  intensityLabel: string,
  purpose: string,
  rationale: string,
  weeklyImpact: string,
): WorkoutCandidate {
  return {
    id: "candidate-1",
    title,
    activityType,
    durationMinutes,
    estimatedDistanceKilometers: distanceKilometersFromText(`${activityType} ${title}`),
    estimatedElevationMeters: null,
    plannedLocationLabel: null,
    intensityLabel,
    purpose,
    prescription: workoutPrescription(title, activityType, intensityLabel, title),
    fuelingSummary: fuelingSummary(activityType, intensityLabel),
    rationale,
    weeklyImpact,
  };
}

function fallbackManualWorkoutCandidate(text: string, workout: Record<string, any> | undefined, scheduledDate: string): WorkoutCandidate {
  const activityType = normalizeActivity(text);
  const title = manualWorkoutTitle(text, activityType);
  const intensityLabel = manualIntensity(text);
  const durationMinutes = manualDurationMinutes(text, activityType);
  const estimatedDistanceKilometers = distanceKilometersFromText(text);
  const estimatedElevationMeters = elevationEligibleActivity(activityType, title, text) ? elevationMetersFromText(text) : null;
  const plannedLocationLabel = locationLabelFromWorkoutText(text);
  const sparse = isSparseWorkoutDescription(text);

  return {
    id: "candidate-1",
    title,
    activityType,
    durationMinutes,
    estimatedDistanceKilometers,
    estimatedElevationMeters,
    plannedLocationLabel,
    intensityLabel,
    purpose: manualPurpose(activityType, workout),
    prescription: workoutPrescription(title, activityType, intensityLabel, text),
    fuelingSummary: fuelingSummary(activityType, intensityLabel),
    rationale: sparse
      ? "Conservative read of your note."
      : "Structured from your description.",
    weeklyImpact: workout
      ? "Replaces this slot; review can adjust around it."
      : `Adds load on ${scheduledDate}; review can adjust around it.`,
  };
}

function withResolvedWorkoutLocation(candidate: WorkoutCandidate, userText: string, homeLocationLabel?: string | null): WorkoutCandidate {
  const candidateLocation = compactNullableText(candidate.plannedLocationLabel);
  if (candidateLocation) {
    return {
      ...candidate,
      plannedLocationLabel: sameLocationLabel(candidateLocation, homeLocationLabel) ? null : candidateLocation,
    };
  }

  const fallbackLocation = locationLabelFromWorkoutText(userText);
  if (!fallbackLocation) return candidate;
  return {
    ...candidate,
    plannedLocationLabel: sameLocationLabel(fallbackLocation, homeLocationLabel) ? null : fallbackLocation,
  };
}

function withResolvedWorkoutIntent(candidate: WorkoutCandidate, userText: string, homeLocationLabel?: string | null): WorkoutCandidate {
  return withResolvedWorkoutLocation(withResolvedWorkoutModality(candidate, userText), userText, homeLocationLabel);
}

function withResolvedWorkoutModality(candidate: WorkoutCandidate, userText: string): WorkoutCandidate {
  if (explicitWalkIntent(userText)) {
    const easy = /\b(easy|low|recovery|recover|gentle|light)\b/i.test(userText);
    return {
      ...candidate,
      activityType: "walk",
      title: easy ? "Recovery Walk" : "Walk",
      estimatedElevationMeters: null,
      purpose: candidate.purpose || (easy ? "Recovery support" : "Walking"),
    };
  }
  return candidate;
}

function explicitWalkIntent(text: string) {
  const lower = text.toLowerCase();
  return /\bwalk(?:ing|s)?\b/.test(lower) && !/\bhik(?:e|ing|es)?\b/.test(lower);
}

function resolvedCandidateLocationLabel(candidate: WorkoutCandidateInput) {
  const explicitLocation = compactNullableText(candidate.plannedLocationLabel);
  const candidateText = [
    explicitLocation,
    candidate.title,
    candidate.activityType,
    candidate.purpose,
    JSON.stringify(candidate.prescription ?? {}),
  ].filter(Boolean).join(" ");
  if (explicitLocation) return explicitLocation;
  return locationLabelFromWorkoutText(candidateText);
}

function looksLikeWorkoutDescription(text: string) {
  const lower = text.toLowerCase();
  return /run|ride|bike|cycle|swim|row|hike|walk|strength|lift|gym|mobility|yoga|pilates|stretch|climb|boulder|workout|session|interval|tempo|zone|cardio|hiit|legs|upper|lower|core/.test(lower);
}

function isSparseWorkoutDescription(text: string) {
  const lower = text.trim().toLowerCase();
  return lower.split(/\s+/).length <= 2 && !/\d/.test(lower);
}

function manualWorkoutTitle(text: string, activityType: string) {
  const lower = text.toLowerCase();
  if (activityType === "hike") return /hard|high|mountain/.test(lower) ? "Hard Hike" : /long|route|elevation|vert|\d/.test(lower) ? "Long Hike" : "Easy Hike";
  if (activityType === "ride") return /interval|vo2/.test(lower) ? "Intervals Ride" : /recover|easy spin/.test(lower) ? "Recovery Ride" : /long/.test(lower) ? "Long Ride" : /tempo|threshold|steady/.test(lower) ? "Tempo Ride" : "Base Ride";
  if (activityType === "run") return /tempo|threshold/.test(lower) ? "Tempo Run" : /interval|vo2/.test(lower) ? "Intervals Run" : /long|\d/.test(lower) ? "Long Run" : "Base Run";
  if (activityType === "strength") return /upper/.test(lower) ? "Upper Body A" : /lower|legs/.test(lower) ? "Lower Body A" : "Full Body A";
  if (activityType === "mobility") return "Mobility";
  if (activityType === "walk") return "Walk";
  if (activityType === "climb") return "Climb";
  return titleCase(activityType);
}

function manualIntensity(text: string) {
  const lower = text.toLowerCase();
  if (/hard|high|heavy|interval|threshold|tempo|vo2|race|max/.test(lower)) return "High";
  const distance = distanceKilometersFromText(lower) ?? 0;
  const elevation = elevationMetersFromText(lower) ?? 0;
  if (/hik/.test(lower)) {
    if (distance >= 20 || elevation >= 1000 || (distance >= 15 && elevation >= 700)) return "High";
    if (distance >= 10 || elevation >= 400 || (distance >= 8 && elevation >= 250)) return "Moderate";
  }
  if (/ride|cycl|bike/.test(lower)) {
    if (distance >= 100 || elevation >= 1200 || (distance >= 80 && elevation >= 800)) return "High";
    if (distance >= 60 || elevation >= 500 || (distance >= 45 && elevation >= 300)) return "Moderate";
  }
  if (/easy|low|recovery|gentle|light/.test(lower)) return "Low";
  if (/zone\s*2|z2/.test(lower)) return "Zone 2";
  if (/steady|long|moderate|elevation|vert/.test(lower)) return "Moderate";
  return "Moderate";
}

function manualDurationMinutes(text: string, activityType: string) {
  const lower = text.toLowerCase();
  const hourMatch = lower.match(/(\d+(?:[.,]\d+)?)\s*(?:h|hr|hrs|hour|hours)\b/);
  if (hourMatch) return Math.max(10, Math.round(Number(hourMatch[1].replace(",", ".")) * 60));
  const minuteMatch = lower.match(/(\d+(?:[.,]\d+)?)\s*(?:m|min|mins|minute|minutes)\b/);
  if (minuteMatch) return Math.max(10, Math.round(Number(minuteMatch[1].replace(",", "."))));

  const distance = distanceKilometersFromText(lower);
  if (distance) {
    if (activityType === "hike") return Math.max(45, Math.round((distance / 4.5) * 60));
    if (activityType === "run") return Math.max(20, Math.round(distance * 6));
    if (activityType === "ride") return Math.max(30, Math.round(distance * 2.5));
    if (activityType === "walk") return Math.max(20, Math.round(distance * 12));
  }

  if (activityType === "hike") return 60;
  if (activityType === "strength") return 45;
  if (activityType === "mobility" || activityType === "walk") return 30;
  return 45;
}

function distanceKilometersFromText(text: string) {
  const match = text.match(/(\d+(?:[.,]\d+)?)\s*(?:km|kilometer|kilometers|kilometre|kilometres)\b/);
  if (match) return parsedNumber(match[1]);
  const shorthand = text.match(/(\d+(?:[.,]\d+)?)\s*k\b(?!\s*m)/);
  if (shorthand) return parsedNumber(shorthand[1]);
  return null;
}

function locationLabelFromWorkoutText(text: string) {
  const normalized = text.replace(/[.,;]+$/g, "").replace(/\s+/g, " ").trim();
  const explicitMatch = normalized.match(/\b(?:in|at|near|around)\s+([a-z][a-z\s.'-]{1,48})$/i);
  const rawLocation = explicitMatch?.[1] ?? normalized.match(/\b(?:run|ride|bike|cycle|swim|row|hike|walk|strength|lift|gym|mobility|yoga|pilates|stretch|climb|boulder|workout|session)\b[\s\S]*?\b(?:zone\s*2|z2|easy|low|recovery|moderate|steady|tempo|threshold|hard|high|heavy|intervals?|vo2|max|\d+(?:[.,]\d+)?\s*(?:km|k|m|min|mins|minutes|h|hr|hrs|hour|hours))\s+([a-z][a-z\s.'-]{1,48})$/i)?.[1];
  if (!rawLocation) return null;

  const location = rawLocation
    .replace(/\b(?:today|tomorrow|tonight|morning|afternoon|evening|zone|z2|easy|low|recovery|moderate|steady|tempo|threshold|hard|high|heavy|intervals?|vo2|max)\b.*$/i, "")
    .replace(/\b(?:run|ride|bike|cycle|swim|row|hike|walk|strength|lift|gym|mobility|yoga|pilates|stretch|climb|boulder|workout|session)\b/gi, "")
    .trim();
  if (!location || location.split(/\s+/).length > 4) return null;
  if (/^\d/.test(location)) return null;
  return titleCase(location);
}

function sameLocationLabel(left: string | null | undefined, right: string | null | undefined) {
  const normalizedLeft = normalizedPrimaryLocationLabel(left);
  const normalizedRight = normalizedPrimaryLocationLabel(right);
  return Boolean(
    normalizedLeft &&
    normalizedRight &&
    (
      normalizedLeft === normalizedRight ||
      normalizedLeft.startsWith(`${normalizedRight} `) ||
      normalizedRight.startsWith(`${normalizedLeft} `)
    ),
  );
}

function normalizedPrimaryLocationLabel(value: string | null | undefined) {
  const primary = compactNullableText(value)?.split(",")[0];
  return primary ? normalizedLocationLookupText(primary) : null;
}

function normalizedLocationLookupText(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function elevationMetersFromText(text: string) {
  const lower = text.toLowerCase();
  const patterns = [
    /(\d+(?:[.,]\d+)?)\s*k\s*m\s*(?:elev|elevation|gain|climb|climbing|vert|vertical|ascent)\b/,
    /(\d+(?:[.,]\d+)?)\s*(?:m|meter|meters|metre|metres)\s*(?:elev|elevation|gain|climb|climbing|vert|vertical|ascent)\b/,
    /(?:elev|elevation|gain|climb|climbing|vert|vertical|ascent)\s*(?:of\s*)?(\d+(?:[.,]\d+)?)\s*(k)?\s*m\b/,
    /\b(\d{3,5})\s*m\b/,
  ];
  for (const pattern of patterns) {
    const match = lower.match(pattern);
    if (!match) continue;
    const value = parsedNumber(match[1]);
    if (!Number.isFinite(value)) continue;
    const thousands = /\d+(?:[.,]\d+)?\s*k\s*m/.test(match[0]) || match[2] === "k";
    return thousands ? Math.round(value * 1000) : Math.round(value);
  }
  return null;
}

function parsedNumber(value: string) {
  const text = String(value ?? "");
  const commaParts = text.split(",");
  if (commaParts.length === 2 && commaParts[1].length === 3) {
    return Number(commaParts.join(""));
  }
  return Number(text.replace(",", "."));
}

function manualPurpose(activityType: string, workout: Record<string, any> | undefined) {
  if (workout?.purpose) return workout.purpose;
  if (activityType === "strength") return "Strength";
  if (["run", "ride", "swim", "row", "hike"].includes(activityType)) return "Endurance support";
  if (["mobility", "walk", "recovery"].includes(activityType)) return "Recovery support";
  return "User-described workout";
}

function workoutPrescription(title: string, activityType: string, intensity: string, description: string) {
  if (activityType === "strength") {
    return {
      warmup: "8-10 min easy movement and ramp-up sets",
      main: description,
      cooldown: "3-5 min easy mobility",
      successCriteria: "Keep form clean and stop with 1-2 reps in reserve.",
    };
  }
  if (["run", "ride", "swim", "row", "hike", "walk"].includes(activityType)) {
    return {
      warmup: "Start easy for 8-10 min",
      main: description || `${title} at ${intensity}`,
      cooldown: "Finish easy for 5-10 min",
      successCriteria: "Keep the effort controlled enough to recover for the next planned session.",
    };
  }
  return {
    warmup: "Start easy",
    main: description || title,
    cooldown: "Finish easy",
    successCriteria: "Finish feeling better than you started.",
  };
}

function throwIfPastPlanningDate(scheduledDate: string, timezone: string) {
  const parsed = parseDateOnly(scheduledDate);
  if (!parsed) {
    throw new Error("Use a valid scheduledDate.");
  }
  if (scheduledDate < isoDate(todayInTimezone(timezone))) {
    throw new Error("Workouts can only be added or manually changed for today or future days.");
  }
}

function parseTimestamp(value: string | undefined) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function timezoneDateParts(date: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    weekday: "short",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    hour12: false,
  }).formatToParts(date);
  const value = (type: string) => parts.find((part) => part.type === type)?.value;
  return {
    weekday: value("weekday") ?? "",
    year: value("year") ?? "1970",
    month: value("month") ?? "01",
    day: value("day") ?? "01",
    hour: Number(value("hour") ?? "0"),
  };
}

function dateOnlyInTimezone(date: Date, timezone: string) {
  const parts = timezoneDateParts(date, timezone);
  return parseDateOnly(`${parts.year}-${parts.month}-${parts.day}`) ?? date;
}

function firstCommittedWeekStart(acceptedAt: Date, timezone: string) {
  const localDate = dateOnlyInTimezone(acceptedAt, timezone);
  const weekStart = startOfWeek(localDate);
  const parts = timezoneDateParts(acceptedAt, timezone);
  return parts.weekday === "Sun" && parts.hour >= 21 ? addDays(weekStart, 7) : weekStart;
}

async function supersedeActivePlanningRows(admin: SupabaseAdminClient, userID: string) {
  await throwOnError(
    admin
      .from("fitness_strategies")
      .update({ status: "superseded" })
      .eq("user_id", userID)
      .eq("status", "active"),
  );
  await throwOnError(
    admin
      .from("user_goals")
      .update({ status: "superseded" })
      .eq("user_id", userID)
      .eq("status", "active"),
  );
}

async function ensureAthleteProfile(admin: SupabaseAdminClient, userID: string) {
  const existing = await maybeSingle(admin.from("athlete_profiles").select().eq("user_id", userID).limit(1));
  if (existing) return existing;

  return single(
    admin.from("athlete_profiles").insert({ user_id: userID }).select().single(),
    "Could not create athlete profile",
  );
}

async function createAcceptedBlueprintRevision(
  admin: SupabaseAdminClient,
  userID: string,
  athleteProfile: Record<string, any>,
  acceptedBlueprint: Record<string, unknown>,
  healthSnapshot: Record<string, unknown> | null | undefined,
  acceptedAt: Date,
) {
  const existing = await list(
    admin
      .from("athlete_blueprint_revisions")
      .select("revision_number")
      .eq("athlete_profile_id", athleteProfile.id)
      .order("revision_number", { ascending: false })
      .limit(1),
  );
  const revisionNumber = Number(existing[0]?.revision_number ?? 0) + 1;
  const revision = await single(
    admin
      .from("athlete_blueprint_revisions")
      .insert({
        athlete_profile_id: athleteProfile.id,
        user_id: userID,
        revision_number: revisionNumber,
        generation_reason: "initial_post_onboarding",
        coach_read: stringAt(objectAt(acceptedBlueprint, "coachRead"), "text") || stringAt(acceptedBlueprint, "coachRead") || "",
        athlete_archetype_json: objectAt(acceptedBlueprint, "archetype") ?? {},
        current_training_state_json: objectAt(acceptedBlueprint, "currentTrainingState") ?? {},
        history_findings_json: arrayAt(acceptedBlueprint, "historyFindings"),
        goal_fit_json: objectAt(acceptedBlueprint, "goalFit") ?? {},
        planning_inputs_json: { acceptedBlueprint },
        evidence_packet_json: { healthSnapshot: healthSnapshot ?? null },
        evidence_packet_version: "v1",
        accepted_at: acceptedAt.toISOString(),
      })
      .select()
      .single(),
    "Could not create athlete blueprint revision",
  );

  await throwOnError(
    admin
      .from("athlete_profiles")
      .update({ current_blueprint_revision_id: revision.id })
      .eq("id", athleteProfile.id)
      .eq("user_id", userID),
  );

  return revision;
}

function preparedGoalTitle(onboarding: Record<string, any>) {
  const selected = onboarding.selected_answers ?? {};
  return selected.chosenGoal?.title
    || selected.goalBrief
    || selected.goalTarget?.title
    || selected.goalText
    || (blockKind(String(onboarding.intent ?? "")) === "consistency" ? "Build consistency" : "Active goal");
}

async function loadPlanningOnboardingContext(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  const persisted = await maybeSingle(
    admin
      .from("onboarding_profiles")
      .select()
      .eq("id", userID)
      .limit(1),
  );
  if (persisted) return persisted;

  const context = requestBody.onboardingContext ?? requestBody.onboarding_context;
  const intent = stringAt(context ?? {}, "intent");
  if (!context || !intent) {
    throw new Error("prepare_initial_strategy_after_blueprint requires onboarding context before onboarding is completed.");
  }

  return {
    id: null,
    intent,
    selected_answers: context,
    generated_summary: null,
    health_permission_state: null,
  };
}

function buildCompactPlanningPacket(args: {
  blueprintRevision: Record<string, any>;
  acceptedBlueprint: Record<string, unknown>;
  onboarding: Record<string, any>;
  goal: Record<string, any>;
  healthSnapshot: Record<string, unknown> | null;
  timezone: string;
  startDate: string;
}) {
  const selected = args.onboarding.selected_answers ?? {};
  const modalities = selectedModalitiesFromOnboarding(args.onboarding);
  const constraints = planningConstraintsFromOnboarding(args.onboarding);
  return {
    athlete_context: {
      blueprint_revision_id: args.blueprintRevision.id,
      coach_read: String(args.blueprintRevision.coach_read ?? ""),
      athlete_archetype: args.blueprintRevision.athlete_archetype_json ?? {},
      current_training_state: args.blueprintRevision.current_training_state_json ?? {},
      history_findings: args.blueprintRevision.history_findings_json ?? [],
      goal_fit: args.blueprintRevision.goal_fit_json ?? {},
      hidden_inputs: args.blueprintRevision.planning_inputs_json ?? { acceptedBlueprint: args.acceptedBlueprint },
    },
    goal_context: {
      user_goal_id: args.goal.id,
      normalized_goal: args.goal.normalized_goal_json ?? {},
      goal_kind: args.goal.goal_kind,
      timeframe_weeks: args.goal.timeframe_weeks ?? null,
      success_definition: selected.goalBrief ?? selected.markerText ?? null,
      selected_modality_order: modalities,
      body_composition_intent: bodyCompositionIntent(selected),
    },
    planning_constraints: {
      feasible_modalities: modalities.length > 0 ? modalities : constraints.feasibleModalities,
      frequency: selected.frequency?.summary ?? selected.frequency ?? null,
      session_length: selected.sessionLength?.summary ?? selected.sessionCapacity?.summary ?? selected.sessionLength ?? null,
      injuries: selected.injuries ?? selected.injuryNotes ?? null,
      equipment_access: constraints.equipmentAccess,
      avoidances: constraints.avoidances,
      bad_day_floor: selected.badDayFloor?.summary ?? selected.floorSummary ?? selected.floor ?? null,
      timezone: args.timezone,
      start_date: args.startDate,
    },
    approved_evidence_summary: compactEvidenceSummary(args.healthSnapshot),
    generation_policy: {
      visible_horizon_weeks: 2,
      committed_horizon_weeks: 1,
      allowed_claims: [
        "Use only the accepted Athlete Blueprint and compact derived evidence.",
        "Do not infer medical diagnoses or prescribe medical care.",
        "Do not claim raw HealthKit sample access.",
      ],
      ai_first_plan_generation: true,
    },
  };
}

function selectedModalitiesFromOnboarding(onboarding: Record<string, any>) {
  const selected = onboarding.selected_answers ?? {};
  const candidates = [
    selected.trainingOptions,
    selected.selectedTrainingOptions,
    selected.supportingTrainingOptions,
    selected.options,
    selected.modalities,
  ].find(Array.isArray) as unknown[] | undefined;
  const values = (candidates ?? [])
    .map((entry) => {
      if (typeof entry === "string") return entry;
      if (entry && typeof entry === "object") {
        const object = entry as Record<string, any>;
        return object.title ?? object.label ?? object.name ?? object.id;
      }
      return null;
    })
    .filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0);
  return Array.from(new Set(values.map(normalizedModalityLabel))).slice(0, 5);
}

function planningConstraintsFromOnboarding(onboarding: Record<string, any>) {
  const selected = onboarding.selected_answers ?? {};
  const equipmentAccess = compactStringArray(selected.infrastructureAccess ?? selected.equipmentAccess ?? selected.infrastructure ?? []);
  const avoidances = compactStringArray(selected.avoids ?? selected.avoidances ?? selected.blockers ?? []);
  const feasibleModalities = compactStringArray(selected.feasibleModalities ?? selected.trainingOptions ?? [])
    .map(normalizedModalityLabel)
    .filter(Boolean);
  return { equipmentAccess, avoidances, feasibleModalities };
}

function compactStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => {
      if (typeof entry === "string") return entry;
      if (entry && typeof entry === "object") {
        const object = entry as Record<string, any>;
        return object.title ?? object.label ?? object.name ?? object.id ?? null;
      }
      return null;
    })
    .filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0)
    .map((entry) => entry.trim());
}

function bodyCompositionIntent(selected: Record<string, any>) {
  const text = [
    selected.goalBrief,
    selected.markerText,
    selected.chosenGoal?.title,
    selected.chosenGoal?.rationale,
  ].filter(Boolean).join(" ").toLowerCase();
  if (!text) return null;
  if (/weight|fat|lean|muscle|body|aesthetic|athletic look|defined/.test(text)) return text.slice(0, 240);
  return null;
}

function compactEvidenceSummary(snapshot: Record<string, any> | null) {
  if (!snapshot) {
    return {
      recent_training_load: {},
      consistency: {},
      modality_mix: {},
      body_recovery_context: {},
      confidence: "low",
      caveats: ["No HealthKit-derived planning snapshot was available."],
    };
  }

  const fitnessHistory = snapshot.fitnessHistory ?? snapshot.fitness_history ?? {};
  return {
    recent_training_load: {
      generatedAt: snapshotGeneratedAt(snapshot),
      loadWindows: (fitnessHistory.load?.windows ?? []).map((window: Record<string, any>) => ({
        window: window.window,
        workouts: window.workouts,
        totalMinutes: window.totalMinutes,
        totalDistanceKilometers: window.totalDistanceKilometers,
      })),
      workouts7d: snapshot.workoutLedger?.windows?.find?.((window: Record<string, any>) => window.window === "7d")?.workouts ?? null,
    },
    consistency: {
      activeWeeks: fitnessHistory.consistency?.activeWeeks ?? null,
      longestActiveWeekStreak: fitnessHistory.consistency?.longestActiveWeekStreak ?? null,
      longestGapDays: fitnessHistory.consistency?.longestGapDays ?? null,
    },
    modality_mix: {
      trainingIdentity: fitnessHistory.trainingIdentity?.label ?? null,
      dominantModalities: fitnessHistory.trainingIdentity?.dominantModalities ?? [],
      strengthWorkouts90Days: fitnessHistory.strengthContinuity?.strengthWorkouts90Days ?? null,
    },
    body_recovery_context: {
      sleepHoursLastNight: snapshot.recovery?.sleepHoursLastNight ?? null,
      hrvTrend: snapshot.recovery?.hrvTrend ?? null,
      restingHeartRateTrend: snapshot.recovery?.restingHeartRateTrend ?? null,
      bodyMassKilograms: snapshot.body?.bodyMassKilograms ?? null,
      bodyMassTrend: snapshot.body?.bodyMassTrend ?? fitnessHistory.bodyTrend?.bodyMassTrend ?? null,
      bodyFatTrend: snapshot.body?.bodyFatTrend ?? fitnessHistory.bodyTrend?.bodyFatTrend ?? null,
    },
    confidence: fitnessHistory.confidence ?? "medium",
    caveats: Array.isArray(snapshot.notes) ? snapshot.notes.slice(0, 8) : [],
  };
}

function planGenerationPolicy(
  onboarding: Record<string, any> | null,
  trainingArchitecture: Record<string, any> | null,
) {
  const allowedActivities = allowedPlanActivities(onboarding, trainingArchitecture);
  return {
    allowedActivities,
    allowedModalities: allowedActivities.map(displayModalityForActivity),
    hardRules: allowedActivities.length > 0
      ? [
        "Generate planned workouts only from allowedActivities.",
        "Do not introduce off-menu modalities such as rowing, swimming, hiking, walking, or mobility unless they appear in allowedActivities.",
        "Use recovery only as prescription/recovery guidance, not as an extra planned workout modality.",
      ]
      : [],
  };
}

function allowedPlanActivities(
  onboarding: Record<string, any> | null,
  trainingArchitecture: Record<string, any> | null,
) {
  const fromOnboarding = onboarding ? selectedModalitiesFromOnboarding(onboarding) : [];
  const fromArchitecture = compactStringArray([
    ...(Array.isArray(trainingArchitecture?.priority_order) ? trainingArchitecture.priority_order : []),
    ...(Array.isArray(trainingArchitecture?.modality_roles)
      ? trainingArchitecture.modality_roles.map((role: Record<string, any>) => role.modality)
      : []),
  ]);
  const modalities = fromOnboarding.length > 0 ? fromOnboarding : fromArchitecture;
  return Array.from(new Set(
    modalities
      .map((modality) => normalizeActivity(modality))
      .filter((activity) => activity && activity !== "workout" && activity !== "recovery" && activity !== "mobility"),
  ));
}

function displayModalityForActivity(activity: string) {
  if (activity === "ride") return "cycling";
  if (activity === "run") return "running";
  return activity;
}

function normalizedModalityLabel(value: string) {
  const text = value.trim().toLowerCase();
  if (text.includes("cycl")) return "cycling";
  if (text.includes("run")) return "running";
  if (text.includes("strength") || text.includes("gym") || text.includes("lift")) return "strength";
  if (text.includes("walk")) return "walking";
  if (text.includes("mobility") || text.includes("yoga")) return "mobility";
  return text.replace(/\s+/g, "_");
}

function acceptedStrategyGoalTitle(strategy: Record<string, unknown>, onboarding: Record<string, any>) {
  const fromStrategy = stringAt(objectAt(strategy, "goalTargetContext"), "title");
  const selected = onboarding.selected_answers ?? {};
  return fromStrategy || selected.chosenGoal?.title || selected.goalBrief || "Active goal";
}

function acceptedStrategyTitle(strategy: Record<string, unknown>, goalKind: string) {
  const explicit = stringAt(strategy, "title");
  if (explicit) return explicit;
  const hasPhases = acceptedStrategyPhases(strategy).length > 0;
  if (goalKind === "consistency") return "Consistency Strategy";
  return hasPhases ? "Goal Build Strategy" : "Fitness Strategy";
}

function acceptedStrategyTimeframeWeeks(strategy: Record<string, unknown>, onboarding: Record<string, any>) {
  const snapshotItems = arrayAt(strategy, "snapshotItems");
  const item = snapshotItems.find((entry) => stringAt(entry, "id") === "timeframe");
  const fromSnapshot = Number(stringAt(item ?? {}, "value") ?? NaN);
  if (Number.isFinite(fromSnapshot) && fromSnapshot > 0) return Math.round(fromSnapshot);
  const selected = onboarding.selected_answers ?? {};
  const candidate = Number(selected.chosenGoal?.timeline?.weeks ?? selected.goalTimeline?.weeks ?? NaN);
  if (Number.isFinite(candidate) && candidate > 0) return Math.round(candidate);
  return blockKind(String(onboarding.intent ?? "")) === "consistency" ? 12 : 8;
}

function normalizedGoalPayload(strategy: Record<string, unknown>, onboarding: Record<string, any>, timeframeWeeks: number) {
  return {
    title: acceptedStrategyGoalTitle(strategy, onboarding),
    timeframeWeeks,
    source: "accepted_strategy",
    onboardingIntent: onboarding.intent ?? null,
    goalTargetContext: objectAt(strategy, "goalTargetContext") ?? null,
  };
}

function acceptedStrategyPhases(strategy: Record<string, unknown>) {
  return arrayAt(strategy, "phases");
}

async function insertAcceptedStrategyPhases(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  strategy: Record<string, unknown>,
) {
  const phases = acceptedStrategyPhases(strategy);
  const rows: Record<string, any>[] = [];
  for (const [index, phase] of phases.entries()) {
    const saved = await single(
      admin
        .from("fitness_strategy_phases")
        .insert({
          fitness_strategy_id: strategyID,
          user_id: userID,
          sequence_order: index + 1,
          name: stringAt(phase, "name") || `Phase ${index + 1}`,
          objective: stringAt(phase, "objective") || "",
          focus_json: [stringAt(phase, "targetSummary")].filter(Boolean),
          risk_json: [],
        })
        .select()
        .single(),
      "Could not create strategy phase",
    );
    rows.push({ ...saved, artifact_id: stringAt(phase, "id") || saved.id, artifact: phase });
  }
  return rows;
}

async function insertAcceptedPlanningTargets(
  admin: SupabaseAdminClient,
  userID: string,
  goal: Record<string, any>,
  strategy: Record<string, any>,
  phaseRows: Record<string, any>[],
  strategyArtifact: Record<string, unknown>,
  startDate: string,
  targetDate: string | null,
) {
  const rows: Record<string, unknown>[] = [];
  const addTarget = (target: Record<string, unknown>, phaseID?: string | null) => {
    const scope = normalizedTargetScope(stringAt(target, "scope"), phaseID);
    const row = planningTargetRowFromArtifact({
      userID,
      goalID: goal.id,
      strategyID: strategy.id,
      phaseID: phaseID ?? null,
      target,
      scope,
      startDate,
      targetDate,
    });
    if (row) rows.push(row);
  };

  for (const target of arrayAt(strategyArtifact, "targets")) {
    addTarget(target);
  }

  for (const phase of phaseRows) {
    for (const target of arrayAt(phase.artifact ?? {}, "targets")) {
      addTarget(target, phase.id);
    }
  }

  if (rows.length > 0) {
    await throwOnError(admin.from("planning_targets").insert(rows));
  }
}

function normalizedTargetScope(scope: string | undefined, phaseID?: string | null) {
  if (phaseID) return "phase";
  if (scope === "goal" || scope === "strategy" || scope === "phase" || scope === "week" || scope === "session") return scope;
  return "strategy";
}

function planningTargetRowFromArtifact(args: {
  userID: string;
  goalID: string;
  strategyID: string;
  phaseID: string | null;
  target: Record<string, unknown>;
  scope: string;
  startDate: string;
  targetDate: string | null;
}) {
  const title = stringAt(args.target, "title");
  if (!title) return null;
  const scope = args.scope === "week" || args.scope === "session" ? "strategy" : args.scope;
  return {
    user_id: args.userID,
    user_goal_id: scope === "goal" ? args.goalID : null,
    fitness_strategy_id: scope === "strategy" ? args.strategyID : null,
    fitness_strategy_phase_id: scope === "phase" ? args.phaseID : null,
    weekly_plan_id: null,
    planned_workout_id: null,
    target_scope: scope,
    target_kind: normalizedTargetKind(stringAt(args.target, "kind")),
    title,
    description: stringAt(args.target, "summary") || null,
    metric_key: stringAt(args.target, "metricKey") || null,
    metric_category: stringAt(args.target, "metricCategory") || "strategy",
    direction: normalizedTargetDirection(stringAt(args.target, "direction")),
    baseline_value: null,
    target_value: numberAt(args.target, "targetValue"),
    unit: stringAt(args.target, "unit") || null,
    start_date: args.startDate,
    target_date: args.targetDate,
    evaluation_rule_json: { source: "accepted_strategy", displayValue: stringAt(args.target, "displayValue") ?? null },
    source: "planning_engine",
    status: "needs_review",
  };
}

function normalizedTargetKind(kind: string | undefined) {
  return kind === "primary" ? "primary" : "supporting";
}

function normalizedTargetDirection(direction: string | undefined) {
  if (["increase", "decrease", "maintain", "complete", "review"].includes(String(direction))) return direction;
  return "maintain";
}

async function insertWeeklyPlansAndWorkouts(
  admin: SupabaseAdminClient,
  args: {
    userID: string;
    strategyID: string;
    trainingArchitectureID?: string | null;
    rhythms: GeneratedRhythm[];
    source: "generated" | "replanned";
    committedWeekStart: string;
    ownerStartDate: string;
    homeLocationLabel?: string | null;
  },
) {
  const savedPlans: Record<string, any>[] = [];
  for (const rhythm of args.rhythms) {
    const status = rhythm.weekStartDate === args.committedWeekStart ? "committed" : "draft";
    const savedPlan = await single(
      admin
        .from("weekly_plans")
        .upsert(
          {
            fitness_strategy_id: args.strategyID,
            training_architecture_id: args.trainingArchitectureID ?? null,
            user_id: args.userID,
            week_start_date: rhythm.weekStartDate,
            week_end_date: rhythm.weekEndDate,
            status,
            objective: rhythm.objective,
            rhythm_json: {
              priorityOrder: rhythm.priorityOrder,
              hardEasyDistribution: rhythm.hardEasyDistribution,
              badDayFloor: rhythm.badDayFloor,
              swapRules: rhythm.swapRules,
            },
            generated_at: new Date().toISOString(),
          },
          { onConflict: "fitness_strategy_id,week_start_date" },
        )
        .select()
        .single(),
      "Could not upsert weekly plan",
    );
    savedPlans.push(savedPlan);

    const constraints = savedPlan.constraints_json ?? {};
    const workouts = applyWeeklyConstraintsToGeneratedWorkouts(
      rhythm.workouts.filter((workout) => status !== "committed" || workout.scheduledDate >= args.ownerStartDate),
      constraints,
    );
    if (workouts.length === 0) continue;

    const protectedKeys = await protectedGenerationKeysForPlan(admin, args.userID, savedPlan.id);
    const workoutRows = workouts
      .filter((workout) => !protectedKeys.has(generatedWorkoutKey(workout)))
      .map((workout) => ({
        active_block_id: null,
        weekly_rhythm_id: null,
        weekly_plan_id: savedPlan.id,
        user_id: args.userID,
        generation_key: generatedWorkoutKey(workout),
        scheduled_date: workout.scheduledDate,
        sequence_order: workout.sequenceOrder,
        activity_type: workout.activityType,
        title: normalizedWorkoutTitle(workout.activityType, workout.title, workout.durationMinutes, workout.intensityLabel, workout.purpose),
        duration_minutes: workout.durationMinutes,
        intensity_label: workout.intensityLabel,
        purpose: workout.purpose,
        ...workoutCardFields({
          scheduledDate: workout.scheduledDate,
          activityType: workout.activityType,
          title: workout.title,
          durationMinutes: workout.durationMinutes,
          intensityLabel: workout.intensityLabel,
          purpose: workout.purpose,
          locationLabel: args.homeLocationLabel,
        }),
        status: "planned",
        source: args.source,
        prescription_json: workout.prescription,
        fueling_summary: workout.fuelingSummary,
      }));

    if (workoutRows.length === 0) continue;

    await throwOnError(
      admin
        .from("planned_workouts")
        .upsert(workoutRows, {
          onConflict: "user_id,weekly_plan_id,generation_key",
          ignoreDuplicates: true,
        }),
    );
  }
  return savedPlans;
}

async function protectedGenerationKeysForPlan(admin: SupabaseAdminClient, userID: string, weeklyPlanID: string) {
  const rows = await list(
    admin
      .from("planned_workouts")
      .select("scheduled_date,sequence_order,status,source")
      .eq("user_id", userID)
      .eq("weekly_plan_id", weeklyPlanID)
      .neq("status", "superseded"),
  );

  const keys = new Set<string>();
  for (const row of rows) {
    const source = String(row.source ?? "");
    const status = String(row.status ?? "");
    const isMutableGeneratedSlot = ["generated", "replanned"].includes(source) && ["planned", "current"].includes(status);
    if (!isMutableGeneratedSlot) {
      keys.add(`${row.scheduled_date}:${row.sequence_order ?? 1}`);
    }
  }
  return keys;
}

function generatedWorkoutKey(workout: GeneratedWorkout) {
  return `${workout.scheduledDate}:${workout.sequenceOrder}`;
}

const workoutTaxonomyRules =
  "Workout title taxonomy: do not include emojis in stored titles. Rides use Base Ride, Long Ride, Intervals Ride, Recovery Ride, or Tempo Ride. Runs use Base Run, Long Run, Intervals Run, Recovery Run, or Tempo Run. Walks use Walk or Recovery Walk; never convert an explicit walk request into a hike unless the user also says hike. Hikes use Easy Hike, Long Hike, or Hard Hike unless preserving a user-authored route/event name. Planned strength must use split plus letter names such as Full Body A, Full Body B, Upper Body C, or Lower Body A; do not output generic Strength support for planned strength. Mobility/yoga/core-prehab is Mobility; restorative/rest is Recovery. Always include estimatedDistanceKilometers and estimatedElevationMeters in workout candidate JSON, using null when unknown or not applicable. For user-authored hikes and rides, parse route distance/elevation when provided. Do not invent elevation for routine AI-planned rides such as 1h Base Ride, Recovery Ride, Tempo Ride, or Intervals Ride; only include ride elevation when the user supplied it or route context explicitly exists. Hike and ride intensity should account for objective route load: long distance or large elevation can upgrade Zone 2/easy work to mid/high.";

function workoutCardFields(input: {
  scheduledDate: string;
  activityType: string;
  title: string;
  durationMinutes: number;
  intensityLabel: string;
  purpose: string;
  locationLabel?: string | null;
  distanceKilometers?: number | null;
  elevationMeters?: number | null;
}) {
  const location = compactNullableText(input.locationLabel);
  const text = `${input.activityType} ${input.title} ${input.intensityLabel} ${input.purpose}`.toLowerCase();
  const distance = distanceEligibleActivity(input.activityType, input.title, input.purpose)
    ? input.distanceKilometers ?? distanceKilometersFromText(text) ?? estimatedDistanceKilometers(input.activityType, input.title, input.durationMinutes, input.intensityLabel, input.purpose)
    : null;
  const elevation = elevationEligibleActivity(input.activityType, input.title, input.purpose)
    ? input.elevationMeters ?? elevationMetersFromText(text)
    : null;
  return {
    estimated_distance_kilometers: distance,
    estimated_elevation_meters: elevation,
    planned_location_label: location,
    weather_forecast_json: {},
  };
}

function estimatedDistanceKilometers(
  activityType: string,
  title: string,
  durationMinutes: number,
  intensityLabel: string,
  purpose: string,
) {
  const activity = normalizeActivity(activityType);
  const text = `${activityType} ${title} ${intensityLabel} ${purpose}`.toLowerCase();
  const minutes = Number(durationMinutes);
  if (!Number.isFinite(minutes) || minutes <= 0) return null;
  if (!distanceEligibleActivity(activityType, title, purpose)) return null;

  let kilometersPerHour: number | null = null;
  if (["ride", "cycling", "cycle", "bike", "biking", "indoor_cycling"].includes(activity) || /ride|cycl|bike/.test(text)) {
    if (/high|hard|interval|threshold|vo2|tempo/.test(text)) {
      kilometersPerHour = 28;
    } else if (/moderate|mid|steady/.test(text)) {
      kilometersPerHour = 24;
    } else {
      kilometersPerHour = 22;
    }
  } else if (["run", "running"].includes(activity) || /run/.test(text)) {
    if (/high|hard|interval|threshold|vo2|tempo/.test(text)) {
      kilometersPerHour = 11;
    } else if (/moderate|mid|steady/.test(text)) {
      kilometersPerHour = 10;
    } else {
      kilometersPerHour = 9;
    }
  } else if (activity === "walk" || /walk/.test(text)) {
    kilometersPerHour = 5;
  } else if (activity === "hike" || /hike/.test(text)) {
    kilometersPerHour = 4.5;
  } else if (activity === "row" || /\b(row|rows|rowing|rower)\b/.test(text)) {
    kilometersPerHour = 8;
  } else if (activity === "swim" || /swim/.test(text)) {
    kilometersPerHour = 2;
  }

  if (!kilometersPerHour) return null;
  return Math.max(1, Math.round((minutes / 60) * kilometersPerHour));
}

function normalizedWorkoutTitle(
  activityType: string,
  title: string,
  durationMinutes: number,
  intensityLabel: string,
  purpose: string,
) {
  const activity = normalizeActivity(activityType);
  const text = `${activityType} ${title} ${intensityLabel} ${purpose}`.toLowerCase();
  const duration = Number(durationMinutes);

  if (["ride", "cycling", "cycle", "bike", "biking", "indoor_cycling"].includes(activity) || /ride|cycl|bike/.test(text)) {
    if (/interval|vo2|zone\s*4|z4|zone\s*5|z5/.test(text)) return "Intervals Ride";
    if (/recover|easy spin/.test(text)) return "Recovery Ride";
    if (duration >= 90 || /long/.test(text)) return "Long Ride";
    if (/tempo|threshold|steady/.test(text)) return "Tempo Ride";
    return "Base Ride";
  }

  if (activity === "walk" || /\bwalk/.test(text)) {
    return /recover|easy|low|gentle|light/.test(text) ? "Recovery Walk" : "Walk";
  }

  if (activity === "hike" || /hik/.test(text)) {
    if (/hard|high|mountain/.test(text)) return "Hard Hike";
    if (duration >= 180 || /long|route|elevation|vert/.test(text)) return "Long Hike";
    return "Easy Hike";
  }

  if (["strength", "gym", "traditional_strength_training", "functional_strength_training"].includes(activity) || /strength|gym|lift|weights|body/.test(text)) {
    return normalizedStrengthTitle(text) ?? "Full Body A";
  }

  if (["run", "running"].includes(activity) || /run/.test(text)) {
    if (/tempo|threshold/.test(text)) return "Tempo Run";
    if (/interval|vo2/.test(text)) return "Intervals Run";
    if (/recover/.test(text)) return "Recovery Run";
    return duration >= 70 || /long/.test(text) ? "Long Run" : "Base Run";
  }

  if (activity === "swim" || /swim/.test(text)) {
    if (/interval|vo2/.test(text)) return "Intervals Swim";
    if (/recover/.test(text)) return "Recovery Swim";
    return "Base Swim";
  }

  if (/mobility|yoga|pilates|stretch|core|prehab/.test(text)) return "Mobility";
  if (/recover|restorative|\brest\b/.test(text)) return "Recovery";
  return compactCardWorkoutTitle(title || titleCase(activityType));
}

function distanceEligibleActivity(activityType: string, title: string, purpose = "") {
  const activity = normalizeActivity(`${activityType} ${title} ${purpose}`);
  return ["ride", "run", "hike", "walk", "swim", "row"].includes(activity);
}

function elevationEligibleActivity(activityType: string, title: string, purpose = "") {
  const activity = normalizeActivity(`${activityType} ${title} ${purpose}`);
  return ["ride", "hike"].includes(activity);
}

function isOutdoorWorkoutActivity(activityType: string) {
  const activity = normalizeActivity(activityType);
  return ["ride", "run", "hike", "walk"].includes(activity);
}

function explicitOutdoorIntent(text: string) {
  return /\b(run|ride|bike|cycle|hike|walk|outdoor|outside)\b/i.test(text);
}

function normalizedStrengthTitle(text: string) {
  const letter = (text.match(/\b([a-e])\b/i)?.[1] ?? "A").toUpperCase();
  if (/upper/.test(text)) return `Upper Body ${letter}`;
  if (/lower|leg/.test(text)) return `Lower Body ${letter}`;
  if (/full|body/.test(text)) return `Full Body ${letter}`;
  return null;
}

function compactCardWorkoutTitle(value: string) {
  const cleaned = String(value ?? "")
    .replace(/\([^)]*\)/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (!cleaned) return "Workout";
  const words = cleaned.split(" ").slice(0, 3).join(" ");
  return titleCase(words);
}

async function fetchOpenMeteoWorkoutForecast(
  locationLabel: string,
  scheduledDate: string,
  geocodeCache: Map<string, OpenMeteoLocation | null>,
  forecastCache: Map<string, OpenMeteoDailyForecast | null>,
): Promise<OpenMeteoDailyForecast | null> {
  const location = await geocodeOpenMeteoLocation(locationLabel, geocodeCache);
  if (!location) return null;

  const cacheKey = `${location.latitude.toFixed(4)},${location.longitude.toFixed(4)}|${scheduledDate}`;
  if (forecastCache.has(cacheKey)) return forecastCache.get(cacheKey) ?? null;

  const params = new URLSearchParams({
    latitude: String(location.latitude),
    longitude: String(location.longitude),
    daily: [
      "weather_code",
      "temperature_2m_max",
      "precipitation_probability_max",
      "precipitation_sum",
      "wind_speed_10m_max",
    ].join(","),
    timezone: "auto",
    forecast_days: "16",
    temperature_unit: "celsius",
    wind_speed_unit: "kmh",
    precipitation_unit: "mm",
  });
  const response = await fetch(`https://api.open-meteo.com/v1/forecast?${params.toString()}`);
  if (!response.ok) {
    forecastCache.set(cacheKey, null);
    return null;
  }

  const payload = await response.json();
  const daily = payload?.daily ?? {};
  const index = Array.isArray(daily.time) ? daily.time.indexOf(scheduledDate) : -1;
  if (index < 0) {
    forecastCache.set(cacheKey, null);
    return null;
  }

  const conditionCode = finiteNumber(daily.weather_code?.[index]);
  const temperature = finiteNumber(daily.temperature_2m_max?.[index]);
  if (conditionCode == null || temperature == null) {
    forecastCache.set(cacheKey, null);
    return null;
  }

  const precipitationProbability = finiteNumber(daily.precipitation_probability_max?.[index]);
  const precipitationMm = finiteNumber(daily.precipitation_sum?.[index]);
  const windKph = finiteNumber(daily.wind_speed_10m_max?.[index]);
  const condition = openMeteoCondition(Number(conditionCode));
  const forecast: OpenMeteoDailyForecast = {
    source: "open-meteo",
    fetchedAt: new Date().toISOString(),
    forecastDate: scheduledDate,
    locationLabel: formattedOpenMeteoLocationLabel(location, locationLabel),
    latitude: roundedCoordinate(location.latitude),
    longitude: roundedCoordinate(location.longitude),
    temperatureCelsius: Math.round(temperature),
    temperatureUnit: "C",
    conditionCode: Number(conditionCode),
    conditionLabel: condition.label,
    conditionEmoji: condition.emoji,
    precipitationProbability,
    precipitationMm,
    windKph,
    outdoorRisk: outdoorRiskForForecast(Number(conditionCode), temperature, precipitationProbability, precipitationMm, windKph),
  };
  forecastCache.set(cacheKey, forecast);
  return forecast;
}

async function geocodeOpenMeteoLocation(
  locationLabel: string,
  geocodeCache: Map<string, OpenMeteoLocation | null>,
): Promise<OpenMeteoLocation | null> {
  const cacheKey = normalizedLocationLookupText(locationLabel);
  if (!cacheKey) return null;
  if (geocodeCache.has(cacheKey)) return geocodeCache.get(cacheKey) ?? null;

  let best: { location: OpenMeteoLocation; score: number } | null = null;
  for (const query of geocodeSearchQueries(locationLabel)) {
    const results = await searchOpenMeteoLocations(query);
    for (const result of results) {
      const latitude = finiteNumber(result?.latitude);
      const longitude = finiteNumber(result?.longitude);
      if (latitude == null || longitude == null) continue;

      const location: OpenMeteoLocation = {
        name: compactNullableText(result.name) ?? query,
        country: compactNullableText(result.country) ?? undefined,
        admin1: compactNullableText(result.admin1) ?? undefined,
        latitude,
        longitude,
      };
      const score = geocodeResultScore(locationLabel, query, location);
      if (!best || score > best.score) {
        best = { location, score };
      }
    }

    if (best && best.score >= 90) break;
  }

  const resolved = best && best.score >= 35 ? best.location : null;
  geocodeCache.set(cacheKey, resolved);
  return resolved;
}

async function searchOpenMeteoLocations(query: string) {
  const params = new URLSearchParams({
    name: query,
    count: "5",
    language: "en",
    format: "json",
  });
  const response = await fetch(`https://geocoding-api.open-meteo.com/v1/search?${params.toString()}`);
  if (!response.ok) return [];
  const payload = await response.json();
  return Array.isArray(payload?.results) ? payload.results : [];
}

function geocodeSearchQueries(locationLabel: string) {
  const raw = compactNullableText(locationLabel);
  if (!raw) return [];

  const primary = compactNullableText(raw.split(",")[0]);
  const cleaned = compactNullableText(normalizedLocationLookupText(raw).replace(/-/g, " "));
  const cleanedPrimary = primary ? compactNullableText(normalizedLocationLookupText(primary).replace(/-/g, " ")) : null;
  const repeatedLettersCollapsed = cleaned ? compactNullableText(cleaned.replace(/([a-z])\1+/g, "$1")) : null;
  const tokenQueries = cleaned
    ?.split(/\s+/)
    .filter((token) => token.length >= 4 && !["city", "town", "near"].includes(token))
    .slice(0, 2);

  return uniqueCompactStrings([
    raw,
    primary,
    cleaned,
    cleanedPrimary,
    repeatedLettersCollapsed,
    ...(tokenQueries ?? []),
  ]);
}

function geocodeResultScore(originalLabel: string, query: string, location: OpenMeteoLocation) {
  const original = normalizedLocationLookupText(originalLabel).replace(/-/g, " ");
  const normalizedQuery = normalizedLocationLookupText(query).replace(/-/g, " ");
  const name = normalizedLocationLookupText(location.name).replace(/-/g, " ");
  const admin = normalizedLocationLookupText(location.admin1 ?? "").replace(/-/g, " ");
  const country = normalizedLocationLookupText(location.country ?? "").replace(/-/g, " ");
  const haystack = [name, admin, country].filter(Boolean).join(" ");

  let score = 0;
  if (name === original || name === normalizedQuery) score += 100;
  if (haystack.includes(original)) score += 70;
  if (haystack.includes(normalizedQuery)) score += 60;
  if (tokenOverlapScore(original, haystack) >= 0.8) score += 45;
  if (tokenOverlapScore(normalizedQuery, haystack) >= 0.8) score += 35;
  if (country && original.includes(country)) score += 15;
  if (admin && original.includes(admin)) score += 10;
  return score;
}

function tokenOverlapScore(needle: string, haystack: string) {
  const tokens = needle.split(/\s+/).filter((token) => token.length > 1);
  if (tokens.length === 0) return 0;
  const matches = tokens.filter((token) => haystack.includes(token)).length;
  return matches / tokens.length;
}

function uniqueCompactStrings(values: Array<string | null | undefined>) {
  const seen = new Set<string>();
  const output: string[] = [];
  for (const value of values) {
    const compact = compactNullableText(value);
    if (!compact) continue;
    const key = normalizedLocationLookupText(compact);
    if (seen.has(key)) continue;
    seen.add(key);
    output.push(compact);
  }
  return output;
}

function formattedOpenMeteoLocationLabel(location: OpenMeteoLocation, fallback: string) {
  return [location.name, location.admin1, location.country]
    .filter(Boolean)
    .join(", ") || fallback;
}

function roundedCoordinate(value: number) {
  return Math.round(value * 10_000) / 10_000;
}

function openMeteoCondition(code: number) {
  if (code === 0) return { label: "Sunny", emoji: "☀️" };
  if ([1, 2].includes(code)) return { label: "Partly cloudy", emoji: "🌤" };
  if (code === 3) return { label: "Cloudy", emoji: "☁️" };
  if ([45, 48].includes(code)) return { label: "Fog", emoji: "🌫" };
  if ([51, 53, 55, 56, 57].includes(code)) return { label: "Drizzle", emoji: "🌦" };
  if ([61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return { label: "Rain", emoji: "🌧" };
  if ([71, 73, 75, 77, 85, 86].includes(code)) return { label: "Snow", emoji: "🌨" };
  if ([95, 96, 99].includes(code)) return { label: "Thunderstorm", emoji: "⛈" };
  return { label: "Weather", emoji: "🌡" };
}

function outdoorRiskForForecast(
  conditionCode: number,
  temperatureCelsius: number,
  precipitationProbability: number | null,
  precipitationMm: number | null,
  windKph: number | null,
): "ok" | "watch" | "miserable" {
  const heavyWeather = [65, 66, 67, 71, 73, 75, 77, 82, 85, 86, 95, 96, 99].includes(conditionCode);
  if (
    heavyWeather ||
    (precipitationProbability ?? 0) >= 70 ||
    (precipitationMm ?? 0) >= 5 ||
    (windKph ?? 0) >= 35 ||
    temperatureCelsius <= 0 ||
    temperatureCelsius >= 32
  ) {
    return "miserable";
  }
  if ((precipitationProbability ?? 0) >= 40 || (precipitationMm ?? 0) >= 2 || (windKph ?? 0) >= 25) {
    return "watch";
  }
  return "ok";
}

async function planningWeatherContextForDate(
  scope: PlanningScope,
  scheduledDate: string,
  locationLabel: string | null | undefined,
  storedForecast: unknown,
) {
  if (!scope.weatherSensitive) return null;

  const location = compactNullableText(locationLabel) ?? scope.homeLocationLabel;
  let forecast = storedOpenMeteoForecastForDate(storedForecast, scheduledDate);
  if (!forecast && location) {
    try {
      forecast = await fetchOpenMeteoWorkoutForecast(
        location,
        scheduledDate,
        new Map<string, OpenMeteoLocation | null>(),
        new Map<string, OpenMeteoDailyForecast | null>(),
      );
    } catch {
      forecast = null;
    }
  }

  return {
    selectedBlocker: "Weather",
    locationLabel: location,
    forecast,
    shouldAvoidOutdoor: forecast?.outdoorRisk === "miserable",
    guidance:
      "If shouldAvoidOutdoor is true, prefer indoor gym, strength, mobility, or recovery options unless the user explicitly asks for an outdoor workout.",
  };
}

function storedOpenMeteoForecastForDate(value: unknown, scheduledDate: string): OpenMeteoDailyForecast | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const forecast = value as Record<string, unknown>;
  if (forecast.source !== "open-meteo" || forecast.forecastDate !== scheduledDate) return null;
  if (typeof forecast.conditionEmoji !== "string" || typeof forecast.conditionLabel !== "string") return null;
  const temperature = finiteNumber(forecast.temperatureCelsius);
  const conditionCode = finiteNumber(forecast.conditionCode);
  if (temperature == null || conditionCode == null) return null;
  return {
    source: "open-meteo",
    fetchedAt: String(forecast.fetchedAt ?? ""),
    forecastDate: scheduledDate,
    locationLabel: String(forecast.locationLabel ?? ""),
    latitude: finiteNumber(forecast.latitude) ?? 0,
    longitude: finiteNumber(forecast.longitude) ?? 0,
    temperatureCelsius: temperature,
    temperatureUnit: "C",
    conditionCode,
    conditionLabel: String(forecast.conditionLabel),
    conditionEmoji: String(forecast.conditionEmoji),
    precipitationProbability: finiteNumber(forecast.precipitationProbability),
    precipitationMm: finiteNumber(forecast.precipitationMm),
    windKph: finiteNumber(forecast.windKph),
    outdoorRisk: forecast.outdoorRisk === "miserable" || forecast.outdoorRisk === "watch" ? forecast.outdoorRisk : "ok",
  };
}

function compactNullableText(value: unknown) {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text.length > 0 ? text : null;
}

function onboardingHasWeatherBlocker(onboarding: Record<string, any> | null | undefined) {
  const blockers = onboarding?.selected_answers?.blockers;
  if (!Array.isArray(blockers)) return false;
  return blockers.some((blocker) => String(blocker ?? "").trim().toLowerCase() === "weather");
}

function applyWeeklyConstraintsToGeneratedWorkouts(workouts: GeneratedWorkout[], constraints: Record<string, any>) {
  const days = constraints?.days ?? {};
  return workouts.flatMap((workout) => {
    const constraint = days[workout.scheduledDate];
    if (constraint?.kind === "unavailable") return [];
    if (constraint?.kind === "limited") {
      return [{
        ...workout,
        durationMinutes: Math.min(workout.durationMinutes, 30),
        intensityLabel: /high|hard|tempo|threshold/i.test(workout.intensityLabel) ? "Low" : workout.intensityLabel,
        purpose: workout.purpose || "Limited-day training",
      }];
    }
    return [workout];
  });
}

async function generateAndPersistWeeklyTargets(
  admin: SupabaseAdminClient,
  args: {
    userID: string;
    goal: Record<string, any>;
    strategy: Record<string, any>;
    weeklyPlans: Record<string, any>[];
    healthSnapshot: Record<string, any> | null;
    acceptedStrategy: Record<string, unknown> | null;
    model: string;
  },
) {
  const visiblePlans = args.weeklyPlans.filter((plan) => ["committed", "draft"].includes(plan.status));
  if (visiblePlans.length === 0) return [];

  const planIDs = visiblePlans.map((plan) => plan.id);
  const workouts = await list(
    admin
      .from("planned_workouts")
      .select()
      .eq("user_id", args.userID)
      .in("weekly_plan_id", planIDs)
      .not("status", "in", "(deleted,superseded)")
      .order("scheduled_date", { ascending: true })
      .order("sequence_order", { ascending: true }),
  );
  const strategyTargets = await list(
    admin
      .from("planning_targets")
      .select("id,target_scope,target_kind,title,description,metric_key,metric_category,direction,target_value,unit,evaluation_rule_json,status")
      .eq("user_id", args.userID)
      .eq("fitness_strategy_id", args.strategy.id)
      .in("target_scope", ["strategy", "goal"]),
  );

  const context = weeklyTargetGenerationContext({
    goal: args.goal,
    strategy: args.strategy,
    acceptedStrategy: args.acceptedStrategy,
    weeklyPlans: visiblePlans,
    workouts,
    strategyTargets,
    healthSnapshot: args.healthSnapshot,
  });

  let generated: WeeklyTargetGenerationOutput;
  try {
    generated = await runWeeklyTargetGeneration(context, args.model);
    await insertTrace(admin, {
      userID: args.userID,
      task: "generate_weekly_plan_targets",
      model: args.model,
      compactRequest: { task: "generate_weekly_plan_targets", context },
      structuredResponse: generated,
      status: "success",
      latencyMS: 0,
    });
  } catch (error) {
    await insertTrace(admin, {
      userID: args.userID,
      task: "generate_weekly_plan_targets",
      model: args.model,
      compactRequest: { task: "generate_weekly_plan_targets", context },
      structuredResponse: null,
      status: "failure",
      latencyMS: 0,
      errorMessage: errorMessage(error),
    });
    throw error;
  }

  const rows = validatedWeeklyTargetRows({
    userID: args.userID,
    weeklyPlans: visiblePlans,
    workouts,
    generated,
  });

  await throwOnError(
    admin
      .from("planning_targets")
      .delete()
      .eq("user_id", args.userID)
      .in("weekly_plan_id", planIDs)
      .eq("target_scope", "week"),
  );

  if (rows.length > 0) {
    await throwOnError(admin.from("planning_targets").insert(rows));
    await evaluateWeeklyTargetsForPlans(admin, args.userID, planIDs);
  }

  return rows;
}

function weeklyTargetGenerationContext(args: {
  goal: Record<string, any>;
  strategy: Record<string, any>;
  acceptedStrategy: Record<string, unknown> | null;
  weeklyPlans: Record<string, any>[];
  workouts: Record<string, any>[];
  strategyTargets: Record<string, any>[];
  healthSnapshot: Record<string, any> | null;
}) {
  return {
    goal: {
      id: args.goal.id,
      title: args.goal.title,
      goalKind: args.goal.goal_kind,
      targetDate: args.goal.target_date,
      timeframeWeeks: args.goal.timeframe_weeks,
      normalizedGoal: args.goal.normalized_goal_json ?? null,
    },
    strategy: {
      id: args.strategy.id,
      title: args.strategy.title,
      summary: args.strategy.summary,
      targetDate: args.strategy.target_date,
      acceptedStrategy: compactWeeklyAcceptedStrategy(args.acceptedStrategy),
    },
    strategyTargets: args.strategyTargets.map((target) => ({
      title: target.title,
      summary: target.description,
      metricCategory: target.metric_category,
      targetValue: target.target_value,
      unit: target.unit,
    })),
    weeks: args.weeklyPlans.map((plan) => {
      const planWorkouts = args.workouts.filter((workout) => workout.weekly_plan_id === plan.id);
      return {
        weeklyPlanID: plan.id,
        status: plan.status,
        weekStartDate: plan.week_start_date,
        weekEndDate: plan.week_end_date,
        objective: plan.objective,
        slots: [1, 2, 3].map((index) => `${plan.id}:target:${index}`),
        workouts: planWorkouts.map((workout) => ({
          id: workout.id,
          scheduledDate: workout.scheduled_date,
          activityType: workout.activity_type,
          normalizedActivity: normalizeActivity(`${workout.activity_type} ${workout.title} ${workout.purpose}`),
          title: workout.title,
          durationMinutes: workout.duration_minutes,
          intensityLabel: workout.intensity_label,
          purpose: workout.purpose,
        })),
      };
    }),
    availableTargetFamilies: [
      "planned_session_completion",
      "modality_session_count",
      "modality_minutes",
      "modality_distance",
      "active_days",
      "support_modality_presence",
      "max_gap_guardrail",
      "minimum_viable_week",
      "body_weight_logging",
      "running_pace",
      "cycling_pace",
    ],
    targetReferenceRules: [
      "Targets must be measurable and computable from planned workouts, completed workouts, matched HealthKit workouts, in-app exercise logs, or explicit body/performance entries.",
      "Good weekly targets include completing planned sessions, completing a modality count, weekly minutes/distance, active days, support modality presence, no gap longer than N days, load guardrails, body-weight logging, or pace/power values when data supports them.",
      "Bad weekly targets include feeling good, reviewing recovery, selecting a next goal, adjusting a plan, confidence improved, or any subjective reflection.",
    ],
    healthSnapshotSummary: args.healthSnapshot
      ? {
        generatedAt: snapshotGeneratedAt(args.healthSnapshot),
        hasBodyMass: typeof args.healthSnapshot.body?.bodyMassKilograms === "number" || typeof args.healthSnapshot.body?.bodyMass28DayAverageKilograms === "number",
        runningDistance7d: args.healthSnapshot.activity?.runningDistance7DaysKilometers ?? args.healthSnapshot.activity?.walkingRunningDistance7DaysKilometers ?? null,
        cyclingDistance7d: args.healthSnapshot.activity?.cyclingDistance7DaysKilometers ?? null,
      }
      : null,
  };
}

function compactWeeklyAcceptedStrategy(strategy: Record<string, unknown> | null) {
  if (!strategy) return null;
  return {
    read: stringAt(strategy, "read") || null,
    goalTargetContext: objectAt(strategy, "goalTargetContext")
      ? {
        title: stringAt(objectAt(strategy, "goalTargetContext"), "title") || null,
        summary: stringAt(objectAt(strategy, "goalTargetContext"), "summary") || null,
      }
      : null,
    targets: arrayAt(strategy, "targets").map(compactAcceptedTarget),
    phases: arrayAt(strategy, "phases").map((phase) => ({
      id: stringAt(phase, "id") || null,
      name: stringAt(phase, "name") || null,
      objective: stringAt(phase, "objective") || null,
      targetSummary: stringAt(phase, "targetSummary") || null,
      targets: arrayAt(phase, "targets").map(compactAcceptedTarget),
    })),
  };
}

function compactAcceptedTarget(target: Record<string, unknown>) {
  return {
    title: stringAt(target, "title") || null,
    summary: stringAt(target, "summary") || null,
    scope: stringAt(target, "scope") || null,
    metricCategory: stringAt(target, "metricCategory") || null,
    targetValue: numberAt(target, "targetValue"),
    unit: stringAt(target, "unit") || null,
    displayValue: stringAt(target, "displayValue") || null,
  };
}

async function runWeeklyTargetGeneration(context: Record<string, unknown>, model: string): Promise<WeeklyTargetGenerationOutput> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const touchpointConfig = planningAITouchpoint("weekly_targets");
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(responsesRequestPayload(
      model,
      touchpointConfig,
      {
        task: "generate_weekly_plan_targets",
        context,
        rules: touchpointConfig.userRules,
      },
      {
        type: "json_schema",
        name: "weekly_plan_targets",
        strict: true,
        schema: weeklyTargetSchema,
      },
    )),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? "OpenAI request failed");
  }

  const outputText = extractOutputText(payload);
  if (!outputText) {
    throw new Error("OpenAI returned no structured weekly target output");
  }

  return JSON.parse(outputText) as WeeklyTargetGenerationOutput;
}

function validatedWeeklyTargetRows(args: {
  userID: string;
  weeklyPlans: Record<string, any>[];
  workouts: Record<string, any>[];
  generated: WeeklyTargetGenerationOutput;
}) {
  const rows: Record<string, unknown>[] = [];
  const weekByID = new Map(args.weeklyPlans.map((plan) => [plan.id, plan]));
  const generatedByWeek = new Map(args.generated.weeks.map((week) => [week.weeklyPlanID, week.targets]));
  for (const plan of args.weeklyPlans) {
    const planWorkouts = args.workouts.filter((workout) => workout.weekly_plan_id === plan.id);
    const proposals = generatedByWeek.get(plan.id) ?? [];
    const accepted = proposals
      .filter((proposal) => weekByID.has(plan.id))
      .map((proposal) => weeklyTargetRowFromProposal(args.userID, plan, planWorkouts, proposal))
      .filter(Boolean) as Record<string, unknown>[];
    const finalRows = accepted.length > 0
      ? accepted.slice(0, 3)
      : [];
    if (finalRows.length === 0) {
      throw new Error(`AI weekly target generation returned no valid targets for week ${plan.week_start_date}.`);
    }
    rows.push(...finalRows.map((row, index) => ({ ...row, target_kind: index === 0 ? "primary" : "supporting" })));
  }
  return rows;
}

function weeklyTargetRowFromProposal(
  userID: string,
  plan: Record<string, any>,
  workouts: Record<string, any>[],
  proposal: WeeklyTargetProposal,
) {
  const family = normalizedWeeklyTargetFamily(proposal.family);
  if (!family || hasBadTargetLanguage(`${proposal.title} ${proposal.summary}`)) return null;

  const modality = normalizedWeeklyModality(proposal.modality, workouts, family);
  const targetValue = normalizedWeeklyTargetValue(proposal.targetValue, family, modality, workouts);
  if (targetValue === null) return null;

  const comparator = normalizedWeeklyComparator(proposal.comparator, family);
  const unit = normalizedWeeklyUnit(proposal.unit, family);
  const title = compactWeeklyTargetTitle(proposal.title, family, modality);
  const displayValue = compactWeeklyDisplayValue(proposal.proposedDisplayValue) ?? weeklyDisplayValue(targetValue, unit, comparator);
  const plannedWorkoutIDs = relevantWeeklyWorkoutIDs(workouts, family, modality);

  return {
    user_id: userID,
    user_goal_id: null,
    fitness_strategy_id: null,
    fitness_strategy_phase_id: null,
    weekly_plan_id: plan.id,
    planned_workout_id: null,
    target_scope: "week",
    target_kind: "supporting",
    title,
    description: cleanTargetCopy(proposal.summary) || defaultWeeklySummary(family, modality),
    metric_key: weeklyMetricKey(family, modality),
    metric_category: `weekly_${family}`,
    direction: comparator === "at_most" ? "decrease" : family === "planned_session_completion" ? "complete" : "increase",
    baseline_value: null,
    target_value: targetValue,
    unit,
    start_date: plan.week_start_date,
    target_date: plan.week_end_date,
    evaluation_rule_json: {
      family,
      comparator,
      displayValue,
      modality,
      plannedWorkoutIDs,
      slotID: proposal.slotID,
      rationale: cleanTargetCopy(proposal.rationale),
    },
    source: "planning_engine",
    status: "needs_review",
  };
}

function normalizedWeeklyTargetFamily(family: string | undefined): WeeklyTargetFamily | null {
  const value = String(family ?? "").toLowerCase().replace(/[-\s]+/g, "_");
  const allowed = new Set([
    "planned_session_completion",
    "modality_session_count",
    "modality_minutes",
    "modality_distance",
    "active_days",
    "support_modality_presence",
    "max_gap_guardrail",
    "minimum_viable_week",
    "body_weight_logging",
    "running_pace",
    "cycling_pace",
  ]);
  return allowed.has(value) ? value as WeeklyTargetFamily : null;
}

function normalizedWeeklyModality(value: string | null | undefined, workouts: Record<string, any>[], family: WeeklyTargetFamily) {
  if (family === "planned_session_completion" || family === "active_days" || family === "max_gap_guardrail" || family === "body_weight_logging" || family === "minimum_viable_week") {
    return null;
  }
  const normalized = value ? normalizeActivity(value) : primaryWeeklyModality(workouts);
  if (!normalized) return null;
  const present = new Set(workouts.map((workout) => normalizeActivity(`${workout.activity_type} ${workout.title} ${workout.purpose}`)));
  if (family === "running_pace") return present.has("run") ? "run" : null;
  if (family === "cycling_pace") return present.has("ride") ? "ride" : null;
  return present.has(normalized) ? normalized : null;
}

function normalizedWeeklyTargetValue(value: number | null | undefined, family: WeeklyTargetFamily, modality: string | null, workouts: Record<string, any>[]) {
  const numeric = typeof value === "number" && Number.isFinite(value) && value > 0 ? value : null;
  switch (family) {
    case "planned_session_completion":
      return Math.max(1, workouts.length);
    case "minimum_viable_week":
      return Math.max(1, Math.min(workouts.length, numeric ? Math.round(numeric) : Math.ceil(workouts.length * 0.6)));
    case "active_days":
      return Math.max(1, Math.min(new Set(workouts.map((workout) => workout.scheduled_date)).size, numeric ? Math.round(numeric) : new Set(workouts.map((workout) => workout.scheduled_date)).size));
    case "modality_session_count":
    case "support_modality_presence": {
      const plannedCount = plannedWorkoutsForModality(workouts, modality).length;
      return Math.max(1, Math.min(plannedCount, numeric ? Math.round(numeric) : plannedCount));
    }
    case "modality_minutes":
      return Math.max(10, numeric ?? plannedMinutes(workouts, modality));
    case "modality_distance":
      return numeric;
    case "max_gap_guardrail":
      return Math.max(1, Math.min(4, numeric ? Math.round(numeric) : 3));
    case "body_weight_logging":
      return Math.max(1, Math.min(7, numeric ? Math.round(numeric) : 2));
    case "running_pace":
    case "cycling_pace":
      return numeric;
  }
}

function normalizedWeeklyComparator(comparator: string | undefined, family: WeeklyTargetFamily) {
  if (family === "max_gap_guardrail" || family === "running_pace") return "at_most";
  if (comparator === "between") return "between";
  if (comparator === "at_most") return "at_most";
  return "at_least";
}

function normalizedWeeklyUnit(unit: string | null | undefined, family: WeeklyTargetFamily) {
  const value = cleanTargetCopy(unit ?? "");
  if (value && !containsInternalTargetLanguage(value)) return value;
  switch (family) {
    case "planned_session_completion":
    case "modality_session_count":
    case "support_modality_presence":
    case "minimum_viable_week":
      return "sessions";
    case "modality_minutes":
      return "min";
    case "modality_distance":
      return "km";
    case "active_days":
    case "max_gap_guardrail":
      return "days";
    case "body_weight_logging":
      return "entries";
    case "running_pace":
      return "min/km";
    case "cycling_pace":
      return "km/h";
  }
}

function compactWeeklyTargetTitle(title: string, family: WeeklyTargetFamily, modality: string | null) {
  const fallback = defaultWeeklyTitle(family, modality);
  const clean = cleanTargetCopy(title);
  if (!clean || containsInternalTargetLanguage(clean)) return fallback;
  const withoutColon = clean.includes(":") ? clean.split(":").pop()?.trim() ?? clean : clean;
  const words = withoutColon.split(/\s+/).filter(Boolean);
  return words.slice(0, 6).join(" ").slice(0, 42).trim() || fallback;
}

function cleanTargetCopy(value: string) {
  return String(value ?? "")
    .replace(/\bbenchmark\b/gi, "result")
    .replace(/\s+/g, " ")
    .trim();
}

function containsInternalTargetLanguage(value: string) {
  return /metric_key|snake_case|target_scope|weekly_plan_id|planned_workout_id|evaluation_rule/i.test(value);
}

function hasBadTargetLanguage(value: string) {
  return /feel|feeling|confidence|review|decide|decision|select|next goal|adjust(ed|ment)? plan|plan adjusted|check[- ]?in|reflect|reflection/i.test(value);
}

function compactWeeklyDisplayValue(value: string | null | undefined) {
  const clean = cleanTargetCopy(value ?? "");
  if (!clean || containsInternalTargetLanguage(clean)) return null;
  return clean
    .replace(/\bminutes\b/gi, "min")
    .replace(/\bminute\b/gi, "min")
    .replace(/\bsessions\b/gi, "sessions")
    .replace(/\bkilometers\b/gi, "km")
    .replace(/\bdays\b/gi, "days")
    .slice(0, 18)
    .trim();
}

function weeklyDisplayValue(targetValue: number, unit: string, comparator: string) {
  const formatted = targetValue % 1 === 0 ? String(targetValue) : targetValue.toFixed(1);
  const prefix = comparator === "at_most" ? "<=" : comparator === "at_least" ? ">=" : "";
  if (unit === "sessions") return `${prefix}${formatted}x`;
  return `${prefix}${formatted} ${unit}`.trim();
}

function weeklyMetricKey(family: WeeklyTargetFamily, modality: string | null) {
  return modality ? `${family}_${modality}` : family;
}

function defaultWeeklyTitle(family: WeeklyTargetFamily, modality: string | null) {
  switch (family) {
    case "planned_session_completion":
      return "Planned sessions";
    case "modality_session_count":
      return `${titleCase(modality ?? "Workout")} sessions`;
    case "modality_minutes":
      return `${titleCase(modality ?? "Workout")} minutes`;
    case "modality_distance":
      return `${titleCase(modality ?? "Workout")} distance`;
    case "active_days":
      return "Active days";
    case "support_modality_presence":
      return `${titleCase(modality ?? "Support")} present`;
    case "max_gap_guardrail":
      return "Max gap";
    case "minimum_viable_week":
      return "Minimum week";
    case "body_weight_logging":
      return "Weight logs";
    case "running_pace":
      return "Run pace";
    case "cycling_pace":
      return "Ride speed";
  }
}

function defaultWeeklySummary(family: WeeklyTargetFamily, modality: string | null) {
  switch (family) {
    case "max_gap_guardrail":
      return "Keep workout spacing tight enough for the week to hold.";
    case "minimum_viable_week":
      return "Complete the reduced floor that still makes the week count.";
    default:
      return `Make the ${modality ? titleCase(modality) : "weekly"} target measurable from completed work.`;
  }
}

function relevantWeeklyWorkoutIDs(workouts: Record<string, any>[], family: WeeklyTargetFamily, modality: string | null) {
  if (!modality) return workouts.map((workout) => workout.id);
  if (family === "active_days" || family === "planned_session_completion" || family === "minimum_viable_week") {
    return workouts.map((workout) => workout.id);
  }
  return plannedWorkoutsForModality(workouts, modality).map((workout) => workout.id);
}

function primaryWeeklyModality(workouts: Record<string, any>[]) {
  const counts = new Map<string, number>();
  for (const workout of workouts) {
    const modality = normalizeActivity(`${workout.activity_type} ${workout.title} ${workout.purpose}`);
    if (modality === "mobility" || modality === "recovery") continue;
    counts.set(modality, (counts.get(modality) ?? 0) + 1);
  }
  return Array.from(counts.entries()).sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;
}

function plannedWorkoutsForModality(workouts: Record<string, any>[], modality: string | null) {
  if (!modality) return workouts;
  return workouts.filter((workout) => normalizeActivity(`${workout.activity_type} ${workout.title} ${workout.purpose}`) === modality);
}

function plannedMinutes(workouts: Record<string, any>[], modality: string | null) {
  return plannedWorkoutsForModality(workouts, modality).reduce((sum, workout) => sum + Number(workout.duration_minutes ?? 0), 0);
}

function alignGeneratedPlanToWeeklyTargets(
  plan: GeneratedPlan,
  constraints: WeeklyTargetConstraint[],
): GeneratedPlan {
  if (constraints.length === 0) return plan;

  const constraintsByWeek = new Map<string, WeeklyTargetConstraint[]>();
  for (const constraint of constraints) {
    constraintsByWeek.set(constraint.weekStartDate, [...(constraintsByWeek.get(constraint.weekStartDate) ?? []), constraint]);
  }

  return {
    ...plan,
    rhythms: plan.rhythms.map((rhythm) => alignRhythmToWeeklyTargets(rhythm, constraintsByWeek.get(rhythm.weekStartDate) ?? [])),
  };
}

function alignRhythmToWeeklyTargets(
  rhythm: GeneratedRhythm,
  constraints: WeeklyTargetConstraint[],
): GeneratedRhythm {
  if (constraints.length === 0) return rhythm;

  const workouts = [...rhythm.workouts].sort((a, b) =>
    a.scheduledDate.localeCompare(b.scheduledDate) || a.sequenceOrder - b.sequenceOrder
  );
  for (const constraint of constraints) {
    if (!constraint.modality) continue;
    if (constraint.family === "modality_session_count" || constraint.family === "support_modality_presence") {
      while (generatedWorkoutsForModality(workouts, constraint.modality).length < Math.round(constraint.targetValue)) {
        workouts.push(generatedWorkoutForConstraint(constraint, rhythm, workouts));
      }
    }
  }

  for (const constraint of constraints) {
    if (!constraint.modality || constraint.family !== "modality_minutes") continue;
    let minutes = generatedWorkoutsForModality(workouts, constraint.modality)
      .reduce((sum, workout) => sum + Number(workout.durationMinutes ?? 0), 0);
    while (minutes < constraint.targetValue) {
      const workout = generatedWorkoutForConstraint(constraint, rhythm, workouts, Math.min(60, Math.max(30, Math.ceil(constraint.targetValue - minutes))));
      workouts.push(workout);
      minutes += workout.durationMinutes;
    }
  }

  for (const constraint of constraints) {
    if (!weeklyTargetCountsActiveDays(constraint)) continue;
    while (new Set(workouts.map((workout) => workout.scheduledDate)).size < Math.round(constraint.targetValue)) {
      workouts.push(generatedWorkoutForConstraint({ ...constraint, modality: "recovery" }, rhythm, workouts, 30));
    }
  }

  const sequenceByDate = new Map<string, number>();
  return {
    ...rhythm,
    workouts: workouts
      .sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate) || a.sequenceOrder - b.sequenceOrder)
      .map((workout) => {
        const sequenceOrder = (sequenceByDate.get(workout.scheduledDate) ?? 0) + 1;
        sequenceByDate.set(workout.scheduledDate, sequenceOrder);
        return { ...workout, sequenceOrder };
      }),
  };
}

function generatedWorkoutsForModality(workouts: GeneratedWorkout[], modality: string) {
  return workouts.filter((workout) => normalizeActivity(`${workout.activityType} ${workout.title} ${workout.purpose}`) === modality);
}

function weeklyTargetCountsActiveDays(constraint: WeeklyTargetConstraint) {
  if (constraint.family === "active_days") return true;
  return constraint.family === "minimum_viable_week" && (constraint.unit === "days" || /day/i.test(constraint.title));
}

function generatedWorkoutForConstraint(
  constraint: WeeklyTargetConstraint,
  rhythm: GeneratedRhythm,
  workouts: GeneratedWorkout[],
  durationMinutes?: number,
): GeneratedWorkout {
  const modality = constraint.modality ?? "recovery";
  const scheduledDate = bestDateForConstraintWorkout(rhythm, workouts, modality);
  const template = workoutTemplateForModality(modality);
  return {
    scheduledDate,
    sequenceOrder: nextGeneratedSequenceOrder(workouts, scheduledDate),
    activityType: template.activityType,
    title: template.title,
    durationMinutes: durationMinutes ?? template.durationMinutes,
    intensityLabel: template.intensityLabel,
    purpose: template.purpose,
    prescription: template.prescription,
    fuelingSummary: template.fuelingSummary,
  };
}

function bestDateForConstraintWorkout(rhythm: GeneratedRhythm, workouts: GeneratedWorkout[], modality: string) {
  const start = parseDateOnly(rhythm.weekStartDate) ?? new Date();
  const candidates = Array.from({ length: 7 }, (_, offset) => isoDate(addDays(start, offset)));
  const sameModalityDates = new Set(generatedWorkoutsForModality(workouts, modality).map((workout) => workout.scheduledDate));
  const scored = candidates.map((date) => ({
    date,
    sameModality: sameModalityDates.has(date) ? 1 : 0,
    workouts: workouts.filter((workout) => workout.scheduledDate === date).length,
  }));
  scored.sort((a, b) => a.sameModality - b.sameModality || a.workouts - b.workouts || a.date.localeCompare(b.date));
  return scored[0]?.date ?? rhythm.weekStartDate;
}

function nextGeneratedSequenceOrder(workouts: GeneratedWorkout[], date: string) {
  return workouts
    .filter((workout) => workout.scheduledDate === date)
    .reduce((max, workout) => Math.max(max, workout.sequenceOrder), 0) + 1;
}

function workoutTemplateForModality(modality: string) {
  switch (modality) {
    case "strength":
      return {
        activityType: "strength",
        title: "Full Body A",
        durationMinutes: 45,
        intensityLabel: "Moderate",
        purpose: "Strength",
        prescription: { source: "weekly_target_alignment", focus: "Full-body strength support" },
        fuelingSummary: "Carbs + protein, 60-120 min before.",
      };
    case "ride":
      return {
        activityType: "ride",
        title: "Base Ride",
        durationMinutes: 45,
        intensityLabel: "Zone 2",
        purpose: "Aerobic base",
        prescription: { source: "weekly_target_alignment", focus: "Steady endurance" },
        fuelingSummary: "Banana + yogurt, 60-90 min before.",
      };
    case "run":
      return {
        activityType: "run",
        title: "Base Run",
        durationMinutes: 35,
        intensityLabel: "Easy",
        purpose: "Aerobic base",
        prescription: { source: "weekly_target_alignment", focus: "Comfortable aerobic running" },
        fuelingSummary: "Banana + yogurt, 60-90 min before.",
      };
    default:
      return {
        activityType: "recovery",
        title: "Recovery",
        durationMinutes: 30,
        intensityLabel: "Low",
        purpose: "Recovery",
        prescription: { source: "weekly_target_alignment", focus: "Low-load movement" },
        fuelingSummary: "Normal meal timing; prioritize protein.",
      };
  }
}

async function evaluatePlanningTargets(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  snapshot: Record<string, any>,
) {
  const targets = await list(
    admin
      .from("planning_targets")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .order("created_at", { ascending: true }),
  );
  if (targets.length === 0) return;

  const evaluations: Record<string, unknown>[] = [];
  for (const target of targets) {
    const currentValue = target.metric_key ? metricValueFor(snapshot, target.metric_key) : null;
    const evaluation = evaluateGoalTarget(target, currentValue);
    evaluations.push({
      user_id: userID,
      planning_target_id: target.id,
      status: evaluation.status,
      current_value: typeof currentValue === "number" ? currentValue : null,
      target_value: target.target_value,
      unit: target.unit,
      progress_ratio: evaluation.progressRatio,
      evidence_json: evaluation.evidence,
      message: evaluation.message,
      confidence: evaluation.confidence,
    });
    await throwOnError(
      admin
        .from("planning_targets")
        .update({ status: evaluation.status })
        .eq("id", target.id)
        .eq("user_id", userID),
    );
  }

  await throwOnError(admin.from("planning_target_evaluations").insert(evaluations));
}

async function evaluateWeeklyTargetsForPlans(admin: SupabaseAdminClient, userID: string, weeklyPlanIDs: string[]) {
  if (weeklyPlanIDs.length === 0) return;

  const [targets, workouts, latestSnapshotRow] = await Promise.all([
    list(
      admin
        .from("planning_targets")
        .select()
        .eq("user_id", userID)
        .eq("target_scope", "week")
        .in("weekly_plan_id", weeklyPlanIDs),
    ),
    list(
      admin
        .from("planned_workouts")
        .select()
        .eq("user_id", userID)
        .in("weekly_plan_id", weeklyPlanIDs)
        .not("status", "in", "(deleted,superseded)"),
    ),
    maybeSingle(
      admin
        .from("health_feature_snapshots")
        .select()
        .eq("user_id", userID)
        .order("generated_at", { ascending: false })
        .limit(1),
    ),
  ]);
  if (targets.length === 0) return;

  const workoutIDs = workouts.map((workout: Record<string, any>) => workout.id);
  const actuals = workoutIDs.length > 0
    ? await list(
      admin
        .from("actual_workouts")
        .select()
        .eq("user_id", userID)
        .in("matched_planned_workout_id", workoutIDs),
    )
    : [];

  const actualByPlannedID = new Map<string, Record<string, any>>();
  for (const actual of actuals) {
    if (actual.matched_planned_workout_id) actualByPlannedID.set(actual.matched_planned_workout_id, actual);
  }

  const snapshot = latestSnapshotRow?.snapshot_json ?? null;
  const evaluations: Record<string, unknown>[] = [];
  for (const target of targets) {
    const weekWorkouts = workouts.filter((workout: Record<string, any>) => workout.weekly_plan_id === target.weekly_plan_id);
    const evaluation = evaluateWeeklyTarget(target, weekWorkouts, actualByPlannedID, snapshot);
    evaluations.push({
      user_id: userID,
      planning_target_id: target.id,
      status: evaluation.status,
      current_value: evaluation.currentValue,
      target_value: target.target_value,
      unit: target.unit,
      progress_ratio: evaluation.progressRatio,
      evidence_json: evaluation.evidence,
      message: evaluation.message,
      confidence: evaluation.confidence,
    });
    await throwOnError(
      admin
        .from("planning_targets")
        .update({ status: evaluation.status })
        .eq("id", target.id)
        .eq("user_id", userID),
    );
  }

  await throwOnError(admin.from("planning_target_evaluations").insert(evaluations));
}

function evaluateWeeklyTarget(
  target: Record<string, any>,
  workouts: Record<string, any>[],
  actualByPlannedID: Map<string, Record<string, any>>,
  snapshot: Record<string, any> | null,
) {
  const rule = target.evaluation_rule_json ?? {};
  const family = normalizedWeeklyTargetFamily(rule.family) ?? normalizedWeeklyTargetFamily(target.metric_key) ?? "planned_session_completion";
  const comparator = rule.comparator === "at_most" || rule.comparator === "between" ? rule.comparator : "at_least";
  const modality = weeklyTargetModality(target, rule);
  const targetValue = typeof target.target_value === "number" ? target.target_value : null;
  if (!targetValue) {
    return weeklyEvaluation("needs_review", null, null, "This weekly target needs a clearer measurable rule.", { reason: "missing_target_value" }, "low");
  }

  const today = new Date();
  const start = parseDateOnly(target.start_date);
  const end = parseDateOnly(target.target_date);
  const weekIsFuture = start ? start > today : false;
  if (weekIsFuture) {
    return weeklyEvaluation("needs_review", null, null, "This draft-week target will be evaluated once the week starts.", { targetValue, family, comparator }, "medium");
  }

  const currentValue = weeklyCurrentValue(family, modality, workouts, actualByPlannedID, snapshot, target);
  if (currentValue === null) {
    return weeklyEvaluation("needs_review", null, null, "HAYF does not have enough data to evaluate this weekly target yet.", { reason: "missing_weekly_metric", family }, "low");
  }

  const achieved = comparator === "at_most" ? currentValue <= targetValue : currentValue >= targetValue;
  const progressRatio = weeklyProgressRatio(currentValue, targetValue, comparator);
  const expected = start && end ? weeklyExpectedProgressRatio(start, end, today) : 0.5;
  const status = achieved ? "achieved" : progressRatio >= expected * 0.65 ? "on_track" : "lagging";
  const message = achieved
    ? "Weekly target reached."
    : status === "on_track"
      ? "This weekly target is broadly on track."
      : "This weekly target is behind the current week pace.";
  return weeklyEvaluation(status, currentValue, progressRatio, message, { currentValue, targetValue, family, comparator, expectedProgressRatio: expected }, "medium");
}

function weeklyExpectedProgressRatio(start: Date, end: Date, today: Date) {
  if (today <= start) return 0;
  if (today >= end) return 1;
  const totalDays = Math.max(1, daysBetween(start, end));
  const elapsedDays = Math.max(0, daysBetween(start, today));
  return Math.max(0, Math.min(1, elapsedDays / totalDays));
}

function weeklyCurrentValue(
  family: WeeklyTargetFamily,
  modality: string | null,
  workouts: Record<string, any>[],
  actualByPlannedID: Map<string, Record<string, any>>,
  snapshot: Record<string, any> | null,
  target: Record<string, any>,
) {
  const completed = workouts.filter((workout) => isCompletedWorkout(workout, actualByPlannedID));
  const completedForModality = completed.filter((workout) => !modality || workoutMatchesModality(workout, modality));
  const actualsForCompleted = completedForModality.map((workout) => actualByPlannedID.get(workout.id)).filter(Boolean) as Record<string, any>[];
  const actualsForModality = modality
    ? actualsForCompleted.filter((actual) => actualMatchesModality(actual, modality))
    : actualsForCompleted;

  switch (family) {
    case "planned_session_completion":
    case "minimum_viable_week":
      return completed.length;
    case "modality_session_count":
    case "support_modality_presence":
      return completedForModality.length;
    case "modality_minutes":
      if (!modality) return null;
      return actualsForCompleted.length > 0
        ? actualsForModality.reduce((sum, actual) => sum + Number(actual.duration_minutes ?? 0), 0)
        : completedForModality.reduce((sum, workout) => sum + Number(workout.duration_minutes ?? 0), 0);
    case "modality_distance":
      return actualsForModality.reduce((sum, actual) => sum + Number(actual.distance_kilometers ?? 0), 0);
    case "active_days":
      return new Set(completed.map((workout) => workout.scheduled_date)).size;
    case "max_gap_guardrail":
      return longestWorkoutGapDays(completed, target.start_date, target.target_date);
    case "body_weight_logging":
      return bodyWeightEntriesForWeek(snapshot, target.start_date, target.target_date);
    case "running_pace":
      return paceMinutesPerKilometer(actualsForModality);
    case "cycling_pace":
      return speedKilometersPerHour(actualsForModality);
  }
}

function weeklyTargetModality(target: Record<string, any>, rule: Record<string, any>) {
  if (typeof rule.modality === "string" && rule.modality.trim()) {
    return normalizeActivity(rule.modality);
  }
  const inferred = inferModality(`${target.metric_key ?? ""} ${target.title ?? ""} ${target.description ?? ""}`);
  return inferred;
}

function inferModality(value: string) {
  const normalized = normalizeActivity(value);
  return normalized === "workout" ? null : normalized;
}

function workoutMatchesModality(workout: Record<string, any>, modality: string) {
  return normalizeActivity(`${workout.activity_type ?? ""} ${workout.title ?? ""} ${workout.purpose ?? ""}`) === modality;
}

function actualMatchesModality(actual: Record<string, any>, modality: string) {
  return normalizeActivity(`${actual.activity_type ?? ""}`) === modality;
}

function isCompletedWorkout(
  workout: Record<string, any>,
  actualByPlannedID?: Map<string, Record<string, any>>,
) {
  if (String(workout.status) === "done") return true;
  return actualByPlannedID?.has(String(workout.id)) ?? false;
}

function longestWorkoutGapDays(workouts: Record<string, any>[], startDate: string, endDate: string) {
  const start = parseDateOnly(startDate);
  const end = parseDateOnly(endDate);
  if (!start || !end) return null;
  const completedDates = workouts.map((workout) => workout.scheduled_date).filter(Boolean).sort();
  const anchors = [startDate, ...completedDates, endDate];
  let longest = 0;
  for (let index = 1; index < anchors.length; index += 1) {
    const previous = parseDateOnly(anchors[index - 1]);
    const current = parseDateOnly(anchors[index]);
    if (!previous || !current) continue;
    longest = Math.max(longest, Math.max(0, daysBetween(previous, current)));
  }
  return longest;
}

function bodyWeightEntriesForWeek(snapshot: Record<string, any> | null, startDate: string, endDate: string) {
  const latest = snapshot?.body?.bodyMassLatestSampleDate;
  if (typeof latest !== "string") return null;
  const latestDate = latest.slice(0, 10);
  return latestDate >= startDate && latestDate <= endDate ? 1 : 0;
}

function paceMinutesPerKilometer(actuals: Record<string, any>[]) {
  const distance = actuals.reduce((sum, actual) => sum + Number(actual.distance_kilometers ?? 0), 0);
  const duration = actuals.reduce((sum, actual) => sum + Number(actual.duration_minutes ?? 0), 0);
  if (distance <= 0 || duration <= 0) return null;
  return Number((duration / distance).toFixed(2));
}

function speedKilometersPerHour(actuals: Record<string, any>[]) {
  const distance = actuals.reduce((sum, actual) => sum + Number(actual.distance_kilometers ?? 0), 0);
  const duration = actuals.reduce((sum, actual) => sum + Number(actual.duration_minutes ?? 0), 0);
  if (distance <= 0 || duration <= 0) return null;
  return Number((distance / (duration / 60)).toFixed(1));
}

function weeklyProgressRatio(currentValue: number, targetValue: number, comparator: string) {
  if (targetValue <= 0) return 0;
  if (comparator === "at_most") {
    return currentValue <= targetValue ? 1 : Math.max(0, Math.min(1, targetValue / currentValue));
  }
  return Math.max(0, Math.min(1.5, currentValue / targetValue));
}

function weeklyEvaluation(
  status: "on_track" | "lagging" | "achieved" | "needs_review",
  currentValue: number | null,
  progressRatio: number | null,
  message: string,
  evidence: Record<string, unknown>,
  confidence: "low" | "medium" | "high",
) {
  return {
    status,
    currentValue,
    progressRatio: progressRatio !== null ? Number(progressRatio.toFixed(2)) : null,
    message,
    evidence,
    confidence,
  };
}

function objectAt(object: Record<string, unknown> | undefined | null, key: string): Record<string, any> | null {
  const value = object?.[key];
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, any> : null;
}

function arrayAt(object: Record<string, unknown> | undefined | null, key: string): Record<string, any>[] {
  const value = object?.[key];
  return Array.isArray(value) ? value.filter((item) => item && typeof item === "object") as Record<string, any>[] : [];
}

function stringAt(object: Record<string, unknown> | undefined | null, key: string): string | undefined {
  const value = object?.[key];
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function numberAt(object: Record<string, unknown> | undefined | null, key: string): number | null {
  const value = object?.[key];
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function weeklyPlanAsRhythm(plan: Record<string, any>) {
  const rhythm = plan.rhythm_json ?? {};
  return {
    id: plan.id,
    weekly_plan_id: plan.id,
    week_start_date: plan.week_start_date,
    week_end_date: plan.week_end_date,
    objective: plan.objective ?? "",
    priority_order_json: rhythm.priorityOrder ?? rhythm.priority_order ?? [],
    swap_rules_json: rhythm.swapRules ?? rhythm.swap_rules ?? [],
    status: plan.status,
  };
}

type InitialWeekActualWorkout = {
  localDate: string;
  modality: string;
  activityType: string;
  durationMinutes: number;
};

function actualWorkoutsForInitialWeek(
  actualWorkouts: ActualWorkoutInput[],
  weekStartDate: string,
  weekEndDate: string,
  acceptedLocalDate: Date,
  timezone: string,
): InitialWeekActualWorkout[] {
  const acceptedDate = isoDate(acceptedLocalDate);
  return uniqueActualWorkouts(actualWorkouts)
    .map((actual) => {
      const localDate = actualWorkoutLocalDate(actual, timezone);
      return {
        localDate,
        modality: normalizeActivity(actual.activity_type),
        activityType: actual.activity_type,
        durationMinutes: Number(actual.duration_minutes ?? 0),
      };
    })
    .filter((actual) =>
      actual.localDate >= weekStartDate &&
      actual.localDate <= weekEndDate &&
      actual.localDate <= acceptedDate &&
      actual.modality !== "recovery" &&
      actual.modality !== "mobility"
    );
}

function actualWorkoutLocalDate(actual: ActualWorkoutInput, timezone: string) {
  const parsed = parseTimestamp(actual.start_date);
  if (!parsed) return actual.start_date.slice(0, 10);
  return isoDate(dateOnlyInTimezone(parsed, timezone));
}

function applyInitialWeekActualWorkoutContext(
  plan: GeneratedPlan,
  completedActuals: InitialWeekActualWorkout[],
  ownerStartDate: string,
): GeneratedPlan {
  if (completedActuals.length === 0) return plan;

  const completedSummary = completedActuals.map((actual) => ({
    date: actual.localDate,
    modality: actual.modality,
    activityType: actual.activityType,
    durationMinutes: actual.durationMinutes,
  }));

  return {
    ...plan,
    block: {
      ...plan.block,
      context: {
        ...(plan.block.context ?? {}),
        completedThisWeekBeforePlanStart: completedSummary,
      },
    },
    rhythms: plan.rhythms.map((rhythm, rhythmIndex) => {
      if (rhythmIndex !== 0) return rhythm;
      const actualsInWeek = completedActuals.filter((actual) =>
        actual.localDate >= rhythm.weekStartDate && actual.localDate <= rhythm.weekEndDate
      );
      if (actualsInWeek.length === 0) return rhythm;

      const desiredByModality = countByModality(rhythm.workouts.filter(isTrainingWorkout));
      const actualByModality = countActualsByModality(actualsInWeek);
      const sameDayActuals = countActualsByDateAndModality(actualsInWeek);
      const keptByModality = new Map<string, number>();
      const desiredTrainingTotal = rhythm.workouts.filter(isTrainingWorkout).length;
      const remainingTrainingTotal = Math.max(0, desiredTrainingTotal - actualsInWeek.length);
      let keptTrainingTotal = 0;

      const adjustedWorkouts = rhythm.workouts.filter((workout) => {
        if (workout.scheduledDate < ownerStartDate || !isTrainingWorkout(workout)) {
          return true;
        }

        const modality = normalizeActivity(`${workout.activityType} ${workout.title}`);
        const sameDayKey = `${workout.scheduledDate}|${modality}`;
        const sameDayActualCount = sameDayActuals.get(sameDayKey) ?? 0;
        if (sameDayActualCount > 0) {
          sameDayActuals.set(sameDayKey, sameDayActualCount - 1);
          return false;
        }

        const desiredForModality = desiredByModality.get(modality) ?? 0;
        const actualForModality = actualByModality.get(modality) ?? 0;
        const remainingForModality = Math.max(0, desiredForModality - actualForModality);
        const keptForModality = keptByModality.get(modality) ?? 0;
        if (desiredForModality > 0 && keptForModality >= remainingForModality) {
          return false;
        }
        if (keptTrainingTotal >= remainingTrainingTotal) {
          return false;
        }

        keptByModality.set(modality, keptForModality + 1);
        keptTrainingTotal += 1;
        return true;
      });

      const resequenced = adjustedWorkouts.map((workout, index) => ({ ...workout, sequenceOrder: index + 1 }));
      return {
        ...rhythm,
        priorityOrder: resequenced.map((workout) => workout.title),
        workouts: resequenced,
      };
    }),
  };
}

function isTrainingWorkout(workout: GeneratedWorkout) {
  const modality = normalizeActivity(`${workout.activityType} ${workout.title}`);
  return modality !== "recovery" && modality !== "mobility";
}

function countByModality(workouts: GeneratedWorkout[]) {
  const counts = new Map<string, number>();
  for (const workout of workouts) {
    const modality = normalizeActivity(`${workout.activityType} ${workout.title}`);
    counts.set(modality, (counts.get(modality) ?? 0) + 1);
  }
  return counts;
}

function countActualsByModality(actuals: InitialWeekActualWorkout[]) {
  const counts = new Map<string, number>();
  for (const actual of actuals) {
    counts.set(actual.modality, (counts.get(actual.modality) ?? 0) + 1);
  }
  return counts;
}

function countActualsByDateAndModality(actuals: InitialWeekActualWorkout[]) {
  const counts = new Map<string, number>();
  for (const actual of actuals) {
    const key = `${actual.localDate}|${actual.modality}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}

function sanitizeGeneratedPlan(
  generated: GeneratedPlan,
  onboarding: Record<string, any> | null,
  start: Date,
  timezone: string,
): GeneratedPlan {
  const kind = generated.block.kind;
  if (!Array.isArray(generated.rhythms) || generated.rhythms.length === 0) {
    throw new Error("AI plan generation returned no weekly rhythms.");
  }
  const rhythms = generated.rhythms;
  const allowedActivities = allowedPlanActivities(onboarding, null);
  const sanitizedTitle = compactBlockTitle(generated.block.title, generated.block.goalText, rhythms, kind);
  return {
    block: {
      ...generated.block,
      kind,
      title: sanitizedTitle,
      startDate: generated.block.startDate || isoDate(start),
      targetDate: kind === "consistency" ? null : generated.block.targetDate,
      reviewCadenceDays: kind === "consistency" ? 28 : Math.max(28, generated.block.reviewCadenceDays || 56),
      context: {
        ...(generated.block.context ?? {}),
        timezone,
      },
    },
    phases: kind === "consistency" ? [] : generated.phases,
    rhythms: rhythms.map((rhythm) => ({
      ...rhythm,
      workouts: sanitizeGeneratedWorkoutsForAllowedActivities(
        normalizeGeneratedWorkoutTaxonomy(rhythm.workouts),
        allowedActivities,
      ).map((workout, index) => ({
        ...workout,
        sequenceOrder: workout.sequenceOrder || index + 1,
        durationMinutes: Math.max(10, workout.durationMinutes || 30),
        fuelingSummary: workout.fuelingSummary?.trim() || fuelingSummary(workout.activityType, workout.intensityLabel),
        prescription: workout.prescription ?? fallbackPrescription(workout.title, workout.activityType, workout.intensityLabel),
      })),
    })),
  };
}

function sanitizeGeneratedWorkoutsForAllowedActivities(
  workouts: GeneratedWorkout[],
  allowedActivities: string[],
) {
  if (allowedActivities.length === 0) return workouts;
  const allowed = new Set(allowedActivities);
  return workouts.map((workout, index) => {
    const activity = normalizeActivity(`${workout.activityType} ${workout.title} ${workout.purpose}`);
    if (allowed.has(activity)) return workout;

    const replacementActivity = allowedActivities[index % allowedActivities.length] ?? allowedActivities[0];
    const template = workoutTemplateForModality(replacementActivity);
    return {
      ...workout,
      activityType: template.activityType,
      title: template.title,
      intensityLabel: template.intensityLabel,
      purpose: template.purpose,
      prescription: template.prescription,
      fuelingSummary: template.fuelingSummary,
      durationMinutes: workout.durationMinutes || template.durationMinutes,
    };
  });
}

function normalizeGeneratedWorkoutTaxonomy(workouts: GeneratedWorkout[]) {
  let fullBodyCount = 0;
  let upperCount = 0;
  let lowerCount = 0;
  return workouts.map((workout) => {
    const text = `${workout.activityType} ${workout.title} ${workout.purpose}`.toLowerCase();
    if (!isStrengthLike(workout.activityType, text)) {
      return {
        ...workout,
        title: normalizedWorkoutTitle(workout.activityType, workout.title, workout.durationMinutes, workout.intensityLabel, workout.purpose),
      };
    }

    if (/upper/.test(text)) {
      upperCount += 1;
      return { ...workout, title: `Upper Body ${strengthLetter(upperCount)}` };
    }
    if (/lower|leg/.test(text)) {
      lowerCount += 1;
      return { ...workout, title: `Lower Body ${strengthLetter(lowerCount)}` };
    }
    fullBodyCount += 1;
    return { ...workout, title: `Full Body ${strengthLetter(fullBodyCount)}` };
  });
}

function strengthLetter(index: number) {
  return ["A", "B", "C", "D", "E"][Math.max(0, Math.min(4, index - 1))] ?? "A";
}

async function markMissedWorkouts(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  syncEndDate?: string,
) {
  const cutoff = parseDateOnly(syncEndDate) ?? new Date();
  const cutoffDate = isoDate(cutoff);
  const plans = await list(
    admin
      .from("weekly_plans")
      .select("id")
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
  );
  const planIDs = plans.map((plan: Record<string, any>) => plan.id);
  if (planIDs.length === 0) return [];
  return list(
    admin
      .from("planned_workouts")
      .update({ status: "missed" })
      .eq("user_id", userID)
      .in("weekly_plan_id", planIDs)
      .lt("scheduled_date", cutoffDate)
      .in("status", ["planned", "current", "checked_in", "adjusted"])
      .in("source", ["generated", "replanned", "user_moved", "user_added", "checkin_adjusted"])
      .select("id, scheduled_date, title"),
  );
}

async function markCurrentWorkoutForStrategy(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  today: Date,
) {
  const allPlans = await list(
    admin
      .from("weekly_plans")
      .select("id")
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID),
  );
  const allPlanIDs = allPlans.map((plan: Record<string, any>) => plan.id);
  if (allPlanIDs.length === 0) return;

  const activePlans = await list(
    admin
      .from("weekly_plans")
      .select("id")
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .in("status", ["committed", "draft"]),
  );
  const planIDs = activePlans.map((plan: Record<string, any>) => plan.id);

  await throwOnError(
    admin
      .from("planned_workouts")
      .update({ status: "planned" })
      .eq("user_id", userID)
      .in("weekly_plan_id", allPlanIDs)
      .eq("status", "current"),
  );
  if (planIDs.length === 0) return;

  const next = await maybeSingle(
    admin
      .from("planned_workouts")
      .select()
      .eq("user_id", userID)
      .in("weekly_plan_id", planIDs)
      .gte("scheduled_date", isoDate(today))
      .in("status", ["planned", "checked_in", "adjusted"])
      .order("scheduled_date", { ascending: true })
      .order("sequence_order", { ascending: true })
      .limit(1),
  );

  if (next?.status === "planned") {
    await throwOnError(admin.from("planned_workouts").update({ status: "current" }).eq("id", next.id));
  }
}

async function promoteDraftWeeklyPlan(admin: SupabaseAdminClient, userID: string, strategyID: string) {
  const drafts = await list(
    admin
      .from("weekly_plans")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .eq("status", "draft")
      .order("week_start_date", { ascending: true })
      .limit(1),
  );
  const draft = drafts[0];
  if (!draft) return null;

  await throwOnError(
    admin
      .from("weekly_plans")
      .update({ status: "archived" })
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .eq("status", "committed"),
  );
  const promotedAt = new Date().toISOString();
  await throwOnError(
    admin
      .from("weekly_plans")
      .update({ status: "committed", promoted_at: promotedAt })
      .eq("id", draft.id)
      .eq("user_id", userID),
  );
  await createPlanEvent(admin, {
    userID,
    fitnessStrategyID: strategyID,
    weeklyPlanID: draft.id,
    eventType: "weekly_plan_promoted",
    payload: { weekStartDate: draft.week_start_date, promotedAt },
  });
  return draft;
}

async function loadActivePlanningScope(admin: SupabaseAdminClient, userID: string): Promise<PlanningScope> {
  const strategy = await single(
    admin
      .from("fitness_strategies")
      .select()
      .eq("user_id", userID)
      .eq("status", "active")
      .single(),
    "Active fitness strategy not found",
  );
  const goal = await single(
    admin
      .from("user_goals")
      .select()
      .eq("id", strategy.user_goal_id)
      .eq("user_id", userID)
      .single(),
    "Active user goal not found",
  );
  const profile = await maybeSingle(admin.from("profiles").select("main_city").eq("id", userID));
  const onboarding = await maybeSingle(admin.from("onboarding_profiles").select("selected_answers").eq("id", userID));
  const timezone = strategy.context_json?.timezone || "UTC";
  return {
    goal,
    strategy,
    timezone,
    homeLocationLabel: profile?.main_city ?? null,
    weatherSensitive: onboardingHasWeatherBlocker(onboarding),
    block: {
      id: strategy.id,
      kind: goal.goal_kind,
      title: strategy.title,
      goal_text: goal.title,
      start_date: strategy.start_date,
      target_date: strategy.target_date,
      review_cadence_days: strategy.review_cadence_days,
      timezone,
      context_json: strategy.context_json ?? {},
    },
  };
}

async function visibleWeeklyPlans(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  window: { start: string; end: string },
) {
  return list(
    admin
      .from("weekly_plans")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .gte("week_start_date", window.start)
      .lte("week_start_date", window.end)
      .order("week_start_date", { ascending: true }),
  );
}

async function weeklyPlanForDate(admin: SupabaseAdminClient, userID: string, strategyID: string, scheduledDate: string) {
  const weekStart = isoDate(startOfWeek(parseDateOnly(scheduledDate) ?? new Date()));
  return maybeSingle(
    admin
      .from("weekly_plans")
      .select()
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .eq("week_start_date", weekStart)
      .limit(1),
  );
}

async function loadPlannedWorkoutForActiveStrategy(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  plannedWorkoutID: string,
) {
  const workout = await single(
    admin
      .from("planned_workouts")
      .select()
      .eq("id", plannedWorkoutID)
      .eq("user_id", userID)
      .single(),
    "Planned workout not found",
  );
  if (!workout.weekly_plan_id) {
    throw new Error("Planned workout is not attached to a weekly plan.");
  }
  const weeklyPlan = await single(
    admin
      .from("weekly_plans")
      .select("id,fitness_strategy_id")
      .eq("id", workout.weekly_plan_id)
      .eq("user_id", userID)
      .single(),
    "Workout weekly plan not found",
  );
  if (weeklyPlan.fitness_strategy_id !== strategyID) {
    throw new Error("Planned workout is not part of the active strategy.");
  }
  return workout;
}

async function reconcileActualWorkouts(
  admin: SupabaseAdminClient,
  userID: string,
  scope: PlanningScope,
  actualWorkouts: ActualWorkoutInput[],
  options: {
    createDetectedProposal: boolean;
    createDisparityProposal: boolean;
  },
) {
  let synced = 0;
  let matched = 0;
  let detected = 0;
  const detectedEvents: Array<{ eventID: string; plannedWorkoutID: string; actual: ActualWorkoutInput }> = [];
  const syncedDates = new Set<string>();

  for (const actual of uniqueActualWorkouts(actualWorkouts)) {
    syncedDates.add(actual.start_date.slice(0, 10));
    const upserted = await single(
      admin
        .from("actual_workouts")
        .upsert(
          {
            user_id: userID,
            healthkit_uuid: actual.healthkit_uuid,
            start_date: actual.start_date,
            activity_type: actual.activity_type,
            duration_minutes: actual.duration_minutes,
            distance_kilometers: actual.distance_kilometers ?? null,
            energy_kilocalories: actual.energy_kilocalories ?? null,
            load_value: actual.load_value ?? null,
            average_heart_rate_bpm: actual.average_heart_rate_bpm ?? null,
            max_heart_rate_bpm: actual.max_heart_rate_bpm ?? null,
            heart_rate_samples_json: actual.heart_rate_samples ?? [],
          },
          { onConflict: "user_id,healthkit_uuid" },
        )
        .select()
        .single(),
      "Could not upsert actual workout",
    );
    synced += 1;

    let staleDetectedWorkoutID: string | null = null;
    if (upserted.matched_planned_workout_id) {
      const existingMatch = await actualMatchForStrategy(
        admin,
        userID,
        scope.strategy.id,
        upserted.matched_planned_workout_id,
      );
      if (existingMatch && existingMatch.source !== "healthkit_detected") {
        continue;
      }
      if (existingMatch?.source === "healthkit_detected") {
        staleDetectedWorkoutID = existingMatch.id;
      }
      await throwOnError(
        admin
          .from("actual_workouts")
          .update({ matched_planned_workout_id: null, match_confidence: null })
          .eq("id", upserted.id),
      );
    }

    const match = await findWorkoutMatch(admin, userID, scope, actual);
    if (match) {
      await throwOnError(
        admin
          .from("actual_workouts")
          .update({ matched_planned_workout_id: match.workout.id, match_confidence: match.confidence })
          .eq("id", upserted.id),
      );
      await throwOnError(admin.from("planned_workouts").update({ status: "done" }).eq("id", match.workout.id));
      const matchEvent = await createPlanEvent(admin, {
        userID,
        fitnessStrategyID: scope.strategy.id,
        weeklyPlanID: match.workout.weekly_plan_id ?? null,
        plannedWorkoutID: match.workout.id,
        eventType: "actual_matched",
        payload: {
          actual,
          confidence: match.confidence,
          matchDisparity: match.disparity,
          plannedWorkout: compactPlannedWorkout(match.workout),
        },
      });
      await createWorkoutDebriefRequest(admin, userID, null, match.workout.id, upserted.id);
      if (options.createDisparityProposal && match.disparity?.needsReview) {
        await createReplanProposal(admin, {
          userID,
          fitnessStrategyID: scope.strategy.id,
          weeklyPlanID: match.workout.weekly_plan_id ?? null,
          triggerEventID: matchEvent.id,
          reason: "Completed workout differed meaningfully from the planned session. Review whether the rest of the week should change.",
          mutations: [],
          metadata: {
            type: "actual_workout_disparity",
            plannedWorkoutID: match.workout.id,
            actualWorkoutID: upserted.id,
            plannedWorkout: compactPlannedWorkout(match.workout),
            actualWorkout: compactActualWorkout(actual),
            disparity: match.disparity,
          },
        });
      }
      if (staleDetectedWorkoutID) {
        await throwOnError(
          admin
            .from("planned_workouts")
            .update({ status: "deleted" })
            .eq("user_id", userID)
            .eq("id", staleDetectedWorkoutID),
        );
      }
      matched += 1;
    } else {
      const inserted = await insertDetectedWorkout(admin, userID, scope, actual);
      await throwOnError(
        admin
          .from("actual_workouts")
          .update({ matched_planned_workout_id: inserted.id, match_confidence: 1 })
          .eq("id", upserted.id),
      );
      const event = await createPlanEvent(admin, {
        userID,
        fitnessStrategyID: scope.strategy.id,
        weeklyPlanID: inserted.weekly_plan_id ?? null,
        plannedWorkoutID: inserted.id,
        eventType: "extra_workout_detected",
        payload: { actual },
      });
      await createWorkoutDebriefRequest(admin, userID, null, inserted.id, upserted.id);
      if (staleDetectedWorkoutID && staleDetectedWorkoutID !== inserted.id) {
        await throwOnError(
          admin
            .from("planned_workouts")
            .update({ status: "deleted" })
            .eq("user_id", userID)
            .eq("id", staleDetectedWorkoutID),
        );
      }
      detectedEvents.push({ eventID: event.id, plannedWorkoutID: inserted.id, actual });
      detected += 1;
    }
  }

  const dedupedDetected = await cleanupDuplicateDetectedWorkouts(admin, userID, Array.from(syncedDates));
  if (options.createDetectedProposal && detectedEvents.length > 0) {
    await createReplanProposal(admin, {
      userID,
      fitnessStrategyID: scope.strategy.id,
      triggerEventID: null,
      reason: detectedEvents.length === 1
        ? "Unexpected HealthKit workout detected. Review whether the rest of the week should change."
        : `${detectedEvents.length} unexpected HealthKit workouts detected. Review whether the current rhythm should change.`,
      mutations: [],
      metadata: {
        detectedWorkoutEventIDs: detectedEvents.map((detectedEvent) => detectedEvent.eventID),
        detectedPlannedWorkoutIDs: detectedEvents.map((detectedEvent) => detectedEvent.plannedWorkoutID),
      },
    });
  }

  return { synced, matched, detected, dedupedDetected, detectedEvents };
}

async function actualMatchForStrategy(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  plannedWorkoutID: string,
) {
  const workout = await maybeSingle(
    admin
      .from("planned_workouts")
      .select("id,weekly_plan_id,status,source")
      .eq("id", plannedWorkoutID)
      .eq("user_id", userID)
      .maybeSingle(),
  );
  if (!workout || ["deleted", "superseded"].includes(String(workout.status ?? ""))) {
    return null;
  }
  if (!workout.weekly_plan_id) {
    return null;
  }
  const weeklyPlan = await maybeSingle(
    admin
      .from("weekly_plans")
      .select("id")
      .eq("id", workout.weekly_plan_id)
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .maybeSingle(),
  );
  return weeklyPlan ? workout : null;
}

async function findWorkoutMatch(
  admin: SupabaseAdminClient,
  userID: string,
  scope: PlanningScope,
  actual: ActualWorkoutInput,
) {
  const actualDate = actual.start_date.slice(0, 10);
  const weeklyPlan = await weeklyPlanForDate(admin, userID, scope.strategy.id, actualDate);
  if (!weeklyPlan) return null;
  const candidates = await list(
    admin
      .from("planned_workouts")
      .select()
      .eq("user_id", userID)
      .eq("weekly_plan_id", weeklyPlan.id)
      .eq("scheduled_date", actualDate)
      .in("status", ["planned", "current", "checked_in", "adjusted"]),
  );

  let best: { workout: Record<string, any>; confidence: number; disparity: WorkoutMatchDisparity | null } | null = null;
  for (const workout of candidates) {
    const match = workoutMatchScore(actual, workout);
    if (match && (!best || compareWorkoutMatches(match, workout, best) > 0)) {
      const confidence = match.confidence;
      best = { workout, confidence, disparity: match.disparity };
    }
  }
  return best;
}

async function insertDetectedWorkout(
  admin: SupabaseAdminClient,
  userID: string,
  scope: PlanningScope,
  actual: ActualWorkoutInput,
) {
  const actualDate = actual.start_date.slice(0, 10);
  const weeklyPlan = await weeklyPlanForDate(admin, userID, scope.strategy.id, actualDate);
  const existing = await list(
    admin
      .from("planned_workouts")
      .select()
      .eq("user_id", userID)
      .eq("scheduled_date", actualDate)
      .eq("source", "healthkit_detected")
      .not("status", "in", "(deleted,superseded)"),
  );
  const duplicate = existing.find((workout: Record<string, any>) =>
    (workout.weekly_plan_id ?? null) === (weeklyPlan?.id ?? null) &&
    normalizeActivity(`${workout.activity_type ?? ""} ${workout.title ?? ""}`) === normalizeActivity(actual.activity_type) &&
    Number(workout.duration_minutes ?? 0) === Number(actual.duration_minutes ?? 0)
  );
  if (duplicate) return duplicate;

  return single(
    admin
      .from("planned_workouts")
      .insert({
        user_id: userID,
        active_block_id: null,
        weekly_rhythm_id: null,
        weekly_plan_id: weeklyPlan?.id ?? null,
        scheduled_date: actualDate,
        sequence_order: existing.length + 1,
        activity_type: normalizeActivity(actual.activity_type),
        title: detectedWorkoutTitle(actual.activity_type),
        duration_minutes: actual.duration_minutes,
        intensity_label: "Detected",
        purpose: "Added from HealthKit",
        ...workoutCardFields({
          scheduledDate: actualDate,
          activityType: actual.activity_type,
          title: detectedWorkoutTitle(actual.activity_type),
          durationMinutes: actual.duration_minutes,
          intensityLabel: "Detected",
          purpose: "Added from HealthKit",
          locationLabel: scope.homeLocationLabel,
          distanceKilometers: actual.distance_kilometers ?? null,
        }),
        status: "done",
        source: "healthkit_detected",
        prescription_json: { detectedFrom: "HealthKit" },
      })
      .select()
      .single(),
    "Could not insert detected workout",
  );
}

function uniqueActualWorkouts(workouts: ActualWorkoutInput[]) {
  const seen = new Set<string>();
  const unique: ActualWorkoutInput[] = [];
  for (const workout of workouts) {
    const key = [
      workout.start_date.slice(0, 16),
      normalizeActivity(workout.activity_type),
      Math.round(Number(workout.duration_minutes ?? 0)),
      workout.distance_kilometers == null ? "" : Number(workout.distance_kilometers).toFixed(2),
    ].join("|");
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(workout);
  }
  return unique;
}

function compactPlannedWorkout(workout: Record<string, any>) {
  return {
    id: workout.id,
    scheduledDate: workout.scheduled_date,
    source: workout.source ?? null,
    activityType: workout.activity_type,
    title: workout.title,
    durationMinutes: workout.duration_minutes,
    intensityLabel: workout.intensity_label,
    purpose: workout.purpose,
  };
}

function compactActualWorkout(actual: ActualWorkoutInput) {
  return {
    healthkitUUID: actual.healthkit_uuid,
    startDate: actual.start_date,
    activityType: actual.activity_type,
    durationMinutes: actual.duration_minutes,
    distanceKilometers: actual.distance_kilometers ?? null,
    energyKilocalories: actual.energy_kilocalories ?? null,
    averageHeartRateBPM: actual.average_heart_rate_bpm ?? null,
    maxHeartRateBPM: actual.max_heart_rate_bpm ?? null,
  };
}

function detectedWorkoutTitle(activityType: string) {
  const activity = normalizeActivity(activityType);
  if (activity === "strength") return "Strength";
  if (activity === "ride") return "Base Ride";
  if (activity === "run") return "Base Run";
  if (activity === "hike") return "Easy Hike";
  if (activity === "swim") return "Base Swim";
  if (activity === "mobility") return "Mobility";
  if (activity === "recovery") return "Recovery";
  return titleCase(activityType);
}

async function cleanupDuplicateDetectedWorkouts(
  admin: SupabaseAdminClient,
  userID: string,
  dates: string[],
) {
  const uniqueDates = Array.from(new Set(dates.filter(Boolean)));
  if (uniqueDates.length === 0) return 0;

  const detected = await list(
    admin
      .from("planned_workouts")
      .select("id,weekly_plan_id,scheduled_date,activity_type,title,duration_minutes,created_at")
      .eq("user_id", userID)
      .eq("source", "healthkit_detected")
      .in("scheduled_date", uniqueDates)
      .not("status", "in", "(deleted,superseded)"),
  );

  const groups = new Map<string, Record<string, any>[]>();
  for (const workout of detected) {
    const key = [
      workout.weekly_plan_id ?? "none",
      workout.scheduled_date,
      normalizeActivity(`${workout.activity_type ?? ""} ${workout.title ?? ""}`),
      Number(workout.duration_minutes ?? 0),
    ].join("|");
    groups.set(key, [...(groups.get(key) ?? []), workout]);
  }

  let removed = 0;
  for (const group of groups.values()) {
    if (group.length < 2) continue;
    const sorted = group.sort((a, b) => String(a.created_at ?? "").localeCompare(String(b.created_at ?? "")));
    const keeper = sorted[0];
    const duplicateIDs = sorted.slice(1).map((workout) => workout.id);
    await throwOnError(
      admin
        .from("actual_workouts")
        .update({ matched_planned_workout_id: keeper.id, match_confidence: 1 })
        .eq("user_id", userID)
        .in("matched_planned_workout_id", duplicateIDs),
    );
    await throwOnError(
      admin
        .from("planned_workouts")
        .update({ status: "deleted" })
        .eq("user_id", userID)
        .in("id", duplicateIDs),
    );
    removed += duplicateIDs.length;
  }

  return removed;
}

async function cleanupDuplicateGeneratedPlanWorkouts(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  window: { start: string; end: string },
) {
  const weeklyPlans = await list(
    admin
      .from("weekly_plans")
      .select("id")
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .gte("week_start_date", window.start)
      .lte("week_start_date", window.end)
      .in("status", ["committed", "draft"]),
  );
  const planIDs = weeklyPlans.map((plan: Record<string, any>) => plan.id);
  if (planIDs.length === 0) return 0;

  const workouts = await list(
    admin
      .from("planned_workouts")
      .select("id,weekly_plan_id,scheduled_date,sequence_order,activity_type,title,duration_minutes,intensity_label,purpose,status,source,created_at")
      .eq("user_id", userID)
      .in("weekly_plan_id", planIDs)
      .gte("scheduled_date", window.start)
      .lte("scheduled_date", window.end)
      .in("status", ["planned", "current"])
      .in("source", ["generated", "replanned"]),
  );

  const groups = new Map<string, Record<string, any>[]>();
  for (const workout of workouts) {
    const key = [
      workout.weekly_plan_id,
      workout.scheduled_date,
      Number(workout.sequence_order ?? 0),
      normalizeActivity(workout.activity_type ?? ""),
      normalizedGeneratedWorkoutText(workout.title),
      Number(workout.duration_minutes ?? 0),
      normalizedGeneratedWorkoutText(workout.intensity_label),
      normalizedGeneratedWorkoutText(workout.purpose),
    ].join("|");
    groups.set(key, [...(groups.get(key) ?? []), workout]);
  }

  let removed = 0;
  for (const group of groups.values()) {
    if (group.length < 2) continue;
    const sorted = group.sort((a, b) => {
      const statusRank = generatedWorkoutStatusRank(a.status) - generatedWorkoutStatusRank(b.status);
      if (statusRank !== 0) return statusRank;
      return String(a.created_at ?? "").localeCompare(String(b.created_at ?? ""));
    });
    const duplicateIDs = sorted.slice(1).map((workout) => workout.id);
    await throwOnError(
      admin
        .from("planned_workouts")
        .update({ status: "superseded", generation_key: null })
        .eq("user_id", userID)
        .in("id", duplicateIDs),
    );
    removed += duplicateIDs.length;
  }

  return removed;
}

function normalizedGeneratedWorkoutText(value: unknown) {
  return String(value ?? "").trim().toLowerCase().replace(/\s+/g, " ");
}

function generatedWorkoutStatusRank(status: unknown) {
  return String(status) === "current" ? 0 : 1;
}

async function persistFitnessEvidence(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string | null,
  snapshot: Record<string, any>,
  links: { userGoalID?: string | null; fitnessStrategyID?: string | null } = {},
) {
  const profile = snapshot.fitnessHistory ?? snapshot.fitness_history;
  if (!profile) {
    return;
  }

  const generatedAt = snapshotGeneratedAt(snapshot);
  const insights = Array.isArray(profile.insightCandidates ?? profile.insight_candidates)
    ? profile.insightCandidates ?? profile.insight_candidates
    : [];

  if (insights.length > 0) {
    await throwOnError(
      admin.from("fitness_history_insights").upsert(
        insights.map((insight: Record<string, any>) => ({
          user_id: userID,
          active_block_id: activeBlockID,
          user_goal_id: links.userGoalID ?? null,
          fitness_strategy_id: links.fitnessStrategyID ?? null,
          insight_key: insight.key,
          category: insight.category ?? "general",
          title: insight.title ?? "Fitness insight",
          summary: insight.summary ?? "",
          evidence_json: insight.evidence ?? {},
          source: "healthkit",
          confidence: insight.confidence ?? "medium",
          updated_at: new Date().toISOString(),
        })),
        { onConflict: "user_id,insight_key" },
      ),
    );
  }

  const observations = fitnessMetricObservations(userID, activeBlockID, snapshot, profile, generatedAt, links);
  if (observations.length > 0) {
    await throwOnError(admin.from("fitness_metric_observations").insert(observations));
  }
}

function fitnessMetricObservations(
  userID: string,
  activeBlockID: string | null,
  snapshot: Record<string, any>,
  profile: Record<string, any>,
  observedAt: string,
  links: { userGoalID?: string | null; fitnessStrategyID?: string | null } = {},
) {
  const rows: Array<Record<string, unknown>> = [];
  const push = (
    metricKey: string,
    metricLabel: string,
    metricCategory: string,
    value: unknown,
    unit: string | null,
    dimensions: Record<string, unknown> = {},
    evidence: Record<string, unknown> = {},
    confidence = "high",
  ) => {
    if (typeof value !== "number" || Number.isNaN(value)) {
      return;
    }

    rows.push({
      user_id: userID,
      active_block_id: activeBlockID,
      user_goal_id: links.userGoalID ?? null,
      fitness_strategy_id: links.fitnessStrategyID ?? null,
      source: "healthkit",
      metric_key: metricKey,
      metric_label: metricLabel,
      metric_category: metricCategory,
      value,
      unit,
      observed_end: observedAt,
      dimensions_json: dimensions,
      evidence_json: evidence,
      confidence,
    });
  };

  const loadWindows = profile.load?.windows ?? [];
  for (const window of loadWindows) {
    push(`training_minutes_${window.window}`, `Training minutes ${window.window}`, "volume", window.totalMinutes, "min", { window: window.window });
    push(`training_workouts_${window.window}`, `Workouts ${window.window}`, "consistency", window.workouts, "count", { window: window.window });
    push(`training_distance_${window.window}_km`, `Training distance ${window.window}`, "volume", window.totalDistanceKilometers, "km", { window: window.window });
  }

  push("cycling_distance_7d_km", "Cycling distance 7d", "weekly_cycling", snapshot.activity?.cyclingDistance7DaysKilometers, "km", { modality: "cycling", window: "7d" });
  push("running_distance_7d_km", "Running distance 7d", "weekly_running", snapshot.activity?.runningDistance7DaysKilometers ?? snapshot.activity?.walkingRunningDistance7DaysKilometers, "km", { modality: "running", window: "7d" });
  push("cycling_distance_90d_km", "Cycling distance 90d", "volume", snapshot.activity?.cyclingDistance90DaysKilometers, "km", { modality: "cycling", window: "90d" });
  push("walking_running_distance_28d_km", "Walking/running distance 28d", "volume", snapshot.activity?.walkingRunningDistance28DaysKilometers, "km", { modality: "walking_running", window: "28d" });
  push("steps_7d_avg", "Average steps 7d", "activity_floor", snapshot.activity?.averageSteps7Days, "steps/day", { window: "7d" });
  push("active_energy_7d_kcal", "Active energy 7d", "activity_floor", snapshot.activity?.activeEnergy7DaysKilocalories, "kcal", { window: "7d" });
  push("body_mass_latest_kg", "Body mass latest", "body", recentBodyMetricValue(snapshot.body?.bodyMassKilograms, snapshot.body?.bodyMassLatestSampleDate), "kg");
  push("body_mass_28d_avg_kg", "Body mass 28d average", "body", snapshot.body?.bodyMass28DayAverageKilograms, "kg", { window: "28d" });
  pushBodyTrendObservations(rows, userID, activeBlockID, observedAt, "body_mass", "Body mass", "kg", snapshot.body?.bodyMassHistory ?? profile.bodyTrend?.bodyMassHistory, links);
  push("body_fat_latest_percentage", "Body fat latest", "body", recentBodyMetricValue(snapshot.body?.bodyFatPercentage, snapshot.body?.bodyFatLatestSampleDate), "%");
  push("body_fat_28d_avg_percentage", "Body fat 28d average", "body", snapshot.body?.bodyFat28DayAveragePercentage, "%", { window: "28d" });
  pushBodyTrendObservations(rows, userID, activeBlockID, observedAt, "body_fat", "Body fat", "percentage_points", snapshot.body?.bodyFatHistory ?? profile.bodyTrend?.bodyFatHistory, links);
  push("vo2_max_latest", "VO2 max latest", "recovery", snapshot.recovery?.vo2MaxLatest, "mL/kg/min");
  push("active_weeks", "Active training weeks", "consistency", profile.consistency?.activeWeeks, "weeks");
  push("longest_active_week_streak", "Longest active week streak", "consistency", profile.consistency?.longestActiveWeekStreak, "weeks");
  push("strength_workouts_7d", "Strength workouts 7d", "weekly_strength", profile.strengthContinuity?.strengthWorkouts7Days, "sessions", { modality: "strength", window: "7d" });
  push("strength_minutes_7d", "Strength minutes 7d", "weekly_strength", profile.strengthContinuity?.strengthMinutes7Days, "min", { modality: "strength", window: "7d" });
  push("strength_workouts_90d", "Strength workouts 90d", "balance", profile.strengthContinuity?.strengthWorkouts90Days, "count", { modality: "strength", window: "90d" });
  push("strength_minutes_90d", "Strength minutes 90d", "balance", profile.strengthContinuity?.strengthMinutes90Days, "min", { modality: "strength", window: "90d" });

  const bestEfforts = profile.performance?.bestDistanceEfforts ?? [];
  for (const effort of bestEfforts) {
    push(
      `${effort.modality}_best_${String(effort.distanceBucketKilometers).replace(".", "_")}k_kph`,
      `${titleCase(effort.modality)} best ${effort.distanceBucketKilometers} km speed`,
      "performance",
      effort.averageSpeedKilometersPerHour,
      "km/h",
      { modality: effort.modality, distanceBucketKilometers: effort.distanceBucketKilometers },
      effort,
    );
  }

  return rows;
}

function pushBodyTrendObservations(
  rows: Array<Record<string, unknown>>,
  userID: string,
  activeBlockID: string | null,
  observedAt: string,
  metricPrefix: "body_mass" | "body_fat",
  metricLabel: string,
  changeUnit: string,
  trend: Record<string, any> | null | undefined,
  links: { userGoalID?: string | null; fitnessStrategyID?: string | null } = {},
) {
  if (!trend || trend.trend === "insufficient") return;

  const confidence = trend.confidence === "high" ? "high" : "medium";
  const commonEvidence = {
    trend: trend.trend ?? null,
    sampleCount: trend.sampleCount ?? null,
    firstSampleDate: trend.firstSampleDate ?? null,
    latestSampleDate: trend.latestSampleDate ?? null,
    firstValue: trend.firstValue ?? null,
    latestValue: trend.latestValue ?? null,
    daysCovered: trend.daysCovered ?? null,
  };

  const push = (
    metricKey: string,
    label: string,
    value: unknown,
    unit: string,
    dimensions: Record<string, unknown>,
  ) => {
    if (typeof value !== "number" || Number.isNaN(value)) return;
    rows.push({
      user_id: userID,
      active_block_id: activeBlockID,
      user_goal_id: links.userGoalID ?? null,
      fitness_strategy_id: links.fitnessStrategyID ?? null,
      source: "healthkit",
      metric_key: metricKey,
      metric_label: label,
      metric_category: "body",
      value,
      unit,
      observed_start: trend.firstSampleDate ?? null,
      observed_end: trend.latestSampleDate ?? observedAt,
      dimensions_json: dimensions,
      evidence_json: commonEvidence,
      confidence,
    });
  };

  push(`${metricPrefix}_change_tracked`, `${metricLabel} change tracked`, trend.change, changeUnit, { window: "tracked" });
  push(`${metricPrefix}_weekly_change_rate`, `${metricLabel} weekly change rate`, trend.weeklyChangeRate, changeUnit, { cadence: "weekly" });
  push(`${metricPrefix}_change_28d`, `${metricLabel} change 28d`, trend.change28Days, changeUnit, { window: "28d" });
  push(`${metricPrefix}_change_90d`, `${metricLabel} change 90d`, trend.change90Days, changeUnit, { window: "90d" });
  push(`${metricPrefix}_change_180d`, `${metricLabel} change 180d`, trend.change180Days, changeUnit, { window: "180d" });
}

function recentBodyMetricValue(value: unknown, sampleDate: unknown) {
  if (typeof value !== "number" || Number.isNaN(value) || typeof sampleDate !== "string") {
    return null;
  }
  const parsed = new Date(sampleDate);
  if (Number.isNaN(parsed.getTime())) return null;
  const cutoff = new Date();
  cutoff.setUTCDate(cutoff.getUTCDate() - 90);
  return parsed >= cutoff ? value : null;
}

function evaluateGoalTarget(target: Record<string, any>, currentValue: number | null | undefined) {
  if (typeof currentValue !== "number" || Number.isNaN(currentValue)) {
    return {
      status: "needs_review",
      progressRatio: null,
      confidence: "low",
      message: "HAYF does not have enough data to evaluate this target yet.",
      evidence: { reason: "missing_metric", metricKey: target.metric_key },
    };
  }

  const targetValue = typeof target.target_value === "number" ? target.target_value : null;
  const baseline = typeof target.baseline_value === "number" ? target.baseline_value : null;
  if (target.direction === "review" || targetValue === null) {
    return {
      status: "needs_review",
      progressRatio: null,
      confidence: "medium",
      message: "This target is useful context, but needs a clearer measurable rule.",
      evidence: { currentValue },
    };
  }

  if (target.direction === "maintain") {
    const status = currentValue >= targetValue ? "on_track" : "lagging";
    return {
      status,
      progressRatio: targetValue > 0 ? Number((currentValue / targetValue).toFixed(2)) : null,
      confidence: "medium",
      message: status === "on_track" ? "This support target is holding." : "This support target is below its current threshold.",
      evidence: { currentValue, targetValue },
    };
  }

  const denominator = baseline !== null ? Math.abs(targetValue - baseline) : Math.abs(targetValue);
  const moved = target.direction === "decrease"
    ? (baseline ?? targetValue) - currentValue
    : currentValue - (baseline ?? 0);
  const progressRatio = denominator > 0 ? Math.max(0, Math.min(1.5, moved / denominator)) : null;
  const achieved = target.direction === "decrease" ? currentValue <= targetValue : currentValue >= targetValue;
  const expected = expectedProgressRatio(target.start_date, target.target_date);
  const status = achieved ? "achieved" : progressRatio !== null && progressRatio >= expected * 0.65 ? "on_track" : "lagging";

  return {
    status,
    progressRatio: progressRatio !== null ? Number(progressRatio.toFixed(2)) : null,
    confidence: "medium",
    message: achieved ? "Target reached." : status === "on_track" ? "Progress is broadly on track." : "Progress is behind the current block pace.",
    evidence: { currentValue, targetValue, baseline, expectedProgressRatio: expected },
  };
}

function metricValueFor(snapshot: Record<string, any>, metricKey: string): number | null {
  const profile = snapshot.fitnessHistory ?? snapshot.fitness_history ?? {};
  const loadWindow = (window: string, field: string) =>
    (profile.load?.windows ?? []).find((item: Record<string, any>) => item.window === window)?.[field];

  const values: Record<string, unknown> = {
    training_minutes_7d: loadWindow("7d", "totalMinutes"),
    training_minutes_28d: loadWindow("28d", "totalMinutes"),
    training_minutes_90d: loadWindow("90d", "totalMinutes"),
    training_workouts_7d: loadWindow("7d", "workouts"),
    training_workouts_28d: loadWindow("28d", "workouts"),
    training_workouts_90d: loadWindow("90d", "workouts"),
    cycling_distance_7d_km: snapshot.activity?.cyclingDistance7DaysKilometers,
    running_distance_7d_km: snapshot.activity?.runningDistance7DaysKilometers
      ?? snapshot.activity?.walkingRunningDistance7DaysKilometers,
    cycling_distance_90d_km: snapshot.activity?.cyclingDistance90DaysKilometers,
    walking_running_distance_28d_km: snapshot.activity?.walkingRunningDistance28DaysKilometers,
    strength_workouts_7d: profile.strengthContinuity?.strengthWorkouts7Days,
    strength_minutes_7d: profile.strengthContinuity?.strengthMinutes7Days,
    recovery_sessions_7d: null,
    recovery_minutes_7d: null,
    steps_7d_avg: snapshot.activity?.averageSteps7Days,
    active_energy_7d_kcal: snapshot.activity?.activeEnergy7DaysKilocalories,
    body_mass_latest_kg: recentBodyMetricValue(snapshot.body?.bodyMassKilograms, snapshot.body?.bodyMassLatestSampleDate),
    body_mass_28d_avg_kg: snapshot.body?.bodyMass28DayAverageKilograms,
    body_mass_change_tracked: snapshot.body?.bodyMassHistory?.change,
    body_mass_weekly_change_rate: snapshot.body?.bodyMassHistory?.weeklyChangeRate,
    body_mass_change_28d: snapshot.body?.bodyMassHistory?.change28Days,
    body_mass_change_90d: snapshot.body?.bodyMassHistory?.change90Days,
    body_mass_change_180d: snapshot.body?.bodyMassHistory?.change180Days,
    body_fat_latest_percentage: recentBodyMetricValue(snapshot.body?.bodyFatPercentage, snapshot.body?.bodyFatLatestSampleDate),
    body_fat_28d_avg_percentage: snapshot.body?.bodyFat28DayAveragePercentage,
    body_fat_change_tracked: snapshot.body?.bodyFatHistory?.change,
    body_fat_weekly_change_rate: snapshot.body?.bodyFatHistory?.weeklyChangeRate,
    body_fat_change_28d: snapshot.body?.bodyFatHistory?.change28Days,
    body_fat_change_90d: snapshot.body?.bodyFatHistory?.change90Days,
    body_fat_change_180d: snapshot.body?.bodyFatHistory?.change180Days,
    vo2_max_latest: snapshot.recovery?.vo2MaxLatest,
    active_weeks: profile.consistency?.activeWeeks,
    longest_active_week_streak: profile.consistency?.longestActiveWeekStreak,
    strength_workouts_90d: profile.strengthContinuity?.strengthWorkouts90Days,
    strength_minutes_90d: profile.strengthContinuity?.strengthMinutes90Days,
  };

  const value = values[metricKey];
  return typeof value === "number" && !Number.isNaN(value) ? value : null;
}

async function createWorkoutDebriefRequest(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string | null,
  plannedWorkoutID: string | null,
  actualWorkoutID: string | null,
) {
  if (!actualWorkoutID) {
    return;
  }

  await throwOnError(
    admin.from("workout_debrief_requests").upsert(
      {
        user_id: userID,
        active_block_id: activeBlockID,
        planned_workout_id: plannedWorkoutID,
        actual_workout_id: actualWorkoutID,
        status: "needed",
        prompt_reason: "completed_workout_detected",
      },
      { onConflict: "user_id,actual_workout_id" },
    ),
  );
  await createPlanEvent(admin, {
    userID,
    activeBlockID,
    plannedWorkoutID,
    eventType: "workout_debrief_requested",
    payload: { actualWorkoutID },
  });
}

async function createGoalReviewProposal(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string,
  reason: string,
) {
  const pending = await list(
    admin
      .from("replan_proposals")
      .select("id,reason,status")
      .eq("user_id", userID)
      .eq("active_block_id", activeBlockID)
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(10),
  );
  if (pending.some((proposal: Record<string, any>) => String(proposal.reason ?? "").includes("goal"))) {
    return;
  }

  await createReplanProposal(admin, {
    userID,
    activeBlockID,
    reason,
    mutations: [],
    metadata: { type: "goal_review" },
  });
}

async function hasUsablePlanWindow(
  admin: SupabaseAdminClient,
  userID: string,
  strategyID: string,
  window: { start: string; end: string },
) {
  const weeklyPlans = await list(
    admin
      .from("weekly_plans")
      .select("id,status")
      .eq("user_id", userID)
      .eq("fitness_strategy_id", strategyID)
      .gte("week_start_date", window.start)
      .lte("week_start_date", window.end)
      .in("status", ["committed", "draft"]),
  );
  const planIDs = weeklyPlans.map((plan: Record<string, any>) => plan.id);
  if (weeklyPlans.length < 2 || planIDs.length === 0) return false;
  const workouts = await list(
    admin
      .from("planned_workouts")
      .select("scheduled_date,status")
      .eq("user_id", userID)
      .in("weekly_plan_id", planIDs)
      .gte("scheduled_date", window.start)
      .lte("scheduled_date", window.end)
      .in("status", ["planned", "current", "checked_in", "adjusted", "done"]),
  );

  if (workouts.length < 4) {
    return false;
  }

  const dates = workouts.map((workout: Record<string, any>) => workout.scheduled_date).sort();
  const lastWorkoutDate = dates[dates.length - 1];
  return lastWorkoutDate >= isoDate(addDays(parseDateOnly(window.end) ?? new Date(), -1));
}

async function hasWeeklyTargetsForPlans(admin: SupabaseAdminClient, userID: string, weeklyPlanIDs: string[]) {
  if (weeklyPlanIDs.length === 0) return false;
  const targets = await list(
    admin
      .from("planning_targets")
      .select("id,weekly_plan_id")
      .eq("user_id", userID)
      .eq("target_scope", "week")
      .in("weekly_plan_id", weeklyPlanIDs),
  );
  const coveredPlans = new Set(targets.map((target: Record<string, any>) => target.weekly_plan_id));
  return weeklyPlanIDs.every((weeklyPlanID) => coveredPlans.has(weeklyPlanID));
}

async function loadWeeklyTargetConstraints(
  admin: SupabaseAdminClient,
  userID: string,
  weeklyPlans: Record<string, any>[],
): Promise<WeeklyTargetConstraint[]> {
  const planIDs = weeklyPlans.map((plan) => plan.id).filter(Boolean);
  if (planIDs.length === 0) return [];

  const planByID = new Map(weeklyPlans.map((plan) => [plan.id, plan]));
  const targets = await list(
    admin
      .from("planning_targets")
      .select("id,weekly_plan_id,title,target_value,unit,metric_key,evaluation_rule_json")
      .eq("user_id", userID)
      .eq("target_scope", "week")
      .in("weekly_plan_id", planIDs),
  );

  return targets
    .map((target: Record<string, any>) => {
      const plan = planByID.get(target.weekly_plan_id);
      const rule = target.evaluation_rule_json ?? {};
      const family = normalizedWeeklyTargetFamily(rule.family) ?? normalizedWeeklyTargetFamily(target.metric_key);
      const targetValue = Number(target.target_value ?? 0);
      if (!plan || !family || !Number.isFinite(targetValue) || targetValue <= 0) return null;
      return {
        id: target.id,
        weeklyPlanID: target.weekly_plan_id,
        weekStartDate: plan.week_start_date,
        weekEndDate: plan.week_end_date,
        title: target.title,
        family,
        modality: weeklyTargetModality(target, rule),
        targetValue,
        unit: target.unit ?? null,
      };
    })
    .filter(Boolean) as WeeklyTargetConstraint[];
}

async function planWindowSatisfiesWeeklyTargets(
  admin: SupabaseAdminClient,
  userID: string,
  weeklyPlans: Record<string, any>[],
) {
  const constraints = await loadWeeklyTargetConstraints(admin, userID, weeklyPlans);
  if (constraints.length === 0) return true;

  const planIDs = weeklyPlans.map((plan) => plan.id).filter(Boolean);
  const workouts = await list(
    admin
      .from("planned_workouts")
      .select("weekly_plan_id,scheduled_date,activity_type,title,duration_minutes,purpose,status")
      .eq("user_id", userID)
      .in("weekly_plan_id", planIDs)
      .not("status", "in", "(deleted,superseded)"),
  );
  const workoutsByPlanID = new Map<string, Record<string, any>[]>();
  for (const workout of workouts) {
    workoutsByPlanID.set(workout.weekly_plan_id, [...(workoutsByPlanID.get(workout.weekly_plan_id) ?? []), workout]);
  }

  return constraints.every((constraint) =>
    plannedConstraintValue(workoutsByPlanID.get(constraint.weeklyPlanID) ?? [], constraint) >= constraint.targetValue
  );
}

function plannedConstraintValue(workouts: Record<string, any>[], constraint: WeeklyTargetConstraint) {
  const activeWorkouts = workouts.filter((workout) => !["deleted", "superseded"].includes(String(workout.status)));
  const modalityWorkouts = constraint.modality
    ? activeWorkouts.filter((workout) => workoutMatchesModality(workout, constraint.modality!))
    : activeWorkouts;

  switch (constraint.family) {
    case "modality_session_count":
    case "support_modality_presence":
      return modalityWorkouts.length;
    case "modality_minutes":
      return modalityWorkouts.reduce((sum, workout) => sum + Number(workout.duration_minutes ?? 0), 0);
    case "active_days":
      return new Set(activeWorkouts.map((workout) => workout.scheduled_date)).size;
    case "minimum_viable_week":
      return constraint.unit === "days" || /day/i.test(constraint.title)
        ? new Set(activeWorkouts.map((workout) => workout.scheduled_date)).size
        : activeWorkouts.length;
    case "planned_session_completion":
      return activeWorkouts.length;
    default:
      return constraint.targetValue;
  }
}

async function createPlanEvent(
  admin: SupabaseAdminClient,
  args: {
    userID: string;
    activeBlockID?: string | null;
    userGoalID?: string | null;
    fitnessStrategyID?: string | null;
    weeklyPlanID?: string | null;
    plannedWorkoutID?: string | null;
    eventType: string;
    payload: Record<string, unknown>;
  },
) {
  return single(
    admin
      .from("plan_events")
      .insert({
        user_id: args.userID,
        active_block_id: args.activeBlockID ?? null,
        user_goal_id: args.userGoalID ?? null,
        fitness_strategy_id: args.fitnessStrategyID ?? null,
        weekly_plan_id: args.weeklyPlanID ?? null,
        planned_workout_id: args.plannedWorkoutID ?? null,
        event_type: args.eventType,
        payload_json: args.payload,
      })
      .select()
      .single(),
    "Could not create plan event",
  );
}

async function createReplanProposal(
  admin: SupabaseAdminClient,
  args: {
    userID: string;
    activeBlockID?: string | null;
    userGoalID?: string | null;
    fitnessStrategyID?: string | null;
    weeklyPlanID?: string | null;
    triggerEventID?: string | null;
    reason: string;
    mutations: Array<Record<string, unknown>>;
    metadata?: Record<string, unknown>;
  },
) {
  await expirePendingReplanProposals(admin, args.userID, args.fitnessStrategyID ?? args.activeBlockID ?? null);

  const insertPayload = {
    user_id: args.userID,
    active_block_id: args.activeBlockID ?? null,
    user_goal_id: args.userGoalID ?? null,
    fitness_strategy_id: args.fitnessStrategyID ?? null,
    weekly_plan_id: args.weeklyPlanID ?? null,
    trigger_event_id: args.triggerEventID ?? null,
    reason: args.reason,
    proposed_mutations_json: args.mutations,
    metadata_json: args.metadata ?? {},
    status: "pending",
  };

  let proposal: Record<string, any>;
  try {
    proposal = await single(
      admin
        .from("replan_proposals")
        .insert(insertPayload)
        .select()
        .single(),
      "Could not create replan proposal",
    );
  } catch (error) {
    if (!isMissingMetadataJSONColumn(error)) throw error;
    const { metadata_json: _metadataJSON, ...legacyPayload } = insertPayload;
    proposal = await single(
      admin
        .from("replan_proposals")
        .insert(legacyPayload)
        .select()
        .single(),
      "Could not create replan proposal",
    );
  }

  await createPlanEvent(admin, {
    userID: args.userID,
    activeBlockID: args.activeBlockID,
    userGoalID: args.userGoalID,
    fitnessStrategyID: args.fitnessStrategyID,
    weeklyPlanID: args.weeklyPlanID,
    eventType: "proposal_created",
    payload: { proposalID: proposal.id, reason: args.reason, ...(args.metadata ?? {}) },
  });

  return proposal;
}

async function expirePendingReplanProposals(
  admin: SupabaseAdminClient,
  userID: string,
  scopeID?: string | null,
  excludeProposalID?: string | null,
) {
  if (!scopeID) return;

  let query = admin
    .from("replan_proposals")
    .update({ status: "expired" })
    .eq("user_id", userID)
    .eq("status", "pending");
  query = query.or(`fitness_strategy_id.eq.${scopeID},active_block_id.eq.${scopeID}`);

  if (excludeProposalID) {
    query = query.neq("id", excludeProposalID);
  }

  await throwOnError(query);
}

async function applyProposalMutations(admin: SupabaseAdminClient, userID: string, proposal: Record<string, any>) {
  const mutations = Array.isArray(proposal.proposed_mutations_json) ? proposal.proposed_mutations_json : [];
  for (const mutation of mutations) {
    if (mutation.type === "update_workout" && mutation.workout_id && mutation.fields) {
      await throwOnError(
        admin
          .from("planned_workouts")
          .update({
            ...mutation.fields,
            version: undefined,
          })
          .eq("id", mutation.workout_id)
          .eq("user_id", userID),
      );
    }

    if (mutation.type === "create_workout" && mutation.fields) {
      await throwOnError(admin.from("planned_workouts").insert({ ...mutation.fields, user_id: userID }));
    }

    if (mutation.type === "delete_workout" && mutation.workout_id) {
      await throwOnError(
        admin
          .from("planned_workouts")
          .update({ status: "deleted", source: "user_deleted", generation_key: null })
          .eq("id", mutation.workout_id)
          .eq("user_id", userID),
      );
    }
  }
}

function validateRequest(value: PlanningAIRequest | null): asserts value is PlanningAIRequest {
  if (!value?.task) {
    throw new Error("Invalid planning AI request");
  }
}

async function insertTrace(
  admin: SupabaseAdminClient,
  trace: {
    userID: string | null;
    task: PlanningTask;
    model: string;
    compactRequest: Record<string, unknown>;
    structuredResponse: Record<string, unknown> | null;
    status: "success" | "failure";
    latencyMS: number;
    errorMessage?: string;
  },
) {
  const { error } = await admin.from("planning_ai_generations").insert({
    user_id: trace.userID,
    task: trace.task,
    model: trace.model,
    compact_request: trace.compactRequest,
    structured_response: trace.structuredResponse,
    status: trace.status,
    latency_ms: trace.latencyMS,
    error_message: trace.errorMessage ?? null,
  });

  if (error) {
    console.error("Failed to insert planning AI trace", error);
  }
}

function compactTraceRequest(requestBody: PlanningAIRequest | null) {
  if (!requestBody) {
    return {};
  }
  return {
    ...requestBody,
    healthSnapshot: summarizeSnapshot(requestBody.healthSnapshot),
    currentDerivedSnapshot: summarizeSnapshot(requestBody.currentDerivedSnapshot ?? requestBody.current_derived_snapshot),
  };
}

function summarizeSnapshot(snapshot: Record<string, unknown> | null | undefined) {
  if (!snapshot) {
    return null;
  }
  return {
    generatedAt: snapshot.generatedAt ?? snapshot.generated_at ?? null,
    workoutLedger: snapshot.workoutLedger ? "present" : null,
    fitnessHistory: snapshot.fitnessHistory ? "present" : null,
    recovery: snapshot.recovery ? "present" : null,
    activity: snapshot.activity ? "present" : null,
  };
}

function blockKind(intent: string) {
  if (intent === "stayConsistent") return "consistency";
  if (intent === "findGoal") return "goal_discovery_chosen";
  return "specific_goal";
}

function compactBlockTitle(
  title: string | undefined,
  goalText: string | undefined,
  rhythms: GeneratedRhythm[],
  kind: string,
) {
  const candidate = title?.trim() ?? "";
  const lower = candidate.toLowerCase();
  if (
    candidate.length > 0 &&
    candidate.length <= 32 &&
    !/\b\d+\s*x\b/.test(lower) &&
    !lower.includes("sessions") &&
    !lower.includes("plus")
  ) {
    return titleCase(candidate);
  }

  const sourceText = `${candidate} ${goalText ?? ""} ${rhythms.flatMap((rhythm) =>
    rhythm.workouts.flatMap((workout) => [workout.activityType, workout.title, workout.purpose])
  ).join(" ")}`.toLowerCase();

  const hasStrength = /strength|lift|gym/.test(sourceText);
  const hasRide = /ride|bike|cycling|cyclist|cycle/.test(sourceText);
  const hasRun = /run|runner|running|5k|10k|marathon/.test(sourceText);
  const hasAerobic = /aerobic|zone 2|base|cardio/.test(sourceText) || hasRide || hasRun;

  if (hasAerobic && hasStrength) return "Aerobic Base + Strength";
  if (hasRide) return "Cycling Build";
  if (hasRun) return "Run Base";
  if (hasStrength) return "Strength Consistency";
  if (kind === "consistency") return "Consistency Rhythm";
  if (kind === "goal_discovery_chosen") return "Goal Build";
  return "Active Fitness Block";
}

function fallbackPrescription(title: string, activityType: string, intensity: string) {
  const lower = `${title} ${activityType} ${intensity}`.toLowerCase();
  if (activityType === "strength") {
    return {
      warmup: "8-10 min easy movement and ramp-up sets",
      main: ["Compound lift or machine pattern 3-4 sets", "Support pull/push 3 sets", "Accessory/core 2-3 sets"],
      cooldown: "3-5 min easy mobility",
      successCriteria: "Leave 1-2 reps in reserve and keep form clean.",
    };
  }
  if (activityType === "ride" && /interval|hard|threshold|vo2|power/.test(lower)) {
    return {
      warmup: "12 min easy spin, then 3 x 30 sec fast cadence with 90 sec easy",
      main: [
        "4 x 4 min hard at RPE 8/10 with 4 min easy spin between",
        "Finish with 8-10 min steady Zone 2 if time remains",
      ],
      cooldown: "8-10 min easy spin",
      successCriteria: "Hard reps stay controlled and repeatable; stop one rep early if power or form drops.",
    };
  }
  if (activityType === "ride" && /long|endurance/.test(lower)) {
    return {
      warmup: "10 min easy spin",
      main: ["Ride mostly Zone 2", "Add 3 x 8 min steady tempo only if legs feel good"],
      cooldown: "5-10 min easy spin",
      successCriteria: "Finish with breathing controlled and enough freshness to train again tomorrow.",
    };
  }
  if (activityType === "run" || activityType === "ride") {
    return {
      warmup: "10 min easy",
      main: `${title} at ${intensity}`,
      cooldown: "5-10 min easy",
      successCriteria: "Keep the effort controlled and repeatable.",
    };
  }
  return {
    main: title,
    successCriteria: "Finish feeling better than you started.",
  };
}

function fuelingSummary(activityType: string, intensity: string) {
  if (activityType === "recovery" || activityType === "mobility") return "Normal meal timing; prioritize protein.";
  if (intensity.toLowerCase().includes("zone 2") || activityType === "ride" || activityType === "run") {
    return "Banana + yogurt, 60-90 min before.";
  }
  return "Carbs + protein, 60-120 min before.";
}

function modalityScore(actualType: string, plannedType: string, plannedTitle: string) {
  const actual = normalizeActivity(actualType);
  const planned = normalizeActivity(`${plannedType} ${plannedTitle}`);
  if (actual === planned) return 1;
  return 0;
}

function compareWorkoutMatches(
  candidate: { confidence: number; disparity: WorkoutMatchDisparity | null },
  candidateWorkout: Record<string, any>,
  current: { workout: Record<string, any>; confidence: number; disparity: WorkoutMatchDisparity | null },
) {
  const candidateUserIntent = userAuthoredWorkoutScore(candidateWorkout);
  const currentUserIntent = userAuthoredWorkoutScore(current.workout);
  if (candidateUserIntent !== currentUserIntent) return candidateUserIntent - currentUserIntent;
  if (candidate.confidence !== current.confidence) return candidate.confidence - current.confidence;
  const candidateReasons = candidate.disparity?.reasons.length ?? 0;
  const currentReasons = current.disparity?.reasons.length ?? 0;
  return currentReasons - candidateReasons;
}

function userAuthoredWorkoutScore(workout: Record<string, any>) {
  const source = String(workout.source ?? "");
  if (source.startsWith("user_")) return 2;
  if (source === "checkin_adjusted") return 1;
  return 0;
}

function durationScore(actual: number, planned: number) {
  const delta = Math.abs(actual - planned);
  if (delta <= 10) return 1;
  if (delta <= 20) return 0.75;
  if (delta <= Math.max(30, planned * 0.5)) return 0.45;
  return 0;
}

function workoutMatchScore(actual: ActualWorkoutInput, workout: Record<string, any>) {
  const plannedText = `${workout.activity_type ?? ""} ${workout.title ?? ""} ${workout.purpose ?? ""} ${workout.intensity_label ?? ""}`;
  const modality = modalityScore(actual.activity_type, workout.activity_type, workout.title);
  if (modality !== 1) return null;

  const duration = durationMatchSignal(actual.duration_minutes, Number(workout.duration_minutes ?? 0));
  const intensity = intensityMatchSignal(actual, plannedText);
  const confidence = Number(((modality * 0.5) + (duration.score * 0.3) + (intensity.score * 0.2)).toFixed(2));
  const disparity = workoutMatchDisparity(duration, intensity);
  return { confidence, disparity };
}

function durationMatchSignal(actualMinutes: number, plannedMinutes: number) {
  if (!Number.isFinite(actualMinutes) || !Number.isFinite(plannedMinutes) || plannedMinutes <= 0) {
    return { score: 0.5, significant: false, plannedMinutes, actualMinutes, ratio: 1 };
  }

  const ratio = actualMinutes / plannedMinutes;
  const absoluteDelta = Math.abs(actualMinutes - plannedMinutes);
  const significant = absoluteDelta >= 15 && (ratio <= 0.65 || ratio >= 1.35);
  return {
    score: durationScore(actualMinutes, plannedMinutes),
    significant,
    plannedMinutes,
    actualMinutes,
    ratio: Number(ratio.toFixed(2)),
  };
}

function intensityMatchSignal(actual: ActualWorkoutInput, plannedText: string) {
  const planned = plannedIntensityBucket(plannedText);
  const actualBucket = actualHeartRateIntensityBucket(actual);
  if (!planned || !actualBucket) return { score: 0.8, significant: false, planned, actual: actualBucket };

  const significant = (planned === "low" && actualBucket === "high") || (planned === "high" && actualBucket === "low");
  if (planned === actualBucket) return { score: 1, significant: false, planned, actual: actualBucket };
  return { score: significant ? 0.35 : 0.72, significant, planned, actual: actualBucket };
}

function workoutMatchDisparity(
  duration: ReturnType<typeof durationMatchSignal>,
  intensity: ReturnType<typeof intensityMatchSignal>,
): WorkoutMatchDisparity | null {
  const reasons: string[] = [];
  if (duration.significant) reasons.push("duration");
  if (intensity.significant) reasons.push("intensity");
  if (reasons.length === 0) return null;
  return {
    needsReview: true,
    reasons,
    duration: {
      plannedMinutes: duration.plannedMinutes,
      actualMinutes: duration.actualMinutes,
      ratio: duration.ratio,
      significant: duration.significant,
    },
    intensity: intensity.planned && intensity.actual
      ? {
          planned: intensity.planned,
          actual: intensity.actual,
          significant: intensity.significant,
        }
      : undefined,
  };
}

function plannedIntensityBucket(value: string): "low" | "moderate" | "high" | null {
  const text = value.toLowerCase();
  if (/\b(zone 4|z4|zone 5|z5|threshold|tempo|hard|vo2|interval|quality|race)\b/.test(text)) return "high";
  if (/\b(zone 1|z1|zone 2|z2|easy|low|recovery|aerobic base|endurance)\b/.test(text)) return "low";
  if (/\b(zone 3|z3|moderate|steady)\b/.test(text)) return "moderate";
  return null;
}

function actualHeartRateIntensityBucket(actual: ActualWorkoutInput): "low" | "moderate" | "high" | null {
  const average = finiteNumber(actual.average_heart_rate_bpm);
  const max = finiteNumber(actual.max_heart_rate_bpm);
  const sampleValues = (actual.heart_rate_samples ?? [])
    .map((sample) => finiteNumber(sample?.bpm))
    .filter((value): value is number => typeof value === "number");
  const highSampleShare = sampleValues.length
    ? sampleValues.filter((value) => value >= 160).length / sampleValues.length
    : 0;

  if ((average && average >= 155) || (max && max >= 175) || highSampleShare >= 0.25) return "high";
  if ((average && average <= 135) && (!max || max <= 155) && highSampleShare < 0.1) return "low";
  if (average || max || sampleValues.length) return "moderate";
  return null;
}

function finiteNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function isStrengthLike(activity: string, text: string) {
  return activity === "strength" || /strength|lift|gym|barbell|dumbbell|kettlebell|machine/.test(text.toLowerCase());
}

function trainingProfile(workout: Record<string, any>): TrainingProfile {
  const text = `${workout.activity_type ?? ""} ${workout.title ?? ""} ${workout.purpose ?? ""} ${workout.intensity_label ?? ""}`.toLowerCase();
  const normalizedActivity = normalizeActivity(text);
  const dimensions = new Set<TrainingDimension>();

  if (/strength|lift|lifting|gym|barbell|dumbbell|kettlebell|hiit|crossfit|boulder|climb/.test(text)) {
    dimensions.add("neuromuscular");
  }
  if (/run|ride|bike|cycle|cycling|swim|row|hike|endurance|aerobic|cardio|zone 2|long/.test(text)) {
    dimensions.add("endurance");
  }
  if (/mobility|yoga|pilates|stretch|recover|recovery|easy walk|walk|preparation/.test(text)) {
    dimensions.add("recovery");
  }
  if (/boulder|climb|skill|technique|drill|practice|movement quality|yoga/.test(text)) {
    dimensions.add("skill");
  }
  if (dimensions.size === 0) {
    dimensions.add((workout.duration_minutes ?? 0) >= 45 ? "endurance" : "neuromuscular");
  }

  return {
    normalizedActivity,
    dimensions: Array.from(dimensions),
    load: trainingLoad(workout, text, dimensions),
    impact: trainingImpact(text),
  };
}

function trainingLoad(workout: Record<string, any>, text: string, dimensions: Set<TrainingDimension>): TrainingLoad {
  const duration = Number(workout.duration_minutes ?? 0);
  if (/recovery|mobility|stretch|easy|low|restorative/.test(text) && !/long|quality|hard|heavy|interval|threshold/.test(text)) {
    return "low";
  }
  if (/hard|high|heavy|quality|interval|threshold|tempo|vo2|race|max|test|progression/.test(text)) {
    return "high";
  }
  if (dimensions.has("endurance") && duration >= 75) return "high";
  if (dimensions.has("neuromuscular") && duration >= 60) return "high";
  if (/moderate|zone 2|steady|strength|boulder|climb|swim|ride|run/.test(text) || duration >= 30) return "moderate";
  return "low";
}

function trainingImpact(text: string): TrainingImpact {
  if (/run|plyo|jump|sprint|court|field|hiit/.test(text)) return "high";
  if (/boulder|climb|hike|strength|lift|gym|crossfit/.test(text)) return "medium";
  return "low";
}

function dimensionLabel(dimension: TrainingDimension) {
  switch (dimension) {
    case "neuromuscular":
      return "strength and neuromuscular";
    case "endurance":
      return "endurance";
    case "recovery":
      return "recovery";
    case "skill":
      return "skill";
  }
}

function workoutsForWeek(workouts: Record<string, any>[], weekStart: Date) {
  return workouts.filter((workout) => startOfWeek(parseDateOnly(workout.scheduled_date) ?? new Date()).getTime() === weekStart.getTime());
}

function findRepairDate(weekStart: Date, weekWorkouts: Record<string, any>[], today: Date = weekStart) {
  const minDate = isoDate(today);
  const occupied = new Set(weekWorkouts.map((workout) => workout.scheduled_date));
  const highLoadDates = new Set(
    weekWorkouts
      .filter((workout) => trainingProfile(workout).load === "high")
      .map((workout) => workout.scheduled_date),
  );

  for (let offset = 0; offset < 7; offset += 1) {
    const date = isoDate(addDays(weekStart, offset));
    if (date < minDate) continue;
    if (occupied.has(date)) continue;
    const adjacentHigh = [-1, 1].some((delta) => highLoadDates.has(isoDate(addDays(weekStart, offset + delta))));
    if (!adjacentHigh) return date;
  }

  for (let offset = 0; offset < 7; offset += 1) {
    const date = isoDate(addDays(weekStart, offset));
    if (date < minDate) continue;
    if (!occupied.has(date)) return date;
  }

  const candidateDates = Array.from({ length: 7 }, (_, offset) => isoDate(addDays(weekStart, offset)))
    .filter((date) => date >= minDate)
    .sort((a, b) => workoutsOnDate(weekWorkouts, a) - workoutsOnDate(weekWorkouts, b));
  const lowerLoadDate = candidateDates.find((date) => {
    const adjacentHigh = [-1, 1].some((delta) => highLoadDates.has(isoDate(addDays(parseDateOnly(date) ?? weekStart, delta))));
    return !adjacentHigh;
  });
  if (lowerLoadDate) return lowerLoadDate;

  if (candidateDates.length > 0) return candidateDates[0];
  return null;
}

function workoutsOnDate(workouts: Record<string, any>[], date: string) {
  return workouts.filter((workout) => workout.scheduled_date === date).length;
}

function nextSequenceOrderForDate(workouts: Record<string, any>[], date: string) {
  const sameDay = workouts.filter((workout) => workout.scheduled_date === date);
  return sameDay.reduce((max, workout) => Math.max(max, Number(workout.sequence_order ?? 0)), 0) + 1;
}

function repairSummaryForMutation(mutation: Record<string, unknown>) {
  if (mutation.type === "create_workout") {
    const fields = mutation.fields as Record<string, unknown> | undefined;
    return `I recommend adding ${fields?.title ?? "a lower-dose support session"} so the week still supports the block.`;
  }
  if (mutation.type === "update_workout") {
    const fields = mutation.fields as Record<string, unknown> | undefined;
    if (fields?.scheduled_date) return `I recommend moving one surrounding session to ${fields.scheduled_date} to restore spacing.`;
    return "I recommend lowering one surrounding session so the week stays recoverable.";
  }
  return "I recommend a small repair so the edit does not pull the week away from the block.";
}

function compactWorkoutForRepair(workout: Record<string, any>) {
  return {
    id: workout.id,
    date: workout.scheduled_date,
    title: workout.title,
    activityType: workout.activity_type,
    durationMinutes: workout.duration_minutes,
    intensity: workout.intensity_label,
    purpose: workout.purpose,
    status: workout.status,
    profile: trainingProfile(workout),
  };
}

function normalizeActivity(value: string) {
  const lower = value.toLowerCase();
  if (/\b(cycling|cycle|bike|biking|ride|rides|riding|indoor cycling)\b/.test(lower) || lower.includes("cycl")) return "ride";
  if (/\b(run|runs|running)\b/.test(lower)) return "run";
  if (/\b(swim|swims|swimming)\b/.test(lower)) return "swim";
  if (/\b(walk|walks|walking)\b/.test(lower)) return "walk";
  if (/\b(hike|hikes|hiking)\b/.test(lower)) return "hike";
  if (/\b(climb|climbs|climbing|boulder|bouldering)\b/.test(lower)) return "climb";
  if (/\b(strength|traditional|functional strength|lift|lifting|gym|weights?)\b/.test(lower)) return "strength";
  if (/\b(mobility|yoga|stretch|stretching|pilates)\b/.test(lower)) return "mobility";
  if (/\b(recover|recovery|restorative)\b/.test(lower)) return "recovery";
  if (/\b(row|rows|rowing|rower)\b/.test(lower)) return "row";
  return lower.replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "") || "workout";
}

function checkInSuggestsAdjustment(requestBody: PlanningAIRequest) {
  const energy = requestBody.mood?.energy;
  if (typeof energy === "number" && energy <= 0.25) return true;
  const text = requestBody.textContext?.toLowerCase() ?? "";
  return ["tired", "exhausted", "sick", "pain", "stressed", "don’t feel", "don't feel"].some((term) => text.includes(term));
}

function expectedProgressRatio(startDate: string | null | undefined, targetDate: string | null | undefined) {
  const start = parseDateOnly(startDate);
  const target = parseDateOnly(targetDate);
  if (!start || !target) {
    return 0.5;
  }

  const totalDays = Math.max(1, daysBetween(start, target));
  const elapsedDays = Math.max(0, daysBetween(start, new Date()));
  return Math.max(0.1, Math.min(1, elapsedDays / totalDays));
}

function extractFirstNumber(value: string) {
  const match = value.match(/(\d+(?:[.,]\d+)?)/);
  return match ? Number(match[1].replace(",", ".")) : null;
}

function snapshotGeneratedAt(snapshot: Record<string, unknown>) {
  const value = snapshot.generatedAt ?? snapshot.generated_at;
  return typeof value === "string" ? value : new Date().toISOString();
}

function healthFreshness(snapshot: Record<string, any> | null) {
  if (!snapshot) {
    return { status: "missing", ageHours: null };
  }

  const generatedAt = snapshot.generated_at ?? snapshot.generatedAt ?? snapshot.snapshot_json?.generatedAt;
  const parsed = typeof generatedAt === "string" ? new Date(generatedAt) : null;
  if (!parsed || Number.isNaN(parsed.getTime())) {
    return { status: "unknown", ageHours: null };
  }

  const ageHours = Math.max(0, Math.round((Date.now() - parsed.getTime()) / 3_600_000));
  return { status: ageHours <= 36 ? "fresh" : "stale", ageHours };
}

function twoWeekWindow(start: Date) {
  const weekStart = startOfWeek(start);
  return { start: isoDate(weekStart), end: isoDate(addDays(weekStart, 13)) };
}

function startOfWeek(date: Date) {
  const copy = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = copy.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  copy.setUTCDate(copy.getUTCDate() + diff);
  return copy;
}

function addDays(date: Date, days: number) {
  const copy = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function daysBetween(start: Date, end: Date) {
  return Math.max(1, Math.round((end.getTime() - start.getTime()) / 86_400_000));
}

function signedCalendarDaysBetween(start: Date, end: Date) {
  const startDate = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()));
  const endDate = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate()));
  return Math.round((endDate.getTime() - startDate.getTime()) / 86_400_000);
}

function absoluteCalendarDaysBetween(start: Date, end: Date) {
  return Math.abs(signedCalendarDaysBetween(start, end));
}

function parseDateOnly(value: string | null | undefined) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function isoDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

function todayInTimezone(timezone: string) {
  try {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(new Date());
    const year = parts.find((part) => part.type === "year")?.value;
    const month = parts.find((part) => part.type === "month")?.value;
    const day = parts.find((part) => part.type === "day")?.value;
    return parseDateOnly(year && month && day ? `${year}-${month}-${day}` : null) ?? new Date();
  } catch {
    return new Date();
  }
}

function titleCase(value: string) {
  return value.replace(/[_-]+/g, " ").replace(/\w\S*/g, (part) => part[0].toUpperCase() + part.slice(1).toLowerCase());
}

function isSundayEveningInTimezone(timezone: string) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    weekday: "short",
    hour: "numeric",
    hour12: false,
  }).formatToParts(new Date());
  const weekday = parts.find((part) => part.type === "weekday")?.value;
  const hour = Number(parts.find((part) => part.type === "hour")?.value);
  return weekday === "Sun" && hour >= 21;
}

async function maybeSingle(builder: any) {
  const { data, error } = await builder;
  if (error) {
    const code = error.code as string | undefined;
    if (code === "PGRST116") return null;
    throw error;
  }
  return Array.isArray(data) ? data[0] ?? null : data;
}

async function single(builder: any, message: string) {
  const { data, error } = await builder;
  if (error) throw error;
  if (!data) throw new Error(message);
  if (Array.isArray(data)) {
    const first = data[0];
    if (!first) throw new Error(message);
    return first;
  }
  return data;
}

async function list(builder: any) {
  const { data, error } = await builder;
  if (error) throw error;
  return data ?? [];
}

async function throwOnError(builder: any) {
  const { error } = await builder;
  if (error) throw error;
}

function extractOutputText(payload: Record<string, any>) {
  if (typeof payload.output_text === "string") {
    return payload.output_text;
  }

  for (const output of payload.output ?? []) {
    for (const content of output.content ?? []) {
      if (content.type === "output_text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }

  return null;
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function responsesRequestPayload(
  model: string,
  touchpointConfig: AITouchpointConfig,
  userContent: Record<string, unknown>,
  format: Record<string, unknown>,
) {
  const payload: Record<string, unknown> = {
    ...(touchpointConfig.parameters ?? {}),
    model,
    input: [
      {
        role: "system",
        content: touchpointConfig.systemPrompt,
      },
      {
        role: "user",
        content: JSON.stringify(userContent),
      },
    ],
    text: {
      ...(touchpointConfig.text ?? {}),
      format,
    },
  };
  if (touchpointConfig.reasoning) {
    payload.reasoning = touchpointConfig.reasoning;
  }
  return payload;
}

function mustGetEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing ${name}`);
  }
  return value;
}

function errorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (error && typeof error === "object") {
    const maybeMessage = (error as Record<string, unknown>).message ?? (error as Record<string, unknown>).error_description;
    if (typeof maybeMessage === "string" && maybeMessage.trim()) {
      return maybeMessage;
    }
    try {
      return JSON.stringify(error);
    } catch {
      return "Unknown error";
    }
  }
  return "Unknown error";
}
