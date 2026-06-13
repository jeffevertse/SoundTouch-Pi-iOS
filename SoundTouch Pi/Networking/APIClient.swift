import Foundation
import Security

enum APIError: LocalizedError {
    case badStatus(Int)
    case serverError(String)
    case noData
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned \(code)"
        case .serverError(let msg): return msg
        case .noData: return "No data received"
        case .unauthorized: return "Invalid auth token — check Settings"
        }
    }
}

// MARK: - Cert pinning delegate (trust-on-first-use)

/// Pins the Pi's TLS public key on the first successful connection and refuses
/// any later key change. Because each Pi serves its own self-signed cert, there
/// is nothing to ship in the app: the first connection establishes trust (TOFU),
/// and from then on a changed key (possible MITM, or a Pi reinstall/cert regen)
/// is rejected until the user explicitly re-trusts via Settings.
final class PinningDelegate: NSObject, URLSessionDelegate {
    static let shared = PinningDelegate()

    private static let pinKey = "soundtouch_pi_pinned_pubkey"

    /// Whether a key has been pinned (used to label the Settings action).
    static var hasPinnedCertificate: Bool { KeychainStore.read(pinKey) != nil }

    /// Forget the pinned key so the server is re-trusted on the next connection.
    static func forgetPinnedCertificate() { KeychainStore.delete(pinKey) }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust   = challenge.protectionSpace.serverTrust,
              let chain         = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf          = chain.first,
              let serverKey     = SecCertificateCopyKey(leaf),
              let serverKeyData = SecKeyCopyExternalRepresentation(serverKey, nil) as Data?
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Pin the public key (tolerates cert renewal as long as the key is the same).
        let fingerprint = serverKeyData.base64EncodedString()

        if let pinned = KeychainStore.read(Self.pinKey) {
            if pinned == fingerprint {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                // Key changed — refuse. User can re-trust from Settings.
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else {
            // First connection — trust on first use and remember the key.
            KeychainStore.save(fingerprint, account: Self.pinKey)
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        }
    }
}

// MARK: - API client

final class APIClient {
    static let shared = APIClient()
    let base = URL(string: "https://soundtouch-pi.local:5000")!

    private static let tokenKey = "soundtouch_pi_auth_token"

    /// Auth token, stored in the Keychain (not UserDefaults). Reads transparently
    /// migrate any token previously saved in UserDefaults, then clear it.
    var authToken: String {
        get {
            if let token = KeychainStore.read(Self.tokenKey) { return token }
            if let legacy = UserDefaults.standard.string(forKey: Self.tokenKey), !legacy.isEmpty {
                KeychainStore.save(legacy, account: Self.tokenKey)
                UserDefaults.standard.removeObject(forKey: Self.tokenKey)
                return legacy
            }
            return ""
        }
        set {
            if newValue.isEmpty {
                KeychainStore.delete(Self.tokenKey)
            } else {
                KeychainStore.save(newValue, account: Self.tokenKey)
            }
            // Never leave a copy behind in UserDefaults.
            UserDefaults.standard.removeObject(forKey: Self.tokenKey)
        }
    }

    let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        return URLSession(configuration: cfg, delegate: PinningDelegate.shared, delegateQueue: nil)
    }()

    // MARK: - Generic helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var req = URLRequest(url: base.appending(path: path))
        let token = authToken
        if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 { throw APIError.unauthorized }
            if !(200..<300).contains(http.statusCode) { throw APIError.badStatus(http.statusCode) }
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: Encodable? = nil) async throws -> T {
        var req = URLRequest(url: base.appending(path: path))
        req.httpMethod = "POST"
        let token = authToken
        if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 { throw APIError.unauthorized }
            if !(200..<300).contains(http.statusCode) { throw APIError.badStatus(http.statusCode) }
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

    func reconnect(host: String? = nil) async throws -> ReconnectResponse {
        struct Body: Encodable { let host: String? }
        return try await post("/api/device/reconnect", body: host.map { Body(host: $0) })
    }

    func update() async throws -> MessageResponse {
        try await post("/api/system/update")
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

// MARK: - Keychain-backed credential storage

/// Minimal wrapper around a generic-password Keychain item. Used for the auth
/// token so it is stored in the system Keychain rather than UserDefaults.
enum KeychainStore {
    private static let service = "com.jeffevertse.soundtouchpi"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    static func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let match: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String:      data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        // Update in place if it exists, otherwise add it.
        if SecItemUpdate(match as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var add = match
            add.merge(attributes) { _, new in new }
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
