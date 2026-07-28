import AppKit
import SwiftUI

enum NativeFileTableColumnKind: String, CaseIterable, Equatable {
    case name
    case size
    case kind
    case modified
    case safety
    case recommendation

    var title: String {
        switch self {
        case .name: "Name"
        case .size: "Size"
        case .kind: "Kind"
        case .modified: "Modified"
        case .safety: "Safety"
        case .recommendation: "Recommendation"
        }
    }

    var identifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(rawValue: rawValue)
    }
}

struct NativeFileTableColumn: Equatable {
    let kind: NativeFileTableColumnKind
    let width: CGFloat
    let minimumWidth: CGFloat
    let isFlexible: Bool

    var isSortable: Bool {
        switch kind {
        case .name, .size, .kind, .modified:
            true
        case .safety, .recommendation:
            false
        }
    }
}

struct NativeFileTableConfiguration: Equatable {
    let rowHeight: CGFloat
    let showsQueuedText: Bool
    let columns: [NativeFileTableColumn]

    init(layout: FileTableLayout) {
        rowHeight = layout.rowHeight
        showsQueuedText = layout.showsQueuedText

        var configuredColumns = [
            NativeFileTableColumn(
                kind: .name,
                width: layout.nameColumnIdeal,
                minimumWidth: layout.nameColumnMinimum,
                isFlexible: true
            ),
            NativeFileTableColumn(
                kind: .size,
                width: layout.sizeColumnWidth,
                minimumWidth: layout.sizeColumnWidth,
                isFlexible: false
            )
        ]

        if layout.showsKindColumn {
            configuredColumns.append(
                NativeFileTableColumn(kind: .kind, width: 78, minimumWidth: 78, isFlexible: false)
            )
            configuredColumns.append(
                NativeFileTableColumn(
                    kind: .safety,
                    width: layout.safetyColumnWidth,
                    minimumWidth: layout.safetyColumnWidth,
                    isFlexible: false
                )
            )
        }

        if layout.showsModifiedColumn {
            configuredColumns.insert(
                NativeFileTableColumn(
                    kind: .modified,
                    width: layout.modifiedColumnWidth,
                    minimumWidth: layout.modifiedColumnWidth,
                    isFlexible: false
                ),
                at: 3
            )
        }

        if layout.showsRecommendationColumn {
            configuredColumns.append(
                NativeFileTableColumn(kind: .recommendation, width: 260, minimumWidth: 180, isFlexible: false)
            )
        }

        columns = configuredColumns
    }
}

enum NativeFileTableSelection {
    static func rowIndexes(for nodeIDs: [UUID], selectedNodeIDs: Set<UUID>) -> IndexSet {
        IndexSet(nodeIDs.indices.filter { selectedNodeIDs.contains(nodeIDs[$0]) })
    }

    static func rowIndexes(for rowIndexByID: [UUID: Int], selectedNodeIDs: Set<UUID>) -> IndexSet {
        IndexSet(selectedNodeIDs.compactMap { rowIndexByID[$0] })
    }
}

enum NativeFileTableNameCellLayout {
    static func indentation(depth: Int, showsQueuedText: Bool) -> CGFloat {
        guard showsQueuedText else {
            return 0
        }
        return CGFloat(max(depth - 1, 0)) * 12
    }
}

struct NativeFileTableSort: Equatable {
    let key: NativeFileTableColumnKind
    let order: SortOrder

    func sorted(_ rows: [FlattenedFileNode]) -> [FlattenedFileNode] {
        let comparator: KeyPathComparator<FlattenedFileNode>
        switch key {
        case .name, .safety, .recommendation:
            comparator = KeyPathComparator(\.sortName, order: order)
        case .size:
            comparator = KeyPathComparator(\.sortSize, order: order)
        case .kind:
            comparator = KeyPathComparator(\.sortKind, order: order)
        case .modified:
            comparator = KeyPathComparator(\.sortModifiedAt, order: order)
        }
        return rows.sorted(using: [comparator])
    }
}

struct NativeFileTableRenderState: Equatable {
    let selectedNodeIDs: Set<UUID>
    let queuedNodeIDs: Set<UUID>
}

struct NativeFileTableRow: Identifiable, Equatable {
    let item: FlattenedFileNode
    let classification: SafetyClassification

    var id: UUID {
        item.id
    }
}

