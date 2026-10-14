import UIKit

/// A project = one photo of a room and every version made from it (Original → V1 → V2 …).
/// Versions are regular history entries (ImageDoc); this store only groups them.
struct DesignProject: Codable, Equatable {
    let id: String
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    /// History doc ids, oldest first (V1, V2, …).
    var versionIDs: [String]
    /// What each edit asked for ("Make the sofa terracotta"), by doc id.
    var notes: [String: String]? = nil
}

extension DesignProject {
    /// "3 versions · Today".
    static func versionsLine(count: Int, date: Date) -> String {
        let versions = count == 1 ? "1 version".localized : String(format: "%d versions".localized, count)
        return "\(versions) · \(date.projectRelativeString)"
    }
}

extension Notification.Name {
    static let projectsDidChange = Notification.Name("projectsDidChange")
}

final class ProjectStore {

    static let shared = ProjectStore()

    private let fileURL: URL
    private var projects: [DesignProject] = []
    private let history = ImageHistoryService()

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("design_projects.json")
        load()
    }

    // MARK: Reading

    /// Projects with their docs, newest activity first. History entries made before projects existed
    /// become single-version projects.
    func allProjects() -> [(project: DesignProject, versions: [ImageDoc])] {
        let docs = history.allDocs()
        let byID = Dictionary(docs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var used = Set<String>()
        var result: [(DesignProject, [ImageDoc])] = []
        for project in projects {
            let versions = project.versionIDs.compactMap { byID[$0] }
            guard !versions.isEmpty else { continue }
            versions.forEach { used.insert($0.id) }
            result.append((project, versions))
        }
        for doc in docs where !used.contains(doc.id) {
            let legacy = DesignProject(id: "legacy-\(doc.id)", title: nil, createdAt: doc.createdAt,
                                       updatedAt: doc.createdAt, versionIDs: [doc.id])
            result.append((legacy, [doc]))
        }
        return result.sorted { $0.0.updatedAt > $1.0.updatedAt }
    }

    func project(containing docID: String) -> (project: DesignProject, versions: [ImageDoc])? {
        allProjects().first { $0.project.versionIDs.contains(docID) }
    }

    func displayTitle(for project: DesignProject, versions: [ImageDoc]) -> String {
        if let title = project.title, !title.isEmpty { return title }
        guard let first = versions.first else { return "Design".localized }
        if let style = first.style, !style.isEmpty, style != "No Style", style != "Custom", first.designOption != .rearrange {
            // "Japandi living room" reads well in English only; other languages get "Вітальня · Сучасний".
            let english = (Locale.preferredLanguages.first ?? "en").hasPrefix("en")
            return english ? "\(style) \(first.projectTitle.lowercased())" : "\(first.projectTitle) · \(style)"
        }
        return first.projectTitle
    }

    // MARK: Writing

    /// New project for a wizard generation; returns its id.
    @discardableResult
    func createProject(firstDocID: String) -> String {
        let id = UUID().uuidString
        let now = Date()
        projects.insert(DesignProject(id: id, title: nil, createdAt: now, updatedAt: now, versionIDs: [firstDocID]), at: 0)
        save()
        return id
    }

    /// Adds an edit (paint, replace, ask for a change, again…) as the next version.
    func addVersion(docID: String, toProjectContaining baseDocID: String) {
        if let i = projects.firstIndex(where: { $0.versionIDs.contains(baseDocID) }) {
            projects[i].versionIDs.append(docID)
            projects[i].updatedAt = Date()
        } else {
            // Legacy single doc → becomes a real project now.
            let now = Date()
            projects.insert(DesignProject(id: UUID().uuidString, title: nil, createdAt: now, updatedAt: now,
                                          versionIDs: [baseDocID, docID]), at: 0)
        }
        save()
    }

    func note(for docID: String) -> String? {
        projects.first { $0.versionIDs.contains(docID) }?.notes?[docID]
    }

    func setNote(_ note: String, for docID: String) {
        guard let i = projects.firstIndex(where: { $0.versionIDs.contains(docID) }) else { return }
        var notes = projects[i].notes ?? [:]
        notes[docID] = note
        projects[i].notes = notes
        save()
    }

    func rename(projectContaining docID: String, to title: String) {
        if let i = projects.firstIndex(where: { $0.versionIDs.contains(docID) }) {
            projects[i].title = title
        } else {
            let now = Date()
            projects.insert(DesignProject(id: UUID().uuidString, title: title, createdAt: now, updatedAt: now,
                                          versionIDs: [docID]), at: 0)
        }
        save()
    }

    /// Deletes one version (history entry). Removing the last version removes the project.
    func deleteVersion(docID: String) async throws {
        try await history.deleteImage(docId: docID)
        if let i = projects.firstIndex(where: { $0.versionIDs.contains(docID) }) {
            projects[i].versionIDs.removeAll { $0 == docID }
            if projects[i].versionIDs.isEmpty { projects.remove(at: i) }
        }
        save()
    }

    func deleteProject(containing docID: String) async throws {
        let ids = projects.first(where: { $0.versionIDs.contains(docID) })?.versionIDs ?? [docID]
        for id in ids { try await history.deleteImage(docId: id) }
        projects.removeAll { $0.versionIDs.contains(docID) }
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        projects = (try? decoder.decode([DesignProject].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(projects) {
            try? data.write(to: fileURL, options: .atomic)
        }
        NotificationCenter.default.post(name: .projectsDidChange, object: nil)
    }
}
