# HAYF Architecture Recommendation

## Short answer

Use `Supabase`, but not as a raw mirror of Apple Health data.

For HAYF's first versions, the best architecture is:

- HealthKit stays the source of truth for Apple health data on-device
- the iOS app computes a small normalized feature set locally
- Supabase stores user account data, user-entered check-ins, recommendation history, and selected derived summaries
- AI coaching consumes derived features and user context, not a giant dump of raw HealthKit samples

This keeps v1 fitness-focused while preserving a path toward the final product vision: a holistic coaching system where fitness, nutrition, and mind assistants can share context, consult one another, and take bounded user-approved actions.

## Why not sync all raw HealthKit data to Supabase?

Because early on it creates more risk than value:

- more privacy and security burden
- more product complexity before you know what features matter
- more backend/storage cost
- harder compliance story if you later expand into sensitive coaching use cases
- more surface area for mistakes with location and health data combined

For a beginner project, keeping raw health data mostly on-device is the simplest and safest choice.

## Recommended v1 architecture

### On device

The iPhone app should:

- request HealthKit permissions
- query recent data when needed
- transform raw samples into compact features such as:
  - last night's sleep duration
  - 7-day sleep average
  - workouts in the last 7 days
  - resting heart rate trend
  - HRV trend
  - activity load estimate
- collect user check-ins such as:
  - energy
  - soreness
  - stress
  - motivation
  - available time
- assemble the recommendation context locally

### In Supabase

Supabase is a good fit for:

- authentication
- user profile and preferences
- app-generated recommendation history
- user feedback on recommendations
- optional daily or session-level derived summaries
- coaching conversation records
- row-level security and admin tooling

The current post-auth account creation contract is documented in `docs/account-creation.md`.

### For AI coaching

A practical first approach is:

- app builds a compact context packet
- backend receives only the context needed for coaching
- AI returns a recommended training session and rationale
- app stores the recommendation and the user's response

The v1 AI layer can be implemented as a single fitness coach, but its contracts should anticipate later domain coaches. In practice, that means keeping context packets explicit, outputs structured, and actions separate from recommendation text.

Example context packet:

- self-reported feeling today
- available time
- sleep summary
- recent workout load
- recovery indicators
- optional weather summary
- optional coarse location context if truly needed

## Suggested data boundary

Store these remotely early:

- user-entered feeling check-ins
- completed recommendation summaries
- derived daily features such as sleep_hours, readiness_score, recent_workout_count
- AI outputs and feedback signals

Avoid storing these remotely at first:

- full raw HealthKit sample history
- minute-level step series
- exact location trails
- any health data you do not actively use in recommendations

## Suggested evolution path

### Phase 1

- iOS only
- HealthKit read access
- local feature extraction
- mock recommendation logic

### Phase 2

- Supabase auth
- check-in storage
- recommendation history
- simple server-side AI orchestration

### Phase 3

- optional background refresh
- smarter feature engineering
- A/B testing for coaching prompts
- selective sync of derived metrics

### Phase 4

- introduce nutrition-domain context and recommendations
- separate shared user context from domain-specific coaching state
- add explicit action requests for tasks such as calendar scheduling

### Phase 5

- introduce mind-domain context and recommendations
- allow domain coaches to exchange compact advice before producing a user-facing recommendation
- enforce consent, permissions, and auditability for any agentic action

## Why this fits HAYF

HAYF is not just a logging app. It is a decision app.

That means the real asset is not raw sensor data alone. The real asset is the decision context you build from:

- how the user feels
- what their recent body signals suggest
- what they have been doing lately
- what constraints they have right now

So design around `context packets` and `derived features`, not bulk storage.

For v1, the HealthKit read scope should cover workouts, sleep, daily movement, recovery signals, cardio fitness, height, and body mass. The app should turn these into compact derived features before recommendation, rather than sending raw HealthKit samples to the AI layer.

## Recommendation

Start with this stack:

- iOS app in SwiftUI
- HealthKit on-device
- local lightweight feature builder
- Supabase for auth, app data, and recommendation history
- AI layer only after the feature contract is stable
- action layer later, with user approval and clear permissions

That gives you a clean beginner-friendly path without painting HAYF into a privacy or architecture corner too early.
