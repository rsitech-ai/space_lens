import AppKit
import Foundation
import OSLog
import Security
import SwiftUI

struct EmptyResultsPresentation: Equatable {
    let title: String
    let systemImage: String
    let description: String
}

@MainActor
final class AppState: ObservableObject {
    private static let logger = Logger(subsystem: "com.rsitech.spacelens", category: "session")

    private nonisolated static func hasAppSandboxEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }
        return SecTaskCopyValueForEntitlement(
            task,
            "com.apple.security.app-sandbox" as CFString,
            nil
        ) as? Bool == true
    }
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

    private var storedSidebarSelection: SidebarSelection = .all
    var sidebarSelection: SidebarSelection {
        get { storedSidebarSelection }
        set {
            guard newValue != storedSidebarSelection else {
                return
            }
            objectWillChange.send()
            storedSidebarSelection = newValue
            rebuildVisibleNodes()
        }
    }
    private var storedRootNode: FileNode?
    var rootNode: FileNode? {
        get { storedRootNode }
        set {
            objectWillChange.send()
            storedRootNode = newValue
            rebuildNodeCaches()
        }
    }
    @Published var snapshot: ScanSnapshot?
    private var storedSelectedNodeIDs: Set<UUID> = []
    var selectedNodeIDs: Set<UUID> {
        get { storedSelectedNodeIDs }
        set {
            guard newValue != storedSelectedNodeIDs else {
                return
            }
            objectWillChange.send()
            storedSelectedNodeIDs = newValue
        }
    }
    private var storedSearchText = ""
    var searchText: String {
        get { storedSearchText }
        set {
            guard newValue != storedSearchText else {
                return
            }
            objectWillChange.send()
            storedSearchText = newValue
            rebuildVisibleNodes()
        }
    }
    private var storedTableFilter: TableFilter = .all
    var tableFilter: TableFilter {
        get { storedTableFilter }
        set {
            guard newValue != storedTableFilter else {
                return
            }
            objectWillChange.send()
            storedTableFilter = newValue
            rebuildVisibleNodes()
        }
    }
    @Published var isScanning = false
    @Published var scanMode: ScanMode = .full
    @Published var scanProgress: ScanProgress?
    @Published var scanStatistics: ScanStatistics?
    @Published var scanIntelligenceSummary: ScanIntelligenceSummary?
    private var storedCleanupQueue: [CleanupCandidate] = []
    private(set) var queuedNodeIDs: Set<UUID> = []
    var cleanupQueue: [CleanupCandidate] {
        get { storedCleanupQueue }
        set {
            objectWillChange.send()
            storedCleanupQueue = newValue
            queuedNodeIDs = Set(newValue.lazy.map(\.fileNode.id))
            rebuildVisibleNodes()
            persistSession()
        }
    }
    @Published var cleanupInProgressIDs: Set<UUID> = []
    @Published var cleanupProgress: CleanupProgress?
    @Published var cleanupStatusMessage: String?
    @Published var latestError: String?
    private(set) var visibleNodes: [FlattenedFileNode] = []
    private(set) var visibleCleanupReadyCount = 0
    var selectedCleanupEligibleNodes: [FileNode] {
        let eligibleNodes = selectedNodeIDs.compactMap { id -> FileNode? in
            guard let node = nodeByID[id], classification(for: node).level.isQueueable else {
                return nil
            }
            return node
        }
        return CleanupTargetNormalizer.collapsingDescendants(eligibleNodes, url: \.url)
    }

    var selectedRecoverableBytes: Int64 {
        selectedCleanupEligibleNodes.reduce(Int64(0)) { $0 + $1.effectiveSize }
    }

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
    private let requiresSecurityScopedAccess: Bool
    private let startSecurityScopedAccess: @Sendable (URL) -> Bool
    private let stopSecurityScopedAccess: @Sendable (URL) -> Void
    private let sessionStore: AppSessionStore?
    private var pendingRestoredCleanupPaths: Set<String> = []

    deinit {
        if isAccessingSecurityScopedRoot, let securityScopedRootURL {
            stopSecurityScopedAccess(securityScopedRootURL)
        }
    }

    init(
        sessionStore: AppSessionStore? = nil,
        restoreOnLaunch: Bool = false,
        smartCleanupScanner: SmartCleanupScanner = SmartCleanupScanner(),
        requiresSecurityScopedAccess: Bool = AppState.hasAppSandboxEntitlement(),
        startSecurityScopedAccess: @escaping @Sendable (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        stopSecurityScopedAccess: @escaping @Sendable (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    ) {
        self.sessionStore = sessionStore
        self.smartCleanupScanner = smartCleanupScanner
        self.requiresSecurityScopedAccess = requiresSecurityScopedAccess
        self.startSecurityScopedAccess = startSecurityScopedAccess
        self.stopSecurityScopedAccess = stopSecurityScopedAccess

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

    var emptyResultsPresentation: EmptyResultsPresentation {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tableFilter != .all {
            return EmptyResultsPresentation(
                title: "No Matching Items",
                systemImage: "line.3.horizontal.decrease.circle",
                description: "Try another search or filter."
            )
        }

        switch sidebarSelection {
        case .all:
            return EmptyResultsPresentation(
                title: "No Scanned Items",
                systemImage: "externaldrive",
                description: "The selected folder does not contain any visible items."
            )
        case .safe:
            return EmptyResultsPresentation(
                title: "No Cleanup Candidates",
                systemImage: "checkmark.shield",
                description: "SpaceLens did not find low-risk cleanup items in this scan."
            )
        case .review:
            return EmptyResultsPresentation(
                title: "Nothing Needs Review",
                systemImage: "checkmark.circle",
                description: "No scanned items require a manual safety decision."
            )
        case .valuable:
            return EmptyResultsPresentation(
                title: "No Valuable Data Flagged",
                systemImage: "doc.badge.gearshape",
                description: "No scanned items were classified as large or valuable."
            )
        case .active:
            return EmptyResultsPresentation(
                title: "No Active or Tool-Owned Items",
                systemImage: "bolt.horizontal",
                description: "No scanned items appear active or owned by a running tool."
            )
        case .errors:
            return EmptyResultsPresentation(
                title: "No Scan Errors",
                systemImage: "checkmark.seal",
                description: "SpaceLens read every scanned location successfully."
            )
        case .queue:
            return EmptyResultsPresentation(
                title: "Cleanup Queue Is Empty",
                systemImage: "tray",
                description: "Select cleanup-ready items and add them to the queue."
            )
        }
    }

    var authorizedScanRoot: URL? {
        rootNode?.url ?? securityScopedRootURL ?? currentScanRootURL
    }

    var currentAuthorizedScanRoot: URL? {
        securityScopedRootURL
    }

    func chooseFolder() {
        chooseFolder(for: .full)
    }

    private func chooseFolder(for scanMode: ScanMode) {
        let panel = NSOpenPanel()
        panel.title = scanMode == .smart
            ? "Select a folder for Smart Scan"
            : "Select a folder to scan"
        panel.prompt = scanMode == .smart ? "Smart Scan" : "Scan"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            switch scanMode {
            case .full:
                startScan(root: url)
            case .smart:
                startSmartScan(root: url)
            }
        }
    }

    func rescan() {
        guard let root = authorizedScanRoot else {
            chooseFolder()
            return
        }

        startScan(root: root)
    }

    func smartScan() {
        guard let root = authorizedScanRoot else {
            chooseFolder(for: .smart)
            return
        }
        startSmartScan(root: root)
    }

    func startScan(root: URL) {
        scanTask?.cancel()
        guard beginAccessingSecurityScopedRoot(root) else {
            rejectUnauthorizedScan()
            return
        }
        resetStaleResultsIfRootChanged(to: root)
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

        scanTask = Task { [weak self] in
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
        guard beginAccessingSecurityScopedRoot(root) else {
            rejectUnauthorizedScan()
            return
        }
        resetStaleResultsIfRootChanged(to: root)
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

        scanTask = Task { [weak self] in
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

        var updatedQueue = cleanupQueue
        guard !updatedQueue.contains(where: {
            CleanupTargetNormalizer.isSameOrDescendant(node.url, of: $0.fileNode.url)
        }) else {
            return
        }

        updatedQueue.removeAll {
            CleanupTargetNormalizer.isSameOrDescendant($0.fileNode.url, of: node.url)
        }
        updatedQueue.append(
            CleanupCandidate(
                fileNode: node,
                classification: classification,
                estimatedRecoverableBytes: node.effectiveSize,
                action: .queueForFutureTrash
            )
        )
        cleanupQueue = updatedQueue
    }

    func addSelectedToCleanupQueue() {
        let nodes = selectedCleanupEligibleNodes
        guard !nodes.isEmpty else {
            return
        }

        let selectedCandidates = nodes.map { node in
            CleanupCandidate(
                fileNode: node,
                classification: classification(for: node),
                estimatedRecoverableBytes: node.effectiveSize,
                action: .queueForFutureTrash
            )
        }
        let updatedQueue = CleanupTargetNormalizer.collapsingDescendants(
            cleanupQueue + selectedCandidates,
            url: { $0.fileNode.url }
        )
        let didChangeQueue = updatedQueue.count != cleanupQueue.count
            || zip(updatedQueue, cleanupQueue).contains { updated, existing in
                updated.id != existing.id
            }
        if didChangeQueue {
            cleanupQueue = updatedQueue
        }
        cleanupStatusMessage = "Queued \(nodes.count) cleanup-ready items"
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

    func forgetSavedSession() {
        cancelScan()
        stopAccessingSecurityScopedRoot()
        currentScanRootURL = nil
        rootNode = nil
        snapshot = nil
        scanStatistics = nil
        scanIntelligenceSummary = nil
        selectedNodeIDs = []
        cleanupQueue = []
        pendingRestoredCleanupPaths = []

        do {
            try sessionStore?.clear()
            cleanupStatusMessage = "Forgot the saved folder and cleanup queue"
            latestError = nil
        } catch {
            latestError = "Could not forget the saved session: \(error.localizedDescription)"
        }
    }

    func pruneSelectionToVisible() {
        let visibleIDs = Set(visibleNodes.map(\.node.id))
        let retainedSelection = selectedNodeIDs.intersection(visibleIDs)
        guard retainedSelection != selectedNodeIDs else {
            return
        }
        selectedNodeIDs = retainedSelection
    }

    func isCleanupInProgress(node: FileNode) -> Bool {
        cleanupInProgressIDs.contains(node.id)
    }

    func isQueued(node: FileNode) -> Bool {
        queuedNodeIDs.contains(node.id)
    }

    func moveToBin(node: FileNode) async {
        guard let authorizedRoot = authorizedScanRoot else {
            latestError = "Select and scan a folder before cleaning up files."
            return
        }
        await performCleanup(node: node, operationName: "Moved to Bin") { progress in
            try await FileCleanupService.moveToBin(
                node: node,
                authorizedRoot: authorizedRoot,
                progress: progress
            )
        }
    }

    func moveSelectedToBin() async {
        guard let authorizedRoot = authorizedScanRoot else {
            latestError = "Select and scan a folder before cleaning up files."
            return
        }
        await performBulkCleanup(nodes: selectedCleanupEligibleNodes, operationName: "Moved to Bin") { node, progress in
            try await FileCleanupService.moveToBin(
                node: node,
                authorizedRoot: authorizedRoot,
                progress: progress
            )
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
            sidebarFilteredNodes = allNodes.filter { queuedNodeIDs.contains($0.node.id) }
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
        storedSelectedNodeIDs.formIntersection(visibleNodes.map(\.node.id))
    }

    private func restorePersistedCleanupQueueIfNeeded() {
        guard !pendingRestoredCleanupPaths.isEmpty else {
            return
        }

        var restoredNodes: [FileNode] = []
        for item in allNodes where !Self.pathMatchKeys(for: [item.node.path]).isDisjoint(with: pendingRestoredCleanupPaths) {
            let classification = classification(for: item.node)
            guard classification.level.isQueueable else {
                continue
            }

            restoredNodes.append(item.node)
        }

        let restoredCandidates = CleanupTargetNormalizer.collapsingDescendants(restoredNodes, url: \.url).map { node in
            let classification = classification(for: node)
            return CleanupCandidate(
                fileNode: node,
                classification: classification,
                estimatedRecoverableBytes: node.effectiveSize,
                action: .queueForFutureTrash
            )
        }

        cleanupQueue = restoredCandidates
        pendingRestoredCleanupPaths.removeAll()
        if !restoredCandidates.isEmpty {
            cleanupStatusMessage = "Restored \(restoredCandidates.count) cleanup queued items"
        }
    }

    private func beginAccessingSecurityScopedRoot(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        if securityScopedRootURL == standardizedURL, isAccessingSecurityScopedRoot {
            return true
        }

        stopAccessingSecurityScopedRoot()
        let startedAccess = startSecurityScopedAccess(standardizedURL)
        let alreadyHasAccess = (try? FileManager.default.contentsOfDirectory(
            at: standardizedURL,
            includingPropertiesForKeys: nil,
            options: []
        )) != nil
        guard startedAccess || alreadyHasAccess || !requiresSecurityScopedAccess else {
            return false
        }

        securityScopedRootURL = standardizedURL
        isAccessingSecurityScopedRoot = startedAccess
        return true
    }

    private func resetStaleResultsIfRootChanged(to root: URL) {
        guard let previousRoot = rootNode?.url ?? currentScanRootURL,
              !Self.pathsReferToSameItem(previousRoot, root) else {
            return
        }

        rootNode = nil
        snapshot = nil
        scanStatistics = nil
        scanIntelligenceSummary = nil
        selectedNodeIDs = []
        cleanupQueue = []
        pendingRestoredCleanupPaths = []
        cleanupStatusMessage = nil
    }

    private func rejectUnauthorizedScan() {
        activeScanID = nil
        currentScanRootURL = nil
        isScanning = false
        scanProgress = nil
        latestError = "SpaceLens could not access that folder. Select it again to refresh permission."
    }

    private func stopAccessingSecurityScopedRoot() {
        guard isAccessingSecurityScopedRoot, let securityScopedRootURL else {
            self.securityScopedRootURL = nil
            isAccessingSecurityScopedRoot = false
            return
        }

        stopSecurityScopedAccess(securityScopedRootURL)
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
            Self.logger.error("Failed to persist SpaceLens session: \(error.localizedDescription, privacy: .private(mask: .hash))")
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

    private static func pathsReferToSameItem(_ lhs: URL, _ rhs: URL) -> Bool {
        !pathMatchKeys(for: [lhs.path]).isDisjoint(with: pathMatchKeys(for: [rhs.path]))
    }

}
