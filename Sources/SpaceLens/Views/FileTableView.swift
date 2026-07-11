import SwiftUI

struct FileTableView: View {
    @EnvironmentObject private var appState: AppState
    @State private var sortOrder = [
        KeyPathComparator(\FlattenedFileNode.sortSize, order: .reverse)
    ]
    @State private var sortedVisibleNodes: [FlattenedFileNode] = []
    @State private var binSelectionConfirmation = false

    var body: some View {
        GeometryReader { geometry in
            let layout = FileTableLayout(width: geometry.size.width)

            VStack(spacing: 0) {
                if !appState.isScanning {
                    HeaderView(layout: layout)
                }
                ScanTelemetryPanel(layout: layout)

                if appState.rootNode == nil && !appState.isScanning {
                    EmptyScanView()
                } else {
                    TableControlBar(visibleCount: sortedVisibleNodes.count, layout: layout)

                    responsiveTable(layout: layout)

                    BulkActionBar(
                        layout: layout,
                        moveToBinConfirmation: $binSelectionConfirmation
                    )
                }
            }
        }
        .confirmationDialog(
            "Move selected cleanup-ready items to the Bin?",
            isPresented: $binSelectionConfirmation
        ) {
            Button("Move \(appState.selectedCleanupEligibleNodes.count) Items to Bin", role: .destructive) {
                Task {
                    await appState.moveSelectedToBin()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(moveToBinConfirmationMessage)
        }
    }

    private var moveToBinConfirmationMessage: String {
        let paths = appState.selectedCleanupEligibleNodes
            .map(\.path)
            .joined(separator: "\n")
        return "\(ByteFormat.string(appState.selectedRecoverableBytes)) will be moved to the Bin. Review every target:\n\n\(paths)"
    }

    private var visibleSelectionFingerprint: [UUID] {
        appState.visibleNodes.map(\.node.id)
    }

    @ViewBuilder
    private func responsiveTable(layout: FileTableLayout) -> some View {
        Group {
            if layout.showsRecommendationColumn {
                fullTable(layout: layout)
            } else if layout.showsModifiedColumn {
                detailedTable(layout: layout)
            } else if layout.showsKindColumn {
                middleTable(layout: layout)
            } else {
                compactTable(layout: layout)
            }
        }
        .onAppear {
            refreshSortedVisibleNodes()
        }
        .onChange(of: visibleSelectionFingerprint) {
            appState.pruneSelectionToVisible()
            refreshSortedVisibleNodes()
        }
        .onChange(of: sortOrder) {
            refreshSortedVisibleNodes()
        }
    }

    private func compactTable(layout: FileTableLayout) -> some View {
        Table(sortedVisibleNodes, selection: $appState.selectedNodeIDs, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.sortName) { item in
                nameCell(item, layout: layout)
            }
            .width(min: layout.nameColumnMinimum, ideal: layout.nameColumnIdeal)

            TableColumn("Size", value: \.sortSize) { item in
                sizeCell(item)
            }
            .width(layout.sizeColumnWidth)
        }
    }

    private func middleTable(layout: FileTableLayout) -> some View {
        Table(sortedVisibleNodes, selection: $appState.selectedNodeIDs, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.sortName) { item in
                nameCell(item, layout: layout)
            }
            .width(min: layout.nameColumnMinimum, ideal: layout.nameColumnIdeal)

            TableColumn("Size", value: \.sortSize) { item in
                sizeCell(item)
            }
            .width(layout.sizeColumnWidth)

            TableColumn("Kind", value: \.sortKind) { item in
                Text(item.sortKind)
                    .lineLimit(1)
            }
            .width(78)

            TableColumn("Safety") { item in
                safetyCell(item)
            }
            .width(layout.safetyColumnWidth)
        }
    }

