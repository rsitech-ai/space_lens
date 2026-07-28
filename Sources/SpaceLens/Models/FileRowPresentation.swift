import Foundation

struct FileRowPresentation: Equatable {
    let name: String
    let location: String
    let absolutePath: String
    let isSelected: Bool
    let isQueued: Bool

    init(
        node: FileNode,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        isSelected: Bool,
        isQueued: Bool
    ) {
        name = node.displayName
        absolutePath = node.path
        self.isSelected = isSelected
        self.isQueued = isQueued

        let parentPath = node.url.deletingLastPathComponent().standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path
        if parentPath == homePath {
            location = "~"
        } else if parentPath.hasPrefix(homePath + "/") {
            location = "~/" + String(parentPath.dropFirst(homePath.count + 1))
        } else {
            location = parentPath
        }
    }

    var accessibilityLabel: String {
        var components = [name, absolutePath]
        if isSelected {
            components.append("Selected")
        }
        if isQueued {
            components.append("Queued for cleanup")
        }
        return components.joined(separator: ", ")
    }
}
