import UIKit
import Vision

/// On-device object picking for R4 Replace / R5 "Tap object" (iOS 17+ foreground instance masks).
/// Each instance gets a centre hotspot, a bounding box, a mask and a best-effort label.
enum ObjectDetector {

    struct Object {
        let mask: CGImage          // image pixel size, white = object
        let bounds: CGRect         // image pixels
        let center: CGPoint        // image pixels
        var label: String
    }

    static var isAvailable: Bool {
        if #available(iOS 17.0, *) { return true }
        return false
    }

    /// `image` should be the same pixel size as the editing mask (`MaskCanvasView.baseImageForMask`).
    static func detect(in image: UIImage, completion: @escaping ([Object]) -> Void) {
        guard #available(iOS 17.0, *), let cg = image.cgImage else {
            completion([])
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            var objects: [Object] = []
            do {
                try handler.perform([request])
                if let result = request.results?.first {
                    for index in result.allInstances {
                        guard let buffer = try? result.generateScaledMaskForImage(forInstances: IndexSet(integer: index),
                                                                                  from: handler),
                              let mask = cgImage(fromMask: buffer),
                              let box = boundingBox(of: buffer) else { continue }
                        guard box.width * box.height > CGFloat(cg.width * cg.height) * 0.004 else { continue }
                        let label = classify(cg, crop: box) ?? "Object".localized
                        objects.append(Object(mask: mask, bounds: box, center: CGPoint(x: box.midX, y: box.midY), label: label))
                    }
                }
            } catch {
                objects = []
            }
            DispatchQueue.main.async { completion(objects) }
        }
    }

    /// Picks the object under a point (image pixels).
    static func object(at point: CGPoint, in objects: [Object]) -> Object? {
        objects.filter { $0.bounds.contains(point) }.min { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
    }

    // MARK: Helpers

    private static func cgImage(fromMask buffer: CVPixelBuffer) -> CGImage? {
        let ci = CIImage(cvPixelBuffer: buffer)
        return CIContext(options: nil).createCGImage(ci, from: ci.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
    }

    private static func boundingBox(of buffer: CVPixelBuffer) -> CGRect? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        let row = CVPixelBufferGetBytesPerRow(buffer)
        let format = CVPixelBufferGetPixelFormatType(buffer)
        var minX = w, minY = h, maxX = -1, maxY = -1
        let step = 2
        for y in stride(from: 0, to: h, by: step) {
            for x in stride(from: 0, to: w, by: step) {
                let on: Bool
                if format == kCVPixelFormatType_OneComponent32Float {
                    on = base.advanced(by: y * row + x * 4).assumingMemoryBound(to: Float32.self).pointee > 0.5
                } else {
                    on = base.advanced(by: y * row + x).assumingMemoryBound(to: UInt8.self).pointee > 127
                }
                if on {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + step, height: maxY - minY + step)
    }

    private static func classify(_ cg: CGImage, crop: CGRect) -> String? {
        guard let cropped = cg.cropping(to: crop.insetBy(dx: -crop.width * 0.1, dy: -crop.height * 0.1)
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))) else { return nil }
        let request = VNClassifyImageRequest()
        try? VNImageRequestHandler(cgImage: cropped, orientation: .up).perform([request])
        let ignored: Set<String> = ["structure", "interior_room", "room", "indoor", "furniture", "wood_processed",
                                    "material", "textile", "liquid", "art", "decoration"]
        guard let best = request.results?.first(where: { $0.confidence > 0.1 && !ignored.contains($0.identifier) }) else {
            return nil
        }
        return best.identifier.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
