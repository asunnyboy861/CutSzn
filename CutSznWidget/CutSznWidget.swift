import WidgetKit
import SwiftUI

struct TargetEntry: TimelineEntry {
    let date: Date
    let tomorrowTarget: String
    let daysOut: Int
}

struct TargetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TargetEntry {
        TargetEntry(date: Date(), tomorrowTarget: "129.4 lbs", daysOut: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (TargetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TargetEntry>) -> Void) {
        let shared = UserDefaults(suiteName: "group.com.zzoutuo.CutSzn")
        let target = shared?.string(forKey: "widget.tomorrowTarget") ?? "—"
        let daysOut = shared?.integer(forKey: "widget.daysOut") ?? 0
        let entry = TargetEntry(date: Date(), tomorrowTarget: target, daysOut: daysOut)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

struct CutSznWidgetEntryView: View {
    var entry: TargetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOMORROW")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(entry.tomorrowTarget)
                .font(.system(size: family == .accessoryInline ? 12 : 22, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
            if family != .accessoryInline {
                Text(entry.daysOut == 0 ? "Weigh-in day" : "\(entry.daysOut) days out")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.04, green: 0.04, blue: 0.045)
        }
    }
}

struct CutSznWidget: Widget {
    let kind: String = "CutSznWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TargetProvider()) { entry in
            CutSznWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tomorrow's Number")
        .description("Your target weight for tomorrow morning.")
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryRectangular])
    }
}

@main
struct CutSznWidgetBundle: WidgetBundle {
    var body: some Widget {
        CutSznWidget()
    }
}
