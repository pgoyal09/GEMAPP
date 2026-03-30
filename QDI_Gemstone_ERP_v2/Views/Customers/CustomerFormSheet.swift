import SwiftUI
import SwiftData

struct CustomerFormSheet: View {
    enum Mode {
        case add
        case edit(Customer)
    }

    let mode: Mode
    var onSave: ((Customer) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @FocusState private var isFirstNameFocused: Bool
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var city = ""
    @State private var country = ""
    @State private var zip = ""

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Customer" : "Add Customer")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.l)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    contactSection
                    addressSection
                }
                .padding(.horizontal, AppSpacing.l)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.outline)
                Button("Save") { save() }
                    .buttonStyle(.gradient)
                    .disabled(firstName.trimmed.isEmpty && lastName.trimmed.isEmpty && company.trimmed.isEmpty)
            }
            .padding(AppSpacing.m)
        }
        .frame(minWidth: 480, minHeight: 400)
        .appBackground()
        
        .onAppear {
            loadExisting()
            isFirstNameFocused = true
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var contactSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Contact")
                HStack(spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First Name").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("First", text: $firstName)
                            .glassField()
                            .textContentType(.givenName)
                            .focused($isFirstNameFocused)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Name").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("Last", text: $lastName).glassField().textContentType(.familyName)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Company").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                    TextField("Company", text: $company).glassField().textContentType(.organizationName)
                }
                HStack(spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("Email", text: $email).glassField().textContentType(.emailAddress)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("Phone", text: $phone).glassField().textContentType(.telephoneNumber)
                    }
                }
            }
        }
    }

    private var addressSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Address")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Street").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                    TextField("Address", text: $address).glassField().textContentType(.fullStreetAddress)
                }
                HStack(spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("City").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("City", text: $city).glassField().textContentType(.addressCity)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Country").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("Country", text: $country).glassField().textContentType(.countryName)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ZIP").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("ZIP", text: $zip).glassField().textContentType(.postalCode).frame(width: 80)
                    }
                }
            }
        }
    }

    private func loadExisting() {
        guard case .edit(let c) = mode else { return }
        firstName = c.firstName
        lastName = c.lastName
        company = c.company
        email = c.email
        phone = c.phone
        address = c.address
        city = c.city
        country = c.country
        zip = c.zip
    }

    private func save() {
        // Require at least one identifying field
        guard !firstName.trimmed.isEmpty || !lastName.trimmed.isEmpty || !company.trimmed.isEmpty else { return }

        switch mode {
        case .add:
            let customer = Customer(
                firstName: firstName.trimmed, lastName: lastName.trimmed,
                company: company.trimmed, email: email.trimmed, phone: phone.trimmed,
                address: address.trimmed, city: city.trimmed, country: country.trimmed, zip: zip.trimmed
            )
            modelContext.insert(customer)
            do {
                try modelContext.save()
            } catch {
                print("Failed to save new customer: \(error.localizedDescription)")
            }
            onSave?(customer)
        case .edit(let c):
            c.firstName = firstName.trimmed
            c.lastName = lastName.trimmed
            c.company = company.trimmed
            c.email = email.trimmed
            c.phone = phone.trimmed
            c.address = address.trimmed
            c.city = city.trimmed
            c.country = country.trimmed
            c.zip = zip.trimmed
            do {
                try modelContext.save()
            } catch {
                print("Failed to save customer edits: \(error.localizedDescription)")
            }
            onSave?(c)
        }
        dismiss()
    }
}
