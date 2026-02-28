import Foundation

enum IntakeShape: String, CaseIterable, Identifiable {
    case round = "Round"
    case oval = "Oval"
    case cushion = "Cushion"
    case pear = "Pear"
    case emerald = "Emerald"
    case princess = "Princess"
    case radiant = "Radiant"
    case marquise = "Marquise"
    case heart = "Heart"
    case asscher = "Asscher"
    case cabochon = "Cabochon"
    case other = "Other"
    var id: Self { self }
}

enum IntakeGrouping: String, CaseIterable, Identifiable {
    case single = "Single"
    case pair = "Pair"
    case lot = "Lot"
    var id: Self { self }
}
