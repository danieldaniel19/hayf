# HAYF Health Evidence Spec

Status: working source of truth for Athlete Blueprint evidence design.

## Purpose

The Athlete Blueprint must feel uncannily perceptive without making claims the data cannot support.

HealthKit is an evidence source, not a direct truth source. HAYF may read broad HealthKit data locally, but no AI model should receive raw HealthKit samples or be asked to infer directly from them. Device-side deterministic transforms must convert raw samples into labelled, quality-gated evidence first.

The contract is:

1. raw HealthKit samples stay on device
2. deterministic functions build compact evidence summaries with provenance and quality metadata
3. only vetted evidence summaries reach backend storage or AI generation
4. the AI may phrase, synthesize, and prioritize evidence, but it may not invent new facts from raw samples it never sees

## Evidence Classes

Every metric or finding must be classified before it can be used in the Athlete Blueprint.

| Class | Meaning | Allowed use |
| --- | --- | --- |
| `current` | Recent enough and sufficiently supported to describe present state | present-tense claims |
| `trend` | Repeated enough over time to describe direction | trend claims |
| `historical` | Real but not recent enough for present-state claims | background context only |
| `insufficient` | Too sparse, stale, or contradictory | no user-facing claim |

Every derived evidence item must carry:

- `source_kind`: `healthkit`, `onboarding`, or later `manual` / `feedback`
- `observed_window`
- `latest_observed_at`
- `sample_count`
- `days_with_data` when relevant
- `recency_class`
- `coverage_class`
- `confidence`
- `allowed_claims`
- `forbidden_claims`

## Current Athlete Blueprint Surface

The user-facing blueprint should show:

1. `coach_read`
2. `athlete_archetype`
3. `current_training_state`
4. `history_findings`
5. `goal_fit`

The section-level output contract is defined in `docs/athlete-blueprint-spec.md`.

The following remain coach-side planning inputs, not frontend blueprint sections:

- coaching profile
- strengths to exploit
- constraints and risks
- coaching priorities

## HealthKit Input Inventory

The current iOS prototype already requests read-only access to:

- workouts and workout routes
- sleep analysis
- step count, active energy, exercise time, walking/running distance, cycling distance
- resting heart rate, HRV SDNN, respiratory rate, oxygen saturation, VO2 max
- body metrics such as body mass, body fat percentage, lean body mass, waist circumference, height, BMI
- optional nutrition logs

The app must continue to treat every HealthKit type as optional.

## Deterministic Device-Side Pipeline

### Stage 1: raw collectors

Collectors query HealthKit and return typed local samples only:

- `collectWorkoutSamples`
- `collectSleepSamples`
- `collectDailyActivitySamples`
- `collectRecoverySamples`
- `collectBodyMetricSamples`
- `collectNutritionSamples`

These functions do no interpretation. They only normalize:

- identifier
- value
- unit
- start date
- end date
- source metadata when useful

### Stage 2: quality profilers

Quality profilers decide whether a metric is usable:

- `profileSampleRecency`
- `profileSampleDensity`
- `profileWindowCoverage`
- `profileSeriesContinuity`
- `classifyEvidenceUsability`

They output metadata such as:

- latest sample age
- sample count by window
- nights or days with data
- gap length
- overlap / continuity
- `current`, `trend`, `historical`, or `insufficient`

### Stage 3: feature builders

Feature builders turn raw samples into compact evidence:

- `buildWorkoutEvidence`
- `buildActivityEvidence`
- `buildSleepEvidence`
- `buildRecoveryEvidence`
- `buildBodyEvidence`
- `buildNutritionEvidence`

Each builder returns descriptive facts plus quality metadata. No prose and no diagnosis.

### Stage 4: cross-signal interpreters

Interpreters are still deterministic. They combine already-vetted features into bounded findings:

- `deriveTrainingIdentity`
- `deriveCurrentTrainingState`
- `deriveConsistencyPattern`
- `deriveRecoveryContext`
- `deriveGoalReadinessSignals`
- `deriveEvidenceBackedFindings`

These functions may emit claims only from allowed evidence classes.

### Stage 5: AI input packager

`buildAthleteBlueprintContextPacket` produces the only payload the AI may read.

It should contain:

- onboarding answers
- current goal
- approved evidence summaries
- approved findings
- confidence and provenance
- explicit `do_not_claim` notes where evidence is stale or insufficient

It must never contain:

- raw HealthKit samples
- full time series
- isolated stale values presented without classification
- fields whose `allowed_claims` is empty

## Metric Family Rules

### 1. Workouts

#### HealthKit inputs

- workout date/time
- modality
- duration
- distance when available
- energy when available

#### Deterministic transforms

