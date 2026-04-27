# Onboarding Flow

## Decision

HAYF onboarding should be one adaptive coach intake, not three fully separate onboarding products.

The user chooses an intent mode:

- help me stay consistent
- I have a concrete goal
- help me choose a goal

Those modes change which questions HAYF asks, but all paths converge into the same underlying profile:

- feasible training options
- current routine
- preferences
- constraints
- equipment and access
- schedule and time budget
- recovery and injury considerations
- goal state
- recommendation style

The first conversion moment should be:

"HAYF already understands enough about me to recommend something sensible today."

It should not feel like:

"HAYF asked me many questions and maybe someday this will pay off."

## Product stance

The first question should not be only "Which sports do you like playing?"

That is useful, but it is not the core signal. The more useful onboarding question is:

"What kinds of training should HAYF realistically choose from when recommending what to do today?"

This captures sports the user likes, but also gym access, equipment, time, injury constraints, weather or location dependencies, current routine, and willingness. A user may like tennis but not have courts, partners, or time. HAYF should optimize for feasible recommendations, not abstract preferences.

## Flow shape

Use a hybrid pattern:

1. Start with one open coach prompt.
2. Extract a draft profile.
3. Show a short coach-style readback.
4. Ask focused clarifying questions with buttons.
5. Always include "something else", "not sure", or a short free-text input.
6. End with a first useful output: a next-session recommendation, weekly direction, or suggested goal.

The repeated interaction pattern is:

1. Ask open.
2. Extract.
3. Clarify with chips.
4. Confirm.

Use open input for:

- the first coach intake
- natural-language goals
- unusual constraints
- injuries and edge cases
- answers that do not fit the available buttons

Use buttons for:

- training frequency
- timeline
- training types
- equipment
- intensity preference
- blockers
- confidence and readiness
- goal category

## Top-level onboarding

1. Welcome: "HAYF helps you decide what to train today."
2. Open input: "What should your coach know? Mention sports, current routine, goals, constraints, or what usually gets in the way."
3. Feasible training menu: "What can HAYF recommend?"
   - Strength
   - Running
   - Cycling
   - Swimming
   - Football
   - Tennis
   - Basketball
   - Mobility
   - Walking
   - Yoga
   - Other
4. Intent choice:
   - Help me stay consistent
   - I have a concrete goal
   - Help me choose a goal
5. Adaptive questions based on intent.
6. Health and constraints:
   - injuries
   - soreness
   - recovery
   - forbidden movements
7. Availability and access:
   - training days
   - typical duration
   - gym, home, outdoor, equipment
8. Coach summary:
   - confirm or edit the understood profile
9. HealthKit permission:
   - ask after the user has seen that HAYF understands them
   - explain that sleep, workouts, heart rate, and activity improve recommendations
10. First useful output:
   - next recommendation, starter week, or chosen goal plan

HealthKit permission should come after the value preview. Permission asks are easier to justify once the user understands why HAYF needs the data.

## Branch A: Help me stay consistent

This user does not want a performance project. They want fewer decisions, less guilt, and a better rhythm. HAYF should not force a goal.

Promise:

"I will keep you moving intelligently."

Flow:

1. Ask current routine.
2. Ask preferred balance.
3. Ask consistency blockers.
4. Ask minimum viable workout.
5. Ask recommendation style.
6. Generate a flexible weekly rhythm.

Typical scenario:

"I lift sometimes, run sometimes, but I am inconsistent. I just want to feel fit and not overthink it."

Clarifying questions:

What should HAYF optimize for most?

- Staying consistent
- Feeling better day to day
- Balanced strength and cardio
- General fitness
- Something else

How many days per week feels realistic?

- 2
- 3
- 4
- 5+
- It changes week to week

When life gets busy, what should HAYF protect?

- Short workouts
- Low mental friction
- Recovery
- Keeping a streak
- Training intensity

What usually breaks consistency?

- Work schedule
- Low energy
- Soreness
- No plan
- Travel
- Motivation
- Other

On a bad day, what is still acceptable?

- 10-minute walk or mobility
- 20-minute easy session
- Short strength circuit
- Rest, but intentional
- Ask me that day

Example output:

"HAYF will bias toward a balanced routine: 3 training days, 1 optional light day, and recommendations that adapt to recovery. No fixed goal yet."

Design note:

Ask fewer preference questions in this branch. For consistency users, too much personalization can become friction. Ask about blockers and minimums first. That is more coach-like.

## Branch B: I have a concrete goal

