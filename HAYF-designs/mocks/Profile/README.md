# Profile Mocks

Created: 2026-05-09

## Files

- `profile-fitness-profile-entry-and-sheet.png`

## Decision Captured

The Profile tab should become the home for user-facing identity and long-term fitness context, without turning HAYF into a dashboard.

The first Profile concept includes:

- a normal profile/account surface with the user's basic account context
- a `Fitness profile` entry point showing a few live highlights from existing derived data
- a pull-up detail card, matching the active block detail behavior from the Plan screen
- concise sections for training identity, consistency, seasonality, active goal signals, and coach-readable highlights

The Fitness Profile should be powered by the same source-agnostic evidence layer used by planning:

- HealthKit-derived observations and insights in V1
- manual gym logs later in V1
- workout debrief feedback later in V1
- future external sources without rebuilding the feature model around one sport

The design should stay aligned with the locked Home and Plan mocks: warm neutral background, object-like white surfaces, thin borders, black primary text, muted secondary text, and sparse HAYF orange for active/live/progress signals.
