import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var forgetSessionConfirmation = false

    var body: some View {
        TabView {
            Form {
                Section("Safety") {
                    Text("Cleanup is enabled only for items classified as safe temp, rebuildable cache, or generated output. SpaceLens 1.0 moves cleanup-ready items to the Bin and shows every target path before confirmation.")
                        .foregroundStyle(.secondary)
                }

                Section("Saved Session") {
                    Text("SpaceLens stores the last selected folder bookmark and cleanup queue locally so your review context can be restored after relaunch.")
                        .foregroundStyle(.secondary)

                    Button("Forget Saved Folder and Queue…", role: .destructive) {
                        forgetSessionConfirmation = true
                    }
                }

                Section("AI") {
                    Text("The MVP uses local rule-based explanations only. No file contents or metadata are sent to external services.")
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
                    Text("For support, use the Support link on the SpaceLens App Store product page. Do not include private file contents or sensitive paths in a support request.")
                        .foregroundStyle(.secondary)
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
