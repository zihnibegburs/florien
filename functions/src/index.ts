import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

admin.initializeApp();

const groqApiKey = defineSecret("GROQ_API_KEY");

const COLORS = ["#6C63FF", "#FF6B9D", "#4ECDC4", "#FFE66D", "#FF8B5A", "#2ECC71"];
const GROQ_BASE = "https://api.groq.com/openai/v1";
const GROQ_MODEL = "llama-3.3-70b-versatile";

type GroqChatResponse = {
  choices?: Array<{ message?: { content?: string } }>;
};

async function callGroq(apiKey: string, userPrompt: string): Promise<Record<string, unknown>> {
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "GROQ_API_KEY secret is not configured."
    );
  }

  const response = await fetch(`${GROQ_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: GROQ_MODEL,
      temperature: 0.3,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: "Sen yardımcı bir planlama asistanısın. Her zaman geçerli JSON döndür.",
        },
        { role: "user", content: userPrompt },
      ],
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new HttpsError("internal", `Groq API error: ${response.status} ${text}`);
  }

  const json = (await response.json()) as GroqChatResponse;
  const content = json.choices?.[0]?.message?.content ?? "";
  return JSON.parse(extractJson(content)) as Record<string, unknown>;
}

function extractJson(content: string): string {
  const trimmed = content.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start >= 0 && end > start) {
    return trimmed.slice(start, end + 1);
  }
  return trimmed;
}

export const assistBreakdown = onCall({ secrets: [groqApiKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const task = String(request.data?.task ?? "").trim();
  if (!task) {
    throw new HttpsError("invalid-argument", "task is required");
  }

  const prompt = `Sen ADHD dostu bir görev planlama asistanısın. Kullanıcının görevini küçük, yapılabilir adımlara böl.
Her adım için gerçekçi süre (dakika) tahmin et. Türkçe yanıt ver.
SADECE aşağıdaki JSON formatında yanıt ver, başka hiçbir metin yazma:
{"steps":[{"title":"adım adı","durationMinutes":15}]}

Görev: ${task}`;

  const root = await callGroq(groqApiKey.value(), prompt);
  const stepsRaw = Array.isArray(root.steps) ? root.steps : [];
  const steps = stepsRaw
    .map((node, i) => {
      const item = node as Record<string, unknown>;
      const title = String(item.title ?? "").trim();
      if (!title) return null;
      const duration = Math.max(5, Number(item.durationMinutes ?? 15) || 15);
      return {
        title,
        durationMinutes: duration,
        color: COLORS[i % COLORS.length],
      };
    })
    .filter((s): s is { title: string; durationMinutes: number; color: string } => s != null);

  if (steps.length === 0) {
    throw new HttpsError("not-found", "AI adım üretemedi, tekrar dene");
  }

  const totalMinutes = steps.reduce((sum, s) => sum + s.durationMinutes, 0);
  return { originalTask: task, steps, totalMinutes };
});

export const assistPlan = onCall({ secrets: [groqApiKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const input = String(request.data?.input ?? "").trim();
  if (!input) {
    throw new HttpsError("invalid-argument", "input is required");
  }

  const planDate = String(request.data?.date ?? new Date().toISOString().slice(0, 10));

  const prompt = `Sen ADHD dostu bir günlük planlama asistanısın. Kullanıcının yazdığı düşünceleri yapılandırılmış günlük plana çevir.
Tarih: ${planDate}
Her görev için: başlık, süre (dakika), önerilen başlangıç saati (HH:mm formatında).
Gerçekçi ve uygulanabilir bir plan oluştur. Türkçe yanıt ver.
SADECE aşağıdaki JSON formatında yanıt ver:
{"summary":"kısa özet","tasks":[{"title":"görev","durationMinutes":30,"suggestedTime":"09:00"}]}

Kullanıcı yazdığı:
${input}`;

  const root = await callGroq(groqApiKey.value(), prompt);
  const summary = String(root.summary ?? "Günlük plan");
  const tasksRaw = Array.isArray(root.tasks) ? root.tasks : [];
  const tasks = tasksRaw
    .map((node, i) => {
      const item = node as Record<string, unknown>;
      const title = String(item.title ?? "").trim();
      if (!title) return null;
      return {
        title,
        durationMinutes: Math.max(5, Number(item.durationMinutes ?? 30) || 30),
        suggestedTime: String(item.suggestedTime ?? "09:00"),
        color: COLORS[i % COLORS.length],
      };
    })
    .filter(
      (t): t is {
        title: string;
        durationMinutes: number;
        suggestedTime: string;
        color: string;
      } => t != null
    );

  const totalMinutes = tasks.reduce((sum, t) => sum + t.durationMinutes, 0);
  return { date: planDate, summary, tasks, totalMinutes };
});
