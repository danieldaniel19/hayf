const state = {
  catalog: null,
  mockFixtures: [],
  defaultModel: "gpt-5-mini",
  selected: null,
  dirty: false,
};

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
};

await loadCatalog();
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
  els.mockFixtureInput.addEventListener("change", () => {
    const fixture = currentMockFixtures()[Number(els.mockFixtureInput.value)];
    if (!fixture) return;
    els.fixtureInput.value = JSON.stringify(fixture.fixture, null, 2);
    els.fixtureNameInput.value = slugify(fixture.name);
    setStatus(`Loaded ${fixture.name}`);
  });
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

function setStatus(text) {
  els.statusLine.textContent = text;
}

function setBusy(isBusy, label = "Working") {
  els.saveButton.disabled = isBusy;
  els.runButton.disabled = isBusy;
  els.saveFixtureButton.disabled = isBusy;
  if (isBusy) setStatus(label);
}
