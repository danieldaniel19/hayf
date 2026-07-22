import {
  scoreAthleteProfile,
  type ProfileScoringRequest,
} from "../../../services/athlete-profile-engine/src/scoring.ts";
import { validateProfileScoringRequest } from "../../../services/athlete-profile-engine/src/validation.ts";

const maximumRequestBytes = 256_000;
const jsonHeaders = { "Content-Type": "application/json" };
const projectAuthURL = "https://nehwppenlaxozpwqepwp.supabase.co/auth/v1/user";
const projectPublishableKey = "sb_publishable_eN9IUQOtgcGL7dG8jQE26A_KA2FHr-u";

export async function handleAthleteProfileRequest(
  request: Request,
  configuredAPIKey?: string,
  authenticatedUser = false,
  authTelemetry?: { delegatedTokenPresent: boolean; authStatus: number | null },
) {
  const path = new URL(request.url).pathname;

  if (request.method === "GET" && path.endsWith("/health")) {
    return jsonResponse({ ok: true, service: "hayf-athlete-profile-engine", version: "athlete-profile-engine-v1" });
  }

  if (request.method !== "POST" || !path.endsWith("/v1/blueprints/score")) {
    return jsonResponse({ error: "Not found" }, 404);
  }

  const acceptedAPIKeys = (configuredAPIKey
    ? [configuredAPIKey]
    : authenticatedUser ? [] : [
      Deno.env.get("ATHLETE_PROFILE_ENGINE_API_KEY"),
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    ]
  ).map((value) => value?.trim() ?? "").filter(Boolean);
  const suppliedKey = request.headers.get("X-HAYF-Profile-Key")?.trim()
    || (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const authenticatedService = acceptedAPIKeys.some((apiKey) => constantTimeEqual(apiKey, suppliedKey));
  if (!acceptedAPIKeys.length && !authenticatedUser) {
    return jsonResponse({ error: "Service authentication is not configured." }, 503);
  }
  if (!authenticatedService && !authenticatedUser) {
    return jsonResponse({ error: "Unauthorized", ...(authTelemetry ? { authTelemetry } : {}) }, 401);
  }

  const contentLength = Number(request.headers.get("Content-Length") ?? 0);
  if (contentLength > maximumRequestBytes) return jsonResponse({ error: "Request body is too large." }, 413);

  try {
    const text = await request.text();
    if (new TextEncoder().encode(text).byteLength > maximumRequestBytes) {
      return jsonResponse({ error: "Request body is too large." }, 413);
    }
    const body: unknown = text ? JSON.parse(text) : {};
    validateProfileScoringRequest(body);
    return jsonResponse(scoreAthleteProfile(body as unknown as ProfileScoringRequest));
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "Invalid scoring request." }, 400);
  }
}

function constantTimeEqual(expected: string, supplied: string) {
  const expectedBytes = new TextEncoder().encode(expected);
  const suppliedBytes = new TextEncoder().encode(supplied);
  let mismatch = expectedBytes.length ^ suppliedBytes.length;
  const length = Math.max(expectedBytes.length, suppliedBytes.length);
  for (let index = 0; index < length; index += 1) {
    mismatch |= (expectedBytes[index] ?? 0) ^ (suppliedBytes[index] ?? 0);
  }
  return mismatch === 0;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

async function hasAuthenticatedSupabaseUser(request: Request) {
  const delegatedToken = request.headers.get("X-HAYF-User-Token")?.trim() ?? "";
  const authorization = delegatedToken
    ? `Bearer ${delegatedToken}`
    : request.headers.get("Authorization")?.trim() ?? "";
  if (!authorization) {
    return { authenticated: false, delegatedTokenPresent: false, authStatus: null };
  }

  try {
    const publishableKeys = [
      Deno.env.get("SUPABASE_ANON_KEY")?.trim(),
      projectPublishableKey,
    ].filter((value, index, values): value is string => Boolean(value) && values.indexOf(value) === index);
    let authStatus: number | null = null;
    for (const publishableKey of publishableKeys) {
      const response = await fetch(projectAuthURL, {
        headers: {
          Authorization: authorization,
          apikey: publishableKey,
        },
        signal: AbortSignal.timeout(3_000),
      });
      authStatus = response.status;
      if (response.ok) {
        return {
          authenticated: true,
          delegatedTokenPresent: Boolean(delegatedToken),
          authStatus,
        };
      }
    }
    return {
      authenticated: false,
      delegatedTokenPresent: Boolean(delegatedToken),
      authStatus,
    };
  } catch {
    return {
      authenticated: false,
      delegatedTokenPresent: Boolean(delegatedToken),
      authStatus: null,
    };
  }
}

if (import.meta.main) {
  Deno.serve(async (request) => {
    const authentication = await hasAuthenticatedSupabaseUser(request);
    return handleAthleteProfileRequest(request, undefined, authentication.authenticated, authentication);
  });
}
