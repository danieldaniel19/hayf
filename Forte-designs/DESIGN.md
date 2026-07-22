---
version: 1.0
name: Forte
status: provisional-name

description: App-wide mobile coaching system derived from the final consistency-intent experience. Calm editorial hierarchy, tactile 3D concepts, soft grouped surfaces, and explicit coach guidance should carry from onboarding into the rest of Forte.

colors:
  ink: "#171816"
  inkSoft: "#3F403D"
  inkMuted: "#74756F"

  background: "#FAF9F7"
  surface: "#FFFFFF"
  surfaceSoft: "#F5F3F0"
  surfaceRaised: "#EEECE8"
  surfaceDisabled: "#E8E6E2"
  borderSubtle: "#E3E0DB"

  indigo: "#4F46E5"
  indigoDeep: "#3730A3"
  indigoSoft: "#EDE9FE"
  indigoMist: "#F4F2FC"

  lilac: "#B5A7D8"
  lilacSoft: "#F0ECF8"
  mist: "#AFC8D8"
  mistSoft: "#EAF2F6"
  jade: "#79A991"
  jadeSoft: "#E6F0EA"
  sand: "#D8BD85"
  sandSoft: "#F5EEDC"
  peach: "#EAB5A1"
  peachSoft: "#F8E9E3"
  sky: "#8FB7E8"
  skySoft: "#E8F1FB"

  success: "#3F8B68"
  info: "#4F78C7"
  warning: "#B88035"
  error: "#B85353"
  onAccent: "#FFFFFF"

typography:
  display:
    fontFamily: "Newsreader, Iowan Old Style, Georgia, serif"
    fontSize: 34px
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "-0.02em"
  h1:
    fontFamily: "Newsreader, Iowan Old Style, Georgia, serif"
    fontSize: 32px
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "-0.015em"
  h2:
    fontFamily: "Newsreader, Iowan Old Style, Georgia, serif"
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  h3:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: 0px
  body:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0px
  bodySmall:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: 0px
  label:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.01em"
  overline:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "0.22em–0.30em"
  action:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: 0px

rounded:
  xs: 8px
  sm: 12px
  md: 16px
  lg: 20px
  xl: 24px
  xxl: 32px
  full: 9999px

spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  xxl: 24px
  xxxl: 32px
  huge: 40px
  giant: 48px
  max: 64px

iconography:
  largeIllustration:
    minWidth: 160px
    style: "calm Bauhaus-inspired balanced-object still life with sculptural matte geometry and soft shadows"
  mediumIcon:
    sizeRange: "32px–80px"
    style: "3D skeuomorphism in one of three named families: object, plinth, or review"
  reviewIcon:
    renderedSize: 48px
    style: "low-density 3D semantic object inside a pale solid rounded rectangle"
  utilityIcon:
    sizeRange: "16px–24px"
    style: "rounded outline"
    strokeWidth: 1.75px

components:
  app-shell:
    backgroundColor: "{colors.background}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    padding: "{spacing.xxl}"
    maxContentWidth: 480px

  button-primary:
    backgroundColor: "{colors.indigo}"
    textColor: "{colors.onAccent}"
    typography: "{typography.action}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 56px

  button-primary-pressed:
    backgroundColor: "{colors.indigoDeep}"
    textColor: "{colors.onAccent}"
    typography: "{typography.action}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 56px

  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.indigoDeep}"
    borderColor: "{colors.borderSubtle}"
    typography: "{typography.action}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 48px

  button-tertiary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 48px

  review-icon:
    assetFamily: "review-icon-*"
    renderedSize: 48px
    backgroundTreatment: "baked pale solid rounded rectangle"
    rounded: "{rounded.md}"

  content-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xl}"

  metric-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"

  read-only-list:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.xl}"
    rowHorizontalPadding: 14px
    rowVerticalPadding: 13px
    iconSize: 48px
    dividerLeadingInset: 76px

  floating-utility-button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.indigoDeep}"
    borderColor: "{colors.borderSubtle}"
    rounded: "{rounded.sm}"
    size: 44px

  choice-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"

  choice-card-selected:
    backgroundColor: "{colors.indigoMist}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"

  image-choice-tile:
    backgroundColor: "{colors.surface}"
    selectedBackgroundColor: "{colors.indigoMist}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    height: 100px
    iconSize: 62px

  weekday-chip:
    backgroundColor: "{colors.surface}"
    selectedBackgroundColor: "{colors.indigoMist}"
    textColor: "{colors.inkSoft}"
    selectedTextColor: "{colors.indigoDeep}"
    rounded: 14px
    width: 42px
    height: 48px

  stacked-choice-list:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    selectedBackgroundColor: "{colors.indigoMist}"
    rounded: "{rounded.xl}"
    rowHeight: 68px
    iconSize: 48px
    dividerColor: "{colors.borderSubtle}"

  text-area:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    placeholderColor: "{colors.inkMuted}"
    borderColor: "{colors.borderSubtle}"
    focusBorderColor: "{colors.indigo}"
    rounded: "{rounded.lg}"
    minHeight: 148px
    padding: "{spacing.lg}"

  wheel-selector:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.inkMuted}"
    selectedTextColor: "{colors.indigoDeep}"
    selectedBackgroundColor: "{colors.indigoMist}"
    rounded: "{rounded.xl}"
    rowHeight: 44px
    viewportHeight: 152px

  sheet:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xxl}"

  chip:
    backgroundColor: "{colors.surfaceRaised}"
    textColor: "{colors.inkSoft}"
    rounded: "{rounded.full}"
    typography: "{typography.bodySmall}"
    height: 40px

  chip-selected:
    backgroundColor: "{colors.indigoSoft}"
    textColor: "{colors.indigoDeep}"
    rounded: "{rounded.full}"
    typography: "{typography.bodySmall}"
    height: 40px

  progress-active:
    backgroundColor: "{colors.indigoDeep}"
    rounded: "{rounded.full}"
    height: 3px

  progress-inactive:
    backgroundColor: "{colors.borderSubtle}"
    rounded: "{rounded.full}"
    height: 3px
---

# Forte Design System

## Overview

Forte is a personal training coach for people balancing fitness with real life. It helps users decide what to do, adapt when plans change, and build trust in themselves by following through consistently.

The product should feel:

- **Calm**: composed, spacious, and never urgent by default.
- **Encouraging**: supportive without praise inflation, pressure, or guilt.
- **Light**: visually soft, easy to scan, and emotionally low-friction.

Forte is not a performance dashboard. It should not resemble Strava, a calorie tracker, or a biohacking tool. It should feel like a thoughtful personal coach: attentive, specific, warm, and quietly confident.

