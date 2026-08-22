import { ApiError, GoogleGenAI } from "@google/genai";
import { HttpsError } from "firebase-functions/v2/https";
import { error as logError } from "firebase-functions/logger";
import {
  AI_REQUEST_TIMEOUT_MS,
} from "./ai-config";
import { loadAiLimitsConfig } from "./ai-limits-config";
import { AI_MAX_OUTPUT_TOKENS } from "./ai-protection";

type GeminiJsonRequest = {
  userPrompt: string;
  systemPrompt?: string;
  responseSchema: Record<string, unknown>;
  apiKey: string;
};

let geminiClient: GoogleGenAI | undefined;
let geminiClientApiKey: string | undefined;

function client(apiKey: string): GoogleGenAI {
  const key = apiKey.trim();
  if (!key) {
    throw new HttpsError(
      "failed-precondition",
      "AI service is not configured.",
      { reason: "AI_CONFIGURATION_UNAVAILABLE" }
    );
  }
  if (geminiClient == null || geminiClientApiKey !== key) {
    geminiClient = new GoogleGenAI({ apiKey: key });
    geminiClientApiKey = key;
  }
  return geminiClient;
}

export async function callGeminiJson(
  request: GeminiJsonRequest
): Promise<Record<string, unknown>> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), AI_REQUEST_TIMEOUT_MS);
  const config = await loadAiLimitsConfig();
  try {
    const response = await client(request.apiKey).models.generateContent({
      model: config.geminiModelName,
      contents: request.userPrompt,
      config: {
        abortSignal: controller.signal,
        systemInstruction: request.systemPrompt ??
          "Sen yardımcı bir planlama asistanısın. Her zaman geçerli JSON döndür.",
        maxOutputTokens: AI_MAX_OUTPUT_TOKENS,
        temperature: 0.2,
        responseMimeType: "application/json",
        responseJsonSchema: request.responseSchema,
      },
    });
    const content = response.text?.trim() ?? "";
    if (!content) return malformedResponse("empty");
    try {
      const parsed = JSON.parse(extractJson(content)) as unknown;
      if (!isJsonObject(parsed)) return malformedResponse("not_object");
      return parsed;
    } catch {
      return malformedResponse("invalid_json");
    }
  } catch (error) {
    throw mapGeminiError(error, config.geminiModelName);
  } finally {
    clearTimeout(timer);
  }
}

function malformedResponse(kind: string): never {
  logError("Gemini returned a malformed response", { kind });
  throw new HttpsError(
    "internal",
    "AI response could not be processed.",
    { reason: "AI_MALFORMED_RESPONSE" }
  );
}

function mapGeminiError(error: unknown, modelName: string): HttpsError {
  if (error instanceof HttpsError) return error;
  if (isAbortError(error)) {
    return new HttpsError("deadline-exceeded", "AI request timed out.", {
      reason: "AI_PROVIDER_TIMEOUT",
    });
  }
  if (error instanceof ApiError) {
    logError("Gemini API request failed", {
      status: error.status,
      model: modelName,
      message: error.message,
    });
    if (error.status === 429) {
      return new HttpsError("resource-exhausted", "AI capacity is limited.", {
        reason: "AI_PROVIDER_QUOTA_EXCEEDED",
      });
    }
    if (error.status === 404) {
      return new HttpsError("failed-precondition", "AI model unavailable.", {
        reason: "AI_MODEL_UNAVAILABLE",
        model: modelName,
      });
    }
    if (error.status === 400) {
      return new HttpsError("failed-precondition", "AI request rejected.", {
        reason: "AI_REQUEST_REJECTED",
        model: modelName,
      });
    }
    if (error.status === 401 || error.status === 403) {
      return new HttpsError("failed-precondition", "AI service is not configured.", {
        reason: "AI_CONFIGURATION_UNAVAILABLE",
      });
    }
    if (error.status === 408 || error.status === 504) {
      return new HttpsError("deadline-exceeded", "AI request timed out.", {
        reason: "AI_PROVIDER_TIMEOUT",
      });
    }
    if (error.status >= 500) {
      return new HttpsError("unavailable", "AI service unavailable.", {
        reason: "AI_PROVIDER_UNAVAILABLE",
      });
    }
  }
  logError("Unexpected Gemini request failure", {
    type: error instanceof Error ? error.name : typeof error,
  });
  return new HttpsError("unavailable", "AI service unavailable.", {
    reason: "AI_PROVIDER_UNAVAILABLE",
  });
}

function isAbortError(error: unknown): boolean {
  return error instanceof Error &&
    (error.name === "AbortError" || error.message.toLowerCase().includes("abort"));
}

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function extractJson(content: string): string {
  const start = content.indexOf("{");
  const end = content.lastIndexOf("}");
  return start >= 0 && end > start ? content.slice(start, end + 1) : content;
}
