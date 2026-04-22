# Beginner-First Roadmap

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

Add simple local models for:

- how the user feels today
- soreness
- stress
- available time
- training goal
- equipment access

Keep this local at first.

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

## Stage 7: Learning loop

Goal: use feedback to improve future suggestions.

Track signals like:

- did the user do the recommended workout?
- how did it feel afterward?
- did they skip it?
- what recommendation types get accepted most often?
