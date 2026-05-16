import { createClient } from "jsr:@supabase/supabase-js@2";

type SupabaseAdminClient = any;

type PlanningTask =
  | "bootstrap_after_onboarding"
  | "sync_healthkit_and_reconcile"
  | "refresh_plan_window"
  | "record_plan_edit"
  | "recommend_workout_replacements"
  | "recommend_workout_additions"
  | "interpret_workout_description"
  | "replace_workout"
  | "add_workout"
  | "create_repair_proposal_for_recent_edit"
  | "apply_replan_proposal"
  | "check_in_to_workout"
  | "scheduled_refresh_due_windows";

type PlanningAIRequest = {
  task: PlanningTask;
  healthSnapshot?: Record<string, unknown> | null;
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

type ActualWorkoutInput = {
  healthkit_uuid: string;
  start_date: string;
  activity_type: string;
  duration_minutes: number;
  distance_kilometers?: number | null;
  energy_kilocalories?: number | null;
  load_value?: number | null;
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

type WorkoutCandidateInput = {
  title: string;
  activityType: string;
  durationMinutes: number;
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

const editRepairSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["reason", "summary"],
  properties: {
    reason: { type: "string" },
    summary: { type: "string" },
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
          rationale: { type: "string" },
          weeklyImpact: { type: "string" },
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
        rationale: { type: "string" },
        weeklyImpact: { type: "string" },
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
  const model = Deno.env.get("OPENAI_MODEL") || "gpt-5-mini";

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
  const { admin, requestBody, userID, model } = args;

  switch (requestBody.task) {
    case "bootstrap_after_onboarding":
      return bootstrapAfterOnboarding(admin, userID!, requestBody, model);
    case "sync_healthkit_and_reconcile":
      return syncHealthKitAndReconcile(admin, userID!, requestBody, model);
    case "refresh_plan_window":
      return refreshPlanWindow(admin, userID!, requestBody, model, "user");
    case "record_plan_edit":
      return recordPlanEdit(admin, userID!, requestBody, model);
    case "recommend_workout_replacements":
      return recommendWorkoutReplacements(admin, userID!, requestBody, model);
    case "recommend_workout_additions":
      return recommendWorkoutAdditions(admin, userID!, requestBody, model);
    case "interpret_workout_description":
      return interpretWorkoutDescription(admin, userID!, requestBody, model);
    case "replace_workout":
      return replaceWorkout(admin, userID!, requestBody, model);
    case "add_workout":
      return addWorkout(admin, userID!, requestBody, model);
    case "create_repair_proposal_for_recent_edit":
      return createRepairProposalForRecentEdit(admin, userID!, requestBody, model);
    case "apply_replan_proposal":
      return applyReplanProposal(admin, userID!, requestBody);
    case "check_in_to_workout":
      return checkInToWorkout(admin, userID!, requestBody);
    case "scheduled_refresh_due_windows":
      return scheduledRefreshDueWindows(admin, model);
    default:
      throw new Error(`Unsupported planning AI task: ${requestBody.task}`);
  }
}

async function bootstrapAfterOnboarding(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const profile = await maybeSingle(admin.from("profiles").select().eq("id", userID));
  const onboarding = await single(
    admin.from("onboarding_profiles").select().eq("id", userID).single(),
    "Completed onboarding profile not found",
  );

  const timezone = requestBody.deviceTimezone || "UTC";
  const start = parseDateOnly(requestBody.startDate) ?? new Date();
  const context = {
    profile,
    onboarding,
    healthSnapshot: requestBody.healthSnapshot ?? null,
    deviceTimezone: timezone,
    startDate: isoDate(start),
  };

  let generated: GeneratedPlan;
  let usedFallback = false;
  try {
    generated = sanitizeGeneratedPlan(await runPlanGeneration("bootstrap_after_onboarding", context, model), onboarding, start, timezone);
  } catch (error) {
    usedFallback = true;
    await insertTrace(admin, {
      userID,
      task: "bootstrap_after_onboarding",
      model,
      compactRequest: { task: "bootstrap_after_onboarding", context },
      structuredResponse: null,
      status: "failure",
      latencyMS: 0,
      errorMessage: errorMessage(error),
    });
    generated = fallbackPlan(onboarding, start, timezone);
  }

  await archiveActiveBlocks(admin, userID);

  const block = await single(
    admin
      .from("active_fitness_blocks")
      .insert({
        user_id: userID,
        kind: generated.block.kind,
        title: generated.block.title,
        goal_text: generated.block.goalText || null,
        status: "active",
        start_date: generated.block.startDate,
        target_date: generated.block.targetDate,
        review_cadence_days: generated.block.reviewCadenceDays,
        timezone,
        source_onboarding_profile_id: onboarding.id,
        context_json: generated.block.context,
      })
      .select()
      .single(),
    "Could not create active fitness block",
  );

  if (generated.phases.length > 0) {
    await throwOnError(
      admin.from("fitness_block_phases").insert(
        generated.phases.map((phase) => ({
          active_block_id: block.id,
          user_id: userID,
          name: phase.name,
          start_date: phase.startDate,
          end_date: phase.endDate,
          objective: phase.objective,
          focus_json: phase.focus,
          risk_json: phase.risk,
        })),
      ),
    );
  }

  await insertRhythmsAndWorkouts(admin, userID, block.id, generated.rhythms, "generated");
  await markCurrentWorkout(admin, userID, block.id, start);
  if (requestBody.healthSnapshot) {
    await persistFitnessEvidence(admin, userID, block.id, requestBody.healthSnapshot);
    await createInitialGoalTargets(admin, userID, block, requestBody.healthSnapshot);
    await evaluateGoalTargets(admin, userID, block, requestBody.healthSnapshot);
  }
  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: block.id,
    eventType: "bootstrapped",
    payload: { usedFallback, blockKind: generated.block.kind },
  });

  return {
    userID,
    model: usedFallback ? "deterministic-fallback" : model,
    usedFallback,
    activeBlockID: block.id,
    eventID: event.id,
    plan: generated,
  };
}

async function syncHealthKitAndReconcile(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
) {
  const block = await loadActiveBlock(admin, userID);
  const timezone = requestBody.deviceTimezone || block.timezone || "UTC";

  if (requestBody.healthSnapshot) {
    await throwOnError(
      admin.from("health_feature_snapshots").insert({
        user_id: userID,
        generated_at: snapshotGeneratedAt(requestBody.healthSnapshot),
        snapshot_json: requestBody.healthSnapshot,
        source_timezone: timezone,
      }),
    );
    await persistFitnessEvidence(admin, userID, block.id, requestBody.healthSnapshot);
  }

  let synced = 0;
  let matched = 0;
  let detected = 0;
  const detectedEvents: Array<{ eventID: string; plannedWorkoutID: string; actual: ActualWorkoutInput }> = [];
  const workouts = requestBody.actualWorkouts ?? [];
  for (const actual of workouts) {
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
          },
          { onConflict: "user_id,healthkit_uuid" },
        )
        .select()
        .single(),
      "Could not upsert actual workout",
    );
    synced += 1;

    if (upserted.matched_planned_workout_id) {
      continue;
    }

    const match = await findWorkoutMatch(admin, userID, block.id, actual);
    if (match) {
      await throwOnError(
        admin
          .from("actual_workouts")
          .update({ matched_planned_workout_id: match.workout.id, match_confidence: match.confidence })
          .eq("id", upserted.id),
      );
      await throwOnError(admin.from("planned_workouts").update({ status: "done" }).eq("id", match.workout.id));
      await createPlanEvent(admin, {
        userID,
        activeBlockID: block.id,
        plannedWorkoutID: match.workout.id,
        eventType: "actual_matched",
        payload: { actual, confidence: match.confidence },
      });
      await createWorkoutDebriefRequest(admin, userID, block.id, match.workout.id, upserted.id);
      matched += 1;
    } else {
      const inserted = await insertDetectedWorkout(admin, userID, block.id, actual);
      await throwOnError(
        admin
          .from("actual_workouts")
          .update({ matched_planned_workout_id: inserted.id, match_confidence: 1 })
          .eq("id", upserted.id),
      );
      const event = await createPlanEvent(admin, {
        userID,
        activeBlockID: block.id,
        plannedWorkoutID: inserted.id,
        eventType: "extra_workout_detected",
        payload: { actual },
      });
      await createWorkoutDebriefRequest(admin, userID, block.id, inserted.id, upserted.id);
      detectedEvents.push({ eventID: event.id, plannedWorkoutID: inserted.id, actual });
      detected += 1;
    }
  }

  const missedWorkouts = await markMissedWorkouts(admin, userID, block.id, requestBody.syncWindow?.endDate);

  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: block.id,
    eventType: "actual_synced",
    payload: {
      synced,
      matched,
      detected,
      missed: missedWorkouts.length,
      missedWorkoutIDs: missedWorkouts.map((workout: Record<string, any>) => workout.id),
      syncWindow: requestBody.syncWindow ?? null,
    },
  });

  if (detectedEvents.length > 0) {
    await createReplanProposal(admin, {
      userID,
      activeBlockID: block.id,
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
    await markCurrentWorkout(admin, userID, block.id, new Date());
  }

  if (requestBody.healthSnapshot) {
    await createInitialGoalTargets(admin, userID, block, requestBody.healthSnapshot);
    await evaluateGoalTargets(admin, userID, block, requestBody.healthSnapshot);
  }

  return { userID, eventID: event.id, synced, matched, detected, missed: missedWorkouts.length, refreshOutput };
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

async function refreshPlanWindowForUser(
  admin: SupabaseAdminClient,
  userID: string,
  windowStart: string | undefined,
  model: string,
  trigger: "user" | "scheduled",
  force = false,
) {
  const block = await loadActiveBlock(admin, userID);
  const start = parseDateOnly(windowStart) ?? new Date();
  const window = twoWeekWindow(start);
  if (!force && trigger === "user" && await hasUsablePlanWindow(admin, userID, block.id, window)) {
    const event = await createPlanEvent(admin, {
      userID,
      activeBlockID: block.id,
      eventType: "window_refreshed",
      payload: { trigger, skipped: true, reason: "visible_two_week_window_already_exists", window },
    });

    return {
      userID,
      model: "deterministic",
      skipped: true,
      activeBlockID: block.id,
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
      .eq("active_block_id", block.id)
      .order("created_at", { ascending: false })
      .limit(30),
  );
  const proposals = await list(
    admin
      .from("replan_proposals")
      .select()
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .in("status", ["pending", "accepted"])
      .order("created_at", { ascending: false })
      .limit(10),
  );
  const context = { block, latestSnapshot, events, proposals, windowStart: isoDate(start), trigger, force };
  const healthDataFreshness = healthFreshness(latestSnapshot);

  let generated: GeneratedPlan;
  let usedFallback = false;
  try {
    generated = sanitizeGeneratedPlan(await runPlanGeneration("refresh_plan_window", context, model), null, start, block.timezone ?? "UTC");
  } catch (error) {
    usedFallback = true;
    await insertTrace(admin, {
      userID,
      task: "refresh_plan_window",
      model,
      compactRequest: { task: "refresh_plan_window", context },
      structuredResponse: null,
      status: "failure",
      latencyMS: 0,
      errorMessage: errorMessage(error),
    });
    generated = fallbackPlanFromBlock(block, start);
  }

  await throwOnError(
    admin
      .from("planned_workouts")
      .update({ status: "superseded" })
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .gte("scheduled_date", window.start)
      .lte("scheduled_date", window.end)
      .in("status", ["planned", "current"])
      .in("source", ["generated", "replanned"]),
  );

  await insertRhythmsAndWorkouts(admin, userID, block.id, generated.rhythms, "replanned", isoDate(start));
  await markCurrentWorkout(admin, userID, block.id, start);
  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: block.id,
    eventType: "window_refreshed",
    payload: { trigger, usedFallback, window, healthDataFreshness },
  });

  return {
    userID,
    model: usedFallback ? "deterministic-fallback" : model,
    usedFallback,
    activeBlockID: block.id,
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

  const block = await loadActiveBlock(admin, userID);
  const edit = requestBody.edit;
  if (edit.type !== "move_workout" && edit.type !== "delete_workout") {
    throw new Error("record_plan_edit only supports move and delete edits");
  }
  const workout = await single(
    admin
      .from("planned_workouts")
      .select()
      .eq("id", edit.planned_workout_id)
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .single(),
    "Planned workout not found",
  );

  let event: Record<string, any>;
  if (edit.type === "move_workout") {
    await throwOnError(
      admin
        .from("planned_workouts")
        .update({
          scheduled_date: edit.scheduled_date,
          sequence_order: edit.sequence_order ?? workout.sequence_order,
          source: "user_moved",
          version: (workout.version ?? 1) + 1,
        })
        .eq("id", workout.id),
    );
    event = await createPlanEvent(admin, {
      userID,
      activeBlockID: block.id,
      plannedWorkoutID: workout.id,
      eventType: "workout_moved",
      payload: { from: workout.scheduled_date, to: edit.scheduled_date },
    });
  } else if (edit.type === "delete_workout") {
    await throwOnError(
      admin
        .from("planned_workouts")
        .update({ status: "deleted", source: "user_deleted", version: (workout.version ?? 1) + 1 })
        .eq("id", workout.id),
    );
    event = await createPlanEvent(admin, {
      userID,
      activeBlockID: block.id,
      plannedWorkoutID: workout.id,
      eventType: "workout_deleted",
      payload: { deletedWorkout: workout },
    });
  } else {
    throw new Error("record_plan_edit does not support replacement edits directly");
  }

  const repairPolicy = requestedRepairPolicy(requestBody);
  const repair = repairPolicy === "deferred"
    ? await buildPlanEditReviewHint(admin, userID, block, workout, edit, requestBody.deviceTimezone || block.timezone || "UTC")
    : await buildPlanEditRepair(admin, userID, block, workout, edit, model, requestBody.deviceTimezone || block.timezone || "UTC");
  const proposal = repair && repairPolicy === "immediate"
    ? await createPlanEditRepairProposal(admin, userID, block.id, event.id, repair)
    : null;
  if (!proposal || repairPolicy === "deferred") {
    await expirePendingReplanProposals(admin, userID, block.id);
  }
  await markCurrentWorkout(admin, userID, block.id, new Date());
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

async function buildPlanEditRepair(
  admin: SupabaseAdminClient,
  userID: string,
  block: Record<string, any>,
  editedWorkout: Record<string, any>,
  edit: PlanEditInput,
  model: string,
  timezone: string,
): Promise<EditRepairPlan | null> {
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

  const [workouts, rhythms, goalTargets] = await Promise.all([
    list(
      admin
        .from("planned_workouts")
        .select()
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .gte("scheduled_date", window.start)
        .lte("scheduled_date", window.end)
        .in("status", ["planned", "current", "checked_in", "adjusted", "done"])
        .order("scheduled_date", { ascending: true })
        .order("sequence_order", { ascending: true }),
    ),
    list(
      admin
        .from("weekly_rhythms")
        .select()
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .eq("status", "active")
        .gte("week_start_date", window.start)
        .lte("week_start_date", window.end),
    ),
    list(
      admin
        .from("fitness_goal_targets")
        .select("id,target_kind,title,description,metric_key,metric_category,evaluation_rule_json,status")
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .in("status", ["on_track", "lagging", "needs_review"]),
    ),
  ]);

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
  block: Record<string, any>,
  editedWorkout: Record<string, any>,
  edit: PlanEditInput,
  timezone: string,
): Promise<EditRepairPlan | null> {
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

  const [workouts, rhythms, goalTargets] = await Promise.all([
    list(
      admin
        .from("planned_workouts")
        .select()
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .gte("scheduled_date", window.start)
        .lte("scheduled_date", window.end)
        .in("status", ["planned", "current", "checked_in", "adjusted", "done"])
        .order("scheduled_date", { ascending: true })
        .order("sequence_order", { ascending: true }),
    ),
    list(
      admin
        .from("weekly_rhythms")
        .select()
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .eq("status", "active")
        .gte("week_start_date", window.start)
        .lte("week_start_date", window.end),
    ),
    list(
      admin
        .from("fitness_goal_targets")
        .select("id,target_kind,title,description,metric_key,metric_category,evaluation_rule_json,status")
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .in("status", ["on_track", "lagging", "needs_review"]),
    ),
  ]);

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
  activeBlockID: string,
  triggerEventID: string,
  repair: EditRepairPlan,
) {
  return createReplanProposal(admin, {
    userID,
    activeBlockID,
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
      active_block_id: block.id,
      weekly_rhythm_id: rhythm?.id ?? sourceWorkout.weekly_rhythm_id ?? null,
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
  if (dimension === "neuromuscular") return "Strength support";
  if (dimension === "endurance") return "Endurance support";
  if (dimension === "recovery") return "Recovery support";
  return sourceWorkout.title ? `${sourceWorkout.title} support` : "Skill support";
}

async function runEditRepairDraft(context: Record<string, unknown>, model: string): Promise<PlanEditRepairDraft> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content:
            "You are HAYF's plan-edit coach. Explain why a user's already-applied plan edit may affect recovery, load balance, or training targets. Be matter-of-fact, specific, and concise. Do not shame the user. Return strict JSON only.",
        },
        {
          role: "user",
          content: JSON.stringify({
            task: "draft_plan_edit_repair",
            context,
            rules:
              "Return one reason sentence and one summary sentence for the proposed repair. The user edit has already been applied; frame the repair as a recommendation, not a command.",
          }),
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "plan_edit_repair",
          strict: true,
          schema: editRepairSchema,
        },
      },
    }),
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

  const block = await loadActiveBlock(admin, userID);
  const workout = await loadPlannedWorkout(admin, userID, block.id, plannedWorkoutID);
  const window = twoWeekWindow(parseDateOnly(workout.scheduled_date) ?? new Date());
  const surroundingWorkouts = await list(
    admin
      .from("planned_workouts")
      .select()
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .gte("scheduled_date", window.start)
      .lte("scheduled_date", window.end)
      .not("status", "in", "(deleted,superseded)")
      .order("scheduled_date", { ascending: true })
      .order("sequence_order", { ascending: true }),
  );
  const phases = await list(
    admin
      .from("fitness_block_phases")
      .select()
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .order("start_date", { ascending: true }),
  );
  const weeklyRhythms = await list(
    admin
      .from("weekly_rhythms")
      .select()
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .gte("week_start_date", window.start)
      .lte("week_start_date", window.end)
      .order("week_start_date", { ascending: true }),
  );

  const context = {
    block,
    workoutToReplace: workout,
    surroundingWorkouts,
    phases,
    weeklyRhythms,
    userIntent: requestBody.textContext || "I do not want to do this workout in this slot.",
    window,
  };

  let candidates: ReplacementCandidate[];
  let usedFallback = false;
  try {
    candidates = sanitizeReplacementCandidates(await runReplacementGeneration(context, model), workout);
  } catch (error) {
    usedFallback = true;
    candidates = fallbackReplacementCandidates(workout, surroundingWorkouts);
    await insertTrace(admin, {
      userID,
      task: "recommend_workout_replacements",
      model,
      compactRequest: { task: "recommend_workout_replacements", context },
      structuredResponse: null,
      status: "failure",
      latencyMS: 0,
      errorMessage: errorMessage(error),
    });
  }

  return {
    userID,
    model: usedFallback ? "deterministic-fallback" : model,
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

  const block = await loadActiveBlock(admin, userID);
  throwIfPastPlanningDate(scheduledDate, block.timezone || "UTC");
  const context = await loadWorkoutPlanningContext(admin, userID, block, scheduledDate);

  let candidates: WorkoutCandidate[];
  let usedFallback = false;
  try {
    candidates = sanitizeWorkoutCandidates(
      await runWorkoutAdditionGeneration(
        {
          ...context,
          userIntent: requestBody.textContext || "I feel like working out on this day, but I want HAYF to pick something that fits the plan.",
        },
        model,
      ),
      fallbackAdditionCandidates(context),
    );
  } catch (error) {
    usedFallback = true;
    candidates = fallbackAdditionCandidates(context);
    await insertTrace(admin, {
      userID,
      task: "recommend_workout_additions",
      model,
      compactRequest: { task: "recommend_workout_additions", context },
      structuredResponse: null,
      status: "failure",
      latencyMS: 0,
      errorMessage: errorMessage(error),
    });
  }

  return {
    userID,
    model: usedFallback ? "deterministic-fallback" : model,
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

  const block = await loadActiveBlock(admin, userID);
  const plannedWorkoutID = requestBody.plannedWorkoutID ?? requestBody.planned_workout_id;
  const scheduledDate = requestBody.scheduledDate ?? requestBody.scheduled_date;
  let workout: Record<string, any> | null = null;
  let contextDate = scheduledDate;

  if (plannedWorkoutID) {
    const loadedWorkout = await loadPlannedWorkout(admin, userID, block.id, plannedWorkoutID);
    workout = loadedWorkout;
    contextDate = loadedWorkout.scheduled_date;
  }
  if (!contextDate) {
    throw new Error("interpret_workout_description requires plannedWorkoutID or scheduledDate");
  }

  throwIfPastPlanningDate(contextDate, block.timezone || "UTC");
  const planningContext = await loadWorkoutPlanningContext(admin, userID, block, contextDate);
  const context = {
    ...planningContext,
    workoutToReplace: workout,
    userIntent: textContext,
  };

  let candidate: WorkoutCandidate;
  let usedFallback = false;
  try {
    candidate = sanitizeWorkoutCandidate(
      (await runWorkoutDescriptionInterpretation(context, model)).candidate,
      fallbackManualWorkoutCandidate(textContext, workout ?? undefined, contextDate),
      "candidate-1",
    );
  } catch (error) {
    usedFallback = true;
    candidate = fallbackManualWorkoutCandidate(textContext, workout ?? undefined, contextDate);
    await insertTrace(admin, {
      userID,
      task: "interpret_workout_description",
      model,
      compactRequest: { task: "interpret_workout_description", context },
      structuredResponse: null,
      status: "failure",
      latencyMS: 0,
      errorMessage: errorMessage(error),
    });
  }

  return {
    userID,
    model: usedFallback ? "deterministic-fallback" : model,
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

  const block = await loadActiveBlock(admin, userID);
  const workout = await loadPlannedWorkout(admin, userID, block.id, plannedWorkoutID);
  const status = workout.status === "current" ? "current" : "planned";

  await throwOnError(
    admin
      .from("planned_workouts")
      .update({
        status: "superseded",
        source: workout.source,
        version: (workout.version ?? 1) + 1,
      })
      .eq("id", workout.id),
  );

  const replacement = await single(
    admin
      .from("planned_workouts")
      .insert({
        active_block_id: workout.active_block_id,
        weekly_rhythm_id: workout.weekly_rhythm_id,
        user_id: userID,
        scheduled_date: workout.scheduled_date,
        sequence_order: workout.sequence_order,
        activity_type: normalizeActivity(candidate.activityType),
        title: candidate.title,
        duration_minutes: Math.max(10, candidate.durationMinutes || workout.duration_minutes || 30),
        intensity_label: candidate.intensityLabel || workout.intensity_label || "Moderate",
        purpose: candidate.purpose || workout.purpose || "Replacement workout",
        status,
        source: "replanned",
        prescription_json: {
          ...(candidate.prescription ?? {}),
          replacementForWorkoutID: workout.id,
          rationale: candidate.rationale ?? null,
          weeklyImpact: candidate.weeklyImpact ?? null,
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
    activeBlockID: block.id,
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
    ? await buildPlanEditReviewHint(admin, userID, block, workout, edit, requestBody.deviceTimezone || block.timezone || "UTC")
    : await buildPlanEditRepair(admin, userID, block, workout, edit, model, requestBody.deviceTimezone || block.timezone || "UTC");
  const proposal = repair && repairPolicy === "immediate"
    ? await createPlanEditRepairProposal(admin, userID, block.id, event.id, repair)
    : null;
  if (!proposal || repairPolicy === "deferred") {
    await expirePendingReplanProposals(admin, userID, block.id);
  }
  await markCurrentWorkout(admin, userID, block.id, new Date());
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

  const block = await loadActiveBlock(admin, userID);
  throwIfPastPlanningDate(scheduledDate, block.timezone || "UTC");
  const context = await loadWorkoutPlanningContext(admin, userID, block, scheduledDate);
  const candidate = sanitizeWorkoutCandidate(rawCandidate, fallbackAdditionCandidates(context)[0], "candidate-1");
  const sequenceOrder = requestBody.sequenceOrder ?? requestBody.sequence_order ??
    nextSequenceOrderForDate(context.surroundingWorkouts, scheduledDate);

  const addedWorkout = await single(
    admin
      .from("planned_workouts")
      .insert({
        active_block_id: block.id,
        weekly_rhythm_id: context.weeklyRhythm?.id ?? null,
        user_id: userID,
        scheduled_date: scheduledDate,
        sequence_order: sequenceOrder,
        activity_type: normalizeActivity(candidate.activityType),
        title: candidate.title,
        duration_minutes: Math.max(10, candidate.durationMinutes || 30),
        intensity_label: candidate.intensityLabel || "Moderate",
        purpose: candidate.purpose || "User-added workout",
        status: "planned",
        source: "user_added",
        prescription_json: {
          ...(candidate.prescription ?? {}),
          addedFrom: "plan_day_add",
          rationale: candidate.rationale ?? null,
          weeklyImpact: candidate.weeklyImpact ?? null,
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
    activeBlockID: block.id,
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
    ? await buildPlanEditReviewHint(admin, userID, block, addedWorkout, edit, requestBody.deviceTimezone || block.timezone || "UTC")
    : await buildPlanEditRepair(admin, userID, block, addedWorkout, edit, model, requestBody.deviceTimezone || block.timezone || "UTC");
  const proposal = repair && repairPolicy === "immediate"
    ? await createPlanEditRepairProposal(admin, userID, block.id, event.id, repair)
    : null;
  if (!proposal || repairPolicy === "deferred") {
    await expirePendingReplanProposals(admin, userID, block.id);
  }
  await markCurrentWorkout(admin, userID, block.id, new Date());

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

  await expirePendingReplanProposals(admin, userID, proposal.active_block_id, proposal.id);

  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: proposal.active_block_id,
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

  const block = await loadActiveBlock(admin, userID);
  const event = await single(
    admin
      .from("plan_events")
      .select()
      .eq("id", eventID)
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .single(),
    "Plan edit event not found",
  );

  const payload = event.payload_json ?? {};
  const reconstructed = await reconstructPlanEditFromEvent(admin, userID, block, event, payload);
  const repair = await buildPlanEditRepair(
    admin,
    userID,
    block,
    reconstructed.editedWorkout,
    reconstructed.edit,
    model,
    requestBody.deviceTimezone || block.timezone || "UTC",
  );

  const proposal = repair
    ? await createPlanEditRepairProposal(admin, userID, block.id, event.id, repair)
    : null;
  if (!proposal) {
    await expirePendingReplanProposals(admin, userID, block.id);
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

async function reconstructPlanEditFromEvent(
  admin: SupabaseAdminClient,
  userID: string,
  block: Record<string, any>,
  event: Record<string, any>,
  payload: Record<string, any>,
): Promise<{ editedWorkout: Record<string, any>; edit: PlanEditInput }> {
  if (payload.action === "workout_replaced") {
    const originalWorkoutID = String(payload.originalWorkoutID ?? payload.original_workout_id ?? "");
    const replacementWorkoutID = String(payload.replacementWorkoutID ?? payload.replacement_workout_id ?? event.planned_workout_id ?? "");
    if (!originalWorkoutID || !replacementWorkoutID) {
      throw new Error("Replacement event is missing workout IDs");
    }
    const original = await loadPlannedWorkout(admin, userID, block.id, originalWorkoutID);
    const replacement = await loadPlannedWorkout(admin, userID, block.id, replacementWorkoutID);
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
    const added = await loadPlannedWorkout(admin, userID, block.id, addedWorkoutID);
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
    const editedWorkout = deletedWorkout ?? await loadPlannedWorkout(admin, userID, block.id, workoutID);
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
    const workout = await loadPlannedWorkout(admin, userID, block.id, workoutID);
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

async function checkInToWorkout(
  admin: SupabaseAdminClient,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  const plannedWorkoutID = requestBody.plannedWorkoutID ?? requestBody.planned_workout_id;
  if (!plannedWorkoutID) {
    throw new Error("check_in_to_workout requires plannedWorkoutID");
  }

  const block = await loadActiveBlock(admin, userID);
  const workout = await single(
    admin
      .from("planned_workouts")
      .select()
      .eq("id", plannedWorkoutID)
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .single(),
    "Planned workout not found",
  );

  const shouldAdjust = checkInSuggestsAdjustment(requestBody);
  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: workout.active_block_id,
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
    activeBlockID: workout.active_block_id,
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
  const blocks = await list(
    admin
      .from("active_fitness_blocks")
      .select("id,user_id,timezone")
      .eq("status", "active"),
  );

  const dueBlocks = blocks.filter((block: Record<string, any>) => isSundayEveningInTimezone(block.timezone || "UTC"));
  const refreshed: string[] = [];
  const failed: Array<{ userID: string; error: string }> = [];

  for (const block of dueBlocks) {
    try {
      await refreshPlanWindowForUser(admin, block.user_id, undefined, model, "scheduled");
      refreshed.push(block.user_id);
    } catch (error) {
      failed.push({ userID: block.user_id, error: errorMessage(error) });
    }
  }

  return {
    model: "deterministic",
    due: dueBlocks.length,
    refreshed,
    failed,
  };
}

async function runPlanGeneration(task: PlanningTask, context: Record<string, unknown>, model: string): Promise<GeneratedPlan> {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content:
            "You are HAYF's fitness planning engine. Return strict JSON for an active block, optional phases, and a two-week plan window. HAYF uses one active fitness block, weekly rhythm, and daily adaptation. Do not create fake phases for consistency blocks. Do not ask follow-up questions. Use compact HealthKit-derived summaries only; never request raw samples.",
        },
        {
          role: "user",
          content: JSON.stringify({
            task,
            context,
            rules:
              "Generate current week and next week. Include full workout prescriptions for every workout and a one-line fuelingSummary. Keep distant block context directional; make only the next two weeks concrete. The active block title is a compact product label for a small mobile card, not a schedule summary: keep it under 32 characters, use Title Case, and prefer names like 'Aerobic Base + Strength', 'Run Base + Strength', 'Strength Consistency', or 'Cycling Build'. Put detailed reasoning in block.context.planningRationale, not in block.title.",
          }),
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "planning_plan",
          strict: true,
          schema: planSchema,
        },
      },
    }),
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
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content:
            "You are HAYF's fitness planning engine. Recommend replacement workouts when a user does not want to do a planned session. Preserve the active block intent, respect fixed/completed workouts, avoid crowding hard sessions, and return strict JSON only.",
        },
        {
          role: "user",
          content: JSON.stringify({
            task: "recommend_workout_replacements",
            context,
            rules:
              "Return 2-3 second-best options for the same date/slot. The first candidate should usually preserve the original training purpose with less friction. Other candidates can swap modality or reduce load. Include the weekly impact in plain language. Do not move other workouts directly.",
          }),
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "replacement_candidates",
          strict: true,
          schema: replacementSchema,
        },
      },
    }),
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
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content:
            "You are HAYF's fitness planning engine. Recommend workouts a user can add to a selected day. Preserve the active block intent, respect fixed/completed workouts, avoid crowding hard sessions, and return strict JSON only.",
        },
        {
          role: "user",
          content: JSON.stringify({
            task: "recommend_workout_additions",
            context,
            rules:
              "Return 2-3 useful options for the selected date. Prefer the option that best fits the week without forcing broader changes. Include the weekly impact in plain language. Do not move or delete other workouts directly.",
          }),
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "workout_addition_candidates",
          strict: true,
          schema: replacementSchema,
        },
      },
    }),
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
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content:
            "You are HAYF's fitness planning engine. Interpret a user's natural-language workout description into one workout candidate that can be inserted into a plan. Preserve concrete details like distance, elevation, duration, intensity, and modality. Return strict JSON only.",
        },
        {
          role: "user",
          content: JSON.stringify({
            task: "interpret_workout_description",
            context,
            rules:
              "Return one candidate. If the description is sparse but clearly a workout, make a conservative candidate and explain what assumption you made in the rationale. If it replaces a planned workout, describe weekly impact relative to the original slot. If it adds to a day, describe likely load/recovery impact.",
          }),
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "workout_candidate",
          strict: true,
          schema: workoutCandidateSchema,
        },
      },
    }),
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
): ReplacementCandidate[] {
  const candidates = Array.isArray(generated.candidates) ? generated.candidates : [];
  const fallbacks = fallbackReplacementCandidates(workout, []);
  const sanitized = candidates.slice(0, 3).map((candidate, index) =>
    sanitizeWorkoutCandidate(candidate, fallbacks[index] ?? fallbackReplacementCandidate(workout, index), `candidate-${index + 1}`)
  );

  return sanitized.length > 0 ? sanitized : fallbackReplacementCandidates(workout, []);
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
  const intensityLabel = candidate?.intensityLabel?.trim() || fallback.intensityLabel || "Moderate";
  const title = candidate?.title?.trim() || fallback.title || titleCase(activityType);
  return {
    id,
    title,
    activityType,
    durationMinutes: Math.max(10, candidate?.durationMinutes || fallback.durationMinutes || 30),
    intensityLabel,
    purpose: candidate?.purpose?.trim() || fallback.purpose || "Useful workout for this plan slot",
    prescription: candidate?.prescription ?? fallback.prescription ?? fallbackPrescription(title, activityType, intensityLabel),
    fuelingSummary: candidate?.fuelingSummary?.trim() || fallback.fuelingSummary || fuelingSummary(activityType, intensityLabel),
    rationale: candidate?.rationale?.trim() || fallback.rationale || "This gives the day a useful training stimulus without guessing beyond the plan.",
    weeklyImpact: candidate?.weeklyImpact?.trim() || fallback.weeklyImpact || "HAYF will check the surrounding week after you confirm.",
  };
}

