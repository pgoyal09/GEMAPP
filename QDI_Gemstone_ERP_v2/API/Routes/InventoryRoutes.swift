import Foundation
import SwiftData

nonisolated(unsafe) private let sharedISOFormatter = ISO8601DateFormatter()

enum InventoryRoutes {
    static func register(router: APIRouter) {
        // GET /api/stones — list/search with pagination
        router.get("/api/stones") { req, container in
            let context = ModelContext(container)
            let page = req.queryInt("page", default: 1)
            let pageSize = req.queryInt("pageSize", default: 50)
            let search = req.queryString("search")
            let statusFilter = req.queryString("status")
            let typeFilter = req.queryString("type")
            let shapeFilter = req.queryString("shape")
            let minCarat = req.queryDouble("minCarat")
            let maxCarat = req.queryDouble("maxCarat")

            let descriptor = FetchDescriptor<Gemstone>(sortBy: [SortDescriptor(\.sku)])
            let allStones = (try? context.fetch(descriptor)) ?? []

            var filtered = allStones
            if let statusFilter, !statusFilter.isEmpty {
                filtered = filtered.filter { $0.status.rawValue.lowercased() == statusFilter.lowercased() }
            }
            if let typeFilter, !typeFilter.isEmpty {
                filtered = filtered.filter { $0.stoneType.rawValue.lowercased() == typeFilter.lowercased() }
            }
            if let shapeFilter, !shapeFilter.isEmpty {
                filtered = filtered.filter { $0.shape.lowercased() == shapeFilter.lowercased() }
            }
            if let minCarat {
                filtered = filtered.filter { $0.caratWeight >= minCarat }
            }
            if let maxCarat {
                filtered = filtered.filter { $0.caratWeight <= maxCarat }
            }
            if let search, !search.isEmpty {
                let q = search.lowercased()
                filtered = filtered.filter {
                    $0.sku.lowercased().contains(q) ||
                    $0.stoneType.rawValue.lowercased().contains(q) ||
                    $0.color.lowercased().contains(q) ||
                    $0.shape.lowercased().contains(q)
                }
            }

            let total = filtered.count
            let startIdx = min((page - 1) * pageSize, total)
            let endIdx = min(startIdx + pageSize, total)
            let pageItems = Array(filtered[startIdx..<endIdx])

            return .okList(
                pageItems.map { stoneJSON($0) },
                page: page, pageSize: pageSize, total: total
            )
        }

        // GET /api/stones/stats
        router.get("/api/stones/stats") { _, container in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Gemstone>()
            let all = (try? context.fetch(descriptor)) ?? []

            var byStatus: [String: Int] = [:]
            var totalCarats = 0.0
            var totalValue = Decimal.zero
            for stone in all {
                byStatus[stone.status.rawValue, default: 0] += 1
                totalCarats += stone.caratWeight
                totalValue += stone.sellPrice * Decimal(stone.caratWeight)
            }

            return .ok([
                "totalCount": all.count,
                "totalCarats": Double(truncating: NSDecimalNumber(decimal: Decimal(totalCarats))),
                "totalValue": Double(truncating: NSDecimalNumber(decimal: totalValue)),
                "byStatus": byStatus
            ] as [String: Any])
        }

        // GET /api/stones/:id — by SKU
        router.get("/api/stones/:id") { req, container in
            guard let id = req.pathParams["id"] else { return .notFound("Missing stone ID") }
            let context = ModelContext(container)
            guard let stone = findStone(id: id, context: context) else {
                return .notFound("Stone '\(id)' not found")
            }
            return .ok(stoneDetailJSON(stone))
        }

        // POST /api/stones — create
        router.post("/api/stones") { req, container in
            await MainActor.run {
                guard let body = req.jsonBody() else {
                    return .error(code: "BAD_REQUEST", message: "Invalid JSON body")
                }
                let context = ModelContext(container)

                guard let typeStr = body["stoneType"] as? String,
                      let stoneType = StoneType(rawValue: typeStr) else {
                    return .error(code: "BAD_REQUEST", message: "stoneType is required")
                }

                let shape = body["shape"] as? String ?? "Round"
                let groupingStr = body["grouping"] as? String ?? "S"
                let grouping = StoneGrouping(rawValue: groupingStr) ?? .single

                let sku = SKUGenerator.generate(
                    type: stoneType,
                    shape: shape,
                    grouping: grouping,
                    modelContext: context
                )

                let stone = Gemstone(
                    sku: sku,
                    stoneType: stoneType,
                    caratWeight: body["caratWeight"] as? Double ?? 0,
                    shape: shape,
                    grouping: grouping,
                    origin: body["origin"] as? String ?? "",
                    status: .available,
                    color: body["color"] as? String ?? "",
                    clarity: body["clarity"] as? String ?? "",
                    cut: body["cut"] as? String ?? "",
                    treatment: body["treatment"] as? String ?? "",
                    costPrice: Decimal(body["costPrice"] as? Double ?? 0),
                    sellPrice: Decimal(body["sellPrice"] as? Double ?? 0)
                )

                context.insert(stone)
                do {
                    try context.save()
                } catch {
                    return .error(code: "SAVE_FAILED", message: ErrorMapper.userMessage(from: error), status: 500)
                }
                return .created(stoneJSON(stone))
            }
        }

        // PATCH /api/stones/:id — update
        router.patch("/api/stones/:id") { req, container in
            guard let id = req.pathParams["id"], let body = req.jsonBody() else {
                return .error(code: "BAD_REQUEST", message: "Invalid request")
            }
            let context = ModelContext(container)
            guard let stone = findStone(id: id, context: context) else {
                return .notFound("Stone '\(id)' not found")
            }

            if let v = body["color"] as? String { stone.color = v }
            if let v = body["clarity"] as? String { stone.clarity = v }
            if let v = body["cut"] as? String { stone.cut = v }
            if let v = body["shape"] as? String { stone.shape = v }
            if let v = body["origin"] as? String { stone.origin = v }
            if let v = body["treatment"] as? String { stone.treatment = v }
            if let v = body["caratWeight"] as? Double { stone.caratWeight = v }
            if let v = body["costPrice"] as? Double { stone.costPrice = Decimal(v) }
            if let v = body["sellPrice"] as? Double { stone.sellPrice = Decimal(v) }

            do { try context.save() } catch {
                return .error(code: "SAVE_FAILED", message: ErrorMapper.userMessage(from: error), status: 500)
            }
            return .ok(stoneJSON(stone))
        }

        // DELETE /api/stones/:id
        router.delete("/api/stones/:id") { req, container in
            guard let id = req.pathParams["id"] else { return .notFound() }
            let context = ModelContext(container)
            guard let stone = findStone(id: id, context: context) else {
                return .notFound("Stone '\(id)' not found")
            }
            if stone.status == .onMemo {
                return .error(code: "CONFLICT", message: "Cannot delete stone that is on memo", status: 409)
            }
            if stone.status == .sold {
                return .error(code: "CONFLICT", message: "Cannot delete sold stone", status: 409)
            }
            context.delete(stone)
            do { try context.save() } catch {
                return .error(code: "DELETE_FAILED", message: ErrorMapper.userMessage(from: error), status: 500)
            }
            return .noContent()
        }
    }

