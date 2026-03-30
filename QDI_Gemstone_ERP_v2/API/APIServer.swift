import Foundation
import Network
import SwiftData

/// Embedded HTTP server using NWListener. Runs on localhost for local API access.
final class APIServer: @unchecked Sendable {
    private var listener: NWListener?
    private let modelContainer: ModelContainer
    private let router = APIRouter()
    private let queue = DispatchQueue(label: "com.qdi.api-server")
    private let startTime = Date()

    private var port: UInt16
    private var bearerToken: String
    private(set) var isRunning = false

    init(modelContainer: ModelContainer, port: UInt16 = 8847, bearerToken: String) {
        self.modelContainer = modelContainer
        self.port = port
        self.bearerToken = bearerToken
        registerRoutes()
    }

    // MARK: - Lifecycle

    func start() throws {
        guard !isRunning else { return }
        let params = NWParameters.tcp
        guard let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 8847) else { return }
        listener = try NWListener(using: params, on: nwPort)

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                AppLogger.api.info("API server listening on port \(self?.port ?? 0)")
                self?.isRunning = true
            case .failed(let error):
                AppLogger.api.error("API server failed: \(error.localizedDescription)")
                self?.isRunning = false
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        AppLogger.api.info("API server stopped")
    }

    func updateConfig(port: UInt16, token: String) {
        self.port = port
        self.bearerToken = token
    }

    var uptime: TimeInterval { Date().timeIntervalSince(startTime) }

    // MARK: - Route Registration

    private func registerRoutes() {
        SystemRoutes.register(router: router, server: self)
        InventoryRoutes.register(router: router)
        MemoRoutes.register(router: router)
        InvoiceRoutes.register(router: router)
        CustomerRoutes.register(router: router)
        DashboardRoutes.register(router: router)
        RFIDRoutes.register(router: router)
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, _, error in
            guard let self else { connection.cancel(); return }

            guard let data, let request = self.parseHTTPRequest(data) else {
                self.sendResponse(.error(code: "BAD_REQUEST", message: "Invalid HTTP request"), on: connection)
                return
            }

            // OPTIONS for CORS preflight
            if request.method == "OPTIONS" {
                self.sendResponse(self.corsResponse(), on: connection)
                return
            }

            // Auth check (skip /api/health)
            if request.path != "/api/health" {
                guard self.authenticate(request) else {
                    self.sendResponse(.unauthorized(), on: connection)
                    return
                }
            }

            // Dispatch
            let container = self.modelContainer
            let router = self.router
            Task.detached {
                let response = await router.dispatch(request, container: container)
                self.sendResponse(response, on: connection)
            }
        }
    }

    private func sendResponse(_ response: APIResponse, on connection: NWConnection) {
        let data = response.httpData
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Auth

    private func authenticate(_ request: APIRequest) -> Bool {
        guard !bearerToken.isEmpty else { return true }
        let authHeader = request.headers["authorization"] ?? ""
        return authHeader == "Bearer \(bearerToken)"
    }

    // MARK: - HTTP Parsing

    private func parseHTTPRequest(_ data: Data) -> APIRequest? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        let parts = string.components(separatedBy: "\r\n\r\n")
        guard !parts.isEmpty else { return nil }

        let headerSection = parts[0]
        let lines = headerSection.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2)
        guard requestParts.count >= 2 else { return nil }

        let method = String(requestParts[0])
        let fullPath = String(requestParts[1])

        let pathComponents = fullPath.split(separator: "?", maxSplits: 1)
        let path = String(pathComponents[0])
        var queryParams: [String: String] = [:]
        if pathComponents.count > 1 {
            for param in String(pathComponents[1]).split(separator: "&") {
                let kv = param.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                    let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                    queryParams[key] = value
                } else if kv.count == 1 {
                    queryParams[String(kv[0])] = ""
                }
            }
        }

        var headers: [String: String] = [:]
        for i in 1..<lines.count {
            if let colonIdx = lines[i].firstIndex(of: ":") {
                let key = String(lines[i][lines[i].startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(lines[i][lines[i].index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        var body: Data? = nil
        if parts.count > 1 {
            let bodyString = parts.dropFirst().joined(separator: "\r\n\r\n")
            if !bodyString.isEmpty {
                body = Data(bodyString.utf8)
            }
        }

        return APIRequest(method: method, path: path, pathParams: [:], queryParams: queryParams, headers: headers, body: body)
    }

    private func corsResponse() -> APIResponse {
        APIResponse(statusCode: 204, body: Data())
    }
}
