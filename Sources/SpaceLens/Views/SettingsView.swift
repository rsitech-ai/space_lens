import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Safety") {
                Text("Cleanup is enabled only for items classified as safe temp, rebuildable cache, or generated output. Move to Bin asks for confirmation; Delete Forever requires typing DELETE.")
                    .foregroundStyle(.secondary)
            }

            Section("AI") {
                Text("The MVP uses local rule-based explanations only. No file contents or metadata are sent to external services.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480)
    }
}
