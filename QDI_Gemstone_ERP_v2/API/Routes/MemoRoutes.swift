nonisolated(unsafe) private let sharedISOFormatter = ISO8601DateFormatter()
import Foundation
import SwiftData

enum MemoRoutes {
    static func register(router: APIRouter) {
        // GET /api/memos
        router.get("/api/memos") { req, container in
            let context = ModelContext(container)
            let page = max(1, req.queryInt("page", default: 1))
            let pageSize = min(req.queryInt("pageSize", default: 50), 200)
            let search = req.queryString("search")
            let statusFilter = req.queryString("status")
            let customerFilter = req.queryString("customer")

            let descriptor = FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            var memos = (try? context.fetch(descriptor)) ?? []

            if let statusFilter, !statusFilter.isEmpty {
                memos = memos.filter { $0.status.rawValue.lowercased() == statusFilter.lowercased() }
            }
            if let customerFilter, !customerFilter.isEmpty {
                let q = customerFilter.lowercased()
                memos = memos.filter { $0.customer?.displayName.lowercased().contains(q) == true }
            }
            if let search, !search.isEmpty {
                let q = search.lowercased()
                memos = memos.filter {
                    $0.referenceNumber.lowercased().contains(q) ||
                    $0.customer?.displayName.lowercased().contains(q) == true
                }
            }

            let total = memos.count
            let startIdx = min((page - 1) * pageSize, total)
            let endIdx = min(startIdx + pageSize, total)
            let pageItems = Array(memos[startIdx..<endIdx])

            return .okList(
                pageItems.map { memoJSON($0) },
                page: page, pageSize: pageSize, total: total
            )
        }

        // GET /api/memos/:id
        router.get("/api/memos/:id") { req, container in
            guard let id = req.pathParams["id"] else { return .notFound() }
            let context = ModelContext(container)
            guard let memo = findMemo(id: id, context: context) else {
                return .notFound("Memo '\(id)' not found")
            }
            return .ok(memoDetailJSON(memo))
        }

        // POST /api/memos — create
        router.post("/api/memos") { req, container in
            await MainActor.run {
                let context = ModelContext(container)
                let body = req.jsonBody()
                do {
                    let memo = try TransactionService.createMemo(modelContext: context)
                    if let customerName = body?["customer"] as? String {
                        memo.customer = findCustomer(name: customerName, context: context)
                    }
                    try context.save()
                    return .created(memoJSON(memo))
                } catch {
                    return .error(code: "CREATE_FAILED", message: ErrorMapper.userMessage(from: error), status: 500)
                }
            }
        }

        // POST /api/memos/:id/items — add stone
        router.post("/api/memos/:id/items") { req, container in
            await MainActor.run {
                guard let id = req.pathParams["id"], let body = req.jsonBody() else {
                    return .error(code: "BAD_REQUEST", message: "Invalid request")
                }
                let context = ModelContext(container)
                guard let memo = findMemo(id: id, context: context) else {
                    return .notFound("Memo '\(id)' not found")
                }
                guard let stoneSku = body["sku"] as? String else {
                    return .error(code: "BAD_REQUEST", message: "sku is required")
                }
                let stoneDesc = FetchDescriptor<Gemstone>()
                guard let stones = try? context.fetch(stoneDesc),
                      let stone = stones.first(where: { $0.sku == stoneSku }) else {
                    return .notFound("Stone '\(stoneSku)' not found")
                }
                do {
                    try TransactionService.addStone(stone, to: memo, modelContext: context)
                    try context.save()
                    return .ok(memoDetailJSON(memo))
                } catch {
                    return .error(code: "ADD_FAILED", message: ErrorMapper.userMessage(from: error))
                }
            }
        }

        // DELETE /api/memos/:id/items/:itemId — remove line item
        router.delete("/api/memos/:id/items/:itemId") { req, container in
            await MainActor.run {
                guard let id = req.pathParams["id"], let itemIdx = req.pathParams["itemId"] else {
                    return .notFound()
                }
                let context = ModelContext(container)
                guard let memo = findMemo(id: id, context: context) else {
                    return .notFound("Memo '\(id)' not found")
                }
                guard let idx = Int(itemIdx), idx < memo.lineItems.count else {
                    return .notFound("Line item not found")
                }
                let item = memo.lineItems[idx]
                do {
                    try TransactionService.removeLineItem(item, modelContext: context)
                    try context.save()
                    return .ok(memoDetailJSON(memo))
                } catch {
                    return .error(code: "REMOVE_FAILED", message: ErrorMapper.userMessage(from: error))
                }
            }
        }

        // DELETE /api/memos/:id — delete draft memo
        router.delete("/api/memos/:id") { req, container in
            await MainActor.run {
                guard let id = req.pathParams["id"] else { return .notFound() }
                let context = ModelContext(container)
                guard let memo = findMemo(id: id, context: context) else {
                    return .notFound("Memo '\(id)' not found")
                }
                do {
                    try MemoService.deleteMemo(memo, modelContext: context)
                } catch {
                    return .error(code: "DELETE_FAILED", message: ErrorMapper.userMessage(from: error), status: 500)
                }
                return .noContent()
            }
        }

        // POST /api/memos/:id/convert — convert to invoice
        router.post("/api/memos/:id/convert") { req, container in
            await MainActor.run {
                guard let id = req.pathParams["id"] else { return .notFound() }
                let context = ModelContext(container)
                guard let memo = findMemo(id: id, context: context) else {
                    return .notFound("Memo '\(id)' not found")
                }
                let openItems = memo.lineItems.filter { $0.status != .returned && $0.status != .sold }
                guard !openItems.isEmpty else {
                    return .error(code: "CONVERT_FAILED", message: "No open items to convert")
                }
                do {
                    let result = try MemoService.convertToInvoice(memo: memo, selectedItems: openItems, modelContext: context)
                    try context.save()
                    if let invoice = result {
                        return .created(InvoiceRoutes.invoiceJSON(invoice))
                    }
                    return .error(code: "CONVERT_FAILED", message: "No invoice created")
                } catch {
                    return .error(code: "CONVERT_FAILED", message: ErrorMapper.userMessage(from: error))
                }
            }
        }
    }

