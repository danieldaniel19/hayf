# Onboarding AI Backend

## Purpose

The onboarding AI backend turns fixed onboarding answers into structured coach output. It does not own the onboarding flow, screens, navigation, or permission asks. The iOS app owns those. The backend receives compact context, calls OpenAI, returns schema-valid JSON, and records a trace row for debugging.

This is intentionally closer to a small typed API than a freeform chat workflow.

## Product Decisions

- Use Supabase Edge Functions as the first AI backend.
- Use OpenAI Structured Outputs so the app receives predictable JSON.
- Default to `gpt-5-mini` through the `OPENAI_MODEL` Supabase secret.
- Store OpenAI credentials only as Supabase secrets, never in the app.
- Store completed onboarding in `public.onboarding_profiles`.
- Store every AI attempt in `public.onboarding_ai_generations`, including failures.
- Keep raw HealthKit samples on device.
- Send only derived HealthKit snapshot fields when generating the first rhythm.
- Keep local deterministic mock output as fallback so onboarding can complete if AI fails.
- Let tester restart onboarding by deleting the signed-in user's `onboarding_profiles` row.

## Files

- `supabase/config.toml`: Supabase project/function config.
- `supabase/migrations/20260429212000_onboarding_ai.sql`: database tables, indexes, trigger, and RLS policies.
- `supabase/functions/onboarding-ai/index.ts`: authenticated Edge Function and OpenAI call.
- `HAYFHealthKitPrototype/Onboarding/OnboardingFlowView.swift`: iOS provider, request/response payloads, fallback provider, and onboarding profile store.
- `HAYFHealthKitPrototype/App/AppRootView.swift`: post-auth gate that uses `onboarding_profiles` as onboarding source of truth.

## Runtime Flow

1. User advances to an AI-backed step in onboarding.
2. `RemoteOnboardingAIProvider` builds an `OnboardingAIFunctionRequest`.
3. The app invokes Supabase function `onboarding-ai`.
4. The Edge Function verifies the Supabase Auth user from the request token.
5. The function calls OpenAI Responses API with a strict JSON schema for the requested task.
6. The function inserts one `onboarding_ai_generations` trace row.
7. The app decodes the structured output and renders it.
8. If anything fails, the app uses `MockOnboardingAIProvider` fallback output.
9. At the final screen, the app upserts `onboarding_profiles`.

## Supported Tasks

### `generate_summary`

Used by all branches after the user has answered the setup questions.

Expected output:

- `rows`: 5-7 summary rows
- `coachNote`: short coach readback
- `realismNote`: empty string when not needed; useful for concrete goals

### `generate_first_rhythm`

Used by all branches after HealthKit permission screen.

Expected output:

- `copy`
- `focusLabel`
- `focusValue`
- `reasonValue`
- `rows`: 3-5 rhythm rows
- `coachNote`

This task may receive `healthSnapshot`, but only as derived features.

### `generate_goal_candidates`

Used only by the "Help me find a goal" branch.

Expected output:

- exactly three candidate objects
- each candidate includes `id`, `title`, `rationale`, `tracking`, and `systemImage`

### `generate_blended_candidate`

Used only by the "Help me find a goal" branch when the user picks two candidates to blend.

Expected output:

- one candidate object with `id`, `title`, `rationale`, `tracking`, and `systemImage`

## Branch Coverage

### Help Me Stay Consistent

AI calls:

- `generate_summary`
- `generate_first_rhythm`

Primary context:

- intent
- training options
- motivation anchors and note
- frequency
- session length
- blockers and blocker note
- support style
- bad-day floor
- optional derived HealthKit snapshot for first rhythm

### I Have A Specific Goal

AI calls:

- `generate_summary`
- `generate_first_rhythm`

Primary context:

- intent
- goal brief
- baseline
- timeline or selected date
- priority tradeoff
- marker text
- supporting training options
- frequency
- session length
- blockers
- support style
- bad-day floor
- optional derived HealthKit snapshot for first rhythm

### Help Me Find A Goal

AI calls:

- `generate_goal_candidates`
- optional `generate_blended_candidate`
- `generate_summary`
- `generate_first_rhythm`

Primary context:

- intent
- training options
- desired direction
- challenge style
- avoids
- chosen/edited/blended goal candidate
- frequency
- session length
- blockers
- support style
- bad-day floor
- optional derived HealthKit snapshot for first rhythm

## Compact Context Shape

The iOS app sends this shape as `context`:

