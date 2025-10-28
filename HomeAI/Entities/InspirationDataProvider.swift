import UIKit

final class InspirationDataProvider {
    
    static let shared = InspirationDataProvider()
    
    func loadInspirationsFromBundle() throws -> [InspirationCategory] {
        guard let url = Bundle.main.url(forResource: "InspirationJson", withExtension: "json") else {
            throw NSError(domain: "Inspirations", code: 1, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(InspirationsResponse.self, from: data)
        return decoded.categories
    }
}

