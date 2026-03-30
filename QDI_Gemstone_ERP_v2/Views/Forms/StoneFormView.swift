import SwiftUI
import SwiftData

struct StoneFormView: View {
    @State var viewModel: StoneFormViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCaratFieldFocused: Bool

    init(mode: StoneFormMode) {
        _viewModel = State(initialValue: StoneFormViewModel(mode: mode))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.l) {
                    identitySection
                    gradingSection
                    if viewModel.isDiamond { diamondSection }
                    if viewModel.isLot { lotSection }
                    certificationSection
                    dimensionsSection
                    pricingSection
                }
                .padding(AppSpacing.l)
            }
            bottomToolbar
        }
        .onAppear {
            if case .intake = viewModel.mode {
                viewModel.refreshSKU(modelContext: modelContext)
            }
            isCaratFieldFocused = true
        }
        .alert("SKU Already Exists", isPresented: $viewModel.showSKUConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Use Anyway") { viewModel.commitSKUChange() }
        } message: {
            Text("A stone with SKU '\(viewModel.pendingSKU)' already exists.")
        }
        .overlay {
            if let msg = viewModel.toastMessage {
                ToastOverlay(message: msg, isError: viewModel.toastIsError)
                    .animation(.easeInOut, value: viewModel.toastMessage)
            }
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Stone Identity")
                HStack(spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SKU").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("SKU", text: $viewModel.sku)
                            .glassField()
                            .font(AppTypography.mono)
                            .disabled(!viewModel.mode.isEditing && viewModel.mode.existingStone == nil)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        Picker("", selection: $viewModel.stoneTypeText) {
                            ForEach(StoneType.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Stone Type")
                        .onChange(of: viewModel.stoneTypeText) { _, _ in viewModel.refreshSKU(modelContext: modelContext) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shape").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("Shape", text: $viewModel.shapeText).glassField()
                            .onChange(of: viewModel.shapeText) { _, _ in viewModel.refreshSKU(modelContext: modelContext) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grouping").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        Picker("", selection: $viewModel.grouping) {
                            ForEach(StoneGrouping.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Stone Grouping")
                        .onChange(of: viewModel.grouping) { _, _ in viewModel.refreshSKU(modelContext: modelContext) }
                    }
                }
                HStack(spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Carats").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("0.00", text: $viewModel.caratText)
                            .glassField()
                            .focused($isCaratFieldFocused)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Origin").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                        TextField("Origin", text: $viewModel.origin).glassField()
                    }
                }
            }
        }
    }

    // MARK: - Grading

    private var gradingSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Grading")
                HStack(spacing: AppSpacing.m) {
                    field("Treatment", $viewModel.treatment)
                }
            }
        }
    }

    // MARK: - Diamond-Specific

    private var diamondSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Diamond Grading")
                HStack(spacing: AppSpacing.m) {
                    field("Color", $viewModel.color)
                    field("Clarity", $viewModel.clarity)
                    field("Cut", $viewModel.cut)
                }
                HStack(spacing: AppSpacing.m) {
                    field("Polish", $viewModel.polish)
                    field("Symmetry", $viewModel.symmetry)
                    field("Fluorescence", $viewModel.fluorescence)
                }
            }
        }
    }

    // MARK: - Lot-Specific

    private var lotSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Lot Details")
                HStack(spacing: AppSpacing.m) {
                    field("Size Range", $viewModel.size)
                    field("Quality", $viewModel.quality)
                }
            }
        }
    }

    // MARK: - Certification

    private var certificationSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Certification")
                Toggle("Has Certificate", isOn: $viewModel.hasCert)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(AppColors.inkMuted)
                    .accessibilityLabel("Has Certificate")
                if viewModel.hasCert {
                    HStack(spacing: AppSpacing.m) {
                        field("Lab", $viewModel.certLab)
                        field("Cert No.", $viewModel.certNo)
                    }
                }
            }
        }
    }

    // MARK: - Dimensions

    private var dimensionsSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Dimensions (mm)")
                HStack(spacing: AppSpacing.m) {
                    field("Length", $viewModel.lengthText)
                    field("Width", $viewModel.widthText)
                    field("Height", $viewModel.heightText)
                }
                if viewModel.isPair {
                    HStack(spacing: AppSpacing.m) {
                        field("Length 2", $viewModel.length2Text)
                        field("Width 2", $viewModel.width2Text)
                        field("Height 2", $viewModel.height2Text)
                    }
                }
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        GlassCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                SectionHeader(title: "Pricing")
                HStack(spacing: AppSpacing.m) {
                    field("Cost Price", $viewModel.costPriceText)
                    field("Sell Price", $viewModel.sellPriceText)
                }
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }.buttonStyle(.outline)

            if case .intake = viewModel.mode {
                Button("Save & Continue") {
                    do {
                        try viewModel.saveAndContinue(modelContext: modelContext)
                    } catch {
                        viewModel.toastMessage = "Save failed: \(error.localizedDescription)"
                        viewModel.toastIsError = true
                    }
                }
                .buttonStyle(.outline(AppColors.primary))
            }

            Button("Save") {
                do {
                    try viewModel.save(modelContext: modelContext)
                    if viewModel.toastIsError == false { dismiss() }
                } catch {
                    viewModel.toastMessage = "Save failed: \(error.localizedDescription)"
                    viewModel.toastIsError = true
                }
            }
            .buttonStyle(.gradient)
            .disabled(!viewModel.canSave)
        }
        .padding(AppSpacing.m)
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .top) { Divider().background(Color.white.opacity(0.06)) }
    }

    // MARK: - Helper

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
            TextField(label, text: text).glassField()
        }
    }
}
