const state = {
  catalog: null,
  mockFixtures: [],
  graphs: [],
  graphFixtures: [],
  graphRuns: [],
  selectedGraph: null,
  selectedNode: null,
  selectedGraphRunID: null,
  graphMetadata: null,
  evals: [],
  lastPromptRun: null,
  selectedGraphTool: null,
  lastGraphRun: null,
  graphReadableValue: null,
  graphReadableTitle: "Graph Result",
  graphReadableSubtitle: "",
  defaultModel: "gpt-5-mini",
  selected: null,
  dirty: false,
};

const PLANNED_GRAPHS = [
  {
    name: "prepare_initial_strategy",
    label: "Prepare Initial Strategy",
    purpose: "Planned sequence for the initial planning pipeline: frame the athlete context, run specialist workers, let the master coach synthesize, then generate the visible strategy.",
    nodes: [
      plannedNode("validate_packet", "Validate Packet", "deterministic", "Confirm the planning packet is compact and safe to send through the graph.", [], "PlanningPacket", "packet summary", []),
      plannedNode("load_knowledge_manifest", "Load Knowledge", "deterministic", "Load HAYF doctrine, policy, goal packs, and modality packs.", [], "none", "KnowledgePack[]", ["core.training_doctrine", "policy.hayf_planning", "goal.*", "modality.*"]),
      plannedNode("architect_frame", "Architect Frame", "deterministic", "Build the shared brief: goal read, selected modalities, weekly budget hypothesis, recovery risks, and specialist questions.", [], "PlanningPacket + KnowledgePack[]", "TrainingArchitectFrame", ["core.training_doctrine", "policy.hayf_planning", "goal.*", "modality.*"]),
      plannedNode("specialist_consultations", "Worker Specialists", "fanout", "Hit the worker coach nodes in parallel. Each selected modality gets a bounded consultant response with adaptations, archetypes, fatigue warnings, and knowledge refs.", ["consult_cycling_specialist", "consult_strength_specialist", "consult_running_specialist", "consult_<modality>_generic_specialist"], "TrainingArchitectFrame + PlanningPacket", "SpecialistConsultation[]", ["core.training_doctrine", "policy.hayf_planning", "modality.*"]),
      plannedNode("architect_synthesis", "Master Coach", "model", "Hit the master Training Architect. It reconciles specialist proposals into one priority order, role assignment, weekly budget, recovery envelope, and conflict decision set.", ["synthesize_training_architecture"], "TrainingArchitectFrame + SpecialistConsultation[]", "TrainingArchitecture", ["core.training_doctrine", "policy.hayf_planning", "goal.*", "modality.*"]),
      plannedNode("deterministic_validation", "Validate Architecture", "deterministic", "Check that the architecture is coherent before it can become product state.", [], "TrainingArchitecture", "validation summary", []),
      plannedNode("author_training_architecture_reasoning", "Architect Reasoning", "model", "Ask the architect reviewer to explain the validated decision without changing it.", ["author_training_architecture_reasoning"], "TrainingArchitecture", "ArchitectureReasoningOutput", ["source_knowledge_refs"]),
      plannedNode("generate_strategy", "Strategy Writer", "model", "Generate measurable strategy targets and user-facing strategy copy from the validated architecture.", ["generate_fitness_strategy_targets", "generate_fitness_strategy"], "PlanningPacket + TrainingArchitecture", "FitnessStrategyArtifact", ["source_knowledge_refs"]),
    ],
    edges: [
      plannedEdge("__start__", "validate_packet"),
      plannedEdge("validate_packet", "load_knowledge_manifest"),
      plannedEdge("load_knowledge_manifest", "architect_frame"),
      plannedEdge("architect_frame", "specialist_consultations"),
      plannedEdge("specialist_consultations", "architect_synthesis"),
      plannedEdge("architect_synthesis", "deterministic_validation"),
      plannedEdge("deterministic_validation", "author_training_architecture_reasoning"),
      plannedEdge("author_training_architecture_reasoning", "generate_strategy"),
      plannedEdge("generate_strategy", "__end__"),
    ],
  },
  {
    name: "training_architecture",
    label: "Training Architecture",
    purpose: "Planned architecture graph: validate packet, frame specialists, run worker coaches, then let the master coach synthesize and validate the architecture.",
    nodes: [
      plannedNode("validate_packet", "Validate Packet", "deterministic", "Reject raw evidence and confirm the compact packet contract.", [], "PlanningPacket", "packet summary", []),
      plannedNode("load_knowledge_manifest", "Load Knowledge", "deterministic", "Load static HAYF knowledge packs.", [], "none", "KnowledgePack[]", ["core.training_doctrine", "policy.hayf_planning", "goal.*", "modality.*"]),
      plannedNode("architect_frame", "Architect Frame", "deterministic", "Build modality briefs and the architect's initial hypotheses.", [], "PlanningPacket + KnowledgePack[]", "TrainingArchitectFrame", ["core.training_doctrine", "policy.hayf_planning", "goal.*", "modality.*"]),
      plannedNode("specialist_consultations", "Worker Specialists", "fanout", "Run bounded modality consultants in parallel.", ["consult_cycling_specialist", "consult_strength_specialist", "consult_running_specialist", "consult_<modality>_generic_specialist"], "TrainingArchitectFrame + PlanningPacket", "SpecialistConsultation[]", ["modality.*"]),
      plannedNode("architect_synthesis", "Master Coach", "model", "Resolve specialist recommendations into one final architecture.", ["synthesize_training_architecture"], "TrainingArchitectFrame + SpecialistConsultation[]", "TrainingArchitecture", ["source_knowledge_refs"]),
      plannedNode("deterministic_validation", "Validate Architecture", "deterministic", "Assert final architecture invariants.", [], "TrainingArchitecture", "validation summary", []),
      plannedNode("author_training_architecture_reasoning", "Architect Reasoning", "model", "Explain why the architecture is coherent.", ["author_training_architecture_reasoning"], "TrainingArchitecture", "ArchitectureReasoningOutput", ["source_knowledge_refs"]),
    ],
    edges: [
      plannedEdge("__start__", "validate_packet"),
      plannedEdge("validate_packet", "load_knowledge_manifest"),
      plannedEdge("load_knowledge_manifest", "architect_frame"),
      plannedEdge("architect_frame", "specialist_consultations"),
      plannedEdge("specialist_consultations", "architect_synthesis"),
      plannedEdge("architect_synthesis", "deterministic_validation"),
      plannedEdge("deterministic_validation", "author_training_architecture_reasoning"),
      plannedEdge("author_training_architecture_reasoning", "__end__"),
    ],
  },
  {
    name: "fitness_strategy",
    label: "Fitness Strategy",
    purpose: "Planned strategy graph: use the validated architecture to generate measurable targets and reveal-screen copy.",
    nodes: [
      plannedNode("generate_strategy", "Strategy Writer", "model", "Generate strategy targets first, then strategy copy.", ["generate_fitness_strategy_targets", "generate_fitness_strategy"], "PlanningPacket + TrainingArchitecture", "FitnessStrategyArtifact", ["source_knowledge_refs"]),
    ],
    edges: [plannedEdge("__start__", "generate_strategy"), plannedEdge("generate_strategy", "__end__")],
  },
  {
    name: "two_week_plan",
    label: "Two-Week Plan",
    purpose: "Planned plan compiler graph: transform architecture and strategy into one committed week plus one draft week.",
    nodes: [
      plannedNode("generate_plan", "Plan Compiler", "model", "Compile the two-week plan from approved archetypes, weekly budget, recovery rules, and planner constraints.", ["compile_two_week_plan"], "PlanningPacket + TrainingArchitecture + FitnessStrategyArtifact", "TwoWeekPlanArtifact", ["source_knowledge_refs"]),
    ],
    edges: [plannedEdge("__start__", "generate_plan"), plannedEdge("generate_plan", "__end__")],
  },
];

const MOCK_GRAPH_FIXTURES = [
  {
    filename: "mock-cycling-specialist.json",
    graphName: "training_architecture",
    name: "Cycling specialist",
    description: "Cycling-led goal that will run the cycling worker specialist and master coach synthesis.",
    fixture: graphFixtureFor({
      title: "Build cycling fitness with two rides and one strength day",
      desiredOutcome: "improve cycling stamina while keeping strength as support",
      goalKind: "specific_goal",
      selectedModalities: ["Cycling", "Strength"],
      feasibleModalities: ["Cycling", "Strength"],
      frequency: "3 days per week",
      equipment: ["Road bike", "Indoor trainer", "Gym"],
      avoidances: ["Late night sessions"],
      modalityMix: { cycling: 8, strength: 4 },
    }),
  },
  {
    filename: "mock-running-strength.json",
    graphName: "prepare_initial_strategy",
    name: "Running plus strength",
    description: "Full initial strategy path with running and strength workers before master synthesis.",
    fixture: graphFixtureFor({
      title: "Run a comfortable 10K while keeping strength",
      desiredOutcome: "finish a 10K without knee flare-ups",
      goalKind: "specific_goal",
      selectedModalities: ["Running", "Strength", "Mobility"],
      feasibleModalities: ["Running", "Strength", "Mobility"],
      frequency: "4 days per week",
      equipment: ["Gym", "Treadmill"],
      avoidances: ["Steep downhill running", "Max-effort intervals"],
      modalityMix: { running: 6, strength: 5, mobility: 3 },
    }),
  },
  {
    filename: "mock-generic-specialist.json",
    graphName: "training_architecture",
    name: "Generic specialist fallback",
    description: "Unsupported modalities route through generic worker specialists.",
    fixture: graphFixtureFor({
      title: "Get fitter through tennis and swimming",
      desiredOutcome: "build a repeatable tennis and swim rhythm",
      goalKind: "consistency",
      selectedModalities: ["Tennis", "Swimming"],
      feasibleModalities: ["Tennis", "Swimming"],
      frequency: "3 days per week",
      equipment: ["Pool access", "Tennis court"],
      avoidances: ["High-impact plyometrics"],
      modalityMix: { tennis: 3, swimming: 2 },
    }),
  },
  {
    filename: "mock-two-week-plan.json",
    graphName: "two_week_plan",
    name: "Two-week plan compiler",
    description: "Runs architecture and strategy setup, then tests the two-week plan compiler.",
    fixture: graphFixtureFor({
      title: "Train consistently three times per week",
      desiredOutcome: "make cycling and strength repeatable",
      goalKind: "consistency",
      selectedModalities: ["Cycling", "Strength"],
      feasibleModalities: ["Cycling", "Strength"],
      frequency: "3 days per week",
      equipment: ["Bike", "Gym"],
      avoidances: ["Late night sessions"],
      modalityMix: { cycling: 3, strength: 5 },
    }),
  },
];