The working brand idea behind Forte is resilience. Strength is not presented as domination or maximum intensity. It is the ability to return, follow through, and trust yourself because your actions align with your intentions.

### Source of Truth

The final consistency-intent screens are the canonical visual and interaction reference for this document. They establish the direction for the whole product, not only onboarding. When this document, an older mockup, and the implemented consistency flow disagree, follow the implemented flow and update the documentation.

Carry its grammar into planning, Today, progress, profile, settings, and coach surfaces:

- warm off-white page canvas
- a constrained, left-aligned editorial reading column
- serif for the page's main coach message and selected high-emphasis values
- sans serif for explanation, rows, controls, and operational data
- indigo for interaction and coaching emphasis
- white grouped surfaces with restrained borders and soft daylight shadows
- semantic 3D illustrations for concepts, with outline symbols reserved for utilities
- one clear action hierarchy and generous vertical separation between sections

Do not copy onboarding chrome where it has no meaning. Standard app screens do not need segmented onboarding progress, step counts, exit controls, or a fixed Continue button. Reuse the hierarchy and components, then apply the navigation appropriate to the product area.

## Brand Principles

- **Coach-first**: Every screen should help the user understand, decide, adapt, or act.
- **Warm intelligence**: Guidance should feel informed and context-aware without looking technical or making AI the visual hero.
- **Soft structure**: Use typography, spacing, tonal surfaces, and imagery instead of heavy borders and rigid containers.
- **Editorial calm**: Major moments should feel considered and human, with strong composition and selective use of serif typography.
- **Tactile clarity**: Important concepts should be easy to recognise through dimensional, object-like icons.
- **Consistency over intensity**: Recommendations should protect realistic rhythm, recovery, and long-term adherence.
- **Quiet confidence**: The product should feel capable and premium without becoming cold, competitive, or over-designed.

## Visual Direction

The visual language combines four layers:

1. warm off-white foundations
2. dark editorial typography
3. indigo interaction and brand accents
4. a controlled three-tier illustration and icon system

The system should feel closer to Airbnb’s balance of editorial imagery, tactile object icons, and clean utility UI than to a conventional fitness dashboard.

The hierarchy must remain clear:

- large illustrations create atmosphere and emotion
- medium icons create recognition and warmth
- small utility icons provide functional clarity
- typography remains the primary carrier of hierarchy

Color and imagery should enrich the interface without competing with the coaching content.

## Color System

### Foundation

- **Ink (`#171816`)**: primary typography and high-contrast interface elements.
- **Ink Soft (`#3F403D`)**: secondary copy and supporting labels.
- **Ink Muted (`#74756F`)**: metadata, captions, inactive states, and tertiary information.
- **Background (`#FAF9F7`)**: persistent app canvas. Warm, quiet, and slightly softer than pure white.
- **Surface (`#FFFFFF`)**: elevated cards, sheets, inputs, and focused interaction areas.
- **Surface Soft (`#F5F3F0`)**: default grouped content and soft cards.
- **Surface Raised (`#EEECE8`)**: chips, segmented controls, inactive states, and subtle separation.
- **Border Subtle (`#E3E0DB`)**: rare separators and outlines when tonal contrast is insufficient.

### Brand Accent

Indigo is the primary brand and interaction color.

- **Indigo (`#4F46E5`)**: primary actions, active navigation, progress, selected controls, and focused interaction.
- **Indigo Deep (`#3730A3`)**: pressed states, high-contrast indigo text, and deeper emphasis.
- **Indigo Soft (`#EDE9FE`)**: selected chips, soft icon backgrounds, and subtle active states.
- **Indigo Mist (`#F4F2FC`)**: large selected surfaces and quiet contextual grouping.

Indigo should create recognition without flooding the screen. A typical screen should have one dominant indigo action or active state, supported by smaller indigo details.

### Illustration and Icon Palette

Illustrations and medium icons are allowed more chromatic freedom than core UI.

Available supporting families include:

- lilac and violet
- mist and sky blue
- jade and soft greens
- sand and warm yellow
- peach and muted coral
- warm neutrals and natural browns

These colors are not permanently assigned to specific sports, metrics, or product domains. Choose them according to the visual subject, emotional tone, readability, and harmony with the surrounding screen.

### Color Rules

- Indigo owns brand recognition and interaction.
- Supporting colors belong mainly to illustrations, dimensional icons, semantic states, and softly tinted surfaces.
- Do not color-code every modality or metric permanently.
- Do not use color as the only way to communicate state.
- Prefer soft tints over colored outlines.
- Use saturated colors in small areas: icons, active controls, progress, or key details.
- Keep large UI surfaces pale and low-contrast.
- A screen may use several illustration colors, but core controls should still feel coherent and indigo-led.
- Avoid generic rainbow dashboards, neon colors, and high-saturation combinations.
- Do not use orange as a primary brand color.
- Avoid decorative gradients in buttons, navigation, cards, and generic UI surfaces.
- Atmospheric tonal transitions are allowed inside large illustrations and carefully rendered skeuomorphic icons.

## Typography

Typography should feel editorial, calm, and distinctive.

Use a serif for major coach-facing moments and a clean sans serif for utility, data, and body copy.

### Serif

Use for:

- app wordmark
- greeting headlines
- recommendation headlines
- onboarding questions
- reflective prompts
- major section titles
- sheet titles
- moments where the coach speaks with emphasis

Preferred direction: Newsreader, Iowan Old Style, or another contemporary serif with warmth, clear mobile rendering, and restrained contrast.

### Sans Serif

Use for:

- body copy
- buttons
- navigation
- metadata
- metrics
- schedules
- form controls
- workout structure
- small labels and utility content

Prefer SF Pro Text or Inter in implementation.

### Typography Rules

- Serif is the coach and editorial voice layer, not a universal replacement for sans serif.
- Avoid serif in dense metric grids, small cards, and long technical instructions.
- Keep typography dark and high contrast against warm backgrounds.
- Use fewer uppercase labels. Overlines may remain uppercase only when they clarify structure.
- Avoid extremely bold, condensed, or technical typography.
- Let large headings wrap naturally and use generous line spacing around them.
- Use tabular numerals for metrics when available.
- Use normal sentence case for buttons and most labels.

## Layout

Forte follows a 4px grid with generous spacing and a light container strategy.

### Layout Rules

