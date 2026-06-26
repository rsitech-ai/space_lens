import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 148, ideal: 210, max: 260)
        } content: {
            FileTableView()
                .navigationSplitViewColumnWidth(min: 340, ideal: 780)
        } detail: {
            InspectorView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 360)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.chooseFolder()
                } label: {
                    Label("Select Folder", systemImage: "folder.badge.plus")
                }

                Button {
                    appState.rescan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isScanning)

                Button {
                    appState.cancelScan()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .disabled(!appState.isScanning)

                if let selectedNode = appState.selectedNode {
                    Button {
                        appState.revealInFinder(selectedNode)
                    } label: {
                        Label("Reveal", systemImage: "finder")
                    }
                }
            }
        }
    }
}
