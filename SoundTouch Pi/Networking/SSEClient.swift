import Foundation

final class SSEClient {
    private let url: URL
    private var task: Task<Void, Never>?

    init(base: URL) {
        self.url = base.appendingPathComponent("/api/events")
    }

    func start(onEvent: @escaping (SSEEvent) -> Void) {
        task?.cancel()
        task = Task { [url] in
            while !Task.isCancelled {
                do {
                    var req = URLRequest(url: url)
                    let token = APIClient.shared.authToken
                    if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
                    let (stream, _) = try await APIClient.shared.session.bytes(for: req)
                    for try await line in stream.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard let data = json.data(using: .utf8),
                              let payload = try? JSONDecoder().decode(SSEPayload.self, from: data)
                        else { continue }

                        let event = Self.parse(payload)
                        await MainActor.run { onEvent(event) }
                    }
                } catch {
                    // Reconnect after a short delay on any error
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private static func parse(_ p: SSEPayload) -> SSEEvent {
        switch p.type {
        case "connected":
            return .connected
        case "nowPlaying":
            let d = p.data
            let np = NowPlaying(
                source:   d?.source,
                status:   d?.status,
                station:  d?.station,
                track:    d?.track,
                artist:   d?.artist,
                album:    nil,
                icon:     d?.icon,
                presetId: d?.presetId
            )
            return .nowPlaying(np)
        case "volume":
            if let d = p.data, let actual = d.actual {
                return .volume(VolumeInfo(target: d.target ?? actual, actual: actual, muted: d.muted ?? false))
            }
            return .connected
        case "error":
            return .error(p.data?.message ?? "Unknown error")
        default:
            return .connected
        }
    }
}
