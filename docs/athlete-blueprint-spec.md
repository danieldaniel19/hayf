# HAYF Athlete Blueprint Spec

Status: working source of truth for the Athlete Blueprint report structure. The first post-onboarding blueprint is revision 1 of an evolving athlete report, not a one-time static snapshot.

## Purpose

The Athlete Blueprint is the first user-visible payoff after onboarding and the durable report structure HAYF should continue to use as the athlete changes. It should make the user feel accurately assessed by a serious coach before HAYF shows the strategy built for them.

The blueprint is not the plan. It is the evidence-backed read of the athlete that future plans should be built from.

## Lifecycle

- The first post-onboarding blueprint is the athlete's first accepted revision.
- Later revisions should reuse the same visible structure as new evidence changes HAYF's read of the athlete over time.
- A current revision may change as body composition, consistency, training state, or other approved evidence changes.
- Prior revisions should remain inspectable so HAYF can explain how its understanding evolved.
- Planning artifacts should reference the blueprint revision that informed them.

## Product Boundary

The user-facing Athlete Blueprint shows:

1. `athlete_profile_scores` with the short `coach_read` interpretation when sufficient evidence exists
2. `athlete_archetype`
3. `current_training_state`
4. `physical_baseline`
5. `history_findings`
6. `goal_fit`

Whenever a valid score envelope exists, the first section shows the radar and its `coach_read` interpretation. The text-only card is reserved for a missing or invalid envelope.

The coach-side model may also maintain:

- strengths to exploit
- constraints and risks
- coaching profile
- coaching priorities

Those are not frontend blueprint sections. They are planning inputs.

## Evidence Dependency

The Athlete Blueprint may only consume the approved evidence packet defined by `docs/health-evidence-spec.md`.

The implementation-facing packet contract is defined in `docs/athlete-blueprint-context-packet.md`.

The AI never sees raw HealthKit samples. It sees:

- onboarding answers
- current goal
- approved metric summaries
- approved findings
- confidence
- provenance
- explicit caveats and forbidden claims

## Output Design Principles

1. Every visible claim must be evidence-backed.
2. Each section should do one distinct job.
3. The report should feel specific, not encyclopedic.
4. A fresh onboarding body baseline is the current truth for body composition; imported body metrics may enrich it only as qualified trend context.
5. Repeated body-change trends are part of athlete identity when they clear evidence thresholds, not merely a side note for body-composition goals.
6. The report should distinguish:
   - who the athlete appears to be
   - where they are now
   - what their history shows
   - how well the chosen goal fits them
7. Goal-aware does not mean goal-dependent. The durable athlete read should remain useful even if the goal later changes.
8. Every visible section should be able to open a compact detail card later with the evidence behind the claim: "why HAYF thinks this."

## Section Contracts

### 0. `athlete_profile_scores`

#### Job

Give the athlete a stable, legible view of the evidence HAYF can currently support. The deterministic contract retains integer evidence indicators from 0–100, while the product presents rounded whole numbers from 0–10. Exact halves round down. They are not percentiles, medical assessments, or predictions of target completion.

#### Fixed axis order

The clockwise order is immutable for `profile-radar-v1.2.0`:

1. Consistency
2. Momentum
3. Strength
4. Training base
5. Endurance

#### Deterministic ownership

All scores are produced by `hayf-athlete-profile-engine`. The AI may never author, repair, reorder, alter, quote, or rank a number in the narrative below the chart. The envelope uses `athlete-profile-scores.v1` and carries `profile-radar-v1.2.0` in `scoreVersion`.

Each dimension includes its key, integer score or `null`, availability status, confidence, weighted components, and evidence IDs. A dimension is `unavailable` when less than 70% of its required evidence weight is trustworthy. Missing evidence is never represented as zero or 50. Fresh 7-, 28-, and 90-day components are excluded when the source snapshot is more than 36 hours old; remaining component weights are re-normalized only at or above 70% coverage.

#### Rubric

