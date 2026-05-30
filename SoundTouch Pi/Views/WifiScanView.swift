import SwiftUI

struct WifiScanView: View {
    @EnvironmentObject var vm: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    let networks: [WifiNetwork]
    let isScanning: Bool

    @State private var selectedNetwork: WifiNetwork?
    @State private var password = ""
    @State private var connecting = false
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isScanning && networks.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Scanning…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if networks.isEmpty {
                    ContentUnavailableView("No Networks Found", systemImage: "wifi.slash")
                } else {
                    List(networks) { network in
                        Button { selectedNetwork = network } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(network.ssid).foregroundStyle(.primary)
                                    HStack(spacing: 4) {
                                        Image(systemName: network.open ? "lock.open" : "lock.fill")
                                            .font(.caption2)
                                        Text("\(network.signal)%")
                                        Text(network.open ? "Open" : "Secured")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: wifiIcon(network.signal))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Networks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedNetwork) { network in
                connectSheet(network)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func connectSheet(_ network: WifiNetwork) -> some View {
        NavigationStack {
            Form {
                Section("Connecting to \(network.ssid)") {
                    if !network.open {
                        SecureField("Password", text: $password)
                    }
                }
                if let msg = resultMessage {
                    Section { Text(msg).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { selectedNetwork = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(connecting ? "Connecting…" : "Connect") {
                        Task {
                            connecting = true
                            let r = try? await APIClient.shared.wifiConnect(ssid: network.ssid, password: password)
                            resultMessage = r?.message ?? (r?.ok == true ? "Connecting…" : r?.error)
                            connecting = false
                        }
                    }
                    .disabled(connecting || (!network.open && password.isEmpty))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func wifiIcon(_ signal: Int) -> String {
        switch signal {
        case 75...: return "wifi"
        case 50...: return "wifi"
        case 25...: return "wifi"
        default:    return "wifi"
        }
    }
}

// Make WifiNetwork conform to Identifiable for .sheet(item:)
extension WifiNetwork: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(ssid) }
    static func == (lhs: WifiNetwork, rhs: WifiNetwork) -> Bool { lhs.ssid == rhs.ssid }
}
