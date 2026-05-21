import { createClient } from "jsr:@supabase/supabase-js@2";

type OnboardingTask =
  | "generate_summary"
  | "generate_goal_candidates"
  | "generate_blended_candidate"
  | "generate_athlete_blueprint"
  | "generate_fitness_strategy_targets"
  | "generate_fitness_strategy";

type OnboardingAIRequest = {
  task: OnboardingTask;
  context: Record<string, unknown>;
  candidates?: Array<Record<string, unknown>>;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const taskSchemas: Record<OnboardingTask, Record<string, unknown>> = {
  generate_summary: {
    type: "object",
    additionalProperties: false,
    required: ["readback"],
    properties: {
      readback: { type: "string" },
    },
  },
  generate_goal_candidates: {
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
          properties: goalCandidateProperties(),
        },
      },
    },
  },
  generate_blended_candidate: {
    type: "object",
    additionalProperties: false,
    required: ["id", "title", "rationale", "tracking", "timeframeWeeks", "systemImage"],
    properties: goalCandidateProperties(),
  },
  generate_athlete_blueprint: {
    type: "object",
    additionalProperties: false,
    required: ["coachRead", "athleteArchetype", "currentTrainingState", "physicalBaseline", "historyFindings", "goalFit"],
    properties: {
      coachRead: { type: "string" },
      athleteArchetype: blueprintTextPairSchema(),
      currentTrainingState: blueprintTextPairSchema(),
      physicalBaseline: blueprintTextPairSchema(),
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
  generate_fitness_strategy_targets: {
    type: "object",
    additionalProperties: false,
    required: ["strategyTargets", "phaseOutline"],
    properties: {
      strategyTargets: {
        type: "array",
        minItems: 3,
        maxItems: 3,
        items: fitnessStrategyTargetProposalSchema(),
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
              items: fitnessStrategyTargetProposalSchema(),
            },
          },
        },
      },
    },
  },
  generate_fitness_strategy: {
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
        minItems: 3,
        maxItems: 3,
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
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startedAt = Date.now();
  const model = Deno.env.get("OPENAI_MODEL") || "gpt-5-mini";
  let requestBody: OnboardingAIRequest | null = null;
  let userID: string | null = null;

  const supabaseUrl = mustGetEnv("SUPABASE_URL");
  const serviceRoleKey = mustGetEnv("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = mustGetEnv("SUPABASE_ANON_KEY");
  const admin = createClient(supabaseUrl, serviceRoleKey);

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data, error } = await userClient.auth.getUser();
    if (error || !data.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    userID = data.user.id;
    requestBody = await req.json();
    validateRequest(requestBody);

    const output = await runOpenAI(requestBody, model);
    await insertTrace(admin, {
      userID,
      task: requestBody.task,
      model,
      compactRequest: compactTraceRequest(requestBody),
      structuredResponse: output,
      status: "success",
      latencyMS: Date.now() - startedAt,
    });

    return jsonResponse({ task: requestBody.task, model, output });
  } catch (error) {
    if (userID && requestBody?.task) {
      await insertTrace(admin, {
        userID,
        task: requestBody.task,
        model,
        compactRequest: compactTraceRequest(requestBody),
        structuredResponse: null,
        status: "failure",
        latencyMS: Date.now() - startedAt,
        errorMessage: errorMessage(error),
      });
    }

    return jsonResponse({ error: errorMessage(error) }, 400);
  }
});

async function runOpenAI(requestBody: OnboardingAIRequest, model: string) {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const promptContext = compactPromptContext(requestBody.task, requestBody.context);
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      reasoning: { effort: "minimal" },
      input: [
        {
          role: "system",
          content: [sharedSystemPrompt(), taskSystemPrompt(requestBody.task)].join(" "),
        },
        {
          role: "user",
          content: JSON.stringify({
            task: requestBody.task,
            context: promptContext,
            candidates: requestBody.candidates ?? [],
            rules: taskRules(requestBody.task),
          }),
        },
      ],
      text: {
        verbosity: "low",
        format: {
          type: "json_schema",
          name: requestBody.task,
          strict: true,
          schema: taskSchemas[requestBody.task],
        },
      },
    }),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? "OpenAI request failed");
  }

  const outputText = extractOutputText(payload);
  if (!outputText) {
    throw new Error("OpenAI returned no structured output text");
  }

  return sanitizeOutputForTask(requestBody.task, JSON.parse(outputText));
}

