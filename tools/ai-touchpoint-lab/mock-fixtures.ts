import type { AITouchpointGroup } from "../../supabase/functions/_shared/ai-touchpoint-catalog.ts";

export type TouchpointMockFixture = {
  group: AITouchpointGroup;
  id: string;
  name: string;
  description: string;
  fixture: {
    task: string;
    context: Record<string, unknown>;
    candidates?: Array<Record<string, unknown>>;
  };
};

const goalDiscoveryContext = {
  intent: "findGoal",
  chosenGoal: "Build a repeatable strength and cardio rhythm",
  trainingOptions: ["strength", "running", "cycling", "mobility"],
  infrastructureAccess: {
    gym: true,
    outdoorRoutes: true,
    bike: true,
    treadmill: false,
  },
  goalDirection: "be more athletic and consistent without over-planning",
  challengeStyle: "measurable but not obsessive",
  goalAvoidances: ["daily weigh-ins", "all-out intervals every week"],
  injuryNotes: "Occasional left knee irritation after steep downhill running.",
  goalTimeline: "8 to 12 weeks",
  frequency: "4 days per week",
  sessionLength: "45 to 60 minutes",
  availableDays: ["Monday", "Wednesday", "Friday", "Sunday"],
  availableDayParts: ["morning", "early evening"],
  blockers: ["travel", "late meetings", "weather"],
  blockerNote: "Work travel usually disrupts Thursdays and Fridays.",
  supportStyle: "direct coach with a calm tone",
  badDayFloor: "20 minutes of mobility or an easy walk",
  bodyBaseline: {
    heightCentimeters: 178,
    bodyMassKilograms: 82,
    physiologyReference: "male",
  },
};

const normalizedGoal = {
  title: "Build a stronger 10K base",
  timeframeWeeks: 12,
  priority:
    "Run a comfortable 10K while keeping two strength sessions most weeks.",
  successSignals: [
    "10K completed",
    "two weekly strength exposures",
    "no knee flare-ups",
  ],
};

const onboardingSignals = {
  selectedModalities: ["running", "strength", "mobility"],
  availableDays: ["Monday", "Wednesday", "Friday", "Sunday"],
  sessionLength: "45 to 60 minutes",
  access: ["gym", "outdoor routes"],
  avoidances: ["steep downhill runs", "max-effort intervals"],
  supportStyle: "direct coach with a calm tone",
};

const evidenceSummary = {
  currentTrainingState: "Moderately active, inconsistent week to week",
  trainingIdentity: "Mixed strength and running",
  recentPattern:
    "Three workouts in the last seven days, but no repeated weekly structure.",
  recovery:
    "Sleep is usually adequate, with lower readiness after late work nights.",
  body:
    "Recent body mass data is available but should be treated as context only.",
};

const blueprint = {
  coachRead:
    "You are already training enough to build from, but your weeks need a clearer repeatable shape. The opportunity is to protect a small number of reliable exposures before chasing bigger volume.",
  athleteArchetype: {
    label: "Mixed builder",
    summary:
      "Your history blends strength and running, with consistency more important than specialization right now.",
  },
  currentTrainingState: {
    label: "Active but uneven",
    summary:
      "You can handle regular training, but the week still changes around work and travel.",
  },
  physicalBaseline: {
    label: "Fresh baseline",
    summary:
      "Your onboarding baseline is useful context, but current body trends need more evidence.",
  },
  historyFindings: [
    {
      id: "training_identity",
      title: "Mixed training base",
      summary: "Your recent history includes both running and strength work.",
    },
    {
      id: "consistency_gap",
      title: "Rhythm needs protection",
      summary: "Missed weeks appear more limiting than peak workout quality.",
    },
  ],
  goalFit: {
    headline: "Good fit",
    summary:
      "A 10K base goal fits your selected modalities as long as strength remains protected.",
  },
};

