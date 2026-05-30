import SwiftUI

struct NowPlayingCard: View {
    @EnvironmentObject var vm: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOW PLAYING")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .kerning(0.5)

            HStack(spacing: 10) {
                Circle()
                    .fill(vm.nowPlaying?.isPlaying == true ? Color(uiColor: .systemGreen) : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .overlay {
                        if vm.nowPlaying?.isPlaying == true {
                            Circle()
                                .fill(Color(uiColor: .systemGreen))
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.5)
                                .opacity(0.4)
                                .animation(.easeInOut(duration: 1.5).repeatForever(), value: vm.nowPlaying?.isPlaying)
                        }
                    }

                Text(stationName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if let meta = metaLine {
                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var stationName: String {
        let np = vm.nowPlaying
        let icon = np?.icon.map { $0 + " " } ?? ""
        return icon + (np?.displayName ?? "—")
    }

    private var metaLine: String? {
        let parts = [vm.nowPlaying?.artist, vm.nowPlaying?.track].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " — ")
    }
}
