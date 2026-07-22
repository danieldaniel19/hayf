import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { timingSafeEqual } from "node:crypto";
import { scoreAthleteProfile, type ProfileScoringRequest } from "./scoring.js";
import { validateProfileScoringRequest } from "./validation.js";

const serviceVersion = "athlete-profile-engine-v1";
const maxRequestBytes = 256_000;

export function createAthleteProfileServer() {
  return createServer(async (request, response) => {
    try {
      if (request.method === "GET" && request.url === "/health") {
        writeJSON(response, 200, { ok: true, service: "@hayf/athlete-profile-engine", version: serviceVersion });
        return;
      }

      if (request.method === "POST" && request.url === "/v1/blueprints/score") {
        if (!process.env.ATHLETE_PROFILE_ENGINE_API_KEY?.trim()) {
          writeJSON(response, 503, { error: "Service authentication is not configured." });
          return;
        }
        if (!authorize(request)) {
          writeJSON(response, 401, { error: "Unauthorized" });
          return;
        }
        const body = await readJSON(request);
        validateProfileScoringRequest(body);
        writeJSON(response, 200, scoreAthleteProfile(body as ProfileScoringRequest));
        return;
      }

      writeJSON(response, 404, { error: "Not found" });
    } catch (error) {
      writeJSON(response, statusForError(error), {
        error: error instanceof Error ? error.message : "Unknown athlete profile engine error",
      });
    }
  });
}

function authorize(request: IncomingMessage) {
  const apiKey = process.env.ATHLETE_PROFILE_ENGINE_API_KEY?.trim();
  const supplied = request.headers.authorization?.replace(/^Bearer\s+/i, "") ?? "";
  if (!apiKey || !supplied) return false;
  const expectedBytes = Buffer.from(apiKey);
  const suppliedBytes = Buffer.from(supplied);
  return expectedBytes.length === suppliedBytes.length && timingSafeEqual(expectedBytes, suppliedBytes);
}

async function readJSON(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.byteLength;
    if (size > maxRequestBytes) throw Object.assign(new Error("Request body is too large."), { statusCode: 413 });
    chunks.push(buffer);
  }
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function writeJSON(response: ServerResponse, statusCode: number, payload: unknown) {
  response.writeHead(statusCode, { "Content-Type": "application/json" });
  response.end(JSON.stringify(payload));
}

function statusForError(error: unknown) {
  if (typeof error === "object" && error && "statusCode" in error) {
    const statusCode = Number((error as { statusCode?: unknown }).statusCode);
    if (Number.isInteger(statusCode) && statusCode >= 400 && statusCode < 600) return statusCode;
  }
  return 400;
}
