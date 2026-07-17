import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var explanation: IntelligenceExplanation?

    var body: some View {
        GeometryReader { geometry in
            let layout = InspectorLayout(width: geometry.size.width)

            Group {
                if let node = appState.selectedNode {
                    ScrollView {
                        VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                            title(node, layout: layout)
                            summary(node, layout: layout)
                            evidence(node)
                            inspectorHint(node)
                        }
                        .padding(layout.padding)
                    }
                    .task(id: node.id) {
                        let classification = appState.classification(for: node)
                        explanation = await appState.intelligenceService.explain(node: node, classification: classification)
                    }
                } else if appState.rootNode != nil, appState.visibleNodes.isEmpty {
                    let presentation = appState.emptyResultsPresentation
                    ContentUnavailableView(
                        presentation.title,
                        systemImage: presentation.systemImage,
                        description: Text(presentation.description)
                    )
                } else {
                    ContentUnavailableView(
                        "No Item Selected",
                        systemImage: "sidebar.leading",
                        description: Text("Select an item to inspect its safety classification and evidence.")
                    )
                }
            }
        }
    }

    private func title(_ node: FileNode, layout: InspectorLayout) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: node.isDirectory ? "folder" : "doc")
                    .font(.title2)
                    .foregroundStyle(node.isDirectory ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.displayName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(layout.isCompact ? 3 : 2)
                        .truncationMode(.middle)
                    Text(ByteFormat.string(node.effectiveSize))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    appState.revealInFinder(node)
                } label: {
                    Image(systemName: "finder")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Reveal in Finder")
                .help("Reveal in Finder")
            }

            Text(node.path)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(layout.isCompact ? 3 : 2)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
        }
    }

    private func summary(_ node: FileNode, layout: InspectorLayout) -> some View {
        let classification = appState.classification(for: node)

        return VStack(alignment: .leading, spacing: 10) {
            Label(classification.level.displayName, systemImage: "circle.fill")
                .foregroundStyle(classification.level.color)
                .font(.headline)

            InspectorField("Category", value: classification.category, isCompact: layout.isCompact)
            InspectorField("Confidence", value: "\(Int(classification.confidence * 100))%", isCompact: layout.isCompact)
            InspectorField("Recommendation", value: classification.recommendedAction, isCompact: layout.isCompact)

            if let explanation {
                Divider()
                Text(explanation.title)
                    .font(.subheadline.weight(.semibold))
                Text(explanation.body)
                    .font(.callout)
                Text(explanation.safetyAnswer)
                    .font(.callout)
                Text(explanation.nextStep)
                    .font(.callout.weight(.medium))
            } else {
                Text(classification.summary)
                    .font(.callout)
            }
        }
    }

    private func evidence(_ node: FileNode) -> some View {
        let classification = appState.classification(for: node)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Evidence")
                .font(.headline)

            ForEach(classification.evidence, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle")
                    .font(.callout)
            }

            if let scanError = node.scanError {
                Label(scanError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
        }
    }

    private func inspectorHint(_ node: FileNode) -> some View {
        let classification = appState.classification(for: node)

        return VStack(alignment: .leading, spacing: 8) {
            if let cleanupProgress = appState.cleanupProgress {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        "\(cleanupProgress.phase.displayName) \(cleanupProgress.completedItemCount) of \(max(cleanupProgress.totalItemCount, 1))",
                        systemImage: "trash"
                    )
                    .font(.caption.weight(.semibold))

                    ProgressView(value: cleanupProgress.fractionCompleted, total: 1)

                    Text(URL(fileURLWithPath: cleanupProgress.currentPath).lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if let cleanupStatusMessage = appState.cleanupStatusMessage {
                Label(cleanupStatusMessage, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Text(classification.level.isQueueable ? "Use the bottom action bar to queue or clean up this selected item." : "Cleanup is disabled for this item. SpaceLens only cleans safe temp, rebuildable cache, and generated output classifications.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct InspectorLayout {
    let width: CGFloat

    var isCompact: Bool {
        width < 330
    }

    var padding: CGFloat {
        isCompact ? 12 : 16
    }

    var sectionSpacing: CGFloat {
        isCompact ? 14 : 18
    }
}

private struct InspectorField: View {
    let title: String
    let value: String
    let isCompact: Bool

    init(_ title: String, value: String, isCompact: Bool) {
        self.title = title
        self.value = value
        self.isCompact = isCompact
    }

    var body: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            LabeledContent {
                Text(value)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Text(title)
            }
        }
    }
}
