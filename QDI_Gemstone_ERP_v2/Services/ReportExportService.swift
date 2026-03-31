import Foundation
import AppKit

enum ReportExportService {

    // MARK: - CSV Export

    static func exportPLToCSV(_ report: PLReport) -> String {
        var lines = ["Stone Type,Units Sold,Revenue,COGS,Gross Profit,Margin %"]
        for row in report.breakdownByType {
            lines.append("\(row.stoneType.csvEscaped),\(row.unitsSold),\(row.revenue),\(row.cogs),\(row.grossProfit),\(String(format: "%.1f", row.marginPercent))")
        }
        lines.append("")
        lines.append("Total,,\(report.revenue),\(report.cogs),\(report.grossProfit),\(String(format: "%.1f", report.marginPercent))")
        return lines.joined(separator: "\n")
    }

    static func exportInventoryTurnoverToCSV(_ report: InventoryTurnoverReport) -> String {
        var lines = ["Metric,Value"]
        lines.append("Current Inventory Count,\(report.currentCount)")
        lines.append("Current Inventory Value,\(report.currentValue)")
        lines.append("Sold in Period Count,\(report.soldCount)")
        lines.append("Sold in Period Value,\(report.soldValue)")
        lines.append("Turnover Rate,\(String(format: "%.2f", report.turnoverRate))")
        lines.append("")
        lines.append("Aging Bucket,Count,Value")
        for bucket in report.agingBuckets {
            lines.append("\(bucket.label.csvEscaped),\(bucket.count),\(bucket.value)")
        }
        lines.append("")
        lines.append("Slow Movers")
        lines.append("SKU,Stone Type,Carats,Cost Price,Days in Inventory")
        for s in report.slowMovers {
            lines.append("\(s.sku.csvEscaped),\(s.stoneType.csvEscaped),\(String(format: "%.2f", s.caratWeight)),\(s.costPrice),\(s.daysInInventory)")
        }
        return lines.joined(separator: "\n")
    }

    static func exportCustomerProfitabilityToCSV(_ report: CustomerProfitabilityReport) -> String {
        var lines = ["Customer,Total Revenue,Total COGS,Profit,Margin %,Transactions,Avg Order Value"]
        for row in report.rows {
            lines.append("\(row.customerName.csvEscaped),\(row.totalRevenue),\(row.totalCOGS),\(row.profit),\(String(format: "%.1f", row.marginPercent)),\(row.transactionCount),\(row.avgOrderValue)")
        }
        return lines.joined(separator: "\n")
    }

    static func exportMarginAnalysisToCSV(_ report: MarginAnalysisReport) -> String {
        var lines = ["Monthly Margin Trend"]
        lines.append("Month,Margin %,Revenue,COGS")
        for m in report.monthlyTrend {
            lines.append("\(m.month.csvEscaped),\(String(format: "%.1f", m.marginPercent)),\(m.revenue),\(m.cogs)")
        }
        lines.append("")
        lines.append("Margin by Stone Type")
        lines.append("Stone Type,Avg Margin %,Count")
        for s in report.byStoneType {
            lines.append("\(s.stoneType.csvEscaped),\(String(format: "%.1f", s.avgMarginPercent)),\(s.count)")
        }
        lines.append("")
        lines.append("Margin Distribution")
        lines.append("Bucket,Count,Percent")
        for d in report.distribution {
            lines.append("\(d.label.csvEscaped),\(d.count),\(String(format: "%.1f", d.percent))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Save CSV

    static func saveCSV(_ content: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - PDF Export (HTML→PDF via WKWebView, matches existing PDFService pattern)

    @MainActor
    static func exportReportToPDF(title: String, html: String, completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        PDFService.shared.renderHTMLToPDF(html: html, completion: completion)
    }

    static func buildPLHTML(_ report: PLReport, dateRange: String) -> String {
        var rows = ""
        for row in report.breakdownByType {
            rows += "<tr><td>\(row.stoneType)</td><td>\(row.unitsSold)</td><td>\(row.revenue.asCurrency)</td><td>\(row.cogs.asCurrency)</td><td>\(row.grossProfit.asCurrency)</td><td>\(String(format: "%.1f%%", row.marginPercent))</td></tr>"
        }
        rows += "<tr style='font-weight:bold;border-top:2px solid #333'><td>Total</td><td></td><td>\(report.revenue.asCurrency)</td><td>\(report.cogs.asCurrency)</td><td>\(report.grossProfit.asCurrency)</td><td>\(String(format: "%.1f%%", report.marginPercent))</td></tr>"

        return wrapHTML(title: "Profit & Loss Report", subtitle: dateRange, body: """
        <table><thead><tr><th>Stone Type</th><th>Units</th><th>Revenue</th><th>COGS</th><th>Gross Profit</th><th>Margin</th></tr></thead><tbody>\(rows)</tbody></table>
        """)
    }

    static func buildInventoryTurnoverHTML(_ report: InventoryTurnoverReport, dateRange: String) -> String {
        var agingRows = ""
        for b in report.agingBuckets {
            agingRows += "<tr><td>\(b.label)</td><td>\(b.count)</td><td>\(b.value.asCurrency)</td></tr>"
        }
        return wrapHTML(title: "Inventory Turnover Report", subtitle: dateRange, body: """
        <div style='margin-bottom:20px'>
        <p><strong>Current Inventory:</strong> \(report.currentCount) stones — \(report.currentValue.asCurrency)</p>
        <p><strong>Sold in Period:</strong> \(report.soldCount) stones — \(report.soldValue.asCurrency)</p>
        <p><strong>Turnover Rate:</strong> \(String(format: "%.2f", report.turnoverRate))</p>
        </div>
        <h3>Aging Buckets</h3>
        <table><thead><tr><th>Bucket</th><th>Count</th><th>Value</th></tr></thead><tbody>\(agingRows)</tbody></table>
        """)
    }

    // MARK: - HTML Wrapper

    private static func wrapHTML(title: String, subtitle: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>
        body { font-family: -apple-system, Helvetica, sans-serif; margin: 40px; color: #1a1a1a; }
        h1 { font-size: 22px; margin-bottom: 4px; }
        h3 { font-size: 15px; margin-top: 20px; }
        .subtitle { font-size: 13px; color: #666; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f5f5f5; font-weight: 600; }
        </style></head>
        <body>
        <h1>\(title)</h1>
        <div class="subtitle">\(subtitle)</div>
        \(body)
        <div style="margin-top:30px;font-size:11px;color:#999">Generated by QDI Gemstone ERP</div>
        </body></html>
        """
    }
}

