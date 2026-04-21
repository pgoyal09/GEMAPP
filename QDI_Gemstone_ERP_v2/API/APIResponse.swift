import Foundation

/// Represents an HTTP response to send back to the client.
struct APIResponse: Sendable {
    let statusCode: Int
    let body: Data
    let contentType: String

    init(statusCode: Int, body: Data, contentType: String = "application/json; charset=utf-8") {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
    }

    var httpData: Data {
        var header = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        if statusCode != 204 {
            header += "Content-Type: \(contentType)\r\n"
            header += "Content-Length: \(body.count)\r\n"
        }
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"
        var data = Data(header.utf8)
        if statusCode != 204 { data.append(body) }
        return data
    }

    private var statusText: String {
        switch statusCode {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 409: "Conflict"
        case 500: "Internal Server Error"
        default: "Unknown"
        }
    }

    // MARK: - Factories

    static func ok(_ data: Any, meta: [String: Any]? = nil) -> APIResponse {
        var envelope: [String: Any] = ["ok": true, "data": data]
        if let meta { envelope["meta"] = meta }
        let body = (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data()
        return APIResponse(statusCode: 200, body: body)
    }

    static func okList(_ data: [[String: Any]], page: Int, pageSize: Int, total: Int) -> APIResponse {
        let envelope: [String: Any] = [
            "ok": true,
            "data": data,
            "meta": ["page": page, "pageSize": pageSize, "total": total]
        ]
        let body = (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data()
        return APIResponse(statusCode: 200, body: body)
    }

    static func created(_ data: Any) -> APIResponse {
        let envelope: [String: Any] = ["ok": true, "data": data]
        let body = (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data()
        return APIResponse(statusCode: 201, body: body)
    }

    static func noContent() -> APIResponse {
        APIResponse(statusCode: 204, body: Data())
    }

    static func error(code: String, message: String, status: Int = 400) -> APIResponse {
        let envelope: [String: Any] = [
            "ok": false,
            "error": ["code": code, "message": message]
        ]
        let body = (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data()
        return APIResponse(statusCode: status, body: body)
    }

    static func notFound(_ message: String = "Not found") -> APIResponse {
        error(code: "NOT_FOUND", message: message, status: 404)
    }

    static func unauthorized() -> APIResponse {
        error(code: "UNAUTHORIZED", message: "Invalid or missing bearer token", status: 401)
    }

    static func serverError(_ message: String = "Internal server error") -> APIResponse {
        error(code: "SERVER_ERROR", message: message, status: 500)
    }

    static func pdf(_ data: Data) -> APIResponse {
        APIResponse(statusCode: 200, body: data, contentType: "application/pdf")
    }
}
