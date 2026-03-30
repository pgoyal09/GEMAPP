import Foundation
import SwiftData

/// Generates PDFs for multiple invoices and saves them into a single folder.
@MainActor
enum BatchPDFExporter {

    /// Generates PDFs for each invoice and writes them to a new temporary directory.
    /// Returns the URL of the directory containing all generated PDFs.
    static func exportInvoices(_ invoices: [Invoice]) async throws -> URL {
        let batchDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("batch-pdf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: batchDir, withIntermediateDirectories: true)

        for invoice in invoices {
            let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                PDFService.shared.generatePDF(invoice: invoice) { result in
                    continuation.resume(with: result)
                }
            }
            let destName = "Invoice-\(invoice.referenceNumber.isEmpty ? invoice.persistentModelID.hashValue.description : invoice.referenceNumber).pdf"
            let destURL = batchDir.appendingPathComponent(destName)
            try FileManager.default.moveItem(at: url, to: destURL)
        }

        return batchDir
    }

    /// Generates PDFs for each memo and writes them to a new temporary directory.
    static func exportMemos(_ memos: [Memo]) async throws -> URL {
        let batchDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("batch-pdf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: batchDir, withIntermediateDirectories: true)

        for memo in memos {
            let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                PDFService.shared.generatePDF(memo: memo) { result in
                    continuation.resume(with: result)
                }
            }
            let destName = "Memo-\(memo.referenceNumber.isEmpty ? memo.persistentModelID.hashValue.description : memo.referenceNumber).pdf"
            let destURL = batchDir.appendingPathComponent(destName)
            try FileManager.default.moveItem(at: url, to: destURL)
        }

        return batchDir
    }
}