- Use 24px horizontal screen padding by default.
- Use 20px only where dense data makes 24px impractical.
- Cap the primary reading and interaction column at 480px on wider layouts. Keep the column centered while its content remains left-aligned.
- Keep coaching content left-aligned.
- Let sections breathe; do not place every group inside a card.
- Use multiple sibling cards when each represents a genuinely different section; never nest framed cards to manufacture hierarchy.
- Use spacing, typography, tinted backgrounds, and imagery to establish hierarchy.
- Reserve pure white for elevated surfaces, choice cards, sheets, and interaction areas.
- Respect iOS safe areas and preserve clear space around bottom navigation.
- In focused workflows, keep the primary action in a fixed bottom action rail with a 97% opaque page background. Scroll content beneath it and provide sufficient bottom inset.
- Avoid dense dashboards and rigid tile mosaics unless comparison is genuinely useful.
- Keep large background illustrations away from critical controls and body-copy reading zones.
- When imagery sits behind text, preserve a quiet text field with sufficient contrast and minimal visual detail.

### Reusable Screen Grammar

The consistency flow establishes four reusable page types.

#### 1. Guided decision page

Use for setup, preference, adjustment, filtering, and coach-led choices.

- Optional 11px uppercase overline in Indigo Deep with 2.4px to 3.4px tracking.
- 31px to 32px editorial headline; 34px is reserved for opening or transition moments.
- 15px explanatory copy with approximately 5px additional line spacing.
- 8px between headline and explanation; typically 18px to 28px between explanation and the first control.
- Choose one control grammar that matches the information: editorial cards, image tiles, stacked rows, wheels, or a text area.
- Keep the primary action fixed at the bottom when the page is a linear workflow.

#### 2. Readback or review page

Use when Forte interprets user data, summarizes a plan, explains a recommendation, or asks for confirmation.

- Lead with a concise editorial introduction.
- Put Forte's interpretation in one tinted coach-read card.
- Follow it with clearly labelled evidence sections rather than mixing inference and source data.
- Use white 24px-radius grouped lists, 48px review illustrations, inset dividers, and compact row copy.
- Provide an explicit primary acceptance action. Add a quieter correction action when the user can revise the source information.

#### 3. Data or connection page

Use for integrations, permissions, profile baselines, and settings that benefit from explanation.

- Start with a distinct identity or context card.
- Explain what is used and why in grouped metadata rows.
- Place privacy, caveats, and state messages near the relevant data rather than in distant legal copy.
- Use compact semantic status capsules; never imply success before the underlying state confirms it.

#### 4. Generative transition page

Use when Forte needs real processing time.

- Preserve orientation and escape controls.
- Use one calm focal object and one status card.
- Show indeterminate progress unless the system exposes real completion values.
- Replace the transition with a focused retry state on failure and reassure the user that completed input is preserved.

### Canonical Page Measurements

- Page gutter: 24px.
- Maximum content width: 480px.
- Floating header control: 44×44px, 12px radius, 17px outline symbol.
- Progress segment: 3px high with 6px gaps.
- Step or header metadata: 14px regular sans serif.
- Standard hero headline: 31px to 32px semibold editorial.
- Hero explanation: 15px regular sans serif.
- Primary action: 56px high, 17px semibold, full pill.
- Quiet secondary action: 48px high, white fill, subtle border, Indigo Deep text.
- Section overline: 11px semibold uppercase with 2.4px to 2.6px tracking.
- Grouped read-only surface: 24px radius.
- Read-only row: 14px horizontal and 12px to 13px vertical padding.
- Review illustration: 48×48px.
- Divider inset after a review illustration: 76px from the leading card edge.

## Surfaces, Borders, and Elevation

The interface should rely primarily on tonal separation.

### Surface Rules

- Default cards use white or softly tinted fills.
- White grouped surfaces are the canonical treatment for choice lists, review evidence, integrations, and compact metadata.
- Use no border when surface contrast is sufficient.
- Use a subtle 1px border only for accessibility, selection clarity, input definition, or white-on-white separation.
- Do not use colored outlines as the default selected state.
- Selected states should use a tinted fill, stronger text or icon emphasis, and a clear control state.
- Avoid nested framed cards.
- Use shadows sparingly and consistently.
- Gradients are an exception, not a general surface treatment. They may appear inside rendered illustrations, the coach-read card, or a purposeful indeterminate progress treatment; keep ordinary cards and buttons flat.

### Elevation

Use three elevation levels:

- **Level 0 — embedded**: no shadow; tinted surface within the page.
- **Level 1 — raised**: soft ambient shadow for choice cards, floating icon buttons, and tactile objects.
- **Level 2 — modal**: stronger but diffused shadow for sheets and temporary overlays.

Shadows should feel like soft daylight, not glossy interface effects. Avoid glows, hard drop shadows, and dark floating panels.

## Shape Language

Forte uses soft, generous geometry.

- **8px**: compact internal details.
- **12px**: small controls and utility icon buttons.
- **16px**: inputs, chips, metric tiles, and compact cards.
- **20px**: default content cards and choice rows.
- **24px**: sheets, major recommendations, and large grouped surfaces.
- **32px**: rare immersive image panels or large onboarding containers.
- **Full pill**: primary buttons, status chips, and segmented controls.

The geometry should feel soft but controlled. Avoid excessive bubble shapes, mismatched radii, or cartoon-like rounded containers.

## Illustration and Icon System

Forte uses three deliberately different visual tiers. Do not mix their roles.

### Tier 1: Large Balanced-Object Illustrations

Use for:

- onboarding backgrounds
- empty states
- major coach moments
- hero cards
- weekly summaries
- large recommendation panels
- section-level emotional or contextual storytelling

Style:

- geometric still life with an editorial, sculptural quality
- abstract object compositions inspired by Zen balance and Bauhaus geometry
- stacked or carefully balanced spheres, bowls, arches, blocks, and related simple forms
- matte plaster-like surfaces with subtle tactile grain
- soft daylight, restrained contact shadows, and quiet depth
- calm, minimal compositions with generous negative space
- warm neutrals supported by muted lilac, jade, sand, indigo, and other palette colors
- restrained detail in text-heavy areas so the composition never becomes the main information layer

This direction is also called **Geometric still life**, **Abstract object composition**, **Zen balance illustration**, or **Bauhaus-inspired object composition**. Core keywords are **stacked spheres, balance, calm, sculptural, minimal, soft shadows**.

Large illustrations should usually sit behind or beside content rather than behave like icons. They may use indigo, lilac, blue, green, sand, peach, and warm neutrals freely as long as the final composition remains soft and harmonious. Use `Assets/illustration-balanced-objects.png` as the canonical reference for composition, material, lighting, and shadow softness.

Do not use mountains, natural scenery, landscape vistas, or atmospheric environment paintings as the Forte illustration language. Also avoid photorealism, stock-photo aesthetics, glossy 3D scenes, cartoon mascots, and flat line-art for large illustrations.

### Tier 2: Medium Skeuomorphic Icons

Use for:

