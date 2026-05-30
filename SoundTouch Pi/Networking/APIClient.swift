import Foundation

enum APIError: LocalizedError {
    case badStatus(Int)
    case serverError(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned \(code)"
        case .serverError(let msg): return msg
        case .noData: return "No data received"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    let base = URL(string: "http://soundtouch-pi.local:5000")!

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        return URLSession(configuration: cfg)
    }()

    // MARK: - Generic helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await session.data(from: base.appending(path: path))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.badStatus(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(T.self, from: data)
        return decoded
    }

    private func post<T: Decodable>(_ path: String, body: Encodable? = nil) async throws -> T {
        var req = URLRequest(url: base.appending(path: path))
        req.httpMethod = "POST"
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Endpoints

    func status() async throws -> NowPlayingResponse {
        try await get("/api/status")
    }

    func presets() async throws -> PresetsResponse {
        try await get("/api/presets")
    }

    func playPreset(_ id: Int) async throws -> OkResponse {
        try await post("/api/preset/\(id)/play")
    }

    func savePreset(_ id: Int, name: String, streamUrl: String, icon: String) async throws -> OkResponse {
        struct Body: Encodable {
            let name, stream_url, icon: String
        }
        return try await post("/api/preset/\(id)/save", body: Body(name: name, stream_url: streamUrl, icon: icon))
    }

    func setVolume(_ level: Int) async throws -> OkResponse {
        struct Body: Encodable { let level: Int }
        return try await post("/api/volume", body: Body(level: level))
    }

    func bass() async throws -> BassResponse {
        try await get("/api/bass")
    }

    func setBass(_ level: Int) async throws -> OkResponse {
        struct Body: Encodable { let level: Int }
        return try await post("/api/bass", body: Body(level: level))
    }

    func control(_ action: String) async throws -> OkResponse {
        try await post("/api/control/\(action)")
    }

    func syncHardwarePresets() async throws -> SyncResponse {
        try await post("/api/sync-hardware-presets")
    }

    func wifiStatus() async throws -> WifiStatusResponse {
        try await get("/api/wifi/status")
    }

    func wifiScan() async throws -> WifiScanResponse {
        try await get("/api/wifi/scan")
    }

    func wifiConnect(ssid: String, password: String) async throws -> MessageResponse {
        struct Body: Encodable { let ssid, password: String }
        return try await post("/api/wifi/connect", body: Body(ssid: ssid, password: password))
    }

    func enableHotspot() async throws -> MessageResponse {
        try await post("/api/wifi/hotspot")
    }

    func disableHotspot() async throws -> MessageResponse {
        try await post("/api/wifi/hotspot/stop")
    }

    func reboot() async throws -> MessageResponse {
        try await post("/api/system/reboot")
    }
}

// URL helper for iOS 16 compatibility
private extension URL {
    func appending(path: String) -> URL {
        appendingPathComponent(path)
    }
}
