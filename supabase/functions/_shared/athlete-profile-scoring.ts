export type AthleteProfileScores = Record<string, any>;

const supportedScoreVersions = new Set(["profile-radar-v1.0.0", "profile-radar-v1.1.0", "profile-radar-v1.2.0"]);

export function validAthleteProfileScores(value: unknown): value is AthleteProfileScores {
  if (!isRecord(value)) return false;
  const payload = value;
  if (payload.schemaVersion !== "athlete-profile-scores.v1" || !supportedScoreVersions.has(payload.scoreVersion)) return false;
  if (typeof payload.evaluatedAt !== "string" || Number.isNaN(Date.parse(payload.evaluatedAt))) return false;
  if (!Array.isArray(payload.dimensions) || payload.dimensions.length !== 5) return false;
  const expectedKeys = payload.scoreVersion === "profile-radar-v1.2.0"
    ? ["consistency", "momentum", "strength", "training_base", "endurance"]
    : ["consistency", "momentum", "strength", "goal_readiness", "endurance"];
  if (!payload.dimensions.every((dimension, index) => validDimension(dimension, expectedKeys[index]))) return false;
  if (!isRecord(payload.sourceSummary)) return false;
  return nonnegativeInteger(payload.sourceSummary.importedWorkoutCount);
}

export function enrichBlueprintContext<T extends Record<string, unknown>>(
  context: T,
  _profileScores: AthleteProfileScores | null,
) : T {
  return { ...context };
}

export function mergeBlueprintProfileScores<T extends Record<string, unknown>>(
  authoredOutput: T,
  profileScores: AthleteProfileScores | null,
) : T & { profileScores: AthleteProfileScores | null } {
  return { ...authoredOutput, profileScores };
}

export function redactBlueprintScoringInput(context: Record<string, unknown>) {
  return Object.fromEntries(Object.entries(context).filter(([key]) => key !== "scoringInput"));
}

export function compactProfileScoresForTrace(profileScores: AthleteProfileScores | null) {
  if (!profileScores) return null;
  return {
    scoreVersion: profileScores.scoreVersion,
    status: "success",
    unavailableDimensions: profileScores.dimensions
      .filter((dimension: Record<string, unknown>) => dimension.status === "unavailable")
      .map((dimension: Record<string, unknown>) => dimension.key),
  };
}

function validDimension(value: unknown, expectedKey: string) {
  if (!isRecord(value) || value.key !== expectedKey) return false;
  if (value.status !== "available" && value.status !== "unavailable") return false;
  if (!["high", "medium", "low", "insufficient"].includes(String(value.confidence))) return false;
  if (value.status === "available" && !boundedScore(value.score)) return false;
  if (value.status === "unavailable" && value.score !== null) return false;
  if (!stringArray(value.evidenceIds) || !Array.isArray(value.components)) return false;
  return value.components.every(validComponent);
}

function validComponent(value: unknown) {
  if (!isRecord(value) || typeof value.key !== "string") return false;
  if (value.status !== "available" && value.status !== "unavailable") return false;
  if (typeof value.weight !== "number" || !Number.isFinite(value.weight) || value.weight <= 0 || value.weight > 1) return false;
  if (value.status === "available" && !boundedScore(value.value)) return false;
  if (value.status === "unavailable" && value.value !== null) return false;
  return stringArray(value.evidenceIds);
}

function isRecord(value: unknown): value is Record<string, any> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function boundedScore(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 100;
}

function nonnegativeInteger(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

function stringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string");
}
