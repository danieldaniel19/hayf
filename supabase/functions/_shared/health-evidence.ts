export function healthSnapshotFreshness(snapshot: Record<string, any>, now = new Date()) {
  const generatedAt = snapshot.generatedAt ?? snapshot.generated_at;
  const parsed = typeof generatedAt === "string" ? new Date(generatedAt) : null;
  if (!parsed || Number.isNaN(parsed.getTime())) return { status: "unknown", ageHours: null };
  const ageHours = Math.max(0, Math.round((now.getTime() - parsed.getTime()) / 3_600_000));
  return { status: ageHours <= 36 ? "fresh" : "stale", ageHours };
}

export function workoutContinuityEvidence(snapshot: Record<string, any>, now = new Date()) {
  const lastWorkoutAt = snapshot.workoutLedger?.lastWorkout?.startDate
    ?? snapshot.workout_ledger?.last_workout?.start_date
    ?? null;
  const parsed = typeof lastWorkoutAt === "string" ? new Date(lastWorkoutAt) : null;
  const daysSince = parsed && !Number.isNaN(parsed.getTime())
    ? Math.max(0, Math.floor((now.getTime() - parsed.getTime()) / 86_400_000))
    : null;
  const totalWorkouts = Number(snapshot.workoutLedger?.totalWorkouts ?? snapshot.workout_ledger?.total_workouts ?? 0);
  const historicalBase = totalWorkouts >= 12 ? "established" : totalWorkouts > 0 ? "limited" : "none";
  let state = "insufficient_history";
  let reentryStage = "none";
  if (daysSince !== null && daysSince <= 6) state = "active";
  else if (daysSince !== null && daysSince <= 20) {
    state = "interrupted";
    reentryStage = "short_break";
  } else if (daysSince !== null && daysSince <= 89) {
    state = "reentry";
    reentryStage = "extended_gap";
  } else if (daysSince !== null) {
    state = "reentry";
    reentryStage = "long_layoff";
  }
  return {
    state,
    reentry_stage: reentryStage,
    days_since_last_workout: daysSince,
    last_workout_at: typeof lastWorkoutAt === "string" ? lastWorkoutAt : null,
    historical_base: historicalBase,
    total_imported_workouts: Number.isFinite(totalWorkouts) ? totalWorkouts : 0,
  };
}

export function currentBodyMetricContext(
  summary: Record<string, any> | null,
  latestSampleDate: string | null,
  stableThreshold: number,
  now = new Date(),
) {
  const latest = typeof latestSampleDate === "string" ? new Date(latestSampleDate) : null;
  const sampleAgeDays = latest && !Number.isNaN(latest.getTime())
    ? Math.max(0, Math.floor((now.getTime() - latest.getTime()) / 86_400_000))
    : null;
  const historical = summary
    ? {
      direction: summary.trend ?? null,
      change: typeof summary.change === "number" ? summary.change : null,
      daysCovered: Number(summary.daysCovered ?? 0),
      sampleCount: Number(summary.sampleCount ?? 0),
      firstSampleDate: summary.firstSampleDate ?? null,
      latestSampleDate: summary.latestSampleDate ?? latestSampleDate ?? null,
    }
    : null;
  if (!summary || sampleAgeDays === null || sampleAgeDays > 30) return { current: false, sampleAgeDays, historical };

  const explicitDirection = String(summary.currentTrend ?? "");
  const explicitChange = typeof summary.currentChange === "number" ? summary.currentChange : null;
  const explicitSamples = Number(summary.currentSampleCount ?? 0);
  const explicitDays = Number(summary.currentDaysCovered ?? 0);
  if (["rising", "falling", "stable"].includes(explicitDirection) && explicitChange !== null && explicitSamples >= 3 && explicitDays >= 21) {
    return {
      current: true,
      direction: explicitDirection,
      change: explicitChange,
      daysCovered: explicitDays,
      sampleCount: explicitSamples,
      confidence: summary.currentConfidence ?? "medium",
      latestSampleDate,
      sampleAgeDays,
      historical,
    };
  }

  const recentChange = typeof summary.change90Days === "number" ? summary.change90Days : null;
  const sampleCount = Number(summary.sampleCount ?? 0);
  if (recentChange === null || sampleCount < 4) return { current: false, sampleAgeDays, historical };
  const direction = Math.abs(recentChange) <= stableThreshold ? "stable" : recentChange > 0 ? "rising" : "falling";
  return {
    current: true,
    direction,
    change: recentChange,
    daysCovered: Math.min(90, Number(summary.daysCovered ?? 90)),
    sampleCount,
    confidence: "medium",
    latestSampleDate,
    sampleAgeDays,
    historical,
  };
}
