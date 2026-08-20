import { ApiError, GoogleGenAI, ThinkingLevel } from "@google/genai";
import { HttpsError } from "firebase-functions/v2/https";
import { error as logError } from "firebase-functions/logger";
import {
  AI_REQUEST_TIMEOUT_MS,
  GEMINI_LOCATION,
  GEMINI_MODEL_NAME,
} from "./ai-config";
import { AI_MAX_OUTPUT_TOKENS } from "./ai-protection";

type GeminiJsonRequest = {
  userPrompt: string;
  systemPrompt?: string;
  responseSchema: Record<string, unknown>;
};

let geminiClient: GoogleGenAI | undefined;

function firebaseProjectId(): string {
  const direct = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  if (direct) return direct;
  try {
    const config = JSON.parse(process.env.FIREBASE_CONFIG ?? "{}") as {
      projectId?: string;
    };
    if (config.projectId) return config.projectId;
  } catch {
    // The consistent configuration error below is safer than leaking JSON.
  }
  throw new HttpsError(
    "failed-precondition",
    "AI service is not configured.",
    { reason: "AI_CONFIGURATION_UNAVAILABLE" }
  );
}

function client(): GoogleGenAI {
  geminiClient ??= new GoogleGenAI({
    enterprise: true,
    project: firebaseProjectId(),
    location: GEMINI_LOCATION,
    apiVersion: "v1",
  });
  return geminiClient;
}

export async function callGeminiJson(
  request: GeminiJsonRequest
): Promise<Record<string, unknown>> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), AI_REQUEST_TIMEOUT_MS);
  try {
    const response = await client().models.generateContent({
      model: GEMINI_MODEL_NAME,
      contents: request.userPrompt,
      config: {
        abortSignal: controller.signal,
        systemInstruction: request.systemPrompt ??
          "Sen yardımcı bir planlama asistanısın. Her zaman geçerli JSON döndür.",
        maxOutputTokens: AI_MAX_OUTPUT_TOKENS,
        temperature: 0.2,
        responseMimeType: "application/json",
        responseJsonSchema: request.responseSchema,
        thinkingConfig: {
          thinkingLevel: ThinkingLevel.MINIMAL,
          includeThoughts: false,
        },
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
    throw mapGeminiError(error);
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

function mapGeminiError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  if (isAbortError(error)) {
    return new HttpsError("deadline-exceeded", "AI request timed out.", {
      reason: "AI_PROVIDER_TIMEOUT",
    });
  }
  if (error instanceof ApiError) {
    logError("Gemini API request failed", { status: error.status });
    if (error.status === 429) {
      return new HttpsError("resource-exhausted", "AI capacity is limited.", {
        reason: "AI_PROVIDER_QUOTA_EXCEEDED",
      });
    }
    if (error.status === 400 || error.status === 404) {
      return new HttpsError("failed-precondition", "AI model unavailable.", {
        reason: "AI_MODEL_UNAVAILABLE",
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