    // MARK: - Helpers

    private static func findStone(id: String, context: ModelContext) -> Gemstone? {
        let descriptor = FetchDescriptor<Gemstone>()
        guard let stones = try? context.fetch(descriptor) else { return nil }
        return stones.first { $0.sku == id }
    }

    static func stoneJSON(_ s: Gemstone) -> [String: Any] {
        [
            "sku": s.sku,
            "stoneType": s.stoneType.rawValue,
            "caratWeight": s.caratWeight,
            "shape": s.shape,
            "grouping": s.grouping.rawValue,
            "status": s.status.rawValue,
            "color": s.color,
            "clarity": s.clarity,
            "cut": s.cut,
            "origin": s.origin,
            "costPrice": NSDecimalNumber(decimal: s.costPrice).doubleValue,
            "sellPrice": NSDecimalNumber(decimal: s.sellPrice).doubleValue,
            "hasCert": s.hasCert,
            "certLab": s.certLab,
            "certNo": s.certNo,
            "createdAt": sharedISOFormatter.string(from: s.createdAt)
        ]
    }

    static func stoneDetailJSON(_ s: Gemstone) -> [String: Any] {
        var json = stoneJSON(s)
        json["treatment"] = s.treatment
        json["polish"] = s.polish
        json["symmetry"] = s.symmetry
        json["fluorescence"] = s.fluorescence
        json["currentLocation"] = s.currentLocation
        json["needsReview"] = s.needsReview
        if let rfid = s.rfidEpc { json["rfidEpc"] = rfid }
        if s.isLot {
            json["remainingCarats"] = s.effectiveRemainingCarats
        }
        return json
    }
}
