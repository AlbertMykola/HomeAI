import UIKit

extension Notification.Name {
    static let imageHistoryDidChange = Notification.Name("imageHistoryDidChange")
}

struct ImageDoc: Codable {
    let id: String
    let prompt: String
    let model: String
    let size: String?
    let seed: Int?
    let storagePath: String
    let previewPath: String?
    let originalPath: String?
    let option: String?
    let interiorRoomType: String?
    let exteriorBuildingType: String?
    let gardenType: String?
    let interiorStyle: String?
    let exteriorStyle: String?
    let createdAt: Date
    let style: String?
    let colorName: String?
    let designMode: String?
    let customPrompt: String?
    let surfaceMaterial: String?
    let surfaceCustomPrompt: String?
    let replaceMode: String?
    let objectToReplace: String?
    
    var designOption: DesignOption? {
        option.flatMap { DesignOption(rawValue: $0) }
    }
    
    var savedInteriorRoomType: InteriorType? {
        interiorRoomType.flatMap { value in
            InteriorType.allCases.first { "\($0)" == value }
        }
    }
    
    var savedExteriorBuildingType: ExteriorType? {
        exteriorBuildingType.flatMap { value in
            ExteriorType.allCases.first { "\($0)" == value }
        }
    }
    
    var savedGardenType: GardenType? {
        gardenType.flatMap { value in
            GardenType.allCases.first { "\($0)" == value }
        }
    }
    
    var savedInteriorStyle: StyleInteriorType? {
        interiorStyle.flatMap { value in
            StyleInteriorType.allCases.first { "\($0)" == value }
        }
    }
    
    var savedExteriorStyle: StyleExteriorType? {
        exteriorStyle.flatMap { value in
            StyleExteriorType.allCases.first { "\($0)" == value }
        }
    }
    
    var savedDesignMode: DesignMode? {
        guard let designMode else { return nil }
        return DesignMode(rawValue: designMode)
    }
    
    var savedSurfaceMaterial: SurfaceMaterialOption? {
        surfaceMaterial.flatMap { value in
            SurfaceMaterialOption.allCases.first { "\($0)" == value }
        }
    }
    
    var savedReplaceMode: GemeniPromptManager.ReplaceMode? {
        replaceMode.flatMap { value in
            switch value {
            case "replace":
                return .replace
            case "remove":
                return .remove
            default:
                return nil
            }
        }
    }
    
    var hasLocalOriginal: Bool {
        guard let originalPath else { return false }
        return FileManager.default.fileExists(atPath: originalPath)
    }
    
    var canRegenerate: Bool {
        guard hasLocalOriginal, let option = designOption else { return false }
        switch option {
        case .interior:
            return savedInteriorRoomType != nil
        case .exterior:
            return savedExteriorBuildingType != nil
        case .garden:
            return savedGardenType != nil
        default:
            return false
        }
    }
}

final class ImageHistoryService {
    private let fileManager = FileManager.default
    private let historyDirectory: URL
    private var cachedDocs: [ImageDoc] = []
    private var nextIndex = 0
    private(set) var hasMore = true
    
    var canLoadMore: Bool { hasMore }

    init() {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        historyDirectory = base.appendingPathComponent("ImageHistory", isDirectory: true)
        try? fileManager.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
        reloadCache()
    }
    
    func resetHistoryPaging() {
        reloadCache()
    }

    private func reloadCache() {
        cachedDocs = loadAllDocs()
        nextIndex = 0
        hasMore = !cachedDocs.isEmpty
    }
    