const WORKFLOW_STAGES = [
  {
    title: "1. Onboarding Stream",
    summary: "The app captures the user's intent stream and turns it into compact onboarding context.",
    steps: [
      workflowStep("stream_selection", "Select onboarding stream", "entry", "User chooses the path and answers the stream questions.", "App UI", "Onboarding intent + draft answers"),
      workflowStep("generate_summary", "Generate onboarding summary", "ai", "AI summarizes the draft into a coach-readable onboarding context.", "onboarding-ai", "Onboarding summary"),
      workflowStep("generate_candidates", "Generate goal candidates", "ai", "AI proposes candidate goals and modality directions.", "onboarding-ai", "Goal candidates"),
      workflowStep("accept_goal", "Accept goal direction", "deterministic", "User selection becomes the source goal signal for blueprint generation.", "App UI", "Accepted intent"),
    ],
  },
  {
    title: "2. Blueprint",
    summary: "The athlete context is compressed before any planning graph sees it.",
    steps: [
      workflowStep("athlete_blueprint", "Generate athlete blueprint", "ai", "AI produces coach read, archetype, training state, baseline, history findings, and goal fit.", "onboarding-ai", "AthleteBlueprintOutput"),
      workflowStep("blueprint_accept", "Accept blueprint", "entry", "User accepts the blueprint, which starts initial strategy preparation.", "App UI", "Accepted blueprint artifact"),
    ],
  },
  {
    title: "3. Prepare Strategy",
    summary: "This is the rich LangGraph path that should happen before a strategy is accepted.",
    steps: [
      workflowStep("prepare_task", "prepare_initial_strategy_after_blueprint", "entry", "Local Edge Function receives accepted blueprint and onboarding context.", "planning-ai", "Planning packet input"),
      workflowStep("compact_packet", "Build compact planning packet", "deterministic", "Raw/large context is reduced to the bounded PlanningPacket contract.", "planning-ai", "PlanningPacket"),
      workflowStep("validate_packet", "Validate packet", "deterministic", "Training orchestrator rejects raw HealthKit ledgers and unsafe packet shapes.", "training_architecture", "Validated packet"),
      workflowStep("load_knowledge", "Load knowledge packs", "deterministic", "Doctrine, policy, goal packs, and modality packs become bounded source material.", "training_architecture", "KnowledgePack[]"),
      workflowStep("architect_frame", "Architect frame", "deterministic", "Builds modality briefs, weekly budget hypothesis, recovery risks, and specialist questions.", "training_architecture", "TrainingArchitectFrame"),
      workflowStep("worker_specialists", "Worker specialists", "fanout", "Selected modalities call bounded specialist coaches in parallel.", "training_architecture", "SpecialistConsultation[]"),
      workflowStep("master_coach", "Master coach synthesis", "ai", "Training Architect resolves priorities, roles, weekly budget, approved/deferred/rejected archetypes, and conflicts.", "training_architecture", "TrainingArchitecture"),
      workflowStep("validate_architecture", "Validate architecture", "deterministic", "Checks invariants before persisting strategy state.", "training_architecture", "Validation summary"),
      workflowStep("architecture_reasoning", "Architecture reasoning", "ai", "Explains the validated architecture without changing decisions.", "training_architecture", "Reasoning trace"),
      workflowStep("strategy_writer", "Strategy writer", "ai", "Generates strategy targets and user-facing strategy copy from the architecture.", "fitness_strategy", "FitnessStrategyArtifact"),
      workflowStep("persist_prepared", "Persist prepared strategy", "storage", "Stores prepared user goal, training architecture, strategy, node outputs, and tool calls.", "planning-ai + Supabase", "Prepared strategy ID"),
    ],
  },
  {
    title: "4. Accept and Generate First Two Weeks",
    summary: "The accepted plan uses the prepared architecture rather than inventing strategy from scratch.",
    steps: [
      workflowStep("accept_prepared", "accept_prepared_strategy_and_create_initial_plan", "entry", "User accepts the prepared strategy in the app.", "planning-ai", "Prepared strategy ID"),
      workflowStep("activate_strategy", "Activate goal and strategy", "deterministic", "Prepared rows become active and older active planning rows are superseded.", "planning-ai + Supabase", "Active strategy"),
      workflowStep("plan_context", "Build planner contract", "deterministic", "Planner receives only approved archetypes, allowed modalities, constraints, strategy, and architecture.", "planning-ai", "PlannerInputContract"),
      workflowStep("compile_two_week_plan", "Compile two-week plan", "ai", "AI generates week 1 committed and week 2 draft from approved architecture constraints.", "two_week_plan", "TwoWeekPlanArtifact"),
      workflowStep("sanitize_insert_plan", "Sanitize and persist plan", "deterministic", "Validates workouts, applies actuals context, inserts weekly plans/workouts and targets.", "planning-ai + Supabase", "Visible two-week plan"),
    ],
  },
  {
    title: "5. Replanning and Plan Maintenance",
    summary: "Current maintenance paths mostly repair or refresh dated plans; specialist/master phase transitions are still future work.",
    steps: [
      workflowStep("health_sync", "Sync HealthKit and reconcile", "deterministic", "Actual workouts and health evidence are persisted and compared with planned work.", "planning-ai", "Evidence + actuals"),
      workflowStep("refresh_window", "Refresh plan window", "ai", "Generates or repairs visible weekly windows when dates roll forward or user requests a refresh.", "planning-ai", "Updated weekly plans"),
      workflowStep("record_edit", "Record plan edit", "deterministic", "User edits are stored as planning events and constraints.", "planning-ai + Supabase", "Plan edit event"),
      workflowStep("repair_proposal", "Create repair proposal", "ai", "AI proposes coherent repairs for recent or pending edits.", "planning-ai", "Repair proposal"),
      workflowStep("apply_replan", "Apply replan proposal", "deterministic", "Accepted proposal updates the plan and preserves audit events.", "planning-ai + Supabase", "Updated plan"),
      workflowStep("weekly_targets", "Generate weekly targets", "ai", "AI derives measurable weekly targets from the active strategy and visible plan.", "planning-ai", "Weekly targets"),
      workflowStep("future_phase_review", "Future phase/specialist review", "planned", "Later we should revisit deferred archetypes and re-engage specialists/master coach at phase transitions.", "future graph", "Not implemented yet"),
    ],
  },
];

const WORKFLOW_LEGEND = [
  { kind: "entry", label: "Entry/user event", description: "A user action or product task boundary starts the next segment." },
  { kind: "deterministic", label: "Deterministic", description: "Code path with validation, shaping, persistence, or rules. No model call." },
  { kind: "ai", label: "AI/model", description: "A model-backed call whose prompt, input, schema, and output can be traced in local/full observability mode." },
  { kind: "fanout", label: "AI fanout", description: "Parallel model-backed worker calls, usually one per selected modality." },
  { kind: "storage", label: "Storage", description: "Supabase persistence of canonical product state and durable traces." },
  { kind: "planned", label: "Planned future", description: "Important lifecycle point that is documented but not wired as a dedicated graph yet." },
];

const els = {
  statusLine: document.querySelector("#statusLine"),
  touchpointList: document.querySelector("#touchpointList"),
  groupLabel: document.querySelector("#groupLabel"),
  touchpointTitle: document.querySelector("#touchpointTitle"),
  labelInput: document.querySelector("#labelInput"),
  modelInput: document.querySelector("#modelInput"),
  reasoningInput: document.querySelector("#reasoningInput"),
  verbosityInput: document.querySelector("#verbosityInput"),
  parametersInput: document.querySelector("#parametersInput"),
  systemPromptInput: document.querySelector("#systemPromptInput"),
  userRulesInput: document.querySelector("#userRulesInput"),
  mockFixtureInput: document.querySelector("#mockFixtureInput"),
  fixtureSummary: document.querySelector("#fixtureSummary"),
  fixtureNameInput: document.querySelector("#fixtureNameInput"),
  fixtureInput: document.querySelector("#fixtureInput"),
  promptReadableOutput: document.querySelector("#promptReadableOutput"),
  promptRequestSummary: document.querySelector("#promptRequestSummary"),
  evalRatingInput: document.querySelector("#evalRatingInput"),
  evalNotesInput: document.querySelector("#evalNotesInput"),
  saveEvalButton: document.querySelector("#saveEvalButton"),
  evalHistory: document.querySelector("#evalHistory"),
  resultOutput: document.querySelector("#resultOutput"),
  diffOutput: document.querySelector("#diffOutput"),
  saveButton: document.querySelector("#saveButton"),
  runButton: document.querySelector("#runButton"),
  showDiffButton: document.querySelector("#showDiffButton"),
  refreshDiffButton: document.querySelector("#refreshDiffButton"),
  saveFixtureButton: document.querySelector("#saveFixtureButton"),
  touchpointModeButton: document.querySelector("#touchpointModeButton"),
  graphModeButton: document.querySelector("#graphModeButton"),
  workflowModeButton: document.querySelector("#workflowModeButton"),
  touchpointWorkspace: document.querySelector("#touchpointWorkspace"),
  graphWorkspace: document.querySelector("#graphWorkspace"),
  workflowWorkspace: document.querySelector("#workflowWorkspace"),
  graphList: document.querySelector("#graphList"),
  workflowList: document.querySelector("#workflowList"),
  workflowDiagram: document.querySelector("#workflowDiagram"),
  workflowLegend: document.querySelector("#workflowLegend"),
  graphEyebrow: document.querySelector("#graphEyebrow"),
  graphTitle: document.querySelector("#graphTitle"),
  graphPurpose: document.querySelector("#graphPurpose"),
  graphTraceBanner: document.querySelector("#graphTraceBanner"),
  graphRunsTable: document.querySelector("#graphRunsTable"),
  refreshGraphRunsButton: document.querySelector("#refreshGraphRunsButton"),
  refreshGraphsButton: document.querySelector("#refreshGraphsButton"),
  runGraphButton: document.querySelector("#runGraphButton"),
  graphMap: document.querySelector("#graphMap"),
  nodeTitle: document.querySelector("#nodeTitle"),
  nodeKind: document.querySelector("#nodeKind"),
  nodeDetails: document.querySelector("#nodeDetails"),
  testToolButton: document.querySelector("#testToolButton"),
  graphFixtureInput: document.querySelector("#graphFixtureInput"),
  graphFixtureSummary: document.querySelector("#graphFixtureSummary"),
  graphFixtureNameInput: document.querySelector("#graphFixtureNameInput"),
  graphFixtureJSONInput: document.querySelector("#graphFixtureJSONInput"),
  graphOverrideToolInput: document.querySelector("#graphOverrideToolInput"),
  graphOverrideModelInput: document.querySelector("#graphOverrideModelInput"),
  graphOverrideSystemPromptInput: document.querySelector("#graphOverrideSystemPromptInput"),
  saveGraphFixtureButton: document.querySelector("#saveGraphFixtureButton"),
  graphRunIDInput: document.querySelector("#graphRunIDInput"),
  loadGraphRunButton: document.querySelector("#loadGraphRunButton"),
  graphRunStatus: document.querySelector("#graphRunStatus"),
  graphTimeline: document.querySelector("#graphTimeline"),
  readableGraphOutputButton: document.querySelector("#readableGraphOutputButton"),
  readableGraphModal: document.querySelector("#readableGraphModal"),
  readableGraphTitle: document.querySelector("#readableGraphTitle"),
  readableGraphContent: document.querySelector("#readableGraphContent"),
  closeReadableGraphButton: document.querySelector("#closeReadableGraphButton"),
};

await loadCatalog();
await loadGraphInspector();
wireEvents();
renderWorkflow();
await refreshDiff();

async function loadCatalog() {
  const [payload, mockPayload] = await Promise.all([
    requestJSON("/api/touchpoints"),
    requestJSON("/api/mock-fixtures"),
  ]);
  state.catalog = payload.catalog;
  state.mockFixtures = mockPayload.fixtures ?? [];
  state.defaultModel = payload.defaultModel;
  renderTouchpoints();
  const firstGroup = Object.keys(state.catalog)[0];
  const first = state.catalog[firstGroup]?.[0];
  if (first) selectTouchpoint(firstGroup, first.id);
  await loadEvalHistory();
  setStatus("Ready");
}