```json
{
  "intent": "stayConsistent",
  "intentTitle": "Help me stay consistent",
  "trainingOptions": ["Running", "Strength"],
  "motivationAnchors": ["Training without overthinking"],
  "motivationNote": "I lose the rhythm when work gets busy.",
  "goalBrief": "",
  "goalMarker": "",
  "goalBaseline": "Not set",
  "goalTimeline": "Not set",
  "goalPriority": "Not set",
  "goalDirection": "Not set",
  "challengeStyle": "Not set",
  "goalAvoidances": [],
  "chosenGoal": null,
  "frequency": "3 days/week",
  "sessionLength": "45 min",
  "blockers": ["Work schedule", "Low energy"],
  "blockerNote": "Late meetings break my plan.",
  "supportStyle": "gentle reset",
  "badDayFloor": "20-minute easy session",
  "healthSnapshot": null
}
```

For first rhythm only, `healthSnapshot` may look like:

```json
{
  "sleepHoursLastNight": 6.5,
  "workoutsLast7Days": 2,
  "averageStepsLast7Days": 7200,
  "heightCentimeters": 178,
  "bodyMassKilograms": 76
}
```

Do not add raw HealthKit samples to this context.

## Prompt Surface

The current base system prompt lives in `supabase/functions/onboarding-ai/index.ts` inside `runOpenAI`:

```text
You are HAYF's onboarding coach. Return concise, practical fitness setup JSON that exactly matches the schema. Do not provide medical advice. Use only the compact context provided; never ask for raw HealthKit samples.
```

Each task also adds task-specific rules through `taskRules(task)`:

- Summary: return 5-7 rows, optional coach note, optional realism note.
- First rhythm: return 3-5 starter rhythm rows and use derived health gently when present.
- Goal candidates: return exactly three distinct candidates.
- Blended candidate: combine the selected candidates into one clearer goal.

The hard boundary is the JSON schema. Prompt changes can alter style and judgment, but outputs must still match the task schema exactly.

## How To Test Prompts In ChatGPT

For prompt refinement, use a normal ChatGPT conversation as a draft lab before changing the Edge Function.

1. Copy the base system prompt from above.
2. Copy one task rule from `taskRules(task)`.
3. Copy a real `compact_request` from `public.onboarding_ai_generations`.
4. Tell ChatGPT to return only JSON matching the output shape.
5. Try several contexts per branch.
6. When a style consistently feels better, move the wording into `index.ts`.

Useful test instruction:

```text
Use this system behavior:
[paste base prompt]

Task rule:
[paste task rule]

Request:
[paste compact_request JSON]

Return only JSON matching the expected output shape. No Markdown.
```

For branch QA, pull example `compact_request` values from successful trace rows:

- consistency summary
- consistency first rhythm
- concrete goal summary
- concrete goal first rhythm
- goal discovery candidates
- blended candidate
- goal discovery summary
- goal discovery first rhythm

## What To Look For During Prompt QA

Good outputs should:

- feel coach-like without sounding theatrical
- be concise enough for mobile UI
- avoid medical claims
- respect the selected intent
- keep consistency users away from forced performance goals
- give concrete-goal users a realism note when the timeline or target is risky
- give goal-discovery users meaningfully different candidates
- use HealthKit snapshot only as a gentle modifier
- never mention unavailable data as if it is known
- never invent UI, navigation, permissions, or unsupported app features

Bad outputs to reject:

- generic wellness copy
- long paragraphs that do not fit cards
- "as an AI" phrasing
- claims based on raw HealthKit history
- rigid plans that ignore bad-day floor or blockers
- goal candidates that are just the same goal rewritten three ways

## Deployment Commands

From the repo root:

```bash
npx supabase link --project-ref nehwppenlaxozpwqepwp
npx supabase db push
npx supabase secrets set OPENAI_API_KEY="..."
npx supabase secrets set OPENAI_MODEL="gpt-5-mini"
npx supabase functions deploy onboarding-ai
```

## Verification Checklist

- Supabase Dashboard has `onboarding_profiles`.
- Supabase Dashboard has `onboarding_ai_generations`.
- Supabase Dashboard has Edge Function `onboarding-ai`.
- Supabase secrets include `OPENAI_API_KEY` and `OPENAI_MODEL`.
- Completing onboarding inserts/updates one `onboarding_profiles` row.
- AI-backed steps insert `onboarding_ai_generations` rows.
- Successful AI calls have `status = success`.
- If AI fails, onboarding still completes with fallback output.
- Restart onboarding deletes the signed-in user's onboarding profile row.

## Current Known Follow-Ups

- Refine prompts for HAYF tone and branch-specific coaching judgment.
- Add a small internal prompt fixture suite once outputs stabilize.
- Consider moving onboarding AI types/provider/store out of `OnboardingFlowView.swift` as the file grows.
- Add user-facing retry only if failures become common enough to matter.
