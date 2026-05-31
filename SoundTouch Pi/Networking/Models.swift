import Foundation

// MARK: - Now Playing

struct NowPlayingResponse: Decodable {
    let ok: Bool
    let nowPlaying: NowPlaying?
    let volume: VolumeInfo?

    enum CodingKeys: String, CodingKey {
        case ok
        case nowPlaying = "now_playing"
        case volume
    }
}

struct NowPlaying: Decodable {
    let source: String?
    let status: String?
    let station: String?
    let track: String?
    let artist: String?
    let album: String?
    let icon: String?
    let presetId: Int?

    enum CodingKeys: String, CodingKey {
        case source, status, station, track, artist, album, icon
        case presetId = "preset_id"
    }

    var isPlaying: Bool {
        status == "PLAY_STATE" || status == "BUFFERING_STATE"
    }

    var displayName: String {
        station ?? track ?? artist ?? "—"
    }
}

// MARK: - Volume & Bass

struct VolumeInfo: Decodable {
    let target: Int
    let actual: Int
    let muted: Bool
}

struct BassResponse: Decodable {
    let ok: Bool
    let level: Int?
    let caps: BassCaps?
}

struct BassCaps: Decodable {
    let available: Bool
    let min: Int
    let max: Int
    let `default`: Int
}

// MARK: - Presets

struct PresetsResponse: Decodable {
    let virtual: [Preset]
    let hardware: [HardwarePreset]
}

struct Preset: Decodable, Identifiable {
    let id: Int
    let name: String
    let streamUrl: String
    let icon: String

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case streamUrl = "stream_url"
    }

    var isConfigured: Bool { !streamUrl.isEmpty }
}

struct HardwarePreset: Decodable, Identifiable {
    let id: Int
    let source: String?
    let location: String?
    let name: String?
}

// MARK: - WiFi

struct WifiStatusResponse: Decodable {
    let ok: Bool
    let mode: String
    let connected: Bool
    let ssid: String?
    let signal: Int?
    let ip: String?
}

struct WifiScanResponse: Decodable {
    let ok: Bool
    let networks: [WifiNetwork]
}

struct WifiNetwork: Decodable, Identifiable {
    var id: String { ssid }
    let ssid: String
    let signal: Int
    let security: String
    let open: Bool
}

// MARK: - Generic

struct OkResponse: Decodable {
    let ok: Bool
    let error: String?
}

struct MessageResponse: Decodable {
    let ok: Bool
    let message: String?
    let error: String?
}

struct SyncResult: Decodable {
    let id: Int
    let ok: Bool
    let reason: String?
    let proxyUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, ok, reason
        case proxyUrl = "proxy_url"
    }
}

struct SyncResponse: Decodable {
    let ok: Bool
    let results: [SyncResult]
}

struct ReconnectResponse: Decodable {
    let ok: Bool
    let host: String?
    let resyncing: Bool?
    let error: String?
}

// MARK: - SSE events

enum SSEEvent {
    case nowPlaying(NowPlaying)
    case volume(VolumeInfo)
    case error(String)
    case connected
}

struct SSEPayload: Decodable {
    let type: String
    let data: SSEData?
}

struct SSEData: Decodable {
    let source: String?
    let status: String?
    let station: String?
    let track: String?
    let artist: String?
    let icon: String?
    let presetId: Int?
    let actual: Int?
    let target: Int?
    let muted: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case source, status, station, track, artist, icon, actual, target, muted, message
        case presetId = "preset_id"
    }
}
