import MoyuCore
import WidgetKit

struct MoyuWidgetEntry: TimelineEntry {
  var date: Date
  var item: WidgetTimelineItem
}

struct MoyuTimelineProvider: TimelineProvider {
  private let appGroup = "group.com.ysq.moyu"

  func placeholder(in context: Context) -> MoyuWidgetEntry {
    let now = Date()
    return MoyuWidgetEntry(
      date: now,
      item: WidgetTimelineItem(
        date: now,
        phase: .afterLunch,
        label: "距离下班",
        targetDate: now.addingTimeInterval(3 * 3600)
      )
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (MoyuWidgetEntry) -> Void) {
    completion(currentEntry() ?? placeholder(in: context))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MoyuWidgetEntry>) -> Void) {
    guard let payload = loadPayload(), !payload.items.isEmpty else {
      let entry = placeholder(in: context)
      completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
      return
    }

    let now = Date()
    let current = payload.items.last(where: { $0.date <= now }) ?? payload.items[0]
    var entries = [MoyuWidgetEntry(date: now, item: current)]
    entries += payload.items
      .filter { $0.date > now }
      .map { MoyuWidgetEntry(date: $0.date, item: $0) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func currentEntry() -> MoyuWidgetEntry? {
    guard let payload = loadPayload() else { return nil }
    let now = Date()
    guard let item = payload.items.last(where: { $0.date <= now }) ?? payload.items.first else {
      return nil
    }
    return MoyuWidgetEntry(date: now, item: item)
  }

  private func loadPayload() -> WidgetTimelinePayload? {
    guard
      let base = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup
      ),
      let data = try? Data(contentsOf: base.appending(path: "widget-timeline.json"))
    else { return nil }
    return try? WidgetTimelineJSON.decode(data)
  }
}