| Dimension | Version 1 components |
| --- | --- |
| Consistency | Active-week rate 30%: `(0,0) (.25,30) (.50,65) (.75,90) (.90,100)`; longest streak 20%: `(0,0) (4,35) (12,70) (24,90) (40,100)`; absolute imported-workout recency 25%: `0–2d=100, 7d=75, 21d=35, 60d=0`; fresh 28-day cadence against declared weekly frequency 25%: `(0,0) (.50,60) (.80,85) (1,100)` |
| Momentum | Absolute workout recency 70%: `0–2d=100, 7d=75, 21d=35, 60d=0`; fresh 7-day minutes versus 28-day weekly baseline 20%: `(0,0) (.50,60) (.80,90) (1–1.25,100) (1.5,85) (2,60) (3,30)`; fresh current-week cadence 10%: `(0,0) (.50,60) (.80,85) (1+,100)` |
| Strength | Historical strength sessions 40%: `(0,0) (12,15) (50,35) (150,55) (300,70) (600,85) (1000,100)`; historical strength share 25%: `(0,0) (.10,30) (.25,60) (.50,85) (.75,100)`; fresh 90-day sessions 20%: `(0,0) (3,25) (12,70) (24,100)`; absolute strength recency 15%: `0d=100, 7d=85, 28d=40, 90d=0` |
| Training base | A goal-independent longitudinal foundation: consistency 35%, current continuity 20%, the stronger available strength/endurance foundation 35%, and the complementary foundation 10%. This is stable across onboarding intents and can evolve as the athlete continues training. |
| Endurance | Recognized historical sessions 30% using the same de-saturated session curve as strength; endurance share of minutes 25%: `(0,0) (.15,25) (.35,50) (.60,75) (.85,95) (1,100)`; longest session 20%: `(0m,0) (30m,25) (60m,55) (120m,85) (240m,100)`; best-distance effort breadth 10%: `0=0, 1=55, 2=75, 3=90, 4=100`; absolute endurance recency 15%: `0d=100, 7d=90, 28d=60, 60d=30, 120d=0` |

Body composition, sleep, HRV, VO₂ max, and all other recovery signals remain excluded from `profile-radar-v1.2.0`. Apple Health currently supplies recent recovery snapshots, but the scoring contract does not yet have the personal baselines, trend windows, source coverage, and freshness metadata required for a trustworthy longitudinal Recovery axis.

#### Rendering and fallback

- Five available dimensions render the filled and outlined pentagon.
- Fewer than five available dimensions render the grid and every supported point without filling through missing vertices; unavailable axes remain visible as `—`.
- An older revision, an invalid envelope, or a scoring-service outage renders the text-only Coach's Read card.
- Available axes show the rounded whole-number 0–10 presentation value; unavailable axes show `—` and read as “not enough evidence” to VoiceOver. A supported zero is available and is plotted at the chart origin.
- The full onboarding card includes the one-to-two-sentence interpretation and imported-workout count.
- The accepted envelope is persisted exactly on the blueprint revision and reused by the compact Profile card and full Profile detail sheet.

### 1. `coach_read`

#### Job

Deliver the opening verdict. This is the emotional center of the screen: one short synthesis that makes the user feel seen.

#### Must answer

- what kind of athlete HAYF believes this is
- what matters most about their present state
- what one or two truths are most important for coaching them well

#### Input findings allowed

- approved `training_identity`
- approved `current_training_state`
- approved `consistency_pattern`
- approved `goal_readiness_signals`
- approved high-confidence onboarding declarations

#### Allowed claim types

- synthesis across approved findings
- tension between declared ambition and observed preparation
- one or two practical implications, if directly supported

#### Forbidden claim types

- new factual claims not present in approved findings
- unsupported motives
- unsupported physiological diagnosis
- body-composition or recovery claims when those metrics are not blueprint-grade

#### Length

- With `athlete_profile_scores`: 1 to 2 AI-authored sentences, fewer than 190 characters. Synthesize the athlete's history, present state, and one coaching implication without quoting, ranking, or mentioning radar scores or axis labels.
- Without scores: retain the established concise text fallback.

#### Example

> You are a strength-led hybrid athlete with a better base than your recent rhythm suggests. Your training history shows that lifting is your most durable anchor, while endurance appears more in bursts than as a steady habit. The goal is realistic, but only if aerobic work becomes protected rather than optional.

### 2. `athlete_archetype`

#### Job

Give the user a memorable, legible label for the kind of athlete HAYF believes they are.

#### Must answer

