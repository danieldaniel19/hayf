import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  defaultAIModel,
  onboardingAITouchpoint,
  type AITouchpointConfig,
} from "../_shared/ai-touchpoints.ts";
import {
  compactProfileScoresForTrace,
  enrichBlueprintContext,
  mergeBlueprintProfileScores,
  redactBlueprintScoringInput,
  type AthleteProfileScores,
  validAthleteProfileScores,
} from "../_shared/athlete-profile-scoring.ts";

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

const defaultAthleteProfileEngineURL =
  "https://nehwppenlaxozpwqepwp.supabase.co/functions/v1/athlete-profile-engine";

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
      readback: {
        type: "string",
        maxLength: 280,
        description: "One or two natural sentences beginning with 'You', containing no em dashes, and each ending with a period.",
      },
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
      coachRead: {
        type: "string",
        maxLength: 190,
        description: "One or two AI-authored sentences synthesizing the athlete's history, present state, and one coaching implication without quoting or ranking radar scores.",
      },
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
  let requestBody: OnboardingAIRequest | null = null;
  let userID: string | null = null;
  let touchpointConfig: AITouchpointConfig | null = null;

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
    touchpointConfig = onboardingAITouchpoint(requestBody.task);

    const profileScoreResult = requestBody.task === "generate_athlete_blueprint"
      ? await fetchAthleteProfileScores(requestBody.context, serviceRoleKey, authHeader)
      : { scores: null, telemetry: null };
    const profileScores = profileScoreResult.scores;
    const enrichedRequest = requestBody.task === "generate_athlete_blueprint"
      ? { ...requestBody, context: enrichBlueprintContext(requestBody.context, profileScores) }
      : requestBody;
    const authoredOutput = await runOpenAI(enrichedRequest, touchpointConfig);
    const output = requestBody.task === "generate_athlete_blueprint"
      ? mergeBlueprintProfileScores(authoredOutput, profileScores)
      : authoredOutput;
    await insertTrace(admin, {
      userID,
      task: requestBody.task,
      model: touchpointConfig.model,
      compactRequest: compactTraceRequest(requestBody),
      structuredResponse: requestBody.task === "generate_athlete_blueprint"
        ? { ...output, profileScores: compactProfileScoresForTrace(profileScores) }
        : output,
      status: "success",
      latencyMS: Date.now() - startedAt,
    });

    return jsonResponse({
      task: requestBody.task,
      model: touchpointConfig.model,
      output,
      ...(profileScoreResult.telemetry ? { profileScoring: profileScoreResult.telemetry } : {}),
    });
  } catch (error) {
    if (userID && requestBody?.task) {
      await insertTrace(admin, {
        userID,
        task: requestBody.task,
        model: touchpointConfig?.model ?? defaultAIModel(),
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

async function runOpenAI(requestBody: OnboardingAIRequest, touchpointConfig: AITouchpointConfig) {
  const apiKey = mustGetEnv("OPENAI_API_KEY");
  const promptContext = compactPromptContext(requestBody.task, requestBody.context);
  const requestPayload: Record<string, unknown> = {
    ...(touchpointConfig.parameters ?? {}),
    model: touchpointConfig.model,
    input: [
      {
        role: "system",
        content: touchpointConfig.systemPrompt,
      },
      {
        role: "user",
        content: JSON.stringify({
          task: requestBody.task,
          context: promptContext,
          candidates: requestBody.candidates ?? [],
          rules: touchpointConfig.userRules,
        }),
      },
    ],
    text: {
      ...(touchpointConfig.text ?? {}),
      format: {
        type: "json_schema",
        name: requestBody.task,
        strict: true,
        schema: taskSchemas[requestBody.task],
      },
    },
  };
  if (touchpointConfig.reasoning) {
    requestPayload.reasoning = touchpointConfig.reasoning;
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(requestPayload),
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

function validateRequest(value: OnboardingAIRequest | null): asserts value is OnboardingAIRequest {
  if (!value || !value.task || !taskSchemas[value.task] || !value.context) {
    throw new Error("Invalid onboarding AI request");
  }

  if (value.task === "generate_blended_candidate" && (value.candidates?.length ?? 0) < 2) {
    throw new Error("Blended candidate generation requires at least two candidates");
  }
}

function compactPromptContext(task: OnboardingTask, context: Record<string, unknown>) {
  if (task === "generate_goal_candidates") {
    return {
      ...pick(context, [
      "intent",
      "trainingOptions",
      "infrastructureAccess",
      "goalDirection",
      "challengeStyle",
      "goalAvoidances",
      "injuryNotes",
      ]),
      goalIntensity: normalizedGoalIntensity(context.goalIntensity),
    };
  }

  if (task === "generate_blended_candidate") {
    return {
      ...pick(context, [
      "intent",
      "trainingOptions",
      "infrastructureAccess",
      "goalDirection",
      "challengeStyle",
      "goalAvoidances",
      "injuryNotes",
      ]),
      goalIntensity: normalizedGoalIntensity(context.goalIntensity),
    };
  }

  if (task === "generate_athlete_blueprint") {
    return pick(context, [
      "intent",
      "normalizedGoal",
      "feasibleTrainingOptions",
      "onboardingSignals",
      "evidenceSummary",
      "sectionSeeds",
      "profileScores",
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
      "motivationAnchors",
      "motivationNote",
      "blockers",
      "blockerNote",
      "injuryNotes",
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
      "blockers",
      "blockerNote",
    ]);
  }

  return pick(context, [
    "intent",
    "chosenGoal",
    "trainingOptions",
    "goalDirection",
    "challengeStyle",
    "goalAvoidances",
    "goalIntensity",
    "injuryNotes",
    "goalTimeline",
    "blockers",
    "blockerNote",
  ]);
}

const goalIntensityLevels = [
  {
    level: 0,
    identifier: "gentle",
    title: "Gentle",
    generationGuidance: "Generate approachable outcomes with modest demands and room to build confidence.",
  },
  {
    level: 1,
    identifier: "steady",
    title: "Steady",
    generationGuidance: "Generate meaningful outcomes that require consistent effort without becoming overly aggressive.",
  },
  {
    level: 2,
    identifier: "ambitious",
    title: "Ambitious",
    generationGuidance: "Generate demanding stretch outcomes that require stronger commitment.",
  },
  {
    level: 3,
    identifier: "extreme",
    title: "Extreme",
    generationGuidance: "Generate the boldest defensible outcomes, while strictly respecting selected modalities, access, avoidances, safety, and the absence of capacity or Health baselines.",
  },
] as const;

function normalizedGoalIntensity(value: unknown) {
  const input = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const identifier = typeof input.identifier === "string" ? input.identifier.toLowerCase() : "";
  const identifierMatch = goalIntensityLevels.find((intensity) => intensity.identifier === identifier);
  const numericLevel = typeof input.level === "number" && Number.isFinite(input.level)
    ? Math.min(3, Math.max(0, Math.round(input.level)))
    : null;
  return identifierMatch ?? goalIntensityLevels[numericLevel ?? 1];
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
  const context = requestBody.task === "generate_athlete_blueprint"
    ? redactBlueprintScoringInput(requestBody.context)
    : requestBody.context;
  return {
    task: requestBody.task,
    context,
    candidates: requestBody.candidates ?? [],
  };
}

async function fetchAthleteProfileScores(
  context: Record<string, unknown>,
  serviceRoleKey: string,
  userAuthorization: string,
) {
  const configuredServiceURL = Deno.env.get("ATHLETE_PROFILE_ENGINE_URL")?.trim();
  const serviceURL = configuredServiceURL || defaultAthleteProfileEngineURL;
  const serviceAPIKey = Deno.env.get("ATHLETE_PROFILE_ENGINE_API_KEY")?.trim()
    || serviceRoleKey.trim();
  const scoringInput = context.scoringInput;
  if (!scoringInput || typeof scoringInput !== "object") {
    return profileScoreFetchResult(null, "missing_scoring_input", 0);
  }
  const evaluatedInput = {
    ...(scoringInput as Record<string, unknown>),
    evaluatedAt: new Date().toISOString(),
  };
  if (!serviceURL) return profileScoreFetchResult(null, "service_not_configured", 0);
  const scoreURL = `${serviceURL.replace(/\/$/, "")}/v1/blueprints/score`;
  const servicePath = new URL(scoreURL).pathname;

  const startedAt = Date.now();
  try {
    const response = await fetch(scoreURL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(userAuthorization ? {
          "X-HAYF-User-Token": userAuthorization.replace(/^Bearer\s+/i, ""),
        } : {}),
        ...(serviceAPIKey ? {
          "X-HAYF-Profile-Key": serviceAPIKey,
        } : {}),
      },
      body: JSON.stringify(evaluatedInput),
      signal: AbortSignal.timeout(athleteProfileEngineTimeoutMS()),
    });
    if (!response.ok) {
      const serviceError = await response.json()
        .then((body) => typeof body?.error === "string" ? body.error : undefined)
        .catch(() => undefined);
      console.warn(JSON.stringify({
        event: "athlete_profile_scoring",
        status: "failure",
        statusCode: response.status,
        latencyMS: Date.now() - startedAt,
      }));
      return profileScoreFetchResult(
        null,
        "service_http_error",
        Date.now() - startedAt,
        response.status,
        servicePath,
        serviceError,
      );
    }
    const payload = await response.json();
    if (!validAthleteProfileScores(payload)) {
      console.warn(JSON.stringify({
        event: "athlete_profile_scoring",
        status: "invalid_response",
        latencyMS: Date.now() - startedAt,
      }));
      return profileScoreFetchResult(null, "invalid_service_response", Date.now() - startedAt);
    }
    console.info(JSON.stringify({
      event: "athlete_profile_scoring",
      status: "success",
      scoreVersion: payload.scoreVersion,
      unavailableDimensions: payload.dimensions
        .filter((dimension: Record<string, unknown>) => dimension.status === "unavailable")
        .map((dimension: Record<string, unknown>) => dimension.key),
      latencyMS: Date.now() - startedAt,
    }));
    return profileScoreFetchResult(payload, "success", Date.now() - startedAt);
  } catch (error) {
    const status = error instanceof DOMException && error.name === "TimeoutError"
      ? "service_timeout"
      : "service_unreachable";
    console.warn(JSON.stringify({
      event: "athlete_profile_scoring",
      status,
      latencyMS: Date.now() - startedAt,
    }));
    return profileScoreFetchResult(null, status, Date.now() - startedAt);
  }
}

function profileScoreFetchResult(
  scores: AthleteProfileScores | null,
  status: string,
  latencyMS: number,
  serviceStatusCode?: number,
  servicePath?: string,
  serviceError?: string,
) {
  return {
    scores,
    telemetry: {
      status,
      latencyMS,
      ...(serviceStatusCode === undefined ? {} : { serviceStatusCode }),
      ...(servicePath === undefined ? {} : { servicePath }),
      ...(serviceError === undefined ? {} : { serviceError }),
      ...(scores ? {
        scoreVersion: scores.scoreVersion,
        unavailableDimensions: scores.dimensions
          .filter((dimension: Record<string, unknown>) => dimension.status === "unavailable")
          .map((dimension: Record<string, unknown>) => dimension.key),
      } : {}),
    },
  };
}

function athleteProfileEngineTimeoutMS() {
  const configured = Number(Deno.env.get("ATHLETE_PROFILE_ENGINE_TIMEOUT_MS") ?? 3_000);
  return Number.isFinite(configured) && configured >= 250 ? Math.round(configured) : 3_000;
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