struct NativeFileTableView: NSViewRepresentable {
    let rows: [NativeFileTableRow]
    let rowsVersion: Int
    let selectedNodeIDs: Set<UUID>
    let queuedNodeIDs: Set<UUID>
    let configuration: NativeFileTableConfiguration
    let sort: NativeFileTableSort
    let onSelectionChange: (Set<UUID>) -> Void
    let onSortChange: (NativeFileTableSort) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectionChange: onSelectionChange,
            onSortChange: onSortChange
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.makeScrollView()
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onSortChange = onSortChange
        context.coordinator.apply(
            rows: rows,
            rowsVersion: rowsVersion,
            selectedNodeIDs: selectedNodeIDs,
            queuedNodeIDs: queuedNodeIDs,
            configuration: configuration,
            sort: sort
        )
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var onSelectionChange: (Set<UUID>) -> Void
        var onSortChange: (NativeFileTableSort) -> Void

        private let tableView = NSTableView()
        private var rows: [NativeFileTableRow] = []
        private var rowIndexByID: [UUID: Int] = [:]
        private var appliedRowsVersion: Int?
        private var appliedConfiguration: NativeFileTableConfiguration?
        private var appliedSort: NativeFileTableSort?
        private var selectedNodeIDs: Set<UUID> = []
        private var queuedNodeIDs: Set<UUID> = []
        private var isSynchronizingSelection = false
        private var isSynchronizingSort = false

        var nativeTableView: NSTableView {
            tableView
        }

        init(
            onSelectionChange: @escaping (Set<UUID>) -> Void,
            onSortChange: @escaping (NativeFileTableSort) -> Void
        ) {
            self.onSelectionChange = onSelectionChange
            self.onSortChange = onSortChange
        }

        func makeScrollView() -> NSScrollView {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.usesAlternatingRowBackgroundColors = true
            tableView.allowsMultipleSelection = true
            tableView.allowsEmptySelection = true
            tableView.allowsColumnSelection = false
            tableView.allowsColumnReordering = false
            tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
            tableView.rowSizeStyle = .custom
            tableView.usesAutomaticRowHeights = false
            tableView.target = self
            tableView.doubleAction = nil

            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.borderType = .noBorder
            scrollView.documentView = tableView
            return scrollView
        }

