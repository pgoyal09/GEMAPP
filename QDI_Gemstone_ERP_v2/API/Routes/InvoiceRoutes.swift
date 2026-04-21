import Foundation
import SwiftData

nonisolated(unsafe) private let sharedISOFormatter = ISO8601DateFormatter()

enum InvoiceRoutes {
    static func register(router: APIRouter) {
        // GET /api/invoices
        router.get("/api/invoices") { req, container in
            let context = ModelContext(container)
            let page = max(1, req.queryInt("page", default: 1))
            let pageSize = min(req.queryInt("pageSize", default: 50), 200)
            let search = req.queryString("search")
            let statusFilter = req.queryString("status")
            let customerFilter = req.queryString("customer")

            let descriptor = FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            var invoices = (try? context.fetch(descriptor)) ?? []

            if let statusFilter, !statusFilter.isEmpty {
                invoices = invoices.filter { $0.status.rawValue.lowercased() == statusFilter.lowercased() }
            }
            if let customerFilter, !customerFilter.isEmpty {
                let q = customerFilter.lowercased()
                invoices = invoices.filter { $0.customer?.displayName.lowercased().contains(q) == true }
            }
            if let search, !search.isEmpty {
                let q = search.lowercased()
                invoices = invoices.filter {
                    $0.referenceNumber.lowercased().contains(q) ||
                    $0.customer?.displayName.lowercased().contains(q) == true
                }
            }

            let total = invoices.count
            let startIdx = min((page - 1) * pageSize, total)
            let endIdx = min(startIdx + pageSize, total)
            let pageItems = Array(invoices[startIdx..<endIdx])

            return .okList(
                pageItems.map { invoiceJSON($0) },
                page: page, pageSize: pageSize, total: total
            )
        }

        // GET /api/invoices/:id
        router.get("/api/invoices/:id") { req, container in
            guard let id = req.pathParams["id"] else { return .notFound() }
            let context = ModelContext(container)
            guard let invoice = findInvoice(id: id, context: context) else {
                return .notFound("Invoice '\(id)' not found")
            }
            return .ok(invoiceDetailJSON(invoice))
        }

        // POST /api/invoices — create
        router.post("/api/invoices") { req, container in
            await MainActor.run {
                let context = ModelContext(container)
                let body = req.jsonBody()
                do {
                    let invoice = try TransactionService.createInvoice(modelContext: context)
                    if let customerName = body?["customer"] as? String {
                        let custDesc = FetchDescriptor<Customer>()
                        if let customers = try? context.fetch(custDesc) {
                            invoice.customer = customers.first { $0.displayName.lowercased() == customerName.lowercased() }
                        }
                    }
                    try context.save()
                    return .created(invoiceJSON(invoice))
                } catch {
                    return .error(code: "CREATE_FAILED", message: ErrorMapper.userMessage(from: error), status: 500)
                }
            }
        }

        // POST /api/invoices/:id/items — add line item
        router.post("/api/invoices/:id/items") { req, container in
            await MainActor.run {
                guard let id = req.pathParams["id"], let body = req.jsonBody() else {
                    return .error(code: "BAD_REQUEST", message: "Invalid request")
                }
                let context = ModelContext(container)
                guard let invoice = findInvoice(id: id, context: context) else {
                    return .notFound("Invoice '\(id)' not found")
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
                    try TransactionService.addStone(stone, to: invoice, modelContext: context)
                    try context.save()
                    return .ok(invoiceDetailJSON(invoice))
                } catch {
                    return .error(code: "ADD_FAILED", message: ErrorMapper.userMessage(from: error))
                }
            }
        }

        // DELETE /api/invoices/:id/items/:itemId
        router.delete("/api/invoices/:id/items/:itemId") { req, container in
            await MainActor.run {
                guard let id = req.pathParams["id"], let itemIdx = req.pathParams["itemId"] else {
                    return .notFound()
                }
                let context = ModelContext(container)
                guard let invoice = findInvoice(id: id, context: context) else {
                    return .notFound("Invoice '\(id)' not found")
                }
                guard let idx = Int(itemIdx), idx < invoice.lineItems.count else {
                    return .notFound("Line item not found")
                }
                let item = invoice.lineItems[idx]
                do {
                    try TransactionService.removeLineItem(item, modelContext: context)
                    try context.save()
                    return .ok(invoiceDetailJSON(invoice))
                } catch {
                    return .error(code: "REMOVE_FAILED", message: ErrorMapper.userMessage(from: error))
                }
            }
        }

        // POST /api/invoices/:id/send — mark as sent
        router.post("/api/invoices/:id/send") { req, container in
            await MainActor.run {
                guard let id = req.pathParams["id"] else { return .notFound() }
                let context = ModelContext(container)
                guard let invoice = findInvoice(id: id, context: context) else {
                    return .notFound("Invoice '\(id)' not found")
                }
                guard invoice.status == .draft else {
                    return .error(code: "CONFLICT", message: "Only draft invoices can be sent", status: 409)
                }
                invoice.status = .sent
                do { try context.save() } catch {
                    return .error(code: "SAVE_FAILED", message: ErrorMapper.userMessage(from: error), status: 500)
                }
                return .ok(invoiceJSON(invoice))
            }
        }

        // POST /api/invoices/:id/void — void invoice
        router.post("/api/invoices/:id/void") { req, container in
            await MainActor.run {
                guard let id = req.pathParams["id"] else { return .notFound() }
                let context = ModelContext(container)
                guard let invoice = findInvoice(id: id, context: context) else {
                    return .notFound("Invoice '\(id)' not found")
                }
                do {
                    try InvoiceService.voidInvoice(invoice, modelContext: context)
                    try context.save()
                } catch {
                    return .error(code: "VOID_FAILED", message: ErrorMapper.userMessage(from: error), status: 500)
                }
                return .ok(invoiceJSON(invoice))
            }
        }

        // GET /api/invoices/:id/pdf — generate PDF
        router.get("/api/invoices/:id/pdf") { req, container in
            guard let id = req.pathParams["id"] else { return .notFound() }
            let context = ModelContext(container)
            guard let invoice = findInvoice(id: id, context: context) else {
                return .notFound("Invoice '\(id)' not found")
            }

            let invoiceID = invoice.persistentModelID
            let pdfData: Data? = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                Task { @MainActor in
                    let mainContext = ModelContext(container)
                    guard let mainInvoice = mainContext.model(for: invoiceID) as? Invoice else {
                        continuation.resume(returning: nil)
                        return
                    }
                    PDFService.shared.generatePDF(invoice: mainInvoice) { result in
                        switch result {
                        case .success(let url):
                            let data = try? Data(contentsOf: url)
                            Task { @MainActor in
                                PDFService.shared.cleanupTempFile(at: url)
                            }
                            continuation.resume(returning: data)
                        case .failure:
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }

            guard let data = pdfData else {
                return .error(code: "PDF_FAILED", message: "Failed to generate PDF", status: 500)
            }
            return .pdf(data)
        }
    }

    // MARK: - Helpers

    private static func findInvoice(id: String, context: ModelContext) -> Invoice? {
        let descriptor = FetchDescriptor<Invoice>()
        guard let invoices = try? context.fetch(descriptor) else { return nil }
        return invoices.first { $0.referenceNumber == id }
    }

    static func invoiceJSON(_ inv: Invoice) -> [String: Any] {
        var json: [String: Any] = [
            "referenceNumber": inv.referenceNumber,
            "status": inv.status.rawValue,
            "totalAmount": NSDecimalNumber(decimal: inv.totalAmount).doubleValue,
            "invoiceDate": sharedISOFormatter.string(from: inv.invoiceDate),
            "createdAt": sharedISOFormatter.string(from: inv.createdAt),
            "lineItemCount": inv.lineItems.count,
            "terms": inv.terms
        ]
        if let customer = inv.customer { json["customer"] = customer.displayName }
        if let dueDate = inv.dueDate { json["dueDate"] = sharedISOFormatter.string(from: dueDate) }
        return json
    }

    static func invoiceDetailJSON(_ inv: Invoice) -> [String: Any] {
        var json = invoiceJSON(inv)
        json["notes"] = inv.notes
        json["lineItems"] = inv.lineItems.map { MemoRoutes.lineItemJSON($0) }
        if let memo = inv.originMemo { json["originMemo"] = memo.referenceNumber }
        return json
    }
}
