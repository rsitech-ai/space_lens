import Foundation

public struct PersistedAppSession: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let savedAt: Date
    public let rootPath: String?
    public let rootBookmarkData: Data?
    public let cleanupPaths: [String]

    public init(
        schemaVersion: Int = 1,
        savedAt: Date = Date(),
        rootPath: String?,
        rootBookmarkData: Data?,
        cleanupPaths: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.rootPath = rootPath
        self.rootBookmarkData = rootBookmarkData
        self.cleanupPaths = cleanupPaths
    }
}

@MainActor
public final class AppSessionStore {
    public static let shared = AppSessionStore()

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> PersistedAppSession? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(PersistedAppSession.self, from: data)
        } catch {
            quarantineCorruptSession()
            return nil
        }
    }

    public func save(rootURL: URL?, cleanupQueue: [CleanupCandidate]) throws {
        let cleanupPaths = cleanupQueue.map(\.fileNode.path).sorted()
        let bookmarkData = try rootURL?.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let session = PersistedAppSession(
            rootPath: rootURL?.standardizedFileURL.path,
            rootBookmarkData: bookmarkData,
            cleanupPaths: cleanupPaths
        )
        try save(session)
    }

    public func save(_ session: PersistedAppSession) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(session)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func resolveRootURL(from session: PersistedAppSession) -> URL? {
        if let bookmarkData = session.rootBookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("SpaceLens", isDirectory: true)
            .appendingPathComponent("session.json")
    }

    private func quarantineCorruptSession() {
        let corruptURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("session.corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? fileManager.moveItem(at: fileURL, to: corruptURL)
    }
}