- workout modality indicators
- weather
- fatigue and readiness
- sleep and recovery
- nutrition and hydration
- equipment
- location or environment concepts when visually prominent
- goal categories
- onboarding choices
- major metrics
- coach recommendations
- category recognition

Typical size: 32px to 80px.

Style:

- 3D isometric or three-quarter perspective
- skeuomorphic, tactile, and object-like
- recognisable materials, volume, highlights, and soft shadows
- simplified enough to read instantly at mobile size
- realistic proportions may be gently stylised
- one primary object or tightly grouped concept
- presented according to one of the named object, plinth, or review families below
- consistent soft directional light, preferably from the upper-left
- consistent camera angle across the family
- controlled depth and detail; do not become miniature product renders

Examples include a bicycle, dumbbell, rainy cloud, fatigue cloud, running shoe, water bottle, target, calendar, heart, link, hurdle, or telescope.

These icons are not claymorphism. Avoid rubbery inflated forms, excessive softness, monochrome clay surfaces, toy-like proportions, and blob-shaped objects unless the subject itself requires them.

#### Medium-icon families

The medium tier has three production families. The family is part of the meaning and must be chosen intentionally.

**Object icons — `object-icon-*`**

- A freestanding tactile 3D object with transparent background and no standard base.
- Use when the object itself has a strong silhouette: modality, equipment, weather, readiness, fatigue, barriers, or an action concept.
- Best for image-choice grids and compact stacked choices.
- Keep object scale and camera angle consistent within a set shown together.

**Plinth icons — `plinth-icon-*`**

- A tactile 3D object presented on the shared low warm-ivory marble plinth.
- Use for conceptual or reflective choices where a curated, editorial feeling is useful: intent, time of day, coaching support, motivation, or a matched descriptive range.
- Keep plinth dimensions, camera, lighting, and object scale consistent across the set.
- The plinth is presentation, not a button background; selection still belongs to the surrounding UI component.

**Review icons — `review-icon-*`**

- A simplified, lower-density 3D concept inside a pale solid rounded rectangle baked into the artwork.
- Render at 48×48px in readbacks, summaries, blueprints, strategies, integration metadata, and other compact read-only evidence.
- Use one clear semantic object or tightly grouped concept with generous internal whitespace.
- Keep the background rectangle soft and low-contrast; vary tint gently for scanning without creating a status-color system.
- Choose the icon for the field's stable meaning, not the current answer. A `Training` review row uses a generic training concept even when the selected modality is cycling.
- Give adjacent rows distinct concepts. Do not repeat one generic target or priority illustration across an entire section.
- Match dynamic or AI-authored content by stable semantic role, with a controlled text fallback only when necessary.
- Review icons are reserved for review and readback contexts. Do not use their baked background treatment in ordinary modality grids, primary choices, navigation, or compact utility controls.

Temporary outline-icon wells may be used only while a required review asset is missing. They are a fallback, not the visual direction.

#### Asset quality and naming

- Use `Assets/README.md` as the filename convention reference.
- `review-icon-*`, `plinth-icon-*`, and `object-icon-*` are production families.
- `chroma-plinth-icon-*` identifies a legacy source whose chroma-key background still needs cleanup. Never ship it as-is or treat it as a finished production family.
- Preserve a source asset in `Forte-designs/Assets` and a correctly named platform asset in the application catalog.
- Reuse an existing asset when both the stable semantic role and presentation family match. Similar subject matter alone is not enough.

Compact choice rows may use this tier at **40px to 50px** when the object has a strong silhouette and remains recognisable at that rendered size. Review and readback rows use the dedicated review family at **48px**. Reuse an existing medium icon when the semantic role and family already match; do not create near-duplicate gym, modality, or equipment artwork. Small functional controls inside the same row—checks, radios, chevrons, locks, and disclosure marks—remain Tier 3 outline icons.

Time-of-day choices form a matched sub-family: a coffee cup for morning, a simple sun for afternoon, and a nightstand lamp for evening. Render all three on the same low warm-ivory pedestal, at the same camera angle and object scale. Represent schedule flexibility with a standalone loose elastic band; do not use sparkles or other AI-associated symbols for this concept.

Consistency barriers use direct object metaphors at compact row scale: calendar and clock for work schedule, low battery for low energy, wrapped arm for soreness, blank clipboard for no plan, carry-on suitcase for travel, split lightning bolt for motivation, and rain cloud for weather. Keep these as isolated objects without pedestals so they align with the existing stacked-choice icon family.

Body-composition range choices use one matched tree family on the same warm-ivory pedestal. Keep the trunk, branch structure, camera, scale, lighting, and base consistent while foliage density progresses from bare to lush across the six ranges. The progression is descriptive rather than evaluative: do not use warning colors, success colors, faces, or body silhouettes. The profile-based estimate uses one tree with a smooth sparse-to-lush canopy transition and a few muted mixed-color leaves to communicate locating a position within the range.

Coaching-support choices use reassuring object metaphors on the shared warm-ivory pedestal: a soft circular return around a pebble for calm reset, a compact megaphone for direct push, a feather for the easiest useful option, a level balance scale for tradeoff explanation, and a compass for reconnecting to purpose. Keep this family supportive rather than punitive; avoid alarms, warning colors, shouting marks, guilt imagery, or aggressive sports poses.

Bad-day floor choices reuse established objects whenever the meaning is unchanged: the walking shoe for walk or mobility, the dumbbell for a short strength circuit, and the elastic band for a variable response. Add a compact stopwatch for an easy timed session and a structured pillow with sleep mask for intentional rest. Keep the objects isolated and at the same compact editorial-card scale; avoid magic wands, sparkles, or near-duplicate modality artwork.

Specific-goal and discovery choices extend the plinth family only where the consistency library has no matching concept. Experience uses one through four graduated neutral rings; priority uses target, balanced beam, protective shield, and paired strength/cardio objects; direction uses athletic drill, supported barbell, endurance loop, and general sport-readiness objects; challenge style uses gauge, deadline flag and calendar, ascending skill steps, and a self-reflection mirror. These are stable role mappings and must never be selected by comparing user-visible copy.

Avoidance and generated-goal cards prefer existing object artwork when both meaning and presentation match. Long-workout, strict-plan, high-intensity, gym-dependence, and no-specific-avoidance states use calm, non-punitive metaphors. Candidate artwork is chosen through `ForteGoalCandidateVisualRole`; arbitrary AI-provided system-image strings are categorization hints only and are never treated as asset names. Summary rows use `ForteSummaryAnswerRole`. Strategy phases and targets use their corresponding Forte phase view models and visual roles. A redesigned production state must resolve to a catalogued Forte asset; expressive SF Symbols are not a production fallback.

### Tier 3: Small Utility Icons

Use for:

- chevrons
- arrows
- close and back controls
- overflow menus
- small location markers
- tabs
- small calendar and clock marks
- filters
- sliders
- share
- bookmark
- information
- small chart indicators
- inline status marks

Typical size: 16px to 24px.

Style:

- clean outline construction
- approximately 1.75px stroke at standard size
- rounded terminals and joins
- simple geometry
- minimal internal detail
- dark ink by default
- indigo for active or emphasized states
- filled details only when needed to communicate state

Utility icons should not imitate the rendering of medium icons. Their role is speed and clarity.

### Cross-System Rules

- Never use emoji in production UI.
- Do not use a medium 3D icon where a small utility symbol would be clearer.
- Do not shrink large editorial illustrations into icons.
- Do not enlarge outline icons to substitute for expressive artwork.
- Keep a shared visual vocabulary across all medium icons: camera, lighting, shadow, material softness, and object scale.
- Maintain accessible labels where an icon’s meaning is not universal.
- Build the system to scale beyond cycling, strength, recovery, weather, and fatigue.

## Components

### App Shell

- Warm off-white background.
- Dark ink typography.
- Minimal chrome.
- Indigo active and interaction states.
- Brand presence should be subtle and need not appear as a logo on every screen.
- Constrain reading-heavy content to a centered 480px maximum-width column with 24px phone gutters.
- A cropped balanced-object illustration may sit in the upper-right as ambient chapter artwork. Keep it away from the headline's reading field and reduce opacity to roughly 0.40–0.52 on content-heavy screens.
- Bottom navigation should remain visually quiet and use outline utility icons.
- Active navigation may use indigo icon and label, with an optional pale indigo capsule.

### Primary Buttons

- Indigo fill with white text.
- Indigo Deep pressed state.
- Full-width when representing the main forward action.
- 56px is the canonical height for the main forward action; 48px is acceptable inside compact cards or retry states.
- Pill radius.
- Optional trailing outline arrow.
- Calm verbs such as `Continue`, `Start session`, `Check in`, or `Update plan`.
- Do not use gradients or illustrations inside standard primary buttons.
- In a focused multi-step workflow, place the button in a fixed bottom action rail using the page background at approximately 97% opacity.

### Secondary Buttons

- The canonical correction or alternate action uses a white 48px pill with Indigo Deep text and a subtle neutral border.
- Indigo Soft or a soft neutral fill may be used when the action behaves more like a selectable alternative than a correction.
- Use for reviewing, swapping, moving, or choosing alternative paths.

### Tertiary and Utility Buttons

- White or transparent surface.
- Dark outline icon or text.
- Subtle elevation only when floating over imagery.
- Use for back, close, overflow, filters, and non-primary actions.

### Choice Cards

Choice cards should feel tactile but not heavy.

- White or softly tinted fill.
- 20px radius.
- Level 1 soft shadow or subtle border, not both unless needed.
- Medium skeuomorphic icon at the leading edge.
- Serif title when the choice is conceptual or coach-led.
- Sans serif description.
- Outline radio or check control.
- Selected state uses Indigo Mist or Indigo Soft with a stronger indigo control state.
- Avoid colored outlines as the primary selected treatment.
- Reuse `ForteEditorialChoiceCard` for choices that combine a medium expressive icon, a serif title, explanatory copy, an optional compact badge, and a single-select radio state.
- Keep the image well 68px square with a subtle vertical divider between the object and copy.
- Use this component for intent-scale decisions and body-composition ranges; do not compress either into stacked rows merely to fit more choices above the fold.

### Image Choice Tiles

Use image choice tiles for small sets of visually distinct categories that benefit from a medium skeuomorphic icon, such as modalities or parts of the day.

- Use a three-column grid at standard Dynamic Type and two columns at accessibility sizes.
- Keep tiles 100px high with a 62px medium icon, a one-line 13px label, and a 16px radius.
- Use the white Surface resting state and Indigo Mist selected state, supported by an indigo border and semibold label.
- Optional compact badges may communicate rank or sequence; omit the badge for ordinary multi-select choices.
- Keep icon scale, lighting, and camera angle consistent across the row.
- Reuse `ForteImageChoiceTile` so modality, availability, and later category grids share geometry and state behavior.

Do not use these tiles for options that need explanatory copy, dense data, or text-only distinctions.

### Weekday Initial Selectors

Use initials for compact Monday-through-Sunday selection when the surrounding label already establishes that the controls represent days.

- Keep the canonical order Monday through Sunday and expose full day names to accessibility.
- Use 42×48px chips with a 14px radius, semibold rounded initials, and at least a 44px touch target.
- Keep weekday and weekend chips on the same neutral surface. Use a subtle vertical divider between Friday and Saturday to improve scanning without assigning semantic colors to the calendar.
- Use Indigo Mist, Indigo Deep text, stronger weight, and a subtle indigo border for selected days.
- Do not add pictograms to the weekday chips; their initials are the information.

Avoid separate weekday and weekend colors unless a future workflow gives those groups distinct meaning beyond their calendar position.

### Stacked Choice Lists

Use a stacked choice list when an onboarding question presents four or more closely related, compact options and each option needs only an icon, a short label, and a selection control.

- Place all rows inside one white or softly neutral surface with a 24px outer radius.
- Use 64px to 72px rows; 68px is the default.
- Use one 48px to 50px medium skeuomorphic icon per row, with consistent object scale, camera angle, and upper-left light.
- Reuse existing `object-icon-*` or `plinth-icon-*` assets whenever the same semantic object and presentation family already communicate the option.
- Separate unselected rows with subtle inset dividers rather than individual card borders or shadows.
- Use Indigo Mist across the full selected row, plus a filled indigo check or radio control. Selection must not rely on color alone.
- Keep row labels in compact sans serif and preserve at least a 44px touch target.
- Keep the list inside the screen's scrolling content while the primary Continue action remains fixed at the bottom.
- Use the shared `ForteStackedChoiceList` component so later screens inherit the same geometry and state treatment.

Do not use the stacked pattern for choices that need multi-line explanations, ranking, comparison, or large expressive icons; use separate choice cards or a grid for those cases.

### Text Areas

Use a text area for optional context that helps Forte understand a choice without turning the onboarding step into a form-heavy experience.

- Place a concise 15px semibold label outside and directly above the input.
- Use a white surface, 20px radius, 16px internal padding, and a minimum height of 148px.
- Keep the resting border subtle. On focus, strengthen it with Indigo rather than adding a glow or saturated fill.
- Use Ink for entered text and a softened Ink Muted for placeholder copy.
- Put the live character count inside the lower-right corner in 12px rounded, tabular numerals.
- Enforce the character limit in the component instead of relying on validation after submission.
- Keep text areas inside scrolling content so the keyboard can reveal and dismiss them naturally; the primary Continue action remains fixed below the scroll view.
- Reuse `ForteTextArea` for multiline free-form onboarding inputs so labels, focus state, counter placement, and limits remain consistent.

