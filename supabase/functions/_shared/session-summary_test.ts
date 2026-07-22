import {
  modalitySafeSessionSummaryFallback,
  sessionSummaryContradictsActivity,
} from "./session-summary.ts";

Deno.test("rejects a run summary attached to a walking session", () => {
  if (!sessionSummaryContradictsActivity("walking", "Easy run to maintain aerobic rhythm this Thursday.")) {
    throw new Error("Expected walking session to reject a run summary");
  }
});

Deno.test("allows neighboring modality context after naming the actual session", () => {
  if (sessionSummaryContradictsActivity("walking", "Gentle walking restores your legs before Saturday's run.")) {
    throw new Error("Expected a walking-first summary to remain valid");
  }
});

Deno.test("keeps modality-safe fallbacks compact and explicit", () => {
  const summary = modalitySafeSessionSummaryFallback("walk", "Easy");
  const words = summary.split(/\s+/).length;
  if (!/walking/i.test(summary) || words < 7 || words > 12 || summary.length > 80) {
    throw new Error(`Unexpected walking fallback: ${summary}`);
  }
});