const strategyTargets = [
  {
    id: "strategy_target_1",
    title: "10K completion",
    summary: "Finish one comfortable 10K effort by the end of the strategy.",
    displayValue: "10K",
    metricCategory: "completion",
    targetValue: 1,
    unit: "event",
  },
  {
    id: "strategy_target_2",
    title: "Strength weeks",
    summary: "Complete two strength sessions in most strategy weeks.",
    displayValue: "2x/wk",
    metricCategory: "adherence",
    targetValue: 2,
    unit: "sessions",
  },
  {
    id: "strategy_target_3",
    title: "Run rhythm",
    summary: "Hold at least two running exposures most weeks.",
    displayValue: "2x/wk",
    metricCategory: "adherence",
    targetValue: 2,
    unit: "runs",
  },
];

const acceptedStrategy = {
  title: "Run Base + Strength",
  read:
    "The strategy is to make two runs and two strength sessions repeatable before raising demand. The week should feel sturdy enough to survive travel, weather, or one bad day.",
  goalTargetContext: {
    title: "Comfortable 10K",
    summary:
      "Your goal gives HAYF a clear endurance outcome while strength protects durability.",
  },
  targets: strategyTargets,
  phases: [
    {
      id: "phase_1",
      name: "Base rhythm",
      objective: "Make the weekly running and strength pattern repeatable.",
      targetSummary: "Two runs and two strength sessions in most weeks.",
      targets: strategyTargets.slice(1),
    },
  ],
};

const healthSnapshotSummary = {
  generatedAt: "2026-07-06T08:30:00Z",
  activity: {
    trainingMinutes7Days: 165,
    runningDistance7DaysKilometers: 12.4,
    cyclingDistance7DaysKilometers: 0,
  },
  recovery: {
    sleepDuration7DayAverageHours: 7.1,
    restingHeartRate7DayAverageBPM: 58,
  },
  fitnessHistory: {
    trainingIdentity: {
      label: "Mixed training",
      dominantModalities: ["running", "strength"],
    },
  },
};

const goalRow = {
  id: "goal_mock_10k",
  title: "Build a stronger 10K base",
  goal_kind: "specific_goal",
  target_date: "2026-09-27",
  timeframe_weeks: 12,
  normalized_goal_json: normalizedGoal,
};

const strategyRow = {
  id: "strategy_mock_run_base",
  title: "Run Base + Strength",
  summary: acceptedStrategy.read,
  rationale: acceptedStrategy.read,
  start_date: "2026-07-13",
  target_date: "2026-09-27",
  review_cadence_days: 28,
  context_json: {
    timezone: "Europe/Berlin",
    acceptedAt: "2026-07-07T08:00:00Z",
    planOwnerStartDate: "2026-07-13",
    acceptedStrategy,
  },
};

const blockRow = {
  id: "block_mock_run_base",
  kind: "specific_goal",
  title: "Build a stronger 10K base",
  goal_text: "Run a comfortable 10K while keeping strength consistent.",
  start_date: "2026-07-13",
  target_date: "2026-09-27",
  review_cadence_days: 28,
  context_json: {
    planningRationale:
      "Protect two runs and two strength exposures before adding intensity.",
  },
};

const weeklyPlans = [
  {
    id: "week_mock_2026_07_13",
    week_start_date: "2026-07-13",
    week_end_date: "2026-07-19",
    status: "committed",
    objective: "Protect the first repeatable run and strength rhythm.",
    rhythm_json: {
      priorityOrder: ["easy run", "strength", "long easy run", "mobility"],
      swapRules: [
        "Keep a rest day after the long run.",
        "Move strength before deleting it.",
      ],
    },
  },
  {
    id: "week_mock_2026_07_20",
    week_start_date: "2026-07-20",
    week_end_date: "2026-07-26",
    status: "draft",
    objective:
      "Repeat the structure with one slightly longer aerobic exposure.",
    rhythm_json: {
      priorityOrder: ["base run", "strength", "long run", "mobility"],
      swapRules: [
        "Keep hard days separated.",
        "Use mobility when travel blocks training.",
      ],
    },
  },
];