function wireEvents() {
  for (
    const input of [
      els.labelInput,
      els.modelInput,
      els.reasoningInput,
      els.verbosityInput,
      els.parametersInput,
      els.systemPromptInput,
      els.userRulesInput,
    ]
  ) {
    input.addEventListener("input", () => {
      state.dirty = true;
      setStatus("Unsaved changes");
    });
  }

  els.saveButton.addEventListener("click", saveCurrent);
  els.runButton.addEventListener("click", runCurrent);
  els.showDiffButton.addEventListener("click", refreshDiff);
  els.refreshDiffButton.addEventListener("click", refreshDiff);
  els.saveFixtureButton.addEventListener("click", saveFixture);
  els.saveEvalButton.addEventListener("click", saveEval);
  els.touchpointModeButton.addEventListener("click", () => setMode("touchpoints"));
  els.graphModeButton.addEventListener("click", () => setMode("graphs"));
  els.workflowModeButton.addEventListener("click", () => setMode("workflow"));
  els.refreshGraphsButton.addEventListener("click", loadGraphInspector);
  els.refreshGraphRunsButton.addEventListener("click", loadGraphRuns);
  els.runGraphButton.addEventListener("click", runSelectedGraph);
  els.saveGraphFixtureButton.addEventListener("click", saveGraphFixture);
  els.loadGraphRunButton.addEventListener("click", loadGraphRunByID);
  els.testToolButton.addEventListener("click", testSelectedTool);
  els.readableGraphOutputButton.addEventListener("click", openReadableGraphModal);
  els.closeReadableGraphButton.addEventListener("click", closeReadableGraphModal);
  els.readableGraphModal.addEventListener("click", (event) => {
    if (event.target === els.readableGraphModal) closeReadableGraphModal();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !els.readableGraphModal.classList.contains("hidden")) {
      closeReadableGraphModal();
    }
  });
  els.mockFixtureInput.addEventListener("change", () => {
    const fixture = currentMockFixtures()[Number(els.mockFixtureInput.value)];
    if (!fixture) return;
    els.fixtureInput.value = JSON.stringify(fixture.fixture, null, 2);
    els.fixtureNameInput.value = slugify(fixture.name);
    renderFixtureSummary();
    setStatus(`Loaded ${fixture.name}`);
  });
  els.graphFixtureInput.addEventListener("change", () => {
    const fixture = state.graphFixtures[Number(els.graphFixtureInput.value)];
    if (!fixture) return;
    selectGraph(fixture.graphName);
    els.graphFixtureJSONInput.value = JSON.stringify(fixture.fixture, null, 2);
    els.graphFixtureNameInput.value = slugify(fixture.name ?? fixture.filename);
    renderGraphFixtureSummary();
    setStatus(`Loaded ${fixture.name}`);
  });
  els.graphOverrideToolInput.addEventListener("change", () => {
    state.selectedGraphTool = els.graphOverrideToolInput.value || null;
  });
}

function setMode(mode) {
  const graphMode = mode === "graphs";
  const workflowMode = mode === "workflow";
  const touchpointMode = mode === "touchpoints";
  els.touchpointModeButton.classList.toggle("active", touchpointMode);
  els.graphModeButton.classList.toggle("active", graphMode);
  els.workflowModeButton.classList.toggle("active", workflowMode);
  els.touchpointWorkspace.classList.toggle("hidden", !touchpointMode);
  els.touchpointList.classList.toggle("hidden", !touchpointMode);
  els.graphWorkspace.classList.toggle("hidden", !graphMode);
  els.graphList.classList.toggle("hidden", !graphMode);
  els.workflowWorkspace.classList.toggle("hidden", !workflowMode);
  els.workflowList.classList.toggle("hidden", !workflowMode);
}

function renderWorkflow() {
  renderWorkflowSidebar();
  renderWorkflowDiagram();
  renderWorkflowLegend();
}

function renderWorkflowSidebar() {
  els.workflowList.innerHTML = "";
  const section = document.createElement("section");
  const title = document.createElement("div");
  title.className = "group-title";
  title.textContent = "Workflow";
  section.append(title);
  for (const stage of WORKFLOW_STAGES) {
    const item = document.createElement("div");
    item.className = "workflow-nav-item";
    item.innerHTML = `<strong>${escapeHTML(stage.title)}</strong><span>${escapeHTML(stage.summary)}</span>`;
    section.append(item);
  }
  els.workflowList.append(section);
}

function renderWorkflowDiagram() {
  els.workflowDiagram.innerHTML = "";
  for (const [stageIndex, stage] of WORKFLOW_STAGES.entries()) {
    const stageEl = document.createElement("section");
    stageEl.className = "workflow-stage";
    const heading = document.createElement("div");
    heading.className = "workflow-stage-heading";
    heading.innerHTML = `<h3>${escapeHTML(stage.title)}</h3><p>${escapeHTML(stage.summary)}</p>`;
    const steps = document.createElement("div");
    steps.className = "workflow-steps";
    for (const [stepIndex, step] of stage.steps.entries()) {
      const stepEl = document.createElement("article");
      stepEl.className = `workflow-step workflow-kind-${step.kind}`;
      stepEl.innerHTML = [
        `<div class="workflow-step-top"><span class="workflow-number">${stageIndex + 1}.${stepIndex + 1}</span>${workflowBadge(step.kind)}</div>`,
        `<h4>${escapeHTML(step.label)}</h4>`,
        `<p>${escapeHTML(step.description)}</p>`,
        `<div class="workflow-meta"><span>${escapeHTML(step.owner)}</span><strong>${escapeHTML(step.output)}</strong></div>`,
      ].join("");
      steps.append(stepEl);
      if (stepIndex < stage.steps.length - 1) {
        const connector = document.createElement("div");
        connector.className = "workflow-connector";
        connector.textContent = "then";
        steps.append(connector);
      }
    }
    stageEl.append(heading, steps);
    els.workflowDiagram.append(stageEl);
  }
}

function renderWorkflowLegend() {
  els.workflowLegend.innerHTML = "";
  for (const item of WORKFLOW_LEGEND) {
    const row = document.createElement("div");
    row.className = "workflow-legend-row";
    row.innerHTML = `${workflowBadge(item.kind)}<div><strong>${escapeHTML(item.label)}</strong><p>${escapeHTML(item.description)}</p></div>`;
    els.workflowLegend.append(row);
  }
}

function renderTouchpoints() {
  els.touchpointList.innerHTML = "";
  for (const [group, entries] of Object.entries(state.catalog)) {
    const section = document.createElement("section");
    const title = document.createElement("div");
    title.className = "group-title";
    title.textContent = group;
    section.append(title);

    for (const entry of entries) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "touchpoint-button";
      button.dataset.group = group;
      button.dataset.id = entry.id;
      button.textContent = entry.label;
      button.addEventListener("click", () => selectTouchpoint(group, entry.id));
      section.append(button);
    }
    els.touchpointList.append(section);
  }
}

async function loadGraphInspector() {
  if (state.graphs.length === 0) {
    state.graphs = PLANNED_GRAPHS;
    state.graphFixtures = graphFixturesWithMocks(state.graphFixtures);
    renderGraphs();
    selectGraph("prepare_initial_strategy");
    renderPlannedTimeline();
  }

  try {
    const [graphsPayload, fixturesPayload] = await Promise.all([
      requestJSON("/api/graphs"),
      requestJSON("/api/graph-fixtures"),
    ]);
    state.graphMetadata = graphsPayload;
    state.graphs = mergePlannedGraphs(graphsPayload.graphs ?? PLANNED_GRAPHS);
    state.graphFixtures = graphFixturesWithMocks(fixturesPayload.fixtures ?? []);
    renderGraphs();
    renderTraceBanner();
    renderGraphFixtures();
    if (!state.selectedGraph && state.graphs.length) {
      selectGraph("prepare_initial_strategy");
    } else if (state.selectedGraph) {
      selectGraph(state.selectedGraph.name);
    }
    renderPlannedTimeline();
    await loadGraphRuns();
  } catch (error) {
    state.graphs = state.graphs.length ? state.graphs : PLANNED_GRAPHS;
    state.graphFixtures = graphFixturesWithMocks(state.graphFixtures);
    renderGraphs();
    if (!state.selectedGraph) selectGraph("prepare_initial_strategy");
    els.graphRunStatus.textContent = `Using planned graph; live metadata unavailable (${error.message}).`;
    setGraphResult(null);
    renderTraceBanner(error.message);
    renderPlannedTimeline();
  }
}

function renderTraceBanner(errorMessage = "") {
  const traceLevel = state.graphMetadata?.traceLevel ?? "compact";
  if (errorMessage) {
    els.graphTraceBanner.className = "trace-banner warning";
    els.graphTraceBanner.textContent = `Live graph metadata unavailable: ${errorMessage}`;
    return;
  }
  const full = traceLevel === "full";
  els.graphTraceBanner.className = `trace-banner ${full ? "success" : "warning"}`;
  els.graphTraceBanner.textContent = full
    ? "Full trace mode is enabled. Prompt, schema, request payload, output, and knowledge refs can appear in node/tool detail."
    : "Compact trace mode is enabled. Run the training orchestrator with HAYF_OBSERVABILITY_TRACE_LEVEL=full to inspect exact prompts and schemas.";
}

async function loadGraphRuns() {
  try {
    const graphName = state.selectedGraph?.name;
    const durableGraph = graphName && graphName !== "prepare_initial_strategy" ? graphName : "all";
    const payload = await requestJSON(`/api/graph-runs?limit=25&graphName=${encodeURIComponent(durableGraph)}`);
    state.graphRuns = payload.runs ?? [];
    renderGraphRuns();
  } catch (error) {
    state.graphRuns = [];
    els.graphRunsTable.innerHTML = `<p class="muted-copy">${escapeHTML(error.message)}</p>`;
  }
}

function renderGraphRuns() {
  if (!state.graphRuns.length) {
    els.graphRunsTable.innerHTML = `<p class="muted-copy">No recent simulator runs found for this graph yet.</p>`;
    return;
  }
  els.graphRunsTable.innerHTML = state.graphRuns.map((run) => (
    `<article class="run-row ${run.graphRunID === state.selectedGraphRunID ? "active" : ""}">` +
    `<div class="run-card-main">` +
    `<strong title="${escapeHTML(run.goal ?? "")}">${escapeHTML(run.goal ?? "No goal title")}</strong>` +
    `<span>${escapeHTML(shortDateTime(run.createdAt))} · ${escapeHTML(run.graphName)}</span>` +
    `</div>` +
    `<div class="run-card-meta">` +
    `${statusBadge(run.status)}` +
    `<span>${escapeHTML([run.provider, run.model].filter(Boolean).join(" · ") || "n/a")}</span>` +
    `<span>${escapeHTML(run.durationMS == null ? "n/a" : `${run.durationMS} ms`)}</span>` +
    `</div>` +
    `<button type="button" data-graph-run-id="${escapeHTML(run.graphRunID)}">Open</button>` +
    `</article>`
  )).join("");
  for (const button of els.graphRunsTable.querySelectorAll("[data-graph-run-id]")) {
    button.addEventListener("click", () => loadGraphRun(button.dataset.graphRunId));
  }
}

function renderGraphs() {
  els.graphList.innerHTML = "";
  const section = document.createElement("section");
  const title = document.createElement("div");
  title.className = "group-title";
  title.textContent = "LangGraph";
  section.append(title);

  for (const graph of state.graphs) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "touchpoint-button";
    button.dataset.graph = graph.name;
    button.textContent = graph.label;
    button.addEventListener("click", () => {
      setMode("graphs");
      selectGraph(graph.name);
    });
    section.append(button);
  }
  els.graphList.append(section);
}

function selectGraph(name) {
  const graph = state.graphs.find((candidate) => candidate.name === name) ??
    state.graphs[0];
  if (!graph) return;
  const changedGraph = state.selectedGraph?.name !== graph.name;

  state.selectedGraph = graph;
  state.selectedNode = graph.nodes[0] ?? null;
  if (changedGraph) {
    els.graphFixtureJSONInput.value = "";
    els.graphFixtureNameInput.value = "";
  }
  els.graphEyebrow.textContent = graph.name;
  els.graphTitle.textContent = graph.label;
  els.graphPurpose.textContent = graph.purpose;
  renderGraphMap();
  renderNodeDetails();
  renderGraphFixtures();
  renderGraphOverrideTools();
  if (!state.lastGraphRun) renderPlannedTimeline();

  for (const button of document.querySelectorAll("[data-graph]")) {
    button.classList.toggle("active", button.dataset.graph === graph.name);
  }
  loadGraphRuns();
}

