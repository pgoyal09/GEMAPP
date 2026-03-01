import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Customer {
    /// Legacy single name; use for migration. New records prefer firstName + lastName.
    var name: String?
    var firstName: String?
    var lastName: String?
    var company: String?
    var email: String?
    var phone: String?
    var address: String?
    var city: String?
    var country: String?
    var zip: String?
    var createdAt: Date
    
    #if canImport(SwiftData)
    @Relationship(inverse: \Memo.customer)
    #endif
    var memos: [Memo]?
    
    #if canImport(SwiftData)
    @Relationship(inverse: \Invoice.customer)
    #endif
    var invoices: [Invoice]?
    
    init(
        name: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        company: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        city: String? = nil,
        country: String? = nil,
        zip: String? = nil,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.country = country
        self.zip = zip
        self.createdAt = createdAt
    }
    
    /// Display name: "firstName lastName", or legacy name if no first/last. Used for list, picker, and logs.
    var displayName: String {
        let first = (firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let last = (lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !first.isEmpty || !last.isEmpty {
            return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        }
        return name ?? ""
    }
    
    /// Memos where stones are currently out on consignment (status == On Memo)
    var activeMemos: [Memo] {
        memos?.filter { $0.status == .onMemo } ?? []
    }

    /// Sum of open memo amounts across all active memos (excludes returned/invoiced items).
    var openExposure: Decimal {
        activeMemos.reduce(Decimal(0)) { $0 + $1.openMemoAmount }
    }
    
    /// Memos where stones were sold (status == Sold)
    var purchaseHistory: [Memo] {
        memos?.filter { $0.status == .sold } ?? []
    }
}
