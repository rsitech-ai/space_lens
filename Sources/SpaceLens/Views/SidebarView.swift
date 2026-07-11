import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { geometry in
            let layout = SidebarLayout(width: geometry.size.width)

            VStack(spacing: 0) {
                List(selection: $appState.sidebarSelection) {
                    Section("Library") {
                        ForEach(AppState.SidebarSelection.allCases) { item in
                            Label {
                                Text(layout.title(for: item))
                                    .lineLimit(1)
                            } icon: {
                                Image(systemName: icon(for: item))
                            }
                            .help(item.title)
                            .tag(item)
                        }
                    }

                    if let snapshot = appState.snapshot {
                        Section("Last Scan") {
                            if layout.isCompact {
                                SidebarMetric(title: "Root", value: URL(fileURLWithPath: snapshot.rootPath).lastPathComponent.ifEmpty(snapshot.rootPath))
                                SidebarMetric(title: "Size", value: ByteFormat.string(snapshot.totalAllocatedSize))
                                SidebarMetric(title: "Items", value: "\(snapshot.nodeCount)")
                                SidebarMetric(title: "Errors", value: "\(snapshot.errorCount)")
                            } else {
                                LabeledContent("Root", value: snapshot.rootPath)
                                LabeledContent("Size", value: ByteFormat.string(snapshot.totalAllocatedSize))
                                LabeledContent("Items", value: "\(snapshot.nodeCount)")
                                LabeledContent("Errors", value: "\(snapshot.errorCount)")
                            }
                        }
                        .font(.caption)
                    }

                    Section("Queue") {
                        if layout.isCompact {
                            SidebarMetric(title: "Candidates", value: "\(appState.cleanupQueue.count)")
                            SidebarMetric(title: "Projected", value: ByteFormat.string(appState.projectedRecoverableBytes))
                        } else {
                            LabeledContent("Candidates", value: "\(appState.cleanupQueue.count)")
                            LabeledContent("Projected", value: ByteFormat.string(appState.projectedRecoverableBytes))
                        }
                    }
                    .font(.caption)
                }
                .listStyle(.sidebar)

                SidebarSupportBar(isCompact: layout.isCompact)
            }
        }
    }

    private func icon(for item: AppState.SidebarSelection) -> String {
        switch item {
        case .all:
            "externaldrive"
        case .safe:
            "checkmark.shield"
        case .review:
            "exclamationmark.magnifyingglass"
        case .valuable:
            "doc.badge.gearshape"
        case .active:
            "bolt.horizontal"
        case .errors:
            "exclamationmark.triangle"
        case .queue:
            "tray.full"
        }
    }
}

private struct SidebarLayout {
    let width: CGFloat

    var isCompact: Bool {
        width < 176
    }

    func title(for selection: AppState.SidebarSelection) -> String {
        guard isCompact else {
            return selection.title
        }

        switch selection {
        case .all:
            return "All"
        case .safe:
            return "Safe"
        case .review:
            return "Review"
        case .valuable:
            return "Valuable"
        case .active:
            return "Active"
        case .errors:
            return "Errors"
        case .queue:
            return "Queue"
        }
    }
}

private struct SidebarSupportBar: View {
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 8) {
            Divider()

            HStack(spacing: 8) {
                SettingsLink {
                    SidebarSupportButton(title: "Settings", systemImage: "gearshape", background: .white.opacity(0.12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .help("Open SpaceLens settings")

            }
            .frame(height: 40)
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.bottom, 10)
        }
    }
}

private struct SidebarSupportButton: View {
    let title: String
    let systemImage: String
    let background: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(background)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SidebarMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
