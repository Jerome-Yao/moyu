import Foundation

public enum IncomeError: Error, Equatable {
    case invalidSchedule
    case noWorkdaysInMonth
    case invalidAnnualPackage
}

public struct IncomeSnapshot: Equatable, Sendable {
    public var dailyWage: Decimal
    public var perSecondIncome: Decimal
    public var earnedToday: Decimal
    public var workProgress: Double

    public init(
        dailyWage: Decimal,
        perSecondIncome: Decimal,
        earnedToday: Decimal,
        workProgress: Double
    ) {
        self.dailyWage = dailyWage
        self.perSecondIncome = perSecondIncome
        self.earnedToday = earnedToday
        self.workProgress = workProgress
    }
}

public struct IncomeEngine: Sendable {
    public var compensation: CompensationInput
    public var workCalendar: WorkCalendar

    public init(compensation: CompensationInput, workCalendar: WorkCalendar) {
        self.compensation = compensation
        self.workCalendar = workCalendar
    }

    public func dailyWage(on day: LocalDay) throws -> Decimal {
        guard compensation.annualPackage > 0 else { throw IncomeError.invalidAnnualPackage }
        let count = workCalendar.workdayCount(year: day.year, month: day.month)
        guard count > 0 else { throw IncomeError.noWorkdaysInMonth }
        return compensation.annualPackage / 12 / Decimal(count)
    }

    public func snapshot(at now: Date) throws -> IncomeSnapshot {
        let schedule = workCalendar.schedule
        guard schedule.isValid, schedule.paidSecondsPerDay > 0 else {
            throw IncomeError.invalidSchedule
        }

        let day = LocalDay(date: now, calendar: workCalendar.calendar)
        let wage = try dailyWage(on: day)
        let perSecond = wage / Decimal(schedule.paidSecondsPerDay)

        guard workCalendar.isWorkday(day),
              let start = schedule.workStart.date(on: day, calendar: workCalendar.calendar),
              let end = schedule.workEnd.date(on: day, calendar: workCalendar.calendar)
        else {
            return IncomeSnapshot(
                dailyWage: wage,
                perSecondIncome: perSecond,
                earnedToday: .zero,
                workProgress: 0
            )
        }

        let elapsed = min(max(now.timeIntervalSince(start), 0), end.timeIntervalSince(start))
        let total = end.timeIntervalSince(start)
        let progress = total > 0 ? elapsed / total : 0
        return IncomeSnapshot(
            dailyWage: wage,
            perSecondIncome: perSecond,
            earnedToday: wage * Decimal.from(progress),
            workProgress: progress
        )
    }
}

public enum WorkPhase: String, Codable, Equatable, Sendable {
    case beforeWork
    case beforeLunch
    case atLunch
    case afterLunch
    case resting
}

public struct WorkStatus: Equatable, Sendable {
    public var phase: WorkPhase
    public var label: String
    public var targetDate: Date

    public init(phase: WorkPhase, label: String, targetDate: Date) {
        self.phase = phase
        self.label = label
        self.targetDate = targetDate
    }
}

public extension IncomeEngine {
    func workStatus(at now: Date) -> WorkStatus? {
        let calendar = workCalendar.calendar
        let schedule = workCalendar.schedule
        let today = LocalDay(date: now, calendar: calendar)

        if workCalendar.isWorkday(today),
           let start = schedule.workStart.date(on: today, calendar: calendar),
           let lunchStart = schedule.lunchStart.date(on: today, calendar: calendar),
           let lunchEnd = schedule.lunchEnd.date(on: today, calendar: calendar),
           let end = schedule.workEnd.date(on: today, calendar: calendar) {
            if now < start {
                return WorkStatus(phase: .beforeWork, label: "距离上班", targetDate: start)
            }
            if now < lunchStart {
                return WorkStatus(phase: .beforeLunch, label: "距离午休", targetDate: lunchStart)
            }
            if now < lunchEnd {
                return WorkStatus(phase: .atLunch, label: "距离午休结束", targetDate: lunchEnd)
            }
            if now < end {
                return WorkStatus(phase: .afterLunch, label: "距离下班", targetDate: end)
            }
        }

        guard let tomorrow = today.adding(days: 1, calendar: calendar),
              let nextDay = workCalendar.nextWorkday(onOrAfter: tomorrow),
              let target = schedule.workStart.date(on: nextDay, calendar: calendar)
        else { return nil }
        return WorkStatus(phase: .resting, label: "距离下次上班", targetDate: target)
    }
}