function sharedSystemPrompt() {
  return [
    "You are HAYF's onboarding coach.",
    "Be concise, perceptive, and practical.",
    "Do not provide medical advice.",
    "Use only the compact context provided.",
    "Never ask for raw HealthKit samples.",
  ].join(" ");
}

function taskSystemPrompt(task: OnboardingTask) {
  switch (task) {
    case "generate_goal_candidates":
      return [
        "You are writing selectable goal cards directly to the user.",
        "Write like a calm coach speaking to an excited athlete at the start of a shared training project.",
        "Use direct second-person language: you, your, we will, and you will.",
        "Never refer to the user as 'the athlete', 'athlete', 'user', or 'client'.",
        "Never write analyst fragments or third-person shorthand.",
      ].join(" ");
    case "generate_blended_candidate":
      return [
        "You are writing one blended goal card directly to the user.",
        "Write like a calm coach speaking to an excited athlete at the start of a shared training project.",
        "Use direct second-person language: you, your, we will, and you will.",
        "Never refer to the user as 'the athlete', 'athlete', 'user', or 'client'.",
      ].join(" ");
    case "generate_athlete_blueprint":
      return "When writing an Athlete Blueprint, sound like an elite coach who has studied the athlete closely, but stay fully inside the approved evidence.";
    case "generate_fitness_strategy_targets":
      return "When designing Fitness Strategy targets, act like a coaching strategist who can turn a goal into measurable success signals without writing workouts.";
    case "generate_fitness_strategy":
      return "When writing a Fitness Strategy, sound like a coach explaining the plan of attack after assessing the athlete.";
    case "generate_summary":
      return "Write a short reflective readback directly to the user.";
  }
}

function validateRequest(value: OnboardingAIRequest | null): asserts value is OnboardingAIRequest {
  if (!value || !value.task || !taskSchemas[value.task] || !value.context) {
    throw new Error("Invalid onboarding AI request");
  }

  if (value.task === "generate_blended_candidate" && (value.candidates?.length ?? 0) < 2) {
    throw new Error("Blended candidate generation requires at least two candidates");
  }
}

