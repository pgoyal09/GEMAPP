import Foundation

/// HTTP client for RapNet TechNet API.
/// Base URL: https://technet.rapnetapis.com
enum RapNetAPIService {

    static let baseURL = "https://technet.rapnetapis.com"

    enum APIError: LocalizedError {
        case invalidCredentials
        case networkError(String)
        case uploadFailed(String)
        case noToken

        var errorDescription: String? {
            switch self {
            case .invalidCredentials: return "Invalid RapNet credentials"
            case .networkError(let msg): return "Network error: \(msg)"
            case .uploadFailed(let msg): return "Upload failed: \(msg)"
            case .noToken: return "Not authenticated — please test connection first"
            }
        }
    }

    // MARK: - Authentication

    /// Authenticate with RapNet and return a JWT Bearer token.
    static func authenticate(username: String, password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/Authentication/Login") else {
            throw APIError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["Username": username, "Password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        if httpResponse.statusCode == 401 {
            throw APIError.invalidCredentials
        }
        guard httpResponse.statusCode == 200 else {
            throw APIError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Response is a JSON string containing the token
        if let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
            return token
        }
        throw APIError.networkError("Could not parse token")
    }

    // MARK: - Upload Inventory

    /// Upload diamond inventory CSV. Returns an upload ID for status tracking.
    static func uploadInventory(csv: String, token: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/diamondupdateingest/api/public/lots") else {
            throw APIError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"inventory.csv\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(csv.data(using: .utf8)!)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.uploadFailed(errMsg)
        }

        // Try to parse upload ID from response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let uploadId = json["UploadId"] as? String {
            return uploadId
        }
        return "submitted"
    }

    // MARK: - Check Upload Status

    static func checkUploadStatus(uploadId: String, token: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/diamondupdateingest/api/public/lots/status/\(uploadId)") else {
            throw APIError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["Status"] as? String {
            return status
        }
        return String(data: data, encoding: .utf8) ?? "unknown"
    }

    // MARK: - Price List

    static func fetchPriceList(token: String) async throws -> [[String: Any]] {
        guard let url = URL(string: "\(baseURL)/prices") else {
            throw APIError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return json
        }
        return []
    }
}
