import SwiftUI

/// Always-visible 3-row filter panel used by InventoryListView.
struct InventoryFilterBar: View {
    @Bindable var viewModel: InventoryViewModel
    @Namespace private var statusNS
    @Namespace private var shapeNS
    @Namespace private var groupingNS

    private let shapes = ["Round", "Cushion", "Oval", "Pear", "Emerald", "Princess", "Marquise", "Other"]
    private let labs = ["GIA", "AGS", "IGI", "HRD", "EGL", "None"]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.standard) {
            rowOne
            rowTwo
            rowThree
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.standard)
        .background(AppColors.cardBackground.opacity(0.5))
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColors.cardStroke).frame(height: 1)
        }
    }

    // MARK: - Row 1: Status | Shape | Grouping

    private var rowOne: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.compact) {
                groupLabel("Status")
                ForEach(InventoryStatusFilter.allCases, id: \.rawValue) { filter in
                    FilterPill(
                        title: filter.rawValue,
                        isActive: viewModel.statusFilter == filter,
                        action: { viewModel.statusFilter = filter },
                        animationNamespace: statusNS
                    )
                }

                pillDivider

                groupLabel("Shape")
                ForEach(shapes, id: \.self) { shape in
                    FilterPill(
                        title: shape,
                        isActive: viewModel.shapeFilter == shape,
                        action: {
                            withAnimation(AppAnimation.spring) {
                                viewModel.shapeFilter = viewModel.shapeFilter == shape ? nil : shape
                            }
                        },
                        animationNamespace: shapeNS
                    )
                }

                pillDivider

                groupLabel("Grouping")
                FilterPill(title: "All", isActive: viewModel.groupingFilter == nil, action: {
                    withAnimation(AppAnimation.spring) { viewModel.groupingFilter = nil }
                }, animationNamespace: groupingNS)
                ForEach(StoneGrouping.allCases) { g in
                    FilterPill(
                        title: g.displayName,
                        isActive: viewModel.groupingFilter == g,
                        action: {
                            withAnimation(AppAnimation.spring) {
                                viewModel.groupingFilter = viewModel.groupingFilter == g ? nil : g
                            }
                        },
                        animationNamespace: groupingNS
                    )
                }
            }
            .padding(.horizontal, AppSpacing.compact)
        }
    }

    // MARK: - Row 2: Stone Type | Color | Clarity | Origin | Treatment | Cut

    private var rowTwo: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.comfortable) {
                filterField(label: "Stone Type") {
                    Picker("Type", selection: Binding(
                        get: { viewModel.stoneTypeFilter },
                        set: { viewModel.stoneTypeFilter = $0 }
                    )) {
                        Text("Any").tag(StoneType?.none)
                        ForEach(StoneType.allCases) { type in
                            Text(type.rawValue).tag(StoneType?.some(type))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                    .glassField()
                }

                filterField(label: "Color") {
                    TextField("Any", text: Binding(
                        get: { viewModel.colorFilter ?? "" },
                        set: { viewModel.colorFilter = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(width: 85)
                    .glassField()
                }

                filterField(label: "Clarity") {
                    TextField("Any", text: Binding(
                        get: { viewModel.clarityFilter ?? "" },
                        set: { viewModel.clarityFilter = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(width: 85)
                    .glassField()
                }

                filterField(label: "Origin") {
                    TextField("Any", text: Binding(
                        get: { viewModel.originFilter ?? "" },
                        set: { viewModel.originFilter = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(width: 100)
                    .glassField()
                }

                filterField(label: "Treatment") {
                    TextField("Any", text: Binding(
                        get: { viewModel.treatmentFilter ?? "" },
                        set: { viewModel.treatmentFilter = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(width: 100)
                    .glassField()
                }

                if viewModel.showDiamondFilters {
                    filterField(label: "Cut") {
                        Picker("Cut", selection: Binding(
                            get: { viewModel.cutFilter },
                            set: { viewModel.cutFilter = $0 }
                        )) {
                            Text("Any").tag(String?.none)
                            ForEach(["Excellent", "Very Good", "Good", "Fair", "Poor"], id: \.self) { cut in
                                Text(cut).tag(String?.some(cut))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                        .glassField()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.compact)
        }
    }

    // MARK: - Row 3: Carat | Price | Lab | Search | Clear All

    private var rowThree: some View {
        HStack(spacing: AppSpacing.standard) {
            groupLabel("Carat")
            TextField("Min", text: $viewModel.caratMinText)
                .onChange(of: viewModel.caratMinText) { _, v in
                    viewModel.caratMin = v.isEmpty ? nil : Double(v)
                }
                .frame(width: 65)
                .glassField()
            Text("–")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            TextField("Max", text: $viewModel.caratMaxText)
                .onChange(of: viewModel.caratMaxText) { _, v in
                    viewModel.caratMax = v.isEmpty ? nil : Double(v)
                }
                .frame(width: 65)
                .glassField()

            rowDivider

            groupLabel("Price")
            TextField("Min $", text: $viewModel.sellMinText)
                .onChange(of: viewModel.sellMinText) { _, v in
                    viewModel.sellMin = v.isEmpty ? nil : Decimal(string: v)
                }
                .frame(width: 75)
                .glassField()
            TextField("Max $", text: $viewModel.sellMaxText)
                .onChange(of: viewModel.sellMaxText) { _, v in
                    viewModel.sellMax = v.isEmpty ? nil : Decimal(string: v)
                }
                .frame(width: 75)
                .glassField()

            rowDivider

            groupLabel("Lab")
            labMenu

            rowDivider

            GlassSearchField(text: $viewModel.searchText, placeholder: "Search by SKU, type, color...")
                .frame(minWidth: 160, maxWidth: 280)

            Spacer(minLength: AppSpacing.compact)

            if viewModel.hasActiveFilters || !viewModel.searchText.isEmpty {
                Button("Clear All") {
                    viewModel.clearAllFilters()
                }
                .buttonStyle(.plain)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.danger)
            }
        }
        .padding(.horizontal, AppSpacing.compact)
    }

    // MARK: - Lab Menu

    private var labMenu: some View {
        Menu {
            Button { viewModel.labFilter = nil } label: {
                HStack {
                    Text("All Labs")
                    if viewModel.labFilter == nil { Image(systemName: "checkmark") }
                }
            }
            Divider()
            ForEach(labs, id: \.self) { lab in
                Button { viewModel.labFilter = lab } label: {
                    HStack {
                        Text(lab)
                        if viewModel.labFilter == lab { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: AppSpacing.compact) {
                Text(viewModel.labFilter ?? "All")
                    .font(AppTypography.caption)
                    .foregroundStyle(viewModel.labFilter != nil ? AppColors.primary : AppColors.inkSubtle)
                Image(systemName: "chevron.down")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppColors.inkSubtle)
            }
            .padding(.horizontal, AppSpacing.standard)
            .padding(.vertical, AppSpacing.compact)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                            .strokeBorder(Color.white.opacity(AppOpacity.dim), lineWidth: 1)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Helpers

    private var pillDivider: some View {
        Rectangle()
            .fill(AppColors.cardStroke)
            .frame(width: 1, height: 20)
            .padding(.horizontal, AppSpacing.standard)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AppColors.cardStroke)
            .frame(width: 1, height: 20)
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.inkSubtle)
    }

    private func filterField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.tight) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkSubtle)
            content()
        }
    }
}