function fallbackReplacementCandidates(workout: Record<string, any>, surroundingWorkouts: Record<string, any>[]): ReplacementCandidate[] {
  const duration = Math.max(15, Math.round((workout.duration_minutes ?? 30) * 0.7));
  const originalType = normalizeActivity(workout.activity_type ?? "");
  const hasStrengthNearby = surroundingWorkouts.some((item) =>
    item.id !== workout.id && /strength|lift/.test(`${item.activity_type ?? ""} ${item.title ?? ""}`.toLowerCase())
  );
  const aerobicType = /run/.test(originalType) ? "run" : "ride";
  const candidates: ReplacementCandidate[] = [
    {
      id: "candidate-1",
      title: "Lower dose",
      activityType: originalType || "training",
      durationMinutes: duration,
      intensityLabel: "Low",
      purpose: workout.purpose || "Preserve the session intent with less load",
      prescription: fallbackPrescription("Lower dose", originalType || "training", "Low"),
      fuelingSummary: fuelingSummary(originalType || "training", "Low"),
      rationale: "This keeps the original purpose but makes it easier to start today.",
      weeklyImpact: "No broader repair is needed unless this becomes a pattern.",
    },
    {
      id: "candidate-2",
      title: hasStrengthNearby ? "Easy aerobic reset" : "Strength support",
      activityType: hasStrengthNearby ? aerobicType : "strength",
      durationMinutes: hasStrengthNearby ? 30 : duration,
      intensityLabel: hasStrengthNearby ? "Zone 2" : "Moderate",
      purpose: hasStrengthNearby ? "Aerobic base" : "Strength anchor",
      prescription: fallbackPrescription(hasStrengthNearby ? "Easy aerobic reset" : "Strength support", hasStrengthNearby ? aerobicType : "strength", hasStrengthNearby ? "Zone 2" : "Moderate"),
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
    prescription: fallbackPrescription(fallbackReplacementTitle(workout, index), workout.activity_type ?? "training", index === 0 ? "Low" : "Moderate"),
    fuelingSummary: fuelingSummary(workout.activity_type ?? "training", index === 0 ? "Low" : "Moderate"),
    rationale: "This keeps the training intent while lowering friction for this slot.",
    weeklyImpact: "The surrounding week can stay as planned unless recovery changes.",
  };
}

function fallbackReplacementTitle(workout: Record<string, any>, index: number) {
  if (index === 0) return "Lower dose";
  if (/strength/.test(`${workout.activity_type ?? ""} ${workout.title ?? ""}`.toLowerCase())) return "Easy aerobic reset";
  return "Strength support";
}

async function loadWorkoutPlanningContext(
  admin: SupabaseAdminClient,
  userID: string,
  block: Record<string, any>,
  scheduledDate: string,
) {
  const date = parseDateOnly(scheduledDate) ?? new Date();
  const window = twoWeekWindow(date);
  const weekStart = isoDate(startOfWeek(date));
  const [surroundingWorkouts, phases, weeklyRhythms] = await Promise.all([
    list(
      admin
        .from("planned_workouts")
        .select()
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .gte("scheduled_date", window.start)
        .lte("scheduled_date", window.end)
        .not("status", "in", "(deleted,superseded)")
        .order("scheduled_date", { ascending: true })
        .order("sequence_order", { ascending: true }),
    ),
    list(
      admin
        .from("fitness_block_phases")
        .select()
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .order("start_date", { ascending: true }),
    ),
    list(
      admin
        .from("weekly_rhythms")
        .select()
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .gte("week_start_date", window.start)
        .lte("week_start_date", window.end)
        .order("week_start_date", { ascending: true }),
    ),
  ]);

  return {
    block,
    scheduledDate,
    weekStart,
    weeklyRhythm: weeklyRhythms.find((rhythm: Record<string, any>) => rhythm.week_start_date === weekStart) ?? null,
    surroundingWorkouts,
    phases,
    weeklyRhythms,
    window,
  };
}

function fallbackAdditionCandidates(context: Record<string, any>): WorkoutCandidate[] {
  const scheduledDate = String(context.scheduledDate ?? isoDate(new Date()));
  const weekStart = startOfWeek(parseDateOnly(scheduledDate) ?? new Date());
  const weekWorkouts = workoutsForWeek(context.surroundingWorkouts ?? [], weekStart);
  const dateWorkouts = (context.surroundingWorkouts ?? []).filter((workout: Record<string, any>) => workout.scheduled_date === scheduledDate);
  const hasStrength = weekWorkouts.some((workout: Record<string, any>) => trainingProfile(workout).dimensions.includes("neuromuscular"));
  const hasEndurance = weekWorkouts.some((workout: Record<string, any>) => trainingProfile(workout).dimensions.includes("endurance"));
  const hasHardNearby = weekWorkouts.some((workout: Record<string, any>) => {
    const days = absoluteCalendarDaysBetween(parseDateOnly(workout.scheduled_date) ?? weekStart, parseDateOnly(scheduledDate) ?? weekStart);
    return days <= 1 && trainingProfile(workout).load === "high";
  });

  const candidates: WorkoutCandidate[] = [];
  if (dateWorkouts.length > 0 || hasHardNearby) {
    candidates.push(additionCandidate("Mobility reset", "mobility", 25, "Low", "Recovery support", "This keeps the added day useful without crowding nearby load.", "Low recovery load; the rest of the week should usually stay intact."));
  }
  if (!hasEndurance) {
    candidates.push(additionCandidate("Easy aerobic base", "ride", 35, "Zone 2", "Aerobic base", "This fills an endurance gap without making the day too sharp.", "Adds low-to-moderate endurance work; HAYF will still check spacing after you confirm."));
  }
  if (!hasStrength) {
    candidates.push(additionCandidate("Strength support", "strength", 40, "Moderate", "Strength anchor", "This gives the week useful strength exposure without chasing maximum load.", "Adds neuromuscular load; HAYF will check nearby hard sessions after you confirm."));
  }
  if (!candidates.some((candidate) => candidate.title === "Easy aerobic base")) {
    candidates.push(additionCandidate("Easy aerobic base", "ride", 35, "Zone 2", "Aerobic base", "This is a useful low-friction endurance option for an open training impulse.", "Adds manageable endurance load; HAYF will check spacing after you confirm."));
  }
  if (!candidates.some((candidate) => candidate.title === "Strength support")) {
    candidates.push(additionCandidate("Strength support", "strength", 40, "Moderate", "Strength support", "This is a useful strength option if the day can handle more load.", "Adds neuromuscular load; HAYF will check nearby hard sessions after you confirm."));
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
  const sparse = isSparseWorkoutDescription(text);

  return {
    id: "candidate-1",
    title,
    activityType,
    durationMinutes,
    intensityLabel,
    purpose: manualPurpose(activityType, workout),
    prescription: workoutPrescription(title, activityType, intensityLabel, text),
    fuelingSummary: fuelingSummary(activityType, intensityLabel),
    rationale: sparse
      ? `I read "${text}" as a conservative ${title.toLowerCase()} because the description is sparse.`
      : "I translated your description into a structured workout HAYF can audit against the plan.",
    weeklyImpact: workout
      ? "This becomes the replacement for the slot; HAYF will check whether the surrounding week needs repair."
      : `This adds load on ${scheduledDate}; HAYF will check whether nearby sessions need spacing or dose changes.`,
  };
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
  if (activityType === "hike") return /long|\d/.test(lower) ? "Long hike" : "Hike";
  if (activityType === "ride") return /long|\d/.test(lower) ? "Long ride" : "Ride";
  if (activityType === "run") return /tempo|interval|threshold/.test(lower) ? "Quality run" : /long|\d/.test(lower) ? "Long run" : "Run";
  if (activityType === "strength") return /upper/.test(lower) ? "Upper strength" : /lower|legs/.test(lower) ? "Lower strength" : "Strength";
  if (activityType === "mobility") return "Mobility";
  if (activityType === "walk") return "Walk";
  if (activityType === "climb") return "Climb";
  return titleCase(activityType);
}

function manualIntensity(text: string) {
  const lower = text.toLowerCase();
  if (/easy|low|recovery|gentle|light/.test(lower)) return "Low";
  if (/hard|high|heavy|interval|threshold|tempo|vo2|race|max/.test(lower)) return "High";
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
  if (match) return Number(match[1].replace(",", "."));
  const shorthand = text.match(/(\d+(?:[.,]\d+)?)\s*k\b/);
  if (shorthand) return Number(shorthand[1].replace(",", "."));
  return null;
}

function manualPurpose(activityType: string, workout: Record<string, any> | undefined) {
  if (workout?.purpose) return workout.purpose;
  if (activityType === "strength") return "Strength support";
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

function fallbackPlan(onboarding: Record<string, any>, start: Date, timezone: string): GeneratedPlan {
  const selected = onboarding.selected_answers ?? {};
  const intent = onboarding.intent as string;
  const kind = blockKind(intent);
  const goalText = selected.chosenGoal?.title || selected.goalBrief || "";
  const title = blockTitle(kind, goalText);
  const targetDate = targetDateFor(selected.goalTimeline, start, kind);
  const reviewCadenceDays = kind === "consistency" ? 28 : daysBetween(start, parseDateOnly(targetDate) ?? addDays(start, 84));
  const phases = kind === "consistency" ? [] : fallbackPhases(start, targetDate);
  const rhythms = fallbackRhythms(start, selected, kind);

  return {
    block: {
      kind,
      title,
      goalText,
      startDate: isoDate(start),
      targetDate,
      reviewCadenceDays,
      context: { selectedAnswers: selected, timezone },
    },
    phases,
    rhythms,
  };
}

function sanitizeGeneratedPlan(
  generated: GeneratedPlan,
  onboarding: Record<string, any> | null,
  start: Date,
  timezone: string,
): GeneratedPlan {
  const fallback = onboarding ? fallbackPlan(onboarding, start, timezone) : null;
  const kind = generated.block.kind;
  const rhythms = generated.rhythms.length > 0 ? generated.rhythms : fallback?.rhythms ?? fallbackRhythms(start, {}, kind);
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
      workouts: rhythm.workouts.map((workout, index) => ({
        ...workout,
        sequenceOrder: workout.sequenceOrder || index + 1,
        durationMinutes: Math.max(10, workout.durationMinutes || 30),
        fuelingSummary: workout.fuelingSummary?.trim() || fuelingSummary(workout.activityType, workout.intensityLabel),
        prescription: workout.prescription ?? fallbackPrescription(workout.title, workout.activityType, workout.intensityLabel),
      })),
    })),
  };
}

