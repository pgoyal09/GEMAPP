import SwiftUI
import SwiftData

struct CustomerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: [SortDescriptor(\Customer.lastName), SortDescriptor(\Customer.firstName)]) private var allCustomers: [Customer]
    @State private var viewModel = CustomerListViewModel()
    @State private var doubleClickedCustomer: Customer?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: AppSpacing.comfortable) {
                    GlassSearchField(text: $viewModel.searchText, placeholder: "Search customers…")
                        .frame(maxWidth: 300)
                    Spacer()
                    Button { viewModel.showAddCustomerSheet = true } label: {
                        Label("Add Customer", systemImage: "plus")
                    }
                    .buttonStyle(.gradient)
                }
                .padding(.horizontal, AppSpacing.hero)
                .padding(.vertical, AppSpacing.section)

                // Table
                customerTable

                // Sticky footer
                footerBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Overlay panel for double-clicked customer
            if let customer = doubleClickedCustomer {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { doubleClickedCustomer = nil }

                HStack(spacing: 0) {
                    Spacer()
                    CustomerFullDetailView(customer: customer, onDismiss: { doubleClickedCustomer = nil })
                        .frame(width: 380)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 20, x: -6)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                .padding(.vertical, AppSpacing.standard)
                .padding(.trailing, AppSpacing.standard)
            }
        }
        .accessibilityIdentifier("CustomerListView")
        .animation(reduceMotion ? nil : AppAnimation.sheetSpring, value: doubleClickedCustomer?.persistentModelID)
        .sheet(isPresented: $viewModel.showAddCustomerSheet) {
            CustomerFormSheet(mode: .add)
        }
    }

    // MARK: - Table

    private var customerTable: some View {
        let filtered = viewModel.filtered(from: allCustomers)
        return ScrollView(.vertical) {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 4) {
                    customerSortableHeader("Name", key: "name", width: TableColumn.customer)
                    customerSortableHeader("Company", key: "company", width: TableColumn.description)
                    customerSortableHeader("Email", key: "contact", width: TableColumn.description)
                    customerSortableHeader("Phone", key: "phone", width: TableColumn.memo)
                    customerSortableHeader("Open Memos", key: "memos", width: TableColumn.price, alignment: .trailing)
                    customerSortableHeader("Total Purchases", key: "purchases", width: TableColumn.price, alignment: .trailing)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.section)
                .padding(.vertical, AppSpacing.comfortable)

                Divider().background(AppColors.cardStroke)

                if filtered.isEmpty {
                    EmptyStateView(icon: "person.2", title: "No customers found")
                        .frame(maxWidth: .infinity)
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

                                Text(customer.company)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                                    .lineLimit(1)
                                    .frame(width: TableColumn.description, alignment: .leading)

                                Text(customer.email)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                                    .lineLimit(1)
                                    .frame(width: TableColumn.description, alignment: .leading)

                                Text(customer.phone)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                                    .lineLimit(1)
                                    .frame(width: TableColumn.memo, alignment: .leading)

                                Text("\(customer.activeMemos.count)")
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .frame(width: TableColumn.price, alignment: .trailing)

                                Text(customerTotalPurchases(customer).asCurrency)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .frame(width: TableColumn.price, alignment: .trailing)

                                Spacer()
                            }
                            .frame(height: 32)
                            .onTapGesture(count: 2) {
                                doubleClickedCustomer = customer
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.standard)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.hero)
    }

    // MARK: - Footer

    private var footerBar: some View {
        let filtered = viewModel.filtered(from: allCustomers)
        return HStack {
            Text("\(filtered.count) customer\(filtered.count == 1 ? "" : "s")")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.comfortable)
    }

    // MARK: - Helpers

    private func customerSortableHeader(_ title: String, key: String, width: CGFloat, alignment: Alignment = .leading) -> TableHeader {
        TableHeader(
            title: title,
            width: width,
            alignment: alignment,
            isSorted: viewModel.sortKey == key,
            ascending: viewModel.sortAscending,
            onTap: { viewModel.toggleSort(key) }
        )
    }

    private func customerTotalPurchases(_ customer: Customer) -> Decimal {
        var total = Decimal.zero
        for memo in customer.memos {
            for item in memo.lineItems where item.status == .sold {
                total += item.netAmount
            }
        }
        for invoice in customer.invoices {
            for item in invoice.lineItems {
                if item.originLineItem != nil { continue }
                total += item.netAmount
            }
        }
        return total
    }
}
