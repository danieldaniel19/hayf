# HAYF Athlete Blueprint Context Packet

Status: implementation-facing contract between deterministic evidence processing and Athlete Blueprint generation.

## Purpose

The Athlete Blueprint Context Packet is the only payload an AI model may read when generating the user-facing Athlete Blueprint.

Its job is to:

1. normalize onboarding inputs
2. normalize the user's goal across all onboarding branches
3. include only approved, quality-gated evidence
4. include hidden coach-side findings needed for synthesis
5. explicitly state what the model must not claim

The packet exists to prevent the model from inferring directly from raw HealthKit data or from treating stale / sparse values as present truth.

## Non-Negotiable Boundary

The packet may include:

- onboarding declarations
- normalized goal
- approved evidence summaries
- approved visible findings
- approved hidden coach-side findings
- confidence, provenance, and forbidden-claim metadata

The packet may not include:

- raw HealthKit samples
- raw sleep intervals
- raw time series
- unlabeled latest values
- evidence whose allowed-claim set is empty
- stale values without an explicit evidence class and caveat

## Top-Level Schema

```json
{
  "packet_version": "1.0",
  "generated_at": "2026-05-17T10:00:00Z",
  "user_context": {},
  "normalized_goal": {},
  "onboarding_profile": {},
  "approved_evidence": [],
  "approved_findings": [],
  "hidden_coach_inputs": {},
  "section_inputs": {},
  "do_not_claim": [],
  "omitted_evidence": []
}
```

## 1. `user_context`

### Purpose

Minimal user-level context needed to interpret dates and phrases correctly.

### Shape

```json
{
  "timezone": "Europe/Berlin",
  "locale": "en-US",
  "health_data_status": "connected | partial | unavailable",
  "evidence_richness": "rich | moderate | sparse"
}
```

### Notes

- This is not profile copy.
- It exists so date windows, fallbacks, and confidence are interpreted correctly.

## 2. `normalized_goal`

### Purpose

Represent all onboarding branches with one common goal contract so `goal_fit` works consistently everywhere.

### Shape

```json
{
  "kind": "consistency | concrete_goal | discovered_goal",
  "title": "string",
  "description": "string",
  "source": "stay_consistent | concrete_goal | find_goal",
  "assessment_horizon_weeks": 12,
  "assessment_horizon_source": "user_supplied | inferred | fallback_12w",
  "target_date": "2026-08-09",
  "tracking_mode": "adherence | completion | metric_progress | review",
  "goal_category": "consistency | endurance | strength | body_composition | sport_performance | general_fitness | custom",
  "declared_priority": "string",
  "chosen_candidate_id": "string | null"
}
```

### Branch normalization rules

#### Stay consistent

```json
{
  "kind": "consistency",
  "title": "Build a consistent training rhythm",
  "source": "stay_consistent",
  "assessment_horizon_weeks": 12,
  "assessment_horizon_source": "fallback_12w",
  "tracking_mode": "adherence",
  "goal_category": "consistency"
}
```

#### Concrete goal

- use the user's explicit goal and timeframe when available
- if timeframe is missing but later logic requires one, use `fallback_12w`

#### Goal discovery

- use the chosen / edited / blended candidate
- use the candidate timeframe when available
- otherwise use `fallback_12w`

### Product rule

Consistency is a real goal, not a null-goal branch. `goal_fit` must evaluate it like every other goal.

## 3. `onboarding_profile`

### Purpose

Carry user-declared information that is valid even when HealthKit is sparse.

### Shape

```json
{
  "intent": "stayConsistent | concreteGoal | findGoal",
  "feasible_training_options": [
    {
      "activity": "strength",
      "title": "Strength",
      "priority": 1
    }
  ],
  "motivation_anchors": ["string"],
  "motivation_note": "string",
  "goal_brief": "string",
  "goal_experience": "string",
  "goal_timeline": "string",
  "goal_priority": "string",
  "goal_direction": "string",
  "challenge_style": "string",
  "goal_avoidances": ["string"],
  "injury_notes": "string",
  "frequency_preference": "string",
  "session_length_preference": "string",
  "blockers": ["string"],
  "blocker_note": "string",
  "support_style": "string",
  "bad_day_floor": "string"
}
```

### Notes

- These fields come from onboarding and may feed both visible and hidden findings.
- The AI may use user-declared motives only when they are explicitly present here.
- The AI may not invent psychological explanations beyond these declarations.

