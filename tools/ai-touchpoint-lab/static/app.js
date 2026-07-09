const state = {
  catalog: null,
  mockFixtures: [],
  graphs: [],
  graphFixtures: [],
  selectedGraph: null,
  selectedNode: null,
  lastGraphRun: null,
  graphReadableValue: null,
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
  fixtureNameInput: document.querySelector("#fixtureNameInput"),
  fixtureInput: document.querySelector("#fixtureInput"),
  resultOutput: document.querySelector("#resultOutput"),
  diffOutput: document.querySelector("#diffOutput"),
  saveButton: document.querySelector("#saveButton"),
  runButton: document.querySelector("#runButton"),
  showDiffButton: document.querySelector("#showDiffButton"),
  refreshDiffButton: document.querySelector("#refreshDiffButton"),
  saveFixtureButton: document.querySelector("#saveFixtureButton"),
  touchpointModeButton: document.querySelector("#touchpointModeButton"),
  graphModeButton: document.querySelector("#graphModeButton"),
  touchpointWorkspace: document.querySelector("#touchpointWorkspace"),
  graphWorkspace: document.querySelector("#graphWorkspace"),
  graphList: document.querySelector("#graphList"),
  graphEyebrow: document.querySelector("#graphEyebrow"),
  graphTitle: document.querySelector("#graphTitle"),
  graphPurpose: document.querySelector("#graphPurpose"),
  refreshGraphsButton: document.querySelector("#refreshGraphsButton"),
  runGraphButton: document.querySelector("#runGraphButton"),
  graphMap: document.querySelector("#graphMap"),
  nodeTitle: document.querySelector("#nodeTitle"),
  nodeKind: document.querySelector("#nodeKind"),
  nodeDetails: document.querySelector("#nodeDetails"),
  testToolButton: document.querySelector("#testToolButton"),
  graphFixtureInput: document.querySelector("#graphFixtureInput"),
  graphFixtureNameInput: document.querySelector("#graphFixtureNameInput"),
  graphFixtureJSONInput: document.querySelector("#graphFixtureJSONInput"),
  saveGraphFixtureButton: document.querySelector("#saveGraphFixtureButton"),
  graphRunStatus: document.querySelector("#graphRunStatus"),
  graphTimeline: document.querySelector("#graphTimeline"),
  graphResultOutput: document.querySelector("#graphResultOutput"),
  readableGraphOutputButton: document.querySelector("#readableGraphOutputButton"),
  readableGraphModal: document.querySelector("#readableGraphModal"),
  readableGraphTitle: document.querySelector("#readableGraphTitle"),
  readableGraphContent: document.querySelector("#readableGraphContent"),
  closeReadableGraphButton: document.querySelector("#closeReadableGraphButton"),
};

await loadCatalog();
await loadGraphInspector();
wireEvents();
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
  els.touchpointModeButton.addEventListener("click", () => setMode("touchpoints"));
  els.graphModeButton.addEventListener("click", () => setMode("graphs"));
  els.refreshGraphsButton.addEventListener("click", loadGraphInspector);
  els.runGraphButton.addEventListener("click", runSelectedGraph);
  els.saveGraphFixtureButton.addEventListener("click", saveGraphFixture);
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
    setStatus(`Loaded ${fixture.name}`);
  });
  els.graphFixtureInput.addEventListener("change", () => {
    const fixture = state.graphFixtures[Number(els.graphFixtureInput.value)];
    if (!fixture) return;
    selectGraph(fixture.graphName);
    els.graphFixtureJSONInput.value = JSON.stringify(fixture.fixture, null, 2);
    els.graphFixtureNameInput.value = slugify(fixture.name ?? fixture.filename);
    setStatus(`Loaded ${fixture.name}`);
  });
}

