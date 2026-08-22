/**
 * Quick Gemini connectivity check (does not print the API key).
 *
 * Usage:
 *   GEMINI_API_KEY="your-ai-studio-key" node scripts/test-gemini.js
 */
const { GoogleGenAI } = require("@google/genai");

const apiKey = (process.env.GEMINI_API_KEY ?? "").trim();
const model = (process.env.GEMINI_MODEL ?? "gemini-3.1-flash-lite").trim();

async function main() {
  if (!apiKey) {
    console.error("Set GEMINI_API_KEY env var (Google AI Studio key).");
    process.exit(1);
  }
  if (!apiKey.startsWith("AIza")) {
    console.warn("Warning: key does not start with AIza — is this an AI Studio key?");
  }

  const ai = new GoogleGenAI({ apiKey });
  console.log(`Testing model: ${model}`);

  try {
    const response = await ai.models.generateContent({
      model,
      contents: "Reply with JSON only: {\"ok\":true}",
      config: {
        responseMimeType: "application/json",
        maxOutputTokens: 32,
        temperature: 0,
      },
    });
    console.log("OK:", (response.text ?? "").trim());
  } catch (error) {
    console.error("FAILED:");
    console.error("  name:", error?.name);
    console.error("  status:", error?.status);
    console.error("  message:", error?.message);
    process.exit(1);
  }
}

main();
