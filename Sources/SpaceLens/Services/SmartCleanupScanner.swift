import Foundation

public final class SmartCleanupScanner: @unchecked Sendable {
    public typealias ProgressHandler = DiskScanner.ProgressHandler
    public typealias CandidatesHandler = @Sendable ([FileNode]) -> Void

    // Bound parallel metadata I/O to avoid filesystem contention.
    private static let measureConcurrency = 3

    private let fileManager: FileManager
    private let diskScanner: DiskScanner
    private let homeDirectory: URL
    private let injectedSimulatorInventory: SimulatorInventory?
    private let discoveryBudget: TimeInterval

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        simulatorInventory: SimulatorInventory? = nil,
        discoveryBudget: TimeInterval = 180
    ) {
        self.fileManager = fileManager
        self.diskScanner = DiskScanner(fileManager: fileManager)
        self.homeDirectory = homeDirectory.standardizedFileURL
        self.injectedSimulatorInventory = simulatorInventory
        self.discoveryBudget = discoveryBudget
    }

    public func scan(
        root rootURL: URL,
        progress: ProgressHandler? = nil,
        onCandidates: CandidatesHandler? = nil
    ) async -> ScanResult {
        await Task.yield()
        let startedAt = Date()
        let rootURL = rootURL.standardizedFileURL
        var context = SmartScanContext(startedAt: startedAt)
        var candidates: [FileNode] = []
        var pendingURLs: [URL] = []
        var seenPaths: Set<String> = []
        var scannedRoots: [String] = []
        let skipSimulatorDeviceTrees = shouldSkipSimulatorDeviceCatalog(for: rootURL)
        async let loadedInventory = resolvedSimulatorInventory(for: rootURL)

        let catalogURLs = (extraKnownRoots(containedIn: rootURL) + directCandidateURLs(
            containedIn: rootURL,
            skippingSimulatorDevices: skipSimulatorDeviceTrees
        )).filter { contains($0.resolvingSymlinksInPath(), in: rootURL.resolvingSymlinksInPath()) }
        for url in catalogURLs {
            enqueueCandidate(url, into: &pendingURLs, seenPaths: &seenPaths, scannedRoots: &scannedRoots)
        }

        let plan = discoveryRoots(containedIn: rootURL)
        var pendingDiscoveryPaths: [String] = []
        var walkedDiscoveryRoots: [String] = []
        for (index, discoveryRoot) in plan.roots.enumerated() {
            if Task.isCancelled {
                break
            }
            if Date().timeIntervalSince(startedAt) > discoveryBudget {
                pendingDiscoveryPaths.append(contentsOf: plan.roots[index...].map(\.path))
                break
            }
            let completed = discoverCandidates(
                under: discoveryRoot,
                authorizedRoot: rootURL,
                pendingURLs: &pendingURLs,
                candidates: &candidates,
                seenPaths: &seenPaths,
                scannedRoots: &scannedRoots,
                extraSkipRoots: walkedDiscoveryRoots,
                skippingSimulatorDeviceTrees: skipSimulatorDeviceTrees,
                context: &context,
                progress: progress,
                onCandidates: onCandidates
            )
            if !completed {
                pendingDiscoveryPaths.append(contentsOf: plan.roots[index...].map(\.path))
                break
            }
            walkedDiscoveryRoots.append(discoveryRoot.standardizedFileURL.path)
        }

        let inventory = await loadedInventory
        context.simulatorInventory = inventory
        if skipSimulatorDeviceTrees {
            if inventory.devices.isEmpty {
                for template in SmartScanCatalog.homeTemplates + SmartScanCatalog.volumeWideTemplates
                where SmartScanCatalog.isCoreSimulatorDevicesTemplate(template.template)
                    || template.template.lowercased().hasSuffix("/xctestdevices") {
                    let url = resolveTemplate(template.template)
                    guard contains(url.resolvingSymlinksInPath(), in: rootURL.resolvingSymlinksInPath()) else { continue }
                    enqueueCandidate(
                        url,
                        into: &pendingURLs,
                        seenPaths: &seenPaths,
                        scannedRoots: &scannedRoots
                    )
                }
            } else {
                enqueueSimulatorDevices(
                    inventory,
                    scanRoot: rootURL,
                    into: &pendingURLs,
                    seenPaths: &seenPaths,
                    scannedRoots: &scannedRoots
                )
            }
        }

        pendingURLs = CleanupTargetNormalizer.collapsingDescendants(pendingURLs, url: { $0 })
        pendingURLs.sort(by: Self.measureOrder)
        let createdNodeCount = await measurePending(
            pendingURLs,
            candidates: &candidates,
            context: &context,
            progress: progress,
            onCandidates: onCandidates
        )

        Self.trimUserContentInventory(&candidates)
        candidates.sort(by: Self.displaySort)
        onCandidates?(candidates)
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
            ),
            pendingDiscoveryPaths: pendingDiscoveryPaths,
            simulatorInventory: inventory,
            createdNodeCount: createdNodeCount
        )
    }

    private func discoverCandidates(
        under rootURL: URL,
        authorizedRoot: URL,
        pendingURLs: inout [URL],
        candidates: inout [FileNode],
        seenPaths: inout Set<String>,
        scannedRoots: inout [String],
        extraSkipRoots: [String],
        skippingSimulatorDeviceTrees: Bool,
        context: inout SmartScanContext,
        progress: ProgressHandler?,
        onCandidates: CandidatesHandler?
    ) -> Bool {
        let authorizedRoot = authorizedRoot.standardizedFileURL.resolvingSymlinksInPath()
        guard !isSymbolicLink(rootURL), contains(rootURL.resolvingSymlinksInPath(), in: authorizedRoot) else { return true }
        let skipRoots = scannedRoots + extraSkipRoots
        let skipRootSet = Set(skipRoots)
        let discoveryErrors = DiscoveryErrorSink()
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants],
            errorHandler: { url, error in
                discoveryErrors.count += 1
                discoveryErrors.failures.append((url, error.localizedDescription))
                return true
            }
        ) else {
            context.errorCount += 1
            appendErrorPlaceholder(
                rootURL,
                message: "Could not enumerate this folder.",
                to: &candidates,
                seenPaths: &seenPaths
            )
            onCandidates?(candidates)
            return true
        }
        defer {
            context.errorCount += discoveryErrors.count
            let before = candidates.count
            for (url, message) in discoveryErrors.failures {
                appendErrorPlaceholder(url, message: message, to: &candidates, seenPaths: &seenPaths)
            }
            if candidates.count > before {
                onCandidates?(candidates)
            }
        }

        var visited = 0
        while let url = enumerator.nextObject() as? URL {
            if visited.isMultiple(of: 256) {
                if Task.isCancelled { return false }
                if Date().timeIntervalSince(context.startedAt) > discoveryBudget { return false }
            }
            visited += 1

            // APFS firmlinks may enumerate canonical URLs outside the selected folder.
            guard contains(url.resolvingSymlinksInPath(), in: authorizedRoot) else {
                enumerator.skipDescendants()
                continue
            }

            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }

            let path = url.standardizedFileURL.path
            if skipRootSet.contains(path) || isInsideSkippedRoot(path, skipRootSet: skipRootSet) {
                enumerator.skipDescendants()
                continue
            }

            emitDiscoveryProgress(url, context: &context, progress: progress)

            if values?.isDirectory != true {
                if isLargeUserContentFile(url) || isDisposableDiagnosticFile(url) {
                    enqueueCandidate(url, into: &pendingURLs, seenPaths: &seenPaths, scannedRoots: &scannedRoots)
                }
                continue
            }

            if isDiscoveredCandidate(url) {
                enumerator.skipDescendants()
                enqueueCandidate(url, into: &pendingURLs, seenPaths: &seenPaths, scannedRoots: &scannedRoots)
                continue
            }

            if shouldSkipDiscoveryDescendants(url, skippingSimulatorDeviceTrees: skippingSimulatorDeviceTrees) {
                enumerator.skipDescendants()
            }
        }
        return true
    }

    private func measurePending(
        _ pendingURLs: [URL],
        candidates: inout [FileNode],
        context: inout SmartScanContext,
        progress: ProgressHandler?,
        onCandidates: CandidatesHandler?
    ) async -> Int {
        let tally = MeasureProgressSink(
            startedAt: context.startedAt,
            scannedCount: context.scannedCount,
            fileCount: context.fileCount,
            directoryCount: context.directoryCount,
            symlinkCount: context.symlinkCount,
            errorCount: context.errorCount,
            discoveredBytes: candidates.reduce(Int64(0)) { $0 + $1.effectiveSize },
            handler: progress
        )
        let inventory = context.simulatorInventory
        var createdNodeCount = 0
        var lastCandidatePublish = Date.distantPast

        func publishCandidates(force: Bool) {
            if !force {
                let now = Date()
                guard now.timeIntervalSince(lastCandidatePublish) >= 0.1 else {
                    return
                }
                lastCandidatePublish = now
            }
            onCandidates?(candidates)
        }

        await withTaskGroup(of: MeasuredRoot.self) { group in
            var index = 0
            var inFlight = 0

            func spawn() {
                while inFlight < Self.measureConcurrency, index < pendingURLs.count {
                    if Task.isCancelled {
                        return
                    }
                    let url = pendingURLs[index]
                    index += 1
                    inFlight += 1
                    group.addTask {
                        await self.measureRoot(url, inventory: inventory, tally: tally)
                    }
                }
            }

            spawn()
            for await measured in group {
                inFlight -= 1
                createdNodeCount += measured.createdNodeCount
                context.scannedCount += measured.nodeCount
                context.fileCount += measured.fileCount
                context.directoryCount += measured.directoryCount
                context.symlinkCount += measured.symlinkCount
                context.errorCount += measured.errorCount
                if let candidate = measured.candidate {
                    candidates.append(candidate)
                    publishCandidates(force: candidates.count == 1)
                }
                if Task.isCancelled {
                    group.cancelAll()
                } else {
                    spawn()
                }
            }
        }

        publishCandidates(force: true)
        return createdNodeCount
    }

    private func measureRoot(
        _ url: URL,
        inventory: SimulatorInventory,
        tally: MeasureProgressSink
    ) async -> MeasuredRoot {
        if Task.isCancelled {
            return .empty
        }

        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        guard fileManager.fileExists(atPath: path) else {
            return .empty
        }

        let result = await diskScanner.scan(
            root: standardizedURL,
            options: .collapsed,
            progress: { update in
                tally.addPartial(update, rootPath: path)
            }
        )
        let bytes = result.root.effectiveSize
        tally.addCompleted(result.snapshot, bytes: bytes, path: path)

        let candidate: FileNode?
        if bytes > 0 {
            candidate = namedCandidate(result.root, inventory: inventory)
        } else if result.root.scanError != nil || result.snapshot.errorCount > 0 {
            candidate = errorCandidate(
                result.root,
                message: result.root.scanError ?? "\(result.snapshot.errorCount) unreadable items"
            )
        } else {
            candidate = nil
        }

        return MeasuredRoot(
            candidate: candidate,
            createdNodeCount: result.createdNodeCount,
            nodeCount: max(result.snapshot.nodeCount, 1),
            fileCount: result.snapshot.fileCount,
            directoryCount: result.snapshot.directoryCount,
            symlinkCount: result.snapshot.symlinkCount,
            errorCount: result.snapshot.errorCount
        )
    }

    private func enqueueCandidate(
        _ url: URL,
        into pendingURLs: inout [URL],
        seenPaths: inout Set<String>,
        scannedRoots: inout [String]
    ) {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        guard seenPaths.insert(path).inserted, fileManager.fileExists(atPath: path) else {
            return
        }
        pendingURLs.append(standardizedURL)
        scannedRoots.append(path)
    }

    private func emitDiscoveryProgress(
        _ url: URL,
        context: inout SmartScanContext,
        progress: ProgressHandler?
    ) {
        guard context.shouldEmitProgress() else {
            return
        }
        progress?(
            ScanProgress(
                currentPath: url.path,
                scannedCount: context.scannedCount,
                fileCount: context.fileCount,
                directoryCount: context.directoryCount,
                symlinkCount: context.symlinkCount,
                errorCount: context.errorCount,
                discoveredBytes: 0,
                startedAt: context.startedAt
            )
        )
    }

    private func appendErrorPlaceholder(
        _ url: URL,
        message: String,
        to candidates: inout [FileNode],
        seenPaths: inout Set<String>
    ) {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        guard seenPaths.insert(path).inserted else {
            return
        }
        candidates.append(
            FileNode(
                url: standardizedURL,
                name: "Unreadable: \(standardizedURL.lastPathComponent)",
                path: path,
                isDirectory: true,
                logicalSize: 0,
                allocatedSize: 0,
                scanError: message
            )
        )
    }

    private func errorCandidate(_ node: FileNode, message: String) -> FileNode {
        FileNode(
            id: node.id,
            url: node.url,
            name: "Unreadable: \(node.displayName)",
            path: node.path,
            isDirectory: node.isDirectory,
            isSymlink: node.isSymlink,
            logicalSize: node.logicalSize,
            allocatedSize: node.allocatedSize,
            modifiedAt: node.modifiedAt,
            createdAt: node.createdAt,
            fileIdentity: node.fileIdentity,
            children: node.children,
            scanError: message,
            rebuildEvidence: node.rebuildEvidence
        )
    }

    private func namedCandidate(_ node: FileNode, inventory: SimulatorInventory) -> FileNode {
        let name = inventory.device(matching: node.path)?.displayName
            ?? SmartScanCatalog.displayName(for: node.url)
            ?? node.name
        return FileNode(
            id: node.id,
            url: node.url,
            name: name,
            path: node.path,
            isDirectory: node.isDirectory,
            isSymlink: node.isSymlink,
            logicalSize: node.logicalSize,
            allocatedSize: node.allocatedSize,
            modifiedAt: node.modifiedAt,
            createdAt: node.createdAt,
            fileIdentity: node.fileIdentity,
            children: node.children,
            scanError: node.scanError,
            rebuildEvidence: node.rebuildEvidence
        )
    }

    private func directCandidateURLs(containedIn rootURL: URL, skippingSimulatorDevices: Bool) -> [URL] {
        var templates = SmartScanCatalog.homeTemplates
        if isVolumeWideRoot(rootURL) {
            templates.append(contentsOf: SmartScanCatalog.volumeWideTemplates)
        }
        if skippingSimulatorDevices {
            templates.removeAll { SmartScanCatalog.isCoreSimulatorDevicesTemplate($0.template) }
        }

        return templates
            .map { resolveTemplate($0.template) }
            .filter { candidate in
                if contains(candidate, in: rootURL) {
                    return true
                }
                return isVolumeWideRoot(rootURL)
            }
    }

    private func resolveTemplate(_ template: String) -> URL {
        if template.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(template.dropFirst(2))).standardizedFileURL
        }

        return URL(fileURLWithPath: template).standardizedFileURL
    }

    private func extraKnownRoots(containedIn rootURL: URL) -> [URL] {
        SmartScanCatalog.extraSystemRoots(scanRoot: rootURL, homeDirectory: homeDirectory)
    }

    func scheduledDiscoveryRoots(containedIn rootURL: URL) -> [URL] {
        discoveryRoots(containedIn: rootURL.standardizedFileURL).roots
    }

    private func discoveryRoots(containedIn rootURL: URL) -> DiscoveryPlan {
        if contains(rootURL, in: homeDirectory), !isHomeRoot(rootURL), !isVolumeWideRoot(rootURL) {
            return DiscoveryPlan(roots: [rootURL])
        }

        let walksWholeHome = contains(homeDirectory, in: rootURL)
            || isHomeRoot(rootURL)
            || (isVolumeWideRoot(rootURL) && isSameVolume(homeDirectory, rootURL))
        guard walksWholeHome || isVolumeWideRoot(rootURL) else {
            return DiscoveryPlan(roots: [rootURL])
        }

        // Visit developer trees first and report any roots left by the discovery budget.
        var priority: [URL] = []
        var remainder: [URL] = []
        var seen: Set<String> = []

        func append(_ url: URL, to bucket: inout [URL]) {
            let path = url.standardizedFileURL.path
            guard fileManager.fileExists(atPath: path), seen.insert(path).inserted else {
                return
            }
            bucket.append(url.standardizedFileURL)
        }

        if walksWholeHome {
            for relative in SmartScanCatalog.priorityHomeRelativePaths {
                append(homeDirectory.appendingPathComponent(relative, isDirectory: true), to: &priority)
            }
            if let children = try? fileManager.contentsOfDirectory(
                at: homeDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) {
                for child in children.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                    guard isDirectory(child), !isSymbolicLink(child) else {
                        continue
                    }
                    append(child, to: &remainder)
                }
            }
            append(homeDirectory, to: &remainder)
        }

        if isVolumeWideRoot(rootURL) {
            append(rootURL, to: &remainder)
        }

        return DiscoveryPlan(roots: priority + remainder)
    }

    private func isHomeRoot(_ url: URL) -> Bool {
        url.standardizedFileURL.path == homeDirectory.path
    }

    private func isVolumeWideRoot(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return path == "/"
    }

    private func shouldSkipDiscoveryDescendants(_ url: URL, skippingSimulatorDeviceTrees: Bool) -> Bool {
        let name = url.lastPathComponent.lowercased()
        if name == ".git" || name == ".svn" || name == ".hg" {
            return true
        }
        if name == "volumes", url.deletingLastPathComponent().path == "/" {
            return true
        }
        if skippingSimulatorDeviceTrees {
            let lowered = url.standardizedFileURL.path.lowercased()
            if lowered.hasSuffix("/coresimulator/devices") || lowered.hasSuffix("/xctestdevices") {
                return true
            }
        }
        let parent = url.deletingLastPathComponent().standardizedFileURL.path
        if parent == homeDirectory.path, SmartScanCatalog.priorityHomeRelativePaths.contains(where: {
            $0.split(separator: "/").first.map(String.init)?.localizedCaseInsensitiveCompare(url.lastPathComponent) == .orderedSame
        }) {
            return true
        }
        return false
    }

    private func isDiscoveredCandidate(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        if name == "node_modules" {
            return true
        }
        if SmartScanCatalog.discoveredDirectoryNames.contains(name) || SmartScanCatalog.isProjectDerivedDataName(name) {
            return true
        }
        if isCargoTargetDirectory(url) || isAndroidBuildIntermediates(url) || isResearchOutputDirectory(url) {
            return true
        }

        let path = url.path.lowercased()
        return path.contains("/node_modules/.cache")
            || isUserLibraryCache(url)
            || path.contains("/.gradle/caches")
    }

    private func isCargoTargetDirectory(_ url: URL) -> Bool {
        guard url.lastPathComponent.lowercased() == "target" else {
            return false
        }

        let parent = url.deletingLastPathComponent()
        if fileManager.fileExists(atPath: parent.appendingPathComponent("Cargo.toml").path) {
            return true
        }
        return false
    }

    private func isAndroidBuildIntermediates(_ url: URL) -> Bool {
        guard url.lastPathComponent.lowercased() == "intermediates",
              url.deletingLastPathComponent().lastPathComponent.lowercased() == "build"
        else {
            return false
        }

        let moduleDirectory = url.deletingLastPathComponent().deletingLastPathComponent()
        return fileManager.fileExists(atPath: moduleDirectory.appendingPathComponent("build.gradle").path)
            || fileManager.fileExists(atPath: moduleDirectory.appendingPathComponent("build.gradle.kts").path)
    }

    private func isResearchOutputDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let path = url.path.lowercased()
        guard name == "output" || path.contains("/output/backtest") else {
            return false
        }
        return path.contains("quants")
            || path.contains("backtest")
            || path.contains("research")
            || path.contains("hummingbot")
    }

    private func isUserLibraryCache(_ url: URL) -> Bool {
        let cachesPath = homeDirectory
            .appendingPathComponent("Library/Caches", isDirectory: true)
            .standardizedFileURL
            .path
            .lowercased()
        let parentPath = url.deletingLastPathComponent().standardizedFileURL.path.lowercased()
        return parentPath == cachesPath
    }

    private func isInsideSkippedRoot(_ path: String, skipRootSet: Set<String>) -> Bool {
        guard !skipRootSet.isEmpty else {
            return false
        }
        var current = (path as NSString).deletingLastPathComponent
        while current != "/", !current.isEmpty {
            if skipRootSet.contains(current) {
                return true
            }
            let parent = (current as NSString).deletingLastPathComponent
            if parent == current {
                return false
            }
            current = parent
        }
        return skipRootSet.contains("/")
    }

    private func contains(_ candidate: URL, in rootURL: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = rootURL.standardizedFileURL.path
        if rootPath == "/" {
            return true
        }

        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    private func isSameVolume(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let left = FileIdentity.capture(at: lhs), let right = FileIdentity.capture(at: rhs) else {
            return false
        }
        return left.deviceID == right.deviceID
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
    }

    private static func trimUserContentInventory(_ candidates: inout [FileNode]) {
        let userFiles = candidates.filter { !$0.isDirectory && SmartScanCatalog.isUserContentPath($0.path) }
        guard userFiles.count > SmartScanCatalog.documentsInventoryLimit else {
            return
        }
        let keep = Set(
            userFiles.sorted { $0.effectiveSize > $1.effectiveSize }
                .prefix(SmartScanCatalog.documentsInventoryLimit)
                .map(\.path)
        )
        candidates.removeAll { candidate in
            !candidate.isDirectory && SmartScanCatalog.isUserContentPath(candidate.path) && !keep.contains(candidate.path)
        }
    }

    private static func displaySort(lhs: FileNode, rhs: FileNode) -> Bool {
        if lhs.effectiveSize == rhs.effectiveSize {
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        return lhs.effectiveSize > rhs.effectiveSize
    }

    private func isLargeUserContentFile(_ url: URL) -> Bool {
        guard SmartScanCatalog.isUserContentPath(url.path) else {
            return false
        }
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey])
        let logical = Int64(values?.fileSize ?? 0)
        let allocated = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        return max(logical, allocated) >= SmartScanCatalog.largeUserContentByteThreshold
    }

    private func isDisposableDiagnosticFile(_ url: URL) -> Bool {
        guard ["log", "crash", "ips", "dmp"].contains(url.pathExtension.lowercased()) || url.lastPathComponent.contains(".log.") else { return false }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let node = FileNode(url: url, isDirectory: false, logicalSize: 0, allocatedSize: 0,
            modifiedAt: values?.contentModificationDate, captureIdentity: false)
        return RuleEngine(homeDirectory: homeDirectory).classify(node).level.isQueueable
    }

    private func shouldSkipSimulatorDeviceCatalog(for rootURL: URL) -> Bool {
        if let injectedSimulatorInventory {
            return !injectedSimulatorInventory.devices.isEmpty
        }
        return isRealUserHome && (isHomeRoot(rootURL) || isVolumeWideRoot(rootURL) || contains(homeDirectory, in: rootURL))
    }

    private var isRealUserHome: Bool {
        homeDirectory.resolvingSymlinksInPath().standardizedFileURL.path
            == FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().standardizedFileURL.path
    }

    func shouldLoadSimulatorInventory(for root: URL) -> Bool {
        guard isRealUserHome else { return false }
        let simulatorRoots = ["Library/Developer/CoreSimulator", "Library/Developer/XCTestDevices"]
            .map { homeDirectory.appendingPathComponent($0, isDirectory: true) }
            + [URL(fileURLWithPath: "/Library/Developer/CoreSimulator", isDirectory: true)]
        return simulatorRoots.contains { contains($0, in: root) || contains(root, in: $0) }
    }

    private func resolvedSimulatorInventory(for root: URL) async -> SimulatorInventory {
        if let injectedSimulatorInventory {
            return injectedSimulatorInventory
        }
        guard shouldLoadSimulatorInventory(for: root) else {
            return .empty
        }
        return await SimulatorInventory.loadCancellable()
    }

    private func enqueueSimulatorDevices(
        _ inventory: SimulatorInventory,
        scanRoot: URL,
        into pendingURLs: inout [URL],
        seenPaths: inout Set<String>,
        scannedRoots: inout [String]
    ) {
        for device in inventory.devices where !device.dataPath.isEmpty {
            let url = URL(fileURLWithPath: device.dataPath, isDirectory: true)
            guard contains(url.resolvingSymlinksInPath(), in: scanRoot.resolvingSymlinksInPath()) else { continue }
            enqueueCandidate(url, into: &pendingURLs, seenPaths: &seenPaths, scannedRoots: &scannedRoots)
        }
    }

    private static func measureOrder(lhs: URL, rhs: URL) -> Bool {
        let left = SmartScanCatalog.collapsedMeasureRank(lhs)
        let right = SmartScanCatalog.collapsedMeasureRank(rhs)
        if left == right {
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
        return left < right
    }
}

