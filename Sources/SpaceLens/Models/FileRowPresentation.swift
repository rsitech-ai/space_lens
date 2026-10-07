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
        scanRoot: URL? = nil,
        isSelected: Bool,
        isQueued: Bool
    ) {
        name = node.displayName
        absolutePath = node.path
        self.isSelected = isSelected
        self.isQueued = isQueued

        let parentPath = node.url.deletingLastPathComponent().standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path
        let rootPath = scanRoot?.standardizedFileURL.path
        if let rootPath, parentPath == rootPath {
            location = "Selected folder"
        } else if let rootPath, rootPath != "/", parentPath.hasPrefix(rootPath + "/") {
            location = String(parentPath.dropFirst(rootPath.count + 1))
        } else if parentPath == homePath {
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
