import { logger } from "firebase-functions";
import {
  persistAppleAppAccountToken,
  uidForAppAccountToken,
} from "./apple-account-token";
import { applyAppStoreEntitlementChange } from "./premium-entitlement";
import {
  APP_ID,
  AppleCredentials,
  AppleTransaction,
  PREMIUM_PRODUCT_IDS,
  decodeJwsPayload,
  fetchAppleTransaction,
} from "./premium-verification";

type AppleNotificationPayload = {
  notificationType?: string;
  subtype?: string;
  notificationUUID?: string;
  data?: {
    bundleId?: string;
    environment?: string;
    signedTransactionInfo?: string;
  };
};

const REBIND_NOTIFICATION_TYPES = new Set([
  "SUBSCRIBED",
  "OFFER_REDEEMED",
]);

const RENEW_NOTIFICATION_TYPES = new Set([
  "DID_RENEW",
  "DID_CHANGE_RENEWAL_PREF",
  "DID_CHANGE_RENEWAL_STATUS",
  "DID_FAIL_TO_RENEW",
  "RENEWAL_EXTENDED",
  "RENEWAL_EXTENSION",
  "PRICE_INCREASE",
]);

const REVOKE_NOTIFICATION_TYPES = new Set([
  "EXPIRED",
  "REFUND",
  "REVOKE",
  "GRACE_PERIOD_EXPIRED",
]);

function appleEntitlementUntil(transaction: AppleTransaction): Date | null {
  if (transaction.bundleId != null && transaction.bundleId !== APP_ID) return null;
  if (!PREMIUM_PRODUCT_IDS.has(transaction.productId ?? "")) return null;
  if (transaction.revocationDate != null) return null;
  const expiresAt = new Date(Number(transaction.expiresDate ?? 0));
  if (!Number.isFinite(expiresAt.getTime()) || expiresAt.getTime() <= Date.now()) {
    return null;
  }
  return expiresAt;
}

/**
 * App Store Server Notifications V2.
 * Re-fetches the transaction from Apple so the JWS body is not trusted alone.
 */
export async function handleAppleServerNotificationV2(
  signedPayload: string,
  credentials: AppleCredentials
): Promise<{
  notificationType: string;
  originalTransactionId: string | null;
  uid: string | null;
  transferredFrom: string | null;
}> {
  const notification = decodeJwsPayload<AppleNotificationPayload>(signedPayload);
  const notificationType = notification.notificationType ?? "";
  if (notificationType === "TEST" || notificationType === "") {
    return {
      notificationType: notificationType || "UNKNOWN",
      originalTransactionId: null,
      uid: null,
      transferredFrom: null,
    };
  }

  const signedTransactionInfo = notification.data?.signedTransactionInfo;
  if (!signedTransactionInfo) {
    logger.info("Apple S2S notification had no transaction.", {
      notificationType,
      subtype: notification.subtype,
      notificationUUID: notification.notificationUUID,
    });
    return {
      notificationType,
      originalTransactionId: null,
      uid: null,
      transferredFrom: null,
    };
  }

  const untrusted = decodeJwsPayload<AppleTransaction>(signedTransactionInfo);
  if (untrusted.bundleId != null && untrusted.bundleId !== APP_ID) {
    return {
      notificationType,
      originalTransactionId: untrusted.originalTransactionId ?? null,
      uid: null,
      transferredFrom: null,
    };
  }
  const lookupId = untrusted.transactionId ?? untrusted.originalTransactionId;
  if (!lookupId) {
    throw new Error("Apple notification transaction is incomplete.");
  }

  const trusted = await fetchAppleTransaction(
    lookupId,
    untrusted.environment ?? notification.data?.environment,
    credentials
  );
  const originalTransactionId =
    trusted.originalTransactionId ?? trusted.transactionId;
  if (!originalTransactionId) {
    throw new Error("Apple transaction is missing originalTransactionId.");
  }
  if (!PREMIUM_PRODUCT_IDS.has(trusted.productId ?? "")) {
    return {
      notificationType,
      originalTransactionId,
      uid: null,
      transferredFrom: null,
    };
  }

  const tokenUid = await uidForAppAccountToken(trusted.appAccountToken);
  const premiumUntil = appleEntitlementUntil(trusted);
  const shouldRevoke = REVOKE_NOTIFICATION_TYPES.has(notificationType) ||
    premiumUntil == null;
  const shouldRebind = !shouldRevoke &&
    REBIND_NOTIFICATION_TYPES.has(notificationType) &&
    tokenUid != null;
  const shouldRenew = !shouldRevoke &&
    (RENEW_NOTIFICATION_TYPES.has(notificationType) ||
      REBIND_NOTIFICATION_TYPES.has(notificationType));

  if (!shouldRevoke && !shouldRenew) {
    return {
      notificationType,
      originalTransactionId,
      uid: tokenUid,
      transferredFrom: null,
    };
  }

  if (tokenUid) await persistAppleAppAccountToken(tokenUid);

  const result = await applyAppStoreEntitlementChange({
    originalTransactionId,
    productId: trusted.productId ?? "",
    premiumUntil: shouldRevoke ? null : premiumUntil,
    bindUid: shouldRebind ? tokenUid : undefined,
    reason: notification.subtype ?
      `${notificationType}:${notification.subtype}` : notificationType,
    appAccountToken: trusted.appAccountToken,
  });

  logger.info("Apple S2S entitlement applied.", {
    notificationType,
    subtype: notification.subtype,
    originalTransactionId,
    uid: result.uid,
    transferredFrom: result.transferredFrom,
  });
  return {
    notificationType,
    originalTransactionId,
    uid: result.uid,
    transferredFrom: result.transferredFrom,
  };
}
