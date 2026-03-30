import Foundation
import SwiftData

/// Parsed HTTP request.
struct APIRequest: Sendable {
    let method: String
    let path: String
    var pathParams: [String: String]
    let queryParams: [String: String]
    let headers: [String: String]
    let body: Data?

    func jsonBody() -> [String: Any]? {
        guard let body else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }

    func queryInt(_ key: String, default defaultValue: Int) -> Int {
        guard let str = queryParams[key], let val = Int(str) else { return defaultValue }
        return val
    }

    func queryString(_ key: String) -> String? {
        queryParams[key]?.removingPercentEncoding
    }

    func queryDouble(_ key: String) -> Double? {
        guard let str = queryParams[key] else { return nil }
        return Double(str)
    }
}

typealias APIRouteHandler = @Sendable (APIRequest, ModelContainer) async -> APIResponse

/// Route registration and dispatch.
final class APIRouter: @unchecked Sendable {
    private struct Route {
        let method: String
        let pattern: String
        let handler: APIRouteHandler
    }

    private var routes: [Route] = []

    func get(_ pattern: String, handler: @escaping APIRouteHandler) {
        routes.append(Route(method: "GET", pattern: pattern, handler: handler))
    }

    func post(_ pattern: String, handler: @escaping APIRouteHandler) {
        routes.append(Route(method: "POST", pattern: pattern, handler: handler))
    }

    func patch(_ pattern: String, handler: @escaping APIRouteHandler) {
        routes.append(Route(method: "PATCH", pattern: pattern, handler: handler))
    }

    func delete(_ pattern: String, handler: @escaping APIRouteHandler) {
        routes.append(Route(method: "DELETE", pattern: pattern, handler: handler))
    }

    func dispatch(_ request: APIRequest, container: ModelContainer) async -> APIResponse {
        for route in routes {
            if route.method == request.method,
               let params = matchPath(pattern: route.pattern, path: request.path) {
                var enriched = request
                enriched.pathParams = params
                return await route.handler(enriched, container)
            }
        }
        return .notFound("No route matches \(request.method) \(request.path)")
    }

    private func matchPath(pattern: String, path: String) -> [String: String]? {
        let patternParts = pattern.split(separator: "/", omittingEmptySubsequences: true)
        let pathParts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard patternParts.count == pathParts.count else { return nil }

        var params: [String: String] = [:]
        for (p, v) in zip(patternParts, pathParts) {
            if p.hasPrefix(":") {
                params[String(p.dropFirst())] = String(v)
            } else if p != v {
                return nil
            }
        }
        return params
    }
}
