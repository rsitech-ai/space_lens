import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var forgetSessionConfirmation = false

    var body: some View {
        TabView {
            Form {
                Section("Safety") {
                    Text("Safe temp, rebuildable cache and generated output can be queued for cleanup. You can also queue Needs Review and Valuable Data, then acknowledge a manual review before moving them to the Bin. Active, protected and incompletely inspected items remain blocked. Every Bin operation shows the exact target paths and checks activity again.")
                        .foregroundStyle(.secondary)
                }

                Section("Saved Session") {
                    Text("SpaceLens stores the last selected folder bookmark and cleanup queue locally so your review context can be restored after relaunch.")
                        .foregroundStyle(.secondary)

                    Button("Forget Saved Folder and Queue…", role: .destructive) {
                        forgetSessionConfirmation = true
                    }.disabled(appState.isCleaningUp)
                }

                Section("AI") {
                    Text("Explanations use deterministic local rules. No file contents or metadata are sent to external services.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Section("Privacy") {
                    Text("SpaceLens processes selected-folder metadata locally. It has no account, analytics, tracking, or external data service.")
                        .foregroundStyle(.secondary)
                }

                Section("Help") {
                    Text("Open SpaceLens Support for help. Do not include private file contents or sensitive paths in a support request.")
                        .foregroundStyle(.secondary)

                    if let supportURL = SupportLinks.supportURL {
                        Link("Open SpaceLens Support", destination: supportURL)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Privacy & Help", systemImage: "hand.raised.fill")
            }
        }
        .padding()
        .frame(width: 520, height: 320)
        .confirmationDialog(
            "Forget the saved folder and cleanup queue?",
            isPresented: $forgetSessionConfirmation
        ) {
            Button("Forget Saved Session", role: .destructive) {
                appState.forgetSavedSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes SpaceLens’s local bookmark and saved queue. It does not delete files from the selected folder.")
        }
    }
}
