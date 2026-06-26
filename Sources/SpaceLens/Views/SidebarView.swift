import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { geometry in
            let layout = SidebarLayout(width: geometry.size.width)

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

                Section("Support") {
                    SettingsLink {
                        Label {
                            Text("Settings")
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "gearshape")
                        }
                    }
                    .help("Open SpaceLens settings")

                    Link(destination: SupportLinks.buyMeACoffee) {
                        Label {
                            Text(layout.sponsorTitle)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                        }
                    }
                    .help("Support SpaceLens")
                }
            }
            .listStyle(.sidebar)
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

    var sponsorTitle: String {
        isCompact ? "Sponsor" : "Sponsor SpaceLens"
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
