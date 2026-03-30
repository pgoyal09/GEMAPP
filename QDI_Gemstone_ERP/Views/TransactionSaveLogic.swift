import SwiftUI
import SwiftData

// MARK: - TransactionEditorView Save Logic

extension TransactionEditorView {

    func saveInvoice() {
        guard let customer = viewModel.customer else { return }
        let ref = viewModel.referenceNumber.isEmpty ? TransactionViewModel.generateNextInvoiceNumber(modelContext: modelContext) : viewModel.referenceNumber
        let invoice = Invoice(
            invoiceDate: viewModel.date,
            dueDate: viewModel.dueDate,
            terms: viewModel.terms,
            referenceNumber: ref.isEmpty ? nil : ref,
            notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
            customer: customer
        )
        modelContext.insert(invoice)

        for draft in viewModel.lineItems {
            let amount = draft.isService ? draft.rate : draft.rate * Decimal(draft.carats)
            let item = LineItem(
                sku: draft.sku,
                itemDescription: draft.description,
                carats: draft.carats,
                rate: draft.rate,
                amount: amount,
                gemstone: draft.gemstone,
                isService: draft.isService,
                brokeredStoneType: draft.isBrokered && !draft.brokeredStoneType.isEmpty ? draft.brokeredStoneType : nil
            )
            modelContext.insert(item)
            item.invoice = invoice

            if let stone = draft.gemstone {
                stone.memo = nil
                stone.status = .sold
                logEvent(stone: stone, type: .sold, message: "Sold to \(customer.displayName)", modelContext: modelContext)
            }
        }
        #if DEBUG
        let stoneCount = viewModel.lineItems.compactMap(\.gemstone).count
        if stoneCount > 0 {
            print("[Invoice] Saved \(stoneCount) gemstone(s) with status=Sold; no gemstones deleted.")
        }
        #endif
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
            viewModel.reset()
            dismiss()
        } catch {
            saveErrorMessage = "Failed to save invoice: \(error.localizedDescription)"
        }
    }

    func saveMemo() {
        guard let customer = viewModel.customer else { return }

        let memo = Memo(
            status: .onMemo,
            dateAssigned: viewModel.date,
            notes: viewModel.notes.isEmpty ? nil : viewModel.notes,
            referenceNumber: viewModel.referenceNumber.isEmpty ? nil : viewModel.referenceNumber,
            customer: customer
        )
        modelContext.insert(memo)

        for draft in viewModel.lineItems {
            let amount = draft.isService ? draft.rate : draft.rate * Decimal(draft.carats)
            let item = LineItem(
                sku: draft.sku,
                itemDescription: draft.description,
                carats: draft.carats,
                rate: draft.rate,
                amount: amount,
                gemstone: draft.gemstone,
                isService: draft.isService,
                brokeredStoneType: draft.isBrokered && !draft.brokeredStoneType.isEmpty ? draft.brokeredStoneType : nil
            )
            modelContext.insert(item)
            item.memo = memo

            if let stone = draft.gemstone {
                stone.memo = memo
                stone.status = .onMemo
                logEvent(stone: stone, type: .sentToCustomer, message: "Sent to \(customer.displayName)", modelContext: modelContext)
            }
        }

        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
            viewModel.reset()
            dismiss()
        } catch {
            saveErrorMessage = "Failed to save memo: \(error.localizedDescription)"
        }
    }

    func saveEditedMemo(_ memo: Memo) {
        guard let customer = viewModel.customer else { return }

        memo.customer = customer
        memo.dateAssigned = viewModel.date
        memo.notes = viewModel.notes.isEmpty ? nil : viewModel.notes
        memo.referenceNumber = viewModel.referenceNumber.isEmpty ? nil : viewModel.referenceNumber

        let existingItems = Array(memo.lineItems)
        for existing in existingItems {
            if let stone = existing.gemstone {
                stone.memo = nil
                stone.status = .available
            }
            modelContext.delete(existing)
        }

        for draft in viewModel.lineItems {
            let amount = draft.isService ? draft.rate : draft.rate * Decimal(draft.carats)
            let item = LineItem(
                sku: draft.sku,
                itemDescription: draft.description,
                carats: draft.carats,
                rate: draft.rate,
                amount: amount,
                gemstone: draft.gemstone,
                isService: draft.isService,
                brokeredStoneType: draft.isBrokered && !draft.brokeredStoneType.isEmpty ? draft.brokeredStoneType : nil
            )
            modelContext.insert(item)
            item.memo = memo

            if let stone = draft.gemstone {
                stone.memo = memo
                logEvent(stone: stone, type: .sentToCustomer, message: "Sent to \(customer.displayName)", modelContext: modelContext)
            }
        }

        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .memoOrInvoiceDidSave, object: nil)
            viewModel.reset()
            dismiss()
        } catch {
            saveErrorMessage = "Failed to save memo: \(error.localizedDescription)"
        }
    }
}