function fallbackPlanFromBlock(block: Record<string, any>, start: Date): GeneratedPlan {
  return {
    block: {
      kind: block.kind,
      title: block.title,
      goalText: block.goal_text ?? "",
      startDate: block.start_date,
      targetDate: block.target_date,
      reviewCadenceDays: block.review_cadence_days,
      context: block.context_json ?? {},
    },
    phases: [],
    rhythms: fallbackRhythms(start, block.context_json?.selectedAnswers ?? {}, block.kind),
  };
}

function fallbackRhythms(start: Date, selected: Record<string, any>, kind: string): GeneratedRhythm[] {
  const weekStart = startOfWeek(start);
  return [0, 7].map((offset) => {
    const base = addDays(weekStart, offset);
    const workouts = fallbackWorkoutsForWeek(base, selected, kind);
    return {
      weekStartDate: isoDate(base),
      weekEndDate: isoDate(addDays(base, 6)),
      objective: kind === "consistency" ? "Keep a balanced rhythm repeatable." : "Move the active block forward without crowding recovery.",
      priorityOrder: workouts.map((workout) => workout.title),
      hardEasyDistribution: { hard: 1, moderate: 2, easy: Math.max(1, workouts.length - 3) },
      badDayFloor: selected.badDayFloor || "20-minute easy session",
      swapRules: ["Preserve the highest-priority session first.", "Use the bad-day floor before skipping completely."],
      workouts,
    };
  });
}

