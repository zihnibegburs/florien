import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

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

const windowSpecs: WindowSpec[] = [
  {
    key: "minute",
    limit: 5,
    errorReason: "AI_RATE_LIMIT_MINUTE",
    startAt: (now) => new Date(Math.floor(now.getTime() / 60_000) * 60_000),
    nextAt: (start) => new Date(start.getTime() + 60_000),
  },
  {
    key: "hour",
    limit: 30,
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
    limit: 100,
    errorReason: "AI_DAILY_LIMIT_REACHED",
    startAt: (now) => new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate()
    )),
    nextAt: (start) => new Date(start.getTime() + 24 * 60 * 60_000),
  },
  {
    key: "month",
    limit: 3000,
    errorReason: "AI_MONTHLY_LIMIT_REACHED",
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
  },
];

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

function assertPremium(data: admin.firestore.DocumentData | undefined, now: Date): void {
  const premiumUntil = data?.premiumUntil;
  if (!(premiumUntil instanceof admin.firestore.Timestamp) ||
      premiumUntil.toMillis() <= now.getTime()) {
    throw new HttpsError("permission-denied", "Premium subscription required.", {
      reason: "PREMIUM_REQUIRED",
    });
  }
}

export async function requirePremiumEntitlement(uid: string): Promise<void> {
  const snapshot = await aiAccessDocument(uid).get();
  assertPremium(snapshot.data(), new Date());
}

export async function reserveAiGeneration(uid: string): Promise<void> {
  const db = admin.firestore();
  const accessRef = aiAccessDocument(uid);
  await db.runTransaction(async (transaction) => {
    const now = new Date();
    const snapshot = await transaction.get(accessRef);
    const data = snapshot.data();
    assertPremium(data, now);

    const storedUsage = (data?.usage ?? {}) as Partial<Record<WindowKey, StoredWindow>>;
    const nextUsage: Partial<Record<WindowKey, StoredWindow>> = {};

    for (const spec of windowSpecs) {
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

export async function protectAiGeneration<T>(
  uid: string,
  normalize: () => T
): Promise<T> {
  // Security order is intentional: entitlement is checked before request data.
  await requirePremiumEntitlement(uid);
  const normalized = normalize();
  await reserveAiGeneration(uid);
  return normalized;
}
