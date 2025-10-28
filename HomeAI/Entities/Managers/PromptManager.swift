//
//  PromptManager.swift
//  HomeDesignAI
//

import Foundation
import UIKit

// MARK: - Modes

enum ChatGPTImageMode {
    case imageToImage
}

// MARK: - Unified Style

enum UnifiedStyle {
    case interior(StyleInteriorType)
    case exterior(StyleExteriorType)
    case garden(String)
    case reference(String)

    var name: String {
        switch self {
        case .interior(let s): return s.name
        case .exterior(let s): return s.name
        case .garden(let n): return n
        case .reference(let n): return n
        }
    }

    var defaultLighting: String? {
        switch self {
        case .interior(let s): return s.defaultLighting
        case .exterior: return "daylight"
        case .garden: return "bright daylight"
        case .reference: return nil
        }
    }
}

// MARK: - Edit Policy

struct EditPolicy {
    // Preserve
    var preserveLayout: Bool = true
    var preserveCamera: Bool = true
    var preserveLeftRight: Bool = true
    var forbidMirrorFlip: Bool = true
    var preserveFixedArchitecture: Bool = true
    var preserveExistingFurniturePositions: Bool = true

    // Physical scale/size locks
    var preserveScaleProportions: Bool = true
    var forbidSpaceResizing: Bool = true
    var forbidOpeningResizing: Bool = true
    var forbidCeilingHeightChange: Bool = true

    // May change
    var allowRetexture: Bool = true
    var allowRelight: Bool = true

    // May add (small decor only)
    var allowAdditions: Bool = true
    var additionsWhitelist: [String] = [
        "rug", "floor lamp", "table lamp", "artwork", "plants",
        "side table", "throw pillows", "vase", "blanket", "small bookshelf"
    ]

    // Negatives
    var negatives: String = "text, watermark, logo, blurry, lowres, heavy artifacts, distorted geometry"
}

// MARK: - Context

struct ChatGPTPromptContext {
    var option: DesignOption?
    var room: InteriorType?
    var typeSelection: String?
    var style: UnifiedStyle?
    var palette: ColorType?
    var aspectRatio: String = "2:3" // синхронізовано з 1024x1536
    var materials: [String] = []
    var lighting: String?
    var realism: String = "photorealistic"
    var negative: String = "text, watermark, logo, blurry, lowres"
    var baseImage: UIImage?
    var referenceImage: UIImage?
    var isEmptyRoom: Bool = false
    var policy: EditPolicy = .init()

    // Захист об’єктів і зон
    var protectedObjects: [String] = [] // e.g. ["refrigerator", "sink", "table"]
    var noEditZones: [CGRect] = [] // Normalized 0..1 rects (opaque in mask)

    var hasContentImage: Bool { baseImage != nil }
    var hasReferenceImage: Bool { referenceImage != nil }
}

// MARK: - Payload

struct ChatMessagePayload {
    let system: String
    let user: String
    let metadata: [String: Any]
}

// MARK: - Prompt Builder

struct PromptBuilder {
    static func buildPayload(from ctx: ChatGPTPromptContext, model: String = "dall-e-2") -> ChatMessagePayload {
        let user = makeUserPrompt(ctx)
        let system = systemPrompt(for: ctx.option)
        let meta: [String: Any] = [
            "aspect_ratio": ctx.aspectRatio,
            "model": model,
            "image_mode": "image_to_image"
        ]
        return .init(system: system, user: user, metadata: meta)
    }

    private static func systemPrompt(for option: DesignOption?) -> String {
        switch option {
        case .exterior, .garden:
            return "You are an architectural image editor for photorealistic outdoor scenes. Follow all constraints exactly."
        case .reference:
            return "You are an architectural image editor for photorealistic style transfer. Follow all constraints exactly."
        default:
            return "You are an architectural image editor for photorealistic interiors. Follow all constraints exactly."
        }
    }

