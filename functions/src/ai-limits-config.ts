import * as admin from "firebase-admin";

export type AiLimitsConfig = {
  freeChatMessagesPerMonth: number;
  premiumMessagesPerMinute: number;
  premiumMessagesPerHour: number;
  premiumMessagesPerDay: number;
  premiumMessagesPerMonth: number;
  geminiModelName: string;
};

export const DEFAULT_AI_LIMITS: AiLimitsConfig = {
  freeChatMessagesPerMonth: 3,
  premiumMessagesPerMinute: 5,
  premiumMessagesPerHour: 30,
  premiumMessagesPerDay: 100,
  premiumMessagesPerMonth: 3000,
  geminiModelName: "gemini-3.1-flash-lite",
};

const CONFIG_TTL_MS = 60_000;
let cachedConfig: AiLimitsConfig | null = null;
let cachedAt = 0;

function clampLimit(value: unknown, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return fallback;
  return Math.floor(parsed);
}

function normalizeModelName(value: unknown, fallback: string): string {
  if (typeof value !== "string") return fallback;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : fallback;
}

function normalizeConfig(raw: admin.firestore.DocumentData | undefined): AiLimitsConfig {
  return {
    freeChatMessagesPerMonth: clampLimit(
      raw?.freeChatMessagesPerMonth,
      DEFAULT_AI_LIMITS.freeChatMessagesPerMonth
    ),
    premiumMessagesPerMinute: clampLimit(
      raw?.premiumMessagesPerMinute,
      DEFAULT_AI_LIMITS.premiumMessagesPerMinute
    ),
    premiumMessagesPerHour: clampLimit(
      raw?.premiumMessagesPerHour,
      DEFAULT_AI_LIMITS.premiumMessagesPerHour
    ),
    premiumMessagesPerDay: clampLimit(
      raw?.premiumMessagesPerDay,
      DEFAULT_AI_LIMITS.premiumMessagesPerDay
    ),
    premiumMessagesPerMonth: clampLimit(
      raw?.premiumMessagesPerMonth,
      DEFAULT_AI_LIMITS.premiumMessagesPerMonth
    ),
    geminiModelName: normalizeModelName(
      raw?.geminiModelName,
      DEFAULT_AI_LIMITS.geminiModelName
    ),
  };
}

export async function loadAiLimitsConfig(): Promise<AiLimitsConfig> {
  const now = Date.now();
  if (cachedConfig && now - cachedAt < CONFIG_TTL_MS) {
    return cachedConfig;
  }

  try {
    const snapshot = await admin.firestore()
      .collection("appConfig")
      .doc("aiLimits")
      .get();
    cachedConfig = normalizeConfig(snapshot.data());
  } catch {
    cachedConfig = { ...DEFAULT_AI_LIMITS };
  }
  cachedAt = now;
  return cachedConfig;
}

export function resetAiLimitsConfigCacheForTests(): void {
  cachedConfig = null;
  cachedAt = 0;
}
