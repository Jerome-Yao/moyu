import MoyuCore
import SwiftUI

struct HomeView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      HomeContent(now: context.date)
    }
    .background(MoyuTheme.warmBackground)
    .navigationTitle("moyu")
    .moyuInlineNavigationTitle()
    .toolbar { SettingsToolbarButton() }
  }

  @ViewBuilder
  private func HomeContent(now: Date) -> some View {
    let engine = model.incomeEngine()
    let income = try? engine.snapshot(at: now)
    let status = engine.workStatus(at: now)

    ScrollView {
      VStack(alignment: .leading, spacing: 34) {
        incomeHero(income)
        if let status { countdown(status) }
        workProgress(income)
        holidayProgress(now: now)
        retirement(now: now)
      }
      .padding(.horizontal, 22)
      .padding(.top, 24)
      .padding(.bottom, 48)
    }
  }

  private func incomeHero(_ snapshot: IncomeSnapshot?) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("今日已入账")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          model.configuration.privacyModeEnabled.toggle()
          Task { try? await model.save() }
        } label: {
          Image(systemName: model.configuration.privacyModeEnabled ? "eye.slash" : "eye")
            .font(.headline)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(model.configuration.privacyModeEnabled ? "显示金额" : "隐藏金额")
      }

      Text(
        MoyuFormat.money(
          snapshot?.earnedToday ?? .zero,
          private: model.configuration.privacyModeEnabled
        )
      )
      .font(.system(size: 52, weight: .bold, design: .rounded))
      .monospacedDigit()
      .contentTransition(.numericText())
      .foregroundStyle(.primary)
      .minimumScaleFactor(0.62)
      .lineLimit(1)

    }
    .accessibilityElement(children: .combine)
  }

  private func countdown(_ status: WorkStatus) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionLabel(status.label)
      Text(status.targetDate, style: .timer)
        .font(.system(size: 38, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(MoyuTheme.accent)
        .contentTransition(.numericText(countsDown: true))
    }
    .accessibilityElement(children: .combine)
  }

  private func workProgress(_ snapshot: IncomeSnapshot?) -> some View {
    let progress = snapshot?.workProgress ?? 0
    return VStack(alignment: .leading, spacing: 12) {
      SectionLabel(
        "今日工时",
        detail: progress.formatted(.percent.precision(.fractionLength(0)))
      )
      SlimProgress(value: progress)
      HStack {
        Text(model.configuration.schedule.workStart, format: .timeOfDay)
        Spacer()
        Text(model.configuration.schedule.workEnd, format: .timeOfDay)
      }
      .font(.caption.monospacedDigit())
      .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func holidayProgress(now: Date) -> some View {
    let state = HolidayProgressEngine(
      years: model.holidays.values.sorted { $0.year < $1.year }
    ).state(at: now)

    VStack(alignment: .leading, spacing: 12) {
      switch state {
      case .between(let previous, let next, let progress):
        SectionLabel(
          "\(previous.name) → \(next.name)",
          detail: progress.formatted(.percent.precision(.fractionLength(0))))
        SlimProgress(value: progress)
      case .inHoliday(let period, let current, let total):
        SectionLabel("\(period.name)假期中")
        Text("第 \(current) / \(total) 天")
          .font(.title2.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(MoyuTheme.accent)
      case .unavailable(let message):
        SectionLabel("节假日进度")
        Text(message)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private func retirement(now: Date) -> some View {
    if let mode = model.configuration.retirement,
      let snapshot = try? RetirementEngine().snapshot(for: mode, at: now)
    {
      VStack(alignment: .leading, spacing: 14) {
        SectionLabel("退休倒计时", detail: "仅供娱乐参考")
        HStack(alignment: .firstTextBaseline, spacing: 24) {
          retirementMetric(snapshot.remainingTotalYears, unit: "年")
          retirementMetric(snapshot.remainingTotalMonths, unit: "月")
          retirementMetric(snapshot.remainingDays, unit: "天")
        }
      }
    }
  }

  private func retirementMetric(_ value: Int, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value, format: .number.grouping(.automatic))
        .font(.title2.bold().monospacedDigit())
      Text(unit)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

struct SettingsToolbarButton: ToolbarContent {
  @Environment(AppModel.self) private var model

  var body: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Button {
        model.isShowingSettings = true
      } label: {
        Image(systemName: "gearshape")
      }
      .accessibilityLabel("设置")
    }
  }
}

extension FormatStyle where Self == TimeOfDayFormatStyle {
  static var timeOfDay: TimeOfDayFormatStyle { TimeOfDayFormatStyle() }
}

struct TimeOfDayFormatStyle: FormatStyle {
  func format(_ value: TimeOfDay) -> String {
    String(format: "%02d:%02d", value.hour, value.minute)
  }
}
