import type { AITouchpointGroup } from "./ai-touchpoint-catalog.ts";

type Schema = Record<string, unknown>;

export type AITouchpointResponseMetadata = {
  formatName: string;
  schema: Schema;
};

const textPairSchema: Schema = {
  type: "object",
  additionalProperties: false,
  required: ["label", "summary"],
  properties: {
    label: { type: "string" },
    summary: { type: "string" },
  },
};

const goalCandidateProperties: Schema = {
  id: { type: "string" },
  title: { type: "string" },
  rationale: { type: "string" },
  tracking: { type: "string" },
  timeframeWeeks: { type: "integer", enum: [4, 8, 12] },
  systemImage: { type: "string" },
};

const targetProposalSchema: Schema = {
  type: "object",
  additionalProperties: false,
  required: [
    "id",
    "family",
    "modality",
    "title",
    "summary",
    "proposedDisplayValue",
    "targetValue",
    "unit",
    "rationale",
    "capstone",
  ],
  properties: {
    id: { type: "string" },
    family: {
      type: "string",
      enum: [
        "consistency",
        "modality_presence",
        "capacity_metric",
        "performance_metric",
        "body_trend",
        "capstone",
      ],
    },
    modality: { type: ["string", "null"] },
    title: { type: "string", maxLength: 48 },
    summary: { type: "string", maxLength: 120 },
    proposedDisplayValue: { type: ["string", "null"], maxLength: 18 },
    targetValue: { type: ["number", "null"] },
    unit: { type: ["string", "null"] },
    rationale: { type: "string" },
    capstone: {
      type: "object",
      additionalProperties: false,
      required: ["isCapstone", "whyAppropriate"],
      properties: {
        isCapstone: { type: "boolean" },
        whyAppropriate: { type: ["string", "null"] },
      },
    },
  },
};

const prescriptionSchema: Schema = {
  type: "object",
  additionalProperties: false,
  required: ["warmup", "main", "cooldown", "successCriteria"],
  properties: {
    warmup: { type: "string" },
    main: { type: ["string", "array"], items: { type: "string" } },
    cooldown: { type: "string" },
    successCriteria: { type: "string" },
  },
};

const workoutSuggestionSchema: Schema = {
  type: "object",
  additionalProperties: false,
  required: [
    "title",
    "activityType",
    "durationMinutes",
    "estimatedDistanceKilometers",
    "estimatedElevationMeters",
    "plannedLocationLabel",
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
    estimatedDistanceKilometers: { type: ["number", "null"] },
    estimatedElevationMeters: { type: ["number", "null"] },
    plannedLocationLabel: { type: ["string", "null"] },
    intensityLabel: { type: "string" },
    purpose: { type: "string" },
    prescription: prescriptionSchema,
    fuelingSummary: { type: "string" },
    rationale: { type: "string", maxLength: 96 },
    weeklyImpact: { type: "string", maxLength: 96 },
  },
};

