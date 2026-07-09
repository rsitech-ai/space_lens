import Foundation

public final class SmartCleanupScanner: @unchecked Sendable {
    public typealias ProgressHandler = DiskScanner.ProgressHandler

    private let fileManager: FileManager
    private let diskScanner: DiskScanner
    private let homeDirectory: URL

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) {
        self.fileManager = fileManager
        self.diskScanner = DiskScanner(fileManager: fileManager)
        self.homeDirectory = homeDirectory.standardizedFileURL
    }

    public func scan(root rootURL: URL, progress: ProgressHandler? = nil) async -> ScanResult {
        let startedAt = Date()
        let rootURL = rootURL.standardizedFileURL
        var context = SmartScanContext(startedAt: startedAt)
        var candidates: [FileNode] = []
        var seenPaths: Set<String> = []

        for url in directCandidateURLs(containedIn: rootURL) {
            await appendCandidate(
                url,
                to: &candidates,
                seenPaths: &seenPaths,
                context: &context,
                progress: progress
            )
        }

        if shouldDiscoverCandidates(under: rootURL) {
            await discoverCandidates(
                under: rootURL,
                candidates: &candidates,
                seenPaths: &seenPaths,
                context: &context,
                progress: progress
            )
        }

        candidates.sort(by: Self.displaySort)
        let logicalSize = candidates.reduce(Int64(0)) { $0 + $1.logicalSize }
        let allocatedSize = candidates.reduce(Int64(0)) { $0 + $1.allocatedSize }
        let completedAt = Date()
        let root = FileNode(
            url: rootURL,
            name: "Smart Scan",
            path: rootURL.path,
            isDirectory: true,
            logicalSize: logicalSize,
            allocatedSize: allocatedSize,
            children: candidates
        )

        progress?(
            ScanProgress(
                currentPath: rootURL.path,
                scannedCount: context.scannedCount,
                fileCount: context.fileCount,
                directoryCount: context.directoryCount,
                symlinkCount: context.symlinkCount,
                errorCount: context.errorCount,
                discoveredBytes: allocatedSize,
                startedAt: startedAt
            )
        )

        return ScanResult(
            root: root,
            snapshot: ScanSnapshot(
                rootPath: root.path,
                startedAt: startedAt,
                completedAt: completedAt,
                totalLogicalSize: logicalSize,
                totalAllocatedSize: allocatedSize,
                nodeCount: context.scannedCount,
                fileCount: context.fileCount,
                directoryCount: context.directoryCount,
                symlinkCount: context.symlinkCount,
                errorCount: context.errorCount
            )
        )
    }

    private func discoverCandidates(
        under rootURL: URL,
        candidates: inout [FileNode],
        seenPaths: inout Set<String>,
        context: inout SmartScanContext,
        progress: ProgressHandler?
    ) async {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            context.errorCount += 1
            return
        }

        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled {
                return
            }

            guard isDirectory(url), !isSymbolicLink(url) else {
                continue
            }

            if url.lastPathComponent.lowercased() == "node_modules" {
                let cacheURL = url.appendingPathComponent(".cache", isDirectory: true)
                if isDirectory(cacheURL), !isSymbolicLink(cacheURL) {
                    await appendCandidate(
                        cacheURL,
                        to: &candidates,
                        seenPaths: &seenPaths,
                        context: &context,
                        progress: progress
                    )
                }
                enumerator.skipDescendants()
                continue
            }

            if shouldSkipDiscoveryDescendants(url) {
                enumerator.skipDescendants()
                continue
            }

            if isDiscoveredCandidate(url) {
                await appendCandidate(
                    url,
                    to: &candidates,
                    seenPaths: &seenPaths,
                    context: &context,
                    progress: progress
                )
                enumerator.skipDescendants()
            }
        }
    }

    private func appendCandidate(
        _ url: URL,
        to candidates: inout [FileNode],
        seenPaths: inout Set<String>,
        context: inout SmartScanContext,
        progress: ProgressHandler?
    ) async {
        if Task.isCancelled {
            return
        }

        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        guard seenPaths.insert(path).inserted, fileManager.fileExists(atPath: path) else {
            return
        }

        let result = await diskScanner.scan(
            root: standardizedURL,
            options: ScanOptions(maxRetainedChildrenPerDirectory: 0)
        )
        context.scannedCount += max(result.snapshot.nodeCount, 1)
        context.fileCount += result.snapshot.fileCount
        context.directoryCount += result.snapshot.directoryCount
        context.symlinkCount += result.snapshot.symlinkCount
        context.errorCount += result.snapshot.errorCount

        guard result.root.effectiveSize > 0 else {
            return
        }

        candidates.append(namedCandidate(result.root))
        progress?(
            ScanProgress(
                currentPath: path,
                scannedCount: context.scannedCount,
                fileCount: context.fileCount,
                directoryCount: context.directoryCount,
                symlinkCount: context.symlinkCount,
                errorCount: context.errorCount,
                discoveredBytes: candidates.reduce(Int64(0)) { $0 + $1.effectiveSize },
                startedAt: context.startedAt
            )
        )
    }

    private func namedCandidate(_ node: FileNode) -> FileNode {
        FileNode(
            id: node.id,
            url: node.url,
            name: explicitDisplayName(for: node.url) ?? node.name,
            path: node.path,
            isDirectory: node.isDirectory,
            isSymlink: node.isSymlink,
            logicalSize: node.logicalSize,
            allocatedSize: node.allocatedSize,
            modifiedAt: node.modifiedAt,
            createdAt: node.createdAt,
            children: node.children,
            scanError: node.scanError
        )
    }

    private func directCandidateURLs(containedIn rootURL: URL) -> [URL] {
        candidatePathTemplates()
            .map(resolveTemplate)
            .filter { candidate in contains(candidate, in: rootURL) }
    }

    private func candidatePathTemplates() -> [String] {
        [
            "/Library/Developer/CoreSimulator/Caches",
            "~/Library/Application Support/com.apple.wallpaper/aerials/videos",
            "~/.gradle/caches",
            "~/.android/avd",
            "~/.rustup/toolchains",
            "~/Library/Developer/Xcode/DerivedData",
            "~/anaconda3/pkgs",
            "~/.codex/sessions",
            "~/Library/Application Support/Notion/Partitions",
            "~/Library/Application Support/Cursor/User/History",
            "~/Library/Application Support/Cursor/User/globalStorage",
            "~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
            "~/dev/trading/rsibot/quants-lab/app/data/cache/lob",
            "~/dev/trading/rsibot/quants-lab/output/backtests",
            "~/dev/new/alpha-vistula/risercz/python/universal/downloads/library"
        ]
    }

    private func resolveTemplate(_ template: String) -> URL {
        if template.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(template.dropFirst(2))).standardizedFileURL
        }

        return URL(fileURLWithPath: template).standardizedFileURL
    }

    private func shouldDiscoverCandidates(under rootURL: URL) -> Bool {
        let path = rootURL.path
        if path == "/" || path == "/System" || path == "/Library" {
            return false
        }

        return contains(rootURL, in: homeDirectory)
    }

    private func shouldSkipDiscoveryDescendants(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name == ".git"
            || name == ".svn"
            || name == ".hg"
            || name == "node_modules"
            || name == ".venv"
            || name == "venv"
            || name == "__pycache__"
    }

    private func isDiscoveredCandidate(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let path = url.path.lowercased()

        if [".build", ".dart_tool", ".pytest_cache", ".mypy_cache", ".ruff_cache", "deriveddata"].contains(name) {
            return true
        }

        if ["build", "dist", "target"].contains(name) {
            return true
        }

        if path.contains("/node_modules/.cache")
            || path.contains("/library/caches/")
            || path.contains("/.gradle/caches")
            || path.contains("/data/cache/lob")
            || path.contains("/output/backtests")
        {
            return true
        }

        return false
    }

    private func explicitDisplayName(for url: URL) -> String? {
        let path = url.standardizedFileURL.path.lowercased()
        let name = url.lastPathComponent
        let lowercasedName = name.lowercased()

        if path.hasSuffix("/library/developer/coresimulator/caches") {
            return "Xcode Simulator Caches"
        }
        if path.hasSuffix("/library/application support/com.apple.wallpaper/aerials/videos") {
            return "Apple Aerial Wallpaper Videos"
        }
        if path.hasSuffix("/.gradle/caches") {
            return "Gradle Caches"
        }
        if path.hasSuffix("/.android/avd") {
            return "Android Virtual Devices"
        }
        if lowercasedName.hasSuffix(".avd"), path.contains("/.android/avd/") {
            return "Android Emulator: \(name.replacingOccurrences(of: ".avd", with: ""))"
        }
        if path.hasSuffix("/.rustup/toolchains") {
            return "Rust Toolchains"
        }
        if path.contains("/.rustup/toolchains/") {
            return "Rust Toolchain: \(name)"
        }
        if path.hasSuffix("/library/developer/xcode/deriveddata") {
            return "Xcode DerivedData"
        }
        if path.hasSuffix("/anaconda3/pkgs") || path.hasSuffix("/miniconda3/pkgs") {
            return "Conda Package Cache"
        }
        if path.hasSuffix("/.codex/sessions") {
            return "Codex Sessions"
        }
        if path.hasSuffix("/library/application support/notion/partitions") {
            return "Notion Local Cache"
        }
        if path.hasSuffix("/library/application support/cursor/user/history") {
            return "Cursor Local History"
        }
        if path.hasSuffix("/library/application support/cursor/user/globalstorage") {
            return "Cursor Global Storage"
        }
        if lowercasedName == "docker.raw" {
            return "Docker Disk Image"
        }
        if path.hasSuffix("/app/data/cache/lob") {
            return "Trading LOB Cache"
        }
        if path.hasSuffix("/output/backtests") {
            return "Backtest Outputs"
        }
        if path.hasSuffix("/downloads/library") {
            return "Research PDF Library"
        }
        if path.hasSuffix("/node_modules/.cache") {
            return "Node Package Cache"
        }
        if lowercasedName == ".build" {
            return "Build Artifacts (.build)"
        }
        if lowercasedName == "build" {
            return "Build Output"
        }
        if lowercasedName == "dist" {
            return "Distribution Output"
        }
        if lowercasedName == "target" {
            return "Rust Target Build Output"
        }
        if lowercasedName == ".dart_tool" {
            return "Dart Tool Cache"
        }
        if lowercasedName == ".pytest_cache" {
            return "Pytest Cache"
        }
        if lowercasedName == ".mypy_cache" {
            return "Mypy Cache"
        }
        if lowercasedName == ".ruff_cache" {
            return "Ruff Cache"
        }

        return nil
    }

    private func contains(_ candidate: URL, in rootURL: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = rootURL.standardizedFileURL.path
        if rootPath == "/" {
            return true
        }

        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
    }

    private static func displaySort(lhs: FileNode, rhs: FileNode) -> Bool {
        if lhs.effectiveSize == rhs.effectiveSize {
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        return lhs.effectiveSize > rhs.effectiveSize
    }
}

private struct SmartScanContext {
    let startedAt: Date
    var scannedCount = 0
    var fileCount = 0
    var directoryCount = 0
    var symlinkCount = 0
    var errorCount = 0
}
