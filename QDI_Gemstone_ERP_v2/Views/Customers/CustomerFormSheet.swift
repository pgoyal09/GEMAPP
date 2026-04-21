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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Field: Hashable { case firstName, lastName, company, email, phone, address, city, country, zip, notes }
    @FocusState private var focusedField: Field?
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var city = ""
    @State private var country = ""
    @State private var zip = ""
    @State private var notes = ""
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var isSaving = false
    @State private var isDirty = false
    @State private var isInitialLoad = true
    @State private var showDiscardAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Customer" : "Add Customer")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.hero)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.hero) {
                    contactSection
                    addressSection
                    notesSection
                }
                .padding(.horizontal, AppSpacing.hero)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                        if isDirty { showDiscardAlert = true } else { dismiss() }
                    }
                    .buttonStyle(.outline)
                    .disabled(isSaving)
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Save") { save() }
                    .buttonStyle(.gradient)
                    .disabled(isSaving || !hasAnyIdentifier)
            }
            .padding(AppSpacing.section)
        }
        .frame(minWidth: 480, minHeight: 400)
        .appBackground()
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95)))
        .interactiveDismissDisabled(isSaving)
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
                        }
                    }
            }
        }
        .onAppear {
            loadExisting()
            focusedField = .firstName
            // Defer clearing the initial load flag so onChange handlers
            // triggered by loadExisting() won't mark the form dirty.
            DispatchQueue.main.async { isInitialLoad = false }
        }
        .onChange(of: firstName) { _, _ in markDirtyIfNeeded() }
        .onChange(of: lastName) { _, _ in markDirtyIfNeeded() }
        .onChange(of: company) { _, _ in markDirtyIfNeeded() }
        .onChange(of: email) { _, _ in markDirtyIfNeeded() }
        .onChange(of: phone) { _, _ in markDirtyIfNeeded() }
        .onChange(of: address) { _, _ in markDirtyIfNeeded() }
        .onChange(of: city) { _, _ in markDirtyIfNeeded() }
        .onChange(of: country) { _, _ in markDirtyIfNeeded() }
        .onChange(of: zip) { _, _ in markDirtyIfNeeded() }
        .onChange(of: notes) { _, _ in markDirtyIfNeeded() }
        .alert("Unsaved Changes", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// At least one identifying field (first name, last name, or company) must be non-empty to save.
    private var hasAnyIdentifier: Bool {
        !firstName.trimmed.isEmpty || !lastName.trimmed.isEmpty || !company.trimmed.isEmpty
    }

    private func markDirtyIfNeeded() {
        guard !isInitialLoad else { return }
        isDirty = true
    }

    private var contactSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Contact")
                HStack(spacing: AppSpacing.section) {
                    FormField(label: "First Name", text: $firstName)
                        .focused($focusedField, equals: .firstName)
                    FormField(label: "Last Name", text: $lastName)
                }
                FormField(label: "Company", text: $company)
                HStack(spacing: AppSpacing.section) {
                    FormField(label: "Email", text: $email)
                    FormField(label: "Phone", text: $phone)
                }
            }
        }
    }

    private var addressSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Address")
                FormField(label: "Street", text: $address)
                HStack(spacing: AppSpacing.section) {
                    FormField(label: "City", text: $city)
                    FormField(label: "Country", text: $country)
                    FormField(label: "ZIP", text: $zip)
                        .frame(width: 80)
                }
            }
        }
    }

    private var notesSection: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                SectionHeader(title: "Notes")
                TextEditor(text: $notes)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .padding(AppSpacing.compact)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.small)
                            .fill(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                    .strokeBorder(Color.white.opacity(AppOpacity.subtle), lineWidth: 1)
                            )
                    )
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
        notes = c.notes
    }

    private func save() {
        // Require at least one identifying field
        guard !firstName.trimmed.isEmpty || !lastName.trimmed.isEmpty || !company.trimmed.isEmpty else { return }

        // Validate field lengths and formats
        if let err = InputValidator.validateStringField(firstName, field: "First name", maxLength: InputValidator.maxCustomerName) ??
            InputValidator.validateStringField(lastName, field: "Last name", maxLength: InputValidator.maxCustomerName) ??
            InputValidator.validateStringField(company, field: "Company", maxLength: InputValidator.maxCompanyName) ??
            InputValidator.validateEmail(email) ??
            InputValidator.validatePhone(phone) {
            toastIsError = true
            withAnimation(reduceMotion ? nil : .default) { toastMessage = err }
            return
        }

        isSaving = true
        defer { isSaving = false }

        switch mode {
        case .add:
            let customer = Customer(
                firstName: firstName.trimmed, lastName: lastName.trimmed,
                company: company.trimmed, email: email.trimmed, phone: phone.trimmed,
                address: address.trimmed, city: city.trimmed, country: country.trimmed, zip: zip.trimmed,
                notes: notes.trimmed
            )
            modelContext.insert(customer)
            do {
                try modelContext.save()
                onSave?(customer)
                dismiss()
            } catch {
                toastIsError = true
                withAnimation(reduceMotion ? nil : .default) { toastMessage = "Failed to save customer: \(ErrorMapper.userMessage(from: error))" }
            }
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
            c.notes = notes.trimmed
            do {
                try modelContext.save()
                onSave?(c)
                dismiss()
            } catch {
                toastIsError = true
                withAnimation(reduceMotion ? nil : .default) { toastMessage = "Failed to save customer: \(ErrorMapper.userMessage(from: error))" }
            }
        }
    }
}
