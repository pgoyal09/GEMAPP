import Foundation
import WebKit
#if canImport(AppKit)
import AppKit
#endif

/// Generates PDFs from Invoice or Memo by rendering HTML via WKWebView.
final class PDFService {

    static let shared = PDFService()

    /// UserDefaults key for stored company logo image data (e.g. from file picker).
    static let companyLogoUserDefaultsKey = "companyLogoImageData"

    /// Company name used in the document header when no custom name is set.
    var companyName: String { "Quality Diajewels Inc." }

    private let letterWidth: CGFloat = 612
    private let letterHeight: CGFloat = 792

    private init() {}

    // MARK: - Public API

    func generatePDF(invoice: Invoice, completion: @escaping (Result<URL, Error>) -> Void) {
        let html = buildHTML(
            documentTitle: "INVOICE",
            companyName: companyName,
            customerAddress: formatAddress(invoice.customer),
            metaLines: invoiceMetaLines(invoice),
            lineItems: Array(invoice.lineItems),
            subtotal: invoiceSubtotal(invoice),
            tax: nil,
            grandTotal: invoiceTotal(invoice),
            notes: invoice.notes,
            logoBase64: loadLogoBase64()
        )
        renderHTMLToPDF(html: html, completion: completion)
    }

    func generatePDF(memo: Memo, completion: @escaping (Result<URL, Error>) -> Void) {
        let html = buildHTML(
            documentTitle: "MEMO",
            companyName: companyName,
            customerAddress: formatAddress(memo.customer),
            metaLines: memoMetaLines(memo),
            lineItems: Array(memo.lineItems),
            subtotal: memoSubtotal(memo),
            tax: nil,
            grandTotal: memoTotal(memo),
            notes: memo.notes,
            logoBase64: loadLogoBase64()
        )
        renderHTMLToPDF(html: html, completion: completion)
    }

    // MARK: - Logo

    private func loadLogoBase64() -> String? {
        guard let data = UserDefaults.standard.data(forKey: Self.companyLogoUserDefaultsKey),
              !data.isEmpty else { return nil }
        return data.base64EncodedString()
    }

    /// Call from UI after user picks a logo image to store it for PDF generation.
    static func saveCompanyLogo(_ imageData: Data) {
        UserDefaults.standard.set(imageData, forKey: companyLogoUserDefaultsKey)
    }

    // MARK: - HTML Template

