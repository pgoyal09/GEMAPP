import SwiftUI
import SwiftData

struct CustomerListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CustomersViewModel()
    @State private var selectedCustomerID: PersistentIdentifier?
    @State private var showAddCustomerSheet = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: customer list (constrained width)
            VStack(spacing: 0) {
                HStack {
                    Text("Customers")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
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
                TextField("Search by name, email, or company…", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                if viewModel.customers.isEmpty {
                    ContentUnavailableView(
                        "No Customers",
                        systemImage: "person.2",
                        description: Text("Customers will appear here.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.filteredCustomers, id: \.id, selection: $selectedCustomerID) { customer in
                        Text(customer.displayName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .tag(customer.id)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 320, maxWidth: 480)

            Divider()

            // Right: customer detail (fills remaining space)
            if let id = selectedCustomerID,
               let customer = viewModel.filteredCustomers.first(where: { $0.id == id }) {
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
