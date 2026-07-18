---
version: alpha
name: HAYF
description: Calm, precise, object-like mobile coaching design system for HAYF, a personal training coach that helps users decide what to train today.
colors:
  primary: "#0F0F0F"
  secondary: "#2A2A2A"
  tertiary: "#FA5B1C"
  neutral: "#FAFAF8"
  surface: "#FFFFFF"
  surfaceWarm: "#FAFAF8"
  surfaceRaised: "#F2F2F2"
  surfaceDisabled: "#EAEAEA"
  border: "#ECECEC"
  borderStrong: "#E0E0E0"
  onPrimary: "#FFFFFF"
  onSurface: "#0F0F0F"
  onMuted: "#A3A3A3"
  success: "#22C55E"
  info: "#3B82F6"
  warning: "#F59E0B"
  error: "#EF4444"
typography:
  display:
    fontFamily: "HAYF Grotesk, SF Pro Display, SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 32px
    fontWeight: 700
    lineHeight: 1.08
    letterSpacing: 0px
  h1:
    fontFamily: "HAYF Grotesk, SF Pro Display, SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: 0px
  h2:
    fontFamily: "HAYF Grotesk, SF Pro Display, SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 22px
    fontWeight: 600
    lineHeight: 1.18
    letterSpacing: 0px
  h3:
    fontFamily: "HAYF Grotesk, SF Pro Display, SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: 0px
  body:
    fontFamily: "HAYF Grotesk, SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: 0px
  bodySmall:
    fontFamily: "HAYF Grotesk, SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: 0px
  labelCaps:
    fontFamily: "HAYF Grotesk, SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1
    letterSpacing: 0.1em
  overline:
    fontFamily: "HAYF Grotesk, SF Pro Text, Inter, system-ui, sans-serif"
    fontSize: 10px
    fontWeight: 500
    lineHeight: 1
    letterSpacing: 0.1em
rounded:
  none: 0px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
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
components:
  app-shell:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.onSurface}"
    typography: "{typography.body}"
    padding: "{spacing.xxl}"
  onboarding-shell:
    backgroundColor: "{colors.surfaceWarm}"
    textColor: "{colors.onSurface}"
    typography: "{typography.body}"
    padding: "{spacing.xxl}"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.onPrimary}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 56px
  button-primary-pressed:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.onPrimary}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 56px
  button-primary-disabled:
    backgroundColor: "{colors.surfaceDisabled}"
    textColor: "{colors.secondary}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 56px
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    typography: "{typography.body}"
    rounded: "{rounded.full}"
    padding: "{spacing.lg}"
    height: 52px
  icon-button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.sm}"
    width: 44px
    height: 44px
  input-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.onSurface}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
  chip:
    backgroundColor: "{colors.surfaceRaised}"
    textColor: "{colors.secondary}"
    typography: "{typography.bodySmall}"
    rounded: "{rounded.sm}"
    padding: "{spacing.md}"
    height: 44px
  chip-selected:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    typography: "{typography.bodySmall}"
    rounded: "{rounded.sm}"
    padding: "{spacing.md}"
    height: 44px
  option-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.onSurface}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
  metric-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.onSurface}"
    typography: "{typography.bodySmall}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
  progress-active:
    backgroundColor: "{colors.tertiary}"
    rounded: "{rounded.xs}"
    height: 3px
  progress-inactive:
    backgroundColor: "{colors.border}"
    rounded: "{rounded.xs}"
    height: 3px
  divider-strong:
    backgroundColor: "{colors.borderStrong}"
    height: 1px
    width: 100%
  metadata-label:
    textColor: "{colors.onMuted}"
    typography: "{typography.bodySmall}"
  success-state:
    backgroundColor: "{colors.success}"
    textColor: "{colors.primary}"
    rounded: "{rounded.full}"
    size: 48px
  info-state:
    backgroundColor: "{colors.info}"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
  warning-state:
    backgroundColor: "{colors.warning}"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
  error-state:
    backgroundColor: "{colors.error}"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
---

# HAYF Design System

## Overview

HAYF ("How Are You Feeling") is a personal training coach for busy, tech-forward people balancing strength and cardio. The interface should feel calm, precise, object-like, and coach-like: functional before decorative, premium without feeling cold, and intelligent without making "AI" the visual hero.

Design every screen around the product promise: help the user know what to train today, adapt when real life changes, and protect long-term consistency. Use a restrained monochrome foundation with HAYF Orange as a focused signal for progress, selection, and important interactive moments.

Brand principles:

- **Object-like**: UI controls should feel tangible, engineered, and purposeful. Prefer clean edges, measured spacing, light borders, subtle surface shifts, and restrained shadows.
- **Precise**: Align to a 4px grid. Use consistent icon stroke, consistent card radius, and compact but breathable layout.
- **Calm**: Keep color quiet. Do not overuse orange. Give text and controls enough space so coaching moments feel considered rather than urgent.
- **Personal**: Copy should sound like a practical coach. Be direct, supportive, and realistic. Avoid hype, gamified pressure, or macho performance language.
- **Intentional**: Every element should help the user decide, check in, understand context, or act. Avoid ornamental UI.

Product UX principles:

- HAYF is a coach, not a tracker. Screens should help the user decide, adapt, and follow through.
- AI should feel present through context-aware guidance and conversational access, not through loud AI branding.
- Structured controls and conversational input should coexist. Use controls for speed and clarity; use text/chat for nuance and exceptions.
- Health permissions should be requested only after a value preview or clear explanation.
- Recommendations should preserve consistency, recovery, and realistic rhythm, not only maximize intensity.
- The app should feel fitness-first in v1 while leaving room for future nutrition and mind coaching.

## Colors

The palette is rooted in warm monochrome surfaces, high-contrast ink, graphite utility tones, and one restrained orange accent.

- **Primary / Ink (`#0F0F0F`)**: primary text, black filled CTAs, tab icons, chart emphasis, and high-contrast interface marks.
- **Secondary / Graphite (`#2A2A2A`)**: secondary text, icon strokes, supporting labels, and quiet utility elements.
- **Tertiary / HAYF Orange (`#FA5B1C`)**: brand mark, active states, selected controls, progress indicators, small highlights, and positive coaching emphasis.
- **Neutral / Warm White (`#FAFAF8`)**: full-screen app background, onboarding background, and warm panels.
- **Surface (`#FFFFFF`)**: cards, elevated panels, input fields, and framed grouped content.
- **Surface Raised (`#F2F2F2`)**: subtle raised surfaces, inactive chips, and chart fills.
- **Surface Disabled (`#EAEAEA`)**: disabled controls, skeletons, and deeper dividers.
- **Border / Fog (`#ECECEC`)**: inactive card outlines, input borders, progress tracks, and subtle separators.
- **Semantic Success (`#22C55E`)**: completed actions, permission success, confirmed workout, and check states.
- **Semantic Info (`#3B82F6`)**: informational notices only when needed. Do not use it as a brand color.
- **Semantic Warning (`#F59E0B`)**: caution, reduced readiness, and goal realism warnings.
- **Semantic Error (`#EF4444`)**: destructive actions, severe errors, and injury-risk alerts.

Color rules:

- Use HAYF Orange sparingly: one orange focus per screen area is enough.
- Use black primary CTAs for the main forward action. Use orange to show selection or progress, not as the default filled CTA background.
- Use warm-white instead of cold grey for full-screen coaching flows.
- Keep text contrast high: ink on warm-white or white for primary content, graphite for secondary content, neutral only for metadata and disabled states.
- Do not introduce blue, purple, green, or gradient-led palettes into core product UI.

## Typography

Use a HAYF Grotesk-style sans serif: modern grotesk, neutral warmth, and technical clarity. In implementation, prefer the system font stack unless a custom HAYF Grotesk font is added later.

- **Display (`32px / 700 / 1.08`)**: major onboarding questions and high-emotion coach moments.
- **H1 (`28px / 700 / 1.12`)**: screen titles and recommendation headlines.
- **H2 (`22px / 600 / 1.18`)**: card groups, summaries, and section-level messages.
- **H3 (`18px / 600 / 1.25`)**: row titles, option titles, and compact panels.
- **Body (`16px / 400 / 1.45`)**: coach explanations, helper text, and form content.
- **Body Small (`14px / 400 / 1.4`)**: metadata, captions, card details, and secondary values.
- **Label Caps (`12px / 500 / 1 / 0.1em`)**: section labels such as `ONBOARDING`, `SETUP COMPLETE`, and card eyebrows.
- **Overline (`10px / 500 / 1 / 0.1em`)**: tiny system labels and chart captions.

Typography rules:

- Large onboarding questions should be bold, black, left-aligned, and broken across lines naturally.
- Body copy should be calm and specific. Avoid vague motivational filler.
- Do not use decorative fonts, italic display type, negative letter spacing, or viewport-scaled font sizes.
- Numeric metrics may use tabular numbers when available.
- Labels can be uppercase, but body and button text should use normal sentence casing unless a compact control explicitly calls for all caps.

## Layout

The layout follows a 4px grid with generous mobile padding and precise left-aligned coaching composition. Screens should feel spacious but not empty, and dense information should be organized with dividers, cards, and quiet hierarchy rather than decoration.

Spacing scale:

- **base / xs (`4px`)**: hairline gaps, tiny icon offsets, and chart ticks.
- **sm (`8px`)**: compact internal spacing, chip gaps, and small row spacing.
- **md (`12px`)**: button icon gaps, option-card internal spacing, and compact section gaps.
- **lg (`16px`)**: standard padding, list row padding, and card padding.
- **xl (`20px`)**: tight mobile side padding and larger card padding.
- **xxl (`24px`)**: default mobile side padding, section gaps, and top spacing between content groups.
- **xxxl (`32px`)**: major vertical separation and onboarding header-to-body spacing.
- **huge (`40px`)**: large screen rhythm and bottom CTA separation.
- **giant (`48px`)**: hero/question spacing and large group separation.
- **max (`64px`)**: rare full-screen breathing space.

Layout rules:

- Mobile screens use 24px horizontal padding by default. Use 20px only where space is tight.
- Keep primary bottom actions above the safe area with 24px horizontal padding and at least 24px top separation from preceding content.
- Keep onboarding content left-aligned. Avoid centered text except for small empty states or circular controls.
- Respect iOS safe areas. Content should never collide with the home indicator or Dynamic Island.
- Avoid nested cards. Cards may contain rows, but do not place framed cards inside framed cards unless the inner element is an input or a clearly separate list group.

Onboarding screen anatomy:

- Top-left HAYF mark.
- Top-right home/exit icon button.
- Seven segmented progress bars.
- Step label, e.g. `Step 4 of 7` or `Ready`.
- Uppercase section label.
- Large question headline.
- Short graphite coach explanation.
- Structured input area.
- Full-width primary CTA near the bottom.
- Optional secondary text action below the CTA.

## Elevation & Depth

Depth is achieved through tonal layers, borders, and spacing rather than heavy shadows. HAYF should feel like precise product hardware: clean surfaces, thin outlines, and measured contrast.

- **Hairline border**: 1px `#ECECEC` for inactive cards, inputs, dividers, and icon buttons.
- **Regular selected border**: 1px `#FA5B1C` for selected states and active option cards.
- **Strong border**: 2px `#0F0F0F` only for rare high-emphasis or debug/prototype affordances.
- **Divider subtle**: 1px `#ECECEC`.
- **Divider strong**: 1px `#E0E0E0`.
- **Shadow low**: subtle, soft, and rare. Use for app icon-style objects or modal lift, not for every card.

Elevation rules:

- Prefer border plus surface hierarchy over shadows.
- Use white cards on warm-white backgrounds for most content hierarchy.
- Use `#F2F2F2` and `#EAEAEA` for disabled, skeleton, inactive, and deeper divider states.
- Do not use broad glows, bokeh, gradient orbs, or stacked card shadows.

## Shapes

The shape language is precise, softly engineered, and object-like. Use modest radius for cards and inputs, pill radius for primary full-width CTAs, and circular forms for targets, progress rings, radios, and icon-only controls.

Radius scale:

- **none (`0px`)**: charts, progress segments, and sharp graphic motifs.
- **xs (`4px`)**: tiny icon construction details and compact tags.
- **sm (`8px`)**: default chips, small controls, icon buttons, and inputs.
- **md (`12px`)**: selectable cards, summary panels, and permission cards.
- **lg (`16px`)**: larger content cards and modal sheets.
- **full (`9999px`)**: circular icon buttons, radio controls, progress rings, target motifs, and full-width primary CTA pills.

Shape rules:

- Default interactive controls should use 8px or 12px radius.
- Primary CTAs should use a pill-like radius when full-width, matching the black rounded button in the mocks.
- Do not mix extremely rounded playful components with precise object-like cards on the same screen.
- Icon style should use 2px stroke, rounded joins, balanced geometry, and simple forms. Active icons add a small HAYF Orange dot, segment, stroke, or target point.

## Components

### App Shell

- Background is warm-white `#FAFAF8`.
- Header uses a small HAYF mark at top-left and a home/exit icon button at top-right for onboarding.
- Progress indicator uses seven segmented bars. Active segments are HAYF Orange; inactive segments are Fog. Height is 2px to 3px with square or lightly rounded ends.
- Bottom actions should remain above the safe area and preserve enough space for the home indicator.

### Buttons

- **Primary**: full-width filled ink `#0F0F0F`, white text, pill radius, 52px to 56px height, 16px semibold label, trailing arrow icon.
- **Primary pressed**: graphite `#2A2A2A`, same shape.
- **Primary disabled**: surface-disabled `#EAEAEA`, neutral text `#A3A3A3`, no orange icon.
- **Secondary**: white or warm-white fill, 1px fog border, ink text, trailing arrow when it advances the user.
- **Text action**: simple and unframed. Use ink for neutral actions and HAYF Orange for directional or historical actions.
- Use one primary CTA per screen. Common labels include `Continue`, `Check In`, `Start with this rhythm`, and `Connect Apple Health`.