- what durable pattern best describes the athlete's identity today

#### Input findings allowed

- approved `training_identity`
- approved `body_change_trend`
- approved onboarding identity signals

#### Allowed claim types

- modality-led identity
- body-change modifiers such as leaning, building, or steady when repeated measurements support them
- training-style identity
- return / rebuilding identity when evidence supports it

#### Forbidden claim types

- labels inferred from a single metric
- personality claims
- future-goal labels that erase historical behavior

#### Structure

```json
{
  "label": "Strength-Led Hybrid",
  "explanation": "Your history is led by strength work, with meaningful but less consistent endurance training."
}
```

#### Archetype vocabulary

Use this initial controlled vocabulary and refine it later through product testing:

- `strength_led`
- `endurance_led`
- `hybrid`
- `sport_led`
- `mixed_training`
- `returning_athlete`
- `consistency_seeker`
- `insufficient_history`

The AI may render polished user-facing labels, but the backend should preserve the stable enum.

### 3. `current_training_state`

#### Job

Describe where the athlete is **now**, independently from who they are in general.

#### Must answer

- continuity state
- recent load state
- momentum / readiness state when supported

#### Input findings allowed

- approved recent-vs-baseline load evidence
- approved consistency evidence
- approved recent activity floor evidence
- approved recovery context when available
- recent onboarding declarations if they clarify a gap or return

#### Allowed claim types

- `stable`
- `building`
- `rebuilding`
- `interrupted`
- `sporadic`
- `high_recent_load`
- `recent_drop`
- `evidence_mixed`

#### Forbidden claim types

- current state from long-term history alone
- readiness verdicts from stale VO2, body, or recovery metrics
- "beginner" / "advanced" labels without sufficient evidence

#### Structure

```json
{
  "label": "Rebuilding with a usable base",
  "summary": "You trained consistently across most of the last 90 days, but the last 3 weeks show a clear drop in volume. HAYF should treat this as re-entry rather than starting from zero.",
  "evidence_ids": ["recent_load_drop", "historical_active_weeks"]
}
```

### 4. `physical_baseline`

#### Job

Show the body-composition baseline HAYF is actually planning from today.

#### Must answer

- current self-reported weight
- current self-reported height
- current estimated body-fat band

#### Allowed claim types

- "current self-reported baseline"
- imported body-trend context only when deterministic evidence says the trend is recent enough

#### Forbidden claim types

- treating a stale HealthKit body-fat or weight sample as current truth
- implying that an estimated band is a lab-grade measurement

### 5. `history_findings`

#### Job

Prove that HAYF actually looked at the athlete's history.

#### Must answer

- what repeated behavior or durable pattern is most revealing about this athlete

#### Input findings allowed

- approved workout-history findings
- approved activity-floor findings
- approved body / recovery findings only when they pass the strict evidence gates

#### Allowed claim types

- modality mix
- consistency pattern
- strongest historical period
- long-session tolerance
- modality continuity
- repeated gap pattern
- recent movement floor
- repeated body trend, only if valid

#### Forbidden claim types

- anything based on one stale or isolated measurement
- causal explanations not supported by onboarding or approved evidence
- more than one low-confidence finding in the visible set

#### Count

- 3 to 6 visible findings
- rank by:
  1. confidence
  2. coaching relevance
  3. surprise / emotional resonance

#### Structure

```json
{
  "id": "strength_anchor",
  "title": "Strength is your anchor",
  "summary": "You logged 24 strength sessions in the last 90 days, more consistently than any other modality.",
  "evidence_class": "current",
  "confidence": "high",
  "evidence_ids": ["strength_sessions_90d", "modality_mix_90d"]
}
```

#### Preferred categories

- `identity`
- `consistency`
- `capacity`
- `seasonality`
- `recovery_context`
- `body_context`

#### Ranking guidance

Prefer:

- high-confidence workout findings
- repeated historical patterns
- findings that explain why the later strategy will look the way it does

Deprioritize:

- generic observations
- stale body context
- low-relevance curiosities

### 5. `goal_fit`

#### Job

Explain the relationship between this athlete and the chosen goal before revealing the strategy.

#### Must answer

- does this goal fit the athlete well
- what helps
- what needs to change

#### Input findings allowed