## 4. `approved_evidence`

### Purpose

Contain metric-level evidence that has already passed deterministic validation.

### Shape

```json
{
  "id": "strength_sessions_90d",
  "category": "workout_history",
  "claim": "strength_continuity",
  "value_summary": "24 sessions in 90 days",
  "evidence_class": "current | trend | historical",
  "confidence": "high | medium | low",
  "source_kind": "healthkit | onboarding | manual | feedback",
  "observed_window": "90d",
  "latest_observed_at": "2026-05-12",
  "sample_count": 24,
  "days_with_data": null,
  "allowed_claims": ["strength_anchor", "strength_led_identity"],
  "forbidden_claims": ["current_strength_level"],
  "caveats": []
}
```

### Inclusion rules

Include only evidence that:

- is not `insufficient`
- has at least one allowed claim
- has explicit provenance
- is useful for either visible synthesis or hidden coach-side reasoning

## 5. `approved_findings`

### Purpose

Contain deterministic, bounded interpretations built from approved evidence.

### Shape

```json
{
  "id": "training_identity_strength_led_hybrid",
  "kind": "training_identity",
  "summary": "History is led by strength work with meaningful but less consistent endurance exposure.",
  "confidence": "high",
  "evidence_ids": ["strength_sessions_90d", "modality_mix_90d"],
  "allowed_sections": ["coach_read", "athlete_archetype", "history_findings"],
  "forbidden_sections": [],
  "allowed_claims": ["strength_led_identity", "hybrid_pattern"],
  "forbidden_claims": []
}
```

### Required finding families

When evidence supports them, the deterministic layer should attempt to produce:

- `training_identity`
- `current_training_state`
- `consistency_pattern`
- `capacity_pattern`
- `recovery_context`
- `body_context`
- `goal_readiness_signal`

## 6. `hidden_coach_inputs`

### Purpose

Carry the coach-side findings that should shape planning but are intentionally not frontend sections.

### Shape

```json
{
  "strengths_to_exploit": [
    {
      "id": "strength_anchor",
      "summary": "Strength is the athlete's most durable training behavior.",
      "evidence_ids": ["strength_sessions_90d"]
    }
  ],
  "constraints_and_risks": [
    {
      "id": "weekday_time_limit",
      "summary": "Declared weekday session tolerance is short.",
      "source_kind": "onboarding",
      "evidence_ids": ["session_length_preference"]
    }
  ],
  "coaching_profile": [
    {
      "id": "needs_low_friction_fallbacks",
      "summary": "User explicitly says low-friction fallbacks matter when life gets busy.",
      "source_kind": "onboarding",
      "evidence_ids": ["bad_day_floor", "blockers"]
    }
  ],
  "coaching_priorities": [
    {
      "id": "protect_strength_anchor",
      "summary": "Plans should preserve the user's durable strength habit.",
      "evidence_ids": ["strength_anchor"]
    }
  ]
}
```

### Notes

- These may feed the later Fitness Strategy directly.
- They may inform `coach_read` only when the implication is directly supported and not too operational for the user-facing report.

## 7. `section_inputs`

### Purpose

Make the permitted evidence boundary explicit for each of the five blueprint sections.

### Shape

```json
{
  "coach_read": {
    "finding_ids": ["training_identity_strength_led_hybrid", "recent_load_drop", "goal_requires_run_continuity"],
    "evidence_ids": ["strength_sessions_90d", "recent_load_ratio", "running_frequency_28d"],
    "must_include": [],
    "must_avoid": ["body_fat_current_state_not_supported"]
  },
  "athlete_archetype": {
    "finding_ids": ["training_identity_strength_led_hybrid"],
    "evidence_ids": ["strength_sessions_90d", "modality_mix_90d"]
  },
  "current_training_state": {
    "finding_ids": ["recent_load_drop"],
    "evidence_ids": ["recent_load_ratio", "historical_active_weeks"]
  },
  "history_findings": {
    "finding_ids": ["strength_anchor", "endurance_in_bursts", "weekend_long_session_tolerance"],
    "evidence_ids": ["strength_sessions_90d", "running_frequency_by_week", "long_session_tolerance"]
  },
  "goal_fit": {
    "finding_ids": ["goal_requires_run_continuity"],
    "evidence_ids": ["normalized_goal", "running_frequency_28d", "long_session_tolerance"]
  }
}
```

### Notes

