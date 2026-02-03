import FirebaseAuth
import Firebase

protocol AuthProviding {
    func ensureSignedIn() async throws -> String
}

final class AuthService: AuthProviding {
    static let shared = AuthService() // lazy + thread-safe by Swift
    private init() {}

    func ensureSignedIn() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }
}
