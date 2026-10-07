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
        case theoretical
        case protected
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
            case .theoretical:
                "Potential Recovery"
            case .protected:
                "Protected Items"
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
            cachedSelectedCleanupEligibleIDs = nil
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
    @Published private(set) var isAddingFiles = false
    private var addFilesTask: Task<Void, Never>?
    private var additionalNodes: [FileNode] = []
    // Authority applies to these exact chooser targets only, never to arbitrary siblings.
    private var additionalCleanupRoots: [UUID: URL] = [:]
    private(set) var displayedNodeIDs: Set<UUID>?
    var showsFileTree: Bool {
        sidebarSelection == .all && tableFilter == .all
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    func setDisplayedNodeIDs(_ ids: Set<UUID>, matching availableIDs: Set<UUID>? = nil) {
        if let availableIDs, availableIDs != Set(visibleNodes.map(\.id)) { return }
        guard displayedNodeIDs != ids else { return }
        objectWillChange.send()
        displayedNodeIDs = ids
        selectedNodeIDs.formIntersection(ids)
    }
    func showSummary(_ selection: SidebarSelection, filter: TableFilter = .all) {
        searchText = ""
        tableFilter = filter
        sidebarSelection = selection
        clearSelection()
    }

    @Published var isScanning = false
    @Published var scanMode: ScanMode = .full
    @Published var scanProgress: ScanProgress?
    @Published var scanStatistics: ScanStatistics?
    @Published var scanIntelligenceSummary: ScanIntelligenceSummary?
    @Published var volumePressure: VolumePressure?
    private var pathUseSnapshot: PathUseSnapshot = .empty
    private var didRemoveFiles = false
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
    @Published private(set) var isCleaningUp = false
    @Published private(set) var estimatedMovedToBinBytes: Int64 = 0
    @Published var cleanupStatusMessage: String?
    @Published var latestError: String?
    @Published private(set) var classificationRevision = 0
    private(set) var visibleNodes: [FlattenedFileNode] = []
    private(set) var visibleCleanupReadyCount = 0
    var selectedCleanupEligibleNodes: [FileNode] {
        if let cachedSelectedCleanupEligibleIDs, cachedSelectedCleanupEligibleIDs == storedSelectedNodeIDs {
            return cachedSelectedCleanupEligibleNodes
        }
        let eligibleNodes = storedSelectedNodeIDs.compactMap { id -> FileNode? in
            guard let node = nodeByID[id], isCleanupEligible(node) else {
                return nil
            }
            return node
        }
        let nodes = CleanupTargetNormalizer.collapsingDescendants(eligibleNodes, url: \.url)
        cachedSelectedCleanupEligibleNodes = nodes
        cachedSelectedCleanupEligibleIDs = storedSelectedNodeIDs
        return nodes
    }

    var selectedRecoverableBytes: Int64 {
        selectedCleanupEligibleNodes.reduce(Int64(0)) { $0 + $1.effectiveSize }
    }

    let ruleEngine = RuleEngine()
    let intelligenceService: IntelligenceService = LocalIntelligenceService()

    private let smartCleanupScanner: SmartCleanupScanner
    private let activitySnapshot: @Sendable () async -> PathUseSnapshot
    private var scanTask: Task<Void, Never>?
    private var activeScanID: UUID?
    private var scanStartedAt = Date()
    private var currentScanRootURL: URL?
    private var allNodes: [FlattenedFileNode] = []
    private var nodeByID: [UUID: FileNode] = [:]
    private var classificationCache: [UUID: SafetyClassification] = [:]
    private var cachedSelectedCleanupEligibleNodes: [FileNode] = []
    private var cachedSelectedCleanupEligibleIDs: Set<UUID>?
    private var lastProgressPublishAt = Date.distantPast
    private var lastCandidatePublishAt = Date.distantPast
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
        activitySnapshot: @escaping @Sendable () async -> PathUseSnapshot = { await PathUseDetector.liveSnapshot() },
        requiresSecurityScopedAccess: Bool = AppState.hasAppSandboxEntitlement(),
        startSecurityScopedAccess: @escaping @Sendable (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        stopSecurityScopedAccess: @escaping @Sendable (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    ) {
        self.sessionStore = sessionStore
        self.smartCleanupScanner = smartCleanupScanner
        self.activitySnapshot = activitySnapshot
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

    var canCleanUp: Bool { !isScanning && !isAddingFiles && snapshot != nil && !isCleaningUp }

    var emptyResultsPresentation: EmptyResultsPresentation {
        if isScanning {
            return EmptyResultsPresentation(
                title: scanProgress.flatMap { $0.phase == .discovering ? nil : $0.phase.title }
                    ?? (scanMode == .smart ? "Finding Cleanup Candidates" : "Scanning Files"),
                systemImage: "sparkle.magnifyingglass",
                description: scanMode == .smart
                    ? "Rebuildable caches appear here as each folder is sized. SpaceLens does not list every file inside them."
                    : "Files appear when the scan finishes. You can stop the scan at any time."
            )
        }

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
        case .theoretical:
            return EmptyResultsPresentation(title: "No Potential Recovery", systemImage: "arrow.triangle.2.circlepath",
                description: "No retained candidates contribute to the theoretical cleanup estimate.")
        case .protected:
            return EmptyResultsPresentation(title: "No Protected Items", systemImage: "lock.shield",
                description: "No retained items were classified as protected or active.")
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

    func chooseAdditionalFiles() {
        guard canCleanUp else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose files or folders to add to the cleanup queue"
        panel.prompt = "Inspect and Queue"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = false
        if panel.runModal() == .OK {
            let urls = panel.urls
            addFilesTask = Task { await addAdditionalFiles(urls) }
        }
    }

    func cancelAddingFiles() { addFilesTask?.cancel() }

    func addAdditionalFiles(_ urls: [URL]) async {
        guard canCleanUp, !requiresSecurityScopedAccess else {
            latestError = "Complete a scan before adding files. Additional targets require the desktop build with filesystem access."
            return
        }
        isAddingFiles = true
        defer { isAddingFiles = false; addFilesTask = nil }
        let activity = await activitySnapshot()
        guard !Task.isCancelled else { return }
        pathUseSnapshot = activity
        classificationCache.removeAll(keepingCapacity: true)
        cachedSelectedCleanupEligibleIDs = nil
        var accepted: [FileNode] = []
        var rejected: [String] = []
        let targets = CleanupTargetNormalizer.collapsingDescendants(urls.map { $0.standardizedFileURL }, url: { $0 })
        for url in targets {
            // Reject protected roots and symlinks before walking potentially huge folders.
            guard activity.activityCheckError == nil,
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true,
                  DiskScanner.excludedNamespaceReason(url) == nil else {
                rejected.append(url.path)
                continue
            }
            let preliminary = FileNode(url: url, isDirectory: values.isDirectory == true,
                logicalSize: 0, allocatedSize: 0, captureIdentity: false)
            let level = ruleEngine.classify(preliminary, pathUse: activity).level
            guard level != .systemCritical, level != .activeOrInUse else {
                rejected.append(url.path)
                continue
            }
            let worker = Task.detached(priority: .userInitiated) { await DiskScanner().scan(root: url, options: .collapsed) }
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            let node = result.root
            let classification = ruleEngine.classify(node, pathUse: activity)
            guard isCleanupEligible(node, classification: classification) else {
                rejected.append(url.path)
                continue
            }
            // Reuse a retained node when available, keeping queue and tree identity coherent.
            if let retained = allNodes.first(where: { $0.node.url.standardizedFileURL == url })?.node {
                guard retained.fileIdentity == node.fileIdentity,
                      retained.effectiveSize == node.effectiveSize,
                      retained.modifiedAt == node.modifiedAt else {
                    rejected.append(url.path + " (changed since scan; scan this folder again)")
                    continue
                }
                accepted.append(retained)
            } else { accepted.append(node) }
        }
        guard !Task.isCancelled else { return }
        for node in accepted {
            if !allNodes.contains(where: { $0.id == node.id }) {
                additionalNodes.append(node)
                additionalCleanupRoots[node.id] = node.url.deletingLastPathComponent()
            }
            nodeByID[node.id] = node
            classificationCache[node.id] = ruleEngine.classify(node, pathUse: activity)
        }
        rebuildNodeCaches()
        let candidates = accepted.map { node in
            CleanupCandidate(fileNode: node, classification: classification(for: node),
                estimatedRecoverableBytes: node.effectiveSize, action: .queueForFutureTrash)
        }
        cleanupQueue = CleanupTargetNormalizer.collapsingDescendants(cleanupQueue + candidates, url: { $0.fileNode.url })
        classificationRevision &+= 1
        showSummary(.queue)
        selectedNodeIDs = Set(accepted.map(\.id)).intersection(queuedNodeIDs)
        cleanupStatusMessage = "Added \(accepted.count) items to the review queue"
        if !rejected.isEmpty {
            latestError = "Could not queue \(rejected.count) active, protected, unreadable or unsupported items:\n" + rejected.prefix(5).joined(separator: "\n")
        }
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

        if scanMode == .smart { startSmartScan(root: root) } else { startScan(root: root) }
    }

    func smartScan() {
        guard let root = authorizedScanRoot else {
            chooseFolder(for: .smart)
            return
        }
        startSmartScan(root: root)
    }

    func startScan(root: URL) {
        guard !isAddingFiles else { return }
        guard !isCleaningUp else { return }
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
        scanStartedAt = Date()
        didRemoveFiles = false
        isScanning = true
        latestError = nil
        selectedNodeIDs = []
        snapshot = nil
        scanStatistics = nil
        scanIntelligenceSummary = nil
        volumePressure = nil
        pathUseSnapshot = .empty
        lastProgressPublishAt = .distantPast
        scanProgress = ScanProgress(currentPath: root.path, scannedCount: 0, errorCount: 0)

        let ruleEngine = ruleEngine
        let intelligenceService = intelligenceService
        let target = WeakAppState(self)

        scanTask = Task {
            let payload = await Self.runFullScan(
                root: root,
                ruleEngine: ruleEngine,
                intelligenceService: intelligenceService,
                onProgress: { progress in
                    Task { @MainActor in
                        target.value?.publishScanProgress(progress, scanID: scanID)
                    }
                }
            )
            guard let self = target.value, let payload, self.activeScanID == scanID else {
                return
            }
            self.applyFinishedScan(
                root: payload.root,
                snapshot: payload.snapshot,
                statistics: payload.statistics,
                intelligenceSummary: payload.intelligenceSummary,
                volumePressure: payload.volumePressure,
                pathUse: payload.pathUse,
                items: payload.items,
                autoQueueConservative: false,
                conservativeNodes: []
            )
        }
    }

    func startSmartScan(root: URL) {
        guard !isAddingFiles else { return }
        guard !isCleaningUp else { return }
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
        scanStartedAt = Date()
        didRemoveFiles = false
        isScanning = true
        latestError = nil
        selectedNodeIDs = []
        snapshot = nil
        scanStatistics = nil
        scanIntelligenceSummary = nil
        volumePressure = nil
        pathUseSnapshot = .empty
        lastProgressPublishAt = .distantPast
        lastCandidatePublishAt = .distantPast
        scanProgress = ScanProgress(currentPath: root.path, scannedCount: 0, errorCount: 0, phase: .findingCandidates)

        let ruleEngine = ruleEngine
        let intelligenceService = intelligenceService
        let smartCleanupScanner = smartCleanupScanner
        let target = WeakAppState(self)

        scanTask = Task {
            let payload = await Self.runSmartScan(
                root: root,
                scanner: smartCleanupScanner,
                ruleEngine: ruleEngine,
                intelligenceService: intelligenceService,
                onProgress: { progress in
                    Task { @MainActor in
                        target.value?.publishScanProgress(progress, scanID: scanID)
                    }
                },
                onCandidates: { candidates in
                    Task { @MainActor in
                        target.value?.publishLiveSmartScanCandidates(candidates, root: root, scanID: scanID)
                    }
                }
            )
            guard let self = target.value, let payload, self.activeScanID == scanID else {
                return
            }
            self.applyFinishedScan(
                root: payload.root,
                snapshot: payload.snapshot,
                statistics: payload.statistics,
                intelligenceSummary: payload.intelligenceSummary,
                volumePressure: payload.volumePressure,
                pathUse: payload.pathUse,
                items: payload.items,
                autoQueueConservative: true,
                conservativeNodes: payload.conservativeNodes
            )
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        activeScanID = nil
        isScanning = false
        scanProgress = nil
        if snapshot == nil {
            rootNode = nil
            cleanupStatusMessage = "Scan cancelled. Rescan before cleanup."
        }
        if rootNode == nil {
            stopAccessingSecurityScopedRoot()
        }
    }

    private func publishScanProgress(_ progress: ScanProgress, scanID: UUID) {
        guard isScanning, activeScanID == scanID else {
            return
        }
        // Progress callbacks hop to the main actor asynchronously. Ignore an older
        // phase if its callback arrives after classification or summary preparation.
        if let current = scanProgress, progress.phase.rawValue < current.phase.rawValue { return }
        let now = Date()
        guard scanProgress?.phase != progress.phase || now.timeIntervalSince(lastProgressPublishAt) >= 0.1 else {
            return
        }
        lastProgressPublishAt = now
        scanProgress = progress
    }

    private func publishLiveSmartScanCandidates(_ candidates: [FileNode], root: URL, scanID: UUID) {
        guard isScanning, activeScanID == scanID else {
            return
        }
        let now = Date()
        let isFirstPaint = storedRootNode == nil
        guard isFirstPaint || now.timeIntervalSince(lastCandidatePublishAt) >= 0.1 else {
            return
        }
        lastCandidatePublishAt = now
        let logicalSize = candidates.reduce(Int64(0)) { $0 + $1.logicalSize }
        let allocatedSize = candidates.reduce(Int64(0)) { $0 + $1.allocatedSize }
        rootNode = FileNode(
            url: root,
            name: "Smart Scan",
            path: root.path,
            isDirectory: true,
            logicalSize: logicalSize,
            allocatedSize: allocatedSize,
            children: candidates,
            captureIdentity: false
        )
    }

    private struct FinishedScanPayload: Sendable {
        let root: FileNode
        let snapshot: ScanSnapshot
        let statistics: ScanStatistics
        let intelligenceSummary: ScanIntelligenceSummary
        let volumePressure: VolumePressure?
        let pathUse: PathUseSnapshot
        let items: [ClassifiedScanItem]
        let conservativeNodes: [FileNode]
    }

    private nonisolated static func runFullScan(
        root: URL,
        ruleEngine: RuleEngine,
        intelligenceService: IntelligenceService,
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> FinishedScanPayload? {
        let result = await DiskScanner().scan(root: root, progress: onProgress)
        guard !Task.isCancelled else {
            return nil
        }

        onProgress(ScanProgress(snapshot: result.snapshot, phase: .checkingActivity))
        let volumePressure = VolumePressureReader.read(for: root)
        let pathUse = await PathUseDetector.liveSnapshot()
        guard !Task.isCancelled else { return nil }
        guard let items = await ScanClassifier.classify(
            nodes: Array(result.root.flattened().dropFirst()), snapshot: result.snapshot,
            ruleEngine: ruleEngine, pathUse: pathUse, onProgress: onProgress
        ) else { return nil }
        onProgress(ScanProgress(snapshot: result.snapshot, phase: .summarizing))
        let statistics = ScanStatistics(snapshot: result.snapshot, items: items)
        let intelligenceSummary = await intelligenceService.summarizeScan(
            snapshot: result.snapshot,
            items: items,
            context: ScanSummaryContext(volumePressure: volumePressure, pathUse: pathUse)
        )
        guard !Task.isCancelled else { return nil }
        return FinishedScanPayload(
            root: result.root,
            snapshot: result.snapshot,
            statistics: statistics,
            intelligenceSummary: intelligenceSummary,
            volumePressure: volumePressure,
            pathUse: pathUse,
            items: items,
            conservativeNodes: []
        )
    }

    private nonisolated static func runSmartScan(
        root: URL,
        scanner: SmartCleanupScanner,
        ruleEngine: RuleEngine,
        intelligenceService: IntelligenceService,
        onProgress: @escaping @Sendable (ScanProgress) -> Void,
        onCandidates: @escaping @Sendable ([FileNode]) -> Void
    ) async -> FinishedScanPayload? {
        let result = await scanner.scan(root: root, progress: onProgress, onCandidates: onCandidates)
        guard !Task.isCancelled else {
            return nil
        }

        onProgress(ScanProgress(snapshot: result.snapshot, phase: .checkingActivity))
        let volumePressure = VolumePressureReader.read(for: root)
        let rawPathUse = await PathUseDetector.liveSnapshot(simulatorInventory: result.simulatorInventory)
        guard !Task.isCancelled else { return nil }
        let flattened = Array(result.root.flattened().dropFirst())
        let pathUse = rawPathUse.withOpenPaths(
            PathUseDetector.matchingOpenPaths(
                candidatePaths: flattened.map(\.node.path),
                openPaths: rawPathUse.openPaths
            )
        )
        guard !Task.isCancelled else { return nil }
        guard let items = await ScanClassifier.classify(
            nodes: flattened, snapshot: result.snapshot,
            ruleEngine: ruleEngine, pathUse: pathUse, onProgress: onProgress
        ) else { return nil }
        onProgress(ScanProgress(snapshot: result.snapshot, phase: .summarizing))
        let statistics = ScanStatistics(snapshot: result.snapshot, items: items)
        let intelligenceSummary = await intelligenceService.summarizeScan(
            snapshot: result.snapshot,
            items: items,
            context: ScanSummaryContext(
                volumePressure: volumePressure,
                pathUse: pathUse,
                pendingDiscoveryPaths: result.pendingDiscoveryPaths
            )
        )
        let conservativeNodes = CleanupTargetNormalizer.collapsingDescendants(
            items.filter { $0.classification.level.isQueueable }.map(\.node),
            url: \.url
        )
        guard !Task.isCancelled else { return nil }
        return FinishedScanPayload(
            root: result.root,
            snapshot: result.snapshot,
            statistics: statistics,
            intelligenceSummary: intelligenceSummary,
            volumePressure: volumePressure,
            pathUse: pathUse,
            items: items,
            conservativeNodes: conservativeNodes
        )
    }

    private func applyFinishedScan(
        root: FileNode,
        snapshot: ScanSnapshot,
        statistics: ScanStatistics,
        intelligenceSummary: ScanIntelligenceSummary,
        volumePressure: VolumePressure?,
        pathUse: PathUseSnapshot,
        items: [ClassifiedScanItem],
        autoQueueConservative: Bool,
        conservativeNodes: [FileNode]
    ) {
        Self.logger.info("\(self.scanMode.rawValue, privacy: .public) scan completed: \(snapshot.nodeCount) items, \(Date().timeIntervalSince(self.scanStartedAt)) seconds, \(snapshot.errorCount) read errors")
        objectWillChange.send()
        pathUseSnapshot = pathUse
        self.volumePressure = volumePressure
        storedRootNode = root
        self.snapshot = snapshot
        isScanning = false
        activeScanID = nil
        scanProgress = nil
        scanStatistics = statistics
        scanIntelligenceSummary = intelligenceSummary
        classificationCache = Dictionary(uniqueKeysWithValues: items.map { ($0.node.id, $0.classification) })
        cachedSelectedCleanupEligibleIDs = nil
        let scannedPaths = Set(items.map { $0.node.url.standardizedFileURL.path })
        additionalNodes.removeAll { node in
            guard scannedPaths.contains(node.url.standardizedFileURL.path) else { return false }
            additionalCleanupRoots.removeValue(forKey: node.id)
            return true
        }
        rebuildNodeCachesKeepingClassification()

        let currentItems = Dictionary(uniqueKeysWithValues: items.map { ($0.node.path, $0) })
        storedCleanupQueue = storedCleanupQueue.compactMap { candidate in
            guard FileManager.default.fileExists(atPath: candidate.fileNode.path) else { return nil }
            guard let item = currentItems[candidate.fileNode.path] else {
                if additionalCleanupRoots[candidate.fileNode.id] != nil,
                   isCleanupEligible(candidate.fileNode) { return candidate }
                return nil
            }
            guard isCleanupEligible(item.node, classification: item.classification) else { return nil }
            return CleanupCandidate(id: candidate.id, fileNode: item.node, classification: item.classification,
                estimatedRecoverableBytes: item.node.effectiveSize, action: candidate.action)
        }
        queuedNodeIDs = Set(storedCleanupQueue.lazy.map(\.fileNode.id))
        restorePersistedCleanupQueueIfNeeded()
        if autoQueueConservative {
            replaceCleanupQueueWithConservativeCandidates(conservativeNodes)
        } else if storedSelectedNodeIDs.isEmpty {
            storedSelectedNodeIDs = root.children.first.map { Set([$0.id]) } ?? []
        }
        rebuildVisibleNodes()
        for candidate in storedCleanupQueue { nodeByID[candidate.fileNode.id] = candidate.fileNode }
        persistSession()
    }

    func classification(for node: FileNode) -> SafetyClassification {
        if let cached = classificationCache[node.id] {
            return cached
        }

        let classification = ruleEngine.classify(node, pathUse: pathUseSnapshot)
        classificationCache[node.id] = classification
        return classification
    }

    func isCleanupEligible(_ node: FileNode, classification: SafetyClassification? = nil) -> Bool {
        let classification = classification ?? self.classification(for: node)
        return classification.level.isQueueable || FileCleanupService.isManuallyReviewable(
            node, classification: classification, pathUse: pathUseSnapshot)
    }

    var selectedManualReviewCount: Int {
        selectedCleanupEligibleNodes.filter { !classification(for: $0).level.isQueueable }.count
    }

    private func replaceCleanupQueueWithConservativeCandidates(_ roots: [FileNode]) {
        let candidates = roots.map { node in
            CleanupCandidate(
                fileNode: node,
                classification: classification(for: node),
                estimatedRecoverableBytes: node.effectiveSize,
                action: .queueForFutureTrash
            )
        }

        if !candidates.isEmpty {
            let previousCount = storedCleanupQueue.count
            storedCleanupQueue = CleanupTargetNormalizer.collapsingDescendants(storedCleanupQueue + candidates, url: { $0.fileNode.url })
            queuedNodeIDs = Set(storedCleanupQueue.lazy.map(\.fileNode.id))
            if storedCleanupQueue.count > previousCount {
                cleanupStatusMessage = "Queued \(storedCleanupQueue.count) conservative cleanup-ready items"
            }
        }

        guard !storedCleanupQueue.isEmpty else {
            storedSidebarSelection = .safe
            storedSelectedNodeIDs = []
            cachedSelectedCleanupEligibleIDs = nil
            return
        }

        storedSidebarSelection = .queue
        storedSelectedNodeIDs = Set(storedCleanupQueue.map(\.fileNode.id))
        cachedSelectedCleanupEligibleIDs = nil
    }

    func addToCleanupQueue(node: FileNode) {
        let classification = ruleEngine.classify(node, pathUse: pathUseSnapshot)
        guard isCleanupEligible(node, classification: classification) else {
            latestError = "This item is active, protected, or could not be inspected completely. Resolve the issue and rescan before queueing."
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
        for candidate in updatedQueue { nodeByID[candidate.fileNode.id] = candidate.fileNode }
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
        cleanupStatusMessage = "Queued \(nodes.count) items for review"
    }

    func selectAllVisible() {
        selectedNodeIDs = displayedNodeIDs ?? Set(visibleNodes.map(\.node.id))
    }

    func selectCleanupReadyVisible() {
        selectedNodeIDs = Set(visibleNodes.filter { classification(for: $0.node).level.isQueueable }.map(\.node.id)).intersection(displayedNodeIDs ?? Set(visibleNodes.map(\.node.id)))
    }

    func clearSelection() {
        selectedNodeIDs = []
    }

    func forgetSavedSession() {
        guard !isCleaningUp else { return }
        cancelAddingFiles()
        additionalNodes.removeAll()
        additionalCleanupRoots.removeAll()
        cancelScan()
        stopAccessingSecurityScopedRoot()
        currentScanRootURL = nil
        rootNode = nil
        snapshot = nil
        scanStatistics = nil
        scanIntelligenceSummary = nil
        volumePressure = nil
        pathUseSnapshot = .empty
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
        await moveToBin(nodes: [node])
    }

    func moveSelectedToBin() async {
        await moveToBin(nodes: selectedCleanupEligibleNodes)
    }

    func moveToBin(nodes: [FileNode], reviewedByUser: Bool = false) async {
        guard canCleanUp, let authorizedRoot = authorizedScanRoot, !nodes.isEmpty else {
            latestError = "Complete a scan and select cleanup-ready items before cleaning up files."
            return
        }
        isCleaningUp = true
        defer { isCleaningUp = false; persistSession() }
        cleanupProgress = CleanupProgress(phase: .preparing, currentPath: authorizedRoot.path, completedItemCount: 0,
            totalItemCount: nodes.count, completedBytes: 0, totalBytes: nodes.reduce(0) { $0 + $1.effectiveSize })
        // The service checks fresh activity after every manual target and before
        // directory inspection. Reviewed files avoid a duplicate batch-wide probe.
        if !reviewedByUser { pathUseSnapshot = await activitySnapshot() }
        classificationCache.removeAll(keepingCapacity: true)
        classificationRevision &+= 1
        cachedSelectedCleanupEligibleIDs = nil
        cleanupQueue = cleanupQueue.compactMap { candidate in
            let classification = ruleEngine.classify(candidate.fileNode, pathUse: pathUseSnapshot)
            guard isCleanupEligible(candidate.fileNode, classification: classification) else { return nil }
            return CleanupCandidate(id: candidate.id, fileNode: candidate.fileNode, classification: classification,
                estimatedRecoverableBytes: candidate.estimatedRecoverableBytes, action: candidate.action)
        }
        rebuildVisibleNodes()
        let invalid = pathUseSnapshot.activityCheckError != nil || nodes.contains {
            let classification = ruleEngine.classify($0, pathUse: pathUseSnapshot)
            return !classification.level.isQueueable && !(reviewedByUser && isCleanupEligible($0, classification: classification))
        }
        guard !invalid else {
            cleanupProgress = nil
            latestError = "Cleanup stopped: an item is active, unverified, or no longer cleanup-ready. Close its tools and rescan."
            await refreshSummaryAfterCleanup()
            return
        }
        let freshActivity = pathUseSnapshot
        let activityRefresh = CleanupActivityRefresh(initial: freshActivity, provider: activitySnapshot)
        let additionalRoots = additionalCleanupRoots
        await performBulkCleanup(nodes: nodes, operationName: "Moved to Bin", reviewedByUser: reviewedByUser) { node, progress in
            try await FileCleanupService.moveToBin(
                node: node,
                authorizedRoot: additionalRoots[node.id] ?? authorizedRoot,
                reviewedByUser: reviewedByUser,
                pathUse: freshActivity,
                activitySnapshot: { await activityRefresh.snapshot(forceRefresh: reviewedByUser) },
                progress: progress
            )
        }
        cleanupProgress = nil
        await refreshSummaryAfterCleanup()
    }

    private func refreshSummaryAfterCleanup() async {
        guard let snapshot else { return }
        let items = allNodes.filter { additionalCleanupRoots[$0.id] == nil }.map { ClassifiedScanItem(node: $0.node, classification: classification(for: $0.node)) }
        scanStatistics = ScanStatistics(snapshot: snapshot, items: items)
        scanIntelligenceSummary = await intelligenceService.summarizeScan(snapshot: snapshot, items: items,
            context: ScanSummaryContext(volumePressure: volumePressure, pathUse: pathUseSnapshot, didRemoveFiles: didRemoveFiles))
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
        reviewedByUser: Bool,
        operation: @escaping @Sendable (FileCleanupService.ProgressHandler?) async throws -> Void
    ) async {
        let classification = ruleEngine.classify(node, pathUse: pathUseSnapshot)
        guard classification.level.isQueueable || (reviewedByUser && isCleanupEligible(node, classification: classification)) else {
            latestError = "Cleanup is disabled for this item because it is not classified as a safe, rebuildable, or generated candidate."
            return
        }

        guard FileManager.default.fileExists(atPath: node.path) else {
            latestError = "The selected item no longer exists on disk. Rescan this folder."
            additionalNodes.removeAll { $0.id == node.id }
            additionalCleanupRoots.removeValue(forKey: node.id)
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
            didRemoveFiles = true
            estimatedMovedToBinBytes += node.effectiveSize
            cleanupInProgressIDs.remove(node.id)
            cleanupStatusMessage = "\(operationName): \(node.displayName)"
            cleanupProgress = nil
            additionalNodes.removeAll { $0.id == node.id }
            additionalCleanupRoots.removeValue(forKey: node.id)
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
        reviewedByUser: Bool,
        operation: @escaping @Sendable (FileNode, FileCleanupService.ProgressHandler?) async throws -> Void
    ) async {
        guard !nodes.isEmpty else {
            latestError = "Select one or more cleanup-ready items first."
            return
        }

        var cleanedCount = 0
        var cleanedBytes: Int64 = 0
        var failures: [String] = []

        for node in nodes {
            await performCleanup(node: node, operationName: operationName, reviewedByUser: reviewedByUser) {
                try await operation(node, $0)
            }
            if let latestError {
                failures.append(latestError)
            } else {
                cleanedCount += 1
                cleanedBytes += node.effectiveSize
            }
        }
        if !failures.isEmpty {
            latestError = failures.prefix(5).joined(separator: "\n")
                + (failures.count > 5 ? "\n\(failures.count - 5) more items could not be moved." : "")
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
        allNodes = (rootNode.map { Array($0.flattened().dropFirst()) } ?? []) + additionalNodes.map { FlattenedFileNode(node: $0, depth: 1) }
        nodeByID = [:]
        if let rootNode {
            nodeByID[rootNode.id] = rootNode
        }
        for item in allNodes {
            nodeByID[item.node.id] = item.node
        }
        for candidate in storedCleanupQueue { nodeByID[candidate.fileNode.id] = candidate.fileNode }
        classificationCache.removeAll(keepingCapacity: true)
        cachedSelectedCleanupEligibleIDs = nil
        rebuildVisibleNodes()
    }

    private func rebuildNodeCachesKeepingClassification() {
        allNodes = (storedRootNode.map { Array($0.flattened().dropFirst()) } ?? []) + additionalNodes.map { FlattenedFileNode(node: $0, depth: 1) }
        nodeByID = [:]
        if let storedRootNode {
            nodeByID[storedRootNode.id] = storedRootNode
        }
        for item in allNodes {
            nodeByID[item.node.id] = item.node
        }
        cachedSelectedCleanupEligibleIDs = nil
    }

    private func rebuildVisibleNodes() {
        let previousIDs = Set(visibleNodes.map(\.id))
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
            sidebarFilteredNodes = CleanupTargetNormalizer.collapsingDescendants(allNodes.filter { classification(for: $0.node).level.isQueueable && additionalCleanupRoots[$0.id] == nil }, url: { $0.node.url })
        case .theoretical:
            sidebarFilteredNodes = CleanupTargetNormalizer.collapsingDescendants(
                allNodes.filter { additionalCleanupRoots[$0.id] == nil && CleanupRecoveryPolicy.countsTowardTheoreticalRecovery(node: $0.node, classification: classification(for: $0.node)) }, url: { $0.node.url })
        case .protected:
            sidebarFilteredNodes = allNodes.filter { [.systemCritical, .activeOrInUse].contains(classification(for: $0.node).level) }
        case .review:
            sidebarFilteredNodes = allNodes.filter { classification(for: $0.node).level == .unknownReview }
        case .valuable:
            sidebarFilteredNodes = allNodes.filter { classification(for: $0.node).level == .largeButValuable }
        case .active:
            sidebarFilteredNodes = allNodes.filter { classification(for: $0.node).level == .activeOrInUse }
        case .errors:
            let errors = allNodes.filter { $0.node.scanError != nil }
            if errors.isEmpty, let rootNode, rootNode.scanError != nil {
                sidebarFilteredNodes = [FlattenedFileNode(node: rootNode, depth: 0)]
            } else {
                sidebarFilteredNodes = errors
            }
        case .queue:
            sidebarFilteredNodes = cleanupQueue.map { FlattenedFileNode(node: $0.fileNode, depth: 1) }
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
        if Set(visibleNodes.map(\.id)) != previousIDs { displayedNodeIDs = nil }
        let retainedSelection = storedSelectedNodeIDs.intersection(Set(visibleNodes.lazy.map(\.node.id)))
        if retainedSelection != storedSelectedNodeIDs {
            storedSelectedNodeIDs = retainedSelection
            cachedSelectedCleanupEligibleIDs = nil
        }
    }

    private func restorePersistedCleanupQueueIfNeeded() {
        guard !pendingRestoredCleanupPaths.isEmpty else {
            return
        }

        var restoredNodes: [FileNode] = []
        for item in allNodes where !Self.pathMatchKeys(for: [item.node.path]).isDisjoint(with: pendingRestoredCleanupPaths) {
            let classification = classification(for: item.node)
            guard isCleanupEligible(item.node, classification: classification) else {
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
        let alreadyHasAccess = (try? standardizedURL.checkResourceIsReachable()) == true
            || FileManager.default.isReadableFile(atPath: standardizedURL.path)
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

        additionalNodes.removeAll()
        additionalCleanupRoots.removeAll()
        rootNode = nil
        snapshot = nil
        scanStatistics = nil
        scanIntelligenceSummary = nil
        volumePressure = nil
        pathUseSnapshot = .empty
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
        // A batch may remove many queued items. Save the final queue once instead of
        // rewriting its bookmark and JSON after every item; stale saved paths restore
        // only after a new scan and never carry approval.
        guard !isCleaningUp else { return }
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

private final class WeakAppState: @unchecked Sendable {
    weak var value: AppState?

    init(_ value: AppState) {
        self.value = value
    }
}
