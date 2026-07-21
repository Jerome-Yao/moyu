import MoyuCore
import SwiftUI

struct OnboardingView: View {
  @Environment(AppModel.self) private var model
  @State private var payMode = 0
  @State private var monthlySalary = "8000"
  @State private var salaryMonths = "12"
  @State private var annualPackage = "96000"
  @State private var schedule = WorkSchedule()
  @State private var errorMessage: String?
  @State private var isSaving = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 34) {
        VStack(alignment: .leading, spacing: 8) {
          Text("moyu")
            .font(.system(size: 48, weight: .bold, design: .rounded))
          Text("先告诉我你的工资和工作时间。")
            .font(.title3)
            .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 16) {
          SectionLabel("年度收入")
          Picker("输入方式", selection: $payMode) {
            Text("月薪 × 薪数").tag(0)
            Text("年度总包").tag(1)
          }
          .pickerStyle(.segmented)

          if payMode == 0 {
            moneyField("月薪", text: $monthlySalary)
            moneyField("薪数", text: $salaryMonths, symbol: "薪")
          } else {
            moneyField("年度总包", text: $annualPackage)
          }
        }

        VStack(alignment: .leading, spacing: 16) {
          SectionLabel("每周工作日")
          WeekdayPicker(selection: $schedule.workdays)
        }

        VStack(alignment: .leading, spacing: 14) {
          SectionLabel("工作时间")
          TimeRow("上班", value: $schedule.workStart)
          TimeRow("午休开始", value: $schedule.lunchStart)
          TimeRow("午休结束", value: $schedule.lunchEnd)
          TimeRow("下班", value: $schedule.workEnd)
        }

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
        }

        Button {
          Task { await finish() }
        } label: {
          HStack {
            if isSaving { ProgressView().controlSize(.small) }
            Text("进入 moyu")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.glassProminent)
        .tint(MoyuTheme.accent)
        .controlSize(.large)
        .disabled(isSaving)
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 36)
    }
    .background(MoyuTheme.warmBackground.ignoresSafeArea())
  }

  private func moneyField(_ title: String, text: Binding<String>, symbol: String = "¥") -> some View
  {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      TextField("0", text: text)
        .moyuDecimalKeyboard()
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
      Text(symbol)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 6)
  }

  private func finish() async {
    errorMessage = nil
    guard schedule.isValid else {
      errorMessage = "请检查工作日和时间顺序"
      return
    }

    let compensation: CompensationInput
    if payMode == 0,
      let salary = Decimal(string: monthlySalary),
      let months = Decimal(string: salaryMonths),
      salary > 0, months > 0
    {
      compensation = .monthly(monthlySalary: salary, salaryMonths: months)
    } else if payMode == 1,
      let annual = Decimal(string: annualPackage),
      annual > 0
    {
      compensation = .annual(totalPackage: annual)
    } else {
      errorMessage = "请输入有效的薪资金额"
      return
    }

    isSaving = true
    defer { isSaving = false }
    do {
      try await model.finishOnboarding(
        with: MoyuConfiguration(
          compensation: compensation,
          schedule: schedule
        ))
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

struct WeekdayPicker: View {
  @Binding var selection: Set<ISOWeekday>

  private let labels: [(ISOWeekday, String)] = [
    (.monday, "一"), (.tuesday, "二"), (.wednesday, "三"),
    (.thursday, "四"), (.friday, "五"), (.saturday, "六"), (.sunday, "日"),
  ]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(labels, id: \.0) { weekday, label in
        Button {
          if selection.contains(weekday) {
            selection.remove(weekday)
          } else {
            selection.insert(weekday)
          }
        } label: {
          Text(label)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
              selection.contains(weekday) ? MoyuTheme.accent : MoyuTheme.secondarySurface,
              in: Circle()
            )
            .foregroundStyle(selection.contains(weekday) ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("星期\(label)")
        .accessibilityAddTraits(selection.contains(weekday) ? .isSelected : [])
      }
    }
  }
}

struct TimeRow: View {
  let title: String
  @Binding var value: TimeOfDay

  init(_ title: String, value: Binding<TimeOfDay>) {
    self.title = title
    _value = value
  }

  var body: some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      DatePicker("", selection: dateBinding, displayedComponents: .hourAndMinute)
        .labelsHidden()
    }
  }

  private var dateBinding: Binding<Date> {
    Binding {
      Calendar.current.date(from: DateComponents(hour: value.hour, minute: value.minute)) ?? Date()
    } set: { date in
      let components = Calendar.current.dateComponents([.hour, .minute], from: date)
      value = TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
  }
}
