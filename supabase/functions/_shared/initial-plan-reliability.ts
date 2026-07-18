type Row = Record<string, unknown>;

export type InitialPlanWorkout = {
  scheduledDate: string;
  sequenceOrder: number;
  archetypeId: string | null;
  activityType: string;
  title: string;
  durationMinutes: number;
  intensityLabel: string;
  purpose: string;
  prescription: Row;
  fuelingSummary: string;
};

export type InitialPlanRhythm = {
  weekStartDate: string;
  weekEndDate: string;
  programStage: "launch" | "program";
  programWeekNumber: number | null;
  programStartDate: string;
  weekContext: { strategyExplanation: string };
  modalityTargets: Array<{ modality: string; sessions: number }>;
  objective: string;
  priorityOrder: string[];
  hardEasyDistribution: Row;
  badDayFloor: string;
  swapRules: string[];
  workouts: InitialPlanWorkout[];
};

export type InitialPlan = {
  block: {
    kind:
      | "specific_goal"
      | "goal_discovery_chosen"
      | "consistency"
      | "re_entry"
      | "maintenance";
    title: string;
    goalText: string;
    startDate: string;
    targetDate: string | null;
    reviewCadenceDays: number;
    context: Row;
  };
  phases: Row[];
  rhythms: InitialPlanRhythm[];
};

export type InitialRhythmSpec = {
  programStage: "launch" | "program";
  programWeekNumber: number | null;
  weekStartDate: string;
  maximumSessions?: number;
};

export type InitialPlanFallbackInput = {
  kind: InitialPlan["block"]["kind"];
  blockTitle: string;
  goalText: string;
  targetDate: string | null;
  reviewCadenceDays: number;
  programStartDate: string;
  ownerStartDate: string;
  rhythmSpecs: InitialRhythmSpec[];
  availableDays: string[];
  priorityModalities: string[];
  sessionsPerProgramWeek: number;
  badDayFloor?: string | null;
  architecture?: Row | null;
};

export function repairInitialPlanPrescriptions<T extends InitialPlan>(plan: T) {
  let repairedWorkoutCount = 0;
  const repaired = {
    ...plan,
    rhythms: plan.rhythms.map((rhythm) => ({
      ...rhythm,
      workouts: rhythm.workouts.map((workout) => {
        if (isVersionTwoPrescription(workout.prescription)) return workout;
        repairedWorkoutCount += 1;
        return {
          ...workout,
          prescription: deterministicVersionTwoPrescription(workout, rhythm),
        };
      }),
    })),
  } as T;
  return { plan: repaired, repairedWorkoutCount };
}

export function buildDeterministicInitialPlan(
  input: InitialPlanFallbackInput,
): InitialPlan {
  const priorityModalities = unique(
    input.priorityModalities.map(normalizedModality).filter(Boolean),
  );
  const modalities = priorityModalities.length > 0
    ? priorityModalities
    : ["strength"];
  const availableDays = new Set(
    input.availableDays.map((day) => day.trim().toLowerCase()),
  );
  const programSessions = clamp(
    Math.round(input.sessionsPerProgramWeek || 3),
    1,
    7,
  );
  const approvedArchetypes = arrayRows(input.architecture?.approved_archetypes);

  const rhythms = input.rhythmSpecs.map((spec) => {
    const dates = weekDates(spec.weekStartDate).filter((date) => {
      if (spec.programStage === "launch" && date < input.ownerStartDate) {
        return false;
      }
      return availableDays.size === 0 || availableDays.has(weekday(date));
    });
    const desiredSessions = spec.programStage === "launch"
      ? clamp(spec.maximumSessions ?? Math.min(2, dates.length), 1, 2)
      : programSessions;
    const sessionCount = Math.max(
      1,
      Math.min(desiredSessions, dates.length || 1),
    );
    const usableDates = dates.length > 0 ? dates : [spec.weekStartDate];
    const workouts = Array.from({ length: sessionCount }, (_, index) => {
      const modality = modalities[index % modalities.length];
      const archetype = approvedArchetypes.find((candidate) =>
        normalizedModality(candidate.modality) === modality &&
        !/recover|restorative/i.test(
          `${candidate.id ?? ""} ${candidate.purpose ?? ""}`,
        )
      );
      return deterministicWorkout(
        modality,
        usableDates[Math.min(index, usableDates.length - 1)],
        index + 1,
        archetype,
      );
    });
    const targetCounts = countModalities(workouts);
    const stageLabel = spec.programStage === "launch"
      ? "Launch"
      : `Program Week ${spec.programWeekNumber ?? 1}`;
    const rhythm: InitialPlanRhythm = {
      weekStartDate: spec.weekStartDate,
      weekEndDate: addDays(spec.weekStartDate, 6),
      programStage: spec.programStage,
      programWeekNumber: spec.programWeekNumber,
      programStartDate: input.programStartDate,
      weekContext: {
        strategyExplanation: spec.programStage === "launch"
          ? "Start with a short, manageable bridge into the full program."
          : "Build a repeatable week with controlled sessions and room to recover.",
      },
      modalityTargets: [...targetCounts].map(([modality, sessions]) => ({
        modality,
        sessions,
      })),
      objective: spec.programStage === "launch"
        ? "Begin with manageable training."
        : "Build a repeatable training rhythm.",
      priorityOrder: modalities,
      hardEasyDistribution: { easy: workouts.length, moderate: 0, hard: 0 },
      badDayFloor: input.badDayFloor?.trim() || "10 minutes of easy movement",
      swapRules: [
        "If recovery is poor, shorten the session and keep the effort easy.",
      ],
      workouts,
    };
    rhythm.workouts = rhythm.workouts.map((workout) => ({
      ...workout,
      prescription: deterministicVersionTwoPrescription(
        workout,
        rhythm,
        stageLabel,
      ),
    }));
    return rhythm;
  });

  return {
    block: {
      kind: input.kind,
      title: input.blockTitle,
      goalText: input.goalText,
      startDate: input.programStartDate,
      targetDate: input.targetDate,
      reviewCadenceDays: input.reviewCadenceDays,
      context: { reliabilityFallback: true },
    },
    phases: [],
    rhythms,
  };
}

