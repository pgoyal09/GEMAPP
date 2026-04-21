import Foundation
import SwiftData

nonisolated(unsafe) private let sharedISOFormatter = ISO8601DateFormatter()

enum RFIDRoutes {
    static func register(router: APIRouter) {
        // GET /api/rfid/status — reader status
        router.get("/api/rfid/status") { _, container in
            let context = ModelContext(container)
            let tagDesc = FetchDescriptor<RFIDTag>()
            let totalTags = (try? context.fetchCount(tagDesc)) ?? 0

            return .ok([
                "totalAssignedTags": totalTags,
                "note": "RFID hardware status requires main app context; use app UI for scan control"
            ] as [String: Any])
        }

        // GET /api/rfid/tags — list assigned RFID tags
        router.get("/api/rfid/tags") { req, container in
            let context = ModelContext(container)
            let page = max(1, req.queryInt("page", default: 1))
            let pageSize = min(req.queryInt("pageSize", default: 50), 200)

            let descriptor = FetchDescriptor<RFIDTag>()
            let allTags = (try? context.fetch(descriptor)) ?? []

            let total = allTags.count
            let startIdx = min((page - 1) * pageSize, total)
            let endIdx = min(startIdx + pageSize, total)
            let pageItems = Array(allTags[startIdx..<endIdx])

            return .okList(
                pageItems.map { tagJSON($0) },
                page: page, pageSize: pageSize, total: total
            )
        }

        // GET /api/rfid/scan/tags — stones with RFID assigned
        router.get("/api/rfid/scan/tags") { _, container in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Gemstone>()
            let stones = (try? context.fetch(descriptor)) ?? []
            let rfidStones = stones.filter { $0.rfidEpc != nil }

            let data = rfidStones.map { stone -> [String: Any] in
                var json: [String: Any] = [
                    "sku": stone.sku,
                    "epc": stone.rfidEpc ?? "",
                    "status": stone.status.rawValue
                ]
                if let lastSeen = stone.rfidLastSeenAt {
                    json["lastSeen"] = sharedISOFormatter.string(from: lastSeen)
                }
                return json
            }

            return .ok(["stones": data, "count": data.count] as [String: Any])
        }
    }

    private static func tagJSON(_ tag: RFIDTag) -> [String: Any] {
        var json: [String: Any] = [
            "epc": tag.epcCurrent,
            "status": tag.status.rawValue
        ]
        if let tid = tag.tidLastVerified { json["tid"] = tid }
        if let firstSeen = tag.firstSeenAt { json["firstSeen"] = sharedISOFormatter.string(from: firstSeen) }
        if let lastSeen = tag.lastSeenAt { json["lastSeen"] = sharedISOFormatter.string(from: lastSeen) }
        return json
    }
}
