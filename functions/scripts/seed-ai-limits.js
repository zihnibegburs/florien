/**
 * Creates or updates Firestore appConfig/aiLimits with default values.
 *
 * Run from repo root (requires Firebase Admin credentials):
 *   cd functions && npm run seed:ai-limits
 *
 * Uses Application Default Credentials (firebase login / gcloud auth).
 */
const admin = require("firebase-admin");

const DEFAULT_AI_LIMITS = {
  freeChatMessagesPerMonth: 3,
  premiumMessagesPerMinute: 5,
  premiumMessagesPerHour: 30,
  premiumMessagesPerDay: 100,
  premiumMessagesPerMonth: 3000,
  geminiModelName: "gemini-3.1-flash-lite",
};

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT ||
        process.env.GOOGLE_CLOUD_PROJECT ||
        "florien-74ad8",
    });
  }

  const ref = admin.firestore().collection("appConfig").doc("aiLimits");
  await ref.set(DEFAULT_AI_LIMITS, { merge: true });
  const snapshot = await ref.get();
  console.log("appConfig/aiLimits written:");
  console.log(JSON.stringify(snapshot.data(), null, 2));
}

main().catch((error) => {
  console.error("Failed to seed appConfig/aiLimits:", error);
  process.exit(1);
});