function deterministicWorkout(
  modality: string,
  scheduledDate: string,
  sequenceOrder: number,
  archetype: Row | undefined,
): InitialPlanWorkout {
  const durationMinutes = archetypeDuration(archetype);
  const copy = workoutCopy(modality);
  return {
    scheduledDate,
    sequenceOrder,
    archetypeId: typeof archetype?.id === "string" ? archetype.id : null,
    activityType: modality,
    title: copy.title,
    durationMinutes,
    intensityLabel: "Easy",
    purpose: copy.purpose,
    prescription: {},
    fuelingSummary: modality === "strength"
      ? "Protein + carbs"
      : "Carbs + water",
  };
}

function deterministicVersionTwoPrescription(
  workout: InitialPlanWorkout,
  rhythm: InitialPlanRhythm,
  stageLabel?: string,
): Row {
  const modality = normalizedModality(
    `${workout.activityType} ${workout.title}`,
  );
  const stage = stageLabel ??
    (rhythm.programStage === "launch"
      ? "Launch"
      : `Program Week ${rhythm.programWeekNumber ?? 1}`);
  const whyToday =
    `${stage} uses this controlled session to build rhythm while protecting recovery.`;
  const constraintsApplied = [
    "Keep the effort controlled",
    "Finish with enough energy for the next session",
  ];

  if (modality === "strength") {
    return {
      schemaVersion: 2,
      summary: "A controlled full body strength session.",
      whyToday,
      warmup: stepGroup("Warm up", "Prepare the main movement patterns.", 8, [
        "Five minutes of easy movement",
        "Two light practice sets",
      ]),
      main: {
        title: "Strength work",
        description: "Use clean, repeatable reps and stop before form slows.",
        blocks: [
          strengthBlock("Squat pattern", "Dumbbells or machine"),
          strengthBlock("Push pattern", "Dumbbells or machine"),
          strengthBlock("Pull pattern", "Cable or dumbbells"),
        ],
      },
      cooldown: stepGroup("Cool down", "Bring the effort down gradually.", 5, [
        "Easy walk",
        "Light mobility",
      ]),
      successCriteria:
        "Complete every set with clean form and energy in reserve.",
      equipment: ["Dumbbells or machines"],
      constraintsApplied,
    };
  }

  if (modality === "ride" || modality === "run") {
    const riding = modality === "ride";
    const activity = riding ? "ride" : "run";
    return {
      schemaVersion: 2,
      summary: `An easy aerobic ${activity} built for repeatable volume.`,
      whyToday,
      warmup: stepGroup("Warm up", `Ease into the ${activity}.`, 10, [
        `Start the ${activity} gently`,
        "Settle into relaxed breathing",
      ]),
      main: {
        title: "Aerobic work",
        description: "Stay at a conversational effort throughout.",
        blocks: [{
          kind: "steady",
          title: "Steady block",
          description: "Use smooth, comfortable movement.",
          durationMinutes: Math.max(10, workout.durationMinutes - 15),
          distanceKilometers: null,
          elevationMeters: null,
          target: "Conversational effort",
          terrainNotes: null,
        }],
      },
      cooldown: stepGroup("Cool down", "Finish at a very easy effort.", 5, [
        `Ease down the ${activity}`,
        "Check how your body feels",
      ]),
      successCriteria:
        "Finish feeling able to repeat an easy session tomorrow.",
      equipment: riding ? ["Bike"] : ["Running shoes"],
      constraintsApplied,
    };
  }

  return {
    schemaVersion: 2,
    summary: "A low load session that keeps the week moving.",
    whyToday,
    warmup: stepGroup("Warm up", "Start with gentle movement.", 5, [
      "Move easily",
    ]),
    main: {
      title: "Easy movement",
      description: "Move through a comfortable range without adding fatigue.",
      blocks: [{
        kind: "mobilityRecovery",
        title: "Mobility flow",
        description: "Use calm, comfortable movements.",
        durationMinutes: Math.max(10, workout.durationMinutes - 8),
        movementFocus: "hips, spine, and breathing",
        steps: ["Easy mobility", "Calm breathing"],
      }],
    },
    cooldown: stepGroup("Cool down", "Finish calmly.", 3, ["Easy breathing"]),
    successCriteria: "Finish feeling better than you started.",
    equipment: [],
    constraintsApplied,
  };
}

