import UIKit

/// A curated idea for the A/08 feed, built from `InspirationJson.json` (category · style · palette name · image).
struct InspirationIdea: Equatable {

    /// Room filters on I1 (chips). `outdoor` groups Exterior + Garden.
    enum Room: Int, CaseIterable {
        case all, living, bedroom, kitchen, bathroom, dining, hallway, gaming, outdoor

        var title: String {
            switch self {
            case .all: return "All".localized
            case .living: return "Living room".localized
            case .bedroom: return "Bedroom".localized
            case .kitchen: return "Kitchen".localized
            case .bathroom: return "Bathroom".localized
            case .dining: return "Dinning room".localized
            case .hallway: return "Hallway".localized
            case .gaming: return "Gaming room".localized
            case .outdoor: return "Outdoor".localized
            }
        }

        init(category: String) {
            switch category.lowercased() {
            case "living room": self = .living
            case "bedroom": self = .bedroom
            case "kitchen": self = .kitchen
            case "bathroom": self = .bathroom
            case "dinning room", "dining room": self = .dining
            case "hallway": self = .hallway
            case "gaming room": self = .gaming
            default: self = .outdoor
            }
        }
    }

    let id: String
    let category: String
    let room: Room
    let style: String
    let paletteName: String

    var image: String { id }
    var option: DesignOption {
        switch category.lowercased() {
        case "exterior": return .exterior
        case "garden": return .garden
        default: return .interior
        }
    }

    /// "Warm Japandi kitchen".
    /// Other languages get "Кухня · Мінімалізм" (adjective + style + noun only reads well in English).
    var title: String {
        guard Self.isEnglish else { return "\(place) · \(style.localized)" }
        let adjective = Self.adjectives[paletteName].map { $0 + " " } ?? ""
        return adjective + style + " " + category.lowercased()
    }

    /// "Kitchen · Beige palette".
    var subtitle: String {
        guard Self.adjectives[paletteName] != nil else { return place }
        let palette = String(format: "%@ palette".localized, paletteName.localized)
        // Non-English titles already start with the room.
        return Self.isEnglish ? "\(place) · \(palette)" : palette
    }

    private var place: String { room == .outdoor ? category.localized : room.title }
    private static var isEnglish: Bool { (Locale.preferredLanguages.first ?? "en").hasPrefix("en") }

    var tags: [String] {
        var tags = [style.localized, room.title]
        if Self.palettes[paletteName] != nil { tags.append(paletteName.localized) }
        return tags
    }

    /// Five swatches for I2 (HEX without #).
    var palette: [String] { Self.palettes[paletteName] ?? Self.palettes["Light"]! }

    /// Matches the search field: style, room, palette or title.
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return [style, style.localized, category, category.localized, paletteName, title]
            .contains { $0.lowercased().contains(q) }
    }

    // MARK: Wizard presets ("Try on my room")

    var interiorStyle: StyleInteriorType? {
        if style.lowercased() == "luxury" { return .glam }
        return StyleInteriorType.allCases.first { Self.key(String(describing: $0)) == Self.key(style) }
    }

    var exteriorStyle: StyleExteriorType? {
        switch style.lowercased() {
        case "luxury": return .italianVilla
        case "classic": return .georgian
        default: return StyleExteriorType.allCases.first { Self.key(String(describing: $0)) == Self.key(style) }
        }
    }

    var gardenStyle: GardenType? {
        switch style.lowercased() {
        case "luxury": return .luxary
        case "modern": return .minimalist
        default: return GardenType.allCases.first { Self.key(String(describing: $0)) == Self.key(style) }
        }
    }

    var colorType: ColorType? {
        ColorType.allCases.first { Self.key(String(describing: $0)) == Self.key(paletteName) }
    }

    private static func key(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter }
    }

    private static let adjectives: [String: String] = [
        "Beige": "Warm", "Pastel": "Soft", "Minimalistic": "Clean", "Earthy": "Earthy", "Light": "Bright",
        "Calm": "Calm", "Spicied": "Spiced", "Blush": "Blush", "Elegant": "Elegant", "Azure": "Azure",
        "Fresh": "Fresh", "Stormy": "Moody", "Floral": "Floral", "Monochrome": "Monochrome", "Peach": "Peach",
        "Neon": "Neon", "Gilded": "Gilded"
    ]

    private static let palettes: [String: [String]] = [
        "Beige": ["EFE8DD", "C9A27E", "7A6A58", "2E2B28", "9AA58A"],
        "Light": ["F6F4EF", "D9D4CA", "A9B49A", "6F7D6A", "3B3F3A"],
        "Earthy": ["E8DCCB", "B98B5E", "8A5A3B", "4E3B2C", "7D8B5E"],
        "Minimalistic": ["F5F5F3", "DADAD6", "A7A7A2", "4A4A48", "1F1F1F"],
        "Pastel": ["F7EFEA", "E9D3CF", "CFDCE3", "D9E3D0", "B7A99A"],
        "Calm": ["EEF1F2", "C9D3D6", "8FA3A8", "5B6E73", "2F3B3E"],
        "Spicied": ["F1E3D3", "D9A066", "B5652F", "7A3E23", "3A2A22"],
        "Blush": ["F8ECEA", "EBC9C3", "D49A93", "9C6B62", "4B3A36"],
        "Elegant": ["F2EFEA", "CBB89A", "8C7A5B", "2F3A3F", "151515"],
        "Azure": ["F1F6F8", "BFD9E3", "6FA4BC", "2F6E8C", "1D3A4A"],
        "Fresh": ["F2F7EE", "CFE3B8", "8DBF6A", "4E8A3A", "2B4A2A"],
        "Stormy": ["E9EAEC", "B6BAC0", "7D838C", "4A5059", "23272D"],
        "Floral": ["F7F0EA", "E8C8C0", "C98F8A", "8EA58A", "4F5E4A"],
        "Monochrome": ["F4F4F4", "CFCFCF", "8F8F8F", "4D4D4D", "141414"],
        "Peach": ["FBEFE6", "F3C9AE", "E39B76", "A8674A", "4A3428"],
        "Neon": ["1A1530", "3B2B7A", "7B3FF2", "E040FB", "29E6F0"],
        "Gilded": ["F4EEE2", "D8C08A", "B08D4A", "5A4A32", "1E1A15"]
    ]
}

