import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import {
  AiLimitsConfig,
  DEFAULT_AI_LIMITS,
  loadAiLimitsConfig,
} from "./ai-limits-config";

export const AI_INPUT_MAX_CHARACTERS = 2000;
export const AI_MAX_OUTPUT_TOKENS = 500;

type WindowKey = "minute" | "hour" | "day" | "month";

type WindowSpec = {
  key: WindowKey;
  limit: number;
  errorReason: string;
  startAt: (now: Date) => Date;
  nextAt: (start: Date) => Date;
};

type StoredWindow = {
  startAt?: admin.firestore.Timestamp;
  count?: number;
};

export type AiChatUsageSnapshot = {
  usedThisMonth: number;
  limitThisMonth: number;
  resetsAt: string;
  isPremium: boolean;
};

const monthWindowSpec = (
  limit: number,
  errorReason: string
): WindowSpec => ({
  key: "month",
  limit,
  errorReason,
  startAt: (now) => new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    1
  )),
  nextAt: (start) => new Date(Date.UTC(
    start.getUTCFullYear(),
    start.getUTCMonth() + 1,
    1
  )),
});

function premiumWindowSpecs(config: AiLimitsConfig): WindowSpec[] {
  return [
    {
      key: "minute",
      limit: config.premiumMessagesPerMinute,
      errorReason: "AI_RATE_LIMIT_MINUTE",
      startAt: (now) => new Date(Math.floor(now.getTime() / 60_000) * 60_000),
      nextAt: (start) => new Date(start.getTime() + 60_000),
    },
    {
      key: "hour",
      limit: config.premiumMessagesPerHour,
      errorReason: "AI_RATE_LIMIT_HOURLY",
      startAt: (now) => new Date(Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth(),
        now.getUTCDate(),
        now.getUTCHours()
      )),
      nextAt: (start) => new Date(start.getTime() + 60 * 60_000),
    },
    {
      key: "day",
      limit: config.premiumMessagesPerDay,
      errorReason: "AI_DAILY_LIMIT_REACHED",
      startAt: (now) => new Date(Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth(),
        now.getUTCDate()
      )),
      nextAt: (start) => new Date(start.getTime() + 24 * 60 * 60_000),
    },
    monthWindowSpec(
      config.premiumMessagesPerMonth,
      "AI_MONTHLY_LIMIT_REACHED"
    ),
  ];
}

function freeChatWindowSpecs(config: AiLimitsConfig): WindowSpec[] {
  return [
    monthWindowSpec(
      config.freeChatMessagesPerMonth,
      "AI_FREE_CHAT_MONTHLY_LIMIT_REACHED"
    ),
  ];
}

export function aiAccessDocument(uid: string): admin.firestore.DocumentReference {
  return admin.firestore()
    .collection("users")
    .doc(uid)
    .collection("private")
    .doc("aiAccess");
}

export function requireAuthenticatedUid(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication required.", {
      reason: "AUTHENTICATION_REQUIRED",
    });
  }
  return uid;
}

export function normalizeAiInput(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} is required`, {
      reason: "AI_INPUT_REQUIRED",
    });
  }
  const normalized = value.normalize("NFKC").replace(/\r\n?/g, "\n").trim();
  if (!normalized) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`, {
      reason: "AI_INPUT_REQUIRED",
    });
  }
  if ([...normalized].length > AI_INPUT_MAX_CHARACTERS) {
    throw new HttpsError(
      "invalid-argument",
      `AI input cannot exceed ${AI_INPUT_MAX_CHARACTERS} characters.`,
      {
        reason: "AI_INPUT_TOO_LONG",
        maxCharacters: AI_INPUT_MAX_CHARACTERS,
      }
    );
  }
  return normalized;
}

export function hasActivePremium(
  data: admin.firestore.DocumentData | undefined,
  now: Date
): boolean {
  const premiumUntil = data?.premiumUntil;
  return premiumUntil instanceof admin.firestore.Timestamp &&
    premiumUntil.toMillis() > now.getTime();
}

function assertPremium(data: admin.firestore.DocumentData | undefined, now: Date): void {
  if (!hasActivePremium(data, now)) {
    throw new HttpsError("permission-denied", "Premium subscription required.", {
      reason: "PREMIUM_REQUIRED",
    });
  }
}

export async function requirePremiumEntitlement(uid: string): Promise<void> {
  const snapshot = await aiAccessDocument(uid).get();
  assertPremium(snapshot.data(), new Date());
}

function windowCount(
  storedUsage: Partial<Record<WindowKey, StoredWindow>>,
  spec: WindowSpec,
  now: Date
): number {
  const currentStart = spec.startAt(now);
  const stored = storedUsage[spec.key];
  const sameWindow = stored?.startAt instanceof admin.firestore.Timestamp &&
    stored.startAt.toMillis() === currentStart.getTime();
  return sameWindow ? Math.max(0, Number(stored?.count ?? 0)) : 0;
}

