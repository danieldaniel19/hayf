export function validateProfileScoringRequest(value: unknown): asserts value is Record<string, unknown> {
  const request = record(value, "Request");
  onlyKeys(request, ["schemaVersion", "evaluatedAt", "intent", "normalizedGoal", "availability", "feasibleModalities", "evidence"], "Request");
  if (request.schemaVersion !== "athlete-profile-scoring-input.v1") throw new Error("Unsupported scoring input schema.");
  enumString(request.intent, ["stayConsistent", "concreteGoal", "findGoal"], "intent");
  optionalDateString(request.evaluatedAt, "evaluatedAt");

  const goal = record(request.normalizedGoal, "normalizedGoal");
  onlyKeys(goal, ["category", "horizonWeeks"], "normalizedGoal");
  stringValue(goal.category, "normalizedGoal.category");
  finiteNumber(goal.horizonWeeks, "normalizedGoal.horizonWeeks", { minimum: 1 });

  const availability = record(request.availability, "availability");
  onlyKeys(availability, ["targetSessionsPerWeek", "availableDaysCount", "ultraFlexible"], "availability");
  finiteNumber(availability.targetSessionsPerWeek, "availability.targetSessionsPerWeek", { minimum: 1 });
  finiteNumber(availability.availableDaysCount, "availability.availableDaysCount", { minimum: 0 });
  if (typeof availability.ultraFlexible !== "boolean") throw new Error("availability.ultraFlexible must be a boolean.");

  const modalities = arrayValue(request.feasibleModalities, "feasibleModalities");
  modalities.forEach((item, index) => stringValue(item, `feasibleModalities[${index}]`));
  if (request.evidence === null) return;

  const evidence = record(request.evidence, "evidence");
  onlyKeys(evidence, [
    "snapshotGeneratedAt", "totalWorkouts", "lastWorkoutAt", "windows", "consistency",
    "modalityMix", "strengthContinuity", "longestWorkouts", "bestDistanceEfforts",
  ], "evidence");
  requiredDateString(evidence.snapshotGeneratedAt, "evidence.snapshotGeneratedAt");
  finiteNumber(evidence.totalWorkouts, "evidence.totalWorkouts", { minimum: 0 });
  nullableDateString(evidence.lastWorkoutAt, "evidence.lastWorkoutAt");

  const windows = record(evidence.windows, "evidence.windows");
  onlyKeys(windows, ["days7", "days28"], "evidence.windows");
  validateWindow(windows.days7, "evidence.windows.days7");
  validateWindow(windows.days28, "evidence.windows.days28");

  const consistency = record(evidence.consistency, "evidence.consistency");
  onlyKeys(consistency, ["weeksAnalyzed", "activeWeeks", "longestActiveWeekStreak"], "evidence.consistency");
  finiteNumber(consistency.weeksAnalyzed, "evidence.consistency.weeksAnalyzed", { minimum: 0 });
  finiteNumber(consistency.activeWeeks, "evidence.consistency.activeWeeks", { minimum: 0 });
  finiteNumber(consistency.longestActiveWeekStreak, "evidence.consistency.longestActiveWeekStreak", { minimum: 0 });

  validateArrayRecords(evidence.modalityMix, "evidence.modalityMix", ["modality", "workouts", "shareOfMinutes", "lastWorkoutAt"], (item, path) => {
    stringValue(item.modality, `${path}.modality`);
    finiteNumber(item.workouts, `${path}.workouts`, { minimum: 0 });
    finiteNumber(item.shareOfMinutes, `${path}.shareOfMinutes`, { minimum: 0, maximum: 1 });
    if (item.lastWorkoutAt !== undefined) nullableDateString(item.lastWorkoutAt, `${path}.lastWorkoutAt`);
  });

  const strength = record(evidence.strengthContinuity, "evidence.strengthContinuity");
  onlyKeys(strength, ["strengthWorkouts90Days", "daysSinceLastStrength"], "evidence.strengthContinuity");
  finiteNumber(strength.strengthWorkouts90Days, "evidence.strengthContinuity.strengthWorkouts90Days", { minimum: 0 });
  nullableNumber(strength.daysSinceLastStrength, "evidence.strengthContinuity.daysSinceLastStrength", { minimum: 0 });

  validateArrayRecords(evidence.longestWorkouts, "evidence.longestWorkouts", ["modality", "durationMinutes"], (item, path) => {
    stringValue(item.modality, `${path}.modality`);
    finiteNumber(item.durationMinutes, `${path}.durationMinutes`, { minimum: 0 });
  });
  validateArrayRecords(evidence.bestDistanceEfforts, "evidence.bestDistanceEfforts", ["modality"], (item, path) => {
    stringValue(item.modality, `${path}.modality`);
  });
}

function validateWindow(value: unknown, path: string) {
  if (value === null) return;
  const window = record(value, path);
  onlyKeys(window, ["workouts", "totalMinutes"], path);
  finiteNumber(window.workouts, `${path}.workouts`, { minimum: 0 });
  finiteNumber(window.totalMinutes, `${path}.totalMinutes`, { minimum: 0 });
}

function validateArrayRecords(
  value: unknown,
  path: string,
  keys: string[],
  validate: (item: Record<string, unknown>, path: string) => void,
) {
  arrayValue(value, path).forEach((entry, index) => {
    const itemPath = `${path}[${index}]`;
    const item = record(entry, itemPath);
    onlyKeys(item, keys, itemPath);
    validate(item, itemPath);
  });
}

function record(value: unknown, path: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${path} must be an object.`);
  return value as Record<string, unknown>;
}

function arrayValue(value: unknown, path: string): unknown[] {
  if (!Array.isArray(value)) throw new Error(`${path} must be an array.`);
  return value;
}

function onlyKeys(value: Record<string, unknown>, allowed: string[], path: string) {
  const unexpected = Object.keys(value).filter((key) => !allowed.includes(key));
  if (unexpected.length) throw new Error(`${path} contains unsupported fields: ${unexpected.join(", ")}.`);
}

function stringValue(value: unknown, path: string): asserts value is string {
  if (typeof value !== "string" || !value.trim()) throw new Error(`${path} must be a non-empty string.`);
}

function enumString(value: unknown, allowed: string[], path: string) {
  stringValue(value, path);
  if (!allowed.includes(value)) throw new Error(`${path} is unsupported.`);
}

function finiteNumber(value: unknown, path: string, bounds: { minimum?: number; maximum?: number } = {}) {
  if (typeof value !== "number" || !Number.isFinite(value)) throw new Error(`${path} must be a finite number.`);
  if (bounds.minimum !== undefined && value < bounds.minimum) throw new Error(`${path} is below its minimum.`);
  if (bounds.maximum !== undefined && value > bounds.maximum) throw new Error(`${path} is above its maximum.`);
}

function nullableNumber(value: unknown, path: string, bounds: { minimum?: number; maximum?: number } = {}) {
  if (value !== null) finiteNumber(value, path, bounds);
}

function requiredDateString(value: unknown, path: string) {
  stringValue(value, path);
  if (Number.isNaN(Date.parse(value))) throw new Error(`${path} must be an ISO-8601 timestamp.`);
}

function optionalDateString(value: unknown, path: string) {
  if (value !== undefined) requiredDateString(value, path);
}

function nullableDateString(value: unknown, path: string) {
  if (value !== null) requiredDateString(value, path);
}
