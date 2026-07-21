import Foundation

public struct MoyuConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var compensation: CompensationInput
    public var schedule: WorkSchedule
    public var manualDayOverrides: [LocalDay: Bool]
    public var retirement: RetirementMode?
    public var savings: SavingsPlan?
    public var privacyModeEnabled: Bool

    public init(
        compensation: CompensationInput = .monthly(monthlySalary: 8_000, salaryMonths: 12),
        schedule: WorkSchedule = WorkSchedule(),
        manualDayOverrides: [LocalDay: Bool] = [:],
        retirement: RetirementMode? = nil,
        savings: SavingsPlan? = nil,
        privacyModeEnabled: Bool = false
    ) {
        self.compensation = compensation
        self.schedule = schedule
        self.manualDayOverrides = manualDayOverrides
        self.retirement = retirement
        self.savings = savings
        self.privacyModeEnabled = privacyModeEnabled
    }

    public var validationErrors: [String] {
        var errors: [String] = []
        if compensation.annualPackage <= 0 {
            errors.append("年度总包必须大于 0")
        }
        if !schedule.isValid {
            errors.append("工作时间顺序无效")
        }
        if let savings {
            if savings.baselineAmount < 0 {
                errors.append("期初存款不能为负数")
            }
            if let target = savings.targetAmount, target <= 0 {
                errors.append("存款目标必须大于 0")
            }
        }
        return errors
    }
}

public struct ConfigurationDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var configuration: MoyuConfiguration

    public init(
        schemaVersion: Int = MoyuConfiguration.currentSchemaVersion,
        exportedAt: Date = Date(),
        configuration: MoyuConfiguration
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.configuration = configuration
    }

    public func validatedConfiguration() throws -> MoyuConfiguration {
        guard schemaVersion == MoyuConfiguration.currentSchemaVersion else {
            throw ConfigurationError.unsupportedSchemaVersion(schemaVersion)
        }
        let errors = configuration.validationErrors
        guard errors.isEmpty else { throw ConfigurationError.invalidFields(errors) }
        return configuration
    }
}

public enum ConfigurationError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidFields([String])
}

public enum ConfigurationJSON {
    public static func encode(_ document: ConfigurationDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> ConfigurationDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ConfigurationDocument.self, from: data)
        _ = try document.validatedConfiguration()
        return document
    }
}