// MARK: - Feed source

enum InspirationFeed {

    /// All curated ideas (bundle JSON). Tolerates trailing commas in the hand-written file.
    static func load() -> [InspirationIdea] {
        guard let url = Bundle.main.url(forResource: "InspirationJson", withExtension: "json"),
              var text = try? String(contentsOf: url) else { return [] }
        text = text.replacingOccurrences(of: #",\s*([\]}])"#, with: "$1", options: .regularExpression)
        guard let data = text.data(using: .utf8),
              let response = try? JSONDecoder().decode(InspirationsResponse.self, from: data) else { return [] }
        var seen = Set<String>()
        let groups = response.categories.map { category in
            category.items.compactMap { item -> InspirationIdea? in
                guard seen.insert(item.image).inserted else { return nil }
                return InspirationIdea(id: item.image, category: category.category,
                                       room: .init(category: category.category), style: item.style,
                                       paletteName: item.colorName)
            }
        }
        // "All" mixes rooms round-robin: interiors first, outdoor ideas after.
        let indoor = groups.filter { $0.first?.room != .outdoor }
        let outdoor = groups.filter { $0.first?.room == .outdoor }
        return roundRobin(indoor) + roundRobin(outdoor)
    }

    private static func roundRobin(_ groups: [[InspirationIdea]]) -> [InspirationIdea] {
        var result: [InspirationIdea] = []
        for i in 0..<(groups.map(\.count).max() ?? 0) {
            result += groups.compactMap { $0[safe: i] }
        }
        return result
    }
}

// MARK: - Saved ideas (Projects › Ideas)

extension Notification.Name {
    static let savedIdeasDidChange = Notification.Name("savedIdeasDidChange")
}

final class IdeasStore {

    static let shared = IdeasStore()
    private let key = "redesign_saved_ideas"

    private(set) var savedIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    func isSaved(_ id: String) -> Bool { savedIDs.contains(id) }

    /// Returns the new state.
    @discardableResult
    func toggle(_ idea: InspirationIdea) -> Bool {
        var ids = savedIDs
        let saved: Bool
        if let i = ids.firstIndex(of: idea.id) {
            ids.remove(at: i)
            saved = false
        } else {
            ids.insert(idea.id, at: 0)
            saved = true
        }
        savedIDs = ids
        AmplitudeService.shared.logRedesignEvent(saved ? "inspiration_save" : "inspiration_unsave",
                                                 properties: ["style": idea.style, "room": idea.category])
        NotificationCenter.default.post(name: .savedIdeasDidChange, object: idea.id)
        return saved
    }

    func savedIdeas(from all: [InspirationIdea] = InspirationFeed.load()) -> [InspirationIdea] {
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return savedIDs.compactMap { byID[$0] }
    }
}