function fallbackWorkoutsForWeek(base: Date, selected: Record<string, any>, kind: string): GeneratedWorkout[] {
  const duration = durationMinutes(selected.sessionLength);
  const goalText = `${selected.goalBrief ?? ""} ${selected.chosenGoal?.title ?? ""}`.toLowerCase();
  const runningGoal = /run|half|marathon|5k|10k/.test(goalText);
  const template = kind === "consistency"
    ? [
        { day: 0, type: "strength", title: "Strength", intensity: "Moderate", purpose: "Strength anchor" },
        { day: 1, type: "ride", title: "Easy ride", intensity: "Zone 2", purpose: "Aerobic base" },
        { day: 4, type: "mobility", title: "Mobility", intensity: "Low", purpose: "Movement quality" },
        { day: 6, type: "recovery", title: "Recovery", intensity: "Low", purpose: "Recovery" },
      ]
    : runningGoal
      ? [
          { day: 0, type: "run", title: "Easy run", intensity: "Zone 2", purpose: "Aerobic base" },
          { day: 2, type: "strength", title: "Strength support", intensity: "Moderate", purpose: "Strength maintenance" },
          { day: 4, type: "run", title: "Quality run", intensity: "Moderate", purpose: "Goal progression" },
          { day: 6, type: "recovery", title: "Recovery", intensity: "Low", purpose: "Recovery" },
        ]
      : [
          { day: 0, type: "strength", title: "Strength", intensity: "Moderate", purpose: "Strength anchor" },
          { day: 1, type: "ride", title: "Easy ride", intensity: "Zone 2", purpose: "Aerobic base" },
          { day: 3, type: "strength", title: "Strength", intensity: "Moderate", purpose: "Strength progression" },
          { day: 6, type: "recovery", title: "Recovery", intensity: "Low", purpose: "Recovery" },
        ];

  return template.map((item, index) => ({
    scheduledDate: isoDate(addDays(base, item.day)),
    sequenceOrder: index + 1,
    activityType: item.type,
    title: item.title,
    durationMinutes: item.type === "recovery" || item.type === "mobility" ? 30 : duration,
    intensityLabel: item.intensity,
    purpose: item.purpose,
    prescription: fallbackPrescription(item.title, item.type, item.intensity),
    fuelingSummary: fuelingSummary(item.type, item.intensity),
  }));
}