private struct DiscoveryPlan {
    let roots: [URL]
}

private struct MeasuredRoot: Sendable {
    let candidate: FileNode?
    let createdNodeCount: Int
    let nodeCount: Int
    let fileCount: Int
    let directoryCount: Int
    let symlinkCount: Int
    let errorCount: Int

    static let empty = MeasuredRoot(
        candidate: nil,
        createdNodeCount: 0,
        nodeCount: 0,
        fileCount: 0,
        directoryCount: 0,
        symlinkCount: 0,
        errorCount: 0
    )
}

private final class MeasureProgressSink: @unchecked Sendable {
    let startedAt: Date
    private let handler: SmartCleanupScanner.ProgressHandler?
    private let lock = NSLock()
    private var scannedCount: Int
    private var fileCount: Int
    private var directoryCount: Int
    private var symlinkCount: Int
    private var errorCount: Int
    private var discoveredBytes: Int64
    private var partials: [String: ScanProgress] = [:]
    private var lastEmit = Date.distantPast

    init(
        startedAt: Date,
        scannedCount: Int,
        fileCount: Int,
        directoryCount: Int,
        symlinkCount: Int,
        errorCount: Int,
        discoveredBytes: Int64,
        handler: SmartCleanupScanner.ProgressHandler?
    ) {
        self.startedAt = startedAt
        self.scannedCount = scannedCount
        self.fileCount = fileCount
        self.directoryCount = directoryCount
        self.symlinkCount = symlinkCount
        self.errorCount = errorCount
        self.discoveredBytes = discoveredBytes
        self.handler = handler
    }

