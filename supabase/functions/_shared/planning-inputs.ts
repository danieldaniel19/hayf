const weekdays = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
] as const;

const weekdayAliases: Record<string, string> = {
  mon: "monday",
  monday: "monday",
  tue: "tuesday",
  tues: "tuesday",
  tuesday: "tuesday",
  wed: "wednesday",
  weds: "wednesday",
  wednesday: "wednesday",
  thu: "thursday",
  thur: "thursday",
  thurs: "thursday",
  thursday: "thursday",
  fri: "friday",
  friday: "friday",
  sat: "saturday",
  saturday: "saturday",
  sun: "sunday",
  sunday: "sunday",
};

const dayPartAliases: Record<string, string> = {
  am: "morning",
  morning: "morning",
  mornings: "morning",
  noon: "midday",
  midday: "midday",
  afternoon: "afternoon",
  afternoons: "afternoon",
  pm: "afternoon",
  evening: "evening",
  evenings: "evening",
  night: "evening",
};

export function parseTimeframeWeeks(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return Math.round(value);
  }

  if (typeof value === "string") {
    const text = value.trim().toLowerCase();
    const match = text.match(/^\d{1,3}$/) ?? text.match(/(?:^|\b)(\d{1,3})\s*[- ]?\s*(?:weeks?|wks?)(?:\b|$)/);
    if (!match) return null;
    const parsed = Number(match[1] ?? match[0]);
    return Number.isFinite(parsed) && parsed > 0 ? Math.round(parsed) : null;
  }

  if (value && typeof value === "object" && !Array.isArray(value)) {
    const object = value as Record<string, unknown>;
    for (const key of ["weeks", "weekCount", "week_count", "value", "summary", "title", "label"]) {
      const parsed = parseTimeframeWeeks(object[key]);
      if (parsed !== null) return parsed;
    }
  }

  return null;
}

export function timeframeWeeksFromPlanningInputs(
  strategy: Record<string, unknown>,
  selectedAnswers: Record<string, unknown>,
): number | null {
  const snapshotItems = Array.isArray(strategy.snapshotItems)
    ? strategy.snapshotItems.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object" && !Array.isArray(item))
    : [];
  const timeframeItem = snapshotItems.find((item) => String(item.id ?? "").trim().toLowerCase() === "timeframe");
  const chosenGoal = objectValue(selectedAnswers.chosenGoal);
  const chosenTimeline = chosenGoal ? chosenGoal.timeline : null;

  for (const candidate of [
    selectedAnswers.goalTimelineWeeks,
    selectedAnswers.goal_timeline_weeks,
    selectedAnswers.goalTimeline,
    selectedAnswers.goal_timeline,
    chosenTimeline,
    timeframeItem?.value,
  ]) {
    const parsed = parseTimeframeWeeks(candidate);
    if (parsed !== null) return parsed;
  }
  return null;
}

export function availableDaysFromPlanningInputs(selectedAnswers: Record<string, unknown>): string[] {
  const availability = objectValue(selectedAnswers.availability);
  const onboardingSignals = objectValue(selectedAnswers.onboardingSignals ?? selectedAnswers.onboarding_signals);
  return normalizedValues(
    firstArray([
      selectedAnswers.availableDays,
      selectedAnswers.available_days,
      availability?.days,
      onboardingSignals?.availableDays,
      onboardingSignals?.available_days,
    ]),
    weekdayAliases,
    weekdays,
  );
}

export function availableDayPartsFromPlanningInputs(selectedAnswers: Record<string, unknown>): string[] {
  const availability = objectValue(selectedAnswers.availability);
  const onboardingSignals = objectValue(selectedAnswers.onboardingSignals ?? selectedAnswers.onboarding_signals);
  return normalizedValues(
    firstArray([
      selectedAnswers.availableDayParts,
      selectedAnswers.available_day_parts,
      availability?.dayParts,
      availability?.day_parts,
      onboardingSignals?.availableDayParts,
      onboardingSignals?.available_day_parts,
    ]),
    dayPartAliases,
    ["morning", "midday", "afternoon", "evening"],
  );
}

export function badDayFloorFromPlanningInputs(selectedAnswers: Record<string, unknown>): string | null {
  for (const candidate of [
    selectedAnswers.badDayFloor,
    selectedAnswers.bad_day_floor,
    selectedAnswers.floorSummary,
    selectedAnswers.floor_summary,
    selectedAnswers.floor,
    objectValue(selectedAnswers.onboardingSignals ?? selectedAnswers.onboarding_signals)?.badDayFloor,
  ]) {
    const text = humanText(candidate);
    if (text) return text;
  }
  return null;
}

function normalizedValues(
  values: unknown[],
  aliases: Record<string, string>,
  order: readonly string[],
): string[] {
  const normalized = new Set<string>();
  for (const value of values) {
    const text = humanText(value)?.toLowerCase().replace(/[._-]+/g, " ").replace(/\s+/g, " ").trim();
    if (!text) continue;
    const canonical = aliases[text] ?? aliases[text.replace(/s$/, "")];
    if (canonical) normalized.add(canonical);
  }
  return order.filter((value) => normalized.has(value));
}

function firstArray(candidates: unknown[]): unknown[] {
  return candidates.find(Array.isArray) as unknown[] | undefined ?? [];
}

function humanText(value: unknown): string | null {
  if (typeof value === "string") {
    const text = value.replace(/\s+/g, " ").trim();
    return text || null;
  }
  if (value && typeof value === "object" && !Array.isArray(value)) {
    const object = value as Record<string, unknown>;
    for (const key of ["summary", "title", "label", "text", "value"]) {
      const text = humanText(object[key]);
      if (text) return text;
    }
  }
  return null;
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}
