import { Annotation, END, START, StateGraph } from "@langchain/langgraph";
import {
  assertPlanningPacket,
  type GraphResult,
  type GraphTraceNode,
  type GraphToolCall,
  type KnowledgeSourceRef,
  type ModalityRole,
  normalizeModality,
  type PlanningPacket,
  type SpecialistConsultation,
  type SpecialistRecommendation,
  type TrainingArchitecture,
  type TrainingArchitectFrame,
  type WorkoutArchetypeRecommendation,
} from "../contracts.js";
import {
  goalPacksFor,
  type KnowledgePack,
  loadKnowledgeManifest,
  modalityPackFor,
  requireKnowledgePack,
  sourceRefs,
} from "../knowledge/manifest.js";
import { runStructuredJSON } from "../ai/openai.js";

type TrainingArchitectureState = {
  packet: PlanningPacket;
  knowledge_manifest?: KnowledgePack[];
  frame?: TrainingArchitectFrame;
  consultations?: SpecialistConsultation[];
  artifact?: TrainingArchitecture;
  nodes: GraphTraceNode[];
  tool_calls: GraphToolCall[];
};

type RejectedRecommendation = TrainingArchitecture["rejected_specialist_recommendations"][number];

type ArchitectSynthesisDecision = {
  priority_order: string[];
  modality_roles: Array<{
    modality: string;
    role: ModalityRole;
    rationale: string;
  }>;
  weekly_budget: {
    target_sessions: number;
    minimum_viable_sessions: number;
    hard_sessions: number;
  };
  recovery_envelope: {
    spacing_rules: string[];
    bad_day_floor: string | null;
  };
  approved_archetype_ids: string[];
  rejected_recommendations: Array<{
    modality: string;
    archetype_id: string | null;
    reason: string;
  }>;
  phase_logic: {
    requires_phases: boolean;
    phases: Array<{
      id: string;
      name: string;
      objective: string;
    }>;
  };
  progression_rules: string[];
  interference_rules: string[];
  conflict_assessment: {
    status: "clear" | "manageable_tradeoff" | "conflicting";
    summary: string;
    required_tradeoffs: string[];
  };
  conflict_decisions: Array<{
    id: string;
    decision: string;
    rationale: string;
  }>;
  minimum_effective_dose_rules: string[];
  planner_constraints: {
    weekly_plan_rules: string[];
    workout_generation_rules: string[];
    target_generation_rules: string[];
  };
};

const State = Annotation.Root({
  packet: Annotation<PlanningPacket>(),
  knowledge_manifest: Annotation<KnowledgePack[]>(),
  frame: Annotation<TrainingArchitectFrame>(),
  consultations: Annotation<SpecialistConsultation[]>({
    reducer: (_, value) => value ?? [],
    default: () => [],
  }),
  artifact: Annotation<TrainingArchitecture>(),
  nodes: Annotation<GraphTraceNode[]>({
    reducer: (left, right) => [...left, ...right],
    default: () => [],
  }),
  tool_calls: Annotation<GraphToolCall[]>({
    reducer: (left, right) => [...left, ...right],
    default: () => [],
  }),
});

function trace(node_name: string, output: Record<string, unknown>, validation: Record<string, unknown> = { valid: true }): GraphTraceNode[] {
  return [{
    node_name,
    input_summary: {},
    output,
    validation,
    status: "succeeded",
  }];
}

function validatePacket(state: TrainingArchitectureState) {
  assertPlanningPacket(state.packet);
  return {
    nodes: trace("validate_packet", {
      blueprint_revision_id: state.packet.athlete_context.blueprint_revision_id,
      goal_kind: state.packet.goal_context.goal_kind,
      selected_modality_count: state.packet.goal_context.selected_modality_order.length,
    }),
  };
}

function loadKnowledgeManifestNode() {
  const knowledge_manifest = loadKnowledgeManifest();
  return {
    knowledge_manifest,
    nodes: trace("load_knowledge_manifest", {
      pack_count: knowledge_manifest.length,
      pack_ids: knowledge_manifest.map((pack) => pack.id),
    }),
  };
}

function architectFrame(state: TrainingArchitectureState) {
  const packet = state.packet;
  const packs = requireManifest(state);
  const selected = normalizeUnique(packet.goal_context.selected_modality_order);
  const feasible = normalizeUnique(packet.planning_constraints.feasible_modalities);
  const selectedModalities = selected.length ? selected : feasible.length ? feasible : ["general"];
  const goalPacks = goalPacksFor(packs, {
    goalKind: packet.goal_context.goal_kind,
    bodyCompositionIntent: packet.goal_context.body_composition_intent,
    goalText: goalText(packet),
  });
  const corePack = requireKnowledgePack(packs, "core.training_doctrine");
  const policyPack = requireKnowledgePack(packs, "policy.hayf_planning");
  const modalityPacks = selectedModalities.map((modality) => modalityPackFor(packs, modality));
  const targetSessions = Math.max(1, Math.min(6, parseFrequency(packet.planning_constraints.frequency)));
  const minimumSessions = Math.max(1, Math.min(targetSessions, targetSessions - 1));
  const maximumSessions = Math.max(targetSessions, Math.min(6, targetSessions + 1));
  const hardDayCap = Math.max(1, Math.min(2, Math.floor(targetSessions / 3) || 1));
  const priorityHypotheses = selectedModalities;
  const knowledgeRefs = sourceRefs([corePack, policyPack, ...goalPacks, ...modalityPacks]);
  const conflictQuestions = conflictSignals(packet).map((signal) => conflictQuestionFor(signal));
  const recoveryRisks = recoveryRisksFor(packet, selectedModalities);
  const specialistBriefs = selectedModalities.map((modality, index) => {
    const modalityPack = modalityPackFor(packs, modality);
    const requestedRole = roleHypothesis(modality, index, packet);
    return {
      modality,
      pack_id: modalityPack.id,
      requested_role: requestedRole,
      brief: [
        `${titleCase(modality)} is selected for the athlete's plan.`,
        `Requested role hypothesis: ${requestedRole}.`,
        `Training budget hypothesis: ${targetSessions} sessions per week with ${hardDayCap} hard day(s).`,
        packet.approved_evidence_summary.confidence === "missing"
          ? "Evidence confidence is missing, so recommendations must be conservative."
          : `Evidence confidence is ${packet.approved_evidence_summary.confidence}.`,
      ].join(" "),
      questions: [
        "Which adaptations matter most for this modality in the stated goal?",
        "Which workout archetypes are useful without creating dated workouts?",
        "What fatigue, interference, and common mistake warnings should the Architect consider?",
      ],
      knowledge_refs: sourceRefs([corePack, policyPack, ...goalPacks, modalityPack]),
    };
  });
  const frame: TrainingArchitectFrame = {
    goal_read: {
      summary: goalSummary(packet),
      priority_basis: [
        "Use the selected modality order as the first priority signal.",
        "Protect adherence and recovery before optional volume.",
        "Promote body-composition or performance-specific work only when the evidence and budget support it.",
      ],
      conflict_questions: conflictQuestions,
    },
    selected_modalities: selectedModalities,
    feasible_modalities: feasible,
    priority_hypotheses: priorityHypotheses,
    weekly_budget_range: {
      minimum_sessions: minimumSessions,
      target_sessions: targetSessions,
      maximum_sessions: maximumSessions,
      hard_day_cap: hardDayCap,
    },
    recovery_risks: recoveryRisks,
    specialist_briefs: specialistBriefs,
    knowledge_refs: knowledgeRefs,
  };

  return {
    frame,
    nodes: trace("architect_frame", {
      selected_modalities: frame.selected_modalities,
      priority_hypotheses: frame.priority_hypotheses,
      specialist_brief_count: frame.specialist_briefs.length,
      knowledge_refs: frame.knowledge_refs.map((ref) => ref.id),
    }),
  };
}

async function specialistConsultations(state: TrainingArchitectureState) {
  const packs = requireManifest(state);
  const frame = requireFrame(state);
  const results = await Promise.all(frame.specialist_briefs.map(async (brief, index) => {
    return consultSpecialist(brief, index, state.packet, packs, frame);
  }));
  const consultations = results.map((result) => result.consultation);
  return {
    consultations,
    nodes: trace("specialist_consultations", {
      specialist_count: consultations.length,
      modalities: consultations.map((consultation) => consultation.modality),
      generic_fallbacks: consultations
        .filter((consultation) => consultation.knowledge_refs.some((ref) => ref.id === "modality.generic"))
        .map((consultation) => consultation.modality),
    }),
    tool_calls: results.map((result) => result.toolCall),
  };
}

