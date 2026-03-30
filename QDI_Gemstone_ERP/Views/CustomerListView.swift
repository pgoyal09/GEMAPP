import SwiftUI
import SwiftData

struct CustomerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Customer.lastName), SortDescriptor(\Customer.firstName)]) private var customers: [Customer]
    @State private var selectedCustomerID: PersistentIdentifier?
    @State private var showAddCustomerSheet = false
    @State private var showEditCustomerSheet = false
    @State private var searchText: String = ""

    private var filteredCustomers: [Customer] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return customers }
        return customers.filter { customer in
            customer.displayName.lowercased().contains(q) ||
            (customer.email ?? "").lowercased().contains(q) ||
            (customer.company ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text("Customers")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    GradientButton(title: "Add Customer", icon: "plus") {
                        showAddCustomerSheet = true
                    }
                }
                .padding(AppSpacing.l)

                GlassSearchField(text: $searchText, placeholder: "Search by name, email, or company…")
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.bottom, AppSpacing.m)

                if customers.isEmpty {
                    ContentUnavailableView(
                        "No Customers",
                        systemImage: "person.2",
                        description: Text("Customers will appear here.")
                    )
                    .foregroundStyle(AppColors.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    customerTable
                }
            }
            .frame(maxWidth: .infinity)

            if let id = selectedCustomerID,
               let customer = filteredCustomers.first(where: { $0.id == id }) {
                VStack(spacing: 0) {
                    HStack {
                        Text(customer.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                        Spacer()
                        Button("Edit") {
                            showEditCustomerSheet = true
                        }
                        .buttonStyle(OutlineGlassButtonStyle())
                        .font(.system(size: 12))
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.vertical, AppSpacing.m)
                    .background(Color.white.opacity(0.03))
                    Divider().background(AppColors.cardStroke)
                    ScrollView {
                        CustomerDetailView(customer: customer)
                    }
                }
                .frame(minWidth: InspectorWidth.min, idealWidth: InspectorWidth.ideal, maxWidth: InspectorWidth.max)
                .frame(maxHeight: .infinity)
                .background(AppColors.panelBackground)
                .sheet(isPresented: $showEditCustomerSheet) {
                    NavigationStack {
                        CustomerFormSheet(mode: .edit(customer)) { _ in
                            showEditCustomerSheet = false
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.shellGradient)
        .sheet(isPresented: $showAddCustomerSheet) {
            NavigationStack {
                CustomerFormSheet(mode: .add) { _ in }
            }
        }
    }

    // MARK: - Customer Table

    private var customerTable: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                tableHeader
                Divider().background(Color.white.opacity(0.06))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredCustomers, id: \.id) { customer in
                            customerRow(customer)
                            Divider().background(Color.white.opacity(0.03))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("CUSTOMER")
                .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
            Text("CONTACT")
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            Text("OPEN MEMOS")
                .frame(width: 90, alignment: .trailing)
            Text("STATUS")
                .frame(width: 80, alignment: .leading)
                .padding(.leading, AppSpacing.m)
        }
        .sectionLabel(tracking: 0.8)
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.s)
        .background(Color.white.opacity(0.03))
    }

    private func customerRow(_ customer: Customer) -> some View {
        let isSelected = selectedCustomerID == customer.id
        return AppTableHoverRow(isSelected: isSelected, onTap: { selectedCustomerID = customer.id }) {
            HStack(spacing: 0) {
                Text(customer.displayName)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    if let email = customer.email, !email.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope")
                                .font(.system(size: 10))
                            Text(email)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.40))
                        .lineLimit(1)
                    }
                    if let phone = customer.phone, !phone.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "phone")
                                .font(.system(size: 10))
                            Text(phone)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.inkSubtle)
                        .lineLimit(1)
                    }
                }
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

                Text("\(customer.activeMemos.count)")
                    .font(AppTypography.body)
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.70))
                    .frame(width: 90, alignment: .trailing)

                statusBadge(for: customer)
                    .frame(width: 80, alignment: .leading)
                    .padding(.leading, AppSpacing.m)
            }
            .padding(.horizontal, AppSpacing.l)
        }
    }

    private func statusBadge(for customer: Customer) -> some View {
        let isActive = !customer.activeMemos.isEmpty
        return Text(isActive ? "Active" : "Inactive")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isActive ? AppColors.success : AppColors.inkSubtle)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? AppColors.success.opacity(0.15) : Color.white.opacity(0.06))
            )
    }
}