function setMode(mode) {
  const graphMode = mode === "graphs";
  els.touchpointModeButton.classList.toggle("active", !graphMode);
  els.graphModeButton.classList.toggle("active", graphMode);
  els.touchpointWorkspace.classList.toggle("hidden", graphMode);
  els.touchpointList.classList.toggle("hidden", graphMode);
  els.graphWorkspace.classList.toggle("hidden", !graphMode);
  els.graphList.classList.toggle("hidden", !graphMode);
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
    state.graphs = mergePlannedGraphs(graphsPayload.graphs ?? PLANNED_GRAPHS);
    state.graphFixtures = graphFixturesWithMocks(fixturesPayload.fixtures ?? []);
    renderGraphs();
    renderGraphFixtures();
    if (!state.selectedGraph && state.graphs.length) {
      selectGraph("prepare_initial_strategy");
    } else if (state.selectedGraph) {
      selectGraph(state.selectedGraph.name);
    }
    renderPlannedTimeline();
  } catch (error) {
    state.graphs = state.graphs.length ? state.graphs : PLANNED_GRAPHS;
    state.graphFixtures = graphFixturesWithMocks(state.graphFixtures);
    renderGraphs();
    if (!state.selectedGraph) selectGraph("prepare_initial_strategy");
    els.graphRunStatus.textContent = `Using planned graph; live metadata unavailable (${error.message}).`;
    setGraphResult(null);
    renderPlannedTimeline();
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
  if (!state.lastGraphRun) renderPlannedTimeline();

  for (const button of document.querySelectorAll("[data-graph]")) {
    button.classList.toggle("active", button.dataset.graph === graph.name);
  }
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
  els.nodeDetails.innerHTML = [
    detailBlock("Purpose", `<span>${escapeHTML(node.purpose)}</span>`),
    detailBlock("Contracts", `<span>${escapeHTML(node.inputContract)} → ${escapeHTML(node.outputContract)}</span>`),
    detailBlock("Tool calls", toolButtons(node.toolCalls)),
    detailBlock("Knowledge refs", pillRow(node.knowledgeRefs)),
    detailBlock("How to use this", `<span>${escapeHTML(nodeHelpText(node))}</span>`),
    latestNode
      ? detailBlock("Latest node output", `<pre class="output">${escapeHTML(formatJSON(latestNode.output ?? latestNode.structured_output_json ?? latestNode))}</pre>`)
      : detailBlock("Latest node output", "<span>No run output yet.</span>"),
    latestTools.length
      ? detailBlock("Latest model trace", latestTools.map((tool) => `<pre class="output">${escapeHTML(formatJSON(tool))}</pre>`).join(""))
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
      },
    });
    state.lastGraphRun = payload;
    els.graphRunStatus.textContent = `${payload.graphName} complete`;
    setGraphResult(payload.artifact ?? payload.artifacts ?? payload);
    renderTimeline(payload);
    renderNodeDetails();
    setStatus("Graph run complete");
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
      },
    });
    setGraphResult(payload);
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
    button.textContent = "Show output";
    button.addEventListener("click", () => {
      setGraphResult(node);
      const matched = state.selectedGraph?.nodes.find((candidate) => candidate.id === nodeName);
      if (matched) {
        inspectGraphNode(matched, { scroll: true });
      }
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
    button.textContent = "Show trace";
    button.addEventListener("click", () => {
      setGraphResult(tool);
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
  els.resultOutput.textContent = "";
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
}

function currentMockFixtures() {
  if (!state.selected) return [];
  return state.mockFixtures.filter((fixture) =>
    fixture.group === state.selected.group && fixture.id === state.selected.id
  );
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
    els.resultOutput.textContent = formatJSON(payload);
    setStatus(
      payload.ok ? `Run complete in ${payload.latencyMS} ms` : "Run failed",
    );
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

function setGraphResult(value, fallbackText = "") {
  state.graphReadableValue = value;
  els.graphResultOutput.textContent = value ? formatJSON(value) : fallbackText;
  els.readableGraphOutputButton.disabled = !value;
}

function openReadableGraphModal() {
  if (!state.graphReadableValue) return;
  els.readableGraphTitle.textContent = readableTitle(state.graphReadableValue);
  els.readableGraphContent.innerHTML = readableHTML(state.graphReadableValue);
  els.readableGraphModal.classList.remove("hidden");
}

function closeReadableGraphModal() {
  els.readableGraphModal.classList.add("hidden");
}

function readableTitle(value) {
  if (value.toolName) return value.toolName;
  if (value.tool_name) return value.tool_name;
  if (value.plannedNode?.label) return value.plannedNode.label;
  if (value.graphName) return value.graphName;
  return "Graph Result";
}

function readableHTML(value) {
  if (value.toolName && value.output) return readableToolTest(value);
  if (value.tool_name && value.output) return readableToolCall(value);
  if (value.plannedNode) return readablePlannedNode(value);
  if (value.trainingArchitecture || value.fitnessStrategy) return readableArtifactBundle(value);
  if (value.priority_order || value.modality_roles) return readableArchitecture(value);
  return readableGeneric(value);
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
    specialistSection(output),
    rawSection("Raw output", output),
  ].join("");
}

function readableToolCall(value) {
  return [
    readableSection("Run", fieldGrid([
      ["Tool", value.tool_name],
      ["Node", value.graph_node_name],
      ["Status", value.status],
      ["Latency", `${value.latency_ms ?? "n/a"} ms`],
    ])),
    promptSection(value.request_json ?? value.input),
    specialistSection(value.output ?? {}),
    rawSection("Raw output", value.output ?? value),
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
    readableSection("Architecture", fieldGrid([
      ["Priority order", (value.priority_order ?? []).join(" > ")],
      ["Conflict status", value.conflict_assessment?.status],
      ["Weekly target", value.weekly_budget?.target_sessions ? `${value.weekly_budget.target_sessions} sessions` : null],
      ["Hard sessions", value.weekly_budget?.hard_sessions],
    ])),
    readableSection("Modality Roles", readableList((value.modality_roles ?? []).map((role) =>
      `${role.modality}: ${role.role} — ${role.rationale}`
    ))),
    readableSection("Approved Archetypes", archetypeList(value.approved_archetypes)),
    readableSection("Recovery Rules", readableList(value.recovery_envelope?.spacing_rules)),
    readableSection("Raw artifact", `<pre class="output readable-pre">${escapeHTML(formatJSON(value))}</pre>`),
  ].join("");
}

function readableArtifactBundle(value) {
  return [
    value.trainingArchitecture ? readableArchitecture(value.trainingArchitecture) : "",
    value.fitnessStrategy ? readableSection("Fitness Strategy", readableObjectSummary(value.fitnessStrategy)) : "",
  ].join("");
}

function readableGeneric(value) {
  return readableSection("Readable Summary", readableObjectSummary(value)) +
    rawSection("Raw data", value);
}

function promptSection(request) {
  const input = Array.isArray(request?.input) ? request.input : [];
  const system = input.find((part) => part.role === "system")?.content;
  const user = input.find((part) => part.role === "user")?.content;
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
      `<div class="readable-field"><span>${escapeHTML(label)}</span><strong>${escapeHTML(value)}</strong></div>`
    ))
    .join("");
  return fields ? `<div class="readable-grid">${fields}</div>` : "<span>No data</span>";
}

function readableList(items) {
  if (!Array.isArray(items) || items.length === 0) return "<span>None</span>";
  return `<ul class="readable-list">${items.map((item) => `<li>${escapeHTML(item)}</li>`).join("")}</ul>`;
}

function archetypeList(archetypes) {
  if (!Array.isArray(archetypes) || archetypes.length === 0) return "<span>None</span>";
  return `<ul class="readable-list">${archetypes.map((item) => (
    `<li><strong>${escapeHTML(item.id ?? item.title ?? "Archetype")}</strong><br>` +
    `${escapeHTML(item.purpose ?? "")}<br>` +
    `<span>${escapeHTML([item.intensity_domain, item.fatigue_cost, durationLabel(item)].filter(Boolean).join(" · "))}</span></li>`
  )).join("")}</ul>`;
}

function knowledgeList(refs) {
  if (!Array.isArray(refs) || refs.length === 0) return "<span>None</span>";
  return `<ul class="readable-list">${refs.map((ref) => (
    `<li><strong>${escapeHTML(ref.id)}</strong><br><span>${escapeHTML(ref.title ?? "")} ${escapeHTML(ref.version ?? "")}</span></li>`
  )).join("")}</ul>`;
}

function readableObjectSummary(value) {
  if (!value || typeof value !== "object") return `<p class="readable-copy">${escapeHTML(value ?? "No data")}</p>`;
  const entries = Object.entries(value).filter(([, entry]) =>
    typeof entry === "string" || typeof entry === "number" || typeof entry === "boolean"
  );
  return entries.length ? fieldGrid(entries) : `<pre class="output readable-pre">${escapeHTML(formatJSON(value))}</pre>`;
}

function rawSection(title, value) {
  return readableSection(title, `<pre class="output readable-pre">${escapeHTML(formatJSON(value))}</pre>`);
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
  els.resultOutput.classList.add("error");
  setStatus("Error");
  window.setTimeout(() => els.resultOutput.classList.remove("error"), 1400);
}

function showGraphError(error) {
  const message = error.message === "Not found"
    ? "Graph API route not found. Restart the AI Touchpoint Lab server so /api/graphs, /api/graph-run, and /api/graph-tool-test are loaded."
    : error.message;
  setGraphResult(null, message);
  els.graphResultOutput.classList.add("error");
  els.graphRunStatus.textContent = "Error";
  setStatus("Error");
  window.setTimeout(() => els.graphResultOutput.classList.remove("error"), 1400);
}

function setStatus(text) {
  els.statusLine.textContent = text;
}

function setBusy(isBusy, label = "Working") {
  els.saveButton.disabled = isBusy;
  els.runButton.disabled = isBusy;
  els.saveFixtureButton.disabled = isBusy;
  els.runGraphButton.disabled = isBusy;
  els.saveGraphFixtureButton.disabled = isBusy;
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
  if (!state.lastGraphRun) renderPlannedTimeline();
  setGraphResult({
    plannedNode: {
      id: node.id,
      label: node.label,
      stage: nodeStageLabel(node),
      purpose: node.purpose,
      toolCalls: node.toolCalls,
      inputContract: node.inputContract,
      outputContract: node.outputContract,
      knowledgeRefs: node.knowledgeRefs,
    },
    nextStep: node.toolCalls?.length
      ? `Use one of the tool buttons in the node drawer to test ${node.toolCalls[0]}.`
      : "Run the graph to capture this node's live output.",
  });
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