async function architectSynthesis(state: TrainingArchitectureState) {
  const packet = state.packet;
  const frame = requireFrame(state);
  const consultations = state.consultations ?? [];
  const synthesis = await synthesizeArchitecture(frame, consultations, packet);
  const filterResult = filterApprovedArchetypes(frame, consultations, packet, synthesis.decision);
  const conflictSignalsForPacket = conflictSignals(packet);
  const conflictDecisionRefs = sourceRefs([
    ...frame.knowledge_refs,
    ...consultations.flatMap((consultation) => consultation.knowledge_refs),
  ]);
  const roleByModality = new Map(synthesis.decision.modality_roles.map((role) => [normalizeModality(role.modality), role]));
  const priorityOrder = normalizeUnique(synthesis.decision.priority_order)
    .filter((modality) => frame.selected_modalities.includes(modality));
  const finalPriorityOrder = priorityOrder.length ? priorityOrder : frame.priority_hypotheses;
  const targetSessions = clampInteger(
    synthesis.decision.weekly_budget.target_sessions,
    frame.weekly_budget_range.minimum_sessions,
    frame.weekly_budget_range.maximum_sessions,
  );
  const minimumSessions = clampInteger(
    synthesis.decision.weekly_budget.minimum_viable_sessions,
    1,
    targetSessions,
  );
  const hardSessions = clampInteger(
    synthesis.decision.weekly_budget.hard_sessions,
    0,
    frame.weekly_budget_range.hard_day_cap,
  );
  const artifact: TrainingArchitecture = {
    source_ids: {
      blueprint_revision_id: packet.athlete_context.blueprint_revision_id,
      user_goal_id: packet.goal_context.user_goal_id,
    },
    goal_read: {
      summary: frame.goal_read.summary,
      goal_kind: packet.goal_context.goal_kind,
      success_definition: packet.goal_context.success_definition,
    },
    modality_roles: frame.selected_modalities.map((modality) => {
      const roleDecision = roleByModality.get(modality);
      const consultation = consultations.find((candidate) => candidate.modality === modality);
      return {
        modality,
        role: roleDecision?.role ?? consultation?.recommended_role ?? roleHypothesis(modality, frame.selected_modalities.indexOf(modality), packet),
        rationale: roleDecision?.rationale || consultation?.rationale || `${titleCase(modality)} remains assigned by the Training Architect.`,
        knowledge_refs: consultation?.knowledge_refs ?? frame.knowledge_refs,
      };
    }),
    priority_order: finalPriorityOrder,
    weekly_budget: {
      target_sessions: targetSessions,
      minimum_viable_sessions: minimumSessions,
      hard_sessions: hardSessions,
      recovery_sessions: Math.max(1, targetSessions - hardSessions),
    },
    recovery_envelope: {
      max_hard_days_per_week: hardSessions,
      spacing_rules: nonEmptyStrings(synthesis.decision.recovery_envelope.spacing_rules, [
        "Separate hard endurance and hard lower-body strength by at least one easier day when possible.",
        "If recovery evidence is missing or worsening, use the minimum viable week before adding intensity.",
      ]),
      bad_day_floor: synthesis.decision.recovery_envelope.bad_day_floor ?? packet.planning_constraints.bad_day_floor,
    },
    minimum_effective_dose_rules: nonEmptyStrings(synthesis.decision.minimum_effective_dose_rules, [
      "Protect the minimum viable week before adding optional work.",
      "Keep every selected modality assigned to a role, even when the role is optional or maintenance.",
      "Use conservative dose when approved evidence is missing.",
    ]),
    specialist_recommendations: consultations.map(compatRecommendationFor),
    architect_frame_summary: frame,
    specialist_consultations: consultations,
    approved_archetypes: filterResult.approved,
    rejected_specialist_recommendations: filterResult.rejected,
    phase_logic: normalizePhaseLogic(synthesis.decision.phase_logic, packet),
    progression_rules: nonEmptyStrings(synthesis.decision.progression_rules, [
      "Progress only when the committed week is mostly completed and recovery caveats are not worsening.",
      "Prefer a small dose increase over adding a new modality when adherence is uncertain.",
      "Escalate intensity only through approved archetypes.",
    ]),
    interference_rules: uniqueStrings(nonEmptyStrings(
      synthesis.decision.interference_rules,
      consultations.flatMap((consultation) => consultation.interference_rules),
    )),
    conflict_assessment: {
      status: conflictSignalsForPacket.length ? "conflicting" : synthesis.decision.conflict_assessment.status,
      summary: synthesis.decision.conflict_assessment.summary || conflictSummary(synthesis.decision.conflict_assessment.status),
      required_tradeoffs: conflictSignalsForPacket.length
        ? conflictSignalsForPacket
        : nonEmptyStrings(synthesis.decision.conflict_assessment.required_tradeoffs, ["Recovery and adherence take precedence over optional volume."]),
    },
    conflict_decisions: normalizeConflictDecisions(synthesis.decision.conflict_decisions, conflictDecisionRefs, [
      {
        id: "final_priority_order",
        decision: `Use ${finalPriorityOrder.map(titleCase).join(" > ")} as the final priority order.`,
        rationale: "The selected modality order is the strongest user-authored priority signal.",
      },
      {
        id: "specialist_filtering",
        decision: "Only approved archetypes reach the planner compiler.",
        rationale: "Specialists provide recommendations, but the Training Architect owns coherence and filters fatigue or interference conflicts.",
      },
      ...conflictSignalsForPacket.map((signal) => ({
        id: signal,
        decision: "Require explicit tradeoff handling before progression.",
        rationale: conflictQuestionFor(signal),
      })),
    ]),
    planner_constraints: {
      weekly_plan_rules: nonEmptyStrings(synthesis.decision.planner_constraints.weekly_plan_rules, [
        "Week 1 is committed; week 2 is draft and must preserve user-authored constraints.",
        "Use the final priority order and role assignments from the Training Architecture.",
      ]),
      workout_generation_rules: nonEmptyStrings(synthesis.decision.planner_constraints.workout_generation_rules, [
        "Do not introduce off-menu modalities.",
        "Do not reopen goal priority, modality role, or tradeoff decisions.",
      ]),
      target_generation_rules: nonEmptyStrings(synthesis.decision.planner_constraints.target_generation_rules, [
        "Targets must be measurable from actual completion, body entries, performance observations, or approved plan structure.",
        "Do not mark completion-based targets done from planned workouts alone.",
      ]),
    },
    source_knowledge_refs: sourceRefs([
      ...frame.knowledge_refs,
      ...consultations.flatMap((consultation) => consultation.knowledge_refs),
      ...filterResult.approved.flatMap((archetype) => archetype.knowledge_refs),
    ]),
  };

  return {
    artifact,
    nodes: trace("architect_synthesis", {
      priority_order: artifact.priority_order,
      role_count: artifact.modality_roles.length,
      approved_archetype_count: artifact.approved_archetypes.length,
      rejected_recommendation_count: artifact.rejected_specialist_recommendations.length,
      conflict_status: artifact.conflict_assessment.status,
    }),
    tool_calls: [synthesis.toolCall],
  };
}

function deterministicValidation(state: TrainingArchitectureState) {
  const artifact = state.artifact;
  if (!artifact?.priority_order.length) {
    throw new Error("Training Architecture requires one final priority order.");
  }
  const selected = new Set(artifact.architect_frame_summary.selected_modalities);
  const roleModalities = new Set(artifact.modality_roles.map((role) => role.modality));
  for (const modality of selected) {
    if (!roleModalities.has(modality)) {
      throw new Error(`Training Architecture requires a final role for ${modality}.`);
    }
  }
  for (const role of artifact.modality_roles) {
    if (!role.knowledge_refs.length) {
      throw new Error(`Modality role for ${role.modality} requires source knowledge refs.`);
    }
  }
  for (const archetype of artifact.approved_archetypes) {
    if (!selected.has(archetype.modality)) {
      throw new Error(`Planner archetype ${archetype.id} uses off-menu modality ${archetype.modality}.`);
    }
    if (!archetype.knowledge_refs.length) {
      throw new Error(`Planner archetype ${archetype.id} requires source knowledge refs.`);
    }
    if (hasDatedWorkoutKeys(archetype)) {
      throw new Error(`Specialist archetype ${archetype.id} must not include dated workout fields.`);
    }
  }
  for (const decision of artifact.conflict_decisions) {
    if (!decision.knowledge_refs.length) {
      throw new Error(`Conflict decision ${decision.id} requires source knowledge refs.`);
    }
  }
  return {
    nodes: trace("deterministic_validation", {
      valid: true,
      selected_modality_count: selected.size,
      approved_archetype_count: artifact.approved_archetypes.length,
    }),
  };
}

type ArchitectureReasoningOutput = {
  reasoning: string;
  finalChecks: string[];
  riskFlags: string[];
};

