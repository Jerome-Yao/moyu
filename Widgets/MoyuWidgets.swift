import SwiftUI
import WidgetKit

@main
struct MoyuWidgets: WidgetBundle {
  var body: some Widget {
    MoyuCountdownWidget()
  }
}

struct MoyuCountdownWidget: Widget {
  let kind = "MoyuCountdownWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MoyuTimelineProvider()) { entry in
      MoyuWidgetView(entry: entry)
    }
    .configurationDisplayName("moyu 倒计时")
    .description("显示午休、下班或下一次上班倒计时。")
    .supportedFamilies(supportedFamilies)
  }

  private var supportedFamilies: [WidgetFamily] {
    #if os(iOS)
      [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
    #else
      [.systemSmall, .systemMedium]
    #endif
  }
}
