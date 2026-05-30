import SwiftUI

struct TransportBar: View {
    @EnvironmentObject var vm: PlayerViewModel

    var body: some View {
        HStack(spacing: 20) {
            ControlButton(systemImage: "power", action: "power", vm: vm)
            ControlButton(systemImage: "backward.end.fill", action: "prev", vm: vm)
            ControlButton(systemImage: "playpause.fill", action: "play_pause", vm: vm, primary: true)
            ControlButton(systemImage: "forward.end.fill", action: "next", vm: vm)
            ControlButton(systemImage: "speaker.slash.fill", action: "mute", vm: vm)
        }
        .padding(.horizontal, 24)
    }
}

private struct ControlButton: View {
    let systemImage: String
    let action: String
    @ObservedObject var vm: PlayerViewModel
    var primary = false

    var body: some View {
        Button {
            Task { await vm.control(action) }
        } label: {
            Image(systemName: systemImage)
                .font(primary ? .title2.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(primary ? .white : .primary)
                .frame(width: primary ? 60 : 48, height: primary ? 60 : 48)
                .background(primary ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
