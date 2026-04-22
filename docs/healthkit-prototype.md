# HealthKit Prototype

## Goal

Prove the riskiest early iOS integration for HAYF:

- request Apple Health access from an app
- read a few relevant data types
- provide a simple user-facing permission management flow

## What this prototype reads

The app asks for read-only access to:

- sleep analysis
- workouts
- step count
- active energy burned
- heart rate variability (SDNN)
- resting heart rate
- body mass

This is enough to validate the HealthKit path without designing the full product model yet.

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
