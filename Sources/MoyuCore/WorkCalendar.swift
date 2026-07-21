import Foundation

public struct WorkCalendar: Sendable {
  public var schedule: WorkSchedule
  public var holidaysByYear: [Int: HolidayYear]
  public var manualOverrides: [LocalDay: Bool]
  public var calendar: Calendar

  public init(
    schedule: WorkSchedule,
    holidaysByYear: [Int: HolidayYear] = [:],
    manualOverrides: [LocalDay: Bool] = [:],
    timeZone: TimeZone = .current
  ) {
    self.schedule = schedule
    self.holidaysByYear = holidaysByYear
    self.manualOverrides = manualOverrides
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "zh_Hans_CN")
    calendar.timeZone = timeZone
    self.calendar = calendar
  }

  public func isWorkday(_ day: LocalDay) -> Bool {
    if let override = manualOverrides[day] {
      return override
    }

    if let holiday = holidaysByYear[day.year]?.days.first(where: { $0.date == day }) {
      return !holiday.isOffDay
    }

    guard let date = day.startDate(in: calendar) else { return false }
    let weekday = ISOWeekday(calendarWeekday: calendar.component(.weekday, from: date))
    return schedule.workdays.contains(weekday)
  }

  public func workdayCount(year: Int, month: Int) -> Int {
    guard
      let interval = calendar.dateInterval(
        of: .month,
        for: calendar.date(from: DateComponents(year: year, month: month, day: 1))
          ?? Date.distantPast
      )
    else { return 0 }

    var date = interval.start
    var count = 0
    while date < interval.end {
      if isWorkday(LocalDay(date: date, calendar: calendar)) {
        count += 1
      }
      guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
      date = next
    }
    return count
  }

  public func nextWorkday(onOrAfter day: LocalDay, maximumSearchDays: Int = 740) -> LocalDay? {
    var candidate = day
    for _ in 0..<maximumSearchDays {
      if isWorkday(candidate) {
        return candidate
      }
      guard let next = candidate.adding(days: 1, calendar: calendar) else { return nil }
      candidate = next
    }
    return nil
  }
}

public actor MonthlyWorkdayCache {
  public struct Key: Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var scheduleVersion: Int
    public var holidayVersion: Int
    public var overrideVersion: Int

    public init(
      year: Int,
      month: Int,
      scheduleVersion: Int,
      holidayVersion: Int,
      overrideVersion: Int
    ) {
      self.year = year
      self.month = month
      self.scheduleVersion = scheduleVersion
      self.holidayVersion = holidayVersion
      self.overrideVersion = overrideVersion
    }
  }

  private var values: [Key: Int] = [:]

  public init() {}

  public func value(for key: Key, calculate: () -> Int) -> Int {
    if let cached = values[key] {
      return cached
    }
    let value = calculate()
    values[key] = value
    return value
  }

  public func removeAll() {
    values.removeAll()
  }
}
