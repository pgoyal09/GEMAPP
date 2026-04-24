import Foundation
import SwiftData
import os

/// Generates PDFs for multiple invoices and saves them into a single folder.
@MainActor
enum BatchPDFExporter {

    private static let logger = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "pdf.batch")

    /// Generates PDFs for each invoice and writes them to a new temporary directory.
    /// Returns the URL of the directory containing all generated PDFs.
    static func exportInvoices(_ invoices: [Invoice]) async throws -> URL {
        logger.info("Batch PDF export started for \(invoices.count) invoices")
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

        logger.info("Batch PDF export completed: \(invoices.count) invoices to \(batchDir.lastPathComponent, privacy: .public)")
        return batchDir
    }

    /// Generates PDFs for each memo and writes them to a new temporary directory.
    static func exportMemos(_ memos: [Memo]) async throws -> URL {
        logger.info("Batch PDF export started for \(memos.count) memos")
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

        logger.info("Batch PDF export completed: \(memos.count) memos to \(batchDir.lastPathComponent, privacy: .public)")
        return batchDir
    }
}
