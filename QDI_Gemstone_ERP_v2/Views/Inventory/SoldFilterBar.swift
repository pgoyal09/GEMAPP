import SwiftUI

struct SoldFilterBar: View {
    @Binding var customerFilter: String
    @Binding var dateFrom: Date?
    @Binding var dateTo: Date?
    @Binding var caratMin: Double?
    @Binding var caratMax: Double?
    @Binding var priceMin: Decimal?
    @Binding var priceMax: Decimal?
    @Binding var stoneTypeFilter: StoneType?
    var customers: [String]

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.section),
        GridItem(.flexible(), spacing: AppSpacing.section),
    ]

    var body: some View {
        GlassCard(padding: AppSpacing.section, cornerRadius: AppCornerRadius.large) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Filters")

                LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.section) {
                    // Customer filter
                    filterField(label: "Customer") {
                        Picker("Customer", selection: $customerFilter) {
                            Text("All Customers").tag("")
                            ForEach(customers, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .glassField()
                    }

                    // Stone type
                    filterField(label: "Stone Type") {
                        Picker("Type", selection: $stoneTypeFilter) {
                            Text("Any").tag(StoneType?.none)
                            ForEach(StoneType.allCases) { type in
                                Text(type.rawValue).tag(StoneType?.some(type))
                            }
                        }
                        .labelsHidden()
                        .glassField()
                    }

                    // Date range
                    filterField(label: "Sold After") {
                        DatePicker("From", selection: Binding(
                            get: { dateFrom ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())! },
                            set: { dateFrom = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .glassField()
                    }

                    filterField(label: "Sold Before") {
                        DatePicker("To", selection: Binding(
                            get: { dateTo ?? Date() },
                            set: { dateTo = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .glassField()
                    }

                    // Carat range
                    filterField(label: "Carat Range") {
                        HStack(spacing: AppSpacing.standard) {
                            TextField("Min", text: Binding(
                                get: { caratMin.map { String(format: "%.2f", $0) } ?? "" },
                                set: { caratMin = Double($0) }
                            ))
                            .glassField()

                            Text("to")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)

                            TextField("Max", text: Binding(
                                get: { caratMax.map { String(format: "%.2f", $0) } ?? "" },
                                set: { caratMax = Double($0) }
                            ))
                            .glassField()
                        }
                    }

                    // Price range
                    filterField(label: "Sold Price") {
                        HStack(spacing: AppSpacing.standard) {
                            TextField("Min $", text: Binding(
                                get: { priceMin.map { "\($0)" } ?? "" },
                                set: { priceMin = Decimal(string: $0) }
                            ))
                            .glassField()

                            Text("to")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)

                            TextField("Max $", text: Binding(
                                get: { priceMax.map { "\($0)" } ?? "" },
                                set: { priceMax = Decimal(string: $0) }
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
