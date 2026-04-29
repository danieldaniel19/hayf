# Account Creation Flow

## Purpose

Account creation is the lean post-auth setup step that establishes who owns the HAYF account. It is separate from onboarding.

Account creation should collect durable account-level basics only:

- name
- birthdate
- main city
- optional profile photo

Do not collect workout goals, injuries, equipment access, weekly schedule, HealthKit permissions, training preferences, or recommendation inputs here. Those belong in onboarding.

## Current User Flow

After Google auth succeeds:

1. The app checks whether the signed-in Supabase Auth user has a row in `public.profiles`.
2. If a profile exists, the user skips account creation and either enters onboarding or lands in the authenticated app shell, depending on onboarding completion state.
3. If no profile exists, the user sees the account creation overview.
4. The overview shows editable rows for name, birthdate, and main city, plus an optional profile photo control.
5. The user can jump into any row directly. The flow is intentionally not strictly linear.
6. Tapping `Continue` moves to the next missing required field, then to review when required fields are complete.
7. Tapping `Create account` saves the profile to Supabase, uploads a custom photo if selected, and then shows the success transition.
8. Tapping `Start onboarding` moves the user into the onboarding flow.

The overview uses per-row checkmarks instead of a top progress bar because users can jump between sections.

## Tester Reset Controls

The authenticated home screen includes two temporary tester controls:

- `Restart account creation`: reopens account setup with the current Supabase profile prefilled. Completing the flow updates the existing `public.profiles` row instead of inserting a new one.
- `Restart onboarding`: deletes the signed-in user's `public.onboarding_profiles` row so the user can run onboarding again.

These controls are intentionally app-local/product-testing affordances. They should be removed or hidden behind a debug flag before a production release.

## Field Decisions

### Name

Required. Prefill from Google metadata when available. The app currently checks common Google/Supabase metadata keys such as `full_name`, `name`, and `display_name`.

### Birthdate

Required. Store birthdate, not age. Age should be derived later because it changes over time.

### Main City

Required. Store as a human-readable string for v1, such as `Munich, Bavaria, Germany`.

This is the user's stable home/base context. It is different from future live location access. Later, HAYF can compare current location to main city to detect travel and adjust recommendations.

For now, the model can use this string directly. Add structured geocoding fields only when deterministic features are needed, such as weather lookup, timezone, country-specific defaults, or distance from home.

### Profile Photo

Optional. If the user has a Google avatar and does not choose a custom photo, store the Google avatar URL. If the user picks a custom photo, upload it to Supabase Storage and store the object path.

The current implementation uses Apple's `PhotosPicker`, which lets the user pick specific photos without asking for broad photo library access up front. A custom gallery/browser would require explicit photo library permission and a usage description.

### Height And Weight

Do not collect height or weight in account creation. These should come from HealthKit when the user grants Apple Health access during onboarding. HealthKit values must still be treated as optional because users can deny specific categories or have missing data.

## Supabase Contract

The account profile is stored in `public.profiles`.

Expected fields:

- `id uuid primary key references auth.users(id) on delete cascade`
- `name text not null`
- `birthdate date not null`
- `main_city text not null`
- `profile_photo_path text null`
- `profile_photo_url text null`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

RLS should allow authenticated users to select, insert, and update only their own profile row.

Profile photos use a private Supabase Storage bucket:

- bucket: `profile-photos`
- path convention: `{user_id}/avatar.jpg`
- access policy: users can read, upload, update, and delete only objects in their own user-id folder

## Current Code Shape

Main files:

- `HAYFHealthKitPrototype/Auth/AccountCreationView.swift`: SwiftUI flow, field validation, city search, photo picker, review, and success state
- `HAYFHealthKitPrototype/Auth/AccountProfileStore.swift`: Supabase profile fetch/create/update and profile photo upload
- `HAYFHealthKitPrototype/App/AppRootView.swift`: post-auth profile and onboarding gate
- `HAYFHealthKitPrototype/Auth/AuthViewModel.swift`: Google auth state plus metadata extraction

The city picker uses MapKit `MKLocalSearchCompleter`. When the user types two or more characters, MapKit suggestions replace the static popular city fallback.

## Known Follow-Ups

- Add profile editing later from the Profile tab/settings.
- Move tester restart controls behind a debug-only surface or remove them before release.
- Decide whether to store structured city metadata after weather, timezone, or travel detection becomes deterministic.
- Consider compressing/resizing custom profile photos before upload.
- Add a clearer recovery state if profile fetch fails because the Supabase table or RLS policy is missing.
