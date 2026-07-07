import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  defaultAIModel,
  onboardingAITouchpoint,
  type AITouchpointConfig,
} from "../_shared/ai-touchpoints.ts";

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

    const output = await runOpenAI(requestBody, touchpointConfig);
    await insertTrace(admin, {
      userID,
      task: requestBody.task,
      model: touchpointConfig.model,
      compactRequest: compactTraceRequest(requestBody),
      structuredResponse: output,
      status: "success",
      latencyMS: Date.now() - startedAt,
    });

    return jsonResponse({ task: requestBody.task, model: touchpointConfig.model, output });
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
