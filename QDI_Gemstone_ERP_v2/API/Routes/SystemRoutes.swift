import Foundation
import SwiftData

enum SystemRoutes {
    static func register(router: APIRouter, server: APIServer) {
        let startTime = Date()
        let serverRef = server

        router.get("/api/health") { _, _ in
            let uptime = Int(Date().timeIntervalSince(startTime))
            return .ok([
                "version": "2.0",
                "uptime": uptime,
                "status": "running"
            ])
        }

        router.get("/api/version") { _, _ in
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            return .ok([
                "version": version,
                "build": build,
                "name": "QDI Gemstone ERP",
                "running": serverRef.isRunning
            ])
        }
    }
}
