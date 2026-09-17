const SUPPORTED_AI_LANGUAGES = [
  "en",
  "tr",
  "es",
  "de",
  "fr",
  "pt",
  "ja",
  "ko",
  "zh",
  "ar",
] as const;

const LANGUAGE_NAMES: Record<(typeof SUPPORTED_AI_LANGUAGES)[number], string> = {
  en: "English",
  tr: "Turkish",
  es: "Spanish",
  de: "German",
  fr: "French",
  pt: "Portuguese",
  ja: "Japanese",
  ko: "Korean",
  zh: "Chinese",
  ar: "Arabic",
};

export function normalizeAiLanguage(raw: unknown): string {
  if (typeof raw !== "string") return "en";
    const primary = raw.trim().toLowerCase().replace(/_/g, "-").split("-")[0];
  return (SUPPORTED_AI_LANGUAGES as readonly string[]).includes(primary)
    ? primary
    : "en";
}

export function aiLanguageName(code: string): string {
  return LANGUAGE_NAMES[code as keyof typeof LANGUAGE_NAMES] ?? "English";
}

export function aiLanguageInstruction(code: string): string {
  const name = aiLanguageName(code);
  return [
    `The app language is ${name} (${code}).`,
    `Write the reply and every task/step title in ${name}.`,
    `If the user's latest message is clearly in a different language, match that language instead.`,
    `Never reply in Turkish unless the user wrote in Turkish or the app language is Turkish.`,
  ].join(" ");
}

export function emptyPlannerReply(code: string): string {
  return code === "tr"
    ? "Planlamak istediğin şeyi biraz daha anlatır mısın?"
    : "Could you tell me a bit more about what you want to plan?";
}

export function normalizeTodoListNames(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const names: string[] = [];
  const seen = new Set<string>();
  for (const item of raw.slice(0, 20)) {
    if (typeof item !== "string") continue;
    const name = item.normalize("NFKC").replace(/\s+/g, " ").trim().slice(0, 40);
    if (!name) continue;
    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    names.push(name);
  }
  return names;
}

const DEFAULT_TODO_LIST_NAMES = new Set([
  "to-do",
  "todo",
  "to do",
  "inbox",
  "default",
]);

export function resolveReturnedTodoListName(
  raw: string,
  available: string[]
): string {
  const needle = raw.trim().toLowerCase();
  if (!needle || DEFAULT_TODO_LIST_NAMES.has(needle)) return "";
  return available.find((name) => name.toLowerCase() === needle) ?? "";
}