function taskRules(task: OnboardingTask) {
  switch (task) {
    case "generate_summary":
      return "Return one concise sentence addressed to the user, like a coach reflecting back what a new client just told them. Describe the user's target or selected direction in natural second-person language, and mention constraints like availability, access, or support style only when they materially shape the read. Do not use imperative planner language like 'Create', 'Build a plan', or 'Track'. Do not explain how HAYF will execute it, and do not list or repeat every answer.";
    case "generate_goal_candidates":
      return [
        "Return exactly three distinct goal candidates.",
        "Each title must name the outcome only and must not include the timeframe because timeframeWeeks is displayed separately.",
        "Titles may use two short sentences when that reads better.",
        "Never use em dashes, en dashes, semicolons, colons, slashes, or plus signs in titles.",
        "Never start a title with punctuation.",
        "Set timeframeWeeks to 4, 8, or 12.",
        "Write rationale as warm coach copy for an excited athlete at the start of a project you will work on together.",
        "Rationale must speak directly to the user with words like you, your, we will, and you will.",
        "Do not write note-style fragments or third-person phrases.",
        "Rationale must be one sentence when possible, two short sentences at most.",
        "Rationale must explain why this goal fits the user's priority and challenge style, then make the payoff feel motivating and concrete.",
        "Do not use semicolons, em dashes, en dashes, slashes, or plus signs.",
        "Do not use the word 'Tracks' or describe tracking in the rationale.",
        "The tracking field is internal only: keep it as a short comma-separated note under 12 words.",
      ].join(" ");
    case "generate_blended_candidate":
      return [
        "Blend the two selected candidates into one candidate that keeps the clearer target, borrows useful support structure, and chooses a concrete 4-, 8-, or 12-week timeframe.",
        "The title must name the outcome only and must not include the timeframe because timeframeWeeks is displayed separately.",
        "Titles may use two short sentences when that reads better.",
        "Never use em dashes, en dashes, semicolons, colons, slashes, or plus signs in titles.",
        "Never start a title with punctuation.",
        "Write rationale as warm coach copy for an excited athlete at the start of a project you will work on together.",
        "Rationale must speak directly to the user with words like you, your, we will, and you will.",
        "Do not write note-style fragments or third-person phrases.",
        "Rationale must be one sentence when possible, two short sentences at most.",
        "Do not use semicolons, em dashes, en dashes, slashes, or plus signs.",
        "Do not use the word 'Tracks' or describe tracking in the rationale.",
        "The tracking field is internal only: keep it as a short comma-separated note under 12 words.",
      ].join(" ");
    case "generate_athlete_blueprint":
      return [
        "Return authored copy for the six Athlete Blueprint sections only.",
        "Use sectionSeeds as factual constraints, not as sample copy to lightly paraphrase.",
        "Do not add new factual claims and preserve every historyFindings id exactly.",
        "coachRead is a read of the athlete, not a restatement of the goal: lead with identity, current state, repeatable patterns, and coaching-relevant tendencies visible in the evidence. Mention the goal only if it creates a meaningful tension or fit. Use 2 to 4 short sentences.",
        "athleteArchetype may verbalize the canonical label naturally. It should treat approved body-change trends as part of athlete identity when sectionSeeds support that, rather than only naming modalities. Label length: 2 to 5 words. Summary: one sentence, 12 to 28 words.",
        "currentTrainingState may verbalize the canonical state naturally. Label length: 2 to 5 words. Summary: one sentence, 12 to 28 words.",
        "physicalBaseline should state the fresh onboarding baseline plainly and should not imply imported body metrics are current truth. Label length: 2 to 6 words. Summary: one sentence, 12 to 28 words.",
        "Each history finding should keep its id but may use fresh natural language. Title: at most 8 words. Summary: one sentence, at most 22 words.",
        "goalFit should assess whether the selected goal and chosen feasible training options make sense together, with historical modalities used as context rather than veto power. Headline: 2 to 6 words. Summary: 1 to 2 sentences, 25 to 55 words.",
        "Do not turn goalFit into a mini-plan: no prescriptions, no weekly session counts, no exercise programming.",
        "Rephrase goals in natural English; never echo a first-person brief such as 'I want to...' verbatim after 'your goal of'.",
      ].join(" ");
    case "generate_fitness_strategy_targets":
      return [
        "Return target proposals only. Do not write strategyRead, fitReasons, pillars, workout plans, weekly plans, or session plans.",
        "Use targetSlots as the exact structural contract. Preserve every target id exactly.",
        "Use targetBrief to choose the target concepts. Do not use sectionSeeds because this task receives no prebuilt target titles or metric contracts.",
        "Infer the progress type from targetBrief: adherence, completion, speed, capacity, strength, skill, body composition, mobility, recovery, or general athleticism.",
        "Return exactly three strategyTargets for the full strategy horizon.",
        "For phased strategies, return exactly the seeded phase ids and exactly three phaseTargets per phase. For consistency strategies, phaseOutline must stay empty.",
        "A strategy target is an end-of-horizon success signal. It answers what should be true by the end of this strategy for HAYF to believe the approach worked.",
        "A phase target is a shorter proof point. It answers what should be true by the end of this phase for HAYF to know the strategy is progressing.",
        "Every target must be measurable, numeric, and trackable from imported performance, body, or workout/adherence data.",
        "Every target title and proposedDisplayValue must make the measurable outcome obvious without the user needing to infer it.",
        "Target titles are UI labels, not explanations: use one short label, 2 to 6 words, ideally under 32 characters. Do not use title: subtitle formatting, colons, or labels like 'thing: explanation'.",
        "proposedDisplayValue is a small pill: keep it under 14 characters whenever possible, using compact forms like +8%, -30 sec, 8/12, 7 days, 3 wks, or 2x/wk.",
        "Put the measurement explanation in summary, but keep summary to one short sentence of 10 to 18 words because it is displayed inside a compact card.",
        "A title must name the measured thing, not the activity of measuring it. Prefer labels like 5K pace, FTP, rhythm weeks, strength weeks, max gap, weekly run minutes, body weight.",
        "When targetBrief.concreteGoalTargets contains one or more targets, include as many of those concrete targets as strategy-level targets as the three available strategy target slots allow.",
        "When targetBrief.concreteGoalTargets contains two targets, use two strategy target slots for those concrete outcomes and one slot for the strongest adherence, modality-presence, body, or capstone support target.",
        "Do not use non-target labels such as review, signal, decision, check-in, stable, before skip, next move, or generic result count.",
        "Do not use the word benchmark anywhere in target titles, target display values, phase objectives, or summaries.",
        "Do not ask the user to reflect, decide, create a plan, or review evidence as a target.",
        "Onboarding choices and targetBrief define the training path. They take precedence over historical modalities.",
        "Use historical data only to size confidence or feasibility when it supports the selected goal and selected modalities.",
        "Do not confuse high general training volume with high goal-specific volume.",
        "Do not introduce modalities, locations, equipment, or dependencies that are absent from targetBrief, unavailable in onboardingSignals, or marked as something the user wants to avoid.",
        "Do not turn a historical modality into a strategy target, phase target, anchor, capstone, or headline unless it is in targetBrief.allowedModalities.",
        "Capstones are optional. Propose a capstone only when it naturally proves the user's goal and matches goal semantics, selected modality, access, horizon, and athlete evidence.",
        "A capstone must be one target inside the strategy, never the whole strategy. Do not create a capstone from historical data alone.",
        "If the user supplied a concrete number, date, or event, treat it as a constraint. If not, do not invent exact pace, weight, load, distance, or body-composition outcomes.",
        "When no exact performance number is supplied, use a numeric threshold, adherence target, comparable-effort improvement, presence count, volume change, distance change, load change, max-gap guardrail, or body-data change that HAYF can track.",
        "Do not create targets like one imported result, final test completed, plan adjusted, confidence improved, recovery reviewed, or next goal selected.",
        "Do not prescribe workouts, session formats, intensity schedules, weekly workout composition, named workout types, or exact training sessions.",
        "Never mention metricKey values, snake_case field names, comparison operators, or internal measurement names in user-facing target copy.",
        "Each target family must come from targetBrief.allowedTargetFamilies.",
      ].join(" ");
    case "generate_fitness_strategy":
      return [
        "Return authored copy for the Fitness Strategy reveal only.",
        "Use sectionSeeds as the exact structural contract and preserve every id exactly.",
        "The targets in sectionSeeds are already validated. Do not redesign, replace, resize, or add targets.",
        "strategyRead should explain the coaching approach, not repeat the user's goal summary. Use 2 to 4 short sentences.",
        "goalTargetContext should frame the user's goal target as context that HAYF translates into strategy. It is not a HAYF target.",
        "fitReasons should explain why this strategy fits the athlete, using only the seeded ids and supplied evidence. Each summary must be one short sentence, 8 to 12 words.",
        "strategyPillars should explain the few steering rules HAYF will prioritize. Keep every seeded id and write concrete user-facing copy. Each summary must be one short sentence, 8 to 12 words.",
        "For consistency goals, phaseOutline must stay empty and operatingRhythm must be present.",
        "For non-consistency goals, phaseOutline should preserve the seeded phase ids and operatingRhythm should be null.",
        "Onboarding choices and validated sectionSeeds define the training path for this strategy. They take precedence over historical modalities.",
        "Do not confuse high general training volume with high goal-specific volume.",
        "Do not introduce modalities, locations, equipment, or dependencies that are absent from sectionSeeds, unavailable in onboardingSignals, or marked as something the user wants to avoid.",
        "Do not turn a historical modality into a strategy target, phase target, anchor, capstone, or headline unless validated sectionSeeds already include it.",
        "Do not prescribe workouts, session formats, intensity schedules, weekly workout composition, named workout types, or exact training sessions.",
        "Do not use the word benchmark anywhere in strategyRead, pillars, fitReasons, phase objectives, or phase target summaries.",
        "Never mention metricKey values, snake_case field names, comparison operators, or internal measurement names in user-facing target copy.",
        "Do not create or mention weekly targets in the Fitness Strategy reveal; weekly targets are shown later in Plan.",
        "Do not create new athlete facts beyond the supplied blueprint summary and onboarding signals.",
      ].join(" ");
  }
}