### Inputs and Chips

- **Input default**: surface fill, 1px fog border, 12px radius, 16px body text, neutral placeholder.
- **Input focused**: 1px graphite or orange border depending on context. Use orange only when focus is part of selection.
- **Text area**: minimum height 180px for open coach intake; include character count bottom-right.
- **Chip default**: surface fill, 1px fog border, 8px radius, 14px text, optional leading icon.
- **Chip selected**: surface fill, 1px HAYF Orange border, orange checkbox or dot, ink text.
- Keep chip hit targets at least 44px high.

### Selectable Cards and Lists

- **Option card default**: surface fill, 1px fog border, 12px radius, 16px padding.
- **Option card selected**: 1px HAYF Orange border, orange radio/check marker, optional light orange tint only if needed for clarity.
- **Option card content**: icon or metric on top/left, title in ink, supporting copy in graphite.
- Use two-column grids for compact chips/cards and three-column grids only when labels are short and legible.
- **List row**: 56px minimum for compact rows, 72px to 96px for coaching rows; leading icon container, title, secondary text or metric, trailing chevron/radio/status.

### Cards, Charts, and Metrics

- **Metric card**: surface fill, 12px radius, 1px fog border, 16px padding, title small, metric large, trend or chart below.
- **Content card**: title/body plus optional image or graphic. Keep imagery quiet and object-like.
- **Permission card**: list what data is used, why it helps, and reassure user control. Keep the main permission CTA below the explanation.
- Charts use simple line charts, bar charts, progress rings, and readiness rings.
- Primary data is ink or graphite; highlight points, active segments, and current state with HAYF Orange.
- Avoid dense biohacker dashboards. Charts should support a recommendation, not become the product.

### Navigation and Icons

- Bottom navigation uses 5 items maximum: Today, Plan, Progress, Insights, Profile.
- Active item uses HAYF Orange icon detail and orange label.
- Inactive items use graphite or neutral.
- Icon set should cover home, plan, check-in, progress, insights, profile, chat, notifications, settings, workout, run, ride, strength, recovery, sleep, readiness, calendar, plus, search, filter, edit, arrows, timer, target, streak, bookmark, and share.
- Keep icon marks connected to HAYF geometry: circular targets, square anchors, connecting paths, and focus points.

### Onboarding and Permission Flow

Use one adaptive coach intake, not separate onboarding products.

1. Open coach prompt.
2. Extract or imply a draft profile.
3. Ask focused clarifying questions with buttons, chips, or option cards.
4. Allow free text for unusual context.
5. Show a coach-style readback.
6. Ask HealthKit permission after the user sees the value.
7. End with a useful output: next recommendation, starter week, or rhythm preview.

Onboarding copy should ask what is realistic, not just what the user likes. Prefer questions like `What can HAYF recommend?`, `What feels realistic most weeks?`, and `On a bad day, what still counts?`

### States

- **Loading**: orange progress ring or subtle spinner. Use calm copy like `Checking your recent signals`.
- **Success**: green check for completed permissions/actions, paired with short confirmation.
- **Empty**: dashed circle or quiet icon, neutral text, and a clear next action.
- **Error**: ink title, graphite explanation, danger only for the error marker or destructive action.

## Do's and Don'ts

- Do use warm-white, white, ink, graphite, fog, and restrained HAYF Orange as the core interface language.
- Do use black filled primary CTAs with trailing arrows.
- Do use orange for selection, progress, active icon details, and focused coaching highlights.
- Do keep layouts left-aligned, spacious, and grounded in the 4px grid.
- Do make HealthKit and recommendation screens privacy-aware, calm, and specific.
- Do make charts and metrics readable at a glance.
- Do use concise coach copy that respects real-life constraints.
- Do keep future coaching domains in mind by using language that can extend from fitness to nutrition and mind without changing the brand.
- Don't make HAYF look like a macho fitness brand, neon wellness app, hardcore endurance dashboard, or generic Apple clone.
- Don't use broad gradients, bright multicolor palettes, decorative blobs, heavy shadows, or playful rounded cards.
- Don't turn every card or icon orange. Orange should be a signal, not the canvas.
- Don't force all input through chat when buttons or cards would be faster.
- Don't overpack dashboards with raw health data. Show the minimum context needed for a better decision.
- Don't use vague motivational copy, guilt-based streak pressure, or exaggerated AI claims.
- Don't ask for sensitive permissions before explaining why they improve recommendations.
- Don't create nested cards, inconsistent icon strokes, arbitrary spacing, or mixed corner-radius styles.
