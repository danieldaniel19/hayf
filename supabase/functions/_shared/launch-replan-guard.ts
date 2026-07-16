type Row = Record<string, unknown>;

export type LaunchReplanGuardResult = {
  mutations: Row[];
  removedCreateCount: number;
};

export function launchPlanReviewRules(weeklyPlans: Row[]) {
  if (!weeklyPlans.some(isLaunchPlan)) return [];
  return [
    "A launch plan is a partial bridge, not a regular training week. Its rhythm modalityTargets and originally scheduled core sessions override Training Architecture weeklyBudget and minimumEffectiveDoseRules.",
    "Never backfill a missed or skipped launch workout later in the week. It still counts as an originally scheduled launch slot for replan scope.",
    "User-added launch workouts are accepted extras. They must not trigger quota filling or expansion toward a regular-week session minimum.",
    "If the user deleted a launch target workout, propose at most one lower-dose replacement in that same target modality when useful. Do not restore the exact workout or add unrelated sessions.",
  ];
}

export function guardLaunchReplanMutations(
  mutations: Row[],
  weeklyPlans: Row[],
  workouts: Row[],
): LaunchReplanGuardResult {
  const launchPlans = new Map(
    weeklyPlans.filter(isLaunchPlan).map((plan) => [String(plan.id), plan]),
  );
  if (launchPlans.size === 0) {
    return { mutations, removedCreateCount: 0 };
  }

  const remainingTargetsByPlan = new Map<string, Map<string, number>>();
  for (const [planID, plan] of launchPlans) {
    const remaining = launchTargetCounts(plan);
    for (const workout of workouts) {
      if (
        String(workout.weekly_plan_id ?? workout.weeklyPlanID ?? "") !== planID
      ) continue;
      if (
        ["deleted", "superseded"].includes(
          String(workout.status ?? "").toLowerCase(),
        )
      ) continue;
      const modality = normalizedModality(
        workout.activity_type ?? workout.activityType,
      );
      if (!remaining.has(modality)) continue;
      remaining.set(modality, Math.max(0, (remaining.get(modality) ?? 0) - 1));
    }
    remainingTargetsByPlan.set(planID, remaining);
  }

  const guarded: Row[] = [];
  let removedCreateCount = 0;
  for (const mutation of mutations) {
    if (String(mutation.type) !== "create_workout") {
      guarded.push(mutation);
      continue;
    }

    const fields = mutation.fields && typeof mutation.fields === "object"
      ? mutation.fields as Row
      : {};
    const planID = String(fields.weekly_plan_id ?? fields.weeklyPlanID ?? "");
    const remaining = remainingTargetsByPlan.get(planID);
    if (!remaining) {
      guarded.push(mutation);
      continue;
    }

    const modality = normalizedModality(
      fields.activity_type ?? fields.activityType,
    );
    const slots = remaining.get(modality) ?? 0;
    if (slots <= 0) {
      removedCreateCount += 1;
      continue;
    }
    remaining.set(modality, slots - 1);
    guarded.push(mutation);
  }

  return { mutations: guarded, removedCreateCount };
}

function isLaunchPlan(plan: Row) {
  const rhythm = objectRow(plan.rhythm_json ?? plan.rhythm);
  return rhythm.programStage === "launch" || rhythm.program_stage === "launch";
}

function launchTargetCounts(plan: Row) {
  const rhythm = objectRow(plan.rhythm_json ?? plan.rhythm);
  const targets = Array.isArray(rhythm.modalityTargets)
    ? rhythm.modalityTargets
    : Array.isArray(rhythm.modality_targets)
    ? rhythm.modality_targets
    : [];
  const counts = new Map<string, number>();
  for (const target of targets) {
    const targetRow = objectRow(target);
    const modality = normalizedModality(targetRow.modality);
    const sessions = Number(targetRow.sessions ?? 0);
    if (!modality || !Number.isFinite(sessions) || sessions <= 0) continue;
    counts.set(
      modality,
      Math.max(counts.get(modality) ?? 0, Math.floor(sessions)),
    );
  }
  return counts;
}

function normalizedModality(value: unknown) {
  const text = String(value ?? "").trim().toLowerCase();
  if (["ride", "rides", "cycling", "bike", "biking"].includes(text)) {
    return "cycling";
  }
  if (["run", "running", "jog", "jogging"].includes(text)) return "running";
  if (["strength", "lifting", "weights", "gym"].includes(text)) {
    return "strength";
  }
  return text;
}

function objectRow(value: unknown): Row {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Row
    : {};
}
