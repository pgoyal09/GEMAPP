import SwiftUI
import SwiftData

/// Reusable button that prints an RFID label and encodes the tag for a gemstone.
/// Drop into any view that has access to the environment's ZebraPrintService.
struct PrintTagButton: View {
    let gemstone: Gemstone
    var style: ButtonVariant = .pill

    @Environment(\.zebraPrintService) private var printService
    @Environment(\.modelContext) private var modelContext
    @State private var isPrinting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    enum ButtonVariant {
        case pill
        case contextMenu
        case icon
    }

    var body: some View {
        Group {
            switch style {
            case .pill:
                Button {
                    printTag()
                } label: {
                    HStack(spacing: 5) {
                        if isPrinting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: showSuccess ? "checkmark.circle.fill" : "printer.fill")
                                .font(.system(size: 12))
                        }
                        Text(showSuccess ? "Printed" : "Print Tag")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(showSuccess ? AppColors.success : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(showSuccess ? AppColors.success.opacity(0.15) : AppColors.primary.opacity(0.80))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isPrinting)

            case .contextMenu:
                Button {
                    printTag()
                } label: {
                    Label(
                        isPrinting ? "Printing…" : "Print RFID Tag",
                        systemImage: "printer.fill"
                    )
                }
                .disabled(isPrinting)

            case .icon:
                Button {
                    printTag()
                } label: {
                    if isPrinting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: showSuccess ? "checkmark.circle.fill" : "printer.fill")
                            .foregroundStyle(showSuccess ? AppColors.success : AppColors.primary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPrinting)
                .help("Print RFID Tag")
            }
        }
        .alert("Print Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func printTag() {
        guard let printService else {
            errorMessage = "Print service not available."
            return
        }
        guard !printService.printerIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Printer IP not configured. Set it in the RFID section of a stone's detail view."
            return
        }

        isPrinting = true
        showSuccess = false
        errorMessage = nil

        Task {
            do {
                try await printService.printAndEncode(stone: gemstone, modelContext: modelContext)
                await MainActor.run {
                    isPrinting = false
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { showSuccess = false }
            } catch {
                await MainActor.run {
                    isPrinting = false
                    errorMessage = error.localizedDescription
                    printService.status = .error
                    printService.lastError = error.localizedDescription
                }
            }
        }
    }
}

/// Compact inline view showing printer connection status + IP config field.
struct PrinterConfigView: View {
    @Environment(\.zebraPrintService) private var printService
    @State private var ipText: String = ""
    @State private var selectedProfile: PrintProfile = .profile2
    @State private var isChecking = false
    @State private var isOnline: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkMuted)
                Spacer()
                if isChecking {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Test") { checkConnection() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                }
            }
            HStack(spacing: 6) {
                TextField("Printer IP (e.g. 192.168.1.100)", text: $ipText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColors.ink)
                    .onSubmit { saveIP() }
                Button("Save") { saveIP() }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            )

            HStack(spacing: 8) {
                Text("Print Profile")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                Picker("", selection: $selectedProfile) {
                    ForEach(PrintProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: selectedProfile) { _, newValue in
                    printService?.printProfile = newValue
                }
                Spacer()
                Text("Temporary testing mode")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.inkMuted)
            }
        }
        .onAppear {
            ipText = printService?.printerIP ?? ""
            selectedProfile = printService?.printProfile ?? .profile2
        }
    }

    private var statusColor: Color {
        guard let isOnline else { return AppColors.inkSubtle }
        return isOnline ? AppColors.success : AppColors.danger
    }

    private var statusLabel: String {
        guard let isOnline else { return "Printer: Not tested" }
        return isOnline ? "Printer: Online" : "Printer: Offline"
    }

    private func saveIP() {
        printService?.printerIP = ipText.trimmingCharacters(in: .whitespacesAndNewlines)
        isOnline = nil
    }

    private func checkConnection() {
        isChecking = true
        isOnline = nil
        Task {
            let online = await printService?.checkConnection() ?? false
            await MainActor.run {
                isOnline = online
                isChecking = false
            }
        }
    }
}
