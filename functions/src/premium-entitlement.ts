import { createHash } from "node:crypto";
import * as admin from "firebase-admin";
import { aiAccessDocument } from "./ai-protection";

export function premiumOwnershipHash(
  provider: "app_store" | "google_play",
  ownershipId: string
): string {
  return createHash("sha256").update(`${provider}:${ownershipId}`).digest("hex");
}

export function premiumOwnershipDocument(
  provider: "app_store" | "google_play",
  ownershipId: string
): admin.firestore.DocumentReference {
  return admin.firestore()
    .collection("premiumTransactions")
    .doc(premiumOwnershipHash(provider, ownershipId));
}

export type AppStoreEntitlementChange = {
  originalTransactionId: string;
  productId: string;
  /** `null` revokes the current owner's entitlement for this transaction. */
  premiumUntil: Date | null;
  /**
   * When set, bind/transfer the subscription to this Firebase uid.
   * When omitted, keep the current `premiumTransactions` owner (renewals).
   */
  bindUid?: string | null;
  reason: string;
  appAccountToken?: string;
};

function asUid(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function laterDate(first: Date | null, second: Date | null): Date | null {
  if (first == null) return second;
  if (second == null) return first;
  return first.getTime() >= second.getTime() ? first : second;
}

function accessBoundToOwnership(
  data: admin.firestore.DocumentData | undefined,
  ownershipHash: string,
  originalTransactionId: string
): boolean {
  const boundHash = data?.premiumOwnershipId;
  const boundOriginal = data?.premiumOriginalTransactionId;
  if (typeof boundHash === "string" && boundHash.length > 0) {
    return boundHash === ownershipHash;
  }
  if (typeof boundOriginal === "string" && boundOriginal.length > 0) {
    return boundOriginal === originalTransactionId;
  }
  // Legacy rows predate these fields; the ownership doc is the source of truth.
  return true;
}

function timestampOrNull(value: unknown): Date | null {
  return value instanceof admin.firestore.Timestamp ? value.toDate() : null;
}

/**
 * Atomically re-binds an App Store subscription (`originalTransactionId`)
 * from the previous Firebase uid to `bindUid`, or refreshes/revokes the
 * current owner. Old-account Premium is deactivated only when it is still
 * tied to this same Apple transaction.
 */
export async function applyAppStoreEntitlementChange(
  change: AppStoreEntitlementChange
): Promise<{ uid: string | null; transferredFrom: string | null }> {
  const db = admin.firestore();
  const ownershipRef = premiumOwnershipDocument(
    "app_store",
    change.originalTransactionId
  );
  const ownershipHash = ownershipRef.id;
  const appleUntil = change.premiumUntil != null &&
    Number.isFinite(change.premiumUntil.getTime()) &&
    change.premiumUntil.getTime() > Date.now() ?
    change.premiumUntil : null;
  const revoke = appleUntil == null;

  return db.runTransaction(async (transaction) => {
    const ownershipSnap = await transaction.get(ownershipRef);
    const ownership = ownershipSnap.data() ?? {};
    const currentUid = asUid(ownership.uid);
    const nextUid = revoke ? currentUid : (change.bindUid || currentUid);
    const transferring = !revoke &&
      nextUid != null &&
      currentUid != null &&
      currentUid !== nextUid;

    const currentAccessRef = currentUid ? aiAccessDocument(currentUid) : null;
    const nextAccessRef = nextUid && nextUid !== currentUid ?
      aiAccessDocument(nextUid) : currentAccessRef;

    const currentAccessSnap = currentAccessRef ?
      await transaction.get(currentAccessRef) : null;
    const nextAccessSnap = nextAccessRef && nextAccessRef !== currentAccessRef ?
      await transaction.get(nextAccessRef) : currentAccessSnap;

    const now = admin.firestore.FieldValue.serverTimestamp();
    const transferredFrom = transferring ? currentUid : null;

    if (transferring && currentAccessRef && currentAccessSnap) {
      if (accessBoundToOwnership(
        currentAccessSnap.data(),
        ownershipHash,
        change.originalTransactionId
      )) {
        transaction.set(currentAccessRef, {
          premiumUntil: admin.firestore.Timestamp.fromMillis(0),
          premiumStatus: "transferred",
          premiumTransferredTo: nextUid,
          premiumTransferredAt: now,
          premiumOwnershipId: admin.firestore.FieldValue.delete(),
        }, { merge: true });
      }
    } else if (revoke && currentAccessRef && currentAccessSnap) {
      if (accessBoundToOwnership(
        currentAccessSnap.data(),
        ownershipHash,
        change.originalTransactionId
      )) {
        transaction.set(currentAccessRef, {
          premiumUntil: admin.firestore.Timestamp.fromMillis(0),
          premiumStatus: "revoked",
          premiumRevokedAt: now,
          premiumRevokeReason: change.reason,
        }, { merge: true });
      }
    }

    if (!revoke && nextUid && nextAccessRef) {
      const existingUntil = nextAccessSnap && !transferring ?
        timestampOrNull(nextAccessSnap.data()?.premiumUntil) : null;
      const effectiveUntil = laterDate(existingUntil, appleUntil) ?? appleUntil;
      if (effectiveUntil) {
        transaction.set(nextAccessRef, {
          premiumUntil: admin.firestore.Timestamp.fromDate(effectiveUntil),
          premiumProvider: "app_store",
          premiumProductId: change.productId,
          premiumOriginalTransactionId: change.originalTransactionId,
          premiumOwnershipId: ownershipHash,
          premiumStatus: "active",
          premiumVerifiedAt: now,
          ...(transferredFrom ? { premiumTransferredFrom: transferredFrom } : {}),
        }, { merge: true });
      }
    }

    transaction.set(ownershipRef, {
      uid: nextUid,
      provider: "app_store",
      productId: change.productId,
      originalTransactionId: change.originalTransactionId,
      status: revoke ? "revoked" : "active",
      reason: change.reason,
      updatedAt: now,
      ...(change.appAccountToken ? { appAccountToken: change.appAccountToken } : {}),
      ...(ownershipSnap.exists ? {} : { createdAt: now }),
      ...(transferredFrom ? {
        previousUid: transferredFrom,
        transferredAt: now,
        transferredTo: nextUid,
      } : {}),
    }, { merge: true });

    return { uid: nextUid, transferredFrom };
  });
}
