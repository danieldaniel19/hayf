type SessionModality =
  | "ride"
  | "run"
  | "swim"
  | "walk"
  | "hike"
  | "climb"
  | "strength"
  | "mobility"
  | "recovery"
  | "row"
  | "workout";

const modalityMentions: Array<{ modality: SessionModality; pattern: RegExp }> = [
  { modality: "ride", pattern: /\b(?:cycling|cycle|bike|biking|ride|rides|riding)\b/i },
  { modality: "run", pattern: /\b(?:run|runs|running|jog|jogging)\b/i },
  { modality: "swim", pattern: /\b(?:swim|swims|swimming)\b/i },
  { modality: "walk", pattern: /\b(?:walk|walks|walking)\b/i },
  { modality: "hike", pattern: /\b(?:hike|hikes|hiking)\b/i },
  { modality: "climb", pattern: /\b(?:climb|climbs|climbing|boulder|bouldering)\b/i },
  { modality: "strength", pattern: /\b(?:strength|lifting|weights?)\b/i },
  { modality: "mobility", pattern: /\b(?:mobility|yoga|stretching|pilates)\b/i },
  { modality: "recovery", pattern: /\b(?:recovery|restorative)\b/i },
  { modality: "row", pattern: /\b(?:row|rows|rowing)\b/i },
];

export function canonicalSessionModality(value: unknown): SessionModality {
  const text = String(value ?? "").trim();
  for (const entry of modalityMentions) {
    if (entry.pattern.test(text)) return entry.modality;
  }
  return "workout";
}

export function sessionSummaryContradictsActivity(activityType: unknown, summary: unknown) {
  const expected = canonicalSessionModality(activityType);
  if (expected === "workout") return false;

  // The opening clause identifies the session itself. Other modalities may still
  // appear later as useful neighboring-session context.
  const lead = String(summary ?? "").trim().split(/\s+/).slice(0, 8).join(" ");
  const firstMention = modalityMentions
    .map((entry) => ({ modality: entry.modality, index: lead.search(entry.pattern) }))
    .filter((entry) => entry.index >= 0)
    .sort((left, right) => left.index - right.index)[0];

  return Boolean(firstMention && firstMention.modality !== expected);
}

export function modalitySafeSessionSummaryFallback(activityType: unknown, intensityLabel?: unknown) {
  const easy = /easy|low|recovery|gentle|light/i.test(String(intensityLabel ?? ""));
  switch (canonicalSessionModality(activityType)) {
    case "ride":
      return `${easy ? "Easy" : "Controlled"} riding adds fitness without crowding nearby planned sessions.`;
    case "run":
      return `${easy ? "Easy" : "Controlled"} running adds fitness without crowding nearby planned sessions.`;
    case "swim":
      return `${easy ? "Easy" : "Controlled"} swimming adds fitness without crowding nearby planned sessions.`;
    case "walk":
      return "Easy walking supports recovery without crowding nearby planned sessions.";
    case "hike":
      return `${easy ? "Easy" : "Controlled"} hiking adds fitness without crowding nearby planned sessions.`;
    case "climb":
      return `${easy ? "Easy" : "Controlled"} climbing adds fitness without crowding nearby planned sessions.`;
    case "strength":
      return "Measured strength work supports progress without crowding nearby sessions.";
    case "mobility":
      return "Gentle mobility supports recovery without crowding nearby planned sessions.";
    case "recovery":
      return "Restorative work protects recovery without crowding nearby planned sessions.";
    case "row":
      return `${easy ? "Easy" : "Controlled"} rowing adds fitness without crowding nearby planned sessions.`;
    default:
      return "This session supports progress without crowding nearby planned work.";
  }
}