const plannedWorkouts = [
  {
    id: "workout_mock_run_monday",
    weekly_plan_id: "week_mock_2026_07_13",
    scheduled_date: "2026-07-13",
    sequence_order: 1,
    activity_type: "running",
    title: "Base Run",
    duration_minutes: 40,
    intensity_label: "Low",
    purpose: "Build easy aerobic volume without stressing the knee.",
    prescription_json: {
      warmup: "8 minutes easy",
      main: "28 minutes conversational running",
      cooldown: "4 minutes walk",
      successCriteria: "Finish feeling like you could add 10 minutes.",
    },
    fueling_summary: "Normal meal timing is enough.",
    status: "planned",
    source: "generated",
    planned_location_label: "Lisbon",
    weather_forecast_json: {
      source: "open-meteo",
      fetchedAt: "2026-07-12T18:00:00Z",
      forecastDate: "2026-07-13",
      locationLabel: "Lisbon",
      latitude: 38.72,
      longitude: -9.14,
      temperatureCelsius: 24,
      conditionCode: 2,
      conditionLabel: "Partly cloudy",
      conditionEmoji: "partly cloudy",
      precipitationProbability: 12,
      precipitationMm: 0,
      windKph: 13,
      outdoorRisk: "ok",
    },
  },
  {
    id: "workout_mock_strength_wed",
    weekly_plan_id: "week_mock_2026_07_13",
    scheduled_date: "2026-07-15",
    sequence_order: 1,
    activity_type: "strength",
    title: "Full Body A",
    duration_minutes: 45,
    intensity_label: "Moderate",
    purpose: "Keep strength progressing without compromising the long run.",
    prescription_json: {
      warmup: "Joint prep and light sets",
      main: "Squat pattern, push, pull, hinge, carry",
      cooldown: "Easy mobility",
      successCriteria: "Leave two reps in reserve on main lifts.",
    },
    fueling_summary: "Include protein in the next meal.",
    status: "planned",
    source: "generated",
    planned_location_label: null,
  },
  {
    id: "workout_mock_long_run_sun",
    weekly_plan_id: "week_mock_2026_07_13",
    scheduled_date: "2026-07-19",
    sequence_order: 1,
    activity_type: "running",
    title: "Long Run",
    duration_minutes: 55,
    intensity_label: "Low",
    purpose: "Extend aerobic time while staying below strain.",
    prescription_json: {
      warmup: "10 minutes easy",
      main: "40 minutes relaxed",
      cooldown: "5 minutes walk",
      successCriteria: "Keep the final 10 minutes controlled.",
    },
    fueling_summary: "Hydrate before heading out.",
    status: "planned",
    source: "generated",
    planned_location_label: "Lisbon",
  },
  {
    id: "workout_mock_mobility_tue",
    weekly_plan_id: "week_mock_2026_07_20",
    scheduled_date: "2026-07-21",
    sequence_order: 1,
    activity_type: "mobility",
    title: "Mobility",
    duration_minutes: 25,
    intensity_label: "Low",
    purpose: "Protect the floor when the week gets crowded.",
    prescription_json: {
      warmup: "Breathing reset",
      main: "Hips, ankles, thoracic rotation",
      cooldown: "Easy walk",
      successCriteria: "Move better than when you started.",
    },
    fueling_summary: "No special fueling needed.",
    status: "planned",
    source: "generated",
    planned_location_label: null,
  },
];

const weeklyRhythms = weeklyPlans.map((plan) => ({
  id: plan.id,
  weekly_plan_id: plan.id,
  week_start_date: plan.week_start_date,
  week_end_date: plan.week_end_date,
  objective: plan.objective,
  priority_order_json: plan.rhythm_json.priorityOrder,
  swap_rules_json: plan.rhythm_json.swapRules,
  status: plan.status,
}));

const weatherContext = {
  forecast: {
    source: "open-meteo",
    forecastDate: "2026-07-13",
    locationLabel: "Lisbon",
    temperatureCelsius: 24,
    temperatureUnit: "C",
    conditionLabel: "Partly cloudy",
    precipitationProbability: 12,
    windKph: 13,
    outdoorRisk: "ok",
  },
  shouldAvoidOutdoor: false,
  rationale: "Outdoor training is reasonable.",
};

