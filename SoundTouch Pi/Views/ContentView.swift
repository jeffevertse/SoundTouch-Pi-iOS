import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: PlayerViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    if let error = vm.errorMessage {
                        ErrorBanner(message: error)
                            .padding(.horizontal).padding(.top, 8)
                    }

                    NowPlayingCard()
                        .padding(.horizontal).padding(.top, 16)

                    VolumeRow()
                        .padding(.horizontal).padding(.top, 12)

                    if let bass = vm.bass, bass.caps?.available == true {
                        BassRow()
                            .padding(.horizontal).padding(.top, 12)
                    }

                    TransportBar()
                        .padding(.top, 16).padding(.bottom, 8)

                    PresetsSection()
                        .padding(.top, 8)

                    SettingsSection()
                        .padding(.top, 8)

                    Spacer(minLength: 40)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))

            if let toast = vm.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: vm.toastMessage)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.errorMessage)
    }
}

// MARK: - Error banner

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(Color(uiColor: .systemRed))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .systemRed).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(.regularMaterial.opacity(0))
            .background(Color.black.opacity(0.75))
            .clipShape(Capsule())
    }
}
