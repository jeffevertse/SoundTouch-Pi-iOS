import SwiftUI

struct PresetsSection: View {
    @EnvironmentObject var vm: PlayerViewModel
    @State private var editingPreset: Preset?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RADIO PRESETS")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .kerning(0.5)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(vm.presets) { preset in
                    PresetCard(preset: preset, isActive: vm.nowPlaying?.presetId == preset.id && vm.nowPlaying?.isPlaying == true)
                        .onTapGesture { Task { await vm.playPreset(preset.id) } }
                        .contextMenu {
                            Button("Edit") { editingPreset = preset }
                        }
                        .overlay(alignment: .topTrailing) {
                            Button { editingPreset = preset } label: {
                                Image(systemName: "pencil")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(8)
                            }
                        }
                }
            }
            .padding(.horizontal, 16)

            // Sync button
            Button {
                Task { await vm.syncHardwarePresets() }
            } label: {
                HStack {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                    Text(vm.isSyncing ? "Syncing…" : "Sync to Device Buttons")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .foregroundStyle(vm.isSyncing ? .secondary : .primary)
            }
            .disabled(vm.isSyncing)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            if let result = vm.syncResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }

            // Other sources
            Text("OTHER SOURCES")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .kerning(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            VStack(spacing: 0) {
                SourceRow(label: "AUX Input", icon: "cable.connector", action: "aux")
                Divider().padding(.leading, 56)
                SourceRow(label: "Bluetooth", icon: "dot.radiowaves.left.and.right", action: "bluetooth")
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditSheet(preset: preset)
                .environmentObject(vm)
        }
    }
}

// MARK: - Preset card

private struct PresetCard: View {
    let preset: Preset
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preset \(preset.id)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(preset.icon)
                .font(.system(size: 28))
                .padding(.vertical, 2)

            Text(preset.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isActive ? Color.accentColor : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Source row

private struct SourceRow: View {
    @EnvironmentObject var vm: PlayerViewModel
    let label: String
    let icon: String
    let action: String

    var body: some View {
        Button {
            Task { await vm.control(action) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
}
