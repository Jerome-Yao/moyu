import MoyuCore
import SwiftUI
import WidgetKit

struct MoyuWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var colorScheme
  let entry: MoyuWidgetEntry

  var body: some View {
    switch family {
    case .accessoryInline:
      inline
    case .accessoryRectangular:
      rectangular
    case .systemMedium:
      home(medium: true)
    default:
      home(medium: false)
    }
  }

  private var inline: some View {
    Label {
      Text(entry.item.targetDate, style: .timer)
    } icon: {
      Image(systemName: "clock")
    }
  }

  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(entry.item.label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(entry.item.targetDate, style: .timer)
        .font(.headline.monospacedDigit())
    }
  }

  private func home(medium: Bool) -> some View {
    VStack(alignment: .leading, spacing: medium ? 12 : 8) {
      HStack {
        Text("moyu")
          .font(.caption.weight(.bold))
        Spacer()
        Image(systemName: iconName)
          .foregroundStyle(.orange)
      }
      Spacer(minLength: 0)
      Text(entry.item.label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(entry.item.targetDate, style: .timer)
        .font(.system(size: medium ? 32 : 26, weight: .bold, design: .rounded))
        .monospacedDigit()
        .minimumScaleFactor(0.7)
      if let start = entry.item.workStart,
        let end = entry.item.workEnd,
        start < end
      {
        ProgressView(timerInterval: start...end, countsDown: false)
          .tint(.orange)
      }
    }
    .containerBackground(for: .widget) {
      colorScheme == .dark
        ? Color(red: 0.055, green: 0.05, blue: 0.045)
        : Color(red: 0.98, green: 0.96, blue: 0.91)
    }
  }

  private var iconName: String {
    switch entry.item.phase {
    case .beforeWork, .resting: "sunrise"
    case .beforeLunch: "cup.and.saucer"
    case .atLunch: "fork.knife"
    case .afterLunch: "figure.walk.departure"
    }
  }
}
