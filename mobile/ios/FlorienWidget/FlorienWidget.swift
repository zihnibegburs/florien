import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

private let appGroupId = "group.com.florien.app"
private let sharedDefault = UserDefaults(suiteName: appGroupId)!

private func widgetChrome(_ key: String, fallback: String) -> String {
    let value = sharedDefault.string(forKey: key) ?? ""
    if !value.isEmpty { return value }
    let catalogKey = "widget.\(key)"
    let localized = String(localized: LocalizedStringResource(stringLiteral: catalogKey))
    return localized == catalogKey ? fallback : localized
}

private func widgetChromeCount(_ key: String, fallback: String, count: Int) -> String {
    widgetChrome(key, fallback: fallback).replacingOccurrences(of: "{count}", with: "\(count)")
}

struct FlorienWidgetTask: Identifiable {
    let id: String
    let title: String
    let icon: String
}

struct FlorienWidgetEntry: TimelineEntry {
    let date: Date
    let profileId: String
    let dailyTaskCount: Int
    let dailyTasks: [FlorienWidgetTask]
    let todoTaskCount: Int
    let todoTasks: [FlorienWidgetTask]
}

struct FlorienWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlorienWidgetEntry {
        FlorienWidgetEntry(
            date: Date(),
            profileId: "primary",
            dailyTaskCount: 3,
            dailyTasks: [
                FlorienWidgetTask(id: "daily-1", title: "Kahvaltı yap", icon: "breakfast"),
                FlorienWidgetTask(id: "daily-2", title: "Toplantıya hazırlan", icon: "meeting"),
                FlorienWidgetTask(id: "daily-3", title: "Kısa yürüyüş", icon: "walking")
            ],
            todoTaskCount: 2,
            todoTasks: [
                FlorienWidgetTask(id: "todo-1", title: "E-postaları yanıtla", icon: "email"),
                FlorienWidgetTask(id: "todo-2", title: "Market listesi hazırla", icon: "groceries")
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FlorienWidgetEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlorienWidgetEntry>) -> Void) {
        let entry = readEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }

    private func readEntry() -> FlorienWidgetEntry {
        let dailyTasks = tasks(for: "daily_task")
        let todoTasks = tasks(for: "todo_task")
        return FlorienWidgetEntry(
            date: Date(),
            profileId: sharedDefault.string(forKey: "widget_profile_id") ?? "primary",
            dailyTaskCount: sharedDefault.integer(forKey: "daily_pending_count"),
            dailyTasks: dailyTasks,
            todoTaskCount: sharedDefault.integer(forKey: "todo_pending_count"),
            todoTasks: todoTasks
        )
    }

    private func tasks(for prefix: String) -> [FlorienWidgetTask] {
        (1...6).compactMap { index in
            let task = sharedDefault.string(forKey: "\(prefix)_\(index)") ?? ""
            let taskId = sharedDefault.string(forKey: "\(prefix)_\(index)_id") ?? ""
            let icon = sharedDefault.string(forKey: "\(prefix)_\(index)_icon") ?? "task"
            return task.isEmpty || taskId.isEmpty
                ? nil
                : FlorienWidgetTask(id: taskId, title: task, icon: icon)
        }
    }
}

struct FlorienWidgetView: View {
    let entry: FlorienWidgetEntry

    var body: some View {
        FlorienTaskListWidgetView(
            title: widgetChrome("chrome_daily_title", fallback: "Günlük plan"),
            taskCount: entry.dailyTaskCount,
            tasks: entry.dailyTasks,
            emptyMessage: widgetChrome("chrome_daily_empty", fallback: "Bugün için planın boş"),
            rootURL: FlorienWidgetURL.today,
            addURL: FlorienWidgetURL.dailyAdd,
            profileId: entry.profileId
        )
    }
}

struct FlorienTodoWidgetView: View {
    let entry: FlorienWidgetEntry

    var body: some View {
        FlorienTaskListWidgetView(
            title: widgetChrome("chrome_todo_title", fallback: "To-do"),
            taskCount: entry.todoTaskCount,
            tasks: entry.todoTasks,
            emptyMessage: widgetChrome("chrome_todo_empty", fallback: "To-do listen şu an boş"),
            rootURL: FlorienWidgetURL.todo,
            addURL: FlorienWidgetURL.todoAdd,
            profileId: entry.profileId
        )
    }
}