    private func buildHTML(
        documentTitle: String,
        companyName: String,
        customerAddress: String,
        metaLines: [String],
        lineItems: [LineItem],
        subtotal: Decimal,
        tax: Decimal?,
        grandTotal: Decimal,
        notes: String?,
        logoBase64: String?
    ) -> String {
        let logoImg: String
        if let base64 = logoBase64 {
            logoImg = #"<img src="data:image/png;base64,\#(base64)" alt="Logo" class="logo" />"#
        } else {
            logoImg = ""
        }

        let metaBlock = metaLines.map { "<p class=\"meta-line\">\($0)</p>" }.joined(separator: "\n")
        let rows = lineItems.map { item in
            """
            <tr>
                <td>\(escape(item.displaySku))</td>
                <td>\(escape(item.displayName))</td>
                <td class="num">\(escape(item.displayCarats))</td>
                <td class="num">\(escape(item.displayRate))</td>
                <td class="num">\(escape(item.displayAmount))</td>
            </tr>
            """
        }.joined(separator: "\n")

        let taxRow: String
        if let t = tax, t > 0 {
            taxRow = "<tr><td colspan=\"4\" class=\"label\">Tax</td><td class=\"num\">\(formatCurrency(t))</td></tr>"
        } else {
            taxRow = ""
        }

        let notesBlock: String
        if let n = notes, !n.isEmpty {
            notesBlock = """
            <div class="notes">
                <strong>Notes</strong><br/>
                \(escape(n))
            </div>
            """
        } else {
            notesBlock = ""
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                * { box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; font-size: 11pt; color: #000; background: #fff; margin: 0; padding: 24px; }
                .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 24px; }
                .logo { max-height: 56px; max-width: 180px; }
                .company { text-align: right; color: #333; }
                .doc-title { font-size: 22pt; font-weight: 700; margin: 16px 0; }
                .bill-to { margin: 16px 0; }
                .bill-to strong { display: block; margin-bottom: 4px; }
                .meta-line { margin: 2px 0; color: #444; }
                table { width: 100%; border-collapse: collapse; margin: 16px 0; }
                th, td { border: 1px solid #000; padding: 8px 10px; text-align: left; }
                th { background: #f0f0f0; font-weight: 600; }
                td.num { text-align: right; }
                .totals { margin-left: auto; width: 240px; margin-top: 8px; }
                .totals tr { border: none; }
                .totals td { border: none; border-top: 1px solid #000; padding: 4px 8px; }
                .totals .label { text-align: right; }
                .totals .num { text-align: right; font-weight: 600; }
                .notes { margin-top: 20px; padding: 10px; background: #f8f8f8; border-radius: 4px; }
                @media print { body { -webkit-print-color-adjust: exact; print-color-adjust: exact; } }
            </style>
        </head>
        <body>
            <div class="header">
                <div>\(logoImg)</div>
                <div class="company">\(escape(companyName))</div>
            </div>
            <h1 class="doc-title">\(escape(documentTitle))</h1>
            <div class="meta">\(metaBlock)</div>
            <div class="bill-to">
                <strong>Bill To</strong>
                \(customerAddress.isEmpty ? "<p>—</p>" : "<p>\(escape(customerAddress))</p>")
            </div>
            <table>
                <thead>
                    <tr>
                        <th>SKU</th>
                        <th>Description</th>
                        <th>Carats</th>
                        <th>Rate</th>
                        <th>Amount</th>
                    </tr>
                </thead>
                <tbody>
                    \(rows)
                </tbody>
            </table>
            <table class="totals">
                <tr><td class="label">Subtotal</td><td class="num">\(formatCurrency(subtotal))</td></tr>
                \(taxRow)
                <tr><td class="label">Total</td><td class="num">\(formatCurrency(grandTotal))</td></tr>
            </table>
            \(notesBlock)
        </body>
        </html>
        """
    }

    private func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private func formatAddress(_ customer: Customer?) -> String {
        guard let c = customer else { return "" }
        var parts: [String] = []
        if let name = c.displayName.isEmpty ? c.name : c.displayName as String?, !name.isEmpty { parts.append(name) }
        if let co = c.company, !co.isEmpty { parts.append(co) }
        if let a = c.address, !a.isEmpty { parts.append(a) }
        let cityZip: [String] = [c.city, c.zip].compactMap { $0 }.filter { !$0.isEmpty }
        if !cityZip.isEmpty { parts.append(cityZip.joined(separator: " ")) }
        if let country = c.country, !country.isEmpty { parts.append(country) }
        return parts.joined(separator: "\n")
    }

    private func invoiceMetaLines(_ invoice: Invoice) -> [String] {
        var lines: [String] = []
        if let ref = invoice.referenceNumber, !ref.isEmpty { lines.append("Invoice #\(ref)") }
        lines.append("Date: \(formatDate(invoice.invoiceDate))")
        if let due = invoice.dueDate { lines.append("Due: \(formatDate(due))") }
        if let terms = invoice.terms, !terms.isEmpty { lines.append("Terms: \(terms)") }
        return lines
    }

    private func memoMetaLines(_ memo: Memo) -> [String] {
        var lines: [String] = []
        if let ref = memo.referenceNumber, !ref.isEmpty { lines.append("Memo #\(ref)") }
        if let date = memo.dateAssigned { lines.append("Date: \(formatDate(date))") }
        lines.append("Status: \(memo.status.rawValue)")
        return lines
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func invoiceSubtotal(_ invoice: Invoice) -> Decimal {
        invoice.lineItems.reduce(0) { $0 + $1.amount }
    }

    private func invoiceTotal(_ invoice: Invoice) -> Decimal {
        invoiceSubtotal(invoice)
    }

    private func memoSubtotal(_ memo: Memo) -> Decimal {
        memo.lineItems.reduce(0) { $0 + $1.amount }
    }

    private func memoTotal(_ memo: Memo) -> Decimal {
        memoSubtotal(memo)
    }

    // MARK: - Render HTML to PDF

    private func renderHTMLToPDF(html: String, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let runner = PDFWebViewRunner(
                html: html,
                pageSize: CGSize(width: self.letterWidth, height: self.letterHeight)
            ) { result in
                DispatchQueue.main.async { completion(result) }
            }
            runner.run()
        }
    }
}

// MARK: - WKWebView PDF runner (must run on main, retains itself until done)

private final class PDFWebViewRunner: NSObject, WKNavigationDelegate {
    let html: String
    let pageSize: CGSize
    let completion: (Result<URL, Error>) -> Void
    private var webView: WKWebView?
    private var selfRetain: PDFWebViewRunner?

    init(html: String, pageSize: CGSize, completion: @escaping (Result<URL, Error>) -> Void) {
        self.html = html
        self.pageSize = pageSize
        self.completion = completion
        super.init()
    }

    func run() {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: CGRect(origin: .zero, size: pageSize), configuration: config)
        wv.navigationDelegate = self
        webView = wv
        selfRetain = self
        wv.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let config = WKPDFConfiguration()
        config.rect = CGRect(origin: .zero, size: pageSize)
        webView.createPDF(configuration: config) { [weak self] result in
            guard let self = self else { return }
            self.selfRetain = nil
            switch result {
            case .success(let data):
                do {
                    let fileName = "document-\(UUID().uuidString).pdf"
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    try data.write(to: url)
                    self.completion(.success(url))
                } catch {
                    self.completion(.failure(error))
                }
            case .failure(let error):
                self.completion(.failure(error))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        selfRetain = nil
        completion(.failure(error))
    }
}
