import Foundation

public enum HolidayDataError: Error, Equatable, LocalizedError {
    case unexpectedYear(expected: Int, actual: Int)
    case unpublishedYear(Int)
    case malformedDate(String)
    case dateOutsideYear(String)
    case duplicateDate(String)
    case emptyName(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case let .unexpectedYear(expected, actual):
            "节假日年份不匹配：期望 \(expected)，实际 \(actual)"
        case let .unpublishedYear(year):
            "\(year) 年假期安排尚未发布"
        case let .malformedDate(value):
            "日期格式无效：\(value)"
        case let .dateOutsideYear(value):
            "日期不属于目标年份：\(value)"
        case let .duplicateDate(value):
            "存在重复日期：\(value)"
        case let .emptyName(value):
            "节日名称为空：\(value)"
        case .invalidResponse:
            "节假日服务器响应无效"
        }
    }
}

private struct RemoteHolidayDocument: Decodable {
    struct Day: Decodable {
        var name: String
        var date: String
        var isOffDay: Bool
    }

    var year: Int
    var papers: [URL]
    var days: [Day]
}

public enum HolidayJSON {
    public static func decode(_ data: Data, expectedYear: Int) throws -> HolidayYear {
        let remote = try JSONDecoder().decode(RemoteHolidayDocument.self, from: data)
        guard remote.year == expectedYear else {
            throw HolidayDataError.unexpectedYear(expected: expectedYear, actual: remote.year)
        }
        guard !remote.papers.isEmpty, !remote.days.isEmpty else {
            throw HolidayDataError.unpublishedYear(expectedYear)
        }

        var seenDates = Set<String>()
        let days = try remote.days.map { item -> HolidayDay in
            let parts = item.date.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 3,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]),
                  let day = Int(parts[2]),
                  (1...12).contains(month),
                  (1...31).contains(day)
            else { throw HolidayDataError.malformedDate(item.date) }
            guard year == expectedYear else { throw HolidayDataError.dateOutsideYear(item.date) }
            guard seenDates.insert(item.date).inserted else {
                throw HolidayDataError.duplicateDate(item.date)
            }
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw HolidayDataError.emptyName(item.date) }
            return HolidayDay(
                name: name,
                date: LocalDay(year: year, month: month, day: day),
                isOffDay: item.isOffDay
            )
        }

        return HolidayYear(year: remote.year, papers: remote.papers, days: days)
    }
}

public enum BundledHolidayLoader {
    public static func load(year: Int) throws -> HolidayYear? {
        let url = Bundle.module.url(
            forResource: String(year),
            withExtension: "json",
            subdirectory: "Holidays"
        ) ?? Bundle.module.url(forResource: String(year), withExtension: "json")
        guard let url else { return nil }
        return try HolidayJSON.decode(Data(contentsOf: url), expectedYear: year)
    }
}

public struct HolidayDownloadClient: Sendable {
    public var baseURL: URL

    public init(
        baseURL: URL = URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/")!
    ) {
        self.baseURL = baseURL
    }

    public func download(year: Int) async throws -> Data {
        let url = baseURL.appending(path: "\(year).json")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode)
        else { throw HolidayDataError.invalidResponse }
        _ = try HolidayJSON.decode(data, expectedYear: year)
        return data
    }
}

public struct HolidayUpdateResult: Equatable, Sendable {
    public var updatedYears: [Int]
    public var failures: [Int: String]

    public init(updatedYears: [Int] = [], failures: [Int: String] = [:]) {
        self.updatedYears = updatedYears
        self.failures = failures
    }
}
