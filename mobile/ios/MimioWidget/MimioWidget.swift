import ActivityKit
import SwiftUI
import WidgetKit

private let appGroupId = "group.com.mimio.mimio"
private let sharedDefault = UserDefaults(suiteName: appGroupId)!

struct MimioWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let taskCount: Int
    let taskCountLabel: String
}

struct MimioWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MimioWidgetEntry {
        MimioWidgetEntry(
            date: Date(),
            title: "Breakfast",
            subtitle: "Up next · 08:00",
            taskCount: 3,
            taskCountLabel: "3 tasks"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MimioWidgetEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MimioWidgetEntry>) -> Void) {
        let entry = readEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }

    private func readEntry() -> MimioWidgetEntry {
        let active = sharedDefault.string(forKey: "active_task_title")
        let next = sharedDefault.string(forKey: "next_task_title")
        let title = active ?? next ?? sharedDefault.string(forKey: "widget_title") ?? "Mimio"
        let subtitle = sharedDefault.string(forKey: "widget_subtitle") ?? "Mimio"
        let count = sharedDefault.integer(forKey: "task_count")
        let countLabel = sharedDefault.string(forKey: "task_count_label") ?? "\(count)"
        return MimioWidgetEntry(
            date: Date(),
            title: title,
            subtitle: subtitle,
            taskCount: count,
            taskCountLabel: countLabel
        )
    }
}

struct MimioWidgetView: View {
    let entry: MimioWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mimio")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.42, green: 0.39, blue: 1.0))
                Spacer()
                Text(entry.taskCountLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(entry.title)
                .font(.headline)
                .lineLimit(2)
            Text(entry.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

@main
struct MimioWidgetBundle: WidgetBundle {
    var body: some Widget {
        MimioWidget()
        if #available(iOS 16.1, *) {
            MimioLiveActivityWidget()
        }
    }
}

struct MimioWidget: Widget {
    let kind: String = "MimioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MimioWidgetProvider()) { entry in
            MimioWidgetView(entry: entry)
        }
        .configurationDisplayName("Mimio Plan")
        .description("Günlük planını ana ekrandan takip et.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Live Activities

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {}

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        "\(id)_\(key)"
    }
}

private struct MimioLiveActivityData {
    let taskTitle: String
    let remaining: String
    let statusLabel: String
    let accentColor: Color
    let isPaused: Bool
    let timerStartDate: Date
    let timerEndDate: Date

    init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
        let key = context.attributes.prefixedKey
        taskTitle = sharedDefault.string(forKey: key("taskTitle")) ?? "Mimio"
        remaining = sharedDefault.string(forKey: key("remaining")) ?? "--:--"
        statusLabel = sharedDefault.string(forKey: key("statusLabel")) ?? "Mimio"
        let colorHex = sharedDefault.string(forKey: key("color")) ?? "#4F52B2"
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
struct MimioLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let data = MimioLiveActivityData(context: context)

            MimioLockScreenLiveActivityView(data: data)
                .widgetURL(URL(string: "mimio://focus")!)
        } dynamicIsland: { context in
            let data = MimioLiveActivityData(context: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mimio")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(data.statusLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(data.accentColor)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MimioTimerLabel(data: data, font: .title3.bold())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(data.taskTitle)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: data.timerStartDate...data.timerEndDate, countsDown: true)
                        .tint(data.accentColor)
                        .opacity(data.isPaused ? 0.35 : 1)
                }
            } compactLeading: {
                Image(systemName: data.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(data.accentColor)
            } compactTrailing: {
                MimioTimerLabel(data: data, font: .caption2.monospacedDigit().bold())
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(data.accentColor)
            }
            .widgetURL(URL(string: "mimio://focus")!)
        }
    }
}

@available(iOS 16.1, *)
private struct MimioLockScreenLiveActivityView: View {
    let data: MimioLiveActivityData

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(data.accentColor.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(data.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(data.taskTitle)
                    .font(.headline)
                    .lineLimit(2)
                MimioTimerLabel(data: data, font: .title3.bold())
                    .foregroundStyle(data.accentColor)
            }

            Spacer(minLength: 0)
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
private struct MimioTimerLabel: View {
    let data: MimioLiveActivityData
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
