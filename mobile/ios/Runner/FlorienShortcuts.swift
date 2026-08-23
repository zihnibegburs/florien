import AppIntents

@available(iOS 16.0, *)
struct FlorienShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddFlorienTaskIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "Add a task to \(.applicationName)",
                "Görev ekle \(.applicationName) ile",
                "\(.applicationName) görev ekle",
                "\(.applicationName)'a görev ekle",
                "Añadir tarea en \(.applicationName)",
                "Ajouter une tâche dans \(.applicationName)",
                "Aufgabe in \(.applicationName) hinzufügen",
                "Adicionar tarefa no \(.applicationName)",
                "\(.applicationName)でタスクを追加",
                "\(.applicationName)에서 할 일 추가",
                "在\(.applicationName)中添加任务",
                "أضف مهمة في \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("intent.add_task.title"),
            systemImageName: "plus.circle.fill"
        )
    }
}
