import Foundation

struct ImageGenResponse: Decodable {
    struct Item: Decodable {
        let b64_json: String?
        let url: String?
    }
    let data: [Item]
}
