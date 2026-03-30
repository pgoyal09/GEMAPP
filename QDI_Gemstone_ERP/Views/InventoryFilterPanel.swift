import SwiftUI

extension InventoryListView {
    var inlineFilterPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Divider()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.m) {
                // Shape
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shape")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("Any", text: Binding(
                        get: { viewModel.shapeFilter ?? "" },
                        set: { viewModel.shapeFilter = $0.isEmpty ? nil : $0 }
                    ))
                    .appSearchField()
                }

                // Certified
                VStack(alignment: .leading, spacing: 4) {
                    Text("Certified")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    Picker("", selection: $viewModel.certifiedFilter) {
                        ForEach(CertifiedFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Treatment
                VStack(alignment: .leading, spacing: 4) {
                    Text("Treatment")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("Any", text: Binding(
                        get: { viewModel.treatmentFilter ?? "" },
                        set: { viewModel.treatmentFilter = $0.isEmpty ? nil : $0 }
                    ))
                    .appSearchField()
                }

                // Single / Pair / Lot
                VStack(alignment: .leading, spacing: 4) {
                    Text("Single / Pair / Lot")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    Picker("", selection: Binding(
                        get: { viewModel.groupingFilter ?? "" },
                        set: { viewModel.groupingFilter = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Any").tag("")
                        Text("Single").tag("S")
                        Text("Pair").tag("P")
                        Text("Lot").tag("L")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Carat min
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carat min")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("0", text: Binding(
                        get: { viewModel.caratMin.map { String(format: "%.2f", $0) } ?? "" },
                        set: { viewModel.caratMin = Double($0) }
                    ))
                    .appSearchField()
                }

                // Carat max
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carat max")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("Any", text: Binding(
                        get: { viewModel.caratMax.map { String(format: "%.2f", $0) } ?? "" },
                        set: { viewModel.caratMax = $0.isEmpty ? nil : Double($0) }
                    ))
                    .appSearchField()
                }

                // Sell min
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sell min")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("0", text: Binding(
                        get: { viewModel.sellMin.map { "\($0)" } ?? "" },
                        set: { viewModel.sellMin = Decimal(string: $0) }
                    ))
                    .appSearchField()
                }

                // Sell max
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sell max")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("Any", text: Binding(
                        get: { viewModel.sellMax.map { "\($0)" } ?? "" },
                        set: { viewModel.sellMax = Decimal(string: $0) }
                    ))
                    .appSearchField()
                }

                // Diamond-only: Color
                if viewModel.showDiamondFilters {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Color")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        TextField("e.g. D-F", text: Binding(
                            get: { viewModel.colorFilter ?? "" },
                            set: { viewModel.colorFilter = $0.isEmpty ? nil : $0 }
                        ))
                        .appSearchField()
                    }
                }

                // Diamond-only: Clarity
                if viewModel.showDiamondFilters {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clarity")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        TextField("e.g. VS1+", text: Binding(
                            get: { viewModel.clarityFilter ?? "" },
                            set: { viewModel.clarityFilter = $0.isEmpty ? nil : $0 }
                        ))
                        .appSearchField()
                    }
                }
            }
            .padding(.horizontal)
            Divider()
        }
        .padding(.vertical, AppSpacing.s)
    }
}
