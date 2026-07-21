import MoyuCore
import SwiftUI

struct SavingsEditor: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var baseline = ""
  @State private var target = ""
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("存款") {
          TextField("期初存款", text: $baseline)
            .moyuDecimalKeyboard()
          TextField("目标存款", text: $target)
            .moyuDecimalKeyboard()
          Text("保存后，期初存款将视为今天 00:00 的余额，并从今天重新累计工资。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        if let errorMessage {
          Text(errorMessage).foregroundStyle(.red)
        }
      }
      .navigationTitle("存款设置")
      .moyuInlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") { Task { await save() } }
        }
      }
      .onAppear {
        if let plan = model.configuration.savings {
          baseline = NSDecimalNumber(decimal: plan.baselineAmount).stringValue
          target = plan.targetAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        }
      }
    }
  }

  private func save() async {
    guard let baselineValue = Decimal(string: baseline), baselineValue >= 0 else {
      errorMessage = "请输入有效的期初存款"
      return
    }
    let targetValue = target.isEmpty ? nil : Decimal(string: target)
    if let targetValue, targetValue <= 0 {
      errorMessage = "目标存款必须大于 0"
      return
    }
    model.configuration.savings = SavingsPlan(
      baselineAmount: baselineValue,
      baselineDay: LocalDay(date: Date(), calendar: .current),
      targetAmount: targetValue
    )
    do {
      try await model.save()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

struct SalarySettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var mode = 0
  @State private var monthly = ""
  @State private var months = ""
  @State private var annual = ""
  @State private var error: String?

  var body: some View {
    Form {
      Picker("输入方式", selection: $mode) {
        Text("月薪 × 薪数").tag(0)
        Text("年度总包").tag(1)
      }
      .pickerStyle(.segmented)
      if mode == 0 {
        TextField("月薪", text: $monthly).moyuDecimalKeyboard()
        TextField("薪数", text: $months).moyuDecimalKeyboard()
      } else {
        TextField("年度总包", text: $annual).moyuDecimalKeyboard()
      }
      if let error { Text(error).foregroundStyle(.red) }
    }
    .navigationTitle("薪资")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("保存") { Task { await save() } }
      }
    }
    .onAppear {
      switch model.configuration.compensation {
      case .monthly(let salary, let salaryMonths):
        mode = 0
        monthly = NSDecimalNumber(decimal: salary).stringValue
        months = NSDecimalNumber(decimal: salaryMonths).stringValue
      case .annual(let total):
        mode = 1
        annual = NSDecimalNumber(decimal: total).stringValue
      }
    }
  }

  private func save() async {
    if mode == 0,
      let salary = Decimal(string: monthly), salary > 0,
      let count = Decimal(string: months), count > 0
    {
      model.configuration.compensation = .monthly(monthlySalary: salary, salaryMonths: count)
    } else if mode == 1, let total = Decimal(string: annual), total > 0 {
      model.configuration.compensation = .annual(totalPackage: total)
    } else {
      error = "请输入有效金额"
      return
    }
    do {
      try await model.save()
      dismiss()
    } catch { self.error = error.localizedDescription }
  }
}

struct ScheduleSettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var schedule = WorkSchedule()
  @State private var error: String?

  var body: some View {
    Form {
      Section("每周工作日") { WeekdayPicker(selection: $schedule.workdays) }
      Section("时间") {
        TimeRow("上班", value: $schedule.workStart)
        TimeRow("午休开始", value: $schedule.lunchStart)
        TimeRow("午休结束", value: $schedule.lunchEnd)
        TimeRow("下班", value: $schedule.workEnd)
      }
      if let error { Text(error).foregroundStyle(.red) }
    }
    .navigationTitle("工作时间")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("保存") { Task { await save() } }
      }
    }
    .onAppear { schedule = model.configuration.schedule }
  }

  private func save() async {
    guard schedule.isValid else {
      error = "请检查工作日和时间顺序"
      return
    }
    model.configuration.schedule = schedule
    do {
      try await model.save()
      dismiss()
    } catch { self.error = error.localizedDescription }
  }
}
