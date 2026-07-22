export const scoreSchemaVersion = "athlete-profile-scores.v1";
export const scoreVersion = "profile-radar-v1.2.0";

export const dimensionOrder = [
  "consistency",
  "momentum",
  "strength",
  "training_base",
  "endurance",
] as const;

export type DimensionKey = typeof dimensionOrder[number];
export type DimensionStatus = "available" | "unavailable";
export type DimensionConfidence = "high" | "medium" | "low" | "insufficient";

export type WorkoutWindowInput = {
  workouts: number;
  totalMinutes: number;
};

export type ProfileScoringRequest = {
  schemaVersion: "athlete-profile-scoring-input.v1";
  evaluatedAt?: string;
  intent: "stayConsistent" | "concreteGoal" | "findGoal";
  normalizedGoal: {
    category: string;
    horizonWeeks: number;
  };
  availability: {
    targetSessionsPerWeek: number;
    availableDaysCount: number;
    ultraFlexible: boolean;
  };
  feasibleModalities: string[];
  evidence: {
    snapshotGeneratedAt: string;
    totalWorkouts: number;
    lastWorkoutAt: string | null;
    windows: {
      days7: WorkoutWindowInput | null;
      days28: WorkoutWindowInput | null;
    };
    consistency: {
      weeksAnalyzed: number;
      activeWeeks: number;
      longestActiveWeekStreak: number;
    };
    modalityMix: Array<{
      modality: string;
      workouts: number;
      shareOfMinutes: number;
      lastWorkoutAt?: string | null;
    }>;
    strengthContinuity: {
      strengthWorkouts90Days: number;
      daysSinceLastStrength: number | null;
    };
    longestWorkouts: Array<{
      modality: string;
      durationMinutes: number;
    }>;
    bestDistanceEfforts: Array<{
      modality: string;
    }>;
  } | null;
};

export type ScoreComponent = {
  key: string;
  value: number | null;
  weight: number;
  status: DimensionStatus;
  evidenceIds: string[];
};

export type ProfileDimensionScore = {
  key: DimensionKey;
  score: number | null;
  status: DimensionStatus;
  confidence: DimensionConfidence;
  components: ScoreComponent[];
  evidenceIds: string[];
};

export type ProfileScoreEnvelope = {
  schemaVersion: typeof scoreSchemaVersion;
  scoreVersion: typeof scoreVersion;
  evaluatedAt: string;
  dimensions: ProfileDimensionScore[];
  sourceSummary: {
    importedWorkoutCount: number;
  };
};

type CurvePoint = readonly [number, number];
type ComponentInput = {
  key: string;
  value: number | null;
  weight: number;
  evidenceIds: string[];
};

const minimumCoverage = 0.7;
const enduranceModalities = new Set([
  "running",
  "cycling",
  "swimming",
  "walking",
  "hiking",
  "rowing",
  "elliptical",
  "cross country skiing",
  "cross_country_skiing",
]);

const activeWeekRateCurve: CurvePoint[] = [[0, 0], [0.25, 30], [0.5, 65], [0.75, 90], [0.9, 100]];
const streakCurve: CurvePoint[] = [[0, 0], [4, 35], [12, 70], [24, 90], [40, 100]];
const cadenceCurve: CurvePoint[] = [[0, 0], [0.5, 60], [0.8, 85], [1, 100]];
const recencyCurve: CurvePoint[] = [[0, 100], [2, 100], [7, 75], [21, 35], [60, 0]];
const loadCurve: CurvePoint[] = [[0, 0], [0.5, 60], [0.8, 90], [1, 100], [1.25, 100], [1.5, 85], [2, 60], [3, 30]];
const historicalSessionsCurve: CurvePoint[] = [[0, 0], [12, 15], [50, 35], [150, 55], [300, 70], [600, 85], [1000, 100]];
const strength90Curve: CurvePoint[] = [[0, 0], [3, 25], [12, 70], [24, 100]];
const strengthRecencyCurve: CurvePoint[] = [[0, 100], [7, 85], [28, 40], [90, 0]];
const strengthShareCurve: CurvePoint[] = [[0, 0], [0.1, 30], [0.25, 60], [0.5, 85], [0.75, 100]];
const enduranceShareCurve: CurvePoint[] = [[0, 0], [0.15, 25], [0.35, 50], [0.6, 75], [0.85, 95], [1, 100]];
const enduranceRecencyCurve: CurvePoint[] = [[0, 100], [7, 90], [28, 60], [60, 30], [120, 0]];
const longestEnduranceCurve: CurvePoint[] = [[0, 0], [30, 25], [60, 55], [120, 85], [240, 100]];
const effortBreadthCurve: CurvePoint[] = [[0, 0], [1, 55], [2, 75], [3, 90], [4, 100]];