async function architectureReasoningTrace(state: TrainingArchitectureState) {
  if (!state.artifact) throw new Error("Training Architecture reasoning requires a validated artifact.");
  const result = await runStructuredJSON<ArchitectureReasoningOutput>({
    toolName: "author_training_architecture_reasoning",
    system: [
      "You are HAYF's Training Architect reviewer.",
      "Review the already validated Training Architecture and write a concise reasoning trace.",
      "Do not change the architecture. Do not invent raw evidence. Explain why the priority order, weekly budget, archetype filtering, and recovery constraints are coherent.",
    ].join(" "),
    input: {
      goal_context: state.packet.goal_context,
      approved_evidence_summary: state.packet.approved_evidence_summary,
      architecture: state.artifact,
    },
    inputSummary: {
      goalKind: state.packet.goal_context.goal_kind,
      priorityOrder: state.artifact.priority_order,
      weeklyBudget: state.artifact.weekly_budget,
      approvedArchetypeCount: state.artifact.approved_archetypes.length,
      conflictStatus: state.artifact.conflict_assessment.status,
    },
    schema: architectureReasoningSchema,
    testOutput: () => ({
      reasoning: "The validated architecture keeps the selected priority first, bounds support work, and caps hard days inside the recovery envelope.",
      finalChecks: [
        "Priority order is present.",
        "Approved archetypes are undated.",
        "Hard-day cap is present.",
      ],
      riskFlags: state.artifact?.conflict_assessment.required_tradeoffs ?? [],
    }),
  });

  return {
    nodes: trace("author_training_architecture_reasoning", {
      reasoning: result.data.reasoning,
      finalChecks: result.data.finalChecks,
      riskFlags: result.data.riskFlags,
    }),
    tool_calls: [result.toolCall],
  };
}

export const trainingArchitectureGraph = new StateGraph(State)
  .addNode("validate_packet", validatePacket)
  .addNode("load_knowledge_manifest", loadKnowledgeManifestNode)
  .addNode("architect_frame", architectFrame)
  .addNode("specialist_consultations", specialistConsultations)
  .addNode("architect_synthesis", architectSynthesis)
  .addNode("deterministic_validation", deterministicValidation)
  .addNode("author_training_architecture_reasoning", architectureReasoningTrace)
  .addEdge(START, "validate_packet")
  .addEdge("validate_packet", "load_knowledge_manifest")
  .addEdge("load_knowledge_manifest", "architect_frame")
  .addEdge("architect_frame", "specialist_consultations")
  .addEdge("specialist_consultations", "architect_synthesis")
  .addEdge("architect_synthesis", "deterministic_validation")
  .addEdge("deterministic_validation", "author_training_architecture_reasoning")
  .addEdge("author_training_architecture_reasoning", END)
  .compile();

export async function invokeTrainingArchitectureGraph(packet: PlanningPacket): Promise<GraphResult<TrainingArchitecture>> {
  const state = await trainingArchitectureGraph.invoke({ packet });
  if (!state.artifact) {
    throw new Error("Training Architecture graph completed without an artifact.");
  }
  return {
    artifact: state.artifact,
    nodes: state.nodes,
    tool_calls: state.tool_calls,
  };
}

const architectureReasoningSchema = {
  type: "object",
  additionalProperties: false,
  required: ["reasoning", "finalChecks", "riskFlags"],
  properties: {
    reasoning: { type: "string" },
    finalChecks: { type: "array", items: { type: "string" } },
    riskFlags: { type: "array", items: { type: "string" } },
  },
};

const modalityRoleEnum: ModalityRole[] = [
  "primary_driver",
  "secondary_support",
  "maintenance_exposure",
  "optional_filler",
  "currently_inappropriate",
];

const sourceRefSchema = {
  type: "object",
  additionalProperties: false,
  required: ["id", "title", "version", "path"],
  properties: {
    id: { type: "string" },
    title: { type: "string" },
    version: { type: "string" },
    path: { type: "string" },
  },
};

const archetypeSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "id",
    "modality",
    "purpose",
    "target_adaptation",
    "intensity_domain",
    "typical_duration_minutes",
    "dose_range",
    "progression_rule",
    "fatigue_cost",
    "prerequisites",
    "incompatibilities",
    "planner_constraints",
    "knowledge_refs",
  ],
  properties: {
    id: { type: "string" },
    modality: { type: "string" },
    purpose: { type: "string" },
    target_adaptation: { type: "string" },
    intensity_domain: { type: "string" },
    typical_duration_minutes: {
      type: "object",
      additionalProperties: false,
      required: ["min", "max"],
      properties: {
        min: { type: "number" },
        max: { type: "number" },
      },
    },
    dose_range: { type: "string" },
    progression_rule: { type: "string" },
    fatigue_cost: { type: "string", enum: ["low", "moderate", "high"] },
    prerequisites: { type: "array", items: { type: "string" } },
    incompatibilities: { type: "array", items: { type: "string" } },
    planner_constraints: { type: "array", items: { type: "string" } },
    knowledge_refs: { type: "array", items: sourceRefSchema },
  },
};

const specialistConsultationSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "coach",
    "modality",
    "recommended_role",
    "rationale",
    "performance_determinants",
    "adaptation_priorities",
    "intensity_model",
    "weekly_dose",
    "archetype_proposals",
    "fatigue_signals",
    "interference_rules",
    "common_mistakes",
    "tool_requests",
    "knowledge_refs",
  ],
  properties: {
    coach: { type: "string" },
    modality: { type: "string" },
    recommended_role: { type: "string", enum: modalityRoleEnum },
    rationale: { type: "string" },
    performance_determinants: { type: "array", items: { type: "string" } },
    adaptation_priorities: { type: "array", items: { type: "string" } },
    intensity_model: { type: "string" },
    weekly_dose: {
      type: "object",
      additionalProperties: false,
      required: ["minimum", "target", "maximum", "hard_cap"],
      properties: {
        minimum: { type: "string" },
        target: { type: "string" },
        maximum: { type: "string" },
        hard_cap: { type: "string" },
      },
    },
    archetype_proposals: { type: "array", minItems: 1, items: archetypeSchema },
    fatigue_signals: { type: "array", items: { type: "string" } },
    interference_rules: { type: "array", items: { type: "string" } },
    common_mistakes: { type: "array", items: { type: "string" } },
    tool_requests: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["tool_name", "purpose", "input", "optional"],
        properties: {
          tool_name: { type: "string" },
          purpose: { type: "string" },
          input: {
            type: "object",
            additionalProperties: false,
            required: ["modality", "horizon_days"],
            properties: {
              modality: { type: "string" },
              horizon_days: { type: ["number", "null"] },
            },
          },
          optional: { type: "boolean" },
        },
      },
    },
    knowledge_refs: { type: "array", items: sourceRefSchema },
  },
};

const architectSynthesisDecisionSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "priority_order",
    "modality_roles",
    "weekly_budget",
    "recovery_envelope",
    "approved_archetype_ids",
    "rejected_recommendations",
    "phase_logic",
    "progression_rules",
    "interference_rules",
    "conflict_assessment",
    "conflict_decisions",
    "minimum_effective_dose_rules",
    "planner_constraints",
  ],
  properties: {
    priority_order: { type: "array", minItems: 1, items: { type: "string" } },
    modality_roles: {
      type: "array",
      minItems: 1,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["modality", "role", "rationale"],
        properties: {
          modality: { type: "string" },
          role: { type: "string", enum: modalityRoleEnum },
          rationale: { type: "string" },
        },
      },
    },
    weekly_budget: {
      type: "object",
      additionalProperties: false,
      required: ["target_sessions", "minimum_viable_sessions", "hard_sessions"],
      properties: {
        target_sessions: { type: "number" },
        minimum_viable_sessions: { type: "number" },
        hard_sessions: { type: "number" },
      },
    },
    recovery_envelope: {
      type: "object",
      additionalProperties: false,
      required: ["spacing_rules", "bad_day_floor"],
      properties: {
        spacing_rules: { type: "array", items: { type: "string" } },
        bad_day_floor: { type: ["string", "null"] },
      },
    },
    approved_archetype_ids: { type: "array", items: { type: "string" } },
    rejected_recommendations: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["modality", "archetype_id", "reason"],
        properties: {
          modality: { type: "string" },
          archetype_id: { type: ["string", "null"] },
          reason: { type: "string" },
        },
      },
    },
    phase_logic: {
      type: "object",
      additionalProperties: false,
      required: ["requires_phases", "phases"],
      properties: {
        requires_phases: { type: "boolean" },
        phases: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: ["id", "name", "objective"],
            properties: {
              id: { type: "string" },
              name: { type: "string" },
              objective: { type: "string" },
            },
          },
        },
      },
    },
    progression_rules: { type: "array", items: { type: "string" } },
    interference_rules: { type: "array", items: { type: "string" } },
    conflict_assessment: {
      type: "object",
      additionalProperties: false,
      required: ["status", "summary", "required_tradeoffs"],
      properties: {
        status: { type: "string", enum: ["clear", "manageable_tradeoff", "conflicting"] },
        summary: { type: "string" },
        required_tradeoffs: { type: "array", items: { type: "string" } },
      },
    },
    conflict_decisions: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["id", "decision", "rationale"],
        properties: {
          id: { type: "string" },
          decision: { type: "string" },
          rationale: { type: "string" },
        },
      },
    },
    minimum_effective_dose_rules: { type: "array", items: { type: "string" } },
    planner_constraints: {
      type: "object",
      additionalProperties: false,
      required: ["weekly_plan_rules", "workout_generation_rules", "target_generation_rules"],
      properties: {
        weekly_plan_rules: { type: "array", items: { type: "string" } },
        workout_generation_rules: { type: "array", items: { type: "string" } },
        target_generation_rules: { type: "array", items: { type: "string" } },
      },
    },
  },
};