function compactPromptContext(task: OnboardingTask, context: Record<string, unknown>) {
  if (task === "generate_goal_candidates") {
    return pick(context, [
      "intent",
      "trainingOptions",
      "infrastructureAccess",
      "goalDirection",
      "challengeStyle",
      "goalAvoidances",
      "injuryNotes",
    ]);
  }

  if (task === "generate_blended_candidate") {
    return pick(context, [
      "intent",
      "trainingOptions",
      "infrastructureAccess",
      "goalDirection",
      "challengeStyle",
      "goalAvoidances",
      "injuryNotes",
    ]);
  }

  if (task === "generate_athlete_blueprint") {
    return pick(context, [
      "intent",
      "normalizedGoal",
      "feasibleTrainingOptions",
      "onboardingSignals",
      "evidenceSummary",
      "sectionSeeds",
      "doNotClaim",
    ]);
  }

  if (task === "generate_fitness_strategy_targets") {
    return pick(context, [
      "intent",
      "normalizedGoal",
      "blueprint",
      "onboardingSignals",
      "targetBrief",
      "targetSlots",
      "doNotClaim",
    ]);
  }

  if (task === "generate_fitness_strategy") {
    return pick(context, [
      "intent",
      "normalizedGoal",
      "blueprint",
      "onboardingSignals",
      "sectionSeeds",
      "doNotClaim",
    ]);
  }

  if (context.intent === "stayConsistent") {
    return pick(context, [
      "intent",
      "trainingOptions",
      "infrastructureAccess",
      "motivationAnchors",
      "motivationNote",
      "frequency",
      "sessionLength",
      "availableDays",
      "availableDayParts",
      "blockers",
      "blockerNote",
      "supportStyle",
      "badDayFloor",
      "bodyBaseline",
    ]);
  }

  if (context.intent === "concreteGoal") {
    return pick(context, [
      "intent",
      "goalBrief",
      "goalExperience",
      "injuryNotes",
      "goalTimeline",
      "goalPriority",
      "trainingOptions",
      "infrastructureAccess",
      "frequency",
      "sessionLength",
      "availableDays",
      "availableDayParts",
      "blockers",
      "blockerNote",
      "supportStyle",
      "badDayFloor",
      "bodyBaseline",
    ]);
  }

  return pick(context, [
    "intent",
    "chosenGoal",
    "trainingOptions",
    "infrastructureAccess",
    "goalDirection",
    "challengeStyle",
    "goalAvoidances",
    "injuryNotes",
    "goalTimeline",
    "frequency",
    "sessionLength",
    "availableDays",
    "availableDayParts",
    "blockers",
    "blockerNote",
    "supportStyle",
    "badDayFloor",
    "bodyBaseline",
  ]);
}