function fallbackPhases(start: Date, targetDate: string | null): GeneratedPhase[] {
  const end = parseDateOnly(targetDate) ?? addDays(start, 84);
  const total = Math.max(21, daysBetween(start, end));
  const firstEnd = addDays(start, Math.floor(total / 3));
  const secondEnd = addDays(start, Math.floor((total * 2) / 3));
  return [
    {
      name: "Base",
      startDate: isoDate(start),
      endDate: isoDate(firstEnd),
      objective: "Make the goal work repeatable around the user's schedule.",
      focus: ["Repeatable weekly rhythm", "Support strength and aerobic base"],
      risk: ["Doing too much too early"],
    },
    {
      name: "Build",
      startDate: isoDate(addDays(firstEnd, 1)),
      endDate: isoDate(secondEnd),
      objective: "Increase goal-specific work while preserving recovery.",
      focus: ["Goal-specific progression", "Recovery-aware volume"],
      risk: ["Crowding the week with too much intensity"],
    },
    {
      name: "Review",
      startDate: isoDate(addDays(secondEnd, 1)),
      endDate: isoDate(end),
      objective: "Sharpen the block and review what should happen next.",
      focus: ["Quality execution", "Next-block decision"],
      risk: ["Chasing extra work instead of useful work"],
    },
  ];
}