async function consultSpecialist(
  brief: TrainingArchitectFrame["specialist_briefs"][number],
  index: number,
  packet: PlanningPacket,
  packs: KnowledgePack[],
  frame: TrainingArchitectFrame,
): Promise<{ consultation: SpecialistConsultation; toolCall: GraphToolCall }> {
  const fallback = consultationFor(brief, index, packet, packs);
  const corePack = requireKnowledgePack(packs, "core.training_doctrine");
  const policyPack = requireKnowledgePack(packs, "policy.hayf_planning");
  const modalityPack = modalityPackFor(packs, brief.modality);
  const goalPacks = goalPacksFor(packs, {
    goalKind: packet.goal_context.goal_kind,
    bodyCompositionIntent: packet.goal_context.body_composition_intent,
    goalText: goalText(packet),
  });
  const refs = sourceRefs([corePack, policyPack, ...goalPacks, modalityPack]);
  const supported = modalityPack.id !== "modality.generic";
  const toolName = supported ? `consult_${brief.modality}_specialist` : `consult_${brief.modality}_generic_specialist`;
  const result = await runStructuredJSON<SpecialistConsultation>({
    toolName,
    system: [
      `You are HAYF's ${titleCase(brief.modality)} specialist coach.`,
      "Use the provided knowledge packs as bounded source material and the athlete packet as the athlete-specific context.",
      "Return an athlete-specific specialist recommendation for the Training Architect.",
      "Do not create dated workouts, weekly plans, or calendar placements.",
      "Do not invent raw evidence. Use only the approved evidence summary.",
      "Keep recommendations conservative when evidence confidence is missing or constraints are unclear.",
      "Every archetype proposal must be reusable by a planner compiler and must include knowledge refs.",
    ].join(" "),
    input: {
      specialist_brief: brief,
      athlete_context: packet.athlete_context,
      goal_context: packet.goal_context,
      planning_constraints: packet.planning_constraints,
      approved_evidence_summary: packet.approved_evidence_summary,
      architect_frame: {
        selected_modalities: frame.selected_modalities,
        weekly_budget_range: frame.weekly_budget_range,
        recovery_risks: frame.recovery_risks,
        priority_hypotheses: frame.priority_hypotheses,
      },
      knowledge_packs: [corePack, policyPack, ...goalPacks, modalityPack].map(packForPrompt),
      output_requirements: {
        modality: brief.modality,
        requested_role: brief.requested_role,
        allowed_roles: modalityRoleEnum,
        no_dated_workouts: true,
        knowledge_refs: refs,
      },
    },
    inputSummary: {
      modality: brief.modality,
      requestedRole: brief.requested_role,
      supportedPack: supported,
      goalKind: packet.goal_context.goal_kind,
      evidenceConfidence: packet.approved_evidence_summary.confidence,
      knowledgeRefs: refs.map((ref) => ref.id),
    },
    schema: specialistConsultationSchema,
    testOutput: () => fallback,
  });

  return {
    consultation: normalizeSpecialistConsultation(result.data, fallback, brief, refs),
    toolCall: result.toolCall,
  };
}

async function synthesizeArchitecture(
  frame: TrainingArchitectFrame,
  consultations: SpecialistConsultation[],
  packet: PlanningPacket,
): Promise<{ decision: ArchitectSynthesisDecision; toolCall: GraphToolCall }> {
  const fallback = deterministicSynthesisDecision(frame, consultations, packet);
  const result = await runStructuredJSON<ArchitectSynthesisDecision>({
    toolName: "synthesize_training_architecture",
    system: [
      "You are HAYF's master Training Architect.",
      "Consolidate independent specialist coach recommendations into one coherent Training Architecture decision.",
      "You own final priority order, role assignments, weekly budget, archetype approval, recovery rules, progression rules, and conflict decisions.",
      "Use HAYF policy and the athlete's approved evidence. Do not create dated workouts.",
      "Prefer a smaller coherent plan over satisfying every specialist request.",
      "Only approve archetype ids proposed by specialists.",
    ].join(" "),
    input: {
      athlete_context: packet.athlete_context,
      goal_context: packet.goal_context,
      planning_constraints: packet.planning_constraints,
      approved_evidence_summary: packet.approved_evidence_summary,
      architect_frame: frame,
      specialist_consultations: consultations,
      available_archetype_ids: consultations.flatMap((consultation) => (
        consultation.archetype_proposals.map((archetype) => archetype.id)
      )),
      output_requirements: {
        selected_modalities: frame.selected_modalities,
        weekly_budget_range: frame.weekly_budget_range,
        no_dated_workouts: true,
      },
    },
    inputSummary: {
      selectedModalities: frame.selected_modalities,
      specialistCount: consultations.length,
      proposedArchetypeCount: consultations.reduce((count, consultation) => count + consultation.archetype_proposals.length, 0),
      weeklyBudgetRange: frame.weekly_budget_range,
      goalKind: packet.goal_context.goal_kind,
    },
    schema: architectSynthesisDecisionSchema,
    testOutput: () => fallback,
  });

  return {
    decision: normalizeSynthesisDecision(result.data, fallback, frame, consultations, packet),
    toolCall: result.toolCall,
  };
}

function normalizeSpecialistConsultation(
  consultation: SpecialistConsultation,
  fallback: SpecialistConsultation,
  brief: TrainingArchitectFrame["specialist_briefs"][number],
  refs: KnowledgeSourceRef[],
): SpecialistConsultation {
  const modality = brief.modality;
  const role = modalityRoleEnum.includes(consultation.recommended_role)
    ? consultation.recommended_role
    : fallback.recommended_role;
  const archetypes = Array.isArray(consultation.archetype_proposals) && consultation.archetype_proposals.length
    ? consultation.archetype_proposals
    : fallback.archetype_proposals;

  return {
    coach: consultation.coach || fallback.coach,
    modality,
    recommended_role: role,
    rationale: nonEmptyString(consultation.rationale, fallback.rationale),
    performance_determinants: nonEmptyStrings(consultation.performance_determinants, fallback.performance_determinants),
    adaptation_priorities: nonEmptyStrings(consultation.adaptation_priorities, fallback.adaptation_priorities),
    intensity_model: nonEmptyString(consultation.intensity_model, fallback.intensity_model),
    weekly_dose: {
      minimum: nonEmptyString(consultation.weekly_dose?.minimum, fallback.weekly_dose.minimum),
      target: nonEmptyString(consultation.weekly_dose?.target, fallback.weekly_dose.target),
      maximum: nonEmptyString(consultation.weekly_dose?.maximum, fallback.weekly_dose.maximum),
      hard_cap: nonEmptyString(consultation.weekly_dose?.hard_cap, fallback.weekly_dose.hard_cap),
    },
    archetype_proposals: archetypes.map((archetype, index) => normalizeArchetype(archetype, fallback.archetype_proposals[index], modality, refs)),
    fatigue_signals: nonEmptyStrings(consultation.fatigue_signals, fallback.fatigue_signals),
    interference_rules: nonEmptyStrings(consultation.interference_rules, fallback.interference_rules),
    common_mistakes: nonEmptyStrings(consultation.common_mistakes, fallback.common_mistakes),
    tool_requests: Array.isArray(consultation.tool_requests) && consultation.tool_requests.length
      ? consultation.tool_requests
      : fallback.tool_requests,
    knowledge_refs: refs,
  };
}