function pick(source: Record<string, unknown>, keys: string[]) {
  return Object.fromEntries(keys.flatMap((key) => key in source ? [[key, source[key]]] : []));
}

function sanitizeOutputForTask(task: OnboardingTask, output: Record<string, any>) {
  if (task === "generate_goal_candidates") {
    return {
      ...output,
      candidates: Array.isArray(output.candidates)
        ? output.candidates.map((candidate: Record<string, any>) => sanitizeGoalCandidate(candidate))
        : [],
    };
  }

  if (task === "generate_blended_candidate") {
    return sanitizeGoalCandidate(output);
  }

  return output;
}

function sanitizeGoalCandidate(candidate: Record<string, any>) {
  return {
    ...candidate,
    title: sanitizeGoalTitle(String(candidate.title ?? "")),
    rationale: sanitizeGoalRationale(String(candidate.rationale ?? "")),
    tracking: sanitizeTracking(String(candidate.tracking ?? "")),
  };
}

function sanitizeGoalTitle(value: string) {
  return sentenceCase(
    value
      .replace(/[—–]/g, ". ")
      .replace(/[;:+/]/g, " ")
      .replace(/^[\s:;,.+\-/]+/, "")
      .replace(/\s+/g, " ")
      .replace(/\s+\./g, ".")
      .trim()
  );
}

