import Foundation

public enum ISOWeekday: Int, Codable, CaseIterable, Hashable, Sendable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    public init(calendarWeekday: Int) {
        self = ISOWeekday(rawValue: ((calendarWeekday + 5) % 7) + 1) ?? .monday
    }
}

public struct LocalDay: Codable, Hashable, Comparable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public func startDate(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public func adding(days: Int, calendar: Calendar) -> LocalDay? {
        guard let date = startDate(in: calendar),
              let result = calendar.date(byAdding: .day, value: days, to: date)
        else { return nil }
        return LocalDay(date: result, calendar: calendar)
    }
}

public struct TimeOfDay: Codable, Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }

    public var secondsSinceMidnight: Int {
        (hour * 60 + minute) * 60
    }

    public func date(on day: LocalDay, calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(
            year: day.year,
            month: day.month,
            day: day.day,
            hour: hour,
            minute: minute
        ))
    }
}

public struct WorkSchedule: Codable, Equatable, Sendable {
    public var workdays: Set<ISOWeekday>
    public var workStart: TimeOfDay
    public var lunchStart: TimeOfDay
    public var lunchEnd: TimeOfDay
    public var workEnd: TimeOfDay

    public init(
        workdays: Set<ISOWeekday> = [.monday, .tuesday, .wednesday, .thursday, .friday],
        workStart: TimeOfDay = .init(hour: 9, minute: 0),
        lunchStart: TimeOfDay = .init(hour: 12, minute: 0),
        lunchEnd: TimeOfDay = .init(hour: 13, minute: 0),
        workEnd: TimeOfDay = .init(hour: 18, minute: 0)
    ) {
        self.workdays = workdays
        self.workStart = workStart
        self.lunchStart = lunchStart
        self.lunchEnd = lunchEnd
        self.workEnd = workEnd
    }

    public var paidSecondsPerDay: Int {
        workEnd.secondsSinceMidnight - workStart.secondsSinceMidnight
    }

    public var isValid: Bool {
        !workdays.isEmpty
            && (0...23).contains(workStart.hour)
            && (0...23).contains(lunchStart.hour)
            && (0...23).contains(lunchEnd.hour)
            && (0...23).contains(workEnd.hour)
            && (0...59).contains(workStart.minute)
            && (0...59).contains(lunchStart.minute)
            && (0...59).contains(lunchEnd.minute)
            && (0...59).contains(workEnd.minute)
            && workStart < lunchStart
            && lunchStart < lunchEnd
            && lunchEnd < workEnd
    }
}

public struct HolidayDay: Codable, Hashable, Sendable {
    public var name: String
    public var date: LocalDay
    public var isOffDay: Bool

    public init(name: String, date: LocalDay, isOffDay: Bool) {
        self.name = name
        self.date = date
        self.isOffDay = isOffDay
    }
}

public struct HolidayYear: Codable, Equatable, Sendable {
    public var year: Int
    public var papers: [URL]
    public var days: [HolidayDay]

    public init(year: Int, papers: [URL] = [], days: [HolidayDay]) {
        self.year = year
        self.papers = papers
        self.days = days
    }
}

public enum CompensationInput: Codable, Equatable, Sendable {
    case monthly(monthlySalary: Decimal, salaryMonths: Decimal)
    case annual(totalPackage: Decimal)

    public var annualPackage: Decimal {
        switch self {
        case let .monthly(monthlySalary, salaryMonths):
            monthlySalary * salaryMonths
        case let .annual(totalPackage):
            totalPackage
        }
    }
}

public enum RetirementPersonnelType: String, Codable, CaseIterable, Sendable {
    case male
    case femaleOriginally50
    case femaleOriginally55
}

public struct SavingsPlan: Codable, Equatable, Sendable {
    public var baselineAmount: Decimal
    public var baselineDay: LocalDay
    public var targetAmount: Decimal?

    public init(baselineAmount: Decimal, baselineDay: LocalDay, targetAmount: Decimal? = nil) {
        self.baselineAmount = baselineAmount
        self.baselineDay = baselineDay
        self.targetAmount = targetAmount
    }
}

public extension Decimal {
    static func from(_ value: TimeInterval) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }
}
