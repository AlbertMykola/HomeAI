import Foundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import UIKit

struct ImageDoc: Codable {
    @DocumentID var id: String?
    let uid: String
    let prompt: String
    let model: String
    let size: String?
    let seed: Int?
    let storagePath: String
    let previewPath: String?
    let downloadURL: String?
    @ServerTimestamp var createdAt: Timestamp?
    let style: String?
    let colorName: String?
}

final class FirebaseImageService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let auth: AuthProviding
    private var lastSnapshot: DocumentSnapshot?
    private var hasMore = true
    
    var canLoadMore: Bool { hasMore }

    init(auth: AuthProviding = AuthService.shared) {
        self.auth = auth
    }
    
    func resetHistoryPaging() {
        lastSnapshot = nil
        hasMore = true
    }

    @discardableResult
    func saveGeneratedImage(_ data: Data, prompt: String, model: String, size: String?, seed: Int?, makePreview: Bool = false, style: String?, colorName: String?) async throws -> ImageDoc {
        let uid = try await auth.ensureSignedIn()

        let fileId = UUID().string
        let path = "images/\(uid)/\(fileId).jpg"
        let ref = storage.reference(withPath: path)

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)

        var previewPath: String? = nil
        if makePreview,
           let ui = UIImage(data: data),
           let previewData = ui.jpegData(compressionQuality: 0.5) {
            let p = "previews/\(uid)/\(fileId).jpg"
            let pref = storage.reference(withPath: p)
            let pmeta = StorageMetadata()
            pmeta.contentType = "image/jpeg"
            _ = try await pref.putDataAsync(previewData, metadata: pmeta)
            previewPath = p
        }

        let url = try? await ref.downloadURL()

        let docRef = db.collection("users").document(uid)
            .collection("images").document(fileId)

        try await docRef.setData([
            "uid": uid,
            "prompt": prompt,
            "model": model,
            "size": size as Any? ?? NSNull(),
            "seed": seed as Any? ?? NSNull(),
            "storagePath": path,
            "previewPath": previewPath as Any? ?? NSNull(),
            "downloadURL": url?.absoluteString as Any? ?? NSNull(),
            "createdAt": FieldValue.serverTimestamp(),
            "style": style as Any? ?? NSNull(),
            "colorName": colorName as Any? ?? NSNull()
        ], merge: false)

        return ImageDoc(
            id: fileId,
            uid: uid,
            prompt: prompt,
            model: model,
            size: size,
            seed: seed,
            storagePath: path,
            previewPath: previewPath,
            downloadURL: url?.absoluteString,
            createdAt: nil,
            style: style,
            colorName: colorName
        )
    }

    // Пагінація сторінками (orderBy + startAfter)
    @discardableResult
    func fetchNextHistoryPage(pageSize: Int = 20) async throws -> [ImageDoc] {
        guard hasMore else { return [] }

        let uid = try await auth.ensureSignedIn()

        var q: Query = db.collection("users").document(uid)
            .collection("images")
            // стабільний порядок: спочатку за датою, потім за id
            .order(by: "createdAt", descending: true)
            .order(by: FieldPath.documentID(), descending: true)
            .limit(to: pageSize)

        // опційно — відкинути записи без createdAt
        // q = q.whereField("createdAt", isGreaterThan: Timestamp(seconds: 0, nanoseconds: 0))

        if let last = lastSnapshot {
            q = q.start(afterDocument: last)
        }

        let snap = try await q.getDocuments()
        lastSnapshot = snap.documents.last

        if snap.documents.count < pageSize { hasMore = false }

        return try snap.documents.map { try $0.data(as: ImageDoc.self) }
    }

    // Realtime‑оновлення (опційно): слухач змін колекції
    func observeHistoryRealtime(
        onChange: @escaping ([ImageDoc]) -> Void,
        onError: @escaping (Error) -> Void
    ) async -> ListenerRegistration? {
        do {
            let uid = try await auth.ensureSignedIn()
            let q = db.collection("users").document(uid)
                .collection("images")
                .order(by: "createdAt", descending: true)
            return q.addSnapshotListener { snap, err in
                if let err = err { onError(err); return }
                guard let snap = snap else { return }
                do {
                    let items = try snap.documents.map { try $0.data(as: ImageDoc.self) }
                    onChange(items)
                } catch {
                    onError(error)
                }
            }
        } catch {
            onError(error)
            return nil
        }
    }

    // URL для Storage path (коли не зберігаєте downloadURL у документі)
    func downloadURL(for storagePath: String) async throws -> URL {
        try await storage.reference(withPath: storagePath).downloadURL()
    }

    // Видалення Storage + Firestore
    func deleteImage(docId: String) async throws {
        let uid = try await auth.ensureSignedIn()
        let ref = db.collection("users").document(uid)
            .collection("images").document(docId)
        let snap = try await ref.getDocument()
        guard let image = try? snap.data(as: ImageDoc.self) else { return }
        try? await storage.reference(withPath: image.storagePath).delete()
        if let p = image.previewPath { try? await storage.reference(withPath: p).delete() }
        try await ref.delete()
    }
}

private extension UUID {
    var string: String { uuidString.lowercased() }
}
