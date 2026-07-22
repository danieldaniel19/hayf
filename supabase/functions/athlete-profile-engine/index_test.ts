import { assertEquals } from "jsr:@std/assert@1";
import { handleAthleteProfileRequest } from "./index.ts";

const endpoint = "https://example.test/athlete-profile-engine/v1/blueprints/score";
const compactInput = {
  schemaVersion: "athlete-profile-scoring-input.v1",
  evaluatedAt: "2026-07-22T20:30:00.000Z",
  intent: "stayConsistent",
  normalizedGoal: { category: "consistency", horizonWeeks: 12 },
  availability: { targetSessionsPerWeek: 3, availableDaysCount: 3, ultraFlexible: false },
  feasibleModalities: ["running"],
  evidence: null,
};

Deno.test("keeps health public and score generation authenticated", async () => {
  const health = await handleAthleteProfileRequest(new Request("https://example.test/athlete-profile-engine/health"), "test-key");
  assertEquals(health.status, 200);

  const unauthorized = await handleAthleteProfileRequest(new Request(endpoint, {
    method: "POST",
    body: JSON.stringify(compactInput),
  }), "test-key");
  assertEquals(unauthorized.status, 401);

  const scored = await handleAthleteProfileRequest(new Request(endpoint, {
    method: "POST",
    headers: { "X-HAYF-Profile-Key": "test-key", "Content-Type": "application/json" },
    body: JSON.stringify(compactInput),
  }), "test-key");
  assertEquals(scored.status, 200);
  const payload = await scored.json();
  assertEquals(payload.scoreVersion, "profile-radar-v1.2.0");
  assertEquals(payload.dimensions.length, 5);

  const userAuthenticated = await handleAthleteProfileRequest(new Request(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(compactInput),
  }), undefined, true);
  assertEquals(userAuthenticated.status, 200);
});

Deno.test("rejects raw or unsupported health fields", async () => {
  const response = await handleAthleteProfileRequest(new Request(endpoint, {
    method: "POST",
    headers: { Authorization: "Bearer test-key", "Content-Type": "application/json" },
    body: JSON.stringify({ ...compactInput, rawHealthKitSamples: [] }),
  }), "test-key");
  assertEquals(response.status, 400);
});
