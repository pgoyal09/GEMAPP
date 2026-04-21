import SwiftUI

// MARK: - Filter Bar Configuration

/// Defines which filter groups are visible in the 3-row filter bar.
struct FilterBarConfig {
    var showStatusPills: Bool = true
    var showShapePills: Bool = true
    var showGroupingPills: Bool = true

    // Row 2
    var showColorPills: Bool = false       // Diamond-style D/E/F/G... pills
    var showColorDropdown: Bool = false     // Gemstone-style dropdown
    var showClarityPills: Bool = false      // Diamond-style IF/VVS1... pills
    var showClarityDropdown: Bool = false   // Gemstone-style dropdown
    var showCutDropdown: Bool = false       // Diamond cut picker
    var showOriginDropdown: Bool = false    // Gemstone origin
    var showTreatmentDropdown: Bool = false // Gemstone treatment
    var showStoneTypePicker: Bool = false   // Lot stone type

    // Row 3
    var showCaratRange: Bool = true
    var showPriceRange: Bool = true
    var showLabDropdown: Bool = true
    var showSearch: Bool = true

    static let diamonds = FilterBarConfig(
        showColorPills: true,
        showClarityPills: true,
        showCutDropdown: true
    )

    static let gemstones = FilterBarConfig(
        showColorDropdown: true,
        showClarityDropdown: true,
        showOriginDropdown: true,
        showTreatmentDropdown: true
    )

    static let lots = FilterBarConfig(
        showShapePills: false,
        showGroupingPills: false,
        showColorDropdown: true,
        showStoneTypePicker: true
    )

    static let inventory = FilterBarConfig(
        showColorPills: true,
        showClarityPills: true,
        showCutDropdown: true
    )
}

// MARK: - Top Shapes

private let topShapes = ["Round", "Cushion", "Oval", "Pear", "Emerald", "Princess", "Marquise"]

private let diamondColors = ["D", "E", "F", "G", "H", "I", "J", "K+"]

private let diamondClarities = ["IF", "VVS1", "VVS2", "VS1", "VS2", "SI1", "SI2", "I1+"]

private let cutGrades = ["Excellent", "Very Good", "Good", "Fair", "Poor"]

private let labOptions = ["GIA", "AGS", "IGI", "HRD", "EGL", "None"]

// MARK: - Inventory Filter Bar V2

struct InventoryFilterBarV2: View {
    let config: FilterBarConfig

    @Binding var statusFilter: GemstoneStatus?
    @Binding var shapeFilter: String?
    @Binding var groupingFilter: StoneGrouping?

    // Row 2
    @Binding var colorFilter: String?
    @Binding var clarityFilter: String?
    @Binding var cutFilter: String?
    @Binding var originFilter: String?
    @Binding var treatmentFilter: String?
    @Binding var stoneTypeFilter: StoneType?

    // Row 3
    @Binding var caratMinText: String
    @Binding var caratMaxText: String
    @Binding var priceMinText: String
    @Binding var priceMaxText: String
    @Binding var labFilter: String?
    @Binding var searchText: String
    @Binding var searchFieldFocusRequest: Bool