    // MARK: - Helpers

    private static func findMemo(id: String, context: ModelContext) -> Memo? {
        let descriptor = FetchDescriptor<Memo>()
        guard let memos = try? context.fetch(descriptor) else { return nil }
        return memos.first { $0.referenceNumber == id }
    }

    private static func findCustomer(name: String, context: ModelContext) -> Customer? {
        let descriptor = FetchDescriptor<Customer>()
        guard let customers = try? context.fetch(descriptor) else { return nil }
        return customers.first { $0.displayName.lowercased() == name.lowercased() }
    }

    static func memoJSON(_ m: Memo) -> [String: Any] {
        var json: [String: Any] = [
            "referenceNumber": m.referenceNumber,
            "status": m.status.rawValue,
            "totalAmount": NSDecimalNumber(decimal: m.totalAmount).doubleValue,
            "createdAt": sharedISOFormatter.string(from: m.createdAt),
            "lineItemCount": m.lineItems.count,
            "ageInDays": m.ageInDays
        ]
        if let customer = m.customer { json["customer"] = customer.displayName }
        if let date = m.dateAssigned { json["dateAssigned"] = sharedISOFormatter.string(from: date) }
        return json
    }

    static func memoDetailJSON(_ m: Memo) -> [String: Any] {
        var json = memoJSON(m)
        json["notes"] = m.notes
        json["lineItems"] = m.lineItems.map { lineItemJSON($0) }
        json["openAmount"] = NSDecimalNumber(decimal: m.openMemoAmount).doubleValue
        return json
    }

    static func lineItemJSON(_ item: LineItem) -> [String: Any] {
        [
            "sku": item.displaySku,
            "description": item.displayName,
            "carats": item.carats,
            "rate": NSDecimalNumber(decimal: item.rate).doubleValue,
            "amount": NSDecimalNumber(decimal: item.amount).doubleValue,
            "status": item.status.rawValue,
            "kind": item.kind.rawValue
        ]
    }
}