async function insertRhythmsAndWorkouts(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string,
  rhythms: GeneratedRhythm[],
  source: "generated" | "replanned",
  minScheduledDate?: string,
) {
  for (const rhythm of rhythms) {
    const savedRhythm = await single(
      admin
        .from("weekly_rhythms")
        .upsert(
          {
            active_block_id: activeBlockID,
            user_id: userID,
            week_start_date: rhythm.weekStartDate,
            week_end_date: rhythm.weekEndDate,
            objective: rhythm.objective,
            priority_order_json: rhythm.priorityOrder,
            hard_easy_distribution_json: rhythm.hardEasyDistribution,
            bad_day_floor: rhythm.badDayFloor,
            swap_rules_json: rhythm.swapRules,
            status: "active",
          },
          { onConflict: "active_block_id,week_start_date" },
        )
        .select()
        .single(),
      "Could not upsert weekly rhythm",
    );

    const workouts = minScheduledDate
      ? rhythm.workouts.filter((workout) => workout.scheduledDate >= minScheduledDate)
      : rhythm.workouts;

    if (workouts.length === 0) {
      continue;
    }

    await throwOnError(
      admin.from("planned_workouts").insert(
        workouts.map((workout) => ({
          active_block_id: activeBlockID,
          weekly_rhythm_id: savedRhythm.id,
          user_id: userID,
          scheduled_date: workout.scheduledDate,
          sequence_order: workout.sequenceOrder,
          activity_type: workout.activityType,
          title: workout.title,
          duration_minutes: workout.durationMinutes,
          intensity_label: workout.intensityLabel,
          purpose: workout.purpose,
          status: "planned",
          source,
          prescription_json: workout.prescription,
          fueling_summary: workout.fuelingSummary,
        })),
      ),
    );
  }
}

async function markCurrentWorkout(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string,
  now: Date,
) {
  await throwOnError(
    admin
      .from("planned_workouts")
      .update({ status: "planned" })
      .eq("user_id", userID)
      .eq("active_block_id", activeBlockID)
      .eq("status", "current"),
  );

  const next = await maybeSingle(
    admin
      .from("planned_workouts")
      .select()
      .eq("user_id", userID)
      .eq("active_block_id", activeBlockID)
      .gte("scheduled_date", isoDate(now))
      .in("status", ["planned", "checked_in", "adjusted"])
      .order("scheduled_date", { ascending: true })
      .order("sequence_order", { ascending: true })
      .limit(1),
  );

  if (next?.status === "planned") {
    await throwOnError(admin.from("planned_workouts").update({ status: "current" }).eq("id", next.id));
  }
}

async function markMissedWorkouts(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string,
  syncEndDate?: string,
) {
  const cutoff = parseDateOnly(syncEndDate) ?? new Date();
  const cutoffDate = isoDate(cutoff);
  return list(
    admin
      .from("planned_workouts")
      .update({ status: "missed" })
      .eq("user_id", userID)
      .eq("active_block_id", activeBlockID)
      .lt("scheduled_date", cutoffDate)
      .in("status", ["planned", "current", "checked_in", "adjusted"])
      .in("source", ["generated", "replanned", "user_moved", "user_added", "checkin_adjusted"])
      .select("id, scheduled_date, title"),
  );
}

async function archiveActiveBlocks(admin: SupabaseAdminClient, userID: string) {
  await throwOnError(
    admin
      .from("active_fitness_blocks")
      .update({ status: "archived" })
      .eq("user_id", userID)
      .eq("status", "active"),
  );
}

async function loadActiveBlock(admin: SupabaseAdminClient, userID: string) {
  return single(
    admin
      .from("active_fitness_blocks")
      .select()
      .eq("user_id", userID)
      .eq("status", "active")
      .single(),
    "Active fitness block not found",
  );
}

async function loadPlannedWorkout(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string,
  plannedWorkoutID: string,
) {
  return single(
    admin
      .from("planned_workouts")
      .select()
      .eq("id", plannedWorkoutID)
      .eq("user_id", userID)
      .eq("active_block_id", activeBlockID)
      .single(),
    "Planned workout not found",
  );
}

async function findWorkoutMatch(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string,
  actual: ActualWorkoutInput,
) {
  const actualDate = actual.start_date.slice(0, 10);
  const candidates = await list(
    admin
      .from("planned_workouts")
      .select()
      .eq("user_id", userID)
      .eq("active_block_id", activeBlockID)
      .eq("scheduled_date", actualDate)
      .in("status", ["planned", "current", "checked_in", "adjusted"]),
  );

  let best: { workout: Record<string, any>; confidence: number } | null = null;
  for (const workout of candidates) {
    const modality = modalityScore(actual.activity_type, workout.activity_type, workout.title);
    const duration = durationScore(actual.duration_minutes, workout.duration_minutes);
    const confidence = Number(((modality * 0.7) + (duration * 0.3)).toFixed(2));
    if (confidence >= 0.68 && (!best || confidence > best.confidence)) {
      best = { workout, confidence };
    }
  }
  return best;
}

async function insertDetectedWorkout(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string,
  actual: ActualWorkoutInput,
) {
  const existing = await list(
    admin
      .from("planned_workouts")
      .select("sequence_order")
      .eq("user_id", userID)
      .eq("active_block_id", activeBlockID)
      .eq("scheduled_date", actual.start_date.slice(0, 10)),
  );

  return single(
    admin
      .from("planned_workouts")
      .insert({
        user_id: userID,
        active_block_id: activeBlockID,
        scheduled_date: actual.start_date.slice(0, 10),
        sequence_order: existing.length + 1,
        activity_type: normalizeActivity(actual.activity_type),
        title: `${titleCase(actual.activity_type)} (detected)`,
        duration_minutes: actual.duration_minutes,
        intensity_label: "Detected",
        purpose: "Added from HealthKit",
        status: "done",
        source: "healthkit_detected",
        prescription_json: { detectedFrom: "HealthKit" },
      })
      .select()
      .single(),
    "Could not insert detected workout",
  );
}

