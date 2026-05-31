import Foundation

struct HealthResponse: Decodable {
    let ok: Bool
    let modelLoaded: Bool
    let cacheFiles: Int
    let cacheBytes: Int
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case modelLoaded = "model_loaded"
        case cacheFiles = "cache_files"
        case cacheBytes = "cache_bytes"
        case error
    }
}

struct VoicesResponse: Decodable {
    let voices: [String]
}

struct CacheResponse: Decodable {
    let cacheDir: String
    let files: Int
    let bytes: Int

    enum CodingKeys: String, CodingKey {
        case cacheDir = "cache_dir"
        case files
        case bytes
    }
}

struct TTSRequest: Encodable {
    let text: String
    let voice: String
    let speed: Double
}

final class KokoroAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func health(baseURL: String) async throws -> HealthResponse {
        let url = try endpoint(baseURL: baseURL, path: "/health")
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    func voices(baseURL: String) async throws -> [String] {
        let url = try endpoint(baseURL: baseURL, path: "/voices")
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(VoicesResponse.self, from: data).voices
    }

    func cache(baseURL: String) async throws -> CacheResponse {
        let url = try endpoint(baseURL: baseURL, path: "/cache")
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(CacheResponse.self, from: data)
    }

    func clearCache(baseURL: String) async throws -> CacheResponse {
        let url = try endpoint(baseURL: baseURL, path: "/cache")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(CacheResponse.self, from: data)
    }

    func tts(baseURL: String, text: String, voice: String, speed: Double) async throws -> URL {
        let url = try endpoint(baseURL: baseURL, path: "/tts")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TTSRequest(text: text, voice: voice, speed: speed))

        let (temporaryURL, response) = try await session.download(for: request)
        let data = try Data(contentsOf: temporaryURL)
        try validate(response: response, data: data)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("kokoro-\(UUID().uuidString).wav")
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func endpoint(baseURL: String, path: String) throws -> URL {
        guard let base = URL(string: baseURL), var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidBackendURL
        }
        components.path = path
        guard let url = components.url else {
            throw ClientError.invalidBackendURL
        }
        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let detail = (try? JSONDecoder().decode(APIErrorResponse.self, from: data).detail)
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(httpResponse.statusCode)"
            throw ClientError.server(detail)
        }
    }
}

struct APIErrorResponse: Decodable {
    let detail: String
}

enum ClientError: LocalizedError {
    case invalidBackendURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL:
            return "Backend URL is invalid."
        case .invalidResponse:
            return "Backend returned an invalid response."
        case let .server(message):
            return message
        }
    }
}
