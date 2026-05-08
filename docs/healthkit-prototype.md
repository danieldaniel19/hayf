# HealthKit Prototype

## Goal

Prove the riskiest early iOS integration for HAYF:

- request Apple Health access from an app
- read a broad personal-first Apple Health scope
- provide a simple user-facing permission and feature-debugging flow

This prototype supports the v1 fitness wedge of the product. The final HAYF vision is broader: a holistic coaching experience across fitness, nutrition, and mind, where domain assistants can eventually share context and take bounded user-approved actions.

## What this prototype reads

The app asks for read-only access to:

- sleep analysis
- workouts
- workout routes
- step count
- active energy burned
- basal energy burned
- Apple exercise time
- Apple stand time and stand hour
- flights climbed
- walking and running distance
- cycling distance
- swimming distance and stroke count
- heart rate variability (SDNN)
- resting heart rate
- walking heart rate average
- heart rate
- VO2 max
- respiratory rate
- oxygen saturation
- body temperature
- blood pressure
- blood glucose
- height
- body mass
- body fat percentage
- lean body mass
- waist circumference
- body mass index
- available nutrition logs such as energy, protein, carbohydrate, fat, sugar, fiber, water, caffeine, sodium, cholesterol, calcium, iron, potassium, vitamin D, vitamin B12, and vitamin C
- mindful sessions and Health event categories that may provide context, such as low/high heart rate, irregular rhythm, low cardio fitness, environmental audio exposure, and toothbrushing

This validates the HealthKit path for long training history, daily movement, recovery, cardio fitness, body context, and available nutrition context without turning Supabase into a raw HealthKit warehouse.

## V1 HealthKit permission scope

The onboarding Health permission ask is intentionally broad for the personal-first build. HAYF should request read-only access to the data that can improve fitness decisions, then perform deterministic filtering and feature extraction locally.

Current v1 read scope:

- `HKObjectType.workoutType()`: workout history, workout modality, duration, dates, and training consistency
- `HKSeriesType.workoutRoute()`: route availability for future outdoor workout context
- `HKCategoryTypeIdentifier.sleepAnalysis`: recent sleep duration and sleep timing
- `HKQuantityTypeIdentifier.stepCount`: baseline daily movement and low-friction activity
- `HKQuantityTypeIdentifier.activeEnergyBurned`: recent activity load
- `HKQuantityTypeIdentifier.basalEnergyBurned`: energy context when available
- `HKQuantityTypeIdentifier.appleExerciseTime`: daily exercise minutes when available
- `HKQuantityTypeIdentifier.appleStandTime`: low-level activity context
- `HKQuantityTypeIdentifier.distanceWalkingRunning`: walking/running volume outside explicit workouts
- `HKQuantityTypeIdentifier.distanceCycling`: cycling volume outside explicit workouts
- `HKQuantityTypeIdentifier.restingHeartRate`: recovery and cardiovascular baseline
- `HKQuantityTypeIdentifier.heartRateVariabilitySDNN`: recovery and strain signal
- `HKQuantityTypeIdentifier.heartRate`: workout intensity and recent effort context when available
- `HKQuantityTypeIdentifier.respiratoryRate` and `oxygenSaturation`: recovery and wellness context when available
- `HKQuantityTypeIdentifier.vo2Max`: cardio fitness baseline when available
- body metrics including height, body mass, body fat, lean mass, waist, and BMI
- nutrition metrics when available, treated as optional and potentially stale

Implementation notes:

- Request read access only for v1. Do not request write permissions until HAYF has a clear user-approved action, such as saving a planned or completed workout.
- Treat every HealthKit type as optional. Availability depends on device, region, Apple Watch use, user history, and what the user grants.
- Use derived features in recommendations, not raw HealthKit dumps. Example: workout-ledger windows, `averageSteps7Days`, `sleepHoursLastNight`, `restingHeartRate14DayAverageBPM`, `vo2MaxLatest`, `bodyMassKilograms`, and nutrition averages with days logged.
- Do not send raw HealthKit samples to Supabase Edge Functions or AI calls.
- Do not request write permissions, clinical records, reproductive health, medications, or symptom categories in the current fitness build.

Suggested user-facing permission framing:

> Connect Apple Health so HAYF can understand your workout history, activity baseline, sleep, recovery signals, body context, and available nutrition logs before it builds your plan.

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
- deterministic feature summaries from HealthKit appear in the Health Debug screen
- the feature JSON can be copied for Xcode/backend debugging

## What to build next after this

1. Normalize daily feature inputs locally.
2. Add a simple "How are you feeling?" check-in model.
3. Save local snapshots of context used for each recommendation.
4. Add backend sync only for data you truly need off-device.
5. Add coaching logic after the data contract is stable.
6. Keep the feature model domain-aware so future nutrition and mind coaching can plug into the same shared context without rewriting the fitness foundation.
