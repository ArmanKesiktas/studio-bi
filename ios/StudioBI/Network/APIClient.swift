import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Geçersiz sunucu yanıtı."
        case .serverError(let code, let msg): return "Sunucu hatası \(code): \(msg)"
        case .decodingError(let e): return "Veri okunamadı: \(e.localizedDescription)"
        case .networkError(let e): return "Bağlantı hatası: \(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://studio-bi-backend.onrender.com"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Custom session with extended timeout for Render Free Tier cold starts
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120   // Render cold start can take 30-50s
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true       // Wait for network instead of failing instantly
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Upload

    func upload(fileURL: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> UploadResponse {
        let url = URL(string: "\(baseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let data = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let mime = mimeType(for: fileURL)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let delegate = UploadProgressDelegate(onProgress: onProgress)
        let (responseData, response) = try await session.upload(for: request, from: body, delegate: delegate)

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: responseData, encoding: .utf8) ?? "Bilinmeyen hata"
            throw APIError.serverError(http.statusCode, msg)
        }
        do {
            return try decoder.decode(UploadResponse.self, from: responseData)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Dataset

    func getDataset(_ id: String) async throws -> DatasetResponse {
        try await get("/datasets/\(id)")
    }

    func getTable(_ id: String, page: Int = 1, pageSize: Int = 50) async throws -> TablePageResponse {
        try await get("/datasets/\(id)/table?page=\(page)&page_size=\(pageSize)")
    }

    // MARK: - Dashboard

    func getDashboard(_ id: String) async throws -> DashboardResponse {
        try await get("/datasets/\(id)/dashboard")
    }

    // MARK: - Chat

    func chat(_ id: String, question: String) async throws -> ChatResponse {
        let url = URL(string: "\(baseURL)/datasets/\(id)/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(question: question))
        return try await perform(request)
    }

    // MARK: - Export

    func exportCSVURL(_ id: String) -> URL {
        URL(string: "\(baseURL)/datasets/\(id)/export/csv")!
    }

    // MARK: - Private helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        let request = URLRequest(url: url)
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        // Retry once on network errors (covers Render cold start dropouts)
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let (data, response) = try await session.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                guard (200..<300).contains(http.statusCode) else {
                    let msg = String(data: data, encoding: .utf8) ?? "Bilinmeyen hata"
                    throw APIError.serverError(http.statusCode, msg)
                }

                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    // Log decoding errors for debugging
                    print("⚠️ Decode error for \(request.url?.path ?? "?"): \(error)")
                    if let raw = String(data: data, encoding: .utf8) {
                        print("⚠️ Raw response: \(raw.prefix(500))")
                    }
                    throw APIError.decodingError(error)
                }
            } catch let error as APIError {
                // Don't retry on server/decoding errors — only network errors
                throw error
            } catch {
                lastError = error
                if attempt == 0 {
                    // Wait briefly before retry
                    try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                }
            }
        }
        throw APIError.networkError(lastError ?? URLError(.unknown))
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "csv": return "text/csv"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "xls": return "application/vnd.ms-excel"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Upload progress delegate

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let onProgress: @Sendable (Double) -> Void
    init(onProgress: @escaping @Sendable (Double) -> Void) { self.onProgress = onProgress }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        onProgress(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }
}
