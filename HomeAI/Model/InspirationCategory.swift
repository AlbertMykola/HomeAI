import Foundation

struct InspirationsResponse: Decodable {
    let categories: [InspirationCategory]
}

struct InspirationCategory: Decodable {
    let category: String
    let items: [InspirationItem]
}

struct InspirationItem: Decodable {
    let style: String
    let image: String
    let colorName: String

    private enum CodingKeys: String, CodingKey {
        case style, image, colorName
    }
    private enum AltKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let s = try c.decodeIfPresent(String.self, forKey: .style) {
            style = s
        } else {
            // fallback на "name"
            let a = try decoder.container(keyedBy: AltKeys.self)
            style = try a.decode(String.self, forKey: .name)
        }

        image = try c.decode(String.self, forKey: .image)
        colorName = try c.decode(String.self, forKey: .colorName)
    }
}