- `buildWorkoutLedger`
- `buildModalityMix`
- `buildConsistencySummary`
- `buildLoadWindows`
- `buildSeasonalitySummary`
- `buildSessionToleranceSummary`
- `buildPerformanceProxySummary`
- `buildStrengthContinuitySummary`

#### Rich-data threshold

- enough workout history to analyze repeated behavior, preferably at least 12 weeks of nontrivial history
- enough sessions for the specific claim being made

#### Allowed blueprint claims

- dominant training modalities
- hybrid / strength-led / endurance-led patterns
- active-week consistency
- recent load relative to prior windows
- long-session tolerance
- strongest historical month / season
- modality continuity

#### Forbidden claims

- exact fitness level from workout count alone
- recovery status from workout volume alone
- causal claims such as "you stop training because you get bored"

#### Notes

Workout history is the highest-trust source for the first blueprint because it is repeated behavioral evidence rather than an isolated measurement.

### 2. Daily activity

#### HealthKit inputs

- steps
- active energy
- Apple exercise time
- walking/running distance
- cycling distance

#### Deterministic transforms

- `buildActivityFloorSummary`
- rolling 7-day and 28-day averages
- recent-versus-baseline deltas

#### Rich-data threshold

- at least 5 days of data in 7 days for short-window claims
- at least 21 days of data in 28 days for stable baseline claims

#### Allowed blueprint claims

- background movement floor is high / moderate / low relative to the user's own history
- recent general activity has risen or fallen

#### Forbidden claims

- formal conditioning claims from steps alone
- exact energy expenditure interpretation

### 3. Sleep

#### HealthKit inputs

- `sleepAnalysis` category samples
- asleep intervals and stage categories where available

#### Deterministic transforms

- `mergeAsleepIntervals`
- `buildNightlySleepSeries`
- `buildSleepWindowSummary`
- `buildSleepRegularitySummary`

#### Rich-data threshold

- at least 10 recorded nights in 14 days for recent-duration claims
- at least 21 recorded nights in 28 days for regularity claims

#### Allowed blueprint claims

- recent sleep duration is short / adequate / variable relative to the user's own record
- sleep evidence is rich or patchy

#### Forbidden claims

- recovery state from sleep alone
- strong sleep-stage interpretations in v1
- claims based on one or two recorded nights

#### Notes

Use total asleep duration and regularity first. Sleep stages may be stored locally for future research, but the first blueprint should not rely on them.

### 4. Resting heart rate

#### HealthKit inputs

- resting heart rate samples

#### Deterministic transforms

- `buildRHRSeries`
- `buildPersonalBaseline`
- `compareRecentToBaseline`

#### Rich-data threshold

- at least 5 days with data in the recent 7-day window
- at least 21 days with data in the 28-day baseline window

#### Allowed blueprint claims

- recent RHR is near / above / below personal baseline

#### Forbidden claims

- population-norm judgements
- recovery diagnosis from RHR alone

### 5. HRV

#### HealthKit inputs

- HRV SDNN samples

#### Deterministic transforms

- `buildHRVSeries`
- `buildPersonalBaseline`
- `compareRecentToBaseline`

#### Rich-data threshold

- at least 5 days with data in the recent 7-day window
- at least 21 days with data in the 28-day baseline window

#### Allowed blueprint claims

- recent HRV is near / above / below personal baseline

#### Forbidden claims

- "good HRV" / "bad HRV" from population comparison
- recovery diagnosis from HRV alone

### 6. Recovery context

#### HealthKit inputs

- sleep summary
- RHR summary
- HRV summary
- respiratory-rate trend when available
- recent training load

#### Deterministic transforms

- `deriveRecoveryContext`

#### Rich-data threshold

- enough coverage for at least two independent signals

#### Allowed blueprint claims

- recent recovery signals look clear, mixed, or strained

#### Required evidence rule

To emit a strained-recovery finding, require either:

1. two physiological signals moving adversely versus personal baseline, or
2. one adverse physiological signal plus materially short sleep plus elevated recent load

#### Forbidden claims

- binary "recovered / not recovered" labels
- diagnosis
- recovery inference from a single metric

### 7. VO2 max

#### HealthKit inputs

- latest VO2 max sample

#### Deterministic transforms

- `classifyLatestVO2Recency`

#### Rich-data threshold

- latest sample within 90 days

#### Allowed blueprint claims

- recent cardio-fitness marker exists
- cardio-fitness marker is stale

#### Forbidden claims

- current aerobic readiness from a stale VO2 max sample
- broad athlete archetype from VO2 max alone

### 8. Body mass

#### HealthKit inputs

- body-mass samples

#### Deterministic transforms

- `buildBodyMassSeries`
- `classifyCurrentBodyMass`
- `deriveBodyMassTrend`

#### Rich-data threshold

- `current`: latest sample within 30 days
- `trend`: at least 4 samples across at least 21 days

