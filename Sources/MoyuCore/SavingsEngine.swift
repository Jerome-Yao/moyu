import Foundation

public struct SavingsSnapshot: Equatable, Sendable {
  public var realtimeBalance: Decimal
  public var targetAmount: Decimal?
  public var remainingAmount: Decimal?
  public var exceededAmount: Decimal?
  public var progress: Double?

  public init(
    realtimeBalance: Decimal,
    targetAmount: Decimal?,
    remainingAmount: Decimal?,
    exceededAmount: Decimal?,
    progress: Double?
  ) {
    self.realtimeBalance = realtimeBalance
    self.targetAmount = targetAmount
    self.remainingAmount = remainingAmount
    self.exceededAmount = exceededAmount
    self.progress = progress
  }
}

public struct SavingsEngine: Sendable {
  public var incomeEngine: IncomeEngine

  public init(incomeEngine: IncomeEngine) {
    self.incomeEngine = incomeEngine
  }

  public func snapshot(plan: SavingsPlan, at now: Date) throws -> SavingsSnapshot {
    let calendar = incomeEngine.workCalendar.calendar
    let today = LocalDay(date: now, calendar: calendar)
    var balance = plan.baselineAmount

    if plan.baselineDay < today {
      var cursor = plan.baselineDay
      while cursor < today {
        if incomeEngine.workCalendar.isWorkday(cursor) {
          balance += try incomeEngine.dailyWage(on: cursor)
        }
        guard let next = cursor.adding(days: 1, calendar: calendar) else { break }
        cursor = next
      }
    }

    if plan.baselineDay <= today {
      balance += try incomeEngine.snapshot(at: now).earnedToday
    }

    guard let target = plan.targetAmount, target > 0 else {
      return SavingsSnapshot(
        realtimeBalance: balance,
        targetAmount: nil,
        remainingAmount: nil,
        exceededAmount: nil,
        progress: nil
      )
    }

    let difference = target - balance
    let progress = min(max(NSDecimalNumber(decimal: balance / target).doubleValue, 0), 1)
    return SavingsSnapshot(
      realtimeBalance: balance,
      targetAmount: target,
      remainingAmount: max(difference, 0),
      exceededAmount: max(-difference, 0),
      progress: progress
    )
  }
}