Do not use an oversized text area for a short factual answer. Use a compact single-line field, picker, or structured choice when the response has a predictable format.

### Wheel Selectors

Use a wheel selector for a short ordered range where users benefit from quickly flicking between adjacent values, such as weekly frequency, duration, weight, or height.

- Use the native iOS wheel picker interaction. Never emulate a wheel with tappable rows or custom scroll snapping.
- Keep each option row 44px high inside a 152px viewport, with the selected value centered.
- Use Ink Muted for surrounding values and preserve the native wheel's top and bottom fading.
- Use the native selection highlight only. Do not layer a custom highlight band behind or over it.
- Group paired values inside one centered white 24px-radius surface, capped near 320px wide, with a subtle divider and at least 16px of visual gutter between the two selection bands; avoid separate bordered picker boxes.
- Center field labels above their wheel columns in 13px semibold sans serif.
- Preserve native press-and-drag, flicking, deceleration, snapping, direct row taps, selection haptics, and VoiceOver adjustable actions.
- Default values may be preselected when they represent a safe, reversible starting point; never imply that a preselection is a recommendation.
- Reuse `ForteWheelSelector` so later numeric and ordered pickers inherit native wheel motion, selection highlight, fading, and accessibility behavior.

Do not use a wheel for unordered categories, long labels, destructive settings, or lists with only two values. Use stacked choices, chips, or a segmented control instead.

### Compact Timeframe Selection

Use one grouped white 24px-radius surface for short mutually exclusive horizons. Present 4, 8, and 12 weeks as compact indigo single-select controls; a concrete-goal flow may add a Date control in the same group. Selecting Date expands the native future-date picker inside that surface instead of opening a custom calendar or a second page. Generated-goal editing uses only the compact 4/8/12-week set. Keep native date semantics, locale formatting, and accessibility intact.

### Discrete Ambition Selector

Goal ambition is an accessible four-position discrete slider: Gentle, Steady, Ambitious, and Extreme. Steady is the neutral default. The thumb and active track use Indigo, values snap to whole positions, and VoiceOver exposes the selected label and adjustable actions. Place the control inside one white 24px surface. Explain the selected level below it in an Indigo Mist coach-context card; the explanation is guidance, not a warning or risk score.

### Rich Generated-Goal Cards

Generated directions use editorial selectable cards with a stable semantic object, serif goal title, compact timeframe pill, rationale, tracking context, and an explicit radio or check state. Single-select cards support Continue and quiet Edit selected / Blend two actions. Blend selection uses the same card, permits exactly two selections, and does not invent a separate visual grammar. Long AI-authored copy must wrap without hiding state or colliding with the fixed action rail. Never use the AI response's `systemImage` value directly as an asset name.

### Phased Strategy Review

After the strategy readback, show Base, Build, and Review as three grouped white 24px-radius sections. Each phase has a stable review illustration, an editorial objective, and exactly three measurable target rows with semantic review assets and optional value pills. Finish with a quiet Indigo Mist Plan bridge explaining that the first two weeks come next. `Accept strategy` remains fixed below the scrolling review; phase content and target artwork come from `ForteStrategyPhaseItem` and `ForteStrategyPhaseTargetItem` view models.

### Content Cards

- Use white or softly tinted surfaces according to hierarchy.
- Use 20px for compact cards and 24px for major grouped or read-only surfaces.
- Keep one dominant message per card.
- Large editorial illustrations may sit in the background or occupy a dedicated edge.
- Preserve a quiet text zone.
- Avoid placing decorative art behind small body copy.

### Metric and Condition Cards

These extend the Weather and Fatigue reference:

- softly tinted background
- one medium skeuomorphic icon
- compact sans serif label
- one clear primary value
- one short interpretation or action
- optional outline chevron when interactive

Different cards may use different supportive colors. Maintain consistent layout and icon rendering rather than forcing a single color.

### Workout Cards

- Prioritize purpose and coach interpretation over raw data.
- Use a medium skeuomorphic modality icon.
- Show only the most decision-relevant metrics.
- Use small outline icons for secondary metadata.
- Keep actions visually secondary to the workout.
- Avoid red destructive controls unless the action is genuinely destructive.

### Chips and Tags

- Use soft fills rather than outlined pills.
- Selected chips use Indigo Soft with Indigo Deep text.
- Keep wording short.
- Small leading icons must use the outline utility style.
- Avoid dense walls of chips.

### Inputs

- White or soft neutral fill.
- 16px radius.
- Minimal border.
- Clear focus state using indigo stroke or subtle indigo halo.
- Utility icons inside inputs remain outline icons.
- Do not use medium skeuomorphic icons inside compact text inputs.

### Progress

- Active segmented progress uses Indigo Deep.
- Inactive progress uses a low-contrast neutral.
- Segmented onboarding progress is 3px high with 6px gaps and should remain restrained.
- Do not use multiple bright colors in one progress component unless the segments have distinct semantic meaning.

### Loading and Generative Transitions

- Treat longer onboarding work as a calm transition screen, not a disabled form or an oversized system spinner.
- Keep the standard onboarding progress header, back action and exit action so the user remains oriented and in control.
- Use the balancing-object composition as the focal loading metaphor. A restrained breathing or floating motion is appropriate; avoid robotic imagery, magic sparkles, chat bubbles or an AI avatar.
- Pair the focal object with one elevated status card containing a short activity title, one concise explanation and a single indeterminate indigo progress track.
- Do not invent percentage completion or multiple staged checkpoints unless the underlying task exposes real progress.
- Move forward automatically when work completes. Do not show a disabled Continue button during generation.
- Respect Reduce Motion by holding the composition and progress indicator in a stable state.
- On failure, replace the animation with a calm retry card. Reassure the user that their answers are preserved, keep technical detail visually secondary and use one clear Try again action.

### AI Readbacks and Confirmation

