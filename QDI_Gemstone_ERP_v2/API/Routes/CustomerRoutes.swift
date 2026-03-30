import Foundation
import SwiftData

enum CustomerRoutes {
    static func register(router: APIRouter) {
        // GET /api/customers
        router.get("/api/customers") { req, container in
            let context = ModelContext(container)
            let page = req.queryInt("page", default: 1)
            let pageSize = req.queryInt("pageSize", default: 50)
            let search = req.queryString("search")

            let descriptor = FetchDescriptor<Customer>(sortBy: [SortDescriptor(\.lastName)])
            var customers = (try? context.fetch(descriptor)) ?? []

            if let search, !search.isEmpty {
                let q = search.lowercased()
                customers = customers.filter {
                    $0.displayName.lowercased().contains(q) ||
                    $0.company.lowercased().contains(q) ||
                    $0.email.lowercased().contains(q)
                }
            }

            let total = customers.count
            let startIdx = min((page - 1) * pageSize, total)
            let endIdx = min(startIdx + pageSize, total)
            let pageItems = Array(customers[startIdx..<endIdx])

            return .okList(
                pageItems.map { customerJSON($0) },
                page: page, pageSize: pageSize, total: total
            )
        }

        // GET /api/customers/:id — by displayName (URL-encoded)
        router.get("/api/customers/:id") { req, container in
            guard let id = req.pathParams["id"]?.removingPercentEncoding else { return .notFound() }
            let context = ModelContext(container)
            guard let customer = findCustomer(id: id, context: context) else {
                return .notFound("Customer '\(id)' not found")
            }
            return .ok(customerDetailJSON(customer, context: context))
        }

        // POST /api/customers — create
        router.post("/api/customers") { req, container in
            guard let body = req.jsonBody() else {
                return .error(code: "BAD_REQUEST", message: "Invalid JSON body")
            }
            let context = ModelContext(container)

            let customer = Customer(
                firstName: body["firstName"] as? String ?? "",
                lastName: body["lastName"] as? String ?? "",
                company: body["company"] as? String ?? "",
                email: body["email"] as? String ?? "",
                phone: body["phone"] as? String ?? "",
                address: body["address"] as? String ?? "",
                city: body["city"] as? String ?? "",
                country: body["country"] as? String ?? "",
                zip: body["zip"] as? String ?? "",
                notes: body["notes"] as? String ?? ""
            )
            context.insert(customer)
            do { try context.save() } catch {
                return .error(code: "SAVE_FAILED", message: error.localizedDescription, status: 500)
            }
            return .created(customerJSON(customer))
        }

        // PATCH /api/customers/:id — update
        router.patch("/api/customers/:id") { req, container in
            guard let id = req.pathParams["id"]?.removingPercentEncoding,
                  let body = req.jsonBody() else {
                return .error(code: "BAD_REQUEST", message: "Invalid request")
            }
            let context = ModelContext(container)
            guard let customer = findCustomer(id: id, context: context) else {
                return .notFound("Customer '\(id)' not found")
            }

            if let v = body["firstName"] as? String { customer.firstName = v }
            if let v = body["lastName"] as? String { customer.lastName = v }
            if let v = body["company"] as? String { customer.company = v }
            if let v = body["email"] as? String { customer.email = v }
            if let v = body["phone"] as? String { customer.phone = v }
            if let v = body["address"] as? String { customer.address = v }
            if let v = body["city"] as? String { customer.city = v }
            if let v = body["country"] as? String { customer.country = v }
            if let v = body["zip"] as? String { customer.zip = v }
            if let v = body["notes"] as? String { customer.notes = v }

            do { try context.save() } catch {
                return .error(code: "SAVE_FAILED", message: error.localizedDescription, status: 500)
            }
            return .ok(customerJSON(customer))
        }

        // DELETE /api/customers/:id
        router.delete("/api/customers/:id") { req, container in
            guard let id = req.pathParams["id"]?.removingPercentEncoding else { return .notFound() }
            let context = ModelContext(container)
            guard let customer = findCustomer(id: id, context: context) else {
                return .notFound("Customer '\(id)' not found")
            }
            context.delete(customer)
            do { try context.save() } catch {
                return .error(code: "DELETE_FAILED", message: error.localizedDescription, status: 500)
            }
            return .noContent()
        }
    }

    // MARK: - Helpers

    private static func findCustomer(id: String, context: ModelContext) -> Customer? {
        let descriptor = FetchDescriptor<Customer>()
        guard let customers = try? context.fetch(descriptor) else { return nil }
        // Match by displayName or email
        return customers.first {
            $0.displayName == id || $0.email == id
        }
    }

    static func customerJSON(_ c: Customer) -> [String: Any] {
        [
            "displayName": c.displayName,
            "firstName": c.firstName,
            "lastName": c.lastName,
            "company": c.company,
            "email": c.email,
            "phone": c.phone,
            "city": c.city,
            "country": c.country,
            "createdAt": ISO8601DateFormatter().string(from: c.createdAt)
        ]
    }

    static func customerDetailJSON(_ c: Customer, context: ModelContext) -> [String: Any] {
        var json = customerJSON(c)
        json["address"] = c.address
        json["zip"] = c.zip
        json["notes"] = c.notes
        json["openExposure"] = NSDecimalNumber(decimal: c.openExposure).doubleValue
        json["isActive"] = c.isActive

        // Recent memos
        let memoDesc = FetchDescriptor<Memo>()
        if let memos = try? context.fetch(memoDesc) {
            let customerMemos = memos.filter { $0.customer?.displayName == c.displayName }
                .prefix(10)
            json["recentMemos"] = customerMemos.map { MemoRoutes.memoJSON($0) }
        }

        // Recent invoices
        let invDesc = FetchDescriptor<Invoice>()
        if let invoices = try? context.fetch(invDesc) {
            let customerInvoices = invoices.filter { $0.customer?.displayName == c.displayName }
                .prefix(10)
            json["recentInvoices"] = customerInvoices.map { InvoiceRoutes.invoiceJSON($0) }
        }

        return json
    }
}