const planningOutputSchemas: Record<string, AITouchpointResponseMetadata> = {
  today_briefing: {
    formatName: "today_briefing",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["headline", "strategyFit", "importance", "weatherInfluence", "fatigueInfluence", "sessionBriefs"],
      properties: {
        headline: { type: "string", maxLength: 80 },
        strategyFit: { type: "string", maxLength: 220 },
        importance: { type: "string", maxLength: 220 },
        weatherInfluence: { type: "string", maxLength: 220 },
        fatigueInfluence: { type: "string", maxLength: 220 },
        sessionBriefs: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: ["workoutID", "preBrief", "postBrief", "weeklyImpact"],
            properties: {
              workoutID: { type: "string" },
              preBrief: { type: "string", maxLength: 220 },
              postBrief: { type: "string", maxLength: 220 },
              weeklyImpact: { type: "string", maxLength: 220 },
            },
          },
        },
      },
    },
  },
  today_workout_action: {
    formatName: "today_workout_action",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["action", "coachRead", "weeklyImpact", "moveOptions", "workoutOptions"],
      properties: {
        action: { type: "string", enum: ["skip", "swap", "move", "adjust"] },
        coachRead: { type: "string", maxLength: 220 },
        weeklyImpact: { type: "string", maxLength: 220 },
        moveOptions: {
          type: "array",
          maxItems: 3,
          items: {
            type: "object",
            additionalProperties: false,
            required: ["date", "rationale"],
            properties: {
              date: { type: "string" },
              rationale: { type: "string", maxLength: 140 },
            },
          },
        },
        workoutOptions: {
          type: "array",
          maxItems: 3,
          items: workoutSuggestionSchema,
        },
      },
    },
  },
  plan_generation: {
    formatName: "planning_plan",
    schema: {
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
                        schemaVersion: { type: "integer" },
                        summary: { type: "string" },
                        warmup: { type: ["string", "object"] },
                        main: { type: ["array", "object"], items: { type: "string" } },
                        cooldown: { type: ["string", "object"] },
                        successCriteria: { type: "string" },
                        equipment: { type: "array", items: { type: "string" } },
                        constraintsApplied: { type: "array", items: { type: "string" } },
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
    },
  },
  plan_edit_repair: {
    formatName: "edit_repair",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["reason", "summary"],
      properties: {
        reason: { type: "string" },
        summary: { type: "string" },
      },
    },
  },
  pending_plan_review: {
    formatName: "pending_plan_review",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["reviewNeeded", "reason", "summary", "confidence", "notes", "mutations"],
      properties: {
        reviewNeeded: { type: "boolean" },
        reason: { type: ["string", "null"] },
        summary: { type: ["string", "null"] },
        confidence: { type: "string", enum: ["low", "medium", "high"] },
        notes: { type: ["string", "null"] },
        mutations: {
          type: "array",
          maxItems: 4,
          items: {
            type: "object",
            additionalProperties: false,
            required: ["type", "workout_id", "fields"],
            properties: {
              type: { type: "string", enum: ["create_workout", "update_workout", "delete_workout"] },
              workout_id: { type: ["string", "null"] },
              fields: {
                type: ["object", "null"],
                additionalProperties: false,
                required: [
                  "scheduled_date",
                  "sequence_order",
                  "activity_type",
                  "title",
                  "duration_minutes",
                  "intensity_label",
                  "purpose",
                  "prescription_json",
                  "fueling_summary",
                ],
                properties: {
                  scheduled_date: { type: ["string", "null"] },
                  sequence_order: { type: ["integer", "null"] },
                  activity_type: { type: ["string", "null"] },
                  title: { type: ["string", "null"] },
                  duration_minutes: { type: ["integer", "null"] },
                  intensity_label: { type: ["string", "null"] },
                  purpose: { type: ["string", "null"] },
                  prescription_json: {
                    type: ["object", "null"],
                    additionalProperties: false,
                    required: ["warmup", "main", "cooldown", "successCriteria"],
                    properties: {
                      warmup: { type: ["string", "null"] },
                      main: { type: ["string", "null"] },
                      cooldown: { type: ["string", "null"] },
                      successCriteria: { type: ["string", "null"] },
                    },
                  },
                  fueling_summary: { type: ["string", "null"] },
                },
              },
            },
          },
        },
      },
    },
  },
  workout_replacements: {
    formatName: "replacement_candidates",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["candidates"],
      properties: {
        candidates: {
          type: "array",
          minItems: 2,
          maxItems: 3,
          items: workoutSuggestionSchema,
        },
      },
    },
  },
  workout_additions: {
    formatName: "workout_addition_candidates",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["candidates"],
      properties: {
        candidates: {
          type: "array",
          minItems: 2,
          maxItems: 3,
          items: workoutSuggestionSchema,
        },
      },
    },
  },
  workout_interpretation: {
    formatName: "workout_interpretation",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["candidate"],
      properties: {
        candidate: workoutSuggestionSchema,
      },
    },
  },
  weekly_targets: {
    formatName: "weekly_targets",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["weeks"],
      properties: {
        weeks: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: ["weeklyPlanID", "targets"],
            properties: {
              weeklyPlanID: { type: "string" },
              targets: {
                type: "array",
                minItems: 1,
                maxItems: 3,
                items: {
                  type: "object",
                  additionalProperties: false,
                  required: [
                    "slotID",
                    "family",
                    "modality",
                    "title",
                    "summary",
                    "proposedDisplayValue",
                    "targetValue",
                    "unit",
                    "comparator",
                    "rationale",
                  ],
                  properties: {
                    slotID: { type: "string" },
                    family: {
                      type: "string",
                      enum: [
                        "planned_session_completion",
                        "modality_session_count",
                        "modality_minutes",
                        "modality_distance",
                        "active_days",
                        "support_modality_presence",
                        "max_gap_guardrail",
                        "minimum_viable_week",
                        "body_weight_logging",
                        "running_pace",
                        "cycling_pace",
                      ],
                    },
                    modality: { type: ["string", "null"] },
                    title: { type: "string", maxLength: 48 },
                    summary: { type: "string", maxLength: 140 },
                    proposedDisplayValue: { type: ["string", "null"], maxLength: 18 },
                    targetValue: { type: ["number", "null"] },
                    unit: { type: ["string", "null"], maxLength: 18 },
                    comparator: { type: "string", enum: ["at_least", "at_most", "between"] },
                    rationale: { type: "string", maxLength: 220 },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
};

export const AI_TOUCHPOINT_RESPONSE_METADATA: Record<AITouchpointGroup, Record<string, AITouchpointResponseMetadata>> = {
  onboarding: {
    generate_summary: {
      formatName: "generate_summary",
      schema: {
        type: "object",
        additionalProperties: false,
        required: ["readback"],
        properties: {
          readback: { type: "string" },
        },
      },
    },
    generate_goal_candidates: {
      formatName: "generate_goal_candidates",
      schema: {
        type: "object",
        additionalProperties: false,
        required: ["candidates"],
        properties: {
          candidates: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["id", "title", "rationale", "tracking", "timeframeWeeks", "systemImage"],
              properties: goalCandidateProperties,
            },
          },
        },
      },
    },
    generate_blended_candidate: {
      formatName: "generate_blended_candidate",
      schema: {
        type: "object",
        additionalProperties: false,
        required: ["id", "title", "rationale", "tracking", "timeframeWeeks", "systemImage"],
        properties: goalCandidateProperties,
      },
    },
    generate_athlete_blueprint: {
      formatName: "generate_athlete_blueprint",
      schema: {
        type: "object",
        additionalProperties: false,
        required: ["coachRead", "athleteArchetype", "currentTrainingState", "physicalBaseline", "historyFindings", "goalFit"],
        properties: {
          coachRead: { type: "string" },
          athleteArchetype: textPairSchema,
          currentTrainingState: textPairSchema,
          physicalBaseline: textPairSchema,
          historyFindings: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["id", "title", "summary"],
              properties: {
                id: { type: "string" },
                title: { type: "string" },
                summary: { type: "string", maxLength: 90 },
              },
            },
          },
          goalFit: {
            type: "object",
            additionalProperties: false,
            required: ["headline", "summary"],
            properties: {
              headline: { type: "string" },
              summary: { type: "string" },
            },
          },
        },
      },
    },
    generate_fitness_strategy_targets: {
      formatName: "generate_fitness_strategy_targets",
      schema: {
        type: "object",
        additionalProperties: false,
        required: ["strategyTargets", "phaseOutline"],
        properties: {
          strategyTargets: {
            type: "array",
            minItems: 3,
            maxItems: 3,
            items: targetProposalSchema,
          },
          phaseOutline: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["id", "phaseTargets"],
              properties: {
                id: { type: "string" },
                phaseTargets: {
                  type: "array",
                  minItems: 3,
                  maxItems: 3,
                  items: targetProposalSchema,
                },
              },
            },
          },
        },
      },
    },
    generate_fitness_strategy: {
      formatName: "generate_fitness_strategy",
      schema: {
        type: "object",
        additionalProperties: false,
        required: ["strategyRead", "goalTargetContext", "fitReasons", "strategyPillars", "phaseOutline", "operatingRhythm"],
        properties: {
          strategyRead: { type: "string" },
          goalTargetContext: {
            type: "object",
            additionalProperties: false,
            required: ["title", "summary"],
            properties: {
              title: { type: "string" },
              summary: { type: "string" },
            },
          },
          fitReasons: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["id", "title", "summary"],
              properties: {
                id: { type: "string" },
                title: { type: "string" },
                summary: { type: "string", maxLength: 90 },
              },
            },
          },
          strategyPillars: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["id", "title", "summary"],
              properties: {
                id: { type: "string" },
                title: { type: "string" },
                summary: { type: "string" },
              },
            },
          },
          phaseOutline: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["id", "name", "objective", "targetSummary"],
              properties: {
                id: { type: "string" },
                name: { type: "string" },
                objective: { type: "string" },
                targetSummary: { type: "string" },
              },
            },
          },
          operatingRhythm: {
            type: ["object", "null"],
            additionalProperties: false,
            required: ["summary", "anchors"],
            properties: {
              summary: { type: "string" },
              anchors: { type: "array", items: { type: "string" } },
            },
          },
        },
      },
    },
  },
  planning: planningOutputSchemas,
};

export function touchpointResponseMetadata(group: AITouchpointGroup, id: string): AITouchpointResponseMetadata | null {
  return AI_TOUCHPOINT_RESPONSE_METADATA[group]?.[id] ?? null;
}