const masterCoachContext = {
  mode: "master_coach_replan",
  specialistPolicy:
    "Specialist consultations are historical inputs already consolidated into this architecture. Do not request, simulate, or re-run specialists during replans.",
  trainingArchitectureID: "architecture_mock_run_base",
  trainingArchitectureAvailable: true,
  priorityOrder: ["running", "strength", "mobility"],
  modalityRoles: [
    {
      modality: "running",
      role: "primary_driver",
      rationale: "Running is the main goal driver for the 10K base.",
    },
    {
      modality: "strength",
      role: "secondary_support",
      rationale:
        "Strength supports durability and body composition without becoming the main load.",
    },
    {
      modality: "mobility",
      role: "maintenance_exposure",
      rationale: "Mobility protects the bad-day floor and recovery rhythm.",
    },
  ],
  weeklyBudget: {
    target_sessions: 4,
    minimum_viable_sessions: 3,
    hard_sessions: 1,
    recovery_sessions: 1,
  },
  recoveryEnvelope: {
    max_hard_days_per_week: 1,
    spacing_rules: [
      "Keep the long run away from moderate lower-body strength when possible.",
      "Use mobility before adding intensity when the week gets crowded.",
    ],
    bad_day_floor: "20 minutes of mobility or an easy walk",
  },
  conflictAssessment: {
    status: "manageable_tradeoff",
    summary: "Running leads while strength stays protected but bounded.",
    required_tradeoffs: [
      "Do not chase strength volume at the expense of run consistency.",
    ],
  },
  approvedArchetypes: [
    {
      id: "running_base",
      modality: "running",
      purpose: "Easy aerobic base",
      targetAdaptation: "aerobic durability",
      intensityDomain: "low",
      typicalDurationMinutes: { min: 35, max: 60 },
      fatigueCost: "moderate",
      plannerConstraints: [
        "Keep conversational unless explicitly marked quality.",
      ],
    },
    {
      id: "strength_full_body",
      modality: "strength",
      purpose: "Full-body strength support",
      targetAdaptation: "durability and strength retention",
      intensityDomain: "moderate",
      typicalDurationMinutes: { min: 35, max: 50 },
      fatigueCost: "moderate",
      plannerConstraints: ["Leave reps in reserve near run quality days."],
    },
  ],
  guidance: [
    "Preserve the Training Architecture unless the user changes the goal through a dedicated strategy flow.",
    "The user's edits are accepted facts.",
    "Repair only the surrounding two-week execution window.",
  ],
};

const missingArchitectureMasterCoachContext = {
  mode: "master_coach_replan",
  specialistPolicy:
    "Master coach only. Do not request, simulate, or re-run specialists during replans.",
  trainingArchitectureID: null,
  trainingArchitectureAvailable: false,
  guidance: [
    "Use the active fitness strategy and current two-week plan as the governing contract.",
    "The user's edits are accepted facts.",
    "Return no repair when the edited plan remains acceptable.",
  ],
};

const workoutPlanningContext = {
  masterCoachContext,
  block: blockRow,
  strategy: strategyRow,
  homeLocationLabel: "Lisbon",
  scheduledDate: "2026-07-13",
  weekStart: "2026-07-13",
  weeklyPlan: weeklyPlans[0],
  weeklyRhythm: weeklyRhythms[0],
  surroundingWorkouts: plannedWorkouts,
  phases: [
    {
      id: "phase_mock_base",
      name: "Base rhythm",
      sequence_order: 1,
      objective: "Make the weekly running and strength pattern repeatable.",
      start_date: "2026-07-13",
      end_date: "2026-08-09",
    },
  ],
  weeklyRhythms,
  window: {
    start: "2026-07-13",
    end: "2026-07-26",
  },
  weatherContext,
};