- Visually separate Forte's interpretation from the source answers so users can compare inference with evidence.
- Present the interpretation in one Indigo Mist-to-white coach-read card using editorial body type, a compact code-native balancing-object mark, a restrained border, and a soft diffused shadow. This is a purposeful gradient exception. Do not use magic sparkles, a chatbot avatar, or a conversational speech bubble.
- Label the same interpretation component according to its role: **Forte Readback**, **Coach's Read**, or **Coach Verdict**. Consistency of component grammar matters more than repeating one label everywhere.
- Give dense read-only rows visual wayfinding with the dedicated `review-icon-*` family at 48×48px. These illustrations are lower-density than primary choice artwork and include their own pale rounded background rectangle.
- Assign review illustrations by stable semantic role. Use generic concepts that survive different user answers, and use distinct icons for adjacent concepts such as training signal, weekly capacity, and recovery guardrail.
- Do not cycle one generic icon through unrelated rows. Repeating an illustration is acceptable only when the rows are genuinely multiple observations of the same stable category.
- Keep the surrounding row surfaces white and copy neutral. Illustration color supports scanning; it must not imply selection, status, or urgency. Navigation, progress, and primary actions remain indigo.
- Keep the readback to one or two direct sentences. It should address the user and identify the most decision-relevant pattern rather than repeat every answer.
- Place source answers underneath in one white 24px-radius stacked surface with compact read-only rows, 48px review illustrations, and dividers inset to 76px.
- Keep confirmation and correction equally clear: use a fixed primary **Looks right** action followed by a quieter **Edit answers** action.
- Readbacks advance automatically only after explicit confirmation. Generated interpretation must never silently replace the user's original answers.
- Treat the Athlete Blueprint as the second chapter of the same readback system. Use the shared Indigo Mist interpretation card, relabel it **Coach's Read** and follow it with the evidence that supports the interpretation.
- Group blueprint evidence into stacked read-only sections for athlete type, current state, physical baseline and history signals. Keep goal fit visually distinct but within the same indigo editorial language.
- Keep **Accept blueprint** and **Edit answers** fixed at the bottom. Accepting advances to strategy generation while editing invalidates the generated blueprint and returns to the source questions.
- Treat the Fitness Strategy as the final translation of the readback sequence: answers establish context, the blueprint describes the athlete and the strategy states how Forte will coach.
- Present strategy snapshot metrics in a spacious 2-by-2 grid. Do not compress four metrics into one narrow row on phone widths.
- Use a 48px review illustration, 19px editorial value, 12px sans serif label, 15px internal padding, 20px radius, and a minimum card height near 132px for each strategy snapshot tile.
- Reuse the shared interpretation card for the **Coach Verdict**, then organize fit reasons, priorities, and targets as separate stacked read-only evidence sections.
- Do not add an **Operating Rhythm** section. If cadence matters, express it through the strategy snapshot, targets, or the plan itself rather than repeating a summary block.
- Strategy targets must use distinct semantic illustrations—for example a modality object for a training signal, capacity for rhythm, and recovery for a hard-day cap. Never apply one section-wide target icon by default.
- Keep the final action fixed and explicit. **Accept strategy** is the canonical completion label for this chapter.

### Apple Health Connection

- Use Apple's official layered Health developer artwork as the visual anchor. Preserve its transparent background and original pink, teal and blue treatment so the brand callback remains distinct from Forte's indigo interaction language.
- Keep the identity card's status capsule below the Apple Health title and connection description. It must remain on one line and must not compete with the artwork for horizontal space.
- Present the connection state beside the Apple Health identity in a compact status capsule. Do not imply a successful connection before HealthKit confirms it.
- Explain requested data in the same compact read-only metadata style as onboarding summaries: one stacked white surface, 48px semantic review illustrations, inset dividers, and short plain-language descriptions.
- Put privacy reassurance near the data list. State that Forte computes features locally first and sends compact summaries rather than raw HealthKit samples.
- Keep simulator fixture controls visually secondary and label them as sample data, not as an Apple Health connection.
- The primary action remains fixed at the bottom and changes from connection to blueprint generation only when the underlying state permits it.

### Sheets and Modals

- White or near-white elevated surface.
- 24px top corner radius.
- Level 2 diffused shadow.
- Serif title when appropriate.
- Medium skeuomorphic icon may appear as the main contextual visual.
- Supporting controls and row icons should remain outline.
- Sheets should focus the user on explanation, adjustment, or context.

## Applying the System Beyond Onboarding

The consistency flow defines the product language; other areas should compose the same primitives around different jobs.

### Today

- Lead with one editorial coach message that answers what matters now.
- Put the next useful action ahead of historical data.
- Use a medium object icon for the recommended modality or condition, then outline symbols for time, location, and disclosure.
- Use one dominant primary action. Alternative sessions or adjustments are secondary.
- Weather, readiness, and recovery cards should explain their consequence, not merely report a value.

### Plan

- Use section overlines, white grouped surfaces, and inset dividers for weekly structure.
- Keep workout rows operational and sans serif; reserve editorial type for the plan's purpose, phase, or coach explanation.
- Use object icons for actual modalities and review icons only when summarizing the meaning of the plan.
- When editing constraints, return to the same choice-card, stacked-list, wheel, and text-area patterns established in onboarding.

### Progress

- Start with a coach interpretation before presenting supporting metrics.
- Use the strategy snapshot's 2-column metric pattern only for a small set of comparable headline measures.
- Prefer trends, consistency, and meaningful comparisons over dense chart collections.
- Pair each major metric group with a short interpretation or next action.
- Avoid turning illustration color into a permanent metric taxonomy.

### Coach

- The coach is a product-wide voice, not a chatbot skin.
- Use the coach-read card for durable interpretations, verdicts, and explanations.
- Conversation may handle nuance, but do not make speech bubbles, avatars, or AI sparkle motifs the system's visual identity.
- When the coach recommends a change, separate the recommendation, evidence, and action using the same readback grammar as the final onboarding chapters.

### Profile, Health, and Settings

- Use the data-or-connection page grammar: clear identity, current state, what is used, why it matters, and how to change it.
- Group related metadata inside one white 24px-radius surface rather than a stack of independent bordered cards.
- Use semantic status capsules for connection or account state and utility symbols for controls.
- Use review icons for read-only category summaries; use object or plinth icons only when a concept is being chosen or introduced.

### Cross-area Consistency

- Reuse tokens and component geometry before inventing page-specific variants.
- A component may change copy and content density, but its state behavior, radius, typography role, icon family, and action hierarchy should remain recognisable.
- New product areas should look like later chapters of the same product, not separate mini-apps.

## Navigation

Use no more than five items.

Recommended v1 structure:

- Today
- Plan
- Progress
- Coach
- Profile

The coach should feel present throughout the app, not isolated to a chat destination.

Active navigation states should use:

- indigo icon and label
- optional Indigo Soft background capsule
- slightly stronger visual weight

Inactive navigation uses Ink Muted outline icons and labels. Avoid illustrated or skeuomorphic navigation icons.

## Onboarding

Onboarding should feel immersive, calm, and personal.

