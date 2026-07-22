import assert from "node:assert/strict";
import test from "node:test";
import { createAthleteProfileServer } from "../src/server.js";

test("keeps health public and scoring authenticated with a compact-only contract", async () => {
  process.env.ATHLETE_PROFILE_ENGINE_API_KEY = "test-profile-key";
  const server = createAthleteProfileServer();
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert.ok(address && typeof address === "object");
  const baseURL = `http://127.0.0.1:${address.port}`;
  try {
    assert.equal((await fetch(`${baseURL}/health`)).status, 200);
    assert.equal((await fetch(`${baseURL}/v1/blueprints/score`, { method: "POST" })).status, 401);

    const unsupportedPayload: Record<string, unknown> = {
      schemaVersion: "athlete-profile-scoring-input.v1",
      intent: "stayConsistent",
      normalizedGoal: { category: "consistency", horizonWeeks: 12 },
      availability: { targetSessionsPerWeek: 3, availableDaysCount: 3, ultraFlexible: false },
      feasibleModalities: ["running"],
      evidence: null,
      rawHealthKitSamples: [],
    };
    const rejected = await fetch(`${baseURL}/v1/blueprints/score`, {
      method: "POST",
      headers: { Authorization: "Bearer test-profile-key", "Content-Type": "application/json" },
      body: JSON.stringify(unsupportedPayload),
    });
    assert.equal(rejected.status, 400);

    delete unsupportedPayload.rawHealthKitSamples;
    const accepted = await fetch(`${baseURL}/v1/blueprints/score`, {
      method: "POST",
      headers: { Authorization: "Bearer test-profile-key", "Content-Type": "application/json" },
      body: JSON.stringify(unsupportedPayload),
    });
    assert.equal(accepted.status, 200);
  } finally {
    server.close();
    delete process.env.ATHLETE_PROFILE_ENGINE_API_KEY;
  }
});
