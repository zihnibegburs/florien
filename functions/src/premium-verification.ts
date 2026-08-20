import * as admin from "firebase-admin";
import { createHash, sign } from "node:crypto";
import { GoogleAuth } from "google-auth-library";
import { HttpsError } from "firebase-functions/v2/https";
import { aiAccessDocument } from "./ai-protection";

const APP_ID = "com.florien.app";
const PREMIUM_PRODUCT_IDS = new Set([
  "com.florien.app.subscription.monthly",
  "com.florien.app.subscription.yearly",
]);
const MAX_VERIFICATION_DATA_LENGTH = 200_000;

type AppleCredentials = {
  sharedSecret?: string;
  issuerId?: string;
  keyId?: string;
  privateKey?: string;
};

type VerifiedPremium = {
  provider: "app_store" | "google_play";
  productId: string;
  premiumUntil: Date;
  ownershipId: string;
};

type AppleTransaction = {
  transactionId?: string;
  originalTransactionId?: string;
  bundleId?: string;
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
  environment?: string;
};

function invalidPurchase(message: string): HttpsError {
  return new HttpsError("failed-precondition", message, {
    reason: "PREMIUM_VERIFICATION_FAILED",
  });
}

function parseAppleCredentials(raw: string): AppleCredentials {
  try {
    const parsed = JSON.parse(raw) as AppleCredentials;
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    throw new HttpsError(
      "failed-precondition",
      "Apple IAP credentials are not configured correctly.",
      { reason: "PREMIUM_VERIFICATION_UNAVAILABLE" }
    );
  }
}

function decodeJwsPayload<T>(jws: string): T {
  const parts = jws.split(".");
  if (parts.length !== 3) throw invalidPurchase("Invalid App Store transaction.");
  try {
    return JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as T;
  } catch {
    throw invalidPurchase("Invalid App Store transaction.");
  }
}

function appleApiToken(credentials: AppleCredentials): string {
  const { issuerId, keyId } = credentials;
  const privateKey = credentials.privateKey?.replace(/\\n/g, "\n");
  if (!issuerId || !keyId || !privateKey) {
    throw new HttpsError(
      "failed-precondition",
      "Apple App Store Server API credentials are not configured.",
      { reason: "PREMIUM_VERIFICATION_UNAVAILABLE" }
    );
  }
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({
    alg: "ES256",
    kid: keyId,
    typ: "JWT",
  })).toString("base64url");
  const payload = Buffer.from(JSON.stringify({
    iss: issuerId,
    iat: now,
    exp: now + 10 * 60,
    aud: "appstoreconnect-v1",
    bid: APP_ID,
  })).toString("base64url");
  const unsigned = `${header}.${payload}`;
  const signature = sign("sha256", Buffer.from(unsigned), {
    key: privateKey,
    dsaEncoding: "ieee-p1363",
  }).toString("base64url");
  return `${unsigned}.${signature}`;
}

