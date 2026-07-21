import Foundation
import MoyuCore
import Observation
import WidgetKit

@MainActor
@Observable
final class AppModel {
  enum LoadingState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
  }

  private static let appGroup = "group.com.ysq.moyu"

  var configuration = MoyuConfiguration()
  var holidays: [Int: HolidayYear] = [:]
  var loadingState: LoadingState = .idle
  var isShowingSettings = false
  var holidayUpdateMessage: String?

  private let configurationStore: ConfigurationStore
  private let holidayStore: HolidayStore

  init() {
    let base =
      FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: Self.appGroup
      )
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "moyu", directoryHint: .isDirectory)
    configurationStore = ConfigurationStore(directory: base)
    holidayStore = HolidayStore(
      directory: base.appending(path: "holidays", directoryHint: .isDirectory))
  }

  func load() async {
    guard loadingState != .loading else { return }
    loadingState = .loading
    do {
      configuration = try await configurationStore.load()
      try await loadHolidayWindow(around: Date())
      writeWidgetTimeline()
      loadingState = .ready
    } catch {
      loadingState = .failed(error.localizedDescription)
    }
  }

  func save() async throws {
    try await configurationStore.save(configuration)
    writeWidgetTimeline()
    WidgetCenter.shared.reloadAllTimelines()
  }

  func finishOnboarding(with configuration: MoyuConfiguration) async throws {
    var completed = configuration
    completed.onboardingCompleted = true
    self.configuration = completed
    try await save()
  }

  func updateHolidays() async {
    let year = Calendar.current.component(.year, from: Date())
    let result = await holidayStore.update(years: [year, year + 1])
    do { try await loadHolidayWindow(around: Date()) } catch {}
    if result.failures.isEmpty {
      holidayUpdateMessage =
        "已更新 \(result.updatedYears.map(String.init).joined(separator: "、")) 年节假日"
    } else if result.updatedYears.isEmpty {
      holidayUpdateMessage = result.failures.values.sorted().joined(separator: "\n")
    } else {
      holidayUpdateMessage =
        "已更新 \(result.updatedYears.map(String.init).joined(separator: "、")) 年；部分年份尚未发布"
    }
    writeWidgetTimeline()
    WidgetCenter.shared.reloadAllTimelines()
  }

  func importConfiguration(_ data: Data) async throws {
    configuration = try await configurationStore.importData(data)
    writeWidgetTimeline()
    WidgetCenter.shared.reloadAllTimelines()
  }

  func exportConfiguration() async throws -> Data {
    try await configurationStore.exportData()
  }

  func clearAllData() async throws {
    try await configurationStore.clear()
    configuration = MoyuConfiguration()
    if let url = widgetTimelineURL() {
      try? FileManager.default.removeItem(at: url)
    }
    WidgetCenter.shared.reloadAllTimelines()
  }

  func workCalendar(timeZone: TimeZone = .current) -> WorkCalendar {
    WorkCalendar(
      schedule: configuration.schedule,
      holidaysByYear: holidays,
      manualOverrides: configuration.manualDayOverrides,
      timeZone: timeZone
    )
  }

  func incomeEngine(timeZone: TimeZone = .current) -> IncomeEngine {
    IncomeEngine(
      compensation: configuration.compensation,
      workCalendar: workCalendar(timeZone: timeZone)
    )
  }

  private func loadHolidayWindow(around date: Date) async throws {
    let year = Calendar.current.component(.year, from: date)
    var loaded: [Int: HolidayYear] = [:]
    for candidate in (year - 1)...(year + 1) {
      if let value = try await holidayStore.load(year: candidate) {
        loaded[candidate] = value
      }
    }
    holidays = loaded
  }

  private func writeWidgetTimeline() {
    guard let destination = widgetTimelineURL() else { return }
    let payload = WidgetTimelineGenerator(incomeEngine: incomeEngine()).generate(from: Date())
    guard let data = try? WidgetTimelineJSON.encode(payload) else { return }
    try? data.write(to: destination, options: .atomic)
  }

  private func widgetTimelineURL() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: Self.appGroup
    )?.appending(path: "widget-timeline.json")
  }
}
