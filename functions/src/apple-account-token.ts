import { createHash } from "node:crypto";
import * as admin from "firebase-admin";

/** RFC 4122 URL namespace. Must match Dart and Swift. */
const URL_NAMESPACE = "6ba7b811-9dad-11d1-80b4-00c04fd430c8";

function uuidBytes(uuid: string): Buffer {
  return Buffer.from(uuid.replace(/-/g, ""), "hex");
}

function formatUuid(bytes: Buffer): string {
  const hex = bytes.subarray(0, 16).toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

export function uuidV5(name: string, namespace: string): string {
  const hash = createHash("sha1")
    .update(uuidBytes(namespace))
    .update(name, "utf8")
    .digest();
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  return formatUuid(hash);
}

export function normalizeAppAccountToken(value: string): string {
  const hex = value.trim().toLowerCase().replace(/-/g, "");
  if (!/^[0-9a-f]{32}$/.test(hex)) return value.trim().toLowerCase();
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

/** Deterministic UUID v5 for StoreKit 2 `appAccountToken`. */
export function appAccountTokenForUid(uid: string): string {
  return normalizeAppAccountToken(uuidV5(`florien.uid:${uid}`, URL_NAMESPACE));
}

export function appleAppAccountTokenDocument(
  token: string
): admin.firestore.DocumentReference {
  return admin.firestore()
    .collection("appleAppAccountTokens")
    .doc(normalizeAppAccountToken(token));
}

export async function persistAppleAppAccountToken(uid: string): Promise<string> {
  const token = appAccountTokenForUid(uid);
  await appleAppAccountTokenDocument(token).set({
    uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return token;
}

export async function uidForAppAccountToken(
  token: string | undefined
): Promise<string | null> {
  if (!token) return null;
  const snapshot = await appleAppAccountTokenDocument(token).get();
  const uid = snapshot.data()?.uid;
  return typeof uid === "string" && uid.length > 0 ? uid : null;
}
