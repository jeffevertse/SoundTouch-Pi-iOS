import SwiftUI

struct PresetEditSheet: View {
    @EnvironmentObject var vm: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    let preset: Preset
    @State private var name: String
    @State private var streamUrl: String
    @State private var icon: String

    init(preset: Preset) {
        self.preset = preset
        _name = State(initialValue: preset.name)
        _streamUrl = State(initialValue: preset.streamUrl)
        _icon = State(initialValue: preset.icon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Station") {
                    TextField("Name", text: $name)
                    TextField("Stream URL", text: $streamUrl)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Icon (emoji)", text: $icon)
                }
                Section {
                    Text("Paste any public HTTP or HTTPS MP3/AAC stream URL.\nFind stations at radio-browser.info")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Preset \(preset.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Play") {
                        Task {
                            await vm.savePreset(
                                id: preset.id,
                                name: name,
                                streamUrl: streamUrl,
                                icon: icon.isEmpty ? "📻" : icon
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
