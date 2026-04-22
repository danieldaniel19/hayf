# HAYF

HAYF stands for "How Are You Feeling".

This repository starts with a deliberately small iOS prototype that tests the first technical hypothesis behind the product:

- Can we ask for HealthKit permission from an iPhone app?
- Can we read a small set of relevant Apple Health data after the user grants access?
- Can we give the user a simple path to manage or revoke that access later?

The answer should be "yes", with one Apple-specific caveat:

- Apps can request HealthKit access in-app.
- Apps cannot fully revoke HealthKit access programmatically on the user's behalf.
- The user manages revocation from Apple's Health permission screens.

## Project included here

- `HAYFHealthKitPrototype.xcodeproj`: minimal iOS SwiftUI app project
- `HAYFHealthKitPrototype/`: app source code
- `docs/healthkit-prototype.md`: setup, scope, and next steps
- `docs/architecture.md`: recommended backend/data architecture for HAYF

## First run checklist

1. Accept the Xcode license in Terminal:
   ```bash
   sudo xcodebuild -license
   ```
2. Open `HAYFHealthKitPrototype.xcodeproj` in Xcode.
3. In the Signing & Capabilities tab:
   - choose your Apple Team
   - let Xcode fix signing if prompted
   - confirm the `HealthKit` capability is present
4. Run on a physical iPhone.

## Why a physical iPhone?

HealthKit permissions and real health samples are best tested on-device. The Simulator is not the right target for proving this hypothesis.

## Prototype scope

This first app is intentionally plain. It focuses on:

- requesting read access to a few useful health signals
- showing whether HealthKit is available
- running a couple of small sample queries after authorization
- explaining how the user can manage or revoke access later

It does not attempt to build the full HAYF experience yet.

## Suggested repo setup next

Once you create the GitHub repo, a clean next step is:

1. initialize git locally
2. commit this prototype baseline
3. push to GitHub
4. continue in small vertical slices: permissions, data normalization, recommendation engine, coaching UI