- onboarding goal details
- approved training identity
- approved current training state
- approved capacity / consistency / readiness signals
- approved body or recovery evidence only if the goal depends on them and quality is high

#### Allowed statuses

- `natural_fit`
- `stretch_but_coherent`
- `premature`
- `mismatch`
- `insufficient_evidence`

#### Structure

```json
{
  "status": "stretch_but_coherent",
  "headline": "Ambitious but coherent",
  "summary": "A half marathon fits your endurance interest and weekly availability, but your recent running continuity is thin. The goal becomes realistic if running turns into a protected weekly behavior instead of an occasional add-on.",
  "supports": [
    "You have enough historical weekly volume to rebuild from.",
    "Weekend long-session tolerance is already present."
  ],
  "gaps": [
    "Recent run frequency is lower than the goal requires."
  ],
  "evidence_ids": ["goal_half_marathon", "running_frequency_28d", "long_session_tolerance"]
}
```

#### Forbidden claim types

- goal success guarantees
- medical or injury predictions
- use of stale body / recovery metrics as readiness facts
- declaring a mismatch only because the athlete's preferences differ from their history

#### Branch rule

`goal_fit` applies to all onboarding branches equally.

- Concrete goals are assessed against the athlete's evidence and chosen timeframe.
- Goal-discovery goals are assessed against the athlete's evidence and chosen direction.
- Consistency is also treated as a real goal: the goal is to become more consistent.

When goal-fit logic needs a timeframe and none is available, use a 12-week fallback horizon. This same 12-week fallback applies anywhere a timeframe is required but missing.

## Supporting Evidence Model

Every visible section should reference underlying evidence IDs, even if the UI does not show them inline.

Recommended evidence object:

```json
{
  "id": "strength_sessions_90d",
  "category": "workout_history",
  "claim": "strength_continuity",
  "value_summary": "24 sessions in 90 days",
  "evidence_class": "current",
  "confidence": "high",
  "source_kind": "healthkit",
  "observed_window": "90d",
  "latest_observed_at": "2026-05-12",
  "allowed_claims": ["strength_anchor", "strength_led_identity"],
  "forbidden_claims": ["current_strength_level"]
}
```

## AI Output Schema

The AI should return structured JSON only. `athlete_profile_scores` is intentionally absent from this authored schema: the backend merges the exact deterministic envelope after structured generation.

```json
{
  "coach_read": {
    "text": "string",
    "evidence_ids": ["string"]
  },
  "athlete_archetype": {
    "kind": "strength_led | endurance_led | hybrid | sport_led | mixed_training | returning_athlete | consistency_seeker | insufficient_history",
    "label": "string",
    "explanation": "string",
    "evidence_ids": ["string"]
  },
  "current_training_state": {
    "kind": "stable | building | rebuilding | interrupted | sporadic | high_recent_load | recent_drop | evidence_mixed",
    "label": "string",
    "summary": "string",
    "evidence_ids": ["string"]
  },
  "history_findings": [
    {
      "id": "string",
      "category": "identity | consistency | capacity | seasonality | recovery_context | body_context",
      "title": "string",
      "summary": "string",
      "confidence": "high | medium | low",
      "evidence_ids": ["string"]
    }
  ],
  "goal_fit": {
    "status": "natural_fit | stretch_but_coherent | premature | mismatch | insufficient_evidence",
    "headline": "string",
    "summary": "string",
    "supports": ["string"],
    "gaps": ["string"],
    "evidence_ids": ["string"]
  },
  "omitted_findings": [
    {
      "reason": "stale | sparse | contradictory | low_relevance",
      "evidence_ids": ["string"]
    }
  ]
}
```

## AI Responsibilities

### The AI may

- select the strongest supported findings
- write concise, high-quality user-facing prose
- combine multiple approved findings into a coherent coach read
- explain goal fit from approved supports and gaps

### The AI may not

- create a new evidence ID
- reference a fact not present in the packet
- convert `historical` evidence into a current claim
- include a section whose required evidence is missing
- expose omitted findings just to fill space

## Rich-Data Example