function buildChatUsageSnapshot(
  storedUsage: Partial<Record<WindowKey, StoredWindow>>,
  config: AiLimitsConfig,
  isPremium: boolean,
  now: Date
): AiChatUsageSnapshot {
  const monthSpec = isPremium ?
    premiumWindowSpecs(config).find((spec) => spec.key === "month")! :
    freeChatWindowSpecs(config)[0];
  const usedThisMonth = windowCount(storedUsage, monthSpec, now);
  const currentStart = monthSpec.startAt(now);
  return {
    usedThisMonth,
    limitThisMonth: monthSpec.limit,
    resetsAt: monthSpec.nextAt(currentStart).toISOString(),
    isPremium,
  };
}

async function reserveAiUsage(
  uid: string,
  specs: WindowSpec[]
): Promise<AiChatUsageSnapshot> {
  const db = admin.firestore();
  const accessRef = aiAccessDocument(uid);
  const config = await loadAiLimitsConfig();

  return db.runTransaction(async (transaction) => {
    const now = new Date();
    const snapshot = await transaction.get(accessRef);
    const data = snapshot.data();
    const isPremium = hasActivePremium(data, now);

    const storedUsage = (data?.usage ?? {}) as Partial<Record<WindowKey, StoredWindow>>;
    const nextUsage: Partial<Record<WindowKey, StoredWindow>> = {
      ...storedUsage,
    };

    for (const spec of specs) {
      const currentStart = spec.startAt(now);
      const stored = storedUsage[spec.key];
      const sameWindow = stored?.startAt instanceof admin.firestore.Timestamp &&
        stored.startAt.toMillis() === currentStart.getTime();
      const count = sameWindow ? Math.max(0, Number(stored?.count ?? 0)) : 0;
      if (count >= spec.limit) {
        const retryAt = spec.nextAt(currentStart);
        throw new HttpsError("resource-exhausted", "AI usage limit reached.", {
          reason: spec.errorReason,
          retryAt: retryAt.toISOString(),
          limit: spec.limit,
        });
      }
      nextUsage[spec.key] = {
        startAt: admin.firestore.Timestamp.fromDate(currentStart),
        count: count + 1,
      };
    }

    transaction.set(accessRef, {
      usage: nextUsage,
      lastAiReservedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return buildChatUsageSnapshot(nextUsage, config, isPremium, now);
  });
}

export async function readAiChatUsage(uid: string): Promise<AiChatUsageSnapshot> {
  const config = await loadAiLimitsConfig();
  const snapshot = await aiAccessDocument(uid).get();
  const data = snapshot.data();
  const now = new Date();
  const isPremium = hasActivePremium(data, now);
  const storedUsage = (data?.usage ?? {}) as Partial<Record<WindowKey, StoredWindow>>;
  return buildChatUsageSnapshot(storedUsage, config, isPremium, now);
}

export async function reserveAiGeneration(uid: string): Promise<void> {
  const config = await loadAiLimitsConfig();
  const db = admin.firestore();
  const accessRef = aiAccessDocument(uid);
  await db.runTransaction(async (transaction) => {
    const now = new Date();
    const snapshot = await transaction.get(accessRef);
    const data = snapshot.data();
    assertPremium(data, now);

    const specs = premiumWindowSpecs(config);
    const storedUsage = (data?.usage ?? {}) as Partial<Record<WindowKey, StoredWindow>>;
    const nextUsage: Partial<Record<WindowKey, StoredWindow>> = {
      ...storedUsage,
    };

    for (const spec of specs) {
      const currentStart = spec.startAt(now);
      const stored = storedUsage[spec.key];
      const sameWindow = stored?.startAt instanceof admin.firestore.Timestamp &&
        stored.startAt.toMillis() === currentStart.getTime();
      const count = sameWindow ? Math.max(0, Number(stored?.count ?? 0)) : 0;
      if (count >= spec.limit) {
        const retryAt = spec.nextAt(currentStart);
        throw new HttpsError("resource-exhausted", "AI usage limit reached.", {
          reason: spec.errorReason,
          retryAt: retryAt.toISOString(),
          limit: spec.limit,
        });
      }
      nextUsage[spec.key] = {
        startAt: admin.firestore.Timestamp.fromDate(currentStart),
        count: count + 1,
      };
    }

    transaction.set(accessRef, {
      usage: nextUsage,
      lastAiReservedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

export async function reserveAiChatGeneration(uid: string): Promise<AiChatUsageSnapshot> {
  const config = await loadAiLimitsConfig();
  const snapshot = await aiAccessDocument(uid).get();
  const isPremium = hasActivePremium(snapshot.data(), new Date());
  const specs = isPremium ?
    premiumWindowSpecs(config) :
    freeChatWindowSpecs(config);
  return reserveAiUsage(uid, specs);
}

export async function protectAiGeneration<T>(
  uid: string,
  normalize: () => T
): Promise<T> {
  await requirePremiumEntitlement(uid);
  const normalized = normalize();
  await reserveAiGeneration(uid);
  return normalized;
}

export async function protectAiChatGeneration<T>(
  uid: string,
  normalize: () => T
): Promise<{ value: T; usage: AiChatUsageSnapshot }> {
  const normalized = normalize();
  const usage = await reserveAiChatGeneration(uid);
  return { value: normalized, usage };
}

export function defaultAiLimitsForDocs(): AiLimitsConfig {
  return { ...DEFAULT_AI_LIMITS };
}
