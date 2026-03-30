import SwiftUI
import SwiftData

struct CustomerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Customer.lastName), SortDescriptor(\Customer.firstName)]) private var allCustomers: [Customer]
    @State private var viewModel = CustomerListViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Left: list
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    GlassSearchField(text: $viewModel.searchText, placeholder: "Search customers…")
                        .frame(maxWidth: 300)
                    Spacer()
                    Button { viewModel.showAddCustomerSheet = true } label: {
                        Label("Add Customer", systemImage: "plus")
                    }
                    .buttonStyle(.gradient)
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.m)

                customerTable
            }
            .frame(maxWidth: .infinity)

            // Right: detail
            if let id = viewModel.selectedCustomerID,
               let customer = allCustomers.first(where: { $0.persistentModelID == id }) {
                CustomerDetailPanel(customer: customer)
            }
        }
        .sheet(isPresented: $viewModel.showAddCustomerSheet) {
            CustomerFormSheet(mode: .add)
        }
    }

    private let customerTableMinWidth: CGFloat =
        TableColumn.customer + TableColumn.description + TableColumn.quantity + TableColumn.status + 60

    private var customerTable: some View {
        let filtered = viewModel.filtered(from: allCustomers)
        return ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    TableHeader(title: "Name", width: TableColumn.customer)
                    TableHeader(title: "Contact", width: TableColumn.description)
                    TableHeader(title: "Open Memos", width: TableColumn.quantity)
                    TableHeader(title: "Status", width: TableColumn.status)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)

                Divider().background(AppColors.cardStroke)

                if filtered.isEmpty {
                    EmptyStateView(icon: "person.2", title: "No customers found")
                        .frame(minWidth: customerTableMinWidth)
                        .frame(height: 200)
                } else {
                    VStack(spacing: 2) {
                        ForEach(filtered) { customer in
                            let isSelected = viewModel.selectedCustomerID == customer.persistentModelID
                            HoverRow(isSelected: isSelected, onTap: {
                                viewModel.selectedCustomerID = customer.persistentModelID
                            }) {
                                Text(customer.displayName)
                                    .font(AppTypography.body.weight(.medium))
                                    .foregroundStyle(AppColors.ink)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: TableColumn.customer, alignment: .leading)

                                HStack(spacing: 8) {
                                    if !customer.email.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "envelope").font(.system(size: 10))
                                            Text(customer.email).lineLimit(1)
                                        }
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                    }
                                    if !customer.phone.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "phone").font(.system(size: 10))
                                            Text(customer.phone).lineLimit(1)
                                        }
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                    }
                                }
                                .frame(width: TableColumn.description, alignment: .leading)

                                Text("\(customer.activeMemos.count)")
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .lineLimit(1)
                                    .frame(width: TableColumn.quantity, alignment: .center)

                                StatusBadge(
                                    title: customer.isActive ? "Active" : "Inactive",
                                    tone: customer.isActive ? .success : .neutral
                                )
                                .frame(width: TableColumn.status, alignment: .leading)

                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
            }
            .frame(minWidth: customerTableMinWidth, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassTable()
        .padding(.horizontal, AppSpacing.l)
        .padding(.bottom, AppSpacing.l)
    }
}