export const rubricCurves = {
  activeWeekRate: activeWeekRateCurve,
  longestStreak: streakCurve,
  cadence: cadenceCurve,
  workoutRecency: recencyCurve,
  recentLoad: loadCurve,
  historicalSessions: historicalSessionsCurve,
  strengthSessions90Days: strength90Curve,
  strengthRecency: strengthRecencyCurve,
  strengthShare: strengthShareCurve,
  enduranceShare: enduranceShareCurve,
  enduranceRecency: enduranceRecencyCurve,
  longestEndurance: longestEnduranceCurve,
  bestDistanceEffortBreadth: effortBreadthCurve,
} as const;

export function scoreAthleteProfile(request: ProfileScoringRequest): ProfileScoreEnvelope {
  const evaluatedAt = validDate(request.evaluatedAt) ?? new Date();
  const evidence = request.evidence;
  const fresh = evidence ? isFresh(evidence.snapshotGeneratedAt, evaluatedAt) : false;

  const consistency = scoreConsistency(request, evaluatedAt, fresh);
  const momentum = scoreMomentum(request, evaluatedAt, fresh);
  const strength = scoreStrength(request, evaluatedAt, fresh);
  const endurance = scoreEndurance(request, evaluatedAt);
  const trainingBase = scoreTrainingBase(consistency, momentum, strength, endurance);
  const byKey = new Map<DimensionKey, ProfileDimensionScore>([
    [consistency.key, consistency],
    [momentum.key, momentum],
    [strength.key, strength],
    [trainingBase.key, trainingBase],
    [endurance.key, endurance],
  ]);

  return {
    schemaVersion: scoreSchemaVersion,
    scoreVersion,
    evaluatedAt: evaluatedAt.toISOString(),
    dimensions: dimensionOrder.map((key) => byKey.get(key) ?? unavailable(key, [])),
    sourceSummary: {
      importedWorkoutCount: Math.max(0, Math.round(evidence?.totalWorkouts ?? 0)),
    },
  };
}

function scoreConsistency(request: ProfileScoringRequest, evaluatedAt: Date, fresh: boolean): ProfileDimensionScore {
  const evidence = request.evidence;
  const historicalAvailable = Boolean(evidence && evidence.totalWorkouts >= 4 && evidence.consistency.weeksAnalyzed >= 4);
  const activeWeekRate = historicalAvailable
    ? evidence!.consistency.activeWeeks / Math.max(1, evidence!.consistency.weeksAnalyzed)
    : null;
  const days28 = fresh ? evidence?.windows.days28 : null;
  const cadenceRatio = days28
    ? days28.workouts / Math.max(1, request.availability.targetSessionsPerWeek * 4)
    : null;
  const daysSinceWorkout = daysBetween(evidence?.lastWorkoutAt ?? null, evaluatedAt);
  return weightedDimension("consistency", [
    component("active_week_rate", activeWeekRate === null ? null : interpolate(activeWeekRate, activeWeekRateCurve), 0.30, ["historical_active_weeks"]),
    component("longest_active_week_streak", historicalAvailable ? interpolate(evidence!.consistency.longestActiveWeekStreak, streakCurve) : null, 0.20, ["longest_active_week_streak"]),
    component("imported_workout_recency", daysSinceWorkout === null ? null : interpolate(daysSinceWorkout, recencyCurve), 0.25, ["last_workout_at"]),
    component("recent_cadence_match", cadenceRatio === null ? null : interpolate(cadenceRatio, cadenceCurve), 0.25, ["workouts_28d", "declared_weekly_frequency"]),
  ]);
}

function scoreMomentum(request: ProfileScoringRequest, evaluatedAt: Date, fresh: boolean): ProfileDimensionScore {
  const evidence = request.evidence;
  const days7 = fresh ? evidence?.windows.days7 : null;
  const days28 = fresh ? evidence?.windows.days28 : null;
  const daysSinceWorkout = daysBetween(evidence?.lastWorkoutAt ?? null, evaluatedAt);
  const loadRatio = days7 && days28
    ? days28.totalMinutes > 0 ? days7.totalMinutes / (days28.totalMinutes / 4) : 0
    : null;
  const cadenceRatio = days7
    ? days7.workouts / Math.max(1, request.availability.targetSessionsPerWeek)
    : null;
  return weightedDimension("momentum", [
    component("workout_recency", daysSinceWorkout === null ? null : interpolate(daysSinceWorkout, recencyCurve), 0.70, ["last_workout_at"]),
    component("recent_load_alignment", loadRatio === null ? null : interpolate(loadRatio, loadCurve), 0.20, ["training_minutes_7d", "training_minutes_28d"]),
    component("current_week_cadence", cadenceRatio === null ? null : interpolate(cadenceRatio, cadenceCurve), 0.10, ["workouts_7d", "declared_weekly_frequency"]),
  ]);
}