async function persistFitnessEvidence(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID: string,
  snapshot: Record<string, any>,
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

  const observations = fitnessMetricObservations(userID, activeBlockID, snapshot, profile, generatedAt);
  if (observations.length > 0) {
    await throwOnError(admin.from("fitness_metric_observations").insert(observations));
  }
}

function fitnessMetricObservations(
  userID: string,
  activeBlockID: string,
  snapshot: Record<string, any>,
  profile: Record<string, any>,
  observedAt: string,
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
  ) => {
    if (typeof value !== "number" || Number.isNaN(value)) {
      return;
    }

    rows.push({
      user_id: userID,
      active_block_id: activeBlockID,
      source: "healthkit",
      metric_key: metricKey,
      metric_label: metricLabel,
      metric_category: metricCategory,
      value,
      unit,
      observed_end: observedAt,
      dimensions_json: dimensions,
      evidence_json: evidence,
      confidence: "high",
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
  push("body_mass_latest_kg", "Body mass latest", "body", snapshot.body?.bodyMassKilograms, "kg");
  push("body_mass_28d_avg_kg", "Body mass 28d average", "body", snapshot.body?.bodyMass28DayAverageKilograms, "kg", { window: "28d" });
  push("body_fat_latest_percentage", "Body fat latest", "body", snapshot.body?.bodyFatPercentage, "%");
  push("body_fat_28d_avg_percentage", "Body fat 28d average", "body", snapshot.body?.bodyFat28DayAveragePercentage, "%", { window: "28d" });
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

async function createInitialGoalTargets(
  admin: SupabaseAdminClient,
  userID: string,
  block: Record<string, any>,
  snapshot: Record<string, any>,
) {
  const existingWeekly: Array<Record<string, any>> = await list(
    admin
      .from("fitness_goal_targets")
      .select("id,metric_key,metric_category,target_kind")
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .like("metric_category", "weekly_%")
  );

  const plannedWorkouts = await list(
    admin
      .from("planned_workouts")
      .select("scheduled_date,activity_type,title,duration_minutes,status")
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .in("status", ["planned", "current", "checked_in", "adjusted", "done"]),
  );
  const targets = buildInitialGoalTargets(userID, block, snapshot, plannedWorkouts);
  if (targets.length === 0) {
    return;
  }

  if (existingWeekly.length > 0) {
    await throwOnError(
      admin
        .from("fitness_goal_targets")
        .delete()
        .eq("user_id", userID)
        .eq("active_block_id", block.id)
        .like("metric_category", "weekly_%"),
    );
  }

  await throwOnError(admin.from("fitness_goal_targets").insert(targets));
  await createPlanEvent(admin, {
    userID,
    activeBlockID: block.id,
    eventType: "goal_targets_created",
    payload: { count: targets.length, source: "weekly_plan_targets", replaced: existingWeekly.length },
  });
}

function buildInitialGoalTargets(
  userID: string,
  block: Record<string, any>,
  snapshot: Record<string, any>,
  plannedWorkouts: Array<Record<string, any>> = [],
) {
  const text = `${block.goal_text ?? ""} ${block.title ?? ""}`.toLowerCase();
  const startDate = isoDate(startOfWeek(new Date()));
  const targetDate = isoDate(addDays(parseDateOnly(startDate) ?? new Date(), 6));
  const profile = snapshot.fitnessHistory ?? snapshot.fitness_history ?? {};
  const isCyclingGoal = /cycle|cycling|bike|ride|climb/.test(text);
  const isRunningGoal = /run|running|5k|10k|marathon|pace/.test(text);
  const week = weeklyPlanSummary(plannedWorkouts, startDate);
  const modalities = new Set([
    ...(profile.trainingIdentity?.dominantModalities ?? []),
    ...week.modalities,
  ].map((value: string) => normalizeWorkoutModality(value)));
  if (isCyclingGoal) modalities.add("cycling");
  if (isRunningGoal) modalities.add("running");
  if (/strength|lift|gym|boulder|climb/.test(text)) modalities.add("strength");

  const rows: Array<Record<string, unknown>> = [];
  const pushWeeklyTarget = (args: {
    kind?: "primary" | "sub_goal";
    title: string;
    description: string;
    metricKey: string;
    metricCategory: string;
    targetValue: number | null;
    unit: string;
    rule: Record<string, unknown>;
  }) => {
    rows.push(goalTargetRow({
      userID,
      blockID: block.id,
      kind: args.kind ?? "sub_goal",
      title: args.title,
      description: args.description,
      metricKey: args.metricKey,
      metricCategory: args.metricCategory,
      direction: "maintain",
      baselineValue: metricValueFor(snapshot, args.metricKey),
      targetValue: args.targetValue,
      unit: args.unit,
      startDate,
      targetDate,
      rule: { ...args.rule, source: "weekly_plan_target", window: "7d", profileLabel: profile.trainingIdentity?.label ?? null },
    }));
  };

  pushWeeklyTarget({
    kind: "primary",
    title: "Weekly training time",
    description: "The total planned training dose for this week. Adjust the week by moving, adding, or resizing sessions.",
    metricKey: "training_minutes_7d",
    metricCategory: "weekly_volume",
    targetValue: week.totalMinutes || fallbackWeeklyMinutes(profile),
    unit: "min",
    rule: { plannedSessions: week.sessionCount },
  });

  if (modalities.has("cycling")) {
    const planned = Math.round((week.minutesByModality.cycling ?? 0) * 0.42);
    pushWeeklyTarget({
      title: "Cycling distance this week",
      description: "A weekly cycling exposure target based on the rides in the plan and the active block goal.",
      metricKey: "cycling_distance_7d_km",
      metricCategory: "weekly_cycling",
      targetValue: planned > 0 ? planned : 40,
      unit: "km",
      rule: { modality: "cycling", plannedMinutes: week.minutesByModality.cycling ?? 0 },
    });
  }

  if (modalities.has("running")) {
    const planned = Math.round((week.minutesByModality.running ?? 0) * 0.13);
    pushWeeklyTarget({
      title: "Running distance this week",
      description: "A weekly run-distance target that can be shaped by adding, moving, or reducing run sessions.",
      metricKey: "running_distance_7d_km",
      metricCategory: "weekly_running",
      targetValue: planned > 0 ? planned : 12,
      unit: "km",
      rule: { modality: "running", plannedMinutes: week.minutesByModality.running ?? 0 },
    });
  }

  if (modalities.has("strength")) {
    pushWeeklyTarget({
      title: "Strength sessions this week",
      description: "The gym or strength anchors HAYF is trying to keep alive in this week.",
      metricKey: "strength_workouts_7d",
      metricCategory: "weekly_strength",
      targetValue: Math.max(1, week.countByModality.strength ?? 0),
      unit: "sessions",
      rule: { modality: "strength", plannedMinutes: week.minutesByModality.strength ?? 0 },
    });
  }

  const recoveryCount = (week.countByModality.recovery ?? 0) + (week.countByModality.walking ?? 0) + (week.countByModality.mobility ?? 0);
  pushWeeklyTarget({
    title: "Recovery sessions this week",
    description: "Low-friction recovery work that keeps the plan adjustable instead of brittle.",
    metricKey: "recovery_sessions_7d",
    metricCategory: "weekly_recovery",
    targetValue: Math.max(1, recoveryCount),
    unit: "sessions",
    rule: { modalities: ["recovery", "walking", "mobility"] },
  });

  return rows.slice(0, 5);
}

function weeklyPlanSummary(plannedWorkouts: Array<Record<string, any>>, startDate: string) {
  const weekStart = startOfWeek(parseDateOnly(startDate) ?? new Date());
  const weekEnd = addDays(weekStart, 6);
  const summary: {
    totalMinutes: number;
    sessionCount: number;
    modalities: string[];
    minutesByModality: Record<string, number>;
    countByModality: Record<string, number>;
  } = {
    totalMinutes: 0,
    sessionCount: 0,
    modalities: [],
    minutesByModality: {},
    countByModality: {},
  };

  for (const workout of plannedWorkouts) {
    const scheduled = parseDateOnly(String(workout.scheduled_date ?? ""));
    if (!scheduled || scheduled < weekStart || scheduled > weekEnd) continue;

    const modality = normalizeWorkoutModality(`${workout.activity_type ?? ""} ${workout.title ?? ""}`);
    const minutes = Math.max(0, Number(workout.duration_minutes ?? 0));
    summary.totalMinutes += minutes;
    summary.sessionCount += 1;
    summary.minutesByModality[modality] = (summary.minutesByModality[modality] ?? 0) + minutes;
    summary.countByModality[modality] = (summary.countByModality[modality] ?? 0) + 1;
  }

  summary.modalities = Object.keys(summary.countByModality);
  summary.totalMinutes = Math.round(summary.totalMinutes);
  return summary;
}

function fallbackWeeklyMinutes(profile: Record<string, any>) {
  const average = profile.consistency?.averageMinutesPerActiveWeek;
  if (typeof average === "number" && !Number.isNaN(average)) {
    return Math.max(90, Math.round(average));
  }
  return 150;
}

function normalizeWorkoutModality(value: string) {
  const text = String(value ?? "").toLowerCase();
  if (/cycle|cycling|bike|ride/.test(text)) return "cycling";
  if (/run|running|jog/.test(text)) return "running";
  if (/strength|lift|lifting|gym|barbell|dumbbell|kettlebell|boulder|climb/.test(text)) return "strength";
  if (/walk|hike/.test(text)) return "walking";
  if (/mobility|yoga|pilates|stretch/.test(text)) return "mobility";
  if (/recover|rest/.test(text)) return "recovery";
  return text.trim() || "training";
}

function goalTargetRow(args: {
  userID: string;
  blockID: string;
  kind: "primary" | "sub_goal";
  title: string;
  description: string;
  metricKey: string;
  metricCategory: string;
  direction: "increase" | "decrease" | "maintain" | "complete" | "review";
  baselineValue?: number | null;
  targetValue?: number | null;
  unit?: string | null;
  startDate: string;
  targetDate?: string | null;
  rule: Record<string, unknown>;
}) {
  return {
    user_id: args.userID,
    active_block_id: args.blockID,
    target_kind: args.kind,
    title: args.title,
    description: args.description,
    metric_key: args.metricKey,
    metric_category: args.metricCategory,
    direction: args.direction,
    baseline_value: typeof args.baselineValue === "number" ? args.baselineValue : null,
    target_value: typeof args.targetValue === "number" ? args.targetValue : null,
    unit: args.unit ?? null,
    start_date: args.startDate,
    target_date: args.targetDate ?? null,
    evaluation_rule_json: args.rule,
    source: "planning_engine",
    status: "needs_review",
  };
}

async function evaluateGoalTargets(
  admin: SupabaseAdminClient,
  userID: string,
  block: Record<string, any>,
  snapshot: Record<string, any>,
) {
  const targets = await list(
    admin
      .from("fitness_goal_targets")
      .select()
      .eq("user_id", userID)
      .eq("active_block_id", block.id)
      .order("created_at", { ascending: true }),
  );
  if (targets.length === 0) {
    return;
  }

  let achievedPrimary = false;
  let reviewPrimary = false;
  const evaluations: Array<Record<string, unknown>> = [];
  for (const target of targets) {
    const currentValue = target.metric_key ? metricValueFor(snapshot, target.metric_key) : null;
    const evaluation = evaluateGoalTarget(target, currentValue);
    evaluations.push({
      user_id: userID,
      active_block_id: block.id,
      goal_target_id: target.id,
      status: evaluation.status,
      current_value: typeof currentValue === "number" ? currentValue : null,
      target_value: target.target_value,
      unit: target.unit,
      progress_ratio: evaluation.progressRatio,
      evidence_json: evaluation.evidence,
      message: evaluation.message,
      confidence: evaluation.confidence,
    });

    if (target.status !== evaluation.status) {
      await createPlanEvent(admin, {
        userID,
        activeBlockID: block.id,
        eventType: "goal_status_changed",
        payload: { goalTargetID: target.id, from: target.status, to: evaluation.status, title: target.title },
      });
    }

    if (target.target_kind === "primary" && evaluation.status === "achieved") {
      achievedPrimary = true;
      await createPlanEvent(admin, {
        userID,
        activeBlockID: block.id,
        eventType: "goal_achieved",
        payload: { goalTargetID: target.id, title: target.title, currentValue, targetValue: target.target_value },
      });
    }

    if (target.target_kind === "primary" && evaluation.status === "needs_review") {
      reviewPrimary = true;
    }

    await throwOnError(
      admin
        .from("fitness_goal_targets")
        .update({ status: evaluation.status })
        .eq("id", target.id)
        .eq("user_id", userID),
    );
  }

  await throwOnError(admin.from("fitness_goal_evaluations").insert(evaluations));
  await createPlanEvent(admin, {
    userID,
    activeBlockID: block.id,
    eventType: "goal_progress_evaluated",
    payload: { count: evaluations.length, generatedAt: snapshotGeneratedAt(snapshot) },
  });

  if (achievedPrimary) {
    await createGoalReviewProposal(admin, userID, block.id, "Primary goal achieved. Review whether to maintain, extend, or start a new block.");
  } else if (reviewPrimary) {
    await createPlanEvent(admin, {
      userID,
      activeBlockID: block.id,
      eventType: "goal_review_needed",
      payload: { reason: "primary_goal_not_measurable" },
    });
    await createGoalReviewProposal(admin, userID, block.id, "Primary goal needs review because HAYF does not have enough measurable evidence yet.");
  }
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
    body_mass_latest_kg: snapshot.body?.bodyMassKilograms,
    body_mass_28d_avg_kg: snapshot.body?.bodyMass28DayAverageKilograms,
    body_fat_latest_percentage: snapshot.body?.bodyFatPercentage,
    body_fat_28d_avg_percentage: snapshot.body?.bodyFat28DayAveragePercentage,
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
  activeBlockID: string,
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
  activeBlockID: string,
  window: { start: string; end: string },
) {
  const workouts = await list(
    admin
      .from("planned_workouts")
      .select("scheduled_date,status")
      .eq("user_id", userID)
      .eq("active_block_id", activeBlockID)
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

async function createPlanEvent(
  admin: SupabaseAdminClient,
  args: {
    userID: string;
    activeBlockID?: string | null;
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
    triggerEventID?: string | null;
    reason: string;
    mutations: Array<Record<string, unknown>>;
    metadata?: Record<string, unknown>;
  },
) {
  await expirePendingReplanProposals(admin, args.userID, args.activeBlockID ?? null);

  const proposal = await single(
    admin
      .from("replan_proposals")
      .insert({
        user_id: args.userID,
        active_block_id: args.activeBlockID ?? null,
        trigger_event_id: args.triggerEventID ?? null,
        reason: args.reason,
        proposed_mutations_json: args.mutations,
        status: "pending",
      })
      .select()
      .single(),
    "Could not create replan proposal",
  );

  await createPlanEvent(admin, {
    userID: args.userID,
    activeBlockID: args.activeBlockID,
    eventType: "proposal_created",
    payload: { proposalID: proposal.id, reason: args.reason, ...(args.metadata ?? {}) },
  });

  return proposal;
}

async function expirePendingReplanProposals(
  admin: SupabaseAdminClient,
  userID: string,
  activeBlockID?: string | null,
  excludeProposalID?: string | null,
) {
  if (!activeBlockID) return;

  let query = admin
    .from("replan_proposals")
    .update({ status: "expired" })
    .eq("user_id", userID)
    .eq("active_block_id", activeBlockID)
    .eq("status", "pending");

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
          .update({ status: "deleted", source: "user_deleted" })
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

function blockTitle(kind: string, goalText: string) {
  if (kind === "consistency") return "Consistency Rhythm";
  if (goalText.trim()) return compactBlockTitle(goalText.trim(), goalText, [], kind);
  return "Active fitness block";
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

function targetDateFor(goalTimeline: string | undefined, start: Date, kind: string) {
  if (kind === "consistency") return null;
  if (!goalTimeline) return isoDate(addDays(start, kind === "goal_discovery_chosen" ? 56 : 84));
  const lower = goalTimeline.toLowerCase();
  if (lower.includes("4")) return isoDate(addDays(start, 28));
  if (lower.includes("8")) return isoDate(addDays(start, 56));
  if (lower.includes("12")) return isoDate(addDays(start, 84));
  const parsed = parseDateOnly(goalTimeline);
  return parsed ? isoDate(parsed) : isoDate(addDays(start, 84));
}

function durationMinutes(sessionLength: string | undefined) {
  if (!sessionLength) return 45;
  const match = sessionLength.match(/\d+/);
  return match ? Number(match[0]) : 45;
}

function fallbackPrescription(title: string, activityType: string, intensity: string) {
  if (activityType === "strength") {
    return {
      warmup: "8-10 min easy movement and ramp-up sets",
      main: ["Compound lift or machine pattern 3-4 sets", "Support pull/push 3 sets", "Accessory/core 2-3 sets"],
      cooldown: "3-5 min easy mobility",
      successCriteria: "Leave 1-2 reps in reserve and keep form clean.",
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
  if ((actual === "ride" && planned === "cycling") || (actual === "cycling" && planned === "ride")) return 1;
  if ((actual === "walk" && planned === "recovery") || (actual === "recovery" && planned === "walk")) return 0.72;
  return 0;
}

function durationScore(actual: number, planned: number) {
  const delta = Math.abs(actual - planned);
  if (delta <= 10) return 1;
  if (delta <= 20) return 0.75;
  if (delta <= Math.max(30, planned * 0.5)) return 0.45;
  return 0;
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
  if (lower.includes("cycle") || lower.includes("bike") || lower.includes("ride")) return "ride";
  if (lower.includes("run")) return "run";
  if (lower.includes("swim")) return "swim";
  if (lower.includes("row")) return "row";
  if (lower.includes("hike")) return "hike";
  if (lower.includes("walk")) return "walk";
  if (lower.includes("climb") || lower.includes("boulder")) return "climb";
  if (lower.includes("strength") || lower.includes("traditional") || lower.includes("lift")) return "strength";
  if (lower.includes("mobility") || lower.includes("yoga") || lower.includes("stretch")) return "mobility";
  if (lower.includes("recover")) return "recovery";
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
  return weekday === "Sun" && hour === 21;
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
