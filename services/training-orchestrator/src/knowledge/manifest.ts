import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { KnowledgeSourceRef } from "../contracts.js";

export type KnowledgeLayer = "core" | "policy" | "goal" | "modality";

export type KnowledgePack = KnowledgeSourceRef & {
  layer: KnowledgeLayer;
  scope: string;
  summary: string;
  content: string;
};

type PackDefinition = Omit<KnowledgePack, "content">;

const packRoot = join(dirname(fileURLToPath(import.meta.url)), "packs");

const PACKS: PackDefinition[] = [
  {
    id: "core.training_doctrine",
    title: "Training Doctrine",
    version: "2026-07-07",
    path: "core/training-doctrine.md",
    layer: "core",
    scope: "all",
    summary: "Shared evidence-first model for adaptation, energy systems, tools, planning, and fatigue.",
  },
  {
    id: "policy.hayf_planning",
    title: "HAYF Planning Policy",
    version: "2026-07-07",
    path: "policy/hayf-planning-policy.md",
    layer: "policy",
    scope: "all",
    summary: "Product-level planning rules for minimum viable weeks, safety limits, evidence boundaries, and planner authority.",
  },
  {
    id: "goal.consistency",
    title: "Consistency Goal Pack",
    version: "2026-07-07",
    path: "goals/consistency.md",
    layer: "goal",
    scope: "consistency",
    summary: "Goal lens for repeatable weekly rhythm and minimum effective dose.",
  },
  {
    id: "goal.body_composition",
    title: "Body Composition Goal Pack",
    version: "2026-07-07",
    path: "goals/body-composition.md",
    layer: "goal",
    scope: "body_composition",
    summary: "Goal lens for fat loss, muscle retention, and fatigue-managed training.",
  },
  {
    id: "goal.performance",
    title: "Performance Goal Pack",
    version: "2026-07-07",
    path: "goals/performance.md",
    layer: "goal",
    scope: "performance",
    summary: "Goal lens for modality-specific performance outcomes and limiter-driven planning.",
  },
  {
    id: "modality.cycling",
    title: "Cycling Modality Pack",
    version: "2026-07-07",
    path: "modalities/cycling.md",
    layer: "modality",
    scope: "cycling",
    summary: "Cycling determinants, adaptations, intensity model, archetypes, weekly structures, and mistakes.",
  },
  {
    id: "modality.strength",
    title: "Strength Modality Pack",
    version: "2026-07-07",
    path: "modalities/strength.md",
    layer: "modality",
    scope: "strength",
    summary: "Strength determinants, adaptations, intensity model, archetypes, weekly structures, and mistakes.",
  },
  {
    id: "modality.running",
    title: "Running Modality Pack",
    version: "2026-07-07",
    path: "modalities/running.md",
    layer: "modality",
    scope: "running",
    summary: "Running determinants, adaptations, intensity model, archetypes, weekly structures, and mistakes.",
  },
  {
    id: "modality.generic",
    title: "Generic Modality Fallback Pack",
    version: "2026-07-07",
    path: "modalities/generic.md",
    layer: "modality",
    scope: "generic",
    summary: "Conservative fallback for modalities without a dedicated specialist pack.",
  },
];

export function loadKnowledgeManifest(): KnowledgePack[] {
  return PACKS.map((pack) => ({
    ...pack,
    content: readFileSync(join(packRoot, pack.path), "utf8"),
  }));
}

export function sourceRefs(packs: Array<KnowledgePack | KnowledgeSourceRef>): KnowledgeSourceRef[] {
  const seen = new Set<string>();
  const refs: KnowledgeSourceRef[] = [];
  for (const pack of packs) {
    if (seen.has(pack.id)) continue;
    seen.add(pack.id);
    refs.push({
      id: pack.id,
      title: pack.title,
      version: pack.version,
      path: pack.path,
    });
  }
  return refs;
}

export function requireKnowledgePack(packs: KnowledgePack[], id: string): KnowledgePack {
  const pack = packs.find((candidate) => candidate.id === id);
  if (!pack) throw new Error(`Knowledge pack not found: ${id}`);
  return pack;
}

export function modalityPackFor(packs: KnowledgePack[], modality: string): KnowledgePack {
  return packs.find((pack) => pack.id === `modality.${modality}`) ?? requireKnowledgePack(packs, "modality.generic");
}

export function goalPacksFor(packs: KnowledgePack[], args: {
  goalKind: string;
  bodyCompositionIntent: string | null;
  goalText: string;
}): KnowledgePack[] {
  const selected: KnowledgePack[] = [];
  if (args.goalKind === "consistency") selected.push(requireKnowledgePack(packs, "goal.consistency"));
  if (args.bodyCompositionIntent || /fat|weight|lean|muscle|composition/i.test(args.goalText)) {
    selected.push(requireKnowledgePack(packs, "goal.body_composition"));
  }
  if (args.goalKind !== "consistency" || /race|performance|vo2|threshold|power|pace|climb/i.test(args.goalText)) {
    selected.push(requireKnowledgePack(packs, "goal.performance"));
  }
  return selected.length ? selected : [requireKnowledgePack(packs, "goal.consistency")];
}
