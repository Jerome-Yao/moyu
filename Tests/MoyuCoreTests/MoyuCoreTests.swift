import Foundation
import MoyuCore
import XCTest

final class MoyuCoreTests: XCTestCase {
  private let timeZone = TimeZone(identifier: "Asia/Shanghai")!

  func testMay2026WorkdayCountUsesHolidayOverrides() {
    let calendar = makeWorkCalendar()
    XCTAssertEqual(calendar.workdayCount(year: 2026, month: 5), 19)
    XCTAssertTrue(calendar.isWorkday(LocalDay(year: 2026, month: 5, day: 9)))
    XCTAssertFalse(calendar.isWorkday(LocalDay(year: 2026, month: 5, day: 4)))
  }

  func testLunchDoesNotPauseIncome() throws {
    let engine = IncomeEngine(
      compensation: .monthly(monthlySalary: 8_000, salaryMonths: 14),
      workCalendar: makeWorkCalendar()
    )
    let atLunch = try engine.snapshot(at: date(2026, 5, 6, 12, 30))
    let afterLunch = try engine.snapshot(at: date(2026, 5, 6, 13, 0))

    XCTAssertEqual(atLunch.workProgress, 3.5 / 9, accuracy: 0.000_001)
    XCTAssertGreaterThan(afterLunch.earnedToday, atLunch.earnedToday)
    XCTAssertEqual(engine.workStatus(at: date(2026, 5, 6, 12, 30))?.phase, .atLunch)
  }

  func testHolidayIntervalAndHolidayState() {
    let engine = HolidayProgressEngine(years: [holidayYear()], timeZone: timeZone)

    guard
      case .between(let previous, let next, let progress) = engine.state(at: date(2026, 7, 21, 12))
    else {
      return XCTFail("Expected between-holidays state")
    }
    XCTAssertEqual(previous.name, "端午节")
    XCTAssertEqual(next.name, "中秋节")
    XCTAssertTrue((0...1).contains(progress))

    guard case .inHoliday(let period, let current, let total) = engine.state(at: date(2026, 9, 26))
    else {
      return XCTFail("Expected active holiday state")
    }
    XCTAssertEqual(period.name, "中秋节")
    XCTAssertEqual(current, 2)
    XCTAssertEqual(total, 3)
  }

  func testProgressiveRetirementBoundary() throws {
    let engine = RetirementEngine(timeZone: timeZone)
    let target = try engine.targetDate(
      for: .automatic(
        birthMonth: BirthMonth(year: 1965, month: 1),
        personnelType: .male
      ))
    XCTAssertEqual(target, date(2025, 3, 1))
  }

  func testConfigurationRoundTripAndValidation() throws {
    let configuration = MoyuConfiguration(
      compensation: .monthly(monthlySalary: 8_000, salaryMonths: 14),
      onboardingCompleted: true
    )
    let data = try ConfigurationJSON.encode(ConfigurationDocument(configuration: configuration))
    XCTAssertEqual(try ConfigurationJSON.decode(data).configuration, configuration)
  }

  private func makeWorkCalendar() -> WorkCalendar {
    WorkCalendar(
      schedule: WorkSchedule(),
      holidaysByYear: [2026: holidayYear()],
      timeZone: timeZone
    )
  }

  private func holidayYear() -> HolidayYear {
    HolidayYear(
      year: 2026,
      days: [
        HolidayDay(name: "劳动节", date: LocalDay(year: 2026, month: 5, day: 1), isOffDay: true),
        HolidayDay(name: "劳动节", date: LocalDay(year: 2026, month: 5, day: 2), isOffDay: true),
        HolidayDay(name: "劳动节", date: LocalDay(year: 2026, month: 5, day: 3), isOffDay: true),
        HolidayDay(name: "劳动节", date: LocalDay(year: 2026, month: 5, day: 4), isOffDay: true),
        HolidayDay(name: "劳动节", date: LocalDay(year: 2026, month: 5, day: 5), isOffDay: true),
        HolidayDay(name: "劳动节", date: LocalDay(year: 2026, month: 5, day: 9), isOffDay: false),
        HolidayDay(name: "端午节", date: LocalDay(year: 2026, month: 6, day: 19), isOffDay: true),
        HolidayDay(name: "端午节", date: LocalDay(year: 2026, month: 6, day: 20), isOffDay: true),
        HolidayDay(name: "端午节", date: LocalDay(year: 2026, month: 6, day: 21), isOffDay: true),
        HolidayDay(name: "中秋节", date: LocalDay(year: 2026, month: 9, day: 25), isOffDay: true),
        HolidayDay(name: "中秋节", date: LocalDay(year: 2026, month: 9, day: 26), isOffDay: true),
        HolidayDay(name: "中秋节", date: LocalDay(year: 2026, month: 9, day: 27), isOffDay: true),
      ])
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0)
    -> Date
  {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(
      from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
      ))!
  }
}
