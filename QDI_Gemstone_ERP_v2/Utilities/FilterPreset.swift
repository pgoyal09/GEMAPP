import Foundation

/// A named filter preset persisted to UserDefaults.
struct FilterPreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String

    // Diamond filters
    var shapeFilter: String?
    var colorFilter: String?
    var clarityFilter: String?

    // Gemstone filters
    var stoneTypeFilter: String?  // StoneType raw value
    var originFilter: String?

    // Shared
    var caratMin: Double?
    var caratMax: Double?
}

/// Manages saving and loading filter presets to/from UserDefaults.
enum FilterPresetStore {

    private static let diamondKey = "com.qdi.gemapp.diamondFilterPresets"
    private static let gemstoneKey = "com.qdi.gemapp.gemstoneFilterPresets"

    // MARK: - Diamond Presets

    static func loadDiamondPresets() -> [FilterPreset] {
        load(key: diamondKey)
    }

    static func saveDiamondPresets(_ presets: [FilterPreset]) {
        save(presets, key: diamondKey)
    }

    // MARK: - Gemstone Presets

    static func loadGemstonePresets() -> [FilterPreset] {
        load(key: gemstoneKey)
    }

    static func saveGemstonePresets(_ presets: [FilterPreset]) {
        save(presets, key: gemstoneKey)
    }

    // MARK: - Private

    private static func load(key: String) -> [FilterPreset] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([FilterPreset].self, from: data)) ?? []
    }

    private static func save(_ presets: [FilterPreset], key: String) {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