function normalizeArchetype(
  archetype: WorkoutArchetypeRecommendation,
  fallback: WorkoutArchetypeRecommendation | undefined,
  modality: string,
  refs: KnowledgeSourceRef[],
): WorkoutArchetypeRecommendation {
  const fallbackID = fallback?.id ?? `${modality}_ai_archetype`;
  const fatigueCost = ["low", "moderate", "high"].includes(archetype.fatigue_cost)
    ? archetype.fatigue_cost
    : fallback?.fatigue_cost ?? "moderate";
  const min = Math.max(5, Number(archetype.typical_duration_minutes?.min ?? fallback?.typical_duration_minutes.min ?? 20));
  const max = Math.max(min, Number(archetype.typical_duration_minutes?.max ?? fallback?.typical_duration_minutes.max ?? min + 20));
  return {
    id: normalizeArchetypeID(archetype.id || fallbackID, modality),
    modality,
    purpose: nonEmptyString(archetype.purpose, fallback?.purpose ?? `Train ${modality} without crowding recovery.`),
    target_adaptation: nonEmptyString(archetype.target_adaptation, fallback?.target_adaptation ?? "repeatable adaptation"),
    intensity_domain: nonEmptyString(archetype.intensity_domain, fallback?.intensity_domain ?? "controlled"),
    typical_duration_minutes: { min, max },
    dose_range: nonEmptyString(archetype.dose_range, fallback?.dose_range ?? "0 to 1 exposure weekly"),
    progression_rule: nonEmptyString(archetype.progression_rule, fallback?.progression_rule ?? "Progress only after adherence and recovery are stable."),
    fatigue_cost: fatigueCost as WorkoutArchetypeRecommendation["fatigue_cost"],
    prerequisites: nonEmptyStrings(archetype.prerequisites, fallback?.prerequisites ?? []),
    incompatibilities: nonEmptyStrings(archetype.incompatibilities, fallback?.incompatibilities ?? []),
    planner_constraints: nonEmptyStrings(archetype.planner_constraints, fallback?.planner_constraints ?? []),
    knowledge_refs: refs,
  };
}

function normalizeSynthesisDecision(
  decision: ArchitectSynthesisDecision,
  fallback: ArchitectSynthesisDecision,
  frame: TrainingArchitectFrame,
  consultations: SpecialistConsultation[],
  packet: PlanningPacket,
): ArchitectSynthesisDecision {
  const availableArchetypeIDs = new Set(consultations.flatMap((consultation) => (
    consultation.archetype_proposals.map((archetype) => archetype.id)
  )));
  const approved = nonEmptyStrings(decision.approved_archetype_ids, fallback.approved_archetype_ids)
    .filter((id) => availableArchetypeIDs.has(id));
  return {
    priority_order: nonEmptyStrings(normalizeUnique(decision.priority_order), fallback.priority_order)
      .filter((modality) => frame.selected_modalities.includes(modality)),
    modality_roles: normalizeRoleDecisions(decision.modality_roles, fallback.modality_roles, frame, consultations, packet),
    weekly_budget: {
      target_sessions: Number(decision.weekly_budget?.target_sessions ?? fallback.weekly_budget.target_sessions),
      minimum_viable_sessions: Number(decision.weekly_budget?.minimum_viable_sessions ?? fallback.weekly_budget.minimum_viable_sessions),
      hard_sessions: Number(decision.weekly_budget?.hard_sessions ?? fallback.weekly_budget.hard_sessions),
    },
    recovery_envelope: {
      spacing_rules: nonEmptyStrings(decision.recovery_envelope?.spacing_rules, fallback.recovery_envelope.spacing_rules),
      bad_day_floor: decision.recovery_envelope?.bad_day_floor ?? fallback.recovery_envelope.bad_day_floor,
    },
    approved_archetype_ids: approved.length ? approved : fallback.approved_archetype_ids,
    rejected_recommendations: Array.isArray(decision.rejected_recommendations)
      ? decision.rejected_recommendations
      : fallback.rejected_recommendations,
    phase_logic: normalizePhaseLogic(decision.phase_logic ?? fallback.phase_logic, packet),
    progression_rules: nonEmptyStrings(decision.progression_rules, fallback.progression_rules),
    interference_rules: nonEmptyStrings(decision.interference_rules, fallback.interference_rules),
    conflict_assessment: {
      status: decision.conflict_assessment?.status ?? fallback.conflict_assessment.status,
      summary: nonEmptyString(decision.conflict_assessment?.summary, fallback.conflict_assessment.summary),
      required_tradeoffs: nonEmptyStrings(decision.conflict_assessment?.required_tradeoffs, fallback.conflict_assessment.required_tradeoffs),
    },
    conflict_decisions: Array.isArray(decision.conflict_decisions) && decision.conflict_decisions.length
      ? decision.conflict_decisions
      : fallback.conflict_decisions,
    minimum_effective_dose_rules: nonEmptyStrings(decision.minimum_effective_dose_rules, fallback.minimum_effective_dose_rules),
    planner_constraints: {
      weekly_plan_rules: nonEmptyStrings(decision.planner_constraints?.weekly_plan_rules, fallback.planner_constraints.weekly_plan_rules),
      workout_generation_rules: nonEmptyStrings(decision.planner_constraints?.workout_generation_rules, fallback.planner_constraints.workout_generation_rules),
      target_generation_rules: nonEmptyStrings(decision.planner_constraints?.target_generation_rules, fallback.planner_constraints.target_generation_rules),
    },
  };
}

function normalizeRoleDecisions(
  decisions: ArchitectSynthesisDecision["modality_roles"],
  fallback: ArchitectSynthesisDecision["modality_roles"],
  frame: TrainingArchitectFrame,
  consultations: SpecialistConsultation[],
  packet: PlanningPacket,
) {
  const byModality = new Map((Array.isArray(decisions) ? decisions : []).map((role) => [normalizeModality(role.modality), role]));
  const fallbackByModality = new Map(fallback.map((role) => [normalizeModality(role.modality), role]));
  return frame.selected_modalities.map((modality, index) => {
    const decision = byModality.get(modality);
    const fallbackRole = fallbackByModality.get(modality);
    const consultation = consultations.find((candidate) => candidate.modality === modality);
    const role = decision && modalityRoleEnum.includes(decision.role)
      ? decision.role
      : fallbackRole?.role ?? consultation?.recommended_role ?? roleHypothesis(modality, index, packet);
    return {
      modality,
      role,
      rationale: nonEmptyString(decision?.rationale, fallbackRole?.rationale ?? consultation?.rationale ?? `${titleCase(modality)} is assigned by final architecture synthesis.`),
    };
  });
}

function deterministicSynthesisDecision(
  frame: TrainingArchitectFrame,
  consultations: SpecialistConsultation[],
  packet: PlanningPacket,
): ArchitectSynthesisDecision {
  const filterResult = filterApprovedArchetypes(frame, consultations, packet);
  const conflictSignalsForPacket = conflictSignals(packet);
  const conflictStatus = conflictSignalsForPacket.length > 0
    ? "conflicting"
    : frame.selected_modalities.length > 2 || filterResult.rejected.length > 0
      ? "manageable_tradeoff"
      : "clear";
  return {
    priority_order: frame.priority_hypotheses,
    modality_roles: consultations.map((consultation) => ({
      modality: consultation.modality,
      role: consultation.recommended_role,
      rationale: consultation.rationale,
    })),
    weekly_budget: {
      target_sessions: frame.weekly_budget_range.target_sessions,
      minimum_viable_sessions: frame.weekly_budget_range.minimum_sessions,
      hard_sessions: frame.weekly_budget_range.hard_day_cap,
    },
    recovery_envelope: {
      spacing_rules: [
        "Separate hard endurance and hard lower-body strength by at least one easier day when possible.",
        "If recovery evidence is missing or worsening, use the minimum viable week before adding intensity.",
      ],
      bad_day_floor: packet.planning_constraints.bad_day_floor,
    },
    approved_archetype_ids: filterResult.approved.map((archetype) => archetype.id),
    rejected_recommendations: filterResult.rejected.map((rejection) => ({
      modality: rejection.modality,
      archetype_id: rejection.archetype_id ?? null,
      reason: rejection.reason,
    })),
    phase_logic: packet.goal_context.goal_kind !== "consistency"
      ? {
        requires_phases: true,
        phases: [
          { id: "base", name: "Base", objective: "Make the weekly structure reliable." },
          { id: "build", name: "Build", objective: "Increase goal-specific dose without breaking recovery." },
          { id: "review", name: "Review", objective: "Confirm progress and decide the next move." },
        ],
      }
      : { requires_phases: false, phases: [] },
    progression_rules: [
      "Progress only when the committed week is mostly completed and recovery caveats are not worsening.",
      "Prefer a small dose increase over adding a new modality when adherence is uncertain.",
      "Escalate intensity only through approved archetypes.",
    ],
    interference_rules: uniqueStrings(consultations.flatMap((consultation) => consultation.interference_rules)),
    conflict_assessment: {
      status: conflictStatus,
      summary: conflictSummary(conflictStatus),
      required_tradeoffs: conflictSignalsForPacket.length
        ? conflictSignalsForPacket
        : ["Recovery and adherence take precedence over optional volume."],
    },
    conflict_decisions: [
      {
        id: "final_priority_order",
        decision: `Use ${frame.priority_hypotheses.map(titleCase).join(" > ")} as the final priority order.`,
        rationale: "The selected modality order is the strongest user-authored priority signal.",
      },
      {
        id: "specialist_filtering",
        decision: "Only approved archetypes reach the planner compiler.",
        rationale: "Specialists provide recommendations, but the Training Architect owns coherence and filters fatigue or interference conflicts.",
      },
      ...conflictSignalsForPacket.map((signal) => ({
        id: signal,
        decision: "Require explicit tradeoff handling before progression.",
        rationale: conflictQuestionFor(signal),
      })),
    ],
    minimum_effective_dose_rules: [
      "Protect the minimum viable week before adding optional work.",
      "Keep every selected modality assigned to a role, even when the role is optional or maintenance.",
      "Use conservative dose when approved evidence is missing.",
    ],
    planner_constraints: {
      weekly_plan_rules: [
        "Week 1 is committed; week 2 is draft and must preserve user-authored constraints.",
        "Use the final priority order and role assignments from the Training Architecture.",
      ],
      workout_generation_rules: [
        `Allowed modalities: ${frame.selected_modalities.join(", ")}.`,
        `Approved archetypes: ${filterResult.approved.map((archetype) => archetype.id).join(", ")}.`,
        "Do not introduce off-menu modalities.",
        "Do not reopen goal priority, modality role, or tradeoff decisions.",
      ],
      target_generation_rules: [
        "Targets must be measurable from actual completion, body entries, performance observations, or approved plan structure.",
        "Do not mark completion-based targets done from planned workouts alone.",
      ],
    },
  };
}

