import Foundation

public enum FileCleanupService {
    public static func moveToBin(url: URL) async throws {
        try await Task.detached(priority: .utility) {
            var resultingItemURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemURL)
        }.value
    }

    public static func deleteForever(url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.removeItem(at: url)
        }.value
    }
}
