import MoyuCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var isExporting = false
  @State private var isImporting = false
  @State private var exportDocument = MoyuFileDocument()
  @State private var showExportWarning = false
  @State private var showClearConfirmation = false
  @State private var message: String?

  var body: some View {
    @Bindable var model = model
    Form {
      Section("工作") {
        NavigationLink("薪资") { SalarySettingsView() }
        NavigationLink("工作时间") { ScheduleSettingsView() }
        NavigationLink("日期覆盖") { DayOverridesView() }
      }

      Section("功能") {
        NavigationLink("退休倒计时") { RetirementSettingsView() }
        Toggle("隐私模式", isOn: $model.configuration.privacyModeEnabled)
          .onChange(of: model.configuration.privacyModeEnabled) {
            Task { try? await model.save() }
          }
      }

      Section("节假日") {
        Button {
          Task { await model.updateHolidays() }
        } label: {
          Label("更新节假日信息", systemImage: "arrow.triangle.2.circlepath")
        }
        if let result = model.holidayUpdateMessage {
          Text(result)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Text("数据来源：NateScarlet/holiday-cn。仅在主动更新时联网。")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section("数据") {
        Button("导出配置") { showExportWarning = true }
        Button("导入配置") { isImporting = true }
        Button("清除全部数据", role: .destructive) { showClearConfirmation = true }
      }

      Section("关于") {
        LabeledContent("应用", value: "moyu")
        LabeledContent("副标题", value: "实时收入小助手")
        LabeledContent("退休政策版本", value: RetirementEngine.policyVersion)
        Text("所有计算仅供娱乐参考。核心数据保存在本机。")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("设置")
    .moyuInlineNavigationTitle()
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("完成") { dismiss() }
      }
    }
    .alert("导出文件包含敏感信息", isPresented: $showExportWarning) {
      Button("取消", role: .cancel) {}
      Button("继续导出") { Task { await prepareExport() } }
    } message: {
      Text("文件包含薪资、退休和存款配置，且不会加密。请谨慎保存和分享。")
    }
    .alert("清除全部数据？", isPresented: $showClearConfirmation) {
      Button("取消", role: .cancel) {}
      Button("清除", role: .destructive) { Task { await clearAllData() } }
    } message: {
      Text("此操作无法撤销。")
    }
    .alert(
      "提示",
      isPresented: Binding(
        get: { message != nil },
        set: { if !$0 { message = nil } }
      )
    ) {
      Button("好") { message = nil }
    } message: {
      Text(message ?? "")
    }
    .fileExporter(
      isPresented: $isExporting,
      document: exportDocument,
      contentType: .json,
      defaultFilename: "moyu-config.moyu"
    ) { result in
      if case .failure(let error) = result { message = error.localizedDescription }
    }
    .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
      Task { await importFile(result) }
    }
  }

  private func prepareExport() async {
    do {
      exportDocument = MoyuFileDocument(data: try await model.exportConfiguration())
      isExporting = true
    } catch { message = error.localizedDescription }
  }

  private func importFile(_ result: Result<URL, Error>) async {
    do {
      let url = try result.get()
      let access = url.startAccessingSecurityScopedResource()
      defer { if access { url.stopAccessingSecurityScopedResource() } }
      try await model.importConfiguration(Data(contentsOf: url))
      message = "配置已导入"
    } catch { message = error.localizedDescription }
  }

  private func clearAllData() async {
    do {
      try await model.clearAllData()
      dismiss()
    } catch { message = error.localizedDescription }
  }
}

struct RetirementSettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var enabled = false
  @State private var mode = 0
  @State private var birthDate =
    Calendar.current.date(from: DateComponents(year: 1990, month: 1)) ?? Date()
  @State private var personnel = RetirementPersonnelType.male
  @State private var remainingYears = "30.0"
  @State private var error: String?

  var body: some View {
    Form {
      Toggle("启用退休倒计时", isOn: $enabled)
      if enabled {
        Picker("计算方式", selection: $mode) {
          Text("自动估算").tag(0)
          Text("手动填写").tag(1)
        }
        .pickerStyle(.segmented)

        if mode == 0 {
          DatePicker("出生年月", selection: $birthDate, displayedComponents: .date)
          Picker("人员类型", selection: $personnel) {
            Text("男职工").tag(RetirementPersonnelType.male)
            Text("原 50 岁女职工").tag(RetirementPersonnelType.femaleOriginally50)
            Text("原 55 岁女职工").tag(RetirementPersonnelType.femaleOriginally55)
          }
        } else {
          TextField("剩余年数", text: $remainingYears)
            .moyuDecimalKeyboard()
          Text("允许一位小数，并按 365.2425 天/年换算。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      if let error { Text(error).foregroundStyle(.red) }
    }
    .navigationTitle("退休倒计时")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("保存") { Task { await save() } }
      }
    }
    .onAppear { load() }
  }

  private func load() {
    guard let retirement = model.configuration.retirement else { return }
    enabled = true
    switch retirement {
    case .automatic(let birthMonth, let type):
      mode = 0
      personnel = type
      birthDate =
        Calendar.current.date(from: DateComponents(year: birthMonth.year, month: birthMonth.month))
        ?? Date()
    case .manual(_, let years):
      mode = 1
      remainingYears = NSDecimalNumber(decimal: years).stringValue
    }
  }

  private func save() async {
    if !enabled {
      model.configuration.retirement = nil
    } else if mode == 0 {
      let components = Calendar.current.dateComponents([.year, .month], from: birthDate)
      model.configuration.retirement = .automatic(
        birthMonth: BirthMonth(year: components.year ?? 1990, month: components.month ?? 1),
        personnelType: personnel
      )
    } else if let years = Decimal(string: remainingYears), years >= 0 {
      model.configuration.retirement = .manual(
        setupDay: LocalDay(date: Date(), calendar: .current),
        remainingYears: years
      )
    } else {
      error = "请输入有效的剩余年数"
      return
    }
    do { try await model.save() } catch { self.error = error.localizedDescription }
  }
}

struct DayOverridesView: View {
  @Environment(AppModel.self) private var model
  @State private var selectedDate = Date()
  @State private var isWorkday = true

  var body: some View {
    Form {
      Section("添加覆盖") {
        DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
        Picker("类型", selection: $isWorkday) {
          Text("上班").tag(true)
          Text("休息").tag(false)
        }
        .pickerStyle(.segmented)
        Button("保存日期覆盖") {
          model.configuration.manualDayOverrides[
            LocalDay(date: selectedDate, calendar: .current)
          ] = isWorkday
          Task { try? await model.save() }
        }
      }

      Section("现有覆盖") {
        if model.configuration.manualDayOverrides.isEmpty {
          Text("暂无")
            .foregroundStyle(.secondary)
        }
        ForEach(model.configuration.manualDayOverrides.keys.sorted(), id: \.self) { day in
          HStack {
            Text(String(format: "%04d-%02d-%02d", day.year, day.month, day.day))
            Spacer()
            Text(model.configuration.manualDayOverrides[day] == true ? "上班" : "休息")
              .foregroundStyle(.secondary)
          }
          .swipeActions {
            Button("删除", role: .destructive) {
              model.configuration.manualDayOverrides.removeValue(forKey: day)
              Task { try? await model.save() }
            }
          }
        }
      }
    }
    .navigationTitle("日期覆盖")
  }
}