function requireManifest(state: TrainingArchitectureState) {
  if (!state.knowledge_manifest?.length) throw new Error("Knowledge manifest has not been loaded.");
  return state.knowledge_manifest;
}

function requireFrame(state: TrainingArchitectureState) {
  if (!state.frame) throw new Error("Training Architect frame has not been produced.");
  return state.frame;
}

function consultationFor(
  brief: TrainingArchitectFrame["specialist_briefs"][number],
  index: number,
  packet: PlanningPacket,
  packs: KnowledgePack[],
): SpecialistConsultation {
  const corePack = requireKnowledgePack(packs, "core.training_doctrine");
  const policyPack = requireKnowledgePack(packs, "policy.hayf_planning");
  const modalityPack = modalityPackFor(packs, brief.modality);
  const goalPacks = goalPacksFor(packs, {
    goalKind: packet.goal_context.goal_kind,
    bodyCompositionIntent: packet.goal_context.body_composition_intent,
    goalText: goalText(packet),
  });
  const refs = sourceRefs([corePack, policyPack, ...goalPacks, modalityPack]);
  const supported = modalityPack.id !== "modality.generic";
  const role = specialistRole(brief.modality, brief.requested_role, index, packet, supported);
  return {
    coach: supported ? `${brief.modality}_specialist_consultant` : "generic_specialist_consultant",
    modality: brief.modality,
    recommended_role: role,
    rationale: roleRationale(brief.modality, role, supported),
    performance_determinants: performanceDeterminants(brief.modality, supported),
    adaptation_priorities: adaptationPriorities(brief.modality, role, packet, supported),
    intensity_model: intensityModel(brief.modality, supported),
    weekly_dose: weeklyDoseFor(role, supported),
    archetype_proposals: archetypesFor(brief.modality, role, packet, refs, supported),
    fatigue_signals: fatigueSignals(brief.modality, supported),
    interference_rules: interferenceRules(brief.modality, role, supported),
    common_mistakes: commonMistakes(brief.modality, supported),
    tool_requests: [
      {
        tool_name: "read_modality_consistency",
        purpose: `Summarize recent consistency for ${brief.modality} when live evidence tools are connected.`,
        input: { modality: brief.modality },
        optional: true,
      },
      {
        tool_name: "read_fatigue_signals",
        purpose: "Summarize cardio, muscular, connective-tissue, and nervous-system fatigue signals.",
        input: { modality: brief.modality, horizon_days: 28 },
        optional: true,
      },
    ],
    knowledge_refs: refs,
  };
}

function archetypesFor(
  modality: string,
  role: ModalityRole,
  packet: PlanningPacket,
  refs: KnowledgeSourceRef[],
  supported: boolean,
): WorkoutArchetypeRecommendation[] {
  if (!supported) {
    return [
      archetype(`${modality}_skill_practice`, modality, "Practice repeatable technique at a controlled effort.", "skill economy and adherence", "easy-skill", 20, 45, "1 to 2 exposures weekly", "Add duration before complexity.", "low", [], ["Do not use as a hard session in V1."], ["Keep prescription conservative until a dedicated modality pack exists."], refs),
      archetype(`${modality}_easy_conditioning`, modality, "Use an easy conditioning exposure for general fitness.", "aerobic base and routine", "easy aerobic", 20, 50, "0 to 2 exposures weekly", "Increase only if the athlete completes the minimum week.", "low", [], ["Avoid if it crowds primary modality recovery."], ["No intervals, races, or technical overload without a dedicated specialist."], refs),
    ];
  }
  if (modality === "cycling") {
    const proposals = [
      archetype("cycling_endurance_ride", modality, "Build durable low-intensity aerobic volume.", "aerobic base and durability", "easy aerobic", 45, 120, "1 to 3 rides weekly", "Extend by 5 to 10 minutes when recovery is stable.", "low", ["Bike access"], ["Avoid adding after a failed minimum week."], ["Can anchor primary cycling weeks or support mixed goals."], refs),
      archetype("cycling_tempo_ride", modality, "Add controlled sustained work without maximal strain.", "tempo durability", "tempo", 35, 75, "0 to 1 ride weekly", "Add intervals before adding intensity.", "moderate", ["Basic cycling tolerance"], ["Do not place after hard lower-body strength."], ["Keep below all-out effort and preserve repeatability."], refs),
    ];
    if (role === "primary_driver" && packet.goal_context.goal_kind !== "consistency") {
      proposals.push(archetype("cycling_vo2_intervals", modality, "Use short high-output intervals only when performance needs justify them.", "VO2max and high-end aerobic power", "VO2max", 35, 60, "0 to 1 ride weekly", "Progress repetitions only after two successful exposures.", "high", ["Established cycling tolerance"], ["Avoid during poor recovery or when strength soreness is high."], ["Counts as a hard day and needs spacing."], refs));
    }
    return proposals;
  }
  if (modality === "strength") {
    const proposals = [
      archetype("strength_full_body_support", modality, "Maintain full-body strength and tissue capacity.", "force production and movement quality", "moderate strength", 35, 60, "1 to 2 sessions weekly", "Add reps or load only when soreness stays bounded.", "moderate", ["Basic gym access or bodyweight alternatives"], ["Do not place immediately before key endurance intensity."], ["Use full-body structure before adding splits."], refs),
      archetype("strength_maintenance", modality, "Keep the strength signal alive with low complexity.", "strength retention", "easy-moderate strength", 20, 45, "1 session weekly", "Hold steady during high endurance load.", "low", [], ["Avoid chasing soreness."], ["Prioritize clean movement and repeatability."], refs),
    ];
    if (packet.goal_context.body_composition_intent || /muscle|strong|hypertrophy|lean/i.test(goalText(packet))) {
      proposals.push(archetype("strength_hypertrophy_support", modality, "Protect lean mass with enough mechanical tension.", "hypertrophy support and muscle retention", "moderate strength", 40, 65, "1 to 2 sessions weekly", "Add one set before adding another hard day.", "moderate", ["Recovery room for soreness"], ["Do not combine with aggressive endurance intensity."], ["Stop short of failure when mixed with endurance priorities."], refs));
    }
    return proposals;
  }
  if (modality === "running") {
    const proposals = [
      archetype("running_easy_aerobic", modality, "Build easy aerobic exposure with impact kept controlled.", "aerobic base and tissue tolerance", "easy aerobic", 20, 50, "0 to 2 runs weekly", "Add 5 minutes only when impact tolerance is calm.", "moderate", ["No active impact injury"], ["Avoid after heavy lower-body strength if soreness is high."], ["Keep easy unless running is the primary goal."], refs),
      archetype("running_strides", modality, "Use short relaxed strides for mechanics without a full hard session.", "neuromuscular coordination", "neuromuscular", 20, 40, "0 to 1 exposure weekly", "Add repetitions before speed.", "moderate", ["Comfortable easy running"], ["Avoid during tendon pain or poor sleep."], ["Attach to an easy run, not a separate hard day."], refs),
    ];
    if (role === "primary_driver" && packet.goal_context.goal_kind !== "consistency") {
      proposals.push(archetype("running_tempo", modality, "Use controlled tempo work for running-specific stamina.", "threshold durability", "threshold", 30, 60, "0 to 1 run weekly", "Extend controlled blocks gradually.", "high", ["Stable easy running base"], ["Do not add alongside cycling VO2 in the same low-budget week."], ["Counts as a hard day."], refs));
    }
    return proposals;
  }
  return [
    archetype(`${modality}_easy_training`, modality, "Keep training repeatable while the modality pack is generic.", "general fitness", "easy", 20, 45, "0 to 2 exposures weekly", "Progress only after adherence is stable.", "low", [], ["Avoid novelty overload."], ["Use conservative prescription."], refs),
  ];
}