async function fetchAppleTransaction(
  transactionId: string,
  environment: string | undefined,
  credentials: AppleCredentials
): Promise<AppleTransaction> {
  const production = "https://api.storekit.itunes.apple.com";
  const sandbox = "https://api.storekit-sandbox.itunes.apple.com";
  const hosts = environment?.toLowerCase() === "sandbox" ?
    [sandbox, production] : [production, sandbox];
  const token = appleApiToken(credentials);

  for (const host of hosts) {
    const response = await fetch(
      `${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    if (response.status === 404) continue;
    if (!response.ok) {
      throw new HttpsError(
        response.status === 401 || response.status === 403 ?
          "failed-precondition" : "unavailable",
        "App Store purchase verification is unavailable.",
        { reason: "PREMIUM_VERIFICATION_UNAVAILABLE" }
      );
    }
    const body = await response.json() as { signedTransactionInfo?: string };
    if (!body.signedTransactionInfo) {
      throw invalidPurchase("App Store transaction was not found.");
    }
    return decodeJwsPayload<AppleTransaction>(body.signedTransactionInfo);
  }
  throw invalidPurchase("App Store transaction was not found.");
}

function validateAppleTransaction(transaction: AppleTransaction): VerifiedPremium {
  const productId = transaction.productId ?? "";
  const premiumUntil = new Date(Number(transaction.expiresDate ?? 0));
  if (transaction.bundleId !== APP_ID ||
      !PREMIUM_PRODUCT_IDS.has(productId) ||
      !Number.isFinite(premiumUntil.getTime()) ||
      premiumUntil.getTime() <= Date.now() ||
      transaction.revocationDate != null) {
    throw invalidPurchase("An active Premium subscription was not found.");
  }
  const ownershipId = transaction.originalTransactionId ?? transaction.transactionId;
  if (!ownershipId) throw invalidPurchase("App Store transaction is incomplete.");
  return { provider: "app_store", productId, premiumUntil, ownershipId };
}

async function verifyAppleLegacyReceipt(
  receipt: string,
  credentials: AppleCredentials
): Promise<VerifiedPremium> {
  if (!credentials.sharedSecret) {
    throw new HttpsError(
      "failed-precondition",
      "Apple shared secret is not configured.",
      { reason: "PREMIUM_VERIFICATION_UNAVAILABLE" }
    );
  }

  const verify = async (url: string): Promise<Record<string, unknown>> => {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        "receipt-data": receipt,
        password: credentials.sharedSecret,
        "exclude-old-transactions": true,
      }),
    });
    if (!response.ok) {
      throw new HttpsError("unavailable", "App Store verification is unavailable.", {
        reason: "PREMIUM_VERIFICATION_UNAVAILABLE",
      });
    }
    return await response.json() as Record<string, unknown>;
  };

  let body = await verify("https://buy.itunes.apple.com/verifyReceipt");
  if (Number(body.status) === 21007) {
    body = await verify("https://sandbox.itunes.apple.com/verifyReceipt");
  }
  if (Number(body.status) !== 0) throw invalidPurchase("Invalid App Store receipt.");
  const receiptBody = body.receipt as Record<string, unknown> | undefined;
  if (receiptBody?.bundle_id !== APP_ID) throw invalidPurchase("Invalid App Store app receipt.");

  const entries = Array.isArray(body.latest_receipt_info) ?
    body.latest_receipt_info as Array<Record<string, unknown>> : [];
  const active = entries
    .filter((entry) => PREMIUM_PRODUCT_IDS.has(String(entry.product_id ?? "")))
    .filter((entry) => entry.cancellation_date_ms == null)
    .map((entry) => ({
      entry,
      expiresAt: Number(entry.expires_date_ms ?? 0),
    }))
    .filter((item) => Number.isFinite(item.expiresAt) && item.expiresAt > Date.now())
    .sort((a, b) => b.expiresAt - a.expiresAt)[0];
  if (!active) throw invalidPurchase("An active Premium subscription was not found.");

  const productId = String(active.entry.product_id ?? "");
  const ownershipId = String(
    active.entry.original_transaction_id ?? active.entry.transaction_id ?? ""
  );
  if (!ownershipId) throw invalidPurchase("App Store receipt is incomplete.");
  return {
    provider: "app_store",
    productId,
    premiumUntil: new Date(active.expiresAt),
    ownershipId,
  };
}

async function verifyApple(
  verificationData: string,
  credentials: AppleCredentials
): Promise<VerifiedPremium> {
  if (verificationData.split(".").length === 3) {
    const untrusted = decodeJwsPayload<AppleTransaction>(verificationData);
    if (!untrusted.transactionId) throw invalidPurchase("App Store transaction is incomplete.");
    const trusted = await fetchAppleTransaction(
      untrusted.transactionId,
      untrusted.environment,
      credentials
    );
    return validateAppleTransaction(trusted);
  }
  return verifyAppleLegacyReceipt(verificationData, credentials);
}

async function verifyGoogle(purchaseToken: string): Promise<VerifiedPremium> {
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const client = await auth.getClient();
  const accessToken = await client.getAccessToken();
  const token = typeof accessToken === "string" ? accessToken : accessToken.token;
  if (!token) {
    throw new HttpsError("failed-precondition", "Google Play verification is unavailable.", {
      reason: "PREMIUM_VERIFICATION_UNAVAILABLE",
    });
  }
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${APP_ID}` +
      `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
    { headers: { Authorization: `Bearer ${token}` } }
  );
  if (response.status === 404) throw invalidPurchase("Google Play purchase was not found.");
  if (!response.ok) {
    throw new HttpsError(
      response.status === 401 || response.status === 403 ?
        "failed-precondition" : "unavailable",
      "Google Play purchase verification is unavailable.",
      { reason: "PREMIUM_VERIFICATION_UNAVAILABLE" }
    );
  }
  const body = await response.json() as {
    subscriptionState?: string;
    lineItems?: Array<{ productId?: string; expiryTime?: string }>;
  };
  const activeStates = new Set([
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  ]);
  if (!activeStates.has(body.subscriptionState ?? "")) {
    throw invalidPurchase("An active Premium subscription was not found.");
  }
  const line = (body.lineItems ?? [])
    .filter((item) => PREMIUM_PRODUCT_IDS.has(item.productId ?? ""))
    .map((item) => ({
      productId: item.productId ?? "",
      premiumUntil: new Date(item.expiryTime ?? ""),
    }))
    .filter((item) => Number.isFinite(item.premiumUntil.getTime()) &&
      item.premiumUntil.getTime() > Date.now())
    .sort((a, b) => b.premiumUntil.getTime() - a.premiumUntil.getTime())[0];
  if (!line) throw invalidPurchase("An active Premium subscription was not found.");
  return {
    provider: "google_play",
    productId: line.productId,
    premiumUntil: line.premiumUntil,
    ownershipId: purchaseToken,
  };
}

async function persistVerifiedPremium(uid: string, verified: VerifiedPremium): Promise<Date> {
  const db = admin.firestore();
  const ownershipHash = createHash("sha256")
    .update(`${verified.provider}:${verified.ownershipId}`)
    .digest("hex");
  const ownershipRef = db.collection("premiumTransactions").doc(ownershipHash);
  const accessRef = aiAccessDocument(uid);

  return db.runTransaction(async (transaction) => {
    const ownership = await transaction.get(ownershipRef);
    const access = await transaction.get(accessRef);
    const ownerUid = ownership.data()?.uid;
    if (ownerUid != null && ownerUid !== uid) {
      throw new HttpsError("permission-denied", "Purchase belongs to another account.", {
        reason: "PREMIUM_PURCHASE_ALREADY_CLAIMED",
      });
    }
    const existingUntil = access.data()?.premiumUntil;
    const effectiveUntil = existingUntil instanceof admin.firestore.Timestamp &&
      existingUntil.toMillis() > verified.premiumUntil.getTime() ?
      existingUntil.toDate() : verified.premiumUntil;

    transaction.set(ownershipRef, {
      uid,
      provider: verified.provider,
      productId: verified.productId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(ownership.exists ? {} : {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    }, { merge: true });
    transaction.set(accessRef, {
      premiumUntil: admin.firestore.Timestamp.fromDate(effectiveUntil),
      premiumProvider: verified.provider,
      premiumProductId: verified.productId,
      premiumVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return effectiveUntil;
  });
}

export async function verifyAndPersistPremium(
  uid: string,
  source: unknown,
  verificationData: unknown,
  appleCredentialsRaw: string
): Promise<{ premium: true; premiumUntil: string }> {
  if (typeof source !== "string" || typeof verificationData !== "string" ||
      !verificationData || verificationData.length > MAX_VERIFICATION_DATA_LENGTH) {
    throw invalidPurchase("Purchase verification data is invalid.");
  }
  const verified = source === "app_store" ?
    await verifyApple(verificationData, parseAppleCredentials(appleCredentialsRaw)) :
    source === "google_play" ? await verifyGoogle(verificationData) : null;
  if (!verified) throw invalidPurchase("Unsupported purchase provider.");
  const premiumUntil = await persistVerifiedPremium(uid, verified);
  return { premium: true, premiumUntil: premiumUntil.toISOString() };
}