private struct FlorienTaskListWidgetView: View {
    let title: String
    let taskCount: Int
    let tasks: [FlorienWidgetTask]
    let emptyMessage: String
    let rootURL: URL
    let addURL: URL
    let profileId: String

    @Environment(\.widgetFamily) private var family

    private var visibleTasks: ArraySlice<FlorienWidgetTask> {
        tasks.prefix(maxVisibleTaskCount)
    }

    private var maxVisibleTaskCount: Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 3
        case .systemLarge:
            return 6
        default:
            return 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(FlorienWidgetStyle.ink)
                    .lineLimit(1)
                Spacer()
                Link(destination: addURL) {
                    ZStack {
                        Circle().fill(FlorienWidgetStyle.primary)
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundStyle(FlorienWidgetStyle.ink)
                    }
                    .frame(width: 26, height: 26)
                }
            }
            Text(widgetChromeCount("chrome_open_tasks", fallback: "{count} tamamlanmamış görev", count: taskCount))
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlorienWidgetStyle.muted)
            if tasks.isEmpty {
                Text(emptyMessage)
                    .font(.headline)
                    .foregroundStyle(FlorienWidgetStyle.ink)
                Text(widgetChrome("chrome_empty_hint", fallback: "Kendine biraz alan aç."))
                    .font(.caption)
                    .foregroundStyle(FlorienWidgetStyle.muted)
            } else {
                ForEach(visibleTasks) { task in
                    let completionURL = FlorienWidgetURL.taskComplete(
                        taskId: task.id,
                        source: rootURL == FlorienWidgetURL.today ? "daily" : "todo",
                        profileId: profileId
                    )
                    HStack(spacing: 8) {
                        FlorienWidgetTaskIcon(icon: task.icon)
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FlorienWidgetStyle.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if family != .systemSmall {
                            Link(destination: completionURL) {
                                Image(systemName: "circle")
                                    .font(.title3)
                                    .foregroundStyle(FlorienWidgetStyle.muted)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .widgetURL(rootURL)
        .florienWidgetContainerBackground()
    }
}

private struct FlorienWidgetTaskIcon: View {
    let icon: String

    private var symbolName: String {
        florienTaskSymbolName(for: icon)
    }

    var body: some View {
        ZStack {
            Circle().fill(FlorienWidgetStyle.lilacSoft)
            Image(systemName: symbolName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(FlorienWidgetStyle.ink)
        }
        .frame(width: 22, height: 22)
    }
}

private func florienTaskSymbolName(for icon: String) -> String {
    switch icon {
    case "meeting", "groups": return "person.2.fill"
    case "email": return "envelope.fill"
    case "phone_call": return "phone.fill"
    case "work", "project", "presentation": return "briefcase.fill"
    case "deadline", "timer": return "timer"
    case "coding", "code": return "chevron.left.forwardslash.chevron.right"
    case "bug_fix": return "ladybug.fill"
    case "research", "search": return "magnifyingglass"
    case "study", "school", "homework", "menu_book", "reading": return "book.fill"
    case "exam", "writing", "note_taking": return "pencil"
    case "language_learning": return "character.book.closed.fill"
    case "childcare", "child_care": return "person.2.fill"
    case "sleep", "bedtime": return "moon.zzz.fill"
    case "shopping", "groceries", "shopping_bag", "online_order": return "cart.fill"
    case "clothes_shopping": return "tshirt.fill"
    case "electronics_shopping": return "headphones"
    case "gift", "birthday": return "gift.fill"
    case "return_item", "pickup", "delivery": return "shippingbox.fill"
    case "breakfast", "lunch", "dinner", "restaurant", "cooking": return "fork.knife"
    case "coffee", "drinks": return "cup.and.saucer.fill"
    case "food_order", "meal_prep", "baking": return "takeoutbag.and.cup.and.straw.fill"
    case "appointment": return "calendar"
    case "doctor", "health", "hospital", "checkup": return "cross.case.fill"
    case "dentist": return "mouth.fill"
    case "medicine", "medication", "pharmacy", "vaccination": return "pills.fill"
    case "therapy", "medical_test": return "heart.text.square.fill"
    case "meditation", "self_improvement", "yoga": return "figure.mind.and.body"
    case "running", "directions_run": return "figure.run"
    case "walking", "directions_walk": return "figure.walk"
    case "gym", "fitness", "workout", "stretching": return "dumbbell.fill"
    case "cycling": return "bicycle"
    case "swimming": return "figure.pool.swim"
    case "sport": return "sportscourt.fill"
    case "travel", "trip_planning", "sightseeing": return "map.fill"
    case "flight": return "airplane"
    case "hotel", "vacation": return "building.2.fill"
    case "luggage", "passport", "visa": return "suitcase.fill"
    case "reservation": return "ticket.fill"
    case "car", "directions_car", "driving": return "car.fill"
    case "car_maintenance", "car_repair": return "wrench.and.screwdriver.fill"
    case "fuel": return "fuelpump.fill"
    case "car_wash": return "drop.fill"
    case "parking": return "parkingsign.circle.fill"
    case "public_transport", "taxi": return "bus.fill"
    case "train": return "tram.fill"
    case "home", "home_repair", "furniture", "moving", "organizing": return "house.fill"
    case "cleaning", "laundry", "dishes": return "sparkles"
    case "gardening", "yard": return "leaf.fill"
    case "bills": return "doc.text.fill"
    case "finance": return "wallet.pass.fill"
    case "payment", "subscription": return "creditcard.fill"
    case "banking": return "building.columns.fill"
    case "family", "friends": return "person.2.fill"
    case "pet", "pets": return "pawprint.fill"
    case "entertainment", "movie", "music", "videocam": return "film.fill"
    default: return "checklist"
    }
}

@main
struct FlorienWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlorienWidget()
        FlorienTodoWidget()
        FlorienFocus15Widget()
        FlorienFocusPresetsWidget()
        FlorienQuickAddWidget()
        FlorienQuickActionsWidget()
        if #available(iOS 16.1, *) {
            FlorienLiveActivityWidget()
        }
    }
}

struct FlorienWidget: Widget {
    let kind: String = "FlorienWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlorienWidgetProvider()) { entry in
            FlorienWidgetView(entry: entry)
        }
        .configurationDisplayName(widgetChrome("chrome_name_daily", fallback: "Günlük Plan"))
        .description(LocalizedStringResource("widget.desc.daily"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct FlorienTodoWidget: Widget {
    let kind: String = "FlorienTodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlorienWidgetProvider()) { entry in
            FlorienTodoWidgetView(entry: entry)
        }
        .configurationDisplayName(widgetChrome("chrome_name_todo", fallback: "To-do"))
        .description(LocalizedStringResource("widget.desc.todo"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct FlorienFocus15Widget: Widget {
    let kind: String = "FlorienFocus15Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlorienWidgetProvider()) { _ in
            FlorienFocus15WidgetView()
        }
        .configurationDisplayName(widgetChrome("chrome_name_focus15", fallback: "15 dk Odaklan"))
        .description(LocalizedStringResource("widget.desc.focus15"))
        .supportedFamilies([.systemSmall])
    }
}

struct FlorienFocus15WidgetView: View {
    var body: some View {
        Link(destination: FlorienWidgetURL.focus(minutes: 15)) {
            VStack(alignment: .leading, spacing: 10) {
                Text(widgetChrome("chrome_focus_brand", fallback: "Florien · Odaklan"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FlorienWidgetStyle.ink)
                Spacer(minLength: 0)
                Text(widgetChrome("chrome_focus_ready_nl", fallback: "15 dakikalık\nalanın hazır"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FlorienWidgetStyle.ink)
                FlorienWidgetPill(label: widgetChrome("chrome_start", fallback: "▶ Başla"), color: FlorienWidgetStyle.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
        }
        .florienWidgetContainerBackground()
    }
}

struct FlorienFocusPresetsWidget: Widget {
    let kind: String = "FlorienFocusPresetsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlorienWidgetProvider()) { _ in
            FlorienFocusPresetsWidgetView()
        }
        .configurationDisplayName(widgetChrome("chrome_name_presets", fallback: "Odak Süresi"))
        .description(LocalizedStringResource("widget.desc.presets"))
        .supportedFamilies([.systemMedium])
    }
}

struct FlorienFocusPresetsWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(widgetChrome("chrome_focus_how_long", fallback: "Ne kadar odaklanmak istersin?"))
                .font(.headline.weight(.bold))
                .foregroundStyle(FlorienWidgetStyle.ink)
            HStack(spacing: 7) {
                ForEach([5, 10, 15, 30], id: \.self) { minutes in
                    Link(destination: FlorienWidgetURL.focus(minutes: minutes)) {
                        FlorienWidgetPill(
                            label: widgetChrome("chrome_min_\(minutes)", fallback: "\(minutes) dk"),
                            color: minutes == 15
                                ? FlorienWidgetStyle.primary
                                : FlorienWidgetStyle.card
                        )
                    }
                }
            }
        }
        .padding()
        .florienWidgetContainerBackground()
    }
}

struct FlorienQuickAddWidget: Widget {
    let kind: String = "FlorienQuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlorienWidgetProvider()) { _ in
            FlorienQuickAddWidgetView()
        }
        .configurationDisplayName(widgetChrome("chrome_name_quick_add", fallback: "Hızlı To-do"))
        .description(LocalizedStringResource("widget.desc.quick_add"))
        .supportedFamilies([.systemSmall])
    }
}