function archetype(
  id: string,
  modality: string,
  purpose: string,
  target_adaptation: string,
  intensity_domain: string,
  minMinutes: number,
  maxMinutes: number,
  dose_range: string,
  progression_rule: string,
  fatigue_cost: WorkoutArchetypeRecommendation["fatigue_cost"],
  prerequisites: string[],
  incompatibilities: string[],
  planner_constraints: string[],
  knowledge_refs: KnowledgeSourceRef[],
): WorkoutArchetypeRecommendation {
  return {
    id,
    modality,
    purpose,
    target_adaptation,
    intensity_domain,
    typical_duration_minutes: { min: minMinutes, max: maxMinutes },
    dose_range,
    progression_rule,
    fatigue_cost,
    prerequisites,
    incompatibilities,
    planner_constraints,
    knowledge_refs,
  };
}

function filterApprovedArchetypes(
  frame: TrainingArchitectFrame,
  consultations: SpecialistConsultation[],
  packet: PlanningPacket,
  decision?: ArchitectSynthesisDecision,
): { approved: WorkoutArchetypeRecommendation[]; rejected: RejectedRecommendation[] } {
  const approved: WorkoutArchetypeRecommendation[] = [];
  const rejected: RejectedRecommendation[] = [];
  const lowBudget = frame.weekly_budget_range.target_sessions <= 3;
  const missingEvidence = packet.approved_evidence_summary.confidence === "missing";
  const architectApprovedIDs = decision ? new Set(decision.approved_archetype_ids) : null;
  const architectRejections = new Map((decision?.rejected_recommendations ?? [])
    .filter((rejection) => rejection.archetype_id)
    .map((rejection) => [rejection.archetype_id, rejection.reason]));

  for (const consultation of consultations) {
    const modalityApproved: WorkoutArchetypeRecommendation[] = [];
    for (const proposal of consultation.archetype_proposals) {
      const highFatigueSupport = proposal.fatigue_cost === "high" && consultation.recommended_role !== "primary_driver";
      const highFatigueLowBudget = proposal.fatigue_cost === "high" && lowBudget;
      const highFatigueMissingEvidence = proposal.fatigue_cost === "high" && missingEvidence;
      const notArchitectApproved = architectApprovedIDs ? !architectApprovedIDs.has(proposal.id) : false;
      if (highFatigueSupport || highFatigueLowBudget || highFatigueMissingEvidence || notArchitectApproved) {
        rejected.push({
          modality: proposal.modality,
          archetype_id: proposal.id,
          reason: architectRejections.get(proposal.id) ?? "Rejected by the Training Architect because its fatigue cost, role fit, budget, evidence confidence, or final architecture decision does not fit.",
          knowledge_refs: proposal.knowledge_refs,
        });
        continue;
      }
      modalityApproved.push(proposal);
      approved.push(proposal);
    }

    if (!modalityApproved.length && consultation.archetype_proposals.length && !architectApprovedIDs) {
      const fallback = consultation.archetype_proposals
        .slice()
        .sort((left, right) => fatigueRank(left.fatigue_cost) - fatigueRank(right.fatigue_cost))[0];
      approved.push(fallback);
    }
  }
  if (!approved.length && decision) {
    return filterApprovedArchetypes(frame, consultations, packet);
  }
  return { approved, rejected };
}

function compatRecommendationFor(consultation: SpecialistConsultation): SpecialistRecommendation {
  return {
    coach: consultation.coach,
    modality: consultation.modality,
    role: consultation.recommended_role,
    development_path: consultation.adaptation_priorities.join(", "),
    weekly_dose: consultation.weekly_dose.target,
    key_risks: consultation.fatigue_signals,
    planning_rules: consultation.interference_rules,
  };
}

function roleHypothesis(modality: string, index: number, packet: PlanningPacket): ModalityRole {
  if (index === 0) return "primary_driver";
  if (modality === "strength" && packet.goal_context.body_composition_intent) return "secondary_support";
  if (modality === "strength") return "secondary_support";
  if (modality === "running") return "optional_filler";
  return index === 1 ? "secondary_support" : "maintenance_exposure";
}

function specialistRole(
  _modality: string,
  requested: ModalityRole,
  index: number,
  _packet: PlanningPacket,
  supported: boolean,
): ModalityRole {
  if (!supported && index > 1) return "maintenance_exposure";
  return requested;
}

function roleRationale(modality: string, role: ModalityRole, supported: boolean) {
  if (!supported) {
    return `${titleCase(modality)} uses the generic fallback pack, so the role stays conservative until a dedicated specialist pack exists.`;
  }
  if (role === "primary_driver") return `${titleCase(modality)} best expresses the user's selected priority and anchors progression.`;
  if (role === "secondary_support") return `${titleCase(modality)} supports the primary goal but must stay bounded by recovery.`;
  if (role === "maintenance_exposure") return `${titleCase(modality)} remains visible without competing for the main adaptation budget.`;
  if (role === "optional_filler") return `${titleCase(modality)} can help only when it does not crowd the minimum viable week.`;
  return `${titleCase(modality)} is currently inappropriate for the stated constraints.`;
}

function performanceDeterminants(modality: string, supported: boolean) {
  if (!supported) return ["repeatability", "skill familiarity", "low-risk conditioning"];
  if (modality === "cycling") return ["aerobic durability", "sustainable power", "fatigue resistance", "fueling tolerance"];
  if (modality === "strength") return ["movement quality", "force production", "tissue tolerance", "progressive loading"];
  if (modality === "running") return ["impact tolerance", "aerobic economy", "durability", "pace control"];
  return ["repeatability", "general conditioning"];
}

function adaptationPriorities(modality: string, role: ModalityRole, packet: PlanningPacket, supported: boolean) {
  if (!supported) return ["skill familiarity", "repeatable exposure", "conservative progression"];
  if (modality === "cycling") {
    return role === "primary_driver"
      ? ["aerobic base", "durability", packet.goal_context.goal_kind === "consistency" ? "repeatable habit" : "controlled intensity"]
      : ["low-impact aerobic support", "recovery-friendly volume"];
  }
  if (modality === "strength") {
    return packet.goal_context.body_composition_intent
      ? ["mechanical tension", "lean mass protection", "joint capacity"]
      : ["movement quality", "general strength", "injury resilience"];
  }
  if (modality === "running") {
    return role === "primary_driver"
      ? ["easy aerobic consistency", "impact tolerance", "running economy"]
      : ["optional aerobic support", "tissue tolerance"];
  }
  return ["general fitness"];
}

function intensityModel(modality: string, supported: boolean) {
  if (!supported) return "Use simple easy/moderate/hard language until a dedicated modality intensity model exists.";
  if (modality === "cycling") return "Power, heart rate, RPE, and talk-test domains: easy, tempo, threshold, VO2max.";
  if (modality === "strength") return "RPE/reps-in-reserve, movement quality, volume, and soreness response.";
  if (modality === "running") return "Pace, heart rate, RPE, and impact tolerance domains: easy, strides, tempo, threshold.";
  return "Simple effort domains.";
}

function weeklyDoseFor(role: ModalityRole, supported: boolean) {
  if (!supported) {
    return { minimum: "0 exposures", target: "1 conservative exposure", maximum: "2 exposures", hard_cap: "0 hard exposures" };
  }
  if (role === "primary_driver") {
    return { minimum: "1 exposure", target: "2 protected exposures", maximum: "3 exposures", hard_cap: "1 hard exposure unless the budget is high" };
  }
  if (role === "secondary_support") {
    return { minimum: "1 exposure", target: "1 to 2 bounded exposures", maximum: "2 exposures", hard_cap: "0 to 1 hard exposure only if it does not conflict" };
  }
  if (role === "maintenance_exposure") {
    return { minimum: "0 exposures", target: "1 exposure", maximum: "1 to 2 exposures", hard_cap: "0 hard exposures" };
  }
  if (role === "optional_filler") {
    return { minimum: "0 exposures", target: "0 to 1 exposure", maximum: "1 exposure", hard_cap: "0 hard exposures" };
  }
  return { minimum: "0 exposures", target: "0 exposures", maximum: "0 exposures", hard_cap: "0 hard exposures" };
}

