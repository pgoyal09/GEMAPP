import Foundation

// MARK: - Diamond Shapes (RapNet)

enum DiamondShape {
    static let allowed = [
        "Round", "Pear", "Emerald", "Princess", "Marquise", "Asscher",
        "Oval", "Radiant", "Heart", "Cushion Brilliant", "Cushion Modified",
        "Square Emerald", "Baguette", "Tapered Baguette", "Briolette",
        "Half Moon", "Hexagonal", "Kite", "Lozenge", "Old Miner",
        "Octagonal", "Pentagonal", "Rose", "Shield", "Square",
        "Star", "Trapezoid", "Triangle", "Trilliant", "Other",
    ]
}

// MARK: - Gemstone Shapes (RapNet)

enum GemstoneShape {
    static let allowed = [
        "Round", "Oval", "Cushion", "Emerald", "Pear", "Marquise",
        "Heart", "Princess", "Radiant", "Asscher", "Baguette",
        "Cabochon", "Bead", "Briolette", "Bufftop", "Cameo", "Carved",
        "Checkerboard", "Fancy", "Fantasy", "Half Moon", "Hexagonal",
        "Intaglio", "Kite", "Lozenge", "Navette", "Octagonal", "Other",
        "Antique Cushion", "Pentagonal", "Rose Cut", "Shield", "Square",
        "Star", "Step", "SugarLoaf", "Tear Drop", "Trapezoid",
        "Triangular", "Trillion",
    ]
}

// MARK: - Gemstone Clarity (RapNet)

enum GemstoneClarityOption {
    static let allowed = ["Eye Clean", "Slightly Included", "Moderately Included", "Visibly Included"]
}

// MARK: - Gemstone Origin

enum GemstoneOriginOption {
    static let allowed = [
        "Sri Lanka", "Madagascar", "Brazil", "Zambia", "Thailand",
        "Myanmar", "Mozambique", "Australia", "India", "Tanzania", "Colombia",
        "United States", "Cambodia", "Ethiopia", "Afghanistan", "Argentina",
        "Bolivia", "China", "Congo", "Fiji", "Greenland", "Iran", "Kashmir",
        "Kenya", "Malawi", "Mexico", "Montana", "Namibia", "Nigeria",
        "Oregon", "Pakistan", "Russia", "Tajikistan", "Vietnam", "Other", "Unknown",
    ]
}

// MARK: - Gemstone Treatment

enum GemstoneTreatmentOption {
    static let allowed = [
        "Bleached", "Coated", "Dyed", "Enhancement", "Filling",
        "Heated", "Heating & Pressure", "Impregnated", "Infused", "Irradiated",
        "Lasering", "None", "Oiling", "Other", "Waxing",
    ]
}

// MARK: - Gemstone Primary Color

enum GemstoneColorOption {
    static let allowed = [
        "Bi-color", "Black", "Blue", "Brown", "Color Change", "Colorless",
        "Golden", "Green", "Grey", "Imperial", "Mint", "Multi-color", "Orange",
        "Other", "Peach", "Pink", "Purple", "Red", "Teal", "Violet", "White", "Yellow",
    ]
}
