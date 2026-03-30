import Foundation
import SwiftData

@Model
final class Customer {
    var firstName: String
    var lastName: String
    var company: String
    var email: String
    var phone: String
    var address: String
    var city: String
    var country: String
    var zip: String
    var createdAt: Date

    @Relationship(deleteRule: .deny, inverse: \Memo.customer)
    var memos: [Memo] = []

    @Relationship(deleteRule: .deny, inverse: \Invoice.customer)
    var invoices: [Invoice] = []

    init(
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        city: String = "",
        country: String = "",
        zip: String = "",
        createdAt: Date = Date()
    ) {
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

    // MARK: - Computed

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? company : full
    }

    var activeMemos: [Memo] {
        memos.filter { $0.status == .onMemo }
    }

    var openExposure: Decimal {
        activeMemos.reduce(Decimal.zero) { $0 + $1.openMemoAmount }
    }

    var formattedAddress: String? {
        var lines: [String] = []
        if !address.isEmpty { lines.append(address) }
        let cityLine = [city, zip, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if !cityLine.isEmpty { lines.append(cityLine) }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    var isActive: Bool { !activeMemos.isEmpty }
}