struct FlorienQuickAddWidgetView: View {
    var body: some View {
        Link(destination: FlorienWidgetURL.todoAdd) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(FlorienWidgetStyle.ink)
                Spacer(minLength: 0)
                Text(widgetChrome("chrome_quick_prompt", fallback: "Aklına bir şey mi geldi?"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FlorienWidgetStyle.ink)
                FlorienWidgetPill(label: widgetChrome("chrome_quick_cta", fallback: "＋ To-do ekle"), color: FlorienWidgetStyle.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
        }
        .florienWidgetContainerBackground()
    }
}

struct FlorienQuickActionsWidget: Widget {
    let kind: String = "FlorienQuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlorienWidgetProvider()) { _ in
            FlorienQuickActionsWidgetView()
        }
        .configurationDisplayName(widgetChrome("chrome_name_quick_actions", fallback: "Florien Hızlı Eylemler"))
        .description(LocalizedStringResource("widget.desc.quick_actions"))
        .supportedFamilies([.systemMedium])
    }
}

private struct FlorienQuickActionsWidgetView: View {
    var body: some View {
        VStack(spacing: 14) {
            Link(destination: FlorienWidgetURL.ai) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(FlorienWidgetStyle.actionSurface)
                    HStack {
                        Text(widgetChrome("chrome_ai_prompt", fallback: "Planın nedir?"))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(FlorienWidgetStyle.ink)
                        Spacer()
                        ZStack {
                            Circle().fill(FlorienWidgetStyle.primary)
                            Image(systemName: "mic.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(FlorienWidgetStyle.ink)
                        }
                        .frame(width: 40, height: 40)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "sparkles")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(FlorienWidgetStyle.lilac)
                                .offset(x: 7, y: -5)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            HStack(spacing: 12) {
                FlorienQuickActionButton(icon: "calendar", color: FlorienWidgetStyle.lilacSoft, url: FlorienWidgetURL.today)
                FlorienQuickActionButton(icon: "checkmark.square", color: FlorienWidgetStyle.primarySoft, url: FlorienWidgetURL.todoAdd)
                FlorienQuickActionButton(icon: "calendar.badge.plus", color: FlorienWidgetStyle.primary, url: FlorienWidgetURL.dailyAdd)
                FlorienQuickActionButton(icon: "timer", color: FlorienWidgetStyle.greenSoft, url: FlorienWidgetURL.focusScreen)
            }
        }
        .padding()
        .florienWidgetContainerBackground()
    }
}

private struct FlorienQuickActionButton: View {
    let icon: String
    let color: Color
    let url: URL