#### Allowed blueprint claims

- current body mass, only when recent
- rising / stable / falling trend, only with repeated measurements

#### Forbidden claims

- current weight from a stale sample
- trend from one or two measurements

### 9. Body fat percentage

#### HealthKit inputs

- body-fat-percentage samples

#### Deterministic transforms

- `buildBodyFatSeries`
- `classifyCurrentBodyFat`
- `deriveBodyFatTrend`

#### Rich-data threshold

- `current`: latest sample within 30 days plus at least 2 samples within 90 days
- `trend`: at least 3 samples across at least 30 days

#### Allowed blueprint claims

- current body-fat context only when repeated and recent
- body-composition trend only when repeated over time

#### Forbidden claims

- using a lone stale body-fat sample as current state
- body-composition coaching claims from isolated readings

### 10. Lean mass / waist circumference

#### HealthKit inputs

- lean body mass
- waist circumference

#### Deterministic transforms

- same pattern as body metrics, with strict recency and density checks

#### Allowed blueprint claims

- historical body-context availability
- current or trend claims only when recent and repeated

#### Forbidden claims

- present-state claims from isolated stale readings

### 11. Nutrition

#### HealthKit inputs

- energy
- protein
- carbohydrate
- fat
- water
- other available logs

#### Deterministic transforms

- `buildNutritionCoverageSummary`
- `buildNutritionWindowSummary`

#### Rich-data threshold

- at least 21 of the last 28 days with energy logged before nutrition becomes blueprint-grade evidence

#### Allowed blueprint claims

- nutrition logging is consistent / sparse
- nutrition context is available for later strategy

#### Forbidden claims

- broad eating-pattern claims from sparse logs
- body-composition causality from nutrition logs alone

## AI Guardrails

### The AI may receive

- `approved_findings`
- `approved_metric_summaries`
- `confidence`
- `provenance`
- `allowed_claims`
- `forbidden_claims`
- explicit caveats such as `body_fat_current_state_not_supported`

### The AI may not receive

- raw HealthKit rows
- raw sleep samples
- raw body-measurement series
- raw heart-rate or HRV samples
- unlabeled isolated latest values

### The AI is allowed to

- choose the clearest user-facing wording
- combine approved findings into a coach-style read
- prioritize the most meaningful findings
- explain the goal fit using approved evidence

### The AI is not allowed to

- derive a new physiological claim from unapproved metrics
- turn `historical` evidence into `current` evidence
- make a user-facing claim whose support is marked `forbidden`
- invent motivations or causal explanations not present in onboarding or approved findings

## Required Device-Side Functions Before Blueprint Generation

These functions are required for the rich-data version of the Athlete Blueprint:

### Collectors

- `collectWorkoutSamples`
- `collectSleepSamples`
- `collectActivitySamples`
- `collectRecoverySamples`
- `collectBodyMetricSamples`
- `collectNutritionSamples`

### Profilers

- `profileRecency`
- `profileDensity`
- `profileCoverage`
- `profileContinuity`
- `classifyEvidence`

### Builders

- `buildWorkoutEvidence`
- `buildActivityEvidence`
- `buildSleepEvidence`
- `buildRecoveryMetricEvidence`
- `buildBodyMetricEvidence`
- `buildNutritionEvidence`

### Interpreters

- `deriveTrainingIdentity`
- `deriveCurrentTrainingState`
- `deriveConsistencyPattern`
- `deriveRecoveryContext`
- `deriveGoalFitInputs`
- `deriveApprovedBlueprintFindings`

### Packager

- `buildAthleteBlueprintContextPacket`

## Current Prototype Gaps

The existing prototype already has good foundations:

- broad HealthKit read scope
- six-year workout import
- workout-ledger windows
- training identity, consistency, seasonality, load, performance, strength continuity
- conservative merged sleep-duration calculation
- compact feature snapshots instead of raw HealthKit upload

Before Athlete Blueprint launch, the following gaps must be closed:

1. latest body and VO2 fields need sample dates preserved through the feature model
2. sleep summaries need nights-with-data and regularity metadata
3. RHR and HRV need day-level recent windows and personal baselines, not only 14-day averages
4. body metrics need recency and density classification
5. all blueprint-facing evidence needs explicit `allowed_claims` / `forbidden_claims`
6. AI input packets need hard exclusion of raw and unapproved fields

## Product Rules To Lock

1. No present-tense claim from a stale isolated sample.
2. No trend claim without repeated observations over time.
3. No recovery inference from a single metric.
4. No population-norm claim where personal baseline is the right comparison.
5. Workout history is the primary evidence source for the first Athlete Blueprint.
6. Body and recovery metrics enrich the blueprint only when evidence quality is high.
7. The user-facing blueprint may sound elegant, but the underlying evidence path must remain inspectable and auditable.
