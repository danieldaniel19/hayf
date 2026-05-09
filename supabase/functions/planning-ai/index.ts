import { createClient } from "jsr:@supabase/supabase-js@2";

type PlanningTask =
  | "bootstrap_after_onboarding"
  | "sync_healthkit_and_reconcile"
  | "refresh_plan_window"
  | "record_plan_edit"
  | "recommend_workout_replacements"
  | "replace_workout"
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
  decision?: "accepted" | "rejected";
  plannedWorkoutID?: string;
  planned_workout_id?: string;
  replacementCandidate?: ReplacementCandidateInput;
  replacement_candidate?: ReplacementCandidateInput;
  mood?: { energy?: number; mood?: number };
  textContext?: string;
  currentDerivedSnapshot?: Record<string, unknown> | null;
  current_derived_snapshot?: Record<string, unknown> | null;
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

type ReplacementCandidateInput = {
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

type ReplacementCandidate = ReplacementCandidateInput & {
  id: string;
  rationale: string;
  weeklyImpact: string;
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startedAt = Date.now();
  const supabaseUrl = mustGetEnv("SUPABASE_URL");
  const serviceRoleKey = mustGetEnv("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = mustGetEnv("SUPABASE_ANON_KEY");
  const admin = createClient(supabaseUrl, serviceRoleKey);
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

    const output = await handleTask({
      admin,
      requestBody,
      userID,
      model,
      startedAt,
    });

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
  admin: ReturnType<typeof createClient>;
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
      return syncHealthKitAndReconcile(admin, userID!, requestBody);
    case "refresh_plan_window":
      return refreshPlanWindow(admin, userID!, requestBody, model, "user");
    case "record_plan_edit":
      return recordPlanEdit(admin, userID!, requestBody);
    case "recommend_workout_replacements":
      return recommendWorkoutReplacements(admin, userID!, requestBody, model);
    case "replace_workout":
      return replaceWorkout(admin, userID!, requestBody);
    case "apply_replan_proposal":
      return applyReplanProposal(admin, userID!, requestBody);
    case "check_in_to_workout":
      return checkInToWorkout(admin, userID!, requestBody);
    case "scheduled_refresh_due_windows":
      return scheduledRefreshDueWindows(admin, model);
  }
}

async function bootstrapAfterOnboarding(
  admin: ReturnType<typeof createClient>,
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
  admin: ReturnType<typeof createClient>,
  userID: string,
  requestBody: PlanningAIRequest,
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
      detectedEvents.push({ eventID: event.id, plannedWorkoutID: inserted.id, actual });
      detected += 1;
    }
  }

  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: block.id,
    eventType: "actual_synced",
    payload: { synced, matched, detected, syncWindow: requestBody.syncWindow ?? null },
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

  await markCurrentWorkout(admin, userID, block.id, new Date());

  return { userID, eventID: event.id, synced, matched, detected };
}

async function refreshPlanWindow(
  admin: ReturnType<typeof createClient>,
  userID: string,
  requestBody: PlanningAIRequest,
  model: string,
  trigger: "user" | "scheduled",
) {
  return refreshPlanWindowForUser(admin, userID, requestBody.windowStart, model, trigger);
}

