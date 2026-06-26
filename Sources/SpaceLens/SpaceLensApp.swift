import AppKit
import SwiftUI

@main
struct SpaceLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("SpaceLens") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 820, minHeight: 620)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") {
                Button("Select Folder...") {
                    appState.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Rescan") {
                    appState.rescan()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandMenu("Selection") {
                Button("Select All Visible") {
                    appState.selectAllVisible()
                }
                .keyboardShortcut("a", modifiers: [.command, .option])

                Button("Select Cleanup Ready") {
                    appState.selectCleanupReadyVisible()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Button("Clear Selection") {
                    appState.clearSelection()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