function isVersionTwoPrescription(value: Row) {
  const warmup = objectRow(value?.warmup);
  const main = objectRow(value?.main);
  const cooldown = objectRow(value?.cooldown);
  return Number(value?.schemaVersion) === 2 &&
    nonEmpty(value?.summary) &&
    nonEmpty(value?.whyToday) &&
    nonEmpty(value?.successCriteria) &&
    nonEmpty(warmup.title) &&
    nonEmpty(warmup.description) &&
    Array.isArray(warmup.steps) && warmup.steps.length > 0 &&
    nonEmpty(main.title) &&
    nonEmpty(main.description) &&
    Array.isArray(main.blocks) && main.blocks.length > 0 &&
    nonEmpty(cooldown.title) &&
    nonEmpty(cooldown.description) &&
    Array.isArray(cooldown.steps) && cooldown.steps.length > 0 &&
    Array.isArray(value?.equipment) &&
    Array.isArray(value?.constraintsApplied);
}

function objectRow(value: unknown): Row {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Row
    : {};
}

function nonEmpty(value: unknown) {
  return typeof value === "string" && value.trim().length > 0;
}

function strengthBlock(title: string, equipment: string) {
  return {
    kind: "strengthExercise",
    title,
    description: `Perform ${title.toLowerCase()} with controlled reps.`,
    exerciseName: title,
    sets: 2,
    reps: "8 to 10",
    restSeconds: 90,
    effortTarget: "Finish with two good reps left",
    coachingCue: "Move smoothly and keep each rep consistent.",
    machineOrEquipment: equipment,
    alternatives: [{
      exerciseName: `${title} alternative`,
      equipment: "Body weight or dumbbells",
      notes: "Use the alternative when the main equipment is unavailable.",
    }],
  };
}

function stepGroup(
  title: string,
  description: string,
  durationMinutes: number,
  steps: string[],
) {
  return { title, description, durationMinutes, steps };
}

function workoutCopy(modality: string) {
  if (modality === "ride") {
    return { title: "Base Ride", purpose: "Build aerobic rhythm" };
  }
  if (modality === "run") {
    return { title: "Base Run", purpose: "Build aerobic rhythm" };
  }
  if (modality === "strength") {
    return { title: "Full Body A", purpose: "Build durable strength" };
  }
  return { title: "Easy Training", purpose: "Build a repeatable rhythm" };
}

function archetypeDuration(archetype: Row | undefined) {
  const duration = archetype?.typical_duration_minutes;
  if (typeof duration === "number" && Number.isFinite(duration)) {
    return clamp(Math.round(duration), 20, 90);
  }
  if (duration && typeof duration === "object" && !Array.isArray(duration)) {
    const row = duration as Row;
    const preferred = Number(row.typical ?? row.target ?? row.min ?? row.max);
    if (Number.isFinite(preferred)) return clamp(Math.round(preferred), 20, 90);
  }
  return 45;
}

function countModalities(workouts: InitialPlanWorkout[]) {
  const counts = new Map<string, number>();
  for (const workout of workouts) {
    const modality = normalizedModality(workout.activityType);
    counts.set(modality, (counts.get(modality) ?? 0) + 1);
  }
  return counts;
}

function normalizedModality(value: unknown) {
  const text = String(value ?? "").trim().toLowerCase();
  if (/cycl|bike|ride/.test(text)) return "ride";
  if (/run|jog/.test(text)) return "run";
  if (/strength|lift|gym|weight/.test(text)) return "strength";
  if (/swim/.test(text)) return "swim";
  if (/row/.test(text)) return "row";
  return text.replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
}

function weekDates(weekStartDate: string) {
  return Array.from(
    { length: 7 },
    (_, offset) => addDays(weekStartDate, offset),
  );
}

function addDays(date: string, days: number) {
  const parsed = new Date(`${date}T00:00:00.000Z`);
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().slice(0, 10);
}

function weekday(date: string) {
  return [
    "sunday",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
  ][
    new Date(`${date}T00:00:00.000Z`).getUTCDay()
  ];
}

function arrayRows(value: unknown): Row[] {
  return Array.isArray(value)
    ? value.filter((entry): entry is Row =>
      Boolean(entry) && typeof entry === "object" && !Array.isArray(entry)
    )
    : [];
}

function unique(values: string[]) {
  return [...new Set(values)];
}

function clamp(value: number, minimum: number, maximum: number) {
  return Math.max(minimum, Math.min(maximum, value));
}
