import Foundation
import MoyuCore

let shanghai = TimeZone(identifier: "Asia/Shanghai")!
let calendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = shanghai
    return value
}()

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

func close(_ value: Double, _ expected: Double, tolerance: Double = 0.000_001) -> Bool {
    abs(value - expected) <= tolerance
}

let holidays2026 = HolidayYear(year: 2026, days: [
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
    HolidayDay(name: "中秋节", date: LocalDay(year: 2026, month: 9, day: 27), isOffDay: true)
])

let schedule = WorkSchedule()
precondition(schedule.isValid)

let workCalendar = WorkCalendar(
    schedule: schedule,
    holidaysByYear: [2026: holidays2026],
    timeZone: shanghai
)
precondition(workCalendar.workdayCount(year: 2026, month: 5) == 19)
precondition(workCalendar.isWorkday(LocalDay(year: 2026, month: 5, day: 9)))
precondition(!workCalendar.isWorkday(LocalDay(year: 2026, month: 5, day: 4)))

let income = IncomeEngine(
    compensation: .monthly(monthlySalary: 8_000, salaryMonths: 14),
    workCalendar: workCalendar
)
let lunchSnapshot = try income.snapshot(at: date(2026, 5, 6, 12, 30))
precondition(close(lunchSnapshot.workProgress, 3.5 / 9))
precondition(lunchSnapshot.earnedToday > 0)
precondition(income.workStatus(at: date(2026, 5, 6, 12, 30))?.phase == .atLunch)

let holidayProgress = HolidayProgressEngine(years: [holidays2026], timeZone: shanghai)
precondition(holidayProgress.periods.count == 3)
if case let .between(previous, next, progress) = holidayProgress.state(at: date(2026, 7, 21, 12)) {
    precondition(previous.name == "端午节")
    precondition(next.name == "中秋节")
    precondition(progress > 0 && progress < 1)
} else {
    preconditionFailure("Expected an inter-holiday progress state")
}

let retirement = RetirementEngine(timeZone: shanghai)
let maleTarget = try retirement.targetDate(for: .automatic(
    birthMonth: BirthMonth(year: 1965, month: 1),
    personnelType: .male
))
precondition(maleTarget == date(2025, 3, 1))

let manualTarget = try retirement.targetDate(for: .manual(
    setupDay: LocalDay(year: 2026, month: 7, day: 21),
    remainingYears: 8.5
))
let manualDays = calendar.dateComponents([.day], from: date(2026, 7, 21), to: manualTarget).day
precondition(manualDays == Int((8.5 * 365.2425).rounded()))

let savings = try SavingsEngine(incomeEngine: income).snapshot(
    plan: SavingsPlan(
        baselineAmount: 100_000,
        baselineDay: LocalDay(year: 2026, month: 5, day: 1),
        targetAmount: 200_000
    ),
    at: date(2026, 5, 6, 12, 30)
)
precondition(savings.realtimeBalance > 100_000)
precondition(savings.progress != nil && savings.progress! > 0.5)

let configuration = MoyuConfiguration(
    compensation: .monthly(monthlySalary: 8_000, salaryMonths: 14),
    schedule: schedule,
    retirement: .automatic(
        birthMonth: BirthMonth(year: 1990, month: 1),
        personnelType: .male
    )
)
let encoded = try ConfigurationJSON.encode(ConfigurationDocument(
    exportedAt: date(2026, 7, 21),
    configuration: configuration
))
let decoded = try ConfigurationJSON.decode(encoded)
precondition(decoded.configuration == configuration)

let bundled2026 = try BundledHolidayLoader.load(year: 2026)
precondition(bundled2026?.days.count == 39)

let verificationDirectory = FileManager.default.temporaryDirectory
    .appending(path: "moyu-verification-\(UUID().uuidString)", directoryHint: .isDirectory)
let configurationStore = ConfigurationStore(directory: verificationDirectory)
try await configurationStore.save(configuration)
let loadedConfiguration = try await configurationStore.load()
precondition(loadedConfiguration == configuration)
let exported = try await configurationStore.exportData()
let exportedConfiguration = try ConfigurationJSON.decode(exported).configuration
precondition(exportedConfiguration == configuration)
try await configurationStore.clear()
try? FileManager.default.removeItem(at: verificationDirectory)

print("MoyuCore verification passed: calendar, income, holidays, retirement, savings, stores")