- Use large balanced-object compositions to establish calm and visual character.
- Keep the main question in serif.
- Use sans serif for explanation and progress metadata.
- Use medium skeuomorphic icons inside answer cards.
- Use outline radios, arrows, close controls, and progress marks.
- Keep indigo as the main interaction signal.
- Allow illustration colors to support the subject without becoming the navigation system.
- Protect text legibility when illustrations extend behind content.
- Avoid making every step visually unique; preserve a stable layout and vary the artwork and choices.

### Consistency-intent reference flow

The final flow demonstrates when to use each component family:

- **Intent**: large editorial choice cards with plinth-style conceptual artwork.
- **Modalities and available times**: compact image-choice grids with freestanding object icons; selected modality order appears as a small indigo badge.
- **Available days**: initial-only weekday selectors; calendar position supplies the context.
- **Access, motivation, and consistency barriers**: white stacked choice lists with tactile leading objects and filled indigo selection controls.
- **Optional nuance and injuries**: a focused text area following the relevant structured choice, or standing alone when free-form context is the only useful input.
- **Weekly capacity and body baseline**: paired native wheel selectors inside one centered white 24px-radius surface.
- **Body-fat range, coaching support, and bad-day floor**: editorial choice cards because each option requires explanation and reflection.
- **Generation**: a calm balanced-object transition plus one honest indeterminate status card.
- **Answer readback**: coach interpretation, source answers, primary acceptance, and quiet correction.
- **Apple Health**: identity, verified status, requested data, privacy context, and explicit connection action.
- **Athlete Blueprint**: interpretation followed by snapshot, history evidence, and goal fit.
- **Fitness Strategy**: 2-column snapshot, coach verdict, fit reasons, priorities, distinct semantic targets, and one explicit acceptance action.

This sequence is a component reference, not a requirement that future workflows reproduce every step. Use the shortest composition that explains the decision and earns the requested input.

### Specific-goal and goal-discovery extensions

Both additional intents reuse the consistency screens for modalities, access, weekly capacity, availability, barriers, injury context, body baseline, support, bad-day floor, generation, readback, Health, blueprint, and strategy. Branch-specific screens use the same progress header, editorial hero, balanced-object background, scrolling content area, and fixed action rail.

- **Specific goal** adds a 280-character guided brief, graduated experience cards, compact timeframe selection with optional native Date expansion, and editorial training-priority cards.
- **Goal discovery** adds direction and challenge cards, a compact multi-select avoidance list, the discrete ambition selector, generated-goal cards, 320-character editing, and exactly-two candidate blending.
- **Both goal branches** finish with the same phased strategy review. Do not fork shared downstream screens or duplicate their business state merely to vary branch copy.

## Coaching Voice

Forte should sound like a calm personal coach.

### Voice Principles

- specific, not generic
- encouraging, not celebratory by default
- direct, not clinical
- realistic, not aspirational at all costs
- emotionally aware without pretending to be therapy
- focused on follow-through, resilience, and self-trust

Prefer:

- `A shorter ride still keeps the week moving.`
- `You have enough recovery for an easy session today.`
- `This keeps your rhythm without adding unnecessary fatigue.`
- `You do not need a perfect week to keep the promise you made to yourself.`

Avoid:

- `Crush your goals.`
- `No excuses.`
- `You are unstoppable.`
- guilt-based streak language
- exaggerated AI claims
- medical or therapeutic overreach

## Product UX Principles

- Forte is a coach, not a tracker.
- Recommendations should explain why they matter now.
- The system should adapt to schedule, fatigue, weather, and user feedback.
- Structured controls should handle common decisions quickly.
- Conversation should handle nuance, uncertainty, and exceptions.
- Health permissions should follow a clear value explanation.
- The product should reward returning and following through, not only performance.
- Show the minimum data needed to support a decision.
- Keep room for future modalities, metrics, nutrition, and mental wellbeing without changing the core visual identity.

## Accessibility

- Maintain WCAG-compliant text contrast.
- Never place essential text over visually busy illustration areas.
- Do not rely on color or icon shape alone to communicate state.
- Keep touch targets at least 44px.
- Provide accessible labels for non-standard skeuomorphic icons.
- Preserve Dynamic Type support for body and utility text.
- Ensure large serif headlines reflow without clipping.
- Reduce decorative motion when Reduce Motion is enabled.
- Do not animate dimensional icons continuously.

## Motion

Motion should feel gentle and natural.

- Use easing rather than springy or bouncy transitions by default.
- Small icon movement may acknowledge selection or completion.
- Large illustrations should remain mostly static.
- Sheets and navigation use standard platform motion.
- Avoid gamified celebrations, confetti, pulsing glows, and constant ambient movement.

## Do's and Don'ts

### Do

- Use warm off-white as the persistent app background.
- Keep typography dark and high contrast.
- Use indigo as the primary brand and interaction accent.
- Use serif selectively for coach voice and editorial emphasis.
- Use softly tinted surfaces instead of constant outlines.
- Allow supporting color freedom inside illustrations and medium icons.
- Use large geometric still-life illustrations for atmosphere and storytelling.
- Use medium 3D isometric skeuomorphic icons for recognisable concepts.
- Choose the medium-icon family by context: object for strong silhouettes, plinth for curated conceptual choices, and review for compact read-only evidence.
- Use distinct semantic review illustrations within a section and keep them generic enough to survive different user answers.
- Use small outline icons for utility and navigation.
- Use generous corners and calm spacing.
- Make guidance feel personal and specific.
- Design for resilience, consistency, and self-trust.

### Don't

- Do not resemble Strava through orange, endurance-first cues, or high-energy visual language.
- Do not use emoji as modality or metric icons.
- Do not use claymorphism for the medium icon family.
- Do not use large outline illustrations as hero imagery.
- Do not use mountain scenes, landscape vistas, or other natural scenery as the primary illustration style.
- Do not use 3D skeuomorphic icons for chevrons, tabs, filters, or other small utilities.
- Do not use baked-background review icons inside ordinary choice grids or navigation.
- Do not repeat one generic review icon across unrelated rows or targets.
- Do not ship chroma-key source exports as finished production assets.
- Do not make every content block a bordered white card.
- Do not permanently assign one color to every sport or metric.
- Do not become as playful or visually busy as Yazio.
- Do not create a cold technical dashboard.
- Do not overuse uppercase labels, pills, or metadata.
- Do not treat serif as a novelty or apply it to dense utility content.
- Do not use macho, guilt-based, or hype-driven fitness language.
- Do not make AI the visual hero.
- Do not mix inconsistent 3D camera angles, lighting styles, or rendering quality.

## Brand Status

`Forte` is the current working name. The visual system should support future naming variations such as `Fortee` or `Fortt` without requiring a redesign.

Avoid building the identity around Portuguese-language explanation or a literal strength symbol until naming and trademark work are complete.
