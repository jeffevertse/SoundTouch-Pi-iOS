import SwiftUI

struct SettingsSection: View {
    @EnvironmentObject var vm: PlayerViewModel
    @State private var isExpanded = false
    @State private var wifiStatus: WifiStatusResponse?
    @State private var networks: [WifiNetwork] = []
    @State private var isScanning = false
    @State private var showScanSheet = false
    @State private var authToken: String = APIClient.shared.authToken
    @State private var isUpdating = false
    @State private var updateMessage: String?
    @State private var rebootArmed = false
    @State private var rebootMessage: String?
    @State private var rebootArmTask: Task<Void, Never>?
    @State private var isReconnecting = false
    @State private var reconnectMessage: String?
    @State private var reconnectFailed = false
    @State private var manualIP = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Security ────────────────────────────────────────────────
            Text("SECURITY")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .kerning(0.5)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    iconBadge("key", color: .accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auth Token")
                            .foregroundStyle(.primary)
                        Text("Copy from the web UI System section")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                Divider().padding(.leading, 56)

                HStack(spacing: 8) {
                    SecureField("Paste token here", text: $authToken)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { saveToken() }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Save") { saveToken() }
                        .buttonStyle(.borderedProminent)
                        .disabled(authToken.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                Divider().padding(.leading, 56)

                Button { forgetCert() } label: {
                    HStack(spacing: 12) {
                        iconBadge("lock.slash", color: Color(uiColor: .systemGray))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Forget Trusted Certificate")
                                .foregroundStyle(.primary)
                            Text("Re-trust the Pi on the next connection (after a reinstall)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            Text("Find the token in the web UI System section (soundtouch-pi.local:5000)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)

            // Reconnect section — only shown when device is unreachable
            if vm.isDeviceOffline {
                Text("DEVICE")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .kerning(0.5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    Button { Task { await doReconnect(host: nil) } } label: {
                        HStack(spacing: 12) {
                            iconBadge("arrow.triangle.2.circlepath", color: Color(uiColor: .systemOrange))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isReconnecting ? "Scanning for device…" : "Find / Reconnect Device")
                                    .foregroundStyle(.primary)
                                Text("Use after a factory reset or IP change")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isReconnecting {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .disabled(isReconnecting)

                    if reconnectFailed {
                        Divider().padding(.leading, 56)
                        HStack(spacing: 8) {
                            TextField("IP address (e.g. 192.168.1.62)", text: $manualIP)
                                .keyboardType(.decimalPad)
                                .autocorrectionDisabled()
                                .padding(10)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Button("Connect") {
                                Task { await doReconnect(host: manualIP.trimmingCharacters(in: .whitespaces)) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(manualIP.trimmingCharacters(in: .whitespaces).isEmpty || isReconnecting)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                if let msg = reconnectMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(reconnectFailed ? Color(uiColor: .systemRed) : .secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                }

                Spacer().frame(height: 24)
            }

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
                Button { Task { await updateTapped() } } label: {
                    HStack(spacing: 12) {
                        iconBadge("arrow.up.circle", color: Color(uiColor: .systemGreen))
                        Text(isUpdating ? "Updating…" : "Update Pi")
                            .foregroundStyle(.primary)
                        Spacer()
                        if isUpdating { ProgressView().scaleEffect(0.8) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .disabled(isUpdating)

                Divider().padding(.leading, 56)

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

            if let msg = updateMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
            }

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

    private func doReconnect(host: String?) async {
        isReconnecting = true
        reconnectMessage = nil
        reconnectFailed = false
        defer { isReconnecting = false }
        do {
            let r = try await vm.reconnect(host: host)
            if r.ok {
                reconnectMessage = "Connected to \(r.host ?? host ?? "device") — resyncing presets…"
                reconnectFailed = false
                vm.toast("Device reconnected!")
            } else {
                reconnectMessage = r.error ?? "Device not found."
                reconnectFailed = true
            }
        } catch {
            reconnectMessage = error.localizedDescription
            reconnectFailed = true
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

    private func saveToken() {
        let token = authToken.trimmingCharacters(in: .whitespaces)
        APIClient.shared.authToken = token
        vm.toast("Token saved")
        Task { await vm.loadAll() }
    }

    private func forgetCert() {
        PinningDelegate.forgetPinnedCertificate()
        vm.toast("Trusted certificate cleared")
    }

    private func updateTapped() async {
        isUpdating = true
        updateMessage = nil
        let r = try? await APIClient.shared.update()
        updateMessage = r?.message ?? "Update started…\nThe service will restart when done."
        isUpdating = false
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