    var body: some View {
        Link(destination: url) {
            ZStack {
                Circle().fill(color)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FlorienWidgetStyle.ink)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

private enum FlorienWidgetURL {
    static let today = URL(string: "florien://widget/today?homeWidget=1")!
    static let todo = URL(string: "florien://widget/todo?homeWidget=1")!
    static let todoAdd = URL(string: "florien://widget/todo/add?homeWidget=1")!
    static let dailyAdd = URL(string: "florien://widget/daily/add?homeWidget=1")!
    static let ai = URL(string: "florien://widget/ai?homeWidget=1")!
    static let focusScreen = URL(string: "florien://widget/focus/screen?homeWidget=1")!
    static let focusStop = URL(string: "florien://widget/focus/stop?homeWidget=1")!

    static func focus(minutes: Int) -> URL {
        URL(string: "florien://widget/focus?minutes=\(minutes)&homeWidget=1")!
    }

    static func taskComplete(taskId: String, source: String, profileId: String) -> URL {
        var components = URLComponents()
        components.scheme = "florien"
        components.host = "widget"
        components.path = "/task/complete"
        components.queryItems = [
            URLQueryItem(name: "taskId", value: taskId),
            URLQueryItem(name: "source", value: source),
            URLQueryItem(name: "profileId", value: profileId),
            URLQueryItem(name: "homeWidget", value: "1")
        ]
        return components.url!
    }
}

private enum FlorienWidgetStyle {
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.18)
    static let muted = Color(red: 0.35, green: 0.33, blue: 0.39)
    static let primary = Color(red: 0.95, green: 0.74, blue: 0.32)
    static let card = Color(red: 1.0, green: 0.99, blue: 0.97)
    static let lilac = Color(red: 0.67, green: 0.63, blue: 0.87)
    static let actionSurface = Color(red: 0.91, green: 0.89, blue: 0.96)
    static let lilacSoft = Color(red: 0.84, green: 0.80, blue: 0.93)
    static let primarySoft = Color(red: 0.99, green: 0.91, blue: 0.68)
    static let greenSoft = Color(red: 0.75, green: 0.87, blue: 0.78)
}

private struct FlorienWidgetPill: View {
    let label: String
    let color: Color

    var body: some View {
        ZStack {
            Capsule().fill(color)
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(FlorienWidgetStyle.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    @ViewBuilder
    func florienWidgetContainerBackground(_ color: Color = FlorienWidgetStyle.card) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            self
        }
    }
}

// MARK: - Live Activities

@available(iOS 16.1, *)
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {}

    var id = UUID()
}

@available(iOS 16.1, *)
extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        "\(id)_\(key)"
    }
}

@available(iOS 16.1, *)
private struct FlorienLiveActivityData {
    let activityKind: String
    let taskTitle: String
    let taskIcon: String
    let usesDefaultFocusIcon: Bool
    let remaining: String
    let statusLabel: String
    let accentColor: Color
    let isPaused: Bool
    let timerStartDate: Date
    let timerEndDate: Date