    var onClearAll: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.standard) {
            row1
            row2
            row3
        }
        .padding(.horizontal, AppSpacing.section)
        .padding(.vertical, AppSpacing.standard)
    }

    // MARK: - Row 1: Status + Shape + Grouping

    private var row1: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.section) {
                if config.showStatusPills {
                    statusGroup
                }

                if config.showShapePills {
                    filterDivider
                    shapeGroup
                }

                if config.showGroupingPills {
                    filterDivider
                    groupingGroup
                }
            }
        }
    }

    private var statusGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Status")
            FilterPill(title: "All", isActive: statusFilter == nil, action: { statusFilter = nil })
            ForEach(GemstoneStatus.allCases, id: \.rawValue) { status in
                FilterPill(
                    title: status.rawValue,
                    isActive: statusFilter == status,
                    action: { statusFilter = statusFilter == status ? nil : status }
                )
            }
        }
    }

    private var shapeGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Shape")
            FilterPill(title: "All", isActive: shapeFilter == nil, action: { shapeFilter = nil })
            ForEach(topShapes, id: \.self) { shape in
                FilterPill(
                    title: shape,
                    isActive: shapeFilter == shape,
                    action: { shapeFilter = shapeFilter == shape ? nil : shape }
                )
            }
            FilterPill(
                title: "Other",
                isActive: shapeFilter == "Other",
                action: { shapeFilter = shapeFilter == "Other" ? nil : "Other" }
            )
        }
    }

    private var groupingGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Group")
            FilterPill(title: "All", isActive: groupingFilter == nil, action: { groupingFilter = nil })
            ForEach(StoneGrouping.allCases, id: \.rawValue) { g in
                FilterPill(
                    title: g.displayName,
                    isActive: groupingFilter == g,
                    action: { groupingFilter = groupingFilter == g ? nil : g }
                )
            }
        }
    }

    // MARK: - Row 2: Color + Clarity + Cut / Origin / Treatment

    @ViewBuilder
    private var row2: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.section) {
                // Color
                if config.showColorPills {
                    colorPillsGroup
                } else if config.showColorDropdown {
                    colorDropdownGroup
                }

                // Clarity
                if config.showClarityPills {
                    filterDivider
                    clarityPillsGroup
                } else if config.showClarityDropdown {
                    filterDivider
                    clarityDropdownGroup
                }

                // Cut (diamonds only)
                if config.showCutDropdown {
                    filterDivider
                    cutDropdownGroup
                }

                // Origin (gemstones)
                if config.showOriginDropdown {
                    filterDivider
                    originDropdownGroup
                }

                // Treatment (gemstones)
                if config.showTreatmentDropdown {
                    filterDivider
                    treatmentDropdownGroup
                }

                // Stone Type (lots)
                if config.showStoneTypePicker {
                    filterDivider
                    stoneTypePickerGroup
                }
            }
        }
    }

    private var colorPillsGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Color")
            FilterPill(title: "All", isActive: colorFilter == nil, action: { colorFilter = nil })
            ForEach(diamondColors, id: \.self) { color in
                FilterPill(
                    title: color,
                    isActive: colorFilter == color,
                    action: { colorFilter = colorFilter == color ? nil : color }
                )
            }
        }
    }

    private var colorDropdownGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Color")
            TextField("Any color", text: Binding(
                get: { colorFilter ?? "" },
                set: { colorFilter = $0.isEmpty ? nil : $0 }
            ))
            .font(AppTypography.caption)
            .glassField()
            .frame(width: 100)
        }
    }

    private var clarityPillsGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Clarity")
            FilterPill(title: "All", isActive: clarityFilter == nil, action: { clarityFilter = nil })
            ForEach(diamondClarities, id: \.self) { clarity in
                FilterPill(
                    title: clarity,
                    isActive: clarityFilter == clarity,
                    action: { clarityFilter = clarityFilter == clarity ? nil : clarity }
                )
            }
        }
    }

    private var clarityDropdownGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Clarity")
            TextField("Any clarity", text: Binding(
                get: { clarityFilter ?? "" },
                set: { clarityFilter = $0.isEmpty ? nil : $0 }
            ))
            .font(AppTypography.caption)
            .glassField()
            .frame(width: 100)
        }
    }

    private var cutDropdownGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Cut")
            Picker("Cut", selection: Binding(
                get: { cutFilter ?? "" },
                set: { cutFilter = $0.isEmpty ? nil : $0 }
            )) {
                Text("All").tag("")
                ForEach(cutGrades, id: \.self) { grade in
                    Text(grade).tag(grade)
                }
            }
            .labelsHidden()
            .frame(width: 120)
        }
    }

    private var originDropdownGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Origin")
            TextField("Any origin", text: Binding(
                get: { originFilter ?? "" },
                set: { originFilter = $0.isEmpty ? nil : $0 }
            ))
            .font(AppTypography.caption)
            .glassField()
            .frame(width: 100)
        }
    }

    private var treatmentDropdownGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Treatment")
            Menu {
                Button("All") { treatmentFilter = nil }
                Divider()
                ForEach(["Heated", "Unheated", "Oiled", "None"], id: \.self) { treatment in
                    Button(treatment) { treatmentFilter = treatment }
                }
            } label: {
                HStack(spacing: AppSpacing.compact) {
                    Text(treatmentFilter ?? "All")
                        .font(AppTypography.caption)
                        .foregroundStyle(treatmentFilter != nil ? AppColors.primary : AppColors.inkSubtle)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppColors.inkSubtle)
                }
                .padding(.horizontal, AppSpacing.standard)
                .padding(.vertical, AppSpacing.compact)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                        .fill(treatmentFilter != nil ? AppColors.primary.opacity(0.20) : Color.white.opacity(AppOpacity.faint))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                .strokeBorder(
                                    treatmentFilter != nil ? AppColors.primary.opacity(0.20) : Color.white.opacity(AppOpacity.dim),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var stoneTypePickerGroup: some View {
        HStack(spacing: AppSpacing.compact) {
            filterLabel("Type")
            Picker("Stone Type", selection: Binding(
                get: { stoneTypeFilter },
                set: { stoneTypeFilter = $0 }
            )) {
                Text("All Types").tag(StoneType?.none)
                ForEach(StoneType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(StoneType?.some(type))
                }
            }
            .labelsHidden()
            .frame(width: 140)
        }
    }

    // MARK: - Row 3: Ranges + Lab + Search + Clear

    private var row3: some View {
        HStack(spacing: AppSpacing.section) {
            // Carat range
            if config.showCaratRange {
                HStack(spacing: AppSpacing.compact) {
                    filterLabel("Carat")
                    TextField("Min", text: $caratMinText)
                        .font(AppTypography.caption)
                        .glassField()
                        .frame(width: 60)
                    Text("–")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("Max", text: $caratMaxText)
                        .font(AppTypography.caption)
                        .glassField()
                        .frame(width: 60)
                }
            }

            // Price range
            if config.showPriceRange {
                HStack(spacing: AppSpacing.compact) {
                    filterLabel("Price")
                    TextField("Min $", text: $priceMinText)
                        .font(AppTypography.caption)
                        .glassField()
                        .frame(width: 70)
                    Text("–")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkSubtle)
                    TextField("Max $", text: $priceMaxText)
                        .font(AppTypography.caption)
                        .glassField()
                        .frame(width: 70)
                }
            }

            // Lab dropdown
            if config.showLabDropdown {
                HStack(spacing: AppSpacing.compact) {
                    filterLabel("Lab")
                    Picker("Lab", selection: Binding(
                        get: { labFilter ?? "" },
                        set: { labFilter = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("All").tag("")
                        ForEach(labOptions, id: \.self) { lab in
                            Text(lab).tag(lab)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
            }

            // Search
            if config.showSearch {
                GlassSearchField(text: $searchText, placeholder: "Search SKU, color...", requestFocus: $searchFieldFocusRequest)
                    .frame(minWidth: 140, maxWidth: 260)
            }

            Spacer(minLength: 0)

            // Clear All
            Button {
                onClearAll()
            } label: {
                Text("Clear All")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func filterLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.inkSubtle)
    }

    private var filterDivider: some View {
        Divider()
            .frame(height: 20)
    }
}