- The AI should be instructed to use only the IDs listed for that section.
- This makes section-level auditing possible.

## 8. `do_not_claim`

### Purpose

Prevent the AI from accidentally using tempting but invalid data.

### Shape

```json
[
  {
    "id": "body_fat_current_state_not_supported",
    "reason": "Latest body-fat sample is stale and isolated.",
    "forbidden_claims": ["current_body_fat", "body_fat_trend", "goal_progress_from_body_fat"],
    "related_evidence_ids": ["body_fat_percentage_latest"]
  }
]
```

### Required cases

Emit `do_not_claim` entries when:

- a latest sample is stale
- a series is too sparse for a trend
- a metric is available historically but not current
- evidence conflicts materially
- a physiological interpretation would require cross-signal support that is absent

## 9. `omitted_evidence`

### Purpose

Retain debug visibility into evidence that exists but was intentionally excluded.

### Shape

```json
[
  {
    "evidence_id": "body_fat_percentage_latest",
    "reason": "stale",
    "summary": "Single body-fat sample from 14 months ago.",
    "would_have_supported": ["body_context"],
    "excluded_from_sections": ["coach_read", "history_findings", "goal_fit"]
  }
]
```

## Section Mapping

| Blueprint section | Required packet inputs | Optional packet inputs | Must not use |
| --- | --- | --- | --- |
| `coach_read` | `normalized_goal`, selected `approved_findings`, high-confidence onboarding declarations | hidden coach inputs when directly supported | raw metrics, omitted evidence, forbidden claims |
| `athlete_archetype` | approved `training_identity` finding | onboarding identity declarations | body / recovery evidence alone |
| `current_training_state` | approved recent-state findings | approved recovery context | long-term history alone, stale physiology |
| `history_findings` | ranked approved findings | body / recovery findings only when blueprint-grade | stale isolated evidence |
| `goal_fit` | `normalized_goal`, approved readiness / capacity findings | body / recovery evidence only when goal-relevant and blueprint-grade | guarantees, stale metrics, unsupported predictions |

## Build Sequence

```text
1. collect raw HealthKit samples locally
2. build quality-gated health evidence locally
3. normalize onboarding answers locally
4. normalize goal locally
5. derive approved findings locally
6. derive hidden coach inputs locally
7. generate do_not_claim entries locally
8. assemble Athlete Blueprint Context Packet locally
9. send only that packet for AI generation
10. receive structured Athlete Blueprint JSON
```

## Example Packet Excerpt

```json
{
  "packet_version": "1.0",
  "normalized_goal": {
    "kind": "consistency",
    "title": "Build a consistent training rhythm",
    "source": "stay_consistent",
    "assessment_horizon_weeks": 12,
    "assessment_horizon_source": "fallback_12w",
    "tracking_mode": "adherence",
    "goal_category": "consistency"
  },
  "approved_evidence": [
    {
      "id": "active_weeks_90d",
      "category": "workout_history",
      "claim": "recent_consistency",
      "value_summary": "8 active weeks in the last 12",
      "evidence_class": "current",
      "confidence": "high",
      "source_kind": "healthkit",
      "observed_window": "90d",
      "allowed_claims": ["recent_consistency_pattern"]
    }
  ],
  "approved_findings": [
    {
      "id": "consistency_is_possible_but_unstable",
      "kind": "consistency_pattern",
      "summary": "The athlete has shown repeated ability to train, but not yet a durable uninterrupted rhythm.",
      "confidence": "high",
      "evidence_ids": ["active_weeks_90d", "longest_gap_days"],
      "allowed_sections": ["coach_read", "current_training_state", "history_findings", "goal_fit"]
    }
  ],
  "do_not_claim": [
    {
      "id": "body_fat_current_state_not_supported",
      "reason": "Latest body-fat sample is stale and isolated.",
      "forbidden_claims": ["current_body_fat", "body_fat_trend"],
      "related_evidence_ids": ["body_fat_percentage_latest"]
    }
  ]
}
```

## Product Decisions To Lock

1. The packet is built deterministically before AI generation.
2. Consistency uses the same goal-fit path as every other goal.
3. A 12-week fallback horizon is used whenever a goal-related timeframe is required but missing.
4. Hidden coach-side findings travel in the packet even when they are not user-facing.
5. Section-level input lists make every generated section auditable.
6. `do_not_claim` is a first-class part of the contract, not a prompt afterthought.