function renderGraphMap() {
  const graph = state.selectedGraph;
  els.graphMap.innerHTML = "";
  if (!graph) return;

  graph.nodes.forEach((node, index) => {
    const row = document.createElement("div");
    row.className = "graph-node-row";
    const number = document.createElement("div");
    number.className = "graph-index";
    number.textContent = String(index + 1);
    const button = document.createElement("button");
    button.type = "button";
    button.className = "graph-node";
    button.classList.toggle("active", state.selectedNode?.id === node.id);
    button.innerHTML = `<strong>${escapeHTML(node.label)}</strong><span>${escapeHTML(nodeStageLabel(node))}</span>`;
    button.addEventListener("click", () => {
      state.selectedNode = node;
      renderGraphMap();
      renderNodeDetails();
      renderGraphOverrideTools();
    });
    row.append(number, button);
    els.graphMap.append(row);

    const next = graph.edges.find((edge) => edge.from === node.id);
    if (next && next.to !== "__end__") {
      const edgeLabel = document.createElement("div");
      edgeLabel.className = "edge-label";
      edgeLabel.textContent = `then ${next.to}`;
      els.graphMap.append(edgeLabel);
    }
  });
}

function renderNodeDetails() {
  const node = state.selectedNode;
  if (!node) {
    els.nodeTitle.textContent = "Node";
    els.nodeKind.textContent = "Select a node.";
    els.nodeDetails.innerHTML = "";
    els.testToolButton.disabled = true;
    return;
  }

  els.nodeTitle.textContent = node.label;
  els.nodeKind.textContent = `${node.kind} · ${node.id}`;
  els.testToolButton.disabled = node.toolCalls.length === 0;
  els.testToolButton.textContent = node.toolCalls.length ? "Test First Tool" : "Test Tool";
  const latestNode = latestGraphNodeOutput(node.id);
  const latestTools = latestToolCalls(node);
  const latestNodeValue = latestNode?.output ?? latestNode?.structured_output_json ?? latestNode;
  state.graphReadableValue = latestNodeValue ?? latestTools[0] ?? null;
  state.graphReadableTitle = node.label;
  state.graphReadableSubtitle = latestNodeValue ? "Latest node output" : latestTools.length ? "Latest model trace" : "Planned node";
  els.readableGraphOutputButton.disabled = !state.graphReadableValue;
  els.nodeDetails.innerHTML = [
    detailBlock("Node Role", [
      `<p class="readable-copy lead-copy">${escapeHTML(node.purpose)}</p>`,
      fieldGrid([
        ["Kind", nodeStageLabel(node)],
        ["Input", node.inputContract],
        ["Output", node.outputContract],
      ]),
    ].join("")),
    detailBlock("Tool calls", toolButtons(node.toolCalls)),
    detailBlock("Knowledge refs", pillRow(node.knowledgeRefs)),
    detailBlock("How to use this", `<span>${escapeHTML(nodeHelpText(node))}</span>`),
    latestNode
      ? detailBlock("Latest node output", readableHTML(latestNodeValue) + advancedJSONSection("Advanced node JSON", latestNode))
      : detailBlock("Latest node output", "<span>No run output yet.</span>"),
    latestTools.length
      ? detailBlock("Latest model trace", latestTools.map((tool) => graphToolCard(tool)).join(""))
      : detailBlock("Latest model trace", "<span>No model call captured yet.</span>"),
  ].join("");
  for (const button of els.nodeDetails.querySelectorAll("[data-tool-name]")) {
    button.addEventListener("click", () => testSelectedTool(button.dataset.toolName));
  }
}

function renderGraphFixtures() {
  const graph = state.selectedGraph;
  const fixtures = graph ? fixturesForGraph(graph.name) : state.graphFixtures;
  els.graphFixtureInput.innerHTML = "";

  if (fixtures.length === 0) {
    const option = document.createElement("option");
    option.value = "";
    option.textContent = "Default planning packet";
    els.graphFixtureInput.append(option);
    if (!els.graphFixtureJSONInput.value.trim()) {
      els.graphFixtureJSONInput.value = JSON.stringify(defaultGraphFixture(), null, 2);
      els.graphFixtureNameInput.value = "default-planning-packet";
    }
    renderGraphFixtureSummary();
    return;
  }

  fixtures.forEach((fixture) => {
    const index = state.graphFixtures.indexOf(fixture);
    const option = document.createElement("option");
    option.value = String(index);
    option.textContent = fixture.name;
    option.title = fixture.description ?? "";
    els.graphFixtureInput.append(option);
  });

  const first = fixtures[0];
  els.graphFixtureInput.value = String(state.graphFixtures.indexOf(first));
  if (!els.graphFixtureJSONInput.value.trim()) {
    els.graphFixtureJSONInput.value = JSON.stringify(first.fixture, null, 2);
    els.graphFixtureNameInput.value = slugify(first.name);
  }
  renderGraphFixtureSummary();
}

function renderGraphOverrideTools() {
  const tools = state.selectedNode?.toolCalls ?? [];
  els.graphOverrideToolInput.innerHTML = "";
  if (!tools.length) {
    const option = document.createElement("option");
    option.value = "";
    option.textContent = "No model tool on selected node";
    els.graphOverrideToolInput.append(option);
    state.selectedGraphTool = null;
    return;
  }
  for (const tool of tools) {
    const option = document.createElement("option");
    option.value = tool;
    option.textContent = tool;
    els.graphOverrideToolInput.append(option);
  }
  if (!state.selectedGraphTool || !tools.includes(state.selectedGraphTool)) {
    state.selectedGraphTool = tools[0];
  }
  els.graphOverrideToolInput.value = state.selectedGraphTool;
}

function collectGraphToolOverrides(forTool = state.selectedGraphTool) {
  const toolName = forTool || els.graphOverrideToolInput.value;
  const model = els.graphOverrideModelInput.value.trim();
  const systemPrompt = els.graphOverrideSystemPromptInput.value.trim();
  if (!toolName || (!model && !systemPrompt)) return {};
  return {
    [toolName]: {
      ...(model ? { model } : {}),
      ...(systemPrompt ? { systemPrompt } : {}),
    },
  };
}

async function runSelectedGraph() {
  if (!state.selectedGraph) return;
  try {
    setBusy(true, "Running graph");
    const payload = await requestJSON("/api/graph-run", {
      method: "POST",
      body: {
        graphName: state.selectedGraph.name,
        fixture: parseJSONField(els.graphFixtureJSONInput, "Graph fixture JSON"),
        toolOverrides: collectGraphToolOverrides(),
      },
    });
    state.lastGraphRun = payload;
    els.graphRunStatus.textContent = `${payload.graphName} complete`;
    renderTimeline(payload);
    renderNodeDetails();
    setGraphResult(payload.artifact ?? payload.artifacts ?? payload, "", {
      title: `${payload.graphName ?? state.selectedGraph.label} output`,
      subtitle: "Graph run artifact",
    });
    setStatus("Graph run complete");
  } catch (error) {
    showGraphError(error);
  } finally {
    setBusy(false);
  }
}

async function loadGraphRunByID() {
  const graphRunID = els.graphRunIDInput.value.trim();
  if (!graphRunID) {
    showGraphError(new Error("Paste a graph run ID first."));
    return;
  }
  await loadGraphRun(graphRunID);
}

async function loadGraphRun(graphRunID) {
  try {
    setBusy(true, "Loading graph run");
    const payload = await requestJSON("/api/graph-run-status", {
      method: "POST",
      body: {
        graphRunID,
        includeTrace: true,
      },
    });
    const output = payload.output ?? payload;
    const graphName = output.graphName ?? output.graph_name;
    state.selectedGraphRunID = graphRunID;
    if (graphName) {
      const matchingGraph = state.graphs.find((graph) => graph.name === graphName);
      if (matchingGraph) selectGraph(matchingGraph.name);
    }
    state.lastGraphRun = output;
    els.graphRunStatus.textContent = `${graphName ?? "Graph run"} ${output.status ?? "loaded"}`;
    renderTimeline(output);
    renderNodeDetails();
    renderGraphRuns();
    setGraphResult(output.output ?? {
      trainingArchitecture: output.trainingArchitecture,
      fitnessStrategy: output.strategy,
    }, "", {
      title: `${graphName ?? "Graph run"} output`,
      subtitle: `Loaded run ${graphRunID}`,
    });
    setStatus("Graph run loaded");
  } catch (error) {
    showGraphError(error);
  } finally {
    setBusy(false);
  }
}

async function testSelectedTool(toolName = state.selectedNode?.toolCalls?.[0]) {
  if (!toolName) return;
  try {
    setBusy(true, "Testing tool");
    const payload = await requestJSON("/api/graph-tool-test", {
      method: "POST",
      body: {
        toolName,
        fixture: parseJSONField(els.graphFixtureJSONInput, "Graph fixture JSON"),
        toolOverrides: collectGraphToolOverrides(toolName),
      },
    });
    setGraphResult(payload, "", {
      title: payload.toolName ?? toolName,
      subtitle: `${payload.graphNodeName ?? state.selectedNode?.id ?? "tool"} test`,
    });
    els.graphRunStatus.textContent = `${payload.toolName} ${payload.status}`;
    setStatus("Tool test complete");
  } catch (error) {
    showGraphError(error);
  } finally {
    setBusy(false);
  }
}

async function saveGraphFixture() {
  if (!state.selectedGraph) return;
  try {
    setBusy(true, "Saving graph fixture");
    const payload = await requestJSON("/api/graph-fixtures", {
      method: "POST",
      body: {
        graphName: state.selectedGraph.name,
        name: els.graphFixtureNameInput.value,
        fixture: parseJSONField(els.graphFixtureJSONInput, "Graph fixture JSON"),
      },
    });
    state.graphFixtures = graphFixturesWithMocks(payload.fixtures ?? []);
    renderGraphFixtures();
    setStatus("Graph fixture saved");
  } catch (error) {
    showGraphError(error);
  } finally {
    setBusy(false);
  }
}

