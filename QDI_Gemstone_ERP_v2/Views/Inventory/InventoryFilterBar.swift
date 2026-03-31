import SwiftUI

/// Inline filter panel that appears below the search bar when toggled.
struct InventoryFilterBar: View {
    @Bindable var viewModel: InventoryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.section),
        GridItem(.flexible(), spacing: AppSpacing.section),
    ]

    var body: some View {
        GlassCard(padding: AppSpacing.section, cornerRadius: AppCornerRadius.large) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Filters")

                LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.section) {
                    // Stone type
                    filterField(label: "Stone Type") {
                        Picker("Stone Type", selection: Binding(
                            get: { viewModel.stoneTypeFilter },
                            set: { viewModel.stoneTypeFilter = $0 }
                        )) {
                            Text("Any").tag(StoneType?.none)
                            ForEach(StoneType.allCases) { type in
                                Text(type.rawValue).tag(StoneType?.some(type))
                            }
                        }
                        .labelsHidden()
                        .glassField()
                    }

                    // Shape
                    filterField(label: "Shape") {
                        TextField("e.g. Round, Oval", text: Binding(
                            get: { viewModel.shapeFilter ?? "" },
                            set: { viewModel.shapeFilter = $0.isEmpty ? nil : $0 }
                        ))
                        .glassField()
                    }

                    // Certified
                    filterField(label: "Certified") {
                        Picker("Certified", selection: $viewModel.certifiedFilter) {
                            ForEach(CertifiedFilter.allCases, id: \.rawValue) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .labelsHidden()
                        .glassField()
                    }

                    // Treatment
                    filterField(label: "Treatment") {
                        TextField("e.g. None, Heated", text: Binding(
                            get: { viewModel.treatmentFilter ?? "" },
                            set: { viewModel.treatmentFilter = $0.isEmpty ? nil : $0 }
                        ))
                        .glassField()
                    }

                    // Grouping
                    filterField(label: "Grouping") {
                        Picker("Grouping", selection: Binding(
                            get: { viewModel.groupingFilter },
                            set: { viewModel.groupingFilter = $0 }
                        )) {
                            Text("Any").tag(StoneGrouping?.none)
                            ForEach(StoneGrouping.allCases) { g in
                                Text(g.displayName).tag(StoneGrouping?.some(g))
                            }
                        }
                        .labelsHidden()
                        .glassField()
                    }

                    // Carat range
                    filterField(label: "Carat Range") {
                        HStack(spacing: AppSpacing.standard) {
                            TextField("Min", text: Binding(
                                get: { viewModel.caratMin.map { String(format: "%.2f", $0) } ?? "" },
                                set: { viewModel.caratMin = Double($0) }
                            ))
                            .glassField()

                            Text("to")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)

                            TextField("Max", text: Binding(
                                get: { viewModel.caratMax.map { String(format: "%.2f", $0) } ?? "" },
                                set: { viewModel.caratMax = Double($0) }
                            ))
                            .glassField()
                        }
                    }

                    // Sell price range
                    filterField(label: "Sell Price") {
                        HStack(spacing: AppSpacing.standard) {
                            TextField("Min $", text: Binding(
                                get: { viewModel.sellMin.map { "\($0)" } ?? "" },
                                set: { viewModel.sellMin = Decimal(string: $0) }
                            ))
                            .glassField()

                            Text("to")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)

                            TextField("Max $", text: Binding(
                                get: { viewModel.sellMax.map { "\($0)" } ?? "" },
                                set: { viewModel.sellMax = Decimal(string: $0) }
                            ))
                            .glassField()
                        }
                    }

                    // Diamond-specific: Color
                    if viewModel.showDiamondFilters {
                        filterField(label: "Color") {
                            TextField("e.g. D, E, F", text: Binding(
                                get: { viewModel.colorFilter ?? "" },
                                set: { viewModel.colorFilter = $0.isEmpty ? nil : $0 }
                            ))
                            .glassField()
                        }

                        // Diamond-specific: Clarity
                        filterField(label: "Clarity") {
                            TextField("e.g. VVS1, VS2", text: Binding(
                                get: { viewModel.clarityFilter ?? "" },
                                set: { viewModel.clarityFilter = $0.isEmpty ? nil : $0 }
                            ))
                            .glassField()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func filterField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            content()
        }
    }
}