export const MOCK_TOUCHPOINT_FIXTURES: TouchpointMockFixture[] = [
  {
    group: "onboarding",
    id: "generate_summary",
    name: "Concrete goal readback",
    description: "Compact onboarding summary context for a specific 10K goal.",
    fixture: {
      task: "generate_summary",
      context: {
        ...goalDiscoveryContext,
        intent: "concreteGoal",
        goalBrief: "Run a comfortable 10K in about three months.",
        goalExperience: "Has run 5K several times but not recently.",
        goalPriority: "durability and consistency",
      },
    },
  },
  {
    group: "onboarding",
    id: "generate_goal_candidates",
    name: "Goal discovery choices",
    description: "Mock selected answers for generating three goal cards.",
    fixture: {
      task: "generate_goal_candidates",
      context: goalDiscoveryContext,
    },
  },
  {
    group: "onboarding",
    id: "generate_blended_candidate",
    name: "Blend strength and 10K",
    description: "Two candidate cards plus the original selected answers.",
    fixture: {
      task: "generate_blended_candidate",
      context: goalDiscoveryContext,
      candidates: [
        {
          id: "candidate_1",
          title: "Finish a comfortable 10K",
          rationale:
            "You want a clear endurance target that still fits your current rhythm.",
          tracking: "10K completion, run frequency",
          timeframeWeeks: 12,
          systemImage: "figure.run",
        },
        {
          id: "candidate_2",
          title: "Hold two strength days weekly",
          rationale:
            "Your week needs a strength anchor that survives busy periods.",
          tracking: "strength sessions, max weekly gap",
          timeframeWeeks: 8,
          systemImage: "dumbbell",
        },
      ],
    },
  },
  {
    group: "onboarding",
    id: "generate_athlete_blueprint",
    name: "Blueprint evidence packet",
    description: "Approved onboarding and HealthKit-derived evidence packet.",
    fixture: {
      task: "generate_athlete_blueprint",
      context: {
        intent: "concreteGoal",
        normalizedGoal,
        feasibleTrainingOptions: ["running", "strength", "mobility"],
        onboardingSignals,
        evidenceSummary,
        sectionSeeds: {
          coachRead: ["training_identity", "consistency_gap"],
          athleteArchetype: {
            id: "mixed_builder",
            canonicalLabel: "Mixed builder",
          },
          currentTrainingState: {
            id: "active_uneven",
            canonicalLabel: "Active but uneven",
          },
          physicalBaseline: {
            id: "fresh_baseline",
            canonicalLabel: "Fresh baseline",
          },
          historyFindings: [
            {
              id: "training_identity",
              evidence: "Running and strength dominate recent workouts.",
            },
            {
              id: "consistency_gap",
              evidence: "Several active weeks are followed by gaps.",
            },
          ],
          goalFit: {
            id: "goal_fit",
            evidence: "Selected modalities match the 10K goal.",
          },
        },
        doNotClaim: [
          "diagnoses",
          "injury recovery status",
          "current body composition trend",
        ],
      },
    },
  },
  {
    group: "onboarding",
    id: "generate_fitness_strategy_targets",
    name: "10K strategy targets",
    description:
      "Target brief and empty target slots for the target generation pass.",
    fixture: {
      task: "generate_fitness_strategy_targets",
      context: {
        intent: "concreteGoal",
        normalizedGoal,
        blueprint,
        onboardingSignals,
        targetBrief: {
          strategyHorizonWeeks: 12,
          allowedModalities: ["running", "strength", "mobility"],
          allowedTargetFamilies: [
            "completion",
            "planned_session_completion",
            "modality_session_count",
            "modality_minutes",
            "max_gap_guardrail",
          ],
          concreteGoalTargets: [
            {
              family: "completion",
              modality: "running",
              label: "Complete a comfortable 10K",
            },
          ],
          constraints: [
            "No steep downhill running",
            "Keep strength as a support modality",
          ],
        },
        targetSlots: [
          { id: "strategy_target_1", scope: "strategy" },
          { id: "strategy_target_2", scope: "strategy" },
          { id: "strategy_target_3", scope: "strategy" },
        ],
        doNotClaim: ["exact race pace", "medical knee status"],
      },
    },
  },
  {
    group: "onboarding",
    id: "generate_fitness_strategy",
    name: "Strategy reveal",
    description:
      "Validated targets and section seeds for the authored strategy pass.",
    fixture: {
      task: "generate_fitness_strategy",
      context: {
        intent: "concreteGoal",
        normalizedGoal,
        blueprint,
        onboardingSignals,
        sectionSeeds: {
          strategyRead: { id: "strategy_read" },
          goalTargetContext: {
            id: "goal_target_context",
            title: "Comfortable 10K",
            summary:
              "Finish one comfortable 10K while keeping strength consistent.",
          },
          fitReasons: [
            {
              id: "selected_modalities",
              evidence: "Running, strength, and mobility are available.",
            },
            {
              id: "history_fit",
              evidence:
                "Recent training already includes running and strength.",
            },
            {
              id: "constraint_fit",
              evidence: "The plan can avoid steep downhill running.",
            },
          ],
          strategyPillars: [
            {
              id: "protect_runs",
              evidence: "Two running exposures support the 10K goal.",
            },
            {
              id: "keep_strength",
              evidence: "Strength supports durability and consistency.",
            },
            {
              id: "use_floor",
              evidence:
                "Mobility protects the week when schedule pressure rises.",
            },
          ],
          targets: strategyTargets,
          phaseOutline: [
            {
              id: "phase_1",
              name: "Base rhythm",
              objective:
                "Make the weekly running and strength pattern repeatable.",
              targetSummary:
                "Two runs and two strength sessions in most weeks.",
            },
          ],
        },
        doNotClaim: ["weekly workout prescriptions", "exact 10K pace"],
      },
    },
  },
  {
    group: "planning",
    id: "today_briefing",
    name: "Planned day briefing",
    description:
      "A compact daily briefing for one planned workout with fresh recovery and weather evidence.",
    fixture: {
      task: "refresh_today_briefing",
      context: {
        localDate: "2026-07-15",
        strategy: {
          id: strategyRow.id,
          title: strategyRow.title,
          summary: strategyRow.summary,
          rationale: strategyRow.rationale,
        },
        phase: acceptedStrategy.phases[0],
        week: {
          id: weeklyPlans[0].id,
          objective: weeklyPlans[0].objective,
          status: weeklyPlans[0].status,
        },
        weather: plannedWorkouts[0].weather_forecast_json,
        fatigue: {
          level: "low",
          confidence: "medium",
          freshness: "fresh",
          factors: [
            "Sleep is close to your recent norm",
            "Recent training volume is within your broader pattern",
          ],
          adjustmentSuggested: false,
        },
        sessions: [{
          workout: plannedWorkouts[1],
          state: "planned",
          actualWorkout: null,
          deviation: null,
          feedback: null,
          debriefStatus: null,
        }],
        tomorrowPreview: plannedWorkouts[2],
        replanReview: {
          status: "none",
          proposalID: null,
          reason: null,
          summary: null,
          mutationCount: 0,
          mutations: [],
        },
        latestSnapshotAt: healthSnapshotSummary.generatedAt,
      },
    },
  },
  {
    group: "planning",
    id: "today_workout_action",
    name: "Reduce today's workout",
    description:
      "Shorter and easier options that preserve today's planned session role.",
    fixture: {
      task: "recommend_today_workout_action",
      context: {
        action: "adjust",
        workout: plannedWorkouts[1],
        masterCoachContext,
        weeklyPlan: weeklyPlans[0],
        surroundingWorkouts: plannedWorkouts,
        weatherContext,
        eligibleMoveDates: ["2026-07-16", "2026-07-17", "2026-07-18"],
        userIntent: "I slept poorly and only have 30 minutes.",
      },
    },
  },
  {
    group: "planning",
    id: "plan_generation",
    name: "Two-week refresh",
    description:
      "Active strategy, visible plans, latest snapshot, and target constraints.",
    fixture: {
      task: "refresh_plan_window",
      context: {
        goal: goalRow,
        strategy: strategyRow,
        block: blockRow,
        weeklyPlans,
        latestSnapshot: {
          generated_at: "2026-07-06T08:30:00Z",
          snapshot_json: healthSnapshotSummary,
        },
        events: [
          {
            id: "event_mock_1",
            event_type: "workout_completed",
            created_at: "2026-07-06T18:30:00Z",
            payload: { title: "Base Run", durationMinutes: 38 },
          },
        ],
        proposals: [],
        windowStart: "2026-07-13",
        trigger: "user",
        force: false,
        weeklyTargetConstraints: {
          "week_mock_2026_07_13": {
            targets: [
              {
                family: "modality_session_count",
                modality: "running",
                targetValue: 2,
              },
              {
                family: "modality_session_count",
                modality: "strength",
                targetValue: 1,
              },
            ],
          },
        },
      },
    },
  },
  {
    group: "planning",
    id: "plan_edit_repair",
    name: "Moved long run repair",
    description:
      "A user moved the long run near strength work and needs a concise repair explanation.",
    fixture: {
      task: "draft_plan_edit_repair",
      context: {
        masterCoachContext: missingArchitectureMasterCoachContext,
        editedWorkout: plannedWorkouts[2],
        edit: {
          type: "move_workout",
          planned_workout_id: "workout_mock_long_run_sun",
          scheduled_date: "2026-07-16",
          sequence_order: 1,
        },
        risks: [
          "Long run now crowds a moderate strength session.",
          "The week loses its easier runway into the longest aerobic exposure.",
        ],
        fallback: {
          reason: "Moving the long run earlier crowds the strength session.",
          summary: "Keep the run but lower the nearby strength dose.",
          mutations: [
            {
              type: "update_workout",
              workout_id: "workout_mock_strength_wed",
              fields: {
                duration_minutes: 35,
                intensity_label: "Low",
              },
            },
          ],
        },
        visibleWorkouts: plannedWorkouts,
      },
    },
  },
  {
    group: "planning",
    id: "pending_plan_review",
    name: "Pending manual edits",
    description:
      "Review a two-week window after user edits are accepted as facts.",
    fixture: {
      task: "create_repair_proposal_for_pending_edits",
      context: {
        masterCoachContext,
        strategy: {
          id: strategyRow.id,
          title: strategyRow.title,
          summary: strategyRow.summary,
          rationale: strategyRow.rationale,
          context: strategyRow.context_json,
        },
        goal: goalRow,
        window: { start: "2026-07-13", end: "2026-07-26" },
        today: "2026-07-14",
        weeklyPlans: weeklyPlans.map((plan) => ({
          id: plan.id,
          status: plan.status,
          weekStartDate: plan.week_start_date,
          weekEndDate: plan.week_end_date,
          objective: plan.objective,
        })),
        workouts: plannedWorkouts.map((workout) => ({
          id: workout.id,
          weeklyPlanID: workout.weekly_plan_id,
          scheduledDate: workout.scheduled_date,
          sequenceOrder: workout.sequence_order,
          activityType: workout.activity_type,
          title: workout.title,
          durationMinutes: workout.duration_minutes,
          intensityLabel: workout.intensity_label,
          purpose: workout.purpose,
          status: workout.status,
        })),
        targets: strategyTargets,
        pendingEvents: [
          {
            id: "event_pending_move",
            eventType: "workout_moved",
            payload: {
              workoutID: "workout_mock_long_run_sun",
              fromDate: "2026-07-19",
              toDate: "2026-07-16",
            },
          },
        ],
        rules: [
          "The user's edits are facts. Do not revert moved, deleted, replaced, added, or availability changes.",
          "Use at most four mutations.",
        ],
      },
    },
  },
  {
    group: "planning",
    id: "workout_replacements",
    name: "Replace rainy base run",
    description:
      "Replacement options for a planned run in a visible two-week window.",
    fixture: {
      task: "recommend_workout_replacements",
      context: {
        masterCoachContext,
        block: blockRow,
        strategy: strategyRow,
        workoutToReplace: plannedWorkouts[0],
        surroundingWorkouts: plannedWorkouts,
        phases: workoutPlanningContext.phases,
        weeklyRhythms,
        userIntent:
          "I do not want to run outside today because my knee feels touchy.",
        window: { start: "2026-07-13", end: "2026-07-26" },
        weatherContext: {
          ...weatherContext,
          shouldAvoidOutdoor: true,
          rationale: "The user explicitly wants to avoid the outdoor run.",
        },
      },
    },
  },
  {
    group: "planning",
    id: "workout_additions",
    name: "Add Friday workout",
    description:
      "Candidate additions for an open day in the active plan window.",
    fixture: {
      task: "recommend_workout_additions",
      context: {
        ...workoutPlanningContext,
        scheduledDate: "2026-07-17",
        userIntent:
          "I unexpectedly have 45 minutes and want something useful but not crushing.",
      },
    },
  },
  {
    group: "planning",
    id: "workout_interpretation",
    name: "Manual ride description",
    description:
      "Natural-language workout text interpreted into a structured workout candidate.",
    fixture: {
      task: "interpret_workout_description",
      context: {
        ...workoutPlanningContext,
        scheduledDate: "2026-07-17",
        workoutToReplace: null,
        userIntent:
          "I want to do a 55 minute easy ride from Lisbon to Belem and back, around 22 km with no hard intervals.",
      },
    },
  },
  {
    group: "planning",
    id: "weekly_targets",
    name: "Weekly targets from plans",
    description:
      "Visible plans, planned workouts, strategy targets, and compact health snapshot.",
    fixture: {
      task: "generate_weekly_plan_targets",
      context: {
        goal: {
          id: goalRow.id,
          title: goalRow.title,
          goalKind: goalRow.goal_kind,
          targetDate: goalRow.target_date,
          timeframeWeeks: goalRow.timeframe_weeks,
          normalizedGoal: goalRow.normalized_goal_json,
        },
        strategy: {
          id: strategyRow.id,
          title: strategyRow.title,
          summary: strategyRow.summary,
          targetDate: strategyRow.target_date,
          acceptedStrategy,
        },
        trainingArchitecture: {
          priorityOrder: masterCoachContext.priorityOrder,
          modalityRoles: masterCoachContext.modalityRoles.map((role) => ({
            modality: role.modality,
            role: role.role,
          })),
          weeklyBudget: masterCoachContext.weeklyBudget,
          plannerConstraints: {
            weekly_plan_rules: [
              "Running leads while strength stays protected but bounded.",
            ],
          },
        },
        strategyTargets: strategyTargets.map((target) => ({
          title: target.title,
          summary: target.summary,
          metricCategory: target.metricCategory,
          targetValue: target.targetValue,
          unit: target.unit,
        })),
        weeks: weeklyPlans.map((plan) => ({
          weeklyPlanID: plan.id,
          status: plan.status,
          weekStartDate: plan.week_start_date,
          weekEndDate: plan.week_end_date,
          objective: plan.objective,
          slots: [1, 2, 3].map((index) => `${plan.id}:target:${index}`),
          workouts: plannedWorkouts
            .filter((workout) => workout.weekly_plan_id === plan.id)
            .map((workout) => ({
              id: workout.id,
              scheduledDate: workout.scheduled_date,
              activityType: workout.activity_type,
              normalizedActivity: workout.activity_type,
              title: workout.title,
              durationMinutes: workout.duration_minutes,
              intensityLabel: workout.intensity_label,
              purpose: workout.purpose,
            })),
        })),
        availableTargetFamilies: [
          "planned_session_completion",
          "modality_session_count",
          "modality_minutes",
          "active_days",
          "support_modality_presence",
          "max_gap_guardrail",
          "minimum_viable_week",
          "running_pace",
        ],
        targetReferenceRules: [
          "Targets must be measurable and computable from planned workouts or completed workouts.",
          "Bad weekly targets include subjective reflection or plan-review tasks.",
          "When trainingArchitecture is present, targets must not introduce modalities outside its priorityOrder or modalityRoles.",
        ],
        healthSnapshotSummary: {
          generatedAt: healthSnapshotSummary.generatedAt,
          hasBodyMass: true,
          runningDistance7d: 12.4,
          cyclingDistance7d: 0,
        },
      },
    },
  },
];
