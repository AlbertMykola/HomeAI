import Foundation

struct ImageGenRequest: Encodable {
    let model: String
    let prompt: String
    let n: Int
    let size: String
}
