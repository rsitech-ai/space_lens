import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
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
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Section("Support SpaceLens") {
                    Text("If SpaceLens saves you time or disk space, you can support the project and help keep the app improving.")
                        .foregroundStyle(.secondary)

                    Link(destination: SupportLinks.buyMeACoffee) {
                        Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text(SupportLinks.buyMeACoffee.absoluteString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Support", systemImage: "heart.fill")
            }
        }
        .padding()
        .frame(width: 520, height: 320)
    }
}
