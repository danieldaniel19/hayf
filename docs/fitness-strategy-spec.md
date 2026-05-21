# HAYF Fitness Strategy Spec

Status: working source of truth for the user-facing Fitness Strategy artifact shown after Athlete Blueprint acceptance.

## Purpose

The Fitness Strategy is the second post-onboarding payoff.

The Athlete Blueprint answers:

> Who does HAYF believe it is coaching?

The Fitness Strategy answers:

> Given this athlete and this goal, how will HAYF coach them toward it?

The strategy is not the goal repeated back to the user, and it is not yet the week-by-week plan. It is the coach's plan of attack: the approach, the structure that supports it, and the targets that will tell HAYF whether it is working.

## Product Placement

The first post-onboarding sequence should be:

1. onboarding summary
2. Apple Health
3. Athlete Blueprint
4. Fitness Strategy
5. Plan

Mental model:

```text
Blueprint = this is who you are
Strategy = this is how HAYF will coach you
Plan = this is what you do next
```

After the user accepts the Fitness Strategy, HAYF should open the first visible planning window:

- current week as `committed`
- next week as `draft`
- first workouts already scheduled

The same strategy artifact should be persisted for later review elsewhere in the app, likely from Profile, even though the final navigation home is not decided yet.

## Design Principles

1. Do not repeat the goal summary the user just reviewed during onboarding.
2. Use the goal only as quiet context for why this strategy exists.
3. Make the strategy feel personally derived from both the goal and the Athlete Blueprint.
4. Separate strategy from execution:
   - this screen explains the approach
   - Plan shows the first two weeks
5. Targets should feel central, not like analytics afterthoughts.
6. Time-bound goals show phases.
7. Consistency goals do not receive fake phases; they show an operating rhythm instead.
8. The user goal target is context; HAYF strategy targets are the derived success signals for the coaching approach.
9. Phased strategies show phase targets inside each phase. Weekly targets are introduced later in Plan, not on the reveal screen.
10. Every major section should later be able to open a compact detail affordance such as:
   - why this strategy
   - why these phases
   - why these targets

## User-Facing Sections

### 1. `strategy_read`

#### Job

Deliver the opening verdict. This is the emotional center of the screen and the closest strategy analogue to the Blueprint `coach_read`.

#### Must answer

- what the overall coaching approach is
- why that approach fits this athlete
- what HAYF is protecting or changing to make the goal realistic

#### Should not do

- restate the goal in different words
- list every onboarding answer
- drift into workout scheduling detail

#### Length

- 2 to 4 sentences
- 45 to 90 words

#### Example Shape

> Your best route is to make the chosen training path repeatable before asking it to become more demanding. HAYF will use your history as context, but the strategy should stay pointed at the goal and constraints you selected. Progression is earned when the week is holding.

### 2. `strategy_pillars`

#### Job

Show the few rules HAYF will use to steer the strategy.

#### Must answer

- what HAYF will prioritize
- what tradeoffs it will make
- what should stay true even as workouts vary

#### Structure

```json
[
  {
    "id": "protect_chosen_path",
    "title": "Protect the chosen path",
    "summary": "The training path selected in onboarding should stay visible while goal-specific work builds around it."
  }
]
```

#### Guidance

- usually 3 to 4 pillars
- each pillar should be a consequence of the athlete read, not a generic fitness truism
- keep the language general enough that historical modalities do not leak into the strategy
- protect the user-selected training path, then use history only when it supports that path

### 3A. `phase_outline`

Used when the goal is time-bound and the strategy requires phases.

#### Job

Show the arc that supports the strategy without revealing a full long-term calendar.

#### Must answer

- what broad stages support the goal
- what each stage is trying to accomplish
- what target or signal matters most in that stage

#### Structure

```json
[
  {
    "id": "base",
    "name": "Base",
    "objective": "Make the weekly rhythm repeatable before adding more demanding work.",
    "targetSummary": "Hold 3 weekly exposures with recovery intact.",
    "phaseTargets": [
      {
        "id": "base_repeatable_weeks",
        "scope": "phase",
        "title": "3 repeatable weeks",
        "summary": "Prove the weekly structure can hold before HAYF asks for more.",
        "metricKey": "phase_weeks_with_min_sessions",
        "targetValue": 3,
        "unit": "weeks"
      }
    ]
  }
]
```

#### Guidance

- required for time-bound concrete goals
- omitted for consistency goals
- should remain directional, not calendar-dense

### 3B. `operating_rhythm`

Used instead of phases for consistency goals.

#### Job

Explain the repeatable structure HAYF is trying to protect.

#### Must answer

- what a good recurring week looks like
- what the bad-day floor is
- how often the strategy should be reviewed

#### Structure

```json
{
  "summary": "Three repeatable training exposures, one low-friction recovery option, and a 28-day review cadence.",
  "anchors": [
    "Protect three weekly training exposures",
    "Use the bad-day floor before skipping completely",
    "Review the rhythm every 28 days"
  ]
}
```

### 4. `strategy_targets`

#### Job

Show the measurable end-of-strategy signals that keep HAYF honest.

#### Must answer

- what HAYF will watch
- what success looks like by the end of the strategy timeframe
- how the user will know they are on track

#### Structure

```json
[
  {
    "id": "weekly_training_time",
    "scope": "strategy | phase | week",
    "title": "Weekly training time",
    "summary": "The planned training dose HAYF wants to hold consistently before progressing.",
    "metricKey": "training_minutes_7d",
    "targetValue": 180,
    "unit": "min"
  }
]
```