    private func detailedTable(layout: FileTableLayout) -> some View {
        Table(sortedVisibleNodes, selection: $appState.selectedNodeIDs, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.sortName) { item in
                nameCell(item, layout: layout)
            }
            .width(min: layout.nameColumnMinimum, ideal: layout.nameColumnIdeal)

            TableColumn("Size", value: \.sortSize) { item in
                sizeCell(item)
            }
            .width(layout.sizeColumnWidth)

            TableColumn("Kind", value: \.sortKind) { item in
                Text(item.sortKind)
                    .lineLimit(1)
            }
            .width(78)

            TableColumn("Modified", value: \.sortModifiedAt) { item in
                modifiedCell(item)
            }
            .width(layout.modifiedColumnWidth)

            TableColumn("Safety") { item in
                safetyCell(item)
            }
            .width(layout.safetyColumnWidth)
        }
    }

    private func fullTable(layout: FileTableLayout) -> some View {
        Table(sortedVisibleNodes, selection: $appState.selectedNodeIDs, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.sortName) { item in
                nameCell(item, layout: layout)
            }
            .width(min: layout.nameColumnMinimum, ideal: layout.nameColumnIdeal)

            TableColumn("Size", value: \.sortSize) { item in
                sizeCell(item)
            }
            .width(layout.sizeColumnWidth)

            TableColumn("Kind", value: \.sortKind) { item in
                Text(item.sortKind)
                    .lineLimit(1)
            }
            .width(78)

            TableColumn("Modified", value: \.sortModifiedAt) { item in
                modifiedCell(item)
            }
            .width(layout.modifiedColumnWidth)

            TableColumn("Safety") { item in
                safetyCell(item)
            }
            .width(layout.safetyColumnWidth)

            TableColumn("Recommendation") { item in
                Text(appState.classification(for: item.node).recommendedAction)
                    .lineLimit(1)
            }
            .width(min: 180, ideal: 260)
        }
    }

    private func refreshSortedVisibleNodes() {
        sortedVisibleNodes = appState.visibleNodes.sorted(using: sortOrder)
    }

    private func nameCell(_ item: FlattenedFileNode, layout: FileTableLayout) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.node.isDirectory ? "folder" : "doc")
                .foregroundStyle(item.node.isDirectory ? .blue : .secondary)
            Text(layout.isCompact ? item.node.displayName : indentedName(item))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func sizeCell(_ item: FlattenedFileNode) -> some View {
        Text(ByteFormat.string(item.node.effectiveSize))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    @ViewBuilder
    private func modifiedCell(_ item: FlattenedFileNode) -> some View {
        if let modifiedAt = item.node.modifiedAt {
            Text(modifiedAt.formatted(date: .abbreviated, time: .shortened))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        } else {
            Text("-")
                .foregroundStyle(.secondary)
        }
    }

    private func safetyCell(_ item: FlattenedFileNode) -> some View {
        let classification = appState.classification(for: item.node)

        return Label(classification.level.displayName, systemImage: "circle.fill")
            .foregroundStyle(classification.level.color)
            .lineLimit(1)
    }

    private func indentedName(_ item: FlattenedFileNode) -> String {
        String(repeating: "  ", count: max(item.depth - 1, 0)) + item.node.displayName
    }
}

private struct FileTableLayout {
    let width: CGFloat

    var isVeryNarrow: Bool {
        width < 440
    }

    var isCompact: Bool {
        width < 620
    }

    var isTight: Bool {
        width < 840
    }

    var showsKindColumn: Bool {
        width >= 500
    }

    var showsModifiedColumn: Bool {
        width >= 700
    }

    var showsSafetyColumn: Bool {
        width >= 620
    }

    var showsRecommendationColumn: Bool {
        width >= 980
    }

    var nameColumnMinimum: CGFloat {
        isCompact ? 145 : 220
    }

    var nameColumnIdeal: CGFloat {
        isCompact ? 190 : 360
    }

    var sizeColumnWidth: CGFloat {
        isCompact ? 82 : 92
    }

    var modifiedColumnWidth: CGFloat {
        isTight ? 128 : 150
    }

    var safetyColumnWidth: CGFloat {
        isTight ? 138 : 170
    }

    var statTileMinimum: CGFloat {
        isCompact ? 104 : 126
    }
}

private struct TableControlBar: View {
    @EnvironmentObject private var appState: AppState
    let visibleCount: Int
    let layout: FileTableLayout

