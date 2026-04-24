import SwiftUI
import SwiftData

struct MemoReturnScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.rfidService) private var rfidService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scannedStones: [ScannedMemoStone] = []
    @State private var isScanning = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var batchMode = true
    @State private var showReturnConfirmation = false
    @State private var recentScans: [ScanLogEntry] = []

    struct ScannedMemoStone: Identifiable {
        let id = UUID()
        let stone: Gemstone
        let memo: Memo
        var confirmed = false
    }

    struct ScanLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let tag: String
        let result: String
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.hero) {
                    if scannedStones.isEmpty && recentScans.isEmpty {
                        EmptyStateView(
                            icon: "wave.3.right",
                            title: "Scan stones to return from memo",
                            subtitle: "Scan RFID tags of stones currently on memo to process returns"
                        )
                    } else {
                        if !scannedStones.isEmpty {
                            scannedList
                        }
                        recentScansLog
                    }
                }
                .padding(AppSpacing.hero)
            }
        }
        .accessibilityIdentifier("MemoReturnScanView")
        .overlay {
            if let msg = toastMessage {
                ToastOverlay(message: msg, isError: toastIsError)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation(reduceMotion ? nil : .default) { toastMessage = nil }
                        }
                    }
            }
        }
        .accessibilityIdentifier("MemoReturnScanView")
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: AppSpacing.comfortable) {
            Text("Memo Return Scanner")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)

            Spacer()

            Toggle("Batch Mode", isOn: $batchMode)
                .toggleStyle(.switch)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.inkMuted)
                .accessibilityLabel("Batch mode: scan multiple stones before confirming")

            if isScanning {
                HStack(spacing: AppSpacing.standard) {
                    ProgressView().controlSize(.small).tint(AppColors.primary)
                    Text("Scanning...")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                }
                Button {
                    stopScanning()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.outline(AppColors.danger))
            } else {
                Button("Start Scan", systemImage: "antenna.radiowaves.left.and.right") {
                    startScanning()
                }
                .buttonStyle(.gradient)
            }

            if !scannedStones.isEmpty && batchMode {
                Button("Return All (\(scannedStones.count))") {
                    showReturnConfirmation = true
                }
                .buttonStyle(.gradient(AppColors.emeraldGradient))
                .accessibilityLabel("Return all \(scannedStones.count) scanned stones from memo")
                .alert("Return \(scannedStones.count) items?", isPresented: $showReturnConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Return All", role: .destructive) { returnAll() }
                } message: {
                    Text("This will return \(scannedStones.count) scanned items to inventory. This cannot be undone.")
                }
            }

            Button("Clear") {
                scannedStones.removeAll()
            }
            .buttonStyle(.outline)
            .disabled(scannedStones.isEmpty)
        }
        .padding(.horizontal, AppSpacing.hero)
        .padding(.vertical, AppSpacing.section)
    }

    // MARK: - Scanned List

    private var scannedList: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Scanned Stones")

                ForEach(Array(scannedStones.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: AppSpacing.comfortable) {
                        Image(systemName: item.confirmed ? "checkmark.circle.fill" : "arrow.uturn.left.circle")
                            .foregroundStyle(item.confirmed ? AppColors.success : AppColors.warning)

                        VStack(alignment: .leading, spacing: AppSpacing.tight) {
                            HStack(spacing: AppSpacing.standard) {
                                Text(item.stone.sku)
                                    .font(AppTypography.mono)
                                    .foregroundStyle(AppColors.ink)
                                StoneTypeBadge(type: item.stone.stoneType.rawValue)
                                Text(String(format: "%.2f ct", item.stone.caratWeight))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                            }
                            Text("Memo: \(item.memo.referenceNumber) — \(item.memo.customer?.displayName ?? "Unknown")")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                        }

                        Spacer()

                        if item.confirmed {
                            StatusBadge(title: "Returned", tone: .success)
                        } else if !batchMode {
                            Button("Return") {
                                returnStone(at: index)
                            }
                            .buttonStyle(.outline(AppColors.success))
                            .accessibilityLabel("Return \(item.stone.sku) from memo")
                        }
                    }
                    .padding(.vertical, AppSpacing.standard)
                    .staggeredRow(index: index, reduceMotion: reduceMotion)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.stone.sku), on memo \(item.memo.referenceNumber), \(item.confirmed ? "returned" : "pending return")")
                }
            }
        }
    }

    // MARK: - Recent Scans Log

    private var recentScansLog: some View {
        GlassCard(padding: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader(title: "Recent Scans")

                if recentScans.isEmpty {
                    Text("No scans recorded yet")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkSubtle)
                } else {
                    ForEach(recentScans) { entry in
                        HStack(spacing: AppSpacing.comfortable) {
                            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkMuted)
                                .frame(width: 80, alignment: .leading)

                            Text(entry.tag.prefix(16) + (entry.tag.count > 16 ? "..." : ""))
                                .font(AppTypography.mono)
                                .foregroundStyle(AppColors.inkSubtle)
                                .lineLimit(1)
                                .frame(width: 140, alignment: .leading)

                            Text(entry.result)
                                .font(AppTypography.caption)
                                .foregroundStyle(entry.result.hasPrefix("Memo match") ? AppColors.success : entry.result.hasPrefix("Unknown") ? AppColors.danger : AppColors.warning)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.compact)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.timestamp.formatted(date: .omitted, time: .standard)): tag \(entry.tag), \(entry.result)")
                    }
                }
            }
        }
    }

    private func appendScanLog(tag: String, result: String) {
        let entry = ScanLogEntry(timestamp: Date(), tag: tag, result: result)
        recentScans.insert(entry, at: 0)
        if recentScans.count > 10 {
            recentScans = Array(recentScans.prefix(10))
        }
    }

    // MARK: - Actions

    private func startScanning() {
        guard let service = rfidService else { return }
        service.onTagDiscovered = { [self] tagID in
            Task { @MainActor in
                self.handleScannedTag(tagID)
            }
        }
        service.startScanning()
        isScanning = true
    }

    private func stopScanning() {
        rfidService?.stopScanning()
        rfidService?.onTagDiscovered = nil
        isScanning = false
        RFIDScanService.flushPendingSaves(modelContext)
    }

    private func handleScannedTag(_ rawHex: String) {
        let result = RFIDScanService.processScannedTag(rawHex: rawHex, modelContext: modelContext)

        switch result {
        case .matched(let stone):
            // Check if on active memo
            if stone.status == .onMemo, let memo = stone.memo, memo.status == .onMemo {
                // Avoid duplicates
                guard !scannedStones.contains(where: { $0.stone.persistentModelID == stone.persistentModelID }) else { return }
                scannedStones.append(ScannedMemoStone(stone: stone, memo: memo))
                appendScanLog(tag: rawHex, result: "Memo match: \(stone.sku)")
            } else {
                toastMessage = "\(stone.sku) is not on memo (status: \(stone.status.rawValue))"
                toastIsError = false
                appendScanLog(tag: rawHex, result: "Not on memo: \(stone.sku) (\(stone.status.rawValue))")
            }
        case .unknownTag(let epc, _):
            toastMessage = "Unknown tag: \(epc)"
            toastIsError = false
            appendScanLog(tag: epc, result: "Unknown tag")
        }
    }

    private func returnStone(at index: Int) {
        guard index < scannedStones.count else { return }
        let item = scannedStones[index]
        do {
            // Find the line item for this stone on this memo
            let lineItems = item.memo.lineItems.filter { $0.gemstone?.persistentModelID == item.stone.persistentModelID && $0.status == .open }
            guard !lineItems.isEmpty else {
                toastMessage = "No open line item found"
                toastIsError = true
                return
            }
            try MemoService.returnItems(lineItems, modelContext: modelContext)
            scannedStones[index].confirmed = true
            toastMessage = "\(item.stone.sku) returned successfully"
            toastIsError = false
        } catch {
            toastMessage = "Failed: \(error.localizedDescription)"
            toastIsError = true
        }
    }

    private func returnAll() {
        var successCount = 0
        for index in scannedStones.indices where !scannedStones[index].confirmed {
            let item = scannedStones[index]
            let lineItems = item.memo.lineItems.filter { $0.gemstone?.persistentModelID == item.stone.persistentModelID && $0.status == .open }
            guard !lineItems.isEmpty else { continue }
            do {
                try MemoService.returnItems(lineItems, modelContext: modelContext)
                scannedStones[index].confirmed = true
                successCount += 1
            } catch {
                continue
            }
        }
        toastMessage = "\(successCount) stone\(successCount == 1 ? "" : "s") returned"
        toastIsError = false
    }
}
