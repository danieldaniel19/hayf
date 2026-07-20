---
version: gamma
name: Forte
status: provisional-name

description: Calm, encouraging, and light mobile coaching system for Forte, a personal coach that helps people follow through with realistic training goals and build trust in themselves through consistency.

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
    fontSize: 42px
    fontWeight: 600
    lineHeight: 1.08
    letterSpacing: "-0.02em"
  h1:
    fontFamily: "Newsreader, Iowan Old Style, Georgia, serif"
    fontSize: 32px
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "-0.015em"
  h2:
    fontFamily: "Newsreader, Iowan Old Style, Georgia, serif"
    fontSize: 24px
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
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0px
  bodySmall:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: 0px
  label:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 13px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.01em"
  overline:
    fontFamily: "SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "0.16em"

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
    style: "3D isometric skeuomorphism"
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

  button-primary:
    backgroundColor: "{colors.indigo}"
    textColor: "{colors.onAccent}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 56px

  button-primary-pressed:
    backgroundColor: "{colors.indigoDeep}"
    textColor: "{colors.onAccent}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 56px

  button-secondary:
    backgroundColor: "{colors.indigoSoft}"
    textColor: "{colors.indigoDeep}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 52px

  button-tertiary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 48px

  icon-tile:
    backgroundColor: "{colors.surfaceSoft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    size: 56px

  content-card:
    backgroundColor: "{colors.surfaceSoft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "{spacing.xl}"

  metric-card:
    backgroundColor: "{colors.surfaceSoft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"

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
    backgroundColor: "{colors.indigo}"
    rounded: "{rounded.full}"
    height: 4px

  progress-inactive:
    backgroundColor: "{colors.borderSubtle}"
    rounded: "{rounded.full}"
    height: 4px
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
- Keep coaching content left-aligned.
- Let sections breathe; do not place every group inside a card.
- Prefer one large soft surface over multiple nested white cards.
- Use spacing, typography, tinted backgrounds, and imagery to establish hierarchy.
- Reserve pure white for elevated surfaces, choice cards, sheets, and interaction areas.
- Respect iOS safe areas and preserve clear space around bottom navigation.
- Avoid dense dashboards and rigid tile mosaics unless comparison is genuinely useful.
- Keep large background illustrations away from critical controls and body-copy reading zones.
- When imagery sits behind text, preserve a quiet text field with sufficient contrast and minimal visual detail.

## Surfaces, Borders, and Elevation

The interface should rely primarily on tonal separation.

### Surface Rules

- Default cards use white or softly tinted fills.
- Use no border when surface contrast is sufficient.
- Use a subtle 1px border only for accessibility, selection clarity, input definition, or white-on-white separation.
- Do not use colored outlines as the default selected state.
- Selected states should use a tinted fill, stronger text or icon emphasis, and a clear control state.
- Avoid nested framed cards.
- Use shadows sparingly and consistently.

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
- isolated on transparent or very soft neutral backgrounds
- consistent soft directional light, preferably from the upper-left
- consistent camera angle across the family
- controlled depth and detail; do not become miniature product renders

Examples include a bicycle, dumbbell, rainy cloud, fatigue cloud, running shoe, water bottle, target, calendar, heart, link, hurdle, or telescope.

These icons are not claymorphism. Avoid rubbery inflated forms, excessive softness, monochrome clay surfaces, toy-like proportions, and blob-shaped objects unless the subject itself requires them.

Compact choice rows may use this tier at **40px to 48px** when the object has a strong silhouette and remains recognisable at that rendered size. Reuse an existing medium icon when the concept already matches; do not create near-duplicate gym, modality, or equipment artwork. Small functional controls inside the same row—checks, radios, chevrons, locks, and disclosure marks—remain Tier 3 outline icons.

Time-of-day choices form a matched sub-family: a coffee cup for morning, a simple sun for afternoon, and a nightstand lamp for evening. Render all three on the same low warm-ivory pedestal, at the same camera angle and object scale. Represent schedule flexibility with a standalone loose elastic band; do not use sparkles or other AI-associated symbols for this concept.

Consistency barriers use direct object metaphors at compact row scale: calendar and clock for work schedule, low battery for low energy, wrapped arm for soreness, blank clipboard for no plan, carry-on suitcase for travel, split lightning bolt for motivation, and rain cloud for weather. Keep these as isolated objects without pedestals so they align with the existing stacked-choice icon family.

Body-composition range choices use one matched tree family on the same warm-ivory pedestal. Keep the trunk, branch structure, camera, scale, lighting, and base consistent while foliage density progresses from bare to lush across the six ranges. The progression is descriptive rather than evaluative: do not use warning colors, success colors, faces, or body silhouettes. The profile-based estimate uses one tree with a smooth sparse-to-lush canopy transition and a few muted mixed-color leaves to communicate locating a position within the range.

Coaching-support choices use reassuring object metaphors on the shared warm-ivory pedestal: a soft circular return around a pebble for calm reset, a compact megaphone for direct push, a feather for the easiest useful option, a level balance scale for tradeoff explanation, and a compass for reconnecting to purpose. Keep this family supportive rather than punitive; avoid alarms, warning colors, shouting marks, guilt imagery, or aggressive sports poses.

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
- Bottom navigation should remain visually quiet and use outline utility icons.
- Active navigation may use indigo icon and label, with an optional pale indigo capsule.

### Primary Buttons

- Indigo fill with white text.
- Indigo Deep pressed state.
- Full-width when representing the main forward action.
- 52px to 56px height.
- Pill radius.
- Optional trailing outline arrow.
- Calm verbs such as `Continue`, `Start session`, `Check in`, or `Update plan`.
- Do not use gradients or illustrations inside standard primary buttons.

### Secondary Buttons

- Indigo Soft or soft neutral fill.
- Indigo Deep or Ink text.
- No border unless necessary.
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
- Use one 40px to 48px medium skeuomorphic icon per row, with consistent object scale, camera angle, and upper-left light.
- Reuse existing medium-icon assets whenever the same object already communicates the option.
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

### Content Cards

- Use softly tinted surfaces by default.
- Use 20px radius.
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

- Active progress uses indigo.
- Inactive progress uses a low-contrast neutral.
- Segmented onboarding progress should remain restrained.
- Do not use multiple bright colors in one progress component unless the segments have distinct semantic meaning.

### Sheets and Modals

- White or near-white elevated surface.
- 24px top corner radius.
- Level 2 diffused shadow.
- Serif title when appropriate.
- Medium skeuomorphic icon may appear as the main contextual visual.
- Supporting controls and row icons should remain outline.
- Sheets should focus the user on explanation, adjustment, or context.

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