```json
{
  "coach_read": {
    "text": "You are a strength-led hybrid athlete with a better base than your recent rhythm suggests. Strength has been your most durable training anchor, while endurance appears more in bursts than as a steady habit. Your goal is realistic, but only if aerobic work becomes protected rather than optional.",
    "evidence_ids": ["training_identity_strength_led_hybrid", "strength_anchor", "recent_run_frequency_low", "goal_half_marathon"]
  },
  "athlete_archetype": {
    "kind": "hybrid",
    "label": "Strength-Led Hybrid",
    "explanation": "Your training history is led by strength work, with meaningful but less consistent endurance training.",
    "evidence_ids": ["training_identity_strength_led_hybrid"]
  },
  "current_training_state": {
    "kind": "rebuilding",
    "label": "Rebuilding with a usable base",
    "summary": "You trained consistently across most of the last 90 days, but the last 3 weeks show a clear drop in volume. HAYF should treat this as re-entry rather than starting from zero.",
    "evidence_ids": ["historical_active_weeks", "recent_load_drop"]
  },
  "history_findings": [
    {
      "id": "strength_anchor",
      "category": "identity",
      "title": "Strength is your anchor",
      "summary": "You logged 24 strength sessions in the last 90 days, more consistently than any other modality.",
      "confidence": "high",
      "evidence_ids": ["strength_sessions_90d", "modality_mix_90d"]
    },
    {
      "id": "endurance_in_bursts",
      "category": "consistency",
      "title": "Endurance comes in bursts",
      "summary": "Your running appears in clusters rather than as a protected weekly habit.",
      "confidence": "high",
      "evidence_ids": ["running_frequency_by_week", "recent_run_frequency_low"]
    },
    {
      "id": "weekend_capacity",
      "category": "capacity",
      "title": "You can handle one longer session",
      "summary": "Your history includes repeated 70+ minute weekend sessions, which gives the strategy room for one longer aerobic anchor.",
      "confidence": "high",
      "evidence_ids": ["long_session_tolerance"]
    }
  ],
  "goal_fit": {
    "status": "stretch_but_coherent",
    "headline": "Ambitious but coherent",
    "summary": "A half marathon fits your endurance interest and weekly availability, but your recent running continuity is thin. The goal becomes realistic if running turns into a protected weekly behavior instead of an occasional add-on.",
    "supports": [
      "You have enough historical weekly volume to rebuild from.",
      "Weekend long-session tolerance is already present."
    ],
    "gaps": [
      "Recent run frequency is lower than the goal requires."
    ],
    "evidence_ids": ["goal_half_marathon", "historical_weekly_volume", "long_session_tolerance", "recent_run_frequency_low"]
  },
  "omitted_findings": [
    {
      "reason": "stale",
      "evidence_ids": ["body_fat_percentage_latest"]
    }
  ]
}
```

## Empty / Thin-Evidence Behavior

If a section lacks required evidence:

- `coach_read` still exists, but leans more on onboarding declarations and says less
- `athlete_archetype.kind = insufficient_history` when no durable pattern can be inferred
- `current_training_state.kind = evidence_mixed` when present-state evidence is weak
- `history_findings` may contain fewer than 3 items
- `goal_fit.status = insufficient_evidence` if the relationship between athlete and goal cannot be responsibly assessed

The UI should never pad weak evidence with weaker prose.

## Interaction Model

The first reveal should stay clean and emotionally direct. Each visible section may later be tappable and open a compact detail card that explains why HAYF believes the claim.

Recommended detail-card contents:

- section title
- user-facing claim
- 2 to 4 supporting evidence bullets
- confidence
- observation window
- any relevant caveat, such as stale or incomplete data

The main screen should prioritize the read; the detail card should provide the audit trail on demand.

## Product Decisions To Lock

1. The blueprint is a report, not a dashboard.
2. The user-facing report has five sections only.
3. Workout history is the dominant source of athlete identity.
4. Goal fit is visible because the report should lead naturally into the later Fitness Strategy.
5. Goal fit applies to every onboarding branch, including consistency.
6. Consistency is treated as a real goal; use a 12-week fallback horizon whenever goal-fit logic requires a timeframe and none is available.
7. Hidden coach-side findings exist and should feed planning, but they do not belong in the first reveal.
8. Every visible section must remain auditable back to approved evidence IDs.
9. Every visible section should be able to open a compact "why HAYF thinks this" detail card later.