    private static func makeUserPrompt(_ ctx: ChatGPTPromptContext) -> String {
        let isReference = (ctx.option == .reference)
        let roomName = isReference ? "scene" : (ctx.room?.name ?? ctx.typeSelection ?? "room")

        var parts: [String] = []

        // Objective
        parts.append("Objective: Restyle this \(roomName) photo; \(ctx.realism) output.")

        // Preserve
        var preserve: [String] = []
        if ctx.policy.preserveLayout { preserve.append("original layout") }
        if ctx.policy.preserveCamera { preserve.append("camera pose and FOV unchanged") }
        if ctx.policy.preserveLeftRight { preserve.append("left/right exactly as base") }
        if ctx.policy.forbidMirrorFlip { preserve.append("never mirror or flip") }
        if ctx.policy.preserveFixedArchitecture { preserve.append("walls, openings, and fixed plumbing unchanged") }
        if ctx.policy.preserveExistingFurniturePositions { preserve.append("positions of existing furniture unchanged") }
        if ctx.policy.preserveScaleProportions { preserve.append("real-world scale and proportions identical to base") }
        if ctx.policy.forbidSpaceResizing { preserve.append("do not enlarge or shrink the room; keep wall distances unchanged") }
        if ctx.policy.forbidOpeningResizing { preserve.append("do not resize windows, doors, or openings") }
        if ctx.policy.forbidCeilingHeightChange { preserve.append("keep ceiling/wall heights unchanged") }

        if !preserve.isEmpty {
            parts.append("Preserve: " + preserve.joined(separator: ", ") + ".")
        }

        // Protected objects / zones
        if !ctx.protectedObjects.isEmpty {
            parts.append("Preserve objects: " + ctx.protectedObjects.joined(separator: ", ") + "; do not remove or occlude.")
        }

        if !ctx.noEditZones.isEmpty {
            parts.append("Edits limited to unprotected living area only; protected zones must remain unchanged.")
        }

        // May change
        if ctx.policy.allowRetexture {
            if !ctx.hasReferenceImage {
                parts.append("May change: finishes, materials, textures, colors, fabrics; refine lighting without changing viewpoint or scale.")
            } else {
                parts.append("The following may be changed: finishes, materials, textures, colors, fabrics; lighting improvements; placement of elements.")
            }
        }

        // May add
        if ctx.policy.allowAdditions {
            let white = ctx.policy.additionsWhitelist.joined(separator: ", ")
            parts.append("May add: style-consistent small decor (\(white)) only where space allows; do not block doors or paths.")
        } else {
            parts.append("Do not add new objects.")
        }

        // Style
        if !isReference {
            let styleName = ctx.style?.name ?? "neutral"
            var styleBlock = "Style: \(styleName)."

            if let p = ctx.palette, p != .random {
                let hexes = p.colors.map { "#\($0)" }.joined(separator: ", ")
                styleBlock += " Palette: \(hexes); apply cohesively."
            } else {
                styleBlock += " Palette: designer’s cohesive selection."
            }

            if !ctx.materials.isEmpty {
                styleBlock += " Materials: \(ctx.materials.joined(separator: ", "))."
            }

            if ctx.policy.allowRelight {
                let l = ctx.lighting ?? ctx.style?.defaultLighting
                styleBlock += l != nil
                    ? " Lighting: \(l!) consistent with the photo."
                    : " Lighting: consistent with the photo."
            }

            parts.append(styleBlock)
        }

        if ctx.isEmptyRoom {
            parts.append("If the room is empty, add only essential, style-matching items without altering structure or scale.")
        }

        // Technical
        parts.append("Technical: Aspect ratio \(ctx.aspectRatio); keep camera intrinsics; avoid geometric warping; never crop or stretch.")

        // Exclusions
        let negativesCombined = [ctx.policy.negatives, ctx.negative].joined(separator: ", ")
        parts.append("Exclusions: \(negativesCombined).")

        // Reference (оновлено для reference-режиму)
        if isReference {
            parts.append("Base: Use the attached room photo as the structural foundation; apply the provided style description to transform finishes, colors, and decor without altering layout, scale, or camera view.")
        } else {
            parts.append(ctx.hasContentImage
                ? "Reference: Use the attached photo as the base; preserve orientation and scale."
                : "Reference: Awaiting the base content image.")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Prompt Manager

final class PromptManager {
    var context = ChatGPTPromptContext()

    // Updates
    func updateOption(_ option: DesignOption) {
        context.option = option
        if option != .interior { context.room = nil }
        else { context.typeSelection = nil }
    }

    func updateRoom(_ room: InteriorType) {
        if context.option == .interior { context.room = room }
    }

    func updateTypeSelection(_ typeName: String, for option: DesignOption) {
        if option != .interior { context.typeSelection = typeName }
    }

    func updateStyle(_ style: UnifiedStyle) {
        context.style = style
        if context.lighting == nil {
            context.lighting = style.defaultLighting
        }
    }

    func updatePalette(_ palette: ColorType) {
        context.palette = palette
    }

    func setAspectRatio(_ ratio: String) {
        context.aspectRatio = ratio
    }

    func addMaterial(_ material: String) {
        if !context.materials.contains(material) {
            context.materials.append(material)
        }
    }

    func setMaterials(_ m: [String]) {
        context.materials = m
    }

    func updateLighting(_ lighting: String?) {
        context.lighting = lighting
    }

    // Policy & protection
    func setPolicy(_ policy: EditPolicy) { context.policy = policy }
    func setAllowAdditions(_ allowed: Bool) { context.policy.allowAdditions = allowed }
    func setAdditionsWhitelist(_ items: [String]) { context.policy.additionsWhitelist = items }
    func setIsEmptyRoom(_ flag: Bool) { context.isEmptyRoom = flag }
    func setProtectedObjects(_ names: [String]) { context.protectedObjects = names }
    func setNoEditZones(_ rects01: [CGRect]) { context.noEditZones = rects01 }

    func updateBaseImage(_ image: UIImage) { context.baseImage = image }
    func updateReferenceImage(_ image: UIImage) { context.referenceImage = image }

    func buildPrompt(model: String = "dall-e-2")
    -> (payload: ChatMessagePayload, baseImage: UIImage?, referenceImage: UIImage?, maskPNG: Data?, apiSize: String?)? {

        guard let option = context.option else { return nil }

        if option == .reference {
            guard context.hasContentImage, context.hasReferenceImage else { return nil }
        } else {
            guard context.style != nil else { return nil }
            if option == .interior && context.room == nil { return nil }
        }

        // 1. Build payload
        let payload = PromptBuilder.buildPayload(from: context, model: model)

        // 2. Prepare base image
        guard let base = context.baseImage else {
            return (payload, context.baseImage, context.referenceImage, nil, nil)
        }

        let isEdits = option == .reference || context.hasContentImage  // Для edits/reference — square
        let preferred: APIImageSize = {
            if isEdits {
                return .square  // Фікс для DALL·E 2 edits (1024x1024 max)
            }
            switch context.aspectRatio {
            case "2:3": return .portrait
            case "3:2": return .landscape
            case "1:1": return .square
            default: return UIImage.bestAPIFormat(for: base)
            }
        }()

        let prep = base.resizedAndPadded(to: preferred)

        // 3. Mask if any
        let maskData: Data? = context.noEditZones.isEmpty
            ? nil
            : UIImage.makeNoEditMask(size: prep.image.size, noEditRects: context.noEditZones)

        let sizeParam: String? = {
            if isEdits { return nil }  // Ігнор для edits (вивід базується на input)
            switch preferred {
            case .square: return "1024x1024"
            case .portrait: return "1024x1536"
            case .landscape: return "1536x1024"
            }
        }()

        context.baseImage = prep.image
        return (payload, context.baseImage, context.referenceImage, maskData, sizeParam)
    }

    func resetContext() {
        context = ChatGPTPromptContext()
    }
}

// MARK: - API Canvas Helpers

enum APIImageSize {
    case square, portrait, landscape

    var size: CGSize {
        switch self {
        case .square: return CGSize(width: 1024, height: 1024)
        case .portrait: return CGSize(width: 1024, height: 1536)
        case .landscape: return CGSize(width: 1536, height: 1024)
        }
    }
}

extension UIImage {
    static func bestAPIFormat(for image: UIImage) -> APIImageSize {
        let a = image.size.width / image.size.height
        let dS = abs(a - 1.0)
        let dP = abs(a - (1024.0 / 1536.0))
        let dL = abs(a - (1536.0 / 1024.0))
        if dS <= min(dP, dL) { return .square }
        return dP < dL ? .portrait : .landscape
    }

    func resizedAndPadded(to target: APIImageSize) -> (image: UIImage, cropBox: CGRect) {
        let targetSize = target.size
        let scale = min(targetSize.width / size.width, targetSize.height / size.height)
        let newW = floor(size.width * scale)
        let newH = floor(size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let out = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            let x = (targetSize.width - newW) / 2.0
            let y = (targetSize.height - newH) / 2.0
            self.draw(in: CGRect(x: x, y: y, width: newW, height: newH))
        }

        let crop = CGRect(
            x: (targetSize.width - newW) / 2.0,
            y: (targetSize.height - newH) / 2.0,
            width: newW,
            height: newH
        )
        return (out, crop)
    }

    // Mask: opaque = protect, transparent = editable
    static func makeNoEditMask(size: CGSize, noEditRects: [CGRect]) -> Data? {
        let r = UIGraphicsImageRenderer(size: size)
        let img = r.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            for n in noEditRects {
                let rect = CGRect(
                    x: n.origin.x * size.width,
                    y: n.origin.y * size.height,
                    width: n.width * size.width,
                    height: n.height * size.height
                )
                ctx.fill(rect)
            }
        }
        return img.pngData()
    }
}

extension StyleInteriorType {
    var defaultLighting: String {
        switch self {
        case .scandinavian, .minimalist, .modern, .contemporary: return "daylight"
        case .classic, .artDeco: return "golden hour"
        case .industrial, .loft: return "moody"
        case .japanese, .wabiSabi: return "soft daylight"
        case .rustic, .farmhouse, .mediterranean: return "golden hour"
        case .vintage, .bohemian: return "evening warm"
        case .tropical: return "bright daylight"
        case .chinese: return "daylight"
        case .hottic: return "golden hour"
        }
    }
}