    init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
        let key = context.attributes.prefixedKey
        activityKind = sharedDefault.string(forKey: key("activityKind")) ?? "focus"
        taskTitle = sharedDefault.string(forKey: key("taskTitle")) ?? "Florien"
        taskIcon = sharedDefault.string(forKey: key("taskIcon")) ?? ""
        usesDefaultFocusIcon = sharedDefault.integer(forKey: key("usesDefaultFocusIcon")) == 1
        remaining = sharedDefault.string(forKey: key("remaining")) ?? "--:--"
        statusLabel = sharedDefault.string(forKey: key("statusLabel")) ?? "Florien"
        let colorHex = sharedDefault.string(forKey: key("color")) ?? "#8FB6A0"
        accentColor = Color(hex: colorHex)
        isPaused = sharedDefault.integer(forKey: key("paused")) == 1

        let startMs = sharedDefault.double(forKey: key("timerStartDate"))
        let endMs = sharedDefault.double(forKey: key("timerEndDate"))
        timerStartDate = startMs > 0
            ? Date(timeIntervalSince1970: startMs / 1000)
            : Date()
        timerEndDate = endMs > 0
            ? Date(timeIntervalSince1970: endMs / 1000)
            : Date().addingTimeInterval(30 * 60)
    }

}

@available(iOS 16.1, *)
struct FlorienLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let data = FlorienLiveActivityData(context: context)

            FlorienLockScreenLiveActivityView(data: data)
                .widgetURL(FlorienWidgetURL.focusScreen)
        } dynamicIsland: { context in
            let data = FlorienLiveActivityData(context: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 6) {
                        FlorienAppMark(size: 26)
                        Text("Florien")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(data.statusLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(data.accentColor)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        FlorienAppMark(size: 18)
                        FlorienTimerLabel(data: data, font: .title3.bold())
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(data.taskTitle)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        ProgressView(timerInterval: data.timerStartDate...data.timerEndDate, countsDown: true)
                            .tint(data.accentColor)
                            .opacity(data.isPaused ? 0.35 : 1)
                        Link(destination: FlorienWidgetURL.focusStop) {
                            Image(systemName: "stop.fill")
                                .font(.caption.bold())
                                .foregroundStyle(FlorienWidgetStyle.ink)
                                .padding(7)
                                .background(FlorienWidgetStyle.primary, in: Circle())
                        }
                        .accessibilityLabel(widgetChrome("chrome_stop_a11y", fallback: "Odaklanmayı durdur"))
                    }
                }
            } compactLeading: {
                FlorienAppMark(size: 20)
            } compactTrailing: {
                FlorienTimerLabel(data: data, font: .caption2.monospacedDigit().bold())
            } minimal: {
                FlorienAppMark(size: 16)
            }
            .widgetURL(FlorienWidgetURL.focusScreen)
        }
    }
}

