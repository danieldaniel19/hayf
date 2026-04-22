# HAYF

HAYF stands for "How Are You Feeling".

HAYF is an iOS fitness coaching app that helps busy professionals decide what to train today based on how they feel, their recent workout and recovery data, and their longer-term goals.

The product idea is simple:

- the user opens the app before training
- HAYF reads relevant context such as sleep, workouts, and activity history
- the user provides a quick pre-workout check-in
- HAYF recommends the best workout for that moment
- after the workout, HAYF checks what Apple Health logged and lets the user confirm or manually log it
- over time, HAYF tracks recommendation compliance and improves personalization

## Product Direction

HAYF is being built first for:

- busy professionals
- users with some existing training experience
- people balancing multiple exercise modalities such as gym, running, cycling, HIIT, and recovery work

The core value proposition is deep personalization without forcing the user to plan everything themselves.

## Current Status

This repository currently contains the first validated technical slice of the product:

- a minimal iOS SwiftUI app
- HealthKit permission flow
- sample Apple Health reads for sleep, workouts, and steps
- foundational product and roadmap documentation

That prototype proved the first important hypothesis: HAYF can request HealthKit access and read relevant Apple Health data on iPhone.

## Repository Structure

- `HAYFHealthKitPrototype.xcodeproj`: current Xcode project
- `HAYFHealthKitPrototype/`: app source code
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
- PRD for v1
- roadmap and story map
- backlog
- decision log
- open questions

## Next Build Focus

The next major product slices are:

1. onboarding for goals, workout preferences, and constraints
2. pre-workout check-in
3. recommendation engine and output schema
4. post-workout Apple Health detection and manual confirmation flow
5. compliance tracking

## Philosophy

HAYF is being built as a serious side project with lean process, tight scope control, and fast validation of the core user loop.