This is the most structured branch. HAYF should behave like a coach building a training brief.

Flow:

1. Identify goal type.
2. Capture target and timeline.
3. Capture current baseline.
4. Capture constraints.
5. Capture success markers.
6. Confirm whether the goal is realistic.
7. Create the plan shape.

Typical scenario:

"I want to run a half marathon in September while keeping strength."

Clarifying questions:

What kind of goal is this?

- Race or event
- Strength target
- Body composition
- Sport performance
- Consistency streak
- Rehab or return to training
- Other

What is the target?

- Finish event
- Hit a time or pace
- Lift a specific weight
- Train X days per week
- Improve endurance
- Custom target

When do you want to achieve it?

- 4 weeks
- 8 weeks
- 12 weeks
- Specific date
- No firm date

Where are you starting from?

- New to this
- Returning after a break
- Training casually
- Already training seriously
- Not sure

What cannot change?

- Strength training stays
- Sport practice stays
- Limited days
- Injury concern
- Travel or work schedule
- Nothing major

How aggressive should HAYF be?

- Conservative
- Balanced
- Ambitious
- Decide for me

Example output:

"HAYF thinks this is realistic if you can train 4 days per week. It will prioritize two runs, two strength sessions, and adjust intensity based on recovery."

Design note:

If the user provides an unrealistic goal, HAYF should say so during onboarding. This is a trust-builder. A coach that always says yes is less valuable.

Example unrealistic-goal response:

"Running a sub-1:30 half marathon in 6 weeks from a 2:05 baseline is unlikely without high injury risk. I can either build toward the race safely or set an intermediate target."

Options:

- Build safely toward the event
- Set a more realistic time goal
- Prioritize finishing healthy
- I understand the risk

## Branch C: Help me choose a goal

This branch is not the same as the consistency branch. This user wants direction. HAYF should infer motivating goal candidates from identity, constraints, preferred challenge type, and feasible training options.

Flow:

1. Ask desired feeling or identity.
2. Ask preferred challenge type.
3. Ask feasible sports and training options.
4. Ask timeline appetite.
5. Offer 2-3 goal candidates.
6. Let the user choose or edit.
7. Convert the chosen goal into a lighter version of Branch B.

Typical scenario:

"I am bored and want something to work toward, but I do not know what."

Clarifying questions:

What kind of change would feel exciting?

- More athletic
- Stronger
- Better endurance
- Leaner or fitter
- More consistent
- Ready for a sport or event
- Less tired or stressed

What kind of challenge motivates you?

- Numbers and targets
- Events and deadlines
- Skill progression
- Feeling better
- Competing with myself
- I do not know yet

What would you rather avoid?

- Running
- Heavy lifting
- Long workouts
- Strict plans
- High intensity
- Gym dependence
- Nothing specific

Pick a timeframe that feels good.

- 4-week reset
- 8-week challenge
- 12-week build
- Seasonal goal
- Decide for me

Goal candidates:

- 8-week balanced athlete goal: 3 workouts per week combining strength and cardio.
- 12-week 10K build while maintaining strength.
- 4-week consistency reset: never miss twice, minimum 20 minutes.
- Strength base goal: improve squat, press, and pull while keeping one cardio day.
- Sport-ready goal: build conditioning and mobility for football, tennis, or basketball.

Choice question:

Which goal feels most like you?

- Choose goal 1
- Choose goal 2
- Choose goal 3
- Blend these
- Write my own

Example output:

"Your starter goal: build a balanced 8-week training rhythm with 3 sessions per week. HAYF will track consistency, strength exposure, cardio exposure, and recovery."

Design note:

"Help me choose a goal" should not generate one perfect goal immediately. It should generate candidates. People often recognize what they want faster than they can articulate it.

## MVP scope

The v1 onboarding should be dynamic but bounded:

- one open coach input
- one intent choice
- no more than five question screens after the intent choice
- one summary confirmation
- one first recommendation or starter plan

Avoid building a sprawling conversational onboarding at first. The first version should create the feeling of a coach through good extraction, smart clarifying questions, and a strong summary.

## Profile outputs

By the end of onboarding, HAYF should have enough structured data to produce a recommendation:

- selected intent mode
- feasible training modalities
- current weekly routine
- target frequency
- time budget
- preferred balance between strength, cardio, mobility, and sport
- equipment and access
- constraints and injuries
- main consistency blockers
- minimum viable session
- goal details, if any
- preferred recommendation style
- HealthKit permission state

The profile should be editable later. Onboarding should create the first useful version, not the permanent truth.
