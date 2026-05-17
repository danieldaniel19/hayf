import { createClient } from "jsr:@supabase/supabase-js@2";

type OnboardingTask =
  | "generate_summary"
  | "generate_goal_candidates"
  | "generate_blended_candidate"
  | "generate_athlete_blueprint";

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
    required: ["coachRead", "athleteArchetype", "currentTrainingState", "historyFindings", "goalFit"],
    properties: {
      coachRead: { type: "string" },
      athleteArchetype: blueprintTextPairSchema(),
      currentTrainingState: blueprintTextPairSchema(),
      historyFindings: {
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
          content:
            "You are HAYF's onboarding coach. Be concise, perceptive, and practical. Do not provide medical advice. Use only the compact context provided; never ask for raw HealthKit samples. When writing an Athlete Blueprint, sound like an elite coach who has studied the athlete closely, but stay fully inside the approved evidence.",
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

  return JSON.parse(outputText);
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
      return "Return one concise sentence addressed to the user, like a coach reflecting back what a new client just told them. Describe what the user wants or selected in natural second-person language, such as 'You selected a goal that will help you build power and raise your threshold over 12 weeks.' Do not use imperative planner language like 'Create', 'Build a plan', or 'Track'. Do not explain how HAYF will execute it, and do not list or repeat every answer.";
    case "generate_goal_candidates":
      return "Return exactly three distinct goal candidates. Each candidate must have a concrete title that includes its timeframe, a short tracking field, and timeframeWeeks set to 4, 8, or 12.";
    case "generate_blended_candidate":
      return "Blend the two selected candidates into one candidate that keeps the clearer target, borrows useful support structure, and chooses a concrete 4-, 8-, or 12-week timeframe.";
    case "generate_athlete_blueprint":
      return [
        "Return authored copy for the five Athlete Blueprint sections only.",
        "Use sectionSeeds as factual constraints, not as sample copy to lightly paraphrase.",
        "Do not add new factual claims and preserve every historyFindings id exactly.",
        "coachRead is a read of the athlete, not a restatement of the goal: lead with identity, current state, repeatable patterns, and coaching-relevant tendencies visible in the evidence. Mention the goal only if it creates a meaningful tension or fit. Use 2 to 4 short sentences.",
        "athleteArchetype may verbalize the canonical label naturally. Label length: 2 to 5 words. Summary: one sentence, 12 to 28 words.",
        "currentTrainingState may verbalize the canonical state naturally. Label length: 2 to 5 words. Summary: one sentence, 12 to 28 words.",
        "Each history finding should keep its id but may use fresh natural language. Title: at most 8 words. Summary: one sentence, at most 22 words.",
        "goalFit should assess whether the selected goal and chosen feasible training options make sense together, with historical modalities used as context rather than veto power. Headline: 2 to 6 words. Summary: 1 to 2 sentences, 25 to 55 words.",
        "Do not turn goalFit into a mini-plan: no prescriptions, no weekly session counts, no exercise programming.",
        "Rephrase goals in natural English; never echo a first-person brief such as 'I want to...' verbatim after 'your goal of'.",
      ].join(" ");
  }
}

function compactPromptContext(task: OnboardingTask, context: Record<string, unknown>) {
  if (task === "generate_goal_candidates") {
    return pick(context, [
      "intent",
      "trainingOptions",
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

  if (context.intent === "stayConsistent") {
    return pick(context, [
      "intent",
      "trainingOptions",
      "motivationAnchors",
      "motivationNote",
      "frequency",
      "sessionLength",
      "blockers",
      "blockerNote",
      "supportStyle",
      "badDayFloor",
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
      "frequency",
      "sessionLength",
      "blockers",
      "blockerNote",
      "supportStyle",
      "badDayFloor",
    ]);
  }

  return pick(context, [
    "intent",
    "chosenGoal",
    "trainingOptions",
    "goalDirection",
    "challengeStyle",
    "goalAvoidances",
    "injuryNotes",
    "goalTimeline",
    "frequency",
    "sessionLength",
    "blockers",
    "blockerNote",
    "supportStyle",
    "badDayFloor",
  ]);
}

function pick(source: Record<string, unknown>, keys: string[]) {
  return Object.fromEntries(keys.flatMap((key) => key in source ? [[key, source[key]]] : []));
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
