import Foundation

public actor ConfigurationStore {
    public let fileURL: URL

    public init(directory: URL, filename: String = "configuration.json") {
        self.fileURL = directory.appending(path: filename)
    }

    public func load() throws -> MoyuConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return MoyuConfiguration()
        }
        let document = try ConfigurationJSON.decode(Data(contentsOf: fileURL))
        return try document.validatedConfiguration()
    }

    public func save(_ configuration: MoyuConfiguration) throws {
        let errors = configuration.validationErrors
        guard errors.isEmpty else { throw ConfigurationError.invalidFields(errors) }
        try ensureDirectory()
        let data = try ConfigurationJSON.encode(ConfigurationDocument(configuration: configuration))
        try data.write(to: fileURL, options: .atomic)
        try applyFileProtectionIfAvailable(to: fileURL)
    }

    public func exportData() throws -> Data {
        let configuration = try load()
        return try ConfigurationJSON.encode(ConfigurationDocument(configuration: configuration))
    }

    public func importData(_ data: Data) throws -> MoyuConfiguration {
        let document = try ConfigurationJSON.decode(data)
        let configuration = try document.validatedConfiguration()
        try save(configuration)
        return configuration
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}

public actor HolidayStore {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func load(year: Int) throws -> HolidayYear? {
        let downloaded = fileURL(for: year)
        if FileManager.default.fileExists(atPath: downloaded.path) {
            do {
                return try HolidayJSON.decode(Data(contentsOf: downloaded), expectedYear: year)
            } catch {
                // A corrupt downloaded file never prevents use of the bundled fallback.
            }
        }
        return try BundledHolidayLoader.load(year: year)
    }

    public func saveValidated(_ data: Data, expectedYear: Int) throws {
        _ = try HolidayJSON.decode(data, expectedYear: expectedYear)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = fileURL(for: expectedYear)
        try data.write(to: destination, options: .atomic)
        try applyFileProtectionIfAvailable(to: destination)
    }

    public func update(
        years: [Int],
        client: HolidayDownloadClient = HolidayDownloadClient()
    ) async -> HolidayUpdateResult {
        var result = HolidayUpdateResult()
        for year in years {
            do {
                let data = try await client.download(year: year)
                try saveValidated(data, expectedYear: year)
                result.updatedYears.append(year)
            } catch {
                result.failures[year] = error.localizedDescription
            }
        }
        return result
    }

    public func lastUpdatedAt(year: Int) -> Date? {
        let url = fileURL(for: year)
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func fileURL(for year: Int) -> URL {
        directory.appending(path: "\(year).json")
    }
}

private func applyFileProtectionIfAvailable(to url: URL) throws {
    #if os(iOS)
    try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: url.path
    )
    #endif
}
