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
                if viewModel.customers.isEmpty {
                    ContentUnavailableView(
                        "No Customers",
                        systemImage: "person.2",
                        description: Text("Customers will appear here.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.customers, selection: $selectedCustomer) { customer in
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
