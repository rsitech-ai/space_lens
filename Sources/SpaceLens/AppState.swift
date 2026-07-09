import AppKit
import Foundation
import OSLog
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private static let logger = Logger(subsystem: "com.andrzej.spacelens", category: "session")

    enum SidebarSelection: String, CaseIterable, Identifiable {
        case all
        case safe
        case review
        case valuable
        case active
        case errors
        case queue

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .all:
                "All Files"
            case .safe:
                "Safe Candidates"
            case .review:
                "Needs Review"
            case .valuable:
                "Valuable Data"
            case .active:
                "Active / Tool-Owned"
            case .errors:
                "Scan Errors"
            case .queue:
                "Cleanup Queue"
            }
        }
    }

    enum TableFilter: String, CaseIterable, Identifiable {
        case all
        case cleanupReady
        case largeOnly
        case folders
        case files

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .all:
                "All"
            case .cleanupReady:
                "Cleanup Ready"
            case .largeOnly:
                "Large"
            case .folders:
                "Folders"
            case .files:
                "Files"
            }
        }
    }

    enum ScanMode: String {
        case full
        case smart

        var inProgressTitle: String {
            switch self {
            case .full:
                "Live scan in progress"
            case .smart:
                "Smart scan in progress"
            }
        }

        var headerTitle: String {
            switch self {
            case .full:
                "Scanning files"
            case .smart:
                "Finding cleanup candidates"
            }
        }
    }

    @Published var sidebarSelection: SidebarSelection = .all {
        didSet {
            rebuildVisibleNodes()
        }
    }
    @Published var rootNode: FileNode? {
        didSet {
            rebuildNodeCaches()
        }
    }
    @Published var snapshot: ScanSnapshot?
    @Published var selectedNodeIDs: Set<UUID> = [] {
        didSet {
            rebuildSelectedNodeCaches()
        }
    }
    @Published var searchText = "" {
        didSet {
            rebuildVisibleNodes()
        }
    }
    @Published var tableFilter: TableFilter = .all {
        didSet {
            rebuildVisibleNodes()
        }
    }
    @Published var isScanning = false
    @Published var scanMode: ScanMode = .full
    @Published var scanProgress: ScanProgress?
    @Published var scanStatistics: ScanStatistics?
    @Published var scanIntelligenceSummary: ScanIntelligenceSummary?
    @Published var cleanupQueue: [CleanupCandidate] = [] {
        didSet {
            rebuildVisibleNodes()
            persistSession()
        }
    }
    @Published var cleanupInProgressIDs: Set<UUID> = []
    @Published var cleanupProgress: CleanupProgress?
    @Published var cleanupStatusMessage: String?
    @Published var latestError: String?
    @Published private(set) var visibleNodes: [FlattenedFileNode] = []
    @Published private(set) var visibleCleanupReadyCount = 0
    @Published private(set) var selectedCleanupEligibleNodes: [FileNode] = []
    @Published private(set) var selectedRecoverableBytes: Int64 = 0

    let ruleEngine = RuleEngine()
    let intelligenceService: IntelligenceService = LocalIntelligenceService()

    private let smartCleanupScanner: SmartCleanupScanner
    private var scanTask: Task<Void, Never>?
    private var activeScanID: UUID?
    private var currentScanRootURL: URL?
    private var allNodes: [FlattenedFileNode] = []
    private var nodeByID: [UUID: FileNode] = [:]
    private var classificationCache: [UUID: SafetyClassification] = [:]
    private var securityScopedRootURL: URL?
    private var isAccessingSecurityScopedRoot = false
    private let sessionStore: AppSessionStore?
    private var pendingRestoredCleanupPaths: Set<String> = []

    deinit {
        if isAccessingSecurityScopedRoot {
            securityScopedRootURL?.stopAccessingSecurityScopedResource()
        }
    }

    init(
        sessionStore: AppSessionStore? = nil,
        restoreOnLaunch: Bool = false,
        smartCleanupScanner: SmartCleanupScanner = SmartCleanupScanner()
    ) {
        self.sessionStore = sessionStore
        self.smartCleanupScanner = smartCleanupScanner

        guard restoreOnLaunch, let sessionStore, let session = sessionStore.load() else {
            return
        }

        pendingRestoredCleanupPaths = Self.pathMatchKeys(for: session.cleanupPaths)
        guard let rootURL = sessionStore.resolveRootURL(from: session) else {
            if !session.cleanupPaths.isEmpty || session.rootPath != nil {
                latestError = "SpaceLens could not restore the last folder. Select it again to refresh saved access."
            }
            return
        }

        currentScanRootURL = rootURL
    }

    var selectedNodeID: UUID? {
        get {
            selectedNodeIDs.first
        }
        set {
            selectedNodeIDs = newValue.map { Set([$0]) } ?? []
        }
    }

    var selectedNode: FileNode? {
        let preferredID = visibleNodes.first { selectedNodeIDs.contains($0.node.id) }?.node.id ?? selectedNodeID
        guard let preferredID else {
            return nil
        }

        return nodeByID[preferredID]
    }

    var selectedNodes: [FileNode] {
        selectedNodeIDs.compactMap { nodeByID[$0] }
    }

    var projectedRecoverableBytes: Int64 {
        cleanupQueue.reduce(Int64(0)) { $0 + $1.estimatedRecoverableBytes }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select a folder to scan"
        panel.prompt = "Scan"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            startScan(root: url)
        }
    }

    func rescan() {
        guard let rootNode else {
            chooseFolder()
            return
        }

        startScan(root: rootNode.url)
    }

    func smartScan() {
        let root = rootNode?.url
            ?? currentScanRootURL
            ?? securityScopedRootURL
            ?? FileManager.default.homeDirectoryForCurrentUser
        startSmartScan(root: root)
    }

    func startScan(root: URL) {
        scanTask?.cancel()
        beginAccessingSecurityScopedRoot(root)
        let scanID = UUID()
        activeScanID = scanID
        currentScanRootURL = root
        scanMode = .full
        isScanning = true
        latestError = nil
        selectedNodeIDs = []
        snapshot = nil
        scanStatistics = nil
        scanIntelligenceSummary = nil
        scanProgress = ScanProgress(currentPath: root.path, scannedCount: 0, errorCount: 0)

        let ruleEngine = ruleEngine
        let intelligenceService = intelligenceService

        scanTask = Task {
            let result = await DiskScanner().scan(root: root) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self, self.isScanning, self.activeScanID == scanID else {
                        return
                    }

                    withAnimation(.easeOut(duration: 0.18)) {
                        self.scanProgress = progress
                    }
                }
            }

            guard !Task.isCancelled else {
                return
            }

            let items = result.root.flattened().dropFirst().map { item in
                ClassifiedScanItem(
                    node: item.node,
                    classification: ruleEngine.classify(item.node)
                )
            }
            let statistics = ScanStatistics(snapshot: result.snapshot, items: items)
            let intelligenceSummary = await intelligenceService.summarizeScan(
                snapshot: result.snapshot,
                items: items
            )

            await MainActor.run { [weak self] in
                guard let self else {
                    return
                }
                guard !Task.isCancelled, self.activeScanID == scanID else {
                    return
                }

                self.rootNode = result.root
                self.snapshot = result.snapshot
                self.isScanning = false
                self.activeScanID = nil
                self.scanProgress = nil
                self.scanStatistics = statistics
                self.scanIntelligenceSummary = intelligenceSummary
                self.selectedNodeIDs = result.root.children.first.map { Set([$0.id]) } ?? []
                self.cleanupQueue.removeAll { candidate in
                    !FileManager.default.fileExists(atPath: candidate.fileNode.path)
                }
                self.restorePersistedCleanupQueueIfNeeded()
                self.persistSession()
            }
        }
    }

    func startSmartScan(root: URL) {
        scanTask?.cancel()
        beginAccessingSecurityScopedRoot(root)
        let scanID = UUID()
        activeScanID = scanID
        currentScanRootURL = root
        scanMode = .smart
        isScanning = true
        latestError = nil
        selectedNodeIDs = []
        snapshot = nil
        scanStatistics = nil
        scanIntelligenceSummary = nil
        scanProgress = ScanProgress(currentPath: root.path, scannedCount: 0, errorCount: 0)

        let ruleEngine = ruleEngine
        let intelligenceService = intelligenceService
        let smartCleanupScanner = smartCleanupScanner

        scanTask = Task {
            let result = await smartCleanupScanner.scan(root: root) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self, self.isScanning, self.activeScanID == scanID else {
                        return
                    }

                    withAnimation(.easeOut(duration: 0.18)) {
                        self.scanProgress = progress
                    }
                }
            }

            guard !Task.isCancelled else {
                return
            }

            let items = result.root.flattened().dropFirst().map { item in
                ClassifiedScanItem(
                    node: item.node,
                    classification: ruleEngine.classify(item.node)
                )
            }
            let statistics = ScanStatistics(snapshot: result.snapshot, items: items)
            let intelligenceSummary = await intelligenceService.summarizeScan(
                snapshot: result.snapshot,
                items: items
            )

            await MainActor.run { [weak self] in
                guard let self else {
                    return
                }
                guard !Task.isCancelled, self.activeScanID == scanID else {
                    return
                }

                self.rootNode = result.root
                self.snapshot = result.snapshot
                self.isScanning = false
                self.activeScanID = nil
                self.scanProgress = nil
                self.scanStatistics = statistics
                self.scanIntelligenceSummary = intelligenceSummary
                self.selectedNodeIDs = result.root.children.first.map { Set([$0.id]) } ?? []
                self.cleanupQueue.removeAll { candidate in
                    !FileManager.default.fileExists(atPath: candidate.fileNode.path)
                }
                self.restorePersistedCleanupQueueIfNeeded()
                self.persistSession()
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        activeScanID = nil
        isScanning = false
        scanProgress = nil
        if rootNode == nil {
            stopAccessingSecurityScopedRoot()
        }
    }

    func classification(for node: FileNode) -> SafetyClassification {
        if let cached = classificationCache[node.id] {
            return cached
        }

        let classification = ruleEngine.classify(node)
        classificationCache[node.id] = classification
        return classification
    }

    func addToCleanupQueue(node: FileNode) {
        let classification = ruleEngine.classify(node)
        guard classification.level.isQueueable else {
            latestError = "SpaceLens only queues known safe, rebuildable, or generated candidates in this MVP."
            return
        }

        guard !cleanupQueue.contains(where: { $0.fileNode.path == node.path }) else {
            return
        }

        cleanupQueue.append(
            CleanupCandidate(
                fileNode: node,
                classification: classification,
                estimatedRecoverableBytes: node.effectiveSize,
                action: .queueForFutureTrash
            )
        )
    }

    func addSelectedToCleanupQueue() {
        let nodes = selectedCleanupEligibleNodes
        nodes.forEach { addToCleanupQueue(node: $0) }
        if !nodes.isEmpty {
            cleanupStatusMessage = "Queued \(nodes.count) cleanup-ready items"
        }
    }

    func selectAllVisible() {
        selectedNodeIDs = Set(visibleNodes.map(\.node.id))
    }

    func selectCleanupReadyVisible() {
        selectedNodeIDs = Set(visibleNodes.filter { classification(for: $0.node).level.isQueueable }.map(\.node.id))
    }

    func clearSelection() {
        selectedNodeIDs = []
    }

    func pruneSelectionToVisible() {
        let visibleIDs = Set(visibleNodes.map(\.node.id))
        selectedNodeIDs = selectedNodeIDs.intersection(visibleIDs)
    }

    func isCleanupInProgress(node: FileNode) -> Bool {
        cleanupInProgressIDs.contains(node.id)
    }

    func moveToBin(node: FileNode) async {
        await performCleanup(node: node, operationName: "Moved to Bin") { progress in
            try await FileCleanupService.moveToBin(url: node.url, progress: progress)
        }
    }

    func deleteForever(node: FileNode) async {
        await performCleanup(node: node, operationName: "Deleted forever") { progress in
            try await FileCleanupService.deleteForever(url: node.url, progress: progress)
        }
    }

    func moveSelectedToBin() async {
        await performBulkCleanup(nodes: selectedCleanupEligibleNodes, operationName: "Moved to Bin") { node, progress in
            try await FileCleanupService.moveToBin(url: node.url, progress: progress)
        }
    }

    func deleteSelectedForever() async {
        await performBulkCleanup(nodes: selectedCleanupEligibleNodes, operationName: "Deleted forever") { node, progress in
            try await FileCleanupService.deleteForever(url: node.url, progress: progress)
        }
    }

    func removeFromCleanupQueue(_ candidate: CleanupCandidate) {
        cleanupQueue.removeAll { $0.id == candidate.id }
    }

    func revealInFinder(_ node: FileNode) {
        FinderService.reveal(node.url)
    }

    private func performCleanup(
        node: FileNode,
        operationName: String,
        operation: @escaping @Sendable (FileCleanupService.ProgressHandler?) async throws -> Void
    ) async {
        let classification = ruleEngine.classify(node)
        guard classification.level.isQueueable else {
            latestError = "Cleanup is disabled for this item because it is not classified as a safe, rebuildable, or generated candidate."
            return
        }

        guard FileManager.default.fileExists(atPath: node.path) else {
            latestError = "The selected item no longer exists on disk. Rescan this folder."
            rootNode = rootNode?.removing(id: node.id)
            cleanupQueue.removeAll { $0.fileNode.id == node.id }
            selectedNodeIDs.remove(node.id)
            return
        }

        latestError = nil
        cleanupStatusMessage = nil
        cleanupProgress = CleanupProgress(
            phase: .preparing,
            currentPath: node.path,
            completedItemCount: 0,
            totalItemCount: 1,
            completedBytes: 0,
            totalBytes: node.effectiveSize
        )
        cleanupInProgressIDs.insert(node.id)

        do {
            try await operation(cleanupProgressHandler(for: node))
            cleanupInProgressIDs.remove(node.id)
            cleanupStatusMessage = "\(operationName): \(node.displayName)"
            cleanupProgress = nil
            rootNode = rootNode?.removing(id: node.id)
            cleanupQueue.removeAll { $0.fileNode.id == node.id }
            selectedNodeIDs.remove(node.id)
        } catch {
            cleanupInProgressIDs.remove(node.id)
            cleanupProgress = nil
            latestError = "Cleanup failed for \(node.displayName): \(error.localizedDescription)"
        }
    }

    private func performBulkCleanup(
        nodes: [FileNode],
        operationName: String,
        operation: @escaping @Sendable (FileNode, FileCleanupService.ProgressHandler?) async throws -> Void
    ) async {
        guard !nodes.isEmpty else {
            latestError = "Select one or more cleanup-ready items first."
            return
        }

        var cleanedCount = 0
        var cleanedBytes: Int64 = 0

        for node in nodes {
            let beforeIDs = selectedNodeIDs
            await performCleanup(node: node, operationName: operationName) {
                try await operation(node, $0)
            }
            if latestError == nil, beforeIDs.contains(node.id), !selectedNodeIDs.contains(node.id) {
                cleanedCount += 1
                cleanedBytes += node.effectiveSize
            }
        }

        if cleanedCount > 0 {
            cleanupStatusMessage = "\(operationName): \(cleanedCount) items, \(ByteFormat.string(cleanedBytes))"
        }
    }

    private func cleanupProgressHandler(for node: FileNode) -> FileCleanupService.ProgressHandler {
        { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self, self.cleanupInProgressIDs.contains(node.id) else {
                    return
                }

                self.cleanupProgress = progress
            }
        }
    }

    private func rebuildNodeCaches() {
        allNodes = rootNode.map { Array($0.flattened().dropFirst()) } ?? []
        nodeByID = [:]
        if let rootNode {
            nodeByID[rootNode.id] = rootNode
        }
        for item in allNodes {
            nodeByID[item.node.id] = item.node
        }
        classificationCache.removeAll(keepingCapacity: true)
        rebuildVisibleNodes()
        rebuildSelectedNodeCaches()
    }

    private func rebuildVisibleNodes() {
        guard rootNode != nil else {
            visibleNodes = []
            visibleCleanupReadyCount = 0
            return
        }

        let sidebarFilteredNodes: [FlattenedFileNode]
        switch sidebarSelection {
        case .all:
            sidebarFilteredNodes = allNodes
        case .safe:
            sidebarFilteredNodes = allNodes.filter { classification(for: $0.node).level.isQueueable }
        case .review:
            sidebarFilteredNodes = allNodes.filter { classification(for: $0.node).level == .unknownReview }
        case .valuable:
            sidebarFilteredNodes = allNodes.filter { classification(for: $0.node).level == .largeButValuable }
        case .active:
            sidebarFilteredNodes = allNodes.filter { classification(for: $0.node).level == .activeOrInUse }
        case .errors:
            sidebarFilteredNodes = allNodes.filter { $0.node.scanError != nil }
        case .queue:
            let queuedIDs = Set(cleanupQueue.map { $0.fileNode.id })
            sidebarFilteredNodes = allNodes.filter { queuedIDs.contains($0.node.id) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let searchedNodes = query.isEmpty
            ? sidebarFilteredNodes
            : sidebarFilteredNodes.filter { item in
                item.node.displayName.lowercased().contains(query)
                    || item.node.path.lowercased().contains(query)
                    || classification(for: item.node).category.lowercased().contains(query)
            }

        visibleNodes = searchedNodes.filter { item in
            switch tableFilter {
            case .all:
                true
            case .cleanupReady:
                classification(for: item.node).level.isQueueable
            case .largeOnly:
                item.node.effectiveSize >= 100_000_000
            case .folders:
                item.node.isDirectory
            case .files:
                !item.node.isDirectory
            }
        }
        visibleCleanupReadyCount = visibleNodes.reduce(into: 0) { count, item in
            if classification(for: item.node).level.isQueueable {
                count += 1
            }
        }
    }

    private func rebuildSelectedNodeCaches() {
        let eligibleNodes = selectedNodeIDs.compactMap { id -> FileNode? in
            guard let node = nodeByID[id], classification(for: node).level.isQueueable else {
                return nil
            }
            return node
        }

        selectedCleanupEligibleNodes = eligibleNodes
        selectedRecoverableBytes = eligibleNodes.reduce(Int64(0)) { $0 + $1.effectiveSize }
    }

    private func restorePersistedCleanupQueueIfNeeded() {
        guard !pendingRestoredCleanupPaths.isEmpty else {
            return
        }

        var restoredCandidates: [CleanupCandidate] = []
        for item in allNodes where !Self.pathMatchKeys(for: [item.node.path]).isDisjoint(with: pendingRestoredCleanupPaths) {
            let classification = classification(for: item.node)
            guard classification.level.isQueueable else {
                continue
            }

            restoredCandidates.append(
                CleanupCandidate(
                    fileNode: item.node,
                    classification: classification,
                    estimatedRecoverableBytes: item.node.effectiveSize,
                    action: .queueForFutureTrash
                )
            )
        }

        cleanupQueue = restoredCandidates
        pendingRestoredCleanupPaths.removeAll()
        if !restoredCandidates.isEmpty {
            cleanupStatusMessage = "Restored \(restoredCandidates.count) cleanup queued items"
        }
    }

    private func beginAccessingSecurityScopedRoot(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        if securityScopedRootURL == standardizedURL, isAccessingSecurityScopedRoot {
            return
        }

        stopAccessingSecurityScopedRoot()
        securityScopedRootURL = standardizedURL
        isAccessingSecurityScopedRoot = standardizedURL.startAccessingSecurityScopedResource()
    }

    private func stopAccessingSecurityScopedRoot() {
        guard isAccessingSecurityScopedRoot, let securityScopedRootURL else {
            self.securityScopedRootURL = nil
            isAccessingSecurityScopedRoot = false
            return
        }

        securityScopedRootURL.stopAccessingSecurityScopedResource()
        self.securityScopedRootURL = nil
        isAccessingSecurityScopedRoot = false
    }

    private func persistSession() {
        guard let sessionStore else {
            return
        }

        do {
            try sessionStore.save(rootURL: securityScopedRootURL ?? rootNode?.url, cleanupQueue: cleanupQueue)
        } catch {
            Self.logger.error("Failed to persist SpaceLens session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func pathMatchKeys(for paths: [String]) -> Set<String> {
        Set(paths.flatMap { path -> [String] in
            let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
            let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
            var keys = [path, standardizedPath, resolvedPath]

            for candidate in [path, standardizedPath, resolvedPath] {
                if candidate.hasPrefix("/private/") {
                    keys.append(String(candidate.dropFirst("/private".count)))
                } else if candidate.hasPrefix("/var/") || candidate.hasPrefix("/tmp/") {
                    keys.append("/private" + candidate)
                }
            }

            return keys
        })
    }
}
