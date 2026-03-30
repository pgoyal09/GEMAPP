import SwiftUI
import SwiftData
import AppKit

struct MemosView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.documentDirtyTracker) private var documentDirtyTracker
    @Environment(\.navigationGuard) private var navigationGuard
    @Query(sort: \Memo.createdAt, order: .reverse) private var allMemos: [Memo]
    @State private var selectedMemoID: PersistentIdentifier?
    @State private var selectedTab: MemosTab = .open

    private var openMemos: [Memo] { allMemos.filter { !$0.isClosed } }
    private var closedMemos: [Memo] { allMemos.filter { $0.isClosed } }
    
    enum MemosTab: String, CaseIterable {
        case open = "Open Memos"
        case closed = "Closed Memos"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.m) {
                HStack(spacing: 0) {
                    ForEach(MemosTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedTab == tab ? .white : Color.white.opacity(0.40))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedTab == tab ? AppColors.primary : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                Spacer()
                if selectedTab == .open {
                    Button {
                        let memo = TransactionViewModel.createNewMemo(modelContext: modelContext)
                        openWindow(id: "memo", value: memo.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .medium))
                            Text("New Memo")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primaryGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: AppColors.primary.opacity(0.20), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("n", modifiers: .command)
                    Button {
                        openSelectedMemo()
                    } label: {
                        Text("Open")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedMemoID == nil)
                    .keyboardShortcut("o", modifiers: .command)
                }
            }
            .padding(AppSpacing.l)
            if selectedTab == .open {
                openMemosContent
            } else {
                closedMemosContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .background {
            Button("") { openSelectedMemo() }
                .keyboardShortcut(.return, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        .onAppear {
            if let id = selectedMemoID, !allMemos.contains(where: { $0.id == id }) {
                selectedMemoID = nil
            }
            navigationGuard?.reportDirty(documentDirtyTracker?.hasUnsavedMemo ?? false)
        }
        .onChange(of: selectedTab) { _, _ in
            if selectedTab == .open {
                if let id = selectedMemoID, !openMemos.contains(where: { $0.id == id }) {
                    selectedMemoID = nil
                }
            } else {
                if let id = selectedMemoID, !closedMemos.contains(where: { $0.id == id }) {
                    selectedMemoID = nil
                }
            }
        }
        .onChange(of: documentDirtyTracker?.hasUnsavedMemo ?? false) { _, dirty in
            navigationGuard?.reportDirty(dirty)
        }
        .onDisappear {
            navigationGuard?.reportDirty(false)
        }
    }
    
    private var openMemosContent: some View {
        Group {
            if openMemos.isEmpty {
                ContentUnavailableView(
                    "No Open Memos",
                    systemImage: "doc.text",
                    description: Text("Create a memo to send stones on consignment.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        AppTableHeader(columns: [
                            .init("MEMO #", width: 100),
                            .init("CUSTOMER"),
                            .init("MEMO DATE", width: 100),
                            .init("DAYS OLD", width: 70),
                            .init("MEMO AMOUNT", width: 110, alignment: .trailing),
                            .init("CUSTOMER EXPOSURE", width: 130, alignment: .trailing)
                        ])
                        Divider().overlay(AppColors.cardStroke)
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(openMemos) { memo in
                                    AppTableHoverRow(
                                        isSelected: selectedMemoID == memo.id,
                                        onTap: {
                                            selectedMemoID = memo.id
                                            openWindow(id: "memo", value: memo.id)
                                        }
                                    ) {
                                        HStack(spacing: 0) {
                                            Text(memo.referenceNumber ?? "—")
                                                .font(.system(size: 13, design: .monospaced))
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(width: 100, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(memo.customer?.displayName ?? "—")
                                                .font(.system(size: 13))
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(memo.dateAssigned ?? Date(), style: .date)
                                                .font(.system(size: 13))
                                                .foregroundStyle(AppColors.inkMuted)
                                                .frame(width: 100, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            daysOldView(memo)
                                                .frame(width: 70, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            memoAmountView(memo)
                                                .frame(width: 110)
                                                .padding(.horizontal, 4)
                                            Group {
                                                if let customer = memo.customer {
                                                    Text(customer.openExposure, format: .currency(code: "USD"))
                                                        .monospacedDigit()
                                                        .foregroundStyle(AppColors.inkMuted)
                                                } else {
                                                    Text("—").foregroundStyle(AppColors.inkSubtle)
                                                }
                                            }
                                            .frame(width: 130, alignment: .trailing)
                                            .padding(.horizontal, 4)
                                        }
                                        .padding(.horizontal, AppSpacing.l)
                                    }
                                    .contextMenu {
                                        Button("Open") { openWindow(id: "memo", value: memo.id) }
                                    }
                                    Divider().overlay(AppColors.cardStroke)
                                }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var closedMemosContent: some View {
        Group {
            if closedMemos.isEmpty {
                ContentUnavailableView(
                    "No Closed Memos",
                    systemImage: "doc.text",
                    description: Text("Closed memos will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        AppTableHeader(columns: [
                            .init("MEMO #", width: 100),
                            .init("CUSTOMER"),
                            .init("MEMO DATE", width: 100),
                            .init("MEMO AMOUNT", width: 110, alignment: .trailing),
                            .init("CUSTOMER EXPOSURE", width: 130, alignment: .trailing)
                        ])
                        Divider().overlay(AppColors.cardStroke)
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(closedMemos) { memo in
                                    AppTableHoverRow(
                                        isSelected: selectedMemoID == memo.id,
                                        onTap: {
                                            selectedMemoID = memo.id
                                            openWindow(id: "memo", value: memo.id)
                                        }
                                    ) {
                                        HStack(spacing: 0) {
                                            Text(memo.referenceNumber ?? "—")
                                                .font(.system(size: 13, design: .monospaced))
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(width: 100, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(memo.customer?.displayName ?? "—")
                                                .font(.system(size: 13))
                                                .foregroundStyle(AppColors.ink)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            Text(memo.dateAssigned ?? Date(), style: .date)
                                                .font(.system(size: 13))
                                                .foregroundStyle(AppColors.inkMuted)
                                                .frame(width: 100, alignment: .leading)
                                                .padding(.horizontal, 4)
                                            memoAmountView(memo)
                                                .frame(width: 110)
                                                .padding(.horizontal, 4)
                                            Group {
                                                if let customer = memo.customer {
                                                    Text(customer.openExposure, format: .currency(code: "USD"))
                                                        .monospacedDigit()
                                                        .foregroundStyle(AppColors.inkMuted)
                                                } else {
                                                    Text("—").foregroundStyle(AppColors.inkSubtle)
                                                }
                                            }
                                            .frame(width: 130, alignment: .trailing)
                                            .padding(.horizontal, 4)
                                        }
                                        .padding(.horizontal, AppSpacing.l)
                                    }
                                    .contextMenu {
                                        Button("Open") { openWindow(id: "memo", value: memo.id) }
                                    }
                                    Divider().overlay(AppColors.cardStroke)
                                }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.m, style: .continuous))
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func memoAmountView(_ memo: Memo) -> some View {
        Group {
            if memo.isClosed {
                Text("Closed")
                    .foregroundStyle(AppColors.inkMuted)
            } else {
                Text(memo.openMemoAmount, format: .currency(code: "USD"))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.80))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func daysOldView(_ memo: Memo) -> some View {
        let days = daysSince(memo.dateAssigned ?? Date())
        let label = days == 0 ? "0d" : "\(days)d"
        return HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text(label)
                .fontWeight(.medium)
        }
        .foregroundStyle(daysOldColor(days))
    }

    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    private func daysOldColor(_ days: Int) -> Color {
        switch days {
        case 0..<30: return AppColors.success
        case 30..<60: return AppColors.warning
        case 60..<90: return AppColors.accentPeach
        default: return AppColors.danger
        }
    }

    private func openSelectedMemo() {
        guard let id = selectedMemoID else { return }
        openWindow(id: "memo", value: id)
    }

    private func memoDisplayTitle(_ memo: Memo) -> String {
        let ref = memo.referenceNumber.map { "#\($0) " } ?? ""
        let name = memo.customer?.displayName ?? "Unknown"
        return "Memo \(ref)– \(name)"
    }
}
