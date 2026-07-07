import {
  AI_TOUCHPOINT_CATALOG,
  type AITouchpointGroup,
  DEFAULT_AI_MODEL,
  type EditableAITouchpointConfig,
  type ReasoningEffort,
  type TextVerbosity,
} from "./ai-touchpoint-catalog.ts";

export type {
  AITouchpointGroup,
  EditableAITouchpointConfig,
  ReasoningEffort,
  TextVerbosity,
};

export type AITouchpointConfig = {
  id: string;
  model: string;
  // Top-level Responses API parameters, for example max_output_tokens or temperature.
  parameters?: Record<string, unknown>;
  reasoning?: { effort: ReasoningEffort };
  text?: { verbosity?: TextVerbosity };
  systemPrompt: string;
  userRules?: string;
};

type PlanningTouchpointOptions = {
  workoutTaxonomyRules?: string;
};

const DEFAULT_MODEL = DEFAULT_AI_MODEL;
const DEFAULT_SYSTEM_PROMPT =
  "Return strict JSON that matches the requested schema.";
const WORKOUT_CANDIDATE_RULES =
  "Keep titles short, no em dashes; use commas or parentheses only for user-specific details. Rationale and weeklyImpact must each be one short sentence under 14 words.";

export function defaultAIModel() {
  return Deno.env.get("OPENAI_MODEL") || DEFAULT_MODEL;
}

function modelFor(touchpointID: string, fallback = DEFAULT_MODEL) {
  const envKey = `OPENAI_MODEL_${
    touchpointID.toUpperCase().replace(/[^A-Z0-9]+/g, "_")
  }`;
  return Deno.env.get(envKey) || Deno.env.get("OPENAI_MODEL") || fallback;
}

function compactJSONString(value: unknown) {
  return JSON.stringify(value);
}

export function onboardingAITouchpoint(task: string): AITouchpointConfig {
  const entry = touchpointEntry("onboarding", task);
  return touchpointConfigFromEntry(entry ?? defaultEntry("onboarding", task));
}

export function planningAITouchpoint(
  id: string,
  options: PlanningTouchpointOptions = {},
): AITouchpointConfig {
  const entry = touchpointEntry("planning", id);
  const config = touchpointConfigFromEntry(
    entry ?? defaultEntry("planning", id),
  );
  return {
    ...config,
    userRules: materializePlanningRules(config.userRules, options),
  };
}

function touchpointEntry(group: AITouchpointGroup, id: string) {
  return (AI_TOUCHPOINT_CATALOG[group] as Record<
    string,
    EditableAITouchpointConfig | undefined
  >)[id];
}

function defaultEntry(
  group: AITouchpointGroup,
  id: string,
): EditableAITouchpointConfig {
  return {
    id,
    group,
    label: id,
    systemPrompt: DEFAULT_SYSTEM_PROMPT,
    userRules: compactJSONString({ task: id }),
  };
}

function touchpointConfigFromEntry(
  entry: EditableAITouchpointConfig,
): AITouchpointConfig {
  return {
    id: entry.id,
    model: modelFor(entry.id, entry.model ?? DEFAULT_MODEL),
    parameters: entry.parameters,
    reasoning: entry.reasoning,
    text: entry.text,
    systemPrompt: entry.systemPrompt,
    userRules: entry.userRules,
  };
}

function materializePlanningRules(
  userRules: string | undefined,
  options: PlanningTouchpointOptions,
) {
  if (!userRules) return userRules;

  return userRules
    .replaceAll("{workoutTaxonomyRules}", options.workoutTaxonomyRules ?? "")
    .replaceAll("{workoutCandidateRules}", WORKOUT_CANDIDATE_RULES);
}
