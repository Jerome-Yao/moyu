import Foundation

public struct BirthMonth: Codable, Equatable, Sendable {
    public var year: Int
    public var month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }
}

public enum RetirementMode: Codable, Equatable, Sendable {
    case automatic(birthMonth: BirthMonth, personnelType: RetirementPersonnelType)
    case manual(setupDay: LocalDay, remainingYears: Decimal)
}

public struct RetirementSnapshot: Equatable, Sendable {
    public var targetDate: Date
    public var remainingDays: Int
    public var remainingTotalYears: Int
    public var remainingTotalMonths: Int

    public init(
        targetDate: Date,
        remainingDays: Int,
        remainingTotalYears: Int,
        remainingTotalMonths: Int
    ) {
        self.targetDate = targetDate
        self.remainingDays = remainingDays
        self.remainingTotalYears = remainingTotalYears
        self.remainingTotalMonths = remainingTotalMonths
    }
}

public enum RetirementError: Error, Equatable {
    case invalidBirthMonth
    case invalidRemainingYears
    case dateCalculationFailed
}

public struct RetirementEngine: Sendable {
    public static let policyVersion = "2025-01-01"

    public var calendar: Calendar

    public init(timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    public func targetDate(for mode: RetirementMode) throws -> Date {
        switch mode {
        case let .automatic(birthMonth, personnelType):
            return try automaticTargetDate(birthMonth: birthMonth, personnelType: personnelType)
        case let .manual(setupDay, remainingYears):
            guard remainingYears >= 0 else { throw RetirementError.invalidRemainingYears }
            guard let setupDate = setupDay.startDate(in: calendar) else {
                throw RetirementError.dateCalculationFailed
            }
            let years = NSDecimalNumber(decimal: remainingYears).doubleValue
            let days = Int((years * 365.2425).rounded())
            guard let result = calendar.date(byAdding: .day, value: days, to: setupDate) else {
                throw RetirementError.dateCalculationFailed
            }
            return result
        }
    }

    public func snapshot(for mode: RetirementMode, at now: Date) throws -> RetirementSnapshot {
        let target = try targetDate(for: mode)
        let today = calendar.startOfDay(for: now)
        let targetDay = calendar.startOfDay(for: target)
        let days = max(calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0, 0)
        return RetirementSnapshot(
            targetDate: target,
            remainingDays: days,
            remainingTotalYears: Int(floor(Double(days) / 365.2425)),
            remainingTotalMonths: Int(floor(Double(days) / 30.436875))
        )
    }

    private func automaticTargetDate(
        birthMonth: BirthMonth,
        personnelType: RetirementPersonnelType
    ) throws -> Date {
        guard (1...12).contains(birthMonth.month), birthMonth.year >= 1900 else {
            throw RetirementError.invalidBirthMonth
        }

        let baseYears: Int
        let reformStart: BirthMonth
        let cohortMonthsPerDelayMonth: Int
        let maximumDelayMonths: Int

        switch personnelType {
        case .male:
            baseYears = 60
            reformStart = BirthMonth(year: 1965, month: 1)
            cohortMonthsPerDelayMonth = 4
            maximumDelayMonths = 36
        case .femaleOriginally50:
            baseYears = 50
            reformStart = BirthMonth(year: 1975, month: 1)
            cohortMonthsPerDelayMonth = 2
            maximumDelayMonths = 60
        case .femaleOriginally55:
            baseYears = 55
            reformStart = BirthMonth(year: 1970, month: 1)
            cohortMonthsPerDelayMonth = 4
            maximumDelayMonths = 36
        }

        let cohortOffset = months(from: reformStart, to: birthMonth)
        let delayMonths = cohortOffset < 0
            ? 0
            : min(maximumDelayMonths, cohortOffset / cohortMonthsPerDelayMonth + 1)

        guard let birthDate = calendar.date(from: DateComponents(
            year: birthMonth.year,
            month: birthMonth.month,
            day: 1
        )),
        let statutoryMonth = calendar.date(
            byAdding: DateComponents(year: baseYears, month: delayMonths),
            to: birthDate
        ),
        let target = calendar.date(byAdding: .month, value: 1, to: statutoryMonth)
        else { throw RetirementError.dateCalculationFailed }

        return target
    }

    private func months(from start: BirthMonth, to end: BirthMonth) -> Int {
        (end.year - start.year) * 12 + end.month - start.month
    }
}