function sanitizeGoalRationale(value: string) {
  return sentenceCase(
    value
      .replace(/[—–;]/g, ". ")
      .replace(/\s+\+\s+/g, " and ")
      .replace(/\//g, " or ")
      .replace(/\bPrimary priority ([^,.]+), athlete wants measurable numeric targets and to be more athletic\.?/gi, "Your $1 priority and your preference for measurable targets give us a clear starting point.")
      .replace(/\bPrimary priority ([^,.]+), athlete wants ([^.]+)\.?/gi, "Your $1 priority matters here, and you want $2.")
      .replace(/\bPrimary interest in ([^.]+)\.?/gi, "Your priority is $1.")
      .replace(/\bThe athlete wants\b/gi, "You want")
      .replace(/\bAthlete wants\b/gi, "You want")
      .replace(/\bthe athlete's\b/gi, "your")
      .replace(/\bathlete's\b/gi, "your")
      .replace(/\bthe athlete\b/gi, "you")
      .replace(/\bathlete\b/gi, "you")
      .replace(/\bthe user's\b/gi, "your")
      .replace(/\buser's\b/gi, "your")
      .replace(/\bthe user\b/gi, "you")
      .replace(/\buser\b/gi, "you")
      .replace(/\bthe your\b/gi, "your")
      .replace(/\s+/g, " ")
      .trim()
  );
}

function sanitizeTracking(value: string) {
  return value
    .replace(/[—–;]/g, ",")
    .replace(/\bTracks?:\s*/gi, "")
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean)
    .slice(0, 4)
    .join(", ");
}

function sentenceCase(value: string) {
  return value
    .split(".")
    .map((part) => {
      const trimmed = part.trim();
      if (!trimmed) return "";
      return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
    })
    .filter(Boolean)
    .join(". ");
}

function goalCandidateProperties() {
  return {
    id: { type: "string" },
    title: { type: "string" },
    rationale: { type: "string" },
    tracking: { type: "string" },
    timeframeWeeks: { type: "integer", enum: [4, 8, 12] },
    systemImage: { type: "string" },
  };
}

function fitnessStrategyTargetProposalSchema() {
  return {
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
}

function blueprintTextPairSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["label", "summary"],
    properties: {
      label: { type: "string" },
      summary: { type: "string" },
    },
  };
}

function extractOutputText(payload: Record<string, any>) {
  if (typeof payload.output_text === "string") {
    return payload.output_text;
  }

  for (const output of payload.output ?? []) {
    for (const content of output.content ?? []) {
      if (content.type === "output_text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }

  return null;
}

function compactTraceRequest(requestBody: OnboardingAIRequest) {
  return {
    task: requestBody.task,
    context: requestBody.context,
    candidates: requestBody.candidates ?? [],
  };
}

async function insertTrace(
  admin: any,
  trace: {
    userID: string;
    task: OnboardingTask;
    model: string;
    compactRequest: Record<string, unknown>;
    structuredResponse: Record<string, unknown> | null;
    status: "success" | "failure";
    latencyMS: number;
    errorMessage?: string;
  },
) {
  const { error } = await admin.from("onboarding_ai_generations").insert({
    user_id: trace.userID,
    task: trace.task,
    model: trace.model,
    compact_request: trace.compactRequest,
    structured_response: trace.structuredResponse,
    status: trace.status,
    latency_ms: trace.latencyMS,
    error_message: trace.errorMessage ?? null,
  });

  if (error) {
    console.error("Failed to insert onboarding AI trace", error);
  }
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function mustGetEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing ${name}`);
  }
  return value;
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "Unknown error";
}
