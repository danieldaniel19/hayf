import { createClient } from "jsr:@supabase/supabase-js@2";

type OnboardingTask =
  | "generate_summary"
  | "generate_first_rhythm"
  | "generate_goal_candidates"
  | "generate_blended_candidate";

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
    required: ["rows", "coachNote", "realismNote"],
    properties: {
      rows: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["systemImage", "label", "value"],
          properties: {
            systemImage: { type: "string" },
            label: { type: "string" },
            value: { type: "string" },
          },
        },
      },
      coachNote: { type: "string" },
      realismNote: { type: "string" },
    },
  },
  generate_first_rhythm: {
    type: "object",
    additionalProperties: false,
    required: ["copy", "focusLabel", "focusValue", "reasonValue", "rows", "coachNote"],
    properties: {
      copy: { type: "string" },
      focusLabel: { type: "string" },
      focusValue: { type: "string" },
      reasonValue: { type: "string" },
      rows: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["day", "workout", "duration"],
          properties: {
            day: { type: "string" },
            workout: { type: "string" },
            duration: { type: "string" },
          },
        },
      },
      coachNote: { type: "string" },
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
          required: ["id", "title", "rationale", "tracking", "systemImage"],
          properties: goalCandidateProperties(),
        },
      },
    },
  },
  generate_blended_candidate: {
    type: "object",
    additionalProperties: false,
    required: ["id", "title", "rationale", "tracking", "systemImage"],
    properties: goalCandidateProperties(),
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
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content:
            "You are HAYF's onboarding coach. Return concise, practical fitness setup JSON that exactly matches the schema. Do not provide medical advice. Use only the compact context provided; never ask for raw HealthKit samples.",
        },
        {
          role: "user",
          content: JSON.stringify({
            task: requestBody.task,
            context: requestBody.context,
            candidates: requestBody.candidates ?? [],
            rules: taskRules(requestBody.task),
          }),
        },
      ],
      text: {
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
      return "Return 5-7 rows using SF Symbol names already familiar to iOS, plus optional coachNote and realismNote strings. Use an empty string when no realism note is needed.";
    case "generate_first_rhythm":
      return "Return a starter weekly rhythm with 3-5 rows. Use derived healthSnapshot only as a gentle adjustment signal when present.";
    case "generate_goal_candidates":
      return "Return exactly three distinct goal candidates. Keep ids URL-safe, titles concrete, and tracking fields short.";
    case "generate_blended_candidate":
      return "Blend the two selected candidates into one candidate that keeps the clearer target and borrows useful support structure.";
  }
}

function goalCandidateProperties() {
  return {
    id: { type: "string" },
    title: { type: "string" },
    rationale: { type: "string" },
    tracking: { type: "string" },
    systemImage: { type: "string" },
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
  admin: ReturnType<typeof createClient>,
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