function scoreStrength(request: ProfileScoringRequest, evaluatedAt: Date, fresh: boolean): ProfileDimensionScore {
  const evidence = request.evidence;
  const historyAvailable = Boolean(evidence && evidence.totalWorkouts >= 8 && evidence.modalityMix.length > 0);
  const strengthMix = evidence?.modalityMix.find((item) => normalizeModality(item.modality) === "strength");
  const absoluteRecency = daysBetween(strengthMix?.lastWorkoutAt ?? null, evaluatedAt);
  const daysSinceStrength = absoluteRecency
    ?? (fresh ? evidence?.strengthContinuity.daysSinceLastStrength ?? null : null);
  return weightedDimension("strength", [
    component("historical_strength_sessions", historyAvailable ? interpolate(strengthMix?.workouts ?? 0, historicalSessionsCurve) : null, 0.40, ["strength_sessions_all_time"]),
    component("historical_strength_share", historyAvailable ? interpolate(strengthMix?.shareOfMinutes ?? 0, strengthShareCurve) : null, 0.25, ["strength_share_of_minutes"]),
    component("strength_sessions_90d", fresh && historyAvailable ? interpolate(evidence!.strengthContinuity.strengthWorkouts90Days, strength90Curve) : null, 0.20, ["strength_sessions_90d"]),
    component("strength_recency", daysSinceStrength !== null
      ? interpolate(daysSinceStrength, strengthRecencyCurve)
      : historyAvailable && (strengthMix?.workouts ?? 0) === 0 ? 0 : null, 0.15, ["last_strength_workout_at"]),
  ]);
}

function scoreEndurance(request: ProfileScoringRequest, evaluatedAt: Date): ProfileDimensionScore {
  const evidence = request.evidence;
  const historyAvailable = Boolean(evidence && evidence.totalWorkouts >= 8 && evidence.modalityMix.length > 0);
  const enduranceMix = evidence?.modalityMix.filter((item) => enduranceModalities.has(normalizeModality(item.modality))) ?? [];
  const enduranceSessions = enduranceMix.reduce((sum, item) => sum + Math.max(0, item.workouts), 0);
  const enduranceShare = enduranceMix.reduce((sum, item) => sum + clamp(item.shareOfMinutes, 0, 1), 0);
  const longestMinutes = Math.max(0, ...(evidence?.longestWorkouts
    .filter((item) => enduranceModalities.has(normalizeModality(item.modality)))
    .map((item) => item.durationMinutes) ?? [0]));
  const effortModalities = new Set((evidence?.bestDistanceEfforts ?? [])
    .map((item) => normalizeModality(item.modality))
    .filter((item) => enduranceModalities.has(item)));
  const lastEnduranceWorkoutAt = latestDate(enduranceMix.map((item) => item.lastWorkoutAt));
  const enduranceRecencyDays = daysBetween(lastEnduranceWorkoutAt, evaluatedAt);
  return weightedDimension("endurance", [
    component("historical_endurance_sessions", historyAvailable ? interpolate(enduranceSessions, historicalSessionsCurve) : null, 0.30, ["endurance_sessions_all_time"]),
    component("endurance_share_of_minutes", historyAvailable ? interpolate(enduranceShare, enduranceShareCurve) : null, 0.25, ["endurance_share_of_minutes"]),
    component("long_session_tolerance", historyAvailable ? interpolate(longestMinutes, longestEnduranceCurve) : null, 0.20, ["longest_endurance_session"]),
    component("distance_effort_breadth", historyAvailable ? interpolate(effortModalities.size, effortBreadthCurve) : null, 0.10, ["best_distance_efforts"]),
    component("endurance_recency", enduranceRecencyDays !== null
      ? interpolate(enduranceRecencyDays, enduranceRecencyCurve)
      : historyAvailable && enduranceSessions === 0 ? 0 : null, 0.15, ["last_endurance_workout_at"]),
  ]);
}

