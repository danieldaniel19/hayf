# Beginner-First Roadmap

HAYF's final vision is a holistic coaching experience across fitness, nutrition, and mind. The roadmap starts with fitness because it is the clearest wedge and the current prototype already validates the HealthKit path, but every phase should preserve room for nutrition and mind coaching to become first-class domains later.

Version sequencing:

- V1: fitness coaching
- V2: nutrition coaching
- V3: mind coaching
- Final vision: fitness, nutrition, and mind coaches are aware of one another, can collaborate, and can take bounded user-approved actions

## Stage 1: Technical proof

Goal: prove iOS + HealthKit works.

Done in this repo:

- minimal SwiftUI app
- HealthKit entitlement
- read authorization request
- sample queries for sleep, workouts, and steps
- user guidance for managing or revoking access

## Stage 2: HAYF input model

Goal: define what HAYF needs at recommendation time.

The onboarding flow is the first place this model becomes visible to the user. It should follow the adaptive coach intake described in `docs/onboarding-flow.md`: one open input, one intent choice, focused clarifying questions, a coach-style summary, and a first useful recommendation or starter plan.

Add simple local models for:

- how the user feels today
- soreness
- stress
- motivation
- available time
- training goal
- equipment access
- whether today should bias toward strength or cardio

Keep this local at first. Model these as fitness-domain inputs, while leaving the structure open for future nutrition and mind-domain inputs.

## Stage 3: Daily feature builder

Goal: turn raw inputs into small usable features.

Examples:

- sleep_last_night_hours
- sleep_7d_avg
- workouts_last_7d
- workout_load_trend
- steps_7d_avg
- readiness_score

This is the bridge between raw HealthKit data and AI coaching.

## Stage 4: Recommendation engine v0

Goal: generate a plain-language workout suggestion without AI first.

Example rules:

- low sleep + high soreness -> recovery walk or mobility
- good sleep + low soreness -> strength or interval session
- moderate energy + short time -> short conditioning workout
- user planned strength but reports anxiety and low motivation -> suggest an easier run, walk, or short alternative without losing weekly balance

This helps validate the product logic before adding model complexity.

## Stage 5: Backend and accounts

Goal: persist only the data that creates product value.

Good first backend items:

- authentication
- check-in history
- recommendation history
- feedback on whether the workout felt right

## Stage 6: AI coaching

Goal: improve the recommendation and explanation quality.

The AI input should be a compact context object, not a raw sensor dump.

The AI output should include:

- suggested workout type
- intensity
- duration
- explanation in human language
- optional fallback if the user feels worse after warm-up
- adaptation options when the user wants to modify the session on the fly

The coaching layer should eventually support:

- quick structured inputs for the fastest flows
- an always-accessible chat entry point for exceptions, tradeoffs, and real-life changes
- context from sources such as weather, calendar, and location when it materially improves coaching
- a future domain-agent shape where fitness, nutrition, and mind assistants can share relevant context and advice
- an action layer for bounded user-approved tasks, such as adding a workout to the user's calendar

## Stage 7: Learning loop

Goal: use feedback to improve future suggestions.

Track signals like:

- did the user do the recommended workout?
- how did it feel afterward?
- did they skip it?
- what recommendation types get accepted most often?

## Later product versions

### V2: Nutrition

Add nutrition coaching after the fitness loop is useful and trustworthy. Nutrition should connect to training goals, recovery, preferences, schedule, and adherence instead of becoming a disconnected food logger.

### V3: Mind

Add mind coaching after the app has enough continuity to support motivation, stress, confidence, and habit formation responsibly. Mind should support the user's consistency and decision-making without turning the product into a generic mental health app.

### Final vision: Collaborative coaching agents

Fitness, nutrition, and mind may eventually operate as standalone agents with shared user context. Each agent should understand its own domain, know when to consult the others, and use a shared action layer for user-approved tasks.
