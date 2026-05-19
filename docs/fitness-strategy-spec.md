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
8. Every major section should later be able to open a compact detail affordance such as:
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

#### Example

> Your best route is not more ambition. It is a strength-led, consistency-protected build that keeps aerobic work regular enough to support the goal without sacrificing the training identity you already sustain best. HAYF will bias toward repeatable progress first, then earn harder work once the week is holding.

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
    "id": "protect_strength_anchor",
    "title": "Keep strength as the anchor",
    "summary": "Your most durable training pattern should stay protected while the goal-specific work builds around it."
  }
]
```

#### Guidance

- usually 3 to 4 pillars
- each pillar should be a consequence of the athlete read, not a generic fitness truism
- examples:
  - protect repeatable training exposures
  - keep strength as the anchor
  - build aerobic work gradually
  - preserve recovery slack
  - reduce friction before adding complexity

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
    "targetSummary": "Hold 3 weekly exposures with recovery intact."
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

Show the measurable signals that keep the strategy honest.

#### Must answer

- what HAYF will watch
- what success looks like
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

- show a curated set on the reveal screen:
  - one primary target
  - two to four supporting targets
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
  "strategyRead": "string",
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
      "targetSummary": "string"
    }
  ],
  "operatingRhythm": {
    "summary": "string",
    "anchors": ["string"]
  },
  "strategyTargets": [
    {
      "id": "string",
      "scope": "strategy | phase | week",
      "title": "string",
      "summary": "string",
      "metricKey": "string | null",
      "targetValue": "number | null",
      "unit": "string | null"
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

- `phaseOutline` is required when the active goal requires phases.
- `phaseOutline` is empty for consistency goals.
- `operatingRhythm` is required for consistency goals.
- `operatingRhythm` may be `null` for phased goals.
- `strategyTargets` should be non-empty whenever meaningful targets can be generated.

## Screen Composition

Recommended screen order:

1. intro
2. `strategy_read`
3. `strategy_pillars`
4. `phase_outline` or `operating_rhythm`
5. `strategy_targets`

Recommended CTA:

- primary: `Accept strategy`
- secondary: `Review Athlete Blueprint`

The CTA should lead directly into the first two-week Plan experience. Do not insert another conceptual screen between Strategy and Plan.

## Later In-App Reuse

The Strategy artifact should be persisted as a durable object because:

- the user may want to review the current strategy later
- the coach may replace the strategy mid-goal
- future explanations should reference which strategy version shaped a week or workout

Likely later homes:

- Profile > Current Strategy
- a detail sheet reachable from Plan

The navigation decision can stay open. The artifact should not.
