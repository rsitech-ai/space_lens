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
                .navigationSplitViewColumnWidth(min: 260, ideal: 360, max: 440)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.chooseFolder()
                } label: {
                    Label("Select Folder", systemImage: "folder.badge.plus")
                }
                .help("Select a folder to scan")
                .disabled(appState.isCleaningUp || appState.isAddingFiles)

                Button {
                    appState.smartScan()
                } label: {
                    Label("Smart Scan", systemImage: "sparkle.magnifyingglass")
                }
                .help("Audit rebuildable caches and conditional user data without deleting anything")
                .disabled(appState.isCleaningUp || appState.isAddingFiles)

                Button {
                    appState.rescan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .help("Scan the current folder again")
                .disabled(appState.isScanning || appState.isCleaningUp || appState.isAddingFiles)

                Button {
                    appState.cancelScan()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .help("Stop the current scan")
                .disabled(!appState.isScanning)

                if let selectedNode = appState.selectedNode {
                    Button {
                        appState.revealInFinder(selectedNode)
                    } label: {
                        Label("Reveal", systemImage: "finder")
                    }
                    .help("Reveal the selected item in Finder")
                }
            }

            ToolbarItemGroup {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open SpaceLens settings")
            }
        }
    }
}
