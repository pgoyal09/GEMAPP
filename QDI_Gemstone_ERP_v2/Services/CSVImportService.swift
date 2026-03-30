import Foundation
import SwiftData

/// Parses supplier price-list CSVs and maps columns to Gemstone fields.
@MainActor
enum CSVImportService {

    /// A single parsed row ready for preview before import.
    struct ImportRow: Identifiable {
        let id = UUID()
        var stoneType: StoneType
        var caratWeight: Double
        var shape: String
        var color: String
        var clarity: String
        var cut: String
        var origin: String
        var costPrice: Decimal
        var sellPrice: Decimal
        var certLab: String
        var certNo: String
        var treatment: String
        var polish: String
        var symmetry: String
        var fluorescence: String
    }

    /// Errors specific to CSV import.
    enum ImportError: LocalizedError {
        case emptyFile
        case missingRequiredColumn(String)
        case parseError(row: Int, detail: String)

        var errorDescription: String? {
            switch self {
            case .emptyFile: return "The CSV file is empty."
            case .missingRequiredColumn(let col): return "Missing required column: \(col)"
            case .parseError(let row, let detail): return "Row \(row): \(detail)"
            }
        }
    }

    /// Parse a CSV file at the given URL into preview rows.
    static func parse(url: URL) throws -> [ImportRow] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { throw ImportError.emptyFile }

        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        // Map known column names
        let colMap = buildColumnMap(headers)

        // Require at least stone type and carat
        guard colMap["stonetype"] != nil || colMap["type"] != nil else {
            throw ImportError.missingRequiredColumn("Stone Type / Type")
        }
        guard colMap["carat"] != nil || colMap["caratweight"] != nil || colMap["weight"] != nil else {
            throw ImportError.missingRequiredColumn("Carat / Weight")
        }

        var rows: [ImportRow] = []
        for i in 1..<lines.count {
            let fields = parseCSVLine(lines[i])
            let row = try mapRow(fields: fields, colMap: colMap, lineNumber: i + 1)
            rows.append(row)
        }
        return rows
    }

    /// Import parsed rows into SwiftData, generating SKUs.
    static func importRows(_ rows: [ImportRow], modelContext: ModelContext) -> Int {
        var count = 0
        for row in rows {
            let sku = SKUGenerator.generate(
                type: row.stoneType,
                shape: row.shape,
                grouping: .single,
                modelContext: modelContext
            )
            let stone = Gemstone(
                sku: sku,
                stoneType: row.stoneType,
                caratWeight: row.caratWeight,
                shape: row.shape,
                origin: row.origin,
                color: row.color,
                clarity: row.clarity,
                cut: row.cut,
                treatment: row.treatment,
                polish: row.polish,
                symmetry: row.symmetry,
                fluorescence: row.fluorescence,
                hasCert: !row.certLab.isEmpty,
                certLab: row.certLab,
                certNo: row.certNo,
                costPrice: row.costPrice,
                sellPrice: row.sellPrice
            )
            modelContext.insert(stone)
            count += 1
        }
        return count
    }

    // MARK: - Private

    private static func buildColumnMap(_ headers: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (i, h) in headers.enumerated() {
            let key = h.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")
            map[key] = i
        }
        return map
    }

    private static func col(_ map: [String: Int], _ fields: [String], _ keys: String...) -> String {
        for key in keys {
            if let idx = map[key], idx < fields.count {
                return fields[idx].trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private static func mapRow(fields: [String], colMap: [String: Int], lineNumber: Int) throws -> ImportRow {
        let typeStr = col(colMap, fields, "stonetype", "type", "gemtype")
        let stoneType = StoneType(rawValue: typeStr)
            ?? StoneType.allCases.first { $0.rawValue.lowercased() == typeStr.lowercased() }
            ?? .diamond

        let caratStr = col(colMap, fields, "carat", "caratweight", "weight", "cts")
        guard let carat = Double(caratStr), carat > 0 else {
            throw ImportError.parseError(row: lineNumber, detail: "Invalid carat weight: \(caratStr)")
        }

        let costStr = col(colMap, fields, "costprice", "cost", "buyprice", "pricepercarat")
        let sellStr = col(colMap, fields, "sellprice", "sell", "askingprice", "price", "totalprice")

        return ImportRow(
            stoneType: stoneType,
            caratWeight: carat,
            shape: col(colMap, fields, "shape", "cut"),
            color: col(colMap, fields, "color", "colour"),
            clarity: col(colMap, fields, "clarity", "purity"),
            cut: col(colMap, fields, "cutgrade", "cutquality"),
            origin: col(colMap, fields, "origin", "country", "source"),
            costPrice: Decimal(string: costStr) ?? 0,
            sellPrice: Decimal(string: sellStr) ?? 0,
            certLab: col(colMap, fields, "certlab", "lab", "laboratory"),
            certNo: col(colMap, fields, "certno", "certnumber", "certificateno", "reportno"),
            treatment: col(colMap, fields, "treatment", "enhancement"),
            polish: col(colMap, fields, "polish", "pol"),
            symmetry: col(colMap, fields, "symmetry", "sym"),
            fluorescence: col(colMap, fields, "fluorescence", "fluor", "flour")
        )
    }

    /// Parse a single CSV line respecting quoted fields.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