#### Guidance

- show exactly three peer strategy targets on the reveal screen
- strategy targets are derived from the goal target and Athlete Blueprint
- capstone events may be one strategy target, but never the whole strategy narrative
- for phased branches, show exactly three phase targets inside each phase
- weekly targets are not shown on this reveal; they arrive with the weekly Plan
- targets should exist whenever they can be made meaningful
- only omit when a target would be fake, misleading, or not measurable yet

### 5. `strategy_detail`

#### Job

Support the later "why this strategy" affordance.

#### Must contain

- concise rationale
- blueprint findings that influenced the strategy
- relevant constraints or risks
- high-level tradeoff explanation

This is not necessarily shown inline on the first screen, but the data should exist from the start.

## Output Contract

The first user-facing Strategy artifact should be able to serialize to:

```json
{
  "goalTargetContext": {
    "title": "string",
    "summary": "string"
  },
  "strategyRead": "string",
  "fitReasons": [
    {
      "id": "string",
      "title": "string",
      "summary": "string"
    }
  ],
  "strategyPillars": [
    {
      "id": "string",
      "title": "string",
      "summary": "string"
    }
  ],
  "phaseOutline": [
    {
      "id": "string",
      "name": "string",
      "objective": "string",
      "targetSummary": "string",
      "phaseTargets": [
        {
          "id": "string",
          "family": "consistency | modality_presence | capacity_metric | performance_metric | body_trend | capstone",
          "modality": "string | null",
          "title": "string",
          "summary": "string",
          "proposedDisplayValue": "string | null",
          "targetValue": "number | null",
          "unit": "string | null",
          "rationale": "string",
          "capstone": {
            "isCapstone": "boolean",
            "whyAppropriate": "string | null"
          }
        }
      ]
    }
  ],
  "operatingRhythm": {
    "summary": "string",
    "anchors": ["string"]
  },
  "strategyTargets": [
    {
      "id": "string",
      "family": "consistency | modality_presence | capacity_metric | performance_metric | body_trend | capstone",
      "modality": "string | null",
      "title": "string",
      "summary": "string",
      "proposedDisplayValue": "string | null",
      "targetValue": "number | null",
      "unit": "string | null",
      "rationale": "string",
      "capstone": {
        "isCapstone": "boolean",
        "whyAppropriate": "string | null"
      }
    }
  ],
  "strategyDetail": {
    "summary": "string",
    "blueprintDrivers": ["string"],
    "constraints": ["string"],
    "tradeoffs": ["string"]
  }
}
```

Contract rules:

- target generation is a separate AI pass: `generate_fitness_strategy_targets` receives `targetBrief` and ID-only `targetSlots`, never prebuilt deterministic capstone titles or metric contracts.
- strategy copy is a second AI pass: `generate_fitness_strategy` receives only the validated target artifact in `sectionSeeds` and must not redesign targets.
- `phaseOutline` is required when the active goal requires phases.
- `phaseOutline` is empty for consistency goals.
- every phase in `phaseOutline` must include exactly three `phaseTargets`.
- `operatingRhythm` is required for consistency goals.
- `operatingRhythm` may be `null` for phased goals.
- `strategyTargets` should contain exactly three peer strategy targets whenever meaningful targets can be generated.
- `goalTargetContext` is shown as quiet context and is not counted as a strategy target.
- week and session targets are omitted from this reveal.
- onboarding intent, chosen training options, access, and avoidances define the strategy's modality path.
- history can size or explain matching targets, but it cannot introduce a modality, dependency, capstone, or anchor the user did not choose.
- target rows must show a human-readable numeric target value such as a range, cadence, percentage, time delta, distance, count, or frequency; raw metric keys and anonymous numeric chips are not user-facing copy.
- non-target labels such as review, signal, decision, check-in, stable, before skip, and next move are not valid targets.
- target titles are compact UI labels, not explanations. They should name one computable outcome in a short phrase, with the numeric value in the pill.
- target summaries may exist in the artifact for auditability, but the reveal renders targets as one-line measurable rows rather than title/subtitle cards.
- generic result-count targets are not valid unless the product explicitly schedules and logs that result as a workout or in-app measurement.
- AI proposes target concepts, titles, summaries, thresholds, and optional capstones from the target brief.
- deterministic code validates target proposals against goal semantics, selected modalities, access, avoidances, horizon, and supported target families before mapping them to app metric keys and persisted target contracts.
- capstones are allowed only when they naturally prove the user's goal; history alone cannot create one.

## Screen Composition

Phased branches are split across two onboarding screens to keep the reveal readable.

Recommended strategy screen order:

1. intro
2. strategy snapshot
3. coach verdict
4. goal context
5. why this fits you
6. what HAYF will protect
7. strategy targets
8. operating rhythm for consistency goals

Recommended phase screen order:

1. phase intro
2. phase outline with compact phase targets
3. bridge to Plan explaining that weekly targets come next

Recommended CTA:

- strategy screen, phased branch: `Review phases`
- phase screen and consistency strategy screen: `Accept strategy`
- secondary: `Review Athlete Blueprint`

The final CTA should lead directly into the first two-week Plan experience.

## Later In-App Reuse

The Strategy artifact should be persisted as a durable object because:

- the user may want to review the current strategy later
- the coach may replace the strategy mid-goal
- future explanations should reference which strategy version shaped a week or workout

Likely later homes:

- Profile > Current Strategy
- a detail sheet reachable from Plan

The navigation decision can stay open. The artifact should not.
