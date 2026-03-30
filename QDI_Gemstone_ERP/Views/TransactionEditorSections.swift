import SwiftUI
import SwiftData

// MARK: - TransactionEditorView Section Extensions

extension TransactionEditorView {

    var referenceLabel: String {
        switch mode {
        case .invoice: return "Reference"
        case .memo, .editMemo: return "Memo Number"
        }
    }

    var referencePlaceholder: String {
        switch mode {
        case .invoice: return "Optional"
        case .memo, .editMemo: return "1001"
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customer")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    HStack(spacing: 8) {
                        Picker("", selection: $viewModel.customer) {
                            Text("Select customer…").tag(nil as Customer?)
                            ForEach(customers, id: \.id) { customer in
                                Text(customer.displayName).tag(customer as Customer?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                        Button {
                            showAddCustomerSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 140)
                }
                if case .invoice = mode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terms")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        Picker("", selection: $viewModel.terms) {
                            Text("Net 30").tag("Net 30")
                            Text("Net 60").tag("Net 60")
                            Text("Due on receipt").tag("Due on receipt")
                            Text("COD").tag("COD")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(referenceLabel)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField(referencePlaceholder, text: $viewModel.referenceNumber)
                        .textFieldStyle(.plain)
                        .glassField()
                        .frame(width: 120)
                }
            }
        }
    }

    var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Line Items")
                    .font(AppTypography.heading)
                Spacer()
            }

            if viewModel.items.isEmpty {
                Text("No line items. Use \"Add Line\" to add from inventory or add a custom line (e.g. Shipping).")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.inkSubtle)
                    .frame(maxWidth: .infinity)
                    .padding(32)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    lineItemHeader
                    Divider()
                    List(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        TransactionLineRowView(
                            item: item,
                            index: index,
                            viewModel: viewModel
                        )
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                }
            }
            HStack(spacing: AppSpacing.m) {
                Button("+ From Inventory") { showInventorySheet = true }
                    .buttonStyle(.borderless)
                Button("+ Brokered Stone") { viewModel.addBrokeredLine() }
                    .buttonStyle(.borderless)
                Button("+ Custom Line") { viewModel.addServiceLine() }
                    .buttonStyle(.borderless)
            }
            .font(.subheadline)
            .foregroundStyle(AppColors.primary)
        }
    }

    var footerSection: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Text("Subtotal")
                        .foregroundStyle(AppColors.inkSubtle)
                    Text(viewModel.subtotal.asCurrency)
                        .frame(width: 100, alignment: .trailing)
                }
                .font(.subheadline)
                if viewModel.tax > 0 {
                    HStack {
                        Text("Tax")
                            .foregroundStyle(AppColors.inkSubtle)
                        Text(viewModel.tax.asCurrency)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .font(.subheadline)
                }
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Text(viewModel.total.asCurrency)
                        .fontWeight(.semibold)
                        .frame(width: 100, alignment: .trailing)
                }
            }
        }
        .padding(.top, 4)
    }

    var lineItemHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("SKU").frame(width: 80, alignment: .leading)
            Text("Description").frame(minWidth: 180, alignment: .leading)
            Text("Carats").frame(width: 60, alignment: .trailing)
            Text("Rate").frame(width: 80, alignment: .trailing)
            Text("Amount").frame(width: 80, alignment: .trailing)
            Spacer().frame(width: 32)
        }
        .font(.caption)
        .foregroundStyle(AppColors.inkSubtle)
        .padding(.vertical, 4)
    }
}
