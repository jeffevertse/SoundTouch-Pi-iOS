import SwiftUI

struct BassRow: View {
    @EnvironmentObject var vm: PlayerViewModel
    @State private var localBass: Double = 0
    @State private var debounceTask: Task<Void, Never>?

    private var caps: BassCaps? { vm.bass?.caps }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.below.rectangle")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Slider(
                value: $localBass,
                in: Double(caps?.min ?? -9)...Double(caps?.max ?? 9),
                step: 1
            )
            .tint(Color(uiColor: .systemTeal))
            .onChange(of: localBass) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await vm.setBass(Int(newValue))
                }
            }

            Text("\(Int(localBass))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear { localBass = Double(vm.bass?.level ?? 0) }
    }
}
