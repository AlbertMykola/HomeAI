import UIKit
import Vision

/// On-device check for W1 "selected": what room it is (Vision classifier) and whether it's bright enough.
/// Never blocks — the result only drives the badge text and the pre-selected room on W2.
enum PhotoQualityChecker {

    struct Result {
        var room: InteriorType?
        var isTooDark: Bool
    }

    static func check(_ image: UIImage, completion: @escaping (Result) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let small = image.downscaled(maxSide: 512)
            let dark = (small.map(averageLuminance) ?? 0.5) < 0.22
            var room: InteriorType?
            if let cg = small?.cgImage {
                let request = VNClassifyImageRequest()
                try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([request])
                let observations = (request.results ?? []).filter { $0.confidence > 0.12 }
                room = observations.lazy.compactMap { mapRoom($0.identifier) }.first
            }
            DispatchQueue.main.async { completion(Result(room: room, isTooDark: dark)) }
        }
    }

    private static func mapRoom(_ identifier: String) -> InteriorType? {
        let id = identifier.lowercased()
        let table: [(String, InteriorType)] = [
            ("kitchen", .kitchen), ("bedroom", .bedroom), ("bathroom", .bathroom), ("bathtub", .bathroom),
            ("living_room", .livingroom), ("living room", .livingroom), ("sofa", .livingroom), ("couch", .livingroom),
            ("dining", .dinningroom), ("office", .office), ("desk", .study), ("nursery", .kids), ("toy", .kids),
            ("attic", .attic), ("toilet", .toilet), ("balcony", .balcony), ("patio", .balcony),
            ("hallway", .hallway), ("corridor", .hallway), ("laundry", .laundry), ("washing_machine", .laundry),
            ("garage", .garage), ("bed", .bedroom), ("video_game", .gaming)
        ]
        return table.first { id.contains($0.0) }?.1
    }

    private static func averageLuminance(_ image: UIImage) -> CGFloat {
        guard let cg = image.cgImage else { return 0.5 }
        let w = 32, h = 32
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0.5 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var sum: CGFloat = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            sum += 0.2126 * CGFloat(pixels[i]) + 0.7152 * CGFloat(pixels[i + 1]) + 0.0722 * CGFloat(pixels[i + 2])
        }
        return sum / CGFloat(w * h) / 255
    }
}

extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let ratio = min(1, maxSide / longest)
        let target = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
