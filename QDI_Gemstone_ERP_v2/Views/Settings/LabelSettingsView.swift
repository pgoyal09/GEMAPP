import SwiftUI
import SwiftData

struct LabelSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("labelTemplate") private var selectedTemplate: String = LabelTemplate.standard.rawValue
    @AppStorage("printerHost") private var printerHost: String = "localhost"
    @AppStorage("printerPort") private var printerPort: Int = 9100

    @State private var previewStone: Gemstone?
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var isPrinting = false

    private var template: LabelTemplate {
        LabelTemplate(rawValue: selectedTemplate) ?? .standard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.hero) {
            templatePicker
            printerConfig
            previewSection
        }
        .onAppear { loadPreviewStone() }
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
                        }
                    }
            }
        }
        .accessibilityIdentifier("LabelSettingsView")
    }

    private func loadPreviewStone() {
        let descriptor = FetchDescriptor<Gemstone>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        var d = descriptor
        d.fetchLimit = 1
        previewStone = try? modelContext.fetch(d).first
    }

    // MARK: - Template Picker

    private var templatePicker: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Label Template")

                ForEach(LabelTemplate.allCases, id: \.self) { tmpl in
                    Button {
                        selectedTemplate = tmpl.rawValue
                    } label: {
                        HStack(spacing: AppSpacing.comfortable) {
                            Image(systemName: tmpl.rawValue == selectedTemplate ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(tmpl.rawValue == selectedTemplate ? AppColors.primary : AppColors.inkSubtle)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tmpl.rawValue)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.ink)
                                Text(tmpl.description)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                            }

                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.standard)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tmpl.rawValue) template: \(tmpl.description)")
                    .accessibilityAddTraits(tmpl.rawValue == selectedTemplate ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Printer Config

    private var printerConfig: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Printer Configuration")

                HStack(spacing: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("Printer IP / Host")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        TextField("localhost", text: $printerHost)
                            .glassField()
                            .accessibilityLabel("Printer host address")
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("Port")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        TextField("9100", value: $printerPort, format: .number)
                            .glassField()
                            .frame(width: 100)
                            .accessibilityLabel("Printer port")
                    }
                }

                Button {
                    Task { await testPrint() }
                } label: {
                    HStack(spacing: AppSpacing.standard) {
                        if isPrinting {
                            ProgressView().controlSize(.small)
                        }
                        Text("Test Print")
                    }
                }
                .buttonStyle(.outline)
                .disabled(isPrinting)
                .accessibilityLabel("Send test label to printer")

                Text("Default: localhost:9100 (Zebra ZD611R via USB)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        GlassCard(padding: AppSpacing.hero) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Label Preview")

                if let stone = previewStone {
                    Text(LabelTemplateService.previewText(for: stone, template: template))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppColors.ink)
                        .padding(AppSpacing.comfortable)
                        .background(
                            RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                .fill(AppColors.cardBackground)
                        )
                        .accessibilityLabel("Label preview for \(stone.sku)")
                } else {
                    Text("No stones in inventory for preview")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                }

                Text("2\" × 1\" — Zebra ZD611R compatible (ZPL)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
            }
        }
    }

    // MARK: - Actions

    private func testPrint() async {
        guard let stone = previewStone else {
            toastMessage = "No stone available for test"
            toastIsError = true
            return
        }
        isPrinting = true
        let zpl = LabelTemplateService.generateZPL(for: stone, template: template)
        do {
            try await LabelTemplateService.printLabel(zpl: zpl, host: printerHost, port: UInt16(printerPort))
            toastMessage = "Test label sent to printer"
            toastIsError = false
        } catch {
            toastMessage = "Print failed: \(error.localizedDescription)"
            toastIsError = true
        }
        isPrinting = false
    }
}
