import SwiftUI
import SwiftData

struct CustomerListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CustomersViewModel()
    @State private var selectedCustomer: Customer?
    @State private var showAddCustomerSheet = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: customer list (constrained width)
            VStack(spacing: 0) {
                HStack {
                    Text("Customers")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Button {
                        showAddCustomerSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                HStack(spacing: AppSpacing.s) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("Search name, company, email…", text: $viewModel.searchText)
                        .appSearchField()
                }
                .padding(.horizontal)
                .padding(.bottom, AppSpacing.s)

                if viewModel.filteredCustomers.isEmpty {
                    ContentUnavailableView(
                        "No Customers",
                        systemImage: "person.2",
                        description: Text(viewModel.searchText.isEmpty ? "Customers will appear here." : "No customers match your search.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.filteredCustomers, selection: $selectedCustomer) { customer in
                        Text(customer.displayName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .tag(customer)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 320, maxWidth: 480)

            Divider()

            // Right: customer detail (fills remaining space)
            if let customer = selectedCustomer {
                ScrollView {
                    CustomerDetailView(customer: customer)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Select a Customer",
                    systemImage: "person.crop.circle",
                    description: Text("Select a customer to view details.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.load(modelContext: modelContext)
        }
        .sheet(isPresented: $showAddCustomerSheet) {
            NavigationStack {
                AddCustomerSheet { _ in
                    viewModel.load(modelContext: modelContext)
                }
            }
        }
    }
}