function fatigueSignals(modality: string, supported: boolean) {
  if (!supported) return ["novelty soreness", "technical frustration", "adherence drag"];
  if (modality === "cycling") return ["heavy legs", "rising RPE for normal power", "poor sleep after intensity", "low appetite after long rides"];
  if (modality === "strength") return ["persistent soreness", "joint irritation", "bar speed or rep quality drop", "motivation drop around heavy lifts"];
  if (modality === "running") return ["tendon pain", "impact soreness", "pace drift at easy effort", "stiffness that changes gait"];
  return ["unusual soreness", "poor recovery"];
}

function interferenceRules(modality: string, role: ModalityRole, supported: boolean) {
  if (!supported) return ["Generic modalities cannot displace approved primary or secondary work in V1."];
  if (modality === "cycling") return ["Do not place cycling VO2 work next to heavy lower-body strength.", "Long rides should not erase the minimum strength dose."];
  if (modality === "strength") return ["Avoid heavy lower-body strength immediately before key endurance intensity.", "Stop support strength short of failure in mixed-goal weeks."];
  if (modality === "running") return role === "primary_driver"
    ? ["Hard running counts as a hard day and needs spacing from strength."]
    : ["Running remains optional if impact soreness threatens the minimum week."];
  return ["Support work cannot compete with the primary adaptation."];
}

function commonMistakes(modality: string, supported: boolean) {
  if (!supported) return ["Treating a generic fallback as expert modality prescription.", "Adding complexity before the habit is stable."];
  if (modality === "cycling") return ["Turning every ride into tempo.", "Adding intensity before easy volume is repeatable.", "Ignoring fueling on longer rides."];
  if (modality === "strength") return ["Chasing soreness as proof of progress.", "Adding too many exercises before progression is stable.", "Letting support strength impair endurance quality."];
  if (modality === "running") return ["Adding speed before impact tolerance.", "Running easy days too hard.", "Keeping optional runs when soreness is rising."];
  return ["Progressing novelty too fast."];
}

function parseFrequency(value: string | null) {
  const match = value?.match(/\d+/);
  return match ? Number(match[0]) : 3;
}

function normalizeUnique(values: string[]) {
  return uniqueStrings(values.map(normalizeModality).filter(Boolean));
}

function uniqueStrings(values: string[]) {
  return Array.from(new Set(values));
}

function goalText(packet: PlanningPacket) {
  return [
    JSON.stringify(packet.goal_context.normalized_goal),
    packet.goal_context.success_definition,
    packet.goal_context.body_composition_intent,
  ].filter(Boolean).join(" ").toLowerCase();
}

function goalSummary(packet: PlanningPacket) {
  const title = String(packet.goal_context.normalized_goal.title ?? packet.goal_context.success_definition ?? "the active goal");
  return `Build training around ${title}.`;
}

function conflictSignals(packet: PlanningPacket) {
  const text = goalText(packet);
  return [
    text.includes("bodybuilder") && text.includes("tour de france") ? "maximal_hypertrophy_vs_grand_tour_endurance" : null,
    text.includes("lose") && text.includes("power") ? "body_composition_vs_performance_fatigue" : null,
    text.includes("maximal hypertrophy") && text.includes("endurance") ? "maximal_hypertrophy_vs_endurance_volume" : null,
  ].filter(Boolean) as string[];
}

function conflictQuestionFor(signal: string) {
  if (signal === "maximal_hypertrophy_vs_grand_tour_endurance") {
    return "Maximal hypertrophy and grand-tour endurance cannot both be maximized; the plan must select a priority.";
  }
  if (signal === "body_composition_vs_performance_fatigue") {
    return "Fat loss and performance work can coexist only if fueling, recovery, and hard-day caps are explicit.";
  }
  if (signal === "maximal_hypertrophy_vs_endurance_volume") {
    return "High hypertrophy volume and high endurance volume compete for recovery and must be sequenced.";
  }
  return "A stated goal conflict requires explicit prioritization.";
}

function conflictSummary(status: TrainingArchitecture["conflict_assessment"]["status"]) {
  if (status === "conflicting") return "The stated goals cannot all be maximized at once without explicit prioritization.";
  if (status === "manageable_tradeoff") return "The goal is viable if support modalities and high-fatigue archetypes stay bounded.";
  return "No major conflict is visible in the planning packet.";
}

function recoveryRisksFor(packet: PlanningPacket, modalities: string[]) {
  const risks = [
    modalities.includes("strength") && (modalities.includes("running") || modalities.includes("cycling"))
      ? "Lower-body strength can interfere with endurance quality if hard sessions are stacked."
      : null,
    modalities.includes("running") ? "Running adds impact cost and should be conservative when evidence is thin." : null,
    packet.approved_evidence_summary.confidence === "missing" ? "Missing evidence requires conservative dose and no fake certainty." : null,
    packet.planning_constraints.injuries ? `Injury constraint: ${packet.planning_constraints.injuries}.` : null,
  ].filter(Boolean) as string[];
  return risks.length ? risks : ["No unusual recovery risk is visible beyond normal hard-day spacing."];
}

function fatigueRank(cost: WorkoutArchetypeRecommendation["fatigue_cost"]) {
  if (cost === "low") return 0;
  if (cost === "moderate") return 1;
  return 2;
}

function hasDatedWorkoutKeys(value: unknown): boolean {
  if (!value || typeof value !== "object") return false;
  for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
    if (["date", "scheduledDate", "scheduled_date", "weekStartDate", "week_start_date"].includes(key)) return true;
    if (Array.isArray(nested) && nested.some(hasDatedWorkoutKeys)) return true;
    if (nested && typeof nested === "object" && hasDatedWorkoutKeys(nested)) return true;
  }
  return false;
}

function packForPrompt(pack: KnowledgePack) {
  return {
    id: pack.id,
    title: pack.title,
    version: pack.version,
    layer: pack.layer,
    scope: pack.scope,
    summary: pack.summary,
    content: pack.content,
  };
}

function nonEmptyString(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function nonEmptyStrings(value: unknown, fallback: string[]) {
  const strings = Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string" && Boolean(item.trim())).map((item) => item.trim())
    : [];
  return strings.length ? uniqueStrings(strings) : fallback;
}

function normalizeArchetypeID(value: string, modality: string) {
  const normalized = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  if (!normalized) return `${modality}_ai_archetype`;
  return normalized.startsWith(`${modality}_`) ? normalized : `${modality}_${normalized}`;
}

function clampInteger(value: unknown, min: number, max: number) {
  const numeric = Math.round(Number(value));
  if (!Number.isFinite(numeric)) return min;
  return Math.max(min, Math.min(max, numeric));
}

function normalizePhaseLogic(
  value: ArchitectSynthesisDecision["phase_logic"],
  packet: PlanningPacket,
): TrainingArchitecture["phase_logic"] {
  if (packet.goal_context.goal_kind === "consistency") {
    return { requires_phases: false, phases: [] };
  }
  const phases = Array.isArray(value?.phases)
    ? value.phases
      .filter((phase) => phase.id && phase.name && phase.objective)
      .map((phase) => ({
        id: normalizeArchetypeID(phase.id, "phase").replace(/^phase_/, ""),
        name: phase.name,
        objective: phase.objective,
      }))
    : [];
  return {
    requires_phases: true,
    phases: phases.length ? phases : [
      { id: "base", name: "Base", objective: "Make the weekly structure reliable." },
      { id: "build", name: "Build", objective: "Increase goal-specific dose without breaking recovery." },
      { id: "review", name: "Review", objective: "Confirm progress and decide the next move." },
    ],
  };
}

function normalizeConflictDecisions(
  decisions: Array<{ id: string; decision: string; rationale: string }>,
  knowledgeRefs: KnowledgeSourceRef[],
  fallback: Array<{ id: string; decision: string; rationale: string }>,
): TrainingArchitecture["conflict_decisions"] {
  const usable = Array.isArray(decisions) && decisions.length ? decisions : fallback;
  return usable
    .filter((decision) => decision.id && decision.decision && decision.rationale)
    .map((decision) => ({
      id: normalizeArchetypeID(decision.id, "decision").replace(/^decision_/, ""),
      decision: decision.decision,
      rationale: decision.rationale,
      knowledge_refs: knowledgeRefs,
    }));
}

function titleCase(value: string) {
  return value
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}
