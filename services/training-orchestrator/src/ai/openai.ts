import { type GraphToolCall, type JsonObject, type KnowledgeSourceRef } from "../contracts.js";

type StructuredJSONArgs<T> = {
  toolName: string;
  graphNodeName?: string;
  system: string;
  input: JsonObject;
  inputSummary: JsonObject;
  schema: JsonObject;
  knowledgeRefs?: KnowledgeSourceRef[];
  testOutput?: () => T;
};

type StructuredJSONResult<T> = {
  data: T;
  toolCall: GraphToolCall;
};

const openAIURL = "https://api.openai.com/v1/responses";

export async function runStructuredJSON<T>(args: StructuredJSONArgs<T>): Promise<StructuredJSONResult<T>> {
  const started = Date.now();
  const model = process.env.OPENAI_MODEL?.trim() || "gpt-5-mini";
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  const fullTrace = process.env.HAYF_OBSERVABILITY_TRACE_LEVEL === "full";

  if (!apiKey) {
    if (process.env.HAYF_ALLOW_AI_STUB === "true" && args.testOutput) {
      const data = args.testOutput();
      return {
        data,
        toolCall: buildToolCall({
          tool_name: args.toolName,
          tool_version: "test-openai-stub",
          graph_node_name: args.graphNodeName,
          input: fullTrace ? fullInput("test", args) : { model: "test", ...args.inputSummary },
          output: data as JsonObject,
          status: "succeeded",
          latency_ms: Date.now() - started,
          provider: "openai",
          model: "test",
          fullTrace,
          args,
        }),
      };
    }
    throw new Error(`OPENAI_API_KEY is required for ${args.toolName}.`);
  }

  const response = await fetch(openAIURL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        { role: "system", content: args.system },
        { role: "user", content: JSON.stringify(args.input) },
      ],
      text: {
        format: {
          type: "json_schema",
          name: args.toolName,
          strict: true,
          schema: args.schema,
        },
      },
    }),
  });

  const payload = await response.json().catch(() => ({})) as JsonObject;
  if (!response.ok) {
    throw new Error(openAIError(payload) ?? `${args.toolName} failed with HTTP ${response.status}.`);
  }

  const data = parseStructuredOutput<T>(payload, args.toolName);
  return {
    data,
    toolCall: buildToolCall({
      tool_name: args.toolName,
      tool_version: "openai-responses-json-schema-v1",
      graph_node_name: args.graphNodeName,
      input: fullTrace ? fullInput(model, args) : { model, ...args.inputSummary },
      output: data as JsonObject,
      status: "succeeded",
      latency_ms: Date.now() - started,
      provider: "openai",
      model,
      fullTrace,
      args,
    }),
  };
}

function buildToolCall<T>(value: {
  tool_name: string;
  tool_version: string;
  graph_node_name?: string;
  input: JsonObject;
  output: JsonObject | null;
  status: GraphToolCall["status"];
  latency_ms: number;
  provider: string;
  model: string;
  fullTrace: boolean;
  args: StructuredJSONArgs<T>;
}): GraphToolCall {
  return {
    tool_name: value.tool_name,
    tool_version: value.tool_version,
    graph_node_name: value.graph_node_name,
    input: value.input,
    output: value.output,
    status: value.status,
    latency_ms: value.latency_ms,
    provider: value.provider,
    model: value.model,
    ...(value.fullTrace
      ? {
        system_prompt: value.args.system,
        request_json: {
          model: value.model,
          input: [
            { role: "system", content: value.args.system },
            { role: "user", content: JSON.stringify(value.args.input) },
          ],
        },
        schema_json: value.args.schema,
        knowledge_refs: value.args.knowledgeRefs ?? [],
      }
      : {}),
  };
}

function fullInput<T>(model: string, args: StructuredJSONArgs<T>): JsonObject {
  return {
    model,
    inputSummary: args.inputSummary,
    input: args.input,
    systemPrompt: args.system,
    schema: args.schema,
    knowledgeRefs: args.knowledgeRefs ?? [],
  };
}

function parseStructuredOutput<T>(payload: JsonObject, toolName: string): T {
  const direct = payload.output_text;
  if (typeof direct === "string" && direct.trim()) return JSON.parse(direct) as T;

  const output = Array.isArray(payload.output) ? payload.output : [];
  for (const item of output) {
    if (!item || typeof item !== "object") continue;
    const content = Array.isArray((item as JsonObject).content) ? (item as JsonObject).content as unknown[] : [];
    for (const part of content) {
      if (!part || typeof part !== "object") continue;
      const text = (part as JsonObject).text ?? (part as JsonObject).output_text;
      if (typeof text === "string" && text.trim()) return JSON.parse(text) as T;
    }
  }

  throw new Error(`${toolName} returned no structured JSON output.`);
}

function openAIError(payload: JsonObject) {
  const error = payload.error;
  if (error && typeof error === "object") {
    const message = (error as JsonObject).message;
    if (typeof message === "string") return message;
  }
  return null;
}