function renderTimeline(payload) {
  els.graphTimeline.innerHTML = "";
  const nodes = payload.nodes ?? [];
  const tools = payload.toolCalls ?? payload.tool_calls ?? [];
  for (const [index, node] of nodes.entries()) {
    const item = document.createElement("div");
    item.className = `timeline-item ${node.status === "failed" ? "failed" : ""}`;
    const nodeName = node.node_name ?? node.nodeName ?? "node";
    item.innerHTML = `<strong>${index + 1}. ${escapeHTML(nodeName)}</strong><span>${escapeHTML(node.status ?? "succeeded")}</span>`;
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = "Inspect";
    button.addEventListener("click", () => {
      const matched = state.selectedGraph?.nodes.find((candidate) => candidate.id === nodeName);
      if (matched) {
        inspectGraphNode(matched, { scroll: false });
      }
      setGraphResult(node.output ?? node.structured_output_json ?? node, "", {
        title: matched?.label ?? nodeName,
        subtitle: `${node.status ?? "succeeded"} node output`,
      });
      document.querySelector(".node-panel")?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    item.append(button);
    els.graphTimeline.append(item);
  }
  for (const tool of tools) {
    const item = document.createElement("div");
    item.className = `timeline-item ${tool.status === "failed" ? "failed" : ""}`;
    item.innerHTML = `<strong>${escapeHTML(tool.tool_name ?? tool.toolName ?? "tool")}</strong><span>${escapeHTML(tool.graph_node_name ?? tool.graphNodeName ?? "model call")} · ${escapeHTML(String(tool.latency_ms ?? tool.latencyMS ?? "n/a"))} ms</span>`;
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = "Inspect";
    button.addEventListener("click", () => {
      const toolNode = tool.graph_node_name ?? tool.graphNodeName;
      const matched = state.selectedGraph?.nodes.find((candidate) => candidate.id === toolNode);
      if (matched) {
        inspectGraphNode(matched, { scroll: false });
      }
      setGraphResult(tool, "", {
        title: tool.tool_name ?? tool.toolName ?? "Model call",
        subtitle: `${toolNode ?? "model call"} trace`,
      });
      document.querySelector(".node-panel")?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    item.append(button);
    els.graphTimeline.append(item);
  }
}

function renderPlannedTimeline() {
  if (state.lastGraphRun) return;
  const graph = state.selectedGraph;
  els.graphTimeline.innerHTML = "";
  if (!graph) return;

  els.graphRunStatus.textContent = "Planned sequence; run to replace with live node answers.";
  for (const [index, node] of graph.nodes.entries()) {
    const item = document.createElement("div");
    item.className = "timeline-item planned";
    item.classList.toggle("active", state.selectedNode?.id === node.id);
    item.innerHTML = `<strong>${index + 1}. ${escapeHTML(node.label)}</strong><span>${escapeHTML(nodeStageLabel(node))}</span><p>${escapeHTML(node.purpose)}</p>`;
    item.addEventListener("click", () => inspectGraphNode(node, { scroll: false }));
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = "Inspect planned node";
    button.addEventListener("click", (event) => {
      event.stopPropagation();
      inspectGraphNode(node, { scroll: true });
    });
    item.append(button);
    if (node.toolCalls?.length) {
      const toolList = document.createElement("div");
      toolList.className = "tool-button-list timeline-tools";
      for (const tool of node.toolCalls) {
        const toolButton = document.createElement("button");
        toolButton.type = "button";
        toolButton.textContent = `Test ${tool}`;
        toolButton.addEventListener("click", (event) => {
          event.stopPropagation();
          inspectGraphNode(node, { scroll: false });
          testSelectedTool(tool);
        });
        toolList.append(toolButton);
      }
      item.append(toolList);
    }
    els.graphTimeline.append(item);
  }
}

function selectTouchpoint(group, id) {
  const entry = findEntry(group, id);
  if (!entry) return;

  state.selected = { group, id };
  state.dirty = false;
  els.groupLabel.textContent = group;
  els.touchpointTitle.textContent = entry.label;
  els.labelInput.value = entry.label ?? id;
  els.modelInput.value = entry.effectiveModel ?? state.defaultModel;
  els.reasoningInput.value = entry.reasoning?.effort ?? "";
  els.verbosityInput.value = entry.text?.verbosity ?? "";
  els.parametersInput.value = JSON.stringify(entry.parameters ?? {}, null, 2);
  els.systemPromptInput.value = entry.systemPrompt ?? "";
  els.userRulesInput.value = entry.userRules ?? "";
  renderMockFixtures();
  renderEvalHistory();
  els.resultOutput.textContent = "";
  els.promptReadableOutput.innerHTML = "";
  els.promptRequestSummary.innerHTML = "";
  els.saveEvalButton.disabled = true;
  state.lastPromptRun = null;
  setStatus("Ready");

  for (const button of document.querySelectorAll(".touchpoint-button")) {
    button.classList.toggle(
      "active",
      button.dataset.group === group && button.dataset.id === id,
    );
  }
}

function renderMockFixtures() {
  const fixtures = currentMockFixtures();
  els.mockFixtureInput.innerHTML = "";

  if (fixtures.length === 0) {
    const option = document.createElement("option");
    option.value = "";
    option.textContent = "No mock fixture";
    els.mockFixtureInput.append(option);
    els.fixtureInput.value = JSON.stringify(
      {
        task: state.selected.id,
        context: {},
        candidates: [],
      },
      null,
      2,
    );
    els.fixtureNameInput.value = "";
    renderFixtureSummary();
    return;
  }

  fixtures.forEach((fixture, index) => {
    const option = document.createElement("option");
    option.value = String(index);
    option.textContent = fixture.name;
    option.title = fixture.description;
    els.mockFixtureInput.append(option);
  });

  els.mockFixtureInput.value = "0";
  els.fixtureInput.value = JSON.stringify(fixtures[0].fixture, null, 2);
  els.fixtureNameInput.value = slugify(fixtures[0].name);
  renderFixtureSummary();
}

function currentMockFixtures() {
  if (!state.selected) return [];
  return state.mockFixtures.filter((fixture) =>
    fixture.group === state.selected.group && fixture.id === state.selected.id
  );
}

function renderFixtureSummary() {
  const fixture = safeParseJSON(els.fixtureInput.value) ?? {};
  els.fixtureSummary.innerHTML = summaryCards(fixtureSummary(fixture));
}

function renderGraphFixtureSummary() {
  const fixture = safeParseJSON(els.graphFixtureJSONInput.value) ?? {};
  const packet = fixture.planningPacket ?? fixture.planning_packet ?? fixture;
  const goal = packet.goal_context ?? {};
  const constraints = packet.planning_constraints ?? {};
  els.graphFixtureSummary.innerHTML = summaryCards({
    Goal: goal.normalized_goal?.title ?? "No goal title",
    Kind: goal.goal_kind ?? "n/a",
    Modalities: (goal.selected_modality_order ?? constraints.feasible_modalities ?? []).join(", ") || "n/a",
    Frequency: constraints.frequency ?? "n/a",
  });
}

function fixtureSummary(fixture) {
  const context = fixture?.context ?? fixture ?? {};
  const summary = fixture?.summary ?? {};
  return {
    Task: fixture?.task ?? summary.task ?? state.selected?.id ?? "n/a",
    Goal: summary.title ?? context.normalizedGoal?.title ?? context.goal?.title ?? context.goal_context?.normalized_goal?.title ?? "No goal title",
    Modalities: (summary.selectedModalities ?? context.selectedModalities ?? context.onboardingSignals?.selectedModalities ?? context.goal_context?.selected_modality_order ?? []).join(", ") || "n/a",
    Frequency: summary.frequency ?? context.frequency ?? context.planning_constraints?.frequency ?? "n/a",
    Candidates: String(summary.candidateCount ?? fixture?.candidates?.length ?? 0),
  };
}

function summaryCards(entries) {
  return Object.entries(entries).map(([label, value]) => (
    `<div class="summary-card"><span>${escapeHTML(label)}</span><strong>${escapeHTML(value ?? "n/a")}</strong></div>`
  )).join("");
}

async function loadEvalHistory() {
  try {
    const payload = await requestJSON("/api/evals");
    state.evals = payload.evals ?? [];
    renderEvalHistory();
  } catch (error) {
    els.evalHistory.innerHTML = `<p class="muted-copy">${escapeHTML(error.message)}</p>`;
  }
}

function renderEvalHistory() {
  const selection = state.selected;
  const evals = selection
    ? state.evals.filter((item) => item.group === selection.group && item.touchpointID === selection.id).slice(0, 8)
    : state.evals.slice(0, 8);
  if (!evals.length) {
    els.evalHistory.innerHTML = `<p class="muted-copy">No saved evals for this touchpoint yet.</p>`;
    return;
  }
  els.evalHistory.innerHTML = evals.map((item) => (
    `<div class="eval-row">` +
    `<span class="rating rating-${escapeHTML(item.rating)}">${escapeHTML(item.rating)}</span>` +
    `<strong>${escapeHTML(shortDateTime(item.createdAt))}</strong>` +
    `<p>${escapeHTML(item.notes || item.fixtureSummary?.title || item.fixtureSummary?.Task || "No notes")}</p>` +
    `</div>`
  )).join("");
}

async function saveCurrent() {
  const selection = requireSelection();
  if (!selection) return;

  try {
    setBusy(true, "Saving");
    const payload = await requestJSON("/api/save", {
      method: "POST",
      body: {
        ...selection,
        config: collectConfig(),
      },
    });
    state.catalog = payload.catalog.catalog ?? payload.catalog;
    renderTouchpoints();
    selectTouchpoint(selection.group, selection.id);
    els.resultOutput.textContent = formatJSON(payload.check);
    els.diffOutput.textContent = payload.diff || "No diff.";
    setStatus(payload.ok ? "Saved" : "Saved, check failed");
  } catch (error) {
    showError(error);
  } finally {
    setBusy(false);
  }
}

async function runCurrent() {
  const selection = requireSelection();
  if (!selection) return;

  try {
    setBusy(true, "Running");
    const payload = await requestJSON("/api/test", {
      method: "POST",
      body: {
        ...selection,
        config: collectConfig(),
        fixture: parseJSONField(els.fixtureInput, "Fixture JSON"),
      },
    });
    state.lastPromptRun = payload;
    els.resultOutput.textContent = formatJSON(payload);
    renderPromptRun(payload);
    els.saveEvalButton.disabled = false;
    setStatus(
      payload.ok ? `Run complete in ${payload.latencyMS} ms` : "Run failed",
    );
  } catch (error) {
    showError(error);
  } finally {
    setBusy(false);
  }
}

function renderPromptRun(payload) {
  const output = payload.parsedOutput ?? payload.outputText ?? payload.error ?? payload.raw;
  els.promptReadableOutput.innerHTML = readablePromptOutput(output, payload);
  els.promptRequestSummary.innerHTML = summaryCards({
    Model: payload.requestSummary?.model ?? "n/a",
    Schema: payload.requestSummary?.schemaName ?? "none",
    Latency: payload.latencyMS == null ? "n/a" : `${payload.latencyMS} ms`,
    Status: payload.ok ? "ok" : `failed ${payload.status ?? ""}`.trim(),
  });
}

async function saveEval() {
  const selection = requireSelection();
  if (!selection || !state.lastPromptRun) return;
  try {
    setBusy(true, "Saving eval");
    const fixture = parseJSONField(els.fixtureInput, "Fixture JSON");
    const payload = await requestJSON("/api/evals", {
      method: "POST",
      body: {
        ...selection,
        touchpointID: selection.id,
        rating: els.evalRatingInput.value,
        notes: els.evalNotesInput.value,
        config: collectConfig(),
        fixture,
        request: state.lastPromptRun.request,
        requestSummary: state.lastPromptRun.requestSummary,
        output: state.lastPromptRun.parsedOutput ?? state.lastPromptRun.outputText,
        raw: state.lastPromptRun.raw,
        latencyMS: state.lastPromptRun.latencyMS,
        status: state.lastPromptRun.status,
      },
    });
    state.evals = payload.evals ?? [];
    els.evalNotesInput.value = "";
    renderEvalHistory();
    setStatus("Eval saved");
  } catch (error) {
    showError(error);
  } finally {
    setBusy(false);
  }
}

async function saveFixture() {
  const selection = requireSelection();
  if (!selection) return;

  try {
    setBusy(true, "Saving fixture");
    const payload = await requestJSON("/api/fixtures", {
      method: "POST",
      body: {
        ...selection,
        name: els.fixtureNameInput.value,
        fixture: parseJSONField(els.fixtureInput, "Fixture JSON"),
      },
    });
    els.resultOutput.textContent = formatJSON(payload);
    setStatus("Fixture saved");
  } catch (error) {
    showError(error);
  } finally {
    setBusy(false);
  }
}

async function refreshDiff() {
  try {
    const payload = await requestJSON("/api/diff");
    els.diffOutput.textContent = payload.diff || "No diff.";
  } catch (error) {
    els.diffOutput.textContent = error.message;
  }
}

function collectConfig() {
  const parameters = parseJSONField(els.parametersInput, "Parameters JSON");
  return {
    label: els.labelInput.value,
    model: els.modelInput.value,
    parameters,
    reasoning: els.reasoningInput.value
      ? { effort: els.reasoningInput.value }
      : undefined,
    text: els.verbosityInput.value
      ? { verbosity: els.verbosityInput.value }
      : undefined,
    systemPrompt: els.systemPromptInput.value,
    userRules: els.userRulesInput.value,
  };
}

function parseJSONField(element, label) {
  try {
    const value = element.value.trim();
    return value ? JSON.parse(value) : {};
  } catch (error) {
    throw new Error(`${label} is invalid JSON: ${error.message}`);
  }
}

function safeParseJSON(value) {
  try {
    return value?.trim() ? JSON.parse(value) : {};
  } catch {
    return null;
  }
}

function shortDateTime(value) {
  if (!value) return "n/a";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "n/a";
  return date.toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function statusBadge(status) {
  return `<span class="status-pill status-${escapeHTML(status ?? "unknown")}">${escapeHTML(status ?? "unknown")}</span>`;
}

function findEntry(group, id) {
  return state.catalog?.[group]?.find((entry) => entry.id === id);
}

function requireSelection() {
  if (!state.selected) {
    showError(new Error("Select a touchpoint first."));
    return null;
  }
  return state.selected;
}

async function requestJSON(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers ?? {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const text = await response.text();
  const payload = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(payload.error ?? `Request failed: ${response.status}`);
  }
  return payload;
}

function formatJSON(value) {
  return JSON.stringify(value, null, 2);
}

function setGraphResult(value, fallbackText = "", options = {}) {
  state.graphReadableValue = value;
  state.graphReadableTitle = options.title ?? readableTitle(value);
  state.graphReadableSubtitle = options.subtitle ?? readableSubtitle(value);
  els.readableGraphOutputButton.disabled = !value;
  if (!value) {
    if (fallbackText) {
      els.nodeTitle.textContent = "Graph Inspector";
      els.nodeKind.textContent = "Error";
      els.nodeDetails.innerHTML = readableSection(
        "Run Error",
        `<p class="readable-copy">${escapeHTML(fallbackText)}</p>`,
      );
    }
    return;
  }
  els.nodeTitle.textContent = state.graphReadableTitle;
  els.nodeKind.textContent = state.graphReadableSubtitle;
  els.nodeDetails.innerHTML = [
    graphResultContext(value),
    readableHTML(value),
    advancedJSONSection("Advanced JSON", value),
  ].join("");
}

function openReadableGraphModal() {
  if (!state.graphReadableValue) return;
  els.readableGraphTitle.textContent = state.graphReadableTitle || readableTitle(state.graphReadableValue);
  els.readableGraphContent.innerHTML = [
    readableHTML(state.graphReadableValue),
    advancedJSONSection("Advanced JSON", state.graphReadableValue),
  ].join("");
  els.readableGraphModal.classList.remove("hidden");
}

function closeReadableGraphModal() {
  els.readableGraphModal.classList.add("hidden");
}

function readableTitle(value) {
  if (!value) return "Graph Inspector";
  if (value.toolName) return value.toolName;
  if (value.tool_name) return value.tool_name;
  if (value.plannedNode?.label) return value.plannedNode.label;
  if (value.graphName) return value.graphName;
  if (value.priority_order || value.modality_roles) return "Training Architecture";
  if (value.read || value.strategyRead || value.strategyTargets || value.targets) return "Fitness Strategy";
  return "Graph Result";
}

function readableSubtitle(value) {
  if (!value || typeof value !== "object") return "Readable output";
  if (value.status) return `${value.status} · readable output`;
  if (value.tool_name || value.toolName) return "Model call trace";
  if (value.priority_order || value.modality_roles) return "Architecture synthesis";
  if (value.read || value.strategyRead || value.strategyTargets || value.targets) return "Strategy artifact";
  return "Readable output";
}

function graphResultContext(value) {
  if (!value || typeof value !== "object") return "";
  const request = value.request_json ?? value.request ?? value.input;
  const entries = [
    ["Tool", value.tool_name ?? value.toolName],
    ["Node", value.graph_node_name ?? value.graphNodeName ?? value.node_name ?? value.nodeName],
    ["Model", value.model ?? request?.model],
    ["Status", value.status],
    ["Latency", value.latency_ms ?? value.latencyMS ? `${value.latency_ms ?? value.latencyMS} ms` : null],
  ];
  return entries.some(([, entry]) => entry !== undefined && entry !== null && entry !== "")
    ? readableSection("Run Context", fieldGrid(entries))
    : "";
}

function readableHTML(value) {
  if (value.toolName && value.output) return readableToolTest(value);
  if (value.tool_name && value.output) return readableToolCall(value);
  if (value.plannedNode) return readablePlannedNode(value);
  if (value.trainingArchitecture || value.fitnessStrategy || value.strategy) return readableArtifactBundle(value);
  if (isArchitectureArtifact(value)) return readableArchitecture(value);
  if (isFitnessStrategyArtifact(value)) return readableFitnessStrategy(value);
  if (isValidationArtifact(value)) return readableValidation(value);
  return readableGeneric(value);
}

function readablePromptOutput(value, payload = {}) {
  if (payload.error) {
    return readableSection("Run Error", `<p class="readable-copy">${escapeHTML(payload.error)}</p>`);
  }
  if (!value) {
    return readableSection("Output", `<p class="readable-copy">No structured output text returned.</p>`);
  }
  if (value.readback) {
    return readableSection("Readback", `<p class="readable-copy lead-copy">${escapeHTML(value.readback)}</p>`);
  }
  if (isArchitectureArtifact(value)) return readableArchitecture(value);
  if (isFitnessStrategyArtifact(value)) return readableFitnessStrategy(value);
  if (isValidationArtifact(value)) return readableValidation(value);
  if (value && typeof value === "object" && ("recommended_role" in value || "archetype_proposals" in value)) {
    return specialistSection(value);
  }
  if (Array.isArray(value.candidates) && value.candidates.some((candidate) => "timeframeWeeks" in candidate)) {
    return readableSection("Goal Candidates", cardList(value.candidates.map((candidate) => ({
      title: candidate.title,
      meta: `${candidate.timeframeWeeks ?? "?"} weeks`,
      body: candidate.rationale,
      footer: candidate.tracking,
    }))));
  }
  if (value.coachRead || value.athleteArchetype || value.goalFit) {
    return [
      readableSection("Coach Read", `<p class="readable-copy lead-copy">${escapeHTML(value.coachRead ?? "")}</p>`),
      readableSection("Athlete", fieldGrid([
        ["Archetype", value.athleteArchetype?.label],
        ["Training state", value.currentTrainingState?.label],
        ["Baseline", value.physicalBaseline?.label],
        ["Goal fit", value.goalFit?.headline],
      ])),
      readableSection("Findings", readableList((value.historyFindings ?? []).map((item) => `${item.title}: ${item.summary}`))),
      value.goalFit?.summary ? readableSection("Goal Fit", `<p class="readable-copy">${escapeHTML(value.goalFit.summary)}</p>`) : "",
    ].join("");
  }
  if (Array.isArray(value.strategyTargets)) {
    return readableSection("Strategy Targets", cardList(value.strategyTargets.map((target) => ({
      title: target.title,
      meta: [target.proposedDisplayValue, target.family, target.modality].filter(Boolean).join(" · "),
      body: target.summary,
      footer: target.rationale,
    }))));
  }
  if (value.strategyRead || value.goalTargetContext || value.strategyPillars) {
    return [
      readableSection("Strategy Read", `<p class="readable-copy lead-copy">${escapeHTML(value.strategyRead ?? "")}</p>`),
      readableSection("Goal Context", fieldGrid([
        ["Title", value.goalTargetContext?.title],
        ["Summary", value.goalTargetContext?.summary],
      ])),
      readableSection("Pillars", readableList((value.strategyPillars ?? []).map((pillar) => `${pillar.title}: ${pillar.summary}`))),
      value.operatingRhythm ? readableSection("Operating Rhythm", `<p class="readable-copy">${escapeHTML(value.operatingRhythm.summary)}</p>${readableList(value.operatingRhythm.anchors)}`) : "",
    ].join("");
  }
  if (Array.isArray(value.candidates)) {
    return readableSection("Candidates", cardList(value.candidates.map((candidate) => ({
      title: candidate.title,
      meta: [candidate.activityType, `${candidate.durationMinutes ?? "?"} min`, candidate.intensityLabel].filter(Boolean).join(" · "),
      body: candidate.purpose,
      footer: candidate.rationale ?? candidate.weeklyImpact,
    }))));
  }
  if (value.candidate) {
    return readableSection("Candidate", cardList([{
      title: value.candidate.title,
      meta: [value.candidate.activityType, `${value.candidate.durationMinutes ?? "?"} min`, value.candidate.intensityLabel].filter(Boolean).join(" · "),
      body: value.candidate.purpose,
      footer: value.candidate.rationale ?? value.candidate.weeklyImpact,
    }]));
  }
  if (Array.isArray(value.weeks)) {
    return readableSection("Weekly Targets", cardList(value.weeks.flatMap((week) =>
      (week.targets ?? []).map((target) => ({
        title: target.title,
        meta: [week.weeklyPlanID, target.proposedDisplayValue, target.family].filter(Boolean).join(" · "),
        body: target.summary,
        footer: target.rationale,
      }))
    )));
  }
  if (value.block || value.rhythms) {
    return readableSection("Plan", readableObjectSummary({
      title: value.block?.title,
      goal: value.block?.goalText,
      weeks: value.rhythms?.length,
      phases: value.phases?.length,
    })) + readableSection("Week Objectives", readableList((value.rhythms ?? []).map((week) => `${week.weekStartDate}: ${week.objective}`)));
  }
  return readableGeneric(value);
}

function isArchitectureArtifact(value) {
  return Boolean(value && typeof value === "object" && (value.priority_order || value.modality_roles || value.approved_archetypes));
}

function isFitnessStrategyArtifact(value) {
  return Boolean(value && typeof value === "object" && (
    value.read ||
    value.strategyRead ||
    value.targets ||
    value.strategyTargets ||
    value.pillars ||
    value.strategyPillars ||
    value.phases ||
    value.phaseOutline ||
    value.goalTargetContext
  ));
}

function isValidationArtifact(value) {
  return Boolean(value && typeof value === "object" && (
    "valid" in value ||
    value.validation ||
    value.errors ||
    value.issues ||
    value.warnings
  ));
}

function cardList(items) {
  if (!items.length) return "<span>No items</span>";
  return `<div class="readable-card-list">${items.map((item) => (
    `<article class="readable-card">` +
    `<strong>${escapeHTML(item.title ?? "Untitled")}</strong>` +
    `${item.meta ? `<span>${escapeHTML(item.meta)}</span>` : ""}` +
    `${item.body ? `<p>${escapeHTML(item.body)}</p>` : ""}` +
    `${item.footer ? `<small>${escapeHTML(item.footer)}</small>` : ""}` +
    `</article>`
  )).join("")}</div>`;
}

function readableToolTest(value) {
  const output = value.output ?? {};
  return [
    readableSection("Run", fieldGrid([
      ["Tool", value.toolName],
      ["Node", value.graphNodeName],
      ["Status", value.status],
      ["Latency", `${value.latencyMS ?? "n/a"} ms`],
    ])),
    promptSection(value.request),
    readablePromptOutput(output),
  ].join("");
}

function readableToolCall(value) {
  const output = value.output ?? value.output_json ?? {};
  return [
    readableSection("Run", fieldGrid([
      ["Tool", value.tool_name ?? value.toolName],
      ["Node", value.graph_node_name ?? value.graphNodeName],
      ["Status", value.status],
      ["Latency", `${value.latency_ms ?? value.latencyMS ?? "n/a"} ms`],
    ])),
    promptSection(value.request_json ?? value.input),
    readablePromptOutput(output),
  ].join("");
}

function graphToolCard(tool) {
  const request = tool.request_json ?? tool.request ?? tool.input;
  const output = tool.output_json ?? tool.output;
  const knowledgeRefs = tool.knowledge_refs ?? tool.knowledgeRefs ?? request?.knowledgeRefs ?? [];
  return [
    `<article class="graph-tool-card">`,
    fieldGrid([
      ["Tool", tool.tool_name ?? tool.toolName],
      ["Node", tool.graph_node_name ?? tool.graphNodeName],
      ["Model", tool.model ?? request?.model],
      ["Status", tool.status],
      ["Latency", `${tool.latency_ms ?? tool.latencyMS ?? "n/a"} ms`],
    ]),
    promptSection(request),
    readableSection("Knowledge Files", knowledgeList(knowledgeRefs)),
    readableSection("Output", readablePromptOutput(output)),
    `<details class="advanced-block"><summary>Raw trace</summary><pre class="output readable-pre">${escapeHTML(formatJSON(tool))}</pre></details>`,
    `</article>`,
  ].join("");
}

function readablePlannedNode(value) {
  const node = value.plannedNode;
  return [
    readableSection("Planned Node", fieldGrid([
      ["Stage", node.stage],
      ["Input", node.inputContract],
      ["Output", node.outputContract],
    ])),
    readableSection("Purpose", `<p class="readable-copy">${escapeHTML(node.purpose)}</p>`),
    readableSection("Tool Calls", pillRow(node.toolCalls)),
    readableSection("Knowledge", pillRow(node.knowledgeRefs)),
    readableSection("Next Step", `<p class="readable-copy">${escapeHTML(value.nextStep)}</p>`),
  ].join("");
}

function specialistSection(output) {
  if (!output || typeof output !== "object" || !("recommended_role" in output || "archetype_proposals" in output)) {
    return readableSection("Output Summary", readableObjectSummary(output));
  }

  return [
    readableSection("Specialist Answer", fieldGrid([
      ["Coach", output.coach],
      ["Modality", output.modality],
      ["Recommended role", output.recommended_role],
      ["Intensity model", output.intensity_model],
    ]) + `<p class="readable-copy">${escapeHTML(output.rationale ?? "")}</p>`),
    readableSection("Weekly Dose", fieldGrid(Object.entries(output.weekly_dose ?? {}))),
    readableSection("Adaptation Priorities", readableList(output.adaptation_priorities)),
    readableSection("Performance Determinants", readableList(output.performance_determinants)),
    readableSection("Archetype Proposals", archetypeList(output.archetype_proposals)),
    readableSection("Fatigue Signals", readableList(output.fatigue_signals)),
    readableSection("Interference Rules", readableList(output.interference_rules)),
    readableSection("Common Mistakes", readableList(output.common_mistakes)),
    readableSection("Knowledge Refs", knowledgeList(output.knowledge_refs)),
  ].join("");
}

function readableArchitecture(value) {
  return [
    value.goal_read ? readableSection("Goal Read", fieldGrid([
      ["Summary", value.goal_read.summary],
      ["Goal kind", value.goal_read.goal_kind],
      ["Success", value.goal_read.success_definition],
    ])) : "",
    readableSection("Architecture", fieldGrid([
      ["Priority order", joinHuman(value.priority_order, " > ")],
      ["Conflict status", value.conflict_assessment?.status],
      ["Weekly target", value.weekly_budget?.target_sessions ? `${value.weekly_budget.target_sessions} sessions` : null],
      ["Hard sessions", value.weekly_budget?.hard_sessions],
      ["Recovery sessions", value.weekly_budget?.recovery_sessions],
      ["Minimum viable", value.weekly_budget?.minimum_viable_sessions ? `${value.weekly_budget.minimum_viable_sessions} sessions` : null],
    ])),
    value.conflict_assessment ? readableSection("Conflict Assessment", [
      `<p class="readable-copy">${escapeHTML(value.conflict_assessment.summary ?? "No conflict summary.")}</p>`,
      readableList(value.conflict_assessment.required_tradeoffs),
    ].join("")) : "",
    readableSection("Modality Roles", cardList((value.modality_roles ?? []).map((role) => ({
      title: role.modality,
      meta: role.role,
      body: role.rationale,
    })))),
    readableSection("Approved Archetypes", archetypeList(value.approved_archetypes)),
    value.deferred_specialist_recommendations?.length
      ? readableSection("Deferred Recommendations", dispositionList(value.deferred_specialist_recommendations))
      : "",
    value.rejected_specialist_recommendations?.length
      ? readableSection("Rejected Recommendations", dispositionList(value.rejected_specialist_recommendations))
      : "",
    readableSection("Recovery Rules", readableList([
      ...(value.recovery_envelope?.spacing_rules ?? []),
      value.recovery_envelope?.bad_day_floor ? `Bad day floor: ${value.recovery_envelope.bad_day_floor}` : null,
      value.recovery_envelope?.max_hard_days_per_week ? `Max hard days per week: ${value.recovery_envelope.max_hard_days_per_week}` : null,
    ].filter(Boolean))),
    readableSection("Minimum Effective Dose", readableList(value.minimum_effective_dose_rules)),
    readableSection("Progression Rules", readableList(value.progression_rules)),
    readableSection("Interference Rules", readableList(value.interference_rules)),
    readableSection("Knowledge Files", knowledgeList(value.source_knowledge_refs)),
  ].join("");
}

function readableArtifactBundle(value) {
  return [
    value.trainingArchitecture ? readableArchitecture(value.trainingArchitecture) : "",
    value.fitnessStrategy ? readableFitnessStrategy(value.fitnessStrategy) : "",
    value.strategy ? readableFitnessStrategy(value.strategy) : "",
  ].join("");
}

function readableFitnessStrategy(value) {
  const read = value.read ?? value.strategyRead;
  const targets = value.targets ?? value.strategyTargets ?? [];
  const pillars = value.pillars ?? value.strategyPillars ?? [];
  const phases = value.phases ?? value.phaseOutline ?? [];
  return [
    read ? readableSection("Strategy Read", `<p class="readable-copy lead-copy">${escapeHTML(read)}</p>`) : "",
    value.goalTargetContext ? readableSection("Goal Context", fieldGrid([
      ["Title", value.goalTargetContext.title],
      ["Summary", value.goalTargetContext.summary ?? value.goalTargetContextSummary],
    ])) : "",
    value.snapshotItems?.length ? readableSection("Snapshot", cardList(value.snapshotItems.map((item) => ({
      title: item.label ?? item.id,
      meta: item.value,
      body: item.systemImage,
    })))) : "",
    targets.length ? readableSection("Targets", targetList(targets)) : "",
    phases.length ? readableSection("Phases", phaseList(phases)) : "",
    value.fitReasons?.length ? readableSection("Fit Reasons", cardList(value.fitReasons.map((reason) => ({
      title: reason.title ?? reason.id,
      meta: reason.systemImage,
      body: reason.summary,
    })))) : "",
    pillars.length ? readableSection("Pillars", cardList(pillars.map((pillar) => ({
      title: pillar.title ?? pillar.id,
      body: pillar.summary,
    })))) : "",
    value.operatingRhythm ? readableSection("Operating Rhythm", [
      `<p class="readable-copy">${escapeHTML(value.operatingRhythm.summary ?? value.operatingRhythmSummary ?? "")}</p>`,
      readableList(value.operatingRhythm.anchors),
    ].join("")) : "",
  ].join("");
}

function readableValidation(value) {
  const validation = value.validation && typeof value.validation === "object" ? value.validation : value;
  return [
    readableSection("Validation", fieldGrid([
      ["Valid", validation.valid],
      ["Status", value.status],
      ["Summary", validation.summary ?? value.summary],
    ])),
    readableSection("Issues", readableList(validation.errors ?? value.errors ?? value.issues)),
    validation.warnings || value.warnings
      ? readableSection("Warnings", readableList(validation.warnings ?? value.warnings))
      : "",
  ].join("");
}

function readableGeneric(value) {
  return readableSection(genericTitle(value), readableObjectSummary(value));
}

function promptSection(request) {
  const input = Array.isArray(request?.input) ? request.input : [];
  const system = input.find((part) => part.role === "system")?.content ?? request?.systemPrompt;
  const user = input.find((part) => part.role === "user")?.content ?? request?.input;
  if (!system && !user) {
    return readableSection("Prompt", `<p class="readable-copy">Compact trace only. Enable full trace to see the exact prompt and request payload.</p>`);
  }
  return readableSection("Prompt", [
    system ? `<div class="readable-field"><span>System</span><p class="readable-copy">${escapeHTML(system)}</p></div>` : "",
    user ? `<details><summary>User payload</summary><pre class="output readable-pre">${escapeHTML(prettyPayload(user))}</pre></details>` : "",
  ].join(""));
}

function readableSection(title, body) {
  return `<section class="readable-section"><h3>${escapeHTML(title)}</h3>${body || "<span>No data</span>"}</section>`;
}

function fieldGrid(entries) {
  const fields = entries
    .filter(([, value]) => value !== undefined && value !== null && value !== "")
    .map(([label, value]) => (
      `<div class="readable-field"><span>${escapeHTML(label)}</span><strong>${escapeHTML(formatReadableValue(value))}</strong></div>`
    ))
    .join("");
  return fields ? `<div class="readable-grid">${fields}</div>` : "<span>No data</span>";
}

function readableList(items) {
  if (!Array.isArray(items) || items.length === 0) return "<span>None</span>";
  return `<ul class="readable-list">${items.map((item) => `<li>${escapeHTML(sentenceFromValue(item))}</li>`).join("")}</ul>`;
}

function archetypeList(archetypes) {
  if (!Array.isArray(archetypes) || archetypes.length === 0) return "<span>None</span>";
  return `<ul class="readable-list">${archetypes.map((item) => (
    `<li><strong>${escapeHTML(item.id ?? item.archetype_id ?? item.title ?? "Archetype")}</strong><br>` +
    `${escapeHTML(item.purpose ?? item.reason ?? item.rationale ?? "")}<br>` +
    `<span>${escapeHTML([item.modality, item.intensity_domain, item.fatigue_cost, item.phase_hint, durationLabel(item)].filter(Boolean).join(" · "))}</span></li>`
  )).join("")}</ul>`;
}

function knowledgeList(refs) {
  if (!Array.isArray(refs) || refs.length === 0) return "<span>None</span>";
  return `<ul class="readable-list">${refs.map((ref) => (
    `<li><strong>${escapeHTML(ref.id ?? ref)}</strong><br><span>${escapeHTML([ref.title, ref.version].filter(Boolean).join(" · "))}</span>${ref.path ? `<br><code>${escapeHTML(`services/training-orchestrator/src/knowledge/packs/${ref.path}`)}</code>` : ""}</li>`
  )).join("")}</ul>`;
}

function readableObjectSummary(value, depth = 0) {
  if (!value || typeof value !== "object") return `<p class="readable-copy">${escapeHTML(value ?? "No data")}</p>`;
  if (Array.isArray(value)) {
    if (!value.length) return "<span>None</span>";
    if (value.every((item) => typeof item !== "object" || item === null)) return readableList(value);
    return cardList(value.map((item, index) => objectToCard(item, `Item ${index + 1}`)));
  }
  const entries = Object.entries(value).filter(([, entry]) =>
    typeof entry === "string" || typeof entry === "number" || typeof entry === "boolean"
  );
  const scalarGrid = entries.length ? fieldGrid(entries.map(([key, entry]) => [humanLabel(key), entry])) : "";
  if (depth > 0) {
    return scalarGrid || `<p class="readable-copy">${escapeHTML(objectCardBody(value) || `Object with ${Object.keys(value).length} fields.`)}</p>`;
  }
  const nested = Object.entries(value)
    .filter(([, entry]) => entry && typeof entry === "object")
    .slice(0, 8)
    .map(([key, entry]) => (
      `<div class="readable-nested"><strong>${escapeHTML(humanLabel(key))}</strong>${readableObjectSummary(entry, depth + 1)}</div>`
    ))
    .join("");
  return scalarGrid || nested ? [scalarGrid, nested].join("") : "<span>No readable fields.</span>";
}

function advancedJSONSection(title, value) {
  return `<details class="advanced-block advanced-json"><summary>${escapeHTML(title)}</summary><pre class="output readable-pre">${escapeHTML(formatJSON(value))}</pre></details>`;
}

function targetList(targets) {
  return cardList((targets ?? []).map((target) => ({
    title: target.title ?? target.id ?? "Target",
    meta: [
      target.displayValue ?? target.proposedDisplayValue,
      target.direction,
      target.unit,
      target.family,
      target.modality,
      target.metricCategory,
    ].filter(Boolean).join(" · "),
    body: target.summary,
    footer: target.rationale,
  })));
}

function phaseList(phases) {
  return cardList((phases ?? []).map((phase) => ({
    title: phase.name ?? phase.title ?? phase.id ?? "Phase",
    meta: phase.targetSummary,
    body: phase.objective ?? phase.summary,
    footer: Array.isArray(phase.targets)
      ? phase.targets.map((target) => target.title ?? target.id).filter(Boolean).join(", ")
      : null,
  })));
}

function dispositionList(items) {
  return cardList((items ?? []).map((item) => ({
    title: item.archetype_id ?? item.id ?? item.modality ?? "Recommendation",
    meta: [item.modality, item.phase_hint].filter(Boolean).join(" · "),
    body: item.reason ?? item.rationale,
  })));
}

function genericTitle(value) {
  if (Array.isArray(value)) return "Items";
  if (!value || typeof value !== "object") return "Output";
  if (value.status || value.valid !== undefined) return "Status";
  return "Output Summary";
}

function joinHuman(value, separator = ", ") {
  return Array.isArray(value) ? value.map(formatReadableValue).join(separator) : formatReadableValue(value);
}

function formatReadableValue(value) {
  if (Array.isArray(value)) return value.map(formatReadableValue).join(", ");
  if (!value || typeof value !== "object") return String(value ?? "n/a");
  return value.title ?? value.name ?? value.label ?? value.id ?? value.summary ?? objectCardBody(value) ?? `Object with ${Object.keys(value).length} fields`;
}

function sentenceFromValue(value) {
  if (!value || typeof value !== "object") return String(value ?? "");
  const title = value.title ?? value.name ?? value.label ?? value.id ?? value.modality ?? value.archetype_id;
  const body = objectCardBody(value);
  return [title, body].filter(Boolean).join(": ");
}

function objectToCard(value, fallbackTitle) {
  if (!value || typeof value !== "object") {
    return { title: fallbackTitle, body: String(value ?? "") };
  }
  return {
    title: value.title ?? value.name ?? value.label ?? value.id ?? value.modality ?? value.archetype_id ?? fallbackTitle,
    meta: [
      value.status,
      value.role,
      value.kind,
      value.direction,
      value.displayValue ?? value.proposedDisplayValue,
      value.phase_hint,
    ].filter(Boolean).join(" · "),
    body: objectCardBody(value),
    footer: Array.isArray(value.knowledge_refs)
      ? value.knowledge_refs.map((ref) => ref.id ?? ref).filter(Boolean).join(", ")
      : null,
  };
}

function objectCardBody(value) {
  return value.summary ??
    value.rationale ??
    value.reason ??
    value.purpose ??
    value.objective ??
    value.read ??
    value.description ??
    null;
}

function humanLabel(value) {
  return String(value)
    .replace(/_/g, " ")
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function prettyPayload(value) {
  if (typeof value !== "string") return formatJSON(value);
  try {
    return formatJSON(JSON.parse(value));
  } catch {
    return value;
  }
}

function durationLabel(item) {
  const duration = item?.typical_duration_minutes;
  if (!duration) return null;
  return `${duration.min}-${duration.max} min`;
}

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(
    /^-+|-+$/g,
    "",
  );
}

function showError(error) {
  els.resultOutput.textContent = error.message;
  els.promptReadableOutput.innerHTML = readableSection("Error", `<p class="readable-copy">${escapeHTML(error.message)}</p>`);
  els.resultOutput.classList.add("error");
  setStatus("Error");
  window.setTimeout(() => els.resultOutput.classList.remove("error"), 1400);
}

function showGraphError(error) {
  const message = error.message === "Not found"
    ? "Graph API route not found. Restart the AI Touchpoint Lab server so /api/graphs, /api/graph-run, and /api/graph-tool-test are loaded."
    : error.message;
  setGraphResult(null, message);
  els.graphRunStatus.textContent = "Error";
  setStatus("Error");
}

function setStatus(text) {
  els.statusLine.textContent = text;
}

function setBusy(isBusy, label = "Working") {
  els.saveButton.disabled = isBusy;
  els.runButton.disabled = isBusy;
  els.saveFixtureButton.disabled = isBusy;
  els.saveEvalButton.disabled = isBusy || !state.lastPromptRun;
  els.runGraphButton.disabled = isBusy;
  els.refreshGraphRunsButton.disabled = isBusy;
  els.saveGraphFixtureButton.disabled = isBusy;
  els.loadGraphRunButton.disabled = isBusy;
  els.testToolButton.disabled = isBusy || !state.selectedNode?.toolCalls.length;
  if (isBusy) setStatus(label);
}

function mergePlannedGraphs(graphs) {
  const plannedByName = new Map(PLANNED_GRAPHS.map((graph) => [graph.name, graph]));
  const liveNames = new Set(graphs.map((graph) => graph.name));
  return [
    ...graphs.map((graph) => ({
      ...plannedByName.get(graph.name),
      ...graph,
      nodes: graph.nodes?.length ? graph.nodes : plannedByName.get(graph.name)?.nodes ?? [],
      edges: graph.edges?.length ? graph.edges : plannedByName.get(graph.name)?.edges ?? [],
    })),
    ...PLANNED_GRAPHS.filter((graph) => !liveNames.has(graph.name)),
  ];
}

function graphFixturesWithMocks(fixtures) {
  const seen = new Set();
  return [...MOCK_GRAPH_FIXTURES, ...fixtures].filter((fixture) => {
    const key = fixture.filename ?? `${fixture.graphName}:${fixture.name}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function fixturesForGraph(graphName) {
  return state.graphFixtures.filter((fixture) =>
    fixture.graphName === graphName ||
    (graphName === "prepare_initial_strategy" && fixture.graphName === "training_architecture")
  );
}

function nodeStageLabel(node) {
  const calls = node.toolCalls?.length ?? 0;
  if (node.kind === "fanout") return `worker fanout · ${calls} possible model calls`;
  if (node.id === "architect_synthesis") return "master coach · synthesis model call";
  if (node.kind === "model") return `model · ${calls} tool call${calls === 1 ? "" : "s"}`;
  if (node.kind === "composite") return "composite graph step";
  return "deterministic";
}

function inspectGraphNode(node, options = {}) {
  state.selectedNode = node;
  renderGraphMap();
  renderNodeDetails();
  renderGraphOverrideTools();
  if (!state.lastGraphRun) renderPlannedTimeline();
  if (options.scroll) {
    document.querySelector(".node-panel")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function toolButtons(toolCalls) {
  if (!toolCalls?.length) return "<span>No model-backed tool calls.</span>";
  return `<div class="tool-button-list">${toolCalls.map((tool) => (
    `<button type="button" data-tool-name="${escapeHTML(tool)}">Test ${escapeHTML(tool)}</button>`
  )).join("")}</div>`;
}

function nodeHelpText(node) {
  if (node.id === "specialist_consultations") {
    return "To test the cycling specialist: choose the Cycling specialist fixture, keep this Worker Specialists node selected, then click Test consult_cycling_specialist.";
  }
  if (node.id === "architect_synthesis") {
    return "Run the worker specialists first or use the graph run; this master coach call needs specialist outputs to synthesize.";
  }
  if (node.toolCalls?.length) {
    return "Use a tool button here to run the smallest graph context needed for that model-backed call.";
  }
  return "This planned step is deterministic; run the graph to see its live input summary and output.";
}

function latestGraphNodeOutput(nodeID) {
  const nodes = state.lastGraphRun?.nodes ?? [];
  return [...nodes].reverse().find((node) =>
    (node.node_name ?? node.nodeName) === nodeID
  );
}

function latestToolCalls(node) {
  const calls = state.lastGraphRun?.toolCalls ?? state.lastGraphRun?.tool_calls ?? [];
  return calls.filter((call) => {
    const callNode = call.graph_node_name ?? call.graphNodeName;
    return callNode === node.id ||
      node.toolCalls.includes(call.tool_name ?? call.toolName);
  });
}

function detailBlock(title, body) {
  return `<div class="detail-block"><strong>${escapeHTML(title)}</strong>${body}</div>`;
}

function pillRow(values) {
  if (!values?.length) return "<span>None</span>";
  return `<div class="pill-row">${values.map((value) => `<span class="pill">${escapeHTML(value)}</span>`).join("")}</div>`;
}

function escapeHTML(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[char]));
}

function defaultGraphFixture() {
  return graphFixtureFor({
    title: "Train consistently three times per week",
    desiredOutcome: "be consistent with cycling and strength",
    goalKind: "consistency",
    selectedModalities: ["Cycling", "Strength"],
    feasibleModalities: ["Cycling", "Strength"],
    frequency: "3 days per week",
    equipment: ["Gym", "Bike"],
    avoidances: ["Late night sessions"],
    modalityMix: { strength: 5, cycling: 3 },
  });
}

function graphFixtureFor(options) {
  return {
    planningPacket: {
      athlete_context: {
        blueprint_revision_id: "11111111-1111-1111-1111-111111111111",
        coach_read: "Durable recreational athlete with mixed training history.",
        athlete_archetype: { label: "durable_generalist" },
        current_training_state: { recentPattern: "two to four sessions weekly" },
        history_findings: [
          { label: "training_history", summary: "Moderate exposure across selected modalities." },
        ],
        goal_fit: { confidence: "medium" },
        hidden_inputs: { motivation: "health and capability" },
      },
      goal_context: {
        user_goal_id: "22222222-2222-2222-2222-222222222222",
        normalized_goal: {
          title: options.title,
          desiredOutcome: options.desiredOutcome,
        },
        goal_kind: options.goalKind,
        timeframe_weeks: options.goalKind === "consistency" ? null : 12,
        success_definition: options.desiredOutcome,
        selected_modality_order: options.selectedModalities,
        body_composition_intent: null,
      },
      planning_constraints: {
        feasible_modalities: options.feasibleModalities,
        frequency: options.frequency,
        session_length: "30-45 minutes",
        injuries: null,
        equipment_access: options.equipment,
        avoidances: options.avoidances,
        bad_day_floor: "10 minutes easy movement",
        timezone: "Europe/Berlin",
        start_date: "2026-07-13",
      },
      approved_evidence_summary: {
        recent_training_load: { sessions28d: 9 },
        consistency: { activeWeeks8w: 6 },
        modality_mix: options.modalityMix,
        body_recovery_context: { sleep: "unknown", bodyMassTrend: "stable" },
        confidence: "medium",
        caveats: ["Mock fixture; no raw HealthKit samples included."],
      },
      generation_policy: {
        visible_horizon_weeks: 2,
        committed_horizon_weeks: 1,
        allowed_claims: ["bounded planning", "evidence summaries only"],
        ai_first_plan_generation: true,
      },
    },
  };
}

function workflowStep(id, label, kind, description, owner, output) {
  return { id, label, kind, description, owner, output };
}

function workflowBadge(kind) {
  const item = WORKFLOW_LEGEND.find((candidate) => candidate.kind === kind);
  const label = item?.label ?? kind;
  return `<span class="workflow-badge workflow-badge-${escapeHTML(kind)}">${escapeHTML(label)}</span>`;
}

function plannedNode(
  id,
  label,
  kind,
  purpose,
  toolCalls,
  inputContract,
  outputContract,
  knowledgeRefs,
) {
  return { id, label, kind, purpose, toolCalls, inputContract, outputContract, knowledgeRefs };
}

function plannedEdge(from, to) {
  return { from, to };
}
