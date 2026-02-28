import SwiftUI
import SwiftData

struct AddCustomerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var city = ""
    @State private var country = ""
    @State private var zip = ""
    
    var onSave: ((Customer) -> Void)?
    
    private var canSave: Bool {
        let f = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !f.isEmpty || !l.isEmpty
    }
    
    var body: some View {
        Form {
            Section("Contact") {
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
                TextField("Company", text: $company)
                    .textContentType(.organizationName)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                TextField("Phone", text: $phone)
                    .textContentType(.telephoneNumber)
            }
            Section("Address") {
                TextField("Street Address", text: $address)
                    .textContentType(.streetAddressLine1)
                TextField("City", text: $city)
                    .textContentType(.addressCity)
                TextField("Zip / Postal Code", text: $zip)
                    .textContentType(.postalCode)
                TextField("Country", text: $country)
                    .textContentType(.countryName)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, minHeight: 380)
        .navigationTitle("Add Customer")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
    }
    
    private func save() {
        let customer = Customer(
            firstName: firstName.isEmpty ? nil : firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.isEmpty ? nil : lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            company: company.isEmpty ? nil : company.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.isEmpty ? nil : city.trimmingCharacters(in: .whitespacesAndNewlines),
            country: country.isEmpty ? nil : country.trimmingCharacters(in: .whitespacesAndNewlines),
            zip: zip.isEmpty ? nil : zip.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(customer)
        do {
            try modelContext.save()
            onSave?(customer)
            dismiss()
        } catch {
            print("Failed to save customer: \(error)")
        }
    }
}
