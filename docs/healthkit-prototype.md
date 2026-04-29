# HealthKit Prototype

## Goal

Prove the riskiest early iOS integration for HAYF:

- request Apple Health access from an app
- read the v1 fitness coaching permission scope
- provide a simple user-facing permission management flow

This prototype supports the v1 fitness wedge of the product. The final HAYF vision is broader: a holistic coaching experience across fitness, nutrition, and mind, where domain assistants can eventually share context and take bounded user-approved actions.

## What this prototype reads

The app asks for read-only access to:

- sleep analysis
- workouts
- step count
- active energy burned
- Apple exercise time
- walking and running distance
- heart rate variability (SDNN)
- resting heart rate
- heart rate
- VO2 max
- height
- body mass

This is enough to validate the HealthKit path for training history, daily movement, recovery, cardio fitness, and basic body context without designing the full product model yet.

## V1 HealthKit permission scope

The onboarding Health permission ask should be broader than height. HAYF should request read-only access to the minimum set of Apple Health data needed to understand training history, recent activity, recovery, and basic body context.

Recommended v1 read scope:

- `HKObjectType.workoutType()`: workout history, workout modality, duration, dates, and training consistency
- `HKCategoryTypeIdentifier.sleepAnalysis`: recent sleep duration and sleep timing
- `HKQuantityTypeIdentifier.stepCount`: baseline daily movement and low-friction activity
- `HKQuantityTypeIdentifier.activeEnergyBurned`: recent activity load
- `HKQuantityTypeIdentifier.appleExerciseTime`: daily exercise minutes when available
- `HKQuantityTypeIdentifier.distanceWalkingRunning`: walking/running volume outside explicit workouts
- `HKQuantityTypeIdentifier.restingHeartRate`: recovery and cardiovascular baseline
- `HKQuantityTypeIdentifier.heartRateVariabilitySDNN`: recovery and strain signal
- `HKQuantityTypeIdentifier.heartRate`: workout intensity and recent effort context when available
- `HKQuantityTypeIdentifier.vo2Max`: cardio fitness baseline when available
- `HKQuantityTypeIdentifier.height`: body context for recommendations
- `HKQuantityTypeIdentifier.bodyMass`: body context and future nutrition/fitness context

Implementation notes:

- Request read access only for v1. Do not request write permissions until HAYF has a clear user-approved action, such as saving a planned or completed workout.
- Treat every HealthKit type as optional. Availability depends on device, region, Apple Watch use, user history, and what the user grants.
- Use derived features in recommendations, not raw HealthKit dumps. Example: `average_steps_7d`, `workouts_14d`, `sleep_hours_last_night`, `resting_hr_delta`, and `latest_body_mass_kg`.
- Do not include reproductive health, clinical records, medications, symptoms, nutrition, mindful sessions, or audio exposure in the v1 fitness permission ask.

Suggested user-facing permission framing:

> Connect Apple Health so HAYF can understand your recent activity, workouts, sleep, recovery signals, and basic body metrics. This helps HAYF recommend training that fits how ready you are today.

## Important platform constraint

Apple does not provide a public API for an app to silently revoke HealthKit permissions on behalf of the user.

That means the correct beginner-friendly UX is:

- `Grant Access` button in-app
- `How to Revoke` section that explains where the user can remove access
- optional button to open the app's Settings page

## Why this is the right first slice

For HAYF, HealthKit access is one of the main feasibility questions. Before we design recommendations, AI prompts, or backend sync, we want proof that:

- the entitlement works
- the authorization prompt works
- queries work
- the device returns data we can later turn into training context

## Expected outcome

After running on a real iPhone and granting access, the prototype should show:

- HealthKit is available
- authorization request completes successfully
- basic summaries from recent data appear on screen

## What to build next after this

1. Normalize daily feature inputs locally.
2. Add a simple "How are you feeling?" check-in model.
3. Save local snapshots of context used for each recommendation.
4. Add backend sync only for data you truly need off-device.
5. Add coaching logic after the data contract is stable.
6. Keep the feature model domain-aware so future nutrition and mind coaching can plug into the same shared context without rewriting the fitness foundation.
