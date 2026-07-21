import Foundation

public struct HolidayPeriod: Equatable, Sendable {
    public var name: String
    public var start: LocalDay
    public var end: LocalDay

    public init(name: String, start: LocalDay, end: LocalDay) {
        self.name = name
        self.start = start
        self.end = end
    }
}

public enum HolidayProgressState: Equatable, Sendable {
    case between(
        previous: HolidayPeriod,
        next: HolidayPeriod,
        progress: Double
    )
    case inHoliday(period: HolidayPeriod, currentDay: Int, totalDays: Int)
    case unavailable(message: String)
}

public struct HolidayProgressEngine: Sendable {
    public var calendar: Calendar
    public var years: [HolidayYear]

    public init(years: [HolidayYear], timeZone: TimeZone = .current) {
        self.years = years
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    public var periods: [HolidayPeriod] {
        let days = years
            .flatMap(\.days)
            .filter(\.isOffDay)
            .sorted { $0.date < $1.date }

        var result: [HolidayPeriod] = []
        for day in days {
            if let last = result.last,
               last.name == day.name,
               last.end.adding(days: 1, calendar: calendar) == day.date {
                result[result.count - 1].end = day.date
            } else {
                result.append(HolidayPeriod(name: day.name, start: day.date, end: day.date))
            }
        }
        return result
    }

    public func state(at now: Date) -> HolidayProgressState {
        let today = LocalDay(date: now, calendar: calendar)
        let periods = periods

        if let active = periods.first(where: { $0.start <= today && today <= $0.end }) {
            let current = dayDistance(from: active.start, to: today) + 1
            let total = dayDistance(from: active.start, to: active.end) + 1
            return .inHoliday(period: active, currentDay: current, totalDays: total)
        }

        guard let previous = periods.last(where: { $0.end < today }),
              let next = periods.first(where: { today < $0.start }),
              let intervalStartDay = previous.end.adding(days: 1, calendar: calendar),
              let intervalStart = intervalStartDay.startDate(in: calendar),
              let intervalEnd = next.start.startDate(in: calendar),
              intervalEnd > intervalStart
        else {
            return .unavailable(message: "下一年度假期安排待发布")
        }

        let elapsed = now.timeIntervalSince(intervalStart)
        let total = intervalEnd.timeIntervalSince(intervalStart)
        let progress = min(max(elapsed / total, 0), 1)
        return .between(previous: previous, next: next, progress: progress)
    }

    private func dayDistance(from start: LocalDay, to end: LocalDay) -> Int {
        guard let startDate = start.startDate(in: calendar),
              let endDate = end.startDate(in: calendar)
        else { return 0 }
        return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}
