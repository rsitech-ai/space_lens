import AppKit
import SwiftUI

@main
struct SpaceLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState(sessionStore: .shared, restoreOnLaunch: true)

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

                Button("Smart Scan") {
                    appState.smartScan()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

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
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
