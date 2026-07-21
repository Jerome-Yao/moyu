import Foundation

public struct WidgetTimelineItem: Codable, Equatable, Sendable {
  public var date: Date
  public var phase: WorkPhase
  public var label: String
  public var targetDate: Date
  public var workStart: Date?
  public var workEnd: Date?

  public init(
    date: Date,
    phase: WorkPhase,
    label: String,
    targetDate: Date,
    workStart: Date? = nil,
    workEnd: Date? = nil
  ) {
    self.date = date
    self.phase = phase
    self.label = label
    self.targetDate = targetDate
    self.workStart = workStart
    self.workEnd = workEnd
  }
}

public struct WidgetTimelinePayload: Codable, Equatable, Sendable {
  public var generatedAt: Date
  public var items: [WidgetTimelineItem]

  public init(generatedAt: Date, items: [WidgetTimelineItem]) {
    self.generatedAt = generatedAt
    self.items = items
  }
}

public struct WidgetTimelineGenerator: Sendable {
  public var incomeEngine: IncomeEngine

  public init(incomeEngine: IncomeEngine) {
    self.incomeEngine = incomeEngine
  }

  public func generate(
    from start: Date,
    maximumItems: Int = 32,
    horizonDays: Int = 8
  ) -> WidgetTimelinePayload {
    let calendar = incomeEngine.workCalendar.calendar
    let horizon = calendar.date(byAdding: .day, value: horizonDays, to: start) ?? start
    var cursor = start
    var items: [WidgetTimelineItem] = []

    while cursor < horizon, items.count < maximumItems,
      let status = incomeEngine.workStatus(at: cursor)
    {
      let day = LocalDay(date: cursor, calendar: calendar)
      let schedule = incomeEngine.workCalendar.schedule
      let isWorkday = incomeEngine.workCalendar.isWorkday(day)
      items.append(
        WidgetTimelineItem(
          date: cursor,
          phase: status.phase,
          label: status.label,
          targetDate: status.targetDate,
          workStart: isWorkday ? schedule.workStart.date(on: day, calendar: calendar) : nil,
          workEnd: isWorkday ? schedule.workEnd.date(on: day, calendar: calendar) : nil
        ))

      let next = status.targetDate.addingTimeInterval(1)
      guard next > cursor else { break }
      cursor = next
    }

    return WidgetTimelinePayload(generatedAt: start, items: items)
  }
}

public enum WidgetTimelineJSON {
  public static func encode(_ payload: WidgetTimelinePayload) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(payload)
  }

  public static func decode(_ data: Data) throws -> WidgetTimelinePayload {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(WidgetTimelinePayload.self, from: data)
  }
}