        func apply(
            rows: [NativeFileTableRow],
            rowsVersion: Int,
            selectedNodeIDs: Set<UUID>,
            queuedNodeIDs: Set<UUID>,
            configuration: NativeFileTableConfiguration,
            sort: NativeFileTableSort
        ) {
            let configurationChanged = configuration != appliedConfiguration
            let rowsChanged = rowsVersion != appliedRowsVersion
            let queuedChangedIDs = queuedNodeIDs.symmetricDifference(self.queuedNodeIDs)
            let selectionChangedIDs = selectedNodeIDs.symmetricDifference(self.selectedNodeIDs)

            if configurationChanged {
                configureColumns(configuration)
                appliedConfiguration = configuration
            }

            if !queuedChangedIDs.isEmpty {
                self.queuedNodeIDs = queuedNodeIDs
            }

            if !selectionChangedIDs.isEmpty {
                self.selectedNodeIDs = selectedNodeIDs
            }

            if rowsChanged {
                self.rows = rows
                rowIndexByID = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($0.element.id, $0.offset) })
                appliedRowsVersion = rowsVersion
                tableView.reloadData()
            }

            if rowsChanged || !selectionChangedIDs.isEmpty {
                synchronizeNativeSelection()
            }

            if !rowsChanged {
                reloadNameCells(for: queuedChangedIDs)
                reloadNameCells(for: selectionChangedIDs)
            }

            if configurationChanged || sort != appliedSort {
                synchronizeSort(sort)
                appliedSort = sort
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(
            _ tableView: NSTableView,
            viewFor tableColumn: NSTableColumn?,
            row: Int
        ) -> NSView? {
            guard let tableColumn, rows.indices.contains(row),
                  let kind = NativeFileTableColumnKind(rawValue: tableColumn.identifier.rawValue)
            else {
                return nil
            }

            let tableRow = rows[row]
            switch kind {
            case .name:
                let cell = reusableNameCell(for: tableColumn)
                cell.configure(
                    item: tableRow.item,
                    presentation: FileRowPresentation(
                        node: tableRow.item.node,
                        isSelected: selectedNodeIDs.contains(tableRow.id),
                        isQueued: queuedNodeIDs.contains(tableRow.id)
                    ),
                    showsQueuedText: appliedConfiguration?.showsQueuedText ?? false
                )
                return cell
            case .size:
                return reusableTextCell(for: tableColumn, text: ByteFormat.string(tableRow.item.node.effectiveSize), color: .labelColor, monospaced: true)
            case .kind:
                return reusableTextCell(for: tableColumn, text: tableRow.item.sortKind, color: .labelColor)
            case .modified:
                let text = tableRow.item.node.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-"
                return reusableTextCell(for: tableColumn, text: text, color: tableRow.item.node.modifiedAt == nil ? .secondaryLabelColor : .labelColor)
            case .safety:
                return reusableTextCell(
                    for: tableColumn,
                    text: "● \(tableRow.classification.level.displayName)",
                    color: nativeColor(for: tableRow.classification.level)
                )
            case .recommendation:
                return reusableTextCell(for: tableColumn, text: tableRow.classification.recommendedAction, color: .labelColor)
            }
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSynchronizingSelection else {
                return
            }
            let selection = Set(tableView.selectedRowIndexes.compactMap { index in
                rows.indices.contains(index) ? rows[index].id : nil
            })
            guard selection != selectedNodeIDs else {
                return
            }
            let changedIDs = selection.symmetricDifference(selectedNodeIDs)
            selectedNodeIDs = selection
            reloadNameCells(for: changedIDs)
            onSelectionChange(selection)
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard !isSynchronizingSort,
                  let descriptor = tableView.sortDescriptors.first,
                  let key = descriptor.key,
                  let column = NativeFileTableColumnKind(rawValue: key)
            else {
                return
            }
            onSortChange(NativeFileTableSort(key: column, order: descriptor.ascending ? .forward : .reverse))
        }

        private func configureColumns(_ configuration: NativeFileTableConfiguration) {
            for column in tableView.tableColumns {
                tableView.removeTableColumn(column)
            }

            tableView.rowHeight = configuration.rowHeight
            for specification in configuration.columns {
                let column = NSTableColumn(identifier: specification.kind.identifier)
                column.title = specification.kind.title
                column.width = specification.width
                column.minWidth = specification.minimumWidth
                column.resizingMask = specification.isFlexible ? .autoresizingMask : []
                if specification.isSortable {
                    column.sortDescriptorPrototype = NSSortDescriptor(key: specification.kind.rawValue, ascending: true)
                }
                tableView.addTableColumn(column)
            }
        }

        private func synchronizeNativeSelection() {
            let indexes = NativeFileTableSelection.rowIndexes(
                for: rowIndexByID,
                selectedNodeIDs: selectedNodeIDs
            )
            guard indexes != tableView.selectedRowIndexes else {
                return
            }
            isSynchronizingSelection = true
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            isSynchronizingSelection = false
        }

        private func synchronizeSort(_ sort: NativeFileTableSort) {
            let descriptor = NSSortDescriptor(key: sort.key.rawValue, ascending: sort.order == .forward)
            guard tableView.sortDescriptors.first?.key != descriptor.key
                || tableView.sortDescriptors.first?.ascending != descriptor.ascending
            else {
                return
            }
            isSynchronizingSort = true
            tableView.sortDescriptors = [descriptor]
            isSynchronizingSort = false
        }

        private func reloadNameCells(for nodeIDs: Set<UUID>) {
            guard let nameColumn = tableView.column(withIdentifier: .init(NativeFileTableColumnKind.name.rawValue)).nonNegative else {
                return
            }
            let indexes = IndexSet(nodeIDs.compactMap { rowIndexByID[$0] })
            guard !indexes.isEmpty else {
                return
            }
            tableView.reloadData(forRowIndexes: indexes, columnIndexes: IndexSet(integer: nameColumn))
        }

        private func reusableNameCell(for column: NSTableColumn) -> NativeFileTableNameCellView {
            let identifier = NSUserInterfaceItemIdentifier("NativeFileTableNameCell")
            if let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NativeFileTableNameCellView {
                return cell
            }
            return NativeFileTableNameCellView(identifier: identifier)
        }

        private func reusableTextCell(
            for column: NSTableColumn,
            text: String,
            color: NSColor,
            monospaced: Bool = false
        ) -> NativeFileTableTextCellView {
            let identifier = NSUserInterfaceItemIdentifier("NativeFileTableTextCell.\(column.identifier.rawValue)")
            let cell: NativeFileTableTextCellView
            if let reusable = tableView.makeView(withIdentifier: identifier, owner: self) as? NativeFileTableTextCellView {
                cell = reusable
            } else {
                cell = NativeFileTableTextCellView(identifier: identifier)
            }
            cell.configure(text: text, color: color, monospaced: monospaced)
            return cell
        }

        private func nativeColor(for level: SafetyLevel) -> NSColor {
            switch level {
            case .safeTemp: .systemGreen
            case .rebuildableCache: .systemTeal
            case .generatedOutput: .systemBlue
            case .largeButValuable: .systemPurple
            case .activeOrInUse: .systemOrange
            case .systemCritical: .systemRed
            case .unknownReview: .secondaryLabelColor
            }
        }
    }
}