async function refreshPlanWindowForUser(
  admin: ReturnType<typeof createClient>,
  userID: string,
  windowStart: string | undefined,
  model: string,
  trigger: "user" | "scheduled",
) {
  const block = await loadActiveBlock(admin, userID);
  const start = parseDateOnly(windowStart) ?? new Date();
  const window = twoWeekWindow(start);
  if (trigger === "user" && await hasUsablePlanWindow(admin, userID, block.id, window)) {
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
  const context = { block, latestSnapshot, events, proposals, windowStart: isoDate(start), trigger };
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

  await insertRhythmsAndWorkouts(admin, userID, block.id, generated.rhythms, "replanned");
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
  admin: ReturnType<typeof createClient>,
  userID: string,
  requestBody: PlanningAIRequest,
) {
  if (!requestBody.edit) {
    throw new Error("record_plan_edit requires edit");
  }

  const block = await loadActiveBlock(admin, userID);
  const edit = requestBody.edit;
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
    const event = await createPlanEvent(admin, {
      userID,
      activeBlockID: block.id,
      plannedWorkoutID: workout.id,
      eventType: "workout_moved",
      payload: { from: workout.scheduled_date, to: edit.scheduled_date },
    });
    const movedAcrossWeek = startOfWeek(parseDateOnly(workout.scheduled_date) ?? new Date()).getTime() !==
      startOfWeek(parseDateOnly(edit.scheduled_date) ?? new Date()).getTime();
    const proposal = movedAcrossWeek
      ? await createReplanProposal(admin, {
        userID,
        activeBlockID: block.id,
        triggerEventID: event.id,
        reason: "A workout moved across weeks. Review whether the surrounding rhythm needs a repair.",
        mutations: [],
      })
      : null;
    await markCurrentWorkout(admin, userID, block.id, new Date());
    return { userID, eventID: event.id, proposalID: proposal?.id ?? null };
  }

  await throwOnError(
    admin
      .from("planned_workouts")
      .update({ status: "deleted", source: "user_deleted", version: (workout.version ?? 1) + 1 })
      .eq("id", workout.id),
  );
  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: block.id,
    plannedWorkoutID: workout.id,
    eventType: "workout_deleted",
    payload: { deletedWorkout: workout },
  });
  const proposal = await createReplanProposal(admin, {
    userID,
    activeBlockID: block.id,
    triggerEventID: event.id,
    reason: "A planned workout was deleted. Review whether the rest of the week should be repaired.",
    mutations: [],
  });
  await markCurrentWorkout(admin, userID, block.id, new Date());
  return { userID, eventID: event.id, proposalID: proposal.id };
}

