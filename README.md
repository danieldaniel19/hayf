# HAYF

HAYF stands for "How Are You Feeling".

HAYF is an iOS coaching app for people balancing strength and cardio who want to know what to train today without guessing. It combines current context, recent workout and recovery data, and longer-term goals to recommend the most appropriate next session.

The long-term vision is broader than fitness alone: HAYF should become a holistic coaching experience across fitness, nutrition, and mind. Those coaching areas may eventually be powered by standalone agents that understand their own domain, share context with one another, and take useful actions for the user, such as adding a recommended workout to the user's calendar.

The product idea is simple:

- the user opens the app before training
- HAYF reads relevant context such as sleep, workouts, and activity history
- the user provides a quick pre-workout check-in
- HAYF recommends the best workout for that moment
- after the workout, HAYF checks what Apple Health logged and lets the user confirm or manually log it
- over time, HAYF tracks recommendation compliance and improves personalization

## Product Direction

HAYF is being built fitness-first for:

- busy professionals and tech-forward users
- people who already rely on ChatGPT-like tools for planning but want something with more context and continuity
- ambitious but inconsistent exercisers trying to balance strength and endurance across a changing week

The v1 value proposition is a personal fitness coach that helps the user balance strength and cardio without forcing them to research best practices or manually re-plan every time life changes.

The product should still leave space for the fuller coaching system:

- V1: fitness coaching, with strength/cardio recommendations and workout follow-through
- V2: nutrition coaching, connected to training goals, recovery, and daily constraints
- V3: mind coaching, connected to motivation, stress, confidence, and habit formation
- Final vision: all coaching areas are aware of one another, can collaborate, and can take bounded user-approved actions

The product promise is:

- HAYF tells the user what to train today based on their data and longer-term goals
- the user can adapt on the fly when time, motivation, schedule, travel, weather, or recovery changes
- the recommendation still protects long-term consistency instead of reacting only to momentary vibes

The intended product feel is:

- highly personal
- calm
- coach-like
- intelligent, with AI clearly present but not marketed as the hero
- minimal, with a mostly black, white, and grey palette plus a restrained HAYF orange accent

## Current Status

This repository currently contains the first validated technical slice of the product plus the first onboarding implementation:

- a minimal iOS SwiftUI app
- Google auth and post-auth account creation
- Supabase profile storage
- stay-consistent onboarding flow
- HealthKit permission flow with the v1 read scope
- sample Apple Health reads for sleep, workouts, steps, height, and body mass
- tester restart controls for account creation and onboarding
- foundational product and roadmap documentation

The prototype has proved the first important hypothesis: HAYF can authenticate a user, create a profile, request HealthKit access, and read relevant Apple Health data on iPhone.

## Repository Structure

- `HAYFHealthKitPrototype.xcodeproj`: current Xcode project
- `HAYFHealthKitPrototype/`: app source code
- `docs/product-positioning.md`: ICP, product promise, and design direction
- `docs/account-creation.md`: post-auth account setup flow, profile schema, and Supabase wiring
- `docs/onboarding-flow.md`: adaptive onboarding flow and branch design
- `docs/healthkit-prototype.md`: HealthKit prototype notes
- `docs/architecture.md`: early architecture recommendation
- `docs/roadmap.md`: beginner-first product and build roadmap

## Getting Started

1. Open `HAYFHealthKitPrototype.xcodeproj` in Xcode.
2. Select your Apple Team in Signing if you want to run on a real device.
3. Run on iPhone Simulator for UI validation.
4. Run on a physical iPhone to test real HealthKit permissions and real Apple Health data.

## HealthKit Notes

A couple of platform realities are already known:

- apps can request HealthKit access in-app
- users manage true HealthKit revocation through Apple's Health permission screens
- real HealthKit behavior should be validated on a physical iPhone, not just in the simulator

## Product Documentation

The working product docs live in Notion and are mirrored here only where useful for engineering context.

Current planning areas include:

- product overview
- product positioning
- PRD for v1
- roadmap and story map
- backlog
- decision log
- open questions

## Next Build Focus

The next major product slices are:

1. concrete-goal and help-me-find-a-goal onboarding branches
2. pre-workout check-in
3. recommendation engine and output schema for balancing strength and cardio
4. lightweight but always-accessible coach/chat affordance
5. post-workout Apple Health detection and manual confirmation flow
6. consistency and compliance tracking

These slices should be designed as the first fitness domain inside a future multi-domain coaching system, not as a one-off fitness-only product.

## Philosophy

HAYF is being built as a serious side project with lean process, tight scope control, and fast validation of the core user loop.
