import SwiftUI

struct VolumeRow: View {
    @EnvironmentObject var vm: PlayerViewModel
    @State private var localVolume: Double = 0
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Slider(value: $localVolume, in: 0...100, step: 1)
                .tint(.accentColor)
                .onChange(of: localVolume) { _, newValue in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        await vm.setVolume(Int(newValue))
                    }
                }

            Text("\(Int(localVolume))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear { localVolume = Double(vm.volume) }
        .onChange(of: vm.volume) { _, v in
            if abs(localVolume - Double(v)) > 1 { localVolume = Double(v) }
        }
    }
}