    private func loadAllDocs() -> [ImageDoc] {
        guard let folders = try? fileManager.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        var docs: [ImageDoc] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for folder in folders {
            let metadataURL = folder.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataURL),
                  let storedDoc = try? decoder.decode(ImageDoc.self, from: data) else { continue }
            docs.append(storedDoc.absolutizedPaths(relativeTo: historyDirectory))
        }
        return docs.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func saveGeneratedImage(_ data: Data,
                            prompt: String,
                            model: String,
                            size: String?,
                            seed: Int?,
                            makePreview: Bool = false,
                            style: String?,
                            colorName: String?,
                            originalImage: UIImage? = nil,
                            designOption: DesignOption,
                            interiorRoomType: InteriorType?,
                            exteriorBuildingType: ExteriorType?,
                            gardenType: GardenType?,
                            interiorStyle: StyleInteriorType?,
                            exteriorStyle: StyleExteriorType?,
                            designMode: DesignMode?,
                            customPrompt: String?,
                            surfaceMaterial: SurfaceMaterialOption?,
                            surfaceCustomPrompt: String?,
                            replaceMode: GemeniPromptManager.ReplaceMode?,
                            objectToReplace: String?) async throws -> ImageDoc {
        let fileId = UUID().uuidString.lowercased()
        let entryFolder = historyDirectory.appendingPathComponent(fileId, isDirectory: true)
        try fileManager.createDirectory(at: entryFolder, withIntermediateDirectories: true)
        
        let generatedURL = entryFolder.appendingPathComponent("generated.jpg")
        try data.write(to: generatedURL, options: .atomic)
        
        var previewPath: String? = nil
        if makePreview,
           let previewImage = UIImage(data: data),
           let previewData = previewImage.jpegData(compressionQuality: 0.5) {
            let previewURL = entryFolder.appendingPathComponent("preview.jpg")
            try previewData.write(to: previewURL, options: .atomic)
            previewPath = previewURL.path
        }
        
        var originalPath: String? = nil
        if let originalImage,
           let originalData = originalImage.jpegData(compressionQuality: 0.9) {
            let originalURL = entryFolder.appendingPathComponent("original.jpg")
            try originalData.write(to: originalURL, options: .atomic)
            originalPath = originalURL.path
        }
        
        let doc = ImageDoc(
            id: fileId,
            prompt: prompt,
            model: model,
            size: size,
            seed: seed,
            storagePath: generatedURL.path,
            previewPath: previewPath,
            originalPath: originalPath,
            option: designOption.rawValue,
            interiorRoomType: interiorRoomType.map { "\($0)" },
            exteriorBuildingType: exteriorBuildingType.map { "\($0)" },
            gardenType: gardenType.map { "\($0)" },
            interiorStyle: interiorStyle.map { "\($0)" },
            exteriorStyle: exteriorStyle.map { "\($0)" },
            createdAt: Date(),
            style: style,
            colorName: colorName,
            designMode: designMode?.rawValue,
            customPrompt: customPrompt,
            surfaceMaterial: surfaceMaterial.map { "\($0)" },
            surfaceCustomPrompt: surfaceCustomPrompt,
            replaceMode: replaceMode.map { "\($0)" },
            objectToReplace: objectToReplace
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metadataURL = entryFolder.appendingPathComponent("metadata.json")
        let relativeDoc = doc.relativizedPaths(relativeTo: historyDirectory)
        try encoder.encode(relativeDoc).write(to: metadataURL, options: .atomic)
        
        cachedDocs.insert(doc, at: 0)
        nextIndex = 0
        hasMore = !cachedDocs.isEmpty
        notifyHistoryChange()
        return doc
    }

    @discardableResult
    func fetchNextHistoryPage(pageSize: Int = 20) async throws -> [ImageDoc] {
        guard !cachedDocs.isEmpty else {
            hasMore = false
            return []
        }
        guard nextIndex < cachedDocs.count else {
            hasMore = false
            return []
        }
        
        let endIndex = min(nextIndex + pageSize, cachedDocs.count)
        let page = Array(cachedDocs[nextIndex..<endIndex])
        nextIndex = endIndex
        hasMore = nextIndex < cachedDocs.count
        return page
    }
    
    func loadImage(at storagePath: String) async throws -> UIImage {
        let url = URL(fileURLWithPath: storagePath)
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "LocalImageStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image at \(storagePath)"])
        }
        return image
    }

    func deleteImage(docId: String) async throws {
        let folder = historyDirectory.appendingPathComponent(docId, isDirectory: true)
        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
            reloadCache()
            notifyHistoryChange()
        }
    }
}

private extension ImageHistoryService {
    func notifyHistoryChange() {
        NotificationCenter.default.post(name: .imageHistoryDidChange, object: nil)
    }
}

private extension ImageDoc {
    func relativizedPaths(relativeTo base: URL) -> ImageDoc {
        return replacingPaths(
            storagePath: makeRelative(storagePath, base: base) ?? "",
            previewPath: makeRelative(previewPath, base: base),
            originalPath: makeRelative(originalPath, base: base)
        )
    }
    
    func absolutizedPaths(relativeTo base: URL) -> ImageDoc {
        return replacingPaths(
            storagePath: makeAbsolute(storagePath, base: base) ?? "",
            previewPath: makeAbsolute(previewPath, base: base),
            originalPath: makeAbsolute(originalPath, base: base)
        )
    }
    
    func replacingPaths(storagePath: String, previewPath: String?, originalPath: String?) -> ImageDoc {
        ImageDoc(
            id: id,
            prompt: prompt,
            model: model,
            size: size,
            seed: seed,
            storagePath: storagePath,
            previewPath: previewPath,
            originalPath: originalPath,
            option: option,
            interiorRoomType: interiorRoomType,
            exteriorBuildingType: exteriorBuildingType,
            gardenType: gardenType,
            interiorStyle: interiorStyle,
            exteriorStyle: exteriorStyle,
            createdAt: createdAt,
            style: style,
            colorName: colorName,
            designMode: designMode,
            customPrompt: customPrompt,
            surfaceMaterial: surfaceMaterial,
            surfaceCustomPrompt: surfaceCustomPrompt,
            replaceMode: replaceMode,
            objectToReplace: objectToReplace
        )
    }
    
    func makeRelative(_ path: String?, base: URL) -> String? {
        guard let path else { return nil }
        if pathHasScheme(path) { return path }
        guard path.hasPrefix("/") else { return path }
        
        let basePath = base.path
        if path.hasPrefix(basePath) {
            var relative = String(path.dropFirst(basePath.count))
            if relative.hasPrefix("/") {
                relative.removeFirst()
            }
            return relative
        }
        return path
    }
    
    func makeAbsolute(_ path: String?, base: URL) -> String? {
        guard let path else { return nil }
        if pathHasScheme(path) { return path }
        if path.hasPrefix("/") {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
            if let rebased = rebaseAbsolutePath(path, base: base) {
                return rebased
            }
            return path
        }
        let url = base.appendingPathComponent(path)
        return url.path
    }
    
    func rebaseAbsolutePath(_ path: String, base: URL) -> String? {
        guard let range = path.range(of: "/ImageHistory/") else { return nil }
        let relative = String(path[range.upperBound...])
        if relative.isEmpty { return nil }
        let rebuilt = base.appendingPathComponent(relative).path
        return rebuilt
    }
    
    func pathHasScheme(_ path: String) -> Bool {
        if let url = URL(string: path), let scheme = url.scheme, !scheme.isEmpty {
            return true
        }
        return false
    }
}

