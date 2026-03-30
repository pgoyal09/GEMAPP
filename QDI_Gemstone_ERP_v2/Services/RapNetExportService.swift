import Foundation

enum RapNetExportService {

    // MARK: - Diamond CSV Export

    static func exportDiamondCSV(stones: [Gemstone]) -> String {
        let header = "Stock #,Availability,Shape,Weight,Color,Clarity,Cut Grade,Polish,Symmetry,Fluorescence Intensity,Fluorescence Color,Measurements,Lab,Report #,RapNet Price,RapNet Discount %,Cash Price,Cash Price Discount %,Depth %,Table %,Eye Clean,Treatment,Member Comment,Country,State,City"

        let rows = stones.map { s in
            let measurements = [s.length, s.width, s.height]
                .compactMap { $0 }
                .map { String(format: "%.2f", $0) }
                .joined(separator: " x ")

            return [
                csvEscape(s.sku),
                csvEscape(s.availability ?? "G"),
                csvEscape(s.shape),
                String(format: "%.2f", s.caratWeight),
                csvEscape(s.fancyColor != nil ? "" : s.color),
                csvEscape(s.clarity),
                csvEscape(s.cut),
                csvEscape(s.polish),
                csvEscape(s.symmetry),
                csvEscape(s.fluorescenceIntensity ?? ""),
                csvEscape(s.fluorescenceColor ?? ""),
                csvEscape(measurements),
                csvEscape(s.certLab),
                csvEscape(s.certNo),
                s.rapNetPrice.map { "\($0)" } ?? "",
                s.rapNetDiscountPct.map { String(format: "%.2f", $0) } ?? "",
                s.cashPrice.map { "\($0)" } ?? "",
                s.cashDiscountPct.map { String(format: "%.2f", $0) } ?? "",
                s.depthPct.map { String(format: "%.1f", $0) } ?? "",
                s.tablePct.map { String(format: "%.0f", $0) } ?? "",
                csvEscape(s.eyeClean ?? ""),
                csvEscape(s.treatment),
                "",
                csvEscape(s.stoneCountry ?? ""),
                csvEscape(s.stoneState ?? ""),
                csvEscape(s.stoneCity ?? ""),
            ].joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - Gemstone CSV Export

    static func exportGemstoneCSV(stones: [Gemstone]) -> String {
        let header = "Stock Number,Availability,Stone Country Location,Stone Type,Shape,Carat Weight,Clarity,Measurements Length,Measurements Width,Measurements Height,Origin,Treatment Type 1,Treatment Type 2,Treatment Type 3,Treatment Note,Primary Color,Color Intensity,Color Modifiers,Color Description,Price Per Carat,Comment"

        let rows = stones.map { s in
            [
                csvEscape(s.sku),
                csvEscape(s.availability ?? "Guaranteed Available"),
                csvEscape(s.stoneCountry ?? ""),
                csvEscape(s.stoneType.rapNetName),
                csvEscape(s.shape),
                String(format: "%.2f", s.caratWeight),
                csvEscape(s.clarity),
                s.length.map { String(format: "%.2f", $0) } ?? "",
                s.width.map { String(format: "%.2f", $0) } ?? "",
                s.height.map { String(format: "%.2f", $0) } ?? "",
                csvEscape(s.origin),
                csvEscape(s.treatment),
                csvEscape(s.treatmentType2 ?? ""),
                csvEscape(s.treatmentType3 ?? ""),
                csvEscape(s.treatmentNotes ?? ""),
                csvEscape(s.primaryColorVendor ?? ""),
                csvEscape(s.colorIntensityVendor ?? ""),
                csvEscape(s.colorModifiersVendor ?? ""),
                csvEscape(s.colorDescription ?? ""),
                "\(s.sellPrice)",
                "",
            ].joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
