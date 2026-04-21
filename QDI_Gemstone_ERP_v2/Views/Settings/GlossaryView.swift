import SwiftUI

/// Dictionary of gemstone industry terms, accessible from Help menu and (?) icons.
struct GlossaryView: View {
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Gemstone Glossary")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.outline)
            }
            .padding(AppSpacing.hero)

            GlassSearchField(text: $searchText, placeholder: "Search terms...")
                .padding(.horizontal, AppSpacing.hero)
                .padding(.bottom, AppSpacing.section)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                    ForEach(filteredTerms, id: \.term) { entry in
                        GlassCard(padding: AppSpacing.section) {
                            VStack(alignment: .leading, spacing: AppSpacing.tableColumnGap) {
                                Text(entry.term)
                                    .font(AppTypography.subheading)
                                    .foregroundStyle(AppColors.ink)
                                Text(entry.definition)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.inkMuted)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.hero)
                .padding(.bottom, AppSpacing.hero)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .appBackground()
    }

    private var filteredTerms: [GlossaryEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Self.glossary }
        return Self.glossary.filter {
            $0.term.lowercased().contains(q) || $0.definition.lowercased().contains(q)
        }
    }

    // MARK: - Glossary Data

    struct GlossaryEntry {
        let term: String
        let definition: String
    }

    static let glossary: [GlossaryEntry] = [
        GlossaryEntry(term: "Carat (ct)", definition: "Unit of weight for gemstones. One carat equals 0.2 grams or 200 milligrams."),
        GlossaryEntry(term: "Clarity", definition: "A grading factor that measures the presence of internal inclusions and surface blemishes. Diamond clarity ranges from FL (Flawless) to I3 (Included)."),
        GlossaryEntry(term: "Color (Diamond)", definition: "Diamond color grades range from D (colorless) to Z (light yellow/brown). Fancy colors (blue, pink, etc.) are graded separately."),
        GlossaryEntry(term: "Cut Grade", definition: "Assessment of how well a diamond's proportions, symmetry, and polish interact with light. Ranges from Excellent to Poor."),
        GlossaryEntry(term: "Fluorescence", definition: "The visible light some diamonds emit when exposed to UV rays. Graded None, Faint, Medium, Strong, Very Strong."),
        GlossaryEntry(term: "Eye Clean", definition: "A stone that appears free of inclusions to the naked eye, without magnification."),
        GlossaryEntry(term: "Depth %", definition: "The total height of a diamond measured from table to culet, expressed as a percentage of its diameter."),
        GlossaryEntry(term: "Table %", definition: "The width of the diamond's table facet (the flat top surface) expressed as a percentage of its diameter."),
        GlossaryEntry(term: "Rapaport (Rap)", definition: "The Rapaport Price List is the primary price reference for wholesale diamond pricing, published weekly."),
        GlossaryEntry(term: "Rap Discount", definition: "The percentage below (negative) or above (positive) the Rapaport list price at which a diamond is offered."),
        GlossaryEntry(term: "Polish", definition: "The quality of the surface finish on a diamond's facets. Graded Excellent to Poor."),
        GlossaryEntry(term: "Symmetry", definition: "How precisely the facets of a diamond are aligned and intersect. Graded Excellent to Poor."),
        GlossaryEntry(term: "GIA", definition: "Gemological Institute of America — the most widely recognized diamond and gemstone grading laboratory."),
        GlossaryEntry(term: "AGS", definition: "American Gem Society — a diamond grading laboratory known for its light performance cut grading."),
        GlossaryEntry(term: "Memo", definition: "A consignment agreement where stones are sent to a buyer for inspection. The seller retains ownership until the buyer decides to purchase or return."),
        GlossaryEntry(term: "Parcel", definition: "A collection of gemstones sold as a group, typically similar in quality and type."),
        GlossaryEntry(term: "Melee", definition: "Small diamonds typically under 0.20 carats, often used for accent stones in jewelry settings."),
        GlossaryEntry(term: "Lot", definition: "A group of similar gemstones sold together by total carat weight rather than individually."),
        GlossaryEntry(term: "Treatment", definition: "Any process applied to a gemstone to improve its appearance. Common treatments include heating, oiling, and irradiation."),
        GlossaryEntry(term: "Inclusion", definition: "An internal characteristic (mineral crystal, feather, cloud, etc.) within a gemstone visible under 10x magnification."),
        GlossaryEntry(term: "Blemish", definition: "An external surface imperfection on a gemstone, such as scratches, nicks, or polish lines."),
        GlossaryEntry(term: "Origin", definition: "The geographic source of a gemstone (e.g., Colombia for emeralds, Burma for rubies). Origin can significantly affect value."),
        GlossaryEntry(term: "Fancy Color", definition: "A diamond with a natural body color other than the normal D-to-Z light yellow/brown range (e.g., pink, blue, green, yellow)."),
        GlossaryEntry(term: "Pavilion", definition: "The lower portion of a gemstone, below the girdle."),
        GlossaryEntry(term: "Crown", definition: "The upper portion of a gemstone, above the girdle."),
        GlossaryEntry(term: "Girdle", definition: "The thin band around the widest part of a diamond, separating the crown from the pavilion."),
        GlossaryEntry(term: "Culet", definition: "The small facet at the bottom tip of a diamond's pavilion. Ideally pointed (None) for modern cuts."),
        GlossaryEntry(term: "Brilliance", definition: "The white light reflected from inside and on the surface of a diamond."),
        GlossaryEntry(term: "Fire", definition: "The dispersion of light into spectral colors (rainbow flashes) seen in a gemstone."),
        GlossaryEntry(term: "Scintillation", definition: "The sparkle or flashes of light seen when a diamond, the light source, or the observer moves."),
    ]
}