    var body: some View {
        Group {
            if layout.isTight {
                VStack(alignment: .leading, spacing: 8) {
                    searchField

                    HStack(spacing: 8) {
                        filterPicker
                        Spacer(minLength: 8)
                        Text("\(visibleCount) visible")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        selectionButtons
                    }
                }
            } else {
                HStack(spacing: 12) {
                    searchField
                        .frame(minWidth: 220, maxWidth: layout.isTight ? 260 : 360)

                    filterPicker

                    Spacer(minLength: 8)

                    Text("\(visibleCount) visible")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    selectionButtons
                }
            }
        }
        .controlSize(.small)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter by name, path, or category", text: $appState.searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var filterPicker: some View {
        Group {
            if layout.isVeryNarrow {
                Picker("Filter", selection: $appState.tableFilter) {
                    ForEach(AppState.TableFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Picker("Filter", selection: $appState.tableFilter) {
                    ForEach(AppState.TableFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .frame(maxWidth: layout.isCompact ? .infinity : 420)
    }

    private var selectionButtons: some View {
        HStack(spacing: 8) {
            Button {
                appState.selectAllVisible()
            } label: {
                AdaptiveActionLabel("Select All", systemImage: "checklist.checked", isCompact: layout.isCompact)
            }
            .accessibilityLabel("Select all visible items")
            .disabled(visibleCount == 0)

            Button {
                appState.selectCleanupReadyVisible()
            } label: {
                AdaptiveActionLabel("Safe", systemImage: "checkmark.shield", isCompact: layout.isCompact)
            }
            .accessibilityLabel("Select cleanup-ready visible items")
            .help("Select visible cleanup-ready items")
            .disabled(appState.visibleCleanupReadyCount == 0)

            Button {
                appState.clearSelection()
            } label: {
                AdaptiveActionLabel("Clear", systemImage: "xmark.circle", isCompact: layout.isCompact)
            }
            .accessibilityLabel("Clear selection")
            .disabled(appState.selectedNodeIDs.isEmpty)
        }
    }
}

private struct BulkActionBar: View {
    @EnvironmentObject private var appState: AppState
    let layout: FileTableLayout
    @Binding var moveToBinConfirmation: Bool

    var body: some View {
        let selectedCount = appState.selectedNodeIDs.count
        let cleanupReadyCount = appState.selectedCleanupEligibleNodes.count
        let hasCleanupReadySelection = cleanupReadyCount > 0

        Group {
            if layout.isTight {
                VStack(alignment: .leading, spacing: 10) {
                    selectionSummary(selectedCount: selectedCount, cleanupReadyCount: cleanupReadyCount)

                    ScrollView(.horizontal, showsIndicators: false) {
                        actionButtons(hasCleanupReadySelection: hasCleanupReadySelection)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    selectionSummary(selectedCount: selectedCount, cleanupReadyCount: cleanupReadyCount)

                    Spacer(minLength: 10)

                    actionButtons(hasCleanupReadySelection: hasCleanupReadySelection)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
        .opacity(selectedCount == 0 ? 0.74 : 1)
        .animation(.easeInOut(duration: 0.18), value: selectedCount)
    }

    private func selectionSummary(selectedCount: Int, cleanupReadyCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let cleanupProgress = appState.cleanupProgress {
                cleanupProgressSummary(cleanupProgress)
            } else {
                Text("\(selectedCount) selected")
                    .font(.headline.monospacedDigit())
                Text("\(cleanupReadyCount) cleanup-ready, \(ByteFormat.string(appState.selectedRecoverableBytes)) recoverable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }

    private func cleanupProgressSummary(_ progress: CleanupProgress) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("\(progress.phase.displayName) \(progress.completedItemCount) of \(max(progress.totalItemCount, 1))")
                    .font(.headline.monospacedDigit())
            }

            ProgressView(value: progress.fractionCompleted, total: 1)
                .frame(width: 260)

            Text("\(URL(fileURLWithPath: progress.currentPath).lastPathComponent.ifEmpty(progress.currentPath)) · \(ByteFormat.string(progress.completedBytes)) of \(ByteFormat.string(progress.totalBytes))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cleanup progress \(progress.completedItemCount) of \(progress.totalItemCount)")
    }

    private func actionButtons(hasCleanupReadySelection: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                appState.addSelectedToCleanupQueue()
            } label: {
                AdaptiveActionLabel("Queue", systemImage: "tray.and.arrow.down", isCompact: false)
            }
            .accessibilityLabel("Queue selected cleanup-ready items")
            .buttonStyle(AnimatedBulkButtonStyle(color: .blue, isProminent: false))
            .disabled(!hasCleanupReadySelection || appState.cleanupProgress != nil)

            Button {
                moveToBinConfirmation = true
            } label: {
                AdaptiveActionLabel("Move to Bin", systemImage: "trash", isCompact: layout.isCompact)
            }
            .accessibilityLabel("Move selected cleanup-ready items to the Bin")
            .buttonStyle(AnimatedBulkButtonStyle(color: .green, isProminent: true))
            .disabled(!hasCleanupReadySelection || appState.cleanupProgress != nil)

        }
    }
}

private struct AdaptiveActionLabel: View {
    let title: String
    let systemImage: String
    let isCompact: Bool

    init(_ title: String, systemImage: String, isCompact: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.isCompact = isCompact
    }

    var body: some View {
        if isCompact {
            Image(systemName: systemImage)
                .help(title)
                .accessibilityLabel(title)
        } else {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
    }
}

private struct AnimatedBulkButtonStyle: ButtonStyle {
    let color: Color
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isProminent ? .white : color)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isProminent ? color.gradient : Color.clear.gradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(color.opacity(isProminent ? 0 : 0.55), lineWidth: 1)
                    }
            }
            .shadow(color: color.opacity(configuration.isPressed && isProminent ? 0.24 : 0), radius: 10, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var appState: AppState
    let layout: FileTableLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if layout.isCompact {
                VStack(alignment: .leading, spacing: 6) {
                    titleBlock

                    if appState.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } else {
                HStack {
                    titleBlock

                    Spacer()

                    if appState.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            if let latestError = appState.latestError {
                Text(latestError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.bar)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appState.isScanning ? appState.scanMode.headerTitle : "Disk intelligence")
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(layout.isCompact ? 2 : 1)
                .truncationMode(.middle)
        }
    }

    private var subtitle: String {
        if let progress = appState.scanProgress {
            return "\(progress.scannedCount) items, \(ByteFormat.string(progress.discoveredBytes)) found"
        }

        if let snapshot = appState.snapshot {
            return "\(ByteFormat.string(snapshot.totalAllocatedSize)) scanned across \(snapshot.nodeCount) items"
        }

        return "Select a folder to map disk usage and review cleanup candidates."
    }
}

private struct ScanTelemetryPanel: View {
    @EnvironmentObject private var appState: AppState
    let layout: FileTableLayout

    var body: some View {
        if appState.isScanning || appState.scanStatistics != nil || appState.scanIntelligenceSummary != nil {
            Group {
                if #available(macOS 26.0, *) {
                    GlassEffectContainer(spacing: 12) {
                        content
                    }
                } else {
                    content
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .background(.bar)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if layout.isCompact {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            statusLabel
                            stopScanButton
                        }

                        Text(statusDetail)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        statusLabel
                        stopScanButton

                        Spacer()

                        Text(statusDetail)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                if let progress = appState.scanProgress, appState.isScanning {
                    DocumentScanMotionView(scannedCount: progress.scannedCount)
                }

                AnimatedScanBar(isActive: appState.isScanning)

                if let progress = appState.scanProgress {
                    Text(progress.currentPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.statTileMinimum), spacing: 10)], spacing: 10) {
                ForEach(statTiles) { tile in
                    StatTileView(tile: tile)
                }
            }

            if let summary = appState.scanIntelligenceSummary {
                IntelligenceStrip(summary: summary, isCompact: layout.isCompact)
            }
        }
        .padding(14)
        .spaceLensGlassSurface(cornerRadius: 18)
    }

    private var statusLabel: some View {
        Label(statusTitle, systemImage: appState.isScanning ? "sparkle.magnifyingglass" : "checkmark.seal")
            .font(.headline)
            .foregroundStyle(appState.isScanning ? .cyan : .green)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    @ViewBuilder
    private var stopScanButton: some View {
        if appState.isScanning {
            Button {
                appState.cancelScan()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(.red.gradient, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Stop scan")
            .accessibilityLabel("Stop scan")
        }
    }

    private var statusTitle: String {
        if appState.isScanning {
            return appState.scanMode.inProgressTitle
        }

        if let summary = appState.scanIntelligenceSummary {
            return summary.title
        }

        return "Scan ready"
    }

    private var statusDetail: String {
        if let progress = appState.scanProgress {
            return "\(progress.scannedCount) items"
        }

        if let snapshot = appState.snapshot {
            return snapshot.completedAt.formatted(date: .omitted, time: .shortened)
        }

        return "No scan"
    }

    private var statTiles: [StatTile] {
        if let progress = appState.scanProgress {
            return [
                StatTile(title: "Scanned", value: "\(progress.scannedCount)", detail: "items", icon: "number", color: .cyan),
                StatTile(title: "Files", value: "\(progress.fileCount)", detail: "regular files", icon: "doc", color: .blue),
                StatTile(title: "Folders", value: "\(progress.directoryCount)", detail: "directories", icon: "folder", color: .indigo),
                StatTile(title: "Found", value: ByteFormat.string(progress.discoveredBytes), detail: "allocated", icon: "externaldrive", color: .teal),
                StatTile(title: "Errors", value: "\(progress.errorCount)", detail: "blocked reads", icon: "exclamationmark.triangle", color: progress.errorCount == 0 ? .secondary : .orange)
            ]
        }

        guard let statistics = appState.scanStatistics else {
            return []
        }

        return [
            StatTile(title: "Total", value: ByteFormat.string(statistics.totalAllocatedBytes), detail: "\(statistics.totalItems) items", icon: "chart.pie", color: .cyan),
            StatTile(title: "Files", value: "\(statistics.fileCount)", detail: "\(statistics.directoryCount) folders", icon: "doc.text.magnifyingglass", color: .blue),
            StatTile(title: "Recoverable", value: ByteFormat.string(statistics.queueableBytes), detail: "\(statistics.queueableCount) candidates", icon: "checkmark.shield", color: .green),
            StatTile(title: "Review", value: "\(statistics.reviewCount)", detail: "manual decisions", icon: "exclamationmark.magnifyingglass", color: .orange),
            StatTile(title: "Protected", value: "\(statistics.protectedCount + statistics.activeCount)", detail: "do not raw-delete", icon: "lock.shield", color: .red),
            StatTile(title: "Largest", value: ByteFormat.string(statistics.largestItemBytes), detail: statistics.largestItemName, icon: "arrow.up.left.and.arrow.down.right", color: .purple)
        ]
    }
}

private struct StatTile: Identifiable {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color

    var id: String {
        title
    }
}

private struct StatTileView: View {
    let tile: StatTile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tile.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tile.color)
                .frame(width: 28, height: 28)
                .background(tile.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(tile.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(tile.value)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(tile.detail)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .spaceLensGlassSurface(cornerRadius: 12)
    }
}

private struct IntelligenceStrip: View {
    let summary: ScanIntelligenceSummary
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 8 : 10) {
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text("Local intelligence")
                    .font(.subheadline.weight(.semibold))
                Text(summary.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(isCompact ? 3 : 2)
                Text(summary.nextStep)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(isCompact ? 3 : 2)
            }

            Spacer(minLength: 8)

            if !isCompact {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(summary.confidence * 100))%")
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text("confidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .spaceLensGlassSurface(cornerRadius: 14)
    }
}

private struct DocumentScanMotionView: View {
    let scannedCount: Int
    private let laneHeight: CGFloat = 88
    private let iconTrackHeight: CGFloat = 52

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.cyan)
                    Text("\(scannedCount) items inspected")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.08), in: Capsule())

                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<7, id: \.self) { index in
                            let phase = (time * 0.42 + Double(index) / 7).truncatingRemainder(dividingBy: 1)
                            let iconSize = index.isMultiple(of: 2) ? CGFloat(25) : CGFloat(21)
                            let x = iconSize / 2 + phase * max(geometry.size.width - iconSize, 1)
                            let y = iconCenterY(index: index, iconSize: iconSize)

                            Image(systemName: index.isMultiple(of: 2) ? "doc.text.magnifyingglass" : "doc")
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundStyle(scanColor(for: index))
                                .opacity(0.42 + 0.5 * phase)
                                .scaleEffect(0.92 + 0.14 * phase)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: iconTrackHeight)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .frame(height: laneHeight)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Scanning documents animation")
    }

    private func iconCenterY(index: Int, iconSize: CGFloat) -> CGFloat {
        let top = iconSize / 2 + 2
        let bottom = iconTrackHeight - iconSize / 2 - 2
        let band = max(bottom - top, 1)
        return top + CGFloat((index * 11) % Int(max(band, 1)))
    }

    private func scanColor(for index: Int) -> Color {
        switch index % 4 {
        case 0:
            .cyan
        case 1:
            .green
        case 2:
            .yellow
        default:
            .orange
        }
    }
}

private struct AnimatedScanBar: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                if isActive {
                    TimelineView(.animation) { timeline in
                        let cycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.45) / 1.45
                        let width = max(geometry.size.width * 0.28, 80)
                        let offset = (geometry.size.width + width) * cycle - width

                        Capsule()
                            .fill(scanGradient)
                            .frame(width: width)
                            .offset(x: offset)
                    }
                } else {
                    Capsule()
                        .fill(scanGradient)
                        .frame(width: geometry.size.width)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 9)
        .accessibilityLabel(isActive ? "Scan is discovering files" : "Scan complete")
    }

    private var scanGradient: LinearGradient {
        LinearGradient(
            colors: [.cyan, .green, .yellow, .orange],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private extension View {
    @ViewBuilder
    func spaceLensGlassSurface(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

private struct EmptyScanView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("No Scan Yet")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                Button {
                    appState.chooseFolder()
                } label: {
                    Label("Select Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    appState.smartScan()
                } label: {
                    Label("Smart Scan", systemImage: "sparkle.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .help("Find safe caches and review-worthy generated files without scanning every file first")
            }

            Text("Smart Scan checks common rebuildable caches, simulator data, package caches, and generated outputs. Nothing is removed automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
