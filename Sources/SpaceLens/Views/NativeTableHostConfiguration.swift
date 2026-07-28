import AppKit
import SwiftUI

struct NativeTableHostConfiguration: Equatable {
    let rowHeight: CGFloat

    @discardableResult
    @MainActor
    func apply(to tableView: NSTableView) -> Bool {
        guard tableView.rowSizeStyle != .custom
            || tableView.rowHeight != rowHeight
            || tableView.usesAutomaticRowHeights
        else {
            return false
        }

        tableView.rowSizeStyle = .custom
        tableView.usesAutomaticRowHeights = false
        tableView.rowHeight = rowHeight
        return true
    }
}

struct NativeTableHostConfigurator: NSViewRepresentable {
    let configuration: NativeTableHostConfiguration

    func makeNSView(context: Context) -> NativeTableHostProbeView {
        NativeTableHostProbeView(configuration: configuration)
    }

    func updateNSView(_ nsView: NativeTableHostProbeView, context: Context) {
        nsView.configuration = configuration
        nsView.configureTableIfNeeded()
    }
}

struct NativeTableCellAccessibilityBridge: NSViewRepresentable {
    let label: String

    func makeNSView(context: Context) -> NativeTableCellAccessibilityProbeView {
        NativeTableCellAccessibilityProbeView(label: label)
    }

    func updateNSView(_ nsView: NativeTableCellAccessibilityProbeView, context: Context) {
        nsView.label = label
        nsView.configureCellIfNeeded()
    }
}

@MainActor
final class NativeTableHostProbeView: NSView {
    var configuration: NativeTableHostConfiguration {
        didSet {
            configureTableIfNeeded()
        }
    }

    private weak var configuredTableView: NSTableView?
    private var hasScheduledLookup = false

    init(configuration: NativeTableHostConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureTableIfNeeded()
    }

    func configureTableIfNeeded() {
        if let configuredTableView {
            configuration.apply(to: configuredTableView)
            return
        }

        guard let tableView = nearestDataTableView() else {
            scheduleLookupIfNeeded()
            return
        }

        configuredTableView = tableView
        configuration.apply(to: tableView)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func scheduleLookupIfNeeded() {
        guard !hasScheduledLookup else {
            return
        }
        hasScheduledLookup = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.hasScheduledLookup = false
            self.configureTableIfNeeded()
        }
    }

    private func nearestDataTableView() -> NSTableView? {
        var ancestor: NSView? = superview
        while let view = ancestor {
            if let tableView = view as? NSTableView, tableView.tableColumns.count >= 2 {
                return tableView
            }
            ancestor = view.superview
        }
        return window?.contentView?.firstDescendant(of: NSTableView.self) { tableView in
            tableView.tableColumns.count >= 2
        }
    }
}

@MainActor
final class NativeTableCellAccessibilityProbeView: NSView {
    var label: String {
        didSet {
            configureCellIfNeeded()
        }
    }

    private weak var configuredCell: NSView?
    private var hasScheduledLookup = false

    init(label: String) {
        self.label = label
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureCellIfNeeded()
    }

    func configureCellIfNeeded() {
        let cell = configuredCell ?? nearestAccessibilityCell()
        guard let cell else {
            scheduleLookupIfNeeded()
            return
        }
        configuredCell = cell
        cell.setAccessibilityLabel(label)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func scheduleLookupIfNeeded() {
        guard !hasScheduledLookup else {
            return
        }
        hasScheduledLookup = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.hasScheduledLookup = false
            self.configureCellIfNeeded()
        }
    }

    private func nearestAccessibilityCell() -> NSView? {
        var ancestor: NSView? = superview
        while let view = ancestor {
            if view is NSTableCellView || view.accessibilityRole() == .cell {
                return view
            }
            ancestor = view.superview
        }
        return nil
    }
}

private extension NSView {
    func firstDescendant<View: NSView>(
        of type: View.Type,
        where predicate: (View) -> Bool
    ) -> View? {
        if let view = self as? View, predicate(view) {
            return view
        }
        for subview in subviews {
            if let match = subview.firstDescendant(of: type, where: predicate) {
                return match
            }
        }
        return nil
    }
}
