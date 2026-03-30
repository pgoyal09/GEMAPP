import SwiftUI
import SwiftData

enum CustomerFormMode {
    case add
    case edit(Customer)
}

struct CustomerFormSheet: View {
    let mode: CustomerFormMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var firstName: String
    @State private var lastName: String
    @State private var company: String
    @State private var email: String
    @State private var phone: String
    @State private var address: String
    @State private var city: String
    @State private var country: String
    @State private var zip: String
    @State private var saveError: String?

    var onSave: ((Customer) -> Void)?

    init(mode: CustomerFormMode = .add, onSave: ((Customer) -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _firstName = State(initialValue: "")
            _lastName = State(initialValue: "")
            _company = State(initialValue: "")
            _email = State(initialValue: "")
            _phone = State(initialValue: "")
            _address = State(initialValue: "")
            _city = State(initialValue: "")
            _country = State(initialValue: "")
            _zip = State(initialValue: "")
        case .edit(let c):
            _firstName = State(initialValue: c.firstName ?? "")
            _lastName = State(initialValue: c.lastName ?? "")
            _company = State(initialValue: c.company ?? "")
            _email = State(initialValue: c.email ?? "")
            _phone = State(initialValue: c.phone ?? "")
            _address = State(initialValue: c.address ?? "")
            _city = State(initialValue: c.city ?? "")
            _country = State(initialValue: c.country ?? "")
            _zip = State(initialValue: c.zip ?? "")
        }
    }

    private var isEdit: Bool { if case .edit = mode { return true } else { return false } }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("First Name", text: $firstName).textContentType(.givenName).glassField()
                TextField("Last Name", text: $lastName).textContentType(.familyName).glassField()
                TextField("Company", text: $company).textContentType(.organizationName).glassField()
                TextField("Email", text: $email).textContentType(.emailAddress).glassField()
                TextField("Phone", text: $phone).textContentType(.telephoneNumber).glassField()
            } header: {
                Text("CONTACT").sectionLabel()
            }
            Section {
                TextField("Street Address", text: $address).textContentType(.streetAddressLine1).glassField()
                TextField("City", text: $city).textContentType(.addressCity).glassField()
                TextField("Zip / Postal Code", text: $zip).textContentType(.postalCode).glassField()
                TextField("Country", text: $country).textContentType(.countryName).glassField()
            } header: {
                Text("ADDRESS").sectionLabel()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .foregroundStyle(AppColors.ink)
        .frame(minWidth: 360, minHeight: 380)
        .background(AppColors.background)
        .navigationTitle(isEdit ? "Edit Customer" : "Add Customer")
        .alert("Save Error", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "An unknown error occurred.")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Color.white.opacity(0.40))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.buttonStyle(GradientButtonStyle()).disabled(!canSave)
            }
        }
    }

    private func save() {
        let trim = { (s: String) -> String? in
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        switch mode {
        case .add:
            let customer = Customer(
                firstName: trim(firstName), lastName: trim(lastName),
                company: trim(company), email: trim(email), phone: trim(phone),
                address: trim(address), city: trim(city),
                country: trim(country), zip: trim(zip)
            )
            modelContext.insert(customer)
            do { try modelContext.save(); onSave?(customer); dismiss() }
            catch { saveError = "Failed to save customer: \(error.localizedDescription)" }
        case .edit(let customer):
            customer.firstName = trim(firstName)
            customer.lastName = trim(lastName)
            customer.company = trim(company)
            customer.email = trim(email)
            customer.phone = trim(phone)
            customer.address = trim(address)
            customer.city = trim(city)
            customer.country = trim(country)
            customer.zip = trim(zip)
            do {
                try modelContext.save()
                onSave?(customer)
                dismiss()
            } catch {
                saveError = "Failed to save customer: \(error.localizedDescription)"
            }
        }
    }
}