async function recommendWorkoutReplacements(
  admin: ReturnType<typeof createClient>,
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

async function replaceWorkout(
  admin: ReturnType<typeof createClient>,
  userID: string,
  requestBody: PlanningAIRequest,
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

  await markCurrentWorkout(admin, userID, block.id, new Date());
  return { userID, eventID: event.id, originalWorkoutID: workout.id, replacementWorkout: replacement };
}

async function applyReplanProposal(
  admin: ReturnType<typeof createClient>,
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

  const event = await createPlanEvent(admin, {
    userID,
    activeBlockID: proposal.active_block_id,
    eventType: requestBody.decision === "accepted" ? "proposal_accepted" : "proposal_rejected",
    payload: { proposalID: proposal.id },
  });

  return { userID, proposalID: proposal.id, decision: requestBody.decision, eventID: event.id };
}

async function checkInToWorkout(
  admin: ReturnType<typeof createClient>,
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

async function scheduledRefreshDueWindows(admin: ReturnType<typeof createClient>, model: string) {
  const blocks = await list(
    admin
      .from("active_fitness_blocks")
      .select("id,user_id,timezone")
      .eq("status", "active"),
  );

  const dueBlocks = blocks.filter((block) => isSundayEveningInTimezone(block.timezone || "UTC"));
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

function sanitizeReplacementCandidates(
  generated: { candidates?: ReplacementCandidateInput[] },
  workout: Record<string, any>,
): ReplacementCandidate[] {
  const candidates = Array.isArray(generated.candidates) ? generated.candidates : [];
  const sanitized = candidates.slice(0, 3).map((candidate, index) => ({
    id: `candidate-${index + 1}`,
    title: candidate.title?.trim() || fallbackReplacementTitle(workout, index),
    activityType: normalizeActivity(candidate.activityType || workout.activity_type || "training"),
    durationMinutes: Math.max(10, candidate.durationMinutes || workout.duration_minutes || 30),
    intensityLabel: candidate.intensityLabel?.trim() || "Moderate",
    purpose: candidate.purpose?.trim() || workout.purpose || "Preserve the plan intent with less friction",
    prescription: candidate.prescription ?? fallbackPrescription(candidate.title || workout.title, candidate.activityType || workout.activity_type, candidate.intensityLabel || workout.intensity_label),
    fuelingSummary: candidate.fuelingSummary?.trim() || fuelingSummary(candidate.activityType || workout.activity_type, candidate.intensityLabel || workout.intensity_label),
    rationale: candidate.rationale?.trim() || "This keeps the training intent while lowering friction for this slot.",
    weeklyImpact: candidate.weeklyImpact?.trim() || "The surrounding week can stay as planned unless recovery changes.",
  }));

  return sanitized.length > 0 ? sanitized : fallbackReplacementCandidates(workout, []);
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

function fallbackReplacementTitle(workout: Record<string, any>, index: number) {
  if (index === 0) return "Lower dose";
  if (/strength/.test(`${workout.activity_type ?? ""} ${workout.title ?? ""}`.toLowerCase())) return "Easy aerobic reset";
  return "Strength support";
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
  admin: ReturnType<typeof createClient>,
  userID: string,
  activeBlockID: string,
  rhythms: GeneratedRhythm[],
  source: "generated" | "replanned",
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

    if (rhythm.workouts.length === 0) {
      continue;
    }

    await throwOnError(
      admin.from("planned_workouts").insert(
        rhythm.workouts.map((workout) => ({
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
  admin: ReturnType<typeof createClient>,
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

async function archiveActiveBlocks(admin: ReturnType<typeof createClient>, userID: string) {
  await throwOnError(
    admin
      .from("active_fitness_blocks")
      .update({ status: "archived" })
      .eq("user_id", userID)
      .eq("status", "active"),
  );
}

async function loadActiveBlock(admin: ReturnType<typeof createClient>, userID: string) {
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
  admin: ReturnType<typeof createClient>,
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
  admin: ReturnType<typeof createClient>,
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
  admin: ReturnType<typeof createClient>,
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

async function hasUsablePlanWindow(
  admin: ReturnType<typeof createClient>,
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

  const dates = workouts.map((workout) => workout.scheduled_date).sort();
  const lastWorkoutDate = dates[dates.length - 1];
  return lastWorkoutDate >= isoDate(addDays(parseDateOnly(window.end) ?? new Date(), -1));
}

async function createPlanEvent(
  admin: ReturnType<typeof createClient>,
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
  admin: ReturnType<typeof createClient>,
  args: {
    userID: string;
    activeBlockID?: string | null;
    triggerEventID?: string | null;
    reason: string;
    mutations: Array<Record<string, unknown>>;
    metadata?: Record<string, unknown>;
  },
) {
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

async function applyProposalMutations(admin: ReturnType<typeof createClient>, userID: string, proposal: Record<string, any>) {
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
  admin: ReturnType<typeof createClient>,
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

function normalizeActivity(value: string) {
  const lower = value.toLowerCase();
  if (lower.includes("cycle") || lower.includes("bike") || lower.includes("ride")) return "ride";
  if (lower.includes("run")) return "run";
  if (lower.includes("walk")) return "walk";
  if (lower.includes("strength") || lower.includes("traditional")) return "strength";
  if (lower.includes("mobility") || lower.includes("yoga")) return "mobility";
  if (lower.includes("recover")) return "recovery";
  return lower.replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "") || "workout";
}

function checkInSuggestsAdjustment(requestBody: PlanningAIRequest) {
  const energy = requestBody.mood?.energy;
  if (typeof energy === "number" && energy <= 0.25) return true;
  const text = requestBody.textContext?.toLowerCase() ?? "";
  return ["tired", "exhausted", "sick", "pain", "stressed", "don’t feel", "don't feel"].some((term) => text.includes(term));
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

function parseDateOnly(value: string | null | undefined) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function isoDate(date: Date) {
  return date.toISOString().slice(0, 10);
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