    func addPartial(_ update: ScanProgress, rootPath: String) {
        lock.lock()
        partials[rootPath] = update
        emitLocked(path: update.currentPath)
        lock.unlock()
    }

    func addCompleted(_ snapshot: ScanSnapshot, bytes: Int64, path: String) {
        lock.lock()
        partials.removeValue(forKey: path)
        scannedCount += max(snapshot.nodeCount, 1)
        fileCount += snapshot.fileCount
        directoryCount += snapshot.directoryCount
        symlinkCount += snapshot.symlinkCount
        errorCount += snapshot.errorCount
        discoveredBytes += bytes
        emitLocked(path: path)
        lock.unlock()
    }

    private func emitLocked(path: String) {
        let now = Date()
        guard now.timeIntervalSince(lastEmit) >= 0.1 else { return }
        lastEmit = now
        let active = Array(partials.values)
        handler?(
            ScanProgress(
                currentPath: path,
                scannedCount: scannedCount + active.reduce(0) { $0 + $1.scannedCount },
                fileCount: fileCount + active.reduce(0) { $0 + $1.fileCount },
                directoryCount: directoryCount + active.reduce(0) { $0 + $1.directoryCount },
                symlinkCount: symlinkCount + active.reduce(0) { $0 + $1.symlinkCount },
                errorCount: errorCount + active.reduce(0) { $0 + $1.errorCount },
                discoveredBytes: discoveredBytes + active.reduce(0) { $0 + $1.discoveredBytes },
                startedAt: startedAt
            )
        )
    }
}

private struct SmartScanContext {
    let startedAt: Date
    var scannedCount = 0
    var fileCount = 0
    var directoryCount = 0
    var symlinkCount = 0
    var errorCount = 0
    var simulatorInventory: SimulatorInventory = .empty
    var lastProgressEmittedAt = Date.distantPast

    mutating func shouldEmitProgress() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastProgressEmittedAt) >= 0.1 else {
            return false
        }
        lastProgressEmittedAt = now
        return true
    }
}

private final class DiscoveryErrorSink: @unchecked Sendable {
    var count = 0
    var failures: [(URL, String)] = []
}