function scoreTrainingBase(
  consistency: ProfileDimensionScore,
  momentum: ProfileDimensionScore,
  strength: ProfileDimensionScore,
  endurance: ProfileDimensionScore,
): ProfileDimensionScore {
  const foundations = [strength, endurance].filter((dimension) => dimension.status === "available");
  const foundationScores = foundations.map((dimension) => dimension.score!).sort((left, right) => right - left);
  const foundationEvidence = unique(foundations.flatMap((dimension) => dimension.evidenceIds));
  return weightedDimension("training_base", [
    fromDimension("consistency_foundation", consistency, 0.35),
    fromDimension("current_continuity", momentum, 0.20),
    component("primary_modality_foundation", foundationScores[0] ?? null, 0.35, foundationEvidence),
    component("complementary_modality_foundation", foundationScores.length > 1 ? foundationScores[1] : null, 0.10, foundationEvidence),
  ]);
}

function weightedDimension(key: DimensionKey, inputs: ComponentInput[]): ProfileDimensionScore {
  const components = inputs.map(materializeComponent);
  const available = inputs.filter((input) => input.value !== null && Number.isFinite(input.value));
  const coverage = available.reduce((sum, input) => sum + input.weight, 0);
  if (coverage + Number.EPSILON < minimumCoverage) return unavailable(key, components);
  const weighted = available.reduce((sum, input) => sum + clamp(input.value!, 0, 100) * input.weight, 0) / coverage;
  const confidence: DimensionConfidence = coverage >= 0.999 ? "high" : coverage >= 0.85 ? "medium" : "low";
  return {
    key,
    score: roundScore(weighted),
    status: "available",
    confidence,
    components,
    evidenceIds: unique(available.flatMap((input) => input.evidenceIds)),
  };
}

function materializeComponent(input: ComponentInput): ScoreComponent {
  return {
    key: input.key,
    value: input.value === null || !Number.isFinite(input.value) ? null : roundScore(input.value),
    weight: input.weight,
    status: input.value === null || !Number.isFinite(input.value) ? "unavailable" : "available",
    evidenceIds: input.evidenceIds,
  };
}

function unavailable(key: DimensionKey, components: ScoreComponent[]): ProfileDimensionScore {
  return { key, score: null, status: "unavailable", confidence: "insufficient", components, evidenceIds: [] };
}

function component(key: string, value: number | null, weight: number, evidenceIds: string[]): ComponentInput {
  return { key, value, weight, evidenceIds };
}

function fromDimension(key: string, dimension: ProfileDimensionScore, weight: number): ComponentInput {
  return component(key, availableScore(dimension), weight, dimension.evidenceIds);
}

function availableScore(dimension: ProfileDimensionScore) {
  return dimension.status === "available" ? dimension.score : null;
}

export function interpolate(value: number, points: CurvePoint[]) {
  if (!Number.isFinite(value) || !points.length) return 0;
  if (value <= points[0][0]) return points[0][1];
  for (let index = 1; index < points.length; index += 1) {
    const [rightX, rightY] = points[index];
    const [leftX, leftY] = points[index - 1];
    if (value <= rightX) {
      const progress = (value - leftX) / Math.max(Number.EPSILON, rightX - leftX);
      return leftY + (rightY - leftY) * progress;
    }
  }
  return points[points.length - 1][1];
}

function isFresh(value: string, evaluatedAt: Date) {
  const generatedAt = validDate(value);
  if (!generatedAt) return false;
  const ageHours = Math.max(0, (evaluatedAt.getTime() - generatedAt.getTime()) / 3_600_000);
  return ageHours <= 36;
}

function daysBetween(value: string | null, evaluatedAt: Date) {
  const date = validDate(value);
  return date ? Math.max(0, (evaluatedAt.getTime() - date.getTime()) / 86_400_000) : null;
}

function validDate(value: string | undefined | null) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function latestDate(values: Array<string | null | undefined>) {
  const dates = values.map(validDate).filter((date): date is Date => date !== null);
  if (!dates.length) return null;
  return dates.reduce((latest, date) => date > latest ? date : latest).toISOString();
}

function normalizeModality(value: string) {
  return value.trim().toLowerCase().replace(/[-_]+/g, " ");
}

function roundScore(value: number) {
  return Math.round(clamp(value, 0, 100));
}

function clamp(value: number, lower: number, upper: number) {
  return Math.min(upper, Math.max(lower, value));
}

function unique(values: string[]) {
  return [...new Set(values)];
}