@MainActor
private final class NativeFileTableNameCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let primaryLabel = NSTextField(labelWithString: "")
    private let secondaryLabel = NSTextField(labelWithString: "")
    private let queuedIconView = NSImageView()
    private let queuedLabel = NSTextField(labelWithString: "Queued")
    private let selectionAccent = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = NSUserInterfaceItemIdentifier("NativeFileTableNameCell")
        wantsLayer = true

        primaryLabel.lineBreakMode = .byTruncatingMiddle
        primaryLabel.maximumNumberOfLines = 1
        secondaryLabel.lineBreakMode = .byTruncatingMiddle
        secondaryLabel.maximumNumberOfLines = 1
        secondaryLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        secondaryLabel.textColor = .secondaryLabelColor
        queuedLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        queuedLabel.textColor = .systemGreen
        queuedIconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        queuedIconView.contentTintColor = .systemGreen
        queuedIconView.imageScaling = .scaleProportionallyDown
        iconView.imageScaling = .scaleProportionallyDown
        selectionAccent.wantsLayer = true

        [selectionAccent, iconView, primaryLabel, secondaryLabel, queuedIconView, queuedLabel].forEach(addSubview)
        [iconView, primaryLabel, secondaryLabel, queuedIconView, queuedLabel].forEach { $0.setAccessibilityElement(false) }
        setAccessibilityElement(true)
    }

    convenience init(identifier: NSUserInterfaceItemIdentifier) {
        self.init(frame: .zero)
        self.identifier = identifier
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        let indentation = NativeFileTableNameCellLayout.indentation(
            depth: configuredDepth,
            showsQueuedText: showsQueuedText
        )
        let left = 8 + indentation
        let badgeWidth: CGFloat = showsQueuedText ? 72 : 18
        let badgeOrigin = max(bounds.width - badgeWidth - 8, left + 24)
        selectionAccent.frame = NSRect(x: 0, y: 0, width: 3, height: bounds.height)
        iconView.frame = NSRect(x: left, y: 13, width: 16, height: 16)
        primaryLabel.frame = NSRect(x: left + 24, y: 21, width: max(badgeOrigin - left - 30, 0), height: 17)
        secondaryLabel.frame = NSRect(x: left + 24, y: 4, width: max(bounds.width - left - 32, 0), height: 15)
        queuedIconView.frame = NSRect(x: badgeOrigin, y: 23, width: 14, height: 14)
        queuedLabel.frame = NSRect(x: badgeOrigin + 18, y: 21, width: max(bounds.width - badgeOrigin - 22, 0), height: 17)
    }

    private var configuredDepth = 0
    private var showsQueuedText = false

    func configure(item: FlattenedFileNode, presentation: FileRowPresentation, showsQueuedText: Bool) {
        configuredDepth = item.depth
        self.showsQueuedText = showsQueuedText
        primaryLabel.stringValue = presentation.name
        primaryLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: presentation.isSelected ? .semibold : .regular)
        secondaryLabel.stringValue = presentation.location
        toolTip = presentation.absolutePath
        setAccessibilityLabel(presentation.accessibilityLabel)
        iconView.image = NSImage(systemSymbolName: item.node.isDirectory ? "folder.fill" : "doc", accessibilityDescription: nil)
        iconView.contentTintColor = iconColor(isDirectory: item.node.isDirectory, presentation: presentation)
        queuedIconView.isHidden = !presentation.isQueued
        queuedLabel.isHidden = !presentation.isQueued || !showsQueuedText
        selectionAccent.isHidden = !presentation.isSelected
        selectionAccent.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        layer?.backgroundColor = presentation.isQueued ? NSColor.systemGreen.withAlphaComponent(0.09).cgColor : NSColor.clear.cgColor
        needsLayout = true
    }

    private func iconColor(isDirectory: Bool, presentation: FileRowPresentation) -> NSColor {
        if presentation.isQueued { return .systemGreen }
        if presentation.isSelected { return .controlAccentColor }
        return isDirectory ? .systemBlue : .secondaryLabelColor
    }
}

@MainActor
private final class NativeFileTableTextCellView: NSTableCellView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        addSubview(label)
    }

    convenience init(identifier: NSUserInterfaceItemIdentifier) {
        self.init(frame: .zero)
        self.identifier = identifier
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 5, dy: 8)
    }

    func configure(text: String, color: NSColor, monospaced: Bool) {
        label.stringValue = text
        label.textColor = color
        label.font = monospaced ? NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular) : NSFont.systemFont(ofSize: NSFont.systemFontSize)
        toolTip = text
        setAccessibilityLabel(text)
    }
}

private extension Int {
    var nonNegative: Int? {
        self >= 0 ? self : nil
    }
}
