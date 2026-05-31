import Foundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {

    // MARK: - Published state
    @Published var nowPlaying: NowPlaying?
    @Published var volume: Int = 0
    @Published var presets: [Preset] = []
    @Published var bass: BassResponse?
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var isSyncing = false
    @Published var syncResult: String?
    @Published var isDeviceOffline = false

    private let api = APIClient.shared
    private let sse: SSEClient
    private var pollTask: Task<Void, Never>?

    init() {
        sse = SSEClient(base: APIClient.shared.base)
        Task { await loadAll() }
        startSSE()
        startFallbackPoll()
    }

    // MARK: - Load

    func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadStatus() }
            group.addTask { await self.loadPresets() }
            group.addTask { await self.loadBass() }
        }
    }

    func loadStatus() async {
        do {
            let r = try await api.status()
            nowPlaying = r.nowPlaying
            if let vol = r.volume { volume = vol.actual }
            isDeviceOffline = false
        } catch {
            isDeviceOffline = true
            showError(error)
        }
    }

    func loadPresets() async {
        do {
            let r = try await api.presets()
            presets = r.virtual
        } catch {
            showError(error)
        }
    }

    func loadBass() async {
        do {
            bass = try await api.bass()
        } catch { /* bass may not be supported */ }
    }

    // MARK: - Playback

    func playPreset(_ id: Int) async {
        toast("Playing…")
        do {
            _ = try await api.playPreset(id)
            try? await Task.sleep(for: .seconds(1.5))
            await loadStatus()
        } catch {
            showError(error)
        }
    }

    func control(_ action: String) async {
        do {
            _ = try await api.control(action)
            try? await Task.sleep(for: .milliseconds(800))
            await loadStatus()
        } catch {
            showError(error)
        }
    }

    func setVolume(_ level: Int) async {
        volume = level
        do { _ = try await api.setVolume(level) }
        catch { showError(error) }
    }

    func setBass(_ level: Int) async {
        do { _ = try await api.setBass(level) }
        catch { showError(error) }
    }

    // MARK: - Preset editing

    func savePreset(id: Int, name: String, streamUrl: String, icon: String) async {
        do {
            _ = try await api.savePreset(id, name: name, streamUrl: streamUrl, icon: icon)
            await loadPresets()
            if !streamUrl.isEmpty { await playPreset(id) }
        } catch {
            showError(error)
        }
    }

    // MARK: - Reconnect

    func reconnect(host: String? = nil) async throws -> ReconnectResponse {
        let r = try await api.reconnect(host: host)
        if r.ok {
            isDeviceOffline = false
            await loadAll()
        }
        return r
    }

    // MARK: - Hardware sync

    func syncHardwarePresets() async {
        isSyncing = true
        syncResult = nil
        defer { isSyncing = false }
        do {
            let r = try await api.syncHardwarePresets()
            let ok = r.results.filter(\.ok).count
            let bad = r.results.filter { !$0.ok }
            var msg = "✅ \(ok) preset\(ok == 1 ? "" : "s") written to device buttons."
            if !bad.isEmpty {
                msg += "  ⚠️ " + bad.map { "#\($0.id): \($0.reason ?? "failed")" }.joined(separator: ", ")
            }
            syncResult = msg
            toast("Device buttons updated!")
        } catch {
            showError(error)
        }
    }

    // MARK: - SSE

    private func startSSE() {
        sse.start { [weak self] event in
            guard let self else { return }
            switch event {
            case .nowPlaying(let np):
                self.nowPlaying = np
            case .volume(let vol):
                self.volume = vol.actual
            case .error(let msg):
                self.showError(msg)
            case .connected:
                break
            }
        }
    }

    private func startFallbackPoll() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self?.loadStatus()
            }
        }
    }

    // MARK: - Helpers

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        Task { try? await Task.sleep(for: .seconds(5)); errorMessage = nil }
    }

    private func showError(_ message: String) {
        errorMessage = message
        Task { try? await Task.sleep(for: .seconds(5)); errorMessage = nil }
    }

    func toast(_ message: String) {
        toastMessage = message
        Task { try? await Task.sleep(for: .seconds(2)); toastMessage = nil }
    }
}