@available(iOS 16.1, *)
private struct FlorienAppMark: View {
    var size: CGFloat = 20

    var body: some View {
        iconImage
            .resizable()
            .interpolation(.high)
            .renderingMode(.original)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityLabel("Florien")
    }

    private var iconImage: Image {
        if let uiImage = UIImage(named: "FlorienAppIcon")
            ?? UIImage(named: "florien-live-activity-icon") {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "square.grid.2x2.fill")
    }
}

@available(iOS 16.1, *)
private struct FlorienLockScreenLiveActivityView: View {
    let data: FlorienLiveActivityData

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(data.accentColor.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(data.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                FlorienLiveActivityFocusIcon(data: data)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(data.taskTitle)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    FlorienAppMark(size: 18)
                    FlorienTimerLabel(data: data, font: .title3.bold())
                        .foregroundStyle(data.accentColor)
                }
            }

            Spacer(minLength: 0)

            Link(destination: FlorienWidgetURL.focusStop) {
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.caption.bold())
                    Text(widgetChrome("chrome_stop", fallback: "Durdur"))
                        .font(.caption2.bold())
                }
                .foregroundStyle(FlorienWidgetStyle.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(FlorienWidgetStyle.primary, in: Capsule())
            }
            .accessibilityLabel(widgetChrome("chrome_stop_a11y", fallback: "Odaklanmayı durdur"))
        }
        .padding()
    }

    private var progress: CGFloat {
        let total = max(data.timerEndDate.timeIntervalSince(data.timerStartDate), 1)
        let remaining = max(data.timerEndDate.timeIntervalSinceNow, 0)
        return CGFloat(1 - (remaining / total))
    }
}

@available(iOS 16.1, *)
private struct FlorienLiveActivityFocusIcon: View {
    let data: FlorienLiveActivityData
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(centerBackground)
            if data.usesDefaultFocusIcon {
                Image("focus-default-hourglass")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: florienTaskSymbolName(for: data.taskIcon))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(data.accentColor)
            }
        }
        .frame(width: 44, height: 44)
    }

    private var centerBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.15, blue: 0.18)
            : Color(red: 1.0, green: 0.99, blue: 0.97)
    }
}

@available(iOS 16.1, *)
private struct FlorienTimerLabel: View {
    let data: FlorienLiveActivityData
    let font: Font

    var body: some View {
        if data.isPaused {
            Text(data.remaining)
                .font(font)
                .monospacedDigit()
        } else {
            Text(timerInterval: data.timerStartDate...data.timerEndDate, countsDown: true)
                .font(font)
                .monospacedDigit()
        }
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
