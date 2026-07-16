export type TodayFatigueInput = {
  freshness: "fresh" | "stale" | "missing" | string;
  evidenceAt: string | null;
  sleepHoursLastNight: number | null;
  averageSleepHours14Days: number | null;
  currentVsNinetyDayMinutesRatio: number | null;
  hasHRVBaseline: boolean;
  hasRestingHeartRateBaseline: boolean;
  hardSessionToday: boolean;
};

export function todayDayState(sessions: Array<{ state: string }>) {
  if (sessions.length === 0) return "rest";
  const completed =
    sessions.filter((session) =>
      session.state === "completed" || session.state === "skipped"
    ).length;
  if (completed === sessions.length) return "completed";
  if (completed > 0) return "mixed";
  return "planned";
}

export function workoutsForTodayPlan<
  T extends {
    weekly_plan_id?: string | null;
    weeklyPlanID?: string | null;
  },
>(workouts: T[], weeklyPlanID: string | null | undefined) {
  if (!weeklyPlanID) return [];
  return workouts.filter((workout) =>
    String(workout.weekly_plan_id ?? workout.weeklyPlanID ?? "") ===
      String(weeklyPlanID)
  );
}

export function explanatoryStrategyTitle(
  explicitTitle: string | null | undefined,
  goalTargetTitle: string | null | undefined,
  fallbackTitle: string,
) {
  const explicit = explicitTitle?.trim() ?? "";
  const target = goalTargetTitle?.trim() ?? "";
  const isGeneric = ["Goal Build Strategy", "Fitness Strategy"].includes(
    explicit,
  );
  if (explicit && !isGeneric) return explicit;
  if (target) return target;
  return explicit || fallbackTitle;
}

export function deriveTodayFatigueEstimate(input: TodayFatigueInput) {
  if (input.freshness === "missing") {
    return {
      level: "unknown",
      confidence: "low",
      freshness: "missing",
      factors: ["No recent recovery snapshot"],
      evidenceAt: null,
      adjustmentSuggested: false,
    };
  }
  if (input.freshness !== "fresh") {
    return {
      level: "unknown",
      confidence: "low",
      freshness: input.freshness,
      factors: ["Recovery evidence is not recent enough"],
      evidenceAt: input.evidenceAt,
      adjustmentSuggested: false,
    };
  }

  const factors: string[] = [];
  let strainSignals = 0;
  if (input.sleepHoursLastNight != null) {
    if (
      input.sleepHoursLastNight < 6 ||
      (input.averageSleepHours14Days != null &&
        input.sleepHoursLastNight <= input.averageSleepHours14Days - 1.25)
    ) {
      factors.push("Sleep was meaningfully below your recent norm");
      strainSignals += 2;
    } else if (
      input.averageSleepHours14Days != null &&
      input.sleepHoursLastNight < input.averageSleepHours14Days - 0.5
    ) {
      factors.push("Sleep was a little below your recent norm");
      strainSignals += 1;
    } else {
      factors.push("Sleep is close to your recent norm");
    }
  }
  if (
    input.currentVsNinetyDayMinutesRatio != null &&
    input.currentVsNinetyDayMinutesRatio >= 1.35
  ) {
    factors.push("Recent training volume is elevated");
    strainSignals += 1;
  } else if (input.currentVsNinetyDayMinutesRatio != null) {
    factors.push("Recent training volume is within your broader pattern");
  }
  if (input.hasHRVBaseline) factors.push("HRV baseline is available");
  if (input.hasRestingHeartRateBaseline) {
    factors.push("Resting heart-rate baseline is available");
  }

  const level = strainSignals >= 2
    ? "high"
    : strainSignals === 1
    ? "moderate"
    : "low";
  return {
    level,
    confidence: factors.length >= 3 ? "medium" : "low",
    freshness: "fresh",
    factors: factors.slice(0, 4),
    evidenceAt: input.evidenceAt,
    adjustmentSuggested: input.hardSessionToday && level === "high",
  };
}

export async function todayInputFingerprint(value: unknown) {
  const bytes = new TextEncoder().encode(JSON.stringify(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

export function isTodayBriefingCacheHit(
  cached: {
    input_fingerprint?: string;
    briefing_json?: { authored?: unknown };
    generation_json?: { status?: string };
  } | null,
  fingerprint: string,
) {
  return cached?.input_fingerprint === fingerprint &&
    Boolean(cached.briefing_json?.authored) &&
    cached.generation_json?.status !== "fallback";
}
