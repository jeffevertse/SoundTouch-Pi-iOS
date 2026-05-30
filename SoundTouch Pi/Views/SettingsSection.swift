import SwiftUI

struct SettingsSection: View {
    @EnvironmentObject var vm: PlayerViewModel
    @State private var isExpanded = false
    @State private var wifiStatus: WifiStatusResponse?
    @State private var networks: [WifiNetwork] = []
    @State private var isScanning = false
    @State private var showScanSheet = false
    @State private var rebootArmed = false
    @State private var rebootMessage: String?
    @State private var rebootArmTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Wi-Fi section
            Text("WI-FI")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .kerning(0.5)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Status row
                Button { withAnimation { isExpanded.toggle() }; if !isExpanded { loadWifi() } } label: {
                    HStack(spacing: 12) {
                        iconBadge("wifi", color: .accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wi-Fi")
                                .foregroundStyle(.primary)
                            if let status = wifiStatus {
                                Text(statusDetail(status))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(wifiStatus?.ssid ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }

                if isExpanded {
                    Divider().padding(.leading, 56)

                    // Scan button
                    Button {
                        showScanSheet = true
                        Task { await scanNetworks() }
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge("magnifyingglass", color: Color(uiColor: .systemGray))
                            Text(isScanning ? "Scanning…" : "Scan for Networks")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .disabled(isScanning)

                    Divider().padding(.leading, 56)

                    // Hotspot toggle
                    Button { Task { await toggleHotspot() } } label: {
                        HStack(spacing: 12) {
                            iconBadge("antenna.radiowaves.left.and.right", color: Color(uiColor: .systemOrange))
                            Text(wifiStatus?.mode == "hotspot" ? "Stop Hotspot" : "Enable Setup Hotspot")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            Text("Creates \"SoundTouch-Pi-Setup\" to reconfigure Wi-Fi from any device")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)

            // System section
            Text("SYSTEM")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .kerning(0.5)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                Button { rebootTapped() } label: {
                    HStack(spacing: 12) {
                        iconBadge("arrow.clockwise", color: Color(uiColor: .systemRed))
                        Text(rebootArmed ? "Tap again to confirm" : "Reboot Pi")
                            .foregroundStyle(rebootArmed ? Color(uiColor: .systemRed) : .primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            if let msg = rebootMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
            }
        }
        .sheet(isPresented: $showScanSheet) {
            WifiScanView(networks: networks, isScanning: isScanning)
                .environmentObject(vm)
        }
        .onAppear { loadWifi() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func iconBadge(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func statusDetail(_ s: WifiStatusResponse) -> String {
        switch s.mode {
        case "client":
            var parts = ["Connected"]
            if let sig = s.signal { parts.append("\(sig)%") }
            if let ip = s.ip { parts.append(ip) }
            return parts.joined(separator: " · ")
        case "hotspot":
            return "Hotspot: \(s.ip ?? "10.42.0.1")"
        default:
            return "Not connected"
        }
    }

    private func loadWifi() {
        Task {
            wifiStatus = try? await APIClient.shared.wifiStatus()
        }
    }

    private func scanNetworks() async {
        isScanning = true
        defer { isScanning = false }
        let r = try? await APIClient.shared.wifiScan()
        networks = r?.networks ?? []
    }

    private func toggleHotspot() async {
        let r = wifiStatus?.mode == "hotspot"
            ? try? await APIClient.shared.disableHotspot()
            : try? await APIClient.shared.enableHotspot()
        vm.toast(r?.message ?? "Done")
        try? await Task.sleep(for: .seconds(5))
        loadWifi()
    }

    private func rebootTapped() {
        if !rebootArmed {
            rebootArmed = true
            rebootArmTask = Task {
                try? await Task.sleep(for: .seconds(4))
                rebootArmed = false
            }
        } else {
            rebootArmTask?.cancel()
            rebootArmed = false
            Task {
                let r = try? await APIClient.shared.reboot()
                rebootMessage = r?.message ?? "Rebooting…\nReconnect in ~30 seconds."
            }
        }
    }
}
